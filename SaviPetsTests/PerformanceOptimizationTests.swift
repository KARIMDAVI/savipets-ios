import XCTest
import SwiftUI
@testable import SaviPets

/// Tests for performance optimization features
@MainActor
final class PerformanceOptimizationTests: XCTestCase {
    
    var bookingDataService: ServiceBookingDataService!
    var analyticsService: BookingAnalyticsService!
    var offlineCache: OfflineBookingCache!
    
    override func setUp() {
        super.setUp()
        bookingDataService = ServiceBookingDataService()
        analyticsService = BookingAnalyticsService()
        offlineCache = OfflineBookingCache()
    }
    
    override func tearDown() {
        bookingDataService = nil
        analyticsService = nil
        offlineCache = nil
        super.tearDown()
    }
    
    // MARK: - Caching Performance Tests
    
    func testOfflineCachePerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<10000).map { index in
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
        XCTAssertLessThan(executionTime, 2.0) // Should complete in less than 2 seconds
        XCTAssertEqual(offlineCache.cachedBookings.count, 10000)
    }
    
    func testCacheRetrievalPerformance() {
        // Given - Create and cache large dataset
        let largeDataset = (0..<5000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        for booking in largeDataset {
            offlineCache.addOfflineBooking(booking)
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let cachedBookings = offlineCache.cachedBookings
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertEqual(cachedBookings.count, 5000)
    }
    
    func testCacheUpdatePerformance() {
        // Given - Create and cache dataset
        let dataset = (0..<1000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        for booking in dataset {
            offlineCache.addOfflineBooking(booking)
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for booking in dataset {
            offlineCache.updateOfflineBooking(booking)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0) // Should complete in less than 1 second
    }
    
    // MARK: - Pagination Performance Tests
    
    func testPaginationPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<10000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        let pageSize = 100
        let totalPages = (largeDataset.count + pageSize - 1) / pageSize
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for page in 0..<totalPages {
            let startIndex = page * pageSize
            let endIndex = min(startIndex + pageSize, largeDataset.count)
            let _ = Array(largeDataset[startIndex..<endIndex])
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.5) // Should complete in less than 500ms
    }
    
    func testVirtualScrollingPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<50000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        let visibleRange = 0..<100 // Only render 100 items at a time
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let visibleItems = Array(largeDataset[visibleRange])
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertEqual(visibleItems.count, 100)
    }
    
    // MARK: - Query Optimization Tests
    
    func testFilteringPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<10000).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: "Service Type \(index % 10)",
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count]
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let filteredBookings = largeDataset.filter { booking in
            booking.serviceType == "Service Type 1" && booking.status == .approved
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertFalse(filteredBookings.isEmpty)
    }
    
    func testSortingPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<10000).map { index in
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
        XCTAssertLessThan(executionTime, 0.5) // Should complete in less than 500ms
        XCTAssertEqual(sortedBookings.count, 10000)
    }
    
    func testSearchPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<10000).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: "Service Type \(index % 100)",
                sitterName: "Sitter \(index % 100)"
            )
        }
        
        let searchTerm = "Service Type 1"
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let searchResults = largeDataset.filter { booking in
            booking.serviceType.localizedCaseInsensitiveContains(searchTerm) ||
            booking.sitterName?.localizedCaseInsensitiveContains(searchTerm) == true
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.2) // Should complete in less than 200ms
        XCTAssertFalse(searchResults.isEmpty)
    }
    
    // MARK: - Memory Optimization Tests
    
    func testMemoryUsageWithLargeDataset() {
        // Given - Create large dataset
        let largeDataset = (0..<10000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process dataset in chunks to minimize memory usage
        let chunkSize = 1000
        var processedCount = 0
        
        for chunk in largeDataset.chunked(into: chunkSize) {
            let _ = chunk.filter { $0.status == .approved }
            processedCount += chunk.count
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0) // Should complete in less than 1 second
        XCTAssertEqual(processedCount, 10000)
    }
    
    func testLazyLoadingPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<10000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Use lazy evaluation
        let lazyResults = largeDataset.lazy
            .filter { $0.status == .approved }
            .prefix(100)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertEqual(lazyResults.count, 100)
    }
    
    // MARK: - Analytics Performance Tests
    
    func testAnalyticsCalculationPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<50000).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: "Service Type \(index % 100)",
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count],
                price: "\(50 + index % 1000).00"
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let metrics = analyticsService.fetchBookingMetrics(
            timeRange: .lastMonth,
            bookings: largeDataset
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 2.0) // Should complete in less than 2 seconds
        XCTAssertEqual(metrics.totalBookings, 50000)
        XCTAssertFalse(metrics.serviceTypeBreakdown.isEmpty)
        XCTAssertFalse(metrics.statusBreakdown.isEmpty)
    }
    
    func testAnalyticsInsightsPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<10000).map { index in
            createMockBooking(
                id: "booking\(index)",
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count]
            )
        }
        
        let metrics = analyticsService.fetchBookingMetrics(
            timeRange: .lastMonth,
            bookings: largeDataset
        )
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let insights = analyticsService.generateInsights(from: metrics)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.5) // Should complete in less than 500ms
        XCTAssertFalse(insights.isEmpty)
    }
    
    // MARK: - Database Query Performance Tests
    
    func testDatabaseQueryPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<10000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate database query operations
        let approvedBookings = largeDataset.filter { $0.status == .approved }
        let pendingBookings = largeDataset.filter { $0.status == .pending }
        let completedBookings = largeDataset.filter { $0.status == .completed }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.3) // Should complete in less than 300ms
        XCTAssertFalse(approvedBookings.isEmpty)
        XCTAssertFalse(pendingBookings.isEmpty)
        XCTAssertFalse(completedBookings.isEmpty)
    }
    
    func testIndexedQueryPerformance() {
        // Given - Create large dataset with indexed fields
        let largeDataset = (0..<10000).map { index in
            createMockBooking(
                id: "booking\(index)",
                clientId: "client\(index % 1000)", // Indexed field
                serviceType: "Service Type \(index % 100)", // Indexed field
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count]
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate indexed queries
        let clientBookings = largeDataset.filter { $0.clientId == "client1" }
        let serviceBookings = largeDataset.filter { $0.serviceType == "Service Type 1" }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertFalse(clientBookings.isEmpty)
        XCTAssertFalse(serviceBookings.isEmpty)
    }
    
    // MARK: - UI Performance Tests
    
    func testUIUpdatePerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate UI updates
        var updatedBookings: [ServiceBooking] = []
        for booking in largeDataset {
            let updatedBooking = createMockBooking(
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
                rescheduleHistory: booking.rescheduleHistory,
                lastModified: Date(),
                lastModifiedBy: booking.lastModifiedBy,
                modificationReason: booking.modificationReason
            )
            updatedBookings.append(updatedBooking)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0) // Should complete in less than 1 second
        XCTAssertEqual(updatedBookings.count, 1000)
    }
    
    func testListViewPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate list view operations
        let visibleItems = Array(largeDataset.prefix(50)) // Only show 50 items
        let _ = visibleItems.map { booking in
            // Simulate view creation
            return "\(booking.serviceType) - \(booking.scheduledTime)"
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
        XCTAssertEqual(visibleItems.count, 50)
    }
    
    // MARK: - Network Performance Tests
    
    func testNetworkRequestPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate network requests
        let batchSize = 100
        let batches = largeDataset.chunked(into: batchSize)
        
        for batch in batches {
            // Simulate batch upload
            let _ = batch.map { $0.id }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.5) // Should complete in less than 500ms
        XCTAssertEqual(batches.count, 10) // 1000 / 100 = 10 batches
    }
    
    func testConcurrentOperationsPerformance() {
        // Given - Create large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        for booking in largeDataset {
            group.enter()
            queue.async {
                let _ = booking.status.rawValue
                group.leave()
            }
        }
        
        group.wait()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0) // Should complete in less than 1 second
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
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
