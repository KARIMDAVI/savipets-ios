import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                RoleRouterView()
            } else {
                SignInView()
            }
        }
    }
}

private struct RoleRouterView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.role {
        case .petOwner:
            OwnerDashboardView()
        case .petSitter:
            SitterDashboardView()
        case .admin:
            AdminDashboardView()
        case .none:
            SignInView()
        }
    }
}



