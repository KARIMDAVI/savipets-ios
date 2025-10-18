import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import LocalAuthentication
import Combine
import OSLog

// MARK: - Admin Security Service

class AdminSecurityService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: AdminUser?
    @Published var securityLevel: AdminSecurityLevel = .standard
    @Published var sessionTimeout: TimeInterval = 1800 // 30 minutes
    @Published var lastActivity: Date = Date()
    @Published var failedLoginAttempts: Int = 0
    @Published var isLockedOut: Bool = false
    @Published var adminAuditLogs: [AdminAuditLogEntry] = []
    @Published var securityAlerts: [AdminSecurityAlert] = []
    
    private var sessionTimer: Timer?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "SaviPets", category: "AdminSecurity")
    
    enum AdminSecurityLevel: String, CaseIterable, Codable {
        case basic = "Basic"
        case standard = "Standard"
        case high = "High"
        case maximum = "Maximum"
        
        var requiresMFA: Bool {
            switch self {
            case .basic: return false
            case .standard: return true
            case .high: return true
            case .maximum: return true
            }
        }
        
        var sessionTimeout: TimeInterval {
            switch self {
            case .basic: return 3600 // 1 hour
            case .standard: return 1800 // 30 minutes
            case .high: return 900 // 15 minutes
            case .maximum: return 300 // 5 minutes
            }
        }
        
        var maxFailedAttempts: Int {
            switch self {
            case .basic: return 10
            case .standard: return 5
            case .high: return 3
            case .maximum: return 2
            }
        }
    }
    
    init() {
        setupAuthListener()
        startSessionTimer()
        loadSecuritySettings()
    }
    
    deinit {
        authStateListener.map(Auth.auth().removeStateDidChangeListener)
        sessionTimer?.invalidate()
    }
    
    // MARK: - Authentication & Authorization
    
    func authenticateWithMFA(completion: @escaping (Result<Bool, AdminSecurityError>) -> Void) {
        guard securityLevel.requiresMFA else {
            completion(.success(true))
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(.failure(.biometricsNotAvailable))
            return
        }
        
        let reason = "Authenticate to access admin dashboard"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.logSecurityEvent(.mfaSuccess)
                    self?.resetFailedAttempts()
                    completion(.success(true))
                } else {
                    self?.logSecurityEvent(.mfaFailure)
                    self?.incrementFailedAttempts()
                    completion(.failure(.authenticationFailed))
                }
            }
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String, completion: @escaping (Result<Void, AdminSecurityError>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(.userNotAuthenticated))
            return
        }
        
        let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: currentPassword)
        
        user.reauthenticate(with: credential) { [weak self] _, error in
            if let error = error {
                self?.logSecurityEvent(.passwordChangeFailure)
                completion(.failure(.authenticationFailed))
                return
            }
            
            user.updatePassword(to: newPassword) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.logSecurityEvent(.passwordChangeFailure)
                        completion(.failure(.passwordUpdateFailed))
                    } else {
                        self?.logSecurityEvent(.passwordChangeSuccess)
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    func enableTwoFactorAuth(completion: @escaping (Result<Void, AdminSecurityError>) -> Void) {
        // Implementation for enabling 2FA
        logSecurityEvent(.twoFactorEnabled)
        completion(.success(()))
    }
    
    func disableTwoFactorAuth(completion: @escaping (Result<Void, AdminSecurityError>) -> Void) {
        // Implementation for disabling 2FA
        logSecurityEvent(.twoFactorDisabled)
        completion(.success(()))
    }
    
    // MARK: - Session Management
    
    func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkSessionTimeout()
        }
    }
    
    func updateActivity() {
        lastActivity = Date()
        logSecurityEvent(.activityUpdate)
    }
    
    func checkSessionTimeout() {
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivity)
        if timeSinceLastActivity > sessionTimeout {
            logSecurityEvent(.sessionTimeout)
            signOut()
        }
    }
    
    func extendSession() {
        lastActivity = Date()
        logSecurityEvent(.sessionExtended)
    }
    
    // MARK: - Access Control
    
    func hasPermission(for action: AdminAction) -> Bool {
        guard let user = currentUser else { return false }
        
        switch action {
        case .viewDashboard:
            return user.permissions.contains(.dashboard)
        case .manageUsers:
            return user.permissions.contains(.userManagement)
        case .viewAnalytics:
            return user.permissions.contains(.analytics)
        case .manageBookings:
            return user.permissions.contains(.bookingManagement)
        case .viewReports:
            return user.permissions.contains(.reporting)
        case .systemSettings:
            return user.permissions.contains(.systemSettings)
        case .securitySettings:
            return user.permissions.contains(.securitySettings)
        }
    }
    
    func checkAccessLevel(for resource: AdminResource) -> AdminAccessLevel {
        guard let user = currentUser else { return .none }
        
        switch resource {
        case .clientData:
            return user.accessLevels.clientData
        case .financialData:
            return user.accessLevels.financialData
        case .systemLogs:
            return user.accessLevels.systemLogs
        case .userAccounts:
            return user.accessLevels.userAccounts
        }
    }
    
    // MARK: - Audit & Monitoring
    
    func logSecurityEvent(_ event: AdminSecurityEvent) {
        let logEntry = AdminAuditLogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            userId: Auth.auth().currentUser?.uid ?? "unknown",
            event: event,
            details: event.description,
            severity: event.severity,
            ipAddress: getCurrentIPAddress(),
            userAgent: getUserAgent()
        )
        
        adminAuditLogs.append(logEntry)
        
        // Store in Firestore
        storeAuditLog(logEntry)
        
        // Check for security alerts
        checkSecurityAlerts(for: event)
        
        logger.info("Security event logged: \(event.rawValue)")
    }
    
    func generateSecurityReport() -> AdminSecurityReport {
        let recentLogs = adminAuditLogs.filter { $0.timestamp > Date().addingTimeInterval(-86400) } // Last 24 hours
        
        return AdminSecurityReport(
            totalEvents: recentLogs.count,
            failedLogins: recentLogs.filter { $0.event == .loginFailure }.count,
            successfulLogins: recentLogs.filter { $0.event == .loginSuccess }.count,
            securityAlerts: securityAlerts.count,
            lastActivity: lastActivity,
            sessionDuration: Date().timeIntervalSince(lastActivity),
            riskScore: calculateRiskScore()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.loadUserProfile(userId: user.uid)
                    self?.logSecurityEvent(.loginSuccess)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                    self?.logSecurityEvent(.logout)
                }
            }
        }
    }
    
    private func loadUserProfile(userId: String) {
        db.collection("admin_users").document(userId).getDocument { [weak self] document, error in
            guard let document = document, document.exists else {
                self?.createDefaultAdminProfile(userId: userId)
                return
            }
            
            DispatchQueue.main.async {
                self?.currentUser = try? document.data(as: AdminUser.self)
                self?.isAuthenticated = true
            }
        }
    }
    
    private func createDefaultAdminProfile(userId: String) {
        let defaultUser = AdminUser(
            id: userId,
            email: Auth.auth().currentUser?.email ?? "",
            displayName: Auth.auth().currentUser?.displayName ?? "Admin",
            permissions: [.dashboard, .analytics, .bookingManagement],
            accessLevels: AdminAccessLevels(
                clientData: .read,
                financialData: .read,
                systemLogs: .none,
                userAccounts: .read
            ),
            securityLevel: .standard,
            lastLogin: Date(),
            isActive: true
        )
        
        DispatchQueue.main.async {
            self.currentUser = defaultUser
            self.isAuthenticated = true
        }
        
        // Store in Firestore
        try? db.collection("admin_users").document(userId).setData(from: defaultUser)
    }
    
    private func loadSecuritySettings() {
        // Load security settings from Firestore or UserDefaults
        if let savedLevel = UserDefaults.standard.string(forKey: "admin_security_level"),
           let level = AdminSecurityLevel(rawValue: savedLevel) {
            securityLevel = level
        }
    }
    
    private func saveSecuritySettings() {
        UserDefaults.standard.set(securityLevel.rawValue, forKey: "admin_security_level")
    }
    
    private func incrementFailedAttempts() {
        failedLoginAttempts += 1
        if failedLoginAttempts >= securityLevel.maxFailedAttempts {
            isLockedOut = true
            logSecurityEvent(.accountLocked)
        }
    }
    
    private func resetFailedAttempts() {
        failedLoginAttempts = 0
        isLockedOut = false
    }
    
    private func storeAuditLog(_ logEntry: AdminAuditLogEntry) {
        try? db.collection("admin_audit_logs").document(logEntry.id).setData(from: logEntry)
    }
    
    private func checkSecurityAlerts(for event: AdminSecurityEvent) {
        switch event {
        case .loginFailure:
            if failedLoginAttempts >= 3 {
                let alert = AdminSecurityAlert(
                    id: UUID().uuidString,
                    title: "Multiple Failed Login Attempts",
                    message: "\(failedLoginAttempts) failed login attempts detected",
                    severity: .warning,
                    timestamp: Date(),
                    category: .authentication
                )
                securityAlerts.append(alert)
            }
        case .accountLocked:
            let alert = AdminSecurityAlert(
                id: UUID().uuidString,
                title: "Account Locked",
                message: "Account has been locked due to multiple failed attempts",
                severity: .critical,
                timestamp: Date(),
                category: .authentication
            )
            securityAlerts.append(alert)
        default:
            break
        }
    }
    
    private func calculateRiskScore() -> Int {
        let recentEvents = adminAuditLogs.filter { $0.timestamp > Date().addingTimeInterval(-3600) } // Last hour
        var score = 0
        
        for event in recentEvents {
            switch event.event {
            case .loginFailure:
                score += 10
            case .accountLocked:
                score += 50
            case .passwordChangeFailure:
                score += 15
            case .unauthorizedAccess:
                score += 30
            default:
                score += 1
            }
        }
        
        return min(score, 100)
    }
    
    private func getCurrentIPAddress() -> String {
        // Simplified IP detection - in production, this would be more sophisticated
        return "127.0.0.1"
    }
    
    private func getUserAgent() -> String {
        return "SaviPets Admin iOS"
    }
    
    private func signOut() {
        try? Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
        sessionTimer?.invalidate()
    }
}

// MARK: - Data Models

struct AdminUser: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let permissions: [AdminPermission]
    let accessLevels: AdminAccessLevels
    let securityLevel: AdminSecurityService.AdminSecurityLevel
    let lastLogin: Date
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    init(id: String, email: String, displayName: String, permissions: [AdminPermission], accessLevels: AdminAccessLevels, securityLevel: AdminSecurityService.AdminSecurityLevel, lastLogin: Date, isActive: Bool) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.permissions = permissions
        self.accessLevels = accessLevels
        self.securityLevel = securityLevel
        self.lastLogin = lastLogin
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum AdminPermission: String, CaseIterable, Codable {
    case dashboard = "dashboard"
    case userManagement = "user_management"
    case analytics = "analytics"
    case bookingManagement = "booking_management"
    case reporting = "reporting"
    case systemSettings = "system_settings"
    case securitySettings = "security_settings"
}

struct AdminAccessLevels: Codable {
    let clientData: AdminAccessLevel
    let financialData: AdminAccessLevel
    let systemLogs: AdminAccessLevel
    let userAccounts: AdminAccessLevel
}

enum AdminAccessLevel: String, CaseIterable, Codable {
    case none = "none"
    case read = "read"
    case write = "write"
    case admin = "admin"
}

enum AdminAction: String, CaseIterable {
    case viewDashboard = "view_dashboard"
    case manageUsers = "manage_users"
    case viewAnalytics = "view_analytics"
    case manageBookings = "manage_bookings"
    case viewReports = "view_reports"
    case systemSettings = "system_settings"
    case securitySettings = "security_settings"
}

enum AdminResource: String, CaseIterable {
    case clientData = "client_data"
    case financialData = "financial_data"
    case systemLogs = "system_logs"
    case userAccounts = "user_accounts"
}

struct AdminAuditLogEntry: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let userId: String
    let event: AdminSecurityEvent
    let details: String
    let severity: AdminSecuritySeverity
    let ipAddress: String
    let userAgent: String
}

enum AdminSecurityEvent: String, CaseIterable, Codable {
    case loginSuccess = "login_success"
    case loginFailure = "login_failure"
    case logout = "logout"
    case passwordChangeSuccess = "password_change_success"
    case passwordChangeFailure = "password_change_failure"
    case mfaSuccess = "mfa_success"
    case mfaFailure = "mfa_failure"
    case twoFactorEnabled = "two_factor_enabled"
    case twoFactorDisabled = "two_factor_disabled"
    case sessionTimeout = "session_timeout"
    case sessionExtended = "session_extended"
    case activityUpdate = "activity_update"
    case accountLocked = "account_locked"
    case unauthorizedAccess = "unauthorized_access"
    
    var description: String {
        switch self {
        case .loginSuccess: return "Successful login"
        case .loginFailure: return "Failed login attempt"
        case .logout: return "User logged out"
        case .passwordChangeSuccess: return "Password changed successfully"
        case .passwordChangeFailure: return "Password change failed"
        case .mfaSuccess: return "MFA authentication successful"
        case .mfaFailure: return "MFA authentication failed"
        case .twoFactorEnabled: return "Two-factor authentication enabled"
        case .twoFactorDisabled: return "Two-factor authentication disabled"
        case .sessionTimeout: return "Session timed out"
        case .sessionExtended: return "Session extended"
        case .activityUpdate: return "User activity updated"
        case .accountLocked: return "Account locked"
        case .unauthorizedAccess: return "Unauthorized access attempt"
        }
    }
    
    var severity: AdminSecuritySeverity {
        switch self {
        case .loginSuccess, .logout, .passwordChangeSuccess, .mfaSuccess, .twoFactorEnabled, .sessionExtended, .activityUpdate:
            return .info
        case .loginFailure, .passwordChangeFailure, .mfaFailure, .twoFactorDisabled:
            return .warning
        case .sessionTimeout, .accountLocked, .unauthorizedAccess:
            return .critical
        }
    }
}

enum AdminSecuritySeverity: String, CaseIterable, Codable {
    case info = "info"
    case warning = "warning"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct AdminSecurityAlert: Identifiable, Codable {
    let id: String
    let title: String
    let message: String
    let severity: AdminSecuritySeverity
    let timestamp: Date
    let category: AlertCategory
    
    enum AlertCategory: String, CaseIterable, Codable {
        case authentication = "authentication"
        case authorization = "authorization"
        case dataAccess = "data_access"
        case systemSecurity = "system_security"
    }
}

struct AdminSecurityReport: Codable {
    let totalEvents: Int
    let failedLogins: Int
    let successfulLogins: Int
    let securityAlerts: Int
    let lastActivity: Date
    let sessionDuration: TimeInterval
    let riskScore: Int
}

enum AdminSecurityError: Error, LocalizedError {
    case authenticationFailed
    case biometricsNotAvailable
    case userNotAuthenticated
    case passwordUpdateFailed
    case insufficientPermissions
    case accountLocked
    case sessionExpired
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device."
        case .userNotAuthenticated:
            return "User is not authenticated."
        case .passwordUpdateFailed:
            return "Failed to update password. Please try again."
        case .insufficientPermissions:
            return "You don't have permission to perform this action."
        case .accountLocked:
            return "Account is locked due to multiple failed attempts."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
        }
    }
}
