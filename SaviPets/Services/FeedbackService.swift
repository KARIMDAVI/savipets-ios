import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog
import Combine
import SwiftUI

/// Service for managing service feedback and ratings
@MainActor
final class FeedbackService: ObservableObject {
    @Published var feedbacks: [ServiceFeedback] = []
    @Published var isProcessing: Bool = false
    @Published var lastUpdated: Date?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let feedbackCollection = "serviceFeedback"
    
    // Real-time listener
    private var feedbackListener: ListenerRegistration?
    
    init() {
        setupRealTimeListener()
    }
    
    deinit {
        feedbackListener?.remove()
    }
    
    // MARK: - Real-time Listener
    private func setupRealTimeListener() {
        feedbackListener = db.collection(feedbackCollection)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.data.error("Feedback listener error: \(error.localizedDescription)")
                    return
                }
                
                Task { @MainActor in
                    self.feedbacks = snapshot?.documents.compactMap { doc in
                        self.parseFeedbackFromDocument(doc)
                    } ?? []
                    self.lastUpdated = Date()
                }
            }
    }
    
    // MARK: - Feedback Submission
    func submitFeedback(
        bookingId: String,
        clientId: String,
        sitterId: String,
        rating: Int,
        comment: String?,
        categories: [FeedbackCategory]
    ) async -> Result<ServiceFeedback, FeedbackError> {
        
        guard rating >= 1 && rating <= 5 else {
            return .failure(.invalidRating)
        }
        
        isProcessing = true
        
        do {
            let feedback = ServiceFeedback(
                id: UUID().uuidString,
                bookingId: bookingId,
                clientId: clientId,
                sitterId: sitterId,
                rating: rating,
                comment: comment,
                categories: categories,
                isAnonymous: false,
                status: .submitted,
                createdAt: Date(),
                lastModified: Date(),
                responses: [],
                helpfulVotes: 0,
                reportedCount: 0,
                isVerified: false
            )
            
            try await db.collection(feedbackCollection).document(feedback.id).setData(feedback.toFirestoreData())
            
            // Update booking with feedback reference
            try await updateBookingWithFeedback(bookingId: bookingId, feedbackId: feedback.id)
            
            // Update sitter rating
            await updateSitterRating(sitterId: sitterId)
            
            AppLogger.data.info("Feedback submitted for booking \(bookingId)")
            
            isProcessing = false
            return .success(feedback)
            
        } catch {
            isProcessing = false
            AppLogger.data.error("Failed to submit feedback: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    // MARK: - Feedback Management
    func updateFeedback(_ feedback: ServiceFeedback) async -> Result<ServiceFeedback, FeedbackError> {
        isProcessing = true
        
        do {
            var updatedFeedback = feedback
            updatedFeedback.lastModified = Date()
            
            try await db.collection(feedbackCollection).document(feedback.id).updateData(updatedFeedback.toFirestoreData())
            
            AppLogger.data.info("Updated feedback \(feedback.id)")
            
            isProcessing = false
            return .success(updatedFeedback)
            
        } catch {
            isProcessing = false
            AppLogger.data.error("Failed to update feedback: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    func deleteFeedback(_ feedbackId: String) async -> Result<Void, FeedbackError> {
        isProcessing = true
        
        do {
            try await db.collection(feedbackCollection).document(feedbackId).delete()
            
            AppLogger.data.info("Deleted feedback \(feedbackId)")
            
            isProcessing = false
            return .success(())
            
        } catch {
            isProcessing = false
            AppLogger.data.error("Failed to delete feedback: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    // MARK: - Feedback Retrieval
    func getFeedbackForBooking(_ bookingId: String) async -> ServiceFeedback? {
        do {
            let snapshot = try await db.collection(feedbackCollection)
                .whereField("bookingId", isEqualTo: bookingId)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first else { return nil }
            return parseFeedbackFromDocument(document)
            
        } catch {
            AppLogger.data.error("Failed to get feedback for booking: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getFeedbacksForSitter(_ sitterId: String, limit: Int = 50) async -> [ServiceFeedback] {
        do {
            let snapshot = try await db.collection(feedbackCollection)
                .whereField("sitterId", isEqualTo: sitterId)
                .whereField("status", isEqualTo: "approved")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { parseFeedbackFromDocument($0) }
            
        } catch {
            AppLogger.data.error("Failed to get feedbacks for sitter: \(error.localizedDescription)")
            return []
        }
    }
    
    func getFeedbacksForClient(_ clientId: String) async -> [ServiceFeedback] {
        do {
            let snapshot = try await db.collection(feedbackCollection)
                .whereField("clientId", isEqualTo: clientId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            return snapshot.documents.compactMap { parseFeedbackFromDocument($0) }
            
        } catch {
            AppLogger.data.error("Failed to get feedbacks for client: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Feedback Analytics
    func getSitterRatingStats(_ sitterId: String) async -> RatingStats? {
        let sitterFeedbacks = await getFeedbacksForSitter(sitterId)
        
        guard !sitterFeedbacks.isEmpty else { return nil }
        
        let totalFeedbacks = sitterFeedbacks.count
        let averageRating = Double(sitterFeedbacks.reduce(0) { $0 + $1.rating }) / Double(totalFeedbacks)
        
        let ratingDistribution = Dictionary(grouping: sitterFeedbacks, by: { $0.rating })
            .mapValues { $0.count }
        
        let categoryStats = Dictionary(grouping: sitterFeedbacks.flatMap { $0.categories }, by: { $0 })
            .mapValues { $0.count }
        
        let recentFeedbacks = sitterFeedbacks.prefix(10)
        let recentAverage = recentFeedbacks.isEmpty ? 0.0 : Double(recentFeedbacks.reduce(0) { $0 + $1.rating }) / Double(recentFeedbacks.count)
        
        return RatingStats(
            sitterId: sitterId,
            totalFeedbacks: totalFeedbacks,
            averageRating: averageRating,
            recentAverageRating: recentAverage,
            ratingDistribution: ratingDistribution,
            categoryStats: categoryStats,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Feedback Actions
    func markFeedbackAsHelpful(_ feedbackId: String, userId: String) async -> Result<Void, FeedbackError> {
        guard let feedback = feedbacks.first(where: { $0.id == feedbackId }) else {
            return .failure(.feedbackNotFound)
        }
        
        do {
            let updatedHelpfulVotes = feedback.helpfulVotes + 1
            
            try await db.collection(feedbackCollection).document(feedbackId).updateData([
                "helpfulVotes": updatedHelpfulVotes,
                "lastModified": FieldValue.serverTimestamp()
            ])
            
            AppLogger.data.info("Marked feedback \(feedbackId) as helpful")
            return .success(())
            
        } catch {
            AppLogger.data.error("Failed to mark feedback as helpful: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    func reportFeedback(_ feedbackId: String, reason: ReportReason, userId: String) async -> Result<Void, FeedbackError> {
        do {
            let reportData: [String: Any] = [
                "feedbackId": feedbackId,
                "reportedBy": userId,
                "reason": reason.rawValue,
                "reportedAt": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("feedbackReports").addDocument(data: reportData)
            
            // Increment reported count
            try await db.collection(feedbackCollection).document(feedbackId).updateData([
                "reportedCount": FieldValue.increment(Int64(1)),
                "lastModified": FieldValue.serverTimestamp()
            ])
            
            AppLogger.data.info("Reported feedback \(feedbackId) for \(reason.rawValue)")
            return .success(())
            
        } catch {
            AppLogger.data.error("Failed to report feedback: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    func respondToFeedback(_ feedbackId: String, response: String, responderId: String, responderType: ResponderType) async -> Result<Void, FeedbackError> {
        guard let feedback = feedbacks.first(where: { $0.id == feedbackId }) else {
            return .failure(.feedbackNotFound)
        }
        
        do {
            let feedbackResponse = FeedbackResponse(
                id: UUID().uuidString,
                response: response,
                responderId: responderId,
                responderType: responderType,
                createdAt: Date()
            )
            
            var updatedResponses = feedback.responses
            updatedResponses.append(feedbackResponse)
            
            try await db.collection(feedbackCollection).document(feedbackId).updateData([
                "responses": updatedResponses.map { $0.toFirestoreData() },
                "lastModified": FieldValue.serverTimestamp()
            ])
            
            AppLogger.data.info("Added response to feedback \(feedbackId)")
            return .success(())
            
        } catch {
            AppLogger.data.error("Failed to respond to feedback: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    // MARK: - Helper Methods
    private func updateBookingWithFeedback(bookingId: String, feedbackId: String) async throws {
        try await db.collection("serviceBookings").document(bookingId).updateData([
            "feedbackId": feedbackId,
            "hasFeedback": true,
            "lastModified": FieldValue.serverTimestamp()
        ])
    }
    
    private func updateSitterRating(sitterId: String) async {
        do {
            let ratingStats = await getSitterRatingStats(sitterId)
            
            if let stats = ratingStats {
                try await db.collection("sitters").document(sitterId).updateData([
                    "rating": stats.averageRating,
                    "totalReviews": stats.totalFeedbacks,
                    "lastRatingUpdate": FieldValue.serverTimestamp()
                ])
                
                AppLogger.data.info("Updated sitter \(sitterId) rating to \(stats.averageRating)")
            }
            
        } catch {
            AppLogger.data.error("Failed to update sitter rating: \(error.localizedDescription)")
        }
    }
    
    private func parseFeedbackFromDocument(_ document: QueryDocumentSnapshot) -> ServiceFeedback? {
        let data = document.data()
        
        guard let bookingId = data["bookingId"] as? String,
              let clientId = data["clientId"] as? String,
              let sitterId = data["sitterId"] as? String,
              let rating = data["rating"] as? Int,
              let categoriesData = data["categories"] as? [String],
              let statusString = data["status"] as? String,
              let status = FeedbackStatus(rawValue: statusString),
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let lastModifiedTimestamp = data["lastModified"] as? Timestamp else {
            return nil
        }
        
        let categories = categoriesData.compactMap { FeedbackCategory(rawValue: $0) }
        let createdAt = createdAtTimestamp.dateValue()
        let lastModified = lastModifiedTimestamp.dateValue()
        
        // Parse responses
        let responsesData = data["responses"] as? [[String: Any]] ?? []
        let responses = responsesData.compactMap { FeedbackResponse.fromFirestoreData($0) }
        
        return ServiceFeedback(
            id: document.documentID,
            bookingId: bookingId,
            clientId: clientId,
            sitterId: sitterId,
            rating: rating,
            comment: data["comment"] as? String,
            categories: categories,
            isAnonymous: data["isAnonymous"] as? Bool ?? false,
            status: status,
            createdAt: createdAt,
            lastModified: lastModified,
            responses: responses,
            helpfulVotes: data["helpfulVotes"] as? Int ?? 0,
            reportedCount: data["reportedCount"] as? Int ?? 0,
            isVerified: data["isVerified"] as? Bool ?? false
        )
    }
    
    // MARK: - Public Methods
    func refreshFeedbacks() async {
        // Force refresh from Firestore
        do {
            let snapshot = try await db.collection(feedbackCollection)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            feedbacks = snapshot.documents.compactMap { parseFeedbackFromDocument($0) }
            lastUpdated = Date()
            
        } catch {
            AppLogger.data.error("Failed to refresh feedbacks: \(error.localizedDescription)")
        }
    }
    
    func getFilteredFeedbacks(
        sitterId: String? = nil,
        minRating: Int? = nil,
        categories: [FeedbackCategory]? = nil,
        status: FeedbackStatus? = nil
    ) -> [ServiceFeedback] {
        
        var filtered = feedbacks
        
        if let sitterId = sitterId {
            filtered = filtered.filter { $0.sitterId == sitterId }
        }
        
        if let minRating = minRating {
            filtered = filtered.filter { $0.rating >= minRating }
        }
        
        if let categories = categories, !categories.isEmpty {
            filtered = filtered.filter { feedback in
                categories.allSatisfy { category in
                    feedback.categories.contains(category)
                }
            }
        }
        
        if let status = status {
            filtered = filtered.filter { $0.status == status }
        }
        
        return filtered
    }
}

// MARK: - Supporting Models
struct ServiceFeedback: Codable, Identifiable {
    let id: String
    let bookingId: String
    let clientId: String
    let sitterId: String
    let rating: Int
    let comment: String?
    let categories: [FeedbackCategory]
    let isAnonymous: Bool
    var status: FeedbackStatus
    let createdAt: Date
    var lastModified: Date
    var responses: [FeedbackResponse]
    var helpfulVotes: Int
    var reportedCount: Int
    let isVerified: Bool
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "bookingId": bookingId,
            "clientId": clientId,
            "sitterId": sitterId,
            "rating": rating,
            "categories": categories.map { $0.rawValue },
            "isAnonymous": isAnonymous,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "lastModified": Timestamp(date: lastModified),
            "responses": responses.map { $0.toFirestoreData() },
            "helpfulVotes": helpfulVotes,
            "reportedCount": reportedCount,
            "isVerified": isVerified
        ]
        
        if let comment = comment {
            data["comment"] = comment
        }
        
        return data
    }
}

enum FeedbackCategory: String, Codable, CaseIterable {
    case punctuality = "punctuality"
    case communication = "communication"
    case petCare = "pet_care"
    case professionalism = "professionalism"
    case reliability = "reliability"
    case cleanliness = "cleanliness"
    case safety = "safety"
    case value = "value"
    
    var displayName: String {
        switch self {
        case .punctuality: return "Punctuality"
        case .communication: return "Communication"
        case .petCare: return "Pet Care"
        case .professionalism: return "Professionalism"
        case .reliability: return "Reliability"
        case .cleanliness: return "Cleanliness"
        case .safety: return "Safety"
        case .value: return "Value for Money"
        }
    }
    
    var icon: String {
        switch self {
        case .punctuality: return "clock"
        case .communication: return "message"
        case .petCare: return "pawprint"
        case .professionalism: return "person.badge.shield.checkmark"
        case .reliability: return "checkmark.shield"
        case .cleanliness: return "sparkles"
        case .safety: return "shield"
        case .value: return "dollarsign.circle"
        }
    }
}

enum FeedbackStatus: String, Codable, CaseIterable {
    case submitted = "submitted"
    case approved = "approved"
    case rejected = "rejected"
    case pending = "pending"
    case flagged = "flagged"
    
    var displayName: String {
        switch self {
        case .submitted: return "Submitted"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .pending: return "Pending Review"
        case .flagged: return "Flagged"
        }
    }
    
    var color: Color {
        switch self {
        case .submitted: return .blue
        case .approved: return .green
        case .rejected: return .red
        case .pending: return .orange
        case .flagged: return .purple
        }
    }
}

struct FeedbackResponse: Codable, Identifiable {
    let id: String
    let response: String
    let responderId: String
    let responderType: ResponderType
    let createdAt: Date
    
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "response": response,
            "responderId": responderId,
            "responderType": responderType.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    static func fromFirestoreData(_ data: [String: Any]) -> FeedbackResponse? {
        guard let id = data["id"] as? String,
              let response = data["response"] as? String,
              let responderId = data["responderId"] as? String,
              let responderTypeString = data["responderType"] as? String,
              let responderType = ResponderType(rawValue: responderTypeString),
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        return FeedbackResponse(
            id: id,
            response: response,
            responderId: responderId,
            responderType: responderType,
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}

enum ResponderType: String, Codable {
    case sitter = "sitter"
    case admin = "admin"
    case client = "client"
    
    var displayName: String {
        switch self {
        case .sitter: return "Pet Sitter"
        case .admin: return "Administrator"
        case .client: return "Client"
        }
    }
}

enum ReportReason: String, Codable, CaseIterable {
    case inappropriate = "inappropriate"
    case spam = "spam"
    case fake = "fake"
    case harassment = "harassment"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .inappropriate: return "Inappropriate Content"
        case .spam: return "Spam"
        case .fake: return "Fake Review"
        case .harassment: return "Harassment"
        case .other: return "Other"
        }
    }
}

struct RatingStats: Codable {
    let sitterId: String
    let totalFeedbacks: Int
    let averageRating: Double
    let recentAverageRating: Double
    let ratingDistribution: [Int: Int]
    let categoryStats: [FeedbackCategory: Int]
    let lastUpdated: Date
}

enum FeedbackError: Error, LocalizedError {
    case invalidRating
    case feedbackNotFound
    case databaseError(String)
    case networkError
    case unauthorizedAccess
    
    var errorDescription: String? {
        switch self {
        case .invalidRating:
            return "Rating must be between 1 and 5 stars"
        case .feedbackNotFound:
            return "Feedback not found"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .networkError:
            return "Network connection error"
        case .unauthorizedAccess:
            return "Unauthorized access to feedback"
        }
    }
}
