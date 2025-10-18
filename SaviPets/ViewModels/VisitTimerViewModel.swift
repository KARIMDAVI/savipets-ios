import Foundation
import FirebaseFirestore
import Combine
import OSLog

/// ViewModel for visit timer following Time-To-Pet pattern with authoritative server timestamps
@MainActor
final class VisitTimerViewModel: ObservableObject {
    
    // MARK: - Published Properties (Authoritative Data from Firestore)
    
    @Published private(set) var scheduledStart: Date?
    @Published private(set) var scheduledEnd: Date?
    @Published private(set) var scheduledDurationSeconds: Int = 0
    
    @Published private(set) var actualStart: Date?
    @Published private(set) var actualEnd: Date?
    
    @Published private(set) var status: String = "scheduled"
    @Published private(set) var sitterId: String = ""
    
    // MARK: - Derived State (Computed from Authoritative Data)
    
    @Published private(set) var isPendingWrite: Bool = false
    @Published private(set) var isOvertime: Bool = false
    @Published private(set) var timeLeftString: String = "--:--"
    @Published private(set) var elapsedTimeString: String = "00:00"
    @Published private(set) var isFiveMinuteWarning: Bool = false
    
    @Published private(set) var lastError: String?
    
    // MARK: - Private Properties
    
    private let visitId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var timerCancellable: AnyCancellable?
    
    private var currentTick: Date = Date()
    
    // MARK: - Initialization
    
    init(visitId: String) {
        self.visitId = visitId
        setupRealtimeListener()
        setupTimerPublisher()
    }
    
    deinit {
        listener?.remove()
        timerCancellable?.cancel()
    }
    
    // MARK: - Firestore Listener
    
    private func setupRealtimeListener() {
        let visitRef = db.collection("visits").document(visitId)
        
        listener = visitRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.lastError = "Listener error: \(error.localizedDescription)"
                    AppLogger.ui.error("Visit listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot, let data = snapshot.data() else {
                    AppLogger.ui.warning("Visit \(self.visitId): snapshot or data is nil")
                    return
                }
                
                // Track pending writes for UI feedback
                self.isPendingWrite = snapshot.metadata.hasPendingWrites
                
                // Map Firestore fields to properties
                self.scheduledStart = (data["scheduledStart"] as? Timestamp)?.dateValue()
                self.scheduledEnd = (data["scheduledEnd"] as? Timestamp)?.dateValue()
                self.status = data["status"] as? String ?? "scheduled"
                self.sitterId = data["sitterId"] as? String ?? ""
                
                // Extract timeline fields (nested structure)
                if let timeline = data["timeline"] as? [String: Any] {
                    if let checkIn = timeline["checkIn"] as? [String: Any],
                       let checkInTimestamp = checkIn["timestamp"] as? Timestamp {
                        self.actualStart = checkInTimestamp.dateValue()
                        AppLogger.ui.info("VisitViewModel: actualStart = \(checkInTimestamp.dateValue())")
                    } else {
                        self.actualStart = nil
                    }
                    
                    if let checkOut = timeline["checkOut"] as? [String: Any],
                       let checkOutTimestamp = checkOut["timestamp"] as? Timestamp {
                        self.actualEnd = checkOutTimestamp.dateValue()
                        AppLogger.ui.info("VisitViewModel: actualEnd = \(checkOutTimestamp.dateValue())")
                    } else {
                        self.actualEnd = nil
                    }
                } else {
                    self.actualStart = nil
                    self.actualEnd = nil
                }
                
                // Compute scheduled duration if not provided
                if let start = self.scheduledStart, let end = self.scheduledEnd {
                    self.scheduledDurationSeconds = Int(end.timeIntervalSince(start))
                }
                
                // Recompute derived state
                self.recomputeDerivedState()
                
                AppLogger.ui.info("VisitViewModel updated: status=\(self.status), actualStart=\(String(describing: self.actualStart)), actualEnd=\(String(describing: self.actualEnd))")
            }
        }
    }
    
    // MARK: - Timer Publisher (1Hz for UI countdown)
    
    private func setupTimerPublisher() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] tick in
                Task { @MainActor in
                    self?.currentTick = tick
                    self?.recomputeDerivedState()
                }
            }
    }
    
    // MARK: - Derived State Computation
    
    private func recomputeDerivedState() {
        let now = currentTick
        
        guard let scheduledStart = scheduledStart,
              let scheduledEnd = scheduledEnd else {
            // No scheduled times available
            timeLeftString = "--:--"
            elapsedTimeString = "00:00"
            isOvertime = false
            isFiveMinuteWarning = false
            return
        }
        
        // If visit hasn't started (no actualStart), show scheduled duration as time left
        guard let actualStartTime = actualStart else {
            // Not started yet - show scheduled duration
            let scheduledDuration = scheduledEnd.timeIntervalSince(scheduledStart)
            timeLeftString = formatCountdown(seconds: Int(scheduledDuration))
            elapsedTimeString = "00:00"
            isOvertime = false
            isFiveMinuteWarning = false
            return
        }
        
        // Visit has started - compute based on actual start time
        let elapsed = (actualEnd ?? now).timeIntervalSince(actualStartTime)
        elapsedTimeString = formatElapsed(seconds: Int(elapsed))
        
        // If visit is completed (has actualEnd), no more countdown
        if actualEnd != nil {
            timeLeftString = "00:00"
            isOvertime = false
            isFiveMinuteWarning = false
            return
        }
        
        // Visit is in progress - compute time left until scheduled end
        // Following Time-To-Pet pattern: duration is from actualStart to scheduledEnd
        let totalDuration = scheduledEnd.timeIntervalSince(actualStartTime)
        let remaining = totalDuration - elapsed
        
        // Overtime detection
        isOvertime = remaining < 0
        
        // Countdown format (absolute value for overtime display)
        if isOvertime {
            timeLeftString = "+" + formatCountdown(seconds: Int(abs(remaining)))
        } else {
            timeLeftString = formatCountdown(seconds: Int(remaining))
            isFiveMinuteWarning = remaining > 0 && remaining <= 300 // 5 minutes
        }
    }
    
    // MARK: - Formatting Helpers
    
    private func formatCountdown(seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func formatElapsed(seconds: Int) -> String {
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
    
    // MARK: - Public Actions
    
    func startVisit() {
        isPendingWrite = true
        
        AppLogger.ui.info("VisitViewModel: Starting visit \(self.visitId)")
        
        db.collection("visits").document(self.visitId).updateData([
            "status": "in_adventure",
            "timeline.checkIn.timestamp": FieldValue.serverTimestamp(),
            "startedAt": FieldValue.serverTimestamp(),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.isPendingWrite = false
                    self.lastError = error.localizedDescription
                    AppLogger.ui.error("VisitViewModel: Error starting visit - \(error.localizedDescription)")
                    AppLogger.timer.error("Start error - Code: \((error as NSError).code), Domain: \((error as NSError).domain)")
                } else {
                    AppLogger.ui.info("VisitViewModel: Visit started successfully")
                    // Note: isPendingWrite will be cleared by snapshot listener
                    
                    // Send notification to Admin and Pet Owner
                    Task { @MainActor in
                        await self.sendVisitStartNotifications()
                    }
                }
            }
        }
    }
    
    /// Send notifications when visit starts (to Admin and Pet Owner)
    private func sendVisitStartNotifications() async {
        // Fetch visit details from Firestore
        do {
            let visitDoc = try await db.collection("visits").document(visitId).getDocument()
            guard let data = visitDoc.data() else {
                AppLogger.notification.error("Visit data not found for notification")
                return
            }
            
            let sitterName = data["sitterName"] as? String ?? "Sitter"
            let clientId = data["clientId"] as? String ?? ""
            let clientName = data["clientName"] as? String ?? "Client"
            let serviceSummary = data["serviceSummary"] as? String ?? "Service"
            let address = data["address"] as? String
            
            // Send notification via SmartNotificationManager
            SmartNotificationManager.shared.sendVisitStartNotification(
                visitId: visitId,
                sitterName: sitterName,
                clientId: clientId,
                clientName: clientName,
                serviceSummary: serviceSummary,
                address: address
            )
        } catch {
            AppLogger.notification.error("Error fetching visit data for notification: \(error.localizedDescription)")
        }
    }
    
    func endVisit() {
        isPendingWrite = true
        
        AppLogger.timer.info("VisitViewModel: Ending visit \(self.visitId)")
        
        db.collection("visits").document(self.visitId).updateData([
            "status": "completed",
            "timeline.checkOut.timestamp": FieldValue.serverTimestamp(),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.isPendingWrite = false
                    self.lastError = error.localizedDescription
                    AppLogger.ui.error("VisitViewModel: Error ending visit - \(error.localizedDescription)")
                } else {
                    AppLogger.ui.info("VisitViewModel: Visit ended successfully")
                }
            }
        }
    }
    
    func undoStart() {
        isPendingWrite = true
        
        AppLogger.ui.info("VisitViewModel: Undoing visit start \(self.visitId)")
        
        db.collection("visits").document(self.visitId).updateData([
            "status": "scheduled",
            "timeline.checkIn": FieldValue.delete(),
            "startedAt": FieldValue.delete(),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.isPendingWrite = false
                    self.lastError = error.localizedDescription
                    AppLogger.ui.error("VisitViewModel: Error undoing start - \(error.localizedDescription)")
                } else {
                    AppLogger.ui.info("VisitViewModel: Visit start undone successfully")
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        listener?.remove()
        listener = nil
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    // MARK: - Computed Properties for UI
    
    var isStarted: Bool {
        return actualStart != nil || status == "in_adventure" || status == "completed"
    }
    
    var isCompleted: Bool {
        return actualEnd != nil || status == "completed"
    }
    
    var displayStartTime: String {
        if let actual = actualStart {
            return formatTime(actual)
        } else if let scheduled = scheduledStart {
            return formatTime(scheduled) + " (scheduled)"
        }
        return "--:--"
    }
    
    var displayEndTime: String {
        if let actual = actualEnd {
            return formatTime(actual)
        } else if let scheduled = scheduledEnd {
            return formatTime(scheduled) + " (scheduled)"
        }
        return "--:--"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    var startTimeDifference: String? {
        guard let actual = actualStart,
              let scheduled = scheduledStart else {
            return nil
        }
        
        let diff = actual.timeIntervalSince(scheduled)
        let minutes = Int(abs(diff)) / 60
        
        guard minutes > 0 else {
            return nil // On time
        }
        
        return diff < 0 ? "\(minutes)m early" : "\(minutes)m late"
    }
}

