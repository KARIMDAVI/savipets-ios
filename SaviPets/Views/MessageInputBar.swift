import SwiftUI
import UIKit

/**
 * MessageInputBar Component
 * 
 * Modern chat input bar with:
 * - Auto-expanding text field
 * - Keyboard-safe positioning
 * - Send button with animations
 * - Optional attachment button
 * - Typing indicator integration
 */
struct MessageInputBar: View {
    @Binding var messageText: String
    let onSend: () -> Void
    let onTyping: (() -> Void)?
    let showAttachButton: Bool
    
    @FocusState private var isFocused: Bool
    @State private var textHeight: CGFloat = 36
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        messageText: Binding<String>,
        onSend: @escaping () -> Void,
        onTyping: (() -> Void)? = nil,
        showAttachButton: Bool = false
    ) {
        self._messageText = messageText
        self.onSend = onSend
        self.onTyping = onTyping
        self.showAttachButton = showAttachButton
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Compact attachment button (optional)
            if showAttachButton {
                Button(action: {
                    // Placeholder for attachment functionality
                }) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Compact capsule text input field
            HStack(spacing: 8) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .font(.system(size: 15, weight: .regular))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .onChange(of: messageText) { _ in
                        onTyping?()
                    }
            }
            .frame(height: 42)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.systemGray6))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                isFocused ? SPDesignSystem.Colors.chatYellow.opacity(0.5) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
            
            // Compact send button with SaviPets yellow theme
            Button(action: handleSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                canSend
                                    ? SPDesignSystem.Colors.chatYellow
                                    : Color(.systemGray4)
                            )
                            .shadow(
                                color: canSend ? SPDesignSystem.Colors.chatYellow.opacity(0.3) : Color.clear,
                                radius: canSend ? 4 : 0,
                                x: 0,
                                y: 2
                            )
                    )
                    .scaleEffect(canSend ? 1.0 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSend)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color(colorScheme == .dark ? .black : .white)
                .shadow(color: .black.opacity(0.05), radius: 8, y: -3)
        )
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func handleSend() {
        guard canSend else { return }
        onSend()
        isFocused = false
    }
}

// MARK: - Preview

#Preview("Empty State - SaviPets Yellow Theme") {
    VStack {
        Spacer()
        MessageInputBar(
            messageText: .constant(""),
            onSend: {},
            showAttachButton: true
        )
    }
    .background(
        LinearGradient(
            colors: [Color.white, SPDesignSystem.Colors.chatYellowLight],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

#Preview("With Text - SaviPets Yellow Theme") {
    VStack {
        Spacer()
        MessageInputBar(
            messageText: .constant("Hello! How is Bella doing?"),
            onSend: {},
            showAttachButton: true
        )
    }
    .background(
        LinearGradient(
            colors: [Color.white, SPDesignSystem.Colors.chatYellowLight],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

#Preview("Compact Without Attachment Button") {
    VStack {
        Spacer()
        MessageInputBar(
            messageText: .constant("Type a message..."),
            onSend: {},
            showAttachButton: false
        )
    }
    .background(
        LinearGradient(
            colors: [Color.white, SPDesignSystem.Colors.chatYellowLight],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

