import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import OSLog

struct BulkActionsSheet: View {
    let selectedBookings: Set<String>
    let allBookings: [ServiceBooking]
    let onActionCompleted: () -> Void
    
    @State private var selectedAction: BulkAction? = nil
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showActionConfirmation: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    enum BulkAction: String, CaseIterable, Identifiable {
        case assignSitter = "Assign Sitter"
        case reschedule = "Reschedule"
        case cancel = "Cancel"
        case approve = "Approve"
        case export = "Export"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .assignSitter: return "person.badge.plus"
            case .reschedule: return "calendar.badge.clock"
            case .cancel: return "xmark.circle"
            case .approve: return "checkmark.circle"
            case .export: return "square.and.arrow.up"
            }
        }
        
        var color: Color {
            switch self {
            case .assignSitter: return .blue
            case .reschedule: return .orange
            case .cancel: return .red
            case .approve: return .green
            case .export: return .purple
            }
        }
        
        var isDestructive: Bool {
            return self == .cancel
        }
    }
    
    private var selectedBookingObjects: [ServiceBooking] {
        allBookings.filter { selectedBookings.contains($0.id) }
    }
    
    private var availableActions: [BulkAction] {
        var actions: [BulkAction] = []
        
        let bookings = selectedBookingObjects
        
        // Check if any bookings can be assigned to sitters
        if bookings.contains(where: { $0.status == .pending && $0.sitterId == nil }) {
            actions.append(.assignSitter)
        }
        
        // Check if any bookings can be rescheduled
        if bookings.contains(where: { canReschedule($0) }) {
            actions.append(.reschedule)
        }
        
        // Check if any bookings can be cancelled
        if bookings.contains(where: { canCancel($0) }) {
            actions.append(.cancel)
        }
        
        // Check if any bookings can be approved
        if bookings.contains(where: { $0.status == .pending }) {
            actions.append(.approve)
        }
        
        // Export is always available
        actions.append(.export)
        
        return actions
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Bulk Actions")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(selectedBookings.count) booking\(selectedBookings.count == 1 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Available actions
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(availableActions) { action in
                        BulkActionButton(
                            action: action,
                            isEnabled: !isProcessing,
                            onTap: {
                                selectedAction = action
                                showActionConfirmation = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Selected bookings preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Bookings")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(selectedBookingObjects.prefix(10)) { booking in
                                BookingPreviewRow(booking: booking)
                            }
                            
                            if selectedBookingObjects.count > 10 {
                                Text("... and \(selectedBookingObjects.count - 10) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 200)
                }
                
                Spacer()
                
                // Processing indicator
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Confirm Action", isPresented: $showActionConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedAction = nil
            }
            
            if let action = selectedAction {
                Button(action.rawValue, role: action.isDestructive ? .destructive : nil) {
                    performBulkAction(action)
                }
            }
        } message: {
            if let action = selectedAction {
                Text(confirmationMessage(for: action))
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func canReschedule(_ booking: ServiceBooking) -> Bool {
        let now = Date()
        return booking.scheduledDate > now && 
               booking.status != .completed && 
               booking.status != .cancelled
    }
    
    private func canCancel(_ booking: ServiceBooking) -> Bool {
        let now = Date()
        return booking.scheduledDate > now && 
               booking.status != .completed && 
               booking.status != .cancelled
    }
    
    private func confirmationMessage(for action: BulkAction) -> String {
        switch action {
        case .assignSitter:
            return "Assign a sitter to \(selectedBookings.count) selected booking\(selectedBookings.count == 1 ? "" : "s")?"
        case .reschedule:
            return "Reschedule \(selectedBookings.count) selected booking\(selectedBookings.count == 1 ? "" : "s")?"
        case .cancel:
            return "Cancel \(selectedBookings.count) selected booking\(selectedBookings.count == 1 ? "" : "s")? This action cannot be undone."
        case .approve:
            return "Approve \(selectedBookings.count) selected booking\(selectedBookings.count == 1 ? "" : "s")?"
        case .export:
            return "Export \(selectedBookings.count) selected booking\(selectedBookings.count == 1 ? "" : "s")?"
        }
    }
    
    private func performBulkAction(_ action: BulkAction) {
        isProcessing = true
        
        Task {
            switch action {
            case .assignSitter:
                await assignSittersToBookings()
            case .reschedule:
                await rescheduleBookings()
            case .cancel:
                await cancelBookings()
            case .approve:
                await approveBookings()
            case .export:
                await exportBookings()
            }
            
            await MainActor.run {
                isProcessing = false
                onActionCompleted()
            }
        }
    }
    
    private func assignSittersToBookings() async {
        // TODO: Implement bulk sitter assignment
        AppLogger.ui.info("Assigning sitters to \(selectedBookings.count) bookings")
        
        // For now, just simulate the operation
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    private func rescheduleBookings() async {
        // TODO: Implement bulk rescheduling
        AppLogger.ui.info("Rescheduling \(selectedBookings.count) bookings")
        
        // For now, just simulate the operation
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    private func cancelBookings() async {
        let db = Firestore.firestore()
        
        for bookingId in selectedBookings {
            do {
                let bookingData: [String: Any] = [
                    "status": "cancelled",
                    "lastModified": FieldValue.serverTimestamp(),
                    "lastModifiedBy": Auth.auth().currentUser?.uid ?? "admin",
                    "modificationReason": "Bulk cancellation by admin"
                ]
                try await db.collection("serviceBookings").document(bookingId).updateData(bookingData)
                
                AppLogger.ui.info("Cancelled booking: \(bookingId)")
            } catch {
                AppLogger.ui.error("Failed to cancel booking \(bookingId): \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                return
            }
        }
    }
    
    private func approveBookings() async {
        let db = Firestore.firestore()
        
        for bookingId in selectedBookings {
            do {
                let bookingData: [String: Any] = [
                    "status": "approved",
                    "lastModified": FieldValue.serverTimestamp(),
                    "lastModifiedBy": Auth.auth().currentUser?.uid ?? "admin",
                    "modificationReason": "Bulk approval by admin"
                ]
                try await db.collection("serviceBookings").document(bookingId).updateData(bookingData)
                
                AppLogger.ui.info("Approved booking: \(bookingId)")
            } catch {
                AppLogger.ui.error("Failed to approve booking \(bookingId): \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                return
            }
        }
    }
    
    private func exportBookings() async {
        // TODO: Implement bulk export functionality
        AppLogger.ui.info("Exporting \(selectedBookings.count) bookings")
        
        // For now, just simulate the operation
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
}

// MARK: - Bulk Action Button
private struct BulkActionButton: View {
    let action: BulkActionsSheet.BulkAction
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundColor(action.color)
                
                Text(action.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(action.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Booking Preview Row
private struct BookingPreviewRow: View {
    let booking: ServiceBooking
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.serviceType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(status: booking.status)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    BulkActionsSheet(
        selectedBookings: ["booking1", "booking2"],
        allBookings: [],
        onActionCompleted: {}
    )
}
