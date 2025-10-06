import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import MapKit
import Combine

struct AdminDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState
    @StateObject private var serviceBookings = ServiceBookingDataService()
    @StateObject private var sitterData = SitterDataService()
    // Using UnifiedChatService for all messaging functionality
    @State private var activeVisits: [LiveVisit] = []
    @State private var isRefreshing: Bool = false
    @State private var showInquiryChat: Bool = false
    @State private var showChat: Bool = false
    @State private var chatSeed: String = ""
    @State private var selectedConversationId: String? = nil
    @State private var showDetails: Bool = false
    @State private var detailsVisit: LiveVisit? = nil
    @State private var assignTarget: ServiceBooking? = nil
    var body: some View {
        TabView {
            Home
                .tabItem { Label("Home", systemImage: "house.fill") }
            AdminClientsView()
                .tabItem { Label("Clients", systemImage: "person.3.fill") }
            AdminSittersView()
                .tabItem { Label("Sitters", systemImage: "figure.walk") }
            AdminBookingsView(serviceBookings: serviceBookings)
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
                    pendingApprovals
                    clientInquiries
                    liveVisits
                    revenueChart
                    activityLog
                }
                .padding()
            }
            .navigationTitle("Overview")
        }
    }

    private var pendingApprovals: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pending Approvals").font(SPDesignSystem.Typography.heading3())
            if serviceBookings.pendingBookings.isEmpty {
                SPCard { Text("No pending service bookings").foregroundColor(.secondary) }
            } else {
                VStack(spacing: 8) {
                    ForEach(serviceBookings.pendingBookings) { b in
                        SPCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(b.serviceType).font(.headline)
                                    Text(b.scheduledDate.formatted(date: .abbreviated, time: .omitted) + " at " + b.scheduledTime)
                                        .font(.subheadline).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Approve") {
                                    assignTarget = b
                                }
                                .buttonStyle(PrimaryButtonStyleBrightInLight())
                            }
                        }
                    }
                }
            }
        }
        .onAppear { serviceBookings.listenToPendingBookings() }
        .sheet(item: Binding(get: { assignTarget.map { AssignSheetTarget(booking: $0) } }, set: { v in assignTarget = v?.booking })) {
            item in
            AssignSitterSheet(booking: item.booking, sitterData: sitterData) { sitter in
                Task {
                    try? await serviceBookings.approveBooking(bookingId: item.booking.id, sitterId: sitter.id, sitterName: sitter.name)
                    assignTarget = nil
                }
            }
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
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Inquiries")
                        .font(SPDesignSystem.Typography.heading3())
                    Spacer()
                    Button(action: { showInquiryChat = true }) {
                        Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button(action: {
                        Task {
                            do {
                                try await appState.chatService.cleanupDuplicateConversations()
                                print("✅ Cleanup completed successfully")
                            } catch {
                                print("❌ Cleanup failed: \(error)")
                            }
                        }
                    }) {
                        Label("Cleanup", systemImage: "trash")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .foregroundColor(.red)
                }
                Text("Recent conversations with pet owners.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Show recent conversations grouped by pet owner
                if !appState.chatService.conversations.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(getRecentConversations(), id: \.id) { conversation in
                            ConversationRow(conversation: conversation) {
                                selectedConversationId = conversation.id
                            }
                        }
                    }
                } else {
                    Text("No recent conversations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
        }
        .sheet(isPresented: $showInquiryChat) {
            NavigationStack { AdminInquiryChatView(initialText: "Hello! How can we help with your booking?") }
        }
        .sheet(item: Binding(get: { selectedConversationId.map { ChatSheetId(id: $0) } }, set: { v in selectedConversationId = v?.id })) { item in
            NavigationStack {
                ConversationChatView(conversationId: item.id)
                    .environmentObject(appState.chatService)
            }
        }
    }
    
    // Helper function to get recent conversations with pet owners
    private func getRecentConversations() -> [Conversation] {
        let allConversations = appState.chatService.conversations
        print("🔍 AdminDashboardView: Total conversations: \(allConversations.count)")
        
        let adminInquiryConversations = allConversations.filter { conversation in
            // Only show admin inquiry conversations
            let isAdminInquiry = conversation.type == .adminInquiry
            print("🔍 AdminDashboardView: Conversation \(conversation.id) type: \(conversation.type), isAdminInquiry: \(isAdminInquiry)")
            return isAdminInquiry
        }
        
        print("🔍 AdminDashboardView: Admin inquiry conversations: \(adminInquiryConversations.count)")
        
        let sortedConversations = adminInquiryConversations
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
            .prefix(5)
            .map { $0 }
        
        print("🔍 AdminDashboardView: Returning \(sortedConversations.count) conversations")
        for conv in sortedConversations {
            print("🔍 AdminDashboardView: - Conversation \(conv.id): participants: \(conv.participants)")
        }
        
        return sortedConversations
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
                        Text("No active visits right now. All quiet!")
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
        .sheet(isPresented: $showChat) { 
            NavigationStack { 
                AdminInquiryChatView(initialText: chatSeed.isEmpty ? "Hello" : chatSeed, currentUserRole: .admin)
                    .environmentObject(appState.chatService)
            }
        }
        .sheet(isPresented: $showDetails) {
            if let v = detailsVisit {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Client: \(v.clientName)").font(.headline)
                        Text("Sitter: \(v.sitterName)")
                        Text("Start: \(v.scheduledStart.formatted(date: .abbreviated, time: .shortened))")
                        Text("End: \(v.scheduledEnd.formatted(date: .abbreviated, time: .shortened))")
                        if let addr = v.address, !addr.isEmpty { Text("Address: \(addr)") }
                        LiveVisitMapPreview(sitterId: v.sitterId)
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Visit Details")
                }
            }
        }
    }

    private var revenueChart: some View {
        AdminRevenueSection()
    }

    private var activityLog: some View {
        AdminActivityLog()
    }
}

private struct AdminMessagesTab: View {
    @EnvironmentObject var chat: ChatService
    @State private var selectedConversationId: String? = nil
    @State private var selectedTab: MessageTab = .approveTexts

    enum MessageTab: String, CaseIterable {
        case approveTexts = "Approve Texts"
        case sitterSupport = "Sitter Support"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Message Type", selection: $selectedTab) {
                    ForEach(MessageTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Content based on selected tab
                switch selectedTab {
                case .approveTexts:
                    ApproveTextsView()
                case .sitterSupport:
                    SitterSupportView(chat: chat, selectedConversationId: $selectedConversationId)
                }
            }
            .navigationTitle("Messages")
            .onAppear {
                chat.listenToAdminInquiries()
                chat.listenToMyConversations()
            }
            .sheet(item: Binding(get: { selectedConversationId.map { ChatSheetId(id: $0) } }, set: { v in selectedConversationId = v?.id })) { item in
                ConversationChatView(conversationId: item.id)
                    .environmentObject(chat)
            }
        }
    }
}

// MARK: - Approve Texts View
private struct ApproveTextsView: View {
    @EnvironmentObject var chat: ChatService
    @State private var showingRejectAlert = false
    @State private var messageToReject: ChatMessage?
    @State private var rejectionReason = ""

    var body: some View {
        List {
            if chat.getPendingMessagesForAdmin().isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No pending messages")
                        .font(.headline)
                    Text("All sitter-to-client messages are approved")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(chat.getPendingMessagesForAdmin()) { message in
                    PendingMessageCard(
                        message: message,
                        onApprove: {
                            Task {
                                try? await chat.approveMessage(messageId: message.id ?? "", conversationId: getConversationIdForMessage(message))
                            }
                        },
                        onReject: {
                            messageToReject = message
                            showingRejectAlert = true
                        }
                    )
                }
            }
        }
        .alert("Reject Message", isPresented: $showingRejectAlert) {
            TextField("Reason for rejection", text: $rejectionReason)
            Button("Cancel", role: .cancel) {
                rejectionReason = ""
                messageToReject = nil
            }
            Button("Reject", role: .destructive) {
                if let message = messageToReject, !rejectionReason.isEmpty {
                    Task {
                        try? await chat.rejectMessage(messageId: message.id ?? "", conversationId: getConversationIdForMessage(message), reason: rejectionReason)
                    }
                }
                rejectionReason = ""
                messageToReject = nil
            }
        } message: {
            Text("Please provide a reason for rejecting this message.")
        }
    }
    
    private func getConversationIdForMessage(_ message: ChatMessage) -> String {
        // Find the conversation that contains this message
        for (conversationId, messages) in chat.messages {
            if messages.contains(where: { $0.id == message.id }) {
                return conversationId
            }
        }
        return ""
    }
}

// MARK: - Pending Message Card
private struct PendingMessageCard: View {
    let message: ChatMessage
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with sender info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From: \(message.senderId)") // Would need to get actual name
                        .font(.headline)
                    Text("Message ID: \(message.id ?? "Unknown")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(message.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Message content
            Text(message.text)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Approve") {
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button("Reject") {
                    onReject()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Inquiries View
private struct InquiriesView: View {
    @ObservedObject var chat: ChatService
    @Binding var selectedConversationId: String?
    
    var body: some View {
        List {
            Section("Client Inquiries") {
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
            Section("Active Conversations") {
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
    }
}

// MARK: - Sitter Support View
private struct SitterSupportView: View {
    @ObservedObject var chat: ChatService
    @Binding var selectedConversationId: String?
    
    // Filter conversations to show only sitter-to-client type (admin can see these)
    private var sitterConversations: [Conversation] {
        chat.conversations.filter { conversation in
            conversation.type == .sitterToClient
        }.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }
    
    var body: some View {
        List {
            Section("Sitter Messages (Pending Approval)") {
                if sitterConversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No sitter messages")
                            .font(.headline)
                        Text("All sitter messages have been processed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(sitterConversations) { conversation in
                        Button(action: { selectedConversationId = conversation.id }) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Show sitter name (first participant who is not admin)
                                Text(conversationDisplayName(for: conversation))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(conversation.lastMessage.isEmpty ? "No messages yet" : conversation.lastMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                
                                // Show pending messages count
                                let pendingCount = getPendingMessageCount(for: conversation)
                                if pendingCount > 0 {
                                    HStack {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("\(pendingCount) pending approval")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    private func conversationDisplayName(for conversation: Conversation) -> String {
        // Get sitter name (first participant who is not admin)
        let sitterParticipant = conversation.participants.first { participant in
            if let index = conversation.participants.firstIndex(of: participant),
               index < conversation.participantRoles.count {
                return conversation.participantRoles[index] == .petSitter
            }
            return false
        }
        
        if let sitterId = sitterParticipant {
            return chat.displayName(for: sitterId)
        }
        
        return "Unknown Sitter"
    }
    
    private func getPendingMessageCount(for conversation: Conversation) -> Int {
        // Count pending messages in this conversation
        let messages = chat.messages[conversation.id] ?? []
        return messages.filter { $0.status == .pending }.count
    }
}

private struct LiveVisit: Identifiable {
    let id: String
    let clientName: String
    let sitterName: String
    let sitterId: String
    let scheduledStart: Date
    let scheduledEnd: Date
    let checkIn: Date?
    let checkOut: Date?
    let status: String // 'in_progress'|'delayed'|'issue'|'completed'
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
                LiveVisitMapPreview(sitterId: visit.sitterId)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    let sitterId = data["sitterId"] as? String ?? ""
                    let scheduledStart = (data["scheduledStart"] as? Timestamp)?.dateValue() ?? Date()
                    let scheduledEnd = (data["scheduledEnd"] as? Timestamp)?.dateValue() ?? Date().addingTimeInterval(30*60)
                    let address = data["address"] as? String
                    let timeline = data["timeline"] as? [String: Any]
                    let checkInTs = ((timeline?["checkIn"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    let checkOutTs = ((timeline?["checkOut"] as? [String: Any])?["timestamp"] as? Timestamp)?.dateValue()
                    let status = data["status"] as? String ?? "in_progress"
                    items.append(LiveVisit(id: d.documentID, clientName: clientName, sitterName: sitterName, sitterId: sitterId, scheduledStart: scheduledStart, scheduledEnd: scheduledEnd, checkIn: checkInTs, checkOut: checkOutTs, status: status, address: address))
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

// MARK: - Assign sitter sheet
private struct AssignSheetTarget: Identifiable { let booking: ServiceBooking; var id: String { booking.id } }

private struct AssignSitterSheet: View {
    let booking: ServiceBooking
    @ObservedObject var sitterData: SitterDataService
    var onAssign: (SitterProfile) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section(header: Text("Select Sitter")) {
                ForEach(sitterData.availableSitters) { sitter in
                    Button(action: { onAssign(sitter); dismiss() }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sitter.name).font(.headline)
                                Text(sitter.email).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if sitter.isActive { Circle().fill(Color.green).frame(width: 10, height: 10) }
                        }
                    }
                }
            }
        }
        .onAppear { sitterData.listenToActiveSitters() }
        .navigationTitle("Assign Sitter")
    }
}

// MARK: - Live location preview
private final class SitterLocationListener: ObservableObject {
    @Published var coordinate: CLLocationCoordinate2D? = nil
    private var listener: ListenerRegistration? = nil

    init(sitterId: String) {
        guard !sitterId.isEmpty else { return }
        let db = Firestore.firestore()
        listener = db.collection("locations").document(sitterId).addSnapshotListener { doc, _ in
            guard let data = doc?.data(),
                  let lat = data["lat"] as? CLLocationDegrees,
                  let lng = data["lng"] as? CLLocationDegrees else { return }
            DispatchQueue.main.async {
                self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }
    }

    deinit { listener?.remove() }
}

private struct LiveVisitMapPreview: View {
    @StateObject private var loc: SitterLocationListener
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    init(sitterId: String) {
        _loc = StateObject(wrappedValue: SitterLocationListener(sitterId: sitterId))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: loc.coordinate.map { [MapPoint(coordinate: $0)] } ?? []) { point in
            MapMarker(coordinate: point.coordinate, tint: .blue)
        }
        .onReceive(loc.$coordinate) { coord in
            if let c = coord {
                region.center = c
            }
        }
    }
}

private struct MapPoint: Identifiable { let id = UUID(); let coordinate: CLLocationCoordinate2D }

// MARK: - Admin Bookings View
private struct AdminBookingsView: View {
    @ObservedObject var serviceBookings: ServiceBookingDataService
    @State private var segment: Segment = .current
    @State private var clientNames: [String: String] = [:]

    enum Segment: String, CaseIterable, Identifiable {
        case past = "Past"
        case current = "Current"
        case future = "Future"
        var id: String { rawValue }
    }

    private var filtered: [ServiceBooking] {
        let now = Date()
        let bookings = serviceBookings.allBookings
        func endDate(_ b: ServiceBooking) -> Date { b.scheduledDate.addingTimeInterval(TimeInterval(max(b.duration, 0) * 60)) }
        switch segment {
        case .past:
            return bookings.filter { 
                // Past bookings: completed, cancelled, or ended before now
                $0.status == .completed || 
                $0.status == .cancelled || 
                endDate($0) < now 
            }.sorted { $0.scheduledDate > $1.scheduledDate }
        case .current:
            return bookings.filter { 
                // Current bookings: in adventure (active) or currently scheduled
                $0.status == .inAdventure || 
                ($0.scheduledDate <= now && endDate($0) > now)
            }.sorted { $0.scheduledDate < $1.scheduledDate }
        case .future:
            return bookings.filter { 
                // Future bookings: pending, approved, or scheduled after now
                $0.status == .pending || 
                $0.status == .approved || 
                $0.scheduledDate > now 
            }.sorted { $0.scheduledDate < $1.scheduledDate }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Timeframe", selection: $segment) {
                    ForEach(Segment.allCases) { seg in Text(seg.rawValue).tag(seg) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List {
                    ForEach(filtered) { b in
                        AdminBookingFullCard(booking: b, clientName: clientNames[b.clientId])
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Bookings")
        }
        .onAppear {
            serviceBookings.listenToAllBookings()
        }
        .onReceive(serviceBookings.$allBookings) { _ in
            resolveMissingClientNames()
        }
    }

    private func resolveMissingClientNames() {
        let ids = Set(serviceBookings.allBookings.map { $0.clientId }).subtracting(clientNames.keys)
        guard !ids.isEmpty else { return }
        let db = Firestore.firestore()
        for uid in ids {
            db.collection("users").document(uid).getDocument { doc, _ in
                let data = doc?.data() ?? [:]
                let email = (data["email"] as? String) ?? ""
                let emailFallback = email.split(separator: "@").first.map(String.init) ?? "Unnamed"
                let rawName = (data["displayName"] as? String) ?? (data["name"] as? String) ?? ""
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emailFallback : rawName
                DispatchQueue.main.async { self.clientNames[uid] = name }
            }
        }
    }
}

private struct AdminBookingFullCard: View {
    let booking: ServiceBooking
    let clientName: String?

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(booking.serviceType).font(.headline)
                        HStack(spacing: 8) {
                            Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                            Text("at \(booking.scheduledTime)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusPill(status: booking.status)
                }

                HStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.caption).foregroundColor(.secondary)
                    Text("Client: \(clientName ?? booking.clientId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let sitterName = booking.sitterName, !sitterName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk").font(.caption).foregroundColor(.green)
                        Text("Sitter: \(sitterName)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                if !booking.pets.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint.fill").font(.caption).foregroundColor(.secondary)
                        Text("Pets: \(booking.pets.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let note = booking.specialInstructions, !note.isEmpty {
                    Text("Note: \(note)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                }
            }
        }
    }
}

private struct StatusPill: View {
    let status: ServiceBooking.BookingStatus
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(status.color).frame(width: 8, height: 8)
            Text(status.displayName)
                .font(.caption).fontWeight(.medium)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Conversation Row Component
private struct ConversationRow: View {
    let conversation: Conversation
    let onTap: () -> Void
    @EnvironmentObject var chat: ChatService
    @State private var petOwnerName: String = "Pet Owner"
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(petOwnerName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(petOwnerName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(conversation.lastMessage.isEmpty ? "No messages yet" : conversation.lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Date
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDate(conversation.lastMessageAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Unread indicator
                    if getUnreadCount() > 0 {
                        Text("\(getUnreadCount())")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadPetOwnerName()
        }
    }
    
    private func loadPetOwnerName() {
        // Find the pet owner participant (non-admin)
        if let petOwnerId = conversation.participants.first(where: { participantId in
            // Find participant who is not admin
            guard let roleIndex = conversation.participants.firstIndex(of: participantId),
                  roleIndex < conversation.participantRoles.count else {
                return false
            }
            return conversation.participantRoles[roleIndex] != .admin
        }) {
            let name = chat.displayName(for: petOwnerId)
            DispatchQueue.main.async {
                self.petOwnerName = name
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func getUnreadCount() -> Int {
        // Get unread count for the current user (admin)
        return conversation.unreadCounts[Auth.auth().currentUser?.uid ?? ""] ?? 0
    }
}
