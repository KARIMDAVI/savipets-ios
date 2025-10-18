import Foundation
import FirebaseFirestore
import OSLog
import Combine

/// Automated business rules engine for smart booking management
@MainActor
final class AutomatedBusinessRules: ObservableObject {
    @Published var rules: [BusinessRule] = []
    @Published var isProcessing: Bool = false
    @Published var lastExecutionTime: Date?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let rulesCollection = "businessRules"
    private let executionsCollection = "ruleExecutions"
    
    // Rule execution queue
    private var executionQueue: [RuleExecution] = []
    
    init() {
        loadRules()
        setupRealTimeProcessing()
    }
    
    // MARK: - Rule Management
    private func loadRules() {
        // Load predefined business rules
        rules = [
            // Auto-approval rules
            BusinessRule(
                id: "auto_approve_regular_clients",
                name: "Auto-approve Regular Clients",
                description: "Automatically approve bookings from clients with 5+ completed bookings",
                type: .autoApproval,
                conditions: [
                    RuleCondition(field: "clientCompletedBookings", operator: .greaterThanOrEqual, value: "5"),
                    RuleCondition(field: "bookingStatus", operator: .equals, value: "pending")
                ],
                actions: [RuleAction(type: .approveBooking, parameters: [:])],
                priority: 1,
                isEnabled: true,
                createdAt: Date(),
                lastModified: Date()
            ),
            
            BusinessRule(
                id: "auto_approve_low_risk_bookings",
                name: "Auto-approve Low Risk Bookings",
                description: "Auto-approve bookings under $50 with 24+ hours notice",
                type: .autoApproval,
                conditions: [
                    RuleCondition(field: "bookingValue", operator: .lessThan, value: "50"),
                    RuleCondition(field: "hoursUntilBooking", operator: .greaterThanOrEqual, value: "24"),
                    RuleCondition(field: "bookingStatus", operator: .equals, value: "pending")
                ],
                actions: [RuleAction(type: .approveBooking, parameters: [:])],
                priority: 2,
                isEnabled: true,
                createdAt: Date(),
                lastModified: Date()
            ),
            
            // Auto-assignment rules
            BusinessRule(
                id: "auto_assign_available_sitters",
                name: "Auto-assign Available Sitters",
                description: "Automatically assign sitters who are available and have high ratings",
                type: .autoAssignment,
                conditions: [
                    RuleCondition(field: "bookingStatus", operator: .equals, value: "approved"),
                    RuleCondition(field: "sitterId", operator: .isNull, value: ""),
                    RuleCondition(field: "availableSittersCount", operator: .greaterThan, value: "0")
                ],
                actions: [
                    RuleAction(type: .assignSitter, parameters: [
                        "criteria": "rating >= 4.5 AND availability = true",
                        "preference": "highest_rating"
                    ])
                ],
                priority: 3,
                isEnabled: true,
                createdAt: Date(),
                lastModified: Date()
            ),
            
            // Pricing rules
            BusinessRule(
                id: "peak_hour_pricing",
                name: "Peak Hour Pricing",
                description: "Apply 20% surcharge for bookings during peak hours (6-8 PM)",
                type: .pricing,
                conditions: [
                    RuleCondition(field: "bookingHour", operator: .greaterThanOrEqual, value: "18"),
                    RuleCondition(field: "bookingHour", operator: .lessThan, value: "20")
                ],
                actions: [
                    RuleAction(type: .adjustPricing, parameters: [
                        "multiplier": "1.2",
                        "reason": "Peak hour surcharge"
                    ])
                ],
                priority: 4,
                isEnabled: true,
                createdAt: Date(),
                lastModified: Date()
            ),
            
            // Cancellation rules
            BusinessRule(
                id: "auto_cancel_old_pending",
                name: "Auto-cancel Old Pending Bookings",
                description: "Automatically cancel pending bookings older than 48 hours",
                type: .autoCancellation,
                conditions: [
                    RuleCondition(field: "bookingStatus", operator: .equals, value: "pending"),
                    RuleCondition(field: "hoursSinceCreated", operator: .greaterThan, value: "48")
                ],
                actions: [
                    RuleAction(type: .cancelBooking, parameters: [
                        "reason": "Auto-cancelled due to no response after 48 hours",
                        "notifyClient": "true"
                    ])
                ],
                priority: 5,
                isEnabled: true,
                createdAt: Date(),
                lastModified: Date()
            ),
            
            // Notification rules
            BusinessRule(
                id: "reminder_notifications",
                name: "Booking Reminders",
                description: "Send reminder notifications for upcoming bookings",
                type: .notification,
                conditions: [
                    RuleCondition(field: "hoursUntilBooking", operator: .equals, value: "24"),
                    RuleCondition(field: "bookingStatus", operator: .equals, value: "approved")
                ],
                actions: [
                    RuleAction(type: .sendNotification, parameters: [
                        "type": "reminder",
                        "title": "Upcoming Booking Reminder",
                        "message": "Your booking is scheduled for tomorrow"
                    ])
                ],
                priority: 6,
                isEnabled: true,
                createdAt: Date(),
                lastModified: Date()
            ),
            
            // Quality assurance rules
            BusinessRule(
                id: "follow_up_completed_bookings",
                name: "Follow-up Completed Bookings",
                description: "Send follow-up requests for completed bookings",
                type: .qualityAssurance,
                conditions: [
                    RuleCondition(field: "bookingStatus", operator: .equals, value: "completed"),
                    RuleCondition(field: "hoursSinceCompletion", operator: .greaterThanOrEqual, value: "2")
                ],
                actions: [
                    RuleAction(type: .sendNotification, parameters: [
                        "type": "follow_up",
                        "title": "How was your service?",
                        "message": "Please rate your recent booking experience"
                    ])
                ],
                priority: 7,
                isEnabled: true,
                createdAt: Date(),
                lastModified: Date()
            )
        ]
    }
    
    // MARK: - Real-time Processing
    private func setupRealTimeProcessing() {
        // Listen to booking changes to trigger rule evaluation
        db.collection("serviceBookings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.data.error("Business rules listener error: \(error.localizedDescription)")
                    return
                }
                
                Task { @MainActor in
                    await self.processBookingChanges(snapshot?.documentChanges ?? [])
                }
            }
    }
    
    private func processBookingChanges(_ changes: [DocumentChange]) async {
        for change in changes {
            if let booking = parseBookingFromDocument(change.document) {
                await evaluateRulesForBooking(booking, changeType: change.type)
            }
        }
    }
    
    // MARK: - Rule Evaluation
    func evaluateRulesForBooking(_ booking: ServiceBooking, changeType: DocumentChangeType) async {
        isProcessing = true
        
        for rule in rules.sorted(by: { $0.priority < $1.priority }) {
            guard rule.isEnabled else { continue }
            
            let context = await buildEvaluationContext(for: booking, changeType: changeType)
            
            if evaluateRule(rule, with: context) {
                await executeRuleActions(rule, for: booking, context: context)
                
                // Record rule execution
                await recordRuleExecution(rule: rule, booking: booking, context: context)
            }
        }
        
        isProcessing = false
        lastExecutionTime = Date()
    }
    
    private func buildEvaluationContext(for booking: ServiceBooking, changeType: DocumentChangeType) async -> RuleEvaluationContext {
        let now = Date()
        let calendar = Calendar.current
        
        // Calculate time-based metrics
        let hoursUntilBooking = booking.scheduledDate.timeIntervalSince(now) / 3600
        let hoursSinceCreated = now.timeIntervalSince(booking.createdAt) / 3600
        let bookingHour = calendar.component(.hour, from: booking.scheduledDate)
        
        // Get client history
        let clientHistory = await getClientBookingHistory(clientId: booking.clientId)
        
        // Get sitter availability
        let availableSitters = await getAvailableSitters(for: booking.scheduledDate)
        
        return RuleEvaluationContext(
            booking: booking,
            changeType: changeType,
            clientCompletedBookings: clientHistory.completed,
            clientTotalBookings: clientHistory.total,
            clientRating: clientHistory.averageRating,
            bookingValue: Double(booking.price) ?? 0,
            hoursUntilBooking: hoursUntilBooking,
            hoursSinceCreated: hoursSinceCreated,
            bookingHour: bookingHour,
            availableSittersCount: availableSitters.count,
            availableSitters: availableSitters,
            currentTime: now
        )
    }
    
    private func evaluateRule(_ rule: BusinessRule, with context: RuleEvaluationContext) -> Bool {
        for condition in rule.conditions {
            if !evaluateCondition(condition, with: context) {
                return false
            }
        }
        return true
    }
    
    private func evaluateCondition(_ condition: RuleCondition, with context: RuleEvaluationContext) -> Bool {
        let fieldValue = getFieldValue(field: condition.field, from: context)
        
        switch condition.operator {
        case .equals:
            return fieldValue == condition.value
        case .notEquals:
            return fieldValue != condition.value
        case .greaterThan:
            return Double(fieldValue) ?? 0 > Double(condition.value) ?? 0
        case .greaterThanOrEqual:
            return Double(fieldValue) ?? 0 >= Double(condition.value) ?? 0
        case .lessThan:
            return Double(fieldValue) ?? 0 < Double(condition.value) ?? 0
        case .lessThanOrEqual:
            return Double(fieldValue) ?? 0 <= Double(condition.value) ?? 0
        case .contains:
            return fieldValue.lowercased().contains(condition.value.lowercased())
        case .isNull:
            return fieldValue.isEmpty
        case .isNotNull:
            return !fieldValue.isEmpty
        }
    }
    
    private func getFieldValue(field: String, from context: RuleEvaluationContext) -> String {
        switch field {
        case "bookingStatus":
            return context.booking.status.rawValue
        case "clientCompletedBookings":
            return String(context.clientCompletedBookings)
        case "clientTotalBookings":
            return String(context.clientTotalBookings)
        case "clientRating":
            return String(context.clientRating)
        case "bookingValue":
            return String(context.bookingValue)
        case "hoursUntilBooking":
            return String(Int(context.hoursUntilBooking))
        case "hoursSinceCreated":
            return String(Int(context.hoursSinceCreated))
        case "bookingHour":
            return String(context.bookingHour)
        case "availableSittersCount":
            return String(context.availableSittersCount)
        case "sitterId":
            return context.booking.sitterId ?? ""
        default:
            return ""
        }
    }
    
    // MARK: - Action Execution
    private func executeRuleActions(_ rule: BusinessRule, for booking: ServiceBooking, context: RuleEvaluationContext) async {
        for action in rule.actions {
            await executeAction(action, for: booking, context: context)
        }
    }
    
    private func executeAction(_ action: RuleAction, for booking: ServiceBooking, context: RuleEvaluationContext) async {
        switch action.type {
        case .approveBooking:
            await approveBooking(booking, reason: "Automated approval by rule: \(action.parameters["reason"] ?? "Business rule")")
            
        case .assignSitter:
            await assignSitterToBooking(booking, context: context, criteria: action.parameters)
            
        case .cancelBooking:
            await cancelBooking(booking, reason: action.parameters["reason"] ?? "Automated cancellation")
            
        case .adjustPricing:
            await adjustBookingPricing(booking, parameters: action.parameters)
            
        case .sendNotification:
            await sendNotification(for: booking, parameters: action.parameters)
            
        case .createFollowUp:
            await createFollowUpTask(for: booking, parameters: action.parameters)
        }
    }
    
    private func approveBooking(_ booking: ServiceBooking, reason: String) async {
        do {
            try await db.collection("serviceBookings").document(booking.id).updateData([
                "status": "approved",
                "approvedAt": FieldValue.serverTimestamp(),
                "approvedBy": "system",
                "approvalReason": reason,
                "lastModified": FieldValue.serverTimestamp(),
                "lastModifiedBy": "system"
            ])
            
            AppLogger.data.info("Auto-approved booking \(booking.id): \(reason)")
            
        } catch {
            AppLogger.data.error("Failed to auto-approve booking \(booking.id): \(error.localizedDescription)")
        }
    }
    
    private func assignSitterToBooking(_ booking: ServiceBooking, context: RuleEvaluationContext, criteria: [String: String]) async {
        // Find best available sitter based on criteria
        guard let bestSitter = await findBestSitter(for: booking, from: context.availableSitters, criteria: criteria) else {
            AppLogger.data.warning("No suitable sitter found for booking \(booking.id)")
            return
        }
        
        do {
            try await db.collection("serviceBookings").document(booking.id).updateData([
                "sitterId": bestSitter.id,
                "sitterName": bestSitter.name,
                "assignedAt": FieldValue.serverTimestamp(),
                "assignedBy": "system",
                "assignmentReason": "Automated assignment by business rule",
                "lastModified": FieldValue.serverTimestamp(),
                "lastModifiedBy": "system"
            ])
            
            AppLogger.data.info("Auto-assigned sitter \(bestSitter.name) to booking \(booking.id)")
            
        } catch {
            AppLogger.data.error("Failed to auto-assign sitter to booking \(booking.id): \(error.localizedDescription)")
        }
    }
    
    private func cancelBooking(_ booking: ServiceBooking, reason: String) async {
        do {
            try await db.collection("serviceBookings").document(booking.id).updateData([
                "status": "cancelled",
                "cancelledAt": FieldValue.serverTimestamp(),
                "cancelledBy": "system",
                "cancellationReason": reason,
                "lastModified": FieldValue.serverTimestamp(),
                "lastModifiedBy": "system"
            ])
            
            AppLogger.data.info("Auto-cancelled booking \(booking.id): \(reason)")
            
        } catch {
            AppLogger.data.error("Failed to auto-cancel booking \(booking.id): \(error.localizedDescription)")
        }
    }
    
    private func adjustBookingPricing(_ booking: ServiceBooking, parameters: [String: String]) async {
        guard let multiplierString = parameters["multiplier"],
              let multiplier = Double(multiplierString),
              let currentPrice = Double(booking.price) else {
            return
        }
        
        let newPrice = currentPrice * multiplier
        let reason = parameters["reason"] ?? "Automated pricing adjustment"
        
        do {
            try await db.collection("serviceBookings").document(booking.id).updateData([
                "price": String(format: "%.2f", newPrice),
                "originalPrice": booking.price,
                "pricingAdjustment": multiplier,
                "pricingReason": reason,
                "lastModified": FieldValue.serverTimestamp(),
                "lastModifiedBy": "system"
            ])
            
            AppLogger.data.info("Adjusted pricing for booking \(booking.id): \(currentPrice) -> \(newPrice) (\(reason))")
            
        } catch {
            AppLogger.data.error("Failed to adjust pricing for booking \(booking.id): \(error.localizedDescription)")
        }
    }
    
    private func sendNotification(for booking: ServiceBooking, parameters: [String: String]) async {
        let notificationService = NotificationService.shared
        
        let title = parameters["title"] ?? "Booking Update"
        let message = parameters["message"] ?? "Your booking has been updated"
        
        // Send notification to client
        await notificationService.sendLocalNotification(
            title: title,
            body: message,
            userInfo: [
                "type": parameters["type"] ?? "general",
                "bookingId": booking.id,
                "clientId": booking.clientId
            ]
        )
        
        AppLogger.data.info("Sent notification for booking \(booking.id): \(title)")
    }
    
    private func createFollowUpTask(for booking: ServiceBooking, parameters: [String: String]) async {
        // Create a follow-up task in the system
        do {
            try await db.collection("followUpTasks").addDocument(data: [
                "bookingId": booking.id,
                "clientId": booking.clientId,
                "type": parameters["type"] ?? "follow_up",
                "title": parameters["title"] ?? "Follow-up Required",
                "description": parameters["description"] ?? "Follow up with client",
                "dueDate": Timestamp(date: Date().addingTimeInterval(24 * 60 * 60)), // 24 hours from now
                "createdAt": Timestamp(date: Date()),
                "createdBy": "system",
                "status": "pending"
            ])
            
            AppLogger.data.info("Created follow-up task for booking \(booking.id)")
            
        } catch {
            AppLogger.data.error("Failed to create follow-up task for booking \(booking.id): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    private func getClientBookingHistory(clientId: String) async -> (completed: Int, total: Int, averageRating: Double) {
        do {
            let snapshot = try await db.collection("serviceBookings")
                .whereField("clientId", isEqualTo: clientId)
                .getDocuments()
            
            let bookings = snapshot.documents.compactMap { parseBookingFromDocument($0) }
            let completed = bookings.filter { $0.status == .completed }.count
            let total = bookings.count
            
            // Calculate average rating (would need ratings collection)
            let averageRating = 4.5 // Placeholder
            
            return (completed: completed, total: total, averageRating: averageRating)
            
        } catch {
            AppLogger.data.error("Failed to get client history: \(error.localizedDescription)")
            return (completed: 0, total: 0, averageRating: 0.0)
        }
    }
    
    private func getAvailableSitters(for date: Date) async -> [SitterProfile] {
        // This would integrate with the SitterDataService
        // For now, return empty array
        return []
    }
    
    private func findBestSitter(for booking: ServiceBooking, from sitters: [SitterProfile], criteria: [String: String]) async -> SitterProfile? {
        // Implement sitter selection logic based on criteria
        // For now, return the first available sitter
        return sitters.first
    }
    
    private func parseBookingFromDocument(_ document: QueryDocumentSnapshot) -> ServiceBooking? {
        // This would use the same parsing logic as in BookingAnalyticsService
        // For brevity, returning nil - in real implementation, this would parse the document
        return nil
    }
    
    private func recordRuleExecution(rule: BusinessRule, booking: ServiceBooking, context: RuleEvaluationContext) async {
        do {
            try await db.collection(executionsCollection).addDocument(data: [
                "ruleId": rule.id,
                "ruleName": rule.name,
                "bookingId": booking.id,
                "executedAt": Timestamp(date: Date()),
                "context": [
                    "bookingStatus": context.booking.status.rawValue,
                    "clientId": context.booking.clientId,
                    "bookingValue": String(context.bookingValue),
                    "hoursUntilBooking": String(context.hoursUntilBooking)
                ]
            ])
        } catch {
            AppLogger.data.error("Failed to record rule execution: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    func addRule(_ rule: BusinessRule) {
        rules.append(rule)
        saveRulesToFirestore()
    }
    
    func updateRule(_ rule: BusinessRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRulesToFirestore()
        }
    }
    
    func deleteRule(_ ruleId: String) {
        rules.removeAll { $0.id == ruleId }
        saveRulesToFirestore()
    }
    
    func toggleRule(_ ruleId: String) {
        if let index = rules.firstIndex(where: { $0.id == ruleId }) {
            rules[index].isEnabled.toggle()
            saveRulesToFirestore()
        }
    }
    
    private func saveRulesToFirestore() {
        // Save rules to Firestore for persistence
        Task {
            do {
                let rulesData = rules.map { $0.toFirestoreData() }
                try await db.collection(rulesCollection).document("active").setData([
                    "rules": rulesData,
                    "lastUpdated": Timestamp(date: Date())
                ])
            } catch {
                AppLogger.data.error("Failed to save rules: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Supporting Models
struct BusinessRule: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let type: RuleType
    let conditions: [RuleCondition]
    let actions: [RuleAction]
    let priority: Int
    var isEnabled: Bool
    let createdAt: Date
    var lastModified: Date
    
    enum RuleType: String, Codable {
        case autoApproval = "auto_approval"
        case autoAssignment = "auto_assignment"
        case autoCancellation = "auto_cancellation"
        case pricing = "pricing"
        case notification = "notification"
        case qualityAssurance = "quality_assurance"
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "description": description,
            "type": type.rawValue,
            "conditions": conditions.map { $0.toFirestoreData() },
            "actions": actions.map { $0.toFirestoreData() },
            "priority": priority,
            "isEnabled": isEnabled,
            "createdAt": Timestamp(date: createdAt),
            "lastModified": Timestamp(date: lastModified)
        ]
    }
}

struct RuleCondition: Codable {
    let field: String
    let `operator`: ConditionOperator
    let value: String
    
    enum ConditionOperator: String, Codable {
        case equals = "equals"
        case notEquals = "not_equals"
        case greaterThan = "greater_than"
        case greaterThanOrEqual = "greater_than_or_equal"
        case lessThan = "less_than"
        case lessThanOrEqual = "less_than_or_equal"
        case contains = "contains"
        case isNull = "is_null"
        case isNotNull = "is_not_null"
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "field": field,
            "operator": `operator`.rawValue,
            "value": value
        ]
    }
}

struct RuleAction: Codable {
    let type: ActionType
    let parameters: [String: String]
    
    enum ActionType: String, Codable {
        case approveBooking = "approve_booking"
        case assignSitter = "assign_sitter"
        case cancelBooking = "cancel_booking"
        case adjustPricing = "adjust_pricing"
        case sendNotification = "send_notification"
        case createFollowUp = "create_follow_up"
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "type": type.rawValue,
            "parameters": parameters
        ]
    }
}

struct RuleEvaluationContext {
    let booking: ServiceBooking
    let changeType: DocumentChangeType
    let clientCompletedBookings: Int
    let clientTotalBookings: Int
    let clientRating: Double
    let bookingValue: Double
    let hoursUntilBooking: TimeInterval
    let hoursSinceCreated: TimeInterval
    let bookingHour: Int
    let availableSittersCount: Int
    let availableSitters: [SitterProfile]
    let currentTime: Date
}

struct RuleExecution: Codable {
    let id: String
    let ruleId: String
    let bookingId: String
    let executedAt: Date
    let context: [String: String] // Changed to String values for Codable
    let success: Bool
    let errorMessage: String?
}
