import SwiftUI
import Charts

// MARK: - Enhanced Workforce Management View

struct EnhancedWorkforceView: View {
    @StateObject private var workforceService = AdminWorkforceService()
    @State private var selectedTab: WorkforceTab = .employees
    @State private var searchText = ""
    @State private var selectedFilters: Set<WorkforceFilter> = []
    @State private var showingAddEmployee = false
    @State private var showingScheduleOptimizer = false
    @State private var showingTimeOffRequests = false
    @State private var showingCertifications = false
    @State private var showingAnalytics = false
    @State private var selectedEmployee: WorkforceEmployee?
    @State private var showingEmployeeDetail = false
    
    enum WorkforceTab: String, CaseIterable {
        case employees = "Employees"
        case schedules = "Schedules"
        case shifts = "Shifts"
        case timeOff = "Time Off"
        case certifications = "Certifications"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .employees: return "person.2.fill"
            case .schedules: return "calendar"
            case .shifts: return "clock.fill"
            case .timeOff: return "calendar.badge.minus"
            case .certifications: return "graduationcap.fill"
            case .analytics: return "chart.bar.fill"
            }
        }
    }
    
    enum WorkforceFilter: String, CaseIterable {
        case active = "Active"
        case inactive = "Inactive"
        case fullTime = "Full Time"
        case partTime = "Part Time"
        case sitters = "Sitters"
        case walkers = "Walkers"
        
        var color: Color {
            switch self {
            case .active: return .green
            case .inactive: return .orange
            case .fullTime: return .blue
            case .partTime: return .purple
            case .sitters: return .cyan
            case .walkers: return .red
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
                    employeesTab
                        .tag(WorkforceTab.employees)
                    
                    schedulesTab
                        .tag(WorkforceTab.schedules)
                    
                    shiftsTab
                        .tag(WorkforceTab.shifts)
                    
                    timeOffTab
                        .tag(WorkforceTab.timeOff)
                    
                    certificationsTab
                        .tag(WorkforceTab.certifications)
                    
                    analyticsTab
                        .tag(WorkforceTab.analytics)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Workforce Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddEmployee = true }) {
                            Label("Add Employee", systemImage: "person.badge.plus")
                        }
                        
                        Button(action: { showingScheduleOptimizer = true }) {
                            Label("Schedule Optimizer", systemImage: "brain.head.profile")
                        }
                        
                        Divider()
                        
                        Button(action: { showingTimeOffRequests = true }) {
                            Label("Time Off Requests", systemImage: "calendar.badge.minus")
                        }
                        
                        Button(action: { showingCertifications = true }) {
                            Label("Certifications", systemImage: "graduationcap.fill")
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
            .sheet(isPresented: $showingAddEmployee) {
                AddEmployeeView(workforceService: workforceService)
            }
            .sheet(isPresented: $showingScheduleOptimizer) {
                ScheduleOptimizerView(workforceService: workforceService)
            }
            .sheet(isPresented: $showingTimeOffRequests) {
                TimeOffRequestsView(workforceService: workforceService)
            }
            .sheet(isPresented: $showingCertifications) {
                CertificationsView(workforceService: workforceService)
            }
            .sheet(isPresented: $showingAnalytics) {
                WorkforceAnalyticsView(workforceService: workforceService)
            }
            .sheet(isPresented: $showingEmployeeDetail) {
                if let employee = selectedEmployee {
                    EmployeeDetailView(employee: employee, workforceService: workforceService)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var enhancedHeader: some View {
        VStack(spacing: SPDesignSystem.Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workforce Management")
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.bold)
                    
                    Text("\(workforceService.employees.count) employees, \(workforceService.shifts.count) shifts")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick stats
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    WorkforceQuickStat(
                        title: "Active",
                        value: "\(workforceService.employees.filter { $0.status == .active }.count)",
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                    
                    WorkforceQuickStat(
                        title: "Hours",
                        value: "\(workforceService.shifts.reduce(0) { $0 + $1.duration })",
                        color: .blue,
                        icon: "clock.fill"
                    )
                    
                    WorkforceQuickStat(
                        title: "Cost",
                        value: "$\(Int(workforceService.shifts.reduce(0.0) { $0 + $1.cost }))",
                        color: .orange,
                        icon: "dollarsign.circle.fill"
                    )
                }
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search employees, shifts...", text: $searchText)
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
            ForEach(WorkforceTab.allCases, id: \.self) { tab in
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
                ForEach(WorkforceFilter.allCases, id: \.self) { filter in
                    WorkforceFilterChip(
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
    
    private var employeesTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(filteredEmployees) { employee in
                    EmployeeCard(employee: employee) {
                        selectedEmployee = employee
                        showingEmployeeDetail = true
                    }
                }
            }
            .padding()
        }
    }
    
    private var schedulesTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(workforceService.schedules) { schedule in
                    ScheduleCard(schedule: schedule, workforceService: workforceService)
                }
            }
            .padding()
        }
    }
    
    private var shiftsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(workforceService.shifts) { shift in
                    ShiftCard(shift: shift, workforceService: workforceService)
                }
            }
            .padding()
        }
    }
    
    private var timeOffTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(workforceService.timeOffRequests) { request in
                    TimeOffRequestCard(request: request, workforceService: workforceService)
                }
            }
            .padding()
        }
    }
    
    private var certificationsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                ForEach(workforceService.certifications) { certification in
                    CertificationCard(certification: certification, workforceService: workforceService)
                }
            }
            .padding()
        }
    }
    
    private var analyticsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                // Analytics charts
                WorkforceAnalyticsCharts(workforceService: workforceService)
            }
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredEmployees: [WorkforceEmployee] {
        var employees = workforceService.employees
        
        // Apply search filter
        if !searchText.isEmpty {
            employees = employees.filter { employee in
                employee.name.lowercased().contains(searchText.lowercased()) ||
                employee.email.lowercased().contains(searchText.lowercased()) ||
                employee.role.rawValue.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Apply status filters
        if !selectedFilters.isEmpty {
            employees = employees.filter { employee in
                if selectedFilters.contains(.active) && employee.status == .active { return true }
                if selectedFilters.contains(.inactive) && employee.status == .inactive { return true }
                if selectedFilters.contains(.fullTime) && employee.availability == .fullTime { return true }
                if selectedFilters.contains(.partTime) && employee.availability == .partTime { return true }
                if selectedFilters.contains(.sitters) && employee.role == .sitter { return true }
                if selectedFilters.contains(.walkers) && employee.role == .walker { return true }
                return false
            }
        }
        
        return employees.sorted { $0.name < $1.name }
    }
}

// MARK: - Supporting Views

struct WorkforceQuickStat: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
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

struct WorkforceFilterChip: View {
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

struct EmployeeCard: View {
    let employee: WorkforceEmployee
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(employee.name)
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(employee.email)
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Image(systemName: employee.status == .active ? "checkmark.circle.fill" : "pause.circle.fill")
                            .font(.caption)
                        Text(employee.status.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(employee.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(employee.status.color.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Role and availability
                HStack(spacing: SPDesignSystem.Spacing.m) {
                    HStack(spacing: 4) {
                        Image(systemName: employee.role.icon)
                            .font(.caption)
                            .foregroundColor(employee.role.color)
                        Text(employee.role.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(employee.availability.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("$\(Int(employee.hourlyRate))/hr")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                // Skills
                if !employee.skills.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(employee.skills, id: \.self) { skill in
                                Text(skill)
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

struct ScheduleCard: View {
    let schedule: WorkforceSchedule
    let workforceService: AdminWorkforceService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.name)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(schedule.shifts.count) shifts")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Optimization indicator
                if schedule.isOptimized {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                        Text("AI Optimized")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // Metrics
            HStack {
                WorkforceMetricItem(title: "Hours", value: "\(schedule.totalHours)")
                WorkforceMetricItem(title: "Cost", value: "$\(Int(schedule.totalCost))")
                WorkforceMetricItem(title: "Shifts", value: "\(schedule.shifts.count)")
                
                Spacer()
                
                // Date range
                Text(formatDateRange(schedule.startDate, schedule.endDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

struct ShiftCard: View {
    let shift: WorkforceShift
    let workforceService: AdminWorkforceService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shift.serviceType)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(shift.location)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Text(shift.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(shift.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(shift.status.color.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Time and cost
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTimeRange(shift.startTime, shift.endTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(Int(shift.cost))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("\(shift.duration)h")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Employee assignment
            if let employeeId = shift.employeeId,
               let employee = workforceService.getEmployeeById(employeeId) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(employee.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.plus")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Unassigned")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func formatTimeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

struct TimeOffRequestCard: View {
    let request: TimeOffRequest
    let workforceService: AdminWorkforceService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let employee = workforceService.getEmployeeById(request.employeeId) {
                        Text(employee.name)
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Text(request.type.rawValue.capitalized)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Text(request.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(request.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(request.status.color.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Date range
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatDateRange(request.startDate, request.endDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Reason
            Text(request.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Actions for pending requests
            if request.status == .pending {
                HStack(spacing: SPDesignSystem.Spacing.s) {
                    Button(action: { approveRequest() }) {
                        Text("Approve")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(6)
                    }
                    
                    Button(action: { denyRequest() }) {
                        Text("Deny")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private func approveRequest() {
        Task {
            try? await workforceService.approveTimeOffRequest(request.id)
        }
    }
    
    private func denyRequest() {
        Task {
            try? await workforceService.denyTimeOffRequest(request.id, reason: "Not approved")
        }
    }
}

struct CertificationCard: View {
    let certification: EmployeeCertification
    let workforceService: AdminWorkforceService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(certification.name)
                        .font(SPDesignSystem.Typography.heading3())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let employee = workforceService.getEmployeeById(certification.employeeId) {
                        Text(employee.name)
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status indicator
                Text(certification.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(certification.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(certification.status.color.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Organization and dates
            HStack {
                Text(certification.issuingOrganization)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Expires: \(formatDate(certification.expirationDate))")
                    .font(.caption)
                    .foregroundColor(certification.expirationDate < Date() ? .red : .secondary)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct WorkforceMetricItem: View {
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

struct WorkforceAnalyticsCharts: View {
    let workforceService: AdminWorkforceService
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            // Employee status distribution
            AdvancedChartCard(
                title: "Employee Status Distribution",
                subtitle: "Distribution of employees by status",
                chartData: employeeStatusData,
                chartType: .pie,
                timeRange: .month
            )
            
            // Hours worked trends
            AdvancedChartCard(
                title: "Hours Worked Trends",
                subtitle: "Weekly hours worked by employees",
                chartData: hoursWorkedData,
                chartType: .bar,
                timeRange: .week
            )
            
            // Cost analysis
            AdvancedChartCard(
                title: "Labor Cost Analysis",
                subtitle: "Monthly labor costs",
                chartData: costAnalysisData,
                chartType: .line,
                timeRange: .month
            )
        }
    }
    
    private var employeeStatusData: [ChartDataPoint] {
        let statusCounts = Dictionary(grouping: workforceService.employees, by: { $0.status })
        return statusCounts.map { status, employees in
            ChartDataPoint(
                xValue: status.rawValue.capitalized,
                yValue: Double(employees.count),
                color: status.color,
                label: "\(employees.count) employees"
            )
        }
    }
    
    private var hoursWorkedData: [ChartDataPoint] {
        // Sample hours worked data for the last 7 days
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let hours = [120, 135, 140, 130, 145, 90, 80]
        
        return zip(days, hours).map { day, hour in
            ChartDataPoint(
                xValue: day,
                yValue: Double(hour),
                color: .blue,
                label: "\(hour) hours"
            )
        }
    }
    
    private var costAnalysisData: [ChartDataPoint] {
        // Sample cost data for the last 6 months
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
        let costs = [12000, 13500, 14000, 13000, 14500, 15000]
        
        return zip(months, costs).map { month, cost in
            ChartDataPoint(
                xValue: month,
                yValue: Double(cost),
                color: .green,
                label: "$\(cost)"
            )
        }
    }
}
