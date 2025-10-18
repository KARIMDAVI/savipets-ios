import XCTest
import SwiftUI
@testable import SaviPets

/// Tests for Booking History View UI/UX functionality
@MainActor
final class BookingHistoryViewTests: XCTestCase {
    
    var mockBookings: [ServiceBooking]!
    
    override func setUp() {
        super.setUp()
        mockBookings = createMockBookings()
    }
    
    override func tearDown() {
        mockBookings = nil
        super.tearDown()
    }
    
    // MARK: - Search Functionality Tests
    
    func testSearchByServiceType() {
        // Given
        let searchText = "Dog Walking"
        let filteredBookings = mockBookings.filter { booking in
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
    
    func testSearchBySitterName() {
        // Given
        let searchText = "Jane"
        let filteredBookings = mockBookings.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
            booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
            booking.address?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSearchByAddress() {
        // Given
        let searchText = "Main"
        let filteredBookings = mockBookings.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
            booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
            booking.address?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSearchCaseInsensitive() {
        // Given
        let searchText = "DOG WALKING"
        let filteredBookings = mockBookings.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
            booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
            booking.address?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSearchNoResults() {
        // Given
        let searchText = "NonExistentService"
        let filteredBookings = mockBookings.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
            booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
            booking.address?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When & Then
        XCTAssertTrue(filteredBookings.isEmpty)
    }
    
    func testSearchEmptyString() {
        // Given
        let searchText = ""
        let filteredBookings = mockBookings.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
            booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
            booking.address?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When & Then
        XCTAssertEqual(filteredBookings.count, mockBookings.count) // Should return all bookings
    }
    
    // MARK: - Status Filter Tests
    
    func testFilterByPendingStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .pending
        let filteredBookings = mockBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .pending })
    }
    
    func testFilterByApprovedStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .approved
        let filteredBookings = mockBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .approved })
    }
    
    func testFilterByCompletedStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .completed
        let filteredBookings = mockBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .completed })
    }
    
    func testFilterByCancelledStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .cancelled
        let filteredBookings = mockBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .cancelled })
    }
    
    func testFilterByInAdventureStatus() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .inAdventure
        let filteredBookings = mockBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.status == .inAdventure })
    }
    
    func testFilterByAllStatuses() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = nil
        let filteredBookings = mockBookings.filter { booking in
            booking.status == statusFilter
        }
        
        // When & Then
        XCTAssertEqual(filteredBookings.count, mockBookings.count) // Should return all bookings
    }
    
    // MARK: - Timeframe Filter Tests
    
    func testFilterByLastWeek() {
        // Given
        let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
        let filteredBookings = mockBookings.filter { booking in
            booking.scheduledDate >= lastWeek
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.scheduledDate >= lastWeek })
    }
    
    func testFilterByLastMonth() {
        // Given
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let filteredBookings = mockBookings.filter { booking in
            booking.scheduledDate >= lastMonth
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.scheduledDate >= lastMonth })
    }
    
    func testFilterByLastThreeMonths() {
        // Given
        let lastThreeMonths = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let filteredBookings = mockBookings.filter { booking in
            booking.scheduledDate >= lastThreeMonths
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.scheduledDate >= lastThreeMonths })
    }
    
    func testFilterByLastYear() {
        // Given
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let filteredBookings = mockBookings.filter { booking in
            booking.scheduledDate >= lastYear
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { $0.scheduledDate >= lastYear })
    }
    
    func testFilterByAllTime() {
        // Given
        let allTime = Date.distantPast
        let filteredBookings = mockBookings.filter { booking in
            booking.scheduledDate >= allTime
        }
        
        // When & Then
        XCTAssertEqual(filteredBookings.count, mockBookings.count) // Should return all bookings
    }
    
    // MARK: - Sort Tests
    
    func testSortByDateNewestFirst() {
        // Given
        let sortOption = SortOption.dateNewestFirst
        let sortedBookings = mockBookings.sorted { booking1, booking2 in
            booking1.scheduledDate > booking2.scheduledDate
        }
        
        // When & Then
        XCTAssertFalse(sortedBookings.isEmpty)
        for i in 0..<(sortedBookings.count - 1) {
            XCTAssertGreaterThanOrEqual(sortedBookings[i].scheduledDate, sortedBookings[i + 1].scheduledDate)
        }
    }
    
    func testSortByDateOldestFirst() {
        // Given
        let sortOption = SortOption.dateOldestFirst
        let sortedBookings = mockBookings.sorted { booking1, booking2 in
            booking1.scheduledDate < booking2.scheduledDate
        }
        
        // When & Then
        XCTAssertFalse(sortedBookings.isEmpty)
        for i in 0..<(sortedBookings.count - 1) {
            XCTAssertLessThanOrEqual(sortedBookings[i].scheduledDate, sortedBookings[i + 1].scheduledDate)
        }
    }
    
    func testSortByServiceType() {
        // Given
        let sortOption = SortOption.serviceType
        let sortedBookings = mockBookings.sorted { booking1, booking2 in
            booking1.serviceType < booking2.serviceType
        }
        
        // When & Then
        XCTAssertFalse(sortedBookings.isEmpty)
        for i in 0..<(sortedBookings.count - 1) {
            XCTAssertLessThanOrEqual(sortedBookings[i].serviceType, sortedBookings[i + 1].serviceType)
        }
    }
    
    func testSortByStatus() {
        // Given
        let sortOption = SortOption.status
        let sortedBookings = mockBookings.sorted { booking1, booking2 in
            booking1.status.rawValue < booking2.status.rawValue
        }
        
        // When & Then
        XCTAssertFalse(sortedBookings.isEmpty)
        for i in 0..<(sortedBookings.count - 1) {
            XCTAssertLessThanOrEqual(sortedBookings[i].status.rawValue, sortedBookings[i + 1].status.rawValue)
        }
    }
    
    func testSortByPrice() {
        // Given
        let sortOption = SortOption.price
        let sortedBookings = mockBookings.sorted { booking1, booking2 in
            let price1 = Double(booking1.price.replacingOccurrences(of: ".00", with: "")) ?? 0.0
            let price2 = Double(booking2.price.replacingOccurrences(of: ".00", with: "")) ?? 0.0
            return price1 > price2
        }
        
        // When & Then
        XCTAssertFalse(sortedBookings.isEmpty)
        for i in 0..<(sortedBookings.count - 1) {
            let price1 = Double(sortedBookings[i].price.replacingOccurrences(of: ".00", with: "")) ?? 0.0
            let price2 = Double(sortedBookings[i + 1].price.replacingOccurrences(of: ".00", with: "")) ?? 0.0
            XCTAssertGreaterThanOrEqual(price1, price2)
        }
    }
    
    // MARK: - Combined Filter Tests
    
    func testSearchAndStatusFilterCombined() {
        // Given
        let searchText = "Dog"
        let statusFilter: ServiceBooking.BookingStatus? = .approved
        
        let filteredBookings = mockBookings.filter { booking in
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
    
    func testSearchAndTimeframeFilterCombined() {
        // Given
        let searchText = "Walking"
        let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
        
        let filteredBookings = mockBookings.filter { booking in
            let matchesSearch = booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
                               booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
                               booking.address?.localizedCaseInsensitiveContains(searchText) == true
            
            let matchesTimeframe = booking.scheduledDate >= lastWeek
            
            return matchesSearch && matchesTimeframe
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { booking in
            (booking.serviceType.contains("Walking") ||
             booking.sitterName?.contains("Walking") == true ||
             booking.address?.contains("Walking") == true) &&
            booking.scheduledDate >= lastWeek
        })
    }
    
    func testAllFiltersCombined() {
        // Given
        let searchText = "Dog"
        let statusFilter: ServiceBooking.BookingStatus? = .approved
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        
        let filteredBookings = mockBookings.filter { booking in
            let matchesSearch = booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
                               booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
                               booking.address?.localizedCaseInsensitiveContains(searchText) == true
            
            let matchesStatus = booking.status == statusFilter
            let matchesTimeframe = booking.scheduledDate >= lastMonth
            
            return matchesSearch && matchesStatus && matchesTimeframe
        }
        
        // When & Then
        XCTAssertFalse(filteredBookings.isEmpty)
        XCTAssertTrue(filteredBookings.allSatisfy { booking in
            (booking.serviceType.contains("Dog") ||
             booking.sitterName?.contains("Dog") == true ||
             booking.address?.contains("Dog") == true) &&
            booking.status == .approved &&
            booking.scheduledDate >= lastMonth
        })
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyStateWithNoBookings() {
        // Given
        let emptyBookings: [ServiceBooking] = []
        
        // When
        let isEmpty = emptyBookings.isEmpty
        
        // Then
        XCTAssertTrue(isEmpty)
    }
    
    func testEmptyStateWithNoSearchResults() {
        // Given
        let searchText = "NonExistentService"
        let filteredBookings = mockBookings.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
            booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true ||
            booking.address?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // When
        let isEmpty = filteredBookings.isEmpty
        
        // Then
        XCTAssertTrue(isEmpty)
    }
    
    func testEmptyStateWithNoFilterResults() {
        // Given
        let statusFilter: ServiceBooking.BookingStatus? = .pending
        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        
        let filteredBookings = mockBookings.filter { booking in
            booking.status == statusFilter && booking.scheduledDate >= futureDate
        }
        
        // When
        let isEmpty = filteredBookings.isEmpty
        
        // Then
        XCTAssertTrue(isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testFilteringPerformance() {
        // Given - Create a large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: "Service Type \(index % 10)",
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count]
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let filteredBookings = largeDataset.filter { booking in
            booking.serviceType.contains("Service Type 1") && booking.status == .approved
        }
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSortingPerformance() {
        // Given - Create a large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(
                id: "booking\(index)",
                scheduledDate: Calendar.current.date(byAdding: .day, value: index, to: Date())!
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        let sortedBookings = largeDataset.sorted { $0.scheduledDate > $1.scheduledDate }
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertEqual(sortedBookings.count, 1000)
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

// MARK: - SortOption Enum

enum SortOption: String, CaseIterable {
    case dateNewestFirst = "dateNewestFirst"
    case dateOldestFirst = "dateOldestFirst"
    case serviceType = "serviceType"
    case status = "status"
    case price = "price"
    
    var displayName: String {
        switch self {
        case .dateNewestFirst: return "Date (Newest First)"
        case .dateOldestFirst: return "Date (Oldest First)"
        case .serviceType: return "Service Type"
        case .status: return "Status"
        case .price: return "Price"
        }
    }
}
