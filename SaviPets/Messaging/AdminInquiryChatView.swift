import SwiftUI
import FirebaseAuth
import FirebaseCore
import OSLog

struct AdminInquiryChatView: View {
    var initialText: String? = nil
    var currentUserRole: UserRole? = nil // Used to determine if this is admin or user view
    @EnvironmentObject var chat: ChatService
    @EnvironmentObject var appState: AppState // Get role from app state if not provided
    @State private var selectedTab: Int = 0 // 0 = Clients, 1 = Sitters
    @State private var selectedConversationId: String? = nil
    @State private var isCleaningUp: Bool = false
    @State private var cleanupMessage: String? = nil
    @State private var showingConversationManagement: Bool = false
    @State private var conversationToDelete: Conversation? = nil
    @State private var showingDeleteAlert: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Only show tabs for admin users
                if isAdminView {
                    Picker("User Type", selection: $selectedTab) {
                        Text("Pet Owners").tag(0)
                        Text("Pet Sitters").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }

                // Show appropriate content based on user role
                if isAdminView {
                    // Admin view: show filtered conversations
                    List {
                        Section {
                            ForEach(filteredConversations) { convo in
                                ConversationRow(
                                    conversation: convo,
                                    conversationTitle: conversationTitle(convo),
                                    hasUnreadMessages: hasUnreadMessages(convo),
                                    onTap: { selectedConversationId = convo.id },
                                    onDelete: { conversationToDelete = convo; showingDeleteAlert = true }
                                )
                            }
                        } header: {
                            HStack {
                                Text("Conversations")
                                Spacer()
                                // Individual conversation management
                                Button(action: showConversationManagement) {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        // Show cleanup message if any
                        if let message = cleanupMessage {
                            Section {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    // User view: show direct admin chat or create one
                    UserAdminChatView(chat: chat)
                }
            }
            .navigationTitle(isAdminView ? "Inquiries" : "Contact Admin")
            .onAppear { 
                chat.listenToMyConversations()
                if !isAdminView {
                    // Ensure admin inquiry channel exists for non-admin users
                    Task {
                        try? await chat.getOrCreateAdminInquiryChannel()
                    }
                }
            }
            .sheet(item: Binding(get: { selectedConversationId.map { ChatSheetId(id: $0) } }, set: { v in selectedConversationId = v?.id })) { item in
                if #available(iOS 17.0, *) {
                    ConversationChatView(conversationId: item.id)
                        .environmentObject(chat)
                } else {
                    // Fallback on earlier versions
                }
            }
            .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    conversationToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let conversation = conversationToDelete {
                        deleteConversation(conversation)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this conversation? This action cannot be undone.")
            }
        }
    }

    private var isAdminView: Bool {
        let role = currentUserRole ?? appState.role
        return role == .admin
    }
    
    private var filteredConversations: [Conversation] {
        let role = selectedTab == 0 ? UserRole.petOwner : UserRole.petSitter
        
        // Filter conversations by role AND unread status
        var filtered = chat.conversations.filter { conversation in
            let hasRole = conversation.participantRoles.contains(role)
            let hasUnread = hasUnreadMessages(conversation)
            
            // For admin view: show conversations with unread messages OR recent activity
            // This ensures admin sees both pet owner and sitter messages
            if isAdminView {
                return hasRole && (hasUnread || isRecentConversation(conversation))
            }
            
            return hasRole && hasUnread
        }
        
        // Sort by most recent first
        filtered.sort { conv1, conv2 in
            conv1.lastMessageAt > conv2.lastMessageAt
        }
        
        return filtered
    }
    
    // Helper function to determine if conversation is recent (within last 24 hours)
    private func isRecentConversation(_ conversation: Conversation) -> Bool {
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        return conversation.lastMessageAt > twentyFourHoursAgo
    }

    private func conversationTitle(_ convo: Conversation) -> String {
        if isAdminView {
            // For admin: show the client/sitter name
            let pairs = zip(convo.participants, convo.participantRoles)
            let others = pairs.filter { $0.1 != UserRole.admin } // Exclude admin
            let names = others.map { pair -> String in
                let participantId = pair.0
                let role = pair.1
                let name = chat.displayName(for: participantId)
                return "\(role.displayName): \(name)"
            }
            return names.isEmpty ? "Unknown User" : names.joined(separator: ", ")
        } else {
            // For users: show "Support" or "Admin"
            return "Support"
        }
    }
    
    private func hasUnreadMessages(_ conversation: Conversation) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        
        // Check if there are unread messages for current user
        if let unreadCount = conversation.unreadCounts[currentUserId], unreadCount > 0 {
            return true
        }
        
        // Fallback: check lastReadTimestamp vs lastMessageAt
        if let lastRead = conversation.lastReadTimestamps[currentUserId] {
            return conversation.lastMessageAt > lastRead
        }
        
        // If no read timestamp exists, consider it unread
        return true
    }
    
    private func showConversationManagement() {
        showingConversationManagement = true
    }
    
    private func deleteConversation(_ conversation: Conversation) {
        isCleaningUp = true
        cleanupMessage = nil
        
        Task {
            do {
                try await chat.deleteConversation(conversation.id)
                await MainActor.run {
                    isCleaningUp = false
                    cleanupMessage = "✓ Conversation deleted successfully"
                    conversationToDelete = nil
                    
                    // Clear message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        cleanupMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isCleaningUp = false
                    cleanupMessage = "✗ Delete failed: \(error.localizedDescription)"
                    AppLogger.ui.error("Delete failed: \(error.localizedDescription)")
                    conversationToDelete = nil
                }
            }
        }
    }
}

// Simple chat view for pet owners to chat directly with admin
private struct UserAdminChatView: View {
    @ObservedObject var chat: ChatService
    @State private var messageText: String = ""
    @State private var currentConversationId: String? = nil
    @State private var isLoading: Bool = false
    @State private var hasAttemptedCreation: Bool = false
    
    private var adminConversation: Conversation? {
        chat.conversations.first { convo in
            convo.type == ConversationType.adminInquiry && convo.isPinned
        }
    }
    
    private var activeConversationId: String? {
        adminConversation?.id ?? currentConversationId
    }
    
    // MARK: - Modern Welcome Header
    
    private var modernWelcomeHeader: some View {
        VStack(spacing: 20) {
            // Icon with SaviPets yellow styling
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
            
            VStack(spacing: 8) {
                Text("Welcome to SaviPets Support")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("We're here to help you with any questions about your pet care needs. Feel free to ask us anything!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Quick action buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    AdminQuickActionButton(
                        icon: "calendar",
                        title: "Book Service",
                        action: { messageText = "I'd like to book a service for my pet" }
                    )
                    
                    AdminQuickActionButton(
                        icon: "questionmark.circle",
                        title: "Ask Question",
                        action: { messageText = "I have a question about..." }
                    )
                }
                
                HStack(spacing: 12) {
                    AdminQuickActionButton(
                        icon: "star",
                        title: "Rate Service",
                        action: { messageText = "I'd like to rate my recent service" }
                    )
                    
                    AdminQuickActionButton(
                        icon: "exclamationmark.triangle",
                        title: "Report Issue",
                        action: { messageText = "I need to report an issue" }
                    )
                }
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray5), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(.systemGray6),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Messages area with modern styling
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Welcome header for first-time users
                    if let conversationId = activeConversationId,
                       let messages = chat.messages[conversationId], messages.isEmpty {
                        modernWelcomeHeader
                            .padding(.top, 20)
                    }
                    
                    if let conversationId = activeConversationId,
                       let messages = chat.messages[conversationId], !messages.isEmpty {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            // ✨ NEW: Modern MessageBubble component
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == Auth.auth().currentUser?.uid,
                                senderName: message.senderId == Auth.auth().currentUser?.uid ? nil : "Admin",
                                showAvatar: shouldShowAvatar(at: index, messages: messages),
                                showTimestamp: shouldShowTimestamp(at: index, messages: messages)
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        // ✅ FIX: Use safeAreaInset for keyboard-safe input bar
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Setting up chat...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                } else if let conversationId = activeConversationId {
                    // ✨ NEW: Modern MessageInputBar component
                    MessageInputBar(
                        messageText: $messageText,
                        onSend: {
                            Task {
                                try? await chat.sendMessageSmart(conversationId: conversationId, text: messageText)
                                messageText = ""
                            }
                        },
                        showAttachButton: false
                    )
                } else {
                    // Fallback: show modern input that creates conversation on send
                    MessageInputBar(
                        messageText: $messageText,
                        onSend: {
                            let messageToSend = messageText
                            messageText = ""
                            Task {
                                await sendMessageDirectly(messageToSend)
                            }
                        },
                        showAttachButton: false
                    )
                }
            }
        }
        .navigationTitle("SaviPets Support")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: adminConversation?.id) { newId in
            if let id = newId {
                DLog.log("Admin conversation changed", id)  // Nil coalescing fix: id is non-optional String
                chat.listenToMessages(conversationId: id)
                currentConversationId = id
            }
        }
        .onAppear {
            DLog.log("UserAdminChatView appeared")
            if let conversationId = adminConversation?.id {
                DLog.log("Found existing admin conversation", conversationId)
                chat.listenToMessages(conversationId: conversationId)
                currentConversationId = conversationId
            } else if !hasAttemptedCreation {
                DLog.log("Creating new admin conversation")
                Task {
                    await createConversationIfNeeded()
                }
            }
        }
    }
    
    private func createConversationIfNeeded() async {
        guard !hasAttemptedCreation else { return }
        hasAttemptedCreation = true
        isLoading = true
        
        do {
            let conversationId = try await chat.getOrCreateAdminInquiryChannel()
            DLog.log("Created conversation ID", conversationId)
            
            // IMPORTANT: Start listening to messages immediately after creating conversation
            await MainActor.run {
                currentConversationId = conversationId
                chat.listenToMessages(conversationId: conversationId)
                isLoading = false
            }
        } catch {
            DLog.log("Error creating conversation:", error.localizedDescription)
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func sendMessageDirectly(_ messageText: String) async {
        DLog.log("sendMessageDirectly", messageText)
        
        do {
            DLog.log("Get or create admin inquiry channel")
            let conversationId = try await chat.getOrCreateAdminInquiryChannel()
            DLog.log("Got conversationId", conversationId)
            
            // Start listening to messages
            await MainActor.run {
                currentConversationId = conversationId
                chat.listenToMessages(conversationId: conversationId)
            }
            
            DLog.log("Calling sendMessageSmart")
            try await chat.sendMessageSmart(conversationId: conversationId, text: messageText)
            DLog.log("sendMessageSmart success")
        } catch {
            DLog.log("sendMessageDirectly error:", error.localizedDescription)
            // Restore the message text if sending failed
            await MainActor.run {
                self.messageText = messageText
            }
        }
    }
    
    private func sendFirstMessage() async {
        DLog.log("sendFirstMessage", messageText)
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            DLog.log("sendFirstMessage: empty text")
            return 
        }
        
        let messageToSend = messageText
        DLog.log("sendFirstMessage sending", messageToSend)
        
        // Clear the text field immediately for better UX
        await MainActor.run {
            messageText = ""
        }
        
        do {
            DLog.log("sendFirstMessage: get/create inquiry channel")
            let conversationId = try await chat.getOrCreateAdminInquiryChannel()
            DLog.log("sendFirstMessage: got conversationId", conversationId)
            
            // IMPORTANT: Start listening to messages BEFORE sending
            await MainActor.run {
                currentConversationId = conversationId
                chat.listenToMessages(conversationId: conversationId)
            }
            
            DLog.log("sendFirstMessage: call sendMessageSmart")
            try await chat.sendMessageSmart(conversationId: conversationId, text: messageToSend)
            DLog.log("sendFirstMessage: success")
        } catch {
            DLog.log("sendFirstMessage error:", error.localizedDescription)
            // Restore the message text if sending failed
            await MainActor.run {
                messageText = messageToSend
            }
        }
    }
    
    // MARK: - Helper functions for smart avatar/timestamp display
    
    private func shouldShowAvatar(at index: Int, messages: [ChatMessage]) -> Bool {
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
    
    private func shouldShowTimestamp(at index: Int, messages: [ChatMessage]) -> Bool {
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

// MARK: - Conversation Row Component

private struct ConversationRow: View {
    let conversation: Conversation
    let conversationTitle: String
    let hasUnreadMessages: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Unread indicator
                Circle()
                    .fill(hasUnreadMessages ? Color.blue : Color.clear)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversationTitle)
                        .font(hasUnreadMessages ? .headline : .subheadline)
                        .fontWeight(hasUnreadMessages ? .semibold : .regular)
                        .foregroundColor(.primary)
                    
                    Text(conversation.lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeAgo(from: conversation.lastMessageAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if hasUnreadMessages {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                    }
                }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Quick Action Button Component

private struct AdminQuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// Simple message bubble view (legacy - specific to admin inquiry)
// DEPRECATED: Kept for compatibility, can be removed after testing
private struct AdminMessageBubble: View {
    let message: ChatMessage
    let displayName: String
    
    var body: some View {
        HStack {
            if Auth.auth().currentUser?.uid == message.senderId {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if message.senderId == "system" {
                // Auto-response message styling
                VStack(alignment: .center, spacing: 4) {
                    Text(message.text)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    Text("Auto-reply")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(message.text)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.timestamp)
    }
}

// Simple message input view
private struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                VStack(spacing: 0) {
                    TextField("Type a message...", text: $text, axis: .vertical)
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
                        .lineLimit(1...4)
                }
                
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                      Color(.systemGray4) : Color.accentColor)
                        )
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}
