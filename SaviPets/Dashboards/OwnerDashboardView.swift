import SwiftUI
import OSLog
import FirebaseAuth
import FirebaseFirestore

struct OwnerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var scrollOffset: CGFloat = 0
    @State private var baseline: CGFloat? = nil
    @StateObject private var serviceBookings = ServiceBookingDataService()
    @StateObject private var paymentConfirmationService = PaymentConfirmationService()
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
            PetOwnerScheduleView()
                .environmentObject(serviceBookings)
                .tabItem { Label("Schedule", systemImage: "calendar") }
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
            .threeDButtonStyle()
            
            Button(action: { callEmergency() }) {
                SPCard { Label("Emergency", systemImage: "phone.fill").font(.headline) }
            }
            .threeDButtonStyle()
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
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
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
                HStack(spacing: 24) {
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
                .padding(.horizontal, 16)
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
    @State private var isPressed: Bool = false
    
    var body: some View {
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
        .padding(16)
        .background(
            ZStack {
                // Glass morphism background
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay for depth
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(SPDesignSystem.Colors.glassBorder.opacity(0.5), lineWidth: 0.5)
                .offset(y: 1)
        )
        // 3D Shadow effects
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .shadow(color: .white.opacity(0.5), radius: 1, x: 0, y: -1)
        // Pressed animation
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

private struct OwnerPetsStrip: View {
    @State private var pets: [PetDataService.Pet] = []
    private let svc = PetDataService()
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SPDesignSystem.Spacing.l) {
                ForEach(pets) { pet in
                    NavigationLink(destination: PetProfileView(petId: pet.id ?? "", pet: pet)) {
                        CircularPetProfile(name: pet.name, photoURL: pet.photoURL, species: pet.species)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("\(pet.name) profile")
                    .accessibilityHint("Double tap to view \(pet.name)'s profile")
                }
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
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

// MARK: - Circular Pet Profile Component
private struct CircularPetProfile: View {
    let name: String
    let photoURL: String?
    let species: String
    
    var body: some View {
        VStack(spacing: 8) {
            // Circular pet image
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                if let photoURL = photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        case .failure(_):
                            fallbackIcon
                        case .empty:
                            ProgressView()
                                .scaleEffect(0.8)
                        @unknown default:
                            fallbackIcon
                        }
                    }
                } else {
                    fallbackIcon
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            
            // Pet name
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
        .frame(width: 80)
    }
    
    private var fallbackIcon: some View {
        Group {
            switch species.lowercased() {
            case "dog":
                Image(systemName: "dog.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.6))
            case "cat":
                Image(systemName: "cat.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.6))
            case "bird":
                Image(systemName: "bird.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.6))
            case "critter", "hamster", "mouse", "rat":
                Image(systemName: "hare.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.6))
            case "fish":
                Image(systemName: "drop.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue.opacity(0.6))
            case "rabbit":
                Image(systemName: "oval.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray.opacity(0.6))
            case "reptile", "lizard", "snake":
                Image(systemName: "oval")
                    .font(.system(size: 24))
                    .foregroundColor(.green.opacity(0.6))
            default:
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
    }
}

private struct MessagesTab: View {
    @EnvironmentObject var chat: ChatService
    @EnvironmentObject var appState: AppState
    @State private var showChat: Bool = false
    @State private var seedText: String = ""
    @State private var selectedConversationId: String? = nil
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar with modern styling
                if !chat.conversations.isEmpty {
                    SearchBarModern(text: $searchText, placeholder: "Search conversations...")
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                }
                
                List {
                    // Pinned section with enhanced styling
                    Section {
                        PinnedConversationCard(
                            title: "SaviPets Support",
                            subtitle: "Get help instantly • Available 24/7",
                            icon: "headphones.circle.fill",
                            iconColor: .blue,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showChat = true
                                }
                            }
                        )
                    } header: {
                        Text("Quick Access")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(nil)
                    }
                    
                    // Active conversations
                    if !filteredConversations.isEmpty {
                        Section {
                            ForEach(filteredConversations) { convo in
                                ConversationRow(
                                    conversation: convo,
                                    currentUserId: Auth.auth().currentUser?.uid ?? "",
                                    displayName: conversationDisplayName(for: convo),
                                    chat: chat
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedConversationId = convo.id
                                }
                            }
                        } header: {
                            Text("Messages")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .onReceive(NotificationCenter.default.publisher(for: .openMessagesTab)) { notif in
                if let text = notif.userInfo?["seed"] as? String {
                    seedText = text
                    showChat = true
                }
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
            }
            .sheet(item: Binding(
                get: { selectedConversationId.map { ChatSheetId(id: $0) } },
                set: { selectedConversationId = $0?.id }
            )) { item in
                ConversationChatView(conversationId: item.id)
                    .environmentObject(chat)
            }
            .overlay {
                if filteredConversations.isEmpty && !searchText.isEmpty {
                    EmptySearchView(searchText: searchText)
                } else if chat.conversations.isEmpty {
                    EmptyMessagesView()
                }
            }
        }
    }
    
    private var filteredConversations: [Conversation] {
        let sitterConvos = sitterConversations
        guard !searchText.isEmpty else { return sitterConvos }
        
        return sitterConvos.filter { convo in
            let displayName = conversationDisplayName(for: convo)
            return displayName.localizedCaseInsensitiveContains(searchText) ||
                   convo.lastMessage.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var sitterConversations: [Conversation] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }
        
        return chat.conversations.filter { conversation in
            if conversation.isPinned { return false }
            _ = conversation.participants.filter { $0 != currentUserId }  // Swift 6: unused value fix
            let displayName = conversationDisplayName(for: conversation)
            return !displayName.contains("Admin") && !displayName.contains("SaviPets")
        }
    }
    
    private func conversationDisplayName(for conversation: Conversation) -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return "Unknown Chat"
        }
        
        if conversation.isPinned, let pinnedName = conversation.pinnedName {
            return pinnedName
        }
        
        let otherParticipants = conversation.participants.filter { $0 != currentUserId }
        if otherParticipants.isEmpty { return "Unknown Chat" }
        
        let otherNames = otherParticipants.map { participantId in
            let name = chat.displayName(for: participantId)
            // Replace admin names with "Admin"
            if name.contains("admin") || name.contains("Admin") || name.contains("SaviPets") {
                return "Admin"
            }
            return name
        }
        
        if otherParticipants.count > 1 { return "Group Chat" }
        
        let displayName = otherNames.first ?? "Unknown User"
        return displayName.count > 20 ? String(displayName.prefix(17)) + "..." : displayName
    }
}

// MARK: - Modern Search Bar
private struct SearchBarModern: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .accentColor : .secondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .font(.body)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)
    }
}

// MARK: - Pinned Conversation Card
private struct PinnedConversationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Conversation Row
private struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: String
    let displayName: String
    let chat: ChatService
    
    @State private var isPressed = false
    
    private var timeAgo: String {
        let lastMessageTime = conversation.lastMessageAt
        
        let now = Date()
        let interval = now.timeIntervalSince(lastMessageTime)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: lastMessageTime)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView(name: displayName, size: 52)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !timeAgo.isEmpty {
                        Text(timeAgo)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(conversation.lastMessage.isEmpty ? "No messages yet" : conversation.lastMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Avatar View
private struct AvatarView: View {
    let name: String
    let size: CGFloat
    
    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
    
    private var backgroundColor: Color {
        // Special handling for Admin
        if name == "Admin" {
            return .blue
        }
        
        let hash = name.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo, .teal]
        return colors[abs(hash) % colors.count]
    }
    
    private var displayInitials: String {
        // Show "A" for Admin instead of initials
        if name == "Admin" {
            return "A"
        }
        return initials
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor.opacity(0.2))
            
            Text(displayInitials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(backgroundColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Empty States
private struct EmptyMessagesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No Messages Yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Start a conversation with your pet sitter or reach out to support")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

private struct EmptySearchView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("No conversations found for '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

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
                BookingsSearchBar(text: $searchText, placeholder: "Search bookings...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)  // ✅ Added space between search and filters
                
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
                    BookingsEmptyStateView(filter: selectedFilter, searchText: searchText)
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
    @State private var isPressed: Bool = false
    
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
                .padding(16)
                .background(
                    ZStack {
                        // Glass morphism background
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        // Subtle gradient overlay for depth
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(UIColor.systemGray5).opacity(0.5), lineWidth: 0.5)
                        .offset(y: 1)
                )
                // 3D Shadow effects for depth
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                .shadow(color: .white.opacity(0.5), radius: 1, x: 0, y: -1)  // Top highlight
            }
            .buttonStyle(PlainButtonStyle())
            // Pressed state animation
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.0, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
        }
        .sheet(isPresented: $showingDetails) {
            BookingDetailsSheet(
                booking: booking,
                clientName: nil, // Owner dashboard doesn't have client name context
                sitterName: booking.sitterName
            )
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


// MARK: - Empty State View
struct BookingsEmptyStateView: View {

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
struct BookingsSearchBar: View {
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


// MARK: - Cancel Booking Sheet
struct CancelBookingSheet: View {
    let booking: ServiceBooking
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var serviceBookings: ServiceBookingDataService
    
    @State private var cancelReason: String = ""
    @State private var isCanceling: Bool = false
    @State private var cancelError: String? = nil
    @State private var showRecurringOptions: Bool = false
    @State private var cancelType: CancelType = .singleVisit
    
    enum CancelType {
        case singleVisit
        case allFutureVisits
    }
    
    private var hoursUntilVisit: Double {
        booking.scheduledDate.timeIntervalSince(Date()) / 3600
    }
    
    private var refundInfo: String {
        if hoursUntilVisit >= (7 * 24) {
            return "✅ Full refund (a week or more notice)"
        } else if hoursUntilVisit >= 24 {
            return "⚠️ 50% refund (24 hours to 7 days notice)"
        } else if hoursUntilVisit >= 0 {
            return "❌ No refund (less than 24 hours notice)"
        } else {
            return "❌ No refund (visit already started)"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Warning header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("Cancel Booking")
                                .font(.title2)
                                .bold()
                        }
                        
                        Text("Are you sure you want to cancel this booking?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Booking details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Booking Details")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(icon: "calendar", label: "Service", value: booking.serviceType)
                            DetailRow(icon: "clock", label: "Date", value: "\(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted)) at \(booking.scheduledTime)")
                            if !booking.pets.isEmpty {
                                DetailRow(icon: "pawprint.fill", label: "Pets", value: booking.pets.joined(separator: ", "))
                            }
                            if let sitter = booking.sitterName {
                                DetailRow(icon: "person.fill", label: "Sitter", value: sitter)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                    
                    // Refund policy information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Refund Policy")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: hoursUntilVisit >= (7 * 24) ? "checkmark.circle.fill" : (hoursUntilVisit >= 24 ? "exclamationmark.circle.fill" : "xmark.circle.fill"))
                                .foregroundColor(hoursUntilVisit >= (7 * 24) ? .green : (hoursUntilVisit >= 24 ? .orange : .red))
                            Text(refundInfo)
                                .font(.subheadline)
                        }
                        
                        Text("Time until visit: \(Int(max(hoursUntilVisit, 0))) hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                    
                    // Recurring series options
                    if booking.isRecurring {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recurring Booking Options")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                Button {
                                    cancelType = .singleVisit
                                } label: {
                                    HStack {
                                        Image(systemName: cancelType == .singleVisit ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(cancelType == .singleVisit ? .blue : .gray)
                                        VStack(alignment: .leading) {
                                            Text("Cancel this visit only")
                                                .foregroundColor(.primary)
                                            if let visitNum = booking.visitNumber {
                                                Text("Visit #\(visitNum) of series")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    cancelType = .allFutureVisits
                                } label: {
                                    HStack {
                                        Image(systemName: cancelType == .allFutureVisits ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(cancelType == .allFutureVisits ? .blue : .gray)
                                        VStack(alignment: .leading) {
                                            Text("Cancel all future visits")
                                                .foregroundColor(.primary)
                                            Text("This will cancel the entire series")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                    }
                    
                    // Cancellation reason
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason for cancellation (optional)")
                            .font(.headline)
                        
                        TextField("e.g., Change of plans, emergency, etc.", text: $cancelReason, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                    
                    // Error message
                    if let error = cancelError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                    
                    Spacer()
                    
                    // Cancel button
                    Button(role: .destructive) {
                        Task { await performCancellation() }
                    } label: {
                        HStack {
                            if isCanceling {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isCanceling ? "Canceling..." : "Confirm Cancellation")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .background(Color.red.opacity(isCanceling ? 0.5 : 1.0))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isCanceling)
                }
                .padding()
            }
            .navigationTitle("Cancel Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .disabled(isCanceling)
                }
            }
        }
        .interactiveDismissDisabled(isCanceling)
    }
    
    @MainActor
    private func performCancellation() async {
        isCanceling = true
        cancelError = nil
        
        do {
            if booking.isRecurring && cancelType == .allFutureVisits {
                // Cancel entire series
                guard let seriesId = booking.recurringSeriesId else {
                    throw NSError(domain: "CancelBooking", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid recurring series"])
                }
                
                let canceledCount = try await serviceBookings.cancelRecurringSeries(
                    seriesId: seriesId,
                    cancelFutureOnly: true
                )
                
                AppLogger.ui.info("Canceled \(canceledCount) future visits in series")
                
            } else {
                // Cancel single booking
                let result = try await serviceBookings.cancelBooking(
                    bookingId: booking.id,
                    reason: cancelReason
                )
                
                AppLogger.ui.info("Booking canceled: \(result.refundMessage)")
            }
            
            // Success
            await MainActor.run {
                isCanceling = false
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                cancelError = ErrorMapper.userFriendlyMessage(for: error)
                isCanceling = false
            }
            AppLogger.ui.error("Cancellation failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Detail Row Helper
private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
            Spacer()
        }
        .font(.subheadline)
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
