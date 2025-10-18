import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog
import Combine
import SwiftUI

/// Service for managing waitlist functionality when bookings are full
@MainActor
final class WaitlistService: ObservableObject {
    @Published var waitlistEntries: [WaitlistEntry] = []
    @Published var isProcessing: Bool = false
    @Published var lastUpdated: Date?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let waitlistCollection = "waitlist"
    
    // Real-time listener
    private var waitlistListener: ListenerRegistration?
    
    init() {
        setupRealTimeListener()
    }
    
    deinit {
        waitlistListener?.remove()
    }
    
    // MARK: - Real-time Listener
    private func setupRealTimeListener() {
        waitlistListener = db.collection(waitlistCollection)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    AppLogger.data.error("Waitlist listener error: \(error.localizedDescription)")
                    return
                }
                
                Task { @MainActor in
                    self.waitlistEntries = snapshot?.documents.compactMap { doc in
                        self.parseWaitlistEntryFromDocument(doc)
                    } ?? []
                    self.lastUpdated = Date()
                }
            }
    }
    
    // MARK: - Waitlist Management
    func addToWaitlist(
        serviceType: String,
        requestedDate: Date,
        requestedTime: String,
        duration: Int,
        pets: [String],
        specialInstructions: String?,
        clientId: String,
        clientName: String,
        clientPhone: String?,
        clientEmail: String
    ) async -> Result<WaitlistEntry, WaitlistError> {
        
        isProcessing = true
        
        do {
            // Check if already on waitlist for same time slot
            let existingEntry = await checkExistingWaitlistEntry(
                clientId: clientId,
                serviceType: serviceType,
                requestedDate: requestedDate,
                requestedTime: requestedTime
            )
            
            if existingEntry != nil {
                isProcessing = false
                return .failure(.alreadyOnWaitlist)
            }
            
            // Create waitlist entry
            let entry = WaitlistEntry(
                id: UUID().uuidString,
                clientId: clientId,
                clientName: clientName,
                clientPhone: clientPhone,
                clientEmail: clientEmail,
                serviceType: serviceType,
                requestedDate: requestedDate,
                requestedTime: requestedTime,
                duration: duration,
                pets: pets,
                specialInstructions: specialInstructions,
                status: .waiting,
                priority: await calculatePriority(for: clientId),
                estimatedWaitTime: await calculateEstimatedWaitTime(for: serviceType, date: requestedDate),
                createdAt: Date(),
                lastModified: Date(),
                notificationsSent: [],
                contactPreferences: ContactPreferences(
                    email: true,
                    phone: clientPhone != nil,
                    push: true
                )
            )
            
            // Save to Firestore
            try await db.collection(waitlistCollection).document(entry.id).setData(entry.toFirestoreData())
            
            // Send confirmation notification
            await sendWaitlistConfirmation(entry)
            
            AppLogger.data.info("Added client \(clientId) to waitlist for \(serviceType)")
            
            isProcessing = false
            return .success(entry)
            
        } catch {
            isProcessing = false
            AppLogger.data.error("Failed to add to waitlist: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    func removeFromWaitlist(_ entryId: String) async -> Result<Void, WaitlistError> {
        isProcessing = true
        
        do {
            try await db.collection(waitlistCollection).document(entryId).delete()
            
            AppLogger.data.info("Removed waitlist entry \(entryId)")
            
            isProcessing = false
            return .success(())
            
        } catch {
            isProcessing = false
            AppLogger.data.error("Failed to remove from waitlist: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    func updateWaitlistEntry(_ entry: WaitlistEntry) async -> Result<WaitlistEntry, WaitlistError> {
        isProcessing = true
        
        do {
            var updatedEntry = entry
            updatedEntry.lastModified = Date()
            
            try await db.collection(waitlistCollection).document(entry.id).updateData(updatedEntry.toFirestoreData())
            
            AppLogger.data.info("Updated waitlist entry \(entry.id)")
            
            isProcessing = false
            return .success(updatedEntry)
            
        } catch {
            isProcessing = false
            AppLogger.data.error("Failed to update waitlist entry: \(error.localizedDescription)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }
    
    // MARK: - Waitlist Processing
    func processWaitlistForTimeSlot(serviceType: String, date: Date, time: String) async {
        // Find available waitlist entries for this time slot
        let availableEntries = waitlistEntries.filter { entry in
            entry.serviceType == serviceType &&
            Calendar.current.isDate(entry.requestedDate, inSameDayAs: date) &&
            entry.requestedTime == time &&
            entry.status == .waiting
        }
        
        // Sort by priority and creation time
        let sortedEntries = availableEntries.sorted { entry1, entry2 in
            if entry1.priority != entry2.priority {
                return entry1.priority > entry2.priority
            }
            return entry1.createdAt < entry2.createdAt
        }
        
        // Process the first entry
        if let topEntry = sortedEntries.first {
            await promoteWaitlistEntry(topEntry)
        }
    }
    
    private func promoteWaitlistEntry(_ entry: WaitlistEntry) async {
        do {
            // Update waitlist entry status
            var updatedEntry = entry
            updatedEntry.status = .promoted
            updatedEntry.promotedAt = Date()
            updatedEntry.lastModified = Date()
            
            try await db.collection(waitlistCollection).document(entry.id).updateData(updatedEntry.toFirestoreData())
            
            // Create booking from waitlist entry
            let booking = createBookingFromWaitlistEntry(entry)
            try await createBookingFromWaitlist(booking)
            
            // Send notification to client
            await sendWaitlistPromotionNotification(entry)
            
            AppLogger.data.info("Promoted waitlist entry \(entry.id) to booking")
            
        } catch {
            AppLogger.data.error("Failed to promote waitlist entry: \(error.localizedDescription)")
        }
    }
    
    private func createBookingFromWaitlistEntry(_ entry: WaitlistEntry) -> ServiceBooking {
        return ServiceBooking(
            id: UUID().uuidString,
            clientId: entry.clientId,
            serviceType: entry.serviceType,
            scheduledDate: entry.requestedDate,
            scheduledTime: entry.requestedTime,
            duration: entry.duration,
            pets: entry.pets,
            specialInstructions: entry.specialInstructions,
            status: .pending,
            sitterId: nil,
            sitterName: nil,
            createdAt: Date(),
            address: nil,
            checkIn: nil,
            checkOut: nil,
            price: calculatePrice(for: entry),
            recurringSeriesId: nil,
            visitNumber: nil,
            isRecurring: false,
            paymentStatus: nil,
            paymentTransactionId: nil,
            paymentAmount: nil,
            paymentMethod: nil,
            rescheduledFrom: nil,
            rescheduledAt: nil,
            rescheduledBy: nil,
            rescheduleReason: nil,
            rescheduleHistory: [],
            lastModified: Date(),
            lastModifiedBy: "system",
            modificationReason: "Created from waitlist"
        )
    }
    
    private func createBookingFromWaitlist(_ booking: ServiceBooking) async throws {
        try await db.collection("serviceBookings").document(booking.id).setData(booking.toFirestoreData())
    }
    
    // MARK: - Helper Methods
    private func checkExistingWaitlistEntry(
        clientId: String,
        serviceType: String,
        requestedDate: Date,
        requestedTime: String
    ) async -> WaitlistEntry? {
        
        let snapshot = try? await db.collection(waitlistCollection)
            .whereField("clientId", isEqualTo: clientId)
            .whereField("serviceType", isEqualTo: serviceType)
            .whereField("requestedDate", isEqualTo: Timestamp(date: requestedDate))
            .whereField("requestedTime", isEqualTo: requestedTime)
            .whereField("status", isEqualTo: "waiting")
            .limit(to: 1)
            .getDocuments()
        
        return snapshot?.documents.first.map { parseWaitlistEntryFromDocument($0) } ?? nil
    }
    
    private func calculatePriority(for clientId: String) async -> Int {
        // Calculate priority based on client history, loyalty, etc.
        do {
            let clientBookings = try await db.collection("serviceBookings")
                .whereField("clientId", isEqualTo: clientId)
                .whereField("status", isEqualTo: "completed")
                .getDocuments()
            
            let completedBookings = clientBookings.documents.count
            
            // Higher priority for loyal customers
            if completedBookings >= 10 {
                return 100
            } else if completedBookings >= 5 {
                return 75
            } else if completedBookings >= 1 {
                return 50
            } else {
                return 25
            }
            
        } catch {
            AppLogger.data.error("Failed to calculate priority: \(error.localizedDescription)")
            return 25 // Default priority
        }
    }
    
    private func calculateEstimatedWaitTime(for serviceType: String, date: Date) async -> TimeInterval {
        // Calculate estimated wait time based on historical data
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let snapshot = try await db.collection("serviceBookings")
                .whereField("serviceType", isEqualTo: serviceType)
                .whereField("scheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("scheduledDate", isLessThan: Timestamp(date: endOfDay))
                .getDocuments()
            
            let bookingsCount = snapshot.documents.count
            
            // Estimate wait time based on booking density
            if bookingsCount < 5 {
                return 0 // Immediate availability likely
            } else if bookingsCount < 10 {
                return 2 * 60 * 60 // 2 hours
            } else if bookingsCount < 20 {
                return 6 * 60 * 60 // 6 hours
            } else {
                return 24 * 60 * 60 // 24 hours
            }
            
        } catch {
            AppLogger.data.error("Failed to calculate wait time: \(error.localizedDescription)")
            return 2 * 60 * 60 // Default 2 hours
        }
    }
    
    private func calculatePrice(for entry: WaitlistEntry) -> String {
        // Calculate price based on service type and duration
        let basePrice: Double
        switch entry.serviceType.lowercased() {
        case "dog walking":
            basePrice = 25.0
        case "pet sitting":
            basePrice = 50.0
        case "grooming":
            basePrice = 75.0
        default:
            basePrice = 30.0
        }
        
        let durationMultiplier = Double(entry.duration) / 60.0
        let totalPrice = basePrice * durationMultiplier
        
        return String(format: "%.2f", totalPrice)
    }
    
    private func parseWaitlistEntryFromDocument(_ document: QueryDocumentSnapshot) -> WaitlistEntry? {
        let data = document.data()
        
        guard let clientId = data["clientId"] as? String,
              let clientName = data["clientName"] as? String,
              let clientEmail = data["clientEmail"] as? String,
              let serviceType = data["serviceType"] as? String,
              let requestedDateTimestamp = data["requestedDate"] as? Timestamp,
              let requestedTime = data["requestedTime"] as? String,
              let duration = data["duration"] as? Int,
              let pets = data["pets"] as? [String],
              let statusString = data["status"] as? String,
              let status = WaitlistStatus(rawValue: statusString),
              let priority = data["priority"] as? Int,
              let estimatedWaitTime = data["estimatedWaitTime"] as? Double,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let lastModifiedTimestamp = data["lastModified"] as? Timestamp else {
            return nil
        }
        
        let requestedDate = requestedDateTimestamp.dateValue()
        let createdAt = createdAtTimestamp.dateValue()
        let lastModified = lastModifiedTimestamp.dateValue()
        
        // Parse contact preferences
        let contactPrefsData = data["contactPreferences"] as? [String: Any] ?? [:]
        let contactPreferences = ContactPreferences(
            email: contactPrefsData["email"] as? Bool ?? true,
            phone: contactPrefsData["phone"] as? Bool ?? false,
            push: contactPrefsData["push"] as? Bool ?? true
        )
        
        // Parse notifications sent
        let notificationsSent = data["notificationsSent"] as? [[String: Any]] ?? []
        
        return WaitlistEntry(
            id: document.documentID,
            clientId: clientId,
            clientName: clientName,
            clientPhone: data["clientPhone"] as? String,
            clientEmail: clientEmail,
            serviceType: serviceType,
            requestedDate: requestedDate,
            requestedTime: requestedTime,
            duration: duration,
            pets: pets,
            specialInstructions: data["specialInstructions"] as? String,
            status: status,
            priority: priority,
            estimatedWaitTime: estimatedWaitTime,
            createdAt: createdAt,
            lastModified: lastModified,
            notificationsSent: notificationsSent.compactMap { NotificationRecord.fromFirestoreData($0) },
            contactPreferences: contactPreferences,
            promotedAt: (data["promotedAt"] as? Timestamp)?.dateValue()
        )
    }
    
    // MARK: - Notifications
    private func sendWaitlistConfirmation(_ entry: WaitlistEntry) async {
        let notificationService = NotificationService.shared
        
        await notificationService.sendLocalNotification(
            title: "Added to Waitlist",
            body: "You've been added to the waitlist for \(entry.serviceType) on \(entry.requestedDate.formatted(date: .abbreviated, time: .omitted))",
            userInfo: [
                "type": "waitlist_confirmation",
                "waitlistId": entry.id,
                "serviceType": entry.serviceType
            ]
        )
    }
    
    private func sendWaitlistPromotionNotification(_ entry: WaitlistEntry) async {
        let notificationService = NotificationService.shared
        
        await notificationService.sendLocalNotification(
            title: "Booking Available!",
            body: "Great news! A spot opened up for your \(entry.serviceType) request. Please confirm your booking.",
            userInfo: [
                "type": "waitlist_promotion",
                "waitlistId": entry.id,
                "serviceType": entry.serviceType
            ]
        )
    }
    
    // MARK: - Public Methods
    func getWaitlistForService(_ serviceType: String, date: Date) -> [WaitlistEntry] {
        return waitlistEntries.filter { entry in
            entry.serviceType == serviceType &&
            Calendar.current.isDate(entry.requestedDate, inSameDayAs: date) &&
            entry.status == .waiting
        }
    }
    
    func getWaitlistForClient(_ clientId: String) -> [WaitlistEntry] {
        return waitlistEntries.filter { $0.clientId == clientId }
    }
    
    func getEstimatedPosition(_ entryId: String) -> Int {
        guard let entry = waitlistEntries.first(where: { $0.id == entryId }) else {
            return 0
        }
        
        let sameSlotEntries = waitlistEntries.filter { otherEntry in
            otherEntry.serviceType == entry.serviceType &&
            Calendar.current.isDate(otherEntry.requestedDate, inSameDayAs: entry.requestedDate) &&
            otherEntry.requestedTime == entry.requestedTime &&
            otherEntry.status == .waiting &&
            (otherEntry.priority > entry.priority || 
             (otherEntry.priority == entry.priority && otherEntry.createdAt < entry.createdAt))
        }
        
        return sameSlotEntries.count + 1
    }
}

// MARK: - Supporting Models
struct WaitlistEntry: Codable, Identifiable {
    let id: String
    let clientId: String
    let clientName: String
    let clientPhone: String?
    let clientEmail: String
    let serviceType: String
    let requestedDate: Date
    let requestedTime: String
    let duration: Int
    let pets: [String]
    let specialInstructions: String?
    var status: WaitlistStatus
    let priority: Int
    let estimatedWaitTime: TimeInterval
    let createdAt: Date
    var lastModified: Date
    var notificationsSent: [NotificationRecord]
    let contactPreferences: ContactPreferences
    var promotedAt: Date?
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "clientId": clientId,
            "clientName": clientName,
            "clientEmail": clientEmail,
            "serviceType": serviceType,
            "requestedDate": Timestamp(date: requestedDate),
            "requestedTime": requestedTime,
            "duration": duration,
            "pets": pets,
            "status": status.rawValue,
            "priority": priority,
            "estimatedWaitTime": estimatedWaitTime,
            "createdAt": Timestamp(date: createdAt),
            "lastModified": Timestamp(date: lastModified),
            "notificationsSent": notificationsSent.map { $0.toFirestoreData() },
            "contactPreferences": [
                "email": contactPreferences.email,
                "phone": contactPreferences.phone,
                "push": contactPreferences.push
            ]
        ]
        
        if let clientPhone = clientPhone {
            data["clientPhone"] = clientPhone
        }
        
        if let specialInstructions = specialInstructions {
            data["specialInstructions"] = specialInstructions
        }
        
        if let promotedAt = promotedAt {
            data["promotedAt"] = Timestamp(date: promotedAt)
        }
        
        return data
    }
}

enum WaitlistStatus: String, Codable, CaseIterable {
    case waiting = "waiting"
    case promoted = "promoted"
    case cancelled = "cancelled"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .waiting: return "Waiting"
        case .promoted: return "Promoted"
        case .cancelled: return "Cancelled"
        case .expired: return "Expired"
        }
    }
    
    var color: Color {
        switch self {
        case .waiting: return .orange
        case .promoted: return .green
        case .cancelled: return .red
        case .expired: return .gray
        }
    }
}

struct ContactPreferences: Codable {
    let email: Bool
    let phone: Bool
    let push: Bool
}

struct NotificationRecord: Codable {
    let type: String
    let sentAt: Date
    let success: Bool
    let errorMessage: String?
    
    static func fromFirestoreData(_ data: [String: Any]) -> NotificationRecord? {
        guard let type = data["type"] as? String,
              let sentAtTimestamp = data["sentAt"] as? Timestamp,
              let success = data["success"] as? Bool else {
            return nil
        }
        
        return NotificationRecord(
            type: type,
            sentAt: sentAtTimestamp.dateValue(),
            success: success,
            errorMessage: data["errorMessage"] as? String
        )
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "type": type,
            "sentAt": Timestamp(date: sentAt),
            "success": success
        ]
        
        if let errorMessage = errorMessage {
            data["errorMessage"] = errorMessage
        }
        
        return data
    }
}

enum WaitlistError: Error, LocalizedError {
    case alreadyOnWaitlist
    case databaseError(String)
    case invalidEntry
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .alreadyOnWaitlist:
            return "You are already on the waitlist for this time slot"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .invalidEntry:
            return "Invalid waitlist entry"
        case .networkError:
            return "Network connection error"
        }
    }
}
