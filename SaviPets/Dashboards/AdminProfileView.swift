import SwiftUI
import FirebaseAuth

struct AdminProfileView: View {
    @EnvironmentObject var appState: AppState
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
                    HStack { Text("Role"); Spacer(); Text("Admin").foregroundColor(.secondary) }
                }
                Section {
                    Button(role: .destructive) { signOut() } label: {
                        HStack { Spacer(); Text("Sign Out"); Spacer() }
                    }
                }
            }
            .navigationTitle("Profile")
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
}


