import SwiftUI
import OSLog
import FirebaseAuth
import FirebaseFirestore

private enum ServiceCategory: String, CaseIterable, Identifiable { case dogWalks = "Dog Walks", petSitting = "Pet Sitting", overnight = "Overnight Care"; var id: String { rawValue } }

private struct ServiceOption: Identifiable, Hashable { let id = UUID(); let label: String; let minutes: Int; let price: Double }

// Consolidated service options per category
private let dogWalkOptions: [ServiceOption] = [
    .init(label: "Potty Break - 15 min", minutes: 15, price: 17.99),
    .init(label: "Quick Walk - 30 min", minutes: 30, price: 24.99),
    .init(label: "Quality Time - 60 min", minutes: 60, price: 39.99),
    .init(label: "Walk & Play - 120 min", minutes: 120, price: 75.00)
]

private let petSittingOptions: [ServiceOption] = [
    .init(label: "Cat Care - 30 min", minutes: 30, price: 25.00),
    .init(label: "Cat Care - 60 min", minutes: 60, price: 45.00),
    .init(label: "Birds Care - 30 min", minutes: 30, price: 28.95),
    .init(label: "Critter Care - 30 min", minutes: 30, price: 28.95)
]

struct BookServiceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var serviceBookings: ServiceBookingDataService

    @State private var category: ServiceCategory = .dogWalks
    @State private var selectedOptionId: UUID? = nil
    @State private var visitDate: Date = Date()
    @State private var note: String = ""
    @State private var showConfirm: Bool = false
    // Overnight
    @State private var overnightNights: Int = 1
    // Pets multi-select
    @State private var pets: [PetDataService.Pet] = []
    @State private var selectedPetNames: Set<String> = []
    
    // Recurring booking state
    @State private var numberOfVisits: Int = 1
    @State private var paymentFrequency: PaymentFrequency = .daily
    @State private var preferredDays: Set<Int> = [] // 1=Mon, 2=Tue, etc.
    @State private var showRecurringOptions: Bool = false
    
    // Square payment integration
    private let squarePayment = SquarePaymentService()
    @State private var isCreatingCheckout: Bool = false
    @State private var checkoutError: String? = nil

    private var serviceOptions: [ServiceOption] {
        switch category { case .dogWalks: return dogWalkOptions; case .petSitting: return petSittingOptions; case .overnight: return [] }
    }
    
    private var selectedOption: ServiceOption? {
        guard let id = selectedOptionId else { return nil }
        return serviceOptions.first { $0.id == id }
    }
    
    private var serviceType: String {
        if let option = selectedOption {
            return option.label
        } else {
            switch category {
            case .dogWalks: return "Dog Walks"
            case .petSitting: return "Pet Sitting"
            case .overnight: return "Overnight Care"
            }
        }
    }
    
    private var totalPrice: Double {
        var basePrice: Double = 0
        
        if let price = selectedOption?.price {
            // Base service price
            basePrice = price
            
            // Add recurring visits if applicable
            if showRecurringOptions && numberOfVisits > 1 {
                basePrice = price * Double(numberOfVisits)
                let discount = paymentFrequency.discountPercentage
                basePrice = basePrice * (1.0 - discount)
            }
            
            // Add per-pet charges: $10 per pet after first 2 pets
            let petsCount = selectedPetNames.count
            if petsCount > 2 {
                let extraPets = petsCount - 2
                let perPetCharge = 10.0 * Double(extraPets)
                basePrice += perPetCharge
            }
            
            return basePrice
        }
        
        if category == .overnight { 
            return Double(overnightNights) * overnightNightlyRate 
        }
        
        return 0
    }
    
    private var subtotalPrice: Double {
        if let price = selectedOption?.price {
            return price * Double(showRecurringOptions ? numberOfVisits : 1)
        }
        return totalPrice
    }
    
    private var discountAmount: Double {
        if showRecurringOptions && numberOfVisits > 1 {
            return subtotalPrice * paymentFrequency.discountPercentage
        }
        return 0
    }
    private var overnightNightlyRate: Double {
        if overnightNights >= 13 { return 120 }
        if overnightNights >= 7 { return 130 }
        return 140
    }
    private var bookingReady: Bool {
        if selectedOption != nil { return true }
        if category == .overnight { return true }
        return false
    }

    private var categoryDescription: String {
        switch category {
        case .dogWalks:
            return "Professional dog walking services tailored to your pet's needs, from quick potty breaks to extended walks with playtime."
        case .petSitting:
            return "Comprehensive pet care services for cats, birds, and small animals with feeding, cleaning, and companionship."
        case .overnight:
            return ""
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Category", selection: $category) {
                    ForEach(ServiceCategory.allCases) { c in Text(c.rawValue).tag(c) }
                }
                .pickerStyle(.segmented)
                .onChange(of: category) { _ in selectedOptionId = nil }

                if category == .overnight {
                    SPCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Overnight Care").font(.headline)
                            Text("Choose the number of nights. Pricing adjusts automatically.").foregroundColor(.secondary)
                            HStack {
                                Stepper("Nights: \(overnightNights)", value: $overnightNights, in: 1...60)
                                Spacer()
                                Text("$\(String(format: "%.2f", overnightNightlyRate))/night")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Total")
                                Spacer()
                                Text("$\(String(format: "%.2f", Double(overnightNights) * overnightNightlyRate))").bold()
                            }
                        }
                    }
                } else {
                    // Single consolidated card per category (Dog Walks / Pet Sitting)
                    SPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(category.rawValue).font(.headline)
                                Spacer()
                                if selectedOption != nil { Image(systemName: "checkmark.circle.fill").foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme)) }
                            }
                            Text(categoryDescription).foregroundColor(.secondary).font(.subheadline)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Choose Service:").font(.subheadline).fontWeight(.medium)
                                Picker("Service Options", selection: $selectedOptionId) {
                                    Text("Select a service...").tag(nil as UUID?)
                                    ForEach(serviceOptions) { option in
                                        Text("\(option.label) — $\(String(format: "%.2f", option.price))").tag(option.id as UUID?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                            }
                            if let selected = selectedOption {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Selected: \(selected.label)").font(.subheadline).fontWeight(.medium).foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                                    Text("Price: $\(String(format: "%.2f", selected.price))").font(.subheadline).foregroundColor(.secondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }

                // Multi-pet selection
                if category != .overnight {
                    SPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Pets").font(.headline)
                            if pets.isEmpty {
                                Text("No pets found. Add pets in My Pets tab.").font(.subheadline).foregroundColor(.secondary)
                            } else {
                                ForEach(pets) { pet in
                                    Toggle(isOn: Binding(
                                        get: { selectedPetNames.contains(pet.name) },
                                        set: { v in if v { selectedPetNames.insert(pet.name) } else { selectedPetNames.remove(pet.name) } }
                                    )) {
                                        Text(pet.name)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Recurring options (multiple visits)
                if bookingReady && category != .overnight {
                    SPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Multiple Visits", isOn: $showRecurringOptions)
                                .font(.headline)
                                .tint(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                            
                            if showRecurringOptions {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Number of visits
                                    Stepper("Number of visits: \(numberOfVisits)", value: $numberOfVisits, in: 1...30)
                                        .font(.subheadline)
                                    
                                    // Payment frequency
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Payment Plan").font(.subheadline).fontWeight(.medium)
                                        Picker("Frequency", selection: $paymentFrequency) {
                                            ForEach(PaymentFrequency.allCases, id: \.self) { freq in
                                                Text(freq.displayName).tag(freq)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        .onChange(of: paymentFrequency) { newValue in
                                            // Reset preferred days when changing frequency
                                            if newValue != .weekly {
                                                preferredDays.removeAll()
                                            }
                                        }
                                    }
                                    
                                    // Weekly: Day selection
                                    if paymentFrequency == .weekly && numberOfVisits > 1 {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Preferred Days").font(.subheadline).fontWeight(.medium)
                                            HStack(spacing: 6) {
                                                ForEach(Array(zip(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].indices, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])), id: \.0) { index, day in
                                                    DayPillButton(
                                                        day: day,
                                                        isSelected: preferredDays.contains(index + 1),
                                                        action: { toggleDay(index + 1) }
                                                    )
                                                }
                                            }
                                            
                                            if !preferredDays.isEmpty {
                                                Text("\(preferredDays.count) day(s) selected")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    // Price breakdown
                                    Divider()
                                    
                                    HStack {
                                        Text("Price per visit")
                                        Spacer()
                                        Text("$\(String(format: "%.2f", selectedOption?.price ?? 0))")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.subheadline)
                                    
                                    HStack {
                                        Text("Subtotal (\(numberOfVisits) visit\(numberOfVisits > 1 ? "s" : ""))")
                                        Spacer()
                                        Text("$\(String(format: "%.2f", subtotalPrice))")
                                    }
                                    .font(.subheadline)
                                    
                                    if discountAmount > 0 {
                                        HStack {
                                            Text("\(paymentFrequency.displayName) discount (\(Int(paymentFrequency.discountPercentage * 100))%)")
                                            Spacer()
                                            Text("-$\(String(format: "%.2f", discountAmount))")
                                                .foregroundColor(.green)
                                        }
                                        .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                }

                if bookingReady {
                    SPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Schedule")
                                .font(.headline)
                            DatePicker("Date & Time", selection: $visitDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "en_US"))
                                .environment(\.calendar, Calendar(identifier: .gregorian))
                                .environment(\.timeZone, TimeZone(identifier: "America/New_York") ?? .current)

                            Text("Notes").font(.headline)
                            TextField("Anything we should know?", text: $note)
                                .textFieldStyle(.roundedBorder)
                            
                            // Price breakdown
                            if !showRecurringOptions || numberOfVisits == 1 {
                                Divider()
                                
                                if let basePrice = selectedOption?.price {
                                    HStack {
                                        Text("Service price")
                                        Spacer()
                                        Text("$\(String(format: "%.2f", basePrice))")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.subheadline)
                                    
                                    let petsCount = selectedPetNames.count
                                    if petsCount > 2 {
                                        let extraPets = petsCount - 2
                                        let perPetCharge = Double(extraPets) * 10.0
                                        HStack {
                                            Text("\(extraPets) extra pet\(extraPets > 1 ? "s" : "") ($10 each)")
                                            Spacer()
                                            Text("+$\(String(format: "%.2f", perPetCharge))")
                                                .foregroundColor(.orange)
                                        }
                                        .font(.subheadline)
                                    }
                                }
                            }

                            HStack {
                                Text("Total")
                                Spacer()
                                Text("$\(String(format: "%.2f", totalPrice))").bold()
                            }

                            Button(action: { showConfirm = true }) {
                                Text("Book Now")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyleBrightInLight())

                            Button(action: { callEmergency() }) {
                                Label("Emergency: (484) 567-7999", systemImage: "phone.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Book Service")
        .task {
            // Load user's pets for selection
            if pets.isEmpty {
                do { pets = try await PetDataService().listPets() } catch { pets = [] }
            }
        }
        .alert(isCreatingCheckout ? "Creating Checkout..." : "Booking Requested", isPresented: $showConfirm) {
            Button(isCreatingCheckout ? "Please Wait" : "Proceed to Payment") {
                Task { await handleBookingConfirmation() }
            }
            .disabled(isCreatingCheckout)
        } message: {
            if isCreatingCheckout {
                Text("Creating secure payment checkout...")
            } else if let error = checkoutError {
                Text("Error: \(error)")
            } else {
                Text(summaryText)
            }
        }
    }

    private var summaryText: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: "en_US")
        
        let petsCount = selectedPetNames.count
        
        if category == .overnight {
            return "Overnight Care — \(overnightNights) night(s) on \(df.string(from: visitDate)). Total: $\(String(format: "%.2f", totalPrice))"
        } else if let opt = selectedOption {
            var details = "\(opt.label)"
            
            // Add pet count if applicable
            if petsCount > 0 {
                details += " for \(petsCount) pet\(petsCount > 1 ? "s" : "")"
                if petsCount > 2 {
                    let extraPets = petsCount - 2
                    details += " (+$\(extraPets * 10) for \(extraPets) extra pet\(extraPets > 1 ? "s" : ""))"
                }
            }
            
            // Add recurring info if applicable
            if showRecurringOptions && numberOfVisits > 1 {
                details += " — \(numberOfVisits) visits (\(paymentFrequency.displayName))"
                if paymentFrequency.discountPercentage > 0 {
                    details += " with \(Int(paymentFrequency.discountPercentage * 100))% discount"
                }
            }
            
            details += " on \(df.string(from: visitDate)). Total: $\(String(format: "%.2f", totalPrice))"
            return details
        }
        
        return "Booking requested for \(category.rawValue). Total: $\(String(format: "%.2f", totalPrice))"
    }

    private func callEmergency() {
        if let url = URL(string: "tel://4845677999") { UIApplication.shared.open(url) }
    }
    
    // MARK: - Square Payment Integration
    
    /// Handle booking confirmation and payment
    @MainActor
    private func handleBookingConfirmation() async {
        if category == .overnight {
            // For overnight, still use admin inquiry (custom pricing)
            let df = DateFormatter()
            df.dateStyle = .medium; df.timeStyle = .short; df.locale = Locale(identifier: "en_US")
            let inquiry = "Overnight inquiry for \(overnightNights) night(s) on \(df.string(from: visitDate)). Notes: \(note)"
            NotificationCenter.default.post(name: .openMessagesTab, object: nil, userInfo: ["seed": inquiry])
            await createBookingIfPossible()
            return
        }
        
        // Create booking first to get booking ID
        guard Auth.auth().currentUser?.uid != nil else { return }  // Swift 6: unused value fix
        let bookingId = UUID().uuidString
        
        isCreatingCheckout = true
        checkoutError = nil
        
        do {
            // STEP 1: Create booking in Firestore FIRST (so Cloud Function can validate it)
            AppLogger.ui.info("📝 Creating booking in Firestore: \(bookingId)")
            try await createBookingInFirestore(bookingId: bookingId)
            
            // STEP 2: Create Square checkout via Cloud Function with retry logic
            AppLogger.ui.info("💳 Creating Square checkout for booking: \(bookingId)")
            
            var checkoutUrl: String? = nil
            
            var retryCount = 0
            let maxRetries = 3
            
            while retryCount < maxRetries {
                do {
                    // Add increasing delay for retries
                    if retryCount > 0 {
                        let delay = Double(retryCount) * 1.0 // 1s, 2s, 3s delays
                        AppLogger.ui.info("⏳ Retrying Square checkout (attempt \(retryCount + 1)/\(maxRetries)) after \(delay)s delay")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    
                    checkoutUrl = try await squarePayment.createCheckout(
                        bookingId: bookingId,
                        serviceType: serviceType,
                        price: totalPrice,
                        numberOfVisits: showRecurringOptions ? numberOfVisits : 1,
                        isRecurring: showRecurringOptions && numberOfVisits > 1,
                        frequency: showRecurringOptions ? paymentFrequency.rawValue : "once",
                        pets: Array(selectedPetNames),
                        scheduledDate: visitDate
                    )
                    
                    // Success! Break out of retry loop
                    break
                    
                } catch {
                    retryCount += 1
                    AppLogger.ui.warning("❌ Square checkout attempt \(retryCount) failed: \(error.localizedDescription)")
                    
                    if retryCount >= maxRetries {
                        // Final attempt failed, throw the error
                        throw error
                    }
                    // Continue to next retry
                }
            }
            
            // Open Square checkout in Safari
            if let checkoutUrl, let url = URL(string: checkoutUrl) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                    isCreatingCheckout = false
                    showConfirm = false
                }
            }
            else {
                await MainActor.run {
                    checkoutError = "Failed to create checkout URL. Please try again."
                    isCreatingCheckout = false
                }
                AppLogger.ui.error("❌ Failed to obtain Square checkout URL after retries for booking: \(bookingId)")
            }
            
            AppLogger.ui.info("✅ Square checkout opened successfully: \(bookingId)")
            
        } catch {
            await MainActor.run {
                checkoutError = error.localizedDescription
                isCreatingCheckout = false
            }
            AppLogger.ui.error("❌ Payment flow failed: \(error.localizedDescription)")
        }
    }
    
    /// Create booking document in Firestore
    @MainActor
    private func createBookingInFirestore(bookingId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Fetch user's address
        var userAddress: String? = nil
        do {
            let userDoc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let userData = userDoc.data() {
                let addr1 = (userData["address1"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let addr2 = (userData["address2"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let city = (userData["city"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let state = (userData["state"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let zip = (userData["zipCode"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                var addressParts: [String] = []
                if !addr1.isEmpty { addressParts.append(addr1) }
                if !addr2.isEmpty { addressParts.append(addr2) }
                if !city.isEmpty { addressParts.append(city) }
                if !state.isEmpty { addressParts.append(state) }
                if !zip.isEmpty { addressParts.append(zip) }
                
                if !addressParts.isEmpty {
                    userAddress = addressParts.joined(separator: ", ")
                }
            }
        } catch {
            AppLogger.ui.warning("Could not fetch user address: \(error.localizedDescription)")
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let scheduledTime = timeFormatter.string(from: visitDate)
        
        let serviceType = selectedOption?.label ?? category.rawValue
        
        // Create booking with pending status (will be approved by webhook)
        let booking = ServiceBooking(
            id: bookingId,
            clientId: uid,
            serviceType: serviceType,
            scheduledDate: visitDate,
            scheduledTime: scheduledTime,
            duration: category == .overnight ? (overnightNights * 12 * 60) : (selectedOption?.minutes ?? 0),
            pets: Array(selectedPetNames),
            specialInstructions: note.isEmpty ? nil : note,
            status: .pending,  // Will be auto-approved by webhook
            sitterId: nil,
            sitterName: nil,
            createdAt: Date(),
            address: userAddress,
            checkIn: nil,
            checkOut: nil,
            price: String(format: "%.2f", totalPrice),
            recurringSeriesId: nil,
            visitNumber: nil,
            isRecurring: showRecurringOptions && numberOfVisits > 1,
            paymentStatus: nil,
            paymentTransactionId: nil,
            paymentAmount: nil,
            paymentMethod: nil,
            rescheduledFrom: nil,
            rescheduledAt: nil,
            rescheduledBy: nil,
            rescheduleReason: nil,
            rescheduleHistory: [],
            lastModified: Date(),
            lastModifiedBy: uid,
            modificationReason: "Initial booking creation"
        )
        
        // CRITICAL: Don't use try? - we need to know if this fails!
        do {
            try await serviceBookings.createBooking(booking)
            AppLogger.ui.info("✅ Booking created in Firestore: \(bookingId)")
        } catch {
            AppLogger.ui.error("❌ Failed to create booking in Firestore: \(error.localizedDescription)")
            throw error // Rethrow so Square checkout doesn't proceed
        }
    }
    
    /// Legacy method - kept for reference but no longer used
    @available(*, deprecated, message: "Use createDynamicCheckout instead")
    private func paymentURL() -> URL? {
        // DEPRECATED: Hardcoded URLs replaced with dynamic Square API
        return nil
    }

    // MARK: - Create booking document (pending)
    @MainActor
    private func createBookingIfPossible() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Fetch user's address from their profile
        var userAddress: String? = nil
        do {
            let userDoc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let userData = userDoc.data() {
                // Combine separate address fields into a single complete address
                let addr1 = (userData["address1"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let addr2 = (userData["address2"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let city = (userData["city"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let state = (userData["state"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let zip = (userData["zipCode"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                var addressParts: [String] = []
                if !addr1.isEmpty { addressParts.append(addr1) }
                if !addr2.isEmpty { addressParts.append(addr2) }
                if !city.isEmpty { addressParts.append(city) }
                if !state.isEmpty { addressParts.append(state) }
                if !zip.isEmpty { addressParts.append(zip) }
                
                if !addressParts.isEmpty {
                    userAddress = addressParts.joined(separator: ", ")
                    AppLogger.ui.info("Fetched client address: \(userAddress!)")
                } else {
                    AppLogger.ui.warning("Client has no address set in profile")
                }
            }
        } catch {
            AppLogger.ui.warning("Could not fetch user address: \(error.localizedDescription)")
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let scheduledTime = timeFormatter.string(from: visitDate)
        
        // Use the specific service option label if selected, otherwise use category
        let serviceType: String
        if let option = selectedOption {
            serviceType = option.label  // e.g., "Potty Break - 15 min"
        } else {
            serviceType = {
                switch category {
                case .dogWalks: return "Dog Walks"
                case .petSitting: return "Pet Sitting"
                case .overnight: return "Overnight Care"
                }
            }()
        }
        
        // Check if this is a recurring booking (multiple visits)
        if showRecurringOptions && numberOfVisits > 1 && category != .overnight {
            // Create recurring series
            do {
                let seriesId = try await serviceBookings.createRecurringSeries(
                    serviceType: serviceType,
                    numberOfVisits: numberOfVisits,
                    frequency: paymentFrequency,
                    startDate: visitDate,
                    preferredTime: scheduledTime,
                    preferredDays: paymentFrequency == .weekly ? Array(preferredDays) : nil,
                    duration: selectedOption?.minutes ?? 0,
                    basePrice: selectedOption?.price ?? 0,
                    pets: Array(selectedPetNames),
                    specialInstructions: note.isEmpty ? nil : note,
                    address: userAddress
                )
                
                AppLogger.ui.info("Created recurring series: \(seriesId)")
            } catch {
                AppLogger.ui.error("Failed to create recurring series: \(error.localizedDescription)")
            }
        } else {
            // Create single booking (existing logic)
            let booking = ServiceBooking(
                id: "",
                clientId: uid,
                serviceType: serviceType,
                scheduledDate: visitDate,
                scheduledTime: scheduledTime,
                duration: category == .overnight ? (overnightNights * 12 * 60) : (selectedOption?.minutes ?? 0),
                pets: Array(selectedPetNames),
                specialInstructions: note.isEmpty ? nil : note,
                status: .pending,
                sitterId: nil,
                sitterName: nil,
                createdAt: Date(),
                address: userAddress,
                checkIn: nil,
                checkOut: nil,
                price: String(format: "%.2f", totalPrice),
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
                lastModified: Date(),
                lastModifiedBy: uid,
                modificationReason: "Initial booking creation"
            )
            try? await serviceBookings.createBooking(booking)
        }
    }
    
    private func toggleDay(_ day: Int) {
        if preferredDays.contains(day) {
            preferredDays.remove(day)
        } else {
            preferredDays.insert(day)
        }
    }
}

// MARK: - Day Pill Button Component

private struct DayPillButton: View {
    let day: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            Text(day)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(width: 40, height: 36)
                .background(
                    isSelected
                        ? SPDesignSystem.Colors.primaryAdjusted(colorScheme)
                        : Color(.tertiarySystemBackground)
                )
                .foregroundColor(
                    isSelected
                        ? SPDesignSystem.Colors.dark
                        : .primary
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
