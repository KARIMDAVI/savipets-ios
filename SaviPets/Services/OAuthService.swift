import Foundation
import OSLog
import SwiftUI
import Combine
import AuthenticationServices
import GoogleSignIn
import FirebaseAuth
import FirebaseCore
import CryptoKit
import Security

final class OAuthService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authService: AuthServiceProtocol
    private let appState: AppState
    private var currentNonce: String?
    private var appleSignInDelegate: AppleSignInDelegate?
    
    init(authService: AuthServiceProtocol, appState: AppState) {
        self.authService = authService
        self.appState = appState
    }
    
    // MARK: - Apple Sign In
    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        
        // Generate nonce if not already set (for SignInWithAppleButton usage)
        if currentNonce == nil {
            let nonce = randomNonceString()
            currentNonce = nonce
        }
        
        switch result {
        case .success(let authorization):
            await processAppleSignInResult(authorization)
        case .failure(let error):
            await MainActor.run {
                // Handle specific Apple Sign In errors
                if let authError = error as? ASAuthorizationError {
                    switch authError.code {
                    case .canceled:
                        errorMessage = "Sign in was canceled"
                    case .failed:
                        errorMessage = "Sign in failed. Please try again."
                    case .invalidResponse:
                        errorMessage = "Invalid response from Apple. Please try again."
                    case .notHandled:
                        errorMessage = "Sign in not handled. Please try again."
                    case .unknown:
                        errorMessage = "Unknown error occurred. Please try again."
                    @unknown default:
                        errorMessage = "Sign in failed. Please try again."
                    }
                } else {
                    errorMessage = ErrorMapper.userFriendlyMessage(for: error)
                }
                isLoading = false
            }
            AppLogger.logError(error, context: "Apple Sign In", logger: .auth)
        }
    }
    
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        do {
            let result = try await performAppleSignIn(request: request)
            await processAppleSignInResult(result)
        } catch {
            await MainActor.run {
                errorMessage = ErrorMapper.userFriendlyMessage(for: error)
                isLoading = false
            }
            AppLogger.logError(error, context: "Apple Sign In", logger: .auth)
        }
    }
    
    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation) {
                // Clear retained delegate after callback completes
                self.appleSignInDelegate = nil
            }
            self.appleSignInDelegate = delegate
            controller.delegate = delegate
            controller.performRequests()
        }
    }
    
    private func processAppleSignInResult(_ result: ASAuthorization) async {
        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential else {
            await MainActor.run {
                errorMessage = "Invalid Apple credential"
                isLoading = false
            }
            return
        }
        
        guard let nonce = currentNonce else {
            await MainActor.run {
                errorMessage = "Missing state"
                isLoading = false
            }
            return
        }
        
        guard let appleTokenData = appleIDCredential.identityToken,
              let idTokenString = String(data: appleTokenData, encoding: .utf8) else {
            await MainActor.run {
                errorMessage = "Unable to fetch Apple identity token"
                isLoading = false
            }
            return
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // Extract display name from Apple credential
            let displayName: String?
            if let given = appleIDCredential.fullName?.givenName,
               let family = appleIDCredential.fullName?.familyName {
                let full = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
                displayName = full.isEmpty ? nil : full
            } else {
                displayName = nil
            }
            
            // Bootstrap OAuth user
            let role = try await authService.bootstrapAfterOAuth(defaultRole: .petOwner, displayName: displayName)
            
            await MainActor.run {
                appState.displayName = displayName ?? extractDisplayNameFromEmail(authResult.user.email)
                appState.isAuthenticated = true
                appState.role = role
                isLoading = false
            }
            
            AppLogger.logEvent("Apple Sign In successful", parameters: ["role": role.rawValue])
        } catch {
            await MainActor.run {
                errorMessage = ErrorMapper.userFriendlyMessage(for: error)
                isLoading = false
            }
            AppLogger.logError(error, context: "Apple Sign In Firebase", logger: .auth)
        }
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        guard let presentingVC = rootViewController() else {
            await MainActor.run {
                errorMessage = "Unable to present Google Sign-In"
                isLoading = false
            }
            return
        }
        
        // Ensure configuration is set
        if GIDSignIn.sharedInstance.configuration == nil {
            if let clientID = FirebaseApp.app()?.options.clientID {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            }
        }
        
        do {
            let result = try await performGoogleSignIn(presentingVC: presentingVC)
            await handleGoogleSignInResult(result)
        } catch {
            await MainActor.run {
                errorMessage = ErrorMapper.userFriendlyMessage(for: error)
                isLoading = false
            }
            AppLogger.logError(error, context: "Google Sign In", logger: .auth)
        }
    }
    
    private func performGoogleSignIn(presentingVC: UIViewController) async throws -> GIDSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sign in failed"]))
                }
            }
        }
    }
    
    private func handleGoogleSignInResult(_ result: GIDSignInResult) async {
        guard let idTokenString = result.user.idToken?.tokenString else {
            await MainActor.run {
                errorMessage = "Missing Google ID token"
                isLoading = false
            }
            return
        }
        
        let accessTokenString = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idTokenString, accessToken: accessTokenString)
        
        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // Extract display name from Google profile
            let displayName: String?
            if let name = result.user.profile?.name, !name.isEmpty {
                displayName = name
            } else {
                displayName = nil
            }
            
            // Bootstrap OAuth user
            let role = try await authService.bootstrapAfterOAuth(defaultRole: .petOwner, displayName: displayName)
            
            await MainActor.run {
                appState.displayName = displayName ?? extractDisplayNameFromEmail(authResult.user.email)
                appState.isAuthenticated = true
                appState.role = role
                isLoading = false
            }
            
            AppLogger.logEvent("Google Sign In successful", parameters: ["role": role.rawValue])
        } catch {
            await MainActor.run {
                errorMessage = ErrorMapper.userFriendlyMessage(for: error)
                isLoading = false
            }
            AppLogger.logError(error, context: "Google Sign In Firebase", logger: .auth)
        }
    }
    
    // MARK: - Helper Methods
    private func extractDisplayNameFromEmail(_ email: String?) -> String? {
        guard let email = email else { return nil }
        return email.components(separatedBy: "@").first?
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
    
    private func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        
        let keyWindow = scenes
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
        
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - Apple Sign In Delegate
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    private let onFinish: () -> Void
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>, onFinish: @escaping () -> Void) {
        self.continuation = continuation
        self.onFinish = onFinish
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
        onFinish()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
        onFinish()
    }
}

// MARK: - Apple Sign In Helpers
private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.map { String(format: "%02x", $0) }.joined()
}

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    
    while remainingLength > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        if status != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
        }
        
        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    return result
}

