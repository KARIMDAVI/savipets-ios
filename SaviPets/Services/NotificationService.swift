import Foundation
import OSLog
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
                AppLogger.notification.info("Permission granted")
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                AppLogger.notification.info("Permission denied")
            }
        } catch {
            AppLogger.notification.info("Error requesting permission: \(error)")
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
                AppLogger.notification.info("Error sending notification: \(error)")
            } else {
                AppLogger.notification.info("Local notification sent successfully")
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
    
    // MARK: - Booking Notifications
    func sendBookingCreatedNotification(for booking: ServiceBooking, clientName: String) {
        let title = "New Booking Created"
        let body = "\(clientName) has created a new \(booking.serviceType) booking for \(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))"
        
        sendLocalNotification(
            title: title,
            body: body,
            userInfo: [
                "type": "booking_created",
                "bookingId": booking.id,
                "clientId": booking.clientId
            ]
        )
    }
    
    func sendBookingApprovedNotification(for booking: ServiceBooking, sitterName: String) {
        let title = "Booking Approved"
        let body = "Your \(booking.serviceType) booking has been approved. Sitter: \(sitterName)"
        
        sendLocalNotification(
            title: title,
            body: body,
            userInfo: [
                "type": "booking_approved",
                "bookingId": booking.id,
                "sitterId": booking.sitterId ?? ""
            ]
        )
    }
    
    func sendBookingRescheduledNotification(for booking: ServiceBooking, newDate: Date, reason: String?) {
        let title = "Booking Rescheduled"
        let body = "Your \(booking.serviceType) booking has been rescheduled to \(newDate.formatted(date: .abbreviated, time: .omitted))"
        
        var userInfo: [String: Any] = [
            "type": "booking_rescheduled",
            "bookingId": booking.id,
            "newDate": newDate.timeIntervalSince1970
        ]
        
        if let reason = reason {
            userInfo["reason"] = reason
        }
        
        sendLocalNotification(
            title: title,
            body: body,
            userInfo: userInfo
        )
    }
    
    func sendBookingCancelledNotification(for booking: ServiceBooking, reason: String?) {
        let title = "Booking Cancelled"
        let body = "Your \(booking.serviceType) booking for \(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted)) has been cancelled"
        
        var userInfo: [String: Any] = [
            "type": "booking_cancelled",
            "bookingId": booking.id
        ]
        
        if let reason = reason {
            userInfo["reason"] = reason
        }
        
        sendLocalNotification(
            title: title,
            body: body,
            userInfo: userInfo
        )
    }
    
    func sendUpcomingBookingReminder(for booking: ServiceBooking, timeBefore: TimeInterval) {
        let title = "Upcoming Booking Reminder"
        let timeString = formatTimeInterval(timeBefore)
        let body = "Your \(booking.serviceType) booking starts in \(timeString)"
        
        sendLocalNotification(
            title: title,
            body: body,
            userInfo: [
                "type": "booking_reminder",
                "bookingId": booking.id,
                "timeBefore": timeBefore
            ]
        )
    }
    
    func sendSitterAssignedNotification(for booking: ServiceBooking, sitterName: String) {
        let title = "Sitter Assigned"
        let body = "\(sitterName) has been assigned to your \(booking.serviceType) booking"
        
        sendLocalNotification(
            title: title,
            body: body,
            userInfo: [
                "type": "sitter_assigned",
                "bookingId": booking.id,
                "sitterId": booking.sitterId ?? "",
                "sitterName": sitterName
            ]
        )
    }
    
    func sendPaymentConfirmationNotification(for booking: ServiceBooking, amount: Double) {
        let title = "Payment Confirmed"
        let body = "Payment of $\(String(format: "%.2f", amount)) confirmed for your \(booking.serviceType) booking"
        
        sendLocalNotification(
            title: title,
            body: body,
            userInfo: [
                "type": "payment_confirmed",
                "bookingId": booking.id,
                "amount": amount
            ]
        )
    }
    
    // MARK: - Scheduled Notifications
    func scheduleBookingReminders(for booking: ServiceBooking) {
        let bookingDate = booking.scheduledDate
        let now = Date()
        
        // Schedule reminders at different intervals
        let reminderIntervals: [TimeInterval] = [
            24 * 60 * 60,  // 24 hours before
            2 * 60 * 60,   // 2 hours before
            30 * 60        // 30 minutes before
        ]
        
        for interval in reminderIntervals {
            let reminderDate = bookingDate.addingTimeInterval(-interval)
            
            // Only schedule if the reminder is in the future
            if reminderDate > now {
                scheduleNotification(
                    identifier: "booking_reminder_\(booking.id)_\(Int(interval))",
                    title: "Upcoming Booking Reminder",
                    body: "Your \(booking.serviceType) booking starts in \(formatTimeInterval(interval))",
                    date: reminderDate,
                    userInfo: [
                        "type": "booking_reminder",
                        "bookingId": booking.id,
                        "interval": interval
                    ]
                )
            }
        }
    }
    
    func cancelBookingReminders(for bookingId: String) {
        let identifiers = [
            "booking_reminder_\(bookingId)_\(24 * 60 * 60)",
            "booking_reminder_\(bookingId)_\(2 * 60 * 60)",
            "booking_reminder_\(bookingId)_\(30 * 60)"
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        AppLogger.notification.info("Cancelled reminders for booking: \(bookingId)")
    }
    
    private func scheduleNotification(identifier: String, title: String, body: String, date: Date, userInfo: [String: Any]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.notification.error("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                AppLogger.notification.info("Scheduled notification: \(identifier)")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Notification Categories
    func setupNotificationCategories() {
        let bookingActions = UNNotificationCategory(
            identifier: "BOOKING_ACTIONS",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_BOOKING",
                    title: "View Details",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "RESCHEDULE",
                    title: "Reschedule",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "CANCEL",
                    title: "Cancel",
                    options: [.destructive]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([bookingActions])
    }
}
