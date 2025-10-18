import Foundation
import OSLog
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Enhanced chat service with robust error handling, retry logic, and offline support
final class ResilientChatService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isOnline: Bool = true
    @Published var pendingMessages: [OfflineMessage] = []
    @Published var retryQueue: [RetryQueueItem] = []
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let listenerManager = MessageListenerManager.shared
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 2.0
    private let maxRetryDelay: TimeInterval = 30.0
    private let offlineQueue = "offline_messages"
    private let retryQueueKey = "retry_operations"
    private var networkObserver: NSObjectProtocol?
    
    // MARK: - Singleton
    static let shared = ResilientChatService()
    
    private init() {
        loadOfflineMessages()
        loadRetryQueue()
        startNetworkMonitoring()
    }
    
    deinit {
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        // Monitor network connectivity
        networkObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NetworkStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isOnline = notification.userInfo?["isOnline"] as? Bool {
                self?.isOnline = isOnline
                if isOnline {
                    Task {
                        await self?.processOfflineQueue()
                        await self?.processRetryQueue()
                    }
                }
            }
        }
    }
    
    // MARK: - Message Sending with Retry Logic
    
    func sendMessage(
        conversationId: String,
        text: String,
        moderationType: ModerationType = .none,
        retryCount: Int = 0
    ) async throws {
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatError.emptyMessage
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            throw ChatError.notAuthenticated
        }
        
        // Create message with initial status
        let messageId = UUID().uuidString
        let messageData: [String: Any] = [
            "senderId": currentUser.uid,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "read": false,
            "status": MessageStatus.sending.rawValue,
            "moderationType": moderationType.rawValue,
            "deliveryStatus": DeliveryStatus.sending.rawValue,
            "isAutoResponse": false,
            "retryCount": retryCount,
            "failureReason": NSNull()
        ]
        
        do {
            if isOnline {
                try await sendMessageOnline(conversationId: conversationId, messageData: messageData, messageId: messageId)
            } else {
                try? await saveMessageOffline(conversationId: conversationId, text: text, moderationType: moderationType)
            }
        } catch {
            if isRetryableError(error) && retryCount < maxRetries {
                await scheduleRetry(
                    operation: .sendMessage(conversationId: conversationId, text: text, moderationType: moderationType),
                    retryCount: retryCount + 1,
                    error: error
                )
            } else {
                // Store in offline queue for later retry
                try? await saveMessageOffline(conversationId: conversationId, text: text, moderationType: moderationType)
                throw ChatError.sendFailed(error)
            }
        }
    }
    
    private func sendMessageOnline(
        conversationId: String,
        messageData: [String: Any],
        messageId: String
    ) async throws {
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        // Use transaction for atomic write
        _ = try await db.runTransaction { transaction, errorPointer in  // Swift 6: unused return value fix
            // Write message
            transaction.setData(messageData, forDocument: messageRef)
            
            // Update conversation
            let conversationRef = self.db.collection("conversations").document(conversationId)
            transaction.updateData([
                "lastMessage": messageData["text"] as? String ?? "",
                "lastMessageAt": FieldValue.serverTimestamp()
            ], forDocument: conversationRef)
            
            return nil
        }
        
        // Update delivery status after successful send
        try await messageRef.updateData([
            "deliveryStatus": DeliveryStatus.delivered.rawValue,
            "deliveredAt": FieldValue.serverTimestamp(),
            "status": MessageStatus.sent.rawValue
        ])
        
        AppLogger.chat.info("Message sent successfully")
    }
    
    // MARK: - Smart Message Sending with Auto-Response
    
    func sendMessageSmart(
        conversationId: String,
        text: String
    ) async throws {
        
        // Get conversation data to determine type and participants
        let conversationDoc = try await db.collection("conversations").document(conversationId).getDocument()
        guard let data = conversationDoc.data(),
              let typeString = data["type"] as? String,
              let type = ConversationType(rawValue: typeString) else {
            throw ChatError.conversationNotFound
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let participants = data["participants"] as? [String],
              let participantRoles = data["participantRoles"] as? [String] else {
            throw ChatError.invalidConversationData
        }
        
        AppLogger.chat.info("sendMessageSmart - conversationId: \(conversationId)")
        AppLogger.chat.info("participants: \(participants)")
        AppLogger.chat.info("participantRoles: \(participantRoles)")
        AppLogger.chat.info("currentUserId: \(currentUserId)")
        
        // Determine moderation type based on conversation type
        let moderationType: ModerationType
        switch type {
        case .adminInquiry:
            moderationType = .none
        case .clientSitter, .sitterToClient:
            // Check if sender is sitter and recipient is client
            let senderIndex = participants.firstIndex(of: currentUserId)
            let senderRole = senderIndex.map { index in
                index < participantRoles.count ? UserRole.from(participantRoles[index]) : nil
            } ?? nil
            let isSitterToClient = senderRole == .petSitter
            moderationType = isSitterToClient ? .admin : .none
        }
        
        // Send message with appropriate moderation
        try await sendMessage(
            conversationId: conversationId,
            text: text,
            moderationType: moderationType
        )
        
        // Handle auto-response for admin inquiries
        if type == .adminInquiry {
            let currentUserIndex = participants.firstIndex(of: currentUserId)
            let currentUserRole = currentUserIndex.map { index in
                index < participantRoles.count ? UserRole.from(participantRoles[index]) : nil
            } ?? nil
            let isPetOwner = currentUserRole == .petOwner
            
            if isPetOwner && !(data["autoResponderSent"] as? Bool ?? false) {
                try? await sendAutoResponse(conversationId: conversationId)
            }
        }
    }
    
    // MARK: - Auto-Response with Per-User Tracking
    
    func sendAutoResponse(conversationId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw ChatError.notAuthenticated
        }
        
        let conversationRef = db.collection("conversations").document(conversationId)
        
        // Check if auto-response already sent for this user
        let conversationDoc = try await conversationRef.getDocument()
        guard let data = conversationDoc.data() else {
            throw ChatError.conversationNotFound
        }
        
        var autoResponseHistory: [String: Date] = [:]
        if let historyData = data["autoResponseHistory"] as? [String: Timestamp] {
            for (userId, timestamp) in historyData {
                autoResponseHistory[userId] = timestamp.dateValue()
            }
        }
        
        // Check if should send auto-response for this user
        let shouldSend = autoResponseHistory[currentUserId] == nil ||
                        Date().timeIntervalSince(autoResponseHistory[currentUserId]!) > 86400 // 24 hours
        
        guard shouldSend else {
            AppLogger.chat.info("Auto-response already sent recently for user: \(currentUserId)")
            return
        }
        
        // Send auto-response message
        let autoResponseText = "We'll be in touch ASAP"
        let messageId = UUID().uuidString
        
        let messageData: [String: Any] = [
            "senderId": "system",
            "text": autoResponseText,
            "timestamp": FieldValue.serverTimestamp(),
            "read": false,
            "status": MessageStatus.sent.rawValue,
            "moderationType": ModerationType.auto.rawValue,
            "deliveryStatus": DeliveryStatus.delivered.rawValue,
            "isAutoResponse": true
        ]
        
        _ = try await db.runTransaction { transaction, errorPointer in  // Swift 6: unused return value fix
            // Add auto-response message
            let messageRef = conversationRef.collection("messages").document(messageId)
            transaction.setData(messageData, forDocument: messageRef)
            
            // Update conversation metadata
            var updatedHistory = autoResponseHistory
            updatedHistory[currentUserId] = Date()
            
            let historyData = updatedHistory.mapValues { Timestamp(date: $0) }
            
            transaction.updateData([
                "lastMessage": autoResponseText,
                "lastMessageAt": FieldValue.serverTimestamp(),
                "autoResponseHistory": historyData
            ], forDocument: conversationRef)
            
            return nil
        }
        
        AppLogger.chat.info("Auto-response sent successfully")
    }
    
    // MARK: - Message Approval System
    
    func approveMessage(messageId: String, conversationId: String) async throws {
        guard let adminId = Auth.auth().currentUser?.uid else {
            throw ChatError.notAuthenticated
        }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        try await messageRef.updateData([
            "status": MessageStatus.sent.rawValue,
            "moderationType": ModerationType.admin.rawValue,
            "moderatedBy": adminId,
            "moderatedAt": FieldValue.serverTimestamp(),
            "deliveryStatus": DeliveryStatus.delivered.rawValue,
            "deliveredAt": FieldValue.serverTimestamp()
        ])
        
        // Update conversation with approved message
        let conversationRef = db.collection("conversations").document(conversationId)
        let messageDoc = try await messageRef.getDocument()
        if let messageData = messageDoc.data(),
           let messageText = messageData["text"] as? String {
            try await conversationRef.updateData([
                "lastMessage": messageText,
                "lastMessageAt": FieldValue.serverTimestamp()
            ])
        }
        
        AppLogger.chat.info("Message approved successfully")
    }
    
    func rejectMessage(messageId: String, conversationId: String, reason: String) async throws {
        guard let adminId = Auth.auth().currentUser?.uid else {
            throw ChatError.notAuthenticated
        }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        try await messageRef.updateData([
            "status": MessageStatus.rejected.rawValue,
            "moderationType": ModerationType.admin.rawValue,
            "moderatedBy": adminId,
            "moderatedAt": FieldValue.serverTimestamp(),
            "failureReason": reason
        ])
        
        AppLogger.chat.info("Message rejected successfully")
    }
    
    // MARK: - Offline Support
    
    private func saveMessageOffline(
        conversationId: String,
        text: String,
        moderationType: ModerationType
    ) async throws {
        let offlineMessage = OfflineMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            text: text,
            moderationType: moderationType,
            createdAt: Date()
        )
        
        await MainActor.run {
            pendingMessages.append(offlineMessage)
        }
        
        saveOfflineMessages()
        AppLogger.chat.info("Message saved offline")
    }
    
    private func processOfflineQueue() async {
        guard isOnline else { return }
        
        let messagesToProcess = pendingMessages
        pendingMessages.removeAll()
        
        for message in messagesToProcess {
            do {
                try await sendMessage(
                    conversationId: message.conversationId,
                    text: message.text,
                    moderationType: message.moderationType
                )
            } catch {
                // Re-add to pending if still failing
                await MainActor.run {
                    pendingMessages.append(message)
                }
            }
        }
        
        saveOfflineMessages()
    }
    
    // MARK: - Retry Queue Management
    
    private func scheduleRetry(
        operation: RetryableOperation,
        retryCount: Int,
        error: Error
    ) async {
        let retryDelay = min(baseRetryDelay * pow(2.0, Double(retryCount)), maxRetryDelay)
        
        let retryOperation = RetryQueueItem(
            id: UUID().uuidString,
            operation: operation,
            retryCount: retryCount,
            scheduledAt: Date().addingTimeInterval(retryDelay),
            lastError: error.localizedDescription
        )
        
        await MainActor.run {
            retryQueue.append(retryOperation)
        }
        
        saveRetryQueue()
        
        // Schedule retry
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
            Task {
                await self.processRetry(retryOperation)
            }
        }
    }
    
    private func processRetry(_ retryOperation: RetryQueueItem) async {
        do {
            switch retryOperation.operation {
            case .sendMessage(let conversationId, let text, let moderationType):
                try await sendMessage(
                    conversationId: conversationId,
                    text: text,
                    moderationType: moderationType,
                    retryCount: retryOperation.retryCount
                )
                
                // Remove from retry queue on success
                await MainActor.run {
                    retryQueue.removeAll { $0.id == retryOperation.id }
                }
                
            }
        } catch {
            if isRetryableError(error) && retryOperation.retryCount < maxRetries {
                await scheduleRetry(
                    operation: retryOperation.operation,
                    retryCount: retryOperation.retryCount + 1,
                    error: error
                )
            }
            
            // Remove from retry queue if max retries exceeded
            await MainActor.run {
                retryQueue.removeAll { $0.id == retryOperation.id }
            }
        }
        
        saveRetryQueue()
    }
    
    private func processRetryQueue() async {
        let currentTime = Date()
        let operationsToRetry = retryQueue.filter { $0.scheduledAt <= currentTime }
        
        for operation in operationsToRetry {
            await processRetry(operation)
        }
    }
    
    // MARK: - Error Classification
    
    private func isRetryableError(_ error: Error) -> Bool {
        let firestoreError = error as NSError  // Swift 6: conditional cast always succeeds, removed 'if let'
        if true {
            switch firestoreError.code {
            case 14: // UNAVAILABLE
                return true
            case 8:  // RESOURCE_EXHAUSTED
                return true
            case 13: // INTERNAL
                return true
            case 4:  // DEADLINE_EXCEEDED
                return true
            default:
                return false
            }
        }
        
        // Network errors are retryable
        return error.localizedDescription.contains("network") ||
               error.localizedDescription.contains("timeout") ||
               error.localizedDescription.contains("connection")
    }
    
    // MARK: - Persistence
    
    private func saveOfflineMessages() {
        if let data = try? JSONEncoder().encode(pendingMessages) {
            UserDefaults.standard.set(data, forKey: offlineQueue)
        }
    }
    
    private func loadOfflineMessages() {
        if let data = UserDefaults.standard.data(forKey: offlineQueue),
           let messages = try? JSONDecoder().decode([OfflineMessage].self, from: data) {
            pendingMessages = messages
        }
    }
    
    private func saveRetryQueue() {
        if let data = try? JSONEncoder().encode(retryQueue) {
            UserDefaults.standard.set(data, forKey: retryQueueKey)
        }
    }
    
    private func loadRetryQueue() {
        if let data = UserDefaults.standard.data(forKey: retryQueueKey),
           let operations = try? JSONDecoder().decode([RetryQueueItem].self, from: data) {
            retryQueue = operations
        }
    }
}

// MARK: - Supporting Types

enum ChatError: LocalizedError {
    case notAuthenticated
    case conversationNotFound
    case invalidConversationData
    case emptyMessage
    case sendFailed(Error)
    case adminNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .conversationNotFound:
            return "Conversation not found"
        case .invalidConversationData:
            return "Invalid conversation data"
        case .emptyMessage:
            return "Message cannot be empty"
        case .sendFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .adminNotFound:
            return "Admin user not found"
        }
    }
}

struct OfflineMessage: Codable {
    let id: String
    let conversationId: String
    let text: String
    let moderationType: ModerationType
    let createdAt: Date
}

enum RetryableOperation: Codable {
    case sendMessage(conversationId: String, text: String, moderationType: ModerationType)
    
    enum CodingKeys: String, CodingKey {
        case type, conversationId, text, moderationType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "sendMessage":
            let conversationId = try container.decode(String.self, forKey: .conversationId)
            let text = try container.decode(String.self, forKey: .text)
            let moderationType = try container.decode(ModerationType.self, forKey: .moderationType)
            self = .sendMessage(conversationId: conversationId, text: text, moderationType: moderationType)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown operation type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .sendMessage(let conversationId, let text, let moderationType):
            try container.encode("sendMessage", forKey: .type)
            try container.encode(conversationId, forKey: .conversationId)
            try container.encode(text, forKey: .text)
            try container.encode(moderationType, forKey: .moderationType)
        }
    }
}

struct RetryQueueItem: Codable {
    let id: String
    let operation: RetryableOperation
    let retryCount: Int
    let scheduledAt: Date
    let lastError: String
}
