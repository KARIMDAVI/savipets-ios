import Foundation

extension String {
    var sanitized: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isValidEmail: Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
    }
    
    func isSecurePassword() -> String? {
        if count < AppConstants.Validation.minPasswordLength {
            return "Password must be at least \(AppConstants.Validation.minPasswordLength) characters"
        }
        if !contains(where: { $0.isNumber }) {
            return "Password must contain at least one number"
        }
        if !contains(where: { $0.isUppercase }) {
            return "Password must contain at least one uppercase letter"
        }
        return nil
    }
}
