import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct ModernChatView: View {
    @EnvironmentObject var chat: ChatService
    @Environment(\.dismiss) var dismiss
    let conversationId: String
    
    @State private var messageText: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @State private var showErrorAlert: Bool = false
    @State private var showScrollToBottomButton: Bool = false
    
    @State private var lastMessageId: String? = nil
    
    @FocusState private var isInputActive: Bool
    
    private var messages: [ChatMessage] {
        chat.messages[conversationId]?.sorted(by: { $0.timestamp < $1.timestamp }) ?? []
    }
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        VStack(spacing: 0) {
            messagesScrollView
            messageInputBar
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
            }
        }
        .onAppear(perform: setupChat)
        .onDisappear(perform: cleanupChat)
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        ModernChatBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == currentUserId,
                            showTimestamp: true // Always show timestamp for now
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onChange(of: messages.last?.id) { newLastMessageId in
                // Only scroll to bottom if the new message is from the current user
                // or if the user is already near the bottom
                if newLastMessageId != nil && (messages.last?.senderId == currentUserId || !showScrollToBottomButton) {
                    withAnimation {
                        proxy.scrollTo(newLastMessageId, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Initial scroll to bottom
                if let lastId = messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }
    
    private var messageInputBar: some View {
        VStack {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .focused($isInputActive)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.systemGray6)))
                    .font(.body)
                    .lineLimit(1...5)
                    .onChange(of: messageText) { newValue in
                        // TODO: Implement typing indicator logic
                    }
                
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color(.systemGray4)
                                    : Color.blue
                            )
                            .frame(width: 40, height: 40)
                        
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private func setupChat() {
        print("Setting up ModernChatView for conversation: \(conversationId)")
        // The message listener should already be set up by UnifiedChatService
        // This ensures we're subscribed to message updates
        chat.listenToMessages(conversationId: conversationId)
    }
    
    private func cleanupChat() {
        print("Cleaning up ModernChatView for conversation: \(conversationId)")
        // TODO: Detach message listener if necessary (UnifiedChatService handles this now)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = "" // Clear input immediately for better UX
        isSending = true
        isInputActive = false // Dismiss keyboard
        
        // Stop typing indicator
        // TODO: Implement stopTypingIndicator()
        
        Task {
            do {
                // Send via ResilientChatService with admin moderation
                try await ResilientChatService.shared.sendMessage(
                    conversationId: conversationId,
                    text: messageToSend,
                    moderationType: .admin
                )
                
                await MainActor.run {
                    isSending = false
                }
                
            } catch {
                print("Error sending message: \(error.localizedDescription)")
                await MainActor.run {
                    messageText = messageToSend // Restore message on failure
                    isSending = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
    
    // TODO: Implement typing indicator logic
    private func startTypingIndicator() {
        // Logic to send typing indicator to Firestore
    }
    
    private func stopTypingIndicator() {
        // Logic to remove typing indicator from Firestore
    }
}

struct ModernConversationListView: View {
    @EnvironmentObject var chat: ChatService
    @State private var selectedConversationId: String? = nil
    @State private var showNewMessageSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Conversations") {
                    ForEach(chat.conversations) { convo in
                        ConversationRowView(conversation: convo, chat: chat) {
                            selectedConversationId = convo.id
                        }
                    }
                }
                
                Section("Quick Actions") {
                    Button(action: { showNewMessageSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Start New Conversation")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Messages")
            .onAppear {
                chat.listenToMyConversations()
            }
            .sheet(item: Binding(get: {
                selectedConversationId.map { ChatSheetId(id: $0) }
            }, set: { v in selectedConversationId = v?.id })) { item in
                ModernChatView(conversationId: item.id)
                    .environmentObject(chat)
            }
            .sheet(isPresented: $showNewMessageSheet) {
                ModernNewMessageView() // New message view for starting new conversations
                    .environmentObject(chat)
            }
        }
    }
}

struct ModernNewMessageView: View {
    @EnvironmentObject var chat: ChatService
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText: String = ""
    @State private var isSending: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Send Message to Admin")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your message will be reviewed by an admin before delivery.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Message input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.headline)
                    
                    TextEditor(text: $messageText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(
                            Group {
                                if messageText.isEmpty {
                                    Text("Type your message here...")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Send button
                Button(action: sendMessage) {
                    HStack {
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSending ? "Sending..." : "Send Message")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Message Sent", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your message has been sent for admin review. You'll be notified once it's approved.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Failed to send message. Please try again.")
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        messageText = "" // Clear the text input immediately for better UX
        isSending = true
        
        Task {
            do {
                let currentUser = Auth.auth().currentUser
                let db = Firestore.firestore()
                
                print("Starting to send message to admin: '\(messageToSend)'")
                
                // Find admin user ID - preferably primary admin
                let adminQuery = try await db.collection("users")
                    .whereField("role", isEqualTo: UserRole.admin.rawValue)
                    .limit(to: 1)
                    .getDocuments()
                
                guard let adminDoc = adminQuery.documents.first else {
                    let error = NSError(domain: "ChatError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No admin user found. Please contact support."])
                    print("Admin user not found when sending message")
                    throw error
                }
                
                let adminId = adminDoc.documentID
                let sitterId = currentUser?.uid ?? ""
                
                print("Found admin: \(adminId), sitter: \(sitterId)")
                
                // Use UnifiedChatService to get or create admin inquiry channel
                print("Getting or creating admin inquiry channel")
                let conversationId = try await UnifiedChatService.shared.getOrCreateAdminInquiryChannel()
                
                print("Using conversation ID: \(conversationId)")
                
                // Send message with admin moderation so it appears in admin's approval queue
                print("Sending message via ResilientChatService")
                try await ResilientChatService.shared.sendMessage(
                    conversationId: conversationId,
                    text: messageToSend,
                    moderationType: .admin
                )
                
                print("Message sent successfully!")
                
                await MainActor.run {
                    isSending = false
                    showSuccessAlert = true
                }
            } catch {
                print("Error sending message: \(error.localizedDescription)")
                await MainActor.run {
                    messageText = messageToSend // Restore the message text if sending failed
                    isSending = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    let chat: ChatService
    let onTap: () -> Void
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var otherParticipantId: String? {
        guard let currentUserId = currentUserId else { return nil }
        return conversation.participants.first { $0 != currentUserId }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading) {
                Text(chat.displayName(for: otherParticipantId ?? ""))
                    .font(.headline)
                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
