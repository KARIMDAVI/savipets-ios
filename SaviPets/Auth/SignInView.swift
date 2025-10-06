import SwiftUI
import UIKit
import FirebaseCore

struct SignInView: View {
	@EnvironmentObject var appState: AppState
	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var authViewModel: AuthViewModel
	@StateObject private var oauthService: OAuthService
	@State private var showSignUp: Bool = false
	
	init() {
		// Initialize with dependencies - will be properly injected in real usage
		let authService: AuthServiceProtocol = FirebaseAuthService()
		let appState = AppState()
		self._authViewModel = StateObject(wrappedValue: AuthViewModel(authService: authService, appState: appState))
		self._oauthService = StateObject(wrappedValue: OAuthService(authService: authService, appState: appState))
	}

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
					FloatingTextField(title: "Email", text: $authViewModel.email, kind: .email, error: authViewModel.emailError)
					FloatingTextField(title: "Password", text: $authViewModel.password, kind: .secure, error: authViewModel.passwordError)

					if let errorMessage = authViewModel.errorMessage ?? oauthService.errorMessage {
						Text(errorMessage)
							.font(SPDesignSystem.Typography.footnote())
							.foregroundColor(SPDesignSystem.Colors.error)
					}

					SPButton(title: "Sign in", kind: .dark, isLoading: authViewModel.isLoading || oauthService.isLoading, systemImage: "lock.fill") {
						Task {
							await authViewModel.signIn()
						}
					}
					.accessibilityLabel("Sign In")
					.accessibilityHint("Double tap to sign in with your email and password")

					thirdPartyButtons

					Button(action: { showSignUp = true }) {
						Text("Sign up")
							.frame(maxWidth: .infinity)
							.padding(.vertical, 14)
							.foregroundColor(.black)
					}
					.glass()
					.accessibilityLabel("Sign Up")
					.accessibilityHint("Double tap to create a new account")
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
                },
                onCompletion: { result in
                    Task {
                        await oauthService.signInWithApple()
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .cornerRadius(8)
            .accessibilityLabel("Sign in with Apple")
            .accessibilityHint("Double tap to sign in using your Apple ID")

            Button(action: { 
                Task {
                    await oauthService.signInWithGoogle()
                }
            }) {
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
            .accessibilityLabel("Sign in with Google")
            .accessibilityHint("Double tap to sign in using your Google account")
        }
    }

}
