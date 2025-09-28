import Foundation
import Combine

enum AuthError: LocalizedError {
    case userNotFound
    case invalidPassword
    case userAlreadyExists
    case adminPasswordIncorrect

    var errorDescription: String? {
        switch self {
        case .userNotFound: return "No account found for this email."
        case .invalidPassword: return "Incorrect password."
        case .userAlreadyExists: return "An account with this email already exists."
        case .adminPasswordIncorrect: return "Current password is incorrect."
        }
    }
}

struct UserAccount: Codable, Equatable {
    let email: String
    var password: String
    let role: UserRole
}

final class AuthService: ObservableObject {
    @Published private(set) var currentUser: UserAccount? = nil

    private let adminPasswordKey = "auth_admin_password"
    private var accounts: [String: UserAccount] = [:] // keyed by lowercased email

    init() {
        loadDefaultAccounts()
    }

    private func loadDefaultAccounts() {
        // Admin password can be changed and persisted
        let adminPassword = UserDefaults.standard.string(forKey: adminPasswordKey) ?? "8899"
        let admin = UserAccount(email: "admin@savipets.com", password: adminPassword, role: .admin)
        let po = UserAccount(email: "testpo@savipets.com", password: "1234", role: .petOwner)
        let ps = UserAccount(email: "testps@savipets.com", password: "1234", role: .petSitter)

        [admin, po, ps].forEach { accounts[$0.email.lowercased()] = $0 }
    }

    func signIn(email: String, password: String) throws -> UserRole {
        let key = email.lowercased()
        guard let account = accounts[key] else { throw AuthError.userNotFound }
        guard account.password == password else { throw AuthError.invalidPassword }
        currentUser = account
        return account.role
    }

    func signOut() {
        currentUser = nil
    }

    func signUp(email: String, password: String, role: UserRole) throws -> UserRole {
        let key = email.lowercased()
        guard accounts[key] == nil else { throw AuthError.userAlreadyExists }
        let account = UserAccount(email: email, password: password, role: role)
        accounts[key] = account
        currentUser = account
        return role
    }

    func changeAdminPassword(current: String, new: String) throws {
        let key = "admin@savipets.com"
        guard var admin = accounts[key] else { return }
        guard admin.password == current else { throw AuthError.adminPasswordIncorrect }
        admin.password = new
        accounts[key] = admin
        UserDefaults.standard.set(new, forKey: adminPasswordKey)
    }
}



