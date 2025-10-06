import SwiftUI
import FirebaseAuth

struct SitterProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteSheet: Bool = false
    @State private var deleteConfirmText: String = ""
    @State private var isDeleting: Bool = false
    @State private var deleteError: String? = nil
    private var email: String { appState.authService.currentUser?.email ?? "" }
    private var display: String {
        if let d = appState.displayName, !d.isEmpty { return d }
        let part = email.split(separator: "@").first.map(String.init) ?? ""
        return part.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack { Text("Name"); Spacer(); Text(display).foregroundColor(.secondary) }
                    HStack { Text("Email"); Spacer(); Text(email).foregroundColor(.secondary) }
                    HStack { Text("Role"); Spacer(); Text("Pet Sitter").foregroundColor(.secondary) }
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
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Are you sure?").font(.title2).bold()
                        Text("This will permanently delete your account and all associated data.")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type DELETE to confirm:").font(.subheadline)
                            TextField("DELETE", text: $deleteConfirmText)
                                .textInputAutocapitalization(.characters)
                                .textCase(.uppercase)
                                .textFieldStyle(.roundedBorder)
                        }
                        if let deleteError { Text(deleteError).foregroundColor(.red).font(.footnote) }
                        Spacer()
                        Button(role: .destructive) {
                            Task { await deleteAccount() }
                        } label: {
                            HStack { Spacer(); Text(isDeleting ? "Deleting..." : "Permanently Delete"); Spacer() }
                        }
                        .disabled(isDeleting || deleteConfirmText.uppercased() != "DELETE")
                    }
                    .padding()
                    .navigationTitle("Delete Account")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showDeleteSheet = false } } }
                }
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
        guard deleteConfirmText.uppercased() == "DELETE" else { return }
        await MainActor.run { isDeleting = true; deleteError = nil }
        do {
            try await appState.authService.deleteAccount()
            await MainActor.run {
                appState.role = nil
                appState.displayName = nil
                showDeleteSheet = false
                isDeleting = false
            }
        } catch {
            await MainActor.run {
                deleteError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isDeleting = false
            }
        }
    }
}
