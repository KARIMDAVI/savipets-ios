import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import EventKit
import EventKitUI
import Combine

/// Main calendar interface for pet owners to manage their bookings
struct PetOwnerScheduleView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var serviceBookings = ServiceBookingDataService()
    @StateObject private var calendarSync = CalendarSyncService()
    
    // Calendar state
    @State private var currentDate = Date()
    @State private var selectedDate: Date?
    @State private var showingMonth = Date()
    
    // UI state
    @State private var showingBookingDetail: Bool = false
    @State private var selectedBooking: ServiceBooking?
    @State private var showingRescheduleSheet: Bool = false
    @State private var showingEditSheet: Bool = false
    @State private var showingCancelSheet: Bool = false
    @State private var showingRecurringSeries: Bool = false
    
    // Enhanced filter state
    @State private var selectedFilter: BookingFilter = .all
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var selectedPetFilter: String? = nil
    @State private var selectedServiceFilter: String? = nil
    @State private var showingAdvancedFilters = false
    
    // Smart features
    @State private var quickActions: [QuickAction] = []
    @State private var predictiveSearchSuggestions: [String] = []
    @State private var showingQuickActions = false
    @State private var bookingInsights: [BookingInsight] = []
    
    // Loading states
    @State private var isLoading = false
    @State private var syncStatus: CalendarSyncService.SyncStatus = .idle
    
    // Accessibility
    @State private var isAccessibilityEnabled = false
    @FocusState private var isSearchFocused: Bool
    
    private var isSyncing: Bool {
        switch syncStatus {
        case .syncing:
            return true
        default:
            return false
        }
    }
    
    // Navigation
    @State private var navigateToBooking = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    enum BookingFilter: String, CaseIterable {
        case all = "All"
        case upcoming = "Upcoming"
        case past = "Past"
        case recurring = "Recurring"
        case pending = "Pending"
        case completed = "Completed"
        case cancelled = "Cancelled"
        
        var systemImage: String {
            switch self {
            case .all: return "calendar"
            case .upcoming: return "clock"
            case .past: return "checkmark.circle"
            case .recurring: return "repeat"
            case .pending: return "hourglass"
            case .completed: return "checkmark.circle.fill"
            case .cancelled: return "xmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .primary
            case .upcoming: return .blue
            case .past: return .gray
            case .recurring: return .purple
            case .pending: return .orange
            case .completed: return .green
            case .cancelled: return .red
            }
        }
    }
    
    // MARK: - Smart Features Models
    struct QuickAction: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let action: () -> Void
        
        static func == (lhs: QuickAction, rhs: QuickAction) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    struct BookingInsight: Identifiable {
        let id = UUID()
        let type: InsightType
        let title: String
        let message: String
        let actionTitle: String?
        let action: (() -> Void)?
        
        enum InsightType {
            case upcoming, reminder, suggestion, warning
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Enhanced Quick Actions Toolbar
                    enhancedQuickActionsToolbar
                    
                    // Smart Insights Section
                    if !bookingInsights.isEmpty {
                        smartInsightsSection
                    }
                    
                    // Enhanced Search Bar
                    if showingSearch {
                        enhancedSearchBar
                    }
                    
                    // Monthly Calendar Grid with enhanced UX
                    enhancedMonthlyCalendarGrid
                    
                    Divider()
                        .padding(.horizontal, SPDesignSystem.Spacing.m)
                    
                    // Enhanced Bookings List with smart filtering
                    enhancedUpcomingBookingsList
                }
            }
            .navigationTitle("My Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { navigateToBooking = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                    }
                }
            }
            .sheet(isPresented: $showingBookingDetail) {
                if let booking = selectedBooking {
                    BookingDetailModal(
                        booking: booking,
                        onReschedule: { selectedBooking = booking; showingRescheduleSheet = true },
                        onEdit: { selectedBooking = booking; showingEditSheet = true },
                        onCancel: { selectedBooking = booking; showingCancelSheet = true },
                        onManageRecurring: { selectedBooking = booking; showingRecurringSeries = true }
                    )
                }
            }
            .sheet(isPresented: $showingRescheduleSheet) {
                if let booking = selectedBooking {
                    RescheduleSheet(booking: booking) { success in
                        if success {
                            showingRescheduleSheet = false
                            selectedBooking = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let booking = selectedBooking {
                    EditBookingSheet(booking: booking) { success in
                        if success {
                            showingEditSheet = false
                            selectedBooking = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCancelSheet) {
                if let booking = selectedBooking {
                    CancelConfirmationSheet(booking: booking) { success in
                        if success {
                            showingCancelSheet = false
                            selectedBooking = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showingRecurringSeries) {
                if let booking = selectedBooking {
                    RecurringSeriesView(booking: booking)
                }
            }
            .navigationDestination(isPresented: $navigateToBooking) {
                BookServiceView()
            }
            .task {
                await loadBookings()
                await checkCalendarAccess()
                await setupSmartFeatures()
                setupAccessibility()
            }
            .onChange(of: searchText) { newValue in
                Task {
                    await updatePredictiveSearch(newValue)
                }
            }
            .onChange(of: selectedDate) { newValue in
                generateBookingInsights()
            }
        }
    }
    
    // MARK: - Enhanced Quick Actions Toolbar
    
    private var enhancedQuickActionsToolbar: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            // Top row - Main actions
            HStack(spacing: SPDesignSystem.Spacing.s) {
                // Smart Filter Button with visual indicator
                Menu {
                    ForEach(BookingFilter.allCases, id: \.self) { filter in
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filter
                            }
                        }) {
                            Label(filter.rawValue, systemImage: filter.systemImage)
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button("Advanced Filters") {
                        showingAdvancedFilters.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedFilter.systemImage)
                            .foregroundColor(selectedFilter.color)
                        Text(selectedFilter.rawValue)
                            .font(SPDesignSystem.Typography.callout())
                            .fontWeight(.medium)
                        
                        // Filter indicator
                        if hasActiveFilters {
                            Circle()
                                .fill(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.horizontal, SPDesignSystem.Spacing.m)
                    .padding(.vertical, SPDesignSystem.Spacing.s)
                    .background(SPDesignSystem.Colors.surface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedFilter.color.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Spacer()
                
                // Quick Actions Menu
                Menu {
                    ForEach(quickActions, id: \.id) { action in
                        Button(action: action.action) {
                            Label(action.title, systemImage: action.icon)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .font(.title2)
                }
                
                // Search Button
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSearch.toggle()
                        if showingSearch {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSearchFocused = true
                            }
                        }
                    }
                }) {
                    Image(systemName: showingSearch ? "xmark.circle.fill" : "magnifyingglass.circle.fill")
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .font(.title2)
                }
                
                // Sync Button
                Button {
                    Task {
                        await syncWithCalendar()
                    }
                } label: {
                    Image(systemName: isSyncing ? "arrow.clockwise" : "calendar.badge.plus")
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .font(.title2)
                        .rotationEffect(.degrees(isSyncing ? 360 : 0))
                        .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
                }
                .disabled(isSyncing)
            }
            
            // Advanced Filters Row (when active)
            if showingAdvancedFilters {
                advancedFiltersRow
            }
        }
        .padding(.horizontal, SPDesignSystem.Spacing.m)
        .padding(.vertical, SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.background(scheme: colorScheme))
    }
    
    // MARK: - Enhanced Search Bar with Predictive Search
    
    private var enhancedSearchBar: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack(spacing: SPDesignSystem.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search bookings, pets, services...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchText = ""
                            predictiveSearchSuggestions = []
                        }
                    }
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                }
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
            .padding(.vertical, SPDesignSystem.Spacing.s)
            .background(SPDesignSystem.Colors.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSearchFocused ? SPDesignSystem.Colors.primaryAdjusted(colorScheme) : Color.clear, lineWidth: 2)
            )
            
            // Predictive Search Suggestions
            if !predictiveSearchSuggestions.isEmpty {
                LazyVStack(spacing: SPDesignSystem.Spacing.xs) {
                    ForEach(predictiveSearchSuggestions, id: \.self) { suggestion in
                        Button(action: {
                            searchText = suggestion
                            performSearch()
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                Text(suggestion)
                                    .font(SPDesignSystem.Typography.footnote())
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, SPDesignSystem.Spacing.m)
                            .padding(.vertical, SPDesignSystem.Spacing.xs)
                            .background(SPDesignSystem.Colors.surface(colorScheme).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, SPDesignSystem.Spacing.m)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Advanced Filters Row
    
    private var advancedFiltersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SPDesignSystem.Spacing.s) {
                // Pet Filter
                Menu {
                    ForEach(availablePets, id: \.self) { pet in
                        Button(pet) {
                            selectedPetFilter = pet
                        }
                    }
                    if selectedPetFilter != nil {
                        Divider()
                        Button("Clear Pet Filter") {
                            selectedPetFilter = nil
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                        Text(selectedPetFilter ?? "All Pets")
                            .font(SPDesignSystem.Typography.footnote())
                        if selectedPetFilter != nil {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, SPDesignSystem.Spacing.s)
                    .padding(.vertical, SPDesignSystem.Spacing.xs)
                    .background(selectedPetFilter != nil ? SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.2) : SPDesignSystem.Colors.surface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Service Filter
                Menu {
                    ForEach(availableServices, id: \.self) { service in
                        Button(service) {
                            selectedServiceFilter = service
                        }
                    }
                    if selectedServiceFilter != nil {
                        Divider()
                        Button("Clear Service Filter") {
                            selectedServiceFilter = nil
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(selectedServiceFilter ?? "All Services")
                            .font(SPDesignSystem.Typography.footnote())
                        if selectedServiceFilter != nil {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, SPDesignSystem.Spacing.s)
                    .padding(.vertical, SPDesignSystem.Spacing.xs)
                    .background(selectedServiceFilter != nil ? SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.2) : SPDesignSystem.Colors.surface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Smart Insights Section
    
    private var smartInsightsSection: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Text("Smart Insights")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Spacer()
                
                Button("Dismiss All") {
                    bookingInsights.removeAll()
                }
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: SPDesignSystem.Spacing.xs) {
                ForEach(bookingInsights) { insight in
                    SmartInsightCard(insight: insight) {
                        if let action = insight.action {
                            action()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, SPDesignSystem.Spacing.m)
        .padding(.vertical, SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(colorScheme).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, SPDesignSystem.Spacing.m)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Enhanced Monthly Calendar Grid
    
    private var enhancedMonthlyCalendarGrid: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            // Enhanced Month Header with Navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 0.1), value: showingMonth)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(monthFormatter.string(from: showingMonth))
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                    
                    Text("\(bookingsInMonth.count) bookings")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 0.1), value: showingMonth)
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
            
            // Enhanced Today Button with animation
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showingMonth = Date()
                    selectedDate = Date()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                    Text("Today")
                }
                .font(SPDesignSystem.Typography.callout())
                .fontWeight(.medium)
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                .padding(.horizontal, SPDesignSystem.Spacing.m)
                .padding(.vertical, SPDesignSystem.Spacing.xs)
                .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Enhanced Calendar Grid with better touch targets
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                // Enhanced Day headers
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(SPDesignSystem.Typography.footnote())
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(SPDesignSystem.Colors.surface(colorScheme).opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                // Enhanced Calendar days with better touch targets
                ForEach(daysInMonth, id: \.self) { date in
                    EnhancedCalendarDayView(
                        date: date,
                        bookings: bookingsForDate(date),
                        isSelected: selectedDate == date,
                        isToday: Calendar.current.isDateInToday(date),
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: showingMonth, toGranularity: .month)
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedDate = date
                            if !bookingsForDate(date).isEmpty {
                                selectedBooking = bookingsForDate(date).first
                                showingBookingDetail = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
        }
        .padding(.vertical, SPDesignSystem.Spacing.m)
    }
    
    // MARK: - Enhanced Upcoming Bookings List
    
    private var enhancedUpcomingBookingsList: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Text("Upcoming Bookings")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Spacer()
                
                Text("Next 30 days")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
            
            if enhancedFilteredBookings.isEmpty {
                SPEmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No bookings found",
                    message: searchText.isEmpty ? "You don't have any bookings in this time period." : "No bookings match your search.",
                    actionTitle: "Book a Service",
                    action: { navigateToBooking = true }
                )
                .padding(.vertical, SPDesignSystem.Spacing.xl)
            } else {
                LazyVStack(spacing: SPDesignSystem.Spacing.s) {
                    ForEach(enhancedFilteredBookings) { booking in
                        SwipeableBookingCard(
                            booking: booking,
                            clientName: nil,
                            sitterName: booking.sitterName,
                            onReschedule: { _ in
                                selectedBooking = booking
                                showingRescheduleSheet = true
                            },
                            onCancel: { _ in
                                selectedBooking = booking
                                showingCancelSheet = true
                            },
                            onViewDetails: { _ in
                                selectedBooking = booking
                                showingBookingDetail = true
                            }
                        )
                        .padding(.horizontal, SPDesignSystem.Spacing.m)
                    }
                }
                .padding(.vertical, SPDesignSystem.Spacing.s)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var daysInMonth: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: showingMonth)?.start ?? showingMonth
        let range = calendar.range(of: .day, in: .month, for: showingMonth) ?? 1..<32
        
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
        
        // Add padding days from previous/next month
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let paddingDays = firstWeekday - 1
        
        var allDays: [Date] = []
        
        // Previous month days
        for i in 0..<paddingDays {
            if let date = calendar.date(byAdding: .day, value: -(paddingDays - i), to: startOfMonth) {
                allDays.append(date)
            }
        }
        
        // Current month days
        allDays.append(contentsOf: days)
        
        // Next month days to fill the grid
        let remainingDays = 42 - allDays.count // 6 weeks * 7 days
        for i in 0..<remainingDays {
            if let date = calendar.date(byAdding: .day, value: i + 1, to: days.last ?? startOfMonth) {
                allDays.append(date)
            }
        }
        
        return allDays
    }
    
    private var filteredBookings: [ServiceBooking] {
        var bookings = serviceBookings.userBookings
        
        // Apply search filter
        if !searchText.isEmpty {
            bookings = bookings.filter { booking in
                booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
                booking.pets.joined().localizedCaseInsensitiveContains(searchText) ||
                (booking.sitterName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .upcoming:
            bookings = bookings.filter { booking in
                booking.scheduledDate > Date() && booking.status != .completed
            }
        case .past:
            bookings = bookings.filter { booking in
                booking.scheduledDate < Date() || booking.status == .completed
            }
        case .recurring:
            bookings = bookings.filter { booking in
                booking.isRecurring
            }
        case .pending:
            bookings = bookings.filter { $0.status == .pending }
        case .completed:
            bookings = bookings.filter { $0.status == .completed }
        case .cancelled:
            bookings = bookings.filter { $0.status == .cancelled }
        }
        
        // Sort by date
        return bookings.sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    // MARK: - Enhanced Computed Properties
    
    private var enhancedFilteredBookings: [ServiceBooking] {
        var bookings = filteredBookings
        
        // Apply pet filter
        if let petFilter = selectedPetFilter {
            bookings = bookings.filter { booking in
                booking.pets.contains(petFilter)
            }
        }
        
        // Apply service filter
        if let serviceFilter = selectedServiceFilter {
            bookings = bookings.filter { booking in
                booking.serviceType.localizedCaseInsensitiveContains(serviceFilter)
            }
        }
        
        return bookings
    }
    
    private var hasActiveFilters: Bool {
        selectedFilter != .all || 
        selectedPetFilter != nil || 
        selectedServiceFilter != nil || 
        !searchText.isEmpty
    }
    
    private var availablePets: [String] {
        Set(serviceBookings.userBookings.flatMap { $0.pets }).sorted()
    }
    
    private var availableServices: [String] {
        Set(serviceBookings.userBookings.map { $0.serviceType }).sorted()
    }
    
    private var bookingsInMonth: [ServiceBooking] {
        let calendar = Calendar.current
        return serviceBookings.userBookings.filter { booking in
            calendar.isDate(booking.scheduledDate, equalTo: showingMonth, toGranularity: .month)
        }
    }
    
    private var upcomingBookingsCount: Int {
        serviceBookings.userBookings.filter { booking in
            booking.scheduledDate > Date() && booking.status != .completed
        }.count
    }
    
    private var completedBookingsCount: Int {
        serviceBookings.userBookings.filter { $0.status == .completed }.count
    }
    
    
    private func bookingsForDate(_ date: Date) -> [ServiceBooking] {
        let calendar = Calendar.current
        return serviceBookings.userBookings.filter { booking in
            calendar.isDate(booking.scheduledDate, inSameDayAs: date)
        }
    }
    
    // MARK: - Actions
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingMonth = Calendar.current.date(byAdding: .month, value: -1, to: showingMonth) ?? showingMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingMonth = Calendar.current.date(byAdding: .month, value: 1, to: showingMonth) ?? showingMonth
        }
    }
    
    private func loadBookings() async {
        isLoading = true
        if let userId = Auth.auth().currentUser?.uid {
            serviceBookings.listenToUserBookings(userId: userId)
        }
        isLoading = false
    }
    
    private func checkCalendarAccess() async {
        _ = await calendarSync.requestCalendarAccess()
    }
    
    private func syncWithCalendar() async {
        syncStatus = .syncing
        let result = await calendarSync.syncAllBookings(serviceBookings.userBookings)
        
        switch result {
        case .success:
            syncStatus = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                syncStatus = .idle
            }
        case .failure:
            syncStatus = .error("Failed to sync")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                syncStatus = .idle
            }
        }
    }
    
    // MARK: - Enhanced Smart Features
    
    private func setupSmartFeatures() async {
        await MainActor.run {
            quickActions = generateQuickActions()
            generateBookingInsights()
        }
    }
    
    private func generateQuickActions() -> [QuickAction] {
        var actions: [QuickAction] = []
        
        // Book new service
        actions.append(QuickAction(
            title: "Book Service",
            subtitle: "Schedule a new visit",
            icon: "plus.circle.fill",
            color: .blue,
            action: { navigateToBooking = true }
        ))
        
        // Quick walk booking
        actions.append(QuickAction(
            title: "Quick Walk",
            subtitle: "30-minute dog walk",
            icon: "figure.walk",
            color: .green,
            action: { 
                // Navigate to booking with pre-selected service
                navigateToBooking = true
            }
        ))
        
        // View calendar
        actions.append(QuickAction(
            title: "View Calendar",
            subtitle: "See full month view",
            icon: "calendar",
            color: .orange,
            action: { 
                selectedDate = Date()
                showingMonth = Date()
            }
        ))
        
        // Sync with calendar
        actions.append(QuickAction(
            title: "Sync Calendar",
            subtitle: "Update external calendars",
            icon: "arrow.clockwise",
            color: .purple,
            action: { 
                Task { await syncWithCalendar() }
            }
        ))
        
        return actions
    }
    
    private func generateBookingInsights() {
        var insights: [BookingInsight] = []
        
        // Upcoming booking reminders
        let upcomingBookings = serviceBookings.userBookings.filter { booking in
            booking.scheduledDate > Date() && 
            booking.scheduledDate < Date().addingTimeInterval(24 * 60 * 60) &&
            booking.status == .approved
        }
        
        if !upcomingBookings.isEmpty {
            insights.append(BookingInsight(
                type: .reminder,
                title: "Upcoming Visits",
                message: "You have \(upcomingBookings.count) visit(s) tomorrow",
                actionTitle: "View Details",
                action: { navigateToBooking = true }
            ))
        }
        
        // Pending approvals
        let pendingBookings = serviceBookings.userBookings.filter { $0.status == .pending }
        if !pendingBookings.isEmpty {
            insights.append(BookingInsight(
                type: .warning,
                title: "Pending Approvals",
                message: "\(pendingBookings.count) booking(s) waiting for approval",
                actionTitle: "Check Status",
                action: { selectedFilter = .pending }
            ))
        }
        
        bookingInsights = insights
    }
    
    private func updatePredictiveSearch(_ searchText: String) async {
        guard !searchText.isEmpty else {
            await MainActor.run {
                predictiveSearchSuggestions = []
            }
            return
        }
        
        // Generate suggestions based on existing bookings
        var allSuggestions: [String] = []
        
        // Add service types
        allSuggestions.append(contentsOf: ["Dog Walking", "Pet Sitting", "Drop-in Visit"])
        
        // Add pet names
        allSuggestions.append(contentsOf: availablePets)
        
        // Add sitter names
        allSuggestions.append(contentsOf: serviceBookings.userBookings.compactMap { $0.sitterName })
        
        let suggestions = Array(Set(allSuggestions))
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .prefix(5)
        
        await MainActor.run {
            predictiveSearchSuggestions = Array(suggestions)
        }
    }
    
    private func performSearch() {
        // Search is handled by the computed property
        // This method can be used for analytics or additional logic
        isSearchFocused = false
    }
    
    private func clearAllFilters() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedFilter = .all
            selectedPetFilter = nil
            selectedServiceFilter = nil
            searchText = ""
            predictiveSearchSuggestions = []
        }
    }
    
    private func handleQuickAction(_ action: String, for booking: ServiceBooking) {
        switch action {
        case "reschedule":
            selectedBooking = booking
            showingRescheduleSheet = true
        case "cancel":
            selectedBooking = booking
            showingCancelSheet = true
        case "view":
            selectedBooking = booking
            showingBookingDetail = true
        default:
            break
        }
    }
    
    private func getEmptyStateTitle() -> String {
        if hasActiveFilters {
            return "No matching bookings"
        } else {
            return "No bookings found"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        if hasActiveFilters {
            return "Try adjusting your filters or search terms."
        } else {
            return "You don't have any bookings yet. Book your first service to get started!"
        }
    }
    
    private func setupAccessibility() {
        isAccessibilityEnabled = UIAccessibility.isVoiceOverRunning
    }
}

// MARK: - Calendar Day View

private struct CalendarDayView: View {
    let date: Date
    let bookings: [ServiceBooking]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(isCurrentMonth ? .primary : .secondary)
                
                // Booking indicators
                if !bookings.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(bookingIndicators, id: \.self) { indicator in
                            Circle()
                                .fill(indicator.color)
                                .frame(width: 6, height: 6)
                        }
                    }
                    
                    if bookings.count > 3 {
                        Text("+\(bookings.count - 3)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 40, height: 40)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return SPDesignSystem.Colors.primaryAdjusted(colorScheme)
        } else if isToday {
            return SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.2)
        } else {
            return Color.clear
        }
    }
    
    private var bookingIndicators: [BookingIndicator] {
        let uniqueStatuses = Set(bookings.map { $0.status })
        return uniqueStatuses.compactMap { status in
            BookingIndicator(status: status)
        }.prefix(3).map { $0 }
    }
}

private struct BookingIndicator: Hashable {
    let status: ServiceBooking.BookingStatus
    let color: Color
    
    init(status: ServiceBooking.BookingStatus) {
        self.status = status
        switch status {
        case .pending:
            self.color = .orange
        case .approved, .inAdventure:
            self.color = .green
        case .completed:
            self.color = .blue
        case .cancelled:
            self.color = .gray
        }
    }
}

// MARK: - Enhanced Calendar Day View

private struct EnhancedCalendarDayView: View {
    let date: Date
    let bookings: [ServiceBooking]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(textColor)
                
                // Enhanced booking indicators with better visual hierarchy
                if !bookings.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(bookingIndicators.prefix(2), id: \.self) { indicator in
                            Circle()
                                .fill(indicator.color)
                                .frame(width: 6, height: 6)
                        }
                        
                        if bookings.count > 2 {
                            Text("+\(bookings.count - 2)")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(minWidth: 40, minHeight: 40)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return SPDesignSystem.Colors.primaryAdjusted(colorScheme)
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return SPDesignSystem.Colors.primaryAdjusted(colorScheme)
        } else if isToday {
            return SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.15)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return SPDesignSystem.Colors.primaryAdjusted(colorScheme)
        } else if isToday {
            return SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected || isToday ? 1 : 0
    }
    
    private var bookingIndicators: [BookingIndicator] {
        let uniqueStatuses = Set(bookings.map { $0.status })
        return uniqueStatuses.compactMap { status in
            BookingIndicator(status: status)
        }
    }
    
    private var accessibilityLabel: String {
        let dayNumber = calendar.component(.day, from: date)
        let monthName = DateFormatter().monthSymbols[calendar.component(.month, from: date) - 1]
        let bookingCount = bookings.count
        
        var label = "\(monthName) \(dayNumber)"
        if !isCurrentMonth {
            label += ", different month"
        }
        if isToday {
            label += ", today"
        }
        if bookingCount > 0 {
            label += ", \(bookingCount) booking\(bookingCount == 1 ? "" : "s")"
        }
        return label
    }
    
    private var accessibilityHint: String {
        if bookings.isEmpty {
            return "No bookings on this date"
        } else {
            return "Tap to view \(bookings.count) booking\(bookings.count == 1 ? "" : "s")"
        }
    }
}

// MARK: - Smart Insight Card

private struct SmartInsightCard: View {
    let insight: PetOwnerScheduleView.BookingInsight
    let onAction: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            // Icon
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title2)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(SPDesignSystem.Typography.callout())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(insight.message)
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Action button
            if let actionTitle = insight.actionTitle {
                Button(actionTitle, action: onAction)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.medium)
                    .foregroundColor(iconColor)
                    .padding(.horizontal, SPDesignSystem.Spacing.s)
                    .padding(.vertical, SPDesignSystem.Spacing.xs)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(iconColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var iconName: String {
        switch insight.type {
        case .upcoming:
            return "clock.fill"
        case .reminder:
            return "bell.fill"
        case .suggestion:
            return "lightbulb.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch insight.type {
        case .upcoming:
            return .blue
        case .reminder:
            return .orange
        case .suggestion:
            return .green
        case .warning:
            return .red
        }
    }
}

// MARK: - Smart Empty State View

private struct SmartEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.6))
            
            VStack(spacing: SPDesignSystem.Spacing.xs) {
                Text(title)
                    .font(SPDesignSystem.Typography.heading3())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(SPDesignSystem.Typography.bodyMedium())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button(actionTitle, action: action)
                .font(SPDesignSystem.Typography.callout())
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, SPDesignSystem.Spacing.l)
                .padding(.vertical, SPDesignSystem.Spacing.s)
                .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(SPDesignSystem.Spacing.xl)
    }
}

// MARK: - Enhanced Swipeable Booking Card (Placeholder)

private struct EnhancedSwipeableBookingCard: View {
    let booking: ServiceBooking
    let clientName: String?
    let sitterName: String?
    let onReschedule: (ServiceBooking) -> Void
    let onCancel: (ServiceBooking) -> Void
    let onViewDetails: (ServiceBooking) -> Void
    let onQuickAction: (String) -> Void
    
    var body: some View {
        // For now, use the existing SwipeableBookingCard
        // This can be enhanced later with additional features
        SwipeableBookingCard(
            booking: booking,
            clientName: clientName,
            sitterName: sitterName,
            onReschedule: onReschedule,
            onCancel: onCancel,
            onViewDetails: onViewDetails
        )
    }
}

// MARK: - Preview

#Preview {
    PetOwnerScheduleView()
        .environmentObject(AppState())
}
