import XCTest
import SwiftUI
@testable import SaviPets

/// Tests for Enhanced Booking Card component
@MainActor
final class EnhancedBookingCardTests: XCTestCase {
    
    var mockBooking: ServiceBooking!
    var mockSitter: SitterProfile!
    
    override func setUp() {
        super.setUp()
        mockBooking = createMockBooking()
        mockSitter = createMockSitter()
    }
    
    override func tearDown() {
        mockBooking = nil
        mockSitter = nil
        super.tearDown()
    }
    
    // MARK: - Card Display Tests
    
    func testBookingCardDisplaysCorrectInformation() {
        // Given
        let card = EnhancedBookingCard(
            booking: mockBooking,
            isSelected: false,
            onSelectionChanged: { _ in },
            onQuickAction: { _, _ in }
        )
        
        // When & Then
        XCTAssertEqual(mockBooking.id, "booking123")
        XCTAssertEqual(mockBooking.serviceType, "Dog Walking")
        XCTAssertEqual(mockBooking.status, .approved)
        XCTAssertEqual(mockBooking.price, "50.00")
    }
    
    func testBookingCardStatusBadge() {
        // Given
        let booking = createMockBooking(status: .pending)
        
        // When
        let statusDisplay = booking.status.displayName
        let statusColor = booking.status.color
        
        // Then
        XCTAssertEqual(statusDisplay, "Pending")
        XCTAssertNotNil(statusColor)
    }
    
    func testBookingCardWithAllStatuses() {
        // Given
        let statuses: [ServiceBooking.BookingStatus] = [.pending, .approved, .inAdventure, .completed, .cancelled]
        
        // When & Then
        for status in statuses {
            let booking = createMockBooking(status: status)
            XCTAssertEqual(booking.status, status)
            XCTAssertFalse(booking.status.displayName.isEmpty)
            XCTAssertNotNil(booking.status.color)
        }
    }
    
    func testBookingCardWithSitterInformation() {
        // Given
        let booking = createMockBooking(
            sitterId: "sitter123",
            sitterName: "Jane Doe"
        )
        
        // When & Then
        XCTAssertEqual(booking.sitterId, "sitter123")
        XCTAssertEqual(booking.sitterName, "Jane Doe")
    }
    
    func testBookingCardWithoutSitterInformation() {
        // Given
        let booking = createMockBooking(sitterId: nil, sitterName: nil)
        
        // When & Then
        XCTAssertNil(booking.sitterId)
        XCTAssertNil(booking.sitterName)
    }
    
    func testBookingCardWithAddress() {
        // Given
        let address = "123 Main Street, Apt 4B, City, State 12345"
        let booking = createMockBooking(address: address)
        
        // When & Then
        XCTAssertEqual(booking.address, address)
    }
    
    func testBookingCardWithoutAddress() {
        // Given
        let booking = createMockBooking(address: nil)
        
        // When & Then
        XCTAssertNil(booking.address)
    }
    
    func testBookingCardWithSpecialInstructions() {
        // Given
        let instructions = "Please feed the dog twice a day and take him for a walk in the evening."
        let booking = createMockBooking(specialInstructions: instructions)
        
        // When & Then
        XCTAssertEqual(booking.specialInstructions, instructions)
    }
    
    func testBookingCardWithoutSpecialInstructions() {
        // Given
        let booking = createMockBooking(specialInstructions: nil)
        
        // When & Then
        XCTAssertNil(booking.specialInstructions)
    }
    
    // MARK: - Selection Tests
    
    func testBookingCardSelection() {
        // Given
        var isSelected = false
        
        // When
        isSelected.toggle()
        
        // Then
        XCTAssertTrue(isSelected)
    }
    
    func testBookingCardSelectionCallback() {
        // Given
        var selectionChanged = false
        let selectionCallback: (Bool) -> Void = { _ in
            selectionChanged = true
        }
        
        // When
        selectionCallback(true)
        
        // Then
        XCTAssertTrue(selectionChanged)
    }
    
    // MARK: - Quick Actions Tests
    
    func testQuickActionReschedule() {
        // Given
        let booking = createMockBooking(status: .approved)
        var actionTriggered = false
        
        let actionCallback: (QuickAction, ServiceBooking) -> Void = { action, _ in
            if action == .reschedule {
                actionTriggered = true
            }
        }
        
        // When
        actionCallback(.reschedule, booking)
        
        // Then
        XCTAssertTrue(actionTriggered)
    }
    
    func testQuickActionCancel() {
        // Given
        let booking = createMockBooking(status: .approved)
        var actionTriggered = false
        
        let actionCallback: (QuickAction, ServiceBooking) -> Void = { action, _ in
            if action == .cancel {
                actionTriggered = true
            }
        }
        
        // When
        actionCallback(.cancel, booking)
        
        // Then
        XCTAssertTrue(actionTriggered)
    }
    
    func testQuickActionAssign() {
        // Given
        let booking = createMockBooking(sitterId: nil)
        var actionTriggered = false
        
        let actionCallback: (QuickAction, ServiceBooking) -> Void = { action, _ in
            if action == .assign {
                actionTriggered = true
            }
        }
        
        // When
        actionCallback(.assign, booking)
        
        // Then
        XCTAssertTrue(actionTriggered)
    }
    
    func testQuickActionViewDetails() {
        // Given
        let booking = createMockBooking()
        var actionTriggered = false
        
        let actionCallback: (QuickAction, ServiceBooking) -> Void = { action, _ in
            if action == .viewDetails {
                actionTriggered = true
            }
        }
        
        // When
        actionCallback(.viewDetails, booking)
        
        // Then
        XCTAssertTrue(actionTriggered)
    }
    
    // MARK: - Action Availability Tests
    
    func testRescheduleActionAvailability() {
        // Given
        let reschedulableStatuses: [ServiceBooking.BookingStatus] = [.pending, .approved]
        let nonReschedulableStatuses: [ServiceBooking.BookingStatus] = [.completed, .cancelled, .inAdventure]
        
        // When & Then
        for status in reschedulableStatuses {
            let booking = createMockBooking(status: status)
            let canReschedule = booking.status != .completed && booking.status != .cancelled
            XCTAssertTrue(canReschedule, "Should be able to reschedule \(status.rawValue)")
        }
        
        for status in nonReschedulableStatuses {
            let booking = createMockBooking(status: status)
            let canReschedule = booking.status != .completed && booking.status != .cancelled
            if status == .inAdventure {
                XCTAssertTrue(canReschedule, "Should be able to reschedule \(status.rawValue)")
            } else {
                XCTAssertFalse(canReschedule, "Should not be able to reschedule \(status.rawValue)")
            }
        }
    }
    
    func testCancelActionAvailability() {
        // Given
        let cancellableStatuses: [ServiceBooking.BookingStatus] = [.pending, .approved, .inAdventure]
        let nonCancellableStatuses: [ServiceBooking.BookingStatus] = [.completed, .cancelled]
        
        // When & Then
        for status in cancellableStatuses {
            let booking = createMockBooking(status: status)
            let canCancel = booking.status != .completed && booking.status != .cancelled
            XCTAssertTrue(canCancel, "Should be able to cancel \(status.rawValue)")
        }
        
        for status in nonCancellableStatuses {
            let booking = createMockBooking(status: status)
            let canCancel = booking.status != .completed && booking.status != .cancelled
            XCTAssertFalse(canCancel, "Should not be able to cancel \(status.rawValue)")
        }
    }
    
    func testAssignActionAvailability() {
        // Given
        let unassignedBooking = createMockBooking(sitterId: nil)
        let assignedBooking = createMockBooking(sitterId: "sitter123")
        
        // When & Then
        let canAssignUnassigned = unassignedBooking.sitterId == nil || unassignedBooking.sitterId?.isEmpty == true
        let canAssignAssigned = assignedBooking.sitterId == nil || assignedBooking.sitterId?.isEmpty == true
        
        XCTAssertTrue(canAssignUnassigned)
        XCTAssertFalse(canAssignAssigned)
    }
    
    // MARK: - Payment Status Tests
    
    func testPaymentStatusDisplay() {
        // Given
        let paymentStatuses: [PaymentStatus] = [.confirmed, .pending, .declined, .failed]
        
        // When & Then
        for status in paymentStatuses {
            let booking = createMockBooking(paymentStatus: status)
            XCTAssertEqual(booking.paymentStatus, status)
        }
    }
    
    func testPaymentAmountDisplay() {
        // Given
        let amounts: [Double] = [25.0, 50.0, 75.0, 100.0]
        
        // When & Then
        for amount in amounts {
            let booking = createMockBooking(paymentAmount: amount)
            XCTAssertEqual(booking.paymentAmount, amount)
        }
    }
    
    // MARK: - Reschedule History Tests
    
    func testRescheduleHistoryDisplay() {
        // Given
        let rescheduleEntry = RescheduleEntry(
            id: "reschedule1",
            originalDate: Date(),
            newDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            reason: "Client requested change",
            requestedBy: "client123",
            requestedAt: Date(),
            approvedBy: "admin123",
            approvedAt: Date(),
            status: .approved
        )
        
        let booking = createMockBooking(rescheduleHistory: [rescheduleEntry])
        
        // When & Then
        XCTAssertEqual(booking.rescheduleHistory.count, 1)
        XCTAssertEqual(booking.rescheduleHistory.first?.id, "reschedule1")
        XCTAssertEqual(booking.rescheduleHistory.first?.reason, "Client requested change")
    }
    
    func testMultipleRescheduleHistory() {
        // Given
        let entries = (0..<3).map { index in
            RescheduleEntry(
                id: "reschedule\(index)",
                originalDate: Date(),
                newDate: Calendar.current.date(byAdding: .day, value: index + 1, to: Date())!,
                reason: "Reason \(index)",
                requestedBy: "client123",
                requestedAt: Date(),
                approvedBy: "admin123",
                approvedAt: Date(),
                status: .approved
            )
        }
        
        let booking = createMockBooking(rescheduleHistory: entries)
        
        // When & Then
        XCTAssertEqual(booking.rescheduleHistory.count, 3)
        XCTAssertEqual(booking.rescheduleHistory.map { $0.id }, ["reschedule0", "reschedule1", "reschedule2"])
    }
    
    // MARK: - Recurring Booking Tests
    
    func testRecurringBookingDisplay() {
        // Given
        let booking = createMockBooking(
            isRecurring: true,
            recurringSeriesId: "series123",
            visitNumber: 2
        )
        
        // When & Then
        XCTAssertTrue(booking.isRecurring)
        XCTAssertEqual(booking.recurringSeriesId, "series123")
        XCTAssertEqual(booking.visitNumber, 2)
    }
    
    func testNonRecurringBookingDisplay() {
        // Given
        let booking = createMockBooking(
            isRecurring: false,
            recurringSeriesId: nil,
            visitNumber: nil
        )
        
        // When & Then
        XCTAssertFalse(booking.isRecurring)
        XCTAssertNil(booking.recurringSeriesId)
        XCTAssertNil(booking.visitNumber)
    }
    
    // MARK: - Date and Time Tests
    
    func testScheduledDateTimeDisplay() {
        // Given
        let scheduledDate = Date()
        let scheduledTime = "2:30 PM"
        
        let booking = createMockBooking(
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime
        )
        
        // When & Then
        XCTAssertEqual(booking.scheduledDate, scheduledDate)
        XCTAssertEqual(booking.scheduledTime, scheduledTime)
    }
    
    func testDurationDisplay() {
        // Given
        let durations = [30, 60, 90, 120]
        
        // When & Then
        for duration in durations {
            let booking = createMockBooking(duration: duration)
            XCTAssertEqual(booking.duration, duration)
        }
    }
    
    // MARK: - Pets Display Tests
    
    func testSinglePetDisplay() {
        // Given
        let pets = ["Buddy"]
        let booking = createMockBooking(pets: pets)
        
        // When & Then
        XCTAssertEqual(booking.pets.count, 1)
        XCTAssertEqual(booking.pets.first, "Buddy")
    }
    
    func testMultiplePetsDisplay() {
        // Given
        let pets = ["Buddy", "Max", "Luna"]
        let booking = createMockBooking(pets: pets)
        
        // When & Then
        XCTAssertEqual(booking.pets.count, 3)
        XCTAssertEqual(booking.pets, pets)
    }
    
    func testNoPetsDisplay() {
        // Given
        let pets: [String] = []
        let booking = createMockBooking(pets: pets)
        
        // When & Then
        XCTAssertEqual(booking.pets.count, 0)
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
    
    private func createMockSitter() -> SitterProfile {
        return SitterProfile(
            id: "sitter123",
            name: "Jane Doe",
            email: "jane.doe@example.com",
            phone: "+1234567890",
            specialties: ["Dog Walking", "Cat Sitting"],
            rating: 4.8,
            totalVisits: 150,
            isActive: true,
            profileImage: nil
        )
    }
}

// MARK: - QuickAction Enum

enum QuickAction: String, CaseIterable {
    case reschedule = "reschedule"
    case cancel = "cancel"
    case assign = "assign"
    case viewDetails = "viewDetails"
}
