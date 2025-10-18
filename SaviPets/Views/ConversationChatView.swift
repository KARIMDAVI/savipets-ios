import SwiftUI
import OSLog
import FirebaseAuth
import Combine
import FirebaseFirestore

/// Enhanced conversation chat view with modern UX features
struct ConversationChatView: View {
    let conversationId: String
    @EnvironmentObject var chat: ChatService
    @StateObject private var paginationViewModel = MessagePaginationViewModel()
    @StateObject private var notificationManager = SmartNotificationManager.shared
    @StateObject private var listenerManager = MessageListenerManager.shared
    
    // MARK: - Firestore Reference
    private let db = Firestore.firestore()
    
    // MARK: - State Properties
    @State private var messageText: String = ""
    @State private var isTyping: Bool = false
    @State private var showMessageReactions: String? = nil
    @State private var selectedMessage: ChatMessage? = nil
    @State private var showingSearch: Bool = false
    @State private var searchQuery: String = ""
    @State private var scrollToBottom: Bool = false
    @State private var showTypingIndicator: Bool = false
    @State private var typingUsers: [String] = []
    @State private var isLoadingMore: Bool = false
    
    // MARK: - Computed Properties
    private var conversation: Conversation? {
        listenerManager.getConversation(by: conversationId)
    }
    
    private var messages: [ChatMessage] {
        if showingSearch && !searchQuery.isEmpty {
            return paginationViewModel.searchResults
        }
        // Use real-time messages from listener for instant updates
        let realtimeMessages = listenerManager.messages[conversationId] ?? []
        return realtimeMessages.sorted { $0.timestamp < $1.timestamp }  // Oldest to newest
    }
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var isAdmin: Bool {
        conversation?.roleFor(currentUserId ?? "") == .admin
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Modern gradient background (like ChatView)
            LinearGradient(
                colors: [
                    Color(.systemGray6),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Messages area with enhanced features
                messagesArea
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                
                // Typing indicator
                if showTypingIndicator && !typingUsers.isEmpty {
                    typingIndicatorView
                }
            }
        }
        // ✅ Use safeAreaInset for keyboard-safe input bar
        .safeAreaInset(edge: .bottom) {
            messageInputArea
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversationTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if conversation != nil {  // Swift 6: unused value fix
                        Text("Online")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.green)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { showingSearch.toggle() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(SPDesignSystem.Colors.chatYellow)
                }
            }
        }
        .searchableCompat(text: $searchQuery, isPresented: $showingSearch, prompt: "Search")
        .onAppear {
            setupConversation()
        }
        .onDisappear {
            cleanupConversation()
        }
        .onChange(of: messageText) { newValue in
            handleTypingStatus(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickReply)) { notification in
            if let text = notification.userInfo?["text"] as? String {
                messageText = text
            }
        }
    }
    
    // MARK: - Messages Area
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Messages (Using modern MessageBubble component)
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == currentUserId,
                            senderName: message.senderId == currentUserId ? nil : listenerManager.displayName(for: message.senderId),
                            showAvatar: shouldShowAvatar(at: index),
                            showTimestamp: shouldShowTimestamp(at: index)
                        )
                        .id(message.id)
                        .onLongPressGesture {
                            selectedMessage = message
                            showMessageReactions = message.id
                        }
                    }
                    
                    // Scroll anchor at bottom
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { _ in
                // Auto-scroll to bottom when new messages arrive
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Initial scroll to bottom
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Typing Indicator
    private var typingIndicatorView: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                        .scaleEffect(showTypingIndicator ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: showTypingIndicator
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .cornerRadius(16)
            
            Text(typingText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
    
    // MARK: - Message Input Area
    private var messageInputArea: some View {
        VStack(spacing: 0) {
            // Message reactions (if showing)
            if showMessageReactions != nil, let message = selectedMessage {
                messageReactionsView(for: message)
            }
            
            // ✨ NEW: Modern MessageInputBar component
            MessageInputBar(
                messageText: $messageText,
                onSend: sendMessage,
                onTyping: handleTypingIndicator,
                showAttachButton: false
            )
        }
    }
    
    // MARK: - Message Reactions View
    private func messageReactionsView(for message: ChatMessage) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Add Reaction")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") {
                    showMessageReactions = nil
                    selectedMessage = nil
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            HStack(spacing: 12) {
                ForEach(["❤️", "👍", "👎", "😂", "😢", "😮"], id: \.self) { emoji in
                    Button(emoji) {
                        handleMessageReaction(message: message, emoji: emoji)
                        showMessageReactions = nil
                        selectedMessage = nil
                    }
                    .font(.title2)
                    .scaleEffect(message.hasReaction(emoji, from: currentUserId ?? "") ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: message.hasReaction(emoji, from: currentUserId ?? ""))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if paginationViewModel.isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !searchQuery.isEmpty && paginationViewModel.searchResults.isEmpty {
                Text("No messages found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Computed Properties
    private var conversationTitle: String {
        guard let conversation = conversation else { return "Chat" }
        
        if conversation.isPinned {
            return conversation.pinnedName ?? "Pinned Chat"
        }
        
        // Get other participants (excluding current user)
        let otherParticipants = conversation.participants.filter { $0 != currentUserId }
        let otherNames = otherParticipants.map { listenerManager.displayName(for: $0) }
        
        return otherNames.joined(separator: ", ")
    }
    
    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var typingText: String {
        if typingUsers.count == 1 {
            return "\(listenerManager.displayName(for: typingUsers[0])) is typing..."
        } else if typingUsers.count > 1 {
            return "\(typingUsers.count) people are typing..."
        }
        return ""
    }
    
    // MARK: - Methods
    private func setupConversation() {
        // Enable auto-scroll to bottom for new conversations
        scrollToBottom = true
        
        // Attach listeners for real-time updates FIRST
        // This ensures messages are loaded and maintained
        _ = listenerManager.attachMessagesListener(for: conversationId)
        listenerManager.attachTypingIndicatorListener(for: conversationId)
        
        // Load historical messages after listener is attached with timeout handling
        Task {
            do {
                // Set a timeout for message loading
                try await withTimeout(seconds: 10) {
                    await paginationViewModel.loadMessages(for: conversationId)
                }
            } catch {
                AppLogger.chat.error("Failed to load messages for conversation \(conversationId): \(error.localizedDescription)")
                // Continue with real-time messages even if historical loading fails
            }
        }
        
        // Mark conversation as read
        markConversationAsRead()
    }
    
    // Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func cleanupConversation() {
        // Detach listeners
        listenerManager.detachMessagesListener(for: conversationId)
        listenerManager.detachTypingIndicatorListener(for: conversationId)
        
        // Stop typing
        stopTyping()
    }
    
    private func sendMessage() {
        guard canSendMessage else { return }
        
        let textToSend = messageText
        messageText = ""
        scrollToBottom = true
        
        Task {
            do {
                try await ResilientChatService.shared.sendMessageSmart(
                    conversationId: conversationId,
                    text: textToSend
                )
            } catch {
                AppLogger.chat.error("Error sending message: \(error.localizedDescription)")
                // Restore message text on error
                await MainActor.run {
                    messageText = textToSend
                }
            }
        }
    }
    
    private func handleTypingIndicator() {
        handleTypingStatus(messageText)
    }
    
    private func handleTypingStatus(_ text: String) {
        let isCurrentlyTyping = !text.isEmpty
        
        if isCurrentlyTyping != isTyping {
            isTyping = isCurrentlyTyping
            updateTypingStatus(isTyping)
        }
    }
    
    private func updateTypingStatus(_ typing: Bool) {
        guard let currentUserId = currentUserId else { return }
        
        let typingRef = db.collection("conversations")
            .document(conversationId)
            .collection("typing")
            .document(currentUserId)
        
        if typing {
            typingRef.setData([
                "userId": currentUserId,
                "isTyping": true,
                "timestamp": FieldValue.serverTimestamp()
            ])
        } else {
            typingRef.delete()
        }
    }
    
    private func stopTyping() {
        guard let currentUserId = currentUserId else { return }
        
        db.collection("conversations")
            .document(conversationId)
            .collection("typing")
            .document(currentUserId)
            .delete()
    }
    
    private func handleMessageReaction(message: ChatMessage, emoji: String) {
        guard let currentUserId = currentUserId else { return }
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(message.id)
        
        var updatedReactions = message.reactions
        
        if message.hasReaction(emoji, from: currentUserId) {
            // Remove reaction
            updatedReactions[emoji]?.removeAll { $0 == currentUserId }
            if updatedReactions[emoji]?.isEmpty == true {
                updatedReactions.removeValue(forKey: emoji)
            }
        } else {
            // Add reaction
            if updatedReactions[emoji] == nil {
                updatedReactions[emoji] = []
            }
            if !updatedReactions[emoji]!.contains(currentUserId) {
                updatedReactions[emoji]!.append(currentUserId)
            }
        }
        
        messageRef.updateData(["reactions": updatedReactions])
    }
    
    private func markConversationAsRead() {
        guard let currentUserId = currentUserId else { return }
        
        let conversationRef = db.collection("conversations").document(conversationId)
        
        // Update last read timestamp
        conversationRef.updateData([
            "lastReadTimestamps.\(currentUserId)": FieldValue.serverTimestamp(),
            "unreadCounts.\(currentUserId)": 0
        ])
    }
    
    private func shouldShowAvatar(at index: Int) -> Bool {
        guard index < messages.count else { return true }
        let message = messages[index]
        
        // Always show for first message
        if index == 0 { return true }
        
        // Show if sender changed from previous message
        if index > 0 && messages[index - 1].senderId != message.senderId {
            return true
        }
        
        // Show if time gap > 5 minutes from previous message
        if index > 0 {
            let timeDiff = message.timestamp.timeIntervalSince(messages[index - 1].timestamp)
            if timeDiff > 300 { return true }
        }
        
        return false
    }
    
    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index < messages.count else { return false }
        
        // Show for last message
        if index == messages.count - 1 { return true }
        
        // Show if next message is from different sender
        if index < messages.count - 1 && messages[index + 1].senderId != messages[index].senderId {
            return true
        }
        
        // Show if time gap > 5 minutes to next message
        if index < messages.count - 1 {
            let timeDiff = messages[index + 1].timestamp.timeIntervalSince(messages[index].timestamp)
            if timeDiff > 300 { return true }
        }
        
        return false
    }
}


// MARK: - Searchable Compatibility
private extension View {
    @ViewBuilder
    func searchableCompat(text: Binding<String>, isPresented: Binding<Bool>, prompt: LocalizedStringKey) -> some View {
        if #available(iOS 17.0, *) {
            self.searchable(text: text, isPresented: isPresented, prompt: prompt)
        } else {
            self.searchable(text: text, prompt: prompt)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ConversationChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConversationChatView(conversationId: "preview-conversation")
                .environmentObject(ChatService())
        }
    }
}
#endif
