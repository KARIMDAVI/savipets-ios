import Foundation
import FirebaseFirestore
import FirebaseAuth
internal import os

/// Service for detecting and preventing booking conflicts
final class BookingConflictService {
    private let db = Firestore.firestore()
    
    /// Check if a time slot is available for a specific sitter
    func isSlotAvailable(
        for sitterId: String,
        start: Date,
        duration: Int
    ) async throws -> Bool {
        let end = start.addingTimeInterval(Double(duration) * 60)
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: start)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? start
        
        AppLogger.data.info("Checking slot availability for sitter: \(sitterId) at \(start)")
        
        let snapshot = try await db.collection("serviceBookings")
            .whereField("sitterId", isEqualTo: sitterId)
            .whereField("scheduledDate", isGreaterThanOrEqualTo: Timestamp(date: dayStart))
            .whereField("scheduledDate", isLessThan: Timestamp(date: dayEnd))
            .whereField("status", in: ["pending", "approved", "in_adventure"])
            .getDocuments()
        
        for doc in snapshot.documents {
            let data = doc.data()
            guard let existingStart = (data["scheduledDate"] as? Timestamp)?.dateValue(),
                  let existingDuration = data["duration"] as? Int else {
                continue
            }
            
            let existingEnd = existingStart.addingTimeInterval(Double(existingDuration) * 60)
            
            // Check for overlap: (start1 < end2) AND (end1 > start2)
            if start < existingEnd && end > existingStart {
                AppLogger.ui.warning("Conflict detected: New booking \(start)-\(end) overlaps with existing \(existingStart)-\(existingEnd)")
                return false
            }
        }
        
        AppLogger.data.info("Slot available for sitter: \(sitterId) at \(start)")
        return true
    }
    
    /// Check availability for multiple dates (batch check for recurring bookings)
    func checkMultipleDates(
        for sitterId: String?,
        dates: [Date],
        duration: Int
    ) async throws -> [Date: Bool] {
        guard let sitterId = sitterId else {
            // No sitter assigned yet, assume all available
            return dates.reduce(into: [:]) { $0[$1] = true }
        }
        
        var availability: [Date: Bool] = [:]
        
        for date in dates {
            do {
                availability[date] = try await isSlotAvailable(
                    for: sitterId,
                    start: date,
                    duration: duration
                )
            } catch {
                AppLogger.data.error("Error checking availability for \(date): \(error.localizedDescription)")
                availability[date] = false
            }
        }
        
        return availability
    }
    
    /// Get list of conflicting dates from a set of proposed dates
    func getConflictingDates(
        for sitterId: String,
        dates: [Date],
        duration: Int
    ) async throws -> [Date] {
        let availability = try await checkMultipleDates(
            for: sitterId,
            dates: dates,
            duration: duration
        )
        
        return dates.filter { availability[$0] == false }
    }
}

