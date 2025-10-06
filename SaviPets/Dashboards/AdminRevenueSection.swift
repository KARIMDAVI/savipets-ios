import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AdminRevenueSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var dailySums: [(label: String, amount: Double)] = []
    @State private var total: Double = 0
    @State private var average: Double = 0
    @State private var topDay: (label: String, amount: Double)? = nil
    @State private var recentPayments: [(date: Date, amount: Double, userId: String, bookingId: String, clientName: String)] = []
    @State private var listener: ListenerRegistration? = nil

    private var maxDailyAmount: Double {
        max(dailySums.map { $0.amount }.max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.m) {
            Text("Revenue (Last 7 Days)")
                .font(.headline)

            HStack(spacing: SPDesignSystem.Spacing.m) {
                summaryCard(title: "Total", value: total)
                summaryCard(title: "Avg / Day", value: average)
                summaryCard(title: "Best Day", value: topDay?.amount ?? 0, subtitle: topDay?.label)
            }

            SPCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Totals").font(.headline)
                    VStack(spacing: 8) {
                        ForEach(dailySums, id: \.label) { d in
                            RevenueBarRow(label: d.label, amount: d.amount, maxAmount: maxDailyAmount)
                        }
                    }
                }
            }
            SPCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Payments").font(.headline)
                    if recentPayments.isEmpty {
                        Text("No payments yet — showing mock data.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    VStack(spacing: 8) {
                        ForEach(recentPayments.isEmpty ? mockRecent() : recentPayments, id: \.bookingId) { p in
                            HStack {
                                Text(formatDate(p.date)).frame(width: 64, alignment: .leading)
                                Text(p.clientName).lineLimit(1)
                                Spacer()
                                Text("$\(p.amount, specifier: "%.2f")")
                                Text(p.bookingId).foregroundColor(.secondary).font(.caption).frame(width: 64, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { listen() }
        .onDisappear { listener?.remove(); listener = nil }
    }

    @ViewBuilder private func summaryCard(title: String, value: Double, subtitle: String? = nil) -> some View {
        SPCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text("$\(value, specifier: "%.2f")").font(.headline)
                if let subtitle { Text(subtitle).font(.caption).foregroundColor(.secondary) }
            }
        }
    }

    private func listen() {
        let db = Firestore.firestore()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        listener?.remove()
        listener = db.collection("payments")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: sevenDaysAgo))
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, _ in
                var sums: [String: Double] = [:]
                var totalUSD: Double = 0
                var _: [(date: Date, amount: Double, userId: String, bookingId: String, clientName: String)] = []
                if let docs = snapshot?.documents, !docs.isEmpty {
                    let group = DispatchGroup()
                    var enriched: [(Date, Double, String, String, String)] = []
                    for d in docs {
                        let data = d.data()
                        let cents = (data["amount"] as? Double) ?? Double((data["amount"] as? Int) ?? 0)
                        let date = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        let label = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
                        let userId = data["userId"] as? String ?? ""
                        let bookingId = data["bookingId"] as? String ?? ""
                        let usd = cents / 100.0
                        sums[label, default: 0] += usd
                        totalUSD += usd

                        group.enter()
                        Firestore.firestore().collection("users").document(userId).getDocument { snap, _ in
                            let name = (snap?.data()?["displayName"] as? String) ?? (snap?.data()?["name"] as? String) ?? userId.prefix(6).description
                            enriched.append((date, usd, userId, bookingId, name))
                            group.leave()
                        }
                    }
                    group.notify(queue: .main) {
                        self.recentPayments = enriched.sorted(by: { $0.0 > $1.0 }).prefix(10).map { ($0.0, $0.1, $0.2, $0.3, $0.4) }
                        self.dailySums = sums.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
                        self.total = totalUSD
                        self.average = self.dailySums.isEmpty ? 0 : (totalUSD / Double(self.dailySums.count))
                        self.topDay = self.dailySums.max(by: { $0.1 < $1.1 })
                    }
                } else {
                    // Fallback mock data
                    let mock = mockRecent()
                    self.recentPayments = mock
                    for m in mock {
                        let label = self.formatDate(m.date)
                        sums[label, default: 0] += m.amount
                        totalUSD += m.amount
                    }
                    self.dailySums = sums.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
                    self.total = totalUSD
                    self.average = self.dailySums.isEmpty ? 0 : (totalUSD / Double(self.dailySums.count))
                    self.topDay = self.dailySums.max(by: { $0.1 < $1.1 })
                }
            }
    }

    private func mockRecent() -> [(date: Date, amount: Double, userId: String, bookingId: String, clientName: String)] {
        let items = [
            (Date(), 50.00, "test1", "B001", "Test User 1"),
            (Date().addingTimeInterval(-86400), 30.00, "test2", "B002", "Test User 2")
        ]
        return items
    }

    private func formatDate(_ d: Date) -> String {
        DateFormatter.localizedString(from: d, dateStyle: .short, timeStyle: .none)
    }
}

struct AdminActivityLog: View {
    @State private var events: [(client: String, pet: String, status: String, at: Date)] = []
    @State private var listener: ListenerRegistration? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity Log").font(SPDesignSystem.Typography.heading3())
            if events.isEmpty {
                SPCard { Text("No recent activity").foregroundColor(.secondary) }
            } else {
                ForEach(events.indices, id: \.self) { i in
                    let e = events[i]
                    SPCard {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.client).font(.headline)
                                Text(e.pet.isEmpty ? "" : e.pet)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatTime(e.at))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(e.status)
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(statusColor(e.status))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(statusColor(e.status).opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .onAppear(perform: listen)
        .onDisappear { listener?.remove(); listener = nil }
    }

    private func statusColor(_ s: String) -> Color {
        switch s.lowercased() {
        case "in progress": return .orange
        case "completed": return .blue
        default: return .gray
        }
    }

    private func listen() {
        let db = Firestore.firestore()
        listener?.remove()
        // Order by latest check-in or checkout; fallback to scheduledStart
        listener = db.collection("visits")
            .order(by: "scheduledStart", descending: true)
            .limit(to: 30)
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { self.events = []; return }
                let items: [(String,String,String,Date)] = docs.compactMap { d in
                    let data = d.data()
                    let client = data["clientName"] as? String ?? "Client"
                    let petsArr = data["pets"] as? [String]
                    let pet = (data["petName"] as? String) ?? petsArr?.first ?? ""
                    let statusRaw = (data["status"] as? String ?? "").lowercased()
                    let status = statusRaw == "in_progress" ? "In Progress" : (statusRaw == "completed" ? "Completed" : statusRaw.capitalized)
                    let at = ((data["timeline"] as? [String: Any])?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp
                    let date = at?.dateValue() ?? ((data["scheduledStart"] as? Timestamp)?.dateValue() ?? Date())
                    return (client, pet, status, date)
                }
                self.events = items.sorted(by: { $0.3 > $1.3 })
            }
    }
}

// MARK: - Subviews

private struct RevenueBarRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    let amount: Double
    let maxAmount: Double

    var body: some View {
        let barColor = SPDesignSystem.Colors.primaryAdjusted(colorScheme)
        HStack {
            Text(label).frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                let width = CGFloat(amount / max(maxAmount, 1)) * max(geo.size.width - 8, 0)
                RoundedRectangle(cornerRadius: 6)
                    .fill(barColor)
                    .frame(width: width, height: 10)
            }
            .frame(height: 12)
            Spacer(minLength: 8)
            Text("$\(amount, specifier: "%.2f")")
        }
    }
}

// Helper function for 12-hour time formatting
private func formatTime(_ date: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = "h:mm a"
    return df.string(from: date)
}
