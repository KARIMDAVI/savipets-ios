import XCTest
@testable import SaviPets

/// Tests for Automated Business Rules functionality
@MainActor
final class AutomatedBusinessRulesTests: XCTestCase {
    
    var businessRules: AutomatedBusinessRules!
    var mockBooking: ServiceBooking!
    
    override func setUp() {
        super.setUp()
        businessRules = AutomatedBusinessRules()
        mockBooking = createMockBooking()
    }
    
    override func tearDown() {
        businessRules = nil
        mockBooking = nil
        super.tearDown()
    }
    
    // MARK: - Rule Creation Tests
    
    func testCreateBusinessRule() {
        // Given
        let rule = BusinessRule(
            id: "rule1",
            name: "High Value Booking Alert",
            description: "Alert for bookings over $100",
            conditions: [
                RuleCondition(
                    field: .price,
                    operator: .greaterThan,
                    value: "100.0"
                )
            ],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "High value booking created"]
                )
            ],
            isActive: true,
            priority: 1
        )
        
        // When & Then
        XCTAssertEqual(rule.id, "rule1")
        XCTAssertEqual(rule.name, "High Value Booking Alert")
        XCTAssertEqual(rule.conditions.count, 1)
        XCTAssertEqual(rule.actions.count, 1)
        XCTAssertTrue(rule.isActive)
        XCTAssertEqual(rule.priority, 1)
    }
    
    func testCreateRuleCondition() {
        // Given
        let condition = RuleCondition(
            field: .status,
            operator: .equals,
            value: "completed"
        )
        
        // When & Then
        XCTAssertEqual(condition.field, .status)
        XCTAssertEqual(condition.operator, .equals)
        XCTAssertEqual(condition.value, "completed")
    }
    
    func testCreateRuleAction() {
        // Given
        let action = RuleAction(
            type: .updateStatus,
            parameters: ["status": "approved"]
        )
        
        // When & Then
        XCTAssertEqual(action.type, .updateStatus)
        XCTAssertEqual(action.parameters["status"], "approved")
    }
    
    // MARK: - Rule Evaluation Tests
    
    func testEvaluateRuleWithSingleCondition() {
        // Given
        let rule = BusinessRule(
            id: "rule1",
            name: "Completed Booking Rule",
            description: "Rule for completed bookings",
            conditions: [
                RuleCondition(
                    field: .status,
                    operator: .equals,
                    value: "completed"
                )
            ],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "Booking completed"]
                )
            ],
            isActive: true,
            priority: 1
        )
        
        let booking = createMockBooking(status: .completed)
        
        // When
        let result = evaluateRule(rule, with: booking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testEvaluateRuleWithMultipleConditions() {
        // Given
        let rule = BusinessRule(
            id: "rule1",
            name: "High Value Completed Booking Rule",
            description: "Rule for high value completed bookings",
            conditions: [
                RuleCondition(
                    field: .status,
                    operator: .equals,
                    value: "completed"
                ),
                RuleCondition(
                    field: .price,
                    operator: .greaterThan,
                    value: "50.0"
                )
            ],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "High value booking completed"]
                )
            ],
            isActive: true,
            priority: 1
        )
        
        let booking = createMockBooking(status: .completed, price: "75.00")
        
        // When
        let result = evaluateRule(rule, with: booking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testEvaluateRuleWithFailedCondition() {
        // Given
        let rule = BusinessRule(
            id: "rule1",
            name: "Completed Booking Rule",
            description: "Rule for completed bookings",
            conditions: [
                RuleCondition(
                    field: .status,
                    operator: .equals,
                    value: "completed"
                )
            ],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "Booking completed"]
                )
            ],
            isActive: true,
            priority: 1
        )
        
        let booking = createMockBooking(status: .pending)
        
        // When
        let result = evaluateRule(rule, with: booking)
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Condition Evaluation Tests
    
    func testConditionEvaluationEquals() {
        // Given
        let condition = RuleCondition(
            field: .status,
            operator: .equals,
            value: "approved"
        )
        
        let booking = createMockBooking(status: .approved)
        
        // When
        let result = evaluateCondition(condition, with: booking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testConditionEvaluationNotEquals() {
        // Given
        let condition = RuleCondition(
            field: .status,
            operator: .notEquals,
            value: "cancelled"
        )
        
        let booking = createMockBooking(status: .approved)
        
        // When
        let result = evaluateCondition(condition, with: booking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testConditionEvaluationGreaterThan() {
        // Given
        let condition = RuleCondition(
            field: .price,
            operator: .greaterThan,
            value: "50.0"
        )
        
        let booking = createMockBooking(price: "75.00")
        
        // When
        let result = evaluateCondition(condition, with: booking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testConditionEvaluationLessThan() {
        // Given
        let condition = RuleCondition(
            field: .price,
            operator: .lessThan,
            value: "100.0"
        )
        
        let booking = createMockBooking(price: "75.00")
        
        // When
        let result = evaluateCondition(condition, with: booking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testConditionEvaluationContains() {
        // Given
        let condition = RuleCondition(
            field: .serviceType,
            operator: .contains,
            value: "Walking"
        )
        
        let booking = createMockBooking(serviceType: "Dog Walking")
        
        // When
        let result = evaluateCondition(condition, with: booking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testConditionEvaluationNotContains() {
        // Given
        let condition = RuleCondition(
            field: .serviceType,
            operator: .notContains,
            value: "Grooming"
        )
        
        let booking = createMockBooking(serviceType: "Dog Walking")
        
        // When
        let result = evaluateCondition(condition, with: booking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    // MARK: - Action Execution Tests
    
    func testExecuteNotificationAction() {
        // Given
        let action = RuleAction(
            type: .sendNotification,
            parameters: ["message": "Test notification"]
        )
        
        // When
        let result = executeAction(action, for: mockBooking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testExecuteUpdateStatusAction() {
        // Given
        let action = RuleAction(
            type: .updateStatus,
            parameters: ["status": "approved"]
        )
        
        // When
        let result = executeAction(action, for: mockBooking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testExecuteAssignSitterAction() {
        // Given
        let action = RuleAction(
            type: .assignSitter,
            parameters: ["sitterId": "sitter123"]
        )
        
        // When
        let result = executeAction(action, for: mockBooking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testExecuteSendEmailAction() {
        // Given
        let action = RuleAction(
            type: .sendEmail,
            parameters: ["template": "booking_confirmation", "recipient": "client@example.com"]
        )
        
        // When
        let result = executeAction(action, for: mockBooking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    // MARK: - Field Value Tests
    
    func testGetFieldValueStatus() {
        // Given
        let booking = createMockBooking(status: .approved)
        
        // When
        let value = getFieldValue(.status, from: booking)
        
        // Then
        XCTAssertEqual(value, "approved")
    }
    
    func testGetFieldValuePrice() {
        // Given
        let booking = createMockBooking(price: "75.00")
        
        // When
        let value = getFieldValue(.price, from: booking)
        
        // Then
        XCTAssertEqual(value, "75.00")
    }
    
    func testGetFieldValueServiceType() {
        // Given
        let booking = createMockBooking(serviceType: "Dog Walking")
        
        // When
        let value = getFieldValue(.serviceType, from: booking)
        
        // Then
        XCTAssertEqual(value, "Dog Walking")
    }
    
    func testGetFieldValueSitterName() {
        // Given
        let booking = createMockBooking(sitterName: "Jane Doe")
        
        // When
        let value = getFieldValue(.sitterName, from: booking)
        
        // Then
        XCTAssertEqual(value, "Jane Doe")
    }
    
    func testGetFieldValueAddress() {
        // Given
        let booking = createMockBooking(address: "123 Main St")
        
        // When
        let value = getFieldValue(.address, from: booking)
        
        // Then
        XCTAssertEqual(value, "123 Main St")
    }
    
    func testGetFieldValueNilSitterName() {
        // Given
        let booking = createMockBooking(sitterName: nil)
        
        // When
        let value = getFieldValue(.sitterName, from: booking)
        
        // Then
        XCTAssertEqual(value, "")
    }
    
    // MARK: - Rule Priority Tests
    
    func testRulePriorityOrdering() {
        // Given
        let highPriorityRule = BusinessRule(
            id: "rule1",
            name: "High Priority Rule",
            description: "High priority rule",
            conditions: [],
            actions: [],
            isActive: true,
            priority: 1
        )
        
        let lowPriorityRule = BusinessRule(
            id: "rule2",
            name: "Low Priority Rule",
            description: "Low priority rule",
            conditions: [],
            actions: [],
            isActive: true,
            priority: 10
        )
        
        // When
        let rules = [lowPriorityRule, highPriorityRule]
        let sortedRules = rules.sorted { $0.priority < $1.priority }
        
        // Then
        XCTAssertEqual(sortedRules.first?.id, "rule1")
        XCTAssertEqual(sortedRules.last?.id, "rule2")
    }
    
    // MARK: - Rule Execution Tests
    
    func testRuleExecutionRecording() {
        // Given
        let rule = BusinessRule(
            id: "rule1",
            name: "Test Rule",
            description: "Test rule",
            conditions: [],
            actions: [],
            isActive: true,
            priority: 1
        )
        
        let booking = createMockBooking()
        
        // When
        let execution = recordRuleExecution(rule: rule, booking: booking, result: true)
        
        // Then
        XCTAssertEqual(execution.ruleId, "rule1")
        XCTAssertEqual(execution.bookingId, booking.id)
        XCTAssertTrue(execution.result)
        XCTAssertNotNil(execution.timestamp)
    }
    
    // MARK: - Complex Rule Tests
    
    func testComplexRuleWithMultipleConditions() {
        // Given
        let rule = BusinessRule(
            id: "complex_rule",
            name: "Complex Booking Rule",
            description: "Rule with multiple conditions",
            conditions: [
                RuleCondition(
                    field: .status,
                    operator: .equals,
                    value: "approved"
                ),
                RuleCondition(
                    field: .price,
                    operator: .greaterThan,
                    value: "50.0"
                ),
                RuleCondition(
                    field: .serviceType,
                    operator: .contains,
                    value: "Walking"
                )
            ],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "Complex rule triggered"]
                )
            ],
            isActive: true,
            priority: 1
        )
        
        let booking = createMockBooking(
            status: .approved,
            price: "75.00",
            serviceType: "Dog Walking"
        )
        
        // When
        let result = evaluateRule(rule, with: booking)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testComplexRuleWithFailedCondition() {
        // Given
        let rule = BusinessRule(
            id: "complex_rule",
            name: "Complex Booking Rule",
            description: "Rule with multiple conditions",
            conditions: [
                RuleCondition(
                    field: .status,
                    operator: .equals,
                    value: "approved"
                ),
                RuleCondition(
                    field: .price,
                    operator: .greaterThan,
                    value: "100.0"
                ),
                RuleCondition(
                    field: .serviceType,
                    operator: .contains,
                    value: "Walking"
                )
            ],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "Complex rule triggered"]
                )
            ],
            isActive: true,
            priority: 1
        )
        
        let booking = createMockBooking(
            status: .approved,
            price: "75.00", // Less than 100.0
            serviceType: "Dog Walking"
        )
        
        // When
        let result = evaluateRule(rule, with: booking)
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Performance Tests
    
    func testRuleEvaluationPerformance() {
        // Given
        let rules = (0..<100).map { index in
            BusinessRule(
                id: "rule\(index)",
                name: "Rule \(index)",
                description: "Rule \(index)",
                conditions: [
                    RuleCondition(
                        field: .status,
                        operator: .equals,
                        value: "approved"
                    )
                ],
                actions: [
                    RuleAction(
                        type: .sendNotification,
                        parameters: ["message": "Rule \(index) triggered"]
                    )
                ],
                isActive: true,
                priority: index
            )
        }
        
        let booking = createMockBooking(status: .approved)
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for rule in rules {
            let _ = evaluateRule(rule, with: booking)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0) // Should complete in less than 1 second
    }
    
    // MARK: - Edge Cases Tests
    
    func testRuleWithEmptyConditions() {
        // Given
        let rule = BusinessRule(
            id: "empty_rule",
            name: "Empty Rule",
            description: "Rule with no conditions",
            conditions: [],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "Empty rule triggered"]
                )
            ],
            isActive: true,
            priority: 1
        )
        
        let booking = createMockBooking()
        
        // When
        let result = evaluateRule(rule, with: booking)
        
        // Then
        XCTAssertTrue(result) // Empty conditions should evaluate to true
    }
    
    func testRuleWithEmptyActions() {
        // Given
        let rule = BusinessRule(
            id: "no_action_rule",
            name: "No Action Rule",
            description: "Rule with no actions",
            conditions: [
                RuleCondition(
                    field: .status,
                    operator: .equals,
                    value: "approved"
                )
            ],
            actions: [],
            isActive: true,
            priority: 1
        )
        
        let booking = createMockBooking(status: .approved)
        
        // When
        let result = evaluateRule(rule, with: booking)
        
        // Then
        XCTAssertTrue(result) // Should still evaluate conditions even with no actions
    }
    
    func testInactiveRule() {
        // Given
        let rule = BusinessRule(
            id: "inactive_rule",
            name: "Inactive Rule",
            description: "Inactive rule",
            conditions: [
                RuleCondition(
                    field: .status,
                    operator: .equals,
                    value: "approved"
                )
            ],
            actions: [
                RuleAction(
                    type: .sendNotification,
                    parameters: ["message": "Inactive rule triggered"]
                )
            ],
            isActive: false,
            priority: 1
        )
        
        let booking = createMockBooking(status: .approved)
        
        // When
        let result = evaluateRule(rule, with: booking)
        
        // Then
        XCTAssertFalse(result) // Inactive rules should not evaluate
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
    
    private func evaluateRule(_ rule: BusinessRule, with booking: ServiceBooking) -> Bool {
        guard rule.isActive else { return false }
        
        for condition in rule.conditions {
            if !evaluateCondition(condition, with: booking) {
                return false
            }
        }
        
        return true
    }
    
    private func evaluateCondition(_ condition: RuleCondition, with booking: ServiceBooking) -> Bool {
        let fieldValue = getFieldValue(condition.field, from: booking)
        
        switch condition.operator {
        case .equals:
            return fieldValue == condition.value
        case .notEquals:
            return fieldValue != condition.value
        case .greaterThan:
            return Double(fieldValue) ?? 0.0 > Double(condition.value) ?? 0.0
        case .lessThan:
            return Double(fieldValue) ?? 0.0 < Double(condition.value) ?? 0.0
        case .contains:
            return fieldValue.localizedCaseInsensitiveContains(condition.value)
        case .notContains:
            return !fieldValue.localizedCaseInsensitiveContains(condition.value)
        }
    }
    
    private func executeAction(_ action: RuleAction, for booking: ServiceBooking) -> Bool {
        switch action.type {
        case .sendNotification:
            return true // Mock implementation
        case .updateStatus:
            return true // Mock implementation
        case .assignSitter:
            return true // Mock implementation
        case .sendEmail:
            return true // Mock implementation
        }
    }
    
    private func getFieldValue(_ field: RuleField, from booking: ServiceBooking) -> String {
        switch field {
        case .status:
            return booking.status.rawValue
        case .price:
            return booking.price
        case .serviceType:
            return booking.serviceType
        case .sitterName:
            return booking.sitterName ?? ""
        case .address:
            return booking.address ?? ""
        case .clientId:
            return booking.clientId
        case .scheduledDate:
            return DateFormatter.iso8601.string(from: booking.scheduledDate)
        case .duration:
            return String(booking.duration)
        }
    }
    
    private func recordRuleExecution(rule: BusinessRule, booking: ServiceBooking, result: Bool) -> RuleExecution {
        return RuleExecution(
            id: UUID().uuidString,
            ruleId: rule.id,
            bookingId: booking.id,
            result: result,
            timestamp: Date(),
            context: ["ruleName": rule.name, "bookingStatus": booking.status.rawValue]
        )
    }
}

// MARK: - Helper Extensions

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}
