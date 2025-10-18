import Foundation
import OSLog
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Unified chat service that replaces ChatService and PendingMessageService
/// This eliminates the dual approval system and provides a single source of truth
final class UnifiedChatService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var conversations: [Conversation] = []
    @Published var messages: [String: [ChatMessage]] = [:]
    @Published var inquiries: [ChatInquiry] = []
    @Published var pendingMessages: [ChatMessage] = [] // Messages awaiting approval
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let listenerManager = MessageListenerManager.shared
    private let resilientService = ResilientChatService.shared
    private let notificationManager = SmartNotificationManager.shared
    private var currentUserRole: UserRole = .petOwner
    private var userNameCache: [String: String] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    static let shared = UnifiedChatService()
    
    private init() {
        setupListeners()
    }
    
    deinit {
        cleanup()
    }
    
    /// Cleanup method for memory management
    func cleanup() {
        // ListenerManager handles its own cleanup in deinit
        userNameCache.removeAll()
    }
    
    // MARK: - Setup
    private func setupListeners() {
        // Listen to conversations for current user
        if let userId = Auth.auth().currentUser?.uid {
            listenerManager.attachConversationListener(for: userId)
        }
        
        // Listen to inquiries (admin only)
        if isAdmin() {
            listenerManager.attachInquiriesListener()
        }
        
        // Update published properties from listener manager
        listenerManager.$conversations
            .assign(to: &$conversations)
        
        listenerManager.$messages
            .assign(to: &$messages)
        
        listenerManager.$inquiries
            .assign(to: &$inquiries)
        
        // Filter pending messages
        listenerManager.$messages
            .map { messagesDict in
                messagesDict.values.flatMap { $0 }
                    .filter { $0.status == .pending }
            }
            .assign(to: &$pendingMessages)
    }
    
    // MARK: - Conversation Management
    
    /// Create or get admin inquiry channel
    func getOrCreateAdminInquiryChannel() async throws -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw ChatError.notAuthenticated
        }
        
        // Find admin user ID
        let adminQuery = try await db.collection("users")
            .whereField("role", isEqualTo: UserRole.admin.rawValue)
            .limit(to: 1)
            .getDocuments()
        
        guard let adminDoc = adminQuery.documents.first else {
            throw ChatError.adminNotFound
        }
        
        let adminId = adminDoc.documentID
        
        // Check if admin inquiry channel already exists
        // Use a more specific query to find existing conversations
        AppLogger.chat.info("Looking for existing admin inquiry conversation for user: \(currentUserId)")
        
        // First, try to find conversations where both users are participants
        // We'll query by the current user and then filter client-side for the admin
        let existingQuery = try await db.collection("conversations")
            .whereField("participants", arrayContains: currentUserId)
            .whereField("type", isEqualTo: ConversationType.adminInquiry.rawValue)
            .whereField("isPinned", isEqualTo: true)
            .order(by: "lastMessageAt", descending: true)
            .getDocuments()
        
        AppLogger.chat.info("Found \(existingQuery.documents.count) potential conversations")
        
        // Filter to find conversation that also contains adminId
        // Also check that it has exactly 2 participants (user + admin)
        let existingConversation = existingQuery.documents.first { doc in
            let data = doc.data()
            if let participants = data["participants"] as? [String] {
                let containsAdmin = participants.contains(adminId)
                let hasCorrectParticipantCount = participants.count == 2
                AppLogger.chat.debug("Conversation \(doc.documentID) participants: \(participants), contains admin: \(containsAdmin), correct count: \(hasCorrectParticipantCount)")
                return containsAdmin && hasCorrectParticipantCount
            }
            return false
        }
        
        if let existingDoc = existingConversation {
            AppLogger.chat.info("Found existing conversation: \(existingDoc.documentID)")
            
            // Attach message listener for the existing conversation
            listenToMessages(conversationId: existingDoc.documentID)
            
            return existingDoc.documentID
        }
        
        AppLogger.chat.info("No existing conversation found, creating new one")
        
        // Create new admin inquiry channel
        let conversationRef = db.collection("conversations").document()
        let userRole = getCurrentUserRole()
        AppLogger.chat.info("Creating NEW conversation \(conversationRef.documentID) with user role: \(userRole.rawValue)")
        AppLogger.chat.info("Participants: [\(currentUserId), \(adminId)]")
        
        // Check for and clean up any duplicate conversations before creating new one
        try await cleanupDuplicateConversations(for: currentUserId, adminId: adminId)
        let conversationData: [String: Any] = [
            "participants": [currentUserId, adminId],
            "participantRoles": [userRole.rawValue, UserRole.admin.rawValue],
            "type": ConversationType.adminInquiry.rawValue,
            "isPinned": true,
            "pinnedName": "SaviPets-Admin",
            "lastMessage": "",
            "lastMessageAt": FieldValue.serverTimestamp(),
            "status": "active",
            "autoResponderSent": false,
            "adminReplied": false,
            "createdAt": FieldValue.serverTimestamp(),
            "autoResponseHistory": [:],
            "autoResponseCooldown": 86400,
            "unreadCounts": [:],
            "lastReadTimestamps": [:]
        ]
        
        try await conversationRef.setData(conversationData)
        
        // Attach message listener for the new conversation
        listenToMessages(conversationId: conversationRef.documentID)
        
        return conversationRef.documentID
    }
    
    /// Accept inquiry and create conversation
    func acceptInquiry(_ inquiry: ChatInquiry, assignToSitterId: String? = nil) async throws {
        guard let adminId = Auth.auth().currentUser?.uid else {
            throw ChatError.notAuthenticated
        }
        
        let inquiryId = inquiry.id
        
        // Build participant lists
        var participants = [inquiry.fromUserId, adminId]
        var participantRoles = [inquiry.fromUserRole.rawValue, UserRole.admin.rawValue]
        
        // Add sitter if assigned
        if let sitterId = assignToSitterId {
            participants.append(sitterId)
            participantRoles.append(UserRole.petSitter.rawValue)
        }
        
        // Create conversation
        let conversationRef = db.collection("conversations").document()
        let conversationData: [String: Any] = [
            "participants": participants,
            "participantRoles": participantRoles,
            "lastMessage": inquiry.initialMessage,
            "lastMessageAt": FieldValue.serverTimestamp(),
            "status": "active",
            "createdAt": FieldValue.serverTimestamp(),
            "type": ConversationType.adminInquiry.rawValue,
            "isPinned": false,
            "autoResponderSent": false,
            "adminReplied": false,
            "autoResponseHistory": [:],
            "autoResponseCooldown": 86400,
            "unreadCounts": [:],
            "lastReadTimestamps": [:]
        ]
        
        try await conversationRef.setData(conversationData)
        
        // Attach message listener for the new conversation
        listenToMessages(conversationId: conversationRef.documentID)
        
        // Update inquiry
        try await db.collection("inquiries").document(inquiryId).updateData([
            "status": "accepted",
            "conversationId": conversationRef.documentID
        ])
        
        // Seed initial message
        let messageRef = conversationRef.collection("messages").document()
        try await messageRef.setData([
            "senderId": inquiry.fromUserId,
            "text": inquiry.initialMessage,
            "timestamp": FieldValue.serverTimestamp(),
            "read": false,
            "status": MessageStatus.sent.rawValue,
            "moderationType": ModerationType.none.rawValue,
            "deliveryStatus": DeliveryStatus.delivered.rawValue,
            "deliveredAt": FieldValue.serverTimestamp(),
            "isAutoResponse": false,
            "reactions": [:],
            "retryCount": 0
        ])
    }
    
    // MARK: - Message Management
    
    /// Send message with unified approval system
    func sendMessageSmart(conversationId: String, text: String) async throws {
        try await resilientService.sendMessageSmart(conversationId: conversationId, text: text)
    }
    
    /// Send message directly (no approval needed)
    func sendMessage(conversationId: String, text: String) async throws {
        try await resilientService.sendMessage(
            conversationId: conversationId,
            text: text,
            moderationType: .none
        )
    }
    
    /// Send message that requires approval
    func sendMessageForApproval(conversationId: String, text: String) async throws {
        try await resilientService.sendMessage(
            conversationId: conversationId,
            text: text,
            moderationType: .admin
        )
    }
    
    // MARK: - Message Approval System (Unified)
    
    /// Approve a pending message
    func approveMessage(messageId: String, conversationId: String) async throws {
        try await resilientService.approveMessage(messageId: messageId, conversationId: conversationId)
        
        // Send approval notification
        notificationManager.sendApprovalNotification(
            messageId: messageId,
            status: .sent
        )
    }
    
    /// Reject a pending message
    func rejectMessage(messageId: String, conversationId: String, reason: String) async throws {
        try await resilientService.rejectMessage(messageId: messageId, conversationId: conversationId, reason: reason)
        
        // Send rejection notification
        notificationManager.sendApprovalNotification(
            messageId: messageId,
            status: .rejected,
            reason: reason
        )
    }
    
    /// Get messages pending approval (admin only)
    func getPendingMessagesForApproval() -> [ChatMessage] {
        return pendingMessages
    }
    
    /// Legacy method for backward compatibility
    func getPendingMessagesForAdmin() -> [ChatMessage] {
        return getPendingMessagesForApproval()
    }
    
    // MARK: - Listener Management
    
    func listenToMessages(conversationId: String) {
        AppLogger.chat.info("Attaching message listener for conversation: \(conversationId)")
        listenerManager.attachMessagesListener(for: conversationId)
            .sink { messages in
                AppLogger.chat.debug("Received \(messages.count) messages for conversation \(conversationId)")
            }
            .store(in: &cancellables)
    }
    
    func listenToMyConversations() {
        if let userId = Auth.auth().currentUser?.uid {
            listenerManager.attachConversationListener(for: userId)
        }
    }
    
    func listenToAdminInquiries() {
        if isAdmin() {
            listenerManager.attachInquiriesListener()
        }
    }
    
    // MARK: - Display Name Management
    
    func displayName(for uid: String) -> String {
        return listenerManager.displayName(for: uid)
    }
    
    func roleFor(userId: String, in convo: Conversation) -> UserRole? {
        return convo.roleFor(userId)
    }
    
    // MARK: - Auto-Response System
    
    func sendAutoResponse(conversationId: String) async throws {
        try await resilientService.sendAutoResponse(conversationId: conversationId)
        notificationManager.sendAutoReplyNotification()
    }
    
    // MARK: - Utility Methods
    
    private func isAdmin() -> Bool {
        return getCurrentUserRole() == .admin
    }
    
    /// Set the current user's role (called from AppState)
    func setCurrentUserRole(_ role: UserRole) {
        AppLogger.chat.info("Setting currentUserRole to: \(role.rawValue)")
        currentUserRole = role
    }
    
    private func getCurrentUserRole() -> UserRole {
        AppLogger.chat.debug("getCurrentUserRole returning: \(self.currentUserRole.rawValue)")
        return self.currentUserRole
    }
    
    // MARK: - Legacy Compatibility Methods
    
    /// Legacy method for backward compatibility
    func createInquiry(subject: String, initialMessage: String, userRole: UserRole) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw ChatError.notAuthenticated
        }
        
        let data: [String: Any] = [
            "fromUserId": currentUser.uid,
            "fromUserRole": userRole.rawValue,
            "toUserId": "admin",
            "subject": subject,
            "initialMessage": initialMessage,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        let ref = db.collection("inquiries").document()
        try await ref.setData(data)
    }
    
    /// Legacy method for backward compatibility
    func markAdminReplied(conversationId: String) async throws {
        try await db.collection("conversations").document(conversationId).updateData([
            "adminReplied": true
        ])
    }
}

// MARK: - Migration Helper

extension UnifiedChatService {
    
    /// Migrate existing pendingMessages collection to message-level status
    func migratePendingMessages() async throws {
        AppLogger.data.info("Starting migration of pendingMessages collection")
        
        // Get all pending messages from the old collection
        let pendingMessagesSnapshot = try await db.collection("pendingMessages")
            .whereField("status", isEqualTo: "pending_approval")
            .getDocuments()
        
        for document in pendingMessagesSnapshot.documents {
            let data = document.data()
            
            guard let content = data["content"] as? String,
                  let senderId = data["senderId"] as? String,
                  let recipientName = data["recipientName"] as? String else {
                continue
            }
            
            // Create a conversation between sitter and client
            let conversationId = try await createOrGetSitterClientConversation(
                senderId: senderId,
                recipientName: recipientName
            )
            
            // Create message with pending status
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document()
            
            try await messageRef.setData([
                "senderId": senderId,
                "text": content,
                "timestamp": FieldValue.serverTimestamp(),
                "read": false,
                "status": MessageStatus.pending.rawValue,
                "moderationType": ModerationType.admin.rawValue,
                "deliveryStatus": DeliveryStatus.sending.rawValue,
                "isAutoResponse": false,
                "reactions": [:],
                "retryCount": 0
            ])
            
            // Delete from old collection
            try await document.reference.delete()
        }
        
        AppLogger.data.info("Migration completed successfully")
    }
    
    private func createOrGetSitterClientConversation(senderId: String, recipientName: String) async throws -> String {
        // For now, create a simple conversation ID
        // In a real implementation, you'd look up the actual client ID
        let conversationId = "sitter_\(senderId)_client"
        
        let conversationRef = db.collection("conversations").document(conversationId)
        
        // Check if conversation already exists
        let conversationDoc = try await conversationRef.getDocument()
        
        if !conversationDoc.exists {
            // Create new conversation
            try await conversationRef.setData([
                "participants": [senderId], // Add client ID when available
                "participantRoles": [UserRole.petSitter.rawValue], // Add client role when available
                "type": ConversationType.sitterToClient.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "lastMessage": "",
                "lastMessageAt": FieldValue.serverTimestamp(),
                "status": "active",
                "isPinned": false,
                "autoResponderSent": false,
                "adminReplied": false,
                "autoResponseHistory": [:],
                "autoResponseCooldown": 86400,
                "unreadCounts": [:],
                "lastReadTimestamps": [:]
            ])
        }
        
        return conversationId
    }
    
    // MARK: - Cleanup Duplicate Conversations
    
    /// Public method to clean up all duplicate conversations in the system
    func cleanupAllDuplicateConversations() async throws {
        AppLogger.chat.info("Starting cleanup of all duplicate conversations")
        
        let allConversations = try await db.collection("conversations")
            .whereField("type", isEqualTo: ConversationType.adminInquiry.rawValue)
            .whereField("isPinned", isEqualTo: true)
            .getDocuments()
        
        // Group conversations by participant pairs
        var conversationGroups: [String: [QueryDocumentSnapshot]] = [:]
        
        for doc in allConversations.documents {
            let data = doc.data()
            if let participants = data["participants"] as? [String],
               participants.count == 2 {
                let sortedParticipants = participants.sorted()
                let key = sortedParticipants.joined(separator: "_")
                conversationGroups[key, default: []].append(doc)
            }
        }
        
        // Clean up groups with duplicates
        for (key, conversations) in conversationGroups {
            if conversations.count > 1 {
                AppLogger.chat.warning("Found \(conversations.count) duplicate conversations for participants: \(key)")
                
                // Sort by lastMessageAt to keep the most recent one
                let sortedConversations = conversations.sorted { doc1, doc2 in
                    let data1 = doc1.data()
                    let data2 = doc2.data()
                    let date1 = data1["lastMessageAt"] as? Timestamp
                    let date2 = data2["lastMessageAt"] as? Timestamp
                    return (date1?.dateValue() ?? Date.distantPast) > (date2?.dateValue() ?? Date.distantPast)
                }
                
                // Keep the first (most recent) conversation, delete the rest
                let conversationsToDelete = Array(sortedConversations.dropFirst())
                
                for doc in conversationsToDelete {
                    AppLogger.chat.info("Deleting duplicate conversation: \(doc.documentID)")
                    try await doc.reference.delete()
                }
                
                AppLogger.chat.info("Cleaned up \(conversationsToDelete.count) duplicate conversations for \(key)")
            }
        }
        
        AppLogger.chat.info("Cleanup completed")
    }
    
    /// Clean up duplicate conversations for the same user-admin pair
    private func cleanupDuplicateConversations(for userId: String, adminId: String) async throws {
        AppLogger.chat.info("Cleaning up duplicate conversations for user: \(userId)")
        
        let duplicateQuery = try await db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .whereField("type", isEqualTo: ConversationType.adminInquiry.rawValue)
            .whereField("isPinned", isEqualTo: true)
            .getDocuments()
        
        let duplicateConversations = duplicateQuery.documents.filter { doc in
            let data = doc.data()
            if let participants = data["participants"] as? [String] {
                return participants.contains(adminId) && participants.count == 2
            }
            return false
        }
        
        if duplicateConversations.count > 1 {
            AppLogger.chat.warning("Found \(duplicateConversations.count) duplicate conversations")
            
            // Sort by lastMessageAt to keep the most recent one
            let sortedConversations = duplicateConversations.sorted { doc1, doc2 in
                let data1 = doc1.data()
                let data2 = doc2.data()
                let date1 = data1["lastMessageAt"] as? Timestamp
                let date2 = data2["lastMessageAt"] as? Timestamp
                return (date1?.dateValue() ?? Date.distantPast) > (date2?.dateValue() ?? Date.distantPast)
            }
            
            // Keep the first (most recent) conversation, delete the rest
            let conversationsToDelete = Array(sortedConversations.dropFirst())
            
            for doc in conversationsToDelete {
                AppLogger.chat.info("Deleting duplicate conversation: \(doc.documentID)")
                try await doc.reference.delete()
            }
            
            AppLogger.chat.info("Cleaned up \(conversationsToDelete.count) duplicate conversations")
        }
    }
    
    // MARK: - Delete Conversation
    
    /// Delete a specific conversation and all its messages
    func deleteConversation(_ conversationId: String) async throws {
        AppLogger.chat.info("Deleting conversation: \(conversationId)")
        
        let conversationRef = db.collection("conversations").document(conversationId)
        
        // First, delete all messages in the conversation
        let messagesQuery = try await conversationRef.collection("messages").getDocuments()
        
        for messageDoc in messagesQuery.documents {
            try await messageDoc.reference.delete()
        }
        
        // Delete any typing indicators
        let typingQuery = try await conversationRef.collection("typing").getDocuments()
        
        for typingDoc in typingQuery.documents {
            try await typingDoc.reference.delete()
        }
        
        // Finally, delete the conversation itself
        try await conversationRef.delete()
        
        AppLogger.chat.info("Successfully deleted conversation: \(conversationId)")
    }
}

// MARK: - Error Extensions


