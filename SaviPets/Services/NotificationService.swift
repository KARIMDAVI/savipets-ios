import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import Combine
import UIKit

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    private init() {}
    
    // MARK: - Request Permission
    func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            if granted {
                print("NotificationService: Permission granted")
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("NotificationService: Permission denied")
            }
        } catch {
            print("NotificationService: Error requesting permission: \(error)")
        }
    }
    
    // MARK: - Send Local Notification
    func sendLocalNotification(title: String, body: String, userInfo: [String: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationService: Error sending notification: \(error)")
            } else {
                print("NotificationService: Local notification sent successfully")
            }
        }
    }
    
    // MARK: - Chat Notifications
    func sendChatNotification(conversationId: String, message: String, senderName: String, isAdmin: Bool) {
        let title = isAdmin ? "Admin Reply" : "New Message"
        let body = isAdmin ? "\(senderName): \(message)" : "\(senderName): \(message)"
        
        sendLocalNotification(
            title: title,
            body: body,
            userInfo: [
                "conversationId": conversationId,
                "type": "chat"
            ]
        )
    }
    
    // MARK: - Auto-Reply Notification
    func sendAutoReplyNotification() {
        sendLocalNotification(
            title: "SaviPets Support",
            body: "We'll be in touch ASAP",
            userInfo: ["type": "auto-reply"]
        )
    }
    
    // MARK: - Check Permission Status
    func checkPermissionStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
