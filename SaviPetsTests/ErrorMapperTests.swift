import XCTest
import FirebaseAuth
@testable import SaviPets

final class ErrorMapperTests: XCTestCase {
    
    // MARK: - Firebase Auth Error Mapping Tests
    
    func testErrorMapping_NetworkError() {
        let error = NSError(
            domain: AuthErrorDomain,
            code: AuthErrorCode.networkError.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Network error"]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        XCTAssertEqual(message, "Network connection failed. Please check your internet.")
    }
    
    func testErrorMapping_UserNotFound() {
        let error = NSError(
            domain: AuthErrorDomain,
            code: AuthErrorCode.userNotFound.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "User not found"]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        XCTAssertEqual(message, "No account found with this email.")
    }
    
    func testErrorMapping_WrongPassword() {
        let error = NSError(
            domain: AuthErrorDomain,
            code: AuthErrorCode.wrongPassword.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Wrong password"]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        XCTAssertEqual(message, "Incorrect password. Please try again.")
    }
    
    func testErrorMapping_InvalidEmail() {
        let error = NSError(
            domain: AuthErrorDomain,
            code: AuthErrorCode.invalidEmail.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Invalid email"]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        XCTAssertEqual(message, "Please enter a valid email address.")
    }
    
    func testErrorMapping_EmailAlreadyInUse() {
        let error = NSError(
            domain: AuthErrorDomain,
            code: AuthErrorCode.emailAlreadyInUse.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Email already in use"]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        XCTAssertEqual(message, "This email is already registered.")
    }
    
    func testErrorMapping_WeakPassword() {
        let error = NSError(
            domain: AuthErrorDomain,
            code: AuthErrorCode.weakPassword.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Weak password"]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        XCTAssertEqual(message, "Password is too weak. Please use a stronger password.")
    }
    
    func testErrorMapping_TooManyRequests() {
        let error = NSError(
            domain: AuthErrorDomain,
            code: AuthErrorCode.tooManyRequests.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Too many requests"]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        XCTAssertEqual(message, "Too many attempts. Please try again later.")
    }
    
    // MARK: - Non-Firebase Error Tests
    
    func testErrorMapping_GenericError() {
        let error = NSError(
            domain: "CustomDomain",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Something went wrong"]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        XCTAssertEqual(message, "Something went wrong")
    }
    
    func testErrorMapping_ErrorWithoutLocalizedDescription() {
        let error = NSError(
            domain: "TestDomain",
            code: 123,
            userInfo: [:]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        // Should return some default message (actual implementation may vary)
        XCTAssertFalse(message.isEmpty, "Should return a non-empty message")
    }
    
    // MARK: - Integration Tests
    
    func testErrorMapping_AllFirebaseAuthErrors() {
        let errorCases: [(AuthErrorCode, String)] = [
            (.networkError, "Network connection failed"),
            (.userNotFound, "No account found"),
            (.wrongPassword, "Incorrect password"),
            (.invalidEmail, "valid email"),
            (.emailAlreadyInUse, "already registered"),
            (.weakPassword, "too weak"),
            (.tooManyRequests, "Too many attempts")
        ]
        
        for (errorCode, expectedSubstring) in errorCases {
            let error = NSError(
                domain: AuthErrorDomain,
                code: errorCode.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Firebase error"]
            )
            
            let message = ErrorMapper.userFriendlyMessage(for: error)
            XCTAssertTrue(
                message.contains(expectedSubstring) || message.lowercased().contains(expectedSubstring.lowercased()),
                "Error message for \(errorCode) should contain '\(expectedSubstring)' but got '\(message)'"
            )
        }
    }
    
    // MARK: - Edge Cases
    
    func testErrorMapping_NilError() {
        // Testing with a minimal error
        struct MinimalError: Error {}
        let error = MinimalError()
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        XCTAssertFalse(message.isEmpty, "Should handle minimal errors gracefully")
    }
    
    func testErrorMapping_CustomFirebaseError() {
        let error = NSError(
            domain: AuthErrorDomain,
            code: 99999, // Unknown error code
            userInfo: [NSLocalizedDescriptionKey: "Unknown Firebase error"]
        )
        
        let message = ErrorMapper.userFriendlyMessage(for: error)
        // Should fall back to localized description
        XCTAssertEqual(message, "Unknown Firebase error")
    }
    
    // MARK: - Performance Tests
    
    func testErrorMapping_Performance() {
        let errors = (0..<1000).map { _ in
            NSError(
                domain: AuthErrorDomain,
                code: AuthErrorCode.networkError.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Network error"]
            )
        }
        
        measure {
            for error in errors {
                _ = ErrorMapper.userFriendlyMessage(for: error)
            }
        }
    }
    
    // MARK: - User Experience Tests
    
    func testErrorMapping_MessagesAreFriendly() {
        let testErrors: [(NSError, String)] = [
            (
                NSError(domain: AuthErrorDomain, code: AuthErrorCode.networkError.rawValue, userInfo: [:]),
                "technical jargon|debug info|stack trace"
            ),
            (
                NSError(domain: AuthErrorDomain, code: AuthErrorCode.userNotFound.rawValue, userInfo: [:]),
                "404|not found error"
            )
        ]
        
        for (error, avoidWords) in testErrors {
            let message = ErrorMapper.userFriendlyMessage(for: error)
            let wordsToAvoid = avoidWords.split(separator: "|")
            
            for word in wordsToAvoid {
                XCTAssertFalse(
                    message.lowercased().contains(word.lowercased()),
                    "User-friendly message should not contain technical term '\(word)': \(message)"
                )
            }
            
            // Messages should be reasonably short (not entire stack traces)
            XCTAssertLessThan(message.count, 200, "Message should be concise")
            
            // Messages should start with capital letter
            XCTAssertTrue(message.first?.isUppercase == true, "Message should start with uppercase")
            
            // Messages should end with period
            XCTAssertTrue(message.hasSuffix("."), "Message should end with period")
        }
    }
}

