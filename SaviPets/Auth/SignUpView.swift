import SwiftUI
import FirebaseCore
import AuthenticationServices
import GoogleSignIn
import UIKit

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
    
    // Additional fields for sitters
    @State private var address: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()

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
                        
                        // Additional fields for sitters
                        if selectedRole == .petSitter {
                            FloatingTextField(title: "Address", text: $address)
                            
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

                        if let errorMessage { Text(errorMessage).foregroundColor(SPDesignSystem.Colors.error) }

                        Button(action: { if !isLoading { createAccount() } }) {
                            HStack(spacing: SPDesignSystem.Spacing.s) {
                                if isLoading {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: SPDesignSystem.Colors.dark))
                                }
                                Image(systemName: "person.badge.plus.fill")
                                Text("Create Account")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(isLoading)
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

                            // After Apple sign-in, ensure role/profile exists using selectedRole as default
                            Task {
                                // Extract display name from Apple credential
                                let displayName: String?
                                if let given = credential.fullName?.givenName, let family = credential.fullName?.familyName {
                                    let full = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
                                    displayName = full.isEmpty ? nil : full
                                } else {
                                    displayName = nil
                                }

                                let _ = try? await appState.authService.bootstrapAfterOAuth(defaultRole: selectedRole, displayName: displayName)
                                await MainActor.run {
                                    if appState.displayName == nil {
                                        appState.displayName = displayName
                                    }
                                    appState.isAuthenticated = true
                                    appState.role = selectedRole
                                }
                            }
                        }
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
        
        // Additional validation for sitters
        if selectedRole == .petSitter {
            guard !address.isEmpty else {
                errorMessage = "Please provide your address"
                return
            }
            guard Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0 >= 18 else {
                errorMessage = "You must be at least 18 years old to be a pet sitter"
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
                    address: selectedRole == .petSitter ? address : nil,
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
            
            // Extract display name from Google profile
            let displayName: String?
            if let name = result?.user.profile?.name, !name.isEmpty {
                displayName = name
            } else {
                displayName = nil
            }
            
            // Ensure role/profile exists using selectedRole as default
            Task {
                let _ = try? await appState.authService.bootstrapAfterOAuth(defaultRole: selectedRole, displayName: displayName)
                await MainActor.run {
                    appState.displayName = displayName
                    if appState.displayName == nil, let email = result?.user.profile?.email {
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
    }
}
