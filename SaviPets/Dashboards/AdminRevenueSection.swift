import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import OSLog

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
                .foregroundStyle(.primary)

            HStack(spacing: SPDesignSystem.Spacing.m) {
                summaryCard(title: "Total", value: total)
                summaryCard(title: "Avg / Day", value: average)
                summaryCard(title: "Best Day", value: topDay?.amount ?? 0, subtitle: topDay?.label)
            }

            // Enhanced 3D Chart Card
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily Totals")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                VStack(spacing: 10) {
                    ForEach(dailySums, id: \.label) { d in
                        RevenueBarRow(
                            label: d.label,
                            amount: d.amount,
                            maxAmount: maxDailyAmount,
                            isTopDay: d.label == topDay?.label
                        )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3), lineWidth: 1)
                    )
            )
            .rotation3DEffect(.degrees(2), axis: (x: 1, y: 0, z: 0))
            SPCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Payments").font(.headline)
                    if recentPayments.isEmpty {
                        Text("No confirmed payments in the last 7 days.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(recentPayments, id: \.bookingId) { p in
                                HStack {
                                    Text(formatDate(p.date))
                                        .font(.caption)
                                        .frame(width: 64, alignment: .leading)
                                    
                                    Text(p.clientName)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("$\(p.amount, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(p.amount < 0 ? .red : .primary)
                                        .fontWeight(.medium)
                                    
                                    Text(p.bookingId.prefix(8))
                                        .foregroundColor(.secondary)
                                        .font(.caption2)
                                        .frame(width: 64, alignment: .trailing)
                                }
                                .padding(.vertical, 2)
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
        
        // Listen to serviceBookings with confirmed payments (approved payments only)
        listener = db.collection("serviceBookings")
            .whereField("paymentStatus", isEqualTo: "confirmed")
            .whereField("paymentConfirmedAt", isGreaterThanOrEqualTo: Timestamp(date: sevenDaysAgo))
            .order(by: "paymentConfirmedAt", descending: false)
            .addSnapshotListener { snapshot, _ in
                var sums: [String: Double] = [:]
                var totalUSD: Double = 0
                
                if let docs = snapshot?.documents, !docs.isEmpty {
                    let group = DispatchGroup()
                    var enriched: [(Date, Double, String, String, String)] = []
                    
                    for d in docs {
                        let data = d.data()
                        let bookingId = d.documentID
                        
                        // Get payment amount from booking price
                        let price = data["price"] as? Double ?? 0.0
                        
                        // Get payment confirmation date
                        let date = (data["paymentConfirmedAt"] as? Timestamp)?.dateValue() ?? Date()
                        let label = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
                        
                        // Get client info
                        let clientId = data["clientId"] as? String ?? ""
                        
                        // Check if this was refunded
                        let status = data["status"] as? String ?? ""
                        let isRefunded = (status == "cancelled" || status == "refunded")
                        let refundAmount = data["refundAmount"] as? Double ?? 0.0
                        
                        // Calculate net amount (payment - refund if any)
                        let netAmount = isRefunded ? -refundAmount : price
                        
                        // Add to daily sums
                        sums[label, default: 0] += netAmount
                        totalUSD += netAmount
                        
                        // Fetch client name
                        group.enter()
                        db.collection("users").document(clientId).getDocument { snap, _ in
                            let name = (snap?.data()?["displayName"] as? String) ?? 
                                      (snap?.data()?["name"] as? String) ?? 
                                      "Client #\(clientId.prefix(6))"
                            enriched.append((date, netAmount, clientId, bookingId, name))
                            group.leave()
                        }
                    }
                    
                    group.notify(queue: .main) {
                        // Sort by date descending and take top 10
                        self.recentPayments = enriched
                            .sorted(by: { $0.0 > $1.0 })
                            .prefix(10)
                            .map { ($0.0, $0.1, $0.2, $0.3, $0.4) }
                        
                        // Sort daily sums chronologically
                        self.dailySums = sums.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
                        self.total = totalUSD
                        
                        // Calculate average only for days that had payments
                        let daysWithPayments = sums.filter { $0.value > 0 }.count
                        self.average = daysWithPayments > 0 ? (totalUSD / Double(daysWithPayments)) : 0
                        
                        self.topDay = self.dailySums.max(by: { $0.1 < $1.1 })
                        
                        AppLogger.data.info("💰 Revenue calculated: Total=$\(totalUSD), Days=\(self.dailySums.count), Avg=$\(self.average)")
                    }
                } else {
                    // No confirmed payments in last 7 days - show empty state
                    DispatchQueue.main.async {
                        self.recentPayments = []
                        self.dailySums = []
                        self.total = 0
                        self.average = 0
                        self.topDay = nil
                        AppLogger.data.info("💰 No confirmed payments found in last 7 days")
                    }
                }
            }
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
    let isTopDay: Bool
    
    @State private var animateBar: CGFloat = 0
    @State private var pulseEffect: Bool = false

    var body: some View {
        let baseColor = SPDesignSystem.Colors.primaryAdjusted(colorScheme)
        
        // Enhanced 3D gradient with depth
        let barGradient = LinearGradient(
            gradient: Gradient(colors: [
                baseColor.opacity(0.9),
                baseColor.opacity(0.7),
                baseColor.opacity(0.5),
                baseColor.opacity(0.3)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Special glow gradient for top day
        let glowGradient = LinearGradient(
            gradient: Gradient(colors: [
                baseColor.opacity(0.6),
                baseColor.opacity(0.3),
                baseColor.opacity(0.1)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )

        HStack(spacing: 12) {
            // Day label
            Text(label)
                .frame(width: 60, alignment: .leading)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            // Bar chart with 3D effect
            GeometryReader { geo in
                let targetWidth = CGFloat(amount / max(maxAmount, 1)) * max(geo.size.width - 8, 0)

                ZStack(alignment: .leading) {
                    // Subtle background track with gradient
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.secondary.opacity(0.08),
                                    Color.secondary.opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                        )
                    
                    // Animated 3D bar with depth
                    RoundedRectangle(cornerRadius: 8)
                        .fill(barGradient)
                        .overlay(
                            // Top highlight for 3D effect
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.2 : 0.4),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: baseColor.opacity(0.3), radius: isTopDay ? 8 : 4, x: 0, y: isTopDay ? 5 : 3)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        .frame(width: animateBar, height: 18)
                        .scaleEffect(isTopDay && pulseEffect ? 1.05 : 1.0)
                        .animation(.easeOut(duration: 0.8).delay(Double(dailySums.firstIndex(where: { $0.label == label }) ?? 0) * 0.1), value: animateBar)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseEffect)
                    
                    // Glow effect for top day
                    if isTopDay {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(glowGradient)
                            .frame(width: animateBar, height: 18)
                            .blur(radius: 8)
                            .opacity(pulseEffect ? 0.6 : 0.3)
                    }
                }
                .onAppear {
                    withAnimation {
                        animateBar = targetWidth
                    }
                    if isTopDay {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            pulseEffect = true
                        }
                    }
                }
                .onChange(of: amount) { _ in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        animateBar = targetWidth
                    }
                }
            }
            .frame(height: 22)

            // Amount with subtle animation
            Text("$\(amount, specifier: "%.2f")")
                .font(.system(size: 13, weight: isTopDay ? .semibold : .medium, design: .rounded))
                .foregroundColor(isTopDay ? baseColor : .secondary)
                .frame(width: 70, alignment: .trailing)
                .scaleEffect(isTopDay && pulseEffect ? 1.05 : 1.0)
        }
        .padding(.vertical, 4)
    }
    
    // Helper to get dailySums for animation delay
    private var dailySums: [(label: String, amount: Double)] {
        // Access from parent view context - will be populated by parent
        []
    }
}

// Helper function for 12-hour time formatting
private func formatTime(_ date: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = "h:mm a"
    return df.string(from: date)
}
