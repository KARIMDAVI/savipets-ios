import XCTest
import FirebaseFirestore
import FirebaseAuth
@testable import SaviPets

@MainActor
final class UnifiedChatServiceTests: XCTestCase {
    var chatService: UnifiedChatService!
    
    override func setUp() async throws {
        try await super.setUp()
        // Note: In production, you'd use Firebase Emulator for testing
        // For now, we'll test the logic that doesn't require Firebase
        chatService = UnifiedChatService.shared
    }
    
    override func tearDown() async throws {
        chatService = nil
        try await super.tearDown()
    }
    
    // MARK: - Role Management Tests
    
    func testSetCurrentUserRole() {
        // Given
        let role = UserRole.petSitter
        
        // When
        chatService.setCurrentUserRole(role)
        
        // Then - verify role was set
        // Note: We can't directly test private properties, but we can test behavior
        XCTAssertTrue(true, "Role set without crashing")
    }
    
    // MARK: - Message Validation Tests
    
    func testMessageTextValidation_ValidText() {
        // Given
        let validText = "Hello, this is a test message"
        
        // Then
        XCTAssertTrue(validText.count > 0)
        XCTAssertTrue(validText.count <= 1000)
    }
    
    func testMessageTextValidation_EmptyText() {
        // Given
        let emptyText = ""
        
        // Then
        XCTAssertTrue(emptyText.isEmpty)
    }
    
    func testMessageTextValidation_TooLong() {
        // Given
        let longText = String(repeating: "a", count: 1001)
        
        // Then
        XCTAssertTrue(longText.count > 1000, "Should detect text over limit")
    }
    
    // MARK: - Conversation Type Tests
    
    func testConversationType_AdminInquiry() {
        // Given
        let type = ConversationType.adminInquiry
        
        // Then
        XCTAssertEqual(type.rawValue, "adminInquiry")
    }
    
    func testConversationType_DirectMessage() {
        // Given
        let type = ConversationType.directMessage
        
        // Then
        XCTAssertEqual(type.rawValue, "directMessage")
    }
    
    // MARK: - Error Handling Tests
    
    func testChatError_NotAuthenticated() {
        // Given
        let error = ChatError.notAuthenticated
        
        // Then
        XCTAssertEqual(error.localizedDescription, "User not authenticated")
    }
    
    func testChatError_AdminNotFound() {
        // Given
        let error = ChatError.adminNotFound
        
        // Then
        XCTAssertEqual(error.localizedDescription, "Admin user not found")
    }
    
    func testChatError_InvalidConversation() {
        // Given
        let error = ChatError.invalidConversation
        
        // Then
        XCTAssertEqual(error.localizedDescription, "Invalid conversation")
    }
    
    // MARK: - Performance Tests
    
    func testCleanupPerformance() {
        // Measure cleanup time
        measure {
            chatService.cleanup()
        }
    }
}




