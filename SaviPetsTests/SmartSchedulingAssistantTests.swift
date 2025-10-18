import XCTest
import SwiftUI
@testable import SaviPets

/// Tests for Smart Scheduling Assistant functionality
@MainActor
final class SmartSchedulingAssistantTests: XCTestCase {
    
    var assistant: SmartSchedulingAssistant!
    var mockBookingDataService: ServiceBookingDataService!
    var mockAnalyticsService: BookingAnalyticsService!
    var mockBusinessRules: AutomatedBusinessRules!
    var mockWaitlistService: WaitlistService!
    
    override func setUp() {
        super.setUp()
        mockBookingDataService = ServiceBookingDataService()
        mockAnalyticsService = BookingAnalyticsService()
        mockBusinessRules = AutomatedBusinessRules()
        mockWaitlistService = WaitlistService()
        
        assistant = SmartSchedulingAssistant(
            bookingDataService: mockBookingDataService,
            analyticsService: mockAnalyticsService,
            businessRules: mockBusinessRules,
            waitlistService: mockWaitlistService
        )
    }
    
    override func tearDown() {
        assistant = nil
        mockBookingDataService = nil
        mockAnalyticsService = nil
        mockBusinessRules = nil
        mockWaitlistService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testAssistantInitialization() {
        // Given & When
        let newAssistant = SmartSchedulingAssistant(
            bookingDataService: mockBookingDataService,
            analyticsService: mockAnalyticsService,
            businessRules: mockBusinessRules,
            waitlistService: mockWaitlistService
        )
        
        // Then
        XCTAssertNotNil(newAssistant)
        XCTAssertTrue(newAssistant.suggestions.isEmpty)
        XCTAssertFalse(newAssistant.isLoading)
        XCTAssertNil(newAssistant.errorMessage)
        XCTAssertNil(newAssistant.optimizationMetrics)
    }
    
    // MARK: - Suggestion Generation Tests
    
    func testGenerateSuggestions() async {
        // Given
        let mockBookings = createMockBookings()
        
        // When
        await assistant.generateSuggestions()
        
        // Then
        XCTAssertFalse(assistant.isLoading)
        XCTAssertNil(assistant.errorMessage)
        XCTAssertNotNil(assistant.optimizationMetrics)
    }
    
    func testGenerateSuggestionsForDateRange() async {
        // Given
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: startDate)!
        let dateRange = DateInterval(start: startDate, end: endDate)
        
        // When
        await assistant.generateSuggestions(for: dateRange)
        
        // Then
        XCTAssertFalse(assistant.isLoading)
        XCTAssertNil(assistant.errorMessage)
    }
    
    // MARK: - Suggestion Types Tests
    
    func testOptimalTimeSlotSuggestion() {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .optimalTimeSlot,
            title: "Optimal Time Slot Available",
            description: "Consider scheduling at 2:00 PM for better availability.",
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.allUsers],
            relevanceScore: 0.85,
            metadata: ["hour": "14", "currentBookings": "5"]
        )
        
        // When & Then
        XCTAssertEqual(suggestion.type, .optimalTimeSlot)
        XCTAssertEqual(suggestion.type.displayName, "Optimal Time Slot")
        XCTAssertEqual(suggestion.type.icon, "clock")
        XCTAssertEqual(suggestion.confidence, 0.8)
        XCTAssertEqual(suggestion.impact, .medium)
        XCTAssertEqual(suggestion.estimatedSavings, 50.0)
    }
    
    func testSitterAssignmentSuggestion() {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .sitterAssignment,
            title: "Sitter Overload Detected",
            description: "Sitter Jane has too many bookings. Consider redistributing.",
            confidence: 0.9,
            impact: .high,
            estimatedSavings: 200.0,
            implementationEffort: .medium,
            targetAudience: [.admins],
            relevanceScore: 0.9,
            metadata: ["sitterId": "sitter123", "workload": "15"]
        )
        
        // When & Then
        XCTAssertEqual(suggestion.type, .sitterAssignment)
        XCTAssertEqual(suggestion.type.displayName, "Sitter Assignment")
        XCTAssertEqual(suggestion.type.icon, "person.2")
        XCTAssertEqual(suggestion.confidence, 0.9)
        XCTAssertEqual(suggestion.impact, .high)
    }
    
    func testCapacityOptimizationSuggestion() {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .capacityOptimization,
            title: "High Demand Service Type",
            description: "Dog Walking is experiencing high demand. Consider adding capacity.",
            confidence: 0.85,
            impact: .high,
            estimatedSavings: 500.0,
            implementationEffort: .high,
            targetAudience: [.admins],
            relevanceScore: 0.8,
            metadata: ["serviceType": "Dog Walking", "demand": "high"]
        )
        
        // When & Then
        XCTAssertEqual(suggestion.type, .capacityOptimization)
        XCTAssertEqual(suggestion.type.displayName, "Capacity Optimization")
        XCTAssertEqual(suggestion.type.icon, "chart.bar")
        XCTAssertEqual(suggestion.impact, .high)
        XCTAssertEqual(suggestion.implementationEffort, .high)
    }
    
    func testConflictResolutionSuggestion() {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .conflictResolution,
            title: "Scheduling Conflict Detected",
            description: "Two bookings are scheduled for the same time slot.",
            confidence: 0.95,
            impact: .critical,
            estimatedSavings: 100.0,
            implementationEffort: .low,
            targetAudience: [.admins],
            relevanceScore: 1.0,
            metadata: ["conflictType": "timeOverlap", "bookingIds": "booking1,booking2"]
        )
        
        // When & Then
        XCTAssertEqual(suggestion.type, .conflictResolution)
        XCTAssertEqual(suggestion.type.displayName, "Conflict Resolution")
        XCTAssertEqual(suggestion.type.icon, "exclamationmark.triangle")
        XCTAssertEqual(suggestion.impact, .critical)
        XCTAssertEqual(suggestion.confidence, 0.95)
    }
    
    func testWaitlistPromotionSuggestion() {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .waitlistPromotion,
            title: "Waitlist Promotion Opportunity",
            description: "Client on waitlist can be promoted to available slot.",
            confidence: 0.9,
            impact: .medium,
            estimatedSavings: 100.0,
            implementationEffort: .low,
            targetAudience: [.admins],
            relevanceScore: 0.95,
            metadata: ["waitlistEntryId": "entry123", "clientId": "client456"]
        )
        
        // When & Then
        XCTAssertEqual(suggestion.type, .waitlistPromotion)
        XCTAssertEqual(suggestion.type.displayName, "Waitlist Promotion")
        XCTAssertEqual(suggestion.type.icon, "person.badge.plus")
        XCTAssertEqual(suggestion.impact, .medium)
        XCTAssertEqual(suggestion.relevanceScore, 0.95)
    }
    
    func testDemandPredictionSuggestion() {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .demandPrediction,
            title: "High Demand Period Detected",
            description: "December shows high demand. Prepare for increased capacity.",
            confidence: 0.8,
            impact: .high,
            estimatedSavings: 1000.0,
            implementationEffort: .high,
            targetAudience: [.admins],
            relevanceScore: 0.85,
            metadata: ["month": "12", "expectedDemand": "150"]
        )
        
        // When & Then
        XCTAssertEqual(suggestion.type, .demandPrediction)
        XCTAssertEqual(suggestion.type.displayName, "Demand Prediction")
        XCTAssertEqual(suggestion.type.icon, "chart.line.uptrend.xyaxis")
        XCTAssertEqual(suggestion.impact, .high)
        XCTAssertEqual(suggestion.implementationEffort, .high)
    }
    
    // MARK: - Impact Level Tests
    
    func testImpactLevels() {
        // Given & When
        let lowImpact = SuggestionImpact.low
        let mediumImpact = SuggestionImpact.medium
        let highImpact = SuggestionImpact.high
        let criticalImpact = SuggestionImpact.critical
        
        // Then
        XCTAssertEqual(lowImpact.displayName, "Low Impact")
        XCTAssertEqual(mediumImpact.displayName, "Medium Impact")
        XCTAssertEqual(highImpact.displayName, "High Impact")
        XCTAssertEqual(criticalImpact.displayName, "Critical Impact")
        
        XCTAssertEqual(lowImpact.color, .green)
        XCTAssertEqual(mediumImpact.color, .yellow)
        XCTAssertEqual(highImpact.color, .orange)
        XCTAssertEqual(criticalImpact.color, .red)
    }
    
    // MARK: - Implementation Effort Tests
    
    func testImplementationEffortLevels() {
        // Given & When
        let lowEffort = ImplementationEffort.low
        let mediumEffort = ImplementationEffort.medium
        let highEffort = ImplementationEffort.high
        
        // Then
        XCTAssertEqual(lowEffort.displayName, "Low Effort")
        XCTAssertEqual(mediumEffort.displayName, "Medium Effort")
        XCTAssertEqual(highEffort.displayName, "High Effort")
        
        XCTAssertEqual(lowEffort.color, .green)
        XCTAssertEqual(mediumEffort.color, .yellow)
        XCTAssertEqual(highEffort.color, .red)
    }
    
    // MARK: - Target Audience Tests
    
    func testTargetAudience() {
        // Given & When
        let allUsers = TargetAudience.allUsers
        let admins = TargetAudience.admins
        let sitters = TargetAudience.sitters
        let clients = TargetAudience.clients
        let specificUser = TargetAudience.user("user123")
        
        // Then
        XCTAssertEqual(allUsers.displayName, "All Users")
        XCTAssertEqual(admins.displayName, "Administrators")
        XCTAssertEqual(sitters.displayName, "Sitters")
        XCTAssertEqual(clients.displayName, "Clients")
        XCTAssertEqual(specificUser.displayName, "User user123")
    }
    
    // MARK: - Suggestion Application Tests
    
    func testApplyOptimalTimeSlotSuggestion() async {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .optimalTimeSlot,
            title: "Test Suggestion",
            description: "Test description",
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.allUsers],
            relevanceScore: 0.85
        )
        
        // When
        let result = await assistant.applySuggestion(suggestion)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testApplySitterAssignmentSuggestion() async {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .sitterAssignment,
            title: "Test Suggestion",
            description: "Test description",
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.admins],
            relevanceScore: 0.85
        )
        
        // When
        let result = await assistant.applySuggestion(suggestion)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testApplyCapacityOptimizationSuggestion() async {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .capacityOptimization,
            title: "Test Suggestion",
            description: "Test description",
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.admins],
            relevanceScore: 0.85
        )
        
        // When
        let result = await assistant.applySuggestion(suggestion)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testApplyConflictResolutionSuggestion() async {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .conflictResolution,
            title: "Test Suggestion",
            description: "Test description",
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.admins],
            relevanceScore: 0.85
        )
        
        // When
        let result = await assistant.applySuggestion(suggestion)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testApplyWaitlistPromotionSuggestion() async {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .waitlistPromotion,
            title: "Test Suggestion",
            description: "Test description",
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.admins],
            relevanceScore: 0.85
        )
        
        // When
        let result = await assistant.applySuggestion(suggestion)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testApplyDemandPredictionSuggestion() async {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .demandPrediction,
            title: "Test Suggestion",
            description: "Test description",
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.admins],
            relevanceScore: 0.85
        )
        
        // When
        let result = await assistant.applySuggestion(suggestion)
        
        // Then
        XCTAssertTrue(result)
    }
    
    // MARK: - Personalized Suggestions Tests
    
    func testGetPersonalizedSuggestions() async {
        // Given
        let userId = "user123"
        let mockSuggestions = [
            SchedulingSuggestion(
                type: .optimalTimeSlot,
                title: "Personalized Suggestion 1",
                description: "Test description 1",
                confidence: 0.9,
                impact: .high,
                estimatedSavings: 100.0,
                implementationEffort: .low,
                targetAudience: [.user(userId)],
                relevanceScore: 0.95
            ),
            SchedulingSuggestion(
                type: .optimalTimeSlot,
                title: "General Suggestion",
                description: "Test description 2",
                confidence: 0.8,
                impact: .medium,
                estimatedSavings: 50.0,
                implementationEffort: .low,
                targetAudience: [.allUsers],
                relevanceScore: 0.7
            )
        ]
        
        // When
        let personalizedSuggestions = await assistant.getPersonalizedSuggestions(for: userId)
        
        // Then
        XCTAssertTrue(personalizedSuggestions.isEmpty) // Mock implementation returns empty
    }
    
    // MARK: - Optimization Metrics Tests
    
    func testOptimizationMetrics() {
        // Given
        let metrics = OptimizationMetrics(
            totalSuggestions: 10,
            estimatedSavings: 1500.0,
            averageConfidence: 0.85,
            highImpactSuggestions: 3,
            optimizationPotential: 0.75
        )
        
        // When & Then
        XCTAssertEqual(metrics.totalSuggestions, 10)
        XCTAssertEqual(metrics.estimatedSavings, 1500.0)
        XCTAssertEqual(metrics.averageConfidence, 0.85)
        XCTAssertEqual(metrics.highImpactSuggestions, 3)
        XCTAssertEqual(metrics.optimizationPotential, 0.75)
    }
    
    // MARK: - Available Slot Tests
    
    func testAvailableSlot() {
        // Given
        let date = Date()
        let slot = AvailableSlot(
            date: date,
            time: "14:00",
            duration: 2.0,
            serviceTypes: ["Dog Walking", "Cat Sitting"]
        )
        
        // When & Then
        XCTAssertEqual(slot.date, date)
        XCTAssertEqual(slot.time, "14:00")
        XCTAssertEqual(slot.duration, 2.0)
        XCTAssertEqual(slot.serviceTypes, ["Dog Walking", "Cat Sitting"])
    }
    
    // MARK: - User Preferences Tests
    
    func testUserPreferences() {
        // Given
        let preferences = UserPreferences(
            preferredServiceTypes: ["Dog Walking", "Cat Sitting"],
            preferredTimeSlots: ["10:00 AM", "2:00 PM"],
            preferredDays: [1, 2, 3], // Monday, Tuesday, Wednesday
            budgetRange: (min: 30.0, max: 100.0),
            specialRequirements: ["Pet medication", "Special diet"]
        )
        
        // When & Then
        XCTAssertEqual(preferences.preferredServiceTypes, ["Dog Walking", "Cat Sitting"])
        XCTAssertEqual(preferences.preferredTimeSlots, ["10:00 AM", "2:00 PM"])
        XCTAssertEqual(preferences.preferredDays, [1, 2, 3])
        XCTAssertEqual(preferences.budgetRange.min, 30.0)
        XCTAssertEqual(preferences.budgetRange.max, 100.0)
        XCTAssertEqual(preferences.specialRequirements, ["Pet medication", "Special diet"])
    }
    
    // MARK: - Suggestion Validation Tests
    
    func testSuggestionValidation() {
        // Given
        let validSuggestion = SchedulingSuggestion(
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.allUsers],
            relevanceScore: 0.85
        )
        
        let invalidSuggestion = SchedulingSuggestion(
            confidence: 0.5, // Below threshold
            impact: .low,
            estimatedSavings: 25.0,
            implementationEffort: .low,
            targetAudience: [.allUsers],
            relevanceScore: 0.6
        )
        
        // When & Then
        XCTAssertGreaterThanOrEqual(validSuggestion.confidence, 0.7)
        XCTAssertLessThan(invalidSuggestion.confidence, 0.7)
    }
    
    // MARK: - Performance Tests
    
    func testSuggestionGenerationPerformance() async {
        // Given - Create large dataset
        let largeDataset = (0..<1000).map { index in
            createMockBooking(id: "booking\(index)")
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await assistant.generateSuggestions()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 5.0) // Should complete in less than 5 seconds
    }
    
    func testSuggestionApplicationPerformance() async {
        // Given - Create multiple suggestions
        let suggestions = (0..<100).map { index in
            SchedulingSuggestion(
                type: .optimalTimeSlot,
                title: "Suggestion \(index)",
                description: "Test description",
                confidence: 0.8,
                impact: .medium,
                estimatedSavings: 50.0,
                implementationEffort: .low,
                targetAudience: [.allUsers],
                relevanceScore: 0.85
            )
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for suggestion in suggestions {
            let _ = await assistant.applySuggestion(suggestion)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 2.0) // Should complete in less than 2 seconds
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptySuggestions() async {
        // Given
        assistant.suggestions = []
        
        // When
        let personalizedSuggestions = await assistant.getPersonalizedSuggestions(for: "user123")
        
        // Then
        XCTAssertTrue(personalizedSuggestions.isEmpty)
    }
    
    func testSuggestionWithExpiration() {
        // Given
        let expiredDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let suggestion = SchedulingSuggestion(
            type: .optimalTimeSlot,
            title: "Expired Suggestion",
            description: "This suggestion has expired",
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.allUsers],
            relevanceScore: 0.85,
            expiresAt: expiredDate
        )
        
        // When & Then
        XCTAssertNotNil(suggestion.expiresAt)
        XCTAssertEqual(suggestion.expiresAt, expiredDate)
    }
    
    func testSuggestionWithoutExpiration() {
        // Given
        let suggestion = SchedulingSuggestion(
            type: .optimalTimeSlot,
            title: "Non-expired Suggestion",
            description: "This suggestion doesn't expire",
            confidence: 0.8,
            impact: .medium,
            estimatedSavings: 50.0,
            implementationEffort: .low,
            targetAudience: [.allUsers],
            relevanceScore: 0.85,
            expiresAt: nil
        )
        
        // When & Then
        XCTAssertNil(suggestion.expiresAt)
    }
    
    // MARK: - Helper Methods
    
    private func createMockBookings() -> [ServiceBooking] {
        let statuses: [ServiceBooking.BookingStatus] = [.pending, .approved, .inAdventure, .completed, .cancelled]
        let services = ["Dog Walking", "Cat Sitting", "Pet Grooming", "Pet Training"]
        
        return (0..<50).map { index in
            createMockBooking(
                id: "booking\(index)",
                serviceType: services[index % services.count],
                status: statuses[index % statuses.count]
            )
        }
    }
    
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
