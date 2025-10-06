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
    @EnvironmentObject var chatService: ChatService

    var body: some View {
        switch appState.role {
        case .petOwner:
            OwnerDashboardView()
                .environmentObject(chatService)
        case .petSitter:
            SitterDashboardView()
                .environmentObject(chatService)
        case .admin:
            AdminDashboardView()
                .environmentObject(chatService)
        case .none:
            SignInView()
        }
    }
}

