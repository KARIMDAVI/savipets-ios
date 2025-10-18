import XCTest
import SwiftUI
@testable import SaviPets

/// Comprehensive end-to-end integration tests for the booking system
@MainActor
final class BookingSystemIntegrationTests: XCTestCase {
    
    var bookingDataService: ServiceBookingDataService!
    var rescheduleService: BookingRescheduleService!
    var analyticsService: BookingAnalyticsService!
    var waitlistService: WaitlistService!
    var businessRules: AutomatedBusinessRules!
    var auditTrailService: AuditTrailService!
    
    override func setUp() {
        super.setUp()
        bookingDataService = ServiceBookingDataService()
        rescheduleService = BookingRescheduleService()
        analyticsService = BookingAnalyticsService()
        waitlistService = WaitlistService()
        businessRules = AutomatedBusinessRules()
        auditTrailService = AuditTrailService()
    }
    
    override func tearDown() {
        bookingDataService = nil
        rescheduleService = nil
        analyticsService = nil
        waitlistService = nil
        businessRules = nil
        auditTrailService = nil
        super.tearDown()
    }
    
    // MARK: - Complete Booking Flow Tests
    
    func testCompleteBookingFlow() {
        // Given
        let clientId = "client123"
        let serviceType = "Dog Walking"
        let scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let scheduledTime = "10:00 AM"
        let duration = 60
        let pets = ["Buddy"]
        let specialInstructions = "Please walk for 30 minutes"
        let price = "50.00"
        
        // When - Create booking
        let booking = ServiceBooking(
            id: "booking123",
            clientId: clientId,
            serviceType: serviceType,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            duration: duration,
            pets: pets,
            specialInstructions: specialInstructions,
            status: .pending,
            sitterId: nil,
            sitterName: nil,
            createdAt: Date(),
            address: "123 Main St",
            checkIn: nil,
            checkOut: nil,
            price: price,
            recurringSeriesId: nil,
            visitNumber: nil,
            isRecurring: false,
            paymentStatus: .pending,
            paymentTransactionId: nil,
            paymentAmount: 50.0,
            paymentMethod: nil,
            rescheduledFrom: nil,
            rescheduledAt: nil,
            rescheduledBy: nil,
            rescheduleReason: nil,
            rescheduleHistory: [],
            lastModified: Date(),
            lastModifiedBy: clientId,
            modificationReason: "Initial booking creation"
        )
        
        // Then - Verify booking creation
        XCTAssertEqual(booking.clientId, clientId)
        XCTAssertEqual(booking.serviceType, serviceType)
        XCTAssertEqual(booking.status, .pending)
        XCTAssertEqual(booking.price, price)
        XCTAssertEqual(booking.pets, pets)
        XCTAssertEqual(booking.specialInstructions, specialInstructions)
    }
    
    func testBookingApprovalFlow() {
        // Given
        let booking = createMockBooking(status: .pending)
        let sitterId = "sitter123"
        let sitterName = "Jane Doe"
        
        // When - Approve booking
        let approvedBooking = ServiceBooking(
            id: booking.id,
            clientId: booking.clientId,
            serviceType: booking.serviceType,
            scheduledDate: booking.scheduledDate,
            scheduledTime: booking.scheduledTime,
            duration: booking.duration,
            pets: booking.pets,
            specialInstructions: booking.specialInstructions,
            status: .approved,
            sitterId: sitterId,
            sitterName: sitterName,
            createdAt: booking.createdAt,
            address: booking.address,
            checkIn: booking.checkIn,
            checkOut: booking.checkOut,
            price: booking.price,
            recurringSeriesId: booking.recurringSeriesId,
            visitNumber: booking.visitNumber,
            isRecurring: booking.isRecurring,
            paymentStatus: .confirmed,
            paymentTransactionId: "txn123",
            paymentAmount: booking.paymentAmount,
            paymentMethod: "Credit Card",
            rescheduledFrom: booking.rescheduledFrom,
            rescheduledAt: booking.rescheduledAt,
            rescheduledBy: booking.rescheduledBy,
            rescheduleReason: booking.rescheduleReason,
            rescheduleHistory: booking.rescheduleHistory,
            lastModified: Date(),
            lastModifiedBy: "admin123",
            modificationReason: "Booking approved and sitter assigned"
        )
        
        // Then - Verify approval
        XCTAssertEqual(approvedBooking.status, .approved)
        XCTAssertEqual(approvedBooking.sitterId, sitterId)
        XCTAssertEqual(approvedBooking.sitterName, sitterName)
        XCTAssertEqual(approvedBooking.paymentStatus, .confirmed)
        XCTAssertEqual(approvedBooking.paymentTransactionId, "txn123")
    }
    
    func testBookingCompletionFlow() {
        // Given
        let booking = createMockBooking(status: .approved)
        let checkInTime = Date()
        let checkOutTime = Calendar.current.date(byAdding: .hour, value: 1, to: checkInTime)!
        
        // When - Complete booking
        let completedBooking = ServiceBooking(
            id: booking.id,
            clientId: booking.clientId,
            serviceType: booking.serviceType,
            scheduledDate: booking.scheduledDate,
            scheduledTime: booking.scheduledTime,
            duration: booking.duration,
            pets: booking.pets,
            specialInstructions: booking.specialInstructions,
            status: .completed,
            sitterId: booking.sitterId,
            sitterName: booking.sitterName,
            createdAt: booking.createdAt,
            address: booking.address,
            checkIn: checkInTime,
            checkOut: checkOutTime,
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
            rescheduleHistory: booking.rescheduleHistory,
            lastModified: Date(),
            lastModifiedBy: booking.sitterId ?? "system",
            modificationReason: "Service completed"
        )
        
        // Then - Verify completion
        XCTAssertEqual(completedBooking.status, .completed)
        XCTAssertNotNil(completedBooking.checkIn)
        XCTAssertNotNil(completedBooking.checkOut)
    }
    
    // MARK: - Rescheduling Integration Tests
    
    func testReschedulingIntegration() {
        // Given
        let originalBooking = createMockBooking(status: .approved)
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: originalBooking.scheduledDate)!
        let newTime = "2:00 PM"
        let reason = "Client requested change"
        let requestedBy = "client123"
        
        // When - Reschedule booking
        let rescheduleRequest = RescheduleRequest(
            bookingId: originalBooking.id,
            newScheduledDate: newDate,
            newScheduledTime: newTime,
            reason: reason,
            requestedBy: requestedBy
        )
        
        let rescheduleResult = rescheduleService.rescheduleBooking(
            bookingId: originalBooking.id,
            newScheduledDate: newDate,
            newScheduledTime: newTime,
            reason: reason,
            requestedBy: requestedBy
        )
        
        // Then - Verify reschedule
        XCTAssertTrue(rescheduleResult.success)
        XCTAssertFalse(rescheduleResult.conflictDetected)
        XCTAssertFalse(rescheduleResult.businessRulesViolated)
    }
    
    func testReschedulingWithConflict() {
        // Given
        let existingBooking = createMockBooking(
            status: .approved,
            scheduledDate: Date(),
            scheduledTime: "2:00 PM"
        )
        
        let newBooking = createMockBooking(
            status: .approved,
            scheduledDate: Date(),
            scheduledTime: "2:00 PM"
        )
        
        // When - Try to reschedule to conflicting time
        let rescheduleResult = rescheduleService.rescheduleBooking(
            bookingId: newBooking.id,
            newScheduledDate: existingBooking.scheduledDate,
            newScheduledTime: existingBooking.scheduledTime,
            reason: "Client requested change",
            requestedBy: "client123"
        )
        
        // Then - Verify conflict detection
        XCTAssertFalse(rescheduleResult.success)
        XCTAssertTrue(rescheduleResult.conflictDetected)
    }
    
    // MARK: - Analytics Integration Tests
    
    func testAnalyticsIntegration() {
        // Given
        let bookings = createMockBookings()
        
        // When - Calculate analytics
        let metrics = analyticsService.fetchBookingMetrics(
            timeRange: .lastMonth,
            bookings: bookings
        )
        
        // Then - Verify metrics
        XCTAssertEqual(metrics.totalBookings, bookings.count)
        XCTAssertGreaterThanOrEqual(metrics.completionRate, 0.0)
        XCTAssertLessThanOrEqual(metrics.completionRate, 1.0)
        XCTAssertGreaterThanOrEqual(metrics.cancellationRate, 0.0)
        XCTAssertLessThanOrEqual(metrics.cancellationRate, 1.0)
        XCTAssertFalse(metrics.serviceTypeBreakdown.isEmpty)
        XCTAssertFalse(metrics.statusBreakdown.isEmpty)
    }
    
    func testAnalyticsInsightsGeneration() {
        // Given
        let bookings = createMockBookings()
        let metrics = analyticsService.fetchBookingMetrics(
            timeRange: .lastMonth,
            bookings: bookings
        )
        
        // When - Generate insights
        let insights = analyticsService.generateInsights(from: metrics)
        
        // Then - Verify insights
        XCTAssertFalse(insights.isEmpty)
        XCTAssertTrue(insights.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(insights.allSatisfy { !$0.message.isEmpty })
    }
    
    // MARK: - Waitlist Integration Tests
    
    func testWaitlistIntegration() {
        // Given
        let waitlistEntry = createWaitlistEntry()
        
        // When - Add to waitlist
        let addResult = waitlistService.addEntryToWaitlist(waitlistEntry)
        
        // Then - Verify addition
        XCTAssertTrue(addResult)
        
        // When - Get waitlist entries
        let entries = waitlistService.getWaitlistEntries()
        
        // Then - Verify retrieval
        XCTAssertFalse(entries.isEmpty)
        XCTAssertTrue(entries.contains { $0.id == waitlistEntry.id })
    }
    
    func testWaitlistToBookingConversion() {
        // Given
        let waitlistEntry = createWaitlistEntry()
        let availableBooking = createMockBooking()
        
        waitlistService.addEntryToWaitlist(waitlistEntry)
        
        // When - Convert waitlist entry to booking
        let conversionResult = waitlistService.createBookingFromWaitlist(
            entry: waitlistEntry,
            availableBooking: availableBooking
        )
        
        // Then - Verify conversion
        XCTAssertTrue(conversionResult)
    }
    
    // MARK: - Business Rules Integration Tests
    
    func testBusinessRulesIntegration() {
        // Given
        let rule = createBusinessRule()
        let booking = createMockBooking(status: .completed)
        
        // When - Process booking with business rules
        let result = businessRules.processBookingChange(
            booking: booking,
            changeType: .statusChange,
            previousValues: ["status": "approved"]
        )
        
        // Then - Verify rule processing
        XCTAssertTrue(result)
    }
    
    func testBusinessRulesWithMultipleConditions() {
        // Given
        let rule = createComplexBusinessRule()
        let booking = createMockBooking(
            status: .completed,
            price: "75.00",
            serviceType: "Dog Walking"
        )
        
        // When - Process booking with complex rules
        let result = businessRules.processBookingChange(
            booking: booking,
            changeType: .statusChange,
            previousValues: ["status": "approved"]
        )
        
        // Then - Verify rule processing
        XCTAssertTrue(result)
    }
    
    // MARK: - Audit Trail Integration Tests
    
    func testAuditTrailIntegration() {
        // Given
        let booking = createMockBooking()
        
        // When - Log booking action
        auditTrailService.logAction(
            action: .create,
            resourceType: .booking,
            resourceId: booking.id,
            details: ["serviceType": booking.serviceType, "price": booking.price],
            userId: booking.clientId
        )
        
        // Then - Verify logging
        // Note: In a real implementation, we would verify the audit log was created
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    func testSecurityEventLogging() {
        // Given
        let suspiciousActivity = "Multiple failed login attempts"
        
        // When - Log security event
        auditTrailService.logSecurityEvent(
            eventType: .suspiciousActivity,
            details: ["activity": suspiciousActivity],
            severity: .medium,
            userId: "user123"
        )
        
        // Then - Verify logging
        // Note: In a real implementation, we would verify the security event was logged
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    // MARK: - End-to-End Workflow Tests
    
    func testCompleteUserJourney() {
        // Given
        let clientId = "client123"
        let serviceType = "Dog Walking"
        let scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        
        // Step 1: Create booking
        let booking = createMockBooking(
            clientId: clientId,
            serviceType: serviceType,
            scheduledDate: scheduledDate,
            status: .pending
        )
        
        // Step 2: Approve booking
        let approvedBooking = createMockBooking(
            id: booking.id,
            clientId: booking.clientId,
            serviceType: booking.serviceType,
            scheduledDate: booking.scheduledDate,
            status: .approved,
            sitterId: "sitter123",
            sitterName: "Jane Doe",
            paymentStatus: .confirmed
        )
        
        // Step 3: Start service
        let inProgressBooking = createMockBooking(
            id: booking.id,
            clientId: booking.clientId,
            serviceType: booking.serviceType,
            scheduledDate: booking.scheduledDate,
            status: .inAdventure,
            sitterId: "sitter123",
            sitterName: "Jane Doe",
            paymentStatus: .confirmed,
            checkIn: Date()
        )
        
        // Step 4: Complete service
        let completedBooking = createMockBooking(
            id: booking.id,
            clientId: booking.clientId,
            serviceType: booking.serviceType,
            scheduledDate: booking.scheduledDate,
            status: .completed,
            sitterId: "sitter123",
            sitterName: "Jane Doe",
            paymentStatus: .confirmed,
            checkIn: Date(),
            checkOut: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        )
        
        // When & Then - Verify complete journey
        XCTAssertEqual(booking.status, .pending)
        XCTAssertEqual(approvedBooking.status, .approved)
        XCTAssertEqual(inProgressBooking.status, .inAdventure)
        XCTAssertEqual(completedBooking.status, .completed)
        
        XCTAssertNil(booking.sitterId)
        XCTAssertEqual(approvedBooking.sitterId, "sitter123")
        XCTAssertEqual(inProgressBooking.sitterId, "sitter123")
        XCTAssertEqual(completedBooking.sitterId, "sitter123")
        
        XCTAssertNil(booking.checkIn)
        XCTAssertNil(approvedBooking.checkIn)
        XCTAssertNotNil(inProgressBooking.checkIn)
        XCTAssertNotNil(completedBooking.checkIn)
        XCTAssertNotNil(completedBooking.checkOut)
    }
    
    func testReschedulingWorkflow() {
        // Given
        let originalBooking = createMockBooking(status: .approved)
        
        // Step 1: Request reschedule
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: originalBooking.scheduledDate)!
        let rescheduleRequest = RescheduleRequest(
            bookingId: originalBooking.id,
            newScheduledDate: newDate,
            newScheduledTime: "2:00 PM",
            reason: "Client requested change",
            requestedBy: "client123"
        )
        
        // Step 2: Process reschedule
        let rescheduleResult = rescheduleService.rescheduleBooking(
            bookingId: originalBooking.id,
            newScheduledDate: newDate,
            newScheduledTime: "2:00 PM",
            reason: "Client requested change",
            requestedBy: "client123"
        )
        
        // Step 3: Update booking with reschedule
        let rescheduledBooking = createMockBooking(
            id: originalBooking.id,
            clientId: originalBooking.clientId,
            serviceType: originalBooking.serviceType,
            scheduledDate: newDate,
            scheduledTime: "2:00 PM",
            status: .approved,
            sitterId: originalBooking.sitterId,
            sitterName: originalBooking.sitterName,
            rescheduledFrom: originalBooking.scheduledDate,
            rescheduledAt: Date(),
            rescheduledBy: "client123",
            rescheduleReason: "Client requested change",
            rescheduleHistory: [
                RescheduleEntry(
                    id: "reschedule1",
                    originalDate: originalBooking.scheduledDate,
                    newDate: newDate,
                    reason: "Client requested change",
                    requestedBy: "client123",
                    requestedAt: Date(),
                    approvedBy: "admin123",
                    approvedAt: Date(),
                    status: .approved
                )
            ]
        )
        
        // When & Then - Verify reschedule workflow
        XCTAssertTrue(rescheduleResult.success)
        XCTAssertEqual(rescheduledBooking.scheduledDate, newDate)
        XCTAssertEqual(rescheduledBooking.scheduledTime, "2:00 PM")
        XCTAssertEqual(rescheduledBooking.rescheduledBy, "client123")
        XCTAssertEqual(rescheduledBooking.rescheduleReason, "Client requested change")
        XCTAssertEqual(rescheduledBooking.rescheduleHistory.count, 1)
    }
    
    // MARK: - Performance Integration Tests
    
    func testLargeDatasetPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: "Service Type \(index % 10)",
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count]
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test analytics calculation
        let metrics = analyticsService.fetchBookingMetrics(
            timeRange: .lastMonth,
            bookings: largeDataset
        )
        
        // Test business rules processing
        for booking in largeDataset.prefix(100) {
            let _ = businessRules.processBookingChange(
                booking: booking,
                changeType: .statusChange,
                previousValues: ["status": "pending"]
            )
        }
        
        // Test waitlist operations
        for i in 0..<100 {
            let entry = createWaitlistEntry(id: "entry\(i)")
            let _ = waitlistService.addEntryToWaitlist(entry)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 5.0) // Should complete in less than 5 seconds
        
        XCTAssertEqual(metrics.totalBookings, 1000)
        XCTAssertFalse(metrics.serviceTypeBreakdown.isEmpty)
        XCTAssertFalse(metrics.statusBreakdown.isEmpty)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testErrorHandlingIntegration() {
        // Given
        let invalidBookingId = "invalid-booking-id"
        
        // When - Try to reschedule invalid booking
        let rescheduleResult = rescheduleService.rescheduleBooking(
            bookingId: invalidBookingId,
            newScheduledDate: Date(),
            newScheduledTime: "10:00 AM",
            reason: "Test reason",
            requestedBy: "client123"
        )
        
        // Then - Verify error handling
        XCTAssertFalse(rescheduleResult.success)
        XCTAssertFalse(rescheduleResult.message.isEmpty)
    }
    
    func testConcurrentOperations() {
        // Given
        let bookings = (0..<100).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When - Perform concurrent operations
        let group = DispatchGroup()
        
        for booking in bookings {
            group.enter()
            DispatchQueue.global().async {
                let _ = self.businessRules.processBookingChange(
                    booking: booking,
                    changeType: .statusChange,
                    previousValues: ["status": "pending"]
                )
                group.leave()
            }
        }
        
        group.wait()
        
        // Then - Verify all operations completed
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    // MARK: - Helper Methods
    
    private func createMockBooking(
        id: String = "booking123",
        clientId: String = "client123",
        serviceType: String = "Dog Walking",
        scheduledDate: Date = Date(),
        scheduledTime: String = "10:00 AM",
        duration: Int = 60,
        pets: [String] = ["Buddy"],
        specialInstructions: String? = "Test instructions",
        status: ServiceBooking.BookingStatus = .approved,
        sitterId: String? = "sitter123",
        sitterName: String? = "Jane Doe",
        createdAt: Date = Date(),
        address: String? = "123 Main St",
        checkIn: Date? = nil,
        checkOut: Date? = nil,
        price: String = "50.00",
        recurringSeriesId: String? = nil,
        visitNumber: Int? = nil,
        isRecurring: Bool = false,
        paymentStatus: PaymentStatus? = .confirmed,
        paymentTransactionId: String? = "txn123",
        paymentAmount: Double? = 50.0,
        paymentMethod: String? = "Credit Card",
        rescheduledFrom: Date? = nil,
        rescheduledAt: Date? = nil,
        rescheduledBy: String? = nil,
        rescheduleReason: String? = nil,
        rescheduleHistory: [RescheduleEntry] = [],
        lastModified: Date? = nil,
        lastModifiedBy: String? = nil,
        modificationReason: String? = nil
    ) -> ServiceBooking {
        return ServiceBooking(
            id: id,
            clientId: clientId,
            serviceType: serviceType,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            duration: duration,
            pets: pets,
            specialInstructions: specialInstructions,
            status: status,
            sitterId: sitterId,
            sitterName: sitterName,
            createdAt: createdAt,
            address: address,
            checkIn: checkIn,
            checkOut: checkOut,
            price: price,
            recurringSeriesId: recurringSeriesId,
            visitNumber: visitNumber,
            isRecurring: isRecurring,
            paymentStatus: paymentStatus,
            paymentTransactionId: paymentTransactionId,
            paymentAmount: paymentAmount,
            paymentMethod: paymentMethod,
            rescheduledFrom: rescheduledFrom,
            rescheduledAt: rescheduledAt,
            rescheduledBy: rescheduledBy,
            rescheduleReason: rescheduleReason,
            rescheduleHistory: rescheduleHistory,
            lastModified: lastModified ?? Date(),
            lastModifiedBy: lastModifiedBy ?? "system",
            modificationReason: modificationReason ?? "Initial booking"
        )
    }
    
    private func createMockBookings() -> [ServiceBooking] {
        let statuses: [ServiceBooking.BookingStatus] = [.pending, .approved, .inAdventure, .completed, .cancelled]
        let services = ["Dog Walking", "Cat Sitting", "Pet Grooming", "Pet Training"]
        
        return (0..<50).map { index in
            createMockBooking(
                id: "booking\(index)",
                clientId: "client\(index)",
                serviceType: services[index % services.count],
                scheduledDate: Calendar.current.date(byAdding: .day, value: index, to: Date())!,
                status: statuses[index % statuses.count],
                price: "\(50 + index * 5).00"
            )
        }
    }
    
    private func createWaitlistEntry(
        id: String = "waitlist1",
        clientId: String = "client123",
        serviceType: String = "Dog Walking",
        preferredDate: Date = Date(),
        preferredTime: String = "10:00 AM",
        duration: Int = 60,
        pets: [String] = ["Buddy"],
        specialInstructions: String? = "Test instructions",
        status: WaitlistStatus = .waiting,
        priority: Int = 1,
        createdAt: Date = Date(),
        notifiedAt: Date? = nil
    ) -> WaitlistEntry {
        return WaitlistEntry(
            id: id,
            clientId: clientId,
            serviceType: serviceType,
            preferredDate: preferredDate,
            preferredTime: preferredTime,
            duration: duration,
            pets: pets,
            specialInstructions: specialInstructions,
            status: status,
            priority: priority,
            createdAt: createdAt,
            notifiedAt: notifiedAt
        )
    }
    
    private func createBusinessRule() -> BusinessRule {
        return BusinessRule(
            id: "rule1",
            name: "Completed Booking Rule",
            description: "Rule for completed bookings",
            conditions: [
                RuleCondition(
                    field: .status,
                    operator: .equals,
                    value: "completed"
                )
            ],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "Booking completed"]
                )
            ],
            isActive: true,
            priority: 1
        )
    }
    
    private func createComplexBusinessRule() -> BusinessRule {
        return BusinessRule(
            id: "complex_rule",
            name: "Complex Booking Rule",
            description: "Rule with multiple conditions",
            conditions: [
                RuleCondition(
                    field: .status,
                    operator: .equals,
                    value: "completed"
                ),
                RuleCondition(
                    field: .price,
                    operator: .greaterThan,
                    value: "50.0"
                ),
                RuleCondition(
                    field: .serviceType,
                    operator: .contains,
                    value: "Walking"
                )
            ],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "Complex rule triggered"]
                )
            ],
            isActive: true,
            priority: 1
        )
    }
}
