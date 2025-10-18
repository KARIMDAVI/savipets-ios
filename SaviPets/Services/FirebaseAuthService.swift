import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import OSLog

enum FirebaseAuthError: LocalizedError {
    case userNotFound
    case invalidPassword
    case userAlreadyExists
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case requiresRecentLogin
    case reauthenticationFailed
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound: return "No account found for this email."
        case .invalidPassword: return "Incorrect password."
        case .userAlreadyExists: return "An account with this email already exists."
        case .emailAlreadyInUse: return "This email is already registered."
        case .weakPassword: return "Password should be at least 6 characters."
        case .networkError: return "Network error. Please check your connection."
        case .requiresRecentLogin: return "For security, please sign in again to delete your account."
        case .reauthenticationFailed: return "Password is incorrect. Please try again."
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
    
    /// Get the sign-in provider for current user
    func getCurrentSignInProvider() -> SignInProvider {
        guard let user = Auth.auth().currentUser else {
            return .email
        }
        
        for providerData in user.providerData {
            switch providerData.providerID {
            case "google.com":
                return .google
            case "apple.com":
                return .apple
            case "password":
                return .email
            default:
                continue
            }
        }
        
        return .email
    }
    
    /// Re-authenticate user with password before sensitive operations
    func reauthenticate(password: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.userNotFound
        }
        guard let email = user.email else {
            throw FirebaseAuthError.unknown("Current user has no email.")
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        
        do {
            try await user.reauthenticate(with: credential)
            AppLogger.auth.info("User re-authenticated successfully")
        } catch let error as NSError {
            AppLogger.auth.error("Re-authentication failed: \(error.localizedDescription)")
            if error.code == AuthErrorCode.wrongPassword.rawValue {
                throw FirebaseAuthError.reauthenticationFailed
            }
            throw mapAuthError(error)
        }
    }
    
    /// Re-authenticate with OAuth provider (Google/Apple)
    func reauthenticateWithOAuth(provider: SignInProvider) async throws {
        guard Auth.auth().currentUser != nil else {  // Swift 6: unused value fix
            throw FirebaseAuthError.userNotFound
        }
        
        AppLogger.auth.info("Triggering OAuth re-authentication for provider: \(provider.rawValue)")
        
        // This will trigger the OAuth flow
        // The actual implementation needs OAuthService integration
        // For now, we'll throw a helpful error if OAuth is needed
        throw FirebaseAuthError.unknown("Please use the OAuth button to re-authenticate with \(provider.displayName).")
    }
    
    /// Schedule account deletion with 30-day grace period
    func scheduleAccountDeletion(password: String?, sendConfirmationEmail: Bool = true) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.userNotFound
        }
        let uid = user.uid
        let email = user.email ?? ""
        
        AppLogger.auth.info("Scheduling account deletion for user: \(uid)")
        
        // Step 1: Re-authenticate based on sign-in provider
        let provider = getCurrentSignInProvider()
        
        if provider == .email {
            guard let pwd = password else {
                throw FirebaseAuthError.unknown("Password required for email users")
            }
            try await reauthenticate(password: pwd)
        } else {
            // OAuth users: Trust recent sign-in (Firebase handles this internally)
            AppLogger.auth.info("OAuth user - skipping password re-auth")
        }
        
        // Step 2: Mark account for deletion in 30 days
        let deletionDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        
        try await db.collection("users").document(uid).updateData([
            "accountStatus": "pendingDeletion",
            "deletionScheduledAt": Timestamp(date: Date()),
            "deletionDate": Timestamp(date: deletionDate),
            "deletionRequestedBy": email
        ])
        
        // Step 3: Add deletion record for audit trail
        let deletionRecord: [String: Any] = [
            "userId": uid,
            "email": email,
            "requestedAt": FieldValue.serverTimestamp(),
            "scheduledFor": Timestamp(date: deletionDate),
            "status": "scheduled",
            "provider": provider.rawValue
        ]
        
        try await db.collection("accountDeletions").addDocument(data: deletionRecord)
        
        AppLogger.auth.info("Account deletion scheduled for: \(deletionDate)")
        
        // Step 4: Send confirmation email (if enabled)
        if sendConfirmationEmail && !email.isEmpty {
            try await sendDeletionConfirmationEmail(email: email, deletionDate: deletionDate)
        }
    }
    
    /// Cancel scheduled account deletion (restore account)
    func cancelAccountDeletion() async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.userNotFound
        }
        let uid = user.uid
        
        AppLogger.auth.info("Canceling account deletion for user: \(uid)")
        
        try await db.collection("users").document(uid).updateData([
            "accountStatus": "active",
            "deletionScheduledAt": FieldValue.delete(),
            "deletionDate": FieldValue.delete(),
            "deletionCanceledAt": FieldValue.serverTimestamp()
        ])
        
        // Update deletion record
        let snapshot = try await db.collection("accountDeletions")
            .whereField("userId", isEqualTo: uid)
            .whereField("status", isEqualTo: "scheduled")
            .getDocuments()
        
        for doc in snapshot.documents {
            try await doc.reference.updateData([
                "status": "canceled",
                "canceledAt": FieldValue.serverTimestamp()
            ])
        }
        
        AppLogger.auth.info("Account deletion canceled successfully")
    }
    
    /// Complete account deletion with re-authentication and Firestore cleanup (immediate)
    func deleteAccountWithReauth(password: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.userNotFound
        }
        let uid = user.uid
        
        AppLogger.auth.info("Starting IMMEDIATE account deletion for user: \(uid)")
        
        // Step 1: Re-authenticate (Firebase security requirement)
        try await reauthenticate(password: password)
        
        // Step 2: Delete all Firestore data (GDPR compliance)
        try await deleteUserData(uid: uid)
        
        // Step 3: Delete Firebase Auth user (must be last)
        do {
            try await user.delete()
            AppLogger.auth.info("User account deleted successfully: \(uid)")
        } catch let error as NSError {
            AppLogger.auth.error("Failed to delete auth user: \(error.localizedDescription)")
            throw mapAuthError(error)
        }
    }
    
    /// Execute permanent deletion (called by Cloud Function after grace period)
    func executeScheduledDeletion(uid: String) async throws {
        AppLogger.auth.info("Executing scheduled deletion for user: \(uid)")
        
        // Delete all Firestore data
        try await deleteUserData(uid: uid)
        
        // Note: Auth user deletion must be done via Admin SDK in Cloud Function
        // This method only handles Firestore cleanup
        
        AppLogger.auth.info("Scheduled deletion executed for: \(uid)")
    }
    
    /// Legacy method - now requires recent login
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.userNotFound
        }
        
        do {
            try await user.delete()
        } catch let error as NSError {
            // Requires recent login; bubble meaningful error
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw FirebaseAuthError.requiresRecentLogin
            }
            throw mapAuthError(error)
        }
    }
    
    // MARK: - Email Notifications
    
    /// Send deletion confirmation email
    private func sendDeletionConfirmationEmail(email: String, deletionDate: Date) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        
        let deletionDateString = dateFormatter.string(from: deletionDate)
        
        // Create email document in Firestore for Cloud Function to send
        let emailData: [String: Any] = [
            "to": email,
            "template": [
                "name": "accountDeletionScheduled",
                "data": [
                    "deletionDate": deletionDateString,
                    "gracePeriodDays": 30
                ]
            ],
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("mail").addDocument(data: emailData)
        AppLogger.auth.info("Deletion confirmation email queued for: \(email)")
    }
    
    // MARK: - Firestore Data Cleanup
    
    /// Delete all user data from Firestore (GDPR Right to be Forgotten)
    private func deleteUserData(uid: String) async throws {
        AppLogger.data.info("Deleting Firestore data for user: \(uid)")
        
        // Note: Batch deletes have a 500 document limit
        // For production apps with many documents, consider Cloud Functions
        
        do {
            // 1. Delete user profile
            try await db.collection("users").document(uid).delete()
            AppLogger.data.info("Deleted user profile")
            
            // 2. Delete public profile
            try await db.collection("publicProfiles").document(uid).delete()
            AppLogger.data.info("Deleted public profile")
            
            // 3. Delete pets (subcollection under artifacts)
            let petsPath = "artifacts/\(AppConstants.Firebase.appId)/users/\(uid)/pets"
            let petsSnapshot = try await db.collection(petsPath).getDocuments()
            for petDoc in petsSnapshot.documents {
                try await petDoc.reference.delete()
            }
            AppLogger.data.info("Deleted \(petsSnapshot.documents.count) pet profiles")
            
            // 4. Delete staff profile (if exists)
            let staffPath = "artifacts/\(AppConstants.Firebase.appId)/users/\(uid)/staff/\(uid)"
            try await db.document(staffPath).delete()
            AppLogger.data.info("Deleted staff profile (if existed)")
            
            // 5. Delete location data
            try await db.collection("locations").document(uid).delete()
            AppLogger.data.info("Deleted location data")
            
            // 6. Cancel user's bookings (don't delete - sitters need history)
            let bookingsSnapshot = try await db.collection("serviceBookings")
                .whereField("clientId", isEqualTo: uid)
                .whereField("status", in: ["pending", "approved"])
                .getDocuments()
            
            for bookingDoc in bookingsSnapshot.documents {
                try await bookingDoc.reference.updateData([
                    "status": "canceled",
                    "canceledAt": FieldValue.serverTimestamp(),
                    "canceledReason": "Account deleted"
                ])
            }
            AppLogger.data.info("Canceled \(bookingsSnapshot.documents.count) pending bookings")
            
            // 7. Mark user as deleted in conversations (don't delete - other users need history)
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("participants", arrayContains: uid)
                .getDocuments()
            
            for convoDoc in conversationsSnapshot.documents {
                // Add a system message indicating user left
                let messageData: [String: Any] = [
                    "senderId": "system",
                    "text": "User has left SaviPets",
                    "timestamp": FieldValue.serverTimestamp(),
                    "read": true,
                    "status": "sent",
                    "moderationType": "none",
                    "deliveryStatus": "delivered",
                    "isAutoResponse": false
                ]
                try await convoDoc.reference.collection("messages").addDocument(data: messageData)
            }
            AppLogger.data.info("Updated \(conversationsSnapshot.documents.count) conversations")
            
            AppLogger.data.info("Firestore data cleanup complete for user: \(uid)")
            
        } catch {
            AppLogger.data.error("Error deleting user data: \(error.localizedDescription)")
            throw error
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

