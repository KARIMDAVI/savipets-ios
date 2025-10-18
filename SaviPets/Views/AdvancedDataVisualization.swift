import SwiftUI
import Charts

// MARK: - Advanced Data Visualization Components

struct AdvancedChartCard: View {
    let title: String
    let subtitle: String
    let chartData: [ChartDataPoint]
    let chartType: ChartType
    let timeRange: TimeRange
    
    enum ChartType: String, CaseIterable {
        case line = "line"
        case bar = "bar"
        case area = "area"
        case pie = "pie"
        case scatter = "scatter"
        
        var icon: String {
            switch self {
            case .line: return "chart.line.uptrend.xyaxis"
            case .bar: return "chart.bar.fill"
            case .area: return "chart.xyaxis.line"
            case .pie: return "chart.pie.fill"
            case .scatter: return "chart.scatter"
            }
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case hour = "hour"
        case day = "day"
        case week = "week"
        case month = "month"
        case quarter = "quarter"
        case year = "year"
        
        var color: Color {
            switch self {
            case .hour: return .blue
            case .day: return .green
            case .week: return .orange
            case .month: return .purple
            case .quarter: return .red
            case .year: return .cyan
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                    
                    Text(subtitle)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Chart type indicator
                HStack(spacing: 4) {
                    Image(systemName: chartType.icon)
                        .font(.caption)
                    Text(chartType.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(timeRange.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(timeRange.color.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Simplified chart placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: chartType.icon)
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        Text("\(chartType.rawValue.capitalized) Chart")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(chartData.count) data points")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                )
            
            // Summary statistics
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(chartData.reduce(0) { $0 + $1.yValue }))")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Average")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(chartData.reduce(0) { $0 + $1.yValue } / Double(chartData.count)))")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

// MARK: - Chart Data Point

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let xValue: String
    let yValue: Double
    let color: Color
    let label: String?
    
    init(xValue: String, yValue: Double, color: Color = .blue, label: String? = nil) {
        self.xValue = xValue
        self.yValue = yValue
        self.color = color
        self.label = label
    }
}

// MARK: - Interactive Metric Card

struct InteractiveMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: TrendData?
    let action: () -> Void
    
    struct TrendData {
        let value: Double
        let period: String
        let isPositive: Bool
    }
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    if let trend = trend {
                        HStack(spacing: 4) {
                            Image(systemName: trend.isPositive ? "arrow.up" : "arrow.down")
                                .font(.caption)
                            Text("\(trend.value, specifier: "%.1f")%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(trend.isPositive ? .green : .red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((trend.isPositive ? Color.green : Color.red).opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(SPDesignSystem.Typography.footnote())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let trend = trend {
                    Text(trend.period)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(SPDesignSystem.Spacing.m)
            .background(SPDesignSystem.Colors.surface(.light))
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {
            // Long press action
        })
    }
}

// MARK: - Advanced Smart Insight Card

struct AdvancedSmartInsightCard: View {
    let insight: InsightData
    let action: (() -> Void)?
    @State private var isExpanded = false
    
    struct InsightData {
        let title: String
        let description: String
        let type: InsightType
        let priority: Priority
        let metrics: [MetricData]
        let recommendations: [String]
        
        enum InsightType: String, CaseIterable {
            case performance = "performance"
            case revenue = "revenue"
            case customer = "customer"
            case operational = "operational"
            case security = "security"
            
            var icon: String {
                switch self {
                case .performance: return "speedometer"
                case .revenue: return "dollarsign.circle"
                case .customer: return "person.2.fill"
                case .operational: return "gearshape.fill"
                case .security: return "shield.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .performance: return .blue
                case .revenue: return .green
                case .customer: return .orange
                case .operational: return .purple
                case .security: return .red
                }
            }
        }
        
        enum Priority: String, CaseIterable {
            case low = "low"
            case medium = "medium"
            case high = "high"
            case critical = "critical"
            
            var color: Color {
                switch self {
                case .low: return .gray
                case .medium: return .blue
                case .high: return .orange
                case .critical: return .red
                }
            }
        }
        
        struct MetricData {
            let name: String
            let value: String
            let change: Double?
            let isPositive: Bool?
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    Image(systemName: insight.type.icon)
                        .font(.title3)
                        .foregroundColor(insight.type.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(insight.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Priority indicator
                Circle()
                    .fill(insight.priority.color)
                    .frame(width: 12, height: 12)
            }
            
            // Description
            Text(insight.description)
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
            
            // Metrics
            if !insight.metrics.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SPDesignSystem.Spacing.s) {
                    ForEach(insight.metrics.indices, id: \.self) { index in
                        let metric = insight.metrics[index]
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Text(metric.value)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if let change = metric.change, let isPositive = metric.isPositive {
                                    HStack(spacing: 2) {
                                        Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                                            .font(.caption2)
                                        Text("\(change, specifier: "%.1f")%")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(isPositive ? .green : .red)
                                }
                            }
                        }
                        .padding(SPDesignSystem.Spacing.s)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Recommendations
            if isExpanded && !insight.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Recommendations")
                        .font(SPDesignSystem.Typography.footnote())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(insight.recommendations.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: SPDesignSystem.Spacing.s) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(insight.type.color)
                            
                            Text(insight.recommendations[index])
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Expand/Collapse button
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(insight.type.color)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Enhanced Dashboard Layout Components

struct DashboardGrid: View {
    let items: [DashboardItem]
    let columns: Int
    
    struct DashboardItem {
        let title: String
        let content: AnyView
        let size: WidgetSize
        let priority: Int
        
        enum WidgetSize {
            case small
            case medium
            case large
            case fullWidth
        }
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: SPDesignSystem.Spacing.m) {
            ForEach(items.sorted(by: { $0.priority < $1.priority }), id: \.title) { item in
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text(item.title)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    item.content
                }
                .padding(SPDesignSystem.Spacing.m)
                .background(SPDesignSystem.Colors.surface(.light))
                .cornerRadius(12)
                .frame(maxWidth: item.size == .fullWidth ? .infinity : .infinity)
            }
        }
    }
}

struct ResponsiveCard: View {
    let title: String
    let content: AnyView
    let actions: [CardAction]
    
    struct CardAction {
        let title: String
        let icon: String
        let action: () -> Void
        let style: ActionStyle
        
        enum ActionStyle {
            case primary
            case secondary
            case destructive
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.m) {
            Text(title)
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            content
            
            if !actions.isEmpty {
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    ForEach(actions.indices, id: \.self) { index in
                        let action = actions[index]
                        Button(action: action.action) {
                            HStack(spacing: 4) {
                                Image(systemName: action.icon)
                                    .font(.caption)
                                Text(action.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(action.style == .primary ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(action.style == .primary ? SPDesignSystem.Colors.primaryAdjusted(.light) : Color(.systemGray6))
                            .cornerRadius(6)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

// MARK: - Advanced Filter Bar

struct AdvancedFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilters: Set<FilterOption>
    let availableFilters: [FilterOption]
    
    struct FilterOption: Hashable {
        let title: String
        let icon: String
        let category: FilterCategory
        
        enum FilterCategory: String, CaseIterable {
            case status = "status"
            case date = "date"
            case type = "type"
            case priority = "priority"
            case user = "user"
            
            var color: Color {
                switch self {
                case .status: return .blue
                case .date: return .green
                case .type: return .orange
                case .priority: return .red
                case .user: return .purple
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search...", text: $searchText)
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
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    ForEach(availableFilters, id: \.title) { filter in
                        AdvancedFilterChip(
                            filter: filter,
                            isSelected: selectedFilters.contains(filter),
                            action: {
                                if selectedFilters.contains(filter) {
                                    selectedFilters.remove(filter)
                                } else {
                                    selectedFilters.insert(filter)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, SPDesignSystem.Spacing.m)
            }
        }
    }
}

struct AdvancedFilterChip: View {
    let filter: AdvancedFilterBar.FilterOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)
                
                Text(filter.title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
            }
            .foregroundColor(isSelected ? .white : filter.category.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? filter.category.color : filter.category.color.opacity(0.1))
            .cornerRadius(6)
        }
    }
}

struct FilterSelectionView: View {
    @Binding var selectedFilters: Set<AdvancedFilterBar.FilterOption>
    let availableFilters: [AdvancedFilterBar.FilterOption]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AdvancedFilterBar.FilterOption.FilterCategory.allCases, id: \.self) { category in
                    Section(category.rawValue.capitalized) {
                        ForEach(filtersForCategory(category), id: \.title) { filter in
                            FilterRow(
                                filter: filter,
                                isSelected: selectedFilters.contains(filter),
                                onTap: {
                                    toggleFilter(filter)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { dismiss() }
                }
            }
        }
    }
    
    private func filtersForCategory(_ category: AdvancedFilterBar.FilterOption.FilterCategory) -> [AdvancedFilterBar.FilterOption] {
        return availableFilters.filter { $0.category == category }
    }
    
    private func toggleFilter(_ filter: AdvancedFilterBar.FilterOption) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
    }
}

struct FilterRow: View {
    let filter: AdvancedFilterBar.FilterOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: filter.icon)
                .foregroundColor(filter.category.color)
            
            Text(filter.title)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(filter.category.color)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Enhanced Dashboard Header

struct AdvancedDashboardHeader: View {
    @ObservedObject var layoutManager: DashboardLayoutManager
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Business Intelligence")
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                    
                    Text("Real-time insights and analytics")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    Button(action: { /* AI Insights */ }) {
                        Image(systemName: "brain.head.profile")
                            .font(.title3)
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    }
                    
                    Button(action: { /* Alerts */ }) {
                        Image(systemName: "bell.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: { /* Refresh */ }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Layout selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    ForEach(DashboardLayoutManager.DashboardLayout.allCases, id: \.self) { layout in
                        Button(action: { layoutManager.switchLayout(layout) }) {
                            VStack(spacing: 4) {
                                Image(systemName: layout.icon)
                                    .font(.title3)
                                
                                Text(layout.rawValue.capitalized)
                                    .font(.caption)
                            }
                            .foregroundColor(layoutManager.currentLayout == layout ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(layoutManager.currentLayout == layout ? SPDesignSystem.Colors.primaryAdjusted(.light) : Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, SPDesignSystem.Spacing.m)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
    }
}

// MARK: - Notification Center

struct AdvancedNotificationCenterView: View {
    @State private var selectedCategory: NotificationCategory = .all
    @State private var notifications: [NotificationItem] = []
    
    enum NotificationCategory: String, CaseIterable {
        case all = "All"
        case system = "System"
        case alerts = "Alerts"
        case updates = "Updates"
        
        var icon: String {
            switch self {
            case .all: return "bell.fill"
            case .system: return "gearshape.fill"
            case .alerts: return "exclamationmark.triangle.fill"
            case .updates: return "arrow.clockwise"
            }
        }
    }
    
    struct NotificationItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let category: NotificationCategory
        let priority: Priority
        let timestamp: Date
        let isRead: Bool
        
        enum Priority {
            case low, medium, high, critical
            
            var color: Color {
                switch self {
                case .low: return .gray
                case .medium: return .blue
                case .high: return .orange
                case .critical: return .red
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category selector
            HStack(spacing: 0) {
                ForEach(NotificationCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        VStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.title3)
                            
                            Text(category.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SPDesignSystem.Spacing.s)
                        .background(selectedCategory == category ? SPDesignSystem.Colors.primaryAdjusted(.light) : Color.clear)
                    }
                }
            }
            .background(Color(.systemGray6))
            
            // Notifications list
            List(filteredNotifications) { notification in
                AdvancedNotificationRow(notification: notification)
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Mark All Read") {
                    // Mark all as read
                }
            }
        }
    }
    
    private var filteredNotifications: [NotificationItem] {
        if selectedCategory == .all {
            return notifications
        }
        return notifications.filter { $0.category == selectedCategory }
    }
}

struct AdvancedNotificationRow: View {
    let notification: AdvancedNotificationCenterView.NotificationItem
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            Circle()
                .fill(notification.priority.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(formatTime(notification.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(SPDesignSystem.Colors.primaryAdjusted(.light))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Sample Data Extensions

extension AdvancedSmartInsightCard.InsightData {
    static func sampleInsights() -> [AdvancedSmartInsightCard.InsightData] {
        return [
            AdvancedSmartInsightCard.InsightData(
                title: "Revenue Growth Opportunity",
                description: "Your weekend bookings are 25% lower than weekdays. Consider promoting weekend specials to increase revenue.",
                type: .revenue,
                priority: .high,
                metrics: [
                    AdvancedSmartInsightCard.InsightData.MetricData(name: "Weekday Avg", value: "45 bookings", change: 12.5, isPositive: true),
                    AdvancedSmartInsightCard.InsightData.MetricData(name: "Weekend Avg", value: "34 bookings", change: -8.2, isPositive: false)
                ],
                recommendations: [
                    "Create weekend promotion campaigns",
                    "Offer discounted weekend packages",
                    "Target weekend-specific marketing"
                ]
            ),
            AdvancedSmartInsightCard.InsightData(
                title: "Customer Satisfaction Alert",
                description: "Recent customer feedback shows a 15% decrease in satisfaction scores. Immediate attention recommended.",
                type: .customer,
                priority: .critical,
                metrics: [
                    AdvancedSmartInsightCard.InsightData.MetricData(name: "Current Score", value: "4.2/5", change: -15.0, isPositive: false),
                    AdvancedSmartInsightCard.InsightData.MetricData(name: "Previous Score", value: "4.8/5", change: nil, isPositive: nil)
                ],
                recommendations: [
                    "Review recent service quality issues",
                    "Implement customer feedback system",
                    "Schedule team training sessions"
                ]
            )
        ]
    }
}

extension ChartDataPoint {
    static func sampleRevenueData() -> [ChartDataPoint] {
        return [
            ChartDataPoint(xValue: "Jan", yValue: 12000, color: .green),
            ChartDataPoint(xValue: "Feb", yValue: 15000, color: .green),
            ChartDataPoint(xValue: "Mar", yValue: 18000, color: .green),
            ChartDataPoint(xValue: "Apr", yValue: 16000, color: .orange),
            ChartDataPoint(xValue: "May", yValue: 20000, color: .green),
            ChartDataPoint(xValue: "Jun", yValue: 22000, color: .green)
        ]
    }
    
    static func sampleBookingData() -> [ChartDataPoint] {
        return [
            ChartDataPoint(xValue: "Mon", yValue: 45, color: .blue),
            ChartDataPoint(xValue: "Tue", yValue: 52, color: .blue),
            ChartDataPoint(xValue: "Wed", yValue: 48, color: .blue),
            ChartDataPoint(xValue: "Thu", yValue: 55, color: .blue),
            ChartDataPoint(xValue: "Fri", yValue: 60, color: .blue),
            ChartDataPoint(xValue: "Sat", yValue: 35, color: .orange),
            ChartDataPoint(xValue: "Sun", yValue: 30, color: .orange)
        ]
    }
}