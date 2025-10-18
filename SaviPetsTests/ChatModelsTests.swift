import XCTest
@testable import SaviPets

final class ChatModelsTests: XCTestCase {
    
    // MARK: - UserRole Tests
    
    func testUserRole_DisplayNames() {
        XCTAssertEqual(UserRole.petOwner.displayName, "Pet Owner")
        XCTAssertEqual(UserRole.petSitter.displayName, "Pet Sitter")
        XCTAssertEqual(UserRole.admin.displayName, "Admin")
    }
    
    func testUserRole_Booleans() {
        let owner = UserRole.petOwner
        XCTAssertTrue(owner.isPetOwner)
        XCTAssertFalse(owner.isPetSitter)
        XCTAssertFalse(owner.isAdmin)
        
        let sitter = UserRole.petSitter
        XCTAssertFalse(sitter.isPetOwner)
        XCTAssertTrue(sitter.isPetSitter)
        XCTAssertFalse(sitter.isAdmin)
        
        let admin = UserRole.admin
        XCTAssertFalse(admin.isPetOwner)
        XCTAssertFalse(admin.isPetSitter)
        XCTAssertTrue(admin.isAdmin)
    }
    
    func testUserRole_FromString() {
        // Test exact raw value matching
        XCTAssertEqual(UserRole.from("petOwner"), .petOwner)
        XCTAssertEqual(UserRole.from("petSitter"), .petSitter)
        XCTAssertEqual(UserRole.from("admin"), .admin)
        
        // Test display name matching
        XCTAssertEqual(UserRole.from("Pet Owner"), .petOwner)
        XCTAssertEqual(UserRole.from("Pet Sitter"), .petSitter)
        XCTAssertEqual(UserRole.from("Admin"), .admin)
        
        // Test invalid inputs
        XCTAssertNil(UserRole.from("invalid"))
        XCTAssertNil(UserRole.from(""))
        XCTAssertNil(UserRole.from("owner"))
    }
    
    // MARK: - MessageStatus Tests
    
    func testMessageStatus_DisplayNames() {
        XCTAssertEqual(MessageStatus.sending.displayName, "Sending")
        XCTAssertEqual(MessageStatus.sent.displayName, "Sent")
        XCTAssertEqual(MessageStatus.pending.displayName, "Pending Approval")
        XCTAssertEqual(MessageStatus.rejected.displayName, "Rejected")
        XCTAssertEqual(MessageStatus.failed.displayName, "Failed")
    }
    
    func testMessageStatus_IsPending() {
        XCTAssertFalse(MessageStatus.sending.isPending)
        XCTAssertFalse(MessageStatus.sent.isPending)
        XCTAssertTrue(MessageStatus.pending.isPending)
        XCTAssertFalse(MessageStatus.rejected.isPending)
        XCTAssertFalse(MessageStatus.failed.isPending)
    }
    
    func testMessageStatus_IsFailed() {
        XCTAssertTrue(MessageStatus.sending.isFailed) // sending counts as potentially failed
        XCTAssertFalse(MessageStatus.sent.isFailed)
        XCTAssertFalse(MessageStatus.pending.isFailed)
        XCTAssertFalse(MessageStatus.rejected.isFailed)
        XCTAssertTrue(MessageStatus.failed.isFailed)
    }
    
    // MARK: - ConversationType Tests
    
    func testConversationType_DisplayNames() {
        XCTAssertEqual(ConversationType.adminInquiry.displayName, "Admin Inquiry")
        XCTAssertEqual(ConversationType.clientSitter.displayName, "Client-Sitter")
        XCTAssertEqual(ConversationType.sitterToClient.displayName, "Sitter to Client")
    }
    
    func testConversationType_RawValues() {
        XCTAssertEqual(ConversationType.adminInquiry.rawValue, "admin-inquiry")
        XCTAssertEqual(ConversationType.clientSitter.rawValue, "client-sitter")
        XCTAssertEqual(ConversationType.sitterToClient.rawValue, "sitter-to-client")
    }
    
    // MARK: - DeliveryStatus Tests
    
    func testDeliveryStatus_DisplayNames() {
        XCTAssertEqual(DeliveryStatus.sending.displayName, "Sending")
        XCTAssertEqual(DeliveryStatus.delivered.displayName, "Delivered")
        XCTAssertEqual(DeliveryStatus.read.displayName, "Read")
        XCTAssertEqual(DeliveryStatus.failed.displayName, "Failed")
    }
    
    // MARK: - Conversation Tests
    
    func testConversation_ShouldSendAutoResponse_FirstTime() {
        let conversation = Conversation(
            id: "test-convo",
            participants: ["user1", "admin1"],
            participantRoles: [.petOwner, .admin],
            lastMessage: "Hello",
            lastMessageAt: Date(),
            status: "active",
            createdAt: Date(),
            type: .adminInquiry,
            isPinned: false,
            pinnedName: nil,
            autoResponseHistory: [:], // No history = first time
            autoResponseCooldown: 86400, // 24 hours
            adminReplied: false
        )
        
        XCTAssertTrue(conversation.shouldSendAutoResponse(for: "user1"), "Should send auto response on first contact")
    }
    
    func testConversation_ShouldSendAutoResponse_WithinCooldown() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        
        let conversation = Conversation(
            id: "test-convo",
            participants: ["user1", "admin1"],
            participantRoles: [.petOwner, .admin],
            lastMessage: "Hello",
            lastMessageAt: now,
            status: "active",
            createdAt: now,
            type: .adminInquiry,
            isPinned: false,
            pinnedName: nil,
            autoResponseHistory: ["user1": oneHourAgo],
            autoResponseCooldown: 86400, // 24 hours
            adminReplied: false
        )
        
        XCTAssertFalse(conversation.shouldSendAutoResponse(for: "user1"), "Should not send auto response within cooldown period")
    }
    
    func testConversation_ShouldSendAutoResponse_AfterCooldown() {
        let now = Date()
        let twoDaysAgo = now.addingTimeInterval(-172800) // 48 hours
        
        let conversation = Conversation(
            id: "test-convo",
            participants: ["user1", "admin1"],
            participantRoles: [.petOwner, .admin],
            lastMessage: "Hello",
            lastMessageAt: now,
            status: "active",
            createdAt: now,
            type: .adminInquiry,
            isPinned: false,
            pinnedName: nil,
            autoResponseHistory: ["user1": twoDaysAgo],
            autoResponseCooldown: 86400, // 24 hours
            adminReplied: false
        )
        
        XCTAssertTrue(conversation.shouldSendAutoResponse(for: "user1"), "Should send auto response after cooldown period")
    }
    
    func testConversation_UnreadCount() {
        let conversation = Conversation(
            id: "test-convo",
            participants: ["user1", "user2"],
            participantRoles: [.petOwner, .petSitter],
            lastMessage: "Test",
            lastMessageAt: Date(),
            status: "active",
            createdAt: Date(),
            type: .clientSitter,
            isPinned: false,
            pinnedName: nil,
            unreadCounts: ["user1": 5, "user2": 0]
        )
        
        XCTAssertEqual(conversation.unreadCount(for: "user1"), 5)
        XCTAssertEqual(conversation.unreadCount(for: "user2"), 0)
        XCTAssertEqual(conversation.unreadCount(for: "user3"), 0)
    }
    
    func testConversation_IsParticipant() {
        let conversation = Conversation(
            id: "test-convo",
            participants: ["user1", "user2", "admin1"],
            participantRoles: [.petOwner, .petSitter, .admin],
            lastMessage: "Test",
            lastMessageAt: Date(),
            status: "active",
            createdAt: Date(),
            type: .clientSitter,
            isPinned: false,
            pinnedName: nil
        )
        
        XCTAssertTrue(conversation.isParticipant("user1"))
        XCTAssertTrue(conversation.isParticipant("user2"))
        XCTAssertTrue(conversation.isParticipant("admin1"))
        XCTAssertFalse(conversation.isParticipant("user3"))
    }
    
    func testConversation_RoleFor() {
        let conversation = Conversation(
            id: "test-convo",
            participants: ["user1", "user2", "admin1"],
            participantRoles: [.petOwner, .petSitter, .admin],
            lastMessage: "Test",
            lastMessageAt: Date(),
            status: "active",
            createdAt: Date(),
            type: .clientSitter,
            isPinned: false,
            pinnedName: nil
        )
        
        XCTAssertEqual(conversation.roleFor("user1"), .petOwner)
        XCTAssertEqual(conversation.roleFor("user2"), .petSitter)
        XCTAssertEqual(conversation.roleFor("admin1"), .admin)
        XCTAssertNil(conversation.roleFor("user3"))
    }
    
    // MARK: - ChatMessage Reaction Tests
    
    func testChatMessage_HasReaction() {
        let message = ChatMessage(
            id: "msg1",
            senderId: "user1",
            text: "Hello",
            timestamp: Date(),
            reactions: ["❤️": ["user2", "user3"], "👍": ["user4"]]
        )
        
        XCTAssertTrue(message.hasReaction("❤️", from: "user2"))
        XCTAssertTrue(message.hasReaction("❤️", from: "user3"))
        XCTAssertTrue(message.hasReaction("👍", from: "user4"))
        XCTAssertFalse(message.hasReaction("❤️", from: "user4"))
        XCTAssertFalse(message.hasReaction("😂", from: "user2"))
    }
    
    func testChatMessage_AddReaction() {
        let originalMessage = ChatMessage(
            id: "msg1",
            senderId: "user1",
            text: "Hello",
            timestamp: Date(),
            reactions: [:]
        )
        
        let withReaction = originalMessage.addReaction("❤️", from: "user2")
        
        XCTAssertTrue(withReaction.hasReaction("❤️", from: "user2"))
        XCTAssertEqual(withReaction.reactions["❤️"]?.count, 1)
    }
    
    func testChatMessage_AddReaction_NoDuplicates() {
        let message = ChatMessage(
            id: "msg1",
            senderId: "user1",
            text: "Hello",
            timestamp: Date(),
            reactions: ["❤️": ["user2"]]
        )
        
        let withReaction = message.addReaction("❤️", from: "user2")
        
        // Should not add duplicate
        XCTAssertEqual(withReaction.reactions["❤️"]?.count, 1)
    }
    
    func testChatMessage_RemoveReaction() {
        let message = ChatMessage(
            id: "msg1",
            senderId: "user1",
            text: "Hello",
            timestamp: Date(),
            reactions: ["❤️": ["user2", "user3"]]
        )
        
        let afterRemoval = message.removeReaction("❤️", from: "user2")
        
        XCTAssertFalse(afterRemoval.hasReaction("❤️", from: "user2"))
        XCTAssertTrue(afterRemoval.hasReaction("❤️", from: "user3"))
        XCTAssertEqual(afterRemoval.reactions["❤️"]?.count, 1)
    }
    
    func testChatMessage_RemoveReaction_LastUser() {
        let message = ChatMessage(
            id: "msg1",
            senderId: "user1",
            text: "Hello",
            timestamp: Date(),
            reactions: ["❤️": ["user2"]]
        )
        
        let afterRemoval = message.removeReaction("❤️", from: "user2")
        
        // Should remove emoji entirely when no users left
        XCTAssertNil(afterRemoval.reactions["❤️"])
    }
    
    // MARK: - VisitStatus Tests
    
    func testVisitStatus_DisplayNames() {
        XCTAssertEqual(VisitStatus.scheduled.displayName, "Scheduled")
        XCTAssertEqual(VisitStatus.inAdventure.displayName, "In Progress")
        XCTAssertEqual(VisitStatus.completed.displayName, "Completed")
        XCTAssertEqual(VisitStatus.cancelled.displayName, "Cancelled")
    }
    
    func testVisitStatus_IsActive() {
        XCTAssertFalse(VisitStatus.scheduled.isActive)
        XCTAssertTrue(VisitStatus.inAdventure.isActive)
        XCTAssertFalse(VisitStatus.completed.isActive)
        XCTAssertFalse(VisitStatus.cancelled.isActive)
    }
    
    func testVisitStatus_IsCompleted() {
        XCTAssertFalse(VisitStatus.scheduled.isCompleted)
        XCTAssertFalse(VisitStatus.inAdventure.isCompleted)
        XCTAssertTrue(VisitStatus.completed.isCompleted)
        XCTAssertFalse(VisitStatus.cancelled.isCompleted)
    }
    
    // MARK: - Edge Cases
    
    func testConversation_EmptyParticipants() {
        let conversation = Conversation(
            id: "test-convo",
            participants: [],
            participantRoles: [],
            lastMessage: "Test",
            lastMessageAt: Date(),
            status: "active",
            createdAt: Date(),
            type: .adminInquiry,
            isPinned: false,
            pinnedName: nil
        )
        
        XCTAssertFalse(conversation.isParticipant("user1"))
        XCTAssertNil(conversation.roleFor("user1"))
    }
    
    func testConversation_MismatchedParticipantsAndRoles() {
        // More participants than roles
        let conversation = Conversation(
            id: "test-convo",
            participants: ["user1", "user2", "user3"],
            participantRoles: [.petOwner, .petSitter], // Only 2 roles
            lastMessage: "Test",
            lastMessageAt: Date(),
            status: "active",
            createdAt: Date(),
            type: .clientSitter,
            isPinned: false,
            pinnedName: nil
        )
        
        XCTAssertEqual(conversation.roleFor("user1"), .petOwner)
        XCTAssertEqual(conversation.roleFor("user2"), .petSitter)
        XCTAssertNil(conversation.roleFor("user3"), "Should return nil for participant without matching role")
    }
    
    // MARK: - Performance Tests
    
    func testConversation_IsParticipant_Performance() {
        let participants = (0..<1000).map { "user\($0)" }
        let roles = (0..<1000).map { _ in UserRole.petOwner }
        
        let conversation = Conversation(
            id: "test-convo",
            participants: participants,
            participantRoles: roles,
            lastMessage: "Test",
            lastMessageAt: Date(),
            status: "active",
            createdAt: Date(),
            type: .clientSitter,
            isPinned: false,
            pinnedName: nil
        )
        
        measure {
            for i in 0..<100 {
                _ = conversation.isParticipant("user\(i)")
            }
        }
    }
    
    func testChatMessage_ReactionOperations_Performance() {
        var message = ChatMessage(
            id: "msg1",
            senderId: "user1",
            text: "Hello",
            timestamp: Date(),
            reactions: [:]
        )
        
        measure {
            for i in 0..<100 {
                message = message.addReaction("❤️", from: "user\(i)")
            }
        }
    }
}

