import Foundation
import OSLog
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Payment Status
enum PaymentStatus: String, CaseIterable, Codable {
    case confirmed = "confirmed"
    case declined = "declined"
    case failed = "failed"
    case pending = "pending"
}

// MARK: - Service Booking Models

struct CancellationResult {
    let success: Bool
    let refundEligible: Bool
    let refundPercentage: Double
    let refundAmount: Double
    let hoursUntilVisit: Double
    
    var refundMessage: String {
        if !refundEligible {
            return "No refund available (less than 24 hours notice)"
        } else if refundPercentage == 1.0 {
            return "Full refund: $\(String(format: "%.2f", refundAmount)) (7+ days notice)"
        } else if refundPercentage == 0.5 {
            return "50% refund: $\(String(format: "%.2f", refundAmount)) (24h-7days notice)"
        } else {
            return "Refund: $\(String(format: "%.2f", refundAmount))"
        }
    }
}

struct ServiceBooking: Identifiable, Codable {
    let id: String
    let clientId: String
    let serviceType: String
    let scheduledDate: Date
    let scheduledTime: String
    let duration: Int // minutes
    let pets: [String] // pet names
    let specialInstructions: String?
    let status: BookingStatus
    let sitterId: String?
    let sitterName: String?
    let createdAt: Date
    let address: String?
    let checkIn: Date?
    let checkOut: Date?
    let price: String
    
    // Recurring booking tracking
    let recurringSeriesId: String?
    let visitNumber: Int?
    let isRecurring: Bool
    
    // Payment tracking
    let paymentStatus: PaymentStatus?
    let paymentTransactionId: String?
    let paymentAmount: Double?
    let paymentMethod: String?
    
    // Rescheduling tracking (Phase 1 enhancement)
    let rescheduledFrom: Date?
    let rescheduledAt: Date?
    let rescheduledBy: String?
    let rescheduleReason: String?
    let rescheduleHistory: [RescheduleEntry]
    let lastModified: Date?
    let lastModifiedBy: String?
    let modificationReason: String?

    enum BookingStatus: String, CaseIterable, Codable {
        case pending = "pending"
        case approved = "approved"
        case inAdventure = "in_adventure"
        case completed = "completed"
        case cancelled = "cancelled"
        
        var color: Color {
            switch self {
            case .pending: return .orange
            case .approved: return .green
            case .inAdventure: return .purple
            case .completed: return .blue
            case .cancelled: return .red
            }
        }
        
        var displayName: String {
            switch self {
            case .pending: return "Pending Approval"
            case .approved: return "Approved"
            case .inAdventure: return "On an Adventure"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            }
        }
    }
}

// MARK: - Service Data Service
final class ServiceBookingDataService: ObservableObject {
    @Published var userBookings: [ServiceBooking] = []
    @Published var pendingBookings: [ServiceBooking] = []
    @Published var allBookings: [ServiceBooking] = []

    private let db = Firestore.firestore()
    private var visitStatusListener: ListenerRegistration?
    private var userBookingsListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    deinit {
        // Clean up all listeners to prevent memory leaks and Firebase errors
        visitStatusListener?.remove()
        userBookingsListener?.remove()
        cancellables.removeAll()
        AppLogger.logEvent("ServiceBookingDataServiceDeallocated", logger: .data)
    }

    func createBooking(_ booking: ServiceBooking) async throws {
        let data: [String: Any] = [
            "clientId": booking.clientId,
            "serviceType": booking.serviceType,
            "scheduledDate": Timestamp(date: booking.scheduledDate),
            "scheduledTime": booking.scheduledTime,
            "duration": booking.duration,
            "pets": booking.pets,
            "specialInstructions": booking.specialInstructions ?? "",
            "status": booking.status.rawValue,
            "sitterId": booking.sitterId ?? "",
            "sitterName": booking.sitterName ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "address": booking.address ?? "",
            "price": booking.price,
            "isRecurring": booking.isRecurring
        ]
        
        AppLogger.data.info("📝 Writing booking document with ID: \(booking.id)")
        AppLogger.data.info("📝 Booking data: clientId=\(booking.clientId), serviceType=\(booking.serviceType), price=\(booking.price)")
        
        // CRITICAL: Use setData with the booking's ID, not addDocument!
        // addDocument() generates a random ID, but we need to use the specific booking.id
        // so the Cloud Function can find it
        try await db.collection("serviceBookings").document(booking.id).setData(data)
        
        AppLogger.data.info("✅ Booking document written successfully with ID: \(booking.id)")
        
        // Verify the document was written by reading it back
        let verificationDoc = try await db.collection("serviceBookings").document(booking.id).getDocument()
        if verificationDoc.exists {
            AppLogger.data.info("✅ Booking document verified in Firestore: \(booking.id)")
        } else {
            AppLogger.data.error("❌ Booking document verification failed: \(booking.id)")
            throw NSError(domain: "FirestoreError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Booking document was not written to Firestore"])
        }
        
        // Send notifications to Admin
        await sendBookingNotifications(booking: booking)
    }
    
    /// Send notifications when a booking is created (to Admin)
    private func sendBookingNotifications(booking: ServiceBooking) async {
        // Fetch client name from users collection
        var clientName = "Client"
        do {
            let clientDoc = try await db.collection("users").document(booking.clientId).getDocument()
            if let data = clientDoc.data() {
                let email = data["email"] as? String ?? ""
                let emailFallback = email.split(separator: "@").first.map(String.init) ?? "Client"
                let rawName = (data["displayName"] as? String) ?? (data["name"] as? String) ?? ""
                clientName = rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emailFallback : rawName
            }
        } catch {
            AppLogger.notification.error("Error fetching client name for notification: \(error.localizedDescription)")
        }
        
        // Send booking created notification
        SmartNotificationManager.shared.sendBookingCreatedNotification(
            bookingId: booking.id,
            clientName: clientName,
            clientId: booking.clientId,
            serviceType: booking.serviceType,
            scheduledDate: booking.scheduledDate,
            scheduledTime: booking.scheduledTime,
            pets: booking.pets
        )
        
        // Send booking needs approval notification (since all bookings start with "pending" status)
        if booking.status == .pending {
            SmartNotificationManager.shared.sendBookingNeedsApprovalNotification(
                bookingId: booking.id,
                clientName: clientName,
                clientId: booking.clientId,
                serviceType: booking.serviceType,
                scheduledDate: booking.scheduledDate,
                scheduledTime: booking.scheduledTime
            )
        }
    }

    /// Listen to visit status changes and sync to corresponding bookings
    /// NOTE: This is now handled by Cloud Functions to avoid permission issues
    /// Client-side sync disabled - status updates happen server-side
    func listenToVisitStatusChanges() {
        // DISABLED: This should be handled by Cloud Functions
        // Cloud Function onVisitStatusChange will sync visit → booking status
        // This prevents permission errors on client side
        
        AppLogger.data.info("Visit status sync disabled - handled by Cloud Functions")
        
        // Original implementation moved to Cloud Functions:
        // functions/src/index.ts → onVisitStatusChange
    }
    
    /// Sync booking statuses from visit data
    /// DEPRECATED: Now handled by Cloud Functions
    private func syncBookingStatuses(from visits: [VisitsListenerManager.Visit]) {
        // This method is no longer used
        // Status sync happens via Cloud Function to avoid permission issues
        AppLogger.data.debug("syncBookingStatuses called but disabled - using Cloud Functions")
    }
    
    func listenToUserBookings(userId: String) {
        // Remove existing listener to prevent duplicates
        userBookingsListener?.remove()
        
        userBookingsListener = db.collection("serviceBookings")
            .whereField("clientId", isEqualTo: userId)
            .order(by: "scheduledDate", descending: false)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot = snapshot else { return }
                
                // CRITICAL FIX: Process documentChanges for deletions
                var current = self?.userBookings ?? []
                
                for change in snapshot.documentChanges {
                    let doc = change.document
                    let docId = doc.documentID
                    
                    switch change.type {
                    case .added, .modified:
                        let booking = self?.parseBookingFromDocument(doc)
                        if let booking = booking {
                            current.removeAll { $0.id == docId }
                            current.append(booking)
                        }
                        
                    case .removed:
                        current.removeAll { $0.id == docId }
                    }
                }
                
                current.sort { $0.scheduledDate < $1.scheduledDate }
                self?.userBookings = current
            }
    }
    
    // MARK: - Old listenToUserBookings (now replaced above)
    private func oldListenToUserBookings_REMOVED() {
        userBookingsListener = db.collection("serviceBookings")
            .whereField("clientId", isEqualTo: "userId")
            .order(by: "scheduledDate", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self?.userBookings = documents.compactMap { doc in
                    let data = doc.data()
                    let duration: Int = (data["duration"] as? Int)
                        ?? (data["duration"] as? Double).map { Int($0) } ?? 30
                    let timeline = data["timeline"] as? [String: Any]
                    let checkIn = ((timeline?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    let checkOut = ((timeline?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    
                    // Parse reschedule history
                    let rescheduleHistoryData = data["rescheduleHistory"] as? [[String: Any]] ?? []
                    let rescheduleHistory = rescheduleHistoryData.compactMap { RescheduleEntry.fromFirestoreData($0) }
                    
                    return ServiceBooking(
                        id: doc.documentID,
                        clientId: data["clientId"] as? String ?? "",
                        serviceType: data["serviceType"] as? String ?? "",
                        scheduledDate: (data["scheduledDate"] as? Timestamp)?.dateValue() ?? Date(),
                        scheduledTime: data["scheduledTime"] as? String ?? "",
                        duration: duration,
                        pets: data["pets"] as? [String] ?? [],
                        specialInstructions: (data["specialInstructions"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        status: ServiceBooking.BookingStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
                        sitterId: (data["sitterId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        sitterName: (data["sitterName"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        address: (data["address"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        checkIn: checkIn,
                        checkOut: checkOut,
                        price: data["price"] as? String ?? "0",
                        recurringSeriesId: (data["recurringSeriesId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        visitNumber: data["visitNumber"] as? Int,
                        isRecurring: data["isRecurring"] as? Bool ?? false,
                        paymentStatus: PaymentStatus(rawValue: data["paymentStatus"] as? String ?? ""),
                        paymentTransactionId: (data["paymentTransactionId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        paymentAmount: data["paymentAmount"] as? Double,
                        paymentMethod: (data["paymentMethod"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        // Rescheduling tracking fields
                        rescheduledFrom: (data["rescheduledFrom"] as? Timestamp)?.dateValue(),
                        rescheduledAt: (data["rescheduledAt"] as? Timestamp)?.dateValue(),
                        rescheduledBy: (data["rescheduledBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        rescheduleReason: (data["rescheduleReason"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        rescheduleHistory: rescheduleHistory,
                        lastModified: (data["lastModified"] as? Timestamp)?.dateValue(),
                        lastModifiedBy: (data["lastModifiedBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        modificationReason: (data["modificationReason"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    )
                }
            }
    }

    func listenToPendingBookings() {
        db.collection("serviceBookings")
            .whereField("status", isEqualTo: ServiceBooking.BookingStatus.pending.rawValue)
            .order(by: "createdAt", descending: false)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot = snapshot else { return }
                
                // CRITICAL FIX: Process documentChanges to handle deletions/cancellations
                var current = self?.pendingBookings ?? []
                
                for change in snapshot.documentChanges {
                    let doc = change.document
                    let docId = doc.documentID
                    
                    switch change.type {
                    case .added, .modified:
                        // Parse booking
                        let booking = self?.parseBookingFromDocument(doc)
                        if let booking = booking {
                            current.removeAll { $0.id == docId }
                            current.append(booking)
                        }
                        
                    case .removed:
                        // ✅ DELETION/CANCELLATION DETECTED
                        current.removeAll { $0.id == docId }
                    }
                }
                
                // Sort by creation date
                current.sort { $0.createdAt < $1.createdAt }
                self?.pendingBookings = current
            }
    }
    
    // MARK: - Helper to Parse Booking from Document
    private func parseBookingFromDocument(_ doc: QueryDocumentSnapshot) -> ServiceBooking? {
        let data = doc.data()
        let duration: Int = (data["duration"] as? Int)
            ?? (data["duration"] as? Double).map { Int($0) } ?? 30
        let timeline = data["timeline"] as? [String: Any]
        let checkIn = ((timeline?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
        let checkOut = ((timeline?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
        
        // Parse reschedule history
        let rescheduleHistoryData = data["rescheduleHistory"] as? [[String: Any]] ?? []
        let rescheduleHistory = rescheduleHistoryData.compactMap { RescheduleEntry.fromFirestoreData($0) }
        
        return ServiceBooking(
            id: doc.documentID,
            clientId: data["clientId"] as? String ?? "",
            serviceType: data["serviceType"] as? String ?? "",
            scheduledDate: (data["scheduledDate"] as? Timestamp)?.dateValue() ?? Date(),
            scheduledTime: data["scheduledTime"] as? String ?? "",
            duration: duration,
            pets: data["pets"] as? [String] ?? [],
            specialInstructions: (data["specialInstructions"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            status: ServiceBooking.BookingStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
            sitterId: (data["sitterId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            sitterName: (data["sitterName"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            address: (data["address"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            checkIn: checkIn,
            checkOut: checkOut,
            price: data["price"] as? String ?? "0",
            recurringSeriesId: (data["recurringSeriesId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            visitNumber: data["visitNumber"] as? Int,
            isRecurring: data["isRecurring"] as? Bool ?? false,
            paymentStatus: PaymentStatus(rawValue: data["paymentStatus"] as? String ?? ""),
            paymentTransactionId: (data["paymentTransactionId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            paymentAmount: data["paymentAmount"] as? Double,
            paymentMethod: (data["paymentMethod"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            // Rescheduling tracking fields
            rescheduledFrom: (data["rescheduledFrom"] as? Timestamp)?.dateValue(),
            rescheduledAt: (data["rescheduledAt"] as? Timestamp)?.dateValue(),
            rescheduledBy: (data["rescheduledBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            rescheduleReason: (data["rescheduleReason"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            rescheduleHistory: rescheduleHistory,
            lastModified: (data["lastModified"] as? Timestamp)?.dateValue(),
            lastModifiedBy: (data["lastModifiedBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            modificationReason: (data["modificationReason"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        )
    }
    
    // MARK: - Old listenToPendingBookings (now replaced above)
    private func oldListenToPendingBookings_REMOVED() {
        db.collection("serviceBookings")
            .whereField("status", isEqualTo: ServiceBooking.BookingStatus.pending.rawValue)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self?.pendingBookings = documents.compactMap { doc in
                    let data = doc.data()
                    let duration: Int = (data["duration"] as? Int)
                        ?? (data["duration"] as? Double).map { Int($0) } ?? 30
                    let timeline = data["timeline"] as? [String: Any]
                    let checkIn = ((timeline?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    let checkOut = ((timeline?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    
                    // Parse reschedule history
                    let rescheduleHistoryData = data["rescheduleHistory"] as? [[String: Any]] ?? []
                    let rescheduleHistory = rescheduleHistoryData.compactMap { RescheduleEntry.fromFirestoreData($0) }
                    
                    return ServiceBooking(
                        id: doc.documentID,
                        clientId: data["clientId"] as? String ?? "",
                        serviceType: data["serviceType"] as? String ?? "",
                        scheduledDate: (data["scheduledDate"] as? Timestamp)?.dateValue() ?? Date(),
                        scheduledTime: data["scheduledTime"] as? String ?? "",
                        duration: duration,
                        pets: data["pets"] as? [String] ?? [],
                        specialInstructions: (data["specialInstructions"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        status: ServiceBooking.BookingStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
                        sitterId: (data["sitterId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        sitterName: (data["sitterName"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        address: (data["address"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        checkIn: checkIn,
                        checkOut: checkOut,
                        price: data["price"] as? String ?? "0",
                        recurringSeriesId: (data["recurringSeriesId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        visitNumber: data["visitNumber"] as? Int,
                        isRecurring: data["isRecurring"] as? Bool ?? false,
                        paymentStatus: PaymentStatus(rawValue: data["paymentStatus"] as? String ?? ""),
                        paymentTransactionId: (data["paymentTransactionId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        paymentAmount: data["paymentAmount"] as? Double,
                        paymentMethod: (data["paymentMethod"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        // Rescheduling tracking fields
                        rescheduledFrom: (data["rescheduledFrom"] as? Timestamp)?.dateValue(),
                        rescheduledAt: (data["rescheduledAt"] as? Timestamp)?.dateValue(),
                        rescheduledBy: (data["rescheduledBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        rescheduleReason: (data["rescheduleReason"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        rescheduleHistory: rescheduleHistory,
                        lastModified: (data["lastModified"] as? Timestamp)?.dateValue(),
                        lastModifiedBy: (data["lastModifiedBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        modificationReason: (data["modificationReason"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    )
                }
            }
    }

    func approveBooking(bookingId: String, sitterId: String, sitterName: String) async throws {
        let bookingRef = db.collection("serviceBookings").document(bookingId)

        // 1) Update booking status and assignment
        try await bookingRef.updateData([
            "status": ServiceBooking.BookingStatus.approved.rawValue,
            "sitterId": sitterId,
            "sitterName": sitterName,
            "approvedAt": FieldValue.serverTimestamp()
        ])

        // 2) Read booking to create corresponding visit document for sitter's schedule
        let snap = try await bookingRef.getDocument()
        let data = snap.data() ?? [:]
        let clientId = (data["clientId"] as? String) ?? ""
        let serviceType = (data["serviceType"] as? String) ?? "Service"
        let scheduledDate = (data["scheduledDate"] as? Timestamp)?.dateValue() ?? Date()
        let scheduledTimeStr = (data["scheduledTime"] as? String) ?? ""
        let duration: Int = (data["duration"] as? Int) ?? (data["duration"] as? Double).map { Int($0) } ?? 30
        let pets = (data["pets"] as? [String]) ?? []
        let note = (data["specialInstructions"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let address = (data["address"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        // Compute scheduledStart by combining date and time string (e.g. "10:00 AM")
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
        let timeFormatter = DateFormatter(); timeFormatter.dateFormat = "h:mm a"
        if let timeOnly = timeFormatter.date(from: scheduledTimeStr) {
            let timeComps = calendar.dateComponents([.hour, .minute], from: timeOnly)
            startComponents.hour = timeComps.hour
            startComponents.minute = timeComps.minute
        }
        let scheduledStart = calendar.date(from: startComponents) ?? scheduledDate
        let scheduledEnd = scheduledStart.addingTimeInterval(TimeInterval(max(duration, 0) * 60))

        // Resolve client display name (best-effort)
        var clientName: String = "Client"
        do {
            let clientDoc = try await db.collection("users").document(clientId).getDocument()
            let udata = clientDoc.data() ?? [:]
            let email = (udata["email"] as? String) ?? ""
            let emailFallback = email.split(separator: "@").first.map(String.init) ?? "Client"
            let rawName = (udata["displayName"] as? String) ?? (udata["name"] as? String) ?? ""
            clientName = rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emailFallback : rawName
        } catch {
            // ignore; keep default
        }

        // 3) Optionally resolve pet photo URLs for context
        var petPhotoURLs: [String] = []
        if !pets.isEmpty {
            if let urls = try? await PetDataService().fetchPetPhotoURLs(forUserId: clientId, matchingNames: pets) {
                petPhotoURLs = urls
            }
        }

        // 4) Upsert visit doc (id == bookingId for easy correlation)
        let visitRef = db.collection("visits").document(bookingId)
        var visitData: [String: Any] = [
            "bookingId": bookingId,
            "sitterId": sitterId,
            "sitterName": sitterName,
            "clientId": clientId,
            "clientName": clientName,
            "serviceSummary": serviceType,
            "scheduledStart": Timestamp(date: scheduledStart),
            "scheduledEnd": Timestamp(date: scheduledEnd),
            "status": "scheduled",
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let note { visitData["note"] = note }
        if let address { visitData["address"] = address }
        if !pets.isEmpty { visitData["pets"] = pets }
        if !petPhotoURLs.isEmpty { visitData["petPhotoURLs"] = petPhotoURLs }

        try await visitRef.setData(visitData, merge: true)
    }

    func completeBooking(bookingId: String) async throws {
        try await db.collection("serviceBookings").document(bookingId).updateData([
            "status": ServiceBooking.BookingStatus.completed.rawValue,
            "completedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Admin: Listen to all bookings in real-time
    func listenToAllBookings() {
        db.collection("serviceBookings")
            .order(by: "scheduledDate", descending: false)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot = snapshot else { return }
                
                // CRITICAL FIX: Process documentChanges for deletions
                var current = self?.allBookings ?? []
                
                for change in snapshot.documentChanges {
                    let doc = change.document
                    let docId = doc.documentID
                    
                    switch change.type {
                    case .added, .modified:
                        let booking = self?.parseBookingFromDocument(doc)
                        if let booking = booking {
                            current.removeAll { $0.id == docId }
                            current.append(booking)
                        }
                        
                    case .removed:
                        current.removeAll { $0.id == docId }
                    }
                }
                
                current.sort { $0.scheduledDate < $1.scheduledDate }
                self?.allBookings = current
            }
    }
    
    // MARK: - Old listenToAllBookings (now replaced above)
    private func oldListenToAllBookings_REMOVED() {
        db.collection("serviceBookings")
            .order(by: "scheduledDate", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self?.allBookings = documents.compactMap { doc in
                    let data = doc.data()
                    let duration: Int = (data["duration"] as? Int)
                        ?? (data["duration"] as? Double).map { Int($0) } ?? 30
                    let timeline = data["timeline"] as? [String: Any]
                    let checkIn = ((timeline?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    let checkOut = ((timeline?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    
                    // Parse reschedule history
                    let rescheduleHistoryData = data["rescheduleHistory"] as? [[String: Any]] ?? []
                    let rescheduleHistory = rescheduleHistoryData.compactMap { RescheduleEntry.fromFirestoreData($0) }
                    
                    return ServiceBooking(
                        id: doc.documentID,
                        clientId: data["clientId"] as? String ?? "",
                        serviceType: data["serviceType"] as? String ?? "",
                        scheduledDate: (data["scheduledDate"] as? Timestamp)?.dateValue() ?? Date(),
                        scheduledTime: data["scheduledTime"] as? String ?? "",
                        duration: duration,
                        pets: data["pets"] as? [String] ?? [],
                        specialInstructions: (data["specialInstructions"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        status: ServiceBooking.BookingStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
                        sitterId: (data["sitterId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        sitterName: (data["sitterName"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        address: (data["address"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        checkIn: checkIn,
                        checkOut: checkOut,
                        price: data["price"] as? String ?? "0",
                        recurringSeriesId: (data["recurringSeriesId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        visitNumber: data["visitNumber"] as? Int,
                        isRecurring: data["isRecurring"] as? Bool ?? false,
                        paymentStatus: PaymentStatus(rawValue: data["paymentStatus"] as? String ?? ""),
                        paymentTransactionId: (data["paymentTransactionId"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        paymentAmount: data["paymentAmount"] as? Double,
                        paymentMethod: (data["paymentMethod"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        // Rescheduling tracking fields
                        rescheduledFrom: (data["rescheduledFrom"] as? Timestamp)?.dateValue(),
                        rescheduledAt: (data["rescheduledAt"] as? Timestamp)?.dateValue(),
                        rescheduledBy: (data["rescheduledBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        rescheduleReason: (data["rescheduleReason"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        rescheduleHistory: rescheduleHistory,
                        lastModified: (data["lastModified"] as? Timestamp)?.dateValue(),
                        lastModifiedBy: (data["lastModifiedBy"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        modificationReason: (data["modificationReason"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    )
                }
            }
    }
    
    // MARK: - Booking Cancellation
    
    /// Cancel a single booking with refund calculation
    func cancelBooking(bookingId: String, reason: String = "") async throws -> CancellationResult {
        guard let booking = userBookings.first(where: { $0.id == bookingId }) else {
            throw NSError(domain: "BookingService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Booking not found"])
        }
        
        // Calculate hours until visit
        let now = Date()
        let hoursUntilVisit = booking.scheduledDate.timeIntervalSince(now) / 3600
        
        // Determine refund eligibility based on cancellation policy
        // Updated policy: < 24h = 0%, 24h-7days = 50%, 7+ days = 100%
        let refundPercentage: Double
        let refundEligible: Bool
        
        if hoursUntilVisit >= (7 * 24) {
            // A week or more ahead: Full refund (100%)
            refundPercentage = 1.0
            refundEligible = true
        } else if hoursUntilVisit >= 24 {
            // 24 hours to 7 days ahead: 50% refund
            refundPercentage = 0.5
            refundEligible = true
        } else if hoursUntilVisit >= 0 {
            // Less than 24 hours: No refund
            refundPercentage = 0.0
            refundEligible = false
        } else {
            // After visit started: No refund
            refundPercentage = 0.0
            refundEligible = false
        }
        
        // Calculate refund amount
        let refundAmount = (Double(booking.price) ?? 0) * refundPercentage
        
        // Update booking in Firestore
        let updateData: [String: Any] = [
            "status": "cancelled",  // Match enum spelling (British)
            "canceledAt": FieldValue.serverTimestamp(),
            "canceledBy": "owner",
            "cancelReason": reason.isEmpty ? "Canceled by owner" : reason,
            "refundEligible": refundEligible,
            "refundPercentage": refundPercentage,
            "refundAmount": refundAmount,
            "refundProcessed": false,
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("serviceBookings").document(bookingId).updateData(updateData)
        
        // Update visit status if exists
        let visitSnapshot = try? await db.collection("visits")
            .whereField("bookingId", isEqualTo: bookingId)
            .getDocuments()
        
        if let visitDoc = visitSnapshot?.documents.first {
            try await visitDoc.reference.updateData([
                "status": "cancelled",  // Match enum spelling
                "canceledAt": FieldValue.serverTimestamp(),
                "canceledBy": "owner"
            ])
        }
        
        // Send notifications (will be handled by Cloud Function)
        if let sitterId = booking.sitterId {
            try await sendCancellationNotification(
                to: sitterId,
                booking: booking,
                canceledBy: "owner"
            )
        }
        
        // Process automatic refund via Square API (if payment exists and refund is eligible)
        if refundEligible && refundAmount > 0 {
            // Check if booking has Square payment ID
            if let squarePaymentId = (try? await db.collection("serviceBookings").document(bookingId).getDocument())?.data()?["squarePaymentId"] as? String, 
               !squarePaymentId.isEmpty {
                
                AppLogger.data.info("Processing automatic refund via Square API")
                
                // Trigger automatic refund
                let squareService = SquarePaymentService()
                do {
                    try await squareService.processRefund(
                        bookingId: bookingId,
                        refundAmount: refundAmount,
                        reason: reason.isEmpty ? "Booking canceled by customer" : reason
                    )
                    
                    AppLogger.data.info("✅ Automatic refund processed: $\(refundAmount)")
                } catch {
                    AppLogger.data.warning("Refund API call failed (will need manual processing): \(error.localizedDescription)")
                    // Don't throw - booking still canceled, admin can manually refund
                }
            } else {
                AppLogger.data.info("No Square payment ID - refund needs manual processing")
            }
        }
        
        AppLogger.data.info("Booking \(bookingId) canceled. Refund: \(refundPercentage * 100)%")
        
        return CancellationResult(
            success: true,
            refundEligible: refundEligible,
            refundPercentage: refundPercentage,
            refundAmount: refundAmount,
            hoursUntilVisit: hoursUntilVisit
        )
    }
    
    /// Cancel entire recurring series
    func cancelRecurringSeries(seriesId: String, cancelFutureOnly: Bool = true) async throws -> Int {
        var canceledCount = 0
        
        // Find all bookings in the series
        let snapshot = try await db.collection("serviceBookings")
            .whereField("recurringSeriesId", isEqualTo: seriesId)
            .getDocuments()
        
        for doc in snapshot.documents {
            let data = doc.data()
            let status = data["status"] as? String ?? ""
            
            // Skip already completed or cancelled bookings
            if status == "completed" || status == "cancelled" {
                continue
            }
            
            if cancelFutureOnly {
                // Only cancel future visits
                if let scheduledDate = (data["scheduledDate"] as? Timestamp)?.dateValue(),
                   scheduledDate > Date() {
                    try await doc.reference.updateData([
                        "status": "cancelled",  // Match enum spelling (British)
                        "canceledAt": FieldValue.serverTimestamp(),
                        "canceledBy": "owner",
                        "cancelReason": "Series canceled by owner",
                        "refundEligible": true,
                        "refundProcessed": false
                    ])
                    canceledCount += 1
                }
            } else {
                // Cancel all visits
                try await doc.reference.updateData([
                    "status": "cancelled",  // Match enum spelling (British)
                    "canceledAt": FieldValue.serverTimestamp(),
                    "canceledBy": "owner",
                    "cancelReason": "Series canceled by owner"
                ])
                canceledCount += 1
            }
        }
        
        // Update series status
        try await db.collection("recurringSeries").document(seriesId).updateData([
            "status": "cancelled",  // Match enum spelling (British)
            "canceledAt": FieldValue.serverTimestamp(),
            "canceledVisits": FieldValue.increment(Int64(canceledCount))
        ])
        
        AppLogger.data.info("Canceled \(canceledCount) visits in series \(seriesId)")
        
        return canceledCount
    }
    
    /// Send cancellation notification
    private func sendCancellationNotification(to userId: String, booking: ServiceBooking, canceledBy: String) async throws {
        // Create notification document for Cloud Function to process
        let notificationData: [String: Any] = [
            "type": "booking_canceled",
            "recipientId": userId,
            "bookingId": booking.id,
            "serviceType": booking.serviceType,
            "scheduledDate": Timestamp(date: booking.scheduledDate),
            "scheduledTime": booking.scheduledTime,
            "canceledBy": canceledBy,
            "createdAt": FieldValue.serverTimestamp(),
            "processed": false
        ]
        
        try await db.collection("notifications").addDocument(data: notificationData)
    }
    
    // MARK: - Recurring Bookings
    
    /// Create a recurring booking series with individual bookings
    func createRecurringSeries(
        serviceType: String,
        numberOfVisits: Int,
        frequency: PaymentFrequency,
        startDate: Date,
        preferredTime: String,
        preferredDays: [Int]?,
        duration: Int,
        basePrice: Double,
        pets: [String],
        specialInstructions: String?,
        address: String?
    ) async throws -> String {
        guard let clientId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Calculate total price with discount
        let discount = frequency.discountPercentage
        let subtotal = basePrice * Double(numberOfVisits)
        let totalPrice = subtotal * (1.0 - discount)
        
        // Create recurring series document
        let seriesRef = db.collection("recurringSeries").document()
        let seriesId = seriesRef.documentID
        
        let seriesData: [String: Any] = [
            "clientId": clientId,
            "serviceType": serviceType,
            "numberOfVisits": numberOfVisits,
            "frequency": frequency.rawValue,
            "startDate": Timestamp(date: startDate),
            "preferredTime": preferredTime,
            "preferredDays": preferredDays ?? [],
            "basePrice": basePrice,
            "totalPrice": totalPrice,
            "pets": pets,
            "specialInstructions": specialInstructions ?? "",
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "assignedSitterId": NSNull(),
            "preferredSitterId": NSNull(),
            "completedVisits": 0,
            "canceledVisits": 0,
            "upcomingVisits": numberOfVisits,
            "duration": duration
        ]
        
        try await seriesRef.setData(seriesData)
        
        // Generate individual booking dates
        let bookingDates = generateBookingDates(
            startDate: startDate,
            preferredTime: preferredTime,
            frequency: frequency,
            preferredDays: preferredDays,
            count: numberOfVisits
        )
        
        // Create individual bookings
        for (index, bookingDate) in bookingDates.enumerated() {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let scheduledTime = timeFormatter.string(from: bookingDate)
            
            let bookingData: [String: Any] = [
                "clientId": clientId,
                "serviceType": serviceType,
                "scheduledDate": Timestamp(date: bookingDate),
                "scheduledTime": scheduledTime,
                "duration": duration,
                "pets": pets,
                "specialInstructions": specialInstructions ?? "",
                "status": ServiceBooking.BookingStatus.pending.rawValue,
                "sitterId": "",
                "sitterName": "",
                "createdAt": FieldValue.serverTimestamp(),
                "address": address ?? "",
                "recurringSeriesId": seriesId,
                "visitNumber": index + 1,
                "isRecurring": true
            ]
            
            try await db.collection("serviceBookings").addDocument(data: bookingData)
        }
        
        AppLogger.data.info("Created recurring series: \(seriesId) with \(numberOfVisits) visits, frequency: \(frequency.rawValue)")
        
        return seriesId
    }
    
    /// Generate booking dates based on frequency and preferences
    private func generateBookingDates(
        startDate: Date,
        preferredTime: String,
        frequency: PaymentFrequency,
        preferredDays: [Int]?,
        count: Int
    ) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        
        // Parse time from preferred time string (e.g., "10:00 AM")
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        let timeComponents = timeFormatter.date(from: preferredTime).map {
            calendar.dateComponents([.hour, .minute], from: $0)
        }
        
        var currentDate = startDate
        
        switch frequency {
        case .daily:
            // Generate consecutive daily bookings
            for _ in 0..<count {
                var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                if let time = timeComponents {
                    components.hour = time.hour
                    components.minute = time.minute
                }
                if let date = calendar.date(from: components) {
                    dates.append(date)
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
        case .weekly:
            // Generate weekly bookings on preferred days
            if let preferredDays = preferredDays, !preferredDays.isEmpty {
                var weeksAdded = 0
                while dates.count < count && weeksAdded < 100 { // Safety limit
                    for weekday in preferredDays.sorted() {
                        guard dates.count < count else { break }
                        
                        let currentWeekday = calendar.component(.weekday, from: currentDate)
                        let daysToAdd = (weekday - currentWeekday + 7) % 7
                        let targetDay = daysToAdd == 0 && !dates.isEmpty ? 7 : daysToAdd
                        
                        if let targetDate = calendar.date(byAdding: .day, value: targetDay, to: currentDate) {
                            var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                            if let time = timeComponents {
                                dateComponents.hour = time.hour
                                dateComponents.minute = time.minute
                            }
                            if let date = calendar.date(from: dateComponents), date >= startDate {
                                dates.append(date)
                                currentDate = date
                            }
                        }
                    }
                    weeksAdded += 1
                }
            } else {
                // Default: once per week, same day as start date
                for _ in 0..<count {
                    var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                    if let time = timeComponents {
                        components.hour = time.hour
                        components.minute = time.minute
                    }
                    if let date = calendar.date(from: components) {
                        dates.append(date)
                    }
                    currentDate = calendar.date(byAdding: .day, value: 7, to: currentDate) ?? currentDate
                }
            }
            
        case .monthly:
            // Generate monthly bookings on same day of month
            for _ in 0..<count {
                var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                if let time = timeComponents {
                    components.hour = time.hour
                    components.minute = time.minute
                }
                if let date = calendar.date(from: components) {
                    dates.append(date)
                }
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }
        }
        
        return Array(dates.prefix(count))
    }
}

// MARK: - ServiceBooking Extensions
extension ServiceBooking {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "clientId": clientId,
            "serviceType": serviceType,
            "scheduledDate": Timestamp(date: scheduledDate),
            "scheduledTime": scheduledTime,
            "duration": duration,
            "pets": pets,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "price": price,
            "isRecurring": isRecurring,
            "rescheduleHistory": rescheduleHistory.map { entry in
                [
                    "originalDate": entry.originalDate,
                    "newDate": entry.newDate,
                    "requestedBy": entry.requestedBy,
                    "requestedAt": entry.requestedAt,
                    "reason": entry.reason,
                    "status": entry.status.rawValue
                ]
            },
            "lastModified": Timestamp(date: lastModified ?? createdAt),
            "lastModifiedBy": lastModifiedBy ?? "system",
            "modificationReason": modificationReason ?? "Initial booking creation"
        ]
        
        if let specialInstructions = specialInstructions {
            data["specialInstructions"] = specialInstructions
        }
        
        if let sitterId = sitterId {
            data["sitterId"] = sitterId
        }
        
        if let sitterName = sitterName {
            data["sitterName"] = sitterName
        }
        
        if let address = address {
            data["address"] = address
        }
        
        if let checkIn = checkIn {
            data["checkIn"] = Timestamp(date: checkIn)
        }
        
        if let checkOut = checkOut {
            data["checkOut"] = Timestamp(date: checkOut)
        }
        
        if let recurringSeriesId = recurringSeriesId {
            data["recurringSeriesId"] = recurringSeriesId
        }
        
        if let visitNumber = visitNumber {
            data["visitNumber"] = visitNumber
        }
        
        if let paymentStatus = paymentStatus {
            data["paymentStatus"] = paymentStatus.rawValue
        }
        
        if let paymentTransactionId = paymentTransactionId {
            data["paymentTransactionId"] = paymentTransactionId
        }
        
        if let paymentAmount = paymentAmount {
            data["paymentAmount"] = paymentAmount
        }
        
        if let paymentMethod = paymentMethod {
            data["paymentMethod"] = paymentMethod
        }
        
        if let rescheduledFrom = rescheduledFrom {
            data["rescheduledFrom"] = Timestamp(date: rescheduledFrom)
        }
        
        if let rescheduledAt = rescheduledAt {
            data["rescheduledAt"] = Timestamp(date: rescheduledAt)
        }
        
        if let rescheduledBy = rescheduledBy {
            data["rescheduledBy"] = rescheduledBy
        }
        
        if let rescheduleReason = rescheduleReason {
            data["rescheduleReason"] = rescheduleReason
        }
        
        return data
    }
}
