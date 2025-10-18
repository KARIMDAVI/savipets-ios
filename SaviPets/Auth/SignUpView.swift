import SwiftUI
import AuthenticationServices
import FirebaseCore

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var oauthService: OAuthService

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var address: String = ""
    @State private var selectedRole: UserRole = .petOwner
    @State private var acceptedTerms: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    // Additional fields for sitters
    @State private var invCode: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    
    init() {
        // Initialize with dependencies - will be properly injected in real usage
        let authService: AuthServiceProtocol = FirebaseAuthService()
        let appState = AppState()
        self._oauthService = StateObject(wrappedValue: OAuthService(authService: authService, appState: appState))
    }

    var body: some View {
        ZStack {
            // Revert SignUp light-mode background to bright gold
            (colorScheme == .light
             ? LinearGradient(colors: [SPDesignSystem.Colors.primary, SPDesignSystem.Colors.secondary],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
             : SPDesignSystem.Colors.goldenGradient(colorScheme)).ignoresSafeArea()

            ScrollView {
                VStack(spacing: SPDesignSystem.Spacing.l) {
                    HStack {
                        Image("AppIcon").resizable().scaledToFit().frame(width: 36, height: 36)
                        Text("Create your account")
                            .font(SPDesignSystem.Typography.brandMedium())
                            .foregroundColor(SPDesignSystem.Colors.dark)
                        Spacer()
                    }

                    VStack(spacing: SPDesignSystem.Spacing.m) {
                        FloatingTextField(title: "First Name", text: $firstName)
                        FloatingTextField(title: "Last Name", text: $lastName)
                        FloatingTextField(title: "Email", text: $email, kind: .email)
                        FloatingTextField(title: "Password", text: $password, kind: .secure)
                        FloatingTextField(title: "Address", text: $address)

                        rolePicker
                        
                        // Additional fields for sitters
                        if selectedRole == .petSitter {
                            FloatingTextField(title: "Invitiation Code", text: $invCode)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date of Birth").font(.caption).foregroundColor(.secondary)
                                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .environment(\.locale, Locale(identifier: "en_US"))
                            }
                        }

                        Toggle(isOn: $acceptedTerms) {
                            HStack(spacing: 4) {
                                Text("I agree to the")
                                    .font(SPDesignSystem.Typography.footnote())
                                    .foregroundColor(.black)

                                Link("Terms", destination: URL(string: "https://www.savipets.com/terms")!)
                                    .font(SPDesignSystem.Typography.footnote())
                                    .foregroundColor(.blue)

                                Text("and")
                                    .font(SPDesignSystem.Typography.footnote())
                                    .foregroundColor(.black)

                                Link("Privacy Policy", destination: URL(string: "https://www.savipets.com/privacy-policy")!)
                                    .font(SPDesignSystem.Typography.footnote())
                                    .foregroundColor(.blue)
                            }
                        }
                        // Revert toggle to bright gold in light mode only
                        .toggleStyle(SwitchToggleStyle(tint: colorScheme == .light ? SPDesignSystem.Colors.primary : SPDesignSystem.Colors.primaryAdjusted(colorScheme)))

                        if let errorMessage = errorMessage ?? oauthService.errorMessage { 
                            Text(errorMessage).foregroundColor(SPDesignSystem.Colors.error) 
                        }

                        Button(action: { if !isLoading && !oauthService.isLoading { createAccount() } }) {
                            HStack(spacing: SPDesignSystem.Spacing.s) {
                                if isLoading || oauthService.isLoading {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: SPDesignSystem.Colors.dark))
                                }
                                Image(systemName: "person.badge.plus.fill")
                                Text("Create Account")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(isLoading || oauthService.isLoading)
                        .buttonStyle(PrimaryButtonStyleBrightInLight())

                        // Third-party sign up buttons (Apple & Google)
                        thirdPartyButtons
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(SPDesignSystem.Colors.glassBorder, lineWidth: 1)
                    )

                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                            Text("Sign in").underline()
                        }
                        .foregroundColor(.black)
                        .font(SPDesignSystem.Typography.bodyMedium())
                    }
                }
                .padding()
            }
        }
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Role").font(.caption).foregroundColor(.secondary)
            Picker("Select your role", selection: $selectedRole) {
                Text("Pet Parent").tag(UserRole.petOwner)
                Text("Pet Sitter").tag(UserRole.petSitter)
            }
            .pickerStyle(.segmented)
        }
    }

    private func roleButton(title: String, image: String, role: UserRole) -> some View {
        Button(action: { selectedRole = role }) {
            VStack(spacing: 8) {
                Image(systemName: image)
                    .font(.title2)
                Text(title).font(.footnote).bold()
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selectedRole == role ? Color.black : Color.black.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var thirdPartyButtons: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(
                .signUp,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    Task {
                        await handleAppleSignUpResult(result)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .cornerRadius(8)
            .accessibilityLabel("Sign up with Apple")
            .accessibilityHint("Double tap to create an account using your Apple ID")

            Button(action: { 
                Task {
                    await handleGoogleSignUp()
                }
            }) {
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image("Google-Sign")
                            .resizable()
                            .frame(width: 15, height: 15)
                        Text("Sign up with Google").font(SPDesignSystem.Typography.bodyMedium())
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .foregroundColor(.black)
            }
            .glass()
            .accessibilityLabel("Sign up with Google")
            .accessibilityHint("Double tap to create an account using your Google account")
        }
    }

    private func createAccount() {
        guard !firstName.isEmpty, !lastName.isEmpty, email.contains("@"), password.count >= 4 else {
            errorMessage = "Please fill all fields correctly"
            return
        }
        
        // Additional validation for sitters
        if selectedRole == .petSitter {
            guard !invCode.isEmpty else {
                errorMessage = "Please provide your Invitation Code"
                return
            }
            guard Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0 >= 18 else {
                errorMessage = "You must be at least 18 years old to be a pet sitter"
                return
            }
            guard !address.isEmpty else {
                errorMessage = "Address is required for pet sitters"
                return
            }
        }
        
        guard acceptedTerms else { errorMessage = "Please accept the terms"; return }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let role = try await appState.authService.signUp(
                    email: email,
                    password: password,
                    role: selectedRole,
                    firstName: firstName,
                    lastName: lastName,
                    address: selectedRole == .petSitter ? invCode : nil,
                    dateOfBirth: selectedRole == .petSitter ? dateOfBirth : nil
                )
                await MainActor.run {
                    appState.role = role
                    appState.isAuthenticated = true
                    let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                    appState.displayName = full.isEmpty ? email.components(separatedBy: "@").first?
                        .replacingOccurrences(of: ".", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .replacingOccurrences(of: "-", with: " ")
                        .capitalized : full
                }
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? "Sign up failed"
                await MainActor.run {
                    errorMessage = msg
                    isLoading = false
                }
            }
        }
    }

    // MARK: - OAuth Handlers
    
    private func handleAppleSignUpResult(_ result: Result<ASAuthorization, Error>) async {
        await oauthService.handleAppleSignInResult(result)
        
        // After successful OAuth, ensure role/profile exists using selectedRole as default
        if oauthService.errorMessage == nil {
            Task {
                let _ = try? await appState.authService.bootstrapAfterOAuth(defaultRole: selectedRole, displayName: appState.displayName)
                await MainActor.run {
                    appState.role = selectedRole
                    dismiss()
                }
            }
        }
    }
    
    private func handleGoogleSignUp() async {
        await oauthService.signInWithGoogle()
        
        // After successful OAuth, ensure role/profile exists using selectedRole as default
        if oauthService.errorMessage == nil {
            Task {
                let _ = try? await appState.authService.bootstrapAfterOAuth(defaultRole: selectedRole, displayName: appState.displayName)
                await MainActor.run {
                    appState.role = selectedRole
                    dismiss()
                }
            }
        }
    }
}
