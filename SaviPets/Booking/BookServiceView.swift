import SwiftUI

private enum ServiceCategory: String, CaseIterable, Identifiable { case dogWalks = "Dog Walks", petSitting = "Pet Sitting", overnight = "Overnight Care"; var id: String { rawValue } }

private struct ServiceOption: Identifiable, Hashable { let id = UUID(); let label: String; let minutes: Int; let price: Double }
private struct ServiceItem: Identifiable { let id = UUID(); let name: String; let details: String; let options: [ServiceOption] }

private let dogWalks: [ServiceItem] = [
    .init(name: "Potty Break",
          details: "A short visit for essentials: fresh water, potty break or litter refresh, and a quick stretch.",
          options: [.init(label: "15 min", minutes: 15, price: 17.99)]),
    .init(name: "Quick Walk",
          details: "A comfortable neighborhood walk with water refreshed and packages brought in if needed.",
          options: [.init(label: "30 min", minutes: 30, price: 24.99)]),
    .init(name: "Quality Time",
          details: "An hour of enrichment and care: hydration/feeding as instructed, light home care, and companionship.",
          options: [.init(label: "60 min", minutes: 60, price: 39.99)]),
    .init(name: "Walk & Play",
          details: "Two hours of balanced exercise and enrichment—extended walk, playtime, and tailored activities.",
          options: [.init(label: "120 min", minutes: 120, price: 75.00)])
]

private let petSitting: [ServiceItem] = [
    .init(name: "Cat Care",
          details: "Litter maintenance, refreshed water/feeding, medication support as needed, and gentle companionship.",
          options: [
            .init(label: "30 min", minutes: 30, price: 25.00),
            .init(label: "60 min", minutes: 60, price: 45.00)
          ]),
    .init(name: "Birds Care",
          details: "Fresh water/food, cage tidying, and attentive interaction with optional TLC.",
          options: [.init(label: "30 min", minutes: 30, price: 28.95)]),
    .init(name: "Critter Care",
          details: "Water refresh, feeding, and habitat tidying with calm handling for pets who enjoy it.",
          options: [.init(label: "30 min", minutes: 30, price: 28.95)])
]

struct BookServiceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var category: ServiceCategory = .dogWalks
    @State private var selectedService: ServiceItem? = nil
    @State private var selectedOption: ServiceOption? = nil
    @State private var visitDate: Date = Date()
    @State private var note: String = ""
    @State private var showConfirm: Bool = false
    // Overnight
    @State private var overnightNights: Int = 1

    private var services: [ServiceItem] {
        switch category { case .dogWalks: return dogWalks; case .petSitting: return petSitting; case .overnight: return [] }
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
        if selectedService != nil && selectedOption != nil { return true }
        if category == .overnight { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Category", selection: $category) {
                    ForEach(ServiceCategory.allCases) { c in Text(c.rawValue).tag(c) }
                }
                .pickerStyle(.segmented)

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
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(services) { svc in
                            SPCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(svc.name).font(.headline)
                                        Spacer()
                                        if selectedService?.id == svc.id { Image(systemName: "checkmark.circle.fill").foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme)) }
                                    }
                                    Text(svc.details).foregroundColor(.secondary)

                                    if selectedService?.id == svc.id {
                                        if svc.options.count > 1 {
                                            Picker("Duration", selection: Binding(get: { selectedOption ?? svc.options.first! }, set: { selectedOption = $0 })) {
                                                ForEach(svc.options) { opt in Text("\(opt.label) — $\(String(format: "%.2f", opt.price))").tag(opt) }
                                            }
                                            .pickerStyle(.menu)
                                        } else {
                                            Text("\(svc.options.first!.label) — $\(String(format: "%.2f", svc.options.first!.price))").foregroundColor(.secondary)
                                        }
                                    }

                                    Button(action: {
                                        selectedService = svc
                                        selectedOption = svc.options.first
                                    }) {
                                        Text(selectedService?.id == svc.id ? "Selected" : "Select")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(PrimaryButtonStyleBrightInLight())
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
        .alert("Booking Requested", isPresented: $showConfirm) {
            Button("OK") {
                if category == .overnight {
                    // Switch to Messages tab and seed admin inquiry
                    let inquiry = "Overnight inquiry for \(overnightNights) night(s) on \(DateFormatter.localizedString(from: visitDate, dateStyle: .medium, timeStyle: .short)). Notes: \(note)"
                    NotificationCenter.default.post(name: .openMessagesTab, object: nil, userInfo: ["seed": inquiry])
                } else if let url = paymentURL() { UIApplication.shared.open(url) }
            }
        } message: {
            Text(summaryText)
        }
    }

    private var summaryText: String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        if let svc = selectedService, let opt = selectedOption {
            return "\(svc.name) — \(opt.label) on \(df.string(from: visitDate)). Total: $\(String(format: "%.2f", opt.price))"
        } else if category == .overnight {
            return "Overnight Care — \(overnightNights) night(s) on \(df.string(from: visitDate)). Total: $\(String(format: "%.2f", totalPrice))"
        }
        return ""
    }

    private func callEmergency() {
        if let url = URL(string: "tel://4845677999") { UIApplication.shared.open(url) }
    }

    private func paymentURL() -> URL? {
        switch category {
        case .dogWalks:
            guard let svc = selectedService else { return nil }
            let name = svc.name.lowercased()
            if name == "potty break" { return URL(string: "https://square.link/u/xNcRM1gd") }
            if name == "quick walk" { return URL(string: "https://square.link/u/hybBmVyp") }
            if name == "quality time" { return URL(string: "https://square.link/u/fFvr8jcx") }
            if name == "walk & play" || name.replacingOccurrences(of: " ", with: "") == "walk&play" {
                return URL(string: "https://square.link/u/fFvr8jcx")
            }
        case .petSitting:
            guard let svc = selectedService else { return nil }
            let name = svc.name.lowercased()
            if name == "cat care" {
                let label = (selectedOption?.label ?? "").lowercased()
                if label.contains("30") { return URL(string: "https://square.link/u/yXF8HxwT") }
                if label.contains("60") { return URL(string: "https://square.link/u/EV5KtP6N") }
            }
            if name == "birds care" { return URL(string: "https://square.link/u/DKzIo4Dj") }
            if name == "critter care" { return URL(string: "https://square.link/u/DKzIo4Dj") }
        case .overnight:
            let n = overnightNights
            if (1...6).contains(n) { return URL(string: "https://square.link/u/TeHTv5Nr") }
            if (7...12).contains(n) { return URL(string: "https://square.link/u/I9WPRwdX") }
            if n >= 13 { return URL(string: "https://square.link/u/BHgNWtpH") }
        }
        return nil
    }

}

extension Notification.Name {
    static let openMessagesTab = Notification.Name("savipets.openMessagesTab")
}


