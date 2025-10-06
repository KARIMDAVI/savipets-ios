import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Service Booking Models
struct ServiceBooking: Identifiable {
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

    enum BookingStatus: String, CaseIterable {
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
            case .inAdventure: return "In an Adventure"
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
            "address": booking.address ?? ""
        ]
        _ = try await db.collection("serviceBookings").addDocument(data: data)
    }

    /// Listen to visit status changes and sync to corresponding bookings
    func listenToVisitStatusChanges() {
        db.collection("visits")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                
                for doc in documents {
                    let data = doc.data()
                    let visitStatus = data["status"] as? String ?? "scheduled"
                    let bookingId = doc.documentID
                    
                    // Map visit status to booking status
                    let bookingStatus: String
                    switch visitStatus {
                    case "scheduled": bookingStatus = "approved"
                    case "in_adventure": bookingStatus = "in_adventure"
                    case "completed": bookingStatus = "completed"
                    default: bookingStatus = "approved"
                    }
                    
                    // Update the corresponding service booking
                    self?.db.collection("serviceBookings").document(bookingId).updateData([
                        "status": bookingStatus,
                        "lastUpdated": FieldValue.serverTimestamp()
                    ]) { error in
                        if let error = error {
                            print("Error updating booking status: \(error)")
                        }
                    }
                }
            }
    }
    
    func listenToUserBookings(userId: String) {
        db.collection("serviceBookings")
            .whereField("clientId", isEqualTo: userId)
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
                        checkOut: checkOut
                    )
                }
            }
    }

    func listenToPendingBookings() {
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
                        checkOut: checkOut
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
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self?.allBookings = documents.compactMap { doc in
                    let data = doc.data()
                    let duration: Int = (data["duration"] as? Int)
                        ?? (data["duration"] as? Double).map { Int($0) } ?? 30
                    let timeline = data["timeline"] as? [String: Any]
                    let checkIn = ((timeline?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    let checkOut = ((timeline?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    
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
                        checkOut: checkOut
                    )
                }
            }
    }
}


