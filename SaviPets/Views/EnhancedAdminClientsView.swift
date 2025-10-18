import SwiftUI
import Charts

// MARK: - Enhanced Admin Clients View

struct EnhancedAdminClientsView: View {
    @StateObject private var crmService = AdminCRMService()
    @State private var selectedTab: ClientTab = .clients
    @State private var searchText = ""
    @State private var selectedFilters: Set<ClientFilter> = []
    @State private var showingAddClient = false
    @State private var showingAddLead = false
    @State private var selectedClient: CRMClient?
    @State private var showingClientDetail = false
    @State private var showingCampaigns = false
    @State private var showingAnalytics = false
    
    enum ClientTab: String, CaseIterable {
        case clients = "Clients"
        case leads = "Leads"
        case interactions = "Interactions"
        case campaigns = "Campaigns"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .clients: return "person.2.fill"
            case .leads: return "person.circle.fill"
            case .interactions: return "bubble.left.and.bubble.right.fill"
            case .campaigns: return "megaphone.fill"
            case .analytics: return "chart.bar.fill"
            }
        }
    }
    
    enum ClientFilter: String, CaseIterable {
        case active = "Active"
        case inactive = "Inactive"
        case highValue = "High Value"
        case recent = "Recent"
        case vip = "VIP"
        
        var color: Color {
            switch self {
            case .active: return .green
            case .inactive: return .orange
            case .highValue: return .blue
            case .recent: return .purple
            case .vip: return .red
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Header
                enhancedHeader
                
                // Tab Selector
                tabSelector
                
                // Filter Bar
                filterBar
                
                // Main Content
                TabView(selection: $selectedTab) {
                    clientsTab
                        .tag(ClientTab.clients)
                    
                    leadsTab
                        .tag(ClientTab.leads)
                    
                    interactionsTab
                        .tag(ClientTab.interactions)
                    
                    campaignsTab
                        .tag(ClientTab.campaigns)
                    
                    analyticsTab
                        .tag(ClientTab.analytics)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Client Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddClient = true }) {
                            Label("Add Client", systemImage: "person.badge.plus")
                        }
                        
                        Button(action: { showingAddLead = true }) {
                            Label("Add Lead", systemImage: "person.circle.badge.plus")
                        }
                        
                        Divider()
                        
                        Button(action: { showingCampaigns = true }) {
                            Label("Campaigns", systemImage: "megaphone.fill")
                        }
                        
                        Button(action: { showingAnalytics = true }) {
                            Label("Analytics", systemImage: "chart.bar.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    }
                }
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView(crmService: crmService)
            }
            .sheet(isPresented: $showingAddLead) {
                AddLeadView(crmService: crmService)
            }
            .sheet(isPresented: $showingClientDetail) {
                if let client = selectedClient {
                    ClientDetailView(client: client, crmService: crmService)
                }
            }
            .sheet(isPresented: $showingCampaigns) {
                CampaignManagementView(crmService: crmService)
            }
            .sheet(isPresented: $showingAnalytics) {
                CRMAnalyticsView(crmService: crmService)
            }
        }
    }
    
    // MARK: - Header
    
    private var enhancedHeader: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Client Management")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.bold)
                    
                    Text("\(crmService.clients.count) clients, \(crmService.leads.count) leads")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick stats
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    QuickStat(
                        title: "Active",
                        value: "\(crmService.clients.filter { $0.status == .active }.count)",
                        color: .green
                    )
                    
                    QuickStat(
                        title: "Revenue",
                        value: "$\(Int(crmService.clients.reduce(0) { $0 + $1.totalRevenue }))",
                        color: .blue
                    )
                    
                    QuickStat(
                        title: "Leads",
                        value: "\(crmService.leads.count)",
                        color: .orange
                    )
                }
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search clients, leads...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(SPDesignSystem.Spacing.s)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ClientTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? SPDesignSystem.Colors.primaryAdjusted(.light) : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SPDesignSystem.Spacing.s)
                }
            }
        }
        .background(SPDesignSystem.Colors.surface(.light))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SPDesignSystem.Spacing.s) {
                ForEach(ClientFilter.allCases, id: \.self) { filter in
                    CRMFilterChip(
                        title: filter.rawValue,
                        color: filter.color,
                        isSelected: selectedFilters.contains(filter)
                    ) {
                        if selectedFilters.contains(filter) {
                            selectedFilters.remove(filter)
                        } else {
                            selectedFilters.insert(filter)
                        }
                    }
                }
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
        }
        .padding(.vertical, SPDesignSystem.Spacing.s)
    }
    
    // MARK: - Tabs
    
    private var clientsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(filteredClients) { client in
                    ClientCard(client: client) {
                        selectedClient = client
                        showingClientDetail = true
                    }
                }
            }
            .padding()
        }
    }
    
    private var leadsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(crmService.leads) { lead in
                    LeadCard(lead: lead, crmService: crmService)
                }
            }
            .padding()
        }
    }
    
    private var interactionsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(crmService.interactions) { interaction in
                    InteractionCard(interaction: interaction, crmService: crmService)
                }
            }
            .padding()
        }
    }
    
    private var campaignsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(crmService.campaigns) { campaign in
                    CampaignCard(campaign: campaign, crmService: crmService)
                }
            }
            .padding()
        }
    }
    
    private var analyticsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                // Analytics charts
                CRMAnalyticsCharts(crmService: crmService)
            }
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredClients: [CRMClient] {
        var clients = crmService.clients
        
        // Apply search filter
        if !searchText.isEmpty {
            clients = crmService.searchClients(query: searchText)
        }
        
        // Apply status filters
        if !selectedFilters.isEmpty {
            clients = clients.filter { client in
                if selectedFilters.contains(.active) && client.status == .active { return true }
                if selectedFilters.contains(.inactive) && client.status == .inactive { return true }
                if selectedFilters.contains(.highValue) && client.lifetimeValue > 1000 { return true }
                if selectedFilters.contains(.recent) && client.lastContactDate > Date().addingTimeInterval(-86400 * 7) { return true }
                if selectedFilters.contains(.vip) && client.tags.contains("VIP") { return true }
                return false
            }
        }
        
        return clients.sorted { $0.lastContactDate > $1.lastContactDate }
    }
}

// MARK: - Supporting Views

struct QuickStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct CRMFilterChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct ClientCard: View {
    let client: CRMClient
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.name)
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(client.company)
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Image(systemName: client.status.icon)
                            .font(.caption)
                        Text(client.status.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(client.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(client.status.color.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Contact info
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(client.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(client.phone)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Metrics
                HStack {
                    MetricItem(title: "Bookings", value: "\(client.totalBookings)")
                    MetricItem(title: "Revenue", value: "$\(Int(client.totalRevenue))")
                    MetricItem(title: "LTV", value: "$\(Int(client.lifetimeValue))")
                    
                    Spacer()
                    
                    // Source indicator
                    HStack(spacing: 4) {
                        Image(systemName: client.source.icon)
                            .font(.caption)
                        Text(client.source.rawValue.capitalized)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Tags
                if !client.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(client.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding(SPDesignSystem.Spacing.m)
            .background(SPDesignSystem.Colors.surface(.light))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MetricItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct LeadCard: View {
    let lead: CRMLead
    let crmService: AdminCRMService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead.name)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(lead.company)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Score indicator
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("\(lead.score)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Contact info
            HStack(spacing: SPDesignSystem.Spacing.m) {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(lead.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(lead.phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Actions
            HStack(spacing: SPDesignSystem.Spacing.s) {
                Button(action: { convertLead() }) {
                    Text("Convert to Client")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                // Status indicator
                Text(lead.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(lead.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(lead.status.color.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func convertLead() {
        Task {
            try? await crmService.convertLeadToClient(lead.id)
        }
    }
}

struct InteractionCard: View {
    let interaction: CRMInteraction
    let crmService: AdminCRMService
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            // Type indicator
            Image(systemName: interaction.type.icon)
                .font(.title3)
                .foregroundColor(interaction.type.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(interaction.subject)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(interaction.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(formatTime(interaction.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Type label
            Text(interaction.type.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(interaction.type.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(interaction.type.color.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CampaignCard: View {
    let campaign: CRMCampaign
    let crmService: AdminCRMService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.name)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(campaign.description)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Status indicator
                Text(campaign.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(campaign.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(campaign.status.color.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Metrics
            HStack {
                MetricItem(title: "Sent", value: "\(campaign.metrics.sent)")
                MetricItem(title: "Opened", value: "\(campaign.metrics.opened)")
                MetricItem(title: "Clicked", value: "\(campaign.metrics.clicked)")
                MetricItem(title: "Revenue", value: "$\(Int(campaign.metrics.revenue))")
            }
            
            // Actions
            HStack(spacing: SPDesignSystem.Spacing.s) {
                Button(action: { executeCampaign() }) {
                    Text("Execute")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                // Type indicator
                HStack(spacing: 4) {
                    Image(systemName: campaign.type.icon)
                        .font(.caption)
                    Text(campaign.type.rawValue.capitalized)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func executeCampaign() {
        Task {
            try? await crmService.executeCampaign(campaign.id)
        }
    }
}

struct CRMAnalyticsCharts: View {
    let crmService: AdminCRMService
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // Client status distribution
            AdvancedChartCard(
                title: "Client Status Distribution",
                subtitle: "Distribution of clients by status",
                chartData: clientStatusData,
                chartType: .pie,
                timeRange: .month
            )
            
            // Revenue trends
            AdvancedChartCard(
                title: "Revenue Trends",
                subtitle: "Monthly revenue from clients",
                chartData: revenueTrendData,
                chartType: .line,
                timeRange: .month
            )
            
            // Lead conversion
            AdvancedChartCard(
                title: "Lead Conversion",
                subtitle: "Lead to client conversion rates",
                chartData: conversionData,
                chartType: .bar,
                timeRange: .week
            )
        }
    }
    
    private var clientStatusData: [ChartDataPoint] {
        let statusCounts = Dictionary(grouping: crmService.clients, by: { $0.status })
        return statusCounts.map { status, clients in
            ChartDataPoint(
                xValue: status.rawValue.capitalized,
                yValue: Double(clients.count),
                color: status.color,
                label: "\(clients.count) clients"
            )
        }
    }
    
    private var revenueTrendData: [ChartDataPoint] {
        // Sample revenue data for the last 6 months
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
        let revenues = [12000, 15000, 18000, 16000, 20000, 22000]
        
        return zip(months, revenues).map { month, revenue in
            ChartDataPoint(
                xValue: month,
                yValue: Double(revenue),
                color: .green,
                label: "$\(revenue)"
            )
        }
    }
    
    private var conversionData: [ChartDataPoint] {
        // Sample conversion data
        let sources = ["Website", "Referral", "Social", "Advertising"]
        let conversions = [25, 40, 15, 20]
        
        return zip(sources, conversions).map { source, conversion in
            ChartDataPoint(
                xValue: source,
                yValue: Double(conversion),
                color: .blue,
                label: "\(conversion)%"
            )
        }
    }
}
