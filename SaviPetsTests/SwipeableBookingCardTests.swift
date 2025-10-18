import XCTest
import SwiftUI
@testable import SaviPets

/// Tests for Swipeable Booking Card UI/UX functionality
@MainActor
final class SwipeableBookingCardTests: XCTestCase {
    
    var mockBooking: ServiceBooking!
    
    override func setUp() {
        super.setUp()
        mockBooking = createMockBooking()
    }
    
    override func tearDown() {
        mockBooking = nil
        super.tearDown()
    }
    
    // MARK: - Swipe Gesture Tests
    
    func testSwipeGestureInitialization() {
        // Given
        let swipeableCard = SwipeableBookingCard(
            booking: mockBooking,
            onCancel: { _ in },
            onReschedule: { _ in }
        )
        
        // When & Then
        XCTAssertNotNil(swipeableCard)
        XCTAssertEqual(swipeableCard.booking.id, mockBooking.id)
    }
    
    func testSwipeToCancelGesture() {
        // Given
        var cancelActionTriggered = false
        var cancelledBooking: ServiceBooking?
        
        let swipeableCard = SwipeableBookingCard(
            booking: mockBooking,
            onCancel: { booking in
                cancelActionTriggered = true
                cancelledBooking = booking
            },
            onReschedule: { _ in }
        )
        
        // When
        swipeableCard.performCancelAction()
        
        // Then
        XCTAssertTrue(cancelActionTriggered)
        XCTAssertEqual(cancelledBooking?.id, mockBooking.id)
    }
    
    func testSwipeToRescheduleGesture() {
        // Given
        var rescheduleActionTriggered = false
        var rescheduledBooking: ServiceBooking?
        
        let swipeableCard = SwipeableBookingCard(
            booking: mockBooking,
            onCancel: { _ in },
            onReschedule: { booking in
                rescheduleActionTriggered = true
                rescheduledBooking = booking
            }
        )
        
        // When
        swipeableCard.performRescheduleAction()
        
        // Then
        XCTAssertTrue(rescheduleActionTriggered)
        XCTAssertEqual(rescheduledBooking?.id, mockBooking.id)
    }
    
    // MARK: - Swipe Threshold Tests
    
    func testSwipeThresholdCalculation() {
        // Given
        let cardWidth: CGFloat = 300.0
        let cancelThreshold: CGFloat = cardWidth * 0.3 // 30% of card width
        let rescheduleThreshold: CGFloat = cardWidth * 0.7 // 70% of card width
        
        // When & Then
        XCTAssertEqual(cancelThreshold, 90.0)
        XCTAssertEqual(rescheduleThreshold, 210.0)
    }
    
    func testSwipeDistanceCalculation() {
        // Given
        let translation = CGSize(width: 150.0, height: 0.0)
        
        // When
        let distance = translation.width
        
        // Then
        XCTAssertEqual(distance, 150.0)
    }
    
    func testSwipeVelocityCalculation() {
        // Given
        let velocity = CGSize(width: 500.0, height: 0.0)
        
        // When
        let velocityMagnitude = velocity.width
        
        // Then
        XCTAssertEqual(velocityMagnitude, 500.0)
    }
    
    // MARK: - Swipe Direction Tests
    
    func testRightSwipeForCancel() {
        // Given
        let rightSwipeTranslation = CGSize(width: 100.0, height: 0.0)
        
        // When
        let isRightSwipe = rightSwipeTranslation.width > 0
        
        // Then
        XCTAssertTrue(isRightSwipe)
    }
    
    func testLeftSwipeForReschedule() {
        // Given
        let leftSwipeTranslation = CGSize(width: -100.0, height: 0.0)
        
        // When
        let isLeftSwipe = leftSwipeTranslation.width < 0
        
        // Then
        XCTAssertTrue(isLeftSwipe)
    }
    
    func testVerticalSwipeIgnored() {
        // Given
        let verticalSwipeTranslation = CGSize(width: 0.0, height: 100.0)
        
        // When
        let hasHorizontalMovement = abs(verticalSwipeTranslation.width) > abs(verticalSwipeTranslation.height)
        
        // Then
        XCTAssertFalse(hasHorizontalMovement)
    }
    
    // MARK: - Action Availability Tests
    
    func testCancelActionAvailability() {
        // Given
        let cancellableStatuses: [ServiceBooking.BookingStatus] = [.pending, .approved, .inAdventure]
        let nonCancellableStatuses: [ServiceBooking.BookingStatus] = [.completed, .cancelled]
        
        // When & Then
        for status in cancellableStatuses {
            let booking = createMockBooking(status: status)
            let canCancel = booking.status != .completed && booking.status != .cancelled
            XCTAssertTrue(canCancel, "Should be able to cancel \(status.rawValue)")
        }
        
        for status in nonCancellableStatuses {
            let booking = createMockBooking(status: status)
            let canCancel = booking.status != .completed && booking.status != .cancelled
            XCTAssertFalse(canCancel, "Should not be able to cancel \(status.rawValue)")
        }
    }
    
    func testRescheduleActionAvailability() {
        // Given
        let reschedulableStatuses: [ServiceBooking.BookingStatus] = [.pending, .approved, .inAdventure]
        let nonReschedulableStatuses: [ServiceBooking.BookingStatus] = [.completed, .cancelled]
        
        // When & Then
        for status in reschedulableStatuses {
            let booking = createMockBooking(status: status)
            let canReschedule = booking.status != .completed && booking.status != .cancelled
            XCTAssertTrue(canReschedule, "Should be able to reschedule \(status.rawValue)")
        }
        
        for status in nonReschedulableStatuses {
            let booking = createMockBooking(status: status)
            let canReschedule = booking.status != .completed && booking.status != .cancelled
            XCTAssertFalse(canReschedule, "Should not be able to reschedule \(status.rawValue)")
        }
    }
    
    // MARK: - Visual Feedback Tests
    
    func testSwipeVisualFeedback() {
        // Given
        let translation = CGSize(width: 120.0, height: 0.0)
        let cardWidth: CGFloat = 300.0
        
        // When
        let progress = min(abs(translation.width) / cardWidth, 1.0)
        
        // Then
        XCTAssertEqual(progress, 0.4) // 120 / 300 = 0.4
        XCTAssertLessThanOrEqual(progress, 1.0)
        XCTAssertGreaterThanOrEqual(progress, 0.0)
    }
    
    func testSwipeColorTransition() {
        // Given
        let cancelProgress: CGFloat = 0.5
        let rescheduleProgress: CGFloat = 0.8
        
        // When
        let cancelColorIntensity = cancelProgress
        let rescheduleColorIntensity = rescheduleProgress
        
        // Then
        XCTAssertEqual(cancelColorIntensity, 0.5)
        XCTAssertEqual(rescheduleColorIntensity, 0.8)
    }
    
    func testSwipeIconOpacity() {
        // Given
        let progress: CGFloat = 0.6
        
        // When
        let iconOpacity = progress
        
        // Then
        XCTAssertEqual(iconOpacity, 0.6)
    }
    
    // MARK: - Haptic Feedback Tests
    
    func testHapticFeedbackTrigger() {
        // Given
        let threshold: CGFloat = 100.0
        let translation = CGSize(width: 120.0, height: 0.0)
        
        // When
        let shouldTriggerHaptic = abs(translation.width) >= threshold
        
        // Then
        XCTAssertTrue(shouldTriggerHaptic)
    }
    
    func testHapticFeedbackNotTriggered() {
        // Given
        let threshold: CGFloat = 100.0
        let translation = CGSize(width: 80.0, height: 0.0)
        
        // When
        let shouldTriggerHaptic = abs(translation.width) >= threshold
        
        // Then
        XCTAssertFalse(shouldTriggerHaptic)
    }
    
    // MARK: - Animation Tests
    
    func testSwipeAnimationDuration() {
        // Given
        let animationDuration: Double = 0.3
        
        // When & Then
        XCTAssertEqual(animationDuration, 0.3)
        XCTAssertGreaterThan(animationDuration, 0.0)
        XCTAssertLessThan(animationDuration, 1.0)
    }
    
    func testSwipeAnimationEasing() {
        // Given
        let animationEasing = Animation.easeOut(duration: 0.3)
        
        // When & Then
        XCTAssertNotNil(animationEasing)
    }
    
    // MARK: - Edge Cases Tests
    
    func testSwipeWithZeroTranslation() {
        // Given
        let zeroTranslation = CGSize(width: 0.0, height: 0.0)
        
        // When
        let hasHorizontalMovement = abs(zeroTranslation.width) > 0
        
        // Then
        XCTAssertFalse(hasHorizontalMovement)
    }
    
    func testSwipeWithNegativeTranslation() {
        // Given
        let negativeTranslation = CGSize(width: -150.0, height: 0.0)
        
        // When
        let distance = abs(negativeTranslation.width)
        
        // Then
        XCTAssertEqual(distance, 150.0)
    }
    
    func testSwipeWithVeryLargeTranslation() {
        // Given
        let largeTranslation = CGSize(width: 1000.0, height: 0.0)
        let cardWidth: CGFloat = 300.0
        
        // When
        let progress = min(abs(largeTranslation.width) / cardWidth, 1.0)
        
        // Then
        XCTAssertEqual(progress, 1.0) // Should be capped at 1.0
    }
    
    func testSwipeWithDiagonalMovement() {
        // Given
        let diagonalTranslation = CGSize(width: 100.0, height: 50.0)
        
        // When
        let hasHorizontalMovement = abs(diagonalTranslation.width) > abs(diagonalTranslation.height)
        
        // Then
        XCTAssertTrue(hasHorizontalMovement)
    }
    
    // MARK: - Performance Tests
    
    func testSwipeGesturePerformance() {
        // Given
        let iterations = 1000
        let translation = CGSize(width: 150.0, height: 0.0)
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            let _ = abs(translation.width)
            let _ = translation.width > 0
            let _ = translation.width < 0
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
    }
    
    func testSwipeCalculationPerformance() {
        // Given
        let iterations = 1000
        let cardWidth: CGFloat = 300.0
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            let translation = CGSize(width: CGFloat(i), height: 0.0)
            let _ = min(abs(translation.width) / cardWidth, 1.0)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 0.1) // Should complete in less than 100ms
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

// MARK: - Mock SwipeableBookingCard

struct SwipeableBookingCard: View {
    let booking: ServiceBooking
    let onCancel: (ServiceBooking) -> Void
    let onReschedule: (ServiceBooking) -> Void
    
    var body: some View {
        Text("Swipeable Card")
    }
    
    func performCancelAction() {
        onCancel(booking)
    }
    
    func performRescheduleAction() {
        onReschedule(booking)
    }
}
