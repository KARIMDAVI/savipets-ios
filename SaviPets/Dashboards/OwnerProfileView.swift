import SwiftUI
import OSLog
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore



struct OwnerProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteSheet: Bool = false
    @State private var deleteConfirmText: String = ""
    @State private var deletePassword: String = ""
    @State private var isDeleting: Bool = false
    @State private var deleteError: String? = nil
    @State private var deletionScheduledDate: Date? = nil
    @State private var showCancelDeletionAlert: Bool = false
    @State private var isEditing: Bool = false
    @State private var editedName: String = ""
    @State private var address1: String = ""
    @State private var address2: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var emergencyContactName: String = ""
    @State private var emergencyContactPhone: String = ""

    @State private var isLoading: Bool = false
    @State private var saveError: String? = nil

    private var email: String { appState.authService.currentUser?.email ?? "" }
    private var display: String {
        // Use saved displayName if available, otherwise fall back to email-based name
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
                    // Full Name - Editable
                    HStack {
                        Text("Full Name")
                        Spacer()
                        if isEditing {
                            TextField("Enter your name", text: $editedName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        } else {
                            Text(display).foregroundColor(.secondary)
                        }
                    }
                    
                    // Email - Read only
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(email).foregroundColor(.secondary)
                    }
                    
                    // Role - Read only
                    HStack {
                        Text("Role")
                        Spacer()
                        Text("Pet Parent").foregroundColor(.secondary)
                    }
                    
                    // Show deletion scheduled warning if applicable
                    if let deletionDate = deletionScheduledDate {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Account Deletion Scheduled")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                            
                            Text("Your account will be permanently deleted on \(deletionDate, style: .date).")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("You can cancel this at any time before that date.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button {
                                showCancelDeletionAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Cancel Deletion & Keep Account")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding()
                            }
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Address") {
                    HStack {
                        Text("Address 1")
                        Spacer()
                        if isEditing {
                            TextField("Street address", text: $address1)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        } else {
                            Text(address1.isEmpty ? "Not set" : address1)
                                .foregroundColor(address1.isEmpty ? .secondary : .primary)
                        }
                    }
                    
                    HStack {
                        Text("Address 2")
                        Spacer()
                        if isEditing {
                            TextField("Apt, suite, etc. (optional)", text: $address2)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        } else {
                            Text(address2.isEmpty ? "Not set" : address2)
                                .foregroundColor(address2.isEmpty ? .secondary : .primary)
                        }
                    }
                    
                    HStack {
                        Text("City")
                        Spacer()
                        if isEditing {
                            TextField("City", text: $city)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        } else {
                            Text(city.isEmpty ? "Not set" : city)
                                .foregroundColor(city.isEmpty ? .secondary : .primary)
                        }
                    }
                    
                    HStack {
                        Text("State")
                        Spacer()
                        if isEditing {
                            TextField("State", text: $state)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        } else {
                            Text(state.isEmpty ? "Not set" : state)
                                .foregroundColor(state.isEmpty ? .secondary : .primary)
                        }
                    }
                    
                    HStack {
                        Text("Zip Code")
                        Spacer()
                        if isEditing {
                            TextField("Zip code", text: $zipCode)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        } else {
                            Text(zipCode.isEmpty ? "Not set" : zipCode)
                                .foregroundColor(zipCode.isEmpty ? .secondary : .primary)
                        }
                    }
                }
                
                Section("Emergency Contact") {
                    HStack {
                        Text("Contact")
                        Spacer()
                        if isEditing {
                            TextField("Name", text: $emergencyContactName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                            TextField("Phone", text: $emergencyContactPhone)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        } else {
                            Text(emergencyContactName.isEmpty ? "Not set" : emergencyContactName)
                                .foregroundColor(emergencyContactName.isEmpty ? .secondary : .primary)
                            if !emergencyContactPhone.isEmpty {
                                Text(emergencyContactPhone)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Sign Out
                Section {
                    Button(action: { signOut() }) {
                        HStack { Spacer(); Text("Sign Out"); Spacer() }
                    }
                }
                
                // DELETE ACCOUNT - Inside the List as the last section
                if isEditing {
                    Section {
                        VStack(spacing: 8) {
                            Text("Deleting your account is permanent and cannot be undone.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("Delete Account")
                                .foregroundColor(.red)
                                .font(.body)
                                .onTapGesture {
                                    showDeleteSheet = true
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        HStack {
                            Button("Cancel") {
                                cancelEdit()
                            }
                            .foregroundColor(.red)
                            
                            Button("Save") {
                                Task { await saveProfile() }
                            }
                            .foregroundColor(.blue)
                            .disabled(isLoading)
                        }
                    } else {
                        Button("Edit") {
                            startEdit()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .onAppear {
                loadProfile()
            }
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
                                Label("All pet profiles and photos", systemImage: "pawprint.fill")
                                Label("Your location data", systemImage: "location.fill")
                                Label("Pending bookings will be canceled", systemImage: "calendar.badge.exclamationmark")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        // Password verification (only for email users)
                        if appState.authService.getCurrentSignInProvider() == .email {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Enter your password to confirm:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                SecureField("Password", text: $deletePassword)
                                    .textFieldStyle(.roundedBorder)
                                    .textContentType(.password)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("You signed in with \(appState.authService.getCurrentSignInProvider().displayName)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
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
            .alert("Cancel Account Deletion", isPresented: $showCancelDeletionAlert) {
                Button("Keep My Account", role: .none) {
                    Task {
                        await cancelDeletion()
                    }
                }
                Button("Continue with Deletion", role: .cancel) {}
            } message: {
                Text("Are you sure you want to cancel the deletion? Your account will remain active and all scheduled deletion will be stopped.")
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
                
                // Show success message (account NOT deleted yet, just scheduled)
                // User can still use the app for 30 days
            }
            
            AppLogger.auth.info("Account deletion scheduled successfully")
            
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
            AppLogger.auth.info("Account deletion canceled")
        } catch {
            AppLogger.auth.error("Failed to cancel deletion: \(error.localizedDescription)")
        }
    }
    
    private func resetDeleteForm() {
        deleteConfirmText = ""
        deletePassword = ""
        deleteError = nil
    }

    // MARK: - Profile Management
    
    private func loadProfile() {
        guard let uid = appState.authService.currentUser?.uid else { return }
        
        Task {
            do {
                let db = Firestore.firestore()
                let doc = try await db.collection("users").document(uid).getDocument()
                
                if let data = doc.data() {
                    await MainActor.run {
                        // Load existing profile data
                        let savedDisplayName = data["displayName"] as? String ?? ""
                        editedName = savedDisplayName.isEmpty ? display : savedDisplayName
                        
                        // Update appState with the saved displayName from Firestore
                        if !savedDisplayName.isEmpty {
                            appState.displayName = savedDisplayName
                        }
                        
                        address1 = data["address1"] as? String ?? ""
                        address2 = data["address2"] as? String ?? ""
                        city = data["city"] as? String ?? ""
                        state = data["state"] as? String ?? ""
                        zipCode = data["zipCode"] as? String ?? ""
                        emergencyContactName = data["emergencyContact"] as? String ?? ""
                        emergencyContactPhone = data["emergencyContactPhone"] as? String ?? ""
                    }
                }
            } catch {
                AppLogger.logError(error, context: "LoadProfile", logger: .data)
            }
        }
    }
    
    private func startEdit() {
        // Use the current saved displayName or fall back to computed display
        editedName = appState.displayName ?? display
        isEditing = true
        saveError = nil
    }
    
    private func cancelEdit() {
        isEditing = false
        saveError = nil
        // Reset to original values
        loadProfile()
    }
    
    @MainActor
    private func saveProfile() async {
        guard let uid = appState.authService.currentUser?.uid else { return }
        
        isLoading = true
        saveError = nil
        
        do {
            let db = Firestore.firestore()
            let profileData: [String: Any] = [
                "displayName": editedName.trimmingCharacters(in: .whitespacesAndNewlines),
                "address1": address1.trimmingCharacters(in: .whitespacesAndNewlines),
                "address2": address2.trimmingCharacters(in: .whitespacesAndNewlines),
                "city": city.trimmingCharacters(in: .whitespacesAndNewlines),
                "state": state.trimmingCharacters(in: .whitespacesAndNewlines),
                "zipCode": zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
                "emergencyContact": emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines),
                "emergencyContactPhone": emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                "updatedAt": Timestamp()
            ]
            
            try await db.collection("users").document(uid).setData(profileData, merge: true)
            
            // Update app state
            appState.displayName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            isEditing = false
            isLoading = false
            
            AppLogger.logEvent("ProfileUpdated", parameters: ["uid": uid], logger: .data)
            
        } catch {
            saveError = error.localizedDescription
            isLoading = false
            AppLogger.logError(error, context: "SaveProfile", logger: .data)
        }
    }
}
