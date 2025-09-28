import SwiftUI
import AuthenticationServices
import GoogleSignIn
import FirebaseCore

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedRole: UserRole = .petOwner
    @State private var acceptedTerms: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

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

                        rolePicker

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

                        if let errorMessage { Text(errorMessage).foregroundColor(SPDesignSystem.Colors.error) }

                        SPButton(title: "Create Account", kind: .primary, isLoading: isLoading, systemImage: "person.badge.plus.fill") {
                            createAccount()
                        }

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
                Text("Pet Owner").tag(UserRole.petOwner)
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
                    switch result {
                    case .success(let auth):
                        if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                            let given = credential.fullName?.givenName
                            let family = credential.fullName?.familyName
                            let full = [given, family].compactMap { $0 }.joined(separator: " ")
                            if !full.trimmingCharacters(in: .whitespaces).isEmpty {
                                appState.displayName = full
                            } else if let email = credential.email {
                                appState.displayName = email.components(separatedBy: "@").first?
                                    .replacingOccurrences(of: ".", with: " ")
                                    .replacingOccurrences(of: "_", with: " ")
                                    .replacingOccurrences(of: "-", with: " ")
                                    .capitalized
                            }
                        }
                        appState.isAuthenticated = true
                        appState.role = selectedRole
                    case .failure(_):
                        errorMessage = "Sign in failed"
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .cornerRadius(8)

            Button(action: { googleSignUp() }) {
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
        }
    }

    private func createAccount() {
        guard !firstName.isEmpty, !lastName.isEmpty, email.contains("@"), password.count >= 4 else {
            errorMessage = "Please fill all fields correctly"
            return
        }
        guard acceptedTerms else { errorMessage = "Please accept the terms"; return }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let role = try await appState.authService.signUp(email: email, password: password, role: selectedRole)
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

    private func googleSignUp() {
        // Ensure GoogleSignIn has configuration
        if GIDSignIn.sharedInstance.configuration == nil {
            if let clientID = FirebaseApp.app()?.options.clientID {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            }
        }
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            if let name = result?.user.profile?.name, !name.isEmpty {
                appState.displayName = name
            } else if let email = result?.user.profile?.email {
                appState.displayName = email.components(separatedBy: "@").first?
                    .replacingOccurrences(of: ".", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .capitalized
            }
            appState.isAuthenticated = true
            appState.role = selectedRole
        }
    }
}
