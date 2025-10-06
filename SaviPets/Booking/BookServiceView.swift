import SwiftUI
import FirebaseAuth

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
    @State private var selectedOption: ServiceOption? = nil
    @State private var visitDate: Date = Date()
    @State private var note: String = ""
    @State private var showConfirm: Bool = false
    // Overnight
    @State private var overnightNights: Int = 1
    // Pets multi-select
    @State private var pets: [PetDataService.Pet] = []
    @State private var selectedPetNames: Set<String> = []

    private var serviceOptions: [ServiceOption] {
        switch category { case .dogWalks: return dogWalkOptions; case .petSitting: return petSittingOptions; case .overnight: return [] }
    }
    private var totalPrice: Double {
        if let price = selectedOption?.price { return price }
        if category == .overnight { return Double(overnightNights) * overnightNightlyRate }
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
                .onChange(of: category) { _ in selectedOption = nil }

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
                                Picker("Service Options", selection: $selectedOption) {
                                    Text("Select a service...").tag(nil as ServiceOption?)
                                    ForEach(serviceOptions, id: \.self) { option in
                                        Text("\(option.label) — $\(String(format: "%.2f", option.price))").tag(option as ServiceOption?)
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
                            Text("Select Pets (optional)").font(.headline)
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

                            Text("Notes (optional)").font(.headline)
                            TextField("Anything we should know?", text: $note)
                                .textFieldStyle(.roundedBorder)

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
        .alert("Booking Requested", isPresented: $showConfirm) {
            Button("OK") {
                if category == .overnight {
                    // Switch to Messages tab and seed admin inquiry
                    let df = DateFormatter()
                    df.dateStyle = .medium; df.timeStyle = .short; df.locale = Locale(identifier: "en_US")
                    let inquiry = "Overnight inquiry for \(overnightNights) night(s) on \(df.string(from: visitDate)). Notes: \(note)"
                    NotificationCenter.default.post(name: .openMessagesTab, object: nil, userInfo: ["seed": inquiry])
                    Task { await createBookingIfPossible() }
                } else if let url = paymentURL() {
                    UIApplication.shared.open(url)
                    Task { await createBookingIfPossible() }
                }
            }
        } message: {
            Text(summaryText)
        }
    }

    private var summaryText: String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short; df.locale = Locale(identifier: "en_US")
        if let opt = selectedOption {
            return "\(opt.label) on \(df.string(from: visitDate)). Total: $\(String(format: "%.2f", opt.price))"
        } else if category == .overnight {
            return "Overnight Care — \(overnightNights) night(s) on \(df.string(from: visitDate)). Total: $\(String(format: "%.2f", totalPrice))"
        }
        return ""
    }

    private func callEmergency() {
        if let url = URL(string: "tel://4845677999") { UIApplication.shared.open(url) }
    }

    private func paymentURL() -> URL? {
        guard let option = selectedOption else {
            if category == .overnight {
                let n = overnightNights
                if (1...6).contains(n) { return URL(string: "https://square.link/u/TeHTv5Nr") }
                if (7...12).contains(n) { return URL(string: "https://square.link/u/I9WPRwdX") }
                if n >= 13 { return URL(string: "https://square.link/u/BHgNWtpH") }
            }
            return nil
        }
        let label = option.label.lowercased()
        if label.contains("potty break") { return URL(string: "https://square.link/u/xNcRM1gd") }
        if label.contains("quick walk") { return URL(string: "https://square.link/u/hybBmVyp") }
        if label.contains("quality time") { return URL(string: "https://square.link/u/fFvr8jcx") }
        if label.contains("walk & play") { return URL(string: "https://square.link/u/fFvr8jcx") }
        if label.contains("cat care") {
            if label.contains("30 min") { return URL(string: "https://square.link/u/yXF8HxwT") }
            if label.contains("60 min") { return URL(string: "https://square.link/u/EV5KtP6N") }
        }
        if label.contains("birds care") { return URL(string: "https://square.link/u/DKzIo4Dj") }
        if label.contains("critter care") { return URL(string: "https://square.link/u/DKzIo4Dj") }
        return nil
    }

    // MARK: - Create booking document (pending)
    @MainActor
    private func createBookingIfPossible() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let timeFormatter = DateFormatter(); timeFormatter.dateFormat = "h:mm a"
        let scheduledTime = timeFormatter.string(from: visitDate)
        let serviceType: String = {
            switch category {
            case .dogWalks: return "Dog Walks"
            case .petSitting: return "Pet Sitting"
            case .overnight: return "Overnight Care"
            }
        }()
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
            address: nil,
            checkIn: nil,
            checkOut: nil
        )
        try? await serviceBookings.createBooking(booking)
    }

}

extension Notification.Name {
    static let openMessagesTab = Notification.Name("savipets.openMessagesTab")
}



