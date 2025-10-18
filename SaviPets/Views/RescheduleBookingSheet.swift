import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct RescheduleBookingSheet: View {
    let booking: ServiceBooking
    @Environment(\.dismiss) private var dismiss
    private let rescheduleService = BookingRescheduleService()
    
    @State private var newDate: Date = Date()
    @State private var reason: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showingConflictResolution: Bool = false
    @State private var availableSlots: [TimeSlot] = []
    @State private var selectedSlot: TimeSlot? = nil
    @State private var showingAvailableSlots: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with booking info
                    bookingInfoHeader
                    
                    // New date selection
                    dateSelectionSection
                    
                    // Available slots (if sitter is assigned)
                    if let sitterId = booking.sitterId, !sitterId.isEmpty {
                        availableSlotsSection
                    }
                    
                    // Reason for rescheduling
                    reasonSection
                    
                    // Error/Success messages
                    if let errorMessage = errorMessage {
                        errorMessageView(errorMessage)
                    }
                    
                    if let successMessage = successMessage {
                        successMessageView(successMessage)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Reschedule Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reschedule") {
                        Task {
                            await rescheduleBooking()
                        }
                    }
                    .disabled(!canReschedule || isProcessing)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            setupInitialDate()
            loadAvailableSlots()
        }
    }
    
    private var bookingInfoHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Booking")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(booking.serviceType)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    StatusBadge(status: booking.status)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text(booking.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.blue)
                }
                .font(.caption)
                
                if let sitterName = booking.sitterName {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                        Text("Sitter: \(sitterName)")
                            .foregroundColor(.green)
                    }
                    .font(.caption)
                }
                
                if !booking.pets.isEmpty {
                    HStack {
                        Image(systemName: "pawprint.fill")
                            .foregroundColor(.secondary)
                        Text("Pets: \(booking.pets.joined(separator: ", "))")
                    }
                    .font(.caption)
                }
                
                // Show reschedule history if exists
                if !booking.rescheduleHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Previous Reschedules")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        ForEach(booking.rescheduleHistory.suffix(2)) { entry in
                            Text("• \(entry.originalDate.formatted(date: .abbreviated, time: .shortened)) → \(entry.newDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var dateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select New Date & Time")
                .font(.headline)
                .foregroundColor(.primary)
            
            DatePicker("New Date & Time", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
                .environment(\.timeZone, TimeZone(identifier: "America/New_York") ?? .current)
                .onChange(of: newDate) { _ in
                    loadAvailableSlots()
                }
            
            // Business hours indicator
            if !isWithinBusinessHours(newDate) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Outside business hours (8 AM - 8 PM)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Minimum notice indicator
            let hoursUntilNewVisit = newDate.timeIntervalSince(Date()) / 3600
            if hoursUntilNewVisit < 2 {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.red)
                    Text("Less than 2 hours notice required")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var availableSlotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Time Slots")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Refresh") {
                    loadAvailableSlots()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if availableSlots.isEmpty {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                    Text("Loading available slots...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableSlots.indices, id: \.self) { index in
                            let slot = availableSlots[index]
                            Button(action: {
                                selectedSlot = slot
                                newDate = slot.start
                            }) {
                                VStack(spacing: 4) {
                                    Text(slot.start.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("Available")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedSlot?.start == slot.start ? Color.blue : Color(.systemGray6))
                                )
                                .foregroundColor(selectedSlot?.start == slot.start ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reason for Rescheduling")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Please provide a reason for rescheduling...", text: $reason, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            
            // Common reasons quick select
            VStack(alignment: .leading, spacing: 8) {
                Text("Common Reasons")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(commonReasons, id: \.self) { commonReason in
                        Button(action: {
                            reason = commonReason
                        }) {
                            Text(commonReason)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    private func errorMessageView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func successMessageView(_ message: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var canReschedule: Bool {
        let hoursUntilNewVisit = newDate.timeIntervalSince(Date()) / 3600
        return hoursUntilNewVisit >= 2 && 
               !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               abs(newDate.timeIntervalSince(booking.scheduledDate)) > 3600 &&
               isWithinBusinessHours(newDate)
    }
    
    private var commonReasons: [String] {
        [
            "Schedule conflict",
            "Pet is sick",
            "Weather concerns",
            "Emergency",
            "Travel delay",
            "Other commitment"
        ]
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialDate() {
        // Set initial date to booking date + 1 day
        newDate = Calendar.current.date(byAdding: .day, value: 1, to: booking.scheduledDate) ?? Date()
    }
    
    private func isWithinBusinessHours(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour >= 8 && hour <= 20
    }
    
    private func loadAvailableSlots() {
        guard let sitterId = booking.sitterId, !sitterId.isEmpty else { return }
        
        Task {
            do {
                let slots = try await rescheduleService.getSitterAvailability(
                    sitterId: sitterId,
                    date: newDate,
                    duration: booking.duration
                )
                
                await MainActor.run {
                    availableSlots = slots
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load available slots: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func rescheduleBooking() async {
        guard canReschedule else { return }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let result = try await rescheduleService.rescheduleBooking(
                bookingId: booking.id,
                newDate: newDate,
                reason: reason,
                requestedBy: Auth.auth().currentUser?.uid ?? "unknown"
            )
            
            await MainActor.run {
                isProcessing = false
                
                if result.success {
                    successMessage = result.message
                    // Dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                } else {
                    errorMessage = result.message
                }
            }
            
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Failed to reschedule booking: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Status Badge Component

