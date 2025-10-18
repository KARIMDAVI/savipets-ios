import XCTest
@testable import SaviPets

final class ValidationHelpersTests: XCTestCase {
    
    // MARK: - Email Validation Tests
    
    func testEmailValidation_ValidEmails() {
        let validEmails = [
            "test@example.com",
            "user.name@example.com",
            "user+tag@example.co.uk",
            "user_name@example.org",
            "123@example.com",
            "test@subdomain.example.com"
        ]
        
        for email in validEmails {
            XCTAssertTrue(email.isValidEmail, "\(email) should be valid")
        }
    }
    
    func testEmailValidation_InvalidEmails() {
        let invalidEmails = [
            "invalid",
            "@example.com",
            "user@",
            "user @example.com",
            "user@example",
            "user@.com",
            "",
            "user@example..com",
            "user@@example.com"
        ]
        
        for email in invalidEmails {
            XCTAssertFalse(email.isValidEmail, "\(email) should be invalid")
        }
    }
    
    // MARK: - Password Validation Tests
    
    func testPasswordValidation_ValidPasswords() {
        let validPasswords = [
            "ValidPass123",
            "Abcdef123",
            "MyPassword1",
            "Test1234A",
            "VerySecure1"
        ]
        
        for password in validPasswords {
            XCTAssertNil(password.isSecurePassword(), "\(password) should be valid")
        }
    }
    
    func testPasswordValidation_TooShort() {
        let shortPasswords = [
            "Short1",
            "Ab1",
            "1234567",  // 7 characters, no uppercase
            "Test12"    // 6 characters
        ]
        
        for password in shortPasswords {
            let error = password.isSecurePassword()
            XCTAssertNotNil(error, "\(password) should be invalid (too short)")
            XCTAssertTrue(error?.contains("at least") == true, "Error should mention minimum length")
        }
    }
    
    func testPasswordValidation_NoNumber() {
        let noNumberPasswords = [
            "NoNumbers",
            "ValidPassword",
            "UPPERCASE",
            "LowerAndUpper"
        ]
        
        for password in noNumberPasswords {
            let error = password.isSecurePassword()
            XCTAssertNotNil(error, "\(password) should be invalid (no number)")
            XCTAssertTrue(error?.contains("number") == true, "Error should mention number requirement")
        }
    }
    
    func testPasswordValidation_NoUppercase() {
        let noUppercasePasswords = [
            "lowercase123",
            "alllower1234",
            "test12345",
            "password1"
        ]
        
        for password in noUppercasePasswords {
            let error = password.isSecurePassword()
            XCTAssertNotNil(error, "\(password) should be invalid (no uppercase)")
            XCTAssertTrue(error?.contains("uppercase") == true, "Error should mention uppercase requirement")
        }
    }
    
    func testPasswordValidation_EmptyPassword() {
        let error = "".isSecurePassword()
        XCTAssertNotNil(error, "Empty password should be invalid")
    }
    
    func testPasswordValidation_ExactMinimumLength() {
        // 8 characters with uppercase and number
        let password = "Valid123"
        XCTAssertNil(password.isSecurePassword(), "Password with exactly 8 characters should be valid")
    }
    
    // MARK: - String Sanitization Tests
    
    func testStringSanitization_RemovesWhitespace() {
        let testCases: [(String, String)] = [
            ("  hello  ", "hello"),
            ("\thello\t", "hello"),
            ("\nhello\n", "hello"),
            ("  hello world  ", "hello world"),
            ("hello", "hello"),
            ("   ", ""),
            ("", "")
        ]
        
        for (input, expected) in testCases {
            XCTAssertEqual(input.sanitized, expected, "Sanitization failed for '\(input)'")
        }
    }
    
    // MARK: - Integration Tests
    
    func testPasswordValidation_RealWorldPasswords() {
        // Common real-world scenarios
        struct PasswordTest {
            let password: String
            let shouldBeValid: Bool
            let description: String
        }
        
        let tests = [
            PasswordTest(password: "MyDog2023", shouldBeValid: true, description: "Common pet-related password"),
            PasswordTest(password: "SaviPets1", shouldBeValid: true, description: "App-related password"),
            PasswordTest(password: "password123", shouldBeValid: false, description: "Weak password (no uppercase)"),
            PasswordTest(password: "PASSWORD123", shouldBeValid: true, description: "All caps with numbers"),
            PasswordTest(password: "Pass1", shouldBeValid: false, description: "Too short"),
            PasswordTest(password: "SuperSecure2024", shouldBeValid: true, description: "Strong password"),
            PasswordTest(password: "12345678", shouldBeValid: false, description: "Numbers only")
        ]
        
        for test in tests {
            let error = test.password.isSecurePassword()
            if test.shouldBeValid {
                XCTAssertNil(error, "\(test.description): '\(test.password)' should be valid but got error: \(error ?? "none")")
            } else {
                XCTAssertNotNil(error, "\(test.description): '\(test.password)' should be invalid")
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmailValidation_EdgeCases() {
        // Very long email
        let longEmail = String(repeating: "a", count: 50) + "@example.com"
        XCTAssertTrue(longEmail.isValidEmail, "Long but valid email should pass")
        
        // Email with multiple dots in local part
        XCTAssertTrue("first.middle.last@example.com".isValidEmail, "Multiple dots should be valid")
        
        // Email with hyphen in domain
        XCTAssertTrue("test@my-domain.com".isValidEmail, "Hyphenated domain should be valid")
    }
    
    func testPasswordValidation_EdgeCases() {
        // Very long password
        let longPassword = "A1" + String(repeating: "a", count: 100)
        XCTAssertNil(longPassword.isSecurePassword(), "Long password should be valid if it meets requirements")
        
        // Password with special characters
        let specialChars = "Valid123!@#$%"
        XCTAssertNil(specialChars.isSecurePassword(), "Password with special characters should be valid")
        
        // Password with spaces
        let withSpaces = "Valid Pass 123"
        // Should still validate based on uppercase, number, and length
        XCTAssertNil(withSpaces.isSecurePassword(), "Password with spaces should be valid if it meets requirements")
    }
    
    // MARK: - Performance Tests
    
    func testEmailValidation_Performance() {
        let emails = (0..<1000).map { "test\($0)@example.com" }
        
        measure {
            for email in emails {
                _ = email.isValidEmail
            }
        }
    }
    
    func testPasswordValidation_Performance() {
        let passwords = (0..<1000).map { "Password\($0)" }
        
        measure {
            for password in passwords {
                _ = password.isSecurePassword()
            }
        }
    }
}

