import Foundation
import FirebaseFirestore
import CoreLocation
import Combine
import OSLog

/// AI Sitter Assignment Service
/// Automatically assigns the best sitter based on availability, distance, pet type, and role
/// Designed to be upgradable for future AI integration via Firebase Functions
final class AISitterAssignmentService: ObservableObject {
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastAssignmentResult: AssignmentResult?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Assignment Result
    struct AssignmentResult {
        let bookingId: String
        let sitterId: String?
        let sitterName: String?
        let assignmentMethod: AssignmentMethod
        let confidence: Double
        let reasons: [String]
        let timestamp: Date
        
        enum AssignmentMethod {
            case aiAutomatic
            case ruleBased
            case adminManual
            case failed
        }
    }
    
    // MARK: - Sitter Profile for Assignment
    struct AssignableSitter {
        let id: String
        let name: String
        let email: String
        let isActive: Bool
        let petTypes: [String] // ["dog", "cat", "bird", etc.]
        let availability: SitterAvailability
        let location: CLLocation?
        let rating: Double
        let totalBookings: Int
        let distance: Double? // Distance to booking location
        let lastAssigned: Date?
        let isAvailable: Bool
    }
    
    // MARK: - Assignment Criteria
    struct AssignmentCriteria {
        let bookingId: String
        let clientId: String
        let bookingLocation: CLLocation?
        let petTypes: [String]
        let serviceType: String
        let scheduledDate: Date
        let duration: Int // minutes
        let specialRequirements: [String]
        let preferredSitterId: String? // If client has a preferred sitter
    }
    
    // MARK: - Main Assignment Function
    /// Automatically assigns the best sitter for a booking
    /// Returns AssignmentResult with assignment details
    func assignBestSitter(for criteria: AssignmentCriteria) async -> AssignmentResult {
        await MainActor.run { isProcessing = true }
        
        defer {
            Task { @MainActor in isProcessing = false }
        }
        
        do {
            // Step 1: Get all available sitters
            let availableSitters = try await fetchAvailableSitters()
            
            // Step 2: Filter sitters based on criteria
            let filteredSitters = filterSitters(availableSitters, criteria: criteria)
            
            // Step 3: Score and rank sitters
            let rankedSitters = scoreAndRankSitters(filteredSitters, criteria: criteria)
            
            // Step 4: Select best sitter
            if let bestSitter = rankedSitters.first {
                // Step 5: Assign the sitter
                let assignmentSuccess = await assignSitterToBooking(
                    sitterId: bestSitter.id,
                    bookingId: criteria.bookingId
                )
                
                if assignmentSuccess {
                    let result = AssignmentResult(
                        bookingId: criteria.bookingId,
                        sitterId: bestSitter.id,
                        sitterName: bestSitter.name,
                        assignmentMethod: .aiAutomatic,
                        confidence: calculateConfidence(for: bestSitter, criteria: criteria),
                        reasons: generateAssignmentReasons(for: bestSitter, criteria: criteria),
                        timestamp: Date()
                    )
                    
                    await MainActor.run { lastAssignmentResult = result }
                    return result
                }
            }
            
            // Fallback: No suitable sitter found
            let fallbackResult = AssignmentResult(
                bookingId: criteria.bookingId,
                sitterId: nil,
                sitterName: nil,
                assignmentMethod: .failed,
                confidence: 0.0,
                reasons: ["No suitable sitters available"],
                timestamp: Date()
            )
            
            await MainActor.run { lastAssignmentResult = fallbackResult }
            return fallbackResult
            
        } catch {
            AppLogger.ui.error("AI Sitter Assignment failed: \(error.localizedDescription)")
            
            let errorResult = AssignmentResult(
                bookingId: criteria.bookingId,
                sitterId: nil,
                sitterName: nil,
                assignmentMethod: .failed,
                confidence: 0.0,
                reasons: ["Assignment failed: \(error.localizedDescription)"],
                timestamp: Date()
            )
            
            await MainActor.run { lastAssignmentResult = errorResult }
            return errorResult
        }
    }
    
    // MARK: - Fetch Available Sitters
    private func fetchAvailableSitters() async throws -> [AssignableSitter] {
        let snapshot = try await db.collection("users")
            .whereField("role", isEqualTo: "petSitter")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        var sitters: [AssignableSitter] = []
        
        for document in snapshot.documents {
            let data = document.data()
            let sitterId = document.documentID
            
            // Parse sitter data
            let name = data["displayName"] as? String ?? data["name"] as? String ?? "Unknown Sitter"
            let email = data["email"] as? String ?? ""
            let isActive = data["isActive"] as? Bool ?? false
            
            // Parse pet types (array of strings)
            let petTypes = data["petTypes"] as? [String] ?? []
            
            // Parse location if available
            var location: CLLocation?
            if let lat = data["lat"] as? Double, let lng = data["lng"] as? Double {
                location = CLLocation(latitude: lat, longitude: lng)
            }
            
            // Parse rating and stats
            let rating = data["rating"] as? Double ?? 5.0
            let totalBookings = data["totalBookings"] as? Int ?? 0
            
            // Get availability data
            let availability = try await fetchSitterAvailability(sitterId: sitterId)
            
            // Get last assigned date
            let lastAssigned = try await getLastAssignedDate(sitterId: sitterId)
            
            let sitter = AssignableSitter(
                id: sitterId,
                name: name,
                email: email,
                isActive: isActive,
                petTypes: petTypes,
                availability: availability,
                location: location,
                rating: rating,
                totalBookings: totalBookings,
                distance: nil, // Will be calculated later
                lastAssigned: lastAssigned,
                isAvailable: availability.isAvailable
            )
            
            sitters.append(sitter)
        }
        
        return sitters
    }
    
    // MARK: - Fetch Sitter Availability
    private func fetchSitterAvailability(sitterId: String) async throws -> SitterAvailability {
        let doc = try await db.collection("sitterAvailability").document(sitterId).getDocument()
        
        guard let data = doc.data() else {
            return SitterAvailability(isAvailable: true, activeHours: [:], blockedDates: [])
        }
        
        let isAvailable = data["isAvailable"] as? Bool ?? true
        let activeHours = data["activeHours"] as? [String: [String: Bool]] ?? [:]
        let blockedDates = data["blockedDates"] as? [String] ?? []
        
        return SitterAvailability(
            isAvailable: isAvailable,
            activeHours: activeHours,
            blockedDates: blockedDates
        )
    }
    
    // MARK: - Get Last Assigned Date
    private func getLastAssignedDate(sitterId: String) async throws -> Date? {
        let snapshot = try await db.collection("bookings")
            .whereField("sitterId", isEqualTo: sitterId)
            .whereField("status", in: ["approved", "inAdventure", "completed"])
            .order(by: "assignedAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first,
              let assignedAt = document.data()["assignedAt"] as? Timestamp else {
            return nil
        }
        
        return assignedAt.dateValue()
    }
    
    // MARK: - Filter Sitters
    private func filterSitters(_ sitters: [AssignableSitter], criteria: AssignmentCriteria) -> [AssignableSitter] {
        var filtered = sitters
        
        // Filter by availability
        filtered = filtered.filter { $0.isAvailable && $0.availability.isAvailable }
        
        // Filter by pet types (sitter must handle at least one of the required pet types)
        if !criteria.petTypes.isEmpty {
            filtered = filtered.filter { sitter in
                criteria.petTypes.contains { petType in
                    sitter.petTypes.contains(petType.lowercased())
                }
            }
        }
        
        // Filter by active status
        filtered = filtered.filter { $0.isActive }
        
        // Filter by minimum rating (optional threshold)
        filtered = filtered.filter { $0.rating >= 3.0 }
        
        // Calculate distances for remaining sitters
        filtered = filtered.map { sitter in
            var updatedSitter = sitter
            if let sitterLocation = sitter.location, let bookingLocation = criteria.bookingLocation {
                updatedSitter = AssignableSitter(
                    id: sitter.id,
                    name: sitter.name,
                    email: sitter.email,
                    isActive: sitter.isActive,
                    petTypes: sitter.petTypes,
                    availability: sitter.availability,
                    location: sitter.location,
                    rating: sitter.rating,
                    totalBookings: sitter.totalBookings,
                    distance: sitterLocation.distance(from: bookingLocation) / 1000, // Convert to km
                    lastAssigned: sitter.lastAssigned,
                    isAvailable: sitter.isAvailable
                )
            }
            return updatedSitter
        }
        
        // Filter by distance (max 50km radius)
        filtered = filtered.filter { sitter in
            guard let distance = sitter.distance else { return true } // Include sitters without location
            return distance <= 50.0
        }
        
        return filtered
    }
    
    // MARK: - Score and Rank Sitters
    private func scoreAndRankSitters(_ sitters: [AssignableSitter], criteria: AssignmentCriteria) -> [AssignableSitter] {
        let scoredSitters = sitters.map { sitter in
            let score = calculateSitterScore(sitter, criteria: criteria)
            return (sitter: sitter, score: score)
        }
        
        // Sort by score (highest first)
        let sortedSitters = scoredSitters.sorted { $0.score > $1.score }
        
        return sortedSitters.map { $0.sitter }
    }
    
    // MARK: - Calculate Sitter Score
    private func calculateSitterScore(_ sitter: AssignableSitter, criteria: AssignmentCriteria) -> Double {
        var score: Double = 0.0
        
        // Rating score (0-40 points)
        score += sitter.rating * 8.0
        
        // Experience score (0-20 points)
        let experienceScore = min(Double(sitter.totalBookings) / 10.0, 20.0)
        score += experienceScore
        
        // Distance score (0-30 points, closer is better)
        if let distance = sitter.distance {
            let distanceScore = max(30.0 - distance, 0.0) // 30 points for 0km, decreasing
            score += distanceScore
        } else {
            score += 15.0 // Half points if no location data
        }
        
        // Pet type match bonus (0-10 points)
        let petTypeMatches = criteria.petTypes.filter { petType in
            sitter.petTypes.contains(petType.lowercased())
        }.count
        score += Double(petTypeMatches) * 2.5
        
        // Preferred sitter bonus
        if let preferredSitterId = criteria.preferredSitterId,
           sitter.id == preferredSitterId {
            score += 50.0 // Big bonus for preferred sitter
        }
        
        // Workload balance (prefer sitters who haven't been assigned recently)
        if let lastAssigned = sitter.lastAssigned {
            let daysSinceLastAssignment = Date().timeIntervalSince(lastAssigned) / (24 * 3600)
            score += min(daysSinceLastAssignment * 2.0, 20.0) // Up to 20 points for rest
        } else {
            score += 25.0 // Bonus for never assigned
        }
        
        return score
    }
    
    // MARK: - Calculate Assignment Confidence
    private func calculateConfidence(for sitter: AssignableSitter, criteria: AssignmentCriteria) -> Double {
        var confidence: Double = 0.5 // Base confidence
        
        // High rating increases confidence
        if sitter.rating >= 4.5 {
            confidence += 0.2
        } else if sitter.rating >= 4.0 {
            confidence += 0.1
        }
        
        // Experience increases confidence
        if sitter.totalBookings >= 20 {
            confidence += 0.2
        } else if sitter.totalBookings >= 10 {
            confidence += 0.1
        }
        
        // Close distance increases confidence
        if let distance = sitter.distance, distance <= 10.0 {
            confidence += 0.1
        }
        
        // Perfect pet type match increases confidence
        let allPetTypesMatch = criteria.petTypes.allSatisfy { petType in
            sitter.petTypes.contains(petType.lowercased())
        }
        if allPetTypesMatch {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Generate Assignment Reasons
    private func generateAssignmentReasons(for sitter: AssignableSitter, criteria: AssignmentCriteria) -> [String] {
        var reasons: [String] = []
        
        if sitter.rating >= 4.5 {
            reasons.append("High rating (\(String(format: "%.1f", sitter.rating)))")
        }
        
        if sitter.totalBookings >= 10 {
            reasons.append("Experienced (\(sitter.totalBookings) bookings)")
        }
        
        if let distance = sitter.distance, distance <= 10.0 {
            reasons.append("Close location (\(String(format: "%.1f", distance))km away)")
        }
        
        let petTypeMatches = criteria.petTypes.filter { petType in
            sitter.petTypes.contains(petType.lowercased())
        }
        if !petTypeMatches.isEmpty {
            reasons.append("Handles \(petTypeMatches.joined(separator: ", "))")
        }
        
        if let preferredSitterId = criteria.preferredSitterId,
           sitter.id == preferredSitterId {
            reasons.append("Client's preferred sitter")
        }
        
        return reasons
    }
    
    // MARK: - Assign Sitter to Booking
    private func assignSitterToBooking(sitterId: String, bookingId: String) async -> Bool {
        do {
            // Update booking with sitter assignment
            try await db.collection("bookings").document(bookingId).setData([
                "sitterId": sitterId,
                "assignedAt": FieldValue.serverTimestamp(),
                "assignmentMethod": "aiAutomatic",
                "status": "assigned",
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
            
            // Create assignment record
            try await db.collection("assignments").document(bookingId).setData([
                "bookingId": bookingId,
                "sitterId": sitterId,
                "assignedAt": FieldValue.serverTimestamp(),
                "method": "aiAutomatic",
                "status": "active"
            ])
            
            // Update sitter's last assigned date
            try await db.collection("users").document(sitterId).setData([
                "lastAssignedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            AppLogger.ui.info("Successfully assigned sitter \(sitterId) to booking \(bookingId)")
            return true
            
        } catch {
            AppLogger.ui.error("Failed to assign sitter \(sitterId) to booking \(bookingId): \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Handle Sitter Unavailability
    func handleSitterUnavailable(sitterId: String, bookingId: String) async {
        do {
            // Mark assignment as cancelled
            try await db.collection("assignments").document(bookingId).setData([
                "status": "cancelled",
                "cancelledAt": FieldValue.serverTimestamp(),
                "reason": "sitterUnavailable"
            ], merge: true)
            
            // Reset booking status
            try await db.collection("bookings").document(bookingId).setData([
                "sitterId": FieldValue.delete(),
                "assignedAt": FieldValue.delete(),
                "assignmentMethod": FieldValue.delete(),
                "status": "pending",
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
            
            AppLogger.ui.info("Handled sitter unavailability for booking \(bookingId)")
            
        } catch {
            AppLogger.ui.error("Failed to handle sitter unavailability: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Future AI Integration Hooks
    
    /// Hook for future Firebase Functions AI integration
    /// This method can be upgraded to call Firebase Functions for ML-based assignment
    func assignBestSitterWithAI(for criteria: AssignmentCriteria) async -> AssignmentResult {
        // For now, use rule-based assignment
        // In the future, this can be upgraded to call Firebase Functions
        
        // TODO: Implement Firebase Functions call for AI-based assignment
        // Example:
        // let aiResult = try await callFirebaseFunction("aiSitterAssignment", data: criteria)
        // return processAIResult(aiResult)
        
        return await assignBestSitter(for: criteria)
    }
    
    /// Prepare data for future AI model training
    func logAssignmentForTraining(result: AssignmentResult, feedback: AssignmentFeedback? = nil) async {
        do {
            var trainingData: [String: Any] = [
                "bookingId": result.bookingId,
                "sitterId": result.sitterId ?? "",
                "assignmentMethod": result.assignmentMethod.rawValue,
                "confidence": result.confidence,
                "reasons": result.reasons,
                "timestamp": result.timestamp
            ]
            
            if let feedback = feedback {
                trainingData["feedback"] = [
                    "rating": feedback.rating,
                    "comments": feedback.comments,
                    "success": feedback.wasSuccessful
                ]
            }
            
            try await db.collection("assignmentTraining").addDocument(data: trainingData)
            
        } catch {
            AppLogger.ui.error("Failed to log assignment for training: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types
struct SitterAvailability {
    let isAvailable: Bool
    let activeHours: [String: [String: Bool]] // dayOfWeek -> hour -> isAvailable
    let blockedDates: [String] // ISO date strings
}

struct AssignmentFeedback {
    let rating: Double // 1-5 stars
    let comments: String
    let wasSuccessful: Bool
}

// MARK: - Assignment Method Extension
extension AISitterAssignmentService.AssignmentResult.AssignmentMethod {
    var rawValue: String {
        switch self {
        case .aiAutomatic: return "aiAutomatic"
        case .ruleBased: return "ruleBased"
        case .adminManual: return "adminManual"
        case .failed: return "failed"
        }
    }
}
