import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Two-stage confirmation sheet for booking cancellation with refund calculation
struct CancelConfirmationSheet: View {
    let booking: ServiceBooking
    let onCompletion: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingStage2 = false
    @State private var selectedCancellationType: CancellationType = .single
    @State private var cancellationReason = ""
    @State private var understandsPolicy = false
    @State private var isCancelling = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Services
    private let auditService = AuditTrailService()
    
    enum CancellationType: String, CaseIterable {
        case single = "Cancel Single Visit"
        case series = "Cancel Entire Series"
        
        var description: String {
            switch self {
            case .single: return "Cancel only this visit"
            case .series: return "Cancel all future visits in this series"
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.l) {
                    if !showingStage2 {
                        // Stage 1: Cancellation Type Selection
                        stage1Content
                    } else {
                        // Stage 2: Confirmation and Details
                        stage2Content
                    }
                }
                .padding(SPDesignSystem.Spacing.m)
            }
            .navigationTitle("Cancel Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(showingStage2 ? "Back" : "Cancel") {
                        if showingStage2 {
                            showingStage2 = false
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
    
    // MARK: - Stage 1 Content
    
    private var stage1Content: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.l) {
            // Header
            headerSection
            
            // Cancellation Policy
            cancellationPolicySection
            
            // Cancellation Type Selection
            cancellationTypeSection
            
            // Continue Button
            continueButton
        }
    }
    
    // MARK: - Stage 2 Content
    
    private var stage2Content: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.l) {
            // Booking Summary
            bookingSummarySection
            
            // Refund Calculation
            refundCalculationSection
            
            // Reason Section
            reasonSection
            
            // Policy Confirmation
            policyConfirmationSection
            
            // Final Confirmation Button
            finalConfirmationButton
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("Cancel Booking")
                    .font(SPDesignSystem.Typography.heading2())
                    .foregroundColor(.red)
            }
            
            Text("Are you sure you want to cancel this booking?")
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(.primary)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Cancellation Policy Section
    
    private var cancellationPolicySection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Cancellation Policy")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                PolicyRow(
                    icon: "clock.fill",
                    iconColor: .green,
                    title: "24+ hours notice",
                    description: "Full refund"
                )
                
                PolicyRow(
                    icon: "clock.badge.exclamationmark",
                    iconColor: .orange,
                    title: "Less than 24 hours",
                    description: "50% refund"
                )
                
                PolicyRow(
                    icon: "xmark.circle.fill",
                    iconColor: .red,
                    title: "Within 2 hours",
                    description: "No refund"
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Cancellation Type Section
    
    private var cancellationTypeSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            cancellationTypeHeader
            cancellationTypeOptions
        }
    }
    
    private var cancellationTypeHeader: some View {
        HStack {
            Image(systemName: "repeat")
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            
            Text("Cancellation Type")
                .font(SPDesignSystem.Typography.heading3())
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
        }
    }
    
    private var cancellationTypeOptions: some View {
        VStack(spacing: 12) {
            ForEach(CancellationType.allCases, id: \.self) { type in
                cancellationTypeButton(for: type)
            }
        }
    }
    
    private func cancellationTypeButton(for type: CancellationType) -> some View {
        Button(action: { selectedCancellationType = type }) {
            HStack {
                Image(systemName: selectedCancellationType == type ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(SPDesignSystem.Typography.bodyMedium())
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(SPDesignSystem.Spacing.m)
            .background(SPDesignSystem.Colors.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(cancellationTypeBorder(for: type))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!booking.isRecurring && type == .series)
    }
    
    private func cancellationTypeBorder(for type: CancellationType) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                selectedCancellationType == type ? SPDesignSystem.Colors.primaryAdjusted(colorScheme) : Color.clear,
                lineWidth: 2
            )
    }
    
    // MARK: - Booking Summary Section
    
    private var bookingSummarySection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Booking Summary")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                SummaryRow(label: "Service", value: booking.serviceType)
                SummaryRow(label: "Date & Time", value: dateFormatter.string(from: booking.scheduledDate))
                SummaryRow(label: "Duration", value: "\(booking.duration) minutes")
                SummaryRow(label: "Pets", value: booking.pets.joined(separator: ", "))
                SummaryRow(label: "Sitter", value: booking.sitterName ?? "Not assigned")
                SummaryRow(label: "Total Price", value: "$\(String(format: "%.2f", booking.price))")
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Refund Calculation Section
    
    private var refundCalculationSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Refund Calculation")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Original Amount:")
                    Spacer()
                    Text("$\(String(format: "%.2f", booking.price))")
                }
                
                HStack {
                    Text("Refund Rate:")
                    Spacer()
                    Text("\(refundRate)%")
                        .foregroundColor(refundRate == 100 ? .green : refundRate == 50 ? .orange : .red)
                }
                
                HStack {
                    Text("Refund Amount:")
                        .font(SPDesignSystem.Typography.bodyMedium())
                    Spacer()
                    Text("$\(String(format: "%.2f", refundAmount))")
                        .font(SPDesignSystem.Typography.bodyMedium())
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                }
                
                if refundAmount < (Double(booking.price) ?? 0.0) {
                    HStack {
                        Text("Processing Fee:")
                        Spacer()
                        Text("$\(String(format: "%.2f", (Double(booking.price) ?? 0.0) - refundAmount))")
                            .foregroundColor(.red)
                    }
                }
                
                if refundAmount > 0 {
                    Text("Refund will be processed within 3-5 business days to your original payment method.")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
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
                
                Text("Reason for Cancellation")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            TextField("Optional - Help us improve our service", text: $cancellationReason, axis: .vertical)
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
    
    // MARK: - Policy Confirmation Section
    
    private var policyConfirmationSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Button(action: { understandsPolicy.toggle() }) {
                    Image(systemName: understandsPolicy ? "checkmark.square.fill" : "square")
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                }
                
                Text("I understand the cancellation policy")
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.primary)
            }
            
            if !understandsPolicy {
                Text("Please confirm that you understand the cancellation policy to proceed.")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.red)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button(action: { showingStage2 = true }) {
            Text("Continue")
                .font(SPDesignSystem.Typography.button())
        }
        .buttonStyle(PrimaryButtonStyleBrightInLight())
        .disabled(selectedCancellationType == .series && !booking.isRecurring)
        .padding(.top, SPDesignSystem.Spacing.l)
    }
    
    // MARK: - Final Confirmation Button
    
    private var finalConfirmationButton: some View {
        Button(action: executeCancellation) {
            HStack {
                if isCancelling {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                }
                
                Text(isCancelling ? "Cancelling..." : "Confirm Cancellation")
                    .font(SPDesignSystem.Typography.button())
            }
        }
        .buttonStyle(DarkButtonStyle())
        .disabled(!understandsPolicy || isCancelling)
        .padding(.top, SPDesignSystem.Spacing.l)
    }
    
    // MARK: - Computed Properties
    
    private var hoursUntilVisit: Double {
        booking.scheduledDate.timeIntervalSince(Date()) / 3600
    }
    
    private var refundRate: Int {
        if hoursUntilVisit >= 24 {
            return 100
        } else if hoursUntilVisit >= 2 {
            return 50
        } else {
            return 0
        }
    }
    
    private var refundAmount: Double {
        (Double(booking.price) ?? 0.0) * Double(refundRate) / 100.0
    }
    
    // MARK: - Actions
    
    private func executeCancellation() {
        guard understandsPolicy else {
            errorMessage = "Please confirm that you understand the cancellation policy"
            showingError = true
            return
        }
        
        isCancelling = true
        
        Task {
            do {
                let db = Firestore.firestore()
                
                // Update booking status
                var updateData: [String: Any] = [
                    "status": ServiceBooking.BookingStatus.cancelled.rawValue,
                    "lastModified": Timestamp(date: Date()),
                    "lastModifiedBy": Auth.auth().currentUser?.uid ?? "unknown",
                    "modificationReason": "Cancelled by client",
                    "cancellationReason": cancellationReason,
                    "cancellationType": selectedCancellationType.rawValue,
                    "refundAmount": refundAmount,
                    "refundRate": refundRate
                ]
                
                // If cancelling entire series, mark as series cancellation
                if selectedCancellationType == .series {
                    updateData["seriesCancelled"] = true
                }
                
                try await db.collection("serviceBookings")
                    .document(booking.id)
                    .updateData(updateData)
                
                // Log the cancellation
                await auditService.logEvent(
                    action: .bookingCancelled,
                    userId: Auth.auth().currentUser?.uid,
                    resourceType: .booking,
                    resourceId: booking.id,
                    details: [
                        "cancellationType": selectedCancellationType.rawValue,
                        "reason": cancellationReason,
                        "refundAmount": refundAmount,
                        "refundRate": refundRate,
                        "hoursUntilVisit": hoursUntilVisit
                    ]
                )
                
                // TODO: Process refund through payment system
                if refundAmount > 0 {
                    // await processRefund(amount: refundAmount, bookingId: booking.id)
                }
                
                // TODO: Notify sitter about cancellation
                // await notifySitterOfCancellation()
                
                await MainActor.run {
                    onCompletion(true)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to cancel booking: \(error.localizedDescription)"
                    showingError = true
                    isCancelling = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct PolicyRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    CancelConfirmationSheet(
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
