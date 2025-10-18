import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

/// Sheet for editing booking details (special instructions, pets, duration, add-ons)
struct EditBookingSheet: View {
    let booking: ServiceBooking
    let onCompletion: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var specialInstructions: String
    @State private var selectedPets: Set<String>
    @State private var duration: Int
    @State private var selectedAddOns: Set<String>
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var priceDifference: Double = 0
    
    // Available options
    private let availableAddOns = [
        "Extra treats (+$3.00)",
        "Photo updates (+$5.00)",
        "Extended playtime (+$10.00)",
        "Medication administration (+$15.00)",
        "Grooming service (+$20.00)"
    ]
    
    private let auditService = AuditTrailService()
    
    init(booking: ServiceBooking, onCompletion: @escaping (Bool) -> Void) {
        self.booking = booking
        self.onCompletion = onCompletion
        self._specialInstructions = State(initialValue: booking.specialInstructions ?? "")
        self._selectedPets = State(initialValue: Set(booking.pets))
        self._duration = State(initialValue: booking.duration)
        self._selectedAddOns = State(initialValue: Set<String>())
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.l) {
                    // Header
                    headerSection
                    
                    // Special Instructions
                    instructionsSection
                    
                    // Pet Selection
                    petsSection
                    
                    // Duration Selection
                    durationSection
                    
                    // Add-ons Selection
                    addOnsSection
                    
                    // Price Preview
                    pricePreviewSection
                    
                    // Non-editable Info
                    nonEditableSection
                    
                    // Save Button
                    saveButton
                }
                .padding(SPDesignSystem.Spacing.m)
            }
            .navigationTitle("Edit Booking")
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
            .onAppear {
                calculatePriceDifference()
            }
            .onChange(of: duration) { _ in
                calculatePriceDifference()
            }
            .onChange(of: selectedAddOns) { _ in
                calculatePriceDifference()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Edit \(booking.serviceType)")
                .font(SPDesignSystem.Typography.heading2())
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            
            Text("Original booking date: \(formatDate(booking.scheduledDate))")
                .font(SPDesignSystem.Typography.callout())
                .foregroundColor(.secondary)
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
            
            TextField("Add special instructions for your sitter...", text: $specialInstructions, axis: .vertical)
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
    
    // MARK: - Pets Section
    
    private var petsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Select Pets")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            // For now, we'll use the existing pet names
            // In a real implementation, this would fetch available pets from the user's profile
            VStack(spacing: 8) {
                ForEach(booking.pets, id: \.self) { petName in
                    HStack {
                        Button(action: {
                            if selectedPets.contains(petName) {
                                selectedPets.remove(petName)
                            } else {
                                selectedPets.insert(petName)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedPets.contains(petName) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                                
                                Text(petName)
                                    .font(SPDesignSystem.Typography.body())
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if selectedPets.isEmpty {
                Text("Please select at least one pet")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.red)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Duration Section
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Duration")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            HStack {
                Stepper(
                    value: $duration,
                    in: 15...120,
                    step: 15
                ) {
                    Text("\(duration) minutes")
                        .font(SPDesignSystem.Typography.bodyMedium())
                        .foregroundColor(.primary)
                }
                .accentColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Spacer()
            }
            
            Text("Duration affects pricing. Base rate is $1.00 per minute.")
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Add-ons Section
    
    private var addOnsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Add-ons")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            VStack(spacing: 8) {
                ForEach(availableAddOns, id: \.self) { addOn in
                    HStack {
                        Button(action: {
                            if selectedAddOns.contains(addOn) {
                                selectedAddOns.remove(addOn)
                            } else {
                                selectedAddOns.insert(addOn)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedAddOns.contains(addOn) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                                
                                Text(addOn)
                                    .font(SPDesignSystem.Typography.body())
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Price Preview Section
    
    private var pricePreviewSection: some View {
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
                    Text("Original Price:")
                    Spacer()
                    Text("$\(String(format: "%.2f", booking.price))")
                }
                
                HStack {
                    Text("New Base Price:")
                    Spacer()
                    Text("$\(String(format: "%.2f", Double(duration)))")
                }
                
                if !selectedAddOns.isEmpty {
                    ForEach(selectedAddOns.sorted(), id: \.self) { addOn in
                        HStack {
                            Text(addOn.components(separatedBy: " (+$")[0])
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("+\(extractAddOnPrice(from: addOn))")
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    Text("New Total:")
                        .font(SPDesignSystem.Typography.bodyMedium())
                    Spacer()
                    Text("$\(String(format: "%.2f", newTotalPrice))")
                        .font(SPDesignSystem.Typography.bodyMedium())
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                }
                
                if priceDifference != 0 {
                    HStack {
                        Text("Difference:")
                        Spacer()
                        Text("\(priceDifference > 0 ? "+" : "")$\(String(format: "%.2f", abs(priceDifference)))")
                            .font(SPDesignSystem.Typography.bodyMedium())
                            .foregroundColor(priceDifference > 0 ? .red : .green)
                    }
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Non-editable Section
    
    private var nonEditableSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                
                Text("Non-editable Information")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Service Type:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(booking.serviceType)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Sitter:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(booking.sitterName ?? "Not assigned")
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Date & Time:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDateTime(booking.scheduledDate))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: saveChanges) {
            HStack {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                }
                
                Text(isSaving ? "Saving..." : "Save Changes")
                    .font(SPDesignSystem.Typography.button())
            }
        }
        .buttonStyle(PrimaryButtonStyleBrightInLight())
        .disabled(selectedPets.isEmpty || isSaving)
        .padding(.top, SPDesignSystem.Spacing.l)
    }
    
    // MARK: - Computed Properties
    
    private var newTotalPrice: Double {
        let basePrice = Double(duration) // $1 per minute
        let addOnPrices = selectedAddOns.compactMap { extractAddOnPrice(from: $0) }
        return basePrice + addOnPrices.reduce(0, +)
    }
    
    // MARK: - Helper Methods
    
    private func extractAddOnPrice(from addOn: String) -> Double {
        // Extract price from strings like "Extra treats (+$3.00)"
        let components = addOn.components(separatedBy: "(+$")
        if components.count > 1 {
            let priceString = components[1].replacingOccurrences(of: ")", with: "")
            return Double(priceString) ?? 0
        }
        return 0
    }
    
    private func calculatePriceDifference() {
        priceDifference = newTotalPrice - (Double(booking.price) ?? 0.0)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveChanges() {
        guard !selectedPets.isEmpty else {
            errorMessage = "Please select at least one pet"
            showingError = true
            return
        }
        
        isSaving = true
        
        Task<Void, Never> {
            do {
                // Create updated booking data
                var updatedData: [String: Any] = [
                    "specialInstructions": specialInstructions,
                    "petNames": Array(selectedPets),
                    "duration": duration,
                    "addOns": Array(selectedAddOns),
                    "lastModified": Timestamp(date: Date()),
                    "lastModifiedBy": Auth.auth().currentUser?.uid ?? "unknown",
                    "modificationReason": "Client edited booking details"
                ]
                
                // Update price if changed
                if newTotalPrice != (Double(booking.price) ?? 0.0) {
                    updatedData["price"] = newTotalPrice
                }
                
                // Update the booking in Firestore
                let db = Firestore.firestore()
                try await db.collection("serviceBookings")
                    .document(booking.id)
                    .updateData(updatedData)
                
                // Log the edit action
                await auditService.logEvent(
                    action: .bookingModified,
                    userId: Auth.auth().currentUser?.uid,
                    resourceType: .booking,
                    resourceId: booking.id,
                    details: [
                        "fieldsChanged": ["specialInstructions", "pets", "duration", "addOns"],
                        "oldPrice": booking.price,
                        "newPrice": newTotalPrice
                    ]
                )
                
                await MainActor.run {
                    onCompletion(true)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save changes: \(error.localizedDescription)"
                    showingError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EditBookingSheet(
        booking: ServiceBooking(
            id: "preview",
            clientId: "client1",
            serviceType: "Dog Walking",
            scheduledDate: Date().addingTimeInterval(3600),
            scheduledTime: "10:00 AM",
            duration: 30,
            pets: ["Buddy", "Max"],
            specialInstructions: "Please avoid the park",
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
