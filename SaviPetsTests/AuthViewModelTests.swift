import XCTest
import SwiftUI
@testable import SaviPets

@MainActor
final class AuthViewModelTests: XCTestCase {
    var authViewModel: AuthViewModel!
    var mockAuthService: MockAuthService!
    var mockAppState: AppState!
    
    override func setUp() async throws {
        try await super.setUp()
        mockAuthService = MockAuthService()
        mockAppState = AppState()
        authViewModel = AuthViewModel(authService: mockAuthService as AuthServiceProtocol, appState: mockAppState)
    }
    
    override func tearDown() async throws {
        authViewModel = nil
        mockAuthService = nil
        mockAppState = nil
        try await super.tearDown()
    }
    
    // MARK: - Email Validation Tests
    
    func testEmailValidation_ValidEmail() async throws {
        // Given
        authViewModel.email = "test@example.com"
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // Then
        XCTAssertNil(authViewModel.emailError, "Valid email should not have error")
    }
    
    func testEmailValidation_InvalidEmail() async throws {
        // Given
        authViewModel.email = "invalid-email"
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // Then
        XCTAssertNotNil(authViewModel.emailError, "Invalid email should have error")
        XCTAssertEqual(authViewModel.emailError, "Enter a valid email")
    }
    
    func testEmailValidation_EmptyEmail() async throws {
        // Given
        authViewModel.email = ""
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // Then
        XCTAssertNil(authViewModel.emailError, "Empty email should not have error")
    }
    
    // MARK: - Password Validation Tests
    
    func testPasswordValidation_ValidPassword() async throws {
        // Given
        authViewModel.password = "ValidPass123"
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // Then
        XCTAssertNil(authViewModel.passwordError, "Valid password should not have error")
    }
    
    func testPasswordValidation_TooShort() async throws {
        // Given
        authViewModel.password = "Short1"
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // Then
        XCTAssertNotNil(authViewModel.passwordError, "Short password should have error")
        XCTAssertTrue(authViewModel.passwordError?.contains("at least 8 characters") == true)
    }
    
    func testPasswordValidation_NoUppercase() async throws {
        // Given
        authViewModel.password = "lowercase123"
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // Then
        XCTAssertNotNil(authViewModel.passwordError, "Password without uppercase should have error")
        XCTAssertTrue(authViewModel.passwordError?.contains("uppercase letter") == true)
    }
    
    func testPasswordValidation_NoNumber() async throws {
        // Given
        authViewModel.password = "NoNumbers"
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // Then
        XCTAssertNotNil(authViewModel.passwordError, "Password without number should have error")
        XCTAssertTrue(authViewModel.passwordError?.contains("number") == true)
    }
    
    // MARK: - Sign In Tests
    
    func testSignIn_Success() async throws {
        // Given
        mockAuthService.shouldSucceed = true
        authViewModel.email = "test@example.com"
        authViewModel.password = "ValidPass123"
        
        // Wait for validation debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // When
        await authViewModel.signIn()
        
        // Then
        XCTAssertFalse(authViewModel.isLoading, "Loading should be false after completion")
        XCTAssertNil(authViewModel.errorMessage, "No error should be present on success")
        XCTAssertEqual(mockAppState.role, .petOwner, "User role should be set")
        XCTAssertNotNil(mockAppState.displayName, "Display name should be set")
    }
    
    func testSignIn_ValidationError() async throws {
        // Given
        authViewModel.email = "invalid-email"
        authViewModel.password = "short"
        
        // Wait for validation debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // When
        await authViewModel.signIn()
        
        // Then
        XCTAssertFalse(authViewModel.isLoading, "Loading should be false")
        XCTAssertEqual(authViewModel.errorMessage, "Please fix validation errors")
    }
    
    func testSignIn_NetworkError() async throws {
        // Given
        mockAuthService.shouldSucceed = false
        mockAuthService.mockError = NSError(domain: "NetworkError", code: -1009, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"])
        authViewModel.email = "test@example.com"
        authViewModel.password = "ValidPass123"
        
        // Wait for validation debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // When
        await authViewModel.signIn()
        
        // Then
        XCTAssertFalse(authViewModel.isLoading, "Loading should be false after completion")
        XCTAssertNotNil(authViewModel.errorMessage, "Error message should be present")
        XCTAssertTrue(authViewModel.errorMessage?.contains("Network") == true)
    }
    
    // MARK: - Debouncing Tests
    
    func testEmailValidationDebouncing() async throws {
        // Given
        authViewModel.email = "test"
        
        // When - change email quickly (should cancel previous validation)
        authViewModel.email = "test@"
        authViewModel.email = "test@example"
        authViewModel.email = "test@example.com"
        
        // Wait for final debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // Then
        XCTAssertNil(authViewModel.emailError, "Final valid email should not have error")
    }
    
    func testPasswordValidationDebouncing() async throws {
        // Given
        authViewModel.password = "short"
        
        // When - change password quickly (should cancel previous validation)
        authViewModel.password = "short1"
        authViewModel.password = "Short1"
        authViewModel.password = "ValidPass123"
        
        // Wait for final debounce
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        // Then
        XCTAssertNil(authViewModel.passwordError, "Final valid password should not have error")
    }
}
