import SwiftUI
import Combine
import FirebaseAuth

/// Sheet for rescheduling a booking with availability checking
struct RescheduleSheet: View {
    let booking: ServiceBooking
    let onCompletion: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var reason = ""
    @State private var isCheckingAvailability = false
    @State private var availabilityStatus: AvailabilityStatus = .unknown
    @State private var showingConfirmation = false
    @State private var isRescheduling = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Services
    private let rescheduleService = BookingRescheduleService()
    private let conflictService = BookingConflictService()
    private let auditService = AuditTrailService()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    enum AvailabilityStatus {
        case unknown
        case available
        case conflict
        case checking
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .available: return .green
            case .conflict: return .red
            case .checking: return .orange
            }
        }
        
        var systemImage: String {
            switch self {
            case .unknown: return "questionmark.circle"
            case .available: return "checkmark.circle.fill"
            case .conflict: return "xmark.circle.fill"
            case .checking: return "clock"
            }
        }
        
        var message: String {
            switch self {
            case .unknown: return "Select a date and time"
            case .available: return "Sitter is available"
            case .conflict: return "Sitter has a conflict"
            case .checking: return "Checking availability..."
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.l) {
                    // Header
                    headerSection
                    
                    // Date Picker
                    datePickerSection
                    
                    // Time Picker
                    timePickerSection
                    
                    // Availability Status
                    availabilitySection
                    
                    // Reason Section
                    reasonSection
                    
                    // Cost Adjustment Preview
                    if hasCostAdjustment {
                        costAdjustmentSection
                    }
                    
                    // Business Rules Warnings
                    businessRulesSection
                    
                    // Confirmation Button
                    confirmationButton
                }
                .padding(SPDesignSystem.Spacing.m)
            }
            .navigationTitle("Reschedule Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .alert("Confirm Reschedule", isPresented: $showingConfirmation) {
                Button("Reschedule", role: .destructive) {
                    performReschedule()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to reschedule this visit to \(dateFormatter.string(from: newScheduledDate)) at \(timeFormatter.string(from: newScheduledDate))?")
            }
        }
        .onAppear {
            selectedDate = booking.scheduledDate
            selectedTime = booking.scheduledDate
        }
        .onChange(of: selectedDate) { _ in
            checkAvailability()
        }
        .onChange(of: selectedTime) { _ in
            checkAvailability()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Reschedule \(booking.serviceType)")
                .font(SPDesignSystem.Typography.heading2())
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            
            Text("Current: \(dateFormatter.string(from: booking.scheduledDate)) at \(timeFormatter.string(from: booking.scheduledDate))")
                .font(SPDesignSystem.Typography.callout())
                .foregroundColor(.secondary)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Date Picker Section
    
    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Select Date")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            DatePicker(
                "Date",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .accentColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Time Picker Section
    
    private var timePickerSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Select Time")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            DatePicker(
                "Time",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .accentColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Availability Section
    
    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: availabilityStatus.systemImage)
                    .foregroundColor(availabilityStatus.color)
                    .rotationEffect(.degrees(availabilityStatus == .checking ? 360 : 0))
                    .animation(
                        availabilityStatus == .checking ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: availabilityStatus
                    )
                
                Text("Availability")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            Text(availabilityStatus.message)
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(availabilityStatus.color)
            
            if availabilityStatus == .conflict {
                Text("Please choose a different time or contact us for assistance.")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Reason Section
    
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Reason for Reschedule")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            TextField("Optional - Help us improve our service", text: $reason, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(SPDesignSystem.Spacing.s)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .lineLimit(3...6)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Cost Adjustment Section
    
    private var costAdjustmentSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Cost Adjustment")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            HStack {
                Text("Original Price:")
                Spacer()
                Text("$\(String(format: "%.2f", booking.price))")
            }
            
            HStack {
                Text("New Price:")
                Spacer()
                Text("$\(String(format: "%.2f", adjustedPrice))")
                    .font(SPDesignSystem.Typography.bodyMedium())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            if adjustedPrice != (Double(booking.price) ?? 0.0) {
                HStack {
                    Text("Difference:")
                    Spacer()
                    Text("\(adjustedPrice > (Double(booking.price) ?? 0.0) ? "+" : "")$\(String(format: "%.2f", adjustedPrice - (Double(booking.price) ?? 0.0)))")
                        .font(SPDesignSystem.Typography.bodyMedium())
                        .foregroundColor(adjustedPrice > (Double(booking.price) ?? 0.0) ? .red : .green)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Business Rules Section
    
    private var businessRulesSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                
                Text("Important Notes")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if isWithin24Hours {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.red)
                        Text("Less than 24 hours notice - may incur additional charges")
                            .font(SPDesignSystem.Typography.callout())
                            .foregroundColor(.red)
                    }
                }
                
                if !isWithinBusinessHours {
                    HStack {
                        Image(systemName: "moon")
                            .foregroundColor(.orange)
                        Text("Outside business hours (8 AM - 8 PM)")
                            .font(SPDesignSystem.Typography.callout())
                            .foregroundColor(.orange)
                    }
                }
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Your sitter will be notified of this change")
                        .font(SPDesignSystem.Typography.callout())
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Confirmation Button
    
    private var confirmationButton: some View {
        Button(action: {
            showingConfirmation = true
        }) {
            HStack {
                if isRescheduling {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                }
                
                Text(isRescheduling ? "Rescheduling..." : "Reschedule Visit")
                    .font(SPDesignSystem.Typography.button())
            }
        }
        .buttonStyle(PrimaryButtonStyleBrightInLight())
        .disabled(availabilityStatus != .available || isRescheduling)
        .padding(.top, SPDesignSystem.Spacing.l)
    }
    
    // MARK: - Computed Properties
    
    private var newScheduledDate: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        return calendar.date(from: combinedComponents) ?? selectedDate
    }
    
    private var isWithin24Hours: Bool {
        let hoursUntil = newScheduledDate.timeIntervalSince(Date()) / 3600
        return hoursUntil < 24
    }
    
    private var isWithinBusinessHours: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: newScheduledDate)
        return hour >= 8 && hour <= 20
    }
    
    private var hasCostAdjustment: Bool {
        // Peak hours or last-minute changes might have cost adjustments
        return isWithin24Hours || !isWithinBusinessHours
    }
    
    private var adjustedPrice: Double {
        var price = Double(booking.price) ?? 0.0
        
        // Last-minute reschedule fee
        if isWithin24Hours {
            price += 5.0
        }
        
        // Outside business hours fee
        if !isWithinBusinessHours {
            price += 10.0
        }
        
        return price
    }
    
    // MARK: - Actions
    
    private func checkAvailability() {
        guard let sitterId = booking.sitterId else {
            availabilityStatus = .available
            return
        }
        
        availabilityStatus = .checking
        
        Task {
            do {
                let isAvailable = try await conflictService.isSlotAvailable(
                    for: sitterId,
                    start: newScheduledDate,
                    duration: booking.duration
                )
                
                await MainActor.run {
                    availabilityStatus = isAvailable ? .available : .conflict
                }
            } catch {
                await MainActor.run {
                    availabilityStatus = .conflict
                    errorMessage = "Failed to check availability: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func performReschedule() {
        isRescheduling = true
        
        Task {
            do {
                let result = try await rescheduleService.rescheduleBooking(
                    bookingId: booking.id,
                    newDate: newScheduledDate,
                    reason: reason.isEmpty ? "No reason provided" : reason,
                    requestedBy: Auth.auth().currentUser?.uid ?? "unknown"
                )
                
                await MainActor.run {
                    if result.success {
                        // Log the reschedule action
                        Task {
                        await auditService.logEvent(
                            action: .bookingModified,
                            userId: Auth.auth().currentUser?.uid,
                            resourceType: .booking,
                            resourceId: booking.id,
                            details: [
                                "originalDate": booking.scheduledDate,
                                "newDate": selectedDate,
                                "reason": reason,
                                "operation": "reschedule"
                            ]
                            )
                        }
                        
                        // Show success toast (would be implemented with a toast system)
                        onCompletion(true)
                        dismiss()
                    } else {
                        errorMessage = result.message
                        showingError = true
                        isRescheduling = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to reschedule: \(error.localizedDescription)"
                    showingError = true
                    isRescheduling = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RescheduleSheet(
        booking: ServiceBooking(
            id: "preview",
            clientId: "client1",
            serviceType: "Dog Walking",
            scheduledDate: Date().addingTimeInterval(3600),
            scheduledTime: "10:00 AM",
            duration: 30,
            pets: ["Buddy"],
            specialInstructions: "",
            status: .approved,
            sitterId: "sitter1",
            sitterName: "Sarah Johnson",
            createdAt: Date(),
            address: "123 Main St",
            checkIn: nil,
            checkOut: nil,
            price: "25.00",
            recurringSeriesId: nil,
            visitNumber: nil,
            isRecurring: false,
            paymentStatus: .confirmed,
            paymentTransactionId: nil,
            paymentAmount: 25.0,
            paymentMethod: "credit_card",
            rescheduledFrom: nil,
            rescheduledAt: nil,
            rescheduledBy: nil,
            rescheduleReason: nil,
            rescheduleHistory: [],
            lastModified: Date(),
            lastModifiedBy: "client1",
            modificationReason: nil
        ),
        onCompletion: { _ in }
    )
}
