import SwiftUI
import FirebaseAuth
import OSLog

struct SitterProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteSheet: Bool = false
    @State private var deleteConfirmText: String = ""
    @State private var deletePassword: String = ""
    @State private var isDeleting: Bool = false
    @State private var deleteError: String? = nil
    @State private var deletionScheduledDate: Date? = nil
    @State private var showCancelDeletionAlert: Bool = false
    
    private var email: String { appState.authService.currentUser?.email ?? "" }
    private var display: String {
        if let d = appState.displayName, !d.isEmpty { return d }
        let part = email.split(separator: "@").first.map(String.init) ?? ""
        return part.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
    
    private var canDelete: Bool {
        let provider = appState.authService.getCurrentSignInProvider()
        
        // OAuth users only need DELETE confirmation
        if provider == .google || provider == .apple {
            return deleteConfirmText.uppercased() == "DELETE"
        }
        
        // Email users need both password and DELETE confirmation
        return !deletePassword.isEmpty && deleteConfirmText.uppercased() == "DELETE"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack { Text("Name"); Spacer(); Text(display).foregroundColor(.secondary) }
                    HStack { Text("Email"); Spacer(); Text(email).foregroundColor(.secondary) }
                    HStack { Text("Role"); Spacer(); Text("Pet Sitter").foregroundColor(.secondary) }
                }
                
                Section("Profile Requirements") {
                    NavigationLink("Complete Profile") {
                        SitterProfileCompletionView()
                    }
                    .foregroundColor(.blue)
                }

                // Sign Out (separate from deletion to avoid accidental clicks)
                Section {
                    Button(action: { signOut() }) {
                        HStack { Spacer(); Text("Sign Out"); Spacer() }
                    }
                }

                // Danger Zone at the bottom
                Section(footer: Text("Deleting your account is permanent and cannot be undone.").font(.footnote).foregroundColor(.secondary)) {
                    Button(role: .destructive) { showDeleteSheet = true } label: {
                        HStack { Spacer(); Text("Delete Account"); Spacer() }
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showDeleteSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 20) {
                        // Warning header
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                Text("Delete Account")
                                    .font(.title2)
                                    .bold()
                            }
                            
                            Text("This action is permanent and cannot be undone.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // What will be deleted
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The following data will be permanently deleted:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Your profile and account information", systemImage: "person.crop.circle.badge.xmark")
                                Label("Your staff profile and certifications", systemImage: "briefcase.fill")
                                Label("Your location data", systemImage: "location.fill")
                                Label("Your visit history will be anonymized", systemImage: "calendar.badge.clock")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        // Password verification
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter your password to confirm:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            SecureField("Password", text: $deletePassword)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)
                        }
                        
                        // Type DELETE confirmation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type DELETE to confirm:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("DELETE", text: $deleteConfirmText)
                                .textInputAutocapitalization(.characters)
                                .textCase(.uppercase)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Error message
                        if let deleteError {
                            Text(deleteError)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .padding(.horizontal, 8)
                        }
                        
                        Spacer()
                        
                        // Delete button
                        Button(role: .destructive) {
                            Task { await deleteAccount() }
                        } label: {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isDeleting ? "Deleting Account..." : "Permanently Delete My Account")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .background(Color.red.opacity((isDeleting || !canDelete) ? 0.5 : 1.0))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isDeleting || !canDelete)
                    }
                    .padding()
                    .navigationTitle("Delete Account")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showDeleteSheet = false
                                resetDeleteForm()
                            }
                            .disabled(isDeleting)
                        }
                    }
                }
                .interactiveDismissDisabled(isDeleting)
            }
        }
    }

    private func signOut() {
        Task {
            do { try appState.authService.signOut() } catch {}
            await MainActor.run {
                appState.role = nil
                appState.displayName = nil
            }
        }
    }

    @MainActor
    private func deleteAccount() async {
        guard canDelete else { return }
        
        isDeleting = true
        deleteError = nil
        
        do {
            let provider = appState.authService.getCurrentSignInProvider()
            
            // Schedule deletion with 30-day grace period
            if provider == .email {
                try await appState.authService.scheduleAccountDeletion(
                    password: deletePassword,
                    sendConfirmationEmail: true
                )
            } else {
                // OAuth users (Google/Apple)
                try await appState.authService.scheduleAccountDeletion(
                    password: nil,
                    sendConfirmationEmail: true
                )
            }
            
            // Success - account scheduled for deletion
            await MainActor.run {
                // Calculate deletion date (30 days from now)
                deletionScheduledDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
                showDeleteSheet = false
                isDeleting = false
            }
            
            AppLogger.auth.info("Sitter account deletion scheduled successfully")
            
        } catch let error as FirebaseAuthError {
            // Handle specific Firebase auth errors with user-friendly messages
            await MainActor.run {
                deleteError = error.errorDescription ?? error.localizedDescription
                isDeleting = false
            }
            AppLogger.auth.error("Account deletion scheduling failed: \(error.localizedDescription)")
            
        } catch {
            // Handle other errors
            await MainActor.run {
                deleteError = ErrorMapper.userFriendlyMessage(for: error)
                isDeleting = false
            }
            AppLogger.auth.error("Account deletion scheduling error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func cancelDeletion() async {
        do {
            try await appState.authService.cancelAccountDeletion()
            deletionScheduledDate = nil
            AppLogger.auth.info("Sitter account deletion canceled")
        } catch {
            AppLogger.auth.error("Failed to cancel deletion: \(error.localizedDescription)")
        }
    }
    
    private func resetDeleteForm() {
        deleteConfirmText = ""
        deletePassword = ""
        deleteError = nil
    }
}
