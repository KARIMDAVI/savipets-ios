import SwiftUI
import FirebaseFirestore
internal import os
import FirebaseAuth

struct SimpleRescheduleSheet: View {
    let booking: ServiceBooking
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var serviceBookings: ServiceBookingDataService
    private let rescheduleService = BookingRescheduleService()
    
    @State private var newDate: Date = Date()
    @State private var reason: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Booking info header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reschedule Booking")
                        .font(.headline)
                    
                    Text(booking.serviceType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Current:")
                        Text(booking.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.blue)
                        Text("at \(booking.scheduledTime)")
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // New date selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select New Date & Time")
                        .font(.headline)
                    
                    DatePicker("New Date & Time", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "en_US"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                        .environment(\.timeZone, TimeZone(identifier: "America/New_York") ?? .current)
                }
                
                // Reason for rescheduling
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reason for Rescheduling")
                        .font(.headline)
                    
                    TextField("Please provide a reason...", text: $reason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: rescheduleBooking) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isProcessing ? "Rescheduling..." : "Reschedule Booking")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canReschedule ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canReschedule || isProcessing)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .onAppear {
            // Set initial date to booking date + 1 day
            newDate = Calendar.current.date(byAdding: .day, value: 1, to: booking.scheduledDate) ?? Date()
        }
    }
    
    private var canReschedule: Bool {
        let now = Date()
        let hoursUntilNewVisit = newDate.timeIntervalSince(now) / 3600
        let _ = booking.scheduledDate.timeIntervalSince(now) / 3600
        
        // Must be at least 2 hours in the future
        // Must provide a reason
        // New date must be different from current date
        return hoursUntilNewVisit >= 2 && 
               !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               abs(newDate.timeIntervalSince(booking.scheduledDate)) > 3600 // At least 1 hour difference
    }
    
    private func rescheduleBooking() {
        guard canReschedule else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
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
                        dismiss()
                    } else {
                        errorMessage = result.message
                    }
                }
                
                AppLogger.ui.info("Booking \(booking.id) reschedule result: \(result.message)")
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to reschedule booking: \(error.localizedDescription)"
                }
                AppLogger.ui.error("Reschedule failed: \(error.localizedDescription)")
            }
        }
    }
}
