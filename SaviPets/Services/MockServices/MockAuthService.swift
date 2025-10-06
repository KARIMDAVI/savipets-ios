import Foundation
import FirebaseAuth

// MARK: - Mock User Implementation

struct MockUser: UserProtocol {
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: URL?
    let isEmailVerified: Bool
    
    init(uid: String, email: String?, displayName: String? = nil, photoURL: URL? = nil, isEmailVerified: Bool = true) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.isEmailVerified = isEmailVerified
    }
}

final class MockAuthService: AuthServiceProtocol {
    var currentUser: UserProtocol?
    var shouldSucceed = true
    var mockError: Error?
    var mockUserRole: UserRole = .petOwner
    
    // Mock data
    private var mockUsers: [String: UserRole] = [:]
    private var mockUserProfiles: [String: [String: Any]] = [:]
    
    init() {
        // Seed some test data
        mockUsers["test@example.com"] = .petOwner
        mockUsers["admin@example.com"] = .admin
        mockUsers["sitter@example.com"] = .petSitter
    }
    
    func signIn(email: String, password: String) async throws -> UserRole {
        if !shouldSucceed {
            throw mockError ?? NSError(domain: "MockAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Mock authentication failed"])
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if let role = mockUsers[email] {
            // Create mock user
            currentUser = MockUser(uid: "mock-\(email)", email: email)
            return role
        } else {
            throw FirebaseAuthError.userNotFound
        }
    }
    
    func signUp(
        email: String,
        password: String,
        role: UserRole,
        firstName: String?,
        lastName: String?,
        address: String?,
        dateOfBirth: Date?
    ) async throws -> UserRole {
        if !shouldSucceed {
            throw mockError ?? NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Mock signup failed"])
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if mockUsers[email] != nil {
            throw FirebaseAuthError.emailAlreadyInUse
        }
        
        mockUsers[email] = role
        currentUser = MockUser(uid: "mock-\(email)", email: email)
        
        // Store profile data
        var profileData: [String: Any] = [
            "email": email,
            "role": role.rawValue,
            "createdAt": Date()
        ]
        
        if let firstName = firstName, !firstName.isEmpty {
            profileData["firstName"] = firstName
        }
        if let lastName = lastName, !lastName.isEmpty {
            profileData["lastName"] = lastName
        }
        if let address = address, !address.isEmpty {
            profileData["address"] = address
        }
        if let dateOfBirth = dateOfBirth {
            profileData["dateOfBirth"] = dateOfBirth
        }
        
        mockUserProfiles["mock-\(email)"] = profileData
        
        return role
    }
    
    func signOut() throws {
        currentUser = nil
    }
    
    func deleteAccount() async throws {
        if !shouldSucceed {
            throw mockError ?? NSError(domain: "MockAuth", code: 403, userInfo: [NSLocalizedDescriptionKey: "Mock account deletion failed"])
        }
        
        guard let user = currentUser else {
            throw FirebaseAuthError.userNotFound
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        mockUsers.removeValue(forKey: user.email ?? "")
        mockUserProfiles.removeValue(forKey: user.uid)
        currentUser = nil
    }
    
    func getUserRole(uid: String) async throws -> UserRole? {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let profile = mockUserProfiles[uid],
           let roleString = profile["role"] as? String,
           let role = UserRole(rawValue: roleString) {
            return role
        }
        return nil
    }
    
    func setUserRole(uid: String, role: UserRole, email: String, displayName: String?) async throws {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        mockUsers[email] = role
        mockUserProfiles[uid] = [
            "email": email,
            "role": role.rawValue,
            "displayName": displayName ?? "",
            "updatedAt": Date()
        ]
    }
    
    func bootstrapAfterOAuth(defaultRole: UserRole, displayName: String?) async throws -> UserRole {
        guard let user = currentUser else {
            throw FirebaseAuthError.userNotFound
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        if let existingRole = try await getUserRole(uid: user.uid) {
            return existingRole
        }
        
        let role: UserRole = (user.email?.lowercased() == "admin@example.com") ? .admin : defaultRole
        try await setUserRole(uid: user.uid, role: role, email: user.email ?? "", displayName: displayName)
        return role
    }
    
    func changeAdminPassword(current: String, new: String) async throws {
        if !shouldSucceed {
            throw mockError ?? NSError(domain: "MockAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Mock password change failed"])
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Mock password validation
        if current.isEmpty {
            throw FirebaseAuthError.invalidPassword
        }
        if new.count < 6 {
            throw FirebaseAuthError.weakPassword
        }
    }
}
