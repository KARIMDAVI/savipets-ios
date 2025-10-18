import SwiftUI

/// Modern chat bubble component following iOS design guidelines
struct ModernChatBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let showTimestamp: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isFromCurrentUser {
                // Avatar for received messages
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text((message.senderName ?? "User").prefix(1).uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message bubble
                Text(message.text)
                    .font(.body)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                isFromCurrentUser 
                                    ? LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color(.systemGray6),
                                            Color(.systemGray5).opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                    )
                    .shadow(
                        color: isFromCurrentUser 
                            ? Color.blue.opacity(0.3)
                            : Color.black.opacity(0.1),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                
                // Timestamp and status
                if showTimestamp {
                    HStack(spacing: 4) {
                        if isFromCurrentUser {
                            // Message status indicator
                            Image(systemName: messageStatusIcon)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if isFromCurrentUser {
                // Avatar for sent messages
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.8), Color.green.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("Me")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private var messageStatusIcon: String {
        // This would be determined by the message status in a real implementation
        // For now, return a default "sent" icon
        return "checkmark"
    }
}

/// Modern chat input field with enhanced UX
struct ModernChatInput: View {
    @Binding var messageText: String
    let onSend: () -> Void
    let isSending: Bool
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var inputHeight: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(.systemGray4))
            
            HStack(alignment: .bottom, spacing: 12) {
                // Text input
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .focused($isTextFieldFocused)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                        .onSubmit {
                            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSend()
                            }
                        }
                        .lineLimit(1...4)
                        .onChange(of: messageText) { _ in
                            updateInputHeight()
                        }
                }
                
                // Send button
                Button(action: onSend) {
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
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(
                                    messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color(.systemGray)
                                        : .white
                                )
                        }
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .animation(.easeInOut(duration: 0.2), value: messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -2)
            )
        }
    }
    
    private func updateInputHeight() {
        // Calculate height based on content
        let lines = messageText.components(separatedBy: .newlines).count
        let baseHeight: CGFloat = 40
        let lineHeight: CGFloat = 20
        let maxHeight: CGFloat = 120
        
        inputHeight = min(maxHeight, max(baseHeight, CGFloat(lines) * lineHeight + 20))
    }
}

/// Modern typing indicator
struct ModernTypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("A")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            // Typing bubble
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemGray6))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            animationOffset = -4
        }
    }
}

#Preview {
    VStack {
        ModernChatBubble(
            message: ChatMessage(
                id: "1",
                senderId: "user1",
                text: "Hello! How are you today?",
                timestamp: Date(),
                senderName: "Pet Sitter"
            ),
            isFromCurrentUser: false,
            showTimestamp: true
        )
        
        ModernChatBubble(
            message: ChatMessage(
                id: "2",
                senderId: "user2",
                text: "I'm doing great, thank you for asking!",
                timestamp: Date(),
                senderName: "Pet Owner"
            ),
            isFromCurrentUser: true,
            showTimestamp: true
        )
        
        ModernTypingIndicator()
        
        Spacer()
        
        ModernChatInput(
            messageText: .constant(""),
            onSend: {},
            isSending: false
        )
    }
    .background(Color(.systemGroupedBackground))
}
