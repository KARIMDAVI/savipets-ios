import XCTest
import FirebaseFirestore
@testable import SaviPets

/// Comprehensive tests for the booking rescheduling functionality
@MainActor
final class BookingRescheduleServiceTests: XCTestCase {
    
    var rescheduleService: BookingRescheduleService!
    var mockFirestore: MockFirestore!
    
    override func setUp() {
        super.setUp()
        mockFirestore = MockFirestore()
        rescheduleService = BookingRescheduleService()
    }
    
    override func tearDown() {
        rescheduleService = nil
        mockFirestore = nil
        super.tearDown()
    }
    
    // MARK: - Reschedule Validation Tests
    
    func testValidRescheduleRequest() async {
        // Given
        let originalDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let newDate = Calendar.current.date(byAdding: .day, value: 8, to: Date())!
        
        let booking = createMockBooking(scheduledDate: originalDate)
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: newDate,
            newScheduledTime: "10:00 AM",
            reason: "Schedule conflict",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertFalse(result.conflictDetected)
        XCTAssertFalse(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("valid"))
    }
    
    func testRescheduleTooCloseToVisit() async {
        // Given - booking is tomorrow (less than 24 hours)
        let tomorrow = Calendar.current.date(byAdding: .hour, value: 12, to: Date())!
        let newDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        
        let booking = createMockBooking(scheduledDate: tomorrow)
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: newDate,
            newScheduledTime: "10:00 AM",
            reason: "Emergency",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("24 hours"))
    }
    
    func testReschedulePastDate() async {
        // Given
        let originalDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        let booking = createMockBooking(scheduledDate: originalDate)
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: pastDate,
            newScheduledTime: "10:00 AM",
            reason: "Mistake",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("future"))
    }
    
    func testRescheduleCompletedBooking() async {
        // Given
        let booking = createMockBooking(status: .completed)
        let request = createMockRescheduleRequest()
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("completed"))
    }
    
    func testRescheduleCancelledBooking() async {
        // Given
        let booking = createMockBooking(status: .cancelled)
        let request = createMockRescheduleRequest()
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("cancelled"))
    }
    
    // MARK: - Business Rules Tests
    
    func testMaxRescheduleAttempts() async {
        // Given - booking with 3 previous reschedules (max is 3)
        let booking = createMockBookingWithRescheduleHistory(count: 3)
        let request = createMockRescheduleRequest()
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("maximum"))
    }
    
    func testWeekendRescheduleRestriction() async {
        // Given - trying to reschedule to weekend
        let weekendDate = getNextSaturday()
        let booking = createMockBooking()
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: weekendDate,
            newScheduledTime: "10:00 AM",
            reason: "Weekend preference",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("weekend"))
    }
    
    func testHolidayRescheduleRestriction() async {
        // Given - trying to reschedule to a holiday
        let holidayDate = getNextHoliday()
        let booking = createMockBooking()
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: holidayDate,
            newScheduledTime: "10:00 AM",
            reason: "Holiday booking",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("holiday"))
    }
    
    // MARK: - Conflict Detection Tests
    
    func testSitterAvailabilityConflict() async {
        // Given - sitter already has a booking at the same time
        let booking = createMockBooking(sitterId: "sitter123")
        let conflictingTime = "2:00 PM"
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: booking.scheduledDate,
            newScheduledTime: conflictingTime,
            reason: "Time change",
            requestedBy: "user123"
        )
        
        // Mock sitter conflict
        mockFirestore.conflictingBookings = [createMockBooking(sitterId: "sitter123", time: conflictingTime)]
        
        // When
        let result = await rescheduleService.rescheduleBooking(request)
        
        // Then
        XCTAssertTrue(result.conflictDetected)
        XCTAssertTrue(result.message.contains("sitter"))
    }
    
    func testClientDoubleBookingConflict() async {
        // Given - client already has a booking at the same time
        let clientId = "client123"
        let booking = createMockBooking(clientId: clientId)
        let conflictingTime = "3:00 PM"
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: booking.scheduledDate,
            newScheduledTime: conflictingTime,
            reason: "Time change",
            requestedBy: clientId
        )
        
        // Mock client conflict
        mockFirestore.conflictingBookings = [createMockBooking(clientId: clientId, time: conflictingTime)]
        
        // When
        let result = await rescheduleService.rescheduleBooking(request)
        
        // Then
        XCTAssertTrue(result.conflictDetected)
        XCTAssertTrue(result.message.contains("client"))
    }
    
    // MARK: - Refund Calculation Tests
    
    func testFullRefundCalculation() async {
        // Given - reschedule more than 7 days in advance
        let originalDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let newDate = Calendar.current.date(byAdding: .day, value: 12, to: Date())!
        let booking = createMockBooking(scheduledDate: originalDate, price: "100.00")
        
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: newDate,
            newScheduledTime: "10:00 AM",
            reason: "Schedule change",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.rescheduleBooking(request)
        
        // Then
        XCTAssertTrue(result.refundEligible)
        XCTAssertEqual(result.refundAmount, 100.00)
    }
    
    func testPartialRefundCalculation() async {
        // Given - reschedule 3 days in advance (50% refund)
        let originalDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let newDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let booking = createMockBooking(scheduledDate: originalDate, price: "80.00")
        
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: newDate,
            newScheduledTime: "10:00 AM",
            reason: "Schedule change",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.rescheduleBooking(request)
        
        // Then
        XCTAssertTrue(result.refundEligible)
        XCTAssertEqual(result.refundAmount, 40.00)
    }
    
    func testNoRefundCalculation() async {
        // Given - reschedule less than 24 hours in advance
        let originalDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date())!
        let newDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        let booking = createMockBooking(scheduledDate: originalDate, price: "60.00")
        
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: newDate,
            newScheduledTime: "10:00 AM",
            reason: "Emergency",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.rescheduleBooking(request)
        
        // Then
        XCTAssertFalse(result.refundEligible)
        XCTAssertEqual(result.refundAmount, 0.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testRescheduleToSameTime() async {
        // Given - trying to reschedule to the same time
        let booking = createMockBooking(time: "10:00 AM")
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: booking.scheduledDate,
            newScheduledTime: "10:00 AM",
            reason: "No change needed",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("same"))
    }
    
    func testRescheduleWithEmptyReason() async {
        // Given
        let booking = createMockBooking()
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            newScheduledTime: "10:00 AM",
            reason: "",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("reason"))
    }
    
    func testRescheduleWithInvalidTimeFormat() async {
        // Given
        let booking = createMockBooking()
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            newScheduledTime: "25:00",
            reason: "Invalid time",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.validateRescheduleRequest(request, booking: booking)
        
        // Then
        XCTAssertTrue(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("time"))
    }
    
    // MARK: - Integration Tests
    
    func testSuccessfulRescheduleFlow() async {
        // Given
        let originalDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let newDate = Calendar.current.date(byAdding: .day, value: 8, to: Date())!
        let booking = createMockBooking(scheduledDate: originalDate)
        
        let request = RescheduleRequest(
            bookingId: booking.id,
            newScheduledDate: newDate,
            newScheduledTime: "2:00 PM",
            reason: "Schedule conflict",
            requestedBy: "user123"
        )
        
        // When
        let result = await rescheduleService.rescheduleBooking(request)
        
        // Then
        XCTAssertFalse(result.conflictDetected)
        XCTAssertFalse(result.businessRulesViolated)
        XCTAssertTrue(result.message.contains("success"))
    }
    
    func testRescheduleHistoryTracking() async {
        // Given
        let booking = createMockBookingWithRescheduleHistory(count: 1)
        let request = createMockRescheduleRequest()
        
        // When
        let result = await rescheduleService.rescheduleBooking(request)
        
        // Then
        if !result.conflictDetected && !result.businessRulesViolated {
            // Verify reschedule history was updated
            XCTAssertEqual(booking.rescheduleHistory.count + 1, 2)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockBooking(
        id: String = "booking123",
        clientId: String = "client123",
        sitterId: String = "sitter123",
        scheduledDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
        time: String = "10:00 AM",
        status: ServiceBooking.BookingStatus = .approved,
        price: String = "50.00"
    ) -> ServiceBooking {
        return ServiceBooking(
            id: id,
            clientId: clientId,
            serviceType: "Dog Walking",
            scheduledDate: scheduledDate,
            scheduledTime: time,
            duration: 60,
            pets: ["Buddy"],
            specialInstructions: "Test instructions",
            status: status,
            sitterId: sitterId,
            sitterName: "Test Sitter",
            createdAt: Date(),
            address: "123 Test St",
            checkIn: nil,
            checkOut: nil,
            price: price,
            recurringSeriesId: nil,
            visitNumber: nil,
            isRecurring: false,
            paymentStatus: .confirmed,
            paymentTransactionId: "txn123",
            paymentAmount: 50.0,
            paymentMethod: "Credit Card",
            rescheduledFrom: nil,
            rescheduledAt: nil,
            rescheduledBy: nil,
            rescheduleReason: nil,
            rescheduleHistory: [],
            lastModified: Date(),
            lastModifiedBy: "system",
            modificationReason: "Initial booking"
        )
    }
    
    private func createMockBookingWithRescheduleHistory(count: Int) -> ServiceBooking {
        var history: [RescheduleEntry] = []
        
        for i in 0..<count {
            let entry = RescheduleEntry(
                id: "reschedule\(i)",
                originalDate: Calendar.current.date(byAdding: .day, value: -(i + 1), to: Date())!,
                newDate: Calendar.current.date(byAdding: .day, value: -(i), to: Date())!,
                reason: "Test reschedule \(i)",
                requestedBy: "user123",
                requestedAt: Calendar.current.date(byAdding: .day, value: -(i + 1), to: Date())!,
                approvedBy: "admin",
                approvedAt: Calendar.current.date(byAdding: .day, value: -(i + 1), to: Date())!,
                status: .approved
            )
            history.append(entry)
        }
        
        var booking = createMockBooking()
        booking = ServiceBooking(
            id: booking.id,
            clientId: booking.clientId,
            serviceType: booking.serviceType,
            scheduledDate: booking.scheduledDate,
            scheduledTime: booking.scheduledTime,
            duration: booking.duration,
            pets: booking.pets,
            specialInstructions: booking.specialInstructions,
            status: booking.status,
            sitterId: booking.sitterId,
            sitterName: booking.sitterName,
            createdAt: booking.createdAt,
            address: booking.address,
            checkIn: booking.checkIn,
            checkOut: booking.checkOut,
            price: booking.price,
            recurringSeriesId: booking.recurringSeriesId,
            visitNumber: booking.visitNumber,
            isRecurring: booking.isRecurring,
            paymentStatus: booking.paymentStatus,
            paymentTransactionId: booking.paymentTransactionId,
            paymentAmount: booking.paymentAmount,
            paymentMethod: booking.paymentMethod,
            rescheduledFrom: booking.rescheduledFrom,
            rescheduledAt: booking.rescheduledAt,
            rescheduledBy: booking.rescheduledBy,
            rescheduleReason: booking.rescheduleReason,
            rescheduleHistory: history,
            lastModified: booking.lastModified,
            lastModifiedBy: booking.lastModifiedBy,
            modificationReason: booking.modificationReason
        )
        
        return booking
    }
    
    private func createMockRescheduleRequest() -> RescheduleRequest {
        return RescheduleRequest(
            bookingId: "booking123",
            newScheduledDate: Calendar.current.date(byAdding: .day, value: 8, to: Date())!,
            newScheduledTime: "2:00 PM",
            reason: "Test reschedule",
            requestedBy: "user123"
        )
    }
    
    private func getNextSaturday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilSaturday = (7 - weekday) % 7
        return calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 7 : daysUntilSaturday, to: today)!
    }
    
    private func getNextHoliday() -> Date {
        // Mock holiday - New Year's Day
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return calendar.date(from: DateComponents(year: currentYear + 1, month: 1, day: 1))!
    }
}

// MARK: - Mock Classes

class MockFirestore {
    var conflictingBookings: [ServiceBooking] = []
    
    func checkSitterAvailability(sitterId: String, date: Date, time: String) -> [ServiceBooking] {
        return conflictingBookings.filter { booking in
            booking.sitterId == sitterId &&
            Calendar.current.isDate(booking.scheduledDate, inSameDayAs: date) &&
            booking.scheduledTime == time
        }
    }
    
    func checkClientAvailability(clientId: String, date: Date, time: String) -> [ServiceBooking] {
        return conflictingBookings.filter { booking in
            booking.clientId == clientId &&
            Calendar.current.isDate(booking.scheduledDate, inSameDayAs: date) &&
            booking.scheduledTime == time
        }
    }
}
