import SwiftUI
import Charts

// MARK: - Advanced Reporting Dashboard

struct EnhancedReportingDashboard: View {
    @StateObject private var reportingService = AdminReportingService()
    @State private var selectedTab: ReportingTab = .overview
    @State private var selectedTimeRange: TimeRange = .last30Days
    @State private var showingReportGenerator = false
    @State private var showingScheduledReports = false
    @State private var showingExportHistory = false
    @State private var selectedReport: Report?
    @State private var showingReportDetail = false
    
    enum ReportingTab: String, CaseIterable {
        case overview = "Overview"
        case reports = "Reports"
        case analytics = "Analytics"
        case insights = "Insights"
        case templates = "Templates"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .reports: return "doc.text.fill"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .insights: return "lightbulb.fill"
            case .templates: return "doc.richtext.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Header
                reportingHeader
                
                // Tab Selector
                tabSelector
                
                // Time Range Selector
                timeRangeSelector
                
                // Main Content
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(ReportingTab.overview)
                    
                    reportsTab
                        .tag(ReportingTab.reports)
                    
                    analyticsTab
                        .tag(ReportingTab.analytics)
                    
                    insightsTab
                        .tag(ReportingTab.insights)
                    
                    templatesTab
                        .tag(ReportingTab.templates)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Reporting & Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingReportGenerator = true }) {
                            Label("Generate Report", systemImage: "plus.circle.fill")
                        }
                        
                        Button(action: { showingScheduledReports = true }) {
                            Label("Scheduled Reports", systemImage: "clock.fill")
                        }
                        
                        Button(action: { showingExportHistory = true }) {
                            Label("Export History", systemImage: "square.and.arrow.down.fill")
                        }
                        
                        Divider()
                        
                        Button(action: { refreshData() }) {
                            Label("Refresh Data", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    }
                }
            }
            .sheet(isPresented: $showingReportGenerator) {
                ReportGeneratorView(reportingService: reportingService)
            }
            .sheet(isPresented: $showingScheduledReports) {
                ScheduledReportsView(reportingService: reportingService)
            }
            .sheet(isPresented: $showingExportHistory) {
                ExportHistoryView(reportingService: reportingService)
            }
            .sheet(isPresented: $showingReportDetail) {
                if let report = selectedReport {
                    ReportDetailView(report: report, reportingService: reportingService)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var reportingHeader: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reporting & Analytics")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.bold)
                    
                    Text("Comprehensive business intelligence and insights")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick stats
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    QuickStatCard(
                        title: "Reports",
                        value: "\(reportingService.reports.count)",
                        icon: "doc.text.fill",
                        color: .blue
                    )
                    
                    QuickStatCard(
                        title: "Insights",
                        value: "\(reportingService.insights.count)",
                        icon: "lightbulb.fill",
                        color: .orange
                    )
                    
                    QuickStatCard(
                        title: "Exports",
                        value: "\(reportingService.exportHistory.count)",
                        icon: "square.and.arrow.down.fill",
                        color: .green
                    )
                }
            }
            
            // Last updated
            HStack {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Last updated: \(formatLastUpdated(reportingService.analyticsData.lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if reportingService.isGeneratingReport {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ReportingTab.allCases, id: \.self) { tab in
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
                        Text(range.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTimeRange == range ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTimeRange == range ? SPDesignSystem.Colors.primaryAdjusted(.light) : SPDesignSystem.Colors.surface(.light))
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
                // Key metrics overview
                KeyMetricsOverviewCard(analyticsData: reportingService.analyticsData)
                
                // Recent insights
                RecentInsightsCard(insights: reportingService.insights)
                
                // Quick actions
                QuickActionsCard(reportingService: reportingService)
                
                // Recent reports
                RecentReportsCard(reports: reportingService.reports) { report in
                    selectedReport = report
                    showingReportDetail = true
                }
            }
            .padding()
        }
    }
    
    private var reportsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(reportingService.reports) { report in
                    ReportCard(report: report) {
                        selectedReport = report
                        showingReportDetail = true
                    }
                }
            }
            .padding()
        }
    }
    
    private var analyticsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.l) {
                // Analytics overview
                AnalyticsOverviewCard(analyticsData: reportingService.analyticsData)
                
                // Charts and visualizations
                AnalyticsChartsCard(analyticsData: reportingService.analyticsData)
                
                // Performance metrics
                PerformanceMetricsCard(analyticsData: reportingService.analyticsData)
            }
            .padding()
        }
    }
    
    private var insightsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(reportingService.insights) { insight in
                    InsightCard(insight: insight)
                }
            }
            .padding()
        }
    }
    
    private var templatesTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(reportingService.reportTemplates) { template in
                    TemplateCard(template: template, reportingService: reportingService)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshData() {
        Task {
            await reportingService.updateAnalyticsData()
            await reportingService.generateInsights()
        }
    }
    
    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
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

struct KeyMetricsOverviewCard: View {
    let analyticsData: AnalyticsData
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Key Metrics Overview")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                MetricOverviewItem(
                    title: "Total Revenue",
                    value: "$\(Int(analyticsData.revenueAnalytics.totalRevenue))",
                    change: analyticsData.revenueAnalytics.revenueGrowth,
                    color: .green
                )
                
                MetricOverviewItem(
                    title: "Total Bookings",
                    value: "\(analyticsData.bookingAnalytics.totalBookings)",
                    change: 12.5, // Sample growth
                    color: .blue
                )
                
                MetricOverviewItem(
                    title: "Customer Satisfaction",
                    value: "\(analyticsData.customerAnalytics.customerSatisfaction, default: "0.0")",
                    change: 2.3, // Sample improvement
                    color: .orange
                )
                
                MetricOverviewItem(
                    title: "Active Sitters",
                    value: "\(analyticsData.sitterAnalytics.activeSitters)",
                    change: 8.7, // Sample growth
                    color: .purple
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct MetricOverviewItem: View {
    let title: String
    let value: String
    let change: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 2) {
                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                    .foregroundColor(change >= 0 ? .green : .red)
                
                Text("\(abs(change), specifier: "%.1f")%")
                    .font(.caption2)
                    .foregroundColor(change >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct RecentInsightsCard: View {
    let insights: [AnalyticsInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Recent Insights")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            if insights.isEmpty {
                Text("No insights available")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(insights.prefix(3))) { insight in
                    InsightRow(insight: insight)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct InsightRow: View {
    let insight: AnalyticsInsight
    
    var body: some View {
        HStack(alignment: .top, spacing: SPDesignSystem.Spacing.s) {
            Image(systemName: insight.type.icon)
                .font(.caption)
                .foregroundColor(insight.type.color)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(insight.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(insight.priority.rawValue.capitalized)
                .font(.caption2)
                .foregroundColor(insight.priority.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(insight.priority.color.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct QuickActionsCard: View {
    let reportingService: AdminReportingService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Quick Actions")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                QuickActionButton(
                    title: "Generate Report",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    // Action handled by parent
                }
                
                QuickActionButton(
                    title: "Export Data",
                    icon: "square.and.arrow.down.fill",
                    color: .green
                ) {
                    // Action handled by parent
                }
                
                QuickActionButton(
                    title: "Schedule Report",
                    icon: "clock.fill",
                    color: .orange
                ) {
                    // Action handled by parent
                }
                
                QuickActionButton(
                    title: "View Analytics",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                ) {
                    // Action handled by parent
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SPDesignSystem.Spacing.s)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct RecentReportsCard: View {
    let reports: [Report]
    let onReportTap: (Report) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Recent Reports")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            if reports.isEmpty {
                Text("No reports generated yet")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(reports.prefix(3))) { report in
                    Button(action: { onReportTap(report) }) {
                        HStack {
                            Image(systemName: report.type.icon)
                                .font(.title3)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(report.name)
                                    .font(SPDesignSystem.Typography.footnote())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(formatReportDate(report.generatedAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
    
    private func formatReportDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ReportCard: View {
    let report: Report
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                // Header
                HStack {
                    Image(systemName: report.type.icon)
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.name)
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(report.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                
                // Report details
                VStack(spacing: SPDesignSystem.Spacing.s) {
                    ReportDetailRow(
                        title: "Time Range",
                        value: report.timeRange.displayName
                    )
                    
                    ReportDetailRow(
                        title: "Generated",
                        value: formatReportDate(report.generatedAt)
                    )
                    
                    ReportDetailRow(
                        title: "Generated By",
                        value: report.generatedBy
                    )
                }
            }
            .padding(SPDesignSystem.Spacing.m)
            .background(SPDesignSystem.Colors.surface(.light))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatReportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ReportDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct AnalyticsOverviewCard: View {
    let analyticsData: AnalyticsData
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Analytics Overview")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                AnalyticsMetricItem(
                    title: "Bookings",
                    value: "\(analyticsData.bookingAnalytics.totalBookings)",
                    subtitle: "Total",
                    color: .blue
                )
                
                AnalyticsMetricItem(
                    title: "Revenue",
                    value: "$\(Int(analyticsData.revenueAnalytics.totalRevenue))",
                    subtitle: "Total",
                    color: .green
                )
                
                AnalyticsMetricItem(
                    title: "Customers",
                    value: "\(analyticsData.customerAnalytics.totalCustomers)",
                    subtitle: "Active",
                    color: .orange
                )
                
                AnalyticsMetricItem(
                    title: "Sitters",
                    value: "\(analyticsData.sitterAnalytics.activeSitters)",
                    subtitle: "Active",
                    color: .purple
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct AnalyticsMetricItem: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct AnalyticsChartsCard: View {
    let analyticsData: AnalyticsData
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Analytics Charts")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            // Revenue trend chart
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                Text("Revenue Trend")
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Chart(analyticsData.revenueAnalytics.revenueTrends) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Revenue", dataPoint.value)
                    )
                    .foregroundStyle(.green)
                }
                .frame(height: 150)
            }
            
            // Booking distribution chart
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                Text("Service Distribution")
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Chart(analyticsData.bookingAnalytics.serviceDistribution) { service in
                    BarMark(
                        x: .value("Service", service.service),
                        y: .value("Count", service.count)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 150)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct PerformanceMetricsCard: View {
    let analyticsData: AnalyticsData
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Performance Metrics")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                PerformanceMetricItem(
                    title: "System Uptime",
                    value: "\(analyticsData.operationalAnalytics.systemUptime, default: "0.0")%",
                    color: .green
                )
                
                PerformanceMetricItem(
                    title: "Response Time",
                    value: "\(Int(analyticsData.operationalAnalytics.averageResponseTime))ms",
                    color: .blue
                )
                
                PerformanceMetricItem(
                    title: "Error Rate",
                    value: "\(String(format: "%.2f", analyticsData.operationalAnalytics.errorRate))%",
                    color: .orange
                )
                
                PerformanceMetricItem(
                    title: "Efficiency",
                    value: "\(String(format: "%.0f", analyticsData.operationalAnalytics.operationalEfficiency))%",
                    color: .purple
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct PerformanceMetricItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
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

struct InsightCard: View {
    let insight: AnalyticsInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                Image(systemName: insight.type.icon)
                    .font(.title3)
                    .foregroundColor(insight.type.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(insight.category.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Priority indicator
                Text(insight.priority.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(insight.priority.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(insight.priority.color.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Description
            Text(insight.description)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
                .lineLimit(nil)
            
            // Recommendations
            if !insight.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Recommendations")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    ForEach(insight.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: SPDesignSystem.Spacing.s) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.top, 2)
                            
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct TemplateCard: View {
    let template: ReportTemplate
    let reportingService: AdminReportingService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                Image(systemName: template.type.icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(template.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if template.isDefault {
                    Text("Default")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            // Description
            Text(template.description)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
                .lineLimit(nil)
            
            // Fields
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                Text("Fields")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SPDesignSystem.Spacing.s) {
                    ForEach(template.fields, id: \.self) { field in
                        Text(field.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SPDesignSystem.Colors.surface(.light))
                            .cornerRadius(6)
                    }
                }
            }
            
            // Action button
            Button("Generate Report") {
                Task {
                    await reportingService.generateCustomReport(template: template, data: [:])
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(SPDesignSystem.Colors.primaryAdjusted(.light))
            .cornerRadius(8)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}
