import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Type-Safe Enums

enum ConversationType: String, Codable, CaseIterable {
    case adminInquiry = "admin-inquiry"
    case clientSitter = "client-sitter"
    case sitterToClient = "sitter-to-client"
    
    var displayName: String {
        switch self {
        case .adminInquiry: return "Admin Inquiry"
        case .clientSitter: return "Client-Sitter"
        case .sitterToClient: return "Sitter to Client"
        }
    }
    
    var requiresApproval: Bool {
        switch self {
        case .sitterToClient, .clientSitter: return true
        case .adminInquiry: return false
        }
    }
}

enum ConversationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case active = "active"
    case rejected = "rejected"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Approval"
        case .active: return "Active"
        case .rejected: return "Rejected"
        case .archived: return "Archived"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .active: return .green
        case .rejected: return .red
        case .archived: return .gray
        }
    }
}

enum MessageStatus: String, Codable, CaseIterable {
    case sending = "sending"
    case sent = "sent"
    case pending = "pending"
    case rejected = "rejected"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .sending: return "Sending"
        case .sent: return "Sent"
        case .pending: return "Pending Approval"
        case .rejected: return "Rejected"
        case .failed: return "Failed"
        }
    }
    
    var isPending: Bool {
        return self == .pending
    }
    
    var isFailed: Bool {
        return self == .failed || self == .sending
    }
}

enum DeliveryStatus: String, Codable {
    case sending = "sending"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .sending: return "Sending"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }
}

enum ModerationType: String, Codable {
    case none = "none"
    case admin = "admin"
    case auto = "auto"
}

// MARK: - Message Attachment Models

enum AttachmentType: String, Codable {
    case image = "image"
    case video = "video"
    case document = "document"
    case audio = "audio"
    
    var displayName: String {
        switch self {
        case .image: return "Image"
        case .video: return "Video"
        case .document: return "Document"
        case .audio: return "Audio"
        }
    }
    
    var iconName: String {
        switch self {
        case .image: return "photo"
        case .video: return "video"
        case .document: return "doc"
        case .audio: return "waveform"
        }
    }
}

struct MessageAttachment: Codable, Identifiable {
    let id: String
    let type: AttachmentType
    let url: String
    let fileName: String
    let fileSize: Int64 // in bytes
    let mimeType: String
    let thumbnailUrl: String? // For images/videos
    let uploadedAt: Date
    let uploadedBy: String
    
    init(id: String = UUID().uuidString, type: AttachmentType, url: String, fileName: String, fileSize: Int64, mimeType: String, thumbnailUrl: String? = nil, uploadedAt: Date = Date(), uploadedBy: String) {
        self.id = id
        self.type = type
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.thumbnailUrl = thumbnailUrl
        self.uploadedAt = uploadedAt
        self.uploadedBy = uploadedBy
    }
    
    // Custom decoder for Firestore
    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String,
              let typeString = data["type"] as? String,
              let type = AttachmentType(rawValue: typeString),
              let url = data["url"] as? String,
              let fileName = data["fileName"] as? String,
              let fileSize = data["fileSize"] as? Int64,
              let mimeType = data["mimeType"] as? String,
              let uploadedBy = data["uploadedBy"] as? String else {
            return nil
        }
        
        self.id = id
        self.type = type
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.thumbnailUrl = data["thumbnailUrl"] as? String
        self.uploadedBy = uploadedBy
        
        // Handle timestamp
        if let timestamp = data["uploadedAt"] as? Timestamp {
            self.uploadedAt = timestamp.dateValue()
        } else if let date = data["uploadedAt"] as? Date {
            self.uploadedAt = date
        } else {
            self.uploadedAt = Date()
        }
    }
    
    var fileSizeFormatted: String {
        let bytes = Double(fileSize)
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", bytes / (1024 * 1024 * 1024))
        }
    }
}

enum SignInProvider: String, Codable {
    case email = "password"
    case google = "google.com"
    case apple = "apple.com"
    
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .google: return "Google"
        case .apple: return "Apple"
        }
    }
}

enum UserRole: String, Codable, CaseIterable {
    case petOwner = "petOwner"
    case petSitter = "petSitter"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .petOwner: return "Pet Owner"
        case .petSitter: return "Pet Sitter"
        case .admin: return "Admin"
        }
    }
    
    var isAdmin: Bool {
        return self == .admin
    }
    
    var isPetOwner: Bool {
        return self == .petOwner
    }
    
    var isPetSitter: Bool {
        return self == .petSitter
    }
    
    // Helper for legacy string matching
    static func from(_ string: String) -> UserRole? {
        // Try exact match first
        if let role = UserRole(rawValue: string) {
            return role
        }
        // Try display name match
        switch string {
        case "Pet Owner": return .petOwner
        case "Pet Sitter": return .petSitter
        case "Admin": return .admin
        default: return nil
        }
    }
}

// MARK: - Enhanced Data Models

struct ChatInquiry: Identifiable, Codable {
    let id: String
    let fromUserId: String
    let fromUserRole: UserRole
    let toUserId: String
    let subject: String
    let initialMessage: String
    let status: String // "pending" | "accepted"
    let createdAt: Date
    var conversationId: String?
    
    init(id: String, fromUserId: String, fromUserRole: UserRole, toUserId: String, subject: String, initialMessage: String, status: String, createdAt: Date, conversationId: String? = nil) {
        self.id = id
        self.fromUserId = fromUserId
        self.fromUserRole = fromUserRole
        self.toUserId = toUserId
        self.subject = subject
        self.initialMessage = initialMessage
        self.status = status
        self.createdAt = createdAt
        self.conversationId = conversationId
    }
    
    // Custom decoder for Firestore Timestamp
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fromUserId = try container.decode(String.self, forKey: .fromUserId)
        fromUserRole = try container.decode(UserRole.self, forKey: .fromUserRole)
        toUserId = try container.decode(String.self, forKey: .toUserId)
        subject = try container.decode(String.self, forKey: .subject)
        initialMessage = try container.decode(String.self, forKey: .initialMessage)
        status = try container.decode(String.self, forKey: .status)
        conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
        
        // Handle Firestore Timestamp
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
    }
}

struct Conversation: Identifiable, Codable {
    let id: String
    let participants: [String]
    let participantRoles: [UserRole]
    let lastMessage: String
    let lastMessageAt: Date
    let status: ConversationStatus
    let createdAt: Date
    let type: ConversationType
    let isPinned: Bool
    let pinnedName: String?
    let autoResponseHistory: [String: Date] // userId: lastSentAt
    let autoResponseCooldown: TimeInterval
    let adminReplied: Bool
    let conversationKey: String?
    
    // Unread count tracking
    let unreadCounts: [String: Int] // userId: count
    let lastReadTimestamps: [String: Date] // userId: lastReadAt
    
    init(id: String, participants: [String], participantRoles: [UserRole], lastMessage: String, lastMessageAt: Date, status: ConversationStatus, createdAt: Date, type: ConversationType, isPinned: Bool = false, pinnedName: String? = nil, autoResponseHistory: [String: Date] = [:], autoResponseCooldown: TimeInterval = 86400, adminReplied: Bool = false, conversationKey: String? = nil, unreadCounts: [String: Int] = [:], lastReadTimestamps: [String: Date] = [:]) {
        self.id = id
        self.participants = participants
        self.participantRoles = participantRoles
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.status = status
        self.createdAt = createdAt
        self.type = type
        self.isPinned = isPinned
        self.pinnedName = pinnedName
        self.autoResponseHistory = autoResponseHistory
        self.autoResponseCooldown = autoResponseCooldown
        self.adminReplied = adminReplied
        self.conversationKey = conversationKey
        self.unreadCounts = unreadCounts
        self.lastReadTimestamps = lastReadTimestamps
    }
    
    // Custom decoder for Firestore data
    init?(from document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let participants = data["participants"] as? [String],
              let participantRoleStrings = data["participantRoles"] as? [String],
              let lastMessage = data["lastMessage"] as? String,
              let statusString = data["status"] as? String,
              let typeString = data["type"] as? String,
              let type = ConversationType(rawValue: typeString) else {
            return nil
        }
        
        self.id = document.documentID
        self.participants = participants
        self.participantRoles = participantRoleStrings.compactMap { UserRole(rawValue: $0) }
        self.lastMessage = lastMessage
        self.status = ConversationStatus(rawValue: statusString) ?? .active
        self.type = type
        self.isPinned = data["isPinned"] as? Bool ?? false
        self.pinnedName = data["pinnedName"] as? String
        self.adminReplied = data["adminReplied"] as? Bool ?? false
        self.conversationKey = data["conversationKey"] as? String
        self.autoResponseCooldown = data["autoResponseCooldown"] as? TimeInterval ?? 86400
        
        // Handle timestamps
        if let timestamp = data["lastMessageAt"] as? Timestamp {
            self.lastMessageAt = timestamp.dateValue()
        } else if let date = data["lastMessageAt"] as? Date {
            self.lastMessageAt = date
        } else {
            self.lastMessageAt = Date()
        }
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else if let date = data["createdAt"] as? Date {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }
        
        // Handle auto response history
        var responseHistory: [String: Date] = [:]
        if let historyData = data["autoResponseHistory"] as? [String: Timestamp] {
            for (userId, timestamp) in historyData {
                responseHistory[userId] = timestamp.dateValue()
            }
        }
        self.autoResponseHistory = responseHistory
        
        // Handle unread counts
        self.unreadCounts = data["unreadCounts"] as? [String: Int] ?? [:]
        
        // Handle last read timestamps
        var readTimestamps: [String: Date] = [:]
        if let timestampsData = data["lastReadTimestamps"] as? [String: Timestamp] {
            for (userId, timestamp) in timestampsData {
                readTimestamps[userId] = timestamp.dateValue()
            }
        }
        self.lastReadTimestamps = readTimestamps
    }
    
    // Helper methods
    func shouldSendAutoResponse(for userId: String) -> Bool {
        guard let lastSent = autoResponseHistory[userId] else { return true }
        return Date().timeIntervalSince(lastSent) > autoResponseCooldown
    }
    
    func unreadCount(for userId: String) -> Int {
        return unreadCounts[userId] ?? 0
    }
    
    func isParticipant(_ userId: String) -> Bool {
        return participants.contains(userId)
    }
    
    func roleFor(_ userId: String) -> UserRole? {
        guard let index = participants.firstIndex(of: userId) else { return nil }
        return index < participantRoles.count ? participantRoles[index] : nil
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let senderId: String
    let text: String
    let timestamp: Date
    let read: Bool
    let status: MessageStatus
    let moderationType: ModerationType
    let moderatedBy: String?
    let moderatedAt: Date?
    let isAutoResponse: Bool
    
    // Enhanced delivery tracking
    let deliveryStatus: String  // "sent" | "delivered" | "read"
    let deliveredAt: Date?
    let readAt: Date?
    let readBy: [String: Date] // userId: readAt
    
    // Message reactions
    let reactions: [String: [String]] // emoji: [userId1, userId2]
    
    // Retry tracking for failed messages
    let retryCount: Int
    let lastRetryAt: Date?
    let failureReason: String?
    
    // Display information
    let senderName: String?
    let isFromAdmin: Bool
    
    // Attachments
    let attachments: [MessageAttachment]
    
    init(id: String, senderId: String, text: String, timestamp: Date, read: Bool = false, status: MessageStatus = .sent, moderationType: ModerationType = .none, moderatedBy: String? = nil, moderatedAt: Date? = nil, isAutoResponse: Bool = false, deliveryStatus: String = "sent", deliveredAt: Date? = nil, readAt: Date? = nil, readBy: [String: Date] = [:], reactions: [String: [String]] = [:], retryCount: Int = 0, lastRetryAt: Date? = nil, failureReason: String? = nil, senderName: String? = nil, isFromAdmin: Bool = false, attachments: [MessageAttachment] = []) {
        self.id = id
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.read = read
        self.status = status
        self.moderationType = moderationType
        self.moderatedBy = moderatedBy
        self.moderatedAt = moderatedAt
        self.isAutoResponse = isAutoResponse
        self.deliveryStatus = deliveryStatus
        self.deliveredAt = deliveredAt
        self.readAt = readAt
        self.readBy = readBy
        self.reactions = reactions
        self.retryCount = retryCount
        self.lastRetryAt = lastRetryAt
        self.failureReason = failureReason
        self.senderName = senderName
        self.isFromAdmin = isFromAdmin
        self.attachments = attachments
    }
    
    // Custom decoder for Firestore data
    init?(from document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let senderId = data["senderId"] as? String,
              let text = data["text"] as? String else {
            return nil
        }
        
        self.id = document.documentID
        self.senderId = senderId
        self.text = text
        self.read = data["read"] as? Bool ?? false
        self.isAutoResponse = data["isAutoResponse"] as? Bool ?? false
        self.moderatedBy = data["moderatedBy"] as? String
        self.retryCount = data["retryCount"] as? Int ?? 0
        self.failureReason = data["failureReason"] as? String
        
        // Handle status
        if let statusString = data["status"] as? String,
           let status = MessageStatus(rawValue: statusString) {
            self.status = status
        } else {
            self.status = .sent
        }
        
        // Handle moderation type
        if let moderationString = data["moderationType"] as? String,
           let moderationType = ModerationType(rawValue: moderationString) {
            self.moderationType = moderationType
        } else {
            self.moderationType = .none
        }
        
        // Handle delivery status (as String for compatibility)
        self.deliveryStatus = data["deliveryStatus"] as? String ?? "sent"
        
        // Handle timestamps
        if let timestamp = data["timestamp"] as? Timestamp {
            self.timestamp = timestamp.dateValue()
        } else if let date = data["timestamp"] as? Date {
            self.timestamp = date
        } else {
            self.timestamp = Date()
        }
        
        if let timestamp = data["moderatedAt"] as? Timestamp {
            self.moderatedAt = timestamp.dateValue()
        } else if let date = data["moderatedAt"] as? Date {
            self.moderatedAt = date
        } else {
            self.moderatedAt = nil
        }
        
        if let timestamp = data["deliveredAt"] as? Timestamp {
            self.deliveredAt = timestamp.dateValue()
        } else if let date = data["deliveredAt"] as? Date {
            self.deliveredAt = date
        } else {
            self.deliveredAt = nil
        }
        
        if let timestamp = data["readAt"] as? Timestamp {
            self.readAt = timestamp.dateValue()
        } else if let date = data["readAt"] as? Date {
            self.readAt = date
        } else {
            self.readAt = nil
        }
        
        if let timestamp = data["lastRetryAt"] as? Timestamp {
            self.lastRetryAt = timestamp.dateValue()
        } else if let date = data["lastRetryAt"] as? Date {
            self.lastRetryAt = date
        } else {
            self.lastRetryAt = nil
        }
        
        // Handle read by timestamps
        var readBy: [String: Date] = [:]
        if let readByData = data["readBy"] as? [String: Timestamp] {
            for (userId, timestamp) in readByData {
                readBy[userId] = timestamp.dateValue()
            }
        }
        self.readBy = readBy
        
        // Handle reactions
        self.reactions = data["reactions"] as? [String: [String]] ?? [:]
        
        // Handle display information
        self.senderName = data["senderName"] as? String
        self.isFromAdmin = data["isFromAdmin"] as? Bool ?? false
        
        // Handle attachments
        var attachments: [MessageAttachment] = []
        if let attachmentsData = data["attachments"] as? [[String: Any]] {
            attachments = attachmentsData.compactMap { MessageAttachment(from: $0) }
        }
        self.attachments = attachments
    }
    
    // Helper methods
    func hasReaction(_ emoji: String, from userId: String) -> Bool {
        return reactions[emoji]?.contains(userId) ?? false
    }
    
    func addReaction(_ emoji: String, from userId: String) -> ChatMessage {
        var newReactions = reactions
        if newReactions[emoji] == nil {
            newReactions[emoji] = []
        }
        if !newReactions[emoji]!.contains(userId) {
            newReactions[emoji]!.append(userId)
        }
        
        return ChatMessage(
            id: id,
            senderId: senderId,
            text: text,
            timestamp: timestamp,
            read: read,
            status: status,
            moderationType: moderationType,
            moderatedBy: moderatedBy,
            moderatedAt: moderatedAt,
            isAutoResponse: isAutoResponse,
            deliveryStatus: deliveryStatus,
            deliveredAt: deliveredAt,
            readAt: readAt,
            readBy: readBy,
            reactions: newReactions,
            retryCount: retryCount,
            lastRetryAt: lastRetryAt,
            failureReason: failureReason,
            senderName: senderName,
            isFromAdmin: isFromAdmin,
            attachments: attachments
        )
    }
    
    func removeReaction(_ emoji: String, from userId: String) -> ChatMessage {
        var newReactions = reactions
        newReactions[emoji]?.removeAll { $0 == userId }
        if newReactions[emoji]?.isEmpty == true {
            newReactions.removeValue(forKey: emoji)
        }
        
        return ChatMessage(
            id: id,
            senderId: senderId,
            text: text,
            timestamp: timestamp,
            read: read,
            status: status,
            moderationType: moderationType,
            moderatedBy: moderatedBy,
            moderatedAt: moderatedAt,
            isAutoResponse: isAutoResponse,
            deliveryStatus: deliveryStatus,
            deliveredAt: deliveredAt,
            readAt: readAt,
            readBy: readBy,
            reactions: newReactions,
            retryCount: retryCount,
            lastRetryAt: lastRetryAt,
            failureReason: failureReason,
            senderName: senderName,
            isFromAdmin: isFromAdmin,
            attachments: attachments
        )
    }
}

// MARK: - Message Pagination

struct MessagePage: Codable {
    let messages: [ChatMessage]
    let hasMore: Bool
    let lastDocumentId: String?
    
    init(messages: [ChatMessage], hasMore: Bool, lastDocumentId: String?) {
        self.messages = messages
        self.hasMore = hasMore
        self.lastDocumentId = lastDocumentId
    }
}

// MARK: - Notification Models

struct ChatNotification: Codable {
    let conversationId: String
    let messageId: String
    let senderName: String
    let messageText: String
    let isAdmin: Bool
    let timestamp: Date
    
    init(conversationId: String, messageId: String, senderName: String, messageText: String, isAdmin: Bool, timestamp: Date = Date()) {
        self.conversationId = conversationId
        self.messageId = messageId
        self.senderName = senderName
        self.messageText = messageText
        self.isAdmin = isAdmin
        self.timestamp = timestamp
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: Codable {
    let userId: String
    let isTyping: Bool
    let timestamp: Date
    
    init(userId: String, isTyping: Bool, timestamp: Date = Date()) {
        self.userId = userId
        self.isTyping = isTyping
        self.timestamp = timestamp
    }
}

// MARK: - Visit Status

enum VisitStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case inAdventure = "in_adventure"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .inAdventure: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isActive: Bool {
        return self == .inAdventure
    }
    
    var isCompleted: Bool {
        return self == .completed
    }
}

// MARK: - Helper Structs

/// Helper struct for sheet presentation with conversation ID
struct ChatSheetId: Identifiable {
    let id: String
}

// MARK: - Recurring Booking Models

enum PaymentFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    
    var discountPercentage: Double {
        switch self {
        case .daily: return 0.0
        case .weekly: return 0.0
        case .monthly: return 0.10 // 10% discount for monthly
        }
    }
}

struct RecurringSeries: Identifiable, Codable {
    let id: String
    let clientId: String
    let serviceType: String
    let numberOfVisits: Int
    let frequency: PaymentFrequency
    let startDate: Date
    let preferredTime: String
    let preferredDays: [Int]?
    let basePrice: Double
    let totalPrice: Double
    let pets: [String]
    let specialInstructions: String?
    let status: RecurringSeriesStatus
    let createdAt: Date
    let assignedSitterId: String?
    let preferredSitterId: String?
    let completedVisits: Int
    let canceledVisits: Int
    let upcomingVisits: Int
    let duration: Int
    
    enum RecurringSeriesStatus: String, Codable {
        case pending = "pending"
        case active = "active"
        case paused = "paused"
        case completed = "completed"
        case canceled = "canceled"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .active: return "Active"
            case .paused: return "Paused"
            case .completed: return "Completed"
            case .canceled: return "Canceled"
            }
        }
    }
}
