import SwiftUI
import Charts

// MARK: - Enhanced Performance Monitoring Dashboard

struct EnhancedPerformanceMonitoringView: View {
    @StateObject private var monitoringService = AdminPerformanceMonitoringService()
    @State private var selectedTab: MonitoringTab = .overview
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var showingAlertDetails = false
    @State private var selectedAlert: PerformanceAlert?
    @State private var showingAlertRules = false
    @State private var showingSystemHealth = false
    @State private var isRefreshing = false
    
    enum MonitoringTab: String, CaseIterable {
        case overview = "Overview"
        case alerts = "Alerts"
        case metrics = "Metrics"
        case sitters = "Sitters"
        case health = "Health"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .alerts: return "exclamationmark.triangle.fill"
            case .metrics: return "speedometer"
            case .sitters: return "figure.walk"
            case .health: return "heart.fill"
            }
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case lastHour = "Last Hour"
        case last24Hours = "Last 24 Hours"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        
        var color: Color {
            switch self {
            case .lastHour: return .blue
            case .last24Hours: return .green
            case .last7Days: return .orange
            case .last30Days: return .purple
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
                
                // Time Range Selector
                timeRangeSelector
                
                // Main Content
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(MonitoringTab.overview)
                    
                    alertsTab
                        .tag(MonitoringTab.alerts)
                    
                    metricsTab
                        .tag(MonitoringTab.metrics)
                    
                    sittersTab
                        .tag(MonitoringTab.sitters)
                    
                    healthTab
                        .tag(MonitoringTab.health)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Performance Monitoring")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAlertRules = true }) {
                            Label("Alert Rules", systemImage: "bell.badge")
                        }
                        
                        Button(action: { showingSystemHealth = true }) {
                            Label("System Health", systemImage: "heart.fill")
                        }
                        
                        Divider()
                        
                        Button(action: { refreshData() }) {
                            Label("Refresh Data", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: { toggleMonitoring() }) {
                            Label("Start Monitoring", 
                                  systemImage: "play.circle.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    }
                }
            }
            .sheet(isPresented: $showingAlertDetails) {
                if let alert = selectedAlert {
                    AlertDetailView(alert: alert, monitoringService: monitoringService)
                }
            }
            .sheet(isPresented: $showingAlertRules) {
                AlertRulesView(monitoringService: monitoringService)
            }
            .sheet(isPresented: $showingSystemHealth) {
                SystemHealthView(monitoringService: monitoringService)
            }
        }
    }
    
    // MARK: - Header
    
    private var enhancedHeader: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance Monitoring")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.bold)
                    
                    Text("Real-time system and business metrics")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // System status indicator
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    SystemStatusIndicator(status: monitoringService.systemHealth.overallStatus)
                    
                    // Active alerts badge
                    if !monitoringService.performanceAlerts.filter({ $0.status == .active }).isEmpty {
                        AlertBadge(count: monitoringService.performanceAlerts.filter({ $0.status == .active }).count)
                    }
                }
            }
            
            // Real-time metrics
            HStack(spacing: SPDesignSystem.Spacing.m) {
                RealTimeMetricCard(
                    title: "Active Bookings",
                    value: "\(monitoringService.realTimeMetrics.activeBookings)",
                    icon: "calendar",
                    color: .blue
                )
                
                RealTimeMetricCard(
                    title: "Active Sitters",
                    value: "\(monitoringService.realTimeMetrics.activeSitters)",
                    icon: "figure.walk",
                    color: .green
                )
                
                RealTimeMetricCard(
                    title: "Today's Revenue",
                    value: "$\(Int(monitoringService.realTimeMetrics.todayRevenue))",
                    icon: "dollarsign.circle.fill",
                    color: .orange
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(MonitoringTab.allCases, id: \.self) { tab in
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
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SPDesignSystem.Spacing.s) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(action: { selectedTimeRange = range }) {
                        Text(range.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTimeRange == range ? .white : range.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTimeRange == range ? range.color : range.color.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
        }
        .padding(.vertical, SPDesignSystem.Spacing.s)
    }
    
    // MARK: - Tabs
    
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.l) {
                // System metrics overview
                SystemMetricsOverviewCard(metrics: monitoringService.systemMetrics)
                
                // KPI metrics overview
                KPIMetricsOverviewCard(metrics: monitoringService.kpiMetrics)
                
                // Recent alerts
                RecentAlertsCard(alerts: monitoringService.performanceAlerts) { alert in
                    selectedAlert = alert
                    showingAlertDetails = true
                }
                
                // Performance trends
                PerformanceTrendsCard(metrics: monitoringService.kpiMetrics)
            }
            .padding()
        }
    }
    
    private var alertsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(monitoringService.performanceAlerts) { alert in
                    PerformanceAlertCard(alert: alert) {
                        selectedAlert = alert
                        showingAlertDetails = true
                    }
                }
            }
            .padding()
        }
    }
    
    private var metricsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.l) {
                // System metrics charts
                SystemMetricsCharts(metrics: monitoringService.systemMetrics)
                
                // KPI metrics charts
                KPIMetricsCharts(metrics: monitoringService.kpiMetrics)
            }
            .padding()
        }
    }
    
    private var sittersTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(monitoringService.sitterPerformance) { sitter in
                    SitterPerformanceCard(sitter: sitter)
                }
            }
            .padding()
        }
    }
    
    private var healthTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.l) {
                // System health overview
                SystemHealthOverviewCard(health: monitoringService.systemHealth)
                
                // Health metrics
                HealthMetricsCard(health: monitoringService.systemHealth)
                
                // Uptime and availability
                UptimeCard(health: monitoringService.systemHealth)
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshData() {
        isRefreshing = true
        
        Task {
            await monitoringService.updateKPIMetrics()
            await monitoringService.updateSitterPerformance()
            await monitoringService.checkSystemHealth()
            
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
    
    private func toggleMonitoring() {
        monitoringService.startSystemMonitoring()
    }
}

// MARK: - Supporting Views

struct SystemStatusIndicator: View {
    let status: SystemHealth.HealthStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct AlertBadge: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red)
            .cornerRadius(8)
    }
}

struct RealTimeMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(8)
    }
}

struct SystemMetricsOverviewCard: View {
    let metrics: SystemMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("System Metrics")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                PerformanceMetricItem(
                    title: "CPU Usage",
                    value: "\(Int(metrics.cpuUsage))%",
                    color: metrics.cpuUsage > 80 ? .red : .green
                )
                
                PerformanceMetricItem(
                    title: "Memory Usage",
                    value: "\(Int(metrics.memoryUsage))%",
                    color: metrics.memoryUsage > 90 ? .red : .green
                )
                
                PerformanceMetricItem(
                    title: "Network Latency",
                    value: "\(Int(metrics.networkMetrics.latency))ms",
                    color: metrics.networkMetrics.latency > 100 ? .red : .green
                )
                
                PerformanceMetricItem(
                    title: "DB Connections",
                    value: "\(metrics.databaseMetrics.connectionCount)",
                    color: .blue
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct KPIMetricsOverviewCard: View {
    let metrics: KPIMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("KPI Metrics")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                PerformanceMetricItem(
                    title: "Bookings",
                    value: "\(metrics.bookingMetrics.totalBookings)",
                    color: .blue
                )
                
                PerformanceMetricItem(
                    title: "Revenue",
                    value: "$\(Int(metrics.revenueMetrics.dailyRevenue))",
                    color: .green
                )
                
                PerformanceMetricItem(
                    title: "Satisfaction",
                    value: "\(String(format: "%.1f", metrics.customerMetrics.customerSatisfaction))",
                    color: .purple
                )
                
                PerformanceMetricItem(
                    title: "Sitters",
                    value: "\(metrics.sitterMetrics.activeSitters)",
                    color: .orange
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct MetricValue: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct RecentAlertsCard: View {
    let alerts: [PerformanceAlert]
    let onAlertTap: (PerformanceAlert) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Recent Alerts")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            if alerts.isEmpty {
                Text("No recent alerts")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(alerts.prefix(3))) { alert in
                    Button(action: { onAlertTap(alert) }) {
                        HStack {
                            Image(systemName: alert.severity.icon)
                                .foregroundColor(alert.severity.color)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.title)
                                    .font(SPDesignSystem.Typography.footnote())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(alert.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(alert.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(alert.status.color)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct PerformanceTrendsCard: View {
    let metrics: KPIMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Performance Trends")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            // Simplified trend visualization
            HStack(spacing: SPDesignSystem.Spacing.m) {
                TrendItem(
                    title: "Revenue Growth",
                    value: "\(String(format: "%.1f", metrics.revenueMetrics.revenueGrowth))%",
                    trend: .up,
                    color: .green
                )
                
                TrendItem(
                    title: "Customer Retention",
                    value: "\(String(format: "%.1f", metrics.customerMetrics.customerRetentionRate))%",
                    trend: .up,
                    color: .blue
                )
                
                TrendItem(
                    title: "Sitter Utilization",
                    value: "\(String(format: "%.1f", metrics.sitterMetrics.utilizationRate))%",
                    trend: .up,
                    color: .orange
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct TrendItem: View {
    let title: String
    let value: String
    let trend: TrendDirection
    let color: Color
    
    enum TrendDirection {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .stable: return "minus"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Image(systemName: trend.icon)
                    .font(.caption2)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct PerformanceAlertCard: View {
    let alert: PerformanceAlert
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                // Header
                HStack {
                    Image(systemName: alert.severity.icon)
                        .font(.title3)
                        .foregroundColor(alert.severity.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(alert.category.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    Text(alert.status.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(alert.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(alert.status.color.opacity(0.1))
                        .cornerRadius(6)
                }
                
                // Message
                Text(alert.message)
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Timestamp
                Text(formatTimestamp(alert.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(SPDesignSystem.Spacing.m)
            .background(SPDesignSystem.Colors.surface(.light))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SitterPerformanceCard: View {
    let sitter: SitterPerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sitter.sitterName)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Performance Score: \(Int(sitter.performanceScore))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Performance score indicator
                Circle()
                    .fill(performanceScoreColor(sitter.performanceScore))
                    .frame(width: 12, height: 12)
            }
            
            // Metrics
            HStack(spacing: SPDesignSystem.Spacing.m) {
                MetricValue(
                    title: "Rating",
                    value: "\(String(format: "%.1f", sitter.rating))",
                    color: .blue
                )
                
                MetricValue(
                    title: "Completion",
                    value: "\(Int(sitter.completionRate))%",
                    color: .green
                )
                
                MetricValue(
                    title: "Response",
                    value: "\(Int(sitter.responseTime))m",
                    color: .orange
                )
                
                MetricValue(
                    title: "Revenue",
                    value: "$\(Int(sitter.revenueGenerated))",
                    color: .purple
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func performanceScoreColor(_ score: Double) -> Color {
        if score >= 90 { return .green }
        else if score >= 80 { return .orange }
        else { return .red }
    }
}

struct MetricDisplay: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct SystemHealthOverviewCard: View {
    let health: SystemHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("System Health")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall Status")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: health.overallStatus.icon)
                            .font(.title3)
                            .foregroundColor(health.overallStatus.color)
                        
                        Text(health.overallStatus.rawValue.capitalized)
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .foregroundColor(health.overallStatus.color)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Uptime")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                    
                    Text("\(health.uptime, specifier: "%.1f")%")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct HealthMetricsCard: View {
    let health: SystemHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Health Metrics")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                HealthMetricItem(
                    title: "Database",
                    status: health.databaseStatus,
                    icon: "externaldrive.fill"
                )
                
                HealthMetricItem(
                    title: "Network",
                    status: health.networkStatus == .connected ? .healthy : .unhealthy,
                    icon: "network"
                )
                
                HealthMetricItem(
                    title: "API",
                    status: health.apiStatus,
                    icon: "globe"
                )
                
                HealthMetricItem(
                    title: "Storage",
                    status: health.storageStatus,
                    icon: "internaldrive.fill"
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct HealthMetricItem: View {
    let title: String
    let status: SystemHealth.HealthStatus
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(status.color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct UptimeCard: View {
    let health: SystemHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Uptime & Availability")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Uptime")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                    
                    Text("\(health.uptime, specifier: "%.2f")%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Check")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(health.lastCheck))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Chart Components

struct SystemMetricsCharts: View {
    let metrics: SystemMetrics
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // CPU and Memory usage
            AdvancedChartCard(
                title: "System Resource Usage",
                subtitle: "CPU and Memory utilization",
                chartData: [
                    ChartDataPoint(xValue: "CPU", yValue: metrics.cpuUsage, color: .blue),
                    ChartDataPoint(xValue: "Memory", yValue: metrics.memoryUsage, color: .green)
                ],
                chartType: .bar,
                timeRange: .hour
            )
            
            // Network metrics
            AdvancedChartCard(
                title: "Network Performance",
                subtitle: "Latency and packet loss",
                chartData: [
                    ChartDataPoint(xValue: "Latency", yValue: metrics.networkMetrics.latency, color: .orange),
                    ChartDataPoint(xValue: "Packet Loss", yValue: metrics.networkMetrics.packetLoss, color: .red)
                ],
                chartType: .line,
                timeRange: .hour
            )
        }
    }
}

struct KPIMetricsCharts: View {
    let metrics: KPIMetrics
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // Revenue trends
            AdvancedChartCard(
                title: "Revenue Trends",
                subtitle: "Daily, weekly, and monthly revenue",
                chartData: [
                    ChartDataPoint(xValue: "Daily", yValue: metrics.revenueMetrics.dailyRevenue, color: .green),
                    ChartDataPoint(xValue: "Weekly", yValue: metrics.revenueMetrics.weeklyRevenue / 7, color: .blue),
                    ChartDataPoint(xValue: "Monthly", yValue: metrics.revenueMetrics.monthlyRevenue / 30, color: .purple)
                ],
                chartType: .bar,
                timeRange: .day
            )
            
            // Customer satisfaction
            AdvancedChartCard(
                title: "Customer Satisfaction",
                subtitle: "Average customer satisfaction rating",
                chartData: [
                    ChartDataPoint(xValue: "Satisfaction", yValue: metrics.customerMetrics.customerSatisfaction * 20, color: .purple)
                ],
                chartType: .bar,
                timeRange: .day
            )
        }
    }
}
