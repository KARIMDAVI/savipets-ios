import SwiftUI

struct AdminChangePasswordView: View {
    @EnvironmentObject var appState: AppState
    @State private var current: String = ""
    @State private var newPass: String = ""
    @State private var confirm: String = ""
    @State private var errorMessage: String? = nil
    @State private var success: Bool = false
    @State private var isLoading: Bool = false

    var body: some View {
        Form {
            Section("Admin Password") {
                Text("Password update is temporarily disabled while migrating to Firebase Auth.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Admin Security")
    }

    @MainActor
    private func change() async {
        guard !current.isEmpty, !newPass.isEmpty, newPass == confirm else {
            errorMessage = "Please enter valid fields and match passwords"
            success = false
            return
        }
        isLoading = true
        defer { isLoading = false }

        // Disabled during migration to Firebase Auth; simulate success for now
        errorMessage = nil
        success = true
        current = ""; newPass = ""; confirm = ""
    }
}
