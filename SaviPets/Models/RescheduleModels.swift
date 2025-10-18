import Foundation
import FirebaseFirestore

// MARK: - Reschedule Models

/// Represents a single reschedule event in a booking's history
struct RescheduleEntry: Codable, Identifiable {
    let id: String
    let originalDate: Date
    let newDate: Date
    let reason: String
    let requestedBy: String // userId who requested the reschedule
    let requestedAt: Date
    let approvedBy: String? // userId who approved (nil if auto-approved)
    let approvedAt: Date?
    let status: RescheduleStatus
    
    init(
        originalDate: Date,
        newDate: Date,
        reason: String,
        requestedBy: String,
        status: RescheduleStatus = .pending
    ) {
        self.id = UUID().uuidString
        self.originalDate = originalDate
        self.newDate = newDate
        self.reason = reason
        self.requestedBy = requestedBy
        self.requestedAt = Date()
        self.approvedBy = nil
        self.approvedAt = nil
        self.status = status
    }
    
}

/// Status of a reschedule request
enum RescheduleStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .approved: return "green"
        case .rejected: return "red"
        case .cancelled: return "gray"
        }
    }
}

/// Represents a reschedule request with additional metadata
struct RescheduleRequest: Codable, Identifiable {
    let id: String
    let bookingId: String
    let clientId: String
    let originalDate: Date
    let newDate: Date
    let reason: String
    let requestedBy: String
    let requestedAt: Date
    let status: RescheduleStatus
    let sitterId: String?
    let sitterName: String?
    let serviceType: String
    let duration: Int // minutes
    
    // Business rule validation
    let hoursUntilOriginalVisit: Double
    let hoursUntilNewVisit: Double
    let isWithinBusinessHours: Bool
    let hasConflict: Bool
    
    init(
        bookingId: String,
        clientId: String,
        originalDate: Date,
        newDate: Date,
        reason: String,
        requestedBy: String,
        sitterId: String? = nil,
        sitterName: String? = nil,
        serviceType: String,
        duration: Int
    ) {
        self.id = UUID().uuidString
        self.bookingId = bookingId
        self.clientId = clientId
        self.originalDate = originalDate
        self.newDate = newDate
        self.reason = reason
        self.requestedBy = requestedBy
        self.requestedAt = Date()
        self.status = .pending
        self.sitterId = sitterId
        self.sitterName = sitterName
        self.serviceType = serviceType
        self.duration = duration
        
        // Calculate business rule metrics
        let now = Date()
        self.hoursUntilOriginalVisit = originalDate.timeIntervalSince(now) / 3600
        self.hoursUntilNewVisit = newDate.timeIntervalSince(now) / 3600
        
        // Check if new date is within business hours (8 AM - 8 PM)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: newDate)
        self.isWithinBusinessHours = hour >= 8 && hour <= 20
        
        // Conflict detection will be set by the service
        self.hasConflict = false
    }
}

/// Result of a reschedule operation
struct RescheduleResult {
    let success: Bool
    let bookingId: String
    let newDate: Date
    let reason: String?
    var conflictDetected: Bool
    var businessRulesViolated: [BusinessRuleViolation]
    let refundEligible: Bool
    let refundAmount: Double?
    var message: String
    
    enum BusinessRuleViolation: String, CaseIterable {
        case tooLate = "too_late" // Less than 2 hours notice
        case outsideBusinessHours = "outside_business_hours"
        case sitterConflict = "sitter_conflict"
        case invalidDate = "invalid_date"
        case noReasonProvided = "no_reason_provided"
        case bookingNotModifiable = "booking_not_modifiable"
        
        var displayMessage: String {
            switch self {
            case .tooLate: return "Cannot reschedule within 2 hours of scheduled visit"
            case .outsideBusinessHours: return "New time is outside business hours (8 AM - 8 PM)"
            case .sitterConflict: return "Sitter is not available at the requested time"
            case .invalidDate: return "New date must be in the future"
            case .noReasonProvided: return "Please provide a reason for rescheduling"
            case .bookingNotModifiable: return "This booking cannot be rescheduled"
            }
        }
    }
}

/// Configuration for reschedule business rules
struct RescheduleBusinessRules {
    let minimumNoticeHours: Double
    let businessHoursStart: Int // 24-hour format
    let businessHoursEnd: Int // 24-hour format
    let allowWeekendReschedules: Bool
    let maxReschedulesPerBooking: Int
    let autoApproveThresholdHours: Double
    
    static let `default` = RescheduleBusinessRules(
        minimumNoticeHours: 2.0,
        businessHoursStart: 8,
        businessHoursEnd: 20,
        allowWeekendReschedules: true,
        maxReschedulesPerBooking: 3,
        autoApproveThresholdHours: 24.0
    )
}

/// Analytics data for reschedule operations
struct RescheduleAnalytics {
    let totalReschedules: Int
    let successfulReschedules: Int
    let failedReschedules: Int
    let averageNoticeTime: Double // hours
    let commonReasons: [String: Int]
    let conflictRate: Double
    let businessHoursCompliance: Double
    
    var successRate: Double {
        guard totalReschedules > 0 else { return 0 }
        return Double(successfulReschedules) / Double(totalReschedules)
    }
}

// MARK: - Firestore Extensions

extension RescheduleEntry {
    /// Convert to Firestore document data
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "originalDate": Timestamp(date: originalDate),
            "newDate": Timestamp(date: newDate),
            "reason": reason,
            "requestedBy": requestedBy,
            "requestedAt": Timestamp(date: requestedAt),
            "approvedBy": approvedBy as Any,
            "approvedAt": approvedAt.map { Timestamp(date: $0) } as Any,
            "status": status.rawValue
        ]
    }
    
    /// Create from Firestore document data
    static func fromFirestoreData(_ data: [String: Any]) -> RescheduleEntry? {
        guard let id = data["id"] as? String,
              let originalDate = (data["originalDate"] as? Timestamp)?.dateValue(),
              let newDate = (data["newDate"] as? Timestamp)?.dateValue(),
              let reason = data["reason"] as? String,
              let requestedBy = data["requestedBy"] as? String,
              let requestedAt = (data["requestedAt"] as? Timestamp)?.dateValue(),
              let statusString = data["status"] as? String,
              let status = RescheduleStatus(rawValue: statusString) else {
            return nil
        }
        
        var entry = RescheduleEntry(
            originalDate: originalDate,
            newDate: newDate,
            reason: reason,
            requestedBy: requestedBy,
            status: status
        )
        
        // Manually set the id since it's not mutable
        entry = RescheduleEntry(
            id: id,
            originalDate: originalDate,
            newDate: newDate,
            reason: reason,
            requestedBy: requestedBy,
            requestedAt: requestedAt,
            approvedBy: data["approvedBy"] as? String,
            approvedAt: (data["approvedAt"] as? Timestamp)?.dateValue(),
            status: status
        )
        
        return entry
    }
    
    private init(
        id: String,
        originalDate: Date,
        newDate: Date,
        reason: String,
        requestedBy: String,
        requestedAt: Date,
        approvedBy: String?,
        approvedAt: Date?,
        status: RescheduleStatus
    ) {
        self.id = id
        self.originalDate = originalDate
        self.newDate = newDate
        self.reason = reason
        self.requestedBy = requestedBy
        self.requestedAt = requestedAt
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.status = status
    }
}

extension RescheduleRequest {
    /// Convert to Firestore document data
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "bookingId": bookingId,
            "clientId": clientId,
            "originalDate": Timestamp(date: originalDate),
            "newDate": Timestamp(date: newDate),
            "reason": reason,
            "requestedBy": requestedBy,
            "requestedAt": Timestamp(date: requestedAt),
            "status": status.rawValue,
            "sitterId": sitterId as Any,
            "sitterName": sitterName as Any,
            "serviceType": serviceType,
            "duration": duration,
            "hoursUntilOriginalVisit": hoursUntilOriginalVisit,
            "hoursUntilNewVisit": hoursUntilNewVisit,
            "isWithinBusinessHours": isWithinBusinessHours,
            "hasConflict": hasConflict
        ]
    }
}
