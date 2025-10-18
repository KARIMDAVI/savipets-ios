import SwiftUI
import OSLog
import FirebaseFirestore
import FirebaseAuth
import MapKit
import Combine
import FirebaseCore
import Charts

struct AdminDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState
    @StateObject private var serviceBookings = ServiceBookingDataService()
    @StateObject private var sitterData = SitterDataService()
    @StateObject private var visitsManager = VisitsListenerManager.shared
    @StateObject private var paymentConfirmationService = PaymentConfirmationService()
    @StateObject private var adminAnalytics = AdminAnalyticsService()
    @StateObject private var aiInsightsService = AIInsightsService()
    @StateObject private var layoutManager = DashboardLayoutManager()
    
    // Enhanced UX State
    @State private var searchText = ""
    @State private var selectedFilters: Set<AdvancedFilterBar.FilterOption> = []
    
    // Using UnifiedChatService for all messaging functionality
    @State private var activeVisits: [LiveVisit] = []
    @State private var isRefreshing: Bool = false
    @State private var showInquiryChat: Bool = false
    @State private var showChat: Bool = false
    @State private var chatSeed: String = ""
    @State private var showUnifiedMap: Bool = false
    
    // Enhanced state management
    @State private var selectedTimeRange: AnalyticsTimeRange = .week
    @State private var showingAIIntelligence: Bool = false
    @State private var showingPerformanceAlerts: Bool = false
    @State private var dashboardLayout: DashboardLayout = .overview
    @State private var isLoadingInsights: Bool = false
    @State private var aiRecommendations: [AIRecommendation] = []
    @State private var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    @State private var systemAlerts: [SystemAlert] = []
    
    // Listener management
    @State private var liveVisitsListener: ListenerRegistration?
    @State private var selectedConversationId: String? = nil
    @State private var showDetails: Bool = false
    @State private var detailsVisit: LiveVisit? = nil
    @State private var assignTarget: ServiceBooking? = nil
    @State private var showPaymentConfirmation: Bool = false
    @State private var paymentConfirmationTarget: ServiceBooking? = nil
    
    enum DashboardLayout: String, CaseIterable {
        case overview = "Overview"
        case analytics = "Analytics"
        case operations = "Operations"
        case intelligence = "AI Intelligence"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .operations: return "gearshape.fill"
            case .intelligence: return "brain.head.profile"
            case .custom: return "slider.horizontal.3"
            }
        }
    }
    
    enum AnalyticsTimeRange: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case quarter = "This Quarter"
        case year = "This Year"
    }
    var body: some View {
        TabView {
            EnhancedHome
                .tabItem { Label("Home", systemImage: "house.fill") }
            AdminClientsView()
                .tabItem { Label("Clients", systemImage: "person.3.fill") }
            AdminSittersView()
                .tabItem { Label("Sitters", systemImage: "figure.walk") }
            AdminBookingManagementView(serviceBookings: serviceBookings)
                .tabItem { Label("Bookings", systemImage: "calendar") }
            
            AdminCollaborationDashboard()
                .tabItem { Label("Team", systemImage: "person.2.circle.fill") }
            
            EnhancedWorkforceView()
                .tabItem { Label("Workforce", systemImage: "person.3.sequence.fill") }
            
            EnhancedPerformanceMonitoringView()
                .tabItem { Label("Monitoring", systemImage: "chart.line.uptrend.xyaxis") }
            
            EnhancedReportingDashboard()
                .tabItem { Label("Reports", systemImage: "doc.text.fill") }
            
            AdminMessagesTab()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
            AdminProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
        .onAppear {
            Task {
                await loadAIInsights()
                await loadPerformanceMetrics()
                await loadSystemAlerts()
            }
        }
    }

    private var EnhancedHome: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Header with Layout Manager
                EnhancedDashboardHeader(layoutManager: layoutManager)
                
                // Advanced Filter Bar
                AdvancedFilterBar(
                    searchText: $searchText,
                    selectedFilters: $selectedFilters,
                    availableFilters: availableFilters
                )
                .padding(.horizontal, SPDesignSystem.Spacing.m)
                .padding(.vertical, SPDesignSystem.Spacing.s)
                
                // Main Content Area with Enhanced Layout
                ScrollView {
                    LazyVStack(spacing: SPDesignSystem.Spacing.l) {
                        switch layoutManager.currentLayout {
                        case .overview:
                            enhancedOverviewContent
                        case .analytics:
                            enhancedAnalyticsContent
                        case .operations:
                            enhancedOperationsContent
                        case .intelligence:
                            enhancedIntelligenceContent
                        case .custom:
                            customLayoutContent
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Ensure chat listener is active for real-time updates
                appState.chatService.listenToMyConversations()
                
                // Request notification permission for admin
                Task {
                    await SmartNotificationManager.shared.requestNotificationPermission()
                }
                
                // Load initial data
                loadDashboardData()
            }
        }
    }
    
    // MARK: - Enhanced Content Views
    
    private var enhancedOverviewContent: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // Interactive Metrics Row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SPDesignSystem.Spacing.m) {
                InteractiveMetricCard(
                    title: "Active Bookings",
                    value: "\(serviceBookings.allBookings.filter { $0.status == .approved || $0.status == .inAdventure }.count)",
                    subtitle: "Currently active",
                    icon: "calendar.badge.checkmark",
                    color: .green,
                    trend: InteractiveMetricCard.TrendData(value: 12.5, period: "vs last week", isPositive: true),
                    action: { /* Navigate to bookings */ }
                )
                
                InteractiveMetricCard(
                    title: "Revenue Today",
                    value: "$\(Int(performanceMetrics.dailyRevenue))",
                    subtitle: "Today's earnings",
                    icon: "dollarsign.circle.fill",
                    color: .blue,
                    trend: InteractiveMetricCard.TrendData(value: 5.2, period: "vs yesterday", isPositive: true),
                    action: { /* Navigate to revenue */ }
                )
                
                InteractiveMetricCard(
                    title: "Active Sitters",
                    value: "\(sitterData.availableSitters.count)",
                    subtitle: "Available now",
                    icon: "person.3.fill",
                    color: .orange,
                    trend: InteractiveMetricCard.TrendData(value: -2.1, period: "vs last week", isPositive: false),
                    action: { /* Navigate to sitters */ }
                )
                
                InteractiveMetricCard(
                    title: "Client Satisfaction",
                    value: "\(Int(performanceMetrics.customerSatisfaction))%",
                    subtitle: "Average rating",
                    icon: "hand.thumbsup.fill",
                    color: .purple,
                    trend: InteractiveMetricCard.TrendData(value: 1.8, period: "vs last month", isPositive: true),
                    action: { /* Navigate to reviews */ }
                )
            }
            
            // Advanced Charts Section
            VStack(spacing: SPDesignSystem.Spacing.m) {
                AdvancedChartCard(
                    title: "Revenue Trends",
                    subtitle: "Monthly revenue performance",
                    chartData: ChartDataPoint.sampleRevenueData(),
                    chartType: .line,
                    timeRange: .month
                )
                
                AdvancedChartCard(
                    title: "Booking Patterns",
                    subtitle: "Weekly booking distribution",
                    chartData: ChartDataPoint.sampleBookingData(),
                    chartType: .bar,
                    timeRange: .week
                )
            }
            
            // Smart Insights Section
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                Text("AI Insights")
                    .font(SPDesignSystem.Typography.heading3())
                    .fontWeight(.semibold)
                    .padding(.horizontal, SPDesignSystem.Spacing.m)
                
                ForEach(AdvancedSmartInsightCard.InsightData.sampleInsights(), id: \.title) { insight in
                    AdvancedSmartInsightCard(insight: insight) {
                        // Handle insight action
                    }
                }
            }
            
            // Existing components
            pendingApprovals
            clientInquiries
            liveVisits
        }
    }
    
    private var enhancedAnalyticsContent: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // Analytics Charts Grid
            DashboardGrid(
                items: [
                    DashboardGrid.DashboardItem(
                        title: "Revenue Analytics",
                        content: AnyView(AdvancedChartCard(
                            title: "Revenue Trends",
                            subtitle: "Monthly performance",
                            chartData: ChartDataPoint.sampleRevenueData(),
                            chartType: .area,
                            timeRange: .month
                        )),
                        size: .large,
                        priority: 1
                    ),
                    DashboardGrid.DashboardItem(
                        title: "Booking Analytics",
                        content: AnyView(AdvancedChartCard(
                            title: "Booking Patterns",
                            subtitle: "Weekly distribution",
                            chartData: ChartDataPoint.sampleBookingData(),
                            chartType: .bar,
                            timeRange: .week
                        )),
                        size: .large,
                        priority: 2
                    ),
                    DashboardGrid.DashboardItem(
                        title: "Customer Analytics",
                        content: AnyView(AdvancedChartCard(
                            title: "Customer Satisfaction",
                            subtitle: "Rating trends",
                            chartData: ChartDataPoint.sampleRevenueData(),
                            chartType: .line,
                            timeRange: .month
                        )),
                        size: .medium,
                        priority: 3
                    ),
                    DashboardGrid.DashboardItem(
                        title: "Sitter Performance",
                        content: AnyView(AdvancedChartCard(
                            title: "Sitter Ratings",
                            subtitle: "Performance metrics",
                            chartData: ChartDataPoint.sampleBookingData(),
                            chartType: .scatter,
                            timeRange: .week
                        )),
                        size: .medium,
                        priority: 4
                    )
                ],
                columns: 2
            )
            
            // Revenue Chart
            revenueChart
        }
    }
    
    private var enhancedOperationsContent: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // Operations Dashboard
            ResponsiveCard(
                title: "Operations Overview",
                content: AnyView(
                    VStack(spacing: SPDesignSystem.Spacing.m) {
                        pendingApprovals
                        clientInquiries
                        liveVisits
                    }
                ),
                actions: [
                    ResponsiveCard.CardAction(
                        title: "Refresh",
                        icon: "arrow.clockwise",
                        action: { refreshNow() },
                        style: .secondary
                    ),
                    ResponsiveCard.CardAction(
                        title: "Export",
                        icon: "square.and.arrow.up",
                        action: { /* Export data */ },
                        style: .primary
                    )
                ]
            )
            
            // Activity Log
            activityLog
        }
    }
    
    private var enhancedIntelligenceContent: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // AI Insights Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: SPDesignSystem.Spacing.m) {
                ForEach(AdvancedSmartInsightCard.InsightData.sampleInsights(), id: \.title) { insight in
                    AdvancedSmartInsightCard(insight: insight) {
                        // Handle insight action
                    }
                }
            }
            
            // AI Recommendations
            if !aiRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("AI Recommendations")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .padding(.horizontal, SPDesignSystem.Spacing.m)
                    
                    ForEach(aiRecommendations) { recommendation in
                        AIRecommendationCard(recommendation: recommendation)
                    }
                }
            }
        }
    }
    
    private var customLayoutContent: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            if layoutManager.customLayouts.isEmpty {
                VStack(spacing: SPDesignSystem.Spacing.l) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Custom Layouts")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                    
                    Text("Create a custom dashboard layout to personalize your view")
                        .font(SPDesignSystem.Typography.body())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Create Custom Layout") {
                        // Open customization view
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(SPDesignSystem.Spacing.xl)
            } else {
                // Display custom layout widgets
                Text("Custom Layout Content")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Supporting Computed Properties
    
    private var availableFilters: [AdvancedFilterBar.FilterOption] {
        return [
            AdvancedFilterBar.FilterOption(title: "Active", icon: "checkmark.circle", category: .status),
            AdvancedFilterBar.FilterOption(title: "Pending", icon: "clock", category: .status),
            AdvancedFilterBar.FilterOption(title: "Today", icon: "calendar", category: .date),
            AdvancedFilterBar.FilterOption(title: "This Week", icon: "calendar.badge.clock", category: .date),
            AdvancedFilterBar.FilterOption(title: "High Priority", icon: "exclamationmark.triangle", category: .priority),
            AdvancedFilterBar.FilterOption(title: "Urgent", icon: "exclamationmark.circle", category: .priority)
        ]
    }
    
    private func loadDashboardData() {
        Task {
            await loadAIInsights()
            await loadPerformanceMetrics()
            await loadSystemAlerts()
        }
    }
    
    // MARK: - Enhanced Header Components
    
    private var enhancedHeader: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Business Intelligence")
                        .font(SPDesignSystem.Typography.heading1())
                        .fontWeight(.bold)
                    
                    Text("Real-time insights and AI-powered recommendations")
                        .font(SPDesignSystem.Typography.body())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    // AI Intelligence Button
                    Button(action: { showingAIIntelligence.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 14, weight: .medium))
                            Text("AI Insights")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .cornerRadius(8)
                    }
                    
                    // Performance Alerts Button
                    Button(action: { showingPerformanceAlerts.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("Alerts")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(systemAlerts.isEmpty ? Color.gray : Color.orange)
                        .cornerRadius(8)
                    }
                    .overlay(
                        // Alert badge
                        systemAlerts.isEmpty ? nil :
                        Text("\(systemAlerts.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    )
                    
                    // Refresh Button
                    Button(action: refreshNow) {
                        Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                    }
                }
            }
            
            // Quick Stats Row
            quickStatsRow
        }
        .padding(.horizontal, SPDesignSystem.Spacing.m)
        .padding(.vertical, SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.background(scheme: colorScheme))
    }
    
    private var dashboardLayoutSelector: some View {
        HStack(spacing: 0) {
            ForEach(DashboardLayout.allCases, id: \.self) { layout in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dashboardLayout = layout
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: layout.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(layout.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(dashboardLayout == layout ? .white : SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(dashboardLayout == layout ? SPDesignSystem.Colors.primaryAdjusted(colorScheme) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, SPDesignSystem.Spacing.m)
        .padding(.vertical, SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(colorScheme))
    }
    
    private var quickStatsRow: some View {
        HStack(spacing: SPDesignSystem.Spacing.m) {
            AdminQuickStatCard(
                title: "Active Bookings",
                value: "\(serviceBookings.allBookings.filter { $0.status == .approved || $0.status == .inAdventure }.count)",
                icon: "calendar.badge.checkmark",
                color: .green,
                trend: "+12%"
            )
            
            AdminQuickStatCard(
                title: "Revenue Today",
                value: "$\(Int(performanceMetrics.dailyRevenue))",
                icon: "dollarsign.circle.fill",
                color: .blue,
                trend: "+8%"
            )
            
            AdminQuickStatCard(
                title: "Active Sitters",
                value: "\(sitterData.availableSitters.count)",
                icon: "figure.walk",
                color: .orange,
                trend: "+3%"
            )
            
            AdminQuickStatCard(
                title: "Client Satisfaction",
                value: "\(Int(performanceMetrics.averageRating))%",
                icon: "star.fill",
                color: .yellow,
                trend: "+5%"
            )
        }
    }
    
    // MARK: - Dashboard Content Sections
    
    private var overviewContent: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // AI Recommendations Section
            if !aiRecommendations.isEmpty {
                aiRecommendationsSection
            }
            
            // System Alerts Section
            if !systemAlerts.isEmpty {
                systemAlertsSection
            }
            
            // Original sections
            pendingApprovals
            clientInquiries
            liveVisits
            revenueChart
            activityLog
        }
    }
    
    private var analyticsContent: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // Time Range Selector
            timeRangeSelector
            
            // Analytics Charts
            analyticsChartsSection
            
            // Performance Metrics
            performanceMetricsSection
            
            // Revenue Analytics
            revenueAnalyticsSection
        }
    }
    
    private var operationsContent: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // Operations Overview
            operationsOverviewSection
            
            // Live Operations
            liveVisits
            
            // Pending Operations
            pendingApprovals
            
            // Workforce Management
            workforceManagementSection
        }
    }
    
    private var intelligenceContent: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // AI Insights Overview
            aiInsightsOverviewSection
            
            // Predictive Analytics
            predictiveAnalyticsSection
            
            // Smart Recommendations
            smartRecommendationsSection
            
            // Performance Insights
            performanceInsightsSection
        }
    }

    private var pendingApprovals: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pending Approvals").font(SPDesignSystem.Typography.heading3())
                Spacer()
                if !serviceBookings.pendingBookings.isEmpty {
                    Text("\(serviceBookings.pendingBookings.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            
            if serviceBookings.pendingBookings.isEmpty {
                SPCard { 
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("No pending approvals")
                            .foregroundColor(.secondary)
                        Text("All bookings are processed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(serviceBookings.pendingBookings) { b in
                        PendingApprovalCard(
                            booking: b,
                            onApprove: { assignTarget = b },
                            onConfirmPayment: { paymentConfirmationTarget = b }
                        )
                    }
                }
            }
        }
        .onAppear { serviceBookings.listenToPendingBookings() }
        .sheet(item: assignSheetBinding) {
            item in
            AssignSitterSheet(booking: item.booking)
        }
        .sheet(item: paymentSheetBinding) {
            item in
            PaymentConfirmationSheet(
                booking: item.booking,
                paymentConfirmationService: paymentConfirmationService
            ) {
                paymentConfirmationTarget = nil
            }
        }
    }
    
    private var assignSheetBinding: Binding<AssignSheetTarget?> {
        Binding(
            get: { assignTarget.map { AssignSheetTarget(booking: $0) } },
            set: { assignTarget = $0?.booking }
        )
    }
    
    private var paymentSheetBinding: Binding<PaymentConfirmationTarget?> {
        Binding(
            get: { paymentConfirmationTarget.map { PaymentConfirmationTarget(booking: $0) } },
            set: { paymentConfirmationTarget = $0?.booking }
        )
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
                    
                    // Show unread count badge
                    if totalUnreadMessages > 0 {
                        Text("\(totalUnreadMessages)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    Button(action: { showInquiryChat = true }) {
                        Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                Text("Recent conversations with pet owners.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Show recent conversations grouped by pet owner
                let recentConvos = getRecentConversations()
                if !recentConvos.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(recentConvos, id: \.id) { conversation in
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
        AppLogger.ui.debug("AdminDashboardView: Total conversations: \(allConversations.count)")
        
        let adminInquiryConversations = allConversations.filter { conversation in
            // Show only admin inquiry conversations with unread messages
            let isAdminInquiry = conversation.type == .adminInquiry
            let hasUnread = hasUnreadMessages(conversation)
            AppLogger.ui.debug("AdminDashboardView: Conversation \(conversation.id) type: \(conversation.type.rawValue), isAdminInquiry: \(isAdminInquiry), hasUnread: \(hasUnread)")
            return isAdminInquiry && hasUnread
        }
        
        AppLogger.ui.debug("AdminDashboardView: Unread admin inquiry conversations: \(adminInquiryConversations.count)")
        
        // Sort by most recent message first (newest at top)
        let sortedConversations = adminInquiryConversations
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
            .prefix(5)
            .map { $0 }
        
        AppLogger.ui.debug("AdminDashboardView: Returning \(sortedConversations.count) conversations")
        for conv in sortedConversations {
            AppLogger.ui.debug("AdminDashboardView: - Conversation \(conv.id): last message: \(conv.lastMessage)")
        }
        
        return sortedConversations
    }
    
    // Helper to check if conversation has unread messages
    private func hasUnreadMessages(_ conversation: Conversation) -> Bool {
        guard let adminId = Auth.auth().currentUser?.uid else { return false }
        
        // Check if there are unread messages for current user
        if let unreadCount = conversation.unreadCounts[adminId], unreadCount > 0 {
            return true
        }
        
        // Fallback: check lastReadTimestamp vs lastMessageAt
        if let lastRead = conversation.lastReadTimestamps[adminId] {
            return conversation.lastMessageAt > lastRead
        }
        
        // If no read timestamp exists, consider it unread
        return true
    }
    
    // Helper to get total unread messages count for badge
    private var totalUnreadMessages: Int {
        guard let adminId = Auth.auth().currentUser?.uid else { return 0 }
        
        let unreadCount = appState.chatService.conversations
            .filter { $0.type == .adminInquiry }
            .reduce(0) { total, conversation in
                total + (conversation.unreadCounts[adminId] ?? 0)
            }
        
        return unreadCount
    }

    private var liveVisits: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with count and controls
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Visits")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("\(activeVisits.count) active")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: { showUnifiedMap.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: showUnifiedMap ? "list.bullet" : "map")
                                .font(.system(size: 14, weight: .medium))
                            Text(showUnifiedMap ? "List" : "Map")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.1))
                        .cornerRadius(8)
                    }
                    .accessibilityLabel(showUnifiedMap ? "Switch to list view" : "Switch to map view")
                    
                    Button(action: refreshNow) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                            .padding(8)
                            .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.1))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Refresh live visits")
                }
            }

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
                // Conditional rendering based on toggle
                if showUnifiedMap {
                    UnifiedLiveMapView(visits: activeVisits)
                        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 400, maxHeight: 400)
                        .cornerRadius(12)
                        .transition(.opacity)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(activeVisits) { v in
                            LiveVisitCard(
                                visit: v,
                                onViewDetails: { detailsVisit = v; showDetails = true },
                                onMessageSitter: { openChatFor(visit: v) },
                                onEndVisit: { endVisit(v) }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .task {
            await subscribeLiveVisitsAsync()
        }
        .onChange(of: visitsManager.inProgressVisits) { newVisits in
            updateActiveVisits(from: newVisits)
        }
        .onDisappear {
            liveVisitsListener?.remove()
            liveVisitsListener = nil
        }
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
                                try? await chat.approveMessage(messageId: message.id, conversationId: getConversationIdForMessage(message))  // Nil coalescing fix: message.id is non-optional
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
                        try? await chat.rejectMessage(messageId: message.id, conversationId: getConversationIdForMessage(message), reason: rejectionReason)  // Nil coalescing fix: message.id is non-optional
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
                    Text("Message ID: \(message.id)")  // Nil coalescing fix: message.id is non-optional
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

struct LiveVisit: Identifiable, Equatable {
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
    let serviceSummary: String
    let pets: [String]
    let petPhotoURLs: [String]
    let note: String
}

private struct LiveVisitCard: View {
    @Environment(\.colorScheme) private var colorScheme
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

    private var statusColor: Color {
        switch visit.status {
        case "in_progress", "in_adventure": return .green
        case "delayed": return .yellow
        case "issue": return .red
        default: return .gray
        }
    }
    
    private var statusIcon: String {
        switch visit.status {
        case "in_progress", "in_adventure": return "checkmark.circle.fill"
        case "delayed": return "exclamationmark.triangle.fill"
        case "issue": return "exclamationmark.octagon.fill"
        default: return "circle.fill"
        }
    }

    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header with Status
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Client and Sitter names - separate lines for better readability
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                                .font(.system(size: 14))
                            Text(visit.clientName)
                                .font(SPDesignSystem.Typography.body())
                                .fontWeight(.medium)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                                .font(.system(size: 14))
                            Text(visit.sitterName)
                                .font(SPDesignSystem.Typography.body())
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    // Status indicator with background
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 12))
                        Text(visit.status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
                }
                
                // Map Preview - Smaller and better positioned
                HStack(spacing: 12) {
                    LiveVisitMapPreview(sitterId: visit.sitterId)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(statusColor, lineWidth: 2)
                        )
                    
                    // Time and Progress Info
                    VStack(alignment: .leading, spacing: 8) {
                        // Progress Bar
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Progress")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(statusColor)
                            }
                            ProgressView(value: progress)
                                .tint(statusColor)
                                .scaleEffect(y: 1.5)
                        }
                        
                        // Time Information
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("Started \(relative(from: visit.checkIn ?? visit.scheduledStart))")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "hourglass.tophalf.filled")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("Ends in \(timeRemaining(until: visit.scheduledEnd))")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Action Buttons - Better organized
                HStack(spacing: 8) {
                    // Primary action
                    Button(action: onViewDetails) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 12))
                            Text("View Details")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .cornerRadius(8)
                    }
                    
                    // Secondary actions
                    Button(action: onMessageSitter) {
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 12))
                            Text("Message")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // End visit button
                    Button(action: onEndVisit) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text("End Visit")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
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
    private func subscribeLiveVisitsAsync() async {
        // Use centralized listener manager to prevent conflicts
        // The VisitsListenerManager is now observed via @StateObject and .onChange
        // Initial load of active visits - done on main thread
        await MainActor.run {
            updateActiveVisits(from: visitsManager.inProgressVisits)
        }
    }
    
    private func subscribeLiveVisits() {
        // Use centralized listener manager to prevent conflicts
        // The VisitsListenerManager is now observed via @StateObject and .onChange
        // Initial load of active visits
        updateActiveVisits(from: visitsManager.inProgressVisits)
    }
    
    private func updateActiveVisits(from visits: [VisitsListenerManager.Visit]) {
        var items: [LiveVisit] = []
        for visit in visits {
            items.append(LiveVisit(
                id: visit.id,
                clientName: visit.clientName,
                sitterName: visit.sitterName,
                sitterId: visit.sitterId,
                scheduledStart: visit.scheduledStart,
                scheduledEnd: visit.scheduledEnd,
                checkIn: visit.checkInTimestamp,
                checkOut: visit.checkOutTimestamp,
                status: visit.status,
                address: visit.address.isEmpty ? nil : visit.address,
                serviceSummary: visit.serviceSummary,
                pets: visit.pets,
                petPhotoURLs: visit.petPhotoURLs,
                note: visit.note
            ))
        }
        withAnimation(.easeInOut(duration: 0.2)) { self.activeVisits = items }
    }

    private func refreshNow() {
        Task { @MainActor in
            isRefreshing = true
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            isRefreshing = false
            updateActiveVisits(from: visitsManager.inProgressVisits)
        }
    }

    private func openChatFor(visit: LiveVisit) {
        // Try to find existing conversation with this sitter
        let existingConversation = appState.chatService.conversations.first { conversation in
            conversation.participants.contains(visit.sitterId) &&
            (conversation.type == .sitterToClient || conversation.type == .clientSitter)
        }
        
        if let conversation = existingConversation {
            // Open existing conversation
            selectedConversationId = conversation.id
        } else {
            // Open admin inquiry chat with pre-filled message for sitter
            chatSeed = "Hello \(visit.sitterName), regarding \(visit.clientName)'s visit (\(visit.id))."
            showChat = true
            
            AppLogger.ui.info("Opening chat for sitter \(visit.sitterId) - use admin inquiry to manually create conversation")
        }
    }

    private func endVisit(_ v: LiveVisit) {
        let db = Firestore.firestore()
        db.collection("visits").document(v.id).setData([
            "status": "completed",
            "timeline.checkOut.timestamp": FieldValue.serverTimestamp()
        ], merge: true)
    }
}

// MARK: - Pending Approval Card
private struct PendingApprovalCard: View {
    let booking: ServiceBooking
    let onApprove: () -> Void
    let onConfirmPayment: () -> Void
    
    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header with service type and date
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(booking.serviceType)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted) + " at " + booking.scheduledTime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !booking.pets.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "pawprint.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(booking.pets.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(booking.status.color)
                            .frame(width: 8, height: 8)
                        Text(booking.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(booking.status.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(booking.status.color.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Payment status if available
                if let paymentStatus = booking.paymentStatus {
                    HStack(spacing: 6) {
                        Image(systemName: paymentStatusIcon(for: paymentStatus))
                            .foregroundColor(paymentStatusColor(for: paymentStatus))
                        Text("Payment: \(paymentStatus.displayName)")
                            .font(.caption)
                            .foregroundColor(paymentStatusColor(for: paymentStatus))
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    // Payment confirmation button (primary)
                    Button(action: onConfirmPayment) {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 12))
                            Text("Confirm Payment")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                        .cornerRadius(8)
                    }
                    
                    // Manual approval button (secondary)
                    Button(action: onApprove) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill.checkmark")
                                .font(.system(size: 12))
                            Text("Manual Assign")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(SPDesignSystem.Colors.primaryAdjusted(.light).opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
        }
    }
    
    private func paymentStatusIcon(for status: PaymentStatus) -> String {
        switch status {
        case .confirmed: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .pending: return "clock.fill"
        }
    }
    
    private func paymentStatusColor(for status: PaymentStatus) -> Color {
        switch status {
        case .confirmed: return .green
        case .declined: return .red
        case .failed: return .orange
        case .pending: return .blue
        }
    }
}

// MARK: - Payment Confirmation Sheet
private struct PaymentConfirmationSheet: View {
    let booking: ServiceBooking
    @ObservedObject var paymentConfirmationService: PaymentConfirmationService
    let onDismiss: () -> Void
    
    @State private var selectedPaymentStatus: PaymentStatus = .confirmed
    @State private var transactionId: String = ""
    @State private var amount: String = ""
    @State private var paymentMethod: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                            DetailRow(icon: "dollarsign.circle", label: "Duration", value: "\(booking.duration) minutes")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Payment status selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Payment Status")
                            .font(.headline)
                        
                        Picker("Payment Status", selection: $selectedPaymentStatus) {
                            ForEach(PaymentStatus.allCases, id: \.self) { status in
                                HStack {
                                    Image(systemName: paymentStatusIcon(for: status))
                                    Text(status.displayName)
                                }
                                .tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Payment details (only show for confirmed payments)
                    if selectedPaymentStatus == .confirmed {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Payment Details")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                TextField("Transaction ID (optional)", text: $transactionId)
                                    .textFieldStyle(.roundedBorder)
                                
                                TextField("Amount (optional)", text: $amount)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
                                
                                TextField("Payment Method (optional)", text: $paymentMethod)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    
                    // Assignment method info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assignment Method")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Image(systemName: selectedPaymentStatus == .confirmed ? "brain.head.profile" : "person.fill.checkmark")
                                .font(.title2)
                                .foregroundColor(selectedPaymentStatus == .confirmed ? .blue : .orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedPaymentStatus == .confirmed ? "AI Auto-Assignment" : "Manual Admin Approval")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(selectedPaymentStatus == .confirmed ? 
                                     "AI will automatically find and assign the best sitter based on availability, distance, and pet type." :
                                     "Admin will manually review and assign a sitter after payment issues are resolved.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(selectedPaymentStatus == .confirmed ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Confirm button
                    Button(action: confirmPayment) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isProcessing ? "Processing..." : "Confirm Payment Status")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .background(selectedPaymentStatus == .confirmed ? Color.blue : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isProcessing)
                }
                .padding()
            }
            .navigationTitle("Payment Confirmation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .disabled(isProcessing)
                }
            }
        }
    }
    
    private func confirmPayment() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            let paymentDetails = PaymentDetails(
                transactionId: transactionId.isEmpty ? nil : transactionId,
                amount: amount.isEmpty ? nil : Double(amount),
                paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod
            )
            
            let result = await paymentConfirmationService.confirmPayment(
                for: booking.id,
                paymentStatus: selectedPaymentStatus,
                paymentDetails: paymentDetails
            )
            
            await MainActor.run {
                isProcessing = false
                
                if result.assignmentTriggered != .none {
                    onDismiss()
                } else {
                    errorMessage = result.message
                }
            }
        }
    }
    
    private func paymentStatusIcon(for status: PaymentStatus) -> String {
        switch status {
        case .confirmed: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .pending: return "clock.fill"
        }
    }
}

// MARK: - Detail Row Component
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

// MARK: - Payment Status Extension
extension PaymentStatus {
    var displayName: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .declined: return "Declined"
        case .failed: return "Failed"
        case .pending: return "Pending"
        }
    }
}

// MARK: - Assign sitter sheet
private struct AssignSheetTarget: Identifiable { let booking: ServiceBooking; var id: String { booking.id } }
private struct PaymentConfirmationTarget: Identifiable { let booking: ServiceBooking; var id: String { booking.id } }


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
        .frame(minWidth: 100, maxWidth: .infinity, minHeight: 80, maxHeight: 80)
        .onReceive(loc.$coordinate) { coord in
            Task { @MainActor in
                if let c = coord {
                    region.center = c
                }
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
    @State private var searchText: String = ""
    @State private var selectedStatus: ServiceBooking.BookingStatus? = nil

    enum Segment: String, CaseIterable, Identifiable {
        case past = "Past"
        case current = "Current"
        case future = "Future"
        var id: String { rawValue }
    }

    private var filtered: [ServiceBooking] {
        let now = Date()
        var bookings = serviceBookings.allBookings
        func endDate(_ b: ServiceBooking) -> Date { b.scheduledDate.addingTimeInterval(TimeInterval(max(b.duration, 0) * 60)) }
        
        // Apply timeframe filter
        switch segment {
        case .past:
            bookings = bookings.filter { 
                $0.status == .completed || 
                $0.status == .cancelled || 
                endDate($0) < now 
            }.sorted { $0.scheduledDate > $1.scheduledDate }
        case .current:
            bookings = bookings.filter { 
                $0.status == .inAdventure || 
                ($0.scheduledDate <= now && endDate($0) > now)
            }.sorted { $0.scheduledDate < $1.scheduledDate }
        case .future:
            bookings = bookings.filter { 
                $0.status == .pending || 
                $0.status == .approved || 
                $0.scheduledDate > now 
            }.sorted { $0.scheduledDate < $1.scheduledDate }
        }
        
        // Apply status filter
        if let selectedStatus = selectedStatus {
            bookings = bookings.filter { $0.status == selectedStatus }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            bookings = bookings.filter { booking in
                let clientName = clientNames[booking.clientId] ?? booking.clientId
                return booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
                       clientName.localizedCaseInsensitiveContains(searchText) ||
                       (booking.sitterName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       booking.pets.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return bookings
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search bookings...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Timeframe picker
                Picker("Timeframe", selection: $segment) {
                    ForEach(Segment.allCases) { seg in Text(seg.rawValue).tag(seg) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Status filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedStatus == nil,
                            count: serviceBookings.allBookings.count
                        ) {
                            selectedStatus = nil
                        }
                        
                        ForEach(ServiceBooking.BookingStatus.allCases, id: \.rawValue) { status in
                            let count = serviceBookings.allBookings.filter { $0.status == status }.count
                            if count > 0 {
                                FilterChip(
                                    title: status.displayName,
                                    isSelected: selectedStatus == status,
                                    count: count,
                                    color: status.color
                                ) {
                                    selectedStatus = status
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Results count
                HStack {
                    Text("\(filtered.count) booking\(filtered.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !searchText.isEmpty {
                        Button("Clear Search") {
                            searchText = ""
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
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

// MARK: - Filter Chip Component
private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    var color: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text("(\(count))").font(.caption)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1)))
            .foregroundColor(isSelected ? color : .primary)
            .overlay(Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1))
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

// MARK: - Supporting Data Models and Services

struct AIRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let priority: Priority
    let category: Category
    let actionTitle: String
    let action: () -> Void
    
    enum Priority: String, CaseIterable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }
    }
    
    enum Category: String, CaseIterable {
        case optimization = "Optimization"
        case revenue = "Revenue"
        case efficiency = "Efficiency"
        case customer = "Customer"
        case workforce = "Workforce"
    }
}

struct PerformanceMetrics {
    var dailyRevenue: Double = 0
    var weeklyRevenue: Double = 0
    var monthlyRevenue: Double = 0
    var averageRating: Double = 0
    var completionRate: Double = 0
    var responseTime: Double = 0
    var customerSatisfaction: Double = 0
    var sitterUtilization: Double = 0
    var bookingConversionRate: Double = 0
    var churnRate: Double = 0
}

struct SystemAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: Severity
    let timestamp: Date
    let category: AlertCategory
    
    enum Severity: String, CaseIterable {
        case critical = "Critical"
        case warning = "Warning"
        case info = "Info"
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
    
    enum AlertCategory: String, CaseIterable {
        case system = "System"
        case performance = "Performance"
        case security = "Security"
        case business = "Business"
    }
}

// MARK: - Quick Stat Card Component

struct AdminQuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
                
                Text(trend)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - AI Insights Service

class AIInsightsService: ObservableObject {
    @Published var insights: [AIRecommendation] = []
    @Published var isLoading: Bool = false
    
    func generateInsights() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate AI processing
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let recommendations = [
            AIRecommendation(
                title: "Optimize Peak Hours",
                description: "Booking demand increases 40% during 2-4 PM. Consider adding more sitters during this time.",
                priority: .high,
                category: .optimization,
                actionTitle: "View Details",
                action: {}
            ),
            AIRecommendation(
                title: "Revenue Opportunity",
                description: "Premium services show 25% higher conversion. Consider promoting them more prominently.",
                priority: .medium,
                category: .revenue,
                actionTitle: "Optimize",
                action: {}
            ),
            AIRecommendation(
                title: "Customer Retention",
                description: "Clients who book weekly services have 80% retention rate. Consider loyalty programs.",
                priority: .medium,
                category: .customer,
                actionTitle: "Implement",
                action: {}
            )
        ]
        
        await MainActor.run {
            self.insights = recommendations
            isLoading = false
        }
    }
}

// MARK: - Admin Analytics Service

class AdminAnalyticsService: ObservableObject {
    @Published var analytics: [String: Any] = [:]
    @Published var isLoading: Bool = false
    
    func loadAnalytics(for timeRange: AdminDashboardView.AnalyticsTimeRange) async {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate analytics loading
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Enhanced Dashboard Components

extension AdminDashboardView {
    
    private var aiRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Text("AI Recommendations")
                    .font(SPDesignSystem.Typography.heading3())
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingAIIntelligence = true
                }
                .font(.caption)
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            LazyVStack(spacing: SPDesignSystem.Spacing.s) {
                ForEach(aiRecommendations.prefix(3)) { recommendation in
                    AIRecommendationCard(recommendation: recommendation)
                }
            }
        }
    }
    
    private var systemAlertsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Text("System Alerts")
                    .font(SPDesignSystem.Typography.heading3())
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingPerformanceAlerts = true
                }
                .font(.caption)
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            LazyVStack(spacing: SPDesignSystem.Spacing.s) {
                ForEach(systemAlerts.prefix(3)) { alert in
                    SystemAlertCard(alert: alert)
                }
            }
        }
    }
    
    private var timeRangeSelector: some View {
        HStack {
            Text("Time Range:")
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(.secondary)
            
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            
            Spacer()
        }
    }
    
    private var analyticsChartsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Analytics Overview")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            // Placeholder for charts
            SPCard {
                VStack(spacing: 16) {
                    Text("📊 Interactive Charts Coming Soon")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Revenue trends, booking patterns, and performance metrics will be displayed here with interactive charts.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }
    
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Performance Metrics")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SPDesignSystem.Spacing.s) {
                AdminMetricCard(title: "Completion Rate", value: "\(Int(performanceMetrics.completionRate))%", icon: "checkmark.circle.fill", color: .green)
                AdminMetricCard(title: "Response Time", value: "\(Int(performanceMetrics.responseTime))m", icon: "clock.fill", color: .blue)
                AdminMetricCard(title: "Sitter Utilization", value: "\(Int(performanceMetrics.sitterUtilization))%", icon: "person.2.fill", color: .orange)
                AdminMetricCard(title: "Conversion Rate", value: "\(Int(performanceMetrics.bookingConversionRate))%", icon: "arrow.up.circle.fill", color: .purple)
            }
        }
    }
    
    private var revenueAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Revenue Analytics")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.s) {
                RevenueCard(title: "Daily", amount: performanceMetrics.dailyRevenue, trend: "+8%")
                RevenueCard(title: "Weekly", amount: performanceMetrics.weeklyRevenue, trend: "+12%")
                RevenueCard(title: "Monthly", amount: performanceMetrics.monthlyRevenue, trend: "+15%")
            }
        }
    }
    
    private var operationsOverviewSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Operations Overview")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            SPCard {
                VStack(spacing: 12) {
                    HStack {
                        Text("Current Operations Status")
                            .font(.headline)
                        Spacer()
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                    }
                    
                    Text("All systems operational. \(activeVisits.count) active visits in progress.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var workforceManagementSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Workforce Management")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            SPCard {
                VStack(spacing: 12) {
                    HStack {
                        Text("Sitter Availability")
                            .font(.headline)
                        Spacer()
                        Text("\(sitterData.availableSitters.count) Available")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    
                    Text("Optimal staffing levels maintained. Consider adding weekend coverage.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var aiInsightsOverviewSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("AI Intelligence Overview")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            SPCard {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI-Powered Insights")
                                .font(.headline)
                            Text("\(aiRecommendations.count) active recommendations")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Text("Our AI analyzes patterns in your data to provide actionable insights for business growth.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var predictiveAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Predictive Analytics")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            SPCard {
                VStack(spacing: 12) {
                    Text("🔮 Predictive Features Coming Soon")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Forecast booking trends, predict demand patterns, and optimize resource allocation with AI-powered predictions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }
    
    private var smartRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Smart Recommendations")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            LazyVStack(spacing: SPDesignSystem.Spacing.s) {
                ForEach(aiRecommendations) { recommendation in
                    AIRecommendationCard(recommendation: recommendation)
                }
            }
        }
    }
    
    private var performanceInsightsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Performance Insights")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            SPCard {
                VStack(spacing: 12) {
                    Text("📈 Performance Analysis")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Deep dive into performance metrics, identify bottlenecks, and optimize operations with data-driven insights.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAIInsights() async {
        await aiInsightsService.generateInsights()
        await MainActor.run {
            aiRecommendations = aiInsightsService.insights
        }
    }
    
    private func loadPerformanceMetrics() async {
        // Simulate loading performance metrics
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            performanceMetrics = PerformanceMetrics(
                dailyRevenue: 1250.0,
                weeklyRevenue: 8750.0,
                monthlyRevenue: 37500.0,
                averageRating: 4.8,
                completionRate: 96.5,
                responseTime: 2.3,
                customerSatisfaction: 94.2,
                sitterUtilization: 78.5,
                bookingConversionRate: 23.7,
                churnRate: 5.2
            )
        }
    }
    
    private func loadSystemAlerts() async {
        // Simulate loading system alerts
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        await MainActor.run {
            systemAlerts = [
                SystemAlert(
                    title: "High Booking Volume",
                    message: "Booking requests are 40% above average. Consider adding more sitters.",
                    severity: .warning,
                    timestamp: Date(),
                    category: .business
                ),
                SystemAlert(
                    title: "System Performance",
                    message: "Response times are within normal range.",
                    severity: .info,
                    timestamp: Date().addingTimeInterval(-3600),
                    category: .performance
                )
            ]
        }
    }
}

// MARK: - Supporting Card Components

struct AIRecommendationCard: View {
    let recommendation: AIRecommendation
    
    var body: some View {
        SPCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(recommendation.priority.color)
                            .frame(width: 8, height: 8)
                        Text(recommendation.priority.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(recommendation.priority.color)
                    }
                    
                    Spacer()
                    
                    Text(recommendation.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(recommendation.priority.color.opacity(0.1))
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(recommendation.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Button(action: recommendation.action) {
                    Text(recommendation.actionTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SystemAlertCard: View {
    let alert: SystemAlert
    
    var body: some View {
        SPCard {
            HStack(spacing: 12) {
                Image(systemName: alert.severity == .critical ? "exclamationmark.octagon.fill" : 
                      alert.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                    .font(.title2)
                    .foregroundColor(alert.severity.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(alert.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text(alert.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(alert.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct AdminMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct RevenueCard: View {
    let title: String
    let amount: Double
    let trend: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(Int(amount))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(trend)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .frame(maxWidth: .infinity)
        .padding(SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

