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
    @Published var currentUser: UserProtocol?
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

    func signUp(
        email: String,
        password: String,
        role: UserRole,
        firstName: String? = nil,
        lastName: String? = nil,
        address: String? = nil,
        dateOfBirth: Date? = nil
    ) async throws -> UserRole {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Build display name from provided first/last names
            let trimmedFirst = (firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLast = (lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let fullName = [trimmedFirst.isEmpty ? nil : trimmedFirst, trimmedLast.isEmpty ? nil : trimmedLast]
                .compactMap { $0 }
                .joined(separator: " ")
            let displayName = fullName.isEmpty ? nil : fullName
            
            // Save user role and display name to Firestore
            try await setUserRole(uid: result.user.uid, role: role, email: email, displayName: displayName)
            
            // Save additional profile fields to users doc
            var extra: [String: Any] = [:]
            if let firstName = firstName, !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { extra["firstName"] = firstName }
            if let lastName = lastName, !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { extra["lastName"] = lastName }
            if let address = address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { extra["address"] = address }
            if let dateOfBirth = dateOfBirth { extra["dateOfBirth"] = dateOfBirth }
            if !extra.isEmpty {
                try await db.collection("users").document(result.user.uid).setData(extra, merge: true)
            }
            
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

    // MARK: - Account deletion
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { throw FirebaseAuthError.userNotFound }
        do {
            try await user.delete()
        } catch let error as NSError {
            // Requires recent login; bubble meaningful error
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue { throw FirebaseAuthError.requiresRecentLogin }
            throw mapAuthError(error)
        }
    }

    func getUserRole(uid: String) async throws -> UserRole? {
        return try await NetworkRetryHelper.retry {
            let document = try await db.collection("users").document(uid).getDocument()
            guard let data = document.data(),
                  let roleString = data["role"] as? String,
                  let role = UserRole(rawValue: roleString) else {
                return nil
            }
            return role
        }
    }

    func setUserRole(uid: String, role: UserRole, email: String, displayName: String? = nil) async throws {
        try await NetworkRetryHelper.retry {
            try await db.collection("users").document(uid).setData([
                "role": role.rawValue,
                "email": email,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            // Use provided displayName, or fallback to email-derived name
            let finalDisplayName: String
            if let displayName = displayName, !displayName.isEmpty {
                finalDisplayName = displayName
            } else {
                finalDisplayName = email.split(separator: "@").first.map(String.init)?.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ") ?? ""
            }
            
            // Maintain world-readable minimal public profile
            try await db.collection("publicProfiles").document(uid).setData([
                "displayName": finalDisplayName,
                "role": role.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    // MARK: - OAuth Bootstrap
    /// Ensures that after a successful OAuth sign-in (Apple/Google), the user's role
    /// and canonical profiles exist in Firestore. Returns the effective role.
    func bootstrapAfterOAuth(defaultRole: UserRole, displayName: String? = nil) async throws -> UserRole {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.userNotFound
        }

        if let role = try await getUserRole(uid: user.uid) {
            // Ensure canonical profiles exist
            try? await createInitialProfilesIfNeeded(user: user, defaultRole: role)
            return role
        }

        // Seed missing role doc: make admin for the known admin email, else use provided default
        let seededRole: UserRole = (user.email?.lowercased() == "admin@savipets.com") ? .admin : defaultRole
        try await setUserRole(uid: user.uid, role: seededRole, email: user.email ?? "", displayName: displayName)
        try? await createInitialProfilesIfNeeded(user: user, defaultRole: seededRole)
        return seededRole
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
        try await NetworkRetryHelper.retry {
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

            // Seed public profile as well
            try await db.collection("publicProfiles").document(user.uid).setData([
                "displayName": profile.displayName,
                "avatarUrl": profile.photoURL ?? "",
                "role": defaultRole.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

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
}

