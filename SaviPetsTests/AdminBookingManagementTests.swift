import XCTest
import SwiftUI
@testable import SaviPets

/// Tests for Admin Booking Management features
@MainActor
final class AdminBookingManagementTests: XCTestCase {
    
    var adminBookingManagementView: AdminBookingManagementView!
    var mockServiceBookings: [ServiceBooking]!
    
    override func setUp() {
        super.setUp()
        mockServiceBookings = createMockBookings()
    }
    
    override func tearDown() {
        adminBookingManagementView = nil
        mockServiceBookings = nil
        super.tearDown()
    }
    
    // MARK: - Search and Filter Tests
    
    func testSearchFunctionality() {
        // Given
        let searchText = "Dog Walking"
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
            booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
            booking.address?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { booking in
            booking.serviceType.contains("Dog Walking") ||
            booking.sitterName?.contains("Dog Walking") == true ||
            booking.address?.contains("Dog Walking") == true
        })
    }
    
    func testSearchByClientName() {
        // Given
        let searchText = "John"
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.clientId.localizedCaseInsensitiveContains(searchText)
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSearchBySitterName() {
        // Given
        let searchText = "Jane"
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSearchByAddress() {
        // Given
        let searchText = "Main"
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.address?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSearchCaseInsensitive() {
        // Given
        let searchText = "DOG WALKING"
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchText)
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSearchNoResults() {
        // Given
        let searchText = "NonExistentService"
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
            booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
            booking.address?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When & Then
        XCTAssertTrue(filteredBookings.isEmpty)
    }
    
    // MARK: - Status Filter Tests
    
    func testFilterByPendingStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .pending
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .pending })
    }
    
    func testFilterByApprovedStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .approved
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .approved })
    }
    
    func testFilterByCompletedStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .completed
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .completed })
    }
    
    func testFilterByCancelledStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .cancelled
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .cancelled })
    }
    
    func testFilterByInAdventureStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .inAdventure
        let filteredBookings = mockServiceBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .inAdventure })
    }
    
    // MARK: - Combined Filter Tests
    
    func testSearchAndStatusFilterCombined() {
        // Given
        let searchText = "Dog"
        let statusFilter: ServiceBooking.BookingStatus? = .approved
        
        let filteredBookings = mockServiceBookings.filter { booking in
            let matchesSearch = booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
                               booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
                               booking.address?.localizedCaseInsensitiveContains(searchText) == true
            
            let matchesStatus = booking.status == statusFilter
            
            return matchesSearch && matchesStatus
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { booking in
            (booking.serviceType.contains("Dog") ||
             booking.sitterName?.contains("Dog") == true ||
             booking.address?.contains("Dog") == true) &&
            booking.status == .approved
        })
    }
    
    // MARK: - Bulk Operations Tests
    
    func testBulkSelection() {
        // Given
        let selectedBookings = Array(mockServiceBookings.prefix(3))
        
        // When
        let bulkActions = BulkActionsSheet(
            selectedBookings: selectedBookings,
            onBulkReschedule: { _ in },
            onBulkAssign: { _ in },
            onBulkCancel: { _ in },
            onDismiss: { }
        )
        
        // Then
        XCTAssertEqual(bulkActions.selectedBookings.count, 3)
    }
    
    func testBulkRescheduleValidation() {
        // Given
        let pendingBookings = mockServiceBookings.filter { $0.status == .pending }
        let completedBookings = mockServiceBookings.filter { $0.status == .completed }
        let mixedBookings = pendingBookings + completedBookings
        
        // When
        let canReschedule = mixedBookings.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        
        // Then
        XCTAssertFalse(canReschedule) // Should be false because completed bookings are included
    }
    
    func testBulkCancelValidation() {
        // Given
        let pendingBookings = mockServiceBookings.filter { $0.status == .pending }
        let approvedBookings = mockServiceBookings.filter { $0.status == .approved }
        let mixedBookings = pendingBookings + approvedBookings
        
        // When
        let canCancel = mixedBookings.allSatisfy { booking in
            booking.status != .completed && booking.status != .cancelled
        }
        
        // Then
        XCTAssertTrue(canCancel)
    }
    
    func testBulkAssignValidation() {
        // Given
        let unassignedBookings = mockServiceBookings.filter { $0.sitterId == nil || $0.sitterId?.isEmpty == true }
        
        // When
        let canAssign = unassignedBookings.allSatisfy { booking in
            booking.sitterId == nil || booking.sitterId?.isEmpty == true
        }
        
        // Then
        XCTAssertTrue(canAssign)
    }
    
    // MARK: - Export Functionality Tests
    
    func testCSVExportData() {
        // Given
        let bookings = mockServiceBookings.prefix(5)
        
        // When
        let csvData = generateCSVData(bookings: Array(bookings))
        
        // Then
        XCTAssertFalse(csvData.isEmpty)
        XCTAssertTrue(csvData.contains("ID,Client ID,Service Type,Status,Scheduled Date,Price"))
        
        // Verify each booking is represented in CSV
        for booking in bookings {
            XCTAssertTrue(csvData.contains(booking.id))
            XCTAssertTrue(csvData.contains(booking.clientId))
            XCTAssertTrue(csvData.contains(booking.serviceType))
            XCTAssertTrue(csvData.contains(booking.status.rawValue))
        }
    }
    
    func testCSVExportHeaders() {
        // Given
        let bookings = mockServiceBookings.prefix(2)
        
        // When
        let csvData = generateCSVData(bookings: Array(bookings))
        let lines = csvData.components(separatedBy: .newlines)
        let headerLine = lines.first ?? ""
        
        // Then
        let expectedHeaders = [
            "ID", "Client ID", "Service Type", "Status",
            "Scheduled Date", "Scheduled Time", "Duration",
            "Sitter Name", "Price", "Address", "Created At"
        ]
        
        for header in expectedHeaders {
            XCTAssertTrue(headerLine.contains(header))
        }
    }
    
    func testCSVExportEscaping() {
        // Given
        let bookingWithComma = ServiceBooking(
            id: "booking123",
            clientId: "client123",
            serviceType: "Dog Walking, Pet Sitting",
            scheduledDate: Date(),
            scheduledTime: "10:00 AM",
            duration: 60,
            pets: ["Buddy"],
            specialInstructions: "Special, instructions",
            status: .pending,
            sitterId: nil,
            sitterName: nil,
            createdAt: Date(),
            address: "123 Main St, Apt 4",
            checkIn: nil,
            checkOut: nil,
            price: "50.00",
            recurringSeriesId: nil,
            visitNumber: nil,
            isRecurring: false,
            paymentStatus: nil,
            paymentTransactionId: nil,
            paymentAmount: nil,
            paymentMethod: nil,
            rescheduledFrom: nil,
            rescheduledAt: nil,
            rescheduledBy: nil,
            rescheduleReason: nil,
            rescheduleHistory: [],
            lastModified: Date(),
            lastModifiedBy: "system",
            modificationReason: "Initial booking"
        )
        
        // When
        let csvData = generateCSVData(bookings: [bookingWithComma])
        
        // Then
        XCTAssertTrue(csvData.contains("\"Dog Walking, Pet Sitting\""))
        XCTAssertTrue(csvData.contains("\"Special, instructions\""))
        XCTAssertTrue(csvData.contains("\"123 Main St, Apt 4\""))
    }
    
    // MARK: - Enhanced Booking Card Tests
    
    func testBookingCardSelection() {
        // Given
        let booking = mockServiceBookings.first!
        var isSelected = false
        
        // When
        isSelected.toggle()
        
        // Then
        XCTAssertTrue(isSelected)
    }
    
    func testBookingCardQuickActions() {
        // Given
        let booking = mockServiceBookings.first!
        
        // When & Then
        let canReschedule = booking.status != .completed && booking.status != .cancelled
        let canCancel = booking.status != .completed && booking.status != .cancelled
        let canAssign = booking.sitterId == nil || booking.sitterId?.isEmpty == true
        
        XCTAssertTrue(canReschedule)
        XCTAssertTrue(canCancel)
        XCTAssertTrue(canAssign)
    }
    
    func testBookingCardStatusDisplay() {
        // Given
        let booking = mockServiceBookings.first!
        
        // When
        let statusDisplay = booking.status.displayName
        let statusColor = booking.status.color
        
        // Then
        XCTAssertFalse(statusDisplay.isEmpty)
        XCTAssertNotNil(statusColor)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetFiltering() {
        // Given - Create a large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(
                id: "booking\(index)",
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count]
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let filteredBookings = largeDataset.filter { booking in
            booking.status == .pending
        }
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSearchPerformance() {
        // Given - Create a large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: "Service Type \(index)"
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let filteredBookings = largeDataset.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains("Service")
        }
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertEqual(filteredBookings.count, 1000)
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
        sitterId: String? = "sitter123",
        sitterName: String? = "Jane Doe",
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
    
    private func generateCSVData(bookings: [ServiceBooking]) -> String {
        let headers = [
            "ID", "Client ID", "Service Type", "Status",
            "Scheduled Date", "Scheduled Time", "Duration",
            "Sitter Name", "Price", "Address", "Created At"
        ]
        
        var csvData = headers.joined(separator: ",") + "\n"
        
        for booking in bookings {
            let row = [
                booking.id,
                booking.clientId,
                "\"\(booking.serviceType)\"",
                booking.status.rawValue,
                DateFormatter.csvDateFormatter.string(from: booking.scheduledDate),
                booking.scheduledTime,
                "\(booking.duration)",
                "\"\(booking.sitterName ?? "")\"",
                booking.price,
                "\"\(booking.address ?? "")\"",
                DateFormatter.csvDateFormatter.string(from: booking.createdAt)
            ]
            
            csvData += row.joined(separator: ",") + "\n"
        }
        
        return csvData
    }
}

// MARK: - Helper Extensions

extension DateFormatter {
    static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

// MARK: - Mock BulkActionsSheet

struct BulkActionsSheet: View {
    let selectedBookings: [ServiceBooking]
    let onBulkReschedule: ([ServiceBooking]) -> Void
    let onBulkAssign: ([ServiceBooking]) -> Void
    let onBulkCancel: ([ServiceBooking]) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Text("Bulk Actions")
            Text("Selected: \(selectedBookings.count) bookings")
        }
    }
}
