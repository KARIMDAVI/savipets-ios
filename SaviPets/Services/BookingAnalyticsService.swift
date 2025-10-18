import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog
import Combine

/// Comprehensive analytics service for booking data collection and insights
@MainActor
final class BookingAnalyticsService: ObservableObject {
    @Published var analyticsData: BookingAnalytics = BookingAnalytics()
    @Published var isCollecting: Bool = false
    @Published var lastUpdated: Date?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let analyticsCollection = "bookingAnalytics"
    
    // Real-time listeners
    private var bookingsListener: ListenerRegistration?
    private var cancellationsListener: ListenerRegistration?
    
    init() {
        setupRealTimeCollection()
    }
    
    deinit {
        bookingsListener?.remove()
        cancellationsListener?.remove()
    }
    
    // MARK: - Real-time Data Collection
    private func setupRealTimeCollection() {
        // Listen to booking changes for real-time analytics
        bookingsListener = db.collection("serviceBookings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        AppLogger.data.error("Analytics listener error: \(error.localizedDescription)")
                        return
                    }
                    
                    self.processBookingChanges(snapshot?.documentChanges ?? [])
                }
            }
    }
    
    private func processBookingChanges(_ changes: [DocumentChange]) {
        for change in changes {
            switch change.type {
            case .added:
                if let booking = parseBookingFromDocument(change.document) {
                    recordBookingCreated(booking)
                }
            case .modified:
                if let booking = parseBookingFromDocument(change.document) {
                    recordBookingUpdated(booking)
                }
            case .removed:
                recordBookingDeleted(change.document.documentID)
            }
        }
    }
    
    // MARK: - Analytics Collection
    func collectAnalytics(timeframe: AnalyticsTimeframe = .last30Days) async {
        isCollecting = true
        
        do {
            let dateRange = timeframe.dateRange
            let bookings = try await fetchBookingsInRange(dateRange)
            
            analyticsData = BookingAnalytics()
            
            lastUpdated = Date()
            await saveAnalyticsToFirestore()
            
            AppLogger.data.info("Analytics collected for \(timeframe.rawValue): \(bookings.count) bookings")
            
        } catch {
            AppLogger.data.error("Failed to collect analytics: \(error.localizedDescription)")
        }
        
        isCollecting = false
    }
    
    private func fetchBookingsInRange(_ dateRange: (start: Date, end: Date)) async throws -> [ServiceBooking] {
        let snapshot = try await db.collection("serviceBookings")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: dateRange.start))
            .whereField("createdAt", isLessThanOrEqualTo: Timestamp(date: dateRange.end))
            .getDocuments()
        
        return snapshot.documents.compactMap { parseBookingFromDocument($0) }
    }
    
    private func parseBookingFromDocument(_ document: QueryDocumentSnapshot) -> ServiceBooking? {
        let data = document.data()
        
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
            id: document.documentID,
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
            rescheduleHistory: [],
            lastModified: (data["lastModified"] as? Timestamp)?.dateValue(),
            lastModifiedBy: data["lastModifiedBy"] as? String,
            modificationReason: data["modificationReason"] as? String
        )
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Insights Generation
    private func generateInsights(from bookings: [ServiceBooking]) -> [AnalyticsInsight] {
        var insights: [AnalyticsInsight] = []
        
        // Basic insights based on booking data
        if bookings.count > 10 {
            insights.append(AnalyticsInsight(
                id: UUID().uuidString,
                title: "Booking Volume Analysis",
                description: "You have \(bookings.count) bookings in this period, showing steady demand.",
                type: .info,
                priority: .low,
                category: .general,
                metrics: ["totalBookings": Double(bookings.count)],
                recommendations: ["Monitor booking patterns", "Plan capacity accordingly"],
                createdAt: Date()
            ))
        }
        
        return insights
    }
    
    // MARK: - Event Recording
    private func recordBookingCreated(_ booking: ServiceBooking) {
        let event = AnalyticsEvent(
            type: .bookingCreated,
            bookingId: booking.id,
            serviceType: booking.serviceType,
            value: Double(booking.price) ?? 0,
            timestamp: Date()
        )
        recordEvent(event)
    }
    
    private func recordBookingUpdated(_ booking: ServiceBooking) {
        let event = AnalyticsEvent(
            type: .bookingUpdated,
            bookingId: booking.id,
            serviceType: booking.serviceType,
            value: Double(booking.price) ?? 0,
            timestamp: Date()
        )
        recordEvent(event)
    }
    
    private func recordBookingDeleted(_ bookingId: String) {
        let event = AnalyticsEvent(
            type: .bookingDeleted,
            bookingId: bookingId,
            serviceType: nil,
            value: 0,
            timestamp: Date()
        )
        recordEvent(event)
    }
    
    private func recordEvent(_ event: AnalyticsEvent) {
        // Store event in Firestore for real-time analytics
        Task {
            do {
                try await db.collection("analyticsEvents").addDocument(data: [
                    "type": event.type.rawValue,
                    "bookingId": event.bookingId,
                    "serviceType": event.serviceType ?? "",
                    "value": event.value,
                    "timestamp": Timestamp(date: event.timestamp)
                ])
            } catch {
                AppLogger.data.error("Failed to record analytics event: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Data Persistence
    private func saveAnalyticsToFirestore() async {
        do {
            let firestoreData: [String: Any] = [
                "totalBookings": analyticsData.totalBookings,
                "completedBookings": analyticsData.completedBookings,
                "cancelledBookings": analyticsData.cancelledBookings,
                "averageBookingValue": analyticsData.averageBookingValue,
                "lastUpdated": Timestamp(date: Date())
            ]
            
            try await db.collection(analyticsCollection)
                .document("current")
                .setData(firestoreData, merge: true)
                
        } catch {
            AppLogger.data.error("Failed to save analytics: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    func getAnalytics(timeframe: AnalyticsTimeframe = .last30Days) async {
        await collectAnalytics(timeframe: timeframe)
    }
    
    func exportAnalytics() -> [String: Any] {
        return [
            "totalBookings": analyticsData.totalBookings,
            "completedBookings": analyticsData.completedBookings,
            "cancelledBookings": analyticsData.cancelledBookings,
            "averageBookingValue": analyticsData.averageBookingValue,
            "exportedAt": Timestamp(date: Date())
        ]
    }
}

// MARK: - Supporting Models
// Note: BookingAnalytics, BookingMetrics, BookingTrends, and AnalyticsInsight 
// are defined in AdminReportingService.swift to avoid duplication

struct AnalyticsEvent: Codable {
    let type: EventType
    let bookingId: String
    let serviceType: String?
    let value: Double
    let timestamp: Date
    
    enum EventType: String, Codable {
        case bookingCreated = "booking_created"
        case bookingUpdated = "booking_updated"
        case bookingDeleted = "booking_deleted"
        case bookingCompleted = "booking_completed"
        case bookingCancelled = "booking_cancelled"
        case bookingRescheduled = "booking_rescheduled"
    }
}

enum AnalyticsTimeframe: String, CaseIterable, Codable {
    case last7Days = "last_7_days"
    case last30Days = "last_30_days"
    case last90Days = "last_90_days"
    case lastYear = "last_year"
    case allTime = "all_time"
    
    var displayName: String {
        switch self {
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .lastYear: return "Last Year"
        case .allTime: return "All Time"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start: start, end: now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start: start, end: now)
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return (start: start, end: now)
        case .lastYear:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (start: start, end: now)
        case .allTime:
            return (start: Date.distantPast, end: Date.distantFuture)
        }
    }
}
