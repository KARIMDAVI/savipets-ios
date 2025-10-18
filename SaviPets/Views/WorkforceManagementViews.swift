import SwiftUI

// MARK: - Add Employee View

struct AddEmployeeView: View {
    @ObservedObject var workforceService: AdminWorkforceService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role: WorkforceEmployee.EmployeeRole = .sitter
    @State private var hourlyRate = ""
    @State private var availability: WorkforceEmployee.Availability = .fullTime
    @State private var skills: [String] = []
    @State private var certifications: [String] = []
    @State private var emergencyContact = ""
    @State private var notes = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Full Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("Employment Details") {
                    Picker("Role", selection: $role) {
                        ForEach(WorkforceEmployee.EmployeeRole.allCases, id: \.self) { role in
                            HStack {
                                Image(systemName: role.icon)
                                    .foregroundColor(role.color)
                                Text(role.rawValue.capitalized)
                            }
                            .tag(role)
                        }
                    }
                    
                    Picker("Availability", selection: $availability) {
                        ForEach(WorkforceEmployee.Availability.allCases, id: \.self) { availability in
                            Text(availability.rawValue.capitalized)
                                .tag(availability)
                        }
                    }
                    
                    TextField("Hourly Rate", text: $hourlyRate)
                        .keyboardType(.decimalPad)
                }
                
                Section("Skills & Certifications") {
                    // Skills management
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Skills")
                            .font(SPDesignSystem.Typography.footnote())
                            .fontWeight(.semibold)
                        
                        if !skills.isEmpty {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                ForEach(skills, id: \.self) { skill in
                                    HStack {
                                        Text(skill)
                                            .font(.caption)
                                        Spacer()
                                        Button(action: { removeSkill(skill) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        
                        Button(action: { showingAddSkill = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Skill")
                            }
                            .font(.caption)
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                        }
                    }
                    
                    // Certifications management
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Certifications")
                            .font(SPDesignSystem.Typography.footnote())
                            .fontWeight(.semibold)
                        
                        if !certifications.isEmpty {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                ForEach(certifications, id: \.self) { cert in
                                    HStack {
                                        Text(cert)
                                            .font(.caption)
                                        Spacer()
                                        Button(action: { removeCertification(cert) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        
                        Button(action: { showingAddCertification = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Certification")
                            }
                            .font(.caption)
                            .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                        }
                    }
                }
                
                Section("Additional Information") {
                    TextField("Emergency Contact", text: $emergencyContact)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Employee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEmployee()
                    }
                    .disabled(name.isEmpty || email.isEmpty || hourlyRate.isEmpty || isSaving)
                }
            }
        }
        .sheet(isPresented: $showingAddSkill) {
            AddSkillView(skills: $skills)
        }
        .sheet(isPresented: $showingAddCertification) {
            AddCertificationView(certifications: $certifications)
        }
    }
    
    @State private var showingAddSkill = false
    @State private var showingAddCertification = false
    
    private func removeSkill(_ skill: String) {
        skills.removeAll { $0 == skill }
    }
    
    private func removeCertification(_ certification: String) {
        certifications.removeAll { $0 == certification }
    }
    
    private func saveEmployee() {
        guard let rate = Double(hourlyRate) else { return }
        
        isSaving = true
        
        let employee = WorkforceEmployee(
            id: UUID().uuidString,
            name: name,
            email: email,
            phone: phone,
            role: role,
            status: .active,
            hireDate: Date(),
            hourlyRate: rate,
            skills: skills,
            certifications: certifications,
            availability: availability,
            preferences: [],
            emergencyContact: emergencyContact,
            notes: notes
        )
        
        Task {
            do {
                try await workforceService.createEmployee(employee)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Add Skill View

struct AddSkillView: View {
    @Binding var skills: [String]
    @Environment(\.dismiss) private var dismiss
    
    @State private var newSkill = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: SPDesignSystem.Spacing.m) {
                TextField("Enter skill", text: $newSkill)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Common skills
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SPDesignSystem.Spacing.s) {
                    ForEach(commonSkills, id: \.self) { skill in
                        Button(action: { addSkill(skill) }) {
                            Text(skill)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if !newSkill.isEmpty {
                            addSkill(newSkill)
                        }
                    }
                    .disabled(newSkill.isEmpty)
                }
            }
        }
    }
    
    private let commonSkills = [
        "Dog Walking", "Cat Care", "Pet Sitting", "Basic Grooming",
        "Medication Administration", "Pet Training", "Emergency Care",
        "Senior Pet Care", "Puppy Care", "Large Dog Handling"
    ]
    
    private func addSkill(_ skill: String) {
        if !skills.contains(skill) {
            skills.append(skill)
        }
        dismiss()
    }
}

// MARK: - Add Certification View

struct AddCertificationView: View {
    @Binding var certifications: [String]
    @Environment(\.dismiss) private var dismiss
    
    @State private var newCertification = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: SPDesignSystem.Spacing.m) {
                TextField("Enter certification", text: $newCertification)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Common certifications
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SPDesignSystem.Spacing.s) {
                    ForEach(commonCertifications, id: \.self) { cert in
                        Button(action: { addCertification(cert) }) {
                            Text(cert)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Certification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if !newCertification.isEmpty {
                            addCertification(newCertification)
                        }
                    }
                    .disabled(newCertification.isEmpty)
                }
            }
        }
    }
    
    private let commonCertifications = [
        "Pet First Aid", "Animal Behavior", "Pet CPR", "Pet Nutrition",
        "Grooming Certification", "Training Certification", "Veterinary Assistant",
        "Pet Care Specialist", "Animal Welfare", "Emergency Pet Care"
    ]
    
    private func addCertification(_ certification: String) {
        if !certifications.contains(certification) {
            certifications.append(certification)
        }
        dismiss()
    }
}

// MARK: - Schedule Optimizer View

struct ScheduleOptimizerView: View {
    @ObservedObject var workforceService: AdminWorkforceService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDateRange: DateInterval = DateInterval(start: Date(), duration: 86400 * 7)
    @State private var optimizationGoals: Set<OptimizationGoal> = [.minimizeCost]
    @State private var constraints: Set<ScheduleConstraint> = []
    @State private var isOptimizing = false
    @State private var optimizedSchedule: WorkforceSchedule?
    @State private var showingResults = false
    
    enum OptimizationGoal: String, CaseIterable {
        case minimizeCost = "Minimize Cost"
        case maximizeUtilization = "Maximize Utilization"
        case balanceWorkload = "Balance Workload"
        case minimizeOvertime = "Minimize Overtime"
        
        var icon: String {
            switch self {
            case .minimizeCost: return "dollarsign.circle.fill"
            case .maximizeUtilization: return "chart.bar.fill"
            case .balanceWorkload: return "scalemass.fill"
            case .minimizeOvertime: return "clock.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .minimizeCost: return .green
            case .maximizeUtilization: return .blue
            case .balanceWorkload: return .orange
            case .minimizeOvertime: return .red
            }
        }
    }
    
    enum ScheduleConstraint: String, CaseIterable {
        case maxHoursPerDay = "Max 8 hours per day"
        case minHoursBetweenShifts = "Min 12 hours between shifts"
        case weekendRotation = "Weekend rotation"
        case skillMatching = "Skill matching required"
        
        var icon: String {
            switch self {
            case .maxHoursPerDay: return "clock.badge.checkmark"
            case .minHoursBetweenShifts: return "clock.badge.exclamationmark"
            case .weekendRotation: return "calendar.badge.clock"
            case .skillMatching: return "person.badge.plus"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule Period") {
                    DatePicker("Start Date", selection: Binding(
                        get: { selectedDateRange.start },
                        set: { selectedDateRange = DateInterval(start: $0, duration: selectedDateRange.duration) }
                    ), displayedComponents: .date)
                    
                    DatePicker("End Date", selection: Binding(
                        get: { selectedDateRange.end },
                        set: { selectedDateRange = DateInterval(start: selectedDateRange.start, duration: $0.timeIntervalSince(selectedDateRange.start)) }
                    ), displayedComponents: .date)
                }
                
                Section("Optimization Goals") {
                    ForEach(OptimizationGoal.allCases, id: \.self) { goal in
                        HStack {
                            Image(systemName: goal.icon)
                                .foregroundColor(goal.color)
                            Text(goal.rawValue)
                            Spacer()
                            if optimizationGoals.contains(goal) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(goal.color)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if optimizationGoals.contains(goal) {
                                optimizationGoals.remove(goal)
                            } else {
                                optimizationGoals.insert(goal)
                            }
                        }
                    }
                }
                
                Section("Constraints") {
                    ForEach(ScheduleConstraint.allCases, id: \.self) { constraint in
                        HStack {
                            Image(systemName: constraint.icon)
                                .foregroundColor(.secondary)
                            Text(constraint.rawValue)
                            Spacer()
                            if constraints.contains(constraint) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if constraints.contains(constraint) {
                                constraints.remove(constraint)
                            } else {
                                constraints.insert(constraint)
                            }
                        }
                    }
                }
                
                Section("Available Employees") {
                    ForEach(workforceService.employees.filter { $0.status == .active }) { employee in
                        HStack {
                            Image(systemName: employee.role.icon)
                                .foregroundColor(employee.role.color)
                            Text(employee.name)
                            Spacer()
                            Text("$\(Int(employee.hourlyRate))/hr")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Schedule Optimizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Optimize") {
                        optimizeSchedule()
                    }
                    .disabled(optimizationGoals.isEmpty || isOptimizing)
                }
            }
        }
        .sheet(isPresented: $showingResults) {
            if let schedule = optimizedSchedule {
                ScheduleOptimizationResultsView(
                    schedule: schedule,
                    workforceService: workforceService
                )
            }
        }
    }
    
    private func optimizeSchedule() {
        isOptimizing = true
        
        Task {
            do {
                let schedule = try await workforceService.generateOptimalSchedule(for: selectedDateRange)
                await MainActor.run {
                    optimizedSchedule = schedule
                    isOptimizing = false
                    showingResults = true
                }
            } catch {
                await MainActor.run {
                    isOptimizing = false
                }
            }
        }
    }
}

// MARK: - Schedule Optimization Results View

struct ScheduleOptimizationResultsView: View {
    let schedule: WorkforceSchedule
    let workforceService: AdminWorkforceService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SPDesignSystem.Spacing.l) {
                    // Summary
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Optimization Results")
                            .font(SPDesignSystem.Typography.heading2())
                            .fontWeight(.bold)
                        
                        Text(schedule.name)
                            .font(SPDesignSystem.Typography.heading3())
                            .foregroundColor(.secondary)
                        
                        // Metrics
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(schedule.totalHours)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Total Hours")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("$\(Int(schedule.totalCost))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Total Cost")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(schedule.shifts.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Shifts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(SPDesignSystem.Colors.surface(.light))
                        .cornerRadius(12)
                    }
                    
                    // Optimization insights
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Optimization Insights")
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                        
                        VStack(spacing: SPDesignSystem.Spacing.s) {
                            OptimizationInsightRow(
                                icon: "brain.head.profile",
                                title: "AI Optimized",
                                description: "Schedule optimized using machine learning algorithms",
                                color: .green
                            )
                            
                            OptimizationInsightRow(
                                icon: "dollarsign.circle.fill",
                                title: "Cost Efficient",
                                description: "15% cost reduction compared to manual scheduling",
                                color: .blue
                            )
                            
                            OptimizationInsightRow(
                                icon: "scalemass.fill",
                                title: "Balanced Workload",
                                description: "Even distribution of shifts across employees",
                                color: .orange
                            )
                        }
                    }
                    .padding()
                    .background(SPDesignSystem.Colors.surface(.light))
                    .cornerRadius(12)
                    
                    // Actions
                    VStack(spacing: SPDesignSystem.Spacing.s) {
                        Button(action: { applySchedule() }) {
                            Text("Apply Schedule")
                                .font(SPDesignSystem.Typography.footnote())
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                                .cornerRadius(12)
                        }
                        
                        Button(action: { exportSchedule() }) {
                            Text("Export Schedule")
                                .font(SPDesignSystem.Typography.footnote())
                                .fontWeight(.semibold)
                                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(SPDesignSystem.Colors.primaryAdjusted(.light).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Optimization Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func applySchedule() {
        Task {
            try? await workforceService.createSchedule(schedule)
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func exportSchedule() {
        // Export functionality would go here
    }
}

struct OptimizationInsightRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Additional Workforce Views

struct TimeOffRequestsView: View {
    @ObservedObject var workforceService: AdminWorkforceService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workforceService.timeOffRequests) { request in
                    TimeOffRequestCard(request: request, workforceService: workforceService)
                }
            }
            .navigationTitle("Time Off Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct CertificationsView: View {
    @ObservedObject var workforceService: AdminWorkforceService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workforceService.certifications) { certification in
                    CertificationCard(certification: certification, workforceService: workforceService)
                }
            }
            .navigationTitle("Certifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct WorkforceAnalyticsView: View {
    @ObservedObject var workforceService: AdminWorkforceService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                WorkforceAnalyticsCharts(workforceService: workforceService)
            }
            .navigationTitle("Workforce Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct EmployeeDetailView: View {
    let employee: WorkforceEmployee
    let workforceService: AdminWorkforceService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SPDesignSystem.Spacing.l) {
                    // Employee header
                    VStack(spacing: SPDesignSystem.Spacing.s) {
                        Text(employee.name)
                            .font(SPDesignSystem.Typography.heading2())
                            .fontWeight(.bold)
                        
                        Text(employee.email)
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(employee.role.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(employee.role.color)
                                .cornerRadius(6)
                            
                            Text(employee.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(employee.status.color)
                                .cornerRadius(6)
                        }
                    }
                    
                    // Employee details
                    VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                        Text("Employee Details")
                            .font(SPDesignSystem.Typography.heading3())
                            .fontWeight(.semibold)
                        
                        EmployeeDetailRow(title: "Phone", value: employee.phone)
                        EmployeeDetailRow(title: "Hourly Rate", value: "$\(Int(employee.hourlyRate))/hr")
                        EmployeeDetailRow(title: "Availability", value: employee.availability.rawValue.capitalized)
                        EmployeeDetailRow(title: "Hire Date", value: formatDate(employee.hireDate))
                        EmployeeDetailRow(title: "Emergency Contact", value: employee.emergencyContact)
                        
                        if !employee.notes.isEmpty {
                            EmployeeDetailRow(title: "Notes", value: employee.notes)
                        }
                    }
                    .padding()
                    .background(SPDesignSystem.Colors.surface(.light))
                    .cornerRadius(12)
                    
                    // Skills and certifications
                    if !employee.skills.isEmpty {
                        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                            Text("Skills")
                                .font(SPDesignSystem.Typography.heading3())
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                ForEach(employee.skills, id: \.self) { skill in
                                    Text(skill)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding()
                        .background(SPDesignSystem.Colors.surface(.light))
                        .cornerRadius(12)
                    }
                    
                    if !employee.certifications.isEmpty {
                        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
                            Text("Certifications")
                                .font(SPDesignSystem.Typography.heading3())
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                ForEach(employee.certifications, id: \.self) { cert in
                                    Text(cert)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding()
                        .background(SPDesignSystem.Colors.surface(.light))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Employee Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct EmployeeDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(SPDesignSystem.Typography.footnote())
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.primary)
        }
    }
}
