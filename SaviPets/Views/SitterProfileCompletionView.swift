import SwiftUI
import FirebaseFirestore
import OSLog

struct SitterProfileCompletionView: View {
    @EnvironmentObject var appState: AppState
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var address: String = ""
    @State private var phoneNumber: String = ""
    @State private var bio: String = ""
    @State private var isLoading: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    private let db = Firestore.firestore()
    
    var body: some View {
        Form {
            Section(header: Text("Required Information")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("First Name", text: $firstName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Your full address", text: $address, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("(555) 123-4567", text: $phoneNumber)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)
                }
            }
            
            Section(header: Text("Optional Information")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Tell clients about your pet care experience...", text: $bio, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(4...8)
                }
            }
            
            Section(footer: Text("Your name and address will be visible to pet owners when they book your services. This helps build trust and ensures transparency.")) {
                Button(action: saveProfile) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isSaving ? "Saving..." : "Save Profile")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSaving || !isFormValid)
                .buttonStyle(.borderedProminent)
            }
            
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            if let successMessage {
                Section {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Complete Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func loadCurrentProfile() {
        guard let uid = appState.authService.currentUser?.uid else { return }
        
        isLoading = true
        Task {
            do {
                let userDoc = try await db.collection("users").document(uid).getDocument()
                if let data = userDoc.data() {
                    await MainActor.run {
                        firstName = data["firstName"] as? String ?? ""
                        lastName = data["lastName"] as? String ?? ""
                        address = data["address"] as? String ?? ""
                        phoneNumber = data["phoneNumber"] as? String ?? ""
                        bio = data["bio"] as? String ?? ""
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load profile: \(error.localizedDescription)"
                    isLoading = false
                }
                AppLogger.ui.error("Error loading sitter profile: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveProfile() {
        guard isFormValid, let uid = appState.authService.currentUser?.uid else { return }
        
        isSaving = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                let fullName = "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))"
                
                // Update user document
                try await db.collection("users").document(uid).setData([
                    "firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "lastName": lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "displayName": fullName,
                    "address": address.trimmingCharacters(in: .whitespacesAndNewlines),
                    "phoneNumber": phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    "bio": bio.trimmingCharacters(in: .whitespacesAndNewlines),
                    "profileCompleted": true,
                    "profileUpdatedAt": FieldValue.serverTimestamp()
                ], merge: true)
                
                // Update public profile for visibility to other users
                try await db.collection("publicProfiles").document(uid).setData([
                    "displayName": fullName,
                    "address": address.trimmingCharacters(in: .whitespacesAndNewlines),
                    "phoneNumber": phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    "bio": bio.trimmingCharacters(in: .whitespacesAndNewlines),
                    "role": "petSitter",
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
                
                await MainActor.run {
                    appState.displayName = fullName
                    successMessage = "Profile saved successfully! Your information is now visible to pet owners."
                    isSaving = false
                }
                
                AppLogger.ui.info("Sitter profile completed successfully for user: \(uid)")
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    isSaving = false
                }
                AppLogger.ui.error("Error saving sitter profile: \(error.localizedDescription)")
            }
        }
    }
}
