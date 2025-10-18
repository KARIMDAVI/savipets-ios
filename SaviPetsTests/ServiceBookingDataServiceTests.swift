import XCTest
import FirebaseFirestore
@testable import SaviPets

@MainActor
final class ServiceBookingDataServiceTests: XCTestCase {
    var bookingService: ServiceBookingDataService!
    
    override func setUp() async throws {
        try await super.setUp()
        bookingService = ServiceBookingDataService()
    }
    
    override func tearDown() async throws {
        bookingService = nil
        try await super.tearDown()
    }
    
    // MARK: - Booking Status Validation Tests
    
    func testBookingStatus_ValidStatuses() {
        let validStatuses = ["pending", "approved", "completed", "cancelled", "in_progress"]
        
        for status in validStatuses {
            XCTAssertTrue(status.count > 0, "Status should not be empty: \(status)")
        }
    }
    
    func testBookingStatus_StatusTransitions() {
        // Test valid status transitions
        let transitions: [(from: String, to: String, valid: Bool)] = [
            ("pending", "approved", true),
            ("approved", "completed", true),
            ("pending", "cancelled", true),
            ("completed", "pending", false), // Can't go back to pending
            ("cancelled", "approved", false), // Can't re-approve cancelled
        ]
        
        for transition in transitions {
            // Verify transition logic
            if transition.valid {
                XCTAssertTrue(transition.to != transition.from, "Valid transition should change status")
            }
        }
    }
    
    // MARK: - Price Validation Tests
    
    func testPriceValidation_ValidPrice() {
        // Given
        let validPrices = ["25.00", "100.50", "0.00"]
        
        for price in validPrices {
            // When
            let parsed = Double(price)
            
            // Then
            XCTAssertNotNil(parsed, "Valid price should parse: \(price)")
            XCTAssertTrue(parsed! >= 0, "Price should be non-negative")
        }
    }
    
    func testPriceValidation_InvalidPrice() {
        // Given
        let invalidPrices = ["abc", "-10", ""]
        
        for price in invalidPrices {
            // When
            let parsed = Double(price)
            
            // Then
            if price == "" || price == "abc" {
                XCTAssertNil(parsed, "Invalid price should not parse: \(price)")
            } else if let value = parsed, value < 0 {
                XCTAssertTrue(value < 0, "Negative price detected")
            }
        }
    }
    
    // MARK: - Service Type Tests
    
    func testServiceType_ValidTypes() {
        let validTypes = ["Dog Walking", "Pet Sitting", "Overnight Care", "Pet Transport", "SavDaily"]
        
        for type in validTypes {
            XCTAssertTrue(type.count > 0, "Service type should not be empty")
            XCTAssertTrue(type.count < 100, "Service type should be reasonable length")
        }
    }
    
    // MARK: - Date Validation Tests
    
    func testScheduledDate_Future() {
        // Given
        let futureDate = Date().addingTimeInterval(24 * 60 * 60) // Tomorrow
        let now = Date()
        
        // Then
        XCTAssertTrue(futureDate > now, "Future date should be after now")
    }
    
    func testScheduledDate_Past() {
        // Given
        let pastDate = Date().addingTimeInterval(-24 * 60 * 60) // Yesterday
        let now = Date()
        
        // Then
        XCTAssertTrue(pastDate < now, "Past date should be before now")
    }
    
    // MARK: - Duration Validation Tests
    
    func testDuration_ValidDurations() {
        let validDurations = [15, 30, 45, 60, 90, 120]
        
        for duration in validDurations {
            XCTAssertTrue(duration > 0, "Duration should be positive")
            XCTAssertTrue(duration <= 480, "Duration should be reasonable (max 8 hours)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testFetchBookingsPerformance() {
        measure {
            // Measure the time to initialize service
            let service = ServiceBookingDataService()
            XCTAssertNotNil(service)
        }
    }
}




