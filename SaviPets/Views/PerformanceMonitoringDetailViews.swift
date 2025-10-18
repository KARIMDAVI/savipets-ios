import SwiftUI

// MARK: - Alert Detail View

struct AlertDetailView: View {
    let alert: PerformanceAlert
    let monitoringService: AdminPerformanceMonitoringService
    @Environment(\.dismiss) private var dismiss
    @State private var showingResolutionForm = false
    @State private var resolutionNotes = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.l) {
                    // Alert header
                    alertHeader
                    
                    // Alert details
                    alertDetails
                    
                    // Resolution section
                    resolutionSection
                    
                    // Related metrics
                    relatedMetrics
                }
                .padding()
            }
            .navigationTitle("Alert Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if alert.status == .active {
                        Button("Resolve") {
                            showingResolutionForm = true
                        }
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                    }
                }
            }
            .sheet(isPresented: $showingResolutionForm) {
                AlertResolutionForm(
                    alert: alert,
                    monitoringService: monitoringService,
                    resolutionNotes: $resolutionNotes
                )
            }
        }
    }
    
    private var alertHeader: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: alert.severity.icon)
                    .font(.largeTitle)
                    .foregroundColor(alert.severity.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(alert.category.rawValue.capitalized)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                Text(alert.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(alert.status.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(alert.status.color.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text(alert.message)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private var alertDetails: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Alert Details")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            VStack(spacing: SPDesignSystem.Spacing.s) {
                PerformanceDetailRow(
                    title: "Severity",
                    value: alert.severity.rawValue.capitalized,
                    color: alert.severity.color
                )
                
                PerformanceDetailRow(
                    title: "Created",
                    value: formatDate(alert.createdAt),
                    color: .primary
                )
                
                PerformanceDetailRow(
                    title: "Last Updated",
                    value: formatDate(alert.createdAt),
                    color: .primary
                )
                
                PerformanceDetailRow(
                    title: "Threshold",
                    value: "N/A", // Placeholder since threshold not available
                    color: .secondary
                )
                
                PerformanceDetailRow(
                    title: "Current Value",
                    value: "N/A", // Placeholder since current value not available
                    color: .primary
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private var resolutionSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Resolution")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            if alert.status == .resolved {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    PerformanceDetailRow(
                        title: "Resolved At",
                        value: formatDate(alert.resolvedAt ?? Date()),
                        color: .green
                    )
                    
                    if !alert.message.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resolution Notes")
                                .font(SPDesignSystem.Typography.footnote())
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            Text(alert.message)
                                .font(SPDesignSystem.Typography.footnote())
                                .foregroundColor(.primary)
                        }
                    }
                }
            } else {
                Text("This alert is currently active and requires attention.")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private var relatedMetrics: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Related Metrics")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            // Show related metrics based on alert category
            switch alert.category {
            case .system:
                SystemMetricsCard(metrics: monitoringService.systemMetrics)
            case .performance:
                KPIMetricsCard(metrics: monitoringService.kpiMetrics)
            case .sitter:
                SitterMetricsCard(sitters: monitoringService.sitterPerformance)
            case .customer:
                CustomerMetricsCard(metrics: monitoringService.kpiMetrics.customerMetrics)
            case .revenue:
                EmptyView() // Placeholder since revenue metrics not available
            case .booking:
                EmptyView() // Placeholder since booking metrics not available
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct PerformanceDetailRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(SPDesignSystem.Typography.footnote())
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Alert Resolution Form

struct AlertResolutionForm: View {
    let alert: PerformanceAlert
    let monitoringService: AdminPerformanceMonitoringService
    @Binding var resolutionNotes: String
    @Environment(\.dismiss) private var dismiss
    @State private var isResolving = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: SPDesignSystem.Spacing.l) {
                // Alert summary
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Resolve Alert")
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                    
                    Text(alert.title)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Resolution notes
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Resolution Notes")
                        .font(SPDesignSystem.Typography.footnote())
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $resolutionNotes)
                        .frame(minHeight: 100)
                        .padding(SPDesignSystem.Spacing.s)
                        .background(SPDesignSystem.Colors.surface(.light))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(SPDesignSystem.Colors.surface(.light))
                    .cornerRadius(8)
                    
                    Button("Resolve Alert") {
                        resolveAlert()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                    .cornerRadius(8)
                    .disabled(isResolving || resolutionNotes.isEmpty)
                }
            }
            .padding()
            .navigationTitle("Resolve Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func resolveAlert() {
        isResolving = true
        
        Task {
            try await monitoringService.resolveAlert(alert.id, resolution: resolutionNotes)
            
            await MainActor.run {
                isResolving = false
                dismiss()
            }
        }
    }
}

// MARK: - Alert Rules View

struct AlertRulesView: View {
    let monitoringService: AdminPerformanceMonitoringService
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddRule = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Alert Rules")
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                    
                    Text("Configure automated alerts for system and business metrics")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Rules list
                ScrollView {
                    LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                        ForEach(monitoringService.alertRules) { rule in
                            AlertRuleCard(rule: rule)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Alert Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Rule") {
                        showingAddRule = true
                    }
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                }
            }
            .sheet(isPresented: $showingAddRule) {
                AddAlertRuleView(monitoringService: monitoringService)
            }
        }
    }
}

struct AlertRuleCard: View {
    let rule: AlertRule
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.name)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(rule.metric.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(rule.isEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            
            // Rule details
            VStack(spacing: SPDesignSystem.Spacing.s) {
                RuleDetailRow(
                    title: "Condition",
                    value: "\(rule.operator.rawValue.capitalized) \(rule.threshold)"
                )
                
                RuleDetailRow(
                    title: "Severity",
                    value: rule.severity.rawValue.capitalized
                )
                
                RuleDetailRow(
                    title: "Cooldown",
                    value: "0 minutes" // Placeholder since cooldown not available
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct RuleDetailRow: View {
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

// MARK: - Add Alert Rule View

struct AddAlertRuleView: View {
    let monitoringService: AdminPerformanceMonitoringService
    @Environment(\.dismiss) private var dismiss
    @State private var ruleName = ""
    @State private var selectedMetric: AlertRule.Metric = .cpuUsage
    @State private var selectedCondition: AlertRule.Condition = .greaterThan
    @State private var threshold = ""
    @State private var selectedSeverity: AlertRule.Severity = .warning
    @State private var cooldownMinutes = 15
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Rule Details") {
                    TextField("Rule Name", text: $ruleName)
                    
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(AlertRule.Metric.allCases, id: \.self) { metric in
                            Text(metric.rawValue.capitalized).tag(metric)
                        }
                    }
                    
                    Picker("Condition", selection: $selectedCondition) {
                        ForEach(AlertRule.Condition.allCases, id: \.self) { condition in
                            Text(condition.rawValue.capitalized).tag(condition)
                        }
                    }
                    
                    TextField("Threshold", text: $threshold)
                        .keyboardType(.decimalPad)
                }
                
                Section("Alert Settings") {
                    Picker("Severity", selection: $selectedSeverity) {
                        ForEach(AlertRule.Severity.allCases, id: \.self) { severity in
                            Text(severity.rawValue.capitalized).tag(severity)
                        }
                    }
                    
                    Stepper("Cooldown: \(cooldownMinutes) minutes", value: $cooldownMinutes, in: 1...60)
                }
            }
            .navigationTitle("Add Alert Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createRule()
                    }
                    .disabled(isCreating || ruleName.isEmpty || threshold.isEmpty)
                }
            }
        }
    }
    
    private func createRule() {
        guard let thresholdValue = Double(threshold) else { return }
        
        isCreating = true
        
        Task {
            let newRule = AlertRule(
                id: UUID().uuidString,
                name: ruleName,
                description: "Custom alert rule",
                metric: selectedMetric.rawValue,
                threshold: thresholdValue,
                operator: AlertRule.Operator(rawValue: selectedCondition.rawValue) ?? .greaterThan,
                severity: PerformanceAlert.Severity(rawValue: selectedSeverity.rawValue) ?? .warning,
                isEnabled: true,
                createdAt: Date()
            )
            
            try await monitoringService.createAlertRule(newRule)
            
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

// MARK: - System Health View

struct SystemHealthView: View {
    let monitoringService: AdminPerformanceMonitoringService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: SPDesignSystem.Spacing.l) {
                    // Overall health status
                    OverallHealthCard(health: monitoringService.systemHealth)
                    
                    // Component health
                    ComponentHealthCard(health: monitoringService.systemHealth)
                    
                    // Performance metrics
                    PerformanceHealthCard(health: monitoringService.systemHealth)
                    
                    // Recommendations
                    HealthRecommendationsCard(health: monitoringService.systemHealth)
                }
                .padding()
            }
            .navigationTitle("System Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OverallHealthCard: View {
    let health: SystemHealth
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            Text("Overall System Health")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: health.overallStatus.icon)
                    .font(.system(size: 40))
                    .foregroundColor(health.overallStatus.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(health.overallStatus.rawValue.capitalized)
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                        .foregroundColor(health.overallStatus.color)
                    
                    Text("System is \(health.overallStatus.rawValue)")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Uptime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(health.uptime, specifier: "%.2f")%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct ComponentHealthCard: View {
    let health: SystemHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Component Health")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            VStack(spacing: SPDesignSystem.Spacing.s) {
                ComponentHealthRow(
                    title: "Database",
                    status: health.databaseStatus,
                    icon: "externaldrive.fill"
                )
                
                ComponentHealthRow(
                    title: "Network",
                    status: health.networkStatus == .connected ? .healthy : .unhealthy,
                    icon: "network"
                )
                
                ComponentHealthRow(
                    title: "API Services",
                    status: health.apiStatus,
                    icon: "globe"
                )
                
                ComponentHealthRow(
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

struct ComponentHealthRow: View {
    let title: String
    let status: SystemHealth.HealthStatus
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(status.color)
                .frame(width: 24)
            
            Text(title)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                
                Text(status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(status.color)
            }
        }
    }
}

struct PerformanceHealthCard: View {
    let health: SystemHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Performance Metrics")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                PerformanceMetric(
                    title: "Response Time",
                    value: "\(Int(health.uptime))%",
                    color: health.uptime > 90 ? .green : .orange
                )
                
                PerformanceMetric(
                    title: "Error Rate",
                    value: "0.0%", // Placeholder since error rate not available
                    color: .green // Default to good since error rate not available
                )
                
                PerformanceMetric(
                    title: "Throughput",
                    value: "0 req/s", // Placeholder since throughput not available
                    color: .blue
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct PerformanceMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
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

struct HealthRecommendationsCard: View {
    let health: SystemHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Recommendations")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            if health.overallStatus == .healthy {
                Text("System is performing well. Continue monitoring for any changes.")
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    if health.uptime < 90 {
                        RecommendationItem(
                            title: "High Response Time",
                            description: "Consider optimizing database queries or increasing server resources.",
                            severity: .warning
                        )
                    }
                    
                    if health.uptime < 90 {
                        RecommendationItem(
                            title: "High Error Rate",
                            description: "Investigate recent errors and check system logs for issues.",
                            severity: .critical
                        )
                    }
                    
                    if health.uptime < 99 {
                        RecommendationItem(
                            title: "Low Uptime",
                            description: "Review recent downtime incidents and implement redundancy measures.",
                            severity: .warning
                        )
                    }
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct RecommendationItem: View {
    let title: String
    let description: String
    let severity: AlertRule.Severity
    
    var body: some View {
        HStack(alignment: .top, spacing: SPDesignSystem.Spacing.s) {
            Image(systemName: severity.icon)
                .font(.caption)
                .foregroundColor(severity.color)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(severity.color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Metric Cards

struct SystemMetricsCard: View {
    let metrics: SystemMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("System Metrics")
                .font(SPDesignSystem.Typography.footnote())
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                PerformanceMetricValue(title: "CPU", value: "\(Int(metrics.cpuUsage))%", color: .blue)
                PerformanceMetricValue(title: "Memory", value: "\(Int(metrics.memoryUsage))%", color: .green)
                PerformanceMetricValue(title: "Latency", value: "\(Int(metrics.networkMetrics.latency))ms", color: .orange)
            }
        }
    }
}

struct KPIMetricsCard: View {
    let metrics: KPIMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("KPI Metrics")
                .font(SPDesignSystem.Typography.footnote())
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                PerformanceMetricValue(title: "Bookings", value: "\(metrics.bookingMetrics.totalBookings)", color: .blue)
                PerformanceMetricValue(title: "Revenue", value: "$\(Int(metrics.revenueMetrics.dailyRevenue))", color: .green)
                PerformanceMetricValue(title: "Satisfaction", value: "\(String(format: "%.1f", metrics.customerMetrics.customerSatisfaction))", color: .purple)
            }
        }
    }
}

struct SitterMetricsCard: View {
    let sitters: [SitterPerformance]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Sitter Performance")
                .font(SPDesignSystem.Typography.footnote())
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                PerformanceMetricValue(title: "Active", value: "\(sitters.count)", color: .blue)
                PerformanceMetricValue(title: "Avg Rating", value: "\(String(format: "%.1f", sitters.map(\.rating).reduce(0, +) / Double(sitters.count)))", color: .green)
                PerformanceMetricValue(title: "Avg Score", value: "\(Int(sitters.map(\.performanceScore).reduce(0, +) / Double(sitters.count)))%", color: .purple)
            }
        }
    }
}

struct CustomerMetricsCard: View {
    let metrics: CustomerMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Customer Metrics")
                .font(SPDesignSystem.Typography.footnote())
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                PerformanceMetricValue(title: "Satisfaction", value: "\(String(format: "%.1f", metrics.customerSatisfaction))", color: .purple)
                PerformanceMetricValue(title: "Retention", value: "\(String(format: "%.1f", metrics.customerRetentionRate))%", color: .blue)
                PerformanceMetricValue(title: "Churn", value: "0.0%", color: .red) // Placeholder since churn rate not available
            }
        }
    }
}

struct PerformanceMetricValue: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
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
