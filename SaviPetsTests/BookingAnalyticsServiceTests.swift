import XCTest
@testable import SaviPets

/// Tests for Booking Analytics Service functionality
@MainActor
final class BookingAnalyticsServiceTests: XCTestCase {
    
    var analyticsService: BookingAnalyticsService!
    var mockBookings: [ServiceBooking]!
    
    override func setUp() {
        super.setUp()
        analyticsService = BookingAnalyticsService()
        mockBookings = createMockBookings()
    }
    
    override func tearDown() {
        analyticsService = nil
        mockBookings = nil
        super.tearDown()
    }
    
    // MARK: - Metrics Calculation Tests
    
    func testTotalBookingsCalculation() {
        // Given
        let bookings = mockBookings
        
        // When
        let totalBookings = bookings.count
        
        // Then
        XCTAssertEqual(totalBookings, 20)
    }
    
    func testCancellationRateCalculation() {
        // Given
        let bookings = mockBookings
        let cancelledBookings = bookings.filter { $0.status == .cancelled }
        
        // When
        let cancellationRate = Double(cancelledBookings.count) / Double(bookings.count)
        
        // Then
        XCTAssertGreaterThanOrEqual(cancellationRate, 0.0)
        XCTAssertLessThanOrEqual(cancellationRate, 1.0)
    }
    
    func testRescheduleRateCalculation() {
        // Given
        let bookings = mockBookings
        let rescheduledBookings = bookings.filter { $0.rescheduleHistory.count > 0 }
        
        // When
        let rescheduleRate = Double(rescheduledBookings.count) / Double(bookings.count)
        
        // Then
        XCTAssertGreaterThanOrEqual(rescheduleRate, 0.0)
        XCTAssertLessThanOrEqual(rescheduleRate, 1.0)
    }
    
    func testCompletionRateCalculation() {
        // Given
        let bookings = mockBookings
        let completedBookings = bookings.filter { $0.status == .completed }
        
        // When
        let completionRate = Double(completedBookings.count) / Double(bookings.count)
        
        // Then
        XCTAssertGreaterThanOrEqual(completionRate, 0.0)
        XCTAssertLessThanOrEqual(completionRate, 1.0)
    }
    
    // MARK: - Service Type Breakdown Tests
    
    func testServiceTypeBreakdown() {
        // Given
        let bookings = mockBookings
        
        // When
        let serviceTypeBreakdown = Dictionary(grouping: bookings, by: { $0.serviceType })
            .mapValues { $0.count }
        
        // Then
        XCTAssertFalse(serviceTypeBreakdown.isEmpty)
        XCTAssertTrue(serviceTypeBreakdown.keys.contains("Dog Walking"))
        XCTAssertTrue(serviceTypeBreakdown.keys.contains("Cat Sitting"))
        XCTAssertTrue(serviceTypeBreakdown.keys.contains("Pet Grooming"))
        XCTAssertTrue(serviceTypeBreakdown.keys.contains("Pet Training"))
    }
    
    func testServiceTypeBreakdownCounts() {
        // Given
        let bookings = mockBookings
        
        // When
        let serviceTypeBreakdown = Dictionary(grouping: bookings, by: { $0.serviceType })
            .mapValues { $0.count }
        
        // Then
        let totalCount = serviceTypeBreakdown.values.reduce(0, +)
        XCTAssertEqual(totalCount, bookings.count)
    }
    
    // MARK: - Status Breakdown Tests
    
    func testStatusBreakdown() {
        // Given
        let bookings = mockBookings
        
        // When
        let statusBreakdown = Dictionary(grouping: bookings, by: { $0.status.rawValue })
            .mapValues { $0.count }
        
        // Then
        XCTAssertFalse(statusBreakdown.isEmpty)
        XCTAssertTrue(statusBreakdown.keys.contains("pending"))
        XCTAssertTrue(statusBreakdown.keys.contains("approved"))
        XCTAssertTrue(statusBreakdown.keys.contains("in_adventure"))
        XCTAssertTrue(statusBreakdown.keys.contains("completed"))
        XCTAssertTrue(statusBreakdown.keys.contains("cancelled"))
    }
    
    func testStatusBreakdownCounts() {
        // Given
        let bookings = mockBookings
        
        // When
        let statusBreakdown = Dictionary(grouping: bookings, by: { $0.status.rawValue })
            .mapValues { $0.count }
        
        // Then
        let totalCount = statusBreakdown.values.reduce(0, +)
        XCTAssertEqual(totalCount, bookings.count)
    }
    
    // MARK: - Revenue Calculation Tests
    
    func testTotalRevenueCalculation() {
        // Given
        let bookings = mockBookings
        
        // When
        let totalRevenue = bookings.compactMap { booking in
            Double(booking.price.replacingOccurrences(of: ".00", with: ""))
        }.reduce(0, +)
        
        // Then
        XCTAssertGreaterThan(totalRevenue, 0.0)
    }
    
    func testAverageRevenuePerBooking() {
        // Given
        let bookings = mockBookings
        
        // When
        let totalRevenue = bookings.compactMap { booking in
            Double(booking.price.replacingOccurrences(of: ".00", with: ""))
        }.reduce(0, +)
        
        let averageRevenue = totalRevenue / Double(bookings.count)
        
        // Then
        XCTAssertGreaterThan(averageRevenue, 0.0)
    }
    
    func testRevenueByServiceType() {
        // Given
        let bookings = mockBookings
        
        // When
        let revenueByServiceType = Dictionary(grouping: bookings, by: { $0.serviceType })
            .mapValues { bookings in
                bookings.compactMap { booking in
                    Double(booking.price.replacingOccurrences(of: ".00", with: ""))
                }.reduce(0, +)
            }
        
        // Then
        XCTAssertFalse(revenueByServiceType.isEmpty)
        XCTAssertTrue(revenueByServiceType.keys.contains("Dog Walking"))
        XCTAssertTrue(revenueByServiceType.keys.contains("Cat Sitting"))
        XCTAssertTrue(revenueByServiceType.keys.contains("Pet Grooming"))
        XCTAssertTrue(revenueByServiceType.keys.contains("Pet Training"))
    }
    
    // MARK: - Time-based Analysis Tests
    
    func testHourlyDistribution() {
        // Given
        let bookings = mockBookings
        
        // When
        let hourlyDistribution = Dictionary(grouping: bookings, by: { booking in
            let timeComponents = booking.scheduledTime.components(separatedBy: ":")
            if let hourString = timeComponents.first, let hour = Int(hourString) {
                return hour
            }
            return 0
        }).mapValues { $0.count }
        
        // Then
        XCTAssertFalse(hourlyDistribution.isEmpty)
    }
    
    func testDailyDistribution() {
        // Given
        let bookings = mockBookings
        
        // When
        let dailyDistribution = Dictionary(grouping: bookings, by: { booking in
            Calendar.current.component(.weekday, from: booking.scheduledDate)
        }).mapValues { $0.count }
        
        // Then
        XCTAssertFalse(dailyDistribution.isEmpty)
        XCTAssertEqual(dailyDistribution.count, 7) // 7 days of the week
    }
    
    func testMonthlyDistribution() {
        // Given
        let bookings = mockBookings
        
        // When
        let monthlyDistribution = Dictionary(grouping: bookings, by: { booking in
            Calendar.current.component(.month, from: booking.scheduledDate)
        }).mapValues { $0.count }
        
        // Then
        XCTAssertFalse(monthlyDistribution.isEmpty)
    }
    
    // MARK: - Growth Rate Tests
    
    func testGrowthRateCalculation() {
        // Given
        let currentPeriodBookings = 100
        let previousPeriodBookings = 80
        
        // When
        let growthRate = calculateGrowthRate(current: Double(currentPeriodBookings), previous: Double(previousPeriodBookings))
        
        // Then
        XCTAssertEqual(growthRate, 0.25) // 25% growth
    }
    
    func testNegativeGrowthRate() {
        // Given
        let currentPeriodBookings = 80
        let previousPeriodBookings = 100
        
        // When
        let growthRate = calculateGrowthRate(current: Double(currentPeriodBookings), previous: Double(previousPeriodBookings))
        
        // Then
        XCTAssertEqual(growthRate, -0.2) // -20% growth (decline)
    }
    
    func testZeroGrowthRate() {
        // Given
        let currentPeriodBookings = 100
        let previousPeriodBookings = 100
        
        // When
        let growthRate = calculateGrowthRate(current: Double(currentPeriodBookings), previous: Double(previousPeriodBookings))
        
        // Then
        XCTAssertEqual(growthRate, 0.0) // 0% growth
    }
    
    func testGrowthRateWithZeroPrevious() {
        // Given
        let currentPeriodBookings = 100
        let previousPeriodBookings = 0
        
        // When
        let growthRate = calculateGrowthRate(current: Double(currentPeriodBookings), previous: Double(previousPeriodBookings))
        
        // Then
        XCTAssertEqual(growthRate, 1.0) // 100% growth (infinite growth from zero)
    }
    
    // MARK: - Analytics Insights Tests
    
    func testPositiveInsightGeneration() {
        // Given
        let metrics = BookingMetrics(
            totalBookings: 100,
            cancellationRate: 0.05, // 5% cancellation rate
            rescheduleRate: 0.10, // 10% reschedule rate
            completionRate: 0.95, // 95% completion rate
            serviceTypeBreakdown: ["Dog Walking": 50, "Cat Sitting": 30, "Pet Grooming": 20],
            statusBreakdown: ["completed": 95, "cancelled": 5],
            totalRevenue: 5000.0,
            averageRevenuePerBooking: 50.0,
            revenueByServiceType: ["Dog Walking": 2500.0, "Cat Sitting": 1500.0, "Pet Grooming": 1000.0],
            hourlyDistribution: [9: 20, 10: 25, 11: 15, 14: 30, 15: 10],
            dailyDistribution: [1: 15, 2: 20, 3: 25, 4: 20, 5: 20],
            monthlyDistribution: [1: 100],
            bookingGrowthRate: 0.15, // 15% growth
            revenueGrowthRate: 0.20, // 20% growth
            completionRateGrowth: 0.05, // 5% improvement
            cancellationRateGrowth: -0.02 // 2% improvement (reduction)
        )
        
        // When
        let insights = generateInsights(from: metrics)
        
        // Then
        XCTAssertFalse(insights.isEmpty)
        let positiveInsights = insights.filter { $0.type == .positive }
        XCTAssertFalse(positiveInsights.isEmpty)
    }
    
    func testNegativeInsightGeneration() {
        // Given
        let metrics = BookingMetrics(
            totalBookings: 100,
            cancellationRate: 0.30, // 30% cancellation rate
            rescheduleRate: 0.25, // 25% reschedule rate
            completionRate: 0.70, // 70% completion rate
            serviceTypeBreakdown: ["Dog Walking": 50, "Cat Sitting": 30, "Pet Grooming": 20],
            statusBreakdown: ["completed": 70, "cancelled": 30],
            totalRevenue: 5000.0,
            averageRevenuePerBooking: 50.0,
            revenueByServiceType: ["Dog Walking": 2500.0, "Cat Sitting": 1500.0, "Pet Grooming": 1000.0],
            hourlyDistribution: [9: 20, 10: 25, 11: 15, 14: 30, 15: 10],
            dailyDistribution: [1: 15, 2: 20, 3: 25, 4: 20, 5: 20],
            monthlyDistribution: [1: 100],
            bookingGrowthRate: -0.10, // -10% growth (decline)
            revenueGrowthRate: -0.15, // -15% growth (decline)
            completionRateGrowth: -0.05, // 5% decline
            cancellationRateGrowth: 0.05 // 5% increase
        )
        
        // When
        let insights = generateInsights(from: metrics)
        
        // Then
        XCTAssertFalse(insights.isEmpty)
        let negativeInsights = insights.filter { $0.type == .negative }
        XCTAssertFalse(negativeInsights.isEmpty)
    }
    
    func testNeutralInsightGeneration() {
        // Given
        let metrics = BookingMetrics(
            totalBookings: 100,
            cancellationRate: 0.15, // 15% cancellation rate
            rescheduleRate: 0.15, // 15% reschedule rate
            completionRate: 0.85, // 85% completion rate
            serviceTypeBreakdown: ["Dog Walking": 50, "Cat Sitting": 30, "Pet Grooming": 20],
            statusBreakdown: ["completed": 85, "cancelled": 15],
            totalRevenue: 5000.0,
            averageRevenuePerBooking: 50.0,
            revenueByServiceType: ["Dog Walking": 2500.0, "Cat Sitting": 1500.0, "Pet Grooming": 1000.0],
            hourlyDistribution: [9: 20, 10: 25, 11: 15, 14: 30, 15: 10],
            dailyDistribution: [1: 15, 2: 20, 3: 25, 4: 20, 5: 20],
            monthlyDistribution: [1: 100],
            bookingGrowthRate: 0.02, // 2% growth
            revenueGrowthRate: 0.03, // 3% growth
            completionRateGrowth: 0.01, // 1% improvement
            cancellationRateGrowth: -0.01 // 1% improvement (reduction)
        )
        
        // When
        let insights = generateInsights(from: metrics)
        
        // Then
        XCTAssertFalse(insights.isEmpty)
        let neutralInsights = insights.filter { $0.type == .neutral }
        XCTAssertFalse(neutralInsights.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testAnalyticsCalculationPerformance() {
        // Given - Create a large dataset
        let largeDataset = (0..<10000).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: "Service Type \(index % 10)",
                status: ServiceBooking.BookingStatus.allCases[index % ServiceBooking.BookingStatus.allCases.count]
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let totalBookings = largeDataset.count
        let cancellationRate = Double(largeDataset.filter { $0.status == .cancelled }.count) / Double(totalBookings)
        let completionRate = Double(largeDataset.filter { $0.status == .completed }.count) / Double(totalBookings)
        let serviceTypeBreakdown = Dictionary(grouping: largeDataset, by: { $0.serviceType }).mapValues { $0.count }
        let statusBreakdown = Dictionary(grouping: largeDataset, by: { $0.status.rawValue }).mapValues { $0.count }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0) // Should complete in less than 1 second
        XCTAssertEqual(totalBookings, 10000)
        XCTAssertGreaterThanOrEqual(cancellationRate, 0.0)
        XCTAssertLessThanOrEqual(cancellationRate, 1.0)
        XCTAssertGreaterThanOrEqual(completionRate, 0.0)
        XCTAssertLessThanOrEqual(completionRate, 1.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testAnalyticsWithEmptyDataset() {
        // Given
        let emptyBookings: [ServiceBooking] = []
        
        // When
        let totalBookings = emptyBookings.count
        let cancellationRate = emptyBookings.isEmpty ? 0.0 : Double(emptyBookings.filter { $0.status == .cancelled }.count) / Double(emptyBookings.count)
        
        // Then
        XCTAssertEqual(totalBookings, 0)
        XCTAssertEqual(cancellationRate, 0.0)
    }
    
    func testAnalyticsWithSingleBooking() {
        // Given
        let singleBooking = [createMockBooking(status: .completed)]
        
        // When
        let totalBookings = singleBooking.count
        let completionRate = Double(singleBooking.filter { $0.status == .completed }.count) / Double(singleBooking.count)
        
        // Then
        XCTAssertEqual(totalBookings, 1)
        XCTAssertEqual(completionRate, 1.0)
    }
    
    func testAnalyticsWithAllCancelledBookings() {
        // Given
        let cancelledBookings = (0..<10).map { _ in createMockBooking(status: .cancelled) }
        
        // When
        let totalBookings = cancelledBookings.count
        let cancellationRate = Double(cancelledBookings.filter { $0.status == .cancelled }.count) / Double(cancelledBookings.count)
        
        // Then
        XCTAssertEqual(totalBookings, 10)
        XCTAssertEqual(cancellationRate, 1.0)
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
    
    private func calculateGrowthRate(current: Double, previous: Double) -> Double {
        if previous == 0 {
            return current > 0 ? 1.0 : 0.0
        }
        return (current - previous) / previous
    }
    
    private func generateInsights(from metrics: BookingMetrics) -> [AnalyticsInsight] {
        var insights: [AnalyticsInsight] = []
        
        // Positive insights
        if metrics.completionRate > 0.9 {
            insights.append(AnalyticsInsight(
                id: UUID().uuidString,
                type: .positive,
                title: "Excellent Completion Rate",
                message: "Your \(Int(metrics.completionRate * 100))% completion rate is outstanding!",
                impact: .high
            ))
        }
        
        if metrics.cancellationRate < 0.1 {
            insights.append(AnalyticsInsight(
                id: UUID().uuidString,
                type: .positive,
                title: "Low Cancellation Rate",
                message: "Your \(Int(metrics.cancellationRate * 100))% cancellation rate is excellent!",
                impact: .medium
            ))
        }
        
        if metrics.bookingGrowthRate > 0.1 {
            insights.append(AnalyticsInsight(
                id: UUID().uuidString,
                type: .positive,
                title: "Strong Growth",
                message: "You're experiencing \(Int(metrics.bookingGrowthRate * 100))% growth in bookings!",
                impact: .high
            ))
        }
        
        // Negative insights
        if metrics.cancellationRate > 0.2 {
            insights.append(AnalyticsInsight(
                id: UUID().uuidString,
                type: .negative,
                title: "High Cancellation Rate",
                message: "Your \(Int(metrics.cancellationRate * 100))% cancellation rate needs attention.",
                impact: .high
            ))
        }
        
        if metrics.completionRate < 0.8 {
            insights.append(AnalyticsInsight(
                id: UUID().uuidString,
                type: .negative,
                title: "Low Completion Rate",
                message: "Your \(Int(metrics.completionRate * 100))% completion rate could be improved.",
                impact: .medium
            ))
        }
        
        if metrics.bookingGrowthRate < -0.05 {
            insights.append(AnalyticsInsight(
                id: UUID().uuidString,
                type: .negative,
                title: "Declining Bookings",
                message: "You're experiencing a \(Int(abs(metrics.bookingGrowthRate) * 100))% decline in bookings.",
                impact: .high
            ))
        }
        
        // Neutral insights
        if metrics.completionRate >= 0.8 && metrics.completionRate <= 0.9 {
            insights.append(AnalyticsInsight(
                id: UUID().uuidString,
                type: .neutral,
                title: "Good Completion Rate",
                message: "Your \(Int(metrics.completionRate * 100))% completion rate is solid.",
                impact: .low
            ))
        }
        
        if metrics.cancellationRate >= 0.1 && metrics.cancellationRate <= 0.2 {
            insights.append(AnalyticsInsight(
                id: UUID().uuidString,
                type: .neutral,
                title: "Average Cancellation Rate",
                message: "Your \(Int(metrics.cancellationRate * 100))% cancellation rate is within normal range.",
                impact: .low
            ))
        }
        
        return insights
    }
}
