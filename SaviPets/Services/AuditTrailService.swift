import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog
import Combine
import SwiftUI

/// Service for comprehensive audit logging and security monitoring
@MainActor
final class AuditTrailService: ObservableObject {
    @Published var auditLogs: [AuditLogEntry] = []
    @Published var securityEvents: [SecurityEvent] = []
    @Published var isMonitoring: Bool = false
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let auditCollection = "auditLogs"
    private let securityCollection = "securityEvents"
    
    // Real-time listeners
    private var auditListener: ListenerRegistration?
    private var securityListener: ListenerRegistration?
    
    // Security monitoring
    private var failedLoginAttempts: [String: [Date]] = [:]
    
    init() {
        setupRealTimeListeners()
        startSecurityMonitoring()
    }
    
    deinit {
        auditListener?.remove()
        securityListener?.remove()
    }
    
    // MARK: - Real-time Listeners
    private func setupRealTimeListeners() {
        // Audit logs listener
        auditListener = db.collection(auditCollection)
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.data.error("Audit listener error: \(error.localizedDescription)")
                    return
                }
                
                Task { @MainActor in
                    self.auditLogs = snapshot?.documents.compactMap { doc in
                        self.parseAuditLogFromDocument(doc)
                    } ?? []
                }
            }
        
        // Security events listener
        securityListener = db.collection(securityCollection)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.data.error("Security listener error: \(error.localizedDescription)")
                    return
                }
                
                Task { @MainActor in
                    self.securityEvents = snapshot?.documents.compactMap { doc in
                        self.parseSecurityEventFromDocument(doc)
                    } ?? []
                }
            }
    }
    
    // MARK: - Audit Logging
    func logEvent(
        action: AuditAction,
        userId: String?,
        resourceType: ResourceType,
        resourceId: String,
        details: [String: Any] = [:],
        severity: AuditSeverity = .info,
        ipAddress: String? = nil,
        userAgent: String? = nil
    ) async {
        
        let auditEntry = AuditLogEntry(
            id: UUID().uuidString,
            action: action,
            userId: userId,
            resourceType: resourceType,
            resourceId: resourceId,
            details: details,
            severity: severity,
            timestamp: Date(),
            ipAddress: ipAddress,
            userAgent: userAgent,
            sessionId: await getCurrentSessionId()
        )
        
        do {
            try await db.collection(auditCollection).document(auditEntry.id).setData(auditEntry.toFirestoreData())
            
            AppLogger.data.info("Audit logged: \(action.rawValue) on \(resourceType.rawValue)")
            
            // Check for suspicious patterns
            await analyzeForSuspiciousActivity(auditEntry)
            
        } catch {
            AppLogger.data.error("Failed to log audit event: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Security Event Logging
    func logSecurityEvent(
        eventType: SecurityEventType,
        userId: String?,
        details: [String: Any] = [:],
        severity: SecuritySeverity = .medium,
        ipAddress: String? = nil,
        userAgent: String? = nil
    ) async {
        
        let securityEvent = SecurityEvent(
            id: UUID().uuidString,
            eventType: eventType,
            userId: userId,
            details: details,
            severity: severity,
            timestamp: Date(),
            ipAddress: ipAddress,
            userAgent: userAgent,
            sessionId: await getCurrentSessionId(),
            isResolved: false,
            resolutionNotes: nil,
            resolvedAt: nil,
            resolvedBy: nil
        )
        
        do {
            try await db.collection(securityCollection).document(securityEvent.id).setData(securityEvent.toFirestoreData())
            
            AppLogger.data.warning("Security event logged: \(eventType.rawValue)")
            
        } catch {
            AppLogger.data.error("Failed to log security event: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Authentication Audit
    func logAuthenticationEvent(
        action: AuthenticationAction,
        userId: String?,
        success: Bool,
        details: [String: Any] = [:],
        ipAddress: String? = nil,
        userAgent: String? = nil
    ) async {
        
        let severity: AuditSeverity = success ? .info : .warning
        var eventDetails = details
        eventDetails["success"] = success
        eventDetails["authenticationAction"] = action.rawValue
        
        await logEvent(
            action: success ? .login : .loginFailed,
            userId: userId,
            resourceType: .user,
            resourceId: userId ?? "anonymous",
            details: eventDetails,
            severity: severity,
            ipAddress: ipAddress,
            userAgent: userAgent
        )
        
        // Track failed login attempts
        if !success, let userId = userId {
            await trackFailedLoginAttempt(userId: userId, ipAddress: ipAddress)
        }
    }
    
    // MARK: - Data Access Audit
    func logDataAccess(
        userId: String,
        resourceType: ResourceType,
        resourceId: String,
        operation: DataOperation,
        details: [String: Any] = [:],
        ipAddress: String? = nil
    ) async {
        
        var eventDetails = details
        eventDetails["operation"] = operation.rawValue
        eventDetails["resourceType"] = resourceType.rawValue
        
        await logEvent(
            action: .dataAccess,
            userId: userId,
            resourceType: resourceType,
            resourceId: resourceId,
            details: eventDetails,
            severity: .info,
            ipAddress: ipAddress
        )
    }
    
    // MARK: - Data Modification Audit
    func logDataModification(
        userId: String,
        resourceType: ResourceType,
        resourceId: String,
        operation: DataOperation,
        oldData: [String: Any]? = nil,
        newData: [String: Any]? = nil,
        details: [String: Any] = [:],
        ipAddress: String? = nil
    ) async {
        
        var eventDetails = details
        eventDetails["operation"] = operation.rawValue
        
        if let oldData = oldData {
            eventDetails["oldData"] = oldData
        }
        
        if let newData = newData {
            eventDetails["newData"] = newData
        }
        
        // Determine severity based on operation
        let severity: AuditSeverity = operation == .delete ? .warning : .info
        
        await logEvent(
            action: .dataModified,
            userId: userId,
            resourceType: resourceType,
            resourceId: resourceId,
            details: eventDetails,
            severity: severity,
            ipAddress: ipAddress
        )
    }
    
    // MARK: - Permission Audit
    func logPermissionChange(
        userId: String,
        targetUserId: String,
        permission: String,
        granted: Bool,
        details: [String: Any] = [:],
        ipAddress: String? = nil
    ) async {
        
        var eventDetails = details
        eventDetails["permission"] = permission
        eventDetails["granted"] = granted
        eventDetails["targetUserId"] = targetUserId
        
        await logEvent(
            action: granted ? .permissionGranted : .permissionRevoked,
            userId: userId,
            resourceType: .user,
            resourceId: targetUserId,
            details: eventDetails,
            severity: .warning,
            ipAddress: ipAddress
        )
    }
    
    // MARK: - Security Monitoring
    private func startSecurityMonitoring() {
        isMonitoring = true
        
        // Monitor for patterns every 5 minutes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.analyzeSecurityPatterns()
                }
            }
            .store(in: &cancellables)
    }
    
    private func trackFailedLoginAttempt(userId: String, ipAddress: String?) async {
        let now = Date()
        let key = ipAddress ?? userId
        
        if failedLoginAttempts[key] == nil {
            failedLoginAttempts[key] = []
        }
        
        failedLoginAttempts[key]?.append(now)
        
        // Clean up old attempts (older than 1 hour)
        failedLoginAttempts[key] = failedLoginAttempts[key]?.filter { attempt in
            now.timeIntervalSince(attempt) < 3600
        }
        
        // Check for brute force attempts
        if let attempts = failedLoginAttempts[key], attempts.count >= 5 {
            await logSecurityEvent(
                eventType: .bruteForceAttempt,
                userId: userId,
                details: [
                    "attemptCount": attempts.count,
                    "timeWindow": "1 hour",
                    "ipAddress": ipAddress ?? "unknown"
                ],
                severity: .high,
                ipAddress: ipAddress
            )
        }
    }
    
    private func analyzeForSuspiciousActivity(_ auditEntry: AuditLogEntry) async {
        guard let userId = auditEntry.userId else { return }
        
        // Check for rapid successive actions
        let recentEntries = auditLogs.filter { entry in
            entry.userId == userId &&
            entry.timestamp > Date().addingTimeInterval(-300) // Last 5 minutes
        }
        
        if recentEntries.count > 20 {
            await logSecurityEvent(
                eventType: .suspiciousActivity,
                userId: userId,
                details: [
                    "activity": "rapid_successive_actions",
                    "actionCount": recentEntries.count,
                    "timeWindow": "5 minutes"
                ],
                severity: .medium
            )
        }
        
        // Check for unusual access patterns
        if auditEntry.resourceType == .user && auditEntry.action == .dataAccess {
            await checkForUnusualAccess(userId: userId, resourceId: auditEntry.resourceId)
        }
    }
    
    private func checkForUnusualAccess(userId: String, resourceId: String) async {
        let recentAccess = auditLogs.filter { entry in
            entry.userId == userId &&
            entry.resourceType == .user &&
            entry.resourceId == resourceId &&
            entry.timestamp > Date().addingTimeInterval(-3600) // Last hour
        }
        
        if recentAccess.count > 10 {
            await logSecurityEvent(
                eventType: .unusualAccessPattern,
                userId: userId,
                details: [
                    "resourceId": resourceId,
                    "accessCount": recentAccess.count,
                    "timeWindow": "1 hour"
                ],
                severity: .medium
            )
        }
    }
    
    private func analyzeSecurityPatterns() async {
        // Analyze failed login patterns
        for (key, attempts) in failedLoginAttempts {
            if attempts.count >= 3 {
                let recentAttempts = attempts.filter { attempt in
                    Date().timeIntervalSince(attempt) < 900 // Last 15 minutes
                }
                
                if recentAttempts.count >= 3 {
                    await logSecurityEvent(
                        eventType: .multipleFailedLogins,
                        userId: nil,
                        details: [
                            "identifier": key,
                            "attemptCount": recentAttempts.count,
                            "timeWindow": "15 minutes"
                        ],
                        severity: .medium
                    )
                }
            }
        }
        
        // Analyze suspicious activities
        await analyzeUnusualBehavior()
    }
    
    private func analyzeUnusualBehavior() async {
        let recentLogs = auditLogs.filter { log in
            log.timestamp > Date().addingTimeInterval(-3600) // Last hour
        }
        
        // Group by user and analyze patterns
        let userActivities = Dictionary(grouping: recentLogs) { $0.userId ?? "anonymous" }
        
        for (userId, activities) in userActivities {
            if userId == "anonymous" { continue }
            
            // Check for admin actions from non-admin users
            let adminActions = activities.filter { activity in
                activity.action == .permissionGranted || activity.action == .permissionRevoked
            }
            
            if !adminActions.isEmpty {
                await logSecurityEvent(
                    eventType: .unauthorizedAdminAction,
                    userId: userId,
                    details: [
                        "actionCount": adminActions.count,
                        "actions": adminActions.map { $0.action.rawValue }
                    ],
                    severity: .high
                )
            }
            
            // Check for bulk operations
            let bulkOperations = activities.filter { activity in
                activity.action == .dataModified && 
                (activity.details["operation"] as? String) == "bulk_update"
            }
            
            if bulkOperations.count > 5 {
                await logSecurityEvent(
                    eventType: .bulkOperation,
                    userId: userId,
                    details: [
                        "operationCount": bulkOperations.count,
                        "timeWindow": "1 hour"
                    ],
                    severity: .medium
                )
            }
        }
    }
    
    // MARK: - Security Event Resolution
    func resolveSecurityEvent(
        eventId: String,
        resolvedBy: String,
        resolutionNotes: String
    ) async -> Result<Void, AuditError> {
        
        do {
            try await db.collection(securityCollection).document(eventId).updateData([
                "isResolved": true,
                "resolutionNotes": resolutionNotes,
                "resolvedAt": FieldValue.serverTimestamp(),
                "resolvedBy": resolvedBy
            ])
            
            AppLogger.data.info("Resolved security event \(eventId)")
            return .success(())
            
        } catch {
            AppLogger.data.error("Failed to resolve security event: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    // MARK: - Audit Report Generation
    func generateAuditReport(
        startDate: Date,
        endDate: Date,
        userId: String? = nil,
        resourceType: ResourceType? = nil,
        severity: AuditSeverity? = nil
    ) async -> Result<AuditReport, AuditError> {
        
        do {
            var query = db.collection(auditCollection)
                .whereField("timestamp", isGreaterThanOrEqualTo: startDate)
                .whereField("timestamp", isLessThan: endDate)
            
            if let userId = userId {
                query = query.whereField("userId", isEqualTo: userId)
            }
            
            if let resourceType = resourceType {
                query = query.whereField("resourceType", isEqualTo: resourceType.rawValue)
            }
            
            if let severity = severity {
                query = query.whereField("severity", isEqualTo: severity.rawValue)
            }
            
            let snapshot = try await query.getDocuments()
            let logs = snapshot.documents.compactMap { parseAuditLogFromDocument($0) }
            
            // Group events by user
            var eventsByUser: [String: [AuditLogEntry]] = [:]
            for log in logs {
                if let userId = log.userId {
                    if eventsByUser[userId] == nil {
                        eventsByUser[userId] = []
                    }
                    eventsByUser[userId]?.append(log)
                }
            }
            
            let report = AuditReport(
                id: UUID().uuidString,
                startDate: startDate,
                endDate: endDate,
                totalEvents: logs.count,
                eventsByAction: Dictionary(grouping: logs, by: { $0.action }),
                eventsBySeverity: Dictionary(grouping: logs, by: { $0.severity }),
                eventsByUser: eventsByUser,
                eventsByResource: Dictionary(grouping: logs, by: { $0.resourceType }),
                generatedAt: Date(),
                generatedBy: Auth.auth().currentUser?.uid
            )
            
            return .success(report)
            
        } catch {
            AppLogger.data.error("Failed to generate audit report: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentSessionId() async -> String {
        // In a real implementation, you would track session IDs
        return "session_\(UUID().uuidString.prefix(8))"
    }
    
    private func parseAuditLogFromDocument(_ document: QueryDocumentSnapshot) -> AuditLogEntry? {
        let data = document.data()
        
        guard let actionString = data["action"] as? String,
              let action = AuditAction(rawValue: actionString),
              let resourceTypeString = data["resourceType"] as? String,
              let resourceType = ResourceType(rawValue: resourceTypeString),
              let resourceId = data["resourceId"] as? String,
              let severityString = data["severity"] as? String,
              let severity = AuditSeverity(rawValue: severityString),
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        return AuditLogEntry(
            id: document.documentID,
            action: action,
            userId: data["userId"] as? String,
            resourceType: resourceType,
            resourceId: resourceId,
            details: data["details"] as? [String: Any] ?? [:],
            severity: severity,
            timestamp: timestamp,
            ipAddress: data["ipAddress"] as? String,
            userAgent: data["userAgent"] as? String,
            sessionId: data["sessionId"] as? String
        )
    }
    
    private func parseSecurityEventFromDocument(_ document: QueryDocumentSnapshot) -> SecurityEvent? {
        let data = document.data()
        
        guard let eventTypeString = data["eventType"] as? String,
              let eventType = SecurityEventType(rawValue: eventTypeString),
              let severityString = data["severity"] as? String,
              let severity = SecuritySeverity(rawValue: severityString),
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        return SecurityEvent(
            id: document.documentID,
            eventType: eventType,
            userId: data["userId"] as? String,
            details: data["details"] as? [String: Any] ?? [:],
            severity: severity,
            timestamp: timestamp,
            ipAddress: data["ipAddress"] as? String,
            userAgent: data["userAgent"] as? String,
            sessionId: data["sessionId"] as? String,
            isResolved: data["isResolved"] as? Bool ?? false,
            resolutionNotes: data["resolutionNotes"] as? String,
            resolvedAt: (data["resolvedAt"] as? Timestamp)?.dateValue(),
            resolvedBy: data["resolvedBy"] as? String
        )
    }
}

// MARK: - Supporting Models
struct AuditLogEntry: Identifiable {
    let id: String
    let action: AuditAction
    let userId: String?
    let resourceType: ResourceType
    let resourceId: String
    let details: [String: Any]
    let severity: AuditSeverity
    let timestamp: Date
    let ipAddress: String?
    let userAgent: String?
    let sessionId: String?
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "action": action.rawValue,
            "resourceType": resourceType.rawValue,
            "resourceId": resourceId,
            "details": details,
            "severity": severity.rawValue,
            "timestamp": Timestamp(date: timestamp),
            "sessionId": sessionId ?? ""
        ]
        
        if let userId = userId {
            data["userId"] = userId
        }
        
        if let ipAddress = ipAddress {
            data["ipAddress"] = ipAddress
        }
        
        if let userAgent = userAgent {
            data["userAgent"] = userAgent
        }
        
        return data
    }
}

struct SecurityEvent: Identifiable {
    let id: String
    let eventType: SecurityEventType
    let userId: String?
    let details: [String: Any]
    let severity: SecuritySeverity
    let timestamp: Date
    let ipAddress: String?
    let userAgent: String?
    let sessionId: String?
    var isResolved: Bool
    let resolutionNotes: String?
    let resolvedAt: Date?
    let resolvedBy: String?
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "eventType": eventType.rawValue,
            "details": details,
            "severity": severity.rawValue,
            "timestamp": Timestamp(date: timestamp),
            "sessionId": sessionId ?? "",
            "isResolved": isResolved
        ]
        
        if let userId = userId {
            data["userId"] = userId
        }
        
        if let ipAddress = ipAddress {
            data["ipAddress"] = ipAddress
        }
        
        if let userAgent = userAgent {
            data["userAgent"] = userAgent
        }
        
        if let resolutionNotes = resolutionNotes {
            data["resolutionNotes"] = resolutionNotes
        }
        
        if let resolvedAt = resolvedAt {
            data["resolvedAt"] = Timestamp(date: resolvedAt)
        }
        
        if let resolvedBy = resolvedBy {
            data["resolvedBy"] = resolvedBy
        }
        
        return data
    }
}

struct AuditReport {
    let id: String
    let startDate: Date
    let endDate: Date
    let totalEvents: Int
    let eventsByAction: [AuditAction: [AuditLogEntry]]
    let eventsBySeverity: [AuditSeverity: [AuditLogEntry]]
    let eventsByUser: [String: [AuditLogEntry]]
    let eventsByResource: [ResourceType: [AuditLogEntry]]
    let generatedAt: Date
    let generatedBy: String?
}

// MARK: - Enums
enum AuditAction: String, Codable, CaseIterable {
    case login = "login"
    case loginFailed = "login_failed"
    case logout = "logout"
    case dataAccess = "data_access"
    case dataModified = "data_modified"
    case dataDeleted = "data_deleted"
    case permissionGranted = "permission_granted"
    case permissionRevoked = "permission_revoked"
    case passwordChanged = "password_changed"
    case accountCreated = "account_created"
    case accountDeleted = "account_deleted"
    case profileUpdated = "profile_updated"
    case bookingCreated = "booking_created"
    case bookingModified = "booking_modified"
    case bookingCancelled = "booking_cancelled"
    case paymentProcessed = "payment_processed"
    case feedbackSubmitted = "feedback_submitted"
    
    var displayName: String {
        switch self {
        case .login: return "Login"
        case .loginFailed: return "Login Failed"
        case .logout: return "Logout"
        case .dataAccess: return "Data Access"
        case .dataModified: return "Data Modified"
        case .dataDeleted: return "Data Deleted"
        case .permissionGranted: return "Permission Granted"
        case .permissionRevoked: return "Permission Revoked"
        case .passwordChanged: return "Password Changed"
        case .accountCreated: return "Account Created"
        case .accountDeleted: return "Account Deleted"
        case .profileUpdated: return "Profile Updated"
        case .bookingCreated: return "Booking Created"
        case .bookingModified: return "Booking Modified"
        case .bookingCancelled: return "Booking Cancelled"
        case .paymentProcessed: return "Payment Processed"
        case .feedbackSubmitted: return "Feedback Submitted"
        }
    }
}

enum AuthenticationAction: String, Codable {
    case signIn = "sign_in"
    case signOut = "sign_out"
    case passwordReset = "password_reset"
    case accountVerification = "account_verification"
    case twoFactorAuth = "two_factor_auth"
}

enum ResourceType: String, Codable, CaseIterable {
    case user = "user"
    case booking = "booking"
    case pet = "pet"
    case sitter = "sitter"
    case payment = "payment"
    case feedback = "feedback"
    case conversation = "conversation"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .user: return "User"
        case .booking: return "Booking"
        case .pet: return "Pet"
        case .sitter: return "Sitter"
        case .payment: return "Payment"
        case .feedback: return "Feedback"
        case .conversation: return "Conversation"
        case .system: return "System"
        }
    }
}

enum DataOperation: String, Codable {
    case create = "create"
    case read = "read"
    case update = "update"
    case delete = "delete"
    case bulkUpdate = "bulk_update"
    case bulkDelete = "bulk_delete"
}

enum AuditSeverity: String, Codable, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}

enum SecurityEventType: String, Codable, CaseIterable {
    case bruteForceAttempt = "brute_force_attempt"
    case suspiciousActivity = "suspicious_activity"
    case unauthorizedAccess = "unauthorized_access"
    case unusualAccessPattern = "unusual_access_pattern"
    case multipleFailedLogins = "multiple_failed_logins"
    case unauthorizedAdminAction = "unauthorized_admin_action"
    case bulkOperation = "bulk_operation"
    case dataExfiltration = "data_exfiltration"
    case accountTakeover = "account_takeover"
    case privilegeEscalation = "privilege_escalation"
    
    var displayName: String {
        switch self {
        case .bruteForceAttempt: return "Brute Force Attempt"
        case .suspiciousActivity: return "Suspicious Activity"
        case .unauthorizedAccess: return "Unauthorized Access"
        case .unusualAccessPattern: return "Unusual Access Pattern"
        case .multipleFailedLogins: return "Multiple Failed Logins"
        case .unauthorizedAdminAction: return "Unauthorized Admin Action"
        case .bulkOperation: return "Bulk Operation"
        case .dataExfiltration: return "Data Exfiltration"
        case .accountTakeover: return "Account Takeover"
        case .privilegeEscalation: return "Privilege Escalation"
        }
    }
}

enum SecuritySeverity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

enum AuditError: Error, LocalizedError {
    case databaseError(String)
    case invalidData
    case unauthorizedAccess
    case reportGenerationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseError(let message):
            return "Database error: \(message)"
        case .invalidData:
            return "Invalid audit data"
        case .unauthorizedAccess:
            return "Unauthorized access to audit logs"
        case .reportGenerationFailed(let message):
            return "Report generation failed: \(message)"
        }
    }
}

