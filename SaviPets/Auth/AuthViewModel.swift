import Foundation
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = "" {
        didSet {
            emailValidationTask?.cancel()
            emailValidationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                validateEmail()
            }
        }
    }
    @Published var password = "" {
        didSet {
            passwordValidationTask?.cancel()
            passwordValidationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                validatePassword()
            }
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var emailValidationError: String?
    @Published var passwordValidationError: String?
    
    private let authService: AuthServiceProtocol
    private let appState: AppState
    private var emailValidationTask: Task<Void, Never>?
    private var passwordValidationTask: Task<Void, Never>?
    
    init(authService: AuthServiceProtocol, appState: AppState) {
        self.authService = authService
        self.appState = appState
    }
    
    var emailError: String? {
        return emailValidationError
    }
    
    var passwordError: String? {
        return passwordValidationError
    }
    
    private func validateEmail() {
        guard !email.isEmpty else { 
            emailValidationError = nil
            return 
        }
        emailValidationError = email.isValidEmail ? nil : "Enter a valid email"
    }
    
    private func validatePassword() {
        guard !password.isEmpty else { 
            passwordValidationError = nil
            return 
        }
        passwordValidationError = password.isSecurePassword()
    }
    
    func signIn() async {
        guard emailError == nil, passwordError == nil else {
            errorMessage = "Please fix validation errors"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let role = try await authService.signIn(email: email, password: password)
            appState.role = role
            appState.displayName = extractDisplayName(from: email)
            AppLogger.logEvent("User signed in", parameters: ["role": role.rawValue])
        } catch {
            errorMessage = ErrorMapper.userFriendlyMessage(for: error)
            AppLogger.logError(error, context: "Sign In", logger: .auth)
        }
        
        isLoading = false
    }
    
    private func extractDisplayName(from email: String) -> String {
        email.components(separatedBy: "@").first?
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized ?? "User"
    }
}
