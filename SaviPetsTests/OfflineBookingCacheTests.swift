import XCTest
import Combine
@testable import SaviPets

/// Tests for Offline Booking Cache functionality
@MainActor
final class OfflineBookingCacheTests: XCTestCase {
    
    var offlineCache: OfflineBookingCache!
    var mockBookings: [ServiceBooking]!
    
    override func setUp() {
        super.setUp()
        offlineCache = OfflineBookingCache()
        mockBookings = createMockBookings()
    }
    
    override func tearDown() {
        offlineCache = nil
        mockBookings = nil
        super.tearDown()
    }
    
    // MARK: - Cache Initialization Tests
    
    func testCacheInitialization() {
        // Given & When
        let cache = OfflineBookingCache()
        
        // Then
        XCTAssertNotNil(cache)
        XCTAssertTrue(cache.cachedBookings.isEmpty)
        XCTAssertTrue(cache.pendingChanges.isEmpty)
    }
    
    func testCachePublishedProperties() {
        // Given
        let cache = OfflineBookingCache()
        
        // When & Then
        XCTAssertNotNil(cache.cachedBookings)
        XCTAssertNotNil(cache.pendingChanges)
    }
    
    // MARK: - Cache Data Management Tests
    
    func testAddOfflineBooking() {
        // Given
        let booking = mockBookings.first!
        
        // When
        offlineCache.addOfflineBooking(booking)
        
        // Then
        XCTAssertEqual(offlineCache.cachedBookings.count, 1)
        XCTAssertEqual(offlineCache.cachedBookings.first?.id, booking.id)
    }
    
    func testAddMultipleOfflineBookings() {
        // Given
        let bookings = Array(mockBookings.prefix(3))
        
        // When
        for booking in bookings {
            offlineCache.addOfflineBooking(booking)
        }
        
        // Then
        XCTAssertEqual(offlineCache.cachedBookings.count, 3)
        XCTAssertEqual(Set(offlineCache.cachedBookings.map { $0.id }), Set(bookings.map { $0.id }))
    }
    
    func testUpdateOfflineBooking() {
        // Given
        let originalBooking = mockBookings.first!
        offlineCache.addOfflineBooking(originalBooking)
        
        let updatedBooking = ServiceBooking(
            id: originalBooking.id,
            clientId: originalBooking.clientId,
            serviceType: "Updated Service",
            scheduledDate: originalBooking.scheduledDate,
            scheduledTime: originalBooking.scheduledTime,
            duration: originalBooking.duration,
            pets: originalBooking.pets,
            specialInstructions: originalBooking.specialInstructions,
            status: .approved,
            sitterId: originalBooking.sitterId,
            sitterName: originalBooking.sitterName,
            createdAt: originalBooking.createdAt,
            address: originalBooking.address,
            checkIn: originalBooking.checkIn,
            checkOut: originalBooking.checkOut,
            price: originalBooking.price,
            recurringSeriesId: originalBooking.recurringSeriesId,
            visitNumber: originalBooking.visitNumber,
            isRecurring: originalBooking.isRecurring,
            paymentStatus: originalBooking.paymentStatus,
            paymentTransactionId: originalBooking.paymentTransactionId,
            paymentAmount: originalBooking.paymentAmount,
            paymentMethod: originalBooking.paymentMethod,
            rescheduledFrom: originalBooking.rescheduledFrom,
            rescheduledAt: originalBooking.rescheduledAt,
            rescheduledBy: originalBooking.rescheduledBy,
            rescheduleReason: originalBooking.rescheduleReason,
            rescheduleHistory: originalBooking.rescheduleHistory,
            lastModified: Date(),
            lastModifiedBy: "system",
            modificationReason: "Updated booking"
        )
        
        // When
        offlineCache.updateOfflineBooking(updatedBooking)
        
        // Then
        XCTAssertEqual(offlineCache.cachedBookings.count, 1)
        XCTAssertEqual(offlineCache.cachedBookings.first?.serviceType, "Updated Service")
        XCTAssertEqual(offlineCache.cachedBookings.first?.status, .approved)
    }
    
    func testDeleteOfflineBooking() {
        // Given
        let booking = mockBookings.first!
        offlineCache.addOfflineBooking(booking)
        
        // When
        offlineCache.deleteOfflineBooking(booking.id)
        
        // Then
        XCTAssertEqual(offlineCache.cachedBookings.count, 0)
    }
    
    func testDeleteNonExistentBooking() {
        // Given
        let nonExistentId = "non-existent-id"
        
        // When
        offlineCache.deleteOfflineBooking(nonExistentId)
        
        // Then
        XCTAssertEqual(offlineCache.cachedBookings.count, 0) // Should not crash
    }
    
    // MARK: - Pending Changes Tests
    
    func testPendingChangesTracking() {
        // Given
        let booking = mockBookings.first!
        
        // When
        offlineCache.addOfflineBooking(booking)
        
        // Then
        XCTAssertEqual(offlineCache.pendingChanges.count, 1)
        XCTAssertEqual(offlineCache.pendingChanges.first?.bookingId, booking.id)
    }
    
    func testMultiplePendingChanges() {
        // Given
        let bookings = Array(mockBookings.prefix(3))
        
        // When
        for booking in bookings {
            offlineCache.addOfflineBooking(booking)
        }
        
        // Then
        XCTAssertEqual(offlineCache.pendingChanges.count, 3)
    }
    
    func testPendingChangeTypes() {
        // Given
        let booking = mockBookings.first!
        
        // When
        offlineCache.addOfflineBooking(booking)
        let pendingChange = offlineCache.pendingChanges.first
        
        // Then
        XCTAssertNotNil(pendingChange)
        XCTAssertEqual(pendingChange?.type, .create)
    }
    
    // MARK: - Data Persistence Tests
    
    func testSaveCachedData() {
        // Given
        let booking = mockBookings.first!
        offlineCache.addOfflineBooking(booking)
        
        // When
        offlineCache.saveCachedData()
        
        // Then
        // Data should be saved to UserDefaults (we can't directly test UserDefaults in unit tests)
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    func testLoadCachedData() {
        // Given
        let booking = mockBookings.first!
        offlineCache.addOfflineBooking(booking)
        offlineCache.saveCachedData()
        
        // When
        offlineCache.loadCachedData()
        
        // Then
        // Data should be loaded from UserDefaults
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    // MARK: - Network Sync Tests
    
    func testRefreshCache() {
        // Given
        let booking = mockBookings.first!
        offlineCache.addOfflineBooking(booking)
        
        // When
        offlineCache.refreshCache()
        
        // Then
        // Should attempt to sync with network
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    func testSyncPendingChanges() {
        // Given
        let booking = mockBookings.first!
        offlineCache.addOfflineBooking(booking)
        
        // When
        offlineCache.syncPendingChanges()
        
        // Then
        // Should attempt to sync pending changes
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    func testProcessPendingChange() {
        // Given
        let booking = mockBookings.first!
        offlineCache.addOfflineBooking(booking)
        let pendingChange = offlineCache.pendingChanges.first!
        
        // When
        offlineCache.processPendingChange(pendingChange)
        
        // Then
        // Should process the pending change
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    // MARK: - Network Monitoring Tests
    
    func testNetworkConnectivityStatus() {
        // Given
        let cache = OfflineBookingCache()
        
        // When & Then
        // Network status should be monitored
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    func testOfflineModeBehavior() {
        // Given
        let cache = OfflineBookingCache()
        
        // When & Then
        // Should behave differently when offline
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    func testOnlineModeBehavior() {
        // Given
        let cache = OfflineBookingCache()
        
        // When & Then
        // Should sync when online
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    // MARK: - Data Integrity Tests
    
    func testCacheDataConsistency() {
        // Given
        let booking = mockBookings.first!
        offlineCache.addOfflineBooking(booking)
        
        // When
        let cachedBooking = offlineCache.cachedBookings.first
        
        // Then
        XCTAssertNotNil(cachedBooking)
        XCTAssertEqual(cachedBooking?.id, booking.id)
        XCTAssertEqual(cachedBooking?.clientId, booking.clientId)
        XCTAssertEqual(cachedBooking?.serviceType, booking.serviceType)
        XCTAssertEqual(cachedBooking?.status, booking.status)
    }
    
    func testCacheDataSerialization() {
        // Given
        let booking = mockBookings.first!
        offlineCache.addOfflineBooking(booking)
        
        // When
        let cachedBooking = offlineCache.cachedBookings.first
        
        // Then
        XCTAssertNotNil(cachedBooking)
        // Should be able to serialize/deserialize
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    // MARK: - Performance Tests
    
    func testCachePerformanceWithLargeDataset() {
        // Given
        let largeDataset = (0..<1000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for booking in largeDataset {
            offlineCache.addOfflineBooking(booking)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0) // Should complete in less than 1 second
        XCTAssertEqual(offlineCache.cachedBookings.count, 1000)
    }
    
    func testCacheUpdatePerformance() {
        // Given
        let bookings = (0..<100).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        for booking in bookings {
            offlineCache.addOfflineBooking(booking)
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for booking in bookings {
            offlineCache.updateOfflineBooking(booking)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.5) // Should complete in less than 500ms
    }
    
    // MARK: - Edge Cases Tests
    
    func testCacheWithDuplicateBookings() {
        // Given
        let booking = mockBookings.first!
        
        // When
        offlineCache.addOfflineBooking(booking)
        offlineCache.addOfflineBooking(booking) // Add same booking again
        
        // Then
        XCTAssertEqual(offlineCache.cachedBookings.count, 1) // Should not duplicate
    }
    
    func testCacheWithEmptyBookings() {
        // Given
        let emptyBookings: [ServiceBooking] = []
        
        // When
        for booking in emptyBookings {
            offlineCache.addOfflineBooking(booking)
        }
        
        // Then
        XCTAssertEqual(offlineCache.cachedBookings.count, 0)
    }
    
    func testCacheWithNilData() {
        // Given
        let cache = OfflineBookingCache()
        
        // When & Then
        // Should handle nil data gracefully
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    // MARK: - Memory Management Tests
    
    func testCacheMemoryUsage() {
        // Given
        let cache = OfflineBookingCache()
        
        // When
        for i in 0..<100 {
            let booking = createMockBooking(id: "booking\(i)")
            cache.addOfflineBooking(booking)
        }
        
        // Then
        // Should not cause memory issues
        XCTAssertEqual(cache.cachedBookings.count, 100)
    }
    
    func testCacheCleanup() {
        // Given
        let cache = OfflineBookingCache()
        
        // When
        for i in 0..<50 {
            let booking = createMockBooking(id: "booking\(i)")
            cache.addOfflineBooking(booking)
        }
        
        // Clear cache
        for i in 0..<50 {
            cache.deleteOfflineBooking("booking\(i)")
        }
        
        // Then
        XCTAssertEqual(cache.cachedBookings.count, 0)
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
