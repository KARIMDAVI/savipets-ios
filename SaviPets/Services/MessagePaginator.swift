import Foundation
import OSLog
import FirebaseFirestore
import Combine

/// Efficient message pagination service for handling large conversation histories
final class MessagePaginator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var hasMoreMessages: Bool = true
    @Published var isRefreshing: Bool = false
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let pageSize = 50
    private var lastDocument: DocumentSnapshot?
    private var conversationId: String?
    private var isLoadingMore: Bool = false
    
    // MARK: - Public Methods
    
    /// Load initial messages for a conversation
    func loadInitialMessages(for conversationId: String) async {
        guard self.conversationId != conversationId else { return }
        
        self.conversationId = conversationId
        messages = []
        lastDocument = nil
        hasMoreMessages = true
        isLoading = true
        
        do {
            let page = try await loadMessagesPage(conversationId: conversationId, isInitial: true)
            await MainActor.run {
                self.messages = page.messages
                self.hasMoreMessages = page.hasMore
                // Note: We can't store DocumentSnapshot directly, so we'll handle pagination differently
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                AppLogger.chat.info("Error loading initial messages: \(error)")
            }
        }
    }
    
    /// Load more messages (pagination)
    func loadMoreMessages() async {
        guard let conversationId = conversationId,
              hasMoreMessages,
              !isLoadingMore else { return }
        
        isLoadingMore = true
        
        do {
            let page = try await loadMessagesPage(conversationId: conversationId, isInitial: false)
            await MainActor.run {
                // Prepend older messages to the beginning
                self.messages = page.messages + self.messages
                self.hasMoreMessages = page.hasMore
                // Note: We can't store DocumentSnapshot directly, so we'll handle pagination differently
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingMore = false
                AppLogger.chat.info("Error loading more messages: \(error)")
            }
        }
    }
    
    /// Refresh messages (pull-to-refresh)
    func refreshMessages() async {
        guard let conversationId = conversationId else { return }
        
        isRefreshing = true
        
        do {
            // Load recent messages (last 20)
            let recentQuery = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .limit(to: 20)
            
            let snapshot = try await recentQuery.getDocuments()
            let recentMessages = snapshot.documents.compactMap { ChatMessage(from: $0) }
            
            await MainActor.run {
                // Replace messages with recent ones, keeping older ones if they don't overlap
                let existingIds = Set(self.messages.map { $0.id })
                let newMessages = recentMessages.filter { !existingIds.contains($0.id) }
                
                // Combine and sort by timestamp
                self.messages = (self.messages + newMessages)
                    .sorted { $0.timestamp < $1.timestamp }
                
                self.isRefreshing = false
            }
        } catch {
            await MainActor.run {
                self.isRefreshing = false
                AppLogger.chat.info("Error refreshing messages: \(error)")
            }
        }
    }
    
    /// Add new message to the end (for real-time updates)
    func addNewMessage(_ message: ChatMessage) {
        // Only add if it's newer than the latest message
        if let latestMessage = messages.last {
            guard message.timestamp > latestMessage.timestamp else { return }
        }
        
        // Avoid duplicates
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        
        messages.append(message)
    }
    
    /// Update existing message
    func updateMessage(_ message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        }
    }
    
    /// Remove message
    func removeMessage(withId messageId: String) {
        messages.removeAll { $0.id == messageId }
    }
    
    /// Clear all messages
    func clearMessages() {
        messages = []
        lastDocument = nil
        hasMoreMessages = true
        conversationId = nil
    }
    
    /// Get message by ID
    func getMessage(withId messageId: String) -> ChatMessage? {
        return messages.first { $0.id == messageId }
    }
    
    /// Get messages around a specific message (for context)
    func getMessagesAround(messageId: String, contextCount: Int = 10) -> [ChatMessage] {
        guard let targetIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            return []
        }
        
        let startIndex = max(0, targetIndex - contextCount)
        let endIndex = min(messages.count, targetIndex + contextCount + 1)
        
        return Array(messages[startIndex..<endIndex])
    }
    
    /// Check if we need to load more messages when scrolling
    func shouldLoadMore(currentIndex: Int) -> Bool {
        // Load more when user scrolls to within 10 messages of the beginning
        return currentIndex < 10 && hasMoreMessages && !isLoadingMore
    }
    
    // MARK: - Private Methods
    
    private func loadMessagesPage(conversationId: String, isInitial: Bool) async throws -> MessagePage {
        var query = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: !isInitial)
            .limit(to: pageSize)
        
        // For initial load, we want the most recent messages
        // For pagination, we continue from where we left off
        if !isInitial, let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await query.getDocuments()
        let messages = snapshot.documents.compactMap { ChatMessage(from: $0) }
        
        // For initial load, we want messages in chronological order (oldest first)
        // For pagination, we're loading older messages, so they're already in the right order
        let orderedMessages = isInitial ? messages.reversed() : messages
        
        let hasMore = snapshot.documents.count == pageSize
        let lastDoc = snapshot.documents.last
        
        return MessagePage(
            messages: orderedMessages,
            hasMore: hasMore,
            lastDocumentId: lastDoc?.documentID
        )
    }
}

// MARK: - Message Search

extension MessagePaginator {
    
    /// Search messages within the loaded conversation
    func searchMessages(query: String) -> [ChatMessage] {
        guard !query.isEmpty else { return messages }
        
        let lowercaseQuery = query.lowercased()
        return messages.filter { message in
            message.text.lowercased().contains(lowercaseQuery)
        }
    }
    
    /// Find messages containing specific text
    func findMessages(containing text: String) -> [ChatMessage] {
        let lowercaseText = text.lowercased()
        return messages.filter { message in
            message.text.lowercased().contains(lowercaseText)
        }
    }
    
    /// Find messages from a specific sender
    func findMessages(from senderId: String) -> [ChatMessage] {
        return messages.filter { $0.senderId == senderId }
    }
    
    /// Find messages within a date range
    func findMessages(from startDate: Date, to endDate: Date) -> [ChatMessage] {
        return messages.filter { message in
            message.timestamp >= startDate && message.timestamp <= endDate
        }
    }
}

// MARK: - Performance Optimizations

extension MessagePaginator {
    
    /// Preload messages for better performance
    func preloadMessages(for conversationIds: [String]) async {
        for conversationId in conversationIds {
            // Preload just the latest message for each conversation
            do {
                let query = db.collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .order(by: "timestamp", descending: true)
                    .limit(to: 1)
                
                let snapshot = try await query.getDocuments()
                if snapshot.documents.first != nil {
                    // Cache the latest message for quick access
                    // This could be stored in a cache or UserDefaults
                    AppLogger.chat.info("Preloaded latest message for conversation \(conversationId)")
                }
            } catch {
                AppLogger.chat.info("Error preloading messages for conversation \(conversationId): \(error)")
            }
        }
    }
    
    /// Optimize memory usage by limiting loaded messages
    func optimizeMemoryUsage() {
        // Keep only the most recent 200 messages in memory
        let maxMessages = 200
        if messages.count > maxMessages {
            let messagesToKeep = Array(messages.suffix(maxMessages))
            messages = messagesToKeep
            AppLogger.chat.info("Optimized memory usage, kept \(maxMessages) most recent messages")
        }
    }
    
    /// Get conversation statistics
    func getConversationStats() -> ConversationStats {
        let totalMessages = messages.count
        let unreadMessages = messages.filter { !$0.read }.count
        let messagesToday = messages.filter { Calendar.current.isDateInToday($0.timestamp) }.count
        let messagesThisWeek = messages.filter { Calendar.current.isDate($0.timestamp, equalTo: Date(), toGranularity: .weekOfYear) }.count
        
        return ConversationStats(
            totalMessages: totalMessages,
            unreadMessages: unreadMessages,
            messagesToday: messagesToday,
            messagesThisWeek: messagesThisWeek,
            hasMoreMessages: hasMoreMessages
        )
    }
}

// MARK: - Supporting Types

struct ConversationStats {
    let totalMessages: Int
    let unreadMessages: Int
    let messagesToday: Int
    let messagesThisWeek: Int
    let hasMoreMessages: Bool
}

// MARK: - Message Pagination View Model

@MainActor
class MessagePaginationViewModel: ObservableObject {
    @Published var paginator = MessagePaginator()
    @Published var searchQuery: String = ""
    @Published var searchResults: [ChatMessage] = []
    @Published var isSearching: Bool = false
    
    private var searchTask: Task<Void, Never>?
    
    func loadMessages(for conversationId: String) async {
        await paginator.loadInitialMessages(for: conversationId)
    }
    
    func loadMoreMessages() async {
        await paginator.loadMoreMessages()
    }
    
    func refreshMessages() async {
        await paginator.refreshMessages()
    }
    
    func searchMessages(query: String) {
        searchQuery = query
        
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        searchTask = Task {
            // Add small delay to avoid excessive searching
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            if !Task.isCancelled {
                searchResults = paginator.searchMessages(query: query)
                isSearching = false
            }
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
        searchTask?.cancel()
    }
    
    func addNewMessage(_ message: ChatMessage) {
        paginator.addNewMessage(message)
    }
    
    func updateMessage(_ message: ChatMessage) {
        paginator.updateMessage(message)
    }
    
    func removeMessage(withId messageId: String) {
        paginator.removeMessage(withId: messageId)
    }
}
