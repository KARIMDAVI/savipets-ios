import Foundation
import EventKit
import EventKitUI
import OSLog
import Combine
import SwiftUI

/// Service for syncing bookings with external calendar applications
@MainActor
final class CalendarSyncService: NSObject, ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    
    // Calendar configuration
    private let calendarTitle = "SaviPets Bookings"
    private var saviPetsCalendar: EKCalendar?
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
        
        var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .syncing: return "Syncing..."
            case .success: return "Synced"
            case .error(let message): return "Error: \(message)"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .syncing: return .blue
            case .success: return .green
            case .error: return .red
            }
        }
    }
    
    override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestCalendarAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            isAuthorized = true
            await setupSaviPetsCalendar()
            return true
            
        case .denied, .restricted:
            isAuthorized = false
            return false
            
        case .notDetermined:
            if #available(iOS 17.0, *) {
                let granted = try? await eventStore.requestFullAccessToEvents()
                isAuthorized = granted ?? false
            } else {
                let granted = try? await eventStore.requestAccess(to: .event)
                isAuthorized = granted ?? false
            }
            if isAuthorized {
                await setupSaviPetsCalendar()
            }
            return isAuthorized
            
        case .fullAccess:
            isAuthorized = true
            await setupSaviPetsCalendar()
            return true
            
        case .writeOnly:
            isAuthorized = true
            await setupSaviPetsCalendar()
            return true
            
        @unknown default:
            isAuthorized = false
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        isAuthorized = EKEventStore.authorizationStatus(for: .event) == .authorized
        if isAuthorized {
            Task {
                await setupSaviPetsCalendar()
            }
        }
    }
    
    // MARK: - Calendar Setup
    private func setupSaviPetsCalendar() async {
        // Find existing SaviPets calendar or create new one
        let calendars = eventStore.calendars(for: .event)
        saviPetsCalendar = calendars.first { $0.title == calendarTitle }
        
        if saviPetsCalendar == nil {
            await createSaviPetsCalendar()
        }
        
        AppLogger.data.info("SaviPets calendar setup completed")
    }
    
    private func createSaviPetsCalendar() async {
        do {
            let calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar.title = calendarTitle
            calendar.cgColor = UIColor.systemBlue.cgColor
            
            // Use the default calendar source
            if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
                calendar.source = defaultSource
            } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
                calendar.source = localSource
            } else if let firstSource = eventStore.sources.first {
                calendar.source = firstSource
            } else {
                AppLogger.data.error("No calendar source available")
                return
            }
            
            try eventStore.saveCalendar(calendar, commit: true)
            saviPetsCalendar = calendar
            
            AppLogger.data.info("Created SaviPets calendar: \(self.calendarTitle)")
            
        } catch {
            AppLogger.data.error("Failed to create SaviPets calendar: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Booking Sync
    func syncBooking(_ booking: ServiceBooking) async -> Result<Void, CalendarError> {
        guard isAuthorized, let _ = saviPetsCalendar else {
            return .failure(.notAuthorized)
        }
        
        syncStatus = .syncing
        
        do {
            // Check if event already exists
            if let existingEvent = await findExistingEvent(for: booking) {
                try await updateEvent(existingEvent, with: booking)
            } else {
                try await createEvent(for: booking, in: saviPetsCalendar!)
            }
            
            syncStatus = .success
            lastSyncTime = Date()
            syncError = nil
            
            AppLogger.data.info("Successfully synced booking \(booking.id) to calendar")
            return .success(())
            
        } catch {
            let errorMessage = error.localizedDescription
            syncStatus = .error(errorMessage)
            syncError = errorMessage
            
            AppLogger.data.error("Failed to sync booking to calendar: \(errorMessage)")
            return .failure(.syncFailed(errorMessage))
        }
    }
    
    func syncMultipleBookings(_ bookings: [ServiceBooking]) async -> Result<SyncResult, CalendarError> {
        guard isAuthorized, let _ = saviPetsCalendar else {
            return .failure(.notAuthorized)
        }
        
        syncStatus = .syncing
        
        var successCount = 0
        var failureCount = 0
        var errors: [String] = []
        
        for booking in bookings {
            let result = await syncBooking(booking)
            switch result {
            case .success:
                successCount += 1
            case .failure(let error):
                failureCount += 1
                errors.append("Booking \(booking.id): \(error.localizedDescription)")
            }
        }
        
        let syncResult = SyncResult(
            totalBookings: bookings.count,
            successfulSyncs: successCount,
            failedSyncs: failureCount,
            errors: errors
        )
        
        if failureCount == 0 {
            syncStatus = .success
            syncError = nil
        } else if successCount == 0 {
            syncStatus = .error("All syncs failed")
            syncError = errors.joined(separator: "; ")
        } else {
            syncStatus = .error("Partial sync: \(failureCount) failed")
            syncError = errors.joined(separator: "; ")
        }
        
        lastSyncTime = Date()
        
        AppLogger.data.info("Batch sync completed: \(successCount) successful, \(failureCount) failed")
        return .success(syncResult)
    }
    
    // MARK: - Event Management
    private func createEvent(for booking: ServiceBooking, in calendar: EKCalendar) async throws {
        let event = EKEvent(eventStore: eventStore)
        
        // Basic event details
        event.title = "\(booking.serviceType) - \(booking.pets.joined(separator: ", "))"
        event.startDate = booking.scheduledDate
        event.endDate = Calendar.current.date(byAdding: .minute, value: booking.duration, to: booking.scheduledDate) ?? booking.scheduledDate
        event.calendar = calendar
        
        // Event notes
        var notes = "SaviPets Booking\n"
        notes += "Service: \(booking.serviceType)\n"
        notes += "Duration: \(booking.duration) minutes\n"
        notes += "Pets: \(booking.pets.joined(separator: ", "))\n"
        notes += "Status: \(booking.status.displayName)\n"
        
        if let sitterName = booking.sitterName {
            notes += "Sitter: \(sitterName)\n"
        }
        
        if let instructions = booking.specialInstructions {
            notes += "Instructions: \(instructions)\n"
        }
        
        notes += "Booking ID: \(booking.id)"
        
        event.notes = notes
        
        // Event location
        if let address = booking.address {
            event.location = address
        }
        
        // Set as all-day event if duration is significant
        if booking.duration >= 480 { // 8 hours
            event.isAllDay = true
        }
        
        // Add URL to booking details (if app supports custom URLs)
        if let url = URL(string: "savipets://booking/\(booking.id)") {
            event.url = url
        }
        
        // Add alarms
        addAlarms(to: event, for: booking)
        
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        AppLogger.data.info("Created calendar event for booking \(booking.id)")
    }
    
    private func updateEvent(_ event: EKEvent, with booking: ServiceBooking) async throws {
        // Update event details
        event.title = "\(booking.serviceType) - \(booking.pets.joined(separator: ", "))"
        event.startDate = booking.scheduledDate
        event.endDate = Calendar.current.date(byAdding: .minute, value: booking.duration, to: booking.scheduledDate) ?? booking.scheduledDate
        
        // Update notes
        var notes = "SaviPets Booking\n"
        notes += "Service: \(booking.serviceType)\n"
        notes += "Duration: \(booking.duration) minutes\n"
        notes += "Pets: \(booking.pets.joined(separator: ", "))\n"
        notes += "Status: \(booking.status.displayName)\n"
        
        if let sitterName = booking.sitterName {
            notes += "Sitter: \(sitterName)\n"
        }
        
        if let instructions = booking.specialInstructions {
            notes += "Instructions: \(instructions)\n"
        }
        
        notes += "Booking ID: \(booking.id)"
        
        if let rescheduleHistory = booking.rescheduleHistory.last {
            notes += "\nLast Rescheduled: \(rescheduleHistory.reason)"
        }
        
        event.notes = notes
        
        // Update location
        if let address = booking.address {
            event.location = address
        }
        
        // Update alarms
        event.alarms = nil
        addAlarms(to: event, for: booking)
        
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        AppLogger.data.info("Updated calendar event for booking \(booking.id)")
    }
    
    private func addAlarms(to event: EKEvent, for booking: ServiceBooking) {
        // Add reminder 24 hours before
        let dayBeforeAlarm = EKAlarm(relativeOffset: -24 * 60 * 60) // 24 hours before
        event.addAlarm(dayBeforeAlarm)
        
        // Add reminder 2 hours before
        let hourBeforeAlarm = EKAlarm(relativeOffset: -2 * 60 * 60) // 2 hours before
        event.addAlarm(hourBeforeAlarm)
        
        // Add reminder 30 minutes before
        let minuteBeforeAlarm = EKAlarm(relativeOffset: -30 * 60) // 30 minutes before
        event.addAlarm(minuteBeforeAlarm)
    }
    
    private func findExistingEvent(for booking: ServiceBooking) async -> EKEvent? {
        let predicate = eventStore.predicateForEvents(
            withStart: Calendar.current.date(byAdding: .day, value: -1, to: booking.scheduledDate) ?? booking.scheduledDate,
            end: Calendar.current.date(byAdding: .day, value: 1, to: booking.scheduledDate) ?? booking.scheduledDate,
            calendars: saviPetsCalendar.map { [$0] } ?? []
        )
        
        let events = eventStore.events(matching: predicate)
        
        // Find event by booking ID in notes
        return events.first { event in
            event.notes?.contains("Booking ID: \(booking.id)") ?? false
        }
    }
    
    // MARK: - Event Removal
    func removeBookingFromCalendar(_ booking: ServiceBooking) async -> Result<Void, CalendarError> {
        guard isAuthorized else {
            return .failure(.notAuthorized)
        }
        
        do {
            if let event = await findExistingEvent(for: booking) {
                try eventStore.remove(event, span: .thisEvent, commit: true)
                AppLogger.data.info("Removed booking \(booking.id) from calendar")
            }
            return .success(())
            
        } catch {
            let errorMessage = error.localizedDescription
            AppLogger.data.error("Failed to remove booking from calendar: \(errorMessage)")
            return .failure(.syncFailed(errorMessage))
        }
    }
    
    // MARK: - Bulk Operations
    func syncAllBookings(_ bookings: [ServiceBooking]) async -> Result<SyncResult, CalendarError> {
        return await syncMultipleBookings(bookings)
    }
    
    func removeAllBookingsFromCalendar(_ bookings: [ServiceBooking]) async -> Result<SyncResult, CalendarError> {
        guard isAuthorized else {
            return .failure(.notAuthorized)
        }
        
        var successCount = 0
        var failureCount = 0
        var errors: [String] = []
        
        for booking in bookings {
            let result = await removeBookingFromCalendar(booking)
            switch result {
            case .success:
                successCount += 1
            case .failure(let error):
                failureCount += 1
                errors.append("Booking \(booking.id): \(error.localizedDescription)")
            }
        }
        
        let syncResult = SyncResult(
            totalBookings: bookings.count,
            successfulSyncs: successCount,
            failedSyncs: failureCount,
            errors: errors
        )
        
        AppLogger.data.info("Bulk removal completed: \(successCount) successful, \(failureCount) failed")
        return .success(syncResult)
    }
    
    // MARK: - Calendar Events Query
    func getUpcomingEvents(days: Int = 30) async -> [EKEvent] {
        guard isAuthorized, let _ = saviPetsCalendar else {
            return []
        }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [saviPetsCalendar!]
        )
        
        return eventStore.events(matching: predicate)
    }
    
    // MARK: - Settings
    func updateCalendarSettings(title: String? = nil, color: UIColor? = nil) async {
        guard let calendar = saviPetsCalendar else { return }
        
        do {
            if let newTitle = title {
                calendar.title = newTitle
            }
            
            if let newColor = color {
                calendar.cgColor = newColor.cgColor
            }
            
            try eventStore.saveCalendar(calendar, commit: true)
            
            AppLogger.data.info("Updated calendar settings")
            
        } catch {
            AppLogger.data.error("Failed to update calendar settings: \(error.localizedDescription)")
        }
    }
    
    func deleteSaviPetsCalendar() async -> Result<Void, CalendarError> {
        guard let calendar = saviPetsCalendar else {
            return .failure(.calendarNotFound)
        }
        
        do {
            try eventStore.removeCalendar(calendar, commit: true)
            saviPetsCalendar = nil
            
            AppLogger.data.info("Deleted SaviPets calendar")
            return .success(())
            
        } catch {
            let errorMessage = error.localizedDescription
            AppLogger.data.error("Failed to delete calendar: \(errorMessage)")
            return .failure(.syncFailed(errorMessage))
        }
    }
}

// MARK: - Supporting Models
struct SyncResult {
    let totalBookings: Int
    let successfulSyncs: Int
    let failedSyncs: Int
    let errors: [String]
    
    var successRate: Double {
        guard totalBookings > 0 else { return 0.0 }
        return Double(successfulSyncs) / Double(totalBookings)
    }
    
    var isCompleteSuccess: Bool {
        return failedSyncs == 0
    }
    
    var isCompleteFailure: Bool {
        return successfulSyncs == 0
    }
}

enum CalendarError: Error, LocalizedError {
    case notAuthorized
    case calendarNotFound
    case syncFailed(String)
    case eventCreationFailed(String)
    case eventUpdateFailed(String)
    case eventDeletionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access not authorized"
        case .calendarNotFound:
            return "SaviPets calendar not found"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .eventCreationFailed(let message):
            return "Event creation failed: \(message)"
        case .eventUpdateFailed(let message):
            return "Event update failed: \(message)"
        case .eventDeletionFailed(let message):
            return "Event deletion failed: \(message)"
        }
    }
}

// MARK: - Calendar Event Extensions
extension EKEvent {
    var bookingId: String? {
        guard let notes = notes,
              let range = notes.range(of: "Booking ID: ") else {
            return nil
        }
        
        let idStart = range.upperBound
        let idEnd = notes.range(of: "\n", range: idStart..<notes.endIndex)?.lowerBound ?? notes.endIndex
        return String(notes[idStart..<idEnd])
    }
    
    var serviceType: String? {
        guard let notes = notes,
              let range = notes.range(of: "Service: ") else {
            return nil
        }
        
        let serviceStart = range.upperBound
        let serviceEnd = notes.range(of: "\n", range: serviceStart..<notes.endIndex)?.lowerBound ?? notes.endIndex
        return String(notes[serviceStart..<serviceEnd])
    }
    
    var petNames: [String]? {
        guard let notes = notes,
              let range = notes.range(of: "Pets: ") else {
            return nil
        }
        
        let petsStart = range.upperBound
        let petsEnd = notes.range(of: "\n", range: petsStart..<notes.endIndex)?.lowerBound ?? notes.endIndex
        let petsString = String(notes[petsStart..<petsEnd])
        return petsString.components(separatedBy: ", ")
    }
}

// MARK: - Color Extensions
extension Color {
    static var systemBlue: Color {
        return Color(UIColor.systemBlue)
    }
}
