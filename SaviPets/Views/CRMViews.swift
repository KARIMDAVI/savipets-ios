import SwiftUI
import Charts

// MARK: - Supporting Components

struct CRMMetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
            
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

struct CRMInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(SPDesignSystem.Typography.body())
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

// MARK: - Client Detail View

struct ClientDetailView: View {
    let client: CRMClient
    let crmService: AdminCRMService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .overview
    @State private var showingAddInteraction = false
    @State private var showingAddTask = false
    @State private var showingEditClient = false
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case interactions = "Interactions"
        case tasks = "Tasks"
        case notes = "Notes"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .overview: return "house.fill"
            case .interactions: return "bubble.left.and.bubble.right.fill"
            case .tasks: return "checkmark.circle.fill"
            case .notes: return "note.text"
            case .analytics: return "chart.bar.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Client Header
                clientHeader
                
                // Tab Selector
                tabSelector
                
                // Content
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(DetailTab.overview)
                    
                    interactionsTab
                        .tag(DetailTab.interactions)
                    
                    tasksTab
                        .tag(DetailTab.tasks)
                    
                    notesTab
                        .tag(DetailTab.notes)
                    
                    analyticsTab
                        .tag(DetailTab.analytics)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle(client.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button(action: { showingAddInteraction = true }) {
                            Label("Add Interaction", systemImage: "plus.message")
                        }
                        
                        Button(action: { showingAddTask = true }) {
                            Label("Add Task", systemImage: "plus.circle")
                        }
                        
                        Divider()
                        
                        Button(action: { showingEditClient = true }) {
                            Label("Edit Client", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddInteraction) {
                AddInteractionView(clientId: client.id, crmService: crmService)
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(clientId: client.id, crmService: crmService)
            }
            .sheet(isPresented: $showingEditClient) {
                EditClientView(client: client, crmService: crmService)
            }
        }
    }
    
    private var clientHeader: some View {
        VStack(spacing: SPDesignSystem.Spacing.m) {
            // Profile section
            HStack(spacing: SPDesignSystem.Spacing.m) {
                // Avatar
                Circle()
                    .fill(SPDesignSystem.Colors.primaryAdjusted(.light))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(client.name.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(SPDesignSystem.Typography.heading2())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(client.company)
                        .font(SPDesignSystem.Typography.body())
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: SPDesignSystem.Spacing.s) {
                        // Status
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
                        
                        // Source
                        HStack(spacing: 4) {
                            Image(systemName: client.source.icon)
                                .font(.caption)
                            Text(client.source.rawValue.capitalized)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Metrics
            HStack(spacing: SPDesignSystem.Spacing.l) {
                CRMMetricCard(title: "Bookings", value: "\(client.totalBookings)", icon: "calendar.badge.checkmark")
                CRMMetricCard(title: "Revenue", value: "$\(Int(client.totalRevenue))", icon: "dollarsign.circle.fill")
                CRMMetricCard(title: "LTV", value: "$\(Int(client.lifetimeValue))", icon: "chart.line.uptrend.xyaxis")
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
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
    
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                // Contact Information
                InfoSection(title: "Contact Information") {
                    CRMInfoRow(label: "Email", value: client.email)
                    CRMInfoRow(label: "Phone", value: client.phone)
                    CRMInfoRow(label: "Company", value: client.company)
                    CRMInfoRow(label: "Created", value: formatDate(client.createdAt))
                    CRMInfoRow(label: "Last Contact", value: formatDate(client.lastContactDate))
                }
                
                // Tags
                if !client.tags.isEmpty {
                    InfoSection(title: "Tags") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: SPDesignSystem.Spacing.s) {
                            ForEach(client.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(SPDesignSystem.Colors.primaryAdjusted(.light))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // Notes
                if !client.notes.isEmpty {
                    InfoSection(title: "Notes") {
                        Text(client.notes)
                            .font(SPDesignSystem.Typography.body())
                            .foregroundColor(.secondary)
                    }
                }
                
                // Insights
                let insights = crmService.generateClientInsights(client.id)
                if !insights.isEmpty {
                    InfoSection(title: "AI Insights") {
                        ForEach(insights) { insight in
                            CRMInsightRow(insight: insight)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var interactionsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.s) {
                ForEach(crmService.getClientInteractions(client.id)) { interaction in
                    InteractionRow(interaction: interaction)
                }
            }
            .padding()
        }
    }
    
    private var tasksTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.s) {
                ForEach(crmService.tasks.filter { $0.clientId == client.id }) { task in
                    TaskRow(task: task, crmService: crmService)
                }
            }
            .padding()
        }
    }
    
    private var notesTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.s) {
                ForEach(crmService.notes.filter { $0.clientId == client.id }) { note in
                    NoteRow(note: note)
                }
            }
            .padding()
        }
    }
    
    private var analyticsTab: some View {
        ScrollView {
            LazyVStack(spacing: SPDesignSystem.Spacing.m) {
                // Client analytics charts
                AdvancedChartCard(
                    title: "Booking Trends",
                    subtitle: "Client booking patterns over time",
                    chartData: bookingTrendData,
                    chartType: .line,
                    timeRange: .month
                )
                
                AdvancedChartCard(
                    title: "Revenue Breakdown",
                    subtitle: "Revenue by service type",
                    chartData: revenueBreakdownData,
                    chartType: .pie,
                    timeRange: .month
                )
            }
            .padding()
        }
    }
    
    private var bookingTrendData: [ChartDataPoint] {
        // Sample booking trend data
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
        let bookings = [2, 3, 1, 4, 2, 3]
        
        return zip(months, bookings).map { month, booking in
            ChartDataPoint(
                xValue: month,
                yValue: Double(booking),
                color: .blue,
                label: "\(booking) bookings"
            )
        }
    }
    
    private var revenueBreakdownData: [ChartDataPoint] {
        // Sample revenue breakdown
        let services = ["Walking", "Sitting", "Boarding", "Grooming"]
        let revenues = [800, 1200, 400, 100]
        
        return zip(services, revenues).map { service, revenue in
            ChartDataPoint(
                xValue: service,
                yValue: Double(revenue),
                color: .green,
                label: "$\(revenue)"
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct CRMCRMMetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
            
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

struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            Text(title)
                .font(SPDesignSystem.Typography.heading3())
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            content
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
}

struct CRMCRMInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(SPDesignSystem.Typography.body())
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

struct CRMInsightRow: View {
    let insight: CRMInsight
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            Circle()
                .fill(insight.priority.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if insight.actionable {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption)
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(.light))
            }
        }
        .padding(SPDesignSystem.Spacing.s)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct InteractionRow: View {
    let interaction: CRMInteraction
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
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

struct TaskRow: View {
    let task: CRMTask
    let crmService: AdminCRMService
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            Button(action: { completeTask() }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(SPDesignSystem.Typography.footnote())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .strikethrough(task.isCompleted)
                
                Text(task.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if let dueDate = task.dueDate {
                    Text("Due: \(formatDate(dueDate))")
                        .font(.caption2)
                        .foregroundColor(dueDate < Date() ? .red : .secondary)
                }
            }
            
            Spacer()
            
            // Priority indicator
            Circle()
                .fill(task.priority.color)
                .frame(width: 8, height: 8)
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func completeTask() {
        Task {
            try? await crmService.completeTask(task.id)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct NoteRow: View {
    let note: CRMNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Text(note.content)
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.primary)
                
                Spacer()
                
                if note.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("By \(note.author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDate(note.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(.light))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Add Client View

struct AddClientView: View {
    let crmService: AdminCRMService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var company = ""
    @State private var status: CRMClient.ClientStatus = .active
    @State private var source: CRMClient.ClientSource = .website
    @State private var notes = ""
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Company", text: $company)
                }
                
                Section("Status & Source") {
                    Picker("Status", selection: $status) {
                        ForEach(CRMClient.ClientStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(status)
                        }
                    }
                    
                    Picker("Source", selection: $source) {
                        ForEach(CRMClient.ClientSource.allCases, id: \.self) { source in
                            Text(source.rawValue.capitalized).tag(source)
                        }
                    }
                }
                
                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                    }
                    
                    HStack {
                        TextField("Add tag", text: $newTag)
                        Button("Add") {
                            if !newTag.isEmpty {
                                tags.append(newTag)
                                newTag = ""
                            }
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveClient() }
                        .disabled(name.isEmpty || email.isEmpty)
                }
            }
        }
    }
    
    private func saveClient() {
        let client = CRMClient(
            id: UUID().uuidString,
            name: name,
            email: email,
            phone: phone,
            company: company,
            status: status,
            source: source,
            tags: tags,
            customFields: [:],
            createdAt: Date(),
            lastContactDate: Date(),
            totalBookings: 0,
            totalRevenue: 0.0,
            lifetimeValue: 0.0,
            notes: notes
        )
        
        Task {
            try? await crmService.createClient(client)
            dismiss()
        }
    }
}

// MARK: - Add Lead View

struct AddLeadView: View {
    let crmService: AdminCRMService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var company = ""
    @State private var status: CRMLead.LeadStatus = .new
    @State private var source: CRMClient.ClientSource = .website
    @State private var score = 50
    @State private var notes = ""
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Company", text: $company)
                }
                
                Section("Lead Details") {
                    Picker("Status", selection: $status) {
                        ForEach(CRMLead.LeadStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(status)
                        }
                    }
                    
                    Picker("Source", selection: $source) {
                        ForEach(CRMClient.ClientSource.allCases, id: \.self) { source in
                            Text(source.rawValue.capitalized).tag(source)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Lead Score: \(score)")
                            .font(.footnote)
                        Slider(value: Binding(
                            get: { Double(score) },
                            set: { score = Int($0) }
                        ), in: 0...100, step: 1)
                    }
                }
                
                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                    }
                    
                    HStack {
                        TextField("Add tag", text: $newTag)
                        Button("Add") {
                            if !newTag.isEmpty {
                                tags.append(newTag)
                                newTag = ""
                            }
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLead() }
                        .disabled(name.isEmpty || email.isEmpty)
                }
            }
        }
    }
    
    private func saveLead() {
        let lead = CRMLead(
            id: UUID().uuidString,
            name: name,
            email: email,
            phone: phone,
            company: company,
            status: status,
            source: source,
            tags: tags,
            customFields: [:],
            createdAt: Date(),
            lastContactDate: Date(),
            score: score,
            notes: notes
        )
        
        Task {
            try? await crmService.createLead(lead)
            dismiss()
        }
    }
}

// MARK: - Add Interaction View

struct AddInteractionView: View {
    let clientId: String
    let crmService: AdminCRMService
    @Environment(\.dismiss) private var dismiss
    
    @State private var type: CRMInteraction.InteractionType = .email
    @State private var subject = ""
    @State private var description = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Interaction Details") {
                    Picker("Type", selection: $type) {
                        ForEach(CRMInteraction.InteractionType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    
                    TextField("Subject", text: $subject)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Interaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveInteraction() }
                        .disabled(subject.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func saveInteraction() {
        let interaction = CRMInteraction(
            id: UUID().uuidString,
            clientId: clientId,
            type: type,
            subject: subject,
            description: description,
            timestamp: Date(),
            metadata: [:]
        )
        
        Task {
            try? await crmService.logInteraction(interaction)
            dismiss()
        }
    }
}

// MARK: - Add Task View

struct AddTaskView: View {
    let clientId: String
    let crmService: AdminCRMService
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var type: CRMTask.TaskType = .call
    @State private var priority: CRMTask.TaskPriority = .medium
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Type", selection: $type) {
                        ForEach(CRMTask.TaskType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(CRMTask.TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue.capitalized).tag(priority)
                        }
                    }
                }
                
                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func saveTask() {
        let task = CRMTask(
            id: UUID().uuidString,
            title: title,
            description: description,
            clientId: clientId,
            type: type,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            isCompleted: false,
            createdAt: Date(),
            completedAt: nil
        )
        
        Task {
            try? await crmService.createTask(task)
            dismiss()
        }
    }
}

// MARK: - Edit Client View

struct EditClientView: View {
    let client: CRMClient
    let crmService: AdminCRMService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var company: String
    @State private var status: CRMClient.ClientStatus
    @State private var notes: String
    
    init(client: CRMClient, crmService: AdminCRMService) {
        self.client = client
        self.crmService = crmService
        self._name = State(initialValue: client.name)
        self._email = State(initialValue: client.email)
        self._phone = State(initialValue: client.phone)
        self._company = State(initialValue: client.company)
        self._status = State(initialValue: client.status)
        self._notes = State(initialValue: client.notes)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Company", text: $company)
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(CRMClient.ClientStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(status)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveClient() }
                        .disabled(name.isEmpty || email.isEmpty)
                }
            }
        }
    }
    
    private func saveClient() {
        let updatedClient = CRMClient(
            id: client.id,
            name: name,
            email: email,
            phone: phone,
            company: company,
            status: status,
            source: client.source,
            tags: client.tags,
            customFields: client.customFields,
            createdAt: client.createdAt,
            lastContactDate: client.lastContactDate,
            totalBookings: client.totalBookings,
            totalRevenue: client.totalRevenue,
            lifetimeValue: client.lifetimeValue,
            notes: notes
        )
        
        Task {
            try? await crmService.updateClient(updatedClient)
            dismiss()
        }
    }
}

// MARK: - Campaign Management View

struct CampaignManagementView: View {
    let crmService: AdminCRMService
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateCampaign = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(crmService.campaigns) { campaign in
                    CampaignRow(campaign: campaign, crmService: crmService)
                }
            }
            .navigationTitle("Campaigns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { showingCreateCampaign = true }
                }
            }
            .sheet(isPresented: $showingCreateCampaign) {
                CreateCampaignView(crmService: crmService)
            }
        }
    }
}

struct CampaignRow: View {
    let campaign: CRMCampaign
    let crmService: AdminCRMService
    
    var body: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Text(campaign.name)
                    .font(SPDesignSystem.Typography.heading3())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(campaign.status.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(campaign.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(campaign.status.color.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Text(campaign.description)
                .font(SPDesignSystem.Typography.footnote())
                .foregroundColor(.secondary)
            
            HStack {
                MetricItem(title: "Sent", value: "\(campaign.metrics.sent)")
                MetricItem(title: "Opened", value: "\(campaign.metrics.opened)")
                MetricItem(title: "Clicked", value: "\(campaign.metrics.clicked)")
                MetricItem(title: "Revenue", value: "$\(Int(campaign.metrics.revenue))")
            }
        }
        .padding(SPDesignSystem.Spacing.s)
    }
}

struct CreateCampaignView: View {
    let crmService: AdminCRMService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var type: CRMCampaign.CampaignType = .email
    @State private var budget: Double = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Campaign Details") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Type", selection: $type) {
                        ForEach(CRMCampaign.CampaignType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    
                    TextField("Budget", value: $budget, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Create Campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createCampaign() }
                        .disabled(name.isEmpty || description.isEmpty)
                }
            }
        }
    }
    
    private func createCampaign() {
        let campaign = CRMCampaign(
            id: UUID().uuidString,
            name: name,
            description: description,
            type: type,
            status: .draft,
            targetAudience: [],
            startDate: Date(),
            endDate: nil,
            budget: budget > 0 ? budget : nil,
            metrics: CRMCampaign.CampaignMetrics(
                sent: 0,
                delivered: 0,
                opened: 0,
                clicked: 0,
                converted: 0,
                revenue: 0
            ),
            createdAt: Date()
        )
        
        Task {
            try? await crmService.createCampaign(campaign)
            dismiss()
        }
    }
}

// MARK: - CRM Analytics View

struct CRMAnalyticsView: View {
    let crmService: AdminCRMService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: SPDesignSystem.Spacing.l) {
                    // Overview metrics
                    VStack(spacing: SPDesignSystem.Spacing.m) {
                        Text("CRM Overview")
                            .font(SPDesignSystem.Typography.heading2())
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SPDesignSystem.Spacing.m) {
                            CRMMetricCard(title: "Total Clients", value: "\(crmService.clients.count)", icon: "person.2.fill")
                            CRMMetricCard(title: "Active Clients", value: "\(crmService.clients.filter { $0.status == .active }.count)", icon: "checkmark.circle.fill")
                            CRMMetricCard(title: "Total Leads", value: "\(crmService.leads.count)", icon: "person.circle.fill")
                            CRMMetricCard(title: "Total Revenue", value: "$\(Int(crmService.clients.reduce(0) { $0 + $1.totalRevenue }))", icon: "dollarsign.circle.fill")
                        }
                    }
                    
                    // Analytics charts
                    CRMAnalyticsCharts(crmService: crmService)
                }
                .padding()
            }
            .navigationTitle("CRM Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
