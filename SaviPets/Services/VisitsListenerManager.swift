import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import OSLog

/// Centralized manager for all visits collection listeners to prevent Firebase accumulator conflicts
@MainActor
final class VisitsListenerManager: ObservableObject {
    static let shared = VisitsListenerManager()
    
    @Published private(set) var allVisits: [Visit] = []
    @Published private(set) var inProgressVisits: [Visit] = []
    @Published private(set) var sitterVisits: [String: [Visit]] = [:] // Key: sitterId, Value: visits for that sitter
    @Published private(set) var error: Error?
    
    private let db = Firestore.firestore()
    private var mainListener: ListenerRegistration?
    
    nonisolated private init() {
        Task { @MainActor in
            startMainListener()
        }
    }
    
    /// Restart listener after authentication
    func restartAfterAuth() {
        AppLogger.data.info("VisitsListenerManager: Restarting after authentication")
        startMainListener()
    }
    
    // MARK: - Visit Model
    struct Visit: Identifiable, Equatable {
        let id: String
        let sitterId: String
        let sitterName: String
        let clientName: String
        let address: String
        let note: String
        let serviceSummary: String
        let pets: [String]
        let petPhotoURLs: [String]
        let status: String
        let scheduledStart: Date
        let scheduledEnd: Date
        let checkInTimestamp: Date?
        let checkOutTimestamp: Date?
        
        init?(id: String, data: [String: Any]) {
            guard let sitterId = data["sitterId"] as? String,
                  let scheduledStartTimestamp = data["scheduledStart"] as? Timestamp else {
                return nil
            }
            
            self.id = id
            self.sitterId = sitterId
            self.sitterName = data["sitterName"] as? String ?? "Sitter"
            self.clientName = data["clientName"] as? String ?? ""
            self.address = data["address"] as? String ?? ""
            self.note = data["note"] as? String ?? ""
            self.serviceSummary = data["serviceSummary"] as? String ?? ""
            self.pets = data["pets"] as? [String] ?? []
            self.petPhotoURLs = data["petPhotoURLs"] as? [String] ?? []
            self.status = data["status"] as? String ?? "scheduled"
            self.scheduledStart = scheduledStartTimestamp.dateValue()
            self.scheduledEnd = (data["scheduledEnd"] as? Timestamp)?.dateValue() ?? scheduledStartTimestamp.dateValue()
            
            // Extract timeline timestamps
            if let timeline = data["timeline"] as? [String: Any] {
                self.checkInTimestamp = ((timeline["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                self.checkOutTimestamp = ((timeline["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
            } else {
                self.checkInTimestamp = nil
                self.checkOutTimestamp = nil
            }
        }
    }
    
    deinit {
        mainListener?.remove()
        // Swift 6 concurrency: Access MainActor-isolated property safely
        Task { @MainActor in
            AppLogger.data.info("VisitsListenerManager deallocated")
        }
    }
    
    /// Start the main listener that handles all visits
    private func startMainListener() {
        mainListener?.remove()
        
        // Check if user is authenticated before starting listener
        guard Auth.auth().currentUser != nil else {
            AppLogger.data.warning("VisitsListenerManager: No authenticated user, skipping listener setup")
            return
        }
        
        mainListener = db.collection("visits")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        self.error = error
                        AppLogger.data.error("Error in visits listener: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        AppLogger.data.info("📍 VisitsListenerManager: No documents in snapshot")
                        return
                    }
                    
                    AppLogger.data.info("📍 VisitsListenerManager: Received \(documents.count) visits")
                    
                    let allVisits = documents.compactMap { doc in
                        let visit = Visit(id: doc.documentID, data: doc.data())
                        if let v = visit {
                            AppLogger.data.info("📍 Visit \(v.id): status=\(v.status), sitter=\(v.sitterName)")
                        }
                        return visit
                    }
                    
                    AppLogger.data.info("📍 Parsed \(allVisits.count) valid visits")
                    
                    self.allVisits = allVisits
                    self.updateFilteredData()
                    
                    AppLogger.data.info("📍 Active visits after filter: \(self.inProgressVisits.count)")
                }
            }
    }
    
    /// Update filtered data based on current filters
    private func updateFilteredData() {
        // Filter in-progress visits
        // Match the statuses used in the app: "in_adventure" is the primary active status
        inProgressVisits = allVisits.filter { visit in
            let isActive = visit.status == "in_progress" || visit.status == "in_adventure"
            if isActive {
                AppLogger.data.info("📍 Active visit found: \(visit.id) - \(visit.status)")
            }
            return isActive
        }
        
        AppLogger.data.info("📍 Total in-progress visits: \(self.inProgressVisits.count)")
        
        // Group visits by sitter
        var sitterGroups: [String: [Visit]] = [:]
        for visit in allVisits {
            sitterGroups[visit.sitterId, default: []].append(visit)
        }
        sitterVisits = sitterGroups
    }
    
    /// Get visits for a specific sitter on a specific day
    func getVisitsForSitter(_ sitterId: String, on day: Date) -> [Visit] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? day
        
        return sitterVisits[sitterId]?.filter { visit in
            visit.scheduledStart >= dayStart && visit.scheduledStart < dayEnd
        } ?? []
    }
    
    /// Get all in-progress visits
    func getInProgressVisits() -> [Visit] {
        return inProgressVisits
    }
    
    /// Get all visits (for status synchronization)
    func getAllVisits() -> [Visit] {
        return allVisits
    }
}

