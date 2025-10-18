import SwiftUI
import Charts
import OSLog

struct AdminAnalyticsDashboardView: View {
    @StateObject private var analyticsService = BookingAnalyticsService()
    @State private var selectedTimeframe: AnalyticsTimeframe = .last30Days
    @State private var selectedMetric: AnalyticsMetric = .overview
    @State private var showExportSheet: Bool = false
    
    enum AnalyticsMetric: String, CaseIterable {
        case overview = "Overview"
        case revenue = "Revenue"
        case performance = "Performance"
        case trends = "Trends"
        case insights = "Insights"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with timeframe selector
                AnalyticsHeaderView(
                    selectedTimeframe: $selectedTimeframe,
                    selectedMetric: $selectedMetric,
                    lastUpdated: analyticsService.lastUpdated,
                    isCollecting: analyticsService.isCollecting
                )
                
                // Main content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedMetric {
                        case .overview:
                            OverviewMetricsView(analytics: analyticsService.analyticsData)
                        case .revenue:
                            RevenueAnalyticsView(analytics: analyticsService.analyticsData)
                        case .performance:
                            PerformanceAnalyticsView(analytics: analyticsService.analyticsData)
                        case .trends:
                            TrendsAnalyticsView(analytics: analyticsService.analyticsData)
                        case .insights:
                            InsightsAnalyticsView(analytics: analyticsService.analyticsData)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Analytics Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export Data") {
                            showExportSheet = true
                        }
                        
                        Button("Refresh") {
                            Task {
                                await analyticsService.getAnalytics(timeframe: selectedTimeframe)
                            }
                        }
                        
                        Button("Settings") {
                            // Analytics settings
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportAnalyticsSheet(analyticsService: analyticsService)
            }
        }
        .onAppear {
            Task {
                await analyticsService.getAnalytics(timeframe: selectedTimeframe)
            }
        }
        .onChange(of: selectedTimeframe) { newTimeframe in
            Task {
                await analyticsService.getAnalytics(timeframe: newTimeframe)
            }
        }
    }
}

// MARK: - Analytics Header
private struct AnalyticsHeaderView: View {
    @Binding var selectedTimeframe: AnalyticsTimeframe
    @Binding var selectedMetric: AdminAnalyticsDashboardView.AnalyticsMetric
    let lastUpdated: Date?
    let isCollecting: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Timeframe selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnalyticsTimeframe.allCases, id: \.rawValue) { timeframe in
                        TimeframeChip(
                            timeframe: timeframe,
                            isSelected: selectedTimeframe == timeframe,
                            onTap: { selectedTimeframe = timeframe }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Metric selector
            Picker("Metric", selection: $selectedMetric) {
                ForEach(AdminAnalyticsDashboardView.AnalyticsMetric.allCases, id: \.id) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Status indicator
            HStack {
                if isCollecting {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Collecting data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let lastUpdated = lastUpdated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
}

private struct TimeframeChip: View {
    let timeframe: AnalyticsTimeframe
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(timeframe.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Overview Metrics
private struct OverviewMetricsView: View {
    let analytics: BookingAnalytics
    
    var body: some View {
        VStack(spacing: 16) {
            // Key metrics grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                MetricCard(
                    title: "Total Bookings",
                    value: "\(analytics.totalBookings)",
                    icon: "calendar.badge.plus",
                    color: .blue
                )
                
                MetricCard(
                    title: "Total Revenue",
                    value: "$\(String(format: "%.0f", analytics.averageBookingValue * Double(analytics.totalBookings)))",
                    icon: "dollarsign.circle",
                    color: .green
                )
                
                MetricCard(
                    title: "Completion Rate",
                    value: "\(Int(Double(analytics.completedBookings) / Double(analytics.totalBookings) * 100))%",
                    icon: "checkmark.circle",
                    color: .green
                )
                
                MetricCard(
                    title: "Avg. Booking Value",
                    value: "$\(String(format: "%.0f", analytics.averageBookingValue))",
                    icon: "chart.bar",
                    color: .orange
                )
            }
            
            // Service type breakdown placeholder
            EmptyView() // Placeholder since service type breakdown not available
            
            // Status distribution placeholder
            EmptyView() // Placeholder since status breakdown not available
        }
    }
}

// MARK: - Revenue Analytics
private struct RevenueAnalyticsView: View {
    let analytics: BookingAnalytics
    
    var body: some View {
        VStack(spacing: 16) {
            // Revenue metrics
            VStack(spacing: 12) {
                MetricCard(
                    title: "Total Revenue",
                    value: "$\(String(format: "%.2f", analytics.averageBookingValue * Double(analytics.totalBookings)))",
                    icon: "dollarsign.circle.fill",
                    color: .green,
                    isLarge: true
                )
                
                HStack(spacing: 12) {
                    MetricCard(
                        title: "Avg. Value",
                        value: "$\(String(format: "%.2f", analytics.averageBookingValue))",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Growth",
                        value: "0.0%", // Placeholder since trends don't exist
                        icon: "arrow.up.right",
                        color: .green // Default to positive
                    )
                }
            }
            
            // Revenue by service type
            if !analytics.serviceDistribution.isEmpty {
                RevenueByServiceView(analytics: analytics)
            }
            
            // Revenue trends placeholder
            EmptyView() // Placeholder since trends not available
        }
    }
}

// MARK: - Performance Analytics
private struct PerformanceAnalyticsView: View {
    let analytics: BookingAnalytics
    
    var body: some View {
        VStack(spacing: 16) {
            // Performance metrics
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                PerformanceMetricCard(
                    title: "Completion Rate",
                    value: Double(analytics.completedBookings) / Double(max(analytics.totalBookings, 1)),
                    icon: "checkmark.circle.fill",
                    color: .green,
                    format: .percentage
                )
                
                PerformanceMetricCard(
                    title: "Cancellation Rate",
                    value: Double(analytics.cancelledBookings) / Double(analytics.totalBookings),
                    icon: "xmark.circle.fill",
                    color: .red,
                    format: .percentage
                )
                
                PerformanceMetricCard(
                    title: "Reschedule Rate",
                    value: 0.0, // Placeholder since reschedule rate not available
                    icon: "arrow.clockwise.circle.fill",
                    color: .orange,
                    format: .percentage
                )
                
                PerformanceMetricCard(
                    title: "Avg. Frequency",
                    value: 0.0, // Placeholder since average booking frequency not available
                    icon: "repeat.circle.fill",
                    color: .blue,
                    format: .decimal
                )
            }
            
            // Hourly distribution
            // Hourly distribution placeholder
            EmptyView() // Placeholder since hourly distribution not available
            
            // Daily distribution placeholder
            EmptyView() // Placeholder since daily distribution not available
        }
    }
}

// MARK: - Trends Analytics
private struct TrendsAnalyticsView: View {
    let analytics: BookingAnalytics
    
    var body: some View {
        VStack(spacing: 16) {
            // Growth trends
            VStack(spacing: 12) {
                Text("Growth Trends")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    TrendCard(
                        title: "Weekly",
                        value: 0.0, // Sample value since trends don't exist
                        icon: "calendar"
                    )
                    
                    TrendCard(
                        title: "Monthly",
                        value: 0.0, // Sample value since trends don't exist
                        icon: "calendar.badge.clock"
                    )
                    
                    TrendCard(
                        title: "Revenue",
                        value: 0.0, // Sample value since trends don't exist
                        icon: "dollarsign"
                    )
                }
            }
            
            // Peak times
            PeakTimesView(
                peakHours: [], // Empty since trends don't exist
                peakDays: [] // Empty since trends don't exist
            )
        }
    }
}

// MARK: - Insights Analytics
private struct InsightsAnalyticsView: View {
    let analytics: BookingAnalytics
    
    var body: some View {
        VStack(spacing: 16) {
            if true { // Always show empty state since insights not available
                EmptyInsightsView()
            } else {
                // Empty ForEach since insights not available
                EmptyView()
            }
        }
    }
}

// MARK: - Supporting Views
private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isLarge: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(isLarge ? .title2 : .title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(isLarge ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

private struct PerformanceMetricCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    let format: ValueFormat
    
    enum ValueFormat {
        case percentage
        case decimal
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formattedValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var formattedValue: String {
        switch format {
        case .percentage:
            return "\(Int(value * 100))%"
        case .decimal:
            return String(format: "%.1f", value)
        }
    }
}

private struct TrendCard: View {
    let title: String
    let value: Double
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: value >= 0 ? "arrow.up" : "arrow.down")
                    .foregroundColor(value >= 0 ? .green : .red)
                    .font(.caption)
                
                Text("\(String(format: "%.1f", abs(value)))%")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(value >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

private struct AdminInsightCard: View {
    let insight: AnalyticsInsight
    
    var body: some View {
        HStack(spacing: 12) {
            // Insight type icon
            Image(systemName: iconForInsightType)
                .foregroundColor(colorForInsightType)
                .font(.title3)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(insight.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForInsightType.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var iconForInsightType: String {
        switch insight.type {
        case .insight: return "checkmark.circle.fill"
        case .opportunity: return "lightbulb.fill"
        case .alert: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    private var colorForInsightType: Color {
        switch insight.type {
        case .insight: return .green
        case .opportunity: return .blue
        case .alert: return .orange
        case .info: return .blue
        }
    }
}

// MARK: - Chart Views
private struct ServiceTypeBreakdownView: View {
    let breakdown: [String: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Type Breakdown")
                .font(.headline)
            
            if breakdown.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(breakdown.sorted { $0.value > $1.value }), id: \.key) { service, count in
                        HStack {
                            Text(service)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            // Progress bar
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                    .overlay(
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(width: geometry.size.width * CGFloat(count) / CGFloat(breakdown.values.max() ?? 1))
                                            .cornerRadius(4),
                                        alignment: .leading
                                    )
                            }
                            .frame(width: 60, height: 8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

private struct StatusDistributionView: View {
    let breakdown: [String: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Distribution")
                .font(.headline)
            
            if breakdown.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(Array(breakdown), id: \.key) { status, count in
                        HStack {
                            Circle()
                                .fill(colorForStatus(status))
                                .frame(width: 12, height: 12)
                            
                            Text(status.capitalized)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed": return .green
        case "pending": return .orange
        case "cancelled": return .red
        case "approved": return .blue
        default: return .gray
        }
    }
}

// MARK: - Additional Chart Views (Placeholders)
private struct RevenueByServiceView: View {
    let analytics: BookingAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue by Service Type")
                .font(.headline)
            
            Text("Chart visualization would go here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

private struct RevenueTrendsView: View {
    let trends: BookingAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue Trends")
                .font(.headline)
            
            Text("Revenue trend chart would go here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

private struct HourlyDistributionView: View {
    let distribution: [Int: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly Distribution")
                .font(.headline)
            
            Text("Hourly distribution chart would go here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

private struct DailyDistributionView: View {
    let distribution: [String: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Distribution")
                .font(.headline)
            
            Text("Daily distribution chart would go here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

private struct PeakTimesView: View {
    let peakHours: [Int]
    let peakDays: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Peak Times")
                .font(.headline)
            
            VStack(spacing: 8) {
                if !peakHours.isEmpty {
                    HStack {
                        Text("Peak Hours:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(peakHours.map { "\($0):00" }.joined(separator: ", "))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                if !peakDays.isEmpty {
                    HStack {
                        Text("Peak Days:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(peakDays.joined(separator: ", "))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

private struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Insights Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Analytics insights will appear here as we collect more data about your booking patterns.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Export Sheet
private struct ExportAnalyticsSheet: View {
    let analyticsService: BookingAnalyticsService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Export Analytics Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose the format for exporting your analytics data")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    AdminExportOptionButton(
                        title: "CSV Format",
                        description: "Export data in CSV format for spreadsheet applications",
                        icon: "tablecells"
                    )
                    
                    AdminExportOptionButton(
                        title: "JSON Format",
                        description: "Export data in JSON format for developers",
                        icon: "curlybraces"
                    )
                    
                    AdminExportOptionButton(
                        title: "PDF Report",
                        description: "Generate a formatted PDF report",
                        icon: "doc.text"
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AdminExportOptionButton: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        Button(action: {
            // Export functionality would go here
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview
#Preview {
    AdminAnalyticsDashboardView()
}
