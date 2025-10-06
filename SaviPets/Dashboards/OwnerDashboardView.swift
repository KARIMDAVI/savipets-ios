import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct OwnerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var scrollOffset: CGFloat = 0
    @State private var baseline: CGFloat? = nil
    @StateObject private var serviceBookings = ServiceBookingDataService()
    @State private var navigateToBooking: Bool = false

    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Home
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            OwnerPetsView()
                .tabItem { Label("My Pets", systemImage: "pawprint.fill") }
                .tag(1)
            OwnerBookingsView()
                .environmentObject(serviceBookings)
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
        .environmentObject(serviceBookings)
        .onAppear {
            if let uid = appState.authService.currentUser?.uid {
                serviceBookings.listenToUserBookings(userId: uid)
                serviceBookings.listenToVisitStatusChanges() // Add visit status sync
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: SPDesignSystem.Spacing.m) {
            Button(action: { navigateToBooking = true }) {
                SPCard { Label("Book Service", systemImage: "calendar.badge.plus").font(.headline) }
            }
            Button(action: { callEmergency() }) {
                SPCard { Label("Emergency", systemImage: "phone.fill").font(.headline) }
            }
        }
        .sheet(isPresented: $navigateToBooking) {
            NavigationStack {
                BookServiceView()
                    .environmentObject(serviceBookings)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { navigateToBooking = false }
                        }
                    }
            }
        }
    }

    // MARK: Active Bookings Logic
    private var activeBookings: [ServiceBooking] {
        serviceBookings.userBookings.filter { booking in
            // Show only active bookings: pending, approved, in_adventure, and completed
            return booking.status == .pending || booking.status == .approved || booking.status == .inAdventure || booking.status == .completed
        }.sorted { $0.scheduledDate > $1.scheduledDate }
    }
    
    private var upcomingServices: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(SPDesignSystem.Typography.heading3())

            if activeBookings.isEmpty {
                SPCard {
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("No active services")
                            .font(.headline)
                        Text("Complete bookings will be moved to your bookings history")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                }
            } else {
                ForEach(Array(activeBookings.prefix(3))) { booking in
                    BookingCardInline(booking: booking)
                }
            }
        }
    }

    private var petsCarousel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Pets").font(SPDesignSystem.Typography.heading3())
            OwnerPetsStrip()
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

// MARK: - Inline booking card for dashboard
private struct BookingCardInline: View {
    let booking: ServiceBooking
    var body: some View {
        SPCard {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.serviceType).font(.headline)
                    HStack(spacing: 8) {
                        Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                        Text("at \(booking.scheduledTime)")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                    if !booking.pets.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "pawprint.fill").font(.caption).foregroundColor(.secondary)
                            Text(booking.pets.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(booking.status.color).frame(width: 8, height: 8)
                    Text(booking.status.displayName)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(booking.status.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(booking.status.color.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

private struct OwnerPetsStrip: View {
    @State private var pets: [PetDataService.Pet] = []
    private let svc = PetDataService()
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(pets) { pet in
                    VStack {
                        // Reuse the compact grid card from OwnerPetsView
                        // Wrapped to a fixed width for horizontal strip
                        PetGridCard(name: pet.name, photoURL: pet.photoURL)
                            .frame(width: 140)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .task { await reload() }
        .onAppear { Task { await reload() } }
        .onReceive(NotificationCenter.default.publisher(for: .petsDidChange)) { _ in
            Task { await reload() }
        }
    }

    @MainActor
    private func reload() async {
        do { pets = try await svc.listPets() } catch { pets = [] }
    }
}

private struct MessagesTab: View {
    @EnvironmentObject var chat: ChatService
    @EnvironmentObject var appState: AppState
    @State private var seeded: Bool = false
    @State private var showChat: Bool = false {
        didSet {
            print("showChat changed to: \(showChat)")
        }
    }
    @State private var seedText: String = ""
    @State private var selectedConversationId: String? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("Pinned") {
                    HStack {
                        Image(systemName: "pin.fill").foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("SaviPets-Admin").font(.headline)
                            Text("Contact Us - Get help instantly")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showChat = true 
                        }
                    }
                }
                Section("Conversations") {
                    ForEach(chat.conversations) { convo in
                        Button(action: { selectedConversationId = convo.id }) {
                            VStack(alignment: .leading) {
                                Text(conversationDisplayName(for: convo))
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(convo.lastMessage.isEmpty ? "No messages yet" : convo.lastMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
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
                NavigationStack { 
                    AdminInquiryChatView(
                        initialText: seedText.isEmpty ? "Hello" : seedText,
                        currentUserRole: appState.role
                    )
                    .environmentObject(chat)
                }
                .onAppear {
                    print("AdminInquiryChatView sheet appeared")
                }
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
    
    // MARK: - Helper Methods
    
    private func conversationDisplayName(for conversation: Conversation) -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return "Unknown Chat"
        }
        
        // If it's a pinned conversation, use the pinned name
        if conversation.isPinned, let pinnedName = conversation.pinnedName {
            return pinnedName
        }
        
        // Get other participants (excluding current user)
        let otherParticipants = conversation.participants.filter { $0 != currentUserId }
        
        if otherParticipants.isEmpty {
            return "Unknown Chat"
        }
        
        // Get display names for other participants
        let otherNames = otherParticipants.map { chat.displayName(for: $0) }
        
        // If it's a group chat (more than 2 participants), show "Group Chat"
        if otherParticipants.count > 1 {
            return "Group Chat"
        }
        
        // For 1-on-1 chats, show the other person's name
        let displayName = otherNames.first ?? "Unknown User"
        
        // Truncate very long names
        if displayName.count > 20 {
            return String(displayName.prefix(17)) + "..."
        }
        
        return displayName
    }
}

struct ChatSheetId: Identifiable { let id: String }

// MARK: - Owner Bookings Management View
struct OwnerBookingsView: View {
    @EnvironmentObject var serviceBookings: ServiceBookingDataService
    @State private var selectedFilter: BookingFilter = .all
    @State private var searchText: String = ""
    
    enum BookingFilter: String, CaseIterable {
        case all = "All"
        case upcoming = "Upcoming"
        case completed = "Completed"
        case cancelled = "Cancelled"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .upcoming: return "clock"
            case .completed: return "checkmark.circle"
            case .cancelled: return "xmark.circle"
            }
        }
    }
    
    private var filteredBookings: [ServiceBooking] {
        var bookings = serviceBookings.userBookings
        if !searchText.isEmpty {
            bookings = bookings.filter { booking in
                booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
                booking.pets.joined().localizedCaseInsensitiveContains(searchText) ||
                booking.specialInstructions?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        switch selectedFilter {
        case .all:
            return bookings.sorted { $0.scheduledDate > $1.scheduledDate }
        case .upcoming:
            return bookings.filter { $0.status == .pending || $0.status == .approved }
                .sorted { $0.scheduledDate < $1.scheduledDate }
        case .completed:
            return bookings.filter { $0.status == .completed }
                .sorted { $0.scheduledDate > $1.scheduledDate }
        case .cancelled:
            return bookings.filter { $0.status == .cancelled }
                .sorted { $0.scheduledDate > $1.scheduledDate }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search bookings...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Filter segmented control
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(BookingFilter.allCases, id: \.self) { filter in
                        Label(filter.rawValue, systemImage: filter.icon).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Bookings list
                if filteredBookings.isEmpty {
                    EmptyStateView(filter: selectedFilter, searchText: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                            ForEach(filteredBookings) { booking in
                                BookingDetailCard(booking: booking)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Booking Detail Card
struct BookingDetailCard: View {
    let booking: ServiceBooking
    @State private var showingDetails = false
    @State private var showingCancelConfirm = false
    @State private var showingReschedule = false
    
    private var isUpcoming: Bool {
        booking.status == .pending || booking.status == .approved
    }
    
    private var canReschedule: Bool {
        isUpcoming && booking.status == .approved
    }
    
    private var canCancel: Bool {
        isUpcoming
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content (tappable)
            Button(action: { showingDetails = true }) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header with status
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(booking.serviceType)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(formatBookingDate())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        StatusBadge(status: booking.status)
                    }
                    
                    // Service details
                    VStack(alignment: .leading, spacing: 8) {
                        if !booking.pets.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "pawprint.fill")
                                    .foregroundColor(.secondary)
                                Text(booking.pets.joined(separator: ", "))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let sitter = booking.sitterName {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                Text("Sitter: \(sitter)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let instruction = booking.specialInstructions, !instruction.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "note.text")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                                Text(instruction)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text("Duration: \(booking.duration) minutes")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Action buttons row (only for upcoming bookings)
                    if canReschedule || canCancel {
                        HStack(spacing: 12) {
                            if canReschedule {
                                Button("Reschedule") { showingReschedule = true }
                                    .foregroundColor(SPDesignSystem.Colors.primary)
                                    .buttonStyle(.borderless)
                            }
                            
                            if canCancel {
                                Button("Cancel") { showingCancelConfirm = true }
                                    .foregroundColor(.red)
                                    .buttonStyle(.borderless)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingDetails) {
            BookingDetailsSheet(booking: booking)
        }
        .sheet(isPresented: $showingCancelConfirm) {
            CancelBookingSheet(booking: booking)
        }
        .sheet(isPresented: $showingReschedule) {
            RescheduleBookingSheet(booking: booking)
        }
    }
    
    private func formatBookingDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        
        let scheduledTime = booking.scheduledTime
        if !scheduledTime.isEmpty {
            // Combine date and time string for display
            return "\(formatter.string(from: booking.scheduledDate)) at \(scheduledTime)"
        } else {
            return formatter.string(from: booking.scheduledDate)
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: ServiceBooking.BookingStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .cornerRadius(8)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {

    let filter: OwnerBookingsView.BookingFilter
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyIcon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(emptyTitle)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyIcon: String {
        if !searchText.isEmpty { return "magnifyingglass" }
        switch filter {
        case .all: return "calendar"
        case .upcoming: return "clock"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    private var emptyTitle: String {
        if !searchText.isEmpty { return "No results found" }
        switch filter {
        case .all: return "No bookings yet"
        case .upcoming: return "No upcoming bookings"
        case .completed: return "No completed bookings"
        case .cancelled: return "No cancelled bookings"
        }
    }
    
    private var emptyMessage: String {
        if !searchText.isEmpty { return "Try adjusting your search terms" }
        switch filter {
        case .all: return "Get started by booking your first service"
        case .upcoming: return "All of your approved bookings will appear here"
        case .completed: return "Completed services will show up here for your reference"
        case .cancelled: return "Cancelled bookings will be listed here"
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Booking Details Sheet (placeholder for now)
struct BookingDetailsSheet: View {
    let booking: ServiceBooking
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Booking ID: \(booking.id)")
                    Text("Service: \(booking.serviceType)")
                    Text("Status: \(booking.status.displayName)")
                    Text("Date: \(booking.scheduledDate, style: .date)")
                    Text("Pets: \(booking.pets.joined(separator: ", "))")
                    if let instructions = booking.specialInstructions {
                        Text("Instructions: \(instructions)")
                    }
                }
                .padding()
            }
            .navigationTitle("Booking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Cancel Booking Sheet (placeholder for now)
struct CancelBookingSheet: View {
    let booking: ServiceBooking
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Are you sure you want to cancel this booking?")
                    .font(.headline)
                Text("This action cannot be undone.")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Cancel Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reschedule Booking Sheet (placeholder for now)
struct RescheduleBookingSheet: View {
    let booking: ServiceBooking
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Reschedule your booking")
                    .font(.headline)
                Text("Feature coming soon!")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
            .environmentObject(appState.chatService)
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
