import SwiftUI
import Combine

// MARK: - Enhanced Dashboard Layout Manager

class DashboardLayoutManager: ObservableObject {
    @Published var currentLayout: DashboardLayout = .overview
    @Published var customLayouts: [CustomLayout] = []
    @Published var widgetPreferences: [String: WidgetPreference] = [:]
    @Published var isEditingLayout = false
    @Published var selectedWidgets: Set<String> = []
    
    enum DashboardLayout: String, CaseIterable {
        case overview = "overview"
        case analytics = "analytics"
        case operations = "operations"
        case intelligence = "intelligence"
        case custom = "custom"
        
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .analytics: return "Analytics"
            case .operations: return "Operations"
            case .intelligence: return "Intelligence"
            case .custom: return "Custom"
            }
        }
        
        var icon: String {
            switch self {
            case .overview: return "house.fill"
            case .analytics: return "chart.bar.fill"
            case .operations: return "gearshape.fill"
            case .intelligence: return "brain.head.profile"
            case .custom: return "slider.horizontal.3"
            }
        }
        
        var color: Color {
            switch self {
            case .overview: return .blue
            case .analytics: return .green
            case .operations: return .orange
            case .intelligence: return .purple
            case .custom: return .gray
            }
        }
    }
    
    struct CustomLayout: Identifiable, Codable {
        let id = UUID()
        let name: String
        let widgets: [WidgetConfiguration]
        let createdAt: Date
        let isDefault: Bool
        
        struct WidgetConfiguration: Codable {
            let id: String
            let type: WidgetType
            let position: WidgetPosition
            let size: WidgetSize
            let settings: [String: String]
            
            enum WidgetType: String, Codable, CaseIterable {
                case metric = "metric"
                case chart = "chart"
                case insight = "insight"
                case activity = "activity"
                case alert = "alert"
                case calendar = "calendar"
                case map = "map"
                case table = "table"
            }
            
            struct WidgetPosition: Codable {
                let row: Int
                let column: Int
            }
            
            enum WidgetSize: String, Codable, CaseIterable {
                case small = "small"
                case medium = "medium"
                case large = "large"
                case fullWidth = "fullWidth"
            }
        }
    }
    
    struct WidgetPreference: Codable {
        let widgetId: String
        var isVisible: Bool
        let position: Int
        let size: CustomLayout.WidgetConfiguration.WidgetSize
        let refreshInterval: TimeInterval
        let customSettings: [String: String]
    }
    
    func switchLayout(_ layout: DashboardLayout) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentLayout = layout
        }
    }
    
    func createCustomLayout(name: String, widgets: [CustomLayout.WidgetConfiguration]) {
        let layout = CustomLayout(
            name: name,
            widgets: widgets,
            createdAt: Date(),
            isDefault: false
        )
        customLayouts.append(layout)
    }
    
    func updateWidgetPreference(_ preference: WidgetPreference) {
        widgetPreferences[preference.widgetId] = preference
    }
    
    func toggleWidgetVisibility(_ widgetId: String) {
        if var preference = widgetPreferences[widgetId] {
            preference.isVisible.toggle()
            widgetPreferences[widgetId] = preference
        } else {
            widgetPreferences[widgetId] = WidgetPreference(
                widgetId: widgetId,
                isVisible: true,
                position: 0,
                size: .medium,
                refreshInterval: 300,
                customSettings: [:]
            )
        }
    }
}

// MARK: - Enhanced Dashboard Header

struct EnhancedDashboardHeader: View {
    @ObservedObject var layoutManager: DashboardLayoutManager
    @State private var showingLayoutSelector = false
    @State private var showingCustomization = false
    @State private var showingNotifications = false
    @State private var notificationCount = 0
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.m) {
            // Main header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Business Intelligence")
                        .font(SPDesignSystem.Typography.heading1())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Real-time insights and AI-powered recommendations")
                        .font(SPDesignSystem.Typography.body())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    // Layout selector
                    Button(action: { showingLayoutSelector.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: layoutManager.currentLayout.icon)
                                .font(.system(size: 14, weight: .medium))
                            Text(layoutManager.currentLayout.title)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(layoutManager.currentLayout.color)
                        .cornerRadius(8)
                    }
                    
                    // Customization button
                    Button(action: { showingCustomization.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    }
                    
                    // Notifications button
                    Button(action: { showingNotifications.toggle() }) {
                        ZStack {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if notificationCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    
                    // Refresh button
                    Button(action: refreshDashboard) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    }
                }
            }
            
            // Layout selector tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    ForEach(DashboardLayoutManager.DashboardLayout.allCases, id: \.self) { layout in
                        Button(action: { layoutManager.switchLayout(layout) }) {
                            HStack(spacing: 6) {
                                Image(systemName: layout.icon)
                                    .font(.system(size: 12, weight: .medium))
                                Text(layout.title)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(layoutManager.currentLayout == layout ? .white : layout.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(layoutManager.currentLayout == layout ? layout.color : layout.color.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, SPDesignSystem.Spacing.m)
            }
        }
        .padding(.horizontal, SPDesignSystem.Spacing.m)
        .padding(.vertical, SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(.light))
        .sheet(isPresented: $showingLayoutSelector) {
            LayoutSelectorView(layoutManager: layoutManager)
        }
        .sheet(isPresented: $showingCustomization) {
            DashboardCustomizationView(layoutManager: layoutManager)
        }
        .sheet(isPresented: $showingNotifications) {
            AdvancedNotificationCenterView()
        }
    }
    
    private func refreshDashboard() {
        // Implement dashboard refresh logic
    }
}

// MARK: - Layout Selector View

struct LayoutSelectorView: View {
    @ObservedObject var layoutManager: DashboardLayoutManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Default Layouts") {
                    ForEach(DashboardLayoutManager.DashboardLayout.allCases.filter { $0 != .custom }, id: \.self) { layout in
                        HStack {
                            Image(systemName: layout.icon)
                                .foregroundColor(layout.color)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(layout.title)
                                    .font(SPDesignSystem.Typography.body())
                                    .fontWeight(.medium)
                                
                                Text(layoutDescription(layout))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if layoutManager.currentLayout == layout {
                                Image(systemName: "checkmark")
                                    .foregroundColor(layout.color)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            layoutManager.switchLayout(layout)
                            dismiss()
                        }
                    }
                }
                
                if !layoutManager.customLayouts.isEmpty {
                    Section("Custom Layouts") {
                        ForEach(layoutManager.customLayouts) { layout in
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(layout.name)
                                        .font(SPDesignSystem.Typography.body())
                                        .fontWeight(.medium)
                                    
                                    Text("\(layout.widgets.count) widgets")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if layoutManager.currentLayout == .custom {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                layoutManager.switchLayout(.custom)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func layoutDescription(_ layout: DashboardLayoutManager.DashboardLayout) -> String {
        switch layout {
        case .overview: return "Key metrics and quick insights"
        case .analytics: return "Charts and detailed analytics"
        case .operations: return "Operational tools and workflows"
        case .intelligence: return "AI insights and recommendations"
        case .custom: return "Your custom dashboard layout"
        }
    }
}

// MARK: - Dashboard Customization View

struct DashboardCustomizationView: View {
    @ObservedObject var layoutManager: DashboardLayoutManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateLayout = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Widget Management") {
                    ForEach(availableWidgets, id: \.id) { widget in
                        WidgetCustomizationRow(
                            widget: widget,
                            layoutManager: layoutManager
                        )
                    }
                }
                
                Section("Layout Actions") {
                    Button(action: { showingCreateLayout.toggle() }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Create Custom Layout")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if !layoutManager.customLayouts.isEmpty {
                        Button(action: deleteCustomLayouts) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                Text("Delete All Custom Layouts")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Customize Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCreateLayout) {
                CreateCustomLayoutView(layoutManager: layoutManager)
            }
        }
    }
    
    private let availableWidgets = [
        WidgetInfo(id: "revenue_chart", title: "Revenue Chart", description: "Monthly revenue trends"),
        WidgetInfo(id: "booking_metrics", title: "Booking Metrics", description: "Daily booking statistics"),
        WidgetInfo(id: "customer_insights", title: "Customer Insights", description: "Customer satisfaction and feedback"),
        WidgetInfo(id: "sitter_performance", title: "Sitter Performance", description: "Sitter ratings and activity"),
        WidgetInfo(id: "live_activities", title: "Live Activities", description: "Real-time team activities"),
        WidgetInfo(id: "system_alerts", title: "System Alerts", description: "System notifications and alerts")
    ]
    
    private func deleteCustomLayouts() {
        layoutManager.customLayouts.removeAll()
    }
}

struct WidgetInfo {
    let id: String
    let title: String
    let description: String
}

struct WidgetCustomizationRow: View {
    let widget: WidgetInfo
    @ObservedObject var layoutManager: DashboardLayoutManager
    
    private var preference: DashboardLayoutManager.WidgetPreference? {
        layoutManager.widgetPreferences[widget.id]
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(widget.title)
                    .font(SPDesignSystem.Typography.body())
                    .fontWeight(.medium)
                
                Text(widget.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { preference?.isVisible ?? true },
                set: { _ in layoutManager.toggleWidgetVisibility(widget.id) }
            ))
        }
    }
}

// MARK: - Create Custom Layout View

struct CreateCustomLayoutView: View {
    @ObservedObject var layoutManager: DashboardLayoutManager
    @Environment(\.dismiss) private var dismiss
    @State private var layoutName = ""
    @State private var selectedWidgets: Set<String> = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: SPDesignSystem.Spacing.l) {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Layout Name")
                        .font(SPDesignSystem.Typography.footnote())
                        .fontWeight(.semibold)
                    
                    TextField("Enter layout name", text: $layoutName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Select Widgets")
                        .font(SPDesignSystem.Typography.footnote())
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SPDesignSystem.Spacing.s) {
                        ForEach(availableWidgets, id: \.id) { widget in
                            WidgetSelectionCard(
                                widget: widget,
                                isSelected: selectedWidgets.contains(widget.id)
                            ) {
                                if selectedWidgets.contains(widget.id) {
                                    selectedWidgets.remove(widget.id)
                                } else {
                                    selectedWidgets.insert(widget.id)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: createLayout) {
                    Text("Create Layout")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(layoutName.isEmpty || selectedWidgets.isEmpty)
            }
            .padding()
            .navigationTitle("Create Custom Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private let availableWidgets = [
        WidgetInfo(id: "revenue_chart", title: "Revenue Chart", description: "Monthly revenue trends"),
        WidgetInfo(id: "booking_metrics", title: "Booking Metrics", description: "Daily booking statistics"),
        WidgetInfo(id: "customer_insights", title: "Customer Insights", description: "Customer satisfaction"),
        WidgetInfo(id: "sitter_performance", title: "Sitter Performance", description: "Sitter ratings"),
        WidgetInfo(id: "live_activities", title: "Live Activities", description: "Real-time activities"),
        WidgetInfo(id: "system_alerts", title: "System Alerts", description: "System notifications")
    ]
    
    private func createLayout() {
        let widgetConfigs = selectedWidgets.map { widgetId in
            DashboardLayoutManager.CustomLayout.WidgetConfiguration(
                id: widgetId,
                type: .metric,
                position: DashboardLayoutManager.CustomLayout.WidgetConfiguration.WidgetPosition(row: 0, column: 0),
                size: .medium,
                settings: [:]
            )
        }
        
        layoutManager.createCustomLayout(name: layoutName, widgets: widgetConfigs)
        dismiss()
    }
}

struct WidgetSelectionCard: View {
    let widget: WidgetInfo
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                HStack {
                    Text(widget.title)
                        .font(SPDesignSystem.Typography.footnote())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
                
                Text(widget.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(SPDesignSystem.Spacing.s)
            .background(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notification Center View

struct NotificationCenterView: View {
    @State private var notifications: [NotificationItem] = []
    @State private var selectedCategory: NotificationCategory = .all
    @Environment(\.dismiss) private var dismiss
    
    enum NotificationCategory: String, CaseIterable {
        case all = "all"
        case system = "system"
        case alerts = "alerts"
        case updates = "updates"
        
        var title: String {
            switch self {
            case .all: return "All"
            case .system: return "System"
            case .alerts: return "Alerts"
            case .updates: return "Updates"
            }
        }
    }
    
    struct NotificationItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let category: NotificationCategory
        let timestamp: Date
        let isRead: Bool
        let priority: Priority
        
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
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SPDesignSystem.Spacing.s) {
                        ForEach(NotificationCategory.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                Text(category.title)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory == category ? SPDesignSystem.Colors.primaryAdjusted(.light) : Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, SPDesignSystem.Spacing.m)
                }
                .padding(.vertical, SPDesignSystem.Spacing.s)
                
                // Notifications list
                List(filteredNotifications) { notification in
                    NotificationRow(notification: notification)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mark All Read") {
                        markAllAsRead()
                    }
                }
            }
        }
        .onAppear {
            loadNotifications()
        }
    }
    
    private var filteredNotifications: [NotificationItem] {
        if selectedCategory == .all {
            return notifications
        } else {
            return notifications.filter { $0.category == selectedCategory }
        }
    }
    
    private func loadNotifications() {
        // Load sample notifications
        notifications = [
            NotificationItem(
                title: "System Update Available",
                message: "A new system update is available with performance improvements.",
                category: .system,
                timestamp: Date().addingTimeInterval(-3600),
                isRead: false,
                priority: .medium
            ),
            NotificationItem(
                title: "High Booking Volume Alert",
                message: "Booking volume is 40% higher than usual. Consider adding more sitters.",
                category: .alerts,
                timestamp: Date().addingTimeInterval(-1800),
                isRead: false,
                priority: .high
            ),
            NotificationItem(
                title: "Revenue Target Achieved",
                message: "Congratulations! You've achieved this month's revenue target.",
                category: .updates,
                timestamp: Date().addingTimeInterval(-7200),
                isRead: true,
                priority: .low
            )
        ]
    }
    
    private func markAllAsRead() {
        notifications = notifications.map { notification in
            NotificationItem(
                title: notification.title,
                message: notification.message,
                category: notification.category,
                timestamp: notification.timestamp,
                isRead: true,
                priority: notification.priority
            )
        }
    }
}

struct NotificationRow: View {
    let notification: NotificationCenterView.NotificationItem
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            // Priority indicator
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
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(notification.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }
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
