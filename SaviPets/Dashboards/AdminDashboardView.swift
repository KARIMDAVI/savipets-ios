import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var activeVisits: [LiveVisit] = []
    @State private var isRefreshing: Bool = false
    @State private var showInquiryChat: Bool = false
    @State private var showChat: Bool = false
    @State private var chatSeed: String = ""
    @State private var showDetails: Bool = false
    @State private var detailsVisit: LiveVisit? = nil
    var body: some View {
        TabView {
            Home
                .tabItem { Label("Home", systemImage: "house.fill") }
            AdminClientsView()
                .tabItem { Label("Clients", systemImage: "person.3.fill") }
            Text("Sitters")
                .tabItem { Label("Sitters", systemImage: "figure.walk") }
            Text("Bookings")
                .tabItem { Label("Bookings", systemImage: "calendar") }
            AdminMessagesTab()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
            AdminProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
    }

    private var Home: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SPDesignSystem.Spacing.l) {
                    header
                    clientInquiries
                    liveVisits
                    quickActions
                    revenueChart
                    activityLog
                }
                .padding()
            }
            .navigationTitle("Overview")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Business Overview")
                    .font(SPDesignSystem.Typography.heading1())
                Text("Metrics at a glance").foregroundColor(.secondary)
            }
            Spacer()
            Button(action: refreshNow) {
                Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath")
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
        }
    }

    private var clientInquiries: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Client Inquiries")
                        .font(SPDesignSystem.Typography.heading3())
                    Spacer()
                    Button(action: { showInquiryChat = true }) {
                        Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                Text("Respond to overnight requests and general questions in real-time.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showInquiryChat) {
            NavigationStack { AdminInquiryChatView(initialText: "Hello! How can we help with your booking?") }
        }
    }

    private var liveVisits: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 0) {
                    Text("Live Visits (")
                    Text("\(activeVisits.count)").bold()
                    Text(")")
                }
                Spacer()
                Button(action: refreshNow) { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh live visits")
            }
            .font(SPDesignSystem.Typography.heading3())

            if activeVisits.isEmpty {
                SPCard {
                    HStack(spacing: 12) {
                        Image(systemName: "sun.max.fill").foregroundColor(.orange)
                        Text("No active visits right now. All quiet! 😊")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(activeVisits) { v in
                        LiveVisitCard(
                            visit: v,
                            onViewDetails: { detailsVisit = v; showDetails = true },
                            onMessageSitter: { openChatFor(visit: v) },
                            onEndVisit: { endVisit(v) }
                        )
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear(perform: subscribeLiveVisits)
        .sheet(isPresented: $showChat) { NavigationStack { AdminInquiryChatView(initialText: chatSeed.isEmpty ? "Hello" : chatSeed) } }
        .sheet(isPresented: $showDetails) {
            if let v = detailsVisit {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Client: \(v.clientName)").font(.headline)
                        Text("Sitter: \(v.sitterName)")
                        Text("Start: \(v.scheduledStart.formatted(date: .abbreviated, time: .shortened))")
                        Text("End: \(v.scheduledEnd.formatted(date: .abbreviated, time: .shortened))")
                        if let addr = v.address, !addr.isEmpty { Text("Address: \(addr)") }
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Visit Details")
                }
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: SPDesignSystem.Spacing.m) {
            SPCard { Label("Add Client", systemImage: "person.badge.plus.fill").font(.headline) }
            NavigationLink {
                AdminChangePasswordView()
            } label: {
                SPCard { Label("Admin Password", systemImage: "key.fill").font(.headline) }
            }
        }
    }

    private var revenueChart: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Revenue (last 7 days)").font(.headline)
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2)).frame(height: 140)
            }
        }
    }

    private var activityLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity Log").font(SPDesignSystem.Typography.heading3())
            ForEach(0..<4) { _ in SPCard { Text("No recent activity").foregroundColor(.secondary) } }
        }
    }
}

private struct AdminMessagesTab: View {
    @EnvironmentObject var chat: ChatService
    @State private var selectedConversationId: String? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("Inquiries") {
                    ForEach(chat.inquiries) { inq in
                        Button(action: {
                            Task { try? await chat.acceptInquiry(inq) }
                        }) {
                            VStack(alignment: .leading) {
                                Text(inq.subject).font(.headline)
                                Text(inq.initialMessage).font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Section("Conversations") {
                    ForEach(chat.conversations) { convo in
                        Button(action: { selectedConversationId = convo.id }) {
                            VStack(alignment: .leading) {
                                Text(convo.participants.joined(separator: ", "))
                                    .font(.headline)
                                Text(convo.lastMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .onAppear { chat.listenToAdminInquiries(); chat.listenToMyConversations() }
            .sheet(item: Binding(get: { selectedConversationId.map { ChatSheetId(id: $0) } }, set: { v in selectedConversationId = v?.id })) { item in
                ConversationChatView(conversationId: item.id)
                    .environmentObject(chat)
            }
        }
    }
}

private struct LiveVisit: Identifiable {
    let id: String
    let clientName: String
    let sitterName: String
    let scheduledStart: Date
    let scheduledEnd: Date
    let checkIn: Date?
    let status: String // 'in_progress'|'delayed'|'issue'
    let address: String?
}

private struct LiveVisitCard: View {
    let visit: LiveVisit
    var onViewDetails: () -> Void = {}
    var onMessageSitter: () -> Void = {}
    var onEndVisit: () -> Void = {}

    private var progress: Double {
        let start = visit.checkIn ?? visit.scheduledStart
        let end = visit.scheduledEnd
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let elapsed = min(Date().timeIntervalSince(start), total)
        return elapsed / total
    }

    private var borderColor: Color {
        switch visit.status {
        case "in_progress": return .green
        case "delayed": return .yellow
        case "issue": return .red
        default: return .gray
        }
    }

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Client: \(visit.clientName) | Sitter: \(visit.sitterName)")
                        .font(.headline)
                    Spacer()
                    Image(systemName: visit.status == "in_progress" ? "checkmark.circle.fill" : visit.status == "delayed" ? "exclamationmark.triangle.fill" : "exclamationmark.octagon.fill")
                        .foregroundColor(borderColor)
                        .accessibilityLabel(visit.status)
                }
                ProgressView(value: progress)
                    .tint(borderColor)
                HStack {
                    Text("Started \(relative(from: visit.checkIn ?? visit.scheduledStart))")
                    Spacer()
                    Text("Ends in \(timeRemaining(until: visit.scheduledEnd))")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                HStack {
                    Button("View Details", action: onViewDetails)
                        .buttonStyle(GhostButtonStyle())
                    Button("Message Sitter", action: onMessageSitter)
                        .buttonStyle(GhostButtonStyle())
                    Spacer()
                    Button("End Visit", action: onEndVisit)
                        .buttonStyle(GhostButtonStyle())
                }
                .accessibilityElement(children: .contain)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
    }

    private func relative(from date: Date) -> String {
        let comp = DateComponentsFormatter(); comp.allowedUnits = [.hour,.minute]; comp.unitsStyle = .short
        let secs = max(Date().timeIntervalSince(date), 0)
        return comp.string(from: secs) ?? "0m"
    }

    private func timeRemaining(until end: Date) -> String {
        let comp = DateComponentsFormatter(); comp.allowedUnits = [.hour,.minute]; comp.unitsStyle = .short
        let secs = max(end.timeIntervalSince(Date()), 0)
        return comp.string(from: secs) ?? "0m"
    }
}
extension AdminDashboardView {
    private func subscribeLiveVisits() {
        let db = Firestore.firestore()
        db.collection("visits")
            .whereField("status", isEqualTo: "in_progress")
            .addSnapshotListener { snap, err in
                guard err == nil, let snap else { self.activeVisits = []; return }
                var items: [LiveVisit] = []
                for d in snap.documents {
                    let data = d.data()
                    let clientName = data["clientName"] as? String ?? "Client"
                    let sitterName = data["sitterName"] as? String ?? "Sitter"
                    let scheduledStart = (data["scheduledStart"] as? Timestamp)?.dateValue() ?? Date()
                    let scheduledEnd = (data["scheduledEnd"] as? Timestamp)?.dateValue() ?? Date().addingTimeInterval(30*60)
                    let address = data["address"] as? String
                    let timeline = data["timeline"] as? [String: Any]
                    let checkInTs = ((timeline?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    let status = data["status"] as? String ?? "in_progress"
                    items.append(LiveVisit(id: d.documentID, clientName: clientName, sitterName: sitterName, scheduledStart: scheduledStart, scheduledEnd: scheduledEnd, checkIn: checkInTs, status: status, address: address))
                }
                withAnimation(.easeInOut(duration: 0.2)) { self.activeVisits = items }
            }
    }

    private func refreshNow() {
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { isRefreshing = false }
        subscribeLiveVisits()
    }

    private func openChatFor(visit: LiveVisit) {
        chatSeed = "Hello \(visit.sitterName), regarding \(visit.clientName)'s visit (\(visit.id))."
        showChat = true
    }

    private func endVisit(_ v: LiveVisit) {
        let db = Firestore.firestore()
        db.collection("visits").document(v.id).setData([
            "status": "completed",
            "timeline.checkOut.timestamp": FieldValue.serverTimestamp()
        ], merge: true)
    }
}
