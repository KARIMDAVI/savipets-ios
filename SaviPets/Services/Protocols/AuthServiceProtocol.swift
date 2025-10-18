import Foundation
import FirebaseAuth

// MARK: - Protocol Abstractions

protocol UserProtocol {
    var uid: String { get }
    var email: String? { get }
    var displayName: String? { get }
    var photoURL: URL? { get }
    var isEmailVerified: Bool { get }
}

// Extend Firebase's User to conform
extension User: UserProtocol {}

protocol AuthServiceProtocol {
    var currentUser: UserProtocol? { get }
    
    func signIn(email: String, password: String) async throws -> UserRole
    func signUp(
        email: String,
        password: String,
        role: UserRole,
        firstName: String?,
        lastName: String?,
        address: String?,
        dateOfBirth: Date?
    ) async throws -> UserRole
    func signOut() throws
    func deleteAccount() async throws
    func deleteAccountWithReauth(password: String) async throws
    func scheduleAccountDeletion(password: String?, sendConfirmationEmail: Bool) async throws
    func cancelAccountDeletion() async throws
    func reauthenticate(password: String) async throws
    func getCurrentSignInProvider() -> SignInProvider
    func getUserRole(uid: String) async throws -> UserRole?
    func setUserRole(uid: String, role: UserRole, email: String, displayName: String?) async throws
    func bootstrapAfterOAuth(defaultRole: UserRole, displayName: String?) async throws -> UserRole
    func changeAdminPassword(current: String, new: String) async throws
}

extension FirebaseAuthService: AuthServiceProtocol {}
