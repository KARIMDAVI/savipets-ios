import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

/// Centralized manager for all Firestore listeners to prevent duplicates and memory leaks
final class MessageListenerManager: ObservableObject {
    static let shared = MessageListenerManager()
    
    // MARK: - Published Properties
    @Published var conversations: [Conversation] = []
    @Published var messages: [String: [ChatMessage]] = [:]
    @Published var inquiries: [ChatInquiry] = []
    @Published var typingIndicators: [String: TypingIndicator] = [:]
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var activeListeners: [String: ListenerRegistration] = [:]
    private var subscriberCounts: [String: Int] = [:]
    private var userNameCache: [String: String] = [:]
    private var nameListeners: [String: ListenerRegistration] = [:]
    
    // MARK: - Singleton
    private init() {}
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - Public Methods
    
    /// Attach a conversation listener for a specific user
    func attachConversationListener(for userId: String) {
        let listenerKey = "conversations_\(userId)"
        
        // Increment subscriber count
        subscriberCounts[listenerKey, default: 0] += 1
        
        // If listener already exists, don't create another
        if activeListeners[listenerKey] != nil {
            return
        }
        
        DLog.log("MessageListenerManager attach conversations", userId)
        
        let listener = db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DLog.log("Conversation listener error:", error.localizedDescription)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    DLog.log("No conversation documents")
                    return
                }
                
                let allConversations = documents.compactMap { Conversation(from: $0) }
                
                // Deduplicate conversations by participant pairs
                let deduplicatedConversations = self.deduplicateConversations(allConversations)
                    .sorted { $0.lastMessageAt > $1.lastMessageAt }
                
                DispatchQueue.main.async {
                    self.conversations = deduplicatedConversations
                    DLog.log("Updated conversations", deduplicatedConversations.count)
                }
                
                // Prefetch display names for all participants
                let allParticipantIds = Set(deduplicatedConversations.flatMap { $0.participants })
                allParticipantIds.forEach { self.ensureDisplayNameListener(uid: $0) }
            }
        
        activeListeners[listenerKey] = listener
    }
    
    /// Detach a conversation listener for a specific user
    func detachConversationListener(for userId: String) {
        let listenerKey = "conversations_\(userId)"
        
        // Decrement subscriber count
        subscriberCounts[listenerKey, default: 1] -= 1
        
        // Only remove listener if no more subscribers
        if subscriberCounts[listenerKey, default: 0] <= 0 {
            activeListeners[listenerKey]?.remove()
            activeListeners.removeValue(forKey: listenerKey)
            subscriberCounts.removeValue(forKey: listenerKey)
        DLog.log("Detached conversation listener", userId)
        }
    }
    
    /// Attach a messages listener for a specific conversation
    func attachMessagesListener(for conversationId: String) -> AnyPublisher<[ChatMessage], Never> {
        let listenerKey = "messages_\(conversationId)"
        
        // Increment subscriber count
        subscriberCounts[listenerKey, default: 0] += 1
        
        // If listener already exists, return existing publisher
        if activeListeners[listenerKey] != nil {
            return Just(messages[conversationId] ?? [])
                .merge(with: Publishers.MergeMany(
                    messages.compactMap { $0.key == conversationId ? Just($0.value).eraseToAnyPublisher() : nil }
                ))
                .eraseToAnyPublisher()
        }
        
        DLog.log("Attach messages listener", conversationId)
        
        let subject = PassthroughSubject<[ChatMessage], Never>()
        
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DLog.log("Messages listener error:", error.localizedDescription)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    DLog.log("No message documents for", conversationId)
                    return
                }
                
                let messages = documents.compactMap { ChatMessage(from: $0) }
                
                DispatchQueue.main.async {
                    self.messages[conversationId] = messages
                    subject.send(messages)
                    DLog.log("Updated messages for", conversationId, messages.count)
                }
                
                // Prefetch display names for senders
                let senderIds = Set(messages.map { $0.senderId })
                senderIds.forEach { self.ensureDisplayNameListener(uid: $0) }
            }
        
        activeListeners[listenerKey] = listener
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Detach a messages listener for a specific conversation
    func detachMessagesListener(for conversationId: String) {
        let listenerKey = "messages_\(conversationId)"
        
        // Decrement subscriber count
        subscriberCounts[listenerKey, default: 1] -= 1
        
        // Only remove listener if no more subscribers
        if subscriberCounts[listenerKey, default: 0] <= 0 {
            activeListeners[listenerKey]?.remove()
            activeListeners.removeValue(forKey: listenerKey)
            subscriberCounts.removeValue(forKey: listenerKey)
        DLog.log("Detached messages listener", conversationId)
        }
    }
    
    /// Attach an inquiries listener for admin users
    func attachInquiriesListener() {
        let listenerKey = "inquiries"
        
        // Increment subscriber count
        subscriberCounts[listenerKey, default: 0] += 1
        
        // If listener already exists, don't create another
        if activeListeners[listenerKey] != nil {
            return
        }
        
        DLog.log("Attach inquiries listener")
        
        let listener = db.collection("inquiries")
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DLog.log("Inquiries listener error:", error.localizedDescription)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    DLog.log("No inquiry documents")
                    return
                }
                
                let inquiries: [ChatInquiry] = documents.compactMap { document -> ChatInquiry? in
                    let documentData = document.data()
                    guard let fromUserId = documentData["fromUserId"] as? String,
                          let fromUserRoleString = documentData["fromUserRole"] as? String,
                          let fromUserRole = UserRole(rawValue: fromUserRoleString),
                          let toUserId = documentData["toUserId"] as? String,
                          let subject = documentData["subject"] as? String,
                          let initialMessage = documentData["initialMessage"] as? String,
                          let status = documentData["status"] as? String else {
                        return nil
                    }
                    
                    let createdAtDate: Date
                    if let timestamp = documentData["createdAt"] as? Timestamp {
                        createdAtDate = timestamp.dateValue()
                    } else if let date = documentData["createdAt"] as? Date {
                        createdAtDate = date
                    } else {
                        createdAtDate = Date()
                    }
                    
                    return ChatInquiry(
                        id: document.documentID,
                        fromUserId: fromUserId,
                        fromUserRole: fromUserRole,
                        toUserId: toUserId,
                        subject: subject,
                        initialMessage: initialMessage,
                        status: status,
                        createdAt: createdAtDate,
                        conversationId: documentData["conversationId"] as? String
                    )
                }
                
                DispatchQueue.main.async {
                    self.inquiries = inquiries
                    DLog.log("Updated inquiries", inquiries.count)
                }
            }
        
        activeListeners[listenerKey] = listener
    }
    
    /// Detach inquiries listener
    func detachInquiriesListener() {
        let listenerKey = "inquiries"
        
        // Decrement subscriber count
        subscriberCounts[listenerKey, default: 1] -= 1
        
        // Only remove listener if no more subscribers
        if subscriberCounts[listenerKey, default: 0] <= 0 {
            activeListeners[listenerKey]?.remove()
            activeListeners.removeValue(forKey: listenerKey)
            subscriberCounts.removeValue(forKey: listenerKey)
        DLog.log("Detached inquiries listener")
        }
    }
    
    /// Attach typing indicator listener for a conversation
    func attachTypingIndicatorListener(for conversationId: String) {
        let listenerKey = "typing_\(conversationId)"
        
        // Increment subscriber count
        subscriberCounts[listenerKey, default: 0] += 1
        
        // If listener already exists, don't create another
        if activeListeners[listenerKey] != nil {
            return
        }
        
        DLog.log("Attach typing indicator listener", conversationId)
        
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("typing")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DLog.log("Typing indicator listener error:", error.localizedDescription)
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                var indicators: [String: TypingIndicator] = [:]
                
                for document in documents {
                    let data = document.data()
                    guard let userId = data["userId"] as? String,
                          let isTyping = data["isTyping"] as? Bool else { continue }
                    
                    let timestamp: Date
                    if let timestampData = data["timestamp"] as? Timestamp {
                        timestamp = timestampData.dateValue()
                    } else if let date = data["timestamp"] as? Date {
                        timestamp = date
                    } else {
                        timestamp = Date()
                    }
                    
                    indicators[userId] = TypingIndicator(
                        userId: userId,
                        isTyping: isTyping,
                        timestamp: timestamp
                    )
                }
                
                DispatchQueue.main.async {
                    self.typingIndicators = indicators
                }
            }
        
        activeListeners[listenerKey] = listener
    }
    
    /// Detach typing indicator listener for a conversation
    func detachTypingIndicatorListener(for conversationId: String) {
        let listenerKey = "typing_\(conversationId)"
        
        // Decrement subscriber count
        subscriberCounts[listenerKey, default: 1] -= 1
        
        // Only remove listener if no more subscribers
        if subscriberCounts[listenerKey, default: 0] <= 0 {
            activeListeners[listenerKey]?.remove()
            activeListeners.removeValue(forKey: listenerKey)
            subscriberCounts.removeValue(forKey: listenerKey)
        DLog.log("Detached typing indicator listener", conversationId)
        }
    }
    
    /// Remove all active listeners
    func removeAllListeners() {
        DLog.log("Removing all listeners", activeListeners.count)
        
        for (listenerKey, listener) in activeListeners {
            listener.remove()
            DLog.log("Removed listener", listenerKey)
        }
        
        activeListeners.removeAll()
        subscriberCounts.removeAll()
        
        // Also remove name listeners
        for (nameListenerKey, listener) in nameListeners {
            listener.remove()
        }
        nameListeners.removeAll()
    }
    
    /// Get current subscriber counts (for debugging)
    func getSubscriberCounts() -> [String: Int] {
        return subscriberCounts
    }
    
    /// Get active listener keys (for debugging)
    func getActiveListeners() -> [String] {
        return Array(activeListeners.keys)
    }
    
    // MARK: - Display Name Management
    
    func displayName(for uid: String) -> String {
        if let name = userNameCache[uid] { return name }
        ensureDisplayNameListener(uid: uid)
        // Better fallback - try to extract from UID or use a more friendly default
        return "User \(String(uid.prefix(8)))"
    }
    
    private func ensureDisplayNameListener(uid: String) {
        if nameListeners[uid] != nil { return }
        
        // Prefer publicProfiles (world readable), fallback to users doc
        let publicRef = db.collection("publicProfiles").document(uid)
        let listener = publicRef.addSnapshotListener { [weak self] doc, _ in
            guard let self = self else { return }
            if let data = doc?.data(), let name = data["displayName"] as? String, !name.isEmpty {
                DispatchQueue.main.async { self.userNameCache[uid] = name }
                return
            }
        }
        nameListeners[uid] = listener
        
        // Also attempt one-time fetch from users as fallback if public missing
        db.collection("users").document(uid).getDocument { [weak self] doc, _ in
            guard let self = self else { return }
            if let data = doc?.data() {
                var name: String? = nil
                
                // Try different name fields in order of preference
                if let displayName = data["displayName"] as? String, !displayName.isEmpty {
                    name = displayName
                } else if let fullName = data["name"] as? String, !fullName.isEmpty {
                    name = fullName
                } else if let email = data["email"] as? String, !email.isEmpty {
                    // Extract name from email if no name is provided
                    let emailName = String(email.split(separator: "@").first ?? "")
                    name = emailName.isEmpty ? nil : emailName
                }
                
                if let finalName = name {
                    DispatchQueue.main.async { self.userNameCache[uid] = finalName }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func getMessages(for conversationId: String) -> [ChatMessage] {
        return messages[conversationId] ?? []
    }
    
    func getConversation(by id: String) -> Conversation? {
        return conversations.first { $0.id == id }
    }
    
    func getInquiry(by id: String) -> ChatInquiry? {
        return inquiries.first { $0.id == id }
    }
    
    func getTypingIndicator(for userId: String, in conversationId: String) -> TypingIndicator? {
        return typingIndicators[userId]
    }
    
    func isUserTyping(_ userId: String, in conversationId: String) -> Bool {
        guard let indicator = getTypingIndicator(for: userId, in: conversationId) else { return false }
        
        // Consider typing if it's been within the last 3 seconds
        return indicator.isTyping && Date().timeIntervalSince(indicator.timestamp) < 3.0
    }
    
    // MARK: - Deduplication Methods
    
    /// Deduplicate conversations by participant pairs, keeping the most recent one
    private func deduplicateConversations(_ conversations: [Conversation]) -> [Conversation] {
        var conversationGroups: [String: [Conversation]] = [:]
        
        // Group conversations by participant pairs
        for conversation in conversations {
            let sortedParticipants = conversation.participants.sorted()
            let key = sortedParticipants.joined(separator: "_")
            conversationGroups[key, default: []].append(conversation)
        }
        
        // Keep only the most recent conversation from each group
        var deduplicated: [Conversation] = []
        for (_, group) in conversationGroups {
            if let mostRecent = group.max(by: { $0.lastMessageAt < $1.lastMessageAt }) {
                deduplicated.append(mostRecent)
            }
        }
        
        return deduplicated
    }
}
