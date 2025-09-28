import SwiftUI
import AuthenticationServices
import GoogleSignIn
import UIKit
import FirebaseCore
import FirebaseAuth
import CryptoKit
import Security

struct SignInView: View {
	@EnvironmentObject var appState: AppState
	@Environment(\.colorScheme) private var colorScheme
	@State private var email: String = ""
	@State private var password: String = ""
	@State private var isLoading: Bool = false
	@State private var errorMessage: String? = nil
	@State private var showSignUp: Bool = false
    @State private var currentNonce: String? = nil

	var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Revert SignIn light-mode background to bright gold
            (colorScheme == .light
             ? LinearGradient(colors: [SPDesignSystem.Colors.primary, SPDesignSystem.Colors.secondary],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
             : SPDesignSystem.Colors.goldenGradient(colorScheme))
                .ignoresSafeArea()

			// Background dog image full, anchored bottom-right
			GeometryReader { geo in
				Image("DogSavi")
					.resizable()
					.scaledToFill()
					.frame(width: geo.size.width, height: geo.size.height, alignment: .bottomTrailing)
					.clipped()
					.opacity(0.85)
					.blendMode(.multiply)
			}
			.ignoresSafeArea()
			
			VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.l) {
				HStack(alignment: .top) {
					brandLockup
					Spacer()
				}

				Spacer()

				VStack(spacing: SPDesignSystem.Spacing.m) {
					FloatingTextField(title: "Email", text: $email, kind: .email, error: emailError)
					FloatingTextField(title: "Password", text: $password, kind: .secure, error: passwordError)

					if let errorMessage {
						Text(errorMessage)
							.font(SPDesignSystem.Typography.footnote())
							.foregroundColor(SPDesignSystem.Colors.error)
					}

					SPButton(title: "Sign in", kind: .dark, isLoading: isLoading, systemImage: "lock.fill") {
						signIn()
					}

					thirdPartyButtons

					Button(action: { showSignUp = true }) {
						Text("Sign up")
							.frame(maxWidth: .infinity)
							.padding(.vertical, 14)
							.foregroundColor(.black)
					}
					.glass()
				}
				.padding()
				.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
				.overlay(
					RoundedRectangle(cornerRadius: 20, style: .continuous)
						.stroke(SPDesignSystem.Colors.glassBorder, lineWidth: 1)
				)
				.frame(maxWidth: .infinity)
				.padding(.horizontal, 40)
				.padding(.top, 40)

				Spacer(minLength: 40)
			}
			.padding(.horizontal, SPDesignSystem.Spacing.l)
			.padding(.top, SPDesignSystem.Spacing.xl)
		}
		.sheet(isPresented: $showSignUp) {
			SignUpView()
				.presentationDetents([.large])
				.presentationDragIndicator(.visible)
		}
	}

	private var brandLockup: some View {
		HStack(spacing: SPDesignSystem.Spacing.m) {
			Image("AppIcon")
				.resizable()
				.scaledToFit()
				.frame(width: 30, height: 38)
			VStack(alignment: .leading, spacing: 9) {
				// 3D Title with blurry shadow
				Text("SaviPets")
					.font(SPDesignSystem.Typography.brandLarge())
					.foregroundStyle(
						LinearGradient(colors: [
							Color.white.opacity(0.95),
							SPDesignSystem.Colors.dark.opacity(0.9)
						], startPoint: .top, endPoint: .bottom)
					)
					.shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 16)
					.shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
					.overlay(
						Text("SaviPets")
							.font(SPDesignSystem.Typography.brandLarge())
							.foregroundColor(.black.opacity(0.95))
							.blur(radius: 1.2)
							.offset(x: 0, y: -1.2)
					)

				// Slogan with soft blur shadow (dark gradient per latest update)
				Text("There is always a good time to be with them!")
					.font(SPDesignSystem.Typography.callout())
					.foregroundStyle(
						LinearGradient(colors: [
							Color.black.opacity(0.9),
							Color.black.opacity(0.85)
						], startPoint: .top, endPoint: .bottom)
					)
					.shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
			}
		}
	}

    private var thirdPartyButtons: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.nonce = sha256(nonce)
                },
                onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
                        guard let nonce = currentNonce else { errorMessage = "Missing state"; return }
                        guard let appleTokenData = appleIDCredential.identityToken,
                              let idTokenString = String(data: appleTokenData, encoding: .utf8) else {
                            errorMessage = "Unable to fetch Apple identity token"
                            return
                        }
                        // FirebaseAuth: create an Apple OAuth credential
                        let credential = OAuthProvider.appleCredential(
                            withIDToken: idTokenString,
                            rawNonce: nonce,
                            fullName: appleIDCredential.fullName
                        )
                        Auth.auth().signIn(with: credential) { authResult, error in
                            if let _ = error { errorMessage = "Sign in failed"; return }
                            if let given = appleIDCredential.fullName?.givenName, let family = appleIDCredential.fullName?.familyName {
                                let full = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
                                if !full.isEmpty { appState.displayName = full }
                            }
                            if appState.displayName == nil, let email = Auth.auth().currentUser?.email {
                                appState.displayName = email.components(separatedBy: "@").first?
                                    .replacingOccurrences(of: ".", with: " ")
                                    .replacingOccurrences(of: "_", with: " ")
                                    .replacingOccurrences(of: "-", with: " ")
                                    .capitalized
                            }
                            appState.isAuthenticated = true
                            appState.role = .petOwner
                        }
                    case .failure(let error):
						let nsError = error as NSError
						if nsError.domain == ASAuthorizationError.errorDomain && nsError.code == ASAuthorizationError.Code.canceled.rawValue {
							errorMessage = "Sign in failed: User cancelled"
						} else {
							errorMessage = "Sign in failed"
						}
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .cornerRadius(8)

            Button(action: { googleSignIn() }) {
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image("Google-Sign")
                            .resizable()
                            .frame(width: 15, height: 15)
                        Text("Sign in with Google").font(SPDesignSystem.Typography.bodyMedium())
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .foregroundColor(.black)
            }
            .glass()
        }
    }

	private var emailError: String? {
		if email.isEmpty { return nil }
		return email.contains("@") ? nil : "Enter a valid email"
	}

	private var passwordError: String? {
		if password.isEmpty { return nil }
		return password.count >= 4 ? nil : "Minimum 4 characters"
	}

    private func signIn() {
        guard emailError == nil, passwordError == nil, !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter valid email and password"
            return
        }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let role = try await appState.authService.signIn(email: email, password: password)
                await MainActor.run {
                    appState.role = role
                    appState.displayName = email.components(separatedBy: "@").first?
                        .replacingOccurrences(of: ".", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .replacingOccurrences(of: "-", with: " ")
                        .capitalized
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "Sign in failed"
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Google Sign-In
    private func googleSignIn() {
        errorMessage = nil
        isLoading = true

        guard let presentingVC = rootViewController() else {
            isLoading = false
            errorMessage = "Unable to present Google Sign-In"
            return
        }

        // Ensure configuration is set (in case AppDelegate wasn't able to)
        if GIDSignIn.sharedInstance.configuration == nil {
            if let clientID = FirebaseApp.app()?.options.clientID {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            }
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
            if let _ = error {
                isLoading = false
                errorMessage = "Sign in failed"
                return
            }

            guard let result = result else {
                isLoading = false
                errorMessage = "Sign in failed"
                return
            }

            // Firebase credential exchange
            guard let idTokenString = result.user.idToken?.tokenString else {
                isLoading = false
                errorMessage = "Missing Google ID token"
                return
            }
            let accessTokenString = result.user.accessToken.tokenString

            let credential = GoogleAuthProvider.credential(withIDToken: idTokenString, accessToken: accessTokenString)
            Auth.auth().signIn(with: credential) { authResult, err in
                isLoading = false
                if let _ = err {
                    errorMessage = "Sign in failed"
                    return
                }

                // Display name from Google profile or email prefix
                if let name = result.user.profile?.name, !name.isEmpty {
                    appState.displayName = name
                } else if let email = Auth.auth().currentUser?.email {
                    appState.displayName = email.components(separatedBy: "@").first?
                        .replacingOccurrences(of: ".", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .replacingOccurrences(of: "-", with: " ")
                        .capitalized
                }

                appState.isAuthenticated = true
                appState.role = .petOwner
            }
        }
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

// MARK: - Apple Sign In helpers
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
