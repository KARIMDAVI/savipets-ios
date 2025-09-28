import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

struct ChatInquiry: Identifiable {
    var id: String?
    let fromUserId: String
    let fromUserRole: String
    let toUserId: String
    let subject: String
    let initialMessage: String
    let status: String
    let createdAt: Timestamp?
    var conversationId: String?
}

struct Conversation: Identifiable {
    var id: String?
    let participants: [String]
    let participantRoles: [String]
    let lastMessage: String
    let lastMessageAt: Timestamp?
    let status: String
    let createdAt: Timestamp?
}

struct ChatMessage: Identifiable {
    var id: String?
    let senderId: String
    let text: String
    let timestamp: Timestamp?
    let read: Bool
}

final class ChatService: ObservableObject {
    private let db = Firestore.firestore()
    @Published var inquiries: [ChatInquiry] = []
    @Published var conversations: [Conversation] = []
    @Published var messages: [String: [ChatMessage]] = [:]

    // MARK: - Inquiries

    func createInquiry(subject: String, initialMessage: String, userRole: UserRole) async throws {
        guard let currentUser = Auth.auth().currentUser else { return }

        let data: [String: Any] = [
            "fromUserId": currentUser.uid,
            "fromUserRole": userRole.rawValue,
            "toUserId": "admin",
            "subject": subject,
            "initialMessage": initialMessage,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]

        let ref = db.collection("inquiries").document()
        try await ref.setData(data)
    }

    func listenToAdminInquiries() {
        db.collection("inquiries")
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                let items: [ChatInquiry] = documents.compactMap { doc in
                    let data = doc.data()
                    guard
                        let fromUserId = data["fromUserId"] as? String,
                        let fromUserRole = data["fromUserRole"] as? String,
                        let toUserId = data["toUserId"] as? String,
                        let subject = data["subject"] as? String,
                        let initialMessage = data["initialMessage"] as? String,
                        let status = data["status"] as? String
                    else { return nil }

                    return ChatInquiry(
                        id: doc.documentID,
                        fromUserId: fromUserId,
                        fromUserRole: fromUserRole,
                        toUserId: toUserId,
                        subject: subject,
                        initialMessage: initialMessage,
                        status: status,
                        createdAt: data["createdAt"] as? Timestamp,
                        conversationId: data["conversationId"] as? String
                    )
                }
                DispatchQueue.main.async {
                    self.inquiries = items
                }
            }
    }

    // MARK: - Conversations

    func listenToMyConversations() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("conversations")
            .whereField("participants", arrayContains: uid)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                let items: [Conversation] = documents.map { doc in
                    let data = doc.data()
                    return Conversation(
                        id: doc.documentID,
                        participants: data["participants"] as? [String] ?? [],
                        participantRoles: data["participantRoles"] as? [String] ?? [],
                        lastMessage: data["lastMessage"] as? String ?? "",
                        lastMessageAt: data["lastMessageAt"] as? Timestamp,
                        status: data["status"] as? String ?? "active",
                        createdAt: data["createdAt"] as? Timestamp
                    )
                }
                DispatchQueue.main.async {
                    self.conversations = items
                }
            }
    }

    func acceptInquiry(_ inquiry: ChatInquiry) async throws {
        guard let inquiryId = inquiry.id,
              let adminId = Auth.auth().currentUser?.uid else { return }

        // Create conversation
        let conversationRef = db.collection("conversations").document()
        let conversationData: [String: Any] = [
            "participants": [inquiry.fromUserId, adminId],
            "participantRoles": [inquiry.fromUserRole, "admin"],
            "lastMessage": inquiry.initialMessage,
            "lastMessageAt": FieldValue.serverTimestamp(),
            "status": "active",
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await conversationRef.setData(conversationData)

        // Update inquiry
        try await db.collection("inquiries").document(inquiryId).updateData([
            "status": "accepted",
            "conversationId": conversationRef.documentID
        ])

        // Seed initial message from the inquiry
        let messageRef = conversationRef.collection("messages").document()
        try await messageRef.setData([
            "senderId": inquiry.fromUserId,
            "text": inquiry.initialMessage,
            "timestamp": FieldValue.serverTimestamp(),
            "read": false
        ])
    }

    // MARK: - Messages

    func listenToMessages(conversationId: String) {
        db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                let list: [ChatMessage] = documents.map { doc in
                    let data = doc.data()
                    return ChatMessage(
                        id: doc.documentID,
                        senderId: data["senderId"] as? String ?? "",
                        text: data["text"] as? String ?? "",
                        timestamp: data["timestamp"] as? Timestamp,
                        read: data["read"] as? Bool ?? false
                    )
                }
                DispatchQueue.main.async {
                    self.messages[conversationId] = list
                }
            }
    }

    func sendMessage(conversationId: String, text: String) async throws {
        guard let currentUser = Auth.auth().currentUser else { return }

        let msgRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document()

        try await msgRef.setData([
            "senderId": currentUser.uid,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "read": false
        ])

        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "lastMessage": text,
                "lastMessageAt": FieldValue.serverTimestamp()
            ])
    }
}
