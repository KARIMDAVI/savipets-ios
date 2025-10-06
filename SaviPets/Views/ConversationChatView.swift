import SwiftUI
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
        return paginationViewModel.paginator.messages
    }
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var isAdmin: Bool {
        conversation?.roleFor(currentUserId ?? "") == .admin
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header with conversation info
            conversationHeader
            
            // Messages area with enhanced features
            messagesArea
            
            // Typing indicator
            if showTypingIndicator && !typingUsers.isEmpty {
                typingIndicatorView
            }
            
            // Message input with reactions
            messageInputArea
        }
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Search") {
                    showingSearch.toggle()
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
    
    // MARK: - Conversation Header
    private var conversationHeader: some View {
        HStack {
            // Conversation info
            VStack(alignment: .leading, spacing: 2) {
                Text(conversationTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let conversation = conversation {
                    Text("\(conversation.participants.count) participants")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Unread count badge
            if let conversation = conversation,
               let currentUserId = currentUserId,
               conversation.unreadCount(for: currentUserId) > 0 {
                Text("\(conversation.unreadCount(for: currentUserId))")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Messages Area
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Load more button
                    if paginationViewModel.paginator.hasMoreMessages {
                        loadMoreButton
                    }
                    
                    // Messages
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubbleView(
                            message: message,
                            displayName: listenerManager.displayName(for: message.senderId),
                            isCurrentUser: message.senderId == currentUserId,
                            onReaction: { emoji in
                                handleMessageReaction(message: message, emoji: emoji)
                            },
                            onLongPress: {
                                selectedMessage = message
                                showMessageReactions = message.id
                            }
                        )
                        .id(message.id)
                        .onAppear {
                            // Load more messages when scrolling to top
                            if paginationViewModel.paginator.shouldLoadMore(currentIndex: index) {
                                Task {
                                    await paginationViewModel.loadMoreMessages()
                                }
                            }
                        }
                    }
                    
                    // Scroll anchor
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                // Auto-scroll to bottom when new messages arrive
                if scrollToBottom {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .refreshable {
                await paginationViewModel.refreshMessages()
            }
        }
    }
    
    // MARK: - Load More Button
    private var loadMoreButton: some View {
        Button(action: {
            guard !isLoadingMore else { return }
            isLoadingMore = true
            Task {
                await paginationViewModel.loadMoreMessages()
                await MainActor.run {
                    isLoadingMore = false
                }
            }
        }) {
            HStack {
                if isLoadingMore {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.up")
                }
                Text(isLoadingMore ? "Loading..." : "Load More")
                    .font(.caption)
            }
            .foregroundColor(.accentColor)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(20)
        }
        .disabled(isLoadingMore)
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
            
            // Input field
            HStack(alignment: .bottom, spacing: 12) {
                // Text input
                VStack(spacing: 0) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        )
                        .lineLimit(1...6)
                }
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(canSendMessage ? Color.accentColor : Color(.systemGray4))
                        )
                }
                .disabled(!canSendMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
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
        Task {
            await paginationViewModel.loadMessages(for: conversationId)
        }
        
        // Attach listeners
        listenerManager.attachMessagesListener(for: conversationId)
        listenerManager.attachTypingIndicatorListener(for: conversationId)
        
        // Mark conversation as read
        markConversationAsRead()
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
                print("Error sending message: \(error)")
                // Restore message text on error
                await MainActor.run {
                    messageText = textToSend
                }
            }
        }
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
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    let displayName: String
    let isCurrentUser: Bool
    let onReaction: (String) -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    messageContent
                    messageMetadata
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if !isCurrentUser {
                        Text(displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    messageContent
                    messageMetadata
                }
                Spacer()
            }
        }
        .onLongPressGesture {
            onLongPress()
        }
    }
    
    private var messageContent: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            // Message text
            Text(message.text)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isCurrentUser ? Color.accentColor : Color(.systemGray5))
                )
                .foregroundColor(isCurrentUser ? .white : .primary)
            
            // Message reactions
            if !message.reactions.isEmpty {
                messageReactions
            }
        }
    }
    
    private var messageReactions: some View {
        HStack(spacing: 4) {
            ForEach(Array(message.reactions.keys.sorted()), id: \.self) { emoji in
                Button(emoji) {
                    onReaction(emoji)
                }
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    Text("\(message.reactions[emoji]?.count ?? 0)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 2)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                )
            }
        }
    }
    
    private var messageMetadata: some View {
        HStack(spacing: 4) {
            // Delivery status
            if isCurrentUser {
                deliveryStatusIcon
            }
            
            // Timestamp
            Text(timeString)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var deliveryStatusIcon: some View {
        Group {
            switch message.deliveryStatus {
            case .sending:
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
            case .delivered:
                Image(systemName: "checkmark")
                    .foregroundColor(.secondary)
            case .read:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        }
        .font(.caption2)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.timestamp)
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
