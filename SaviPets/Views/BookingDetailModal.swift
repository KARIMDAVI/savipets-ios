import SwiftUI

/// Full-screen modal showing complete booking details
struct BookingDetailModal: View {
    let booking: ServiceBooking
    let onReschedule: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void
    let onManageRecurring: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
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
                    // Header Section
                    headerSection
                    
                    // Date & Time Section
                    dateTimeSection
                    
                    // Pets Section
                    petsSection
                    
                    // Sitter Section
                    if let sitterName = booking.sitterName {
                        sitterSection(sitterName: sitterName)
                    }
                    
                    // Location Section
                    locationSection
                    
                    // Special Instructions Section
                    if let instructions = booking.specialInstructions, !instructions.isEmpty {
                        instructionsSection
                    }
                    
                    // Price Breakdown Section
                    priceBreakdownSection
                    
                    // Recurring Series Info
                    if booking.isRecurring {
                        recurringSeriesSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding(SPDesignSystem.Spacing.m)
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.serviceType)
                        .font(SPDesignSystem.Typography.heading2())
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                    
                    Text("Duration: \(booking.duration) minutes")
                        .font(SPDesignSystem.Typography.callout())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: booking.status)
            }
            
            // Service description removed as property doesn't exist
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Date & Time Section
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Date & Time")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: booking.scheduledDate))
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(.primary)
                
                // Time until visit
                let timeUntil = timeUntilVisit
                if timeUntil > 0 {
                    Text(timeUntilText)
                        .font(SPDesignSystem.Typography.callout())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Pets Section
    
    private var petsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Pets")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    ForEach(booking.pets, id: \.self) { petName in
                        PetCard(petName: petName)
                    }
                }
                .padding(.horizontal, SPDesignSystem.Spacing.xs)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Sitter Section
    
    private func sitterSection(sitterName: String) -> some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Assigned Sitter")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            HStack(spacing: SPDesignSystem.Spacing.s) {
                // Sitter photo placeholder
                Circle()
                    .fill(SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(sitterName)
                        .font(SPDesignSystem.Typography.bodyMedium())
                        .foregroundColor(.primary)
                    
                    Text("4.8 ⭐ • 150+ visits")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Location")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            Text(booking.address ?? "")
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(.primary)
            
            Button("Open in Maps") {
                // Open in Maps functionality would go here
            }
            .font(SPDesignSystem.Typography.callout())
            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Instructions Section
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Special Instructions")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            Text(booking.specialInstructions ?? "")
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Price Breakdown Section
    
    private var priceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Price Breakdown")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Base Service")
                        .font(SPDesignSystem.Typography.body())
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", totalPrice))")
                        .font(SPDesignSystem.Typography.body())
                        .foregroundColor(.primary)
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .font(SPDesignSystem.Typography.heading3())
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                    
                    Spacer()
                    Text("$\(String(format: "%.2f", totalPrice))")
                        .font(SPDesignSystem.Typography.heading3())
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Recurring Series Section
    
    private var recurringSeriesSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "repeat")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Recurring Series")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Dog Walk")
                    .font(SPDesignSystem.Typography.bodyMedium())
                    .foregroundColor(.primary)
                
                Text("Visit \(booking.visitNumber ?? 1) of ongoing series")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
            }
            
            Button("Manage Series") {
                onManageRecurring()
            }
            .font(SPDesignSystem.Typography.callout())
            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            Button(action: onReschedule) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text("Reschedule Visit")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyleBrightInLight())
            
            Button(action: onEdit) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Modify Details")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle())
            
            Button(action: onCancel) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Cancel Booking")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle())
            .foregroundColor(.red)
        }
        .padding(SPDesignSystem.Spacing.m)
    }
    
    // MARK: - Computed Properties
    
    private var timeUntilVisit: TimeInterval {
        return booking.scheduledDate.timeIntervalSinceNow
    }
    
    private var timeUntilText: String {
        let timeInterval = timeUntilVisit
        let hours = Int(timeInterval / 3600)
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours >= 24 {
            let days = hours / 24
            return "in \(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "in \(hours) hour\(hours == 1 ? "" : "s")"
        } else if minutes > 0 {
            return "in \(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "now"
        }
    }
    
    private var totalPrice: Double {
        let basePrice = Double(booking.price) ?? 0.0
        return basePrice
    }
}

// MARK: - Pet Card

private struct PetCard: View {
    let petName: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            // Pet photo placeholder
            Circle()
                .fill(SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "pawprint.fill")
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                )
            
            Text(petName)
                .font(SPDesignSystem.Typography.callout())
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(width: 80)
        .padding(SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    BookingDetailModal(
        booking: ServiceBooking(
            id: "preview",
            clientId: "client1",
            serviceType: "Dog Walking",
            scheduledDate: Date().addingTimeInterval(3600),
            scheduledTime: "10:00 AM",
            duration: 30,
            pets: ["Buddy", "Max"],
            specialInstructions: "Please avoid the park during busy hours.",
            status: .approved,
            sitterId: "sitter1",
            sitterName: "Sarah Johnson",
            createdAt: Date(),
            address: "123 Main St, City, State",
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
        onReschedule: {},
        onEdit: {},
        onCancel: {},
        onManageRecurring: {}
    )
}