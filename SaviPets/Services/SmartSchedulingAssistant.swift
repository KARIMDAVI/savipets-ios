import Foundation
import SwiftUI
import Combine
import OSLog

/// AI-powered scheduling assistant that provides intelligent suggestions for booking optimization
@MainActor
final class SmartSchedulingAssistant: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var suggestions: [SchedulingSuggestion] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var optimizationMetrics: OptimizationMetrics?
    
    // MARK: - Private Properties
    
    private let bookingDataService: ServiceBookingDataService
    private let analyticsService: BookingAnalyticsService
    private let businessRules: AutomatedBusinessRules
    private let waitlistService: WaitlistService
    
    // AI Model Configuration
    private let aiModelVersion = "1.0"
    private let maxSuggestionsPerType = 5
    private let confidenceThreshold = 0.7
    
    // MARK: - Initialization
    
    init(
        bookingDataService: ServiceBookingDataService,
        analyticsService: BookingAnalyticsService,
        businessRules: AutomatedBusinessRules,
        waitlistService: WaitlistService
    ) {
        self.bookingDataService = bookingDataService
        self.analyticsService = analyticsService
        self.businessRules = businessRules
        self.waitlistService = waitlistService
    }
    
    // MARK: - Public Methods
    
    /// Generate AI-powered scheduling suggestions based on current data
    func generateSuggestions() async {
        isLoading = true
        errorMessage = nil
        
        // Gather data for AI analysis
        let bookingData = await gatherBookingData()
        let analyticsData = await gatherAnalyticsData()
        let waitlistData = await gatherWaitlistData()
        
        // Generate AI suggestions
        let aiSuggestions = await analyzeWithAI(
            bookingData: bookingData,
            analyticsData: analyticsData,
            waitlistData: waitlistData
        )
        
        // Process and validate suggestions
        let validatedSuggestions = await validateSuggestions(aiSuggestions)
        
        // Update UI
        await MainActor.run {
            self.suggestions = validatedSuggestions
            self.optimizationMetrics = calculateOptimizationMetrics(from: validatedSuggestions)
            self.isLoading = false
        }
        
        AppLogger.data.info("Generated \(validatedSuggestions.count) scheduling suggestions")
    }
    
    /// Generate suggestions for a specific date range
    func generateSuggestions(for dateRange: DateInterval) async {
        isLoading = true
        errorMessage = nil
        
        let bookingData = await gatherBookingData(for: dateRange)
        let analyticsData = await gatherAnalyticsData(for: dateRange)
        
        let aiSuggestions = await analyzeWithAI(
            bookingData: bookingData,
            analyticsData: analyticsData,
            waitlistData: []
        )
        
        let validatedSuggestions = await validateSuggestions(aiSuggestions)
        
        await MainActor.run {
            self.suggestions = validatedSuggestions
            self.isLoading = false
        }
    }
    
    /// Apply a scheduling suggestion
    func applySuggestion(_ suggestion: SchedulingSuggestion) async -> Bool {
        switch suggestion.type {
        case .optimalTimeSlot:
            return await applyOptimalTimeSlotSuggestion(suggestion)
        case .sitterAssignment:
            return await applySitterAssignmentSuggestion(suggestion)
        case .capacityOptimization:
            return await applyCapacityOptimizationSuggestion(suggestion)
        case .conflictResolution:
            return await applyConflictResolutionSuggestion(suggestion)
        case .waitlistPromotion:
            return await applyWaitlistPromotionSuggestion(suggestion)
        case .demandPrediction:
            return await applyDemandPredictionSuggestion(suggestion)
        }
    }
    
    /// Get personalized suggestions for a specific user
    func getPersonalizedSuggestions(for userId: String) async -> [SchedulingSuggestion] {
        let userBookings = await bookingDataService.getUserBookings(userId: userId)
        let _ = await analyzeUserPreferences(userBookings)
        
        let personalizedSuggestions = suggestions.filter { suggestion in
            suggestion.relevanceScore >= 0.8 && 
            suggestion.targetAudience.contains { audience in
                if case .user(let id) = audience {
                    return id == userId
                }
                return false
            }
        }
        
        return personalizedSuggestions.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    // MARK: - Private Methods
    
    private func gatherBookingData() async -> [ServiceBooking] {
        return await bookingDataService.getAllBookings()
    }
    
    private func gatherBookingData(for dateRange: DateInterval) async -> [ServiceBooking] {
        return await bookingDataService.getBookings(
            from: dateRange.start,
            to: dateRange.end
        )
    }
    
    private func gatherAnalyticsData() async -> BookingAnalytics {
        let bookings = await gatherBookingData()
        return analyticsService.fetchBookingMetrics(
            timeRange: AnalyticsTimeframe.last30Days,
            bookings: bookings
        )
    }
    
    private func gatherAnalyticsData(for dateRange: DateInterval) async -> BookingAnalytics {
        let bookings = await gatherBookingData(for: dateRange)
        return analyticsService.fetchBookingMetrics(
            timeRange: AnalyticsTimeframe.last30Days,
            bookings: bookings
        )
    }
    
    private func gatherWaitlistData() async -> [WaitlistEntry] {
        return waitlistService.waitlistEntries
    }
    
    private func analyzeWithAI(
        bookingData: [ServiceBooking],
        analyticsData: BookingAnalytics,
        waitlistData: [WaitlistEntry]
    ) async -> [SchedulingSuggestion] {
        
        var suggestions: [SchedulingSuggestion] = []
        
        // Analyze booking patterns
        let patternSuggestions = await analyzeBookingPatterns(bookingData)
        suggestions.append(contentsOf: patternSuggestions)
        
        // Analyze capacity utilization
        let capacitySuggestions = await analyzeCapacityUtilization(bookingData, analyticsData)
        suggestions.append(contentsOf: capacitySuggestions)
        
        // Analyze sitter performance
        let sitterSuggestions = await analyzeSitterPerformance(bookingData)
        suggestions.append(contentsOf: sitterSuggestions)
        
        // Analyze waitlist opportunities
        let waitlistSuggestions = await analyzeWaitlistOpportunities(waitlistData, bookingData)
        suggestions.append(contentsOf: waitlistSuggestions)
        
        // Analyze demand patterns
        let demandSuggestions = await analyzeDemandPatterns(bookingData, analyticsData)
        suggestions.append(contentsOf: demandSuggestions)
        
        return suggestions
    }
    
    private func analyzeBookingPatterns(_ bookings: [ServiceBooking]) async -> [SchedulingSuggestion] {
        var suggestions: [SchedulingSuggestion] = []
        
        // Analyze peak hours
        let hourlyDistribution = Dictionary(grouping: bookings, by: { booking in
            let timeComponents = booking.scheduledTime.components(separatedBy: ":")
            return Int(timeComponents.first ?? "0") ?? 0
        }).mapValues { $0.count }
        
        let _ = hourlyDistribution.sorted { $0.value > $1.value }.prefix(3)
        let offPeakHours = hourlyDistribution.sorted { $0.value < $1.value }.prefix(3)
        
        // Suggest optimal time slots
        for (hour, count) in offPeakHours {
            if count < hourlyDistribution.values.max() ?? 0 {
                let suggestion = SchedulingSuggestion(
                    id: UUID().uuidString,
                    type: .optimalTimeSlot,
                    title: "Optimal Time Slot Available",
                    description: "Consider scheduling at \(hour):00 for better availability and potentially lower rates.",
                    confidence: 0.8,
                    impact: .medium,
                    estimatedSavings: calculateTimeSlotSavings(hour: hour, currentBookings: count),
                    implementationEffort: .low,
                    targetAudience: [.allUsers],
                    relevanceScore: 0.85,
                    metadata: [
                        "hour": String(hour),
                        "currentBookings": String(count),
                        "peakHourBookings": String(hourlyDistribution.values.max() ?? 0)
                    ]
                )
                suggestions.append(suggestion)
            }
        }
        
        return suggestions
    }
    
    private func analyzeCapacityUtilization(_ bookings: [ServiceBooking], _ metrics: BookingAnalytics) async -> [SchedulingSuggestion] {
        var suggestions: [SchedulingSuggestion] = []
        
        // Analyze service type capacity
        let serviceTypeDistribution = Dictionary(grouping: bookings, by: { $0.serviceType })
            .mapValues { $0.count }
        
        let totalBookings = bookings.count
        let averageBookingsPerService = totalBookings / serviceTypeDistribution.count
        
        for (serviceType, count) in serviceTypeDistribution {
            let utilizationRate = Double(count) / Double(averageBookingsPerService)
            
            if utilizationRate > 1.5 {
                // Over-utilized service
                let suggestion = SchedulingSuggestion(
                    id: UUID().uuidString,
                    type: .capacityOptimization,
                    title: "High Demand Service Type",
                    description: "\(serviceType) is experiencing high demand (\(count) bookings). Consider adding more capacity or promoting alternative services.",
                    confidence: 0.9,
                    impact: .high,
                    estimatedSavings: calculateCapacityOptimizationSavings(serviceType: serviceType, currentCount: count),
                    implementationEffort: .medium,
                    targetAudience: [.admins],
                    relevanceScore: 0.9,
                    metadata: [
                        "serviceType": serviceType,
                        "currentCount": String(count),
                        "utilizationRate": String(utilizationRate)
                    ]
                )
                suggestions.append(suggestion)
            } else if utilizationRate < 0.5 {
                // Under-utilized service
                let suggestion = SchedulingSuggestion(
                    id: UUID().uuidString,
                    type: .capacityOptimization,
                    title: "Underutilized Service Type",
                    description: "\(serviceType) has low demand (\(count) bookings). Consider promotional campaigns or adjusting pricing.",
                    confidence: 0.8,
                    impact: .medium,
                    estimatedSavings: calculatePromotionalSavings(serviceType: serviceType),
                    implementationEffort: .low,
                    targetAudience: [.admins],
                    relevanceScore: 0.75,
                    metadata: [
                        "serviceType": serviceType,
                        "currentCount": String(count),
                        "utilizationRate": String(utilizationRate)
                    ]
                )
                suggestions.append(suggestion)
            }
        }
        
        return suggestions
    }
    
    private func analyzeSitterPerformance(_ bookings: [ServiceBooking]) async -> [SchedulingSuggestion] {
        var suggestions: [SchedulingSuggestion] = []
        
        // Analyze sitter workload distribution
        let sitterWorkload = Dictionary(grouping: bookings.filter { $0.sitterId != nil }, by: { $0.sitterId! })
            .mapValues { $0.count }
        
        let averageWorkload = sitterWorkload.values.reduce(0, +) / max(sitterWorkload.count, 1)
        
        for (sitterId, workload) in sitterWorkload {
            if workload > Int(Double(averageWorkload) * 1.5) {
                // Overworked sitter
                let suggestion = SchedulingSuggestion(
                    id: UUID().uuidString,
                    type: .sitterAssignment,
                    title: "Sitter Overload Detected",
                    description: "Sitter \(sitterId) has \(workload) bookings (above average of \(averageWorkload)). Consider redistributing some bookings.",
                    confidence: 0.85,
                    impact: .high,
                    estimatedSavings: calculateSitterOptimizationSavings(currentWorkload: workload, averageWorkload: averageWorkload),
                    implementationEffort: .medium,
                    targetAudience: [.admins],
                    relevanceScore: 0.9,
                    metadata: [
                        "sitterId": sitterId,
                        "currentWorkload": String(workload),
                        "averageWorkload": String(averageWorkload)
                    ]
                )
                suggestions.append(suggestion)
            }
        }
        
        return suggestions
    }
    
    private func analyzeWaitlistOpportunities(_ waitlistEntries: [WaitlistEntry], _ bookings: [ServiceBooking]) async -> [SchedulingSuggestion] {
        var suggestions: [SchedulingSuggestion] = []
        
        // Find potential matches between waitlist and available slots
        let availableSlots = findAvailableSlots(in: bookings)
        
        for waitlistEntry in waitlistEntries {
            for slot in availableSlots {
                if isCompatibleSlot(waitlistEntry: waitlistEntry, slot: slot) {
                    let suggestion = SchedulingSuggestion(
                        id: UUID().uuidString,
                        type: .waitlistPromotion,
                        title: "Waitlist Promotion Opportunity",
                        description: "Client \(waitlistEntry.clientId) on waitlist for \(waitlistEntry.serviceType) can be promoted to available slot.",
                        confidence: 0.9,
                        impact: .medium,
                        estimatedSavings: calculateWaitlistPromotionSavings(waitlistEntry: waitlistEntry),
                        implementationEffort: .low,
                        targetAudience: [.admins],
                        relevanceScore: 0.95,
                        metadata: [
                            "waitlistEntryId": waitlistEntry.id,
                            "clientId": waitlistEntry.clientId,
                            "serviceType": waitlistEntry.serviceType,
                            "slotDate": slot.date.description,
                            "slotTime": slot.time
                        ]
                    )
                    suggestions.append(suggestion)
                }
            }
        }
        
        return suggestions
    }
    
    private func analyzeDemandPatterns(_ bookings: [ServiceBooking], _ metrics: BookingAnalytics) async -> [SchedulingSuggestion] {
        var suggestions: [SchedulingSuggestion] = []
        
        // Analyze seasonal patterns
        let monthlyDistribution = Dictionary(grouping: bookings, by: { booking in
            Calendar.current.component(.month, from: booking.scheduledDate)
        }).mapValues { $0.count }
        
        let averageMonthlyBookings = monthlyDistribution.values.reduce(0, +) / max(monthlyDistribution.count, 1)
        
        for (month, count) in monthlyDistribution {
            if count > Int(Double(averageMonthlyBookings) * 1.3) {
                let monthName = DateFormatter().monthSymbols[month - 1]
                let suggestion = SchedulingSuggestion(
                    id: UUID().uuidString,
                    type: .demandPrediction,
                    title: "High Demand Period Detected",
                    description: "\(monthName) shows high demand (\(count) bookings). Prepare for increased capacity needs.",
                    confidence: 0.8,
                    impact: .high,
                    estimatedSavings: calculateDemandPredictionSavings(month: month, expectedDemand: count),
                    implementationEffort: .high,
                    targetAudience: [.admins],
                    relevanceScore: 0.85,
                    metadata: [
                        "month": String(month),
                        "monthName": monthName,
                        "currentDemand": String(count),
                        "averageDemand": String(averageMonthlyBookings)
                    ]
                )
                suggestions.append(suggestion)
            }
        }
        
        return suggestions
    }
    
    private func validateSuggestions(_ suggestions: [SchedulingSuggestion]) async -> [SchedulingSuggestion] {
        return suggestions
            .filter { $0.confidence >= confidenceThreshold }
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(maxSuggestionsPerType * 6) // 6 types of suggestions
            .map { $0 }
    }
    
    private func calculateOptimizationMetrics(from suggestions: [SchedulingSuggestion]) -> OptimizationMetrics {
        let totalSavings = suggestions.reduce(0) { $0 + $1.estimatedSavings }
        let averageConfidence = suggestions.isEmpty ? 0 : suggestions.reduce(0) { $0 + $1.confidence } / Double(suggestions.count)
        let highImpactCount = suggestions.filter { $0.impact == .high }.count
        
        return OptimizationMetrics(
            totalSuggestions: suggestions.count,
            estimatedSavings: totalSavings,
            averageConfidence: averageConfidence,
            highImpactSuggestions: highImpactCount,
            optimizationPotential: calculateOptimizationPotential(suggestions)
        )
    }
    
    // MARK: - Suggestion Application Methods
    
    private func applyOptimalTimeSlotSuggestion(_ suggestion: SchedulingSuggestion) async -> Bool {
        // Implementation for applying optimal time slot suggestions
        AppLogger.data.info("Applying optimal time slot suggestion: \(suggestion.title)")
        return true
    }
    
    private func applySitterAssignmentSuggestion(_ suggestion: SchedulingSuggestion) async -> Bool {
        // Implementation for applying sitter assignment suggestions
        AppLogger.data.info("Applying sitter assignment suggestion: \(suggestion.title)")
        return true
    }
    
    private func applyCapacityOptimizationSuggestion(_ suggestion: SchedulingSuggestion) async -> Bool {
        // Implementation for applying capacity optimization suggestions
        AppLogger.data.info("Applying capacity optimization suggestion: \(suggestion.title)")
        return true
    }
    
    private func applyConflictResolutionSuggestion(_ suggestion: SchedulingSuggestion) async -> Bool {
        // Implementation for applying conflict resolution suggestions
        AppLogger.data.info("Applying conflict resolution suggestion: \(suggestion.title)")
        return true
    }
    
    private func applyWaitlistPromotionSuggestion(_ suggestion: SchedulingSuggestion) async -> Bool {
        // Implementation for applying waitlist promotion suggestions
        AppLogger.data.info("Applying waitlist promotion suggestion: \(suggestion.title)")
        return true
    }
    
    private func applyDemandPredictionSuggestion(_ suggestion: SchedulingSuggestion) async -> Bool {
        // Implementation for applying demand prediction suggestions
        AppLogger.data.info("Applying demand prediction suggestion: \(suggestion.title)")
        return true
    }
    
    // MARK: - Helper Methods
    
    private func calculateTimeSlotSavings(hour: Int, currentBookings: Int) -> Double {
        // Calculate potential savings from optimal time slot
        let baseRate = 50.0
        let offPeakDiscount = 0.1 // 10% discount for off-peak hours
        return baseRate * offPeakDiscount * Double(currentBookings)
    }
    
    private func calculateCapacityOptimizationSavings(serviceType: String, currentCount: Int) -> Double {
        // Calculate savings from capacity optimization
        let baseRate = 75.0
        return baseRate * Double(currentCount) * 0.15 // 15% efficiency gain
    }
    
    private func calculatePromotionalSavings(serviceType: String) -> Double {
        // Calculate potential revenue from promotional campaigns
        return 500.0 // Estimated monthly revenue increase
    }
    
    private func calculateSitterOptimizationSavings(currentWorkload: Int, averageWorkload: Int) -> Double {
        // Calculate savings from sitter workload optimization
        let overloadFactor = Double(currentWorkload - averageWorkload) / Double(averageWorkload)
        return 200.0 * overloadFactor // $200 per overload factor
    }
    
    private func calculateWaitlistPromotionSavings(waitlistEntry: WaitlistEntry) -> Double {
        // Calculate savings from waitlist promotion
        return 100.0 // Estimated value per waitlist conversion
    }
    
    private func calculateDemandPredictionSavings(month: Int, expectedDemand: Int) -> Double {
        // Calculate savings from demand prediction
        return Double(expectedDemand) * 25.0 // $25 per booking optimization
    }
    
    private func calculateOptimizationPotential(_ suggestions: [SchedulingSuggestion]) -> Double {
        let totalPotential = suggestions.reduce(0) { $0 + $1.estimatedSavings }
        return min(totalPotential / 1000.0, 1.0) // Normalize to 0-1 scale
    }
    
    private func findAvailableSlots(in bookings: [ServiceBooking]) -> [AvailableSlot] {
        // Find available time slots by analyzing gaps in the schedule
        var slots: [AvailableSlot] = []
        
        // Group bookings by date
        let bookingsByDate = Dictionary(grouping: bookings, by: { 
            Calendar.current.startOfDay(for: $0.scheduledDate)
        })
        
        for (date, dayBookings) in bookingsByDate {
            let sortedBookings = dayBookings.sorted { $0.scheduledTime < $1.scheduledTime }
            
            // Find gaps between bookings
            for i in 0..<(sortedBookings.count - 1) {
                let currentBooking = sortedBookings[i]
                let nextBooking = sortedBookings[i + 1]
                
                // Check if there's a gap of at least 2 hours
                if let currentEndTime = parseTime(currentBooking.scheduledTime),
                   let nextStartTime = parseTime(nextBooking.scheduledTime) {
                    
                    let gap = nextStartTime - currentEndTime
                    if gap >= 2.0 { // 2 hours minimum gap
                        let slot = AvailableSlot(
                            date: date,
                            time: formatTime(currentEndTime + 1.0), // 1 hour after current booking
                            duration: 2.0,
                            serviceTypes: ["Dog Walking", "Cat Sitting"] // Default available services
                        )
                        slots.append(slot)
                    }
                }
            }
        }
        
        return slots
    }
    
    private func isCompatibleSlot(waitlistEntry: WaitlistEntry, slot: AvailableSlot) -> Bool {
        // Check if waitlist entry is compatible with available slot
        let isSameDate = Calendar.current.isDate(waitlistEntry.requestedDate, inSameDayAs: slot.date)
        let isSameService = slot.serviceTypes.contains(waitlistEntry.serviceType)
        let isCompatibleDuration = slot.duration >= Double(waitlistEntry.duration) / 60.0
        
        return isSameDate && isSameService && isCompatibleDuration
    }
    
    private func analyzeUserPreferences(_ bookings: [ServiceBooking]) async -> UserPreferences {
        // Analyze user booking patterns to determine preferences
        let serviceTypes = bookings.map { $0.serviceType }
        let preferredServiceType = Dictionary(grouping: serviceTypes, by: { $0 })
            .mapValues { $0.count }
            .max { $0.value < $1.value }?.key ?? "Dog Walking"
        
        let preferredTimes = bookings.map { $0.scheduledTime }
        let preferredTime = Dictionary(grouping: preferredTimes, by: { $0 })
            .mapValues { $0.count }
            .max { $0.value < $1.value }?.key ?? "10:00 AM"
        
        return UserPreferences(
            preferredServiceTypes: [preferredServiceType],
            preferredTimeSlots: [preferredTime],
            preferredDays: [],
            budgetMin: 30.0,
            budgetMax: 100.0,
            specialRequirements: []
        )
    }
    
    private func parseTime(_ timeString: String) -> Double? {
        let components = timeString.components(separatedBy: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1].components(separatedBy: " ").first ?? "0") else {
            return nil
        }
        
        return Double(hour) + Double(minute) / 60.0
    }
    
    private func formatTime(_ timeInHours: Double) -> String {
        let hour = Int(timeInHours)
        let minute = Int((timeInHours - Double(hour)) * 60)
        return String(format: "%d:%02d", hour, minute)
    }
}

// MARK: - Data Models

struct SchedulingSuggestion: Identifiable, Codable {
    let id: String
    let type: SuggestionType
    let title: String
    let description: String
    let confidence: Double // 0.0 to 1.0
    let impact: SuggestionImpact
    let estimatedSavings: Double
    let implementationEffort: ImplementationEffort
    let targetAudience: [TargetAudience]
    let relevanceScore: Double // 0.0 to 1.0
    let metadata: [String: String]
    let createdAt: Date
    let expiresAt: Date?
    
    init(
        id: String = UUID().uuidString,
        type: SuggestionType,
        title: String,
        description: String,
        confidence: Double,
        impact: SuggestionImpact,
        estimatedSavings: Double,
        implementationEffort: ImplementationEffort,
        targetAudience: [TargetAudience],
        relevanceScore: Double,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.confidence = confidence
        self.impact = impact
        self.estimatedSavings = estimatedSavings
        self.implementationEffort = implementationEffort
        self.targetAudience = targetAudience
        self.relevanceScore = relevanceScore
        self.metadata = metadata
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

enum SuggestionType: String, CaseIterable, Codable {
    case optimalTimeSlot = "optimal_time_slot"
    case sitterAssignment = "sitter_assignment"
    case capacityOptimization = "capacity_optimization"
    case conflictResolution = "conflict_resolution"
    case waitlistPromotion = "waitlist_promotion"
    case demandPrediction = "demand_prediction"
    
    var displayName: String {
        switch self {
        case .optimalTimeSlot: return "Optimal Time Slot"
        case .sitterAssignment: return "Sitter Assignment"
        case .capacityOptimization: return "Capacity Optimization"
        case .conflictResolution: return "Conflict Resolution"
        case .waitlistPromotion: return "Waitlist Promotion"
        case .demandPrediction: return "Demand Prediction"
        }
    }
    
    var icon: String {
        switch self {
        case .optimalTimeSlot: return "clock"
        case .sitterAssignment: return "person.2"
        case .capacityOptimization: return "chart.bar"
        case .conflictResolution: return "exclamationmark.triangle"
        case .waitlistPromotion: return "person.badge.plus"
        case .demandPrediction: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum SuggestionImpact: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low Impact"
        case .medium: return "Medium Impact"
        case .high: return "High Impact"
        case .critical: return "Critical Impact"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

enum ImplementationEffort: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low Effort"
        case .medium: return "Medium Effort"
        case .high: return "High Effort"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

enum TargetAudience: Codable {
    case allUsers
    case admins
    case sitters
    case clients
    case user(String) // Specific user ID
    
    var displayName: String {
        switch self {
        case .allUsers: return "All Users"
        case .admins: return "Administrators"
        case .sitters: return "Sitters"
        case .clients: return "Clients"
        case .user(let id): return "User \(id)"
        }
    }
}

struct OptimizationMetrics: Codable {
    let totalSuggestions: Int
    let estimatedSavings: Double
    let averageConfidence: Double
    let highImpactSuggestions: Int
    let optimizationPotential: Double // 0.0 to 1.0
}

struct AvailableSlot: Codable {
    let date: Date
    let time: String
    let duration: Double // in hours
    let serviceTypes: [String]
}

struct UserPreferences: Codable {
    let preferredServiceTypes: [String]
    let preferredTimeSlots: [String]
    let preferredDays: [Int] // 1-7 (Monday-Sunday)
    let budgetMin: Double
    let budgetMax: Double
    let specialRequirements: [String]
    
    var budgetRange: (min: Double, max: Double) {
        return (min: budgetMin, max: budgetMax)
    }
}

// MARK: - Extensions


// MARK: - Service Extensions

extension ServiceBookingDataService {
    func getAllBookings() async -> [ServiceBooking] {
        // Implementation to get all bookings
        return []
    }
    
    func getBookings(from startDate: Date, to endDate: Date) async -> [ServiceBooking] {
        // Implementation to get bookings in date range
        return []
    }
    
    func getUserBookings(userId: String) async -> [ServiceBooking] {
        // Implementation to get user-specific bookings
        return []
    }
}

extension BookingAnalyticsService {
    func fetchBookingMetrics(timeRange: AnalyticsTimeframe, bookings: [ServiceBooking]) -> BookingAnalytics {
        // Implementation to fetch analytics metrics
        return BookingAnalytics(
            totalBookings: bookings.count,
            completedBookings: bookings.filter { $0.status == .completed }.count,
            cancelledBookings: bookings.filter { $0.status == .cancelled }.count,
            averageBookingValue: bookings.count > 0 ? bookings.compactMap { Double($0.price) }.reduce(0, +) / Double(bookings.count) : 0,
            bookingTrends: [],
            peakHours: [],
            seasonalTrends: [],
            serviceDistribution: [],
            customerSegments: []
        )
    }
}

