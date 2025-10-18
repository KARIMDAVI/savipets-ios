import SwiftUI
import Charts

// MARK: - Report Generator View

struct ReportGeneratorView: View {
    let reportingService: AdminReportingService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ReportType = .booking
    @State private var selectedTimeRange: TimeRange = .last30Days
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var reportName = ""
    @State private var selectedFilters: Set<String> = []
    @State private var isGenerating = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Report Configuration") {
                    Picker("Report Type", selection: $selectedType) {
                        ForEach(ReportType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    
                    TextField("Report Name", text: $reportName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    
                    if selectedTimeRange == .custom {
                        DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                    }
                }
                
                Section("Filters") {
                    ForEach(availableFilters, id: \.self) { filter in
                        HStack {
                            Text(filter)
                            Spacer()
                            if selectedFilters.contains(filter) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFilters.contains(filter) {
                                selectedFilters.remove(filter)
                            } else {
                                selectedFilters.insert(filter)
                            }
                        }
                    }
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Report Preview")
                            .font(SPDesignSystem.Typography.footnote())
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("Type: \(selectedType.displayName)")
                            .font(.caption)
                        
                        Text("Time Range: \(selectedTimeRange.displayName)")
                            .font(.caption)
                        
                        Text("Filters: \(selectedFilters.count) selected")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate") {
                        generateReport()
                    }
                    .disabled(isGenerating || reportName.isEmpty)
                }
            }
        }
    }
    
    private var availableFilters: [String] {
        switch selectedType {
        case .booking:
            return ["Completed Bookings", "Cancelled Bookings", "Pending Bookings", "High Value Bookings"]
        case .revenue:
            return ["Daily Revenue", "Weekly Revenue", "Monthly Revenue", "Service Revenue"]
        case .customer:
            return ["New Customers", "Returning Customers", "High Value Customers", "Satisfied Customers"]
        case .sitter:
            return ["Active Sitters", "Top Performers", "Certified Sitters", "Available Sitters"]
        case .operational:
            return ["System Metrics", "Performance Metrics", "Error Rates", "Uptime"]
        case .financial:
            return ["Revenue", "Expenses", "Profit", "Cash Flow"]
        case .marketing:
            return ["Campaigns", "Leads", "Conversions", "ROI"]
        case .custom:
            return []
        }
    }
    
    private func generateReport() {
        isGenerating = true
        
        let filters = ReportFilters(
            dateRange: selectedTimeRange == .custom ? DateRange(startDate: customStartDate, endDate: customEndDate) : nil,
            serviceTypes: selectedFilters.contains("Service Revenue") ? ["Dog Walking", "Pet Sitting"] : nil,
            sitterIds: selectedFilters.contains("Top Performers") ? ["sitter1", "sitter2"] : nil,
            customerSegments: selectedFilters.contains("High Value Customers") ? ["High Value"] : nil
        )
        
        Task {
            await reportingService.generateReport(
                type: selectedType,
                timeRange: selectedTimeRange,
                filters: filters
            )
            
            await MainActor.run {
                isGenerating = false
                dismiss()
            }
        }
    }
}

// MARK: - Report Detail View

struct ReportDetailView: View {
    let report: Report
    let reportingService: AdminReportingService
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportOptions = false
    @State private var isExporting = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.l) {
                    // Report header
                    reportHeader
                    
                    // Report data visualization
                    reportDataSection
                    
                    // Export options
                    exportSection
                }
                .padding()
            }
            .navigationTitle(report.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        showingExportOptions = true
                    }
                    .disabled(isExporting)
                }
            }
            .actionSheet(isPresented: $showingExportOptions) {
                ActionSheet(
                    title: Text("Export Format"),
                    message: Text("Choose the format for your report"),
                    buttons: [
                        .default(Text("PDF")) { exportReport(.pdf) },
                        .default(Text("CSV")) { exportReport(.csv) },
                        .default(Text("Excel")) { exportReport(.excel) },
                        .default(Text("JSON")) { exportReport(.json) },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: report.type.icon)
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.name)
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(report.type.displayName)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
            }
            
            // Report details
            VStack(spacing: SPDesignSystem.Spacing.s) {
                ReportDetailInfoRow(
                    title: "Time Range",
                    value: report.timeRange.displayName
                )
                
                ReportDetailInfoRow(
                    title: "Generated",
                    value: formatReportDate(report.generatedAt)
                )
                
                ReportDetailInfoRow(
                    title: "Generated By",
                    value: report.generatedBy
                )
                
                if !(report.filters.serviceTypes?.isEmpty ?? true) {
                    ReportDetailInfoRow(
                        title: "Service Types",
                        value: report.filters.serviceTypes?.joined(separator: ", ") ?? "All"
                    )
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private var reportDataSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Report Data")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            // Display report data based on type
            switch report.type {
            case .booking:
                BookingReportDataView(data: report.data)
            case .revenue:
                RevenueReportDataView(data: report.data)
            case .customer:
                CustomerReportDataView(data: report.data)
            case .sitter:
                SitterReportDataView(data: report.data)
            case .operational:
                OperationalReportDataView(data: report.data)
            case .financial:
                FinancialReportDataView(data: report.data)
            case .marketing:
                MarketingReportDataView(data: report.data)
            case .custom:
                CustomReportDataView(data: report.data)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text("Export Options")
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
            
            HStack(spacing: SPDesignSystem.Spacing.m) {
                ExportOptionButton(
                    title: "PDF",
                    icon: "doc.fill",
                    color: .red
                ) {
                    exportReport(.pdf)
                }
                
                ExportOptionButton(
                    title: "CSV",
                    icon: "tablecells.fill",
                    color: .green
                ) {
                    exportReport(.csv)
                }
                
                ExportOptionButton(
                    title: "Excel",
                    icon: "tablecells.fill",
                    color: .blue
                ) {
                    exportReport(.excel)
                }
                
                ExportOptionButton(
                    title: "JSON",
                    icon: "curlybraces",
                    color: .orange
                ) {
                    exportReport(.json)
                }
            }
            
            if isExporting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Exporting report...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func exportReport(_ format: ExportFormat) {
        isExporting = true
        
        Task {
            let url = await reportingService.exportReport(report, format: format)
            
            await MainActor.run {
                isExporting = false
                if url != nil {
                    // Show success message
                }
            }
        }
    }
    
    private func formatReportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ReportDetailInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(SPDesignSystem.Typography.footnote())
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct ExportOptionButton: View {
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
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SPDesignSystem.Spacing.s)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Report Data Views

struct BookingReportDataView: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            if let totalBookings = data["totalBookings"] as? Int {
                ReportDataRow(title: "Total Bookings", value: "\(totalBookings)")
            }
            
            if let completedBookings = data["completedBookings"] as? Int {
                ReportDataRow(title: "Completed Bookings", value: "\(completedBookings)")
            }
            
            if let cancelledBookings = data["cancelledBookings"] as? Int {
                ReportDataRow(title: "Cancelled Bookings", value: "\(cancelledBookings)")
            }
            
            if let averageValue = data["averageBookingValue"] as? Double {
                ReportDataRow(title: "Average Booking Value", value: "$\(Int(averageValue))")
            }
            
            if let conversionRate = data["bookingConversionRate"] as? Double {
                ReportDataRow(title: "Conversion Rate", value: "\(Int(conversionRate))%")
            }
        }
    }
}

struct RevenueReportDataView: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            if let totalRevenue = data["totalRevenue"] as? Double {
                ReportDataRow(title: "Total Revenue", value: "$\(Int(totalRevenue))")
            }
            
            if let dailyRevenue = data["dailyRevenue"] as? Double {
                ReportDataRow(title: "Daily Revenue", value: "$\(Int(dailyRevenue))")
            }
            
            if let weeklyRevenue = data["weeklyRevenue"] as? Double {
                ReportDataRow(title: "Weekly Revenue", value: "$\(Int(weeklyRevenue))")
            }
            
            if let monthlyRevenue = data["monthlyRevenue"] as? Double {
                ReportDataRow(title: "Monthly Revenue", value: "$\(Int(monthlyRevenue))")
            }
            
            if let growth = data["revenueGrowth"] as? Double {
                ReportDataRow(title: "Revenue Growth", value: "\(Int(growth))%")
            }
        }
    }
}

struct CustomerReportDataView: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            if let totalCustomers = data["totalCustomers"] as? Int {
                ReportDataRow(title: "Total Customers", value: "\(totalCustomers)")
            }
            
            if let newCustomers = data["newCustomers"] as? Int {
                ReportDataRow(title: "New Customers", value: "\(newCustomers)")
            }
            
            if let returningCustomers = data["returningCustomers"] as? Int {
                ReportDataRow(title: "Returning Customers", value: "\(returningCustomers)")
            }
            
            if let satisfaction = data["customerSatisfaction"] as? Double {
                ReportDataRow(title: "Customer Satisfaction", value: "\(String(format: "%.1f", satisfaction))")
            }
            
            if let retention = data["customerRetentionRate"] as? Double {
                ReportDataRow(title: "Retention Rate", value: "\(Int(retention))%")
            }
        }
    }
}

struct SitterReportDataView: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            if let totalSitters = data["totalSitters"] as? Int {
                ReportDataRow(title: "Total Sitters", value: "\(totalSitters)")
            }
            
            if let activeSitters = data["activeSitters"] as? Int {
                ReportDataRow(title: "Active Sitters", value: "\(activeSitters)")
            }
            
            if let averageRating = data["averageRating"] as? Double {
                ReportDataRow(title: "Average Rating", value: "\(String(format: "%.1f", averageRating))")
            }
            
            if let utilization = data["utilizationRate"] as? Double {
                ReportDataRow(title: "Utilization Rate", value: "\(Int(utilization))%")
            }
            
            if let retention = data["retentionRate"] as? Double {
                ReportDataRow(title: "Retention Rate", value: "\(Int(retention))%")
            }
        }
    }
}

struct OperationalReportDataView: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            if let uptime = data["systemUptime"] as? Double {
                ReportDataRow(title: "System Uptime", value: "\(String(format: "%.1f", uptime))%")
            }
            
            if let responseTime = data["averageResponseTime"] as? Double {
                ReportDataRow(title: "Response Time", value: "\(Int(responseTime))ms")
            }
            
            if let errorRate = data["errorRate"] as? Double {
                ReportDataRow(title: "Error Rate", value: "\(String(format: "%.2f", errorRate))%")
            }
            
            if let tickets = data["supportTickets"] as? Int {
                ReportDataRow(title: "Support Tickets", value: "\(tickets)")
            }
            
            if let resolutionTime = data["resolutionTime"] as? Double {
                ReportDataRow(title: "Resolution Time", value: "\(Int(resolutionTime))h")
            }
        }
    }
}

struct FinancialReportDataView: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            if let totalRevenue = data["totalRevenue"] as? Double {
                ReportDataRow(title: "Total Revenue", value: "$\(Int(totalRevenue))")
            }
            
            if let totalExpenses = data["totalExpenses"] as? Double {
                ReportDataRow(title: "Total Expenses", value: "$\(Int(totalExpenses))")
            }
            
            if let netProfit = data["netProfit"] as? Double {
                ReportDataRow(title: "Net Profit", value: "$\(Int(netProfit))")
            }
            
            if let profitMargin = data["profitMargin"] as? Double {
                ReportDataRow(title: "Profit Margin", value: "\(Int(profitMargin))%")
            }
        }
    }
}

struct MarketingReportDataView: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            if let campaigns = data["campaigns"] as? Int {
                ReportDataRow(title: "Campaigns", value: "\(campaigns)")
            }
            
            if let totalSpend = data["totalSpend"] as? Double {
                ReportDataRow(title: "Total Spend", value: "$\(Int(totalSpend))")
            }
            
            if let roi = data["roi"] as? Double {
                ReportDataRow(title: "ROI", value: "\(Int(roi))%")
            }
            
            if let conversionRate = data["conversionRate"] as? Double {
                ReportDataRow(title: "Conversion Rate", value: "\(Int(conversionRate))%")
            }
            
            if let acquisitionCost = data["acquisitionCost"] as? Double {
                ReportDataRow(title: "Acquisition Cost", value: "$\(Int(acquisitionCost))")
            }
        }
    }
}

struct CustomReportDataView: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            ForEach(Array(data.keys.sorted()), id: \.self) { key in
                if let value = data[key] {
                    ReportDataRow(
                        title: key.replacingOccurrences(of: "_", with: " ").capitalized,
                        value: String(describing: value)
                    )
                }
            }
        }
    }
}

struct ReportDataRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(SPDesignSystem.Typography.footnote())
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Scheduled Reports View

struct ScheduledReportsView: View {
    let reportingService: AdminReportingService
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSchedule = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Scheduled Reports")
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                    
                    Text("Automated report generation and delivery")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Scheduled reports list
                ScrollView {
                    LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                        ForEach(reportingService.scheduledReports) { scheduledReport in
                            ScheduledReportCard(scheduledReport: scheduledReport)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Scheduled Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Schedule") {
                        showingAddSchedule = true
                    }
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                AddScheduledReportView(reportingService: reportingService)
            }
        }
    }
}

struct ScheduledReportCard: View {
    let scheduledReport: ScheduledReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(scheduledReport.templateName)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Template: \(scheduledReport.templateId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(scheduledReport.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            
            // Schedule details
            VStack(spacing: SPDesignSystem.Spacing.s) {
                ScheduledReportDetailRow(
                    title: "Frequency",
                    value: scheduledReport.schedule.frequency.rawValue.capitalized
                )
                
                ScheduledReportDetailRow(
                    title: "Time",
                    value: scheduledReport.schedule.time
                )
                
                ScheduledReportDetailRow(
                    title: "Recipients",
                    value: "\(scheduledReport.recipients.count) recipients"
                )
                
                if let lastRun = scheduledReport.lastRun {
                    ScheduledReportDetailRow(
                        title: "Last Run",
                        value: formatDate(lastRun)
                    )
                }
                
                if let nextRun = scheduledReport.nextRun {
                    ScheduledReportDetailRow(
                        title: "Next Run",
                        value: formatDate(nextRun)
                    )
                }
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

struct ScheduledReportDetailRow: View {
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

struct AddScheduledReportView: View {
    let reportingService: AdminReportingService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: ReportTemplate?
    @State private var selectedFrequency: ScheduleFrequency = .weekly
    @State private var scheduleTime = Date()
    @State private var recipients: [String] = []
    @State private var newRecipient = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Report Template") {
                    Picker("Template", selection: $selectedTemplate) {
                        ForEach(reportingService.reportTemplates) { template in
                            Text(template.name).tag(template as ReportTemplate?)
                        }
                    }
                }
                
                Section("Schedule") {
                    Picker("Frequency", selection: $selectedFrequency) {
                        ForEach(ScheduleFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue.capitalized).tag(frequency)
                        }
                    }
                    
                    DatePicker("Time", selection: $scheduleTime, displayedComponents: .hourAndMinute)
                }
                
                Section("Recipients") {
                    ForEach(recipients, id: \.self) { recipient in
                        Text(recipient)
                    }
                    .onDelete(perform: deleteRecipient)
                    
                    HStack {
                        TextField("Email address", text: $newRecipient)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add") {
                            if !newRecipient.isEmpty {
                                recipients.append(newRecipient)
                                newRecipient = ""
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Scheduled Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveScheduledReport()
                    }
                    .disabled(selectedTemplate == nil || recipients.isEmpty)
                }
            }
        }
    }
    
    private func deleteRecipient(at offsets: IndexSet) {
        recipients.remove(atOffsets: offsets)
    }
    
    private func saveScheduledReport() {
        guard let template = selectedTemplate else { return }
        
        let schedule = ReportSchedule(
            frequency: selectedFrequency,
            time: DateFormatter.timeFormatter.string(from: scheduleTime),
            dayOfWeek: nil,
            dayOfMonth: nil
        )
        
        Task {
            await reportingService.createScheduledReport(
                template: template,
                schedule: schedule,
                recipients: recipients
            )
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

// MARK: - Export History View

struct ExportHistoryView: View {
    let reportingService: AdminReportingService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                    Text("Export History")
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                    
                    Text("Download and manage exported reports")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Export history list
                ScrollView {
                    LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                        ForEach(reportingService.exportHistory) { export in
                            ExportHistoryCard(export: export)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Export History")
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

struct ExportHistoryCard: View {
    let export: ExportRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                Image(systemName: export.format.icon)
                    .font(.title3)
                    .foregroundColor(export.format.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(export.reportName)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(export.format.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Download button
                Button(action: { downloadExport(export) }) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            
            // Export details
            VStack(spacing: SPDesignSystem.Spacing.s) {
                ExportHistoryDetailRow(
                    title: "Exported",
                    value: formatDate(export.exportedAt)
                )
                
                ExportHistoryDetailRow(
                    title: "File Size",
                    value: formatFileSize(export.fileSize)
                )
                
                ExportHistoryDetailRow(
                    title: "Format",
                    value: export.format.displayName
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func downloadExport(_ export: ExportRecord) {
        // Implement download functionality
        if let url = URL(string: export.downloadUrl) {
            // Handle download
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct ExportHistoryDetailRow: View {
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

// MARK: - Extensions

extension ExportFormat {
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .csv: return "tablecells.fill"
        case .excel: return "tablecells.fill"
        case .json: return "curlybraces"
        }
    }
    
    var color: Color {
        switch self {
        case .pdf: return .red
        case .csv: return .green
        case .excel: return .blue
        case .json: return .orange
        }
    }
}
