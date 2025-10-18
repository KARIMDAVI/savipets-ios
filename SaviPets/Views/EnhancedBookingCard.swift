import SwiftUI
import OSLog

struct EnhancedBookingCard: View {
    let booking: ServiceBooking
    let clientName: String?
    let sitterName: String?
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    
    @State private var showDetails: Bool = false
    @State private var showRescheduleSheet: Bool = false
    @State private var showCancelAlert: Bool = false
    @State private var showAssignSitterSheet: Bool = false
    
    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header with selection and status
                HStack {
                    Button(action: onSelectionToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .gray)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(booking.serviceType)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                            Text("at \(booking.scheduledTime)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusBadge(status: booking.status)
                        
                        if booking.isRecurring {
                            HStack(spacing: 2) {
                                Image(systemName: "repeat")
                                    .font(.caption2)
                                Text("Recurring")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // Client and sitter info
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Client")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(clientName ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if let sitterName = sitterName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sitter")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(sitterName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    } else if booking.status == .pending {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sitter")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Unassigned")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(booking.price)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                // Pets
                if !booking.pets.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Pets: \(booking.pets.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Address
                if let address = booking.address, !address.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Special instructions preview
                if let note = booking.specialInstructions, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Payment status
                if let paymentStatus = booking.paymentStatus {
                    HStack(spacing: 6) {
                        Image(systemName: paymentStatusIcon(paymentStatus))
                            .font(.caption)
                            .foregroundColor(paymentStatusColor(paymentStatus))
                        Text("Payment: \(paymentStatus.displayName)")
                            .font(.caption)
                            .foregroundColor(paymentStatusColor(paymentStatus))
                    }
                }
                
                // Reschedule history indicator
                if !booking.rescheduleHistory.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text("Rescheduled \(booking.rescheduleHistory.count) time\(booking.rescheduleHistory.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Details") {
                        showDetails = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    if canModifyBooking() {
                        Button("Reschedule") {
                            showRescheduleSheet = true
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        
                        Button("Cancel") {
                            showCancelAlert = true
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    if booking.status == .pending && booking.sitterId == nil {
                        Button("Assign Sitter") {
                            showAssignSitterSheet = true
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                    }
                }
            }
        }
        .sheet(isPresented: $showDetails) {
            BookingDetailsSheet(booking: booking, clientName: clientName, sitterName: sitterName)
        }
        .sheet(isPresented: $showRescheduleSheet) {
            RescheduleBookingSheet(booking: booking)
        }
        .sheet(isPresented: $showAssignSitterSheet) {
            AssignSitterSheet(booking: booking)
        }
        .alert("Cancel Booking", isPresented: $showCancelAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) {
                cancelBooking()
            }
        } message: {
            Text("Are you sure you want to cancel this booking? This action cannot be undone.")
        }
    }
    
    private func canModifyBooking() -> Bool {
        let now = Date()
        
        // Can modify if booking hasn't started yet
        return booking.scheduledDate > now && 
               booking.status != .completed && 
               booking.status != .cancelled
    }
    
    private func paymentStatusIcon(_ status: PaymentStatus) -> String {
        switch status {
        case .pending:
            return "clock"
        case .confirmed:
            return "checkmark.circle"
        case .failed:
            return "xmark.circle"
        case .declined:
            return "arrow.uturn.backward.circle"
        }
    }
    
    private func paymentStatusColor(_ status: PaymentStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .confirmed:
            return .green
        case .failed:
            return .red
        case .declined:
            return .blue
        }
    }
    
    private func cancelBooking() {
        AppLogger.ui.info("Cancelling booking: \(booking.id)")
        // TODO: Implement booking cancellation
    }
}

// MARK: - Booking Details Sheet
struct BookingDetailsSheet: View {
    let booking: ServiceBooking
    let clientName: String?
    let sitterName: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Basic info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Booking Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        DetailRow(label: "Booking ID", value: booking.id)
                        DetailRow(label: "Service Type", value: booking.serviceType)
                        DetailRow(label: "Date & Time", value: "\(booking.scheduledDate.formatted(date: .complete, time: .shortened))")
                        DetailRow(label: "Duration", value: "\(booking.duration) minutes")
                        DetailRow(label: "Status", value: booking.status.displayName)
                        DetailRow(label: "Price", value: booking.price)
                        DetailRow(label: "Created", value: booking.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    // Client & Sitter
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assignment")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        DetailRow(label: "Client ID", value: booking.clientId)
                        DetailRow(label: "Client Name", value: clientName ?? "Unknown")
                        
                        if let sitterId = booking.sitterId {
                            DetailRow(label: "Sitter ID", value: sitterId)
                        }
                        
                        DetailRow(label: "Sitter Name", value: sitterName ?? "Unassigned")
                    }
                    
                    // Pets
                    if !booking.pets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pets")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            ForEach(booking.pets, id: \.self) { pet in
                                HStack {
                                    Image(systemName: "pawprint.fill")
                                        .foregroundColor(.orange)
                                    Text(pet)
                                }
                            }
                        }
                    }
                    
                    // Address
                    if let address = booking.address, !address.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Address")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text(address)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Special instructions
                    if let note = booking.specialInstructions, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Special Instructions")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text(note)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Payment information
                    if let paymentStatus = booking.paymentStatus {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Payment Information")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            DetailRow(label: "Status", value: paymentStatus.displayName)
                            
                            if let transactionId = booking.paymentTransactionId {
                                DetailRow(label: "Transaction ID", value: transactionId)
                            }
                            
                            if let amount = booking.paymentAmount {
                                DetailRow(label: "Amount", value: "$\(String(format: "%.2f", amount))")
                            }
                            
                            if let method = booking.paymentMethod {
                                DetailRow(label: "Method", value: method)
                            }
                        }
                    }
                    
                    // Recurring information
                    if booking.isRecurring {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recurring Booking")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            DetailRow(label: "Series ID", value: booking.recurringSeriesId ?? "Unknown")
                            DetailRow(label: "Visit Number", value: "\(booking.visitNumber ?? 1)")
                        }
                    }
                    
                    // Reschedule history
                    if !booking.rescheduleHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reschedule History")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(booking.rescheduleHistory.enumerated()), id: \.offset) { index, entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.requestedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("From: \(entry.originalDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                    
                                    Text("To: \(entry.newDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                    
                                    if !entry.reason.isEmpty {
                                        Text("Reason: \(entry.reason)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Modification history
                    if let lastModified = booking.lastModified {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Modified")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            DetailRow(label: "Date", value: lastModified.formatted(date: .abbreviated, time: .shortened))
                            
                            if let modifiedBy = booking.lastModifiedBy {
                                DetailRow(label: "Modified By", value: modifiedBy)
                            }
                            
                            if let reason = booking.modificationReason {
                                DetailRow(label: "Reason", value: reason)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Booking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Assign Sitter Sheet
struct AssignSitterSheet: View {
    let booking: ServiceBooking
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sitterData = SitterDataService()
    @State private var selectedSitterId: String? = nil
    @State private var isAssigning: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Assign Sitter")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Select a sitter for this booking:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if sitterData.availableSitters.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("No Available Sitters")
                            .font(.headline)
                        
                        Text("There are currently no available sitters for this booking.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(sitterData.availableSitters) { sitter in
                            SitterRow(
                                sitter: sitter,
                                isSelected: selectedSitterId == sitter.id,
                                onTap: { selectedSitterId = sitter.id }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Assign Sitter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Assign") {
                        assignSitter()
                    }
                    .disabled(selectedSitterId == nil || isAssigning)
                }
            }
        }
        .onAppear {
            sitterData.listenToActiveSitters()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func assignSitter() {
        guard let sitterId = selectedSitterId else { return }
        
        isAssigning = true
        
        Task {
            // TODO: Implement sitter assignment logic
            AppLogger.ui.info("Assigning sitter \(sitterId) to booking \(booking.id)")
            
            await MainActor.run {
                isAssigning = false
                dismiss()
            }
        }
    }
}

// MARK: - Sitter Row
private struct SitterRow: View {
    let sitter: SitterProfile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(sitter.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.green)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(sitter.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(sitter.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", sitter.rating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(sitter.totalVisits) completed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EnhancedBookingCard(
        booking: ServiceBooking(
            id: "test",
            clientId: "client1",
            serviceType: "Dog Walking",
            scheduledDate: Date(),
            scheduledTime: "10:00 AM",
            duration: 30,
            pets: ["Buddy", "Max"],
            specialInstructions: "Test instructions",
            status: .pending,
            sitterId: nil,
            sitterName: nil,
            createdAt: Date(),
            address: "123 Main St",
            checkIn: nil,
            checkOut: nil,
            price: "$25.00",
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
            lastModified: nil,
            lastModifiedBy: nil,
            modificationReason: nil
        ),
        clientName: "John Doe",
        sitterName: nil,
        isSelected: false,
        onSelectionToggle: {}
    )
}

// MARK: - DetailRow Component
private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
