import SwiftUI
import FirebaseAuth

struct OwnerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var scrollOffset: CGFloat = 0
    @State private var baseline: CGFloat? = nil

    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Home
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            OwnerPetsView()
                .tabItem { Label("My Pets", systemImage: "pawprint.fill") }
                .tag(1)
            Text("Bookings")
                .tabItem { Label("Bookings", systemImage: "calendar") }
                .tag(2)
            MessagesTab()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(3)
            OwnerProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .tint(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
        .onReceive(NotificationCenter.default.publisher(for: .openMessagesTab)) { notif in
            selectedTab = 3
        }
    }

    private var Home: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SPDesignSystem.Spacing.l) {
                    // Track scroll offset — give the probe a non-zero height so GeometryReader updates.
                    Color.clear
                        .frame(height: 1)
                        .overlay(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetKey.self,
                                        value: geo.frame(in: .named("homeScroll")).minY
                                    )
                            }
                        )

                    servicesSection
                    quickActions
                    upcomingServices
                    petsCarousel
                    activityFeed
                }
                .padding()
            }
            .coordinateSpace(name: "homeScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                // Establish a baseline once, then measure relative movement.
                if baseline == nil { baseline = value }
                scrollOffset = value - (baseline ?? 0)
            }
            .safeAreaInset(edge: .top) {
                welcomeHeader
                    .padding(.horizontal, SPDesignSystem.Spacing.l)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: SPDesignSystem.Spacing.m) {
            NavigationLink { BookServiceView() } label: {
                SPCard { Label("Book Service", systemImage: "calendar.badge.plus").font(.headline) }
            }
            Button(action: { callEmergency() }) {
                SPCard { Label("Emergency", systemImage: "phone.fill").font(.headline) }
            }
        }
    }

    private var upcomingServices: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Upcoming Service")
                    .font(SPDesignSystem.Typography.heading3())
                HStack {
                    Image(systemName: "clock").foregroundColor(.secondary)
                    Text("Tomorrow 2:00 PM - 30 min Walk")
                }
                .foregroundColor(.secondary)
            }
        }
    }

    private var petsCarousel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Pets").font(SPDesignSystem.Typography.heading3())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    ForEach(0..<5) { _ in
                        SPCard {
                            VStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2)).frame(height: 100)
                                Text("Buddy")
                                    .font(.headline)
                            }
                            .frame(width: 140)
                        }
                    }
                }
            }
        }
    }

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Activity").font(SPDesignSystem.Typography.heading3())
            ForEach(0..<3) { _ in SPCard { Text("No recent activity").foregroundColor(.secondary) } }
        }
    }

    // MARK: Services Section
    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Services").font(SPDesignSystem.Typography.heading3())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    NavigationLink { DogWalksServicesView() } label: {
                        ServiceCategoryCard(title: "Dog Walks", imageName: "service-dogwalks")
                    }
                    NavigationLink { PetSittingServicesView() } label: {
                        ServiceCategoryCard(title: "Pet Sitting", imageName: "service-petsitting")
                    }
                    NavigationLink { PetTransportationView() } label: {
                        ServiceCategoryCard(title: "Pet Transportation", imageName: "service-transport")
                    }
                    NavigationLink { OvernightCareServicesView() } label: {
                        ServiceCategoryCard(title: "Overnight Care", imageName: "service-overnight")
                    }
                    NavigationLink { SavDailyServicesView() } label: {
                        ServiceCategoryCard(title: "SavDaily", imageName: "service-savdaily")
                    }
                }
            }
        }
    }

    // MARK: Helpers
    private var userName: String {
        if let display = appState.displayName, !display.trimmingCharacters(in: .whitespaces).isEmpty {
            return display
        }
        if let email = appState.authService.currentUser?.email,
           let namePart = email.split(separator: "@").first {
            let formatted = namePart
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized
            return formatted.isEmpty ? "Friend" : formatted
        }
        return "Friend"
    }

    private var welcomeHeader: some View {
        // scrollOffset is negative as you scroll down; convert to a positive collapse amount.
        let collapse = min(max(-scrollOffset, 0), 100) // clamp 0...100
        let scale = 1.0 - (collapse / 300)             // ~1.0 -> ~0.67
        let opacity = 1.0 - (collapse / 100)           // 1.0 -> 0
        let blurRadius = collapse / 12                 // 0 -> ~8.3

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Welcome,")
                .font(SPDesignSystem.Typography.heading1())
            Text(userName)
                .font(SPDesignSystem.Typography.heading1())
                .fontWeight(.bold)
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
        }
        .scaleEffect(scale, anchor: .leading)
        .opacity(opacity)
        .blur(radius: blurRadius)
        .animation(.easeOut(duration: 0.15), value: scrollOffset)
    }

    private func callEmergency() {
        if let url = URL(string: "tel://4845677999") { UIApplication.shared.open(url) }
    }
}

private struct MessagesTab: View {
    @EnvironmentObject var chat: ChatService
    @State private var seeded: Bool = false
    @State private var showChat: Bool = false
    @State private var seedText: String = ""
    @State private var selectedConversationId: String? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("Pinned") {
                    Button(action: { showChat = true }) {
                        HStack {
                            Image(systemName: "pin.fill").foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("SaviPets-Admin").font(.headline)
                                Text("Auto-response: We'll be in touch ASAP.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
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
            .onReceive(NotificationCenter.default.publisher(for: .openMessagesTab)) { notif in
                if let text = notif.userInfo?["seed"] as? String { seedText = text; showChat = true }
            }
            .onAppear { chat.listenToMyConversations() }
            .sheet(isPresented: $showChat) {
                NavigationStack { AdminInquiryChatView(initialText: seedText.isEmpty ? "Hello" : seedText) }
            }
            .sheet(item: Binding(get: {
                selectedConversationId.map { ChatSheetId(id: $0) }
            }, set: { v in
                selectedConversationId = v?.id
            })) { item in
                ConversationChatView(conversationId: item.id)
                    .environmentObject(chat)
            }
        }
    }
}

struct ChatSheetId: Identifiable { let id: String }

struct ConversationChatView: View {
    let conversationId: String
    @EnvironmentObject var chat: ChatService
    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 0) {
            List(chat.messages[conversationId] ?? []) { msg in
                HStack {
                    if msg.senderId != (Auth.auth().currentUser?.uid ?? "") { Spacer() }
                    Text(msg.text)
                        .padding(10)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                    if msg.senderId == (Auth.auth().currentUser?.uid ?? "") { Spacer() }
                }
            }
            .listStyle(.plain)
            .onAppear { chat.listenToMessages(conversationId: conversationId) }

            HStack(spacing: 8) {
                TextField("Message", text: $input).textFieldStyle(.roundedBorder)
                Button("Send") {
                    Task { try? await chat.sendMessage(conversationId: conversationId, text: input); input = "" }
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Chat")
    }
}

#if DEBUG
struct OwnerDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        appState.isAuthenticated = true
        appState.role = .petOwner
        appState.displayName = "Alex"
        return OwnerDashboardView()
            .environmentObject(appState)
            .previewDisplayName("Owner Dashboard")
    }
}
#endif

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
