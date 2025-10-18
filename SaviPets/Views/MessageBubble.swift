import SwiftUI
import UIKit
import OSLog

/**
 * MessageBubble Component
 * 
 * Modern chat bubble with:
 * - Left/right positioning based on sender
 * - Adaptive colors for light/dark mode
 * - Avatar for incoming messages
 * - Timestamp display
 * - Delivery status indicators
 * - Smooth animations
 */
struct MessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let senderName: String?
    let showAvatar: Bool
    let showTimestamp: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        message: ChatMessage,
        isFromCurrentUser: Bool,
        senderName: String? = nil,
        showAvatar: Bool = true,
        showTimestamp: Bool = false
    ) {
        self.message = message
        self.isFromCurrentUser = isFromCurrentUser
        self.senderName = senderName
        self.showAvatar = showAvatar
        self.showTimestamp = showTimestamp
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if !isFromCurrentUser {
                // Modern avatar for incoming messages
                if showAvatar {
                    ChatAvatarView(name: senderName ?? "U", size: 36)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            } else {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 6) {
                // Enhanced sender name styling
                if !isFromCurrentUser, let name = senderName {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
                
                // Modern message bubble with enhanced styling
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(modernBubbleBackground)
                    .foregroundColor(bubbleTextColor)
                    .font(.system(size: 15, weight: .regular))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Enhanced timestamp and delivery status
                if showTimestamp {
                    HStack(spacing: 6) {
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        if isFromCurrentUser {
                            deliveryStatusIcon
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isFromCurrentUser ? .trailing : .leading)
            
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .transition(.scale.combined(with: .opacity))
    }
    
    private var modernBubbleBackground: some View {
        Group {
            if isFromCurrentUser {
                // Outgoing message - SaviPets yellow theme
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SPDesignSystem.Colors.chatYellow)
                    .shadow(
                        color: SPDesignSystem.Colors.chatYellow.opacity(0.25),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            } else {
                // Incoming message - white with gray border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SPDesignSystem.Colors.chatBubbleIncoming)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(SPDesignSystem.Colors.chatBubbleBorder, lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.04),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            }
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if isFromCurrentUser {
                // Outgoing message - accent color
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            } else {
                // Incoming message - system gray
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemGray5))
            }
        }
    }
    
    private var bubbleTextColor: Color {
        if isFromCurrentUser {
            return .white // White text on yellow background
        } else {
            return SPDesignSystem.Colors.chatTextDark // Black text on white background
        }
    }
    
    private var deliveryStatusIcon: some View {
        Group {
            switch message.deliveryStatus {
            case "sent":
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case "delivered":
                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            case "read":
                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.blue)
            default:
                EmptyView()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Bubble Shape

private struct BubbleShape: Shape {
    let isFromCurrentUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isFromCurrentUser
                ? [.topLeft, .topRight, .bottomLeft]
                : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
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
                .fill(
                    LinearGradient(
                        colors: [backgroundColor, backgroundColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("Incoming Message - SaviPets Yellow Theme") {
    VStack(spacing: 12) {
        MessageBubble(
            message: ChatMessage(
                id: "1",
                senderId: "user2",
                text: "Hey! How's Bella doing today?",
                timestamp: Date(),
                deliveryStatus: "read",
                senderName: "SaviPets-Admin",
                isFromAdmin: true
            ),
            isFromCurrentUser: false,
            senderName: "SaviPets-Admin",
            showAvatar: true,
            showTimestamp: true
        )
        
        MessageBubble(
            message: ChatMessage(
                id: "3",
                senderId: "user2",
                text: "We're here to help! 🐾",
                timestamp: Date(),
                deliveryStatus: "read",
                senderName: "SaviPets-Admin",
                isFromAdmin: true
            ),
            isFromCurrentUser: false,
            senderName: "SaviPets-Admin",
            showAvatar: false,
            showTimestamp: false
        )
    }
    .padding()
    .background(SPDesignSystem.Colors.chatYellowLight)
}

#Preview("Outgoing Message - SaviPets Yellow Theme") {
    VStack(spacing: 12) {
        MessageBubble(
            message: ChatMessage(
                id: "2",
                senderId: "user1",
                text: "She's having a great time at the park! 🐕",
                timestamp: Date(),
                deliveryStatus: "read",
                senderName: nil,
                isFromAdmin: false
            ),
            isFromCurrentUser: true,
            showTimestamp: true
        )
        
        MessageBubble(
            message: ChatMessage(
                id: "4",
                senderId: "user1",
                text: "Thank you so much for checking in!",
                timestamp: Date(),
                deliveryStatus: "delivered",
                senderName: nil,
                isFromAdmin: false
            ),
            isFromCurrentUser: true,
            showTimestamp: true
        )
    }
    .padding()
    .background(SPDesignSystem.Colors.chatYellowLight)
}

#Preview("Chat Conversation - Full Theme") {
    ScrollView {
        VStack(spacing: 8) {
            // Incoming messages (Admin)
            MessageBubble(
                message: ChatMessage(
                    id: "1",
                    senderId: "admin1",
                    text: "Hello! How can I help you today?",
                    timestamp: Date().addingTimeInterval(-300),
                    deliveryStatus: "read",
                    senderName: "SaviPets-Admin",
                    isFromAdmin: true
                ),
                isFromCurrentUser: false,
                senderName: "SaviPets-Admin",
                showAvatar: true,
                showTimestamp: true
            )
            
            // Outgoing messages (User)
            MessageBubble(
                message: ChatMessage(
                    id: "2",
                    senderId: "user1",
                    text: "Hi! I need to book a pet sitting service.",
                    timestamp: Date().addingTimeInterval(-240),
                    deliveryStatus: "read",
                    senderName: nil,
                    isFromAdmin: false
                ),
                isFromCurrentUser: true,
                showTimestamp: true
            )
            
            // Incoming
            MessageBubble(
                message: ChatMessage(
                    id: "3",
                    senderId: "admin1",
                    text: "Of course! I can help you with that. What dates are you looking for? 🐾",
                    timestamp: Date().addingTimeInterval(-180),
                    deliveryStatus: "read",
                    senderName: "SaviPets-Admin",
                    isFromAdmin: true
                ),
                isFromCurrentUser: false,
                senderName: "SaviPets-Admin",
                showAvatar: false,
                showTimestamp: true
            )
            
            // Outgoing
            MessageBubble(
                message: ChatMessage(
                    id: "4",
                    senderId: "user1",
                    text: "Next weekend, Friday through Sunday.",
                    timestamp: Date().addingTimeInterval(-120),
                    deliveryStatus: "delivered",
                    senderName: nil,
                    isFromAdmin: false
                ),
                isFromCurrentUser: true,
                showTimestamp: true
            )
        }
        .padding()
    }
    .background(
        LinearGradient(
            colors: [Color.white, SPDesignSystem.Colors.chatYellowLight],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

