import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog

/// Service responsible for handling booking rescheduling operations
final class BookingRescheduleService {
    private let db = Firestore.firestore()
    private let businessRules = RescheduleBusinessRules.default
    
    /// Reschedule a booking to a new date/time with comprehensive validation
    func rescheduleBooking(
        bookingId: String,
        newDate: Date,
        reason: String,
        requestedBy: String
    ) async throws -> RescheduleResult {
        
        AppLogger.data.info("Starting reschedule process for booking: \(bookingId)")
        
        // Step 1: Validate business rules
        let validationResult = try await validateRescheduleRequest(
            bookingId: bookingId,
            newDate: newDate,
            reason: reason,
            requestedBy: requestedBy
        )
        
        guard validationResult.businessRulesViolated.isEmpty else {
            AppLogger.data.warning("Reschedule validation failed: \(validationResult.businessRulesViolated)")
            return validationResult
        }
        
        // Step 2: Check for sitter conflicts
        let hasConflict = try await checkSitterConflict(
            bookingId: bookingId,
            newDate: newDate
        )
        
        if hasConflict {
            var result = validationResult
            result.conflictDetected = true
            result.businessRulesViolated.append(.sitterConflict)
            result.message = "Sitter is not available at the requested time"
            return result
        }
        
        // Step 3: Perform the reschedule
        try await performReschedule(
            bookingId: bookingId,
            newDate: newDate,
            reason: reason,
            requestedBy: requestedBy
        )
        
        // Step 4: Send notifications
        await sendRescheduleNotifications(
            bookingId: bookingId,
            newDate: newDate,
            reason: reason
        )
        
        AppLogger.data.info("Reschedule completed successfully for booking: \(bookingId)")
        
        return RescheduleResult(
            success: true,
            bookingId: bookingId,
            newDate: newDate,
            reason: reason,
            conflictDetected: false,
            businessRulesViolated: [],
            refundEligible: false, // Rescheduling doesn't trigger refunds
            refundAmount: nil,
            message: "Booking rescheduled successfully"
        )
    }
    
    /// Validate a reschedule request against business rules
    private func validateRescheduleRequest(
        bookingId: String,
        newDate: Date,
        reason: String,
        requestedBy: String
    ) async throws -> RescheduleResult {
        
        // Get the booking
        let booking = try await getBooking(bookingId: bookingId)
        
        var violations: [RescheduleResult.BusinessRuleViolation] = []
        
        // Check if booking can be modified
        if !canModifyBooking(booking) {
            violations.append(.bookingNotModifiable)
        }
        
        // Check minimum notice requirement
        let hoursUntilNewVisit = newDate.timeIntervalSince(Date()) / 3600
        if hoursUntilNewVisit < businessRules.minimumNoticeHours {
            violations.append(.tooLate)
        }
        
        // Check business hours
        if !isWithinBusinessHours(newDate) {
            violations.append(.outsideBusinessHours)
        }
        
        // Check if date is in the future
        if newDate <= Date() {
            violations.append(.invalidDate)
        }
        
        // Check if reason is provided
        if reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            violations.append(.noReasonProvided)
        }
        
        // Check max reschedules per booking
        if booking.rescheduleHistory.count >= businessRules.maxReschedulesPerBooking {
            violations.append(.bookingNotModifiable)
        }
        
        return RescheduleResult(
            success: violations.isEmpty,
            bookingId: bookingId,
            newDate: newDate,
            reason: reason,
            conflictDetected: false,
            businessRulesViolated: violations,
            refundEligible: false,
            refundAmount: nil,
            message: violations.isEmpty ? "Validation passed" : "Validation failed"
        )
    }
    
    /// Check if there are any sitter conflicts at the new time
    func checkSitterConflict(
        bookingId: String,
        newDate: Date
    ) async throws -> Bool {
        
        let booking = try await getBooking(bookingId: bookingId)
        guard let sitterId = booking.sitterId else {
            // No sitter assigned, no conflict possible
            return false
        }
        
        let startTime = newDate
        let endTime = newDate.addingTimeInterval(TimeInterval(booking.duration * 60))
        
        // Query for conflicting bookings
        let conflictQuery = db.collection("serviceBookings")
            .whereField("sitterId", isEqualTo: sitterId)
            .whereField("status", in: ["approved", "in_adventure"])
            .whereField("scheduledDate", isGreaterThan: Timestamp(date: startTime.addingTimeInterval(-3600)))
            .whereField("scheduledDate", isLessThan: Timestamp(date: endTime.addingTimeInterval(3600)))
        
        let snapshot = try await conflictQuery.getDocuments()
        
        for doc in snapshot.documents {
            // Skip the current booking being rescheduled
            if doc.documentID != bookingId {
                let data = doc.data()
                let existingDate = (data["scheduledDate"] as? Timestamp)?.dateValue() ?? Date()
                let existingDuration = data["duration"] as? Int ?? 0
                let existingEnd = existingDate.addingTimeInterval(TimeInterval(existingDuration * 60))
                
                // Check for time overlap
                if (startTime < existingEnd && endTime > existingDate) {
                    AppLogger.data.info("Sitter conflict detected: \(sitterId) at \(newDate)")
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Perform the actual reschedule operation
    private func performReschedule(
        bookingId: String,
        newDate: Date,
        reason: String,
        requestedBy: String
    ) async throws {
        
        let booking = try await getBooking(bookingId: bookingId)
        
        // Create new reschedule entry
        let rescheduleEntry = RescheduleEntry(
            originalDate: booking.scheduledDate,
            newDate: newDate,
            reason: reason,
            requestedBy: requestedBy,
            status: .approved
        )
        
        // Update reschedule history
        var updatedHistory = booking.rescheduleHistory
        updatedHistory.append(rescheduleEntry)
        
        // Format new time
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let newScheduledTime = timeFormatter.string(from: newDate)
        
        // Update booking document
        let bookingRef = db.collection("serviceBookings").document(bookingId)
        let updateData: [String: Any] = [
            "scheduledDate": Timestamp(date: newDate),
            "scheduledTime": newScheduledTime,
            "rescheduledFrom": Timestamp(date: booking.scheduledDate),
            "rescheduledAt": FieldValue.serverTimestamp(),
            "rescheduledBy": requestedBy,
            "rescheduleReason": reason,
            "rescheduleHistory": updatedHistory.map { entry in
                [
                    "originalDate": entry.originalDate,
                    "newDate": entry.newDate,
                    "requestedBy": entry.requestedBy,
                    "requestedAt": entry.requestedAt,
                    "reason": entry.reason,
                    "status": entry.status.rawValue
                ]
            },
            "lastModified": FieldValue.serverTimestamp(),
            "lastModifiedBy": requestedBy,
            "modificationReason": "Rescheduled: \(reason)"
        ]
        
        try await bookingRef.updateData(updateData)
        
        // Create reschedule request document for audit trail
        let rescheduleRequest = RescheduleRequest(
            bookingId: bookingId,
            clientId: booking.clientId,
            originalDate: booking.scheduledDate,
            newDate: newDate,
            reason: reason,
            requestedBy: requestedBy,
            sitterId: booking.sitterId,
            sitterName: booking.sitterName,
            serviceType: booking.serviceType,
            duration: booking.duration
        )
        
        try await db.collection("rescheduleRequests").document(rescheduleRequest.id).setData(rescheduleRequest.toFirestoreData())
        
        AppLogger.data.info("Booking \(bookingId) rescheduled from \(booking.scheduledDate) to \(newDate)")
    }
    
    /// Get booking by ID
    private func getBooking(bookingId: String) async throws -> ServiceBooking {
        let doc = try await db.collection("serviceBookings").document(bookingId).getDocument()
        
        guard doc.exists, let data = doc.data() else {
            throw BookingError.bookingNotFound
        }
        
        // Parse the booking data
        let duration: Int = (data["duration"] as? Int) ?? (data["duration"] as? Double).map { Int($0) } ?? 30
        let timeline = data["timeline"] as? [String: Any]
        let checkIn = ((timeline?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
        let checkOut = ((timeline?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
        
        // Parse reschedule history
        let rescheduleHistoryData = data["rescheduleHistory"] as? [[String: Any]] ?? []
        let rescheduleHistory = rescheduleHistoryData.compactMap { RescheduleEntry.fromFirestoreData($0) }
        
        return ServiceBooking(
            id: doc.documentID,
            clientId: data["clientId"] as? String ?? "",
            serviceType: data["serviceType"] as? String ?? "",
            scheduledDate: (data["scheduledDate"] as? Timestamp)?.dateValue() ?? Date(),
            scheduledTime: data["scheduledTime"] as? String ?? "",
            duration: duration,
            pets: data["pets"] as? [String] ?? [],
            specialInstructions: (data["specialInstructions"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            status: ServiceBooking.BookingStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
            sitterId: (data["sitterId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            sitterName: (data["sitterName"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            address: (data["address"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            checkIn: checkIn,
            checkOut: checkOut,
            price: data["price"] as? String ?? "0",
            recurringSeriesId: (data["recurringSeriesId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            visitNumber: data["visitNumber"] as? Int,
            isRecurring: data["isRecurring"] as? Bool ?? false,
            paymentStatus: PaymentStatus(rawValue: data["paymentStatus"] as? String ?? ""),
            paymentTransactionId: (data["paymentTransactionId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            paymentAmount: data["paymentAmount"] as? Double,
            paymentMethod: (data["paymentMethod"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            rescheduledFrom: (data["rescheduledFrom"] as? Timestamp)?.dateValue(),
            rescheduledAt: (data["rescheduledAt"] as? Timestamp)?.dateValue(),
            rescheduledBy: (data["rescheduledBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            rescheduleReason: (data["rescheduleReason"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            rescheduleHistory: rescheduleHistory,
            lastModified: (data["lastModified"] as? Timestamp)?.dateValue(),
            lastModifiedBy: (data["lastModifiedBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            modificationReason: (data["modificationReason"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        )
    }
    
    /// Check if a booking can be modified
    private func canModifyBooking(_ booking: ServiceBooking) -> Bool {
        let now = Date()
        let hoursUntilVisit = booking.scheduledDate.timeIntervalSince(now) / 3600
        
        // Can modify if booking is pending or approved, and more than minimum notice hours before visit
        return (booking.status == .pending || booking.status == .approved) && 
               hoursUntilVisit > businessRules.minimumNoticeHours && 
               booking.scheduledDate > now
    }
    
    /// Check if a date is within business hours
    private func isWithinBusinessHours(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        
        // Check if it's a weekend
        if !businessRules.allowWeekendReschedules && (weekday == 1 || weekday == 7) {
            return false
        }
        
        return hour >= businessRules.businessHoursStart && hour <= businessRules.businessHoursEnd
    }
    
    /// Send notifications about the reschedule
    private func sendRescheduleNotifications(
        bookingId: String,
        newDate: Date,
        reason: String
    ) async {
        // This would integrate with your existing notification system
        // For now, we'll just log the notification
        AppLogger.notification.info("Reschedule notification sent for booking: \(bookingId)")
        
        // TODO: Integrate with SmartNotificationManager
        // SmartNotificationManager.shared.sendRescheduleNotification(...)
    }
    
    /// Get sitter availability for a given date range
    func getSitterAvailability(
        sitterId: String,
        date: Date,
        duration: Int
    ) async throws -> [TimeSlot] {
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        // Get all bookings for this sitter on this date
        let bookingsQuery = db.collection("serviceBookings")
            .whereField("sitterId", isEqualTo: sitterId)
            .whereField("status", in: ["approved", "in_adventure"])
            .whereField("scheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("scheduledDate", isLessThan: Timestamp(date: endOfDay))
        
        let snapshot = try await bookingsQuery.getDocuments()
        
        // Create occupied time slots
        var occupiedSlots: [TimeSlot] = []
        for doc in snapshot.documents {
            let data = doc.data()
            let bookingDate = (data["scheduledDate"] as? Timestamp)?.dateValue() ?? Date()
            let bookingDuration = data["duration"] as? Int ?? 30
            let endTime = bookingDate.addingTimeInterval(TimeInterval(bookingDuration * 60))
            
            occupiedSlots.append(TimeSlot(start: bookingDate, end: endTime))
        }
        
        // Generate available time slots (30-minute intervals from 8 AM to 8 PM)
        var availableSlots: [TimeSlot] = []
        var currentTime = calendar.date(bySettingHour: businessRules.businessHoursStart, minute: 0, second: 0, of: date) ?? date
        
        while currentTime < calendar.date(bySettingHour: businessRules.businessHoursEnd, minute: 0, second: 0, of: date) ?? date {
            let slotEnd = currentTime.addingTimeInterval(TimeInterval(duration * 60))
            let proposedSlot = TimeSlot(start: currentTime, end: slotEnd)
            
            // Check if this slot conflicts with any occupied slots
            let hasConflict = occupiedSlots.contains { occupiedSlot in
                proposedSlot.start < occupiedSlot.end && proposedSlot.end > occupiedSlot.start
            }
            
            if !hasConflict {
                availableSlots.append(proposedSlot)
            }
            
            currentTime = currentTime.addingTimeInterval(1800) // Add 30 minutes
        }
        
        return availableSlots
    }
}

// MARK: - Supporting Types

/// Represents a time slot for availability checking
struct TimeSlot {
    let start: Date
    let end: Date
    
    var duration: TimeInterval {
        return end.timeIntervalSince(start)
    }
    
    var isAvailable: Bool = true
}

/// Booking-specific errors
enum BookingError: Error, LocalizedError {
    case bookingNotFound
    case rescheduleTooLate
    case sitterConflict
    case insufficientPermissions
    case invalidDate
    case businessRulesViolated([RescheduleResult.BusinessRuleViolation])
    
    var errorDescription: String? {
        switch self {
        case .bookingNotFound:
            return "Booking not found"
        case .rescheduleTooLate:
            return "Cannot reschedule within 2 hours of scheduled visit"
        case .sitterConflict:
            return "Sitter is not available at the requested time"
        case .insufficientPermissions:
            return "You don't have permission to modify this booking"
        case .invalidDate:
            return "New date must be in the future"
        case .businessRulesViolated(let violations):
            return violations.map { $0.displayMessage }.joined(separator: "; ")
        }
    }
}
