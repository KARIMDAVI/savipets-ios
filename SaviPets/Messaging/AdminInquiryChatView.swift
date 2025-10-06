import SwiftUI
import FirebaseAuth
import FirebaseCore

struct AdminInquiryChatView: View {
    var initialText: String? = nil
    var currentUserRole: UserRole? = nil // Used to determine if this is admin or user view
    @EnvironmentObject var chat: ChatService
    @EnvironmentObject var appState: AppState // Get role from app state if not provided
    @State private var selectedTab: Int = 0 // 0 = Clients, 1 = Sitters
    @State private var selectedConversationId: String? = nil

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
                        Section("Conversations") {
                            ForEach(filteredConversations) { convo in
                                Button(action: { selectedConversationId = convo.id }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conversationTitle(convo))
                                            .font(.headline)
                                        Text(convo.lastMessage)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
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
        }
    }

    private var isAdminView: Bool {
        let role = currentUserRole ?? appState.role
        return role == .admin
    }
    
    private var filteredConversations: [Conversation] {
        let role = selectedTab == 0 ? UserRole.petOwner : UserRole.petSitter
        return chat.conversations.filter { $0.participantRoles.contains(role) }
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let conversationId = activeConversationId,
                       let messages = chat.messages[conversationId], !messages.isEmpty {
                        ForEach(messages) { message in
                            MessageBubble(message: message, displayName: chat.displayName(for: message.senderId))
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "message.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No messages yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Send a message to get started!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            
            // Message input - always show, create conversation if needed
            VStack(spacing: 0) {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Setting up chat...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                } else if let conversationId = activeConversationId {
                    MessageInputView(
                        text: $messageText,
                        onSend: {
                            Task {
                                try? await chat.sendMessageSmart(conversationId: conversationId, text: messageText)
                                messageText = ""
                            }
                        }
                    )
                } else {
                    // Fallback: show a message input that creates conversation on send
                    VStack(spacing: 12) {
                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(spacing: 0) {
                                TextField("Type your message...", text: $messageText, axis: .vertical)
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
                            
                            Button(action: {
                                let messageToSend = messageText
                                DLog.log("SEND tapped", messageToSend)
                                
                                // SIMPLE TEST: Just clear the text field to see if button works
                                messageText = ""
                                DLog.log("Text field cleared")
                                
                                // Now try to send the message with the original text
                                Task {
                                    await sendMessageDirectly(messageToSend)
                                }
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                                  Color(.systemGray4) : Color.accentColor)
                                    )
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding()
                }
            }
        }
        .onChange(of: adminConversation?.id) { newId in
            if let id = newId {
                DLog.log("Admin conversation changed", id ?? "nil")
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
}

// Simple message bubble view
private struct MessageBubble: View {
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
