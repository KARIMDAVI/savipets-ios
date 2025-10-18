import Foundation
import Combine
import FirebaseFirestore
import OSLog
import Network

/// Service for managing offline booking data and synchronization
@MainActor
final class OfflineBookingCache: ObservableObject {
    @Published var cachedBookings: [ServiceBooking] = []
    @Published var isOnline: Bool = true
    @Published var lastSyncDate: Date?
    @Published var pendingChanges: [BookingChange] = []
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let cacheKey = "cached_bookings"
    private let pendingChangesKey = "pending_booking_changes"
    private let lastSyncKey = "last_sync_date"
    
    // Network monitoring
    private let networkMonitor = NetworkMonitor()
    
    init() {
        setupNetworkMonitoring()
        loadCachedData()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                Task { @MainActor in
                    self?.isOnline = isConnected
                    
                    if isConnected {
                        await self?.syncPendingChanges()
                        await self?.refreshCache()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cache Management
    func loadCachedData() {
        // Load cached bookings
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cachedBookings = try? JSONDecoder().decode([ServiceBooking].self, from: data) {
            self.cachedBookings = cachedBookings
            AppLogger.data.info("Loaded \(cachedBookings.count) cached bookings")
        }
        
        // Load pending changes
        if let data = UserDefaults.standard.data(forKey: pendingChangesKey),
           let pendingChanges = try? JSONDecoder().decode([BookingChange].self, from: data) {
            self.pendingChanges = pendingChanges
            AppLogger.data.info("Loaded \(pendingChanges.count) pending changes")
        }
        
        // Load last sync date
        if let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            self.lastSyncDate = lastSync
        }
    }
    
    func saveCachedData() {
        // Save cached bookings
        if let data = try? JSONEncoder().encode(cachedBookings) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
        
        // Save pending changes
        if let data = try? JSONEncoder().encode(pendingChanges) {
            UserDefaults.standard.set(data, forKey: pendingChangesKey)
        }
        
        // Save last sync date
        if let lastSync = lastSyncDate {
            UserDefaults.standard.set(lastSync, forKey: lastSyncKey)
        }
        
        AppLogger.data.info("Saved cached data to local storage")
    }
    
    // MARK: - Offline Operations
    func addOfflineBooking(_ booking: ServiceBooking) {
        // Add to cache
        cachedBookings.append(booking)
        
        // Track as pending change
        let bookingData = ServiceBookingData(
            id: booking.id,
            clientId: booking.clientId,
            serviceType: booking.serviceType,
            scheduledDate: booking.scheduledDate,
            scheduledTime: booking.scheduledTime,
            duration: booking.duration,
            pets: booking.pets,
            specialInstructions: booking.specialInstructions,
            status: booking.status.rawValue,
            sitterId: booking.sitterId,
            sitterName: booking.sitterName,
            createdAt: booking.createdAt,
            address: booking.address,
            price: booking.price,
            isRecurring: booking.isRecurring
        )
        
        let change = BookingChange(
            id: UUID().uuidString,
            type: .create,
            bookingId: booking.id,
            bookingData: bookingData,
            timestamp: Date(),
            isProcessed: false
        )
        pendingChanges.append(change)
        
        saveCachedData()
        AppLogger.data.info("Added booking \(booking.id) for offline processing")
    }
    
    func updateOfflineBooking(_ booking: ServiceBooking) {
        // Update cache
        if let index = cachedBookings.firstIndex(where: { $0.id == booking.id }) {
            cachedBookings[index] = booking
            
            // Track as pending change
            let bookingData = ServiceBookingData(
                id: booking.id,
                clientId: booking.clientId,
                serviceType: booking.serviceType,
                scheduledDate: booking.scheduledDate,
                scheduledTime: booking.scheduledTime,
                duration: booking.duration,
                pets: booking.pets,
                specialInstructions: booking.specialInstructions,
                status: booking.status.rawValue,
                sitterId: booking.sitterId,
                sitterName: booking.sitterName,
                createdAt: booking.createdAt,
                address: booking.address,
                price: booking.price,
                isRecurring: booking.isRecurring
            )
            
            let change = BookingChange(
                id: UUID().uuidString,
                type: .update,
                bookingId: booking.id,
                bookingData: bookingData,
                timestamp: Date(),
                isProcessed: false
            )
            pendingChanges.append(change)
            
            saveCachedData()
            AppLogger.data.info("Updated booking \(booking.id) for offline processing")
        }
    }
    
    func deleteOfflineBooking(_ bookingId: String) {
        // Remove from cache
        cachedBookings.removeAll { $0.id == bookingId }
        
        // Track as pending change
        let change = BookingChange(
            id: UUID().uuidString,
            type: .delete,
            bookingId: bookingId,
            bookingData: nil,
            timestamp: Date(),
            isProcessed: false
        )
        pendingChanges.append(change)
        
        saveCachedData()
        AppLogger.data.info("Deleted booking \(bookingId) for offline processing")
    }
    
    // MARK: - Synchronization
    func refreshCache() async {
        guard isOnline else {
            AppLogger.data.warning("Cannot refresh cache - offline")
            return
        }
        
        do {
            // Fetch latest bookings from Firestore
            let snapshot = try await db.collection("serviceBookings")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            let freshBookings = snapshot.documents.compactMap { doc in
                // Parse booking from document data
                let data = doc.data()
                return createServiceBooking(from: data, id: doc.documentID)
            }
            
            // Update cache
            cachedBookings = freshBookings
            lastSyncDate = Date()
            
            saveCachedData()
            AppLogger.data.info("Refreshed cache with \(freshBookings.count) bookings")
            
        } catch {
            AppLogger.data.error("Failed to refresh cache: \(error.localizedDescription)")
        }
    }
    
    func syncPendingChanges() async {
        guard isOnline else {
            AppLogger.data.warning("Cannot sync changes - offline")
            return
        }
        
        let unprocessedChanges = pendingChanges.filter { !$0.isProcessed }
        
        for change in unprocessedChanges {
            do {
                try await processPendingChange(change)
                
                // Mark as processed
                if let index = pendingChanges.firstIndex(where: { $0.id == change.id }) {
                    pendingChanges[index].isProcessed = true
                }
                
            } catch {
                AppLogger.data.error("Failed to sync change \(change.id): \(error.localizedDescription)")
            }
        }
        
        // Remove processed changes
        pendingChanges.removeAll { $0.isProcessed }
        saveCachedData()
        
        AppLogger.data.info("Synced \(unprocessedChanges.count) pending changes")
    }
    
    private func processPendingChange(_ change: BookingChange) async throws {
        switch change.type {
        case .create:
            guard let bookingData = change.bookingData else { return }
            try await db.collection("serviceBookings").document(bookingData.id).setData(bookingData.toFirestoreData())
            
        case .update:
            guard let bookingData = change.bookingData else { return }
            try await db.collection("serviceBookings").document(bookingData.id).updateData(bookingData.toFirestoreData())
            
        case .delete:
            try await db.collection("serviceBookings").document(change.bookingId).delete()
        }
    }
    
    private func createServiceBooking(from data: [String: Any], id: String) -> ServiceBooking? {
        guard let clientId = data["clientId"] as? String,
              let serviceType = data["serviceType"] as? String,
              let scheduledDateTimestamp = data["scheduledDate"] as? Timestamp,
              let scheduledTime = data["scheduledTime"] as? String,
              let duration = data["duration"] as? Int,
              let pets = data["pets"] as? [String],
              let statusString = data["status"] as? String,
              let status = ServiceBooking.BookingStatus(rawValue: statusString),
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let price = data["price"] as? String,
              let isRecurring = data["isRecurring"] as? Bool else {
            return nil
        }
        
        let scheduledDate = scheduledDateTimestamp.dateValue()
        let createdAt = createdAtTimestamp.dateValue()
        
        return ServiceBooking(
            id: id,
            clientId: clientId,
            serviceType: serviceType,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            duration: duration,
            pets: pets,
            specialInstructions: data["specialInstructions"] as? String,
            status: status,
            sitterId: data["sitterId"] as? String,
            sitterName: data["sitterName"] as? String,
            createdAt: createdAt,
            address: data["address"] as? String,
            checkIn: (data["checkIn"] as? Timestamp)?.dateValue(),
            checkOut: (data["checkOut"] as? Timestamp)?.dateValue(),
            price: price,
            recurringSeriesId: data["recurringSeriesId"] as? String,
            visitNumber: data["visitNumber"] as? Int,
            isRecurring: isRecurring,
            paymentStatus: PaymentStatus(rawValue: data["paymentStatus"] as? String ?? ""),
            paymentTransactionId: data["paymentTransactionId"] as? String,
            paymentAmount: data["paymentAmount"] as? Double,
            paymentMethod: data["paymentMethod"] as? String,
            rescheduledFrom: (data["rescheduledFrom"] as? Timestamp)?.dateValue(),
            rescheduledAt: (data["rescheduledAt"] as? Timestamp)?.dateValue(),
            rescheduledBy: data["rescheduledBy"] as? String,
            rescheduleReason: data["rescheduleReason"] as? String,
            rescheduleHistory: [], // Simplified for offline cache
            lastModified: (data["lastModified"] as? Timestamp)?.dateValue(),
            lastModifiedBy: data["lastModifiedBy"] as? String,
            modificationReason: data["modificationReason"] as? String
        )
    }
    
    // MARK: - Query Methods
    func getBookings(for userId: String) -> [ServiceBooking] {
        return cachedBookings.filter { booking in
            booking.clientId == userId || booking.sitterId == userId
        }
    }
    
    func getBooking(by id: String) -> ServiceBooking? {
        return cachedBookings.first { $0.id == id }
    }
    
    func getBookingsByStatus(_ status: ServiceBooking.BookingStatus) -> [ServiceBooking] {
        return cachedBookings.filter { $0.status == status }
    }
    
    func getBookingsInDateRange(_ startDate: Date, _ endDate: Date) -> [ServiceBooking] {
        return cachedBookings.filter { booking in
            booking.scheduledDate >= startDate && booking.scheduledDate <= endDate
        }
    }
    
    // MARK: - Offline Indicators
    var hasPendingChanges: Bool {
        return !pendingChanges.filter { !$0.isProcessed }.isEmpty
    }
    
    var offlineIndicatorText: String {
        if !isOnline {
            return "Offline Mode"
        } else if hasPendingChanges {
            return "Syncing Changes..."
        } else {
            return "Online"
        }
    }
}

// MARK: - Supporting Models
struct BookingChange: Codable, Identifiable {
    let id: String
    let type: ChangeType
    let bookingId: String
    let bookingData: ServiceBookingData?
    let timestamp: Date
    var isProcessed: Bool
    
    enum ChangeType: String, Codable {
        case create
        case update
        case delete
    }
}

// Simplified booking data for offline storage
struct ServiceBookingData: Codable {
    let id: String
    let clientId: String
    let serviceType: String
    let scheduledDate: Date
    let scheduledTime: String
    let duration: Int
    let pets: [String]
    let specialInstructions: String?
    let status: String
    let sitterId: String?
    let sitterName: String?
    let createdAt: Date
    let address: String?
    let price: String
    let isRecurring: Bool
}

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - ServiceBookingData Extension for Firestore
extension ServiceBookingData {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "clientId": clientId,
            "serviceType": serviceType,
            "scheduledDate": Timestamp(date: scheduledDate),
            "scheduledTime": scheduledTime,
            "duration": duration,
            "pets": pets,
            "status": status,
            "createdAt": Timestamp(date: createdAt),
            "price": price,
            "isRecurring": isRecurring
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
        
        return data
    }
}
