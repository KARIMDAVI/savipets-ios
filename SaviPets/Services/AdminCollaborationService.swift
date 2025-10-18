import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import OSLog

// MARK: - Admin Collaboration Service

class AdminCollaborationService: ObservableObject {
    @Published var activeUsers: [ActiveUser] = []
    @Published var teamMessages: [TeamMessage] = []
    @Published var notifications: [CollaborationNotification] = []
    @Published var isOnline: Bool = false
    @Published var currentUserPresence: UserPresence = .offline
    @Published var sharedWorkspaces: [SharedWorkspace] = []
    @Published var liveActivities: [LiveActivity] = []
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "SaviPets", category: "AdminCollaboration")
    private var presenceListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var notificationsListener: ListenerRegistration?
    private var activitiesListener: ListenerRegistration?
    private var heartbeatTimer: Timer?
    
    init() {
        setupPresenceTracking()
        startHeartbeat()
        loadInitialData()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Presence Management
    
    func updatePresence(_ presence: UserPresence) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        currentUserPresence = presence
        isOnline = presence != .offline
        
        let presenceData: [String: Any] = [
            "userId": userId,
            "presence": presence.rawValue,
            "lastSeen": Timestamp(date: Date()),
            "isOnline": isOnline,
            "deviceInfo": getDeviceInfo()
        ]
        
        db.collection("admin_presence").document(userId).setData(presenceData) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to update presence: \(error.localizedDescription)")
            } else {
                self?.logger.info("Presence updated to: \(presence.rawValue)")
            }
        }
    }
    
    func setAway() {
        updatePresence(.away)
    }
    
    func setBusy() {
        updatePresence(.busy)
    }
    
    func setAvailable() {
        updatePresence(.available)
    }
    
    func goOffline() {
        updatePresence(.offline)
        cleanup()
    }
    
    // MARK: - Team Messaging
    
    func sendTeamMessage(_ content: String, type: MessageType = .text, priority: MessagePriority = .normal) {
        guard let userId = Auth.auth().currentUser?.uid,
              let userEmail = Auth.auth().currentUser?.email else { return }
        
        let message = TeamMessage(
            id: UUID().uuidString,
            senderId: userId,
            senderName: getCurrentUserName(),
            senderEmail: userEmail,
            content: content,
            type: type,
            priority: priority,
            timestamp: Date(),
            isRead: false,
            reactions: [],
            mentions: extractMentions(from: content),
            readAt: nil
        )
        
        try? db.collection("admin_team_messages").document(message.id).setData(from: message) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send team message: \(error.localizedDescription)")
            } else {
                self?.logger.info("Team message sent successfully")
                self?.notifyTeamMembers(message)
            }
        }
    }
    
    func sendDirectMessage(to userId: String, content: String, type: MessageType = .text) {
        guard let senderId = Auth.auth().currentUser?.uid,
              let senderEmail = Auth.auth().currentUser?.email else { return }
        
        let message = DirectMessage(
            id: UUID().uuidString,
            senderId: senderId,
            senderName: getCurrentUserName(),
            senderEmail: senderEmail,
            recipientId: userId,
            content: content,
            type: type,
            timestamp: Date(),
            isRead: false
        )
        
        try? db.collection("admin_direct_messages").document(message.id).setData(from: message) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send direct message: \(error.localizedDescription)")
            } else {
                self?.logger.info("Direct message sent successfully")
            }
        }
    }
    
    func addReaction(to messageId: String, reaction: MessageReaction) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("admin_team_messages").document(messageId).updateData([
            "reactions": FieldValue.arrayUnion([[
                "userId": userId,
                "reaction": reaction.rawValue,
                "timestamp": Timestamp(date: Date())
            ]])
        ]) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to add reaction: \(error.localizedDescription)")
            }
        }
    }
    
    func markMessageAsRead(_ messageId: String) {
        db.collection("admin_team_messages").document(messageId).updateData([
            "isRead": true,
            "readAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Live Activities
    
    func startLiveActivity(_ activity: LiveActivityType, details: [String: Any] = [:]) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let liveActivity = LiveActivity(
            id: UUID().uuidString,
            userId: userId,
            userName: getCurrentUserName(),
            activityType: activity,
            details: details.mapValues { String(describing: $0) },
            startTime: Date(),
            endTime: nil,
            isActive: true
        )
        
        try? db.collection("admin_live_activities").document(liveActivity.id).setData(from: liveActivity) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to start live activity: \(error.localizedDescription)")
            } else {
                self?.logger.info("Live activity started: \(activity.rawValue)")
            }
        }
    }
    
    func endLiveActivity(_ activityId: String) {
        db.collection("admin_live_activities").document(activityId).updateData([
            "isActive": false,
            "endTime": Timestamp(date: Date())
        ]) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to end live activity: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Shared Workspaces
    
    func createSharedWorkspace(name: String, description: String, members: [String]) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let workspace = SharedWorkspace(
            id: UUID().uuidString,
            name: name,
            description: description,
            createdBy: userId,
            createdByName: getCurrentUserName(),
            members: members + [userId],
            createdAt: Date(),
            isActive: true,
            sharedData: [:],
            lastUpdated: nil,
            updatedBy: nil
        )
        
        try? db.collection("admin_shared_workspaces").document(workspace.id).setData(from: workspace) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to create shared workspace: \(error.localizedDescription)")
            } else {
                self?.logger.info("Shared workspace created: \(name)")
            }
        }
    }
    
    func updateSharedData(workspaceId: String, data: [String: Any]) {
        db.collection("admin_shared_workspaces").document(workspaceId).updateData([
            "sharedData": data,
            "lastUpdated": Timestamp(date: Date()),
            "updatedBy": Auth.auth().currentUser?.uid ?? ""
        ]) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to update shared data: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notifications
    
    func sendNotification(to userId: String, title: String, message: String, type: NotificationType, priority: NotificationPriority = .normal) {
        let notification = CollaborationNotification(
            id: UUID().uuidString,
            recipientId: userId,
            senderId: Auth.auth().currentUser?.uid ?? "",
            senderName: getCurrentUserName(),
            title: title,
            message: message,
            type: type,
            priority: priority,
            timestamp: Date(),
            isRead: false,
            actionRequired: false,
            readAt: nil
        )
        
        try? db.collection("admin_notifications").document(notification.id).setData(from: notification) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
    
    func markNotificationAsRead(_ notificationId: String) {
        db.collection("admin_notifications").document(notificationId).updateData([
            "isRead": true,
            "readAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Screen Sharing & Collaboration
    
    func requestScreenShare(from userId: String) {
        sendNotification(
            to: userId,
            title: "Screen Share Request",
            message: "\(getCurrentUserName()) wants to share their screen with you.",
            type: .screenShare,
            priority: .high
        )
    }
    
    func startCollaborativeSession(type: CollaborationType, participants: [String]) {
        let session = CollaborationSession(
            id: UUID().uuidString,
            type: type,
            initiatorId: Auth.auth().currentUser?.uid ?? "",
            participants: participants,
            startTime: Date(),
            endTime: nil,
            isActive: true,
            sharedContent: [:]
        )
        
        try? db.collection("admin_collaboration_sessions").document(session.id).setData(from: session) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to start collaboration session: \(error.localizedDescription)")
            } else {
                self?.logger.info("Collaboration session started: \(type.rawValue)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupPresenceTracking() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Listen to presence updates
        presenceListener = db.collection("admin_presence")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.activeUsers = documents.compactMap { doc in
                        try? doc.data(as: ActiveUser.self)
                    }.filter { $0.isOnline }
                }
            }
        
        // Listen to team messages
        messagesListener = db.collection("admin_team_messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.teamMessages = documents.compactMap { doc in
                        try? doc.data(as: TeamMessage.self)
                    }.sorted { $0.timestamp > $1.timestamp }
                }
            }
        
        // Listen to notifications
        notificationsListener = db.collection("admin_notifications")
            .whereField("recipientId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.notifications = documents.compactMap { doc in
                        try? doc.data(as: CollaborationNotification.self)
                    }
                }
            }
        
        // Listen to live activities
        activitiesListener = db.collection("admin_live_activities")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.liveActivities = documents.compactMap { doc in
                        try? doc.data(as: LiveActivity.self)
                    }
                }
            }
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updatePresence(self?.currentUserPresence ?? .offline)
        }
    }
    
    private func loadInitialData() {
        updatePresence(.available)
    }
    
    private func cleanup() {
        presenceListener?.remove()
        messagesListener?.remove()
        notificationsListener?.remove()
        activitiesListener?.remove()
        heartbeatTimer?.invalidate()
        
        // Set offline status
        if let userId = Auth.auth().currentUser?.uid {
            db.collection("admin_presence").document(userId).updateData([
                "isOnline": false,
                "presence": UserPresence.offline.rawValue,
                "lastSeen": Timestamp(date: Date())
            ])
        }
    }
    
    private func getCurrentUserName() -> String {
        return Auth.auth().currentUser?.displayName ?? 
               Auth.auth().currentUser?.email?.components(separatedBy: "@").first?.capitalized ?? 
               "Admin"
    }
    
    private func getDeviceInfo() -> [String: String] {
        return [
            "platform": "iOS",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "deviceModel": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion
        ]
    }
    
    private func extractMentions(from content: String) -> [String] {
        let mentionPattern = "@\\w+"
        let regex = try? NSRegularExpression(pattern: mentionPattern)
        let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content)) ?? []
        
        return matches.compactMap { match in
            if let range = Range(match.range, in: content) {
                return String(content[range]).replacingOccurrences(of: "@", with: "")
            }
            return nil
        }
    }
    
    private func notifyTeamMembers(_ message: TeamMessage) {
        // Send push notifications to mentioned users
        for mention in message.mentions {
            if let user = activeUsers.first(where: { $0.userName.lowercased() == mention.lowercased() }) {
                sendNotification(
                    to: user.userId,
                    title: "You were mentioned",
                    message: "\(message.senderName) mentioned you in a team message",
                    type: .mention,
                    priority: .high
                )
            }
        }
    }
}

// MARK: - Data Models

struct ActiveUser: Codable, Identifiable {
    let userId: String
    let userName: String
    let userEmail: String
    let presence: UserPresence
    let lastSeen: Date
    let isOnline: Bool
    let deviceInfo: [String: String]
    
    var id: String { userId }
}

enum UserPresence: String, CaseIterable, Codable {
    case online = "online"
    case available = "available"
    case away = "away"
    case busy = "busy"
    case offline = "offline"
    
    var color: Color {
        switch self {
        case .online, .available: return .green
        case .away: return .yellow
        case .busy: return .red
        case .offline: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .online, .available: return "circle.fill"
        case .away: return "moon.fill"
        case .busy: return "exclamationmark.circle.fill"
        case .offline: return "circle"
        }
    }
}

struct TeamMessage: Codable, Identifiable {
    let id: String
    let senderId: String
    let senderName: String
    let senderEmail: String
    let content: String
    let type: MessageType
    let priority: MessagePriority
    let timestamp: Date
    let isRead: Bool
    let reactions: [MessageReactionData]
    let mentions: [String]
    let readAt: Date?
    
    var readCount: Int {
        return isRead ? 1 : 0
    }
}

struct DirectMessage: Codable, Identifiable {
    let id: String
    let senderId: String
    let senderName: String
    let senderEmail: String
    let recipientId: String
    let content: String
    let type: MessageType
    let timestamp: Date
    let isRead: Bool
}

enum MessageType: String, CaseIterable, Codable {
    case text = "text"
    case image = "image"
    case file = "file"
    case system = "system"
    case announcement = "announcement"
}

enum MessagePriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

enum MessageReaction: String, CaseIterable, Codable {
    case like = "👍"
    case love = "❤️"
    case laugh = "😂"
    case wow = "😮"
    case sad = "😢"
    case angry = "😠"
    case thumbsDown = "👎"
}

struct MessageReactionData: Codable {
    let userId: String
    let reaction: MessageReaction
    let timestamp: Date
}

struct CollaborationNotification: Codable, Identifiable {
    let id: String
    let recipientId: String
    let senderId: String
    let senderName: String
    let title: String
    let message: String
    let type: NotificationType
    let priority: NotificationPriority
    let timestamp: Date
    let isRead: Bool
    let actionRequired: Bool
    let readAt: Date?
}

enum NotificationType: String, CaseIterable, Codable {
    case message = "message"
    case mention = "mention"
    case system = "system"
    case collaboration = "collaboration"
    case screenShare = "screen_share"
    case workspace = "workspace"
    case alert = "alert"
}

enum NotificationPriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct LiveActivity: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let activityType: LiveActivityType
    let details: [String: String]
    let startTime: Date
    let endTime: Date?
    let isActive: Bool
}

enum LiveActivityType: String, CaseIterable, Codable {
    case viewingDashboard = "viewing_dashboard"
    case editingData = "editing_data"
    case managingUsers = "managing_users"
    case analyzingReports = "analyzing_reports"
    case collaborating = "collaborating"
    case screenSharing = "screen_sharing"
    
    var icon: String {
        switch self {
        case .viewingDashboard: return "chart.bar.fill"
        case .editingData: return "pencil.circle.fill"
        case .managingUsers: return "person.2.fill"
        case .analyzingReports: return "doc.text.fill"
        case .collaborating: return "person.2.circle.fill"
        case .screenSharing: return "rectangle.and.pencil.and.ellipsis"
        }
    }
    
    var description: String {
        switch self {
        case .viewingDashboard: return "Viewing Dashboard"
        case .editingData: return "Editing Data"
        case .managingUsers: return "Managing Users"
        case .analyzingReports: return "Analyzing Reports"
        case .collaborating: return "Collaborating"
        case .screenSharing: return "Screen Sharing"
        }
    }
}

struct SharedWorkspace: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let createdBy: String
    let createdByName: String
    let members: [String]
    let createdAt: Date
    let isActive: Bool
    let sharedData: [String: String]
    let lastUpdated: Date?
    let updatedBy: String?
}

struct CollaborationSession: Codable, Identifiable {
    let id: String
    let type: CollaborationType
    let initiatorId: String
    let participants: [String]
    let startTime: Date
    let endTime: Date?
    let isActive: Bool
    let sharedContent: [String: String]
}

enum CollaborationType: String, CaseIterable, Codable {
    case screenShare = "screen_share"
    case documentEdit = "document_edit"
    case dataAnalysis = "data_analysis"
    case meeting = "meeting"
    case training = "training"
    
    var icon: String {
        switch self {
        case .screenShare: return "rectangle.and.pencil.and.ellipsis"
        case .documentEdit: return "doc.text.fill"
        case .dataAnalysis: return "chart.bar.fill"
        case .meeting: return "video.fill"
        case .training: return "graduationcap.fill"
        }
    }
    
    var description: String {
        switch self {
        case .screenShare: return "Screen Sharing"
        case .documentEdit: return "Document Editing"
        case .dataAnalysis: return "Data Analysis"
        case .meeting: return "Meeting"
        case .training: return "Training Session"
        }
    }
}
