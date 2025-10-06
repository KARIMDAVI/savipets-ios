import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Legacy ChatService (Deprecated - Use UnifiedChatService)
// This class is kept for backward compatibility but delegates to UnifiedChatService

final class ChatService: ObservableObject {
    // Delegate to unified service
    private let unifiedService = UnifiedChatService.shared
    
    // MARK: - Published Properties (delegated)
    @Published private(set) var inquiries: [ChatInquiry] = []
    
    @Published private(set) var conversations: [Conversation] = []
    
    @Published private(set) var messages: [String: [ChatMessage]] = [:]
    
    // MARK: - Initialization
    init() {
        // Subscribe to unified service updates
        unifiedService.$inquiries
            .receive(on: DispatchQueue.main)
            .assign(to: \.inquiries, on: self)
            .store(in: &cancellables)
        
        unifiedService.$conversations
            .receive(on: DispatchQueue.main)
            .assign(to: \.conversations, on: self)
            .store(in: &cancellables)
        
        unifiedService.$messages
            .receive(on: DispatchQueue.main)
            .assign(to: \.messages, on: self)
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Inquiries (Delegated)

    func createInquiry(subject: String, initialMessage: String, userRole: UserRole) async throws {
        try await unifiedService.createInquiry(subject: subject, initialMessage: initialMessage, userRole: userRole)
    }

    func listenToAdminInquiries() {
        unifiedService.listenToAdminInquiries()
    }

    // MARK: - Conversations (Delegated)

    func listenToMyConversations() {
        unifiedService.listenToMyConversations()
    }

    func acceptInquiry(_ inquiry: ChatInquiry, assignToSitterId: String? = nil) async throws {
        try await unifiedService.acceptInquiry(inquiry, assignToSitterId: assignToSitterId)
    }
    
    // MARK: - All Other Methods (Delegated)
    
    func listenToMessages(conversationId: String) {
        unifiedService.listenToMessages(conversationId: conversationId)
    }
    
    func sendMessage(conversationId: String, text: String) async throws {
        try await unifiedService.sendMessage(conversationId: conversationId, text: text)
    }
    
    func sendMessageSmart(conversationId: String, text: String) async throws {
        try await unifiedService.sendMessageSmart(conversationId: conversationId, text: text)
    }
    
    func getOrCreateAdminInquiryChannel() async throws -> String {
        try await unifiedService.getOrCreateAdminInquiryChannel()
    }
    
    func sendAutoResponse(conversationId: String) async throws {
        try await unifiedService.sendAutoResponse(conversationId: conversationId)
    }
    
    func markAdminReplied(conversationId: String) async throws {
        try await unifiedService.markAdminReplied(conversationId: conversationId)
    }
    
    func approveMessage(messageId: String, conversationId: String) async throws {
        try await unifiedService.approveMessage(messageId: messageId, conversationId: conversationId)
    }
    
    func rejectMessage(messageId: String, conversationId: String, reason: String) async throws {
        try await unifiedService.rejectMessage(messageId: messageId, conversationId: conversationId, reason: reason)
    }
    
    func displayName(for uid: String) -> String {
        unifiedService.displayName(for: uid)
    }
    
    func roleFor(userId: String, in convo: Conversation) -> UserRole? {
        unifiedService.roleFor(userId: userId, in: convo)
    }
    
    func getPendingMessagesForAdmin() -> [ChatMessage] {
        unifiedService.getPendingMessagesForAdmin()
    }
    
    func setCurrentUserRole(_ role: UserRole) {
        print("🔵 ChatService: Setting user role to: \(role.rawValue)")
        unifiedService.setCurrentUserRole(role)
    }
    
    func cleanupDuplicateConversations() async throws {
        try await unifiedService.cleanupAllDuplicateConversations()
    }
}

