import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import Combine
import UIKit

/// Smart notification manager that batches notifications to prevent spam
final class SmartNotificationManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SmartNotificationManager()
    
    // MARK: - Published Properties
    @Published var isNotificationEnabled: Bool = false
    @Published var pendingNotifications: [String: [ChatNotification]] = [:]
    
    // MARK: - Private Properties
    private let batchDelay: TimeInterval = 3.0
    private let maxBatchSize = 5
    private var batchTimers: [String: Timer] = [:]
    private var lastNotificationTimes: [String: Date] = [:]
    private let minimumIntervalBetweenNotifications: TimeInterval = 2.0
    
    // MARK: - Notification Categories
    private let chatNotificationCategory = "CHAT_MESSAGE"
    private let approvalNotificationCategory = "MESSAGE_APPROVAL"
    private let systemNotificationCategory = "SYSTEM_MESSAGE"
    
    // MARK: - Singleton
    private init() {
        setupNotificationCategories()
        checkNotificationPermission()
    }
    
    // MARK: - Public Methods
    
    /// Request notification permission
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            await MainActor.run {
                self.isNotificationEnabled = granted
            }
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("SmartNotificationManager: Notification permission granted")
            } else {
                print("SmartNotificationManager: Notification permission denied")
            }
            
            return granted
        } catch {
            print("SmartNotificationManager: Error requesting notification permission: \(error)")
            return false
        }
    }
    
    /// Schedule a chat notification (with smart batching)
    func scheduleChatNotification(
        conversationId: String,
        messageId: String,
        senderName: String,
        messageText: String,
        isAdmin: Bool = false
    ) {
        // Check if notifications are enabled
        guard isNotificationEnabled else {
            print("SmartNotificationManager: Notifications disabled, skipping")
            return
        }
        
        // Check rate limiting
        guard shouldSendNotification(for: conversationId) else {
            print("SmartNotificationManager: Rate limited, skipping notification")
            return
        }
        
        let notification = ChatNotification(
            conversationId: conversationId,
            messageId: messageId,
            senderName: senderName,
            messageText: messageText,
            isAdmin: isAdmin
        )
        
        // Add to pending notifications
        pendingNotifications[conversationId, default: []].append(notification)
        
        // Cancel existing timer if any
        batchTimers[conversationId]?.invalidate()
        
        // Schedule batched notification
        let timer = Timer.scheduledTimer(withTimeInterval: batchDelay, repeats: false) { [weak self] _ in
            Task {
                await self?.sendBatchedNotification(for: conversationId)
            }
        }
        
        batchTimers[conversationId] = timer
        lastNotificationTimes[conversationId] = Date()
        
        print("SmartNotificationManager: Scheduled notification for conversation \(conversationId)")
    }
    
    /// Send immediate notification (for urgent messages)
    func sendImmediateNotification(
        title: String,
        body: String,
        category: String = "IMMEDIATE",
        userInfo: [String: Any] = [:]
    ) {
        guard isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("SmartNotificationManager: Error sending immediate notification: \(error)")
            } else {
                print("SmartNotificationManager: Immediate notification sent successfully")
            }
        }
    }
    
    /// Send message approval notification
    func sendApprovalNotification(
        messageId: String,
        status: MessageStatus,
        reason: String? = nil
    ) {
        guard isNotificationEnabled else { return }
        
        let title: String
        let body: String
        
        switch status {
        case .sent:
            title = "Message Approved"
            body = "Your message has been approved and sent"
        case .rejected:
            title = "Message Rejected"
            body = reason ?? "Your message was rejected"
        default:
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = approvalNotificationCategory
        content.userInfo = [
            "messageId": messageId,
            "status": status.rawValue
        ]
        
        let request = UNNotificationRequest(
            identifier: "approval_\(messageId)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("SmartNotificationManager: Error sending approval notification: \(error)")
            } else {
                print("SmartNotificationManager: Approval notification sent successfully")
            }
        }
    }
    
    /// Send auto-reply notification
    func sendAutoReplyNotification() {
        guard isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "SaviPets Support"
        content.body = "We'll be in touch ASAP"
        content.sound = .default
        content.categoryIdentifier = systemNotificationCategory
        content.userInfo = ["type": "auto-reply"]
        
        let request = UNNotificationRequest(
            identifier: "auto-reply-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("SmartNotificationManager: Error sending auto-reply notification: \(error)")
            } else {
                print("SmartNotificationManager: Auto-reply notification sent successfully")
            }
        }
    }
    
    /// Clear all pending notifications
    func clearPendingNotifications() {
        // Cancel all timers
        for timer in batchTimers.values {
            timer.invalidate()
        }
        batchTimers.removeAll()
        
        // Clear pending notifications
        pendingNotifications.removeAll()
        
        print("SmartNotificationManager: Cleared all pending notifications")
    }
    
    /// Clear notifications for a specific conversation
    func clearNotifications(for conversationId: String) {
        batchTimers[conversationId]?.invalidate()
        batchTimers.removeValue(forKey: conversationId)
        pendingNotifications.removeValue(forKey: conversationId)
        
        print("SmartNotificationManager: Cleared notifications for conversation \(conversationId)")
    }
    
    // MARK: - Private Methods
    
    private func sendBatchedNotification(for conversationId: String) async {
        guard let notifications = pendingNotifications[conversationId],
              !notifications.isEmpty else { return }
        
        // Clear the pending notifications
        pendingNotifications.removeValue(forKey: conversationId)
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = chatNotificationCategory
        content.userInfo = [
            "conversationId": conversationId,
            "type": "chat"
        ]
        
        if notifications.count == 1 {
            // Single message notification
            let notification = notifications[0]
            content.title = notification.isAdmin ? "Admin Reply" : "New Message"
            content.body = "\(notification.senderName): \(notification.messageText)"
        } else {
            // Multiple messages notification
            guard let latestNotification = notifications.last else { return }
            let senderNames = Set(notifications.map { $0.senderName })
            
            if senderNames.count == 1 {
                // All from same sender
                content.title = notifications[0].isAdmin ? "Admin Messages" : "New Messages"
                content.body = "\(notifications.count) messages from \(senderNames.first ?? "Unknown")"
            } else {
                // From multiple senders
                content.title = "New Messages"
                content.body = "\(notifications.count) new messages"
            }
        }
        
        let request = UNNotificationRequest(
            identifier: "chat_\(conversationId)_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("SmartNotificationManager: Sent batched notification for conversation \(conversationId)")
        } catch {
            print("SmartNotificationManager: Error sending batched notification: \(error)")
        }
    }
    
    private func shouldSendNotification(for conversationId: String) -> Bool {
        guard let lastTime = lastNotificationTimes[conversationId] else {
            return true
        }
        
        return Date().timeIntervalSince(lastTime) >= minimumIntervalBetweenNotifications
    }
    
    private func setupNotificationCategories() {
        // Chat notification category with reply action
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type your message..."
        )
        
        let markAsReadAction = UNNotificationAction(
            identifier: "MARK_AS_READ_ACTION",
            title: "Mark as Read",
            options: []
        )
        
        let chatCategory = UNNotificationCategory(
            identifier: chatNotificationCategory,
            actions: [replyAction, markAsReadAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Approval notification category
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View",
            options: [.foreground]
        )
        
        let approvalCategory = UNNotificationCategory(
            identifier: approvalNotificationCategory,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // System notification category
        let systemCategory = UNNotificationCategory(
            identifier: systemNotificationCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([
            chatCategory,
            approvalCategory,
            systemCategory
        ])
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Analytics
    
    func getNotificationStats() -> NotificationStats {
        let totalPending = pendingNotifications.values.flatMap { $0 }.count
        let activeBatches = batchTimers.count
        
        return NotificationStats(
            totalPendingNotifications: totalPending,
            activeBatches: activeBatches,
            isEnabled: isNotificationEnabled
        )
    }
}

// MARK: - Notification Stats

struct NotificationStats {
    let totalPendingNotifications: Int
    let activeBatches: Int
    let isEnabled: Bool
}

// MARK: - Notification Extensions

extension SmartNotificationManager {
    
    /// Handle notification actions
    func handleNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse,
               let conversationId = userInfo["conversationId"] as? String {
                // Handle quick reply
                handleQuickReply(conversationId: conversationId, text: textResponse.userText)
            }
            
        case "MARK_AS_READ_ACTION":
            if let conversationId = userInfo["conversationId"] as? String {
                // Mark conversation as read
                markConversationAsRead(conversationId: conversationId)
            }
            
        case "VIEW_ACTION":
            if let conversationId = userInfo["conversationId"] as? String {
                // Navigate to conversation
                navigateToConversation(conversationId: conversationId)
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleQuickReply(conversationId: String, text: String) {
        // This would integrate with the chat service to send a quick reply
        print("SmartNotificationManager: Quick reply to \(conversationId): \(text)")
        
        // Post notification to app to handle quick reply
        NotificationCenter.default.post(
            name: .quickReply,
            object: nil,
            userInfo: [
                "conversationId": conversationId,
                "text": text
            ]
        )
    }
    
    private func markConversationAsRead(conversationId: String) {
        // This would integrate with the chat service to mark as read
        print("SmartNotificationManager: Marking conversation \(conversationId) as read")
        
        // Post notification to app
        NotificationCenter.default.post(
            name: .markConversationAsRead,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }
    
    private func navigateToConversation(conversationId: String) {
        // This would integrate with the app's navigation
        print("SmartNotificationManager: Navigating to conversation \(conversationId)")
        
        // Post notification to app
        NotificationCenter.default.post(
            name: .navigateToConversation,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let quickReply = Notification.Name("quickReply")
    static let markConversationAsRead = Notification.Name("markConversationAsRead")
    static let navigateToConversation = Notification.Name("navigateToConversation")
}

// MARK: - Push Notification Support

extension SmartNotificationManager {
    
    /// Register for push notifications
    func registerForPushNotifications() async {
        guard isNotificationEnabled else { return }
        
        do {
            let token = try await Messaging.messaging().token()
            print("SmartNotificationManager: FCM Token: \(token)")
            
            // Send token to server for targeted notifications
            await sendTokenToServer(token: token)
            
        } catch {
            print("SmartNotificationManager: Error getting FCM token: \(error)")
        }
    }
    
    private func sendTokenToServer(token: String) async {
        // This would send the FCM token to your server for targeted push notifications
        print("SmartNotificationManager: Sending FCM token to server: \(token)")
        
        // Example implementation:
        // let url = URL(string: "https://your-server.com/api/fcm-tokens")!
        // var request = URLRequest(url: url)
        // request.httpMethod = "POST"
        // request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 
        // let body = ["token": token, "userId": Auth.auth().currentUser?.uid]
        // request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        // 
        // let (_, response) = try await URLSession.shared.data(for: request)
        // print("SmartNotificationManager: Token sent to server: \(response)")
    }
    
    /// Handle push notification
    func handlePushNotification(userInfo: [AnyHashable: Any]) {
        print("SmartNotificationManager: Received push notification: \(userInfo)")
        
        // Handle different types of push notifications
        if let type = userInfo["type"] as? String {
            switch type {
            case "chat":
                // Handle chat notification
                break
            case "approval":
                // Handle approval notification
                break
            case "system":
                // Handle system notification
                break
            default:
                break
            }
        }
    }
}
