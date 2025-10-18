import SwiftUI
import FirebaseAuth
import OSLog

/**
 * ChatView - Modern Chat Interface
 * 
 * A clean, modern chat interface inspired by contemporary messaging apps.
 * 
 * Features:
 * - Rounded container with soft shadows
 * - Real-time message updates
 * - Typing indicators
 * - Auto-scroll to latest messages
 * - Keyboard-aware input bar
 * - Delivery status tracking
 * - Admin approval status for sitter-owner chats
 * 
 * How It Works:
 * 1. Loads conversation and messages from Firestore
 * 2. Displays messages in chronological order
 * 3. Shows pending approval overlay for unapproved sitter-owner chats
 * 4. Updates in real-time via Firestore listeners
 * 5. Sends messages via ChatService
 */
struct ChatView: View {
    let conversationId: String
    let conversationType: ConversationType
    
    @EnvironmentObject var chat: ChatService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var conversation: Conversation?
    @State private var isLoading: Bool = true
    @State private var showTypingIndicator: Bool = false
    @State private var isPendingApproval: Bool = false
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private var otherParticipantName: String {
        guard let conv = conversation else { return "Chat" }
        let otherIds = conv.participants.filter { $0 != currentUserId }
        return otherIds.first.map { chat.displayName(for: $0) } ?? "Chat"
    }
    
    private var canSendMessages: Bool {
        // Admin can always send
        if let roles = conversation?.participantRoles, roles.contains(.admin) {
            return true
        }
        
        // Approved conversations allow messages
        if conversation?.status == .active {
            return true
        }
        
        // Admin inquiry always allowed
        if conversationType == .adminInquiry {
            return true
        }
        
        // Pending approval blocks messages
        return false
    }
    
    var body: some View {
        ZStack {
            // SaviPets yellow gradient background (Smartsupp-inspired)
            LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.black : Color.white,
                    colorScheme == .dark ? Color(UIColor.systemGray6).opacity(0.3) : SPDesignSystem.Colors.chatYellowLight
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Messages scroll view with modern styling
            messagesScrollView
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        // Pending approval overlay
        .overlay(alignment: .bottom) {
            if isPendingApproval && !canSendMessages {
                pendingApprovalBanner
            }
        }
        // ✅ FIX: Use safeAreaInset for keyboard-safe input bar
        .safeAreaInset(edge: .bottom) {
            if canSendMessages {
                MessageInputBar(
                    messageText: $messageText,
                    onSend: sendMessage,
                    onTyping: handleTyping,
                    showAttachButton: false
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(otherParticipantName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Online")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.green)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(SPDesignSystem.Colors.chatYellow)
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { 
                    dismiss() 
                }
                .font(.system(size: 16, weight: .medium))
            }
        }
        .onAppear {
            loadConversation()
            loadMessages()
        }
    }
    
    // MARK: - Messages Scroll View
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Welcome header for admin inquiries
                    if conversationType == .adminInquiry && messages.count < 3 {
                        welcomeHeader
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                    }
                    
                    // Messages
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let isFromCurrentUser = message.senderId == currentUserId
                        let showAvatar = shouldShowAvatar(at: index)
                        let showTimestamp = shouldShowTimestamp(at: index)
                        
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: isFromCurrentUser,
                            senderName: isFromCurrentUser ? nil : (message.senderName ?? chat.displayName(for: message.senderId)),
                            showAvatar: showAvatar,
                            showTimestamp: showTimestamp
                        )
                        .id(message.id)
                    }
                    
                    // Typing indicator
                    if showTypingIndicator {
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: showTypingIndicator) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    // MARK: - Welcome Header
    
    private var welcomeHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [SPDesignSystem.Colors.chatYellow.opacity(0.15), SPDesignSystem.Colors.chatYellow.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: SPDesignSystem.Colors.chatYellow.opacity(0.2), radius: 10, x: 0, y: 5)
                
                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(SPDesignSystem.Colors.chatYellow)
            }
            
            VStack(spacing: 6) {
                Text("SaviPets Support")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("We're here to help you with any questions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SPDesignSystem.Colors.chatYellowLight.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(SPDesignSystem.Colors.chatYellow.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Pending Approval Banner
    
    private var pendingApprovalBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pending Admin Approval")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("An admin will review this chat request shortly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Helper Functions
    
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
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                if showTypingIndicator {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadConversation() {
        // Find conversation in existing chat service data
        if let conv = chat.conversations.first(where: { $0.id == conversationId }) {
            self.conversation = conv
            self.isPendingApproval = conv.status == .pending
        }
        self.isLoading = false
    }
    
    private func loadMessages() {
        // Use existing chat service messages
        // Messages are already loaded by ChatService listeners
        if let convMessages = chat.messages[conversationId] {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.messages = convMessages.sorted { $0.timestamp < $1.timestamp }
            }
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        Task {
            do {
                // Use existing sendMessage method
                try await chat.sendMessage(conversationId: conversationId, text: text)
                
                await MainActor.run {
                    messageText = ""
                }
            } catch {
                AppLogger.ui.error("Failed to send message: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleTyping() {
        // Optional: Implement typing indicator logic
        // For now, just a placeholder
    }
}

// MARK: - Typing Indicator View

private struct TypingIndicatorView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar placeholder
            ChatAvatarView(name: "S", size: 32)
            
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemGray5))
            )
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Chat Avatar View

private struct ChatAvatarView: View {
    let name: String
    let size: CGFloat
    
    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
    
    private var backgroundColor: Color {
        let hash = name.hashValue
        let colors: [Color] = [
            SPDesignSystem.Colors.chatYellow,
            .green,
            .orange,
            .purple,
            .pink,
            .indigo,
            .teal
        ]
        return colors[abs(hash) % colors.count]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor.opacity(0.2))
            
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(backgroundColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("Chat View - Active") {
    NavigationStack {
        ChatView(
            conversationId: "test-conversation",
            conversationType: .clientSitter
        )
        .environmentObject(AppState())
        .environmentObject(ChatService())
    }
}

#Preview("Chat View - Pending") {
    NavigationStack {
        ChatView(
            conversationId: "test-conversation-pending",
            conversationType: .sitterToClient
        )
        .environmentObject(AppState())
        .environmentObject(ChatService())
    }
}

