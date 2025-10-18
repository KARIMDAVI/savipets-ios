import Foundation
import OSLog
import SwiftUI
import Combine
import FirebaseAuth

final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var role: UserRole? = nil
    @Published var displayName: String? = nil
    @Published var authErrorMessage: String? = nil

    let authService = FirebaseAuthService()
    let chatService = ChatService()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen to auth state
        authService.$currentUser
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$isAuthenticated)

        // Update display name
        authService.$currentUser
            .map { user in
                guard let email = user?.email else { return nil }
                return email.split(separator: "@").first.map { part in
                    part.replacingOccurrences(of: ".", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .replacingOccurrences(of: "-", with: " ")
                        .capitalized
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$displayName)

        // Load user role when authenticated
        authService.$currentUser
            .compactMap { $0?.uid }
            .sink { uid in
                Task { [weak self] in
                    guard let self else { return }
                    let r = try? await self.authService.getUserRole(uid: uid)
                    await MainActor.run { 
                        self.role = r
                        AppLogger.auth.info("Setting user role to: \(r?.rawValue ?? "nil")")
                        // Also set the role in the chat service
                        if let role = r {
                            self.chatService.setCurrentUserRole(role)
                            AppLogger.auth.info("Called chatService.setCurrentUserRole(\(role.rawValue))")
                        }
                        
                        // Restart visits listener after authentication
                        VisitsListenerManager.shared.restartAfterAuth()
                    }
                }
            }
            .store(in: &cancellables)
    }
}

