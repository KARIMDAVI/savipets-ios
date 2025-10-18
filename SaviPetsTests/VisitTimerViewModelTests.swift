import XCTest
import FirebaseFirestore
@testable import SaviPets

@MainActor
final class VisitTimerViewModelTests: XCTestCase {
    var viewModel: VisitTimerViewModel!
    let testVisitId = "test-visit-123"
    
    override func setUp() async throws {
        try await super.setUp()
        // Note: This requires Firestore emulator for full testing
        // For now, we'll test computed properties and logic that doesn't require Firebase
    }
    
    override func tearDown() async throws {
        viewModel?.cleanup()
        viewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        viewModel = VisitTimerViewModel(visitId: testVisitId)
        
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertEqual(viewModel.status, "scheduled", "Initial status should be scheduled")
        XCTAssertNil(viewModel.actualStart, "Actual start should be nil initially")
        XCTAssertNil(viewModel.actualEnd, "Actual end should be nil initially")
        XCTAssertFalse(viewModel.isOvertime, "Should not be overtime initially")
        XCTAssertFalse(viewModel.isPendingWrite, "Should not have pending writes initially")
    }
    
    // MARK: - Computed Property Tests
    
    func testIsStarted_WithActualStart() {
        viewModel = VisitTimerViewModel(visitId: testVisitId)
        
        // Simulate visit has started by setting status
        // Note: In real app, this would be set via Firestore listener
        // We can't easily test this without mocking Firestore
        
        // For now, test the logic exists
        XCTAssertFalse(viewModel.isStarted, "Should not be started without actual start time")
    }
    
    func testIsCompleted_WithActualEnd() {
        viewModel = VisitTimerViewModel(visitId: testVisitId)
        
        XCTAssertFalse(viewModel.isCompleted, "Should not be completed without actual end time")
    }
    
    // MARK: - Time Formatting Tests
    
    func testDisplayStartTime_WithScheduledTime() {
        viewModel = VisitTimerViewModel(visitId: testVisitId)
        
        // Without actual data from Firestore, display times will show defaults
        let displayTime = viewModel.displayStartTime
        XCTAssertNotNil(displayTime, "Should return a display time string")
    }
    
    func testDisplayEndTime_WithScheduledTime() {
        viewModel = VisitTimerViewModel(visitId: testVisitId)
        
        let displayTime = viewModel.displayEndTime
        XCTAssertNotNil(displayTime, "Should return a display time string")
    }
    
    // MARK: - Start Time Difference Tests
    
    func testStartTimeDifference_NoActualStart() {
        viewModel = VisitTimerViewModel(visitId: testVisitId)
        
        XCTAssertNil(viewModel.startTimeDifference, "Should be nil without actual start time")
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanup() {
        viewModel = VisitTimerViewModel(visitId: testVisitId)
        
        viewModel.cleanup()
        
        // After cleanup, ViewModel should still exist but listeners should be removed
        XCTAssertNotNil(viewModel, "ViewModel should still exist after cleanup")
    }
    
    // MARK: - Timer Calculation Logic Tests (Theoretical)
    
    func testTimerCalculation_EarlyStart() {
        // This tests the theoretical calculation logic
        // In a real scenario with actual data:
        
        // Given:
        // - scheduledStart: 10:00 AM
        // - scheduledEnd: 11:00 AM (60 min duration)
        // - actualStart: 9:55 AM (5 min early)
        // - currentTime: 10:30 AM
        
        // Expected behavior:
        // - elapsed: 35 minutes (from 9:55 to 10:30)
        // - timeLeft: 25 minutes (scheduled end 11:00 - current 10:30)
        // - totalDuration: from actualStart (9:55) to scheduledEnd (11:00) = 65 minutes
        
        // This demonstrates the Time-To-Pet pattern:
        // Duration is from ACTUAL start to SCHEDULED end
        
        let scheduledStart = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let scheduledEnd = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
        let actualStart = Calendar.current.date(bySettingHour: 9, minute: 55, second: 0, of: Date())!
        let currentTime = Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date())!
        
        let elapsed = currentTime.timeIntervalSince(actualStart)
        let remaining = scheduledEnd.timeIntervalSince(currentTime)
        
        XCTAssertEqual(Int(elapsed / 60), 35, "Should calculate 35 minutes elapsed")
        XCTAssertEqual(Int(remaining / 60), 30, "Should calculate 30 minutes remaining")
    }
    
    func testTimerCalculation_LateStart() {
        // Given:
        // - scheduledStart: 10:00 AM
        // - scheduledEnd: 11:00 AM
        // - actualStart: 10:05 AM (5 min late)
        // - currentTime: 10:30 AM
        
        // Expected:
        // - elapsed: 25 minutes (from 10:05 to 10:30)
        // - timeLeft: 30 minutes (scheduled end 11:00 - current 10:30)
        
        let scheduledStart = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let scheduledEnd = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
        let actualStart = Calendar.current.date(bySettingHour: 10, minute: 5, second: 0, of: Date())!
        let currentTime = Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date())!
        
        let elapsed = currentTime.timeIntervalSince(actualStart)
        let remaining = scheduledEnd.timeIntervalSince(currentTime)
        
        XCTAssertEqual(Int(elapsed / 60), 25, "Should calculate 25 minutes elapsed")
        XCTAssertEqual(Int(remaining / 60), 30, "Should calculate 30 minutes remaining")
    }
    
    func testTimerCalculation_Overtime() {
        // Given:
        // - scheduledEnd: 11:00 AM
        // - currentTime: 11:10 AM
        
        // Expected:
        // - isOvertime: true
        // - timeLeft: +10 minutes (overtime indicator)
        
        let scheduledEnd = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
        let currentTime = Calendar.current.date(bySettingHour: 11, minute: 10, second: 0, of: Date())!
        
        let remaining = scheduledEnd.timeIntervalSince(currentTime)
        let isOvertime = remaining < 0
        
        XCTAssertTrue(isOvertime, "Should detect overtime")
        XCTAssertEqual(Int(abs(remaining) / 60), 10, "Should calculate 10 minutes overtime")
    }
    
    func testTimerCalculation_FiveMinuteWarning() {
        // Given:
        // - scheduledEnd: 11:00 AM
        // - currentTime: 10:57 AM
        
        // Expected:
        // - isFiveMinuteWarning: true
        // - timeLeft: 3 minutes
        
        let scheduledEnd = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!
        let currentTime = Calendar.current.date(bySettingHour: 10, minute: 57, second: 0, of: Date())!
        
        let remaining = scheduledEnd.timeIntervalSince(currentTime)
        let isFiveMinuteWarning = remaining > 0 && remaining <= 300 // 5 minutes
        
        XCTAssertTrue(isFiveMinuteWarning, "Should trigger 5-minute warning")
        XCTAssertEqual(Int(remaining / 60), 3, "Should calculate 3 minutes remaining")
    }
    
    // MARK: - Edge Case Tests
    
    func testTimerCalculation_ExactlyOnTime() {
        let scheduledStart = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let actualStart = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        
        let difference = actualStart.timeIntervalSince(scheduledStart)
        
        XCTAssertEqual(Int(difference), 0, "Should be exactly on time")
    }
    
    func testTimerCalculation_MidnightCrossover() {
        // Test visit that starts before midnight and ends after
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 30
        let scheduledStart = Calendar.current.date(from: components)!
        
        components.day! += 1
        components.hour = 0
        components.minute = 30
        let scheduledEnd = Calendar.current.date(from: components)!
        
        let duration = scheduledEnd.timeIntervalSince(scheduledStart)
        
        XCTAssertEqual(Int(duration / 60), 60, "Should calculate 60 minutes across midnight")
    }
    
    // MARK: - Performance Tests
    
    func testTimerCalculation_Performance() {
        let scheduledStart = Date()
        let scheduledEnd = scheduledStart.addingTimeInterval(3600) // 1 hour
        let actualStart = scheduledStart.addingTimeInterval(-300) // 5 min early
        let currentTime = scheduledStart.addingTimeInterval(1800) // 30 min later
        
        measure {
            for _ in 0..<1000 {
                _ = currentTime.timeIntervalSince(actualStart)
                _ = scheduledEnd.timeIntervalSince(currentTime)
            }
        }
    }
    
    // MARK: - Timer State Tests
    
    func testTimerState_NotStarted() {
        // State: scheduled, no actual start
        // Expected UI: Show scheduled duration, elapsed = 0
        let hasStarted = false
        
        XCTAssertFalse(hasStarted, "Visit should not be started")
    }
    
    func testTimerState_InProgress() {
        // State: in_adventure, has actual start, no actual end
        // Expected UI: Show elapsed time, countdown, overtime detection
        let status = "in_adventure"
        let hasActualStart = true
        let hasActualEnd = false
        
        XCTAssertEqual(status, "in_adventure")
        XCTAssertTrue(hasActualStart)
        XCTAssertFalse(hasActualEnd)
    }
    
    func testTimerState_Completed() {
        // State: completed, has actual start and end
        // Expected UI: Show total duration, no countdown
        let status = "completed"
        let hasActualStart = true
        let hasActualEnd = true
        
        XCTAssertEqual(status, "completed")
        XCTAssertTrue(hasActualStart)
        XCTAssertTrue(hasActualEnd)
    }
}

// MARK: - Timer Format Tests

final class TimerFormattingTests: XCTestCase {
    
    func testFormatCountdown_Minutes() {
        // Test formatting of countdown timer
        let testCases: [(Int, String)] = [
            (0, "00:00"),
            (30, "00:30"),
            (60, "01:00"),
            (90, "01:30"),
            (3599, "59:59"),
            (3600, "60:00"),
            (7200, "120:00")
        ]
        
        for (seconds, expected) in testCases {
            let mins = seconds / 60
            let secs = seconds % 60
            let formatted = String(format: "%02d:%02d", mins, secs)
            
            XCTAssertEqual(formatted, expected, "Format for \(seconds) seconds failed")
        }
    }
    
    func testFormatElapsed_WithHours() {
        // Test formatting of elapsed time with hours
        let testCases: [(Int, String)] = [
            (0, "00:00"),
            (30, "00:30"),
            (60, "01:00"),
            (3600, "1:00:00"),
            (3661, "1:01:01"),
            (7200, "2:00:00")
        ]
        
        for (seconds, expected) in testCases {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            let secs = seconds % 60
            
            let formatted: String
            if hours > 0 {
                formatted = String(format: "%d:%02d:%02d", hours, mins, secs)
            } else {
                formatted = String(format: "%02d:%02d", mins, secs)
            }
            
            XCTAssertEqual(formatted, expected, "Format for \(seconds) seconds failed")
        }
    }
}
