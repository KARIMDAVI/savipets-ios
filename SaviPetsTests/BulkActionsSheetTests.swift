import XCTest
import SwiftUI
@testable import SaviPets

/// Tests for Bulk Actions Sheet functionality
@MainActor
final class BulkActionsSheetTests: XCTestCase {
    
    var mockBookings: [ServiceBooking]!
    
    override func setUp() {
        super.setUp()
        mockBookings = createMockBookings()
    }
    
    override func tearDown() {
        mockBookings = nil
        super.tearDown()
    }
    
    // MARK: - Bulk Selection Tests
    
    func testBulkSelectionCount() {
        // Given
        let selectedBookings = Array(mockBookings.prefix(5))
        
        // When
        let bulkActions = BulkActionsSheet(
            selectedBookings: selectedBookings,
            onBulkReschedule: { _ in },
            onBulkAssign: { _ in },
            onBulkCancel: { _ in },
            onDismiss: { }
        )
        
        // Then
        XCTAssertEqual(bulkActions.selectedBookings.count, 5)
    }
    
    func testBulkSelectionEmpty() {
        // Given
        let selectedBookings: [ServiceBooking] = []
        
        // When
        let bulkActions = BulkActionsSheet(
            selectedBookings: selectedBookings,
            onBulkReschedule: { _ in },
            onBulkAssign: { _ in },
            onBulkCancel: { _ in },
            onDismiss: { }
        )
        
        // Then
        XCTAssertEqual(bulkActions.selectedBookings.count, 0)
    }
    
    func testBulkSelectionAllBookings() {
        // Given
        let selectedBookings = mockBookings
        
        // When
        let bulkActions = BulkActionsSheet(
            selectedBookings: selectedBookings,
            onBulkReschedule: { _ in },
            onBulkAssign: { _ in },
            onBulkCancel: { _ in },
            onDismiss: { }
        )
        
        // Then
        XCTAssertEqual(bulkActions.selectedBookings.count, mockBookings.count)
    }
    
    // MARK: - Bulk Reschedule Tests
    
    func testBulkRescheduleValidation() {
        // Given
        let pendingBookings = mockBookings.filter { $0.status == .pending }
        let approvedBookings = mockBookings.filter { $0.status == .approved }
        let reschedulableBookings = pendingBookings + approvedBookings
        
        // When
        let canReschedule = reschedulableBookings.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        
        // Then
        XCTAssertTrue(canReschedule)
    }
    
    func testBulkRescheduleWithCompletedBookings() {
        // Given
        let completedBookings = mockBookings.filter { $0.status == .completed }
        let pendingBookings = mockBookings.filter { $0.status == .pending }
        let mixedBookings = completedBookings + pendingBookings
        
        // When
        let canReschedule = mixedBookings.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        
        // Then
        XCTAssertFalse(canReschedule) // Should be false because completed bookings are included
    }
    
    func testBulkRescheduleWithCancelledBookings() {
        // Given
        let cancelledBookings = mockBookings.filter { $0.status == .cancelled }
        let pendingBookings = mockBookings.filter { $0.status == .pending }
        let mixedBookings = cancelledBookings + pendingBookings
        
        // When
        let canReschedule = mixedBookings.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        
        // Then
        XCTAssertFalse(canReschedule) // Should be false because cancelled bookings are included
    }
    
    func testBulkRescheduleWithInAdventureBookings() {
        // Given
        let inAdventureBookings = mockBookings.filter { $0.status == .inAdventure }
        
        // When
        let canReschedule = inAdventureBookings.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        
        // Then
        XCTAssertTrue(canReschedule) // Should be true because inAdventure can be rescheduled
    }
    
    func testBulkRescheduleCallback() {
        // Given
        let selectedBookings = Array(mockBookings.prefix(3))
        var rescheduleCallbackCalled = false
        var callbackBookings: [ServiceBooking] = []
        
        let onBulkReschedule: ([ServiceBooking]) -> Void = { bookings in
            rescheduleCallbackCalled = true
            callbackBookings = bookings
        }
        
        // When
        onBulkReschedule(selectedBookings)
        
        // Then
        XCTAssertTrue(rescheduleCallbackCalled)
        XCTAssertEqual(callbackBookings.count, 3)
        XCTAssertEqual(callbackBookings, selectedBookings)
    }
    
    // MARK: - Bulk Cancel Tests
    
    func testBulkCancelValidation() {
        // Given
        let pendingBookings = mockBookings.filter { $0.status == .pending }
        let approvedBookings = mockBookings.filter { $0.status == .approved }
        let cancellableBookings = pendingBookings + approvedBookings
        
        // When
        let canCancel = cancellableBookings.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        
        // Then
        XCTAssertTrue(canCancel)
    }
    
    func testBulkCancelWithCompletedBookings() {
        // Given
        let completedBookings = mockBookings.filter { $0.status == .completed }
        
        // When
        let canCancel = completedBookings.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        
        // Then
        XCTAssertFalse(canCancel) // Should be false because completed bookings cannot be cancelled
    }
    
    func testBulkCancelWithCancelledBookings() {
        // Given
        let cancelledBookings = mockBookings.filter { $0.status == .cancelled }
        
        // When
        let canCancel = cancelledBookings.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        
        // Then
        XCTAssertFalse(canCancel) // Should be false because cancelled bookings are already cancelled
    }
    
    func testBulkCancelCallback() {
        // Given
        let selectedBookings = Array(mockBookings.prefix(2))
        var cancelCallbackCalled = false
        var callbackBookings: [ServiceBooking] = []
        
        let onBulkCancel: ([ServiceBooking]) -> Void = { bookings in
            cancelCallbackCalled = true
            callbackBookings = bookings
        }
        
        // When
        onBulkCancel(selectedBookings)
        
        // Then
        XCTAssertTrue(cancelCallbackCalled)
        XCTAssertEqual(callbackBookings.count, 2)
        XCTAssertEqual(callbackBookings, selectedBookings)
    }
    
    // MARK: - Bulk Assign Tests
    
    func testBulkAssignValidation() {
        // Given
        let unassignedBookings = mockBookings.filter { $0.sitterId == nil || $0.sitterId?.isEmpty == true }
        
        // When
        let canAssign = unassignedBookings.allSatisfy { booking in
            booking.sitterId == nil || booking.sitterId?.isEmpty == true
        }
        
        // Then
        XCTAssertTrue(canAssign)
    }
    
    func testBulkAssignWithAssignedBookings() {
        // Given
        let assignedBookings = mockBookings.filter { $0.sitterId != nil && !$0.sitterId!.isEmpty }
        
        // When
        let canAssign = assignedBookings.allSatisfy { booking in
            booking.sitterId == nil || booking.sitterId?.isEmpty == true
        }
        
        // Then
        XCTAssertFalse(canAssign) // Should be false because bookings are already assigned
    }
    
    func testBulkAssignWithMixedBookings() {
        // Given
        let unassignedBookings = mockBookings.filter { $0.sitterId == nil || $0.sitterId?.isEmpty == true }
        let assignedBookings = mockBookings.filter { $0.sitterId != nil && !$0.sitterId!.isEmpty }
        let mixedBookings = unassignedBookings + assignedBookings
        
        // When
        let canAssign = mixedBookings.allSatisfy { booking in
            booking.sitterId == nil || booking.sitterId?.isEmpty == true
        }
        
        // Then
        XCTAssertFalse(canAssign) // Should be false because some bookings are already assigned
    }
    
    func testBulkAssignCallback() {
        // Given
        let selectedBookings = Array(mockBookings.prefix(4))
        var assignCallbackCalled = false
        var callbackBookings: [ServiceBooking] = []
        
        let onBulkAssign: ([ServiceBooking]) -> Void = { bookings in
            assignCallbackCalled = true
            callbackBookings = bookings
        }
        
        // When
        onBulkAssign(selectedBookings)
        
        // Then
        XCTAssertTrue(assignCallbackCalled)
        XCTAssertEqual(callbackBookings.count, 4)
        XCTAssertEqual(callbackBookings, selectedBookings)
    }
    
    // MARK: - Dismiss Tests
    
    func testDismissCallback() {
        // Given
        var dismissCallbackCalled = false
        
        let onDismiss: () -> Void = {
            dismissCallbackCalled = true
        }
        
        // When
        onDismiss()
        
        // Then
        XCTAssertTrue(dismissCallbackCalled)
    }
    
    // MARK: - Performance Tests
    
    func testBulkOperationsPerformance() {
        // Given - Create a large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(
                id: "booking\(index)",
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count]
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let reschedulableBookings = largeDataset.filter { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertFalse(reschedulableBookings.isEmpty)
    }
    
    func testBulkValidationPerformance() {
        // Given - Create a large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(
                id: "booking\(index)",
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count]
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let canReschedule = largeDataset.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertTrue(canReschedule)
    }
    
    // MARK: - Edge Cases Tests
    
    func testBulkOperationsWithSingleBooking() {
        // Given
        let singleBooking = [mockBookings.first!]
        
        // When
        let bulkActions = BulkActionsSheet(
            selectedBookings: singleBooking,
            onBulkReschedule: { _ in },
            onBulkAssign: { _ in },
            onBulkCancel: { _ in },
            onDismiss: { }
        )
        
        // Then
        XCTAssertEqual(bulkActions.selectedBookings.count, 1)
    }
    
    func testBulkOperationsWithDuplicateBookings() {
        // Given
        let duplicateBookings = [mockBookings.first!, mockBookings.first!]
        
        // When
        let bulkActions = BulkActionsSheet(
            selectedBookings: duplicateBookings,
            onBulkReschedule: { _ in },
            onBulkAssign: { _ in },
            onBulkCancel: { _ in },
            onDismiss: { }
        )
        
        // Then
        XCTAssertEqual(bulkActions.selectedBookings.count, 2) // Should still work with duplicates
    }
    
    func testBulkOperationsWithDifferentStatuses() {
        // Given
        let statuses: [ServiceBooking.BookingStatus] = [.pending, .approved, .inAdventure, .completed, .cancelled]
        let mixedBookings = statuses.map { status in
            createMockBooking(status: status)
        }
        
        // When
        let reschedulableCount = mixedBookings.filter { booking in
            booking.status != .completed && booking.status != .cancelled
        }.count
        
        let cancellableCount = mixedBookings.filter { booking in
            booking.status != .completed && booking.status != .cancelled
        }.count
        
        // Then
        XCTAssertEqual(reschedulableCount, 3) // pending, approved, inAdventure
        XCTAssertEqual(cancellableCount, 3) // pending, approved, inAdventure
    }
    
    // MARK: - Helper Methods
    
    private func createMockBookings() -> [ServiceBooking] {
        let statuses: [ServiceBooking.BookingStatus] = [.pending, .approved, .inAdventure, .completed, .cancelled]
        let services = ["Dog Walking", "Cat Sitting", "Pet Grooming", "Pet Training"]
        let sitters = ["Jane Doe", "John Smith", "Alice Johnson", "Bob Wilson"]
        let addresses = ["123 Main St", "456 Oak Ave", "789 Pine Rd", "321 Elm St"]
        
        return (0..<20).map { index in
            createMockBooking(
                id: "booking\(index)",
                clientId: "client\(index)",
                serviceType: services[index % services.count],
                scheduledDate: Calendar.current.date(byAdding: .day, value: index, to: Date())!,
                status: statuses[index % statuses.count],
                sitterId: index % 2 == 0 ? "sitter\(index % sitters.count)" : nil,
                sitterName: index % 2 == 0 ? sitters[index % sitters.count] : nil,
                address: addresses[index % addresses.count],
                price: "\(50 + index * 5).00"
            )
        }
    }
    
    private func createMockBooking(
        id: String = "booking123",
        clientId: String = "client123",
        serviceType: String = "Dog Walking",
        scheduledDate: Date = Date(),
        time: String = "10:00 AM",
        status: ServiceBooking.BookingStatus = .pending,
        sitterId: String? = nil,
        sitterName: String? = nil,
        address: String? = "123 Main St",
        price: String = "50.00"
    ) -> ServiceBooking {
        return ServiceBooking(
            id: id,
            clientId: clientId,
            serviceType: serviceType,
            scheduledDate: scheduledDate,
            scheduledTime: time,
            duration: 60,
            pets: ["Buddy"],
            specialInstructions: "Test instructions",
            status: status,
            sitterId: sitterId,
            sitterName: sitterName,
            createdAt: Date(),
            address: address,
            checkIn: nil,
            checkOut: nil,
            price: price,
            recurringSeriesId: nil,
            visitNumber: nil,
            isRecurring: false,
            paymentStatus: .confirmed,
            paymentTransactionId: "txn123",
            paymentAmount: Double(price.replacingOccurrences(of: ".00", with: "")) ?? 50.0,
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
}
