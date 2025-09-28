import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

enum FirebaseAuthError: LocalizedError {
    case userNotFound
    case invalidPassword
    case userAlreadyExists
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case requiresRecentLogin
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound: return "No account found for this email."
        case .invalidPassword: return "Incorrect password."
        case .userAlreadyExists: return "An account with this email already exists."
        case .emailAlreadyInUse: return "This email is already registered."
        case .weakPassword: return "Password should be at least 6 characters."
        case .networkError: return "Network error. Please check your connection."
        case .requiresRecentLogin: return "Please sign in again to change your password."
        case .unknown(let message): return message
        }
    }
}

final class FirebaseAuthService: ObservableObject {
    @Published var currentUser: User?
    private let db = Firestore.firestore()
    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        // Listen for auth state changes
        listener = Auth.auth().addStateDidChangeListener { _, user in
            self.currentUser = user
        }
    }

    deinit {
        if let listener { Auth.auth().removeStateDidChangeListener(listener) }
    }

    func signIn(email: String, password: String) async throws -> UserRole {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            if let role = try await getUserRole(uid: result.user.uid) {
                // Ensure canonical profile exists
                try? await createInitialProfilesIfNeeded(user: result.user, defaultRole: role)
                return role
            }
            // Seed missing role doc: make admin for the known admin email, else default owner
            let seededRole: UserRole = (result.user.email?.lowercased() == "admin@savipets.com") ? .admin : .petOwner
            try await setUserRole(uid: result.user.uid, role: seededRole, email: result.user.email ?? email)
            // Create initial profiles for brand new users
            try? await createInitialProfilesIfNeeded(user: result.user, defaultRole: seededRole)
            return seededRole
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func signUp(email: String, password: String, role: UserRole) async throws -> UserRole {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            // Save user role to Firestore
            try await setUserRole(uid: result.user.uid, role: role, email: email)
            // Initialize canonical user/staff profiles
            try? await createInitialProfilesIfNeeded(user: result.user, defaultRole: role)
            return role
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func getUserRole(uid: String) async throws -> UserRole? {
        let document = try await db.collection("users").document(uid).getDocument()
        guard let data = document.data(),
              let roleString = data["role"] as? String,
              let role = UserRole(rawValue: roleString) else {
            return nil
        }
        return role
    }

    func setUserRole(uid: String, role: UserRole, email: String) async throws {
        try await db.collection("users").document(uid).setData([
            "role": role.rawValue,
            "email": email,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // Change password for the currently signed-in (admin) user.
    // Reauthenticates with the current password, then updates to the new password.
    func changeAdminPassword(current: String, new: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.userNotFound
        }
        guard let email = user.email else {
            throw FirebaseAuthError.unknown("Current user has no email.")
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: current)
        do {
            // Must reauthenticate before sensitive operations
            _ = try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: new)
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    private func mapAuthError(_ error: NSError) -> FirebaseAuthError {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return .unknown(error.localizedDescription)
        }

        switch errorCode {
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .invalidPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkError
        case .requiresRecentLogin:
            return .requiresRecentLogin
        default:
            return .unknown(error.localizedDescription)
        }
    }

    // MARK: - Initial Profiles
    private func createInitialProfilesIfNeeded(user: User, defaultRole: UserRole) async throws {
        let dataService = PetDataService()
        let exists = try await dataService.userProfileExists(uid: user.uid)
        if exists { return }

        let profile = PetDataService.UserProfile(
            id: user.uid,
            email: user.email ?? "",
            displayName: user.displayName ?? "Pet Parent",
            photoURL: user.photoURL?.absoluteString,
            phone: user.phoneNumber,
            address: nil,
            createdAt: Date(),
            role: defaultRole.rawValue,
            ownerData: PetDataService.OwnerData(
                preferences: ["notifications": true],
                emergencyContact: nil
            )
        )
        try await dataService.updateProfile(profile: profile)

        if defaultRole == .petSitter || defaultRole == .admin {
            let staff = PetDataService.StaffProfile(
                id: user.uid,
                skills: [],
                certifications: [],
                availability: [],
                metricsSummary: ["completedShifts": 0.0],
                bio: nil,
                locationZone: nil,
                isManager: (defaultRole == .admin) ? true : nil,
                adminNotes: nil
            )
            try await dataService.updateStaffProfile(profile: staff)
        }
    }
}

