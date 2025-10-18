import XCTest
import FirebaseFirestore
@testable import SaviPets

/// Tests for RescheduleModels data structures
final class RescheduleModelsTests: XCTestCase {
    
    // MARK: - RescheduleEntry Tests
    
    func testRescheduleEntryInitialization() {
        // Given
        let id = "reschedule123"
        let originalDate = Date()
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: originalDate)!
        let reason = "Schedule conflict"
        let requestedBy = "user123"
        let requestedAt = Date()
        let approvedBy = "admin456"
        let approvedAt = Date()
        let status = RescheduleStatus.approved
        
        // When
        let entry = RescheduleEntry(
            id: id,
            originalDate: originalDate,
            newDate: newDate,
            reason: reason,
            requestedBy: requestedBy,
            requestedAt: requestedAt,
            approvedBy: approvedBy,
            approvedAt: approvedAt,
            status: status
        )
        
        // Then
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.originalDate, originalDate)
        XCTAssertEqual(entry.newDate, newDate)
        XCTAssertEqual(entry.reason, reason)
        XCTAssertEqual(entry.requestedBy, requestedBy)
        XCTAssertEqual(entry.requestedAt, requestedAt)
        XCTAssertEqual(entry.approvedBy, approvedBy)
        XCTAssertEqual(entry.approvedAt, approvedAt)
        XCTAssertEqual(entry.status, status)
    }
    
    func testRescheduleEntryWithoutApproval() {
        // Given
        let entry = RescheduleEntry(
            id: "reschedule123",
            originalDate: Date(),
            newDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            reason: "Schedule conflict",
            requestedBy: "user123",
            requestedAt: Date(),
            approvedBy: nil,
            approvedAt: nil,
            status: .pending
        )
        
        // Then
        XCTAssertNil(entry.approvedBy)
        XCTAssertNil(entry.approvedAt)
        XCTAssertEqual(entry.status, .pending)
    }
    
    func testRescheduleEntryToFirestoreData() {
        // Given
        let originalDate = Date()
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: originalDate)!
        let requestedAt = Date()
        let approvedAt = Date()
        
        let entry = RescheduleEntry(
            id: "reschedule123",
            originalDate: originalDate,
            newDate: newDate,
            reason: "Schedule conflict",
            requestedBy: "user123",
            requestedAt: requestedAt,
            approvedBy: "admin456",
            approvedAt: approvedAt,
            status: .approved
        )
        
        // When
        let firestoreData = entry.toFirestoreData()
        
        // Then
        XCTAssertEqual(firestoreData["id"] as? String, "reschedule123")
        XCTAssertEqual((firestoreData["originalDate"] as? Timestamp)?.dateValue(), originalDate)
        XCTAssertEqual((firestoreData["newDate"] as? Timestamp)?.dateValue(), newDate)
        XCTAssertEqual(firestoreData["reason"] as? String, "Schedule conflict")
        XCTAssertEqual(firestoreData["requestedBy"] as? String, "user123")
        XCTAssertEqual((firestoreData["requestedAt"] as? Timestamp)?.dateValue(), requestedAt)
        XCTAssertEqual(firestoreData["approvedBy"] as? String, "admin456")
        XCTAssertEqual((firestoreData["approvedAt"] as? Timestamp)?.dateValue(), approvedAt)
        XCTAssertEqual(firestoreData["status"] as? String, "approved")
    }
    
    func testRescheduleEntryFromFirestoreData() {
        // Given
        let originalDate = Date()
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: originalDate)!
        let requestedAt = Date()
        let approvedAt = Date()
        
        let firestoreData: [String: Any] = [
            "id": "reschedule123",
            "originalDate": Timestamp(date: originalDate),
            "newDate": Timestamp(date: newDate),
            "reason": "Schedule conflict",
            "requestedBy": "user123",
            "requestedAt": Timestamp(date: requestedAt),
            "approvedBy": "admin456",
            "approvedAt": Timestamp(date: approvedAt),
            "status": "approved"
        ]
        
        // When
        let entry = RescheduleEntry.fromFirestoreData(firestoreData)
        
        // Then
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.id, "reschedule123")
        XCTAssertEqual(entry?.originalDate, originalDate)
        XCTAssertEqual(entry?.newDate, newDate)
        XCTAssertEqual(entry?.reason, "Schedule conflict")
        XCTAssertEqual(entry?.requestedBy, "user123")
        XCTAssertEqual(entry?.requestedAt, requestedAt)
        XCTAssertEqual(entry?.approvedBy, "admin456")
        XCTAssertEqual(entry?.approvedAt, approvedAt)
        XCTAssertEqual(entry?.status, .approved)
    }
    
    func testRescheduleEntryFromFirestoreDataWithNilValues() {
        // Given
        let firestoreData: [String: Any] = [
            "id": "reschedule123",
            "originalDate": Timestamp(date: Date()),
            "newDate": Timestamp(date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!),
            "reason": "Schedule conflict",
            "requestedBy": "user123",
            "requestedAt": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        // When
        let entry = RescheduleEntry.fromFirestoreData(firestoreData)
        
        // Then
        XCTAssertNotNil(entry)
        XCTAssertNil(entry?.approvedBy)
        XCTAssertNil(entry?.approvedAt)
        XCTAssertEqual(entry?.status, .pending)
    }
    
    func testRescheduleEntryFromFirestoreDataInvalidData() {
        // Given - missing required fields
        let firestoreData: [String: Any] = [
            "id": "reschedule123"
            // Missing other required fields
        ]
        
        // When
        let entry = RescheduleEntry.fromFirestoreData(firestoreData)
        
        // Then
        XCTAssertNil(entry)
    }
    
    // MARK: - RescheduleRequest Tests
    
    func testRescheduleRequestInitialization() {
        // Given
        let bookingId = "booking123"
        let newScheduledDate = Date()
        let newScheduledTime = "2:00 PM"
        let reason = "Schedule conflict"
        let requestedBy = "user123"
        
        // When
        let request = RescheduleRequest(
            bookingId: bookingId,
            newScheduledDate: newScheduledDate,
            newScheduledTime: newScheduledTime,
            reason: reason,
            requestedBy: requestedBy
        )
        
        // Then
        XCTAssertEqual(request.bookingId, bookingId)
        XCTAssertEqual(request.newScheduledDate, newScheduledDate)
        XCTAssertEqual(request.newScheduledTime, newScheduledTime)
        XCTAssertEqual(request.reason, reason)
        XCTAssertEqual(request.requestedBy, requestedBy)
    }
    
    func testRescheduleRequestValidation() {
        // Given
        let validRequest = RescheduleRequest(
            bookingId: "booking123",
            newScheduledDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            newScheduledTime: "2:00 PM",
            reason: "Valid reason",
            requestedBy: "user123"
        )
        
        // When
        let isValid = validRequest.isValid
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testRescheduleRequestValidationEmptyReason() {
        // Given
        let invalidRequest = RescheduleRequest(
            bookingId: "booking123",
            newScheduledDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            newScheduledTime: "2:00 PM",
            reason: "",
            requestedBy: "user123"
        )
        
        // When
        let isValid = invalidRequest.isValid
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testRescheduleRequestValidationPastDate() {
        // Given
        let invalidRequest = RescheduleRequest(
            bookingId: "booking123",
            newScheduledDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            newScheduledTime: "2:00 PM",
            reason: "Past date",
            requestedBy: "user123"
        )
        
        // When
        let isValid = invalidRequest.isValid
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    // MARK: - RescheduleResult Tests
    
    func testRescheduleResultSuccess() {
        // Given
        let result = RescheduleResult(
            conflictDetected: false,
            businessRulesViolated: false,
            refundEligible: true,
            refundAmount: 50.0,
            message: "Reschedule successful"
        )
        
        // Then
        XCTAssertFalse(result.conflictDetected)
        XCTAssertFalse(result.businessRulesViolated)
        XCTAssertTrue(result.refundEligible)
        XCTAssertEqual(result.refundAmount, 50.0)
        XCTAssertEqual(result.message, "Reschedule successful")
    }
    
    func testRescheduleResultConflict() {
        // Given
        let result = RescheduleResult(
            conflictDetected: true,
            businessRulesViolated: false,
            refundEligible: false,
            refundAmount: 0.0,
            message: "Sitter conflict detected"
        )
        
        // Then
        XCTAssertTrue(result.conflictDetected)
        XCTAssertFalse(result.businessRulesViolated)
        XCTAssertFalse(result.refundEligible)
        XCTAssertEqual(result.refundAmount, 0.0)
        XCTAssertEqual(result.message, "Sitter conflict detected")
    }
    
    func testRescheduleResultBusinessRulesViolated() {
        // Given
        let result = RescheduleResult(
            conflictDetected: false,
            businessRulesViolated: true,
            refundEligible: false,
            refundAmount: 0.0,
            message: "Business rules violated"
        )
        
        // Then
        XCTAssertFalse(result.conflictDetected)
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertFalse(result.refundEligible)
        XCTAssertEqual(result.refundAmount, 0.0)
        XCTAssertEqual(result.message, "Business rules violated")
    }
    
    // MARK: - BusinessRuleViolation Tests
    
    func testBusinessRuleViolationTypes() {
        // Test all violation types
        XCTAssertEqual(BusinessRuleViolation.tooCloseToVisit.displayName, "Too close to visit")
        XCTAssertEqual(BusinessRuleViolation.maxReschedulesExceeded.displayName, "Maximum reschedules exceeded")
        XCTAssertEqual(BusinessRuleViolation.weekendRestriction.displayName, "Weekend not allowed")
        XCTAssertEqual(BusinessRuleViolation.holidayRestriction.displayName, "Holiday not allowed")
        XCTAssertEqual(BusinessRuleViolation.invalidTimeSlot.displayName, "Invalid time slot")
        XCTAssertEqual(BusinessRuleViolation.bookingNotModifiable.displayName, "Booking not modifiable")
        XCTAssertEqual(BusinessRuleViolation.pastDate.displayName, "Cannot reschedule to past date")
    }
    
    func testBusinessRuleViolationSeverity() {
        // Test severity levels
        XCTAssertEqual(BusinessRuleViolation.tooCloseToVisit.severity, .high)
        XCTAssertEqual(BusinessRuleViolation.maxReschedulesExceeded.severity, .medium)
        XCTAssertEqual(BusinessRuleViolation.weekendRestriction.severity, .low)
        XCTAssertEqual(BusinessRuleViolation.holidayRestriction.severity, .medium)
        XCTAssertEqual(BusinessRuleViolation.invalidTimeSlot.severity, .high)
        XCTAssertEqual(BusinessRuleViolation.bookingNotModifiable.severity, .high)
        XCTAssertEqual(BusinessRuleViolation.pastDate.severity, .high)
    }
    
    // MARK: - RescheduleStatus Tests
    
    func testRescheduleStatusValues() {
        // Test all status values
        XCTAssertEqual(RescheduleStatus.pending.rawValue, "pending")
        XCTAssertEqual(RescheduleStatus.approved.rawValue, "approved")
        XCTAssertEqual(RescheduleStatus.rejected.rawValue, "rejected")
        XCTAssertEqual(RescheduleStatus.cancelled.rawValue, "cancelled")
    }
    
    func testRescheduleStatusDisplayNames() {
        // Test display names
        XCTAssertEqual(RescheduleStatus.pending.displayName, "Pending")
        XCTAssertEqual(RescheduleStatus.approved.displayName, "Approved")
        XCTAssertEqual(RescheduleStatus.rejected.displayName, "Rejected")
        XCTAssertEqual(RescheduleStatus.cancelled.displayName, "Cancelled")
    }
    
    func testRescheduleStatusColors() {
        // Test colors
        XCTAssertEqual(RescheduleStatus.pending.color, .orange)
        XCTAssertEqual(RescheduleStatus.approved.color, .green)
        XCTAssertEqual(RescheduleStatus.rejected.color, .red)
        XCTAssertEqual(RescheduleStatus.cancelled.color, .gray)
    }
    
    // MARK: - Codable Tests
    
    func testRescheduleEntryCodable() throws {
        // Given
        let originalEntry = RescheduleEntry(
            id: "reschedule123",
            originalDate: Date(),
            newDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            reason: "Schedule conflict",
            requestedBy: "user123",
            requestedAt: Date(),
            approvedBy: "admin456",
            approvedAt: Date(),
            status: .approved
        )
        
        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalEntry)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEntry = try decoder.decode(RescheduleEntry.self, from: data)
        
        // Then
        XCTAssertEqual(originalEntry.id, decodedEntry.id)
        XCTAssertEqual(originalEntry.reason, decodedEntry.reason)
        XCTAssertEqual(originalEntry.requestedBy, decodedEntry.requestedBy)
        XCTAssertEqual(originalEntry.approvedBy, decodedEntry.approvedBy)
        XCTAssertEqual(originalEntry.status, decodedEntry.status)
    }
    
    func testRescheduleRequestCodable() throws {
        // Given
        let originalRequest = RescheduleRequest(
            bookingId: "booking123",
            newScheduledDate: Date(),
            newScheduledTime: "2:00 PM",
            reason: "Schedule conflict",
            requestedBy: "user123"
        )
        
        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalRequest)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedRequest = try decoder.decode(RescheduleRequest.self, from: data)
        
        // Then
        XCTAssertEqual(originalRequest.bookingId, decodedRequest.bookingId)
        XCTAssertEqual(originalRequest.newScheduledTime, decodedRequest.newScheduledTime)
        XCTAssertEqual(originalRequest.reason, decodedRequest.reason)
        XCTAssertEqual(originalRequest.requestedBy, decodedRequest.requestedBy)
    }
}
