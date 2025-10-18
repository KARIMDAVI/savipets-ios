import SwiftUI

struct ServiceCategoryCard: View {
    let title: String
    let imageName: String
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 220, height: 140)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .frame(height: 80)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
        }
        .frame(width: 220, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.clear)
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
    }
}
// MARK: OvernightCare
struct OvernightCareServicesView: View {
    var body: some View {
        List {
            ServiceRow(name: "1 - 6 days", duration: "8 PM - 8 AM", price: "$140.00", details: "We will come to stay with your pet for the night. Great for older pets, pets with frequent medication or needs, multiple pets, or pets that do NOT do well in Kennels.")
            ServiceRow(name: "7 - 12 days", duration: "8 PM - 8 AM", price: "$130.00", details: "Up to 12 days.")
            ServiceRow(name: "13+", duration: "8 PM - 8 AM", price: "$120.00", details: "Up to 30 days.")
        }
        .navigationTitle("Overnight Care")
    }
}

// MARK: Dog Walks
struct DogWalksServicesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ServiceRow(name: "Potty Break", duration: "15 min", price: "$17.99", details: "A short visit tailored for essential care: fresh water, quick potty break or litter refresh, and a brief walk to stretch their legs.")
                ServiceRow(name: "Quick Walk", duration: "30 min", price: "$24.99", details: "A half‑hour visit to refresh water, bring in packages, and provide a comfortable walk. During extreme heat or rain, we shorten outdoor time and focus on safe indoor engagement.")
                ServiceRow(name: "Quality Time", duration: "60 min", price: "$39.99", details: "A full hour of attentive care. We ensure water/feeding as instructed, light home care (packages/mail), and meaningful enrichment time for a happier pet.")
                ServiceRow(name: "Walk & Play", duration: "120 min", price: "$75.00", details: "Two hours of balanced exercise and enrichment. Includes an extended walk, playtime, hydration check, and tailored activities to match your pet's energy level—ideal for high‑energy dogs or special days.")
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [
                    Color.yellow.opacity(0.1),
                    Color.white.opacity(0.8),
                    Color.yellow.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationTitle("Dog Walks")
    }
}

// MARK: Pet Sitting
struct PetSittingServicesView: View {
    var body: some View {
        List {
            ServiceRow(name: "Cat Care", duration: "30–60 min", price: "$25-$45", details: "Loving care for your cat: litter maintenance, refreshed water/feeding, medication support as needed, and gentle companionship.")
            ServiceRow(name: "Birds Care", duration: "30 min", price: "$28.95", details: "Fresh water and food, cage tidying, and attentive interaction with optional TLC for birds who enjoy it.")
            ServiceRow(name: "Critter Care", duration: "30 min", price: "$28.95", details: "Water refresh, feeding, and habitat tidying for small pets—with calm handling for those who like it.")
        }
        .navigationTitle("Pet Sitting")
    }
}

// MARK: Transportation + Calculator
struct PetTransportationView: View {
    @State private var distanceMiles: String = "0"
    @State private var numberOfPets: String = "1"
    @State private var serviceType: TransportKind = .petExpress

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Pet Transportation Calculator")
                    .font(SPDesignSystem.Typography.heading1())

                SPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Estimate your trip")
                            .font(SPDesignSystem.Typography.heading3())
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Distance (miles)")
                                TextField("0", text: $distanceMiles)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Number of Pets")
                                TextField("1", text: $numberOfPets)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }
                        Picker("Service Type", selection: $serviceType) {
                            Text("PET Express").tag(TransportKind.petExpress)
                            Text("Shuttle Service").tag(TransportKind.shuttleService)
                            Text("Flight Companion").tag(TransportKind.flightCompanion)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                results
            }
            .padding()
        }
        .navigationTitle("Transportation")
    }

    private var results: some View {
        VStack(spacing: 16) {
            costRow(label: "PET Express Total Cost", value: petExpressCost, highlight: serviceType == .petExpress, subtitle: "Private transport pricing")
            costRow(label: "Shuttle Service Total Cost", value: shuttleServiceCost, highlight: serviceType == .shuttleService, subtitle: "Shared ride estimate")
            costRow(label: "Flight Companion Total Cost", value: flightCompanionCost, highlight: serviceType == .flightCompanion, subtitle: "Escort for pets under 20lbs")
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    private func costRow(label: String, value: Double, highlight: Bool, subtitle: String) -> some View {
        SPCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.headline)
                    Text(subtitle).font(.footnote).foregroundColor(.secondary)
                }
                Spacer()
                Text("$\(value, specifier: "%.2f")")
                    .font(.title2).bold()
                    .foregroundColor(highlight ? SPDesignSystem.Colors.primaryAdjusted(colorScheme) : .primary)
            }
        }
        .opacity(highlight ? 1 : 0.6)
    }

    private var petExpressCost: Double { (200 * pets) + (2 * miles) }
    private var shuttleServiceCost: Double { (300 * pets) + (1 * miles) }
    private var flightCompanionCost: Double { (1500 * pets) + (1 * miles) }

    private var miles: Double { Double(distanceMiles) ?? 0 }
    private var pets: Double { Double(numberOfPets) ?? 1 }
}

enum TransportKind { case petExpress, shuttleService, flightCompanion }

struct ServiceRow: View {
    let name: String
    let duration: String
    let price: String
    let details: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.headline)
                Spacer()
                Text(price).bold()
            }
            Text(duration).foregroundColor(.secondary)
            Text(details)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: SavDaily Subscriptions
struct SavDailyPlan: Identifiable {
    let id = UUID()
    let name: String
    let walksPerMonth: String
    let price: String
    let SavedNote: String
    let perks: String
    let subscribeURL: URL
}

struct SavDailyServicesView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    private let plans: [SavDailyPlan] = [
        .init(name: "Regular",
              walksPerMonth: "12 walks",
              price: "$270",
              SavedNote: "Save $30",
              perks: "1 Free Walk for 12‑day streak",
              subscribeURL: URL(string: "https://square.link/u/mgbPj5FO")!),
        .init(name: "Premium",
              walksPerMonth: "20 walks",
              price: "$450",
              SavedNote: "Save $50",
              perks: "2 Free Walks + Priority Scheduling",
              subscribeURL: URL(string: "https://square.link/u/hMLzIXzK")!),
        .init(name: "Unlimited",
              walksPerMonth: "30 walks",
              price: "$675",
              SavedNote: "Save $75",
              perks: "3 Free Walks + Surprise Gift",
              subscribeURL: URL(string: "https://square.link/u/pYJ08RLc")!)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                ForEach(plans) { plan in
                    SavDailyPlanCard(plan: plan) { url in
                        openURL(url)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("SavDaily")
    }

    private var header: some View {
        ZStack(alignment: .leading) {
            Color.yellow
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose Your Plan")
                    .font(SPDesignSystem.Typography.heading1())
                    .foregroundColor(SPDesignSystem.Colors.dark)
                Text("Flexible monthly walking bundles designed around your pet's routine.")
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.black.opacity(0.75))
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }
}

private struct SavDailyPlanCard: View {
    let plan: SavDailyPlan
    var onSubscribe: (URL) -> Void

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(plan.name)
                        .font(.headline)
                    Spacer()
                    Text(plan.price)
                        .font(.title3).bold()
                        .foregroundColor(.primary)
                }
                HStack {
                    label(title: "Walks / Month", value: plan.walksPerMonth)
                    Spacer()
                    label(title: "Saved", value: plan.SavedNote)
                }
                Text(plan.perks)
                    .font(.subheadline).bold()
                    .foregroundColor(.orange)

                Button {
                    onSubscribe(plan.subscribeURL)
                } label: {
                    Text("Subscribe")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
                }
                .background(Color.yellow)
                .cornerRadius(14)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func label(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.subheadline)
        }
    }
}


