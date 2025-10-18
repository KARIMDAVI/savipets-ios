import Foundation
import SwiftUI
import FirebaseAnalytics
import OSLog

/// Centralized analytics manager for tracking key events
enum AnalyticsManager {
    
    // MARK: - Event Names
    
    private enum Event {
        static let bookingCreated = "booking_created"
        static let bookingApproved = "booking_approved"
        static let bookingCompleted = "booking_completed"
        static let visitStarted = "visit_started"
        static let visitEnded = "visit_ended"
        static let visitOvertime = "visit_overtime"
        static let chatMessageSent = "chat_message_sent"
        static let petProfileCreated = "pet_profile_created"
        static let petProfileUpdated = "pet_profile_updated"
        static let userSignIn = "user_sign_in"
        static let userSignUp = "user_sign_up"
        static let userSignOut = "user_sign_out"
        static let errorOccurred = "error_occurred"
        static let featureUsed = "feature_used"
    }
    
    // MARK: - Parameter Keys
    
    private enum Parameter {
        static let serviceType = "service_type"
        static let price = "price"
        static let duration = "duration"
        static let sitterId = "sitter_id"
        static let clientId = "client_id"
        static let visitId = "visit_id"
        static let bookingId = "booking_id"
        static let conversationId = "conversation_id"
        static let petId = "pet_id"
        static let petType = "pet_type"
        static let errorType = "error_type"
        static let errorMessage = "error_message"
        static let featureName = "feature_name"
        static let userRole = "user_role"
        static let messageLength = "message_length"
        static let overtimeMinutes = "overtime_minutes"
    }
    
    // MARK: - Booking Events
    
    static func trackBookingCreated(
        serviceType: String,
        price: String,
        duration: Int,
        sitterId: String,
        clientId: String
    ) {
        Analytics.logEvent(Event.bookingCreated, parameters: [
            Parameter.serviceType: serviceType,
            Parameter.price: price,
            Parameter.duration: duration,
            Parameter.sitterId: sitterId,
            Parameter.clientId: clientId,
        ])
        
        AppLogger.data.info("Analytics: Booking created - \(serviceType), $\(price)")
    }
    
    static func trackBookingApproved(
        bookingId: String,
        serviceType: String,
        sitterId: String
    ) {
        Analytics.logEvent(Event.bookingApproved, parameters: [
            Parameter.bookingId: bookingId,
            Parameter.serviceType: serviceType,
            Parameter.sitterId: sitterId,
        ])
        
        AppLogger.data.info("Analytics: Booking approved - \(bookingId)")
    }
    
    static func trackBookingCompleted(
        bookingId: String,
        serviceType: String,
        price: String
    ) {
        Analytics.logEvent(Event.bookingCompleted, parameters: [
            Parameter.bookingId: bookingId,
            Parameter.serviceType: serviceType,
            Parameter.price: price,
        ])
        
        AppLogger.data.info("Analytics: Booking completed - \(bookingId), $\(price)")
    }
    
    // MARK: - Visit Events
    
    static func trackVisitStarted(
        visitId: String,
        sitterId: String,
        clientId: String,
        serviceType: String
    ) {
        Analytics.logEvent(Event.visitStarted, parameters: [
            Parameter.visitId: visitId,
            Parameter.sitterId: sitterId,
            Parameter.clientId: clientId,
            Parameter.serviceType: serviceType,
        ])
        
        AppLogger.timer.info("Analytics: Visit started - \(visitId)")
    }
    
    static func trackVisitEnded(
        visitId: String,
        sitterId: String,
        duration: Int,
        wasOvertime: Bool = false
    ) {
        Analytics.logEvent(Event.visitEnded, parameters: [
            Parameter.visitId: visitId,
            Parameter.sitterId: sitterId,
            Parameter.duration: duration,
            "was_overtime": wasOvertime,
        ])
        
        AppLogger.timer.info("Analytics: Visit ended - \(visitId), duration: \(duration)min")
    }
    
    static func trackVisitOvertime(
        visitId: String,
        overtimeMinutes: Int
    ) {
        Analytics.logEvent(Event.visitOvertime, parameters: [
            Parameter.visitId: visitId,
            Parameter.overtimeMinutes: overtimeMinutes,
        ])
        
        AppLogger.timer.warning("Analytics: Visit overtime - \(visitId), +\(overtimeMinutes)min")
    }
    
    // MARK: - Chat Events
    
    static func trackMessageSent(
        conversationId: String,
        messageLength: Int,
        senderRole: String,
        isAdminInquiry: Bool = false
    ) {
        Analytics.logEvent(Event.chatMessageSent, parameters: [
            Parameter.conversationId: conversationId,
            Parameter.messageLength: messageLength,
            Parameter.userRole: senderRole,
            "is_admin_inquiry": isAdminInquiry,
        ])
        
        AppLogger.chat.info("Analytics: Message sent - \(conversationId), length: \(messageLength)")
    }
    
    // MARK: - Pet Events
    
    static func trackPetProfileCreated(
        petId: String,
        petType: String,
        ownerId: String
    ) {
        Analytics.logEvent(Event.petProfileCreated, parameters: [
            Parameter.petId: petId,
            Parameter.petType: petType,
            Parameter.clientId: ownerId,
        ])
        
        AppLogger.data.info("Analytics: Pet profile created - \(petType)")
    }
    
    static func trackPetProfileUpdated(
        petId: String,
        petType: String
    ) {
        Analytics.logEvent(Event.petProfileUpdated, parameters: [
            Parameter.petId: petId,
            Parameter.petType: petType,
        ])
        
        AppLogger.data.info("Analytics: Pet profile updated - \(petId)")
    }
    
    // MARK: - User Events
    
    static func trackUserSignIn(
        userId: String,
        role: UserRole,
        method: String = "email"
    ) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method,
            Parameter.userRole: role.rawValue,
        ])
        
        // Set user properties for segmentation
        Analytics.setUserID(userId)
        Analytics.setUserProperty(role.rawValue, forName: "user_role")
        
        AppLogger.auth.info("Analytics: User signed in - \(role.rawValue)")
    }
    
    static func trackUserSignUp(
        userId: String,
        role: UserRole,
        method: String = "email"
    ) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: method,
            Parameter.userRole: role.rawValue,
        ])
        
        // Set user properties
        Analytics.setUserID(userId)
        Analytics.setUserProperty(role.rawValue, forName: "user_role")
        
        AppLogger.auth.info("Analytics: User signed up - \(role.rawValue)")
    }
    
    static func trackUserSignOut() {
        Analytics.logEvent("user_sign_out", parameters: nil)
        
        // Clear user properties
        Analytics.setUserID(nil)
        
        AppLogger.auth.info("Analytics: User signed out")
    }
    
    // MARK: - Error Events
    
    static func trackError(
        error: Error,
        context: String,
        isCritical: Bool = false
    ) {
        Analytics.logEvent(Event.errorOccurred, parameters: [
            Parameter.errorType: String(describing: type(of: error)),
            Parameter.errorMessage: error.localizedDescription,
            "context": context,
            "is_critical": isCritical,
        ])
        
        AppLogger.ui.error("Analytics: Error tracked - \(context): \(error.localizedDescription)")
    }
    
    // MARK: - Feature Usage Events
    
    static func trackFeatureUsed(
        feature: String,
        userRole: UserRole,
        metadata: [String: Any]? = nil
    ) {
        var parameters: [String: Any] = [
            Parameter.featureName: feature,
            Parameter.userRole: userRole.rawValue,
        ]
        
        if let metadata = metadata {
            parameters.merge(metadata) { _, new in new }
        }
        
        Analytics.logEvent(Event.featureUsed, parameters: parameters)
        
        AppLogger.ui.info("Analytics: Feature used - \(feature)")
    }
    
    // MARK: - Screen View Events
    
    static func trackScreenView(
        screenName: String,
        screenClass: String? = nil
    ) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName,
        ])
        
        AppLogger.ui.debug("Analytics: Screen view - \(screenName)")
    }
    
    // MARK: - Custom Conversion Events
    
    static func trackConversion(
        type: String,
        value: Double,
        currency: String = "USD"
    ) {
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterValue: value,
            AnalyticsParameterCurrency: currency,
            "conversion_type": type,
        ])
        
        AppLogger.data.info("Analytics: Conversion - \(type), $\(value)")
    }
}

// MARK: - View Modifier for Screen Tracking

extension View {
    /// Automatically track screen views
    func trackScreen(name: String, class className: String? = nil) -> some View {
        self.onAppear {
            AnalyticsManager.trackScreenView(screenName: name, screenClass: className)
        }
    }
}

