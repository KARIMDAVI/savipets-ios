import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import OSLog

// MARK: - Advanced CRM Service

class AdminCRMService: ObservableObject {
    @Published var clients: [CRMClient] = []
    @Published var leads: [CRMLead] = []
    @Published var interactions: [CRMInteraction] = []
    @Published var campaigns: [CRMCampaign] = []
    @Published var opportunities: [CRMOpportunity] = []
    @Published var tasks: [CRMTask] = []
    @Published var notes: [CRMNote] = []
    @Published var tags: [CRMTag] = []
    @Published var customFields: [CRMCustomField] = []
    @Published var emailTemplates: [CRMEmailTemplate] = []
    @Published var analytics: CRMAnalytics = CRMAnalytics(
        totalClients: 0,
        activeClients: 0,
        totalLeads: 0,
        conversionRate: 0.0,
        averageLifetimeValue: 0.0,
        totalRevenue: 0.0,
        monthlyGrowth: 0.0,
        topSources: [:],
        clientSatisfaction: 0.0
    )
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "SaviPets", category: "AdminCRM")
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadInitialData()
        setupRealTimeListeners()
    }
    
    // MARK: - Client Management
    
    func createClient(_ client: CRMClient) async throws {
        try db.collection("crm_clients").document(client.id).setData(from: client)
        logger.info("Client created: \(client.email)")
    }
    
    func updateClient(_ client: CRMClient) async throws {
        try db.collection("crm_clients").document(client.id).setData(from: client)
        logger.info("Client updated: \(client.email)")
    }
    
    func deleteClient(_ clientId: String) async throws {
        try await db.collection("crm_clients").document(clientId).delete()
        logger.info("Client deleted: \(clientId)")
    }
    
    func getClientById(_ clientId: String) -> CRMClient? {
        return clients.first { $0.id == clientId }
    }
    
    func searchClients(query: String) -> [CRMClient] {
        let lowercaseQuery = query.lowercased()
        return clients.filter { client in
            client.name.lowercased().contains(lowercaseQuery) ||
            client.email.lowercased().contains(lowercaseQuery) ||
            client.phone.lowercased().contains(lowercaseQuery) ||
            client.company.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Lead Management
    
    func createLead(_ lead: CRMLead) async throws {
        try db.collection("crm_leads").document(lead.id).setData(from: lead)
        logger.info("Lead created: \(lead.email)")
    }
    
    func convertLeadToClient(_ leadId: String) async throws {
        guard let lead = leads.first(where: { $0.id == leadId }) else { return }
        
        let client = CRMClient(
            id: UUID().uuidString,
            name: lead.name,
            email: lead.email,
            phone: lead.phone,
            company: lead.company,
            status: .active,
            source: lead.source,
            tags: lead.tags,
            customFields: lead.customFields,
            createdAt: Date(),
            lastContactDate: Date(),
            totalBookings: 0,
            totalRevenue: 0.0,
            lifetimeValue: 0.0,
            notes: lead.notes
        )
        
        try await createClient(client)
        try await db.collection("crm_leads").document(leadId).delete()
        logger.info("Lead converted to client: \(lead.email)")
    }
    
    // MARK: - Interaction Management
    
    func logInteraction(_ interaction: CRMInteraction) async throws {
        try db.collection("crm_interactions").document(interaction.id).setData(from: interaction)
        
        // Update client's last contact date
        if let clientIndex = clients.firstIndex(where: { $0.id == interaction.clientId }) {
            clients[clientIndex].lastContactDate = interaction.timestamp
        }
        
        logger.info("Interaction logged: \(interaction.type.rawValue)")
    }
    
    func getClientInteractions(_ clientId: String) -> [CRMInteraction] {
        return interactions.filter { $0.clientId == clientId }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Campaign Management
    
    func createCampaign(_ campaign: CRMCampaign) async throws {
        try db.collection("crm_campaigns").document(campaign.id).setData(from: campaign)
        logger.info("Campaign created: \(campaign.name)")
    }
    
    func executeCampaign(_ campaignId: String) async throws {
        guard let campaign = campaigns.first(where: { $0.id == campaignId }) else { return }
        
        // Execute campaign logic based on type
        switch campaign.type {
        case .email:
            try await executeEmailCampaign(campaign)
        case .sms:
            try await executeSMSCampaign(campaign)
        case .phone:
            try await executePhoneCampaign(campaign)
        case .social:
            try await executeSocialCampaign(campaign)
        case .advertising:
            try await executeAdvertisingCampaign(campaign)
        }
        
        logger.info("Campaign executed: \(campaign.name)")
    }
    
    // MARK: - Opportunity Management
    
    func createOpportunity(_ opportunity: CRMOpportunity) async throws {
        try db.collection("crm_opportunities").document(opportunity.id).setData(from: opportunity)
        logger.info("Opportunity created: \(opportunity.name)")
    }
    
    func updateOpportunityStage(_ opportunityId: String, stage: CRMOpportunity.Stage) async throws {
        try await db.collection("crm_opportunities").document(opportunityId).updateData([
            "stage": stage.rawValue,
            "lastUpdated": Timestamp(date: Date())
        ])
        logger.info("Opportunity stage updated: \(stage.rawValue)")
    }
    
    // MARK: - Task Management
    
    func createTask(_ task: CRMTask) async throws {
        try db.collection("crm_tasks").document(task.id).setData(from: task)
        logger.info("Task created: \(task.title)")
    }
    
    func completeTask(_ taskId: String) async throws {
        try await db.collection("crm_tasks").document(taskId).updateData([
            "isCompleted": true,
            "completedAt": Timestamp(date: Date())
        ])
        logger.info("Task completed: \(taskId)")
    }
    
    // MARK: - Analytics
    
    func calculateClientLifetimeValue(_ clientId: String) -> Double {
        let clientInteractions = getClientInteractions(clientId)
        let bookingInteractions = clientInteractions.filter { $0.type == .booking }
        
        return bookingInteractions.reduce(0.0) { total, interaction in
            total + (interaction.metadata["revenue"] as? Double ?? 0.0)
        }
    }
    
    func getClientEngagementScore(_ clientId: String) -> Double {
        let clientInteractions = getClientInteractions(clientId)
        let daysSinceLastContact = Date().timeIntervalSince(clientInteractions.first?.timestamp ?? Date()) / 86400
        
        // Calculate engagement score based on interaction frequency and recency
        let interactionCount = Double(clientInteractions.count)
        let recencyScore = max(0, 100 - daysSinceLastContact)
        
        return min(100, (interactionCount * 10) + (recencyScore * 0.5))
    }
    
    func generateClientInsights(_ clientId: String) -> [CRMInsight] {
        var insights: [CRMInsight] = []
        
        guard let client = getClientById(clientId) else { return insights }
        let clientInteractions = getClientInteractions(clientId)
        
        // High-value client insight
        if client.lifetimeValue > 1000 {
            insights.append(CRMInsight(
                type: .highValue,
                title: "High-Value Client",
                description: "This client has generated significant revenue",
                priority: .high,
                actionable: true
            ))
        }
        
        // Engagement insight
        let engagementScore = getClientEngagementScore(clientId)
        if engagementScore < 30 {
            insights.append(CRMInsight(
                type: .engagement,
                title: "Low Engagement",
                description: "Client engagement is low. Consider reaching out",
                priority: .medium,
                actionable: true
            ))
        }
        
        // Booking pattern insight
        let bookingInteractions = clientInteractions.filter { $0.type == .booking }
        if bookingInteractions.count > 5 {
            insights.append(CRMInsight(
                type: .pattern,
                title: "Frequent Booker",
                description: "This client books services regularly",
                priority: .low,
                actionable: false
            ))
        }
        
        return insights
    }
    
    // MARK: - Private Methods
    
    private func loadInitialData() {
        // Load sample data for development
        loadSampleData()
    }
    
    private func setupRealTimeListeners() {
        // Listen to clients
        db.collection("crm_clients")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.clients = documents.compactMap { doc in
                        try? doc.data(as: CRMClient.self)
                    }
                }
            }
        
        // Listen to leads
        db.collection("crm_leads")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.leads = documents.compactMap { doc in
                        try? doc.data(as: CRMLead.self)
                    }
                }
            }
        
        // Listen to interactions
        db.collection("crm_interactions")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.interactions = documents.compactMap { doc in
                        try? doc.data(as: CRMInteraction.self)
                    }
                }
            }
    }
    
    private func loadSampleData() {
        // Sample clients
        clients = [
            CRMClient(
                id: "1",
                name: "Sarah Johnson",
                email: "sarah.johnson@email.com",
                phone: "+1-555-0123",
                company: "Tech Corp",
                status: .active,
                source: .referral,
                tags: ["VIP", "Regular"],
                customFields: [:],
                createdAt: Date().addingTimeInterval(-86400 * 30),
                lastContactDate: Date().addingTimeInterval(-86400 * 2),
                totalBookings: 15,
                totalRevenue: 2500.0,
                lifetimeValue: 2500.0,
                notes: "Prefers morning walks"
            ),
            CRMClient(
                id: "2",
                name: "Mike Chen",
                email: "mike.chen@email.com",
                phone: "+1-555-0124",
                company: "Design Studio",
                status: .active,
                source: .website,
                tags: ["New"],
                customFields: [:],
                createdAt: Date().addingTimeInterval(-86400 * 7),
                lastContactDate: Date().addingTimeInterval(-86400 * 1),
                totalBookings: 3,
                totalRevenue: 450.0,
                lifetimeValue: 450.0,
                notes: "Has two dogs"
            )
        ]
        
        // Sample leads
        leads = [
            CRMLead(
                id: "1",
                name: "Emily Davis",
                email: "emily.davis@email.com",
                phone: "+1-555-0125",
                company: "Marketing Agency",
                status: .new,
                source: .social,
                tags: ["Hot Lead"],
                customFields: [:],
                createdAt: Date().addingTimeInterval(-86400 * 3),
                lastContactDate: Date().addingTimeInterval(-86400 * 1),
                score: 85,
                notes: "Interested in pet sitting services"
            )
        ]
        
        // Sample interactions
        interactions = [
            CRMInteraction(
                id: "1",
                clientId: "1",
                type: .email,
                subject: "Service Confirmation",
                description: "Confirmed booking for next week",
                timestamp: Date().addingTimeInterval(-86400 * 2),
                metadata: ["bookingId": "123"]
            ),
            CRMInteraction(
                id: "2",
                clientId: "2",
                type: .phone,
                subject: "Service Inquiry",
                description: "Called to ask about weekend availability",
                timestamp: Date().addingTimeInterval(-86400 * 1),
                metadata: [:]
            )
        ]
    }
    
    private func executeEmailCampaign(_ campaign: CRMCampaign) async throws {
        // Implement email campaign execution
        logger.info("Executing email campaign: \(campaign.name)")
    }
    
    private func executeSMSCampaign(_ campaign: CRMCampaign) async throws {
        // Implement SMS campaign execution
        logger.info("Executing SMS campaign: \(campaign.name)")
    }
    
    private func executePhoneCampaign(_ campaign: CRMCampaign) async throws {
        // Implement phone campaign execution
        logger.info("Executing phone campaign: \(campaign.name)")
    }
    
    private func executeSocialCampaign(_ campaign: CRMCampaign) async throws {
        // Implement social media campaign execution
        logger.info("Executing social campaign: \(campaign.name)")
    }
    
    private func executeAdvertisingCampaign(_ campaign: CRMCampaign) async throws {
        // Implement advertising campaign execution
        logger.info("Executing advertising campaign: \(campaign.name)")
    }
}

// MARK: - CRM Data Models

struct CRMClient: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let phone: String
    let company: String
    let status: ClientStatus
    let source: ClientSource
    let tags: [String]
    let customFields: [String: String]
    let createdAt: Date
    var lastContactDate: Date
    let totalBookings: Int
    let totalRevenue: Double
    let lifetimeValue: Double
    let notes: String
    
    enum ClientStatus: String, CaseIterable, Codable {
        case active = "active"
        case inactive = "inactive"
        case prospect = "prospect"
        case churned = "churned"
        
        var color: Color {
            switch self {
            case .active: return .green
            case .inactive: return .orange
            case .prospect: return .blue
            case .churned: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "checkmark.circle.fill"
            case .inactive: return "pause.circle.fill"
            case .prospect: return "person.circle.fill"
            case .churned: return "xmark.circle.fill"
            }
        }
    }
    
    enum ClientSource: String, CaseIterable, Codable {
        case website = "website"
        case referral = "referral"
        case social = "social"
        case advertising = "advertising"
        case direct = "direct"
        case partner = "partner"
        
        var icon: String {
            switch self {
            case .website: return "globe"
            case .referral: return "person.2.fill"
            case .social: return "at"
            case .advertising: return "megaphone.fill"
            case .direct: return "phone.fill"
            case .partner: return "handshake.fill"
            }
        }
    }
}

struct CRMLead: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let phone: String
    let company: String
    let status: LeadStatus
    let source: CRMClient.ClientSource
    let tags: [String]
    let customFields: [String: String]
    let createdAt: Date
    let lastContactDate: Date
    let score: Int
    let notes: String
    
    enum LeadStatus: String, CaseIterable, Codable {
        case new = "new"
        case contacted = "contacted"
        case qualified = "qualified"
        case proposal = "proposal"
        case negotiation = "negotiation"
        case closed = "closed"
        case lost = "lost"
        
        var color: Color {
            switch self {
            case .new: return .blue
            case .contacted: return .cyan
            case .qualified: return .green
            case .proposal: return .orange
            case .negotiation: return .yellow
            case .closed: return .purple
            case .lost: return .red
            }
        }
    }
}

struct CRMInteraction: Codable, Identifiable {
    let id: String
    let clientId: String
    let type: InteractionType
    let subject: String
    let description: String
    let timestamp: Date
    let metadata: [String: String]
    
    enum InteractionType: String, CaseIterable, Codable {
        case email = "email"
        case phone = "phone"
        case sms = "sms"
        case meeting = "meeting"
        case booking = "booking"
        case support = "support"
        case social = "social"
        
        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .phone: return "phone.fill"
            case .sms: return "message.fill"
            case .meeting: return "calendar"
            case .booking: return "calendar.badge.plus"
            case .support: return "questionmark.circle.fill"
            case .social: return "at"
            }
        }
        
        var color: Color {
            switch self {
            case .email: return .blue
            case .phone: return .green
            case .sms: return .orange
            case .meeting: return .purple
            case .booking: return .red
            case .support: return .yellow
            case .social: return .cyan
            }
        }
    }
}

struct CRMCampaign: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let type: CampaignType
    let status: CampaignStatus
    let targetAudience: [String]
    let startDate: Date
    let endDate: Date?
    let budget: Double?
    let metrics: CampaignMetrics
    let createdAt: Date
    
    enum CampaignType: String, CaseIterable, Codable {
        case email = "email"
        case sms = "sms"
        case phone = "phone"
        case social = "social"
        case advertising = "advertising"
        
        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .sms: return "message.fill"
            case .phone: return "phone.fill"
            case .social: return "at"
            case .advertising: return "megaphone.fill"
            }
        }
    }
    
    enum CampaignStatus: String, CaseIterable, Codable {
        case draft = "draft"
        case scheduled = "scheduled"
        case running = "running"
        case completed = "completed"
        case paused = "paused"
        case cancelled = "cancelled"
        
        var color: Color {
            switch self {
            case .draft: return .gray
            case .scheduled: return .blue
            case .running: return .green
            case .completed: return .purple
            case .paused: return .orange
            case .cancelled: return .red
            }
        }
    }
    
    struct CampaignMetrics: Codable {
        let sent: Int
        let delivered: Int
        let opened: Int
        let clicked: Int
        let converted: Int
        let revenue: Double
    }
}

struct CRMOpportunity: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let clientId: String
    let stage: Stage
    let value: Double
    let probability: Int
    let expectedCloseDate: Date
    let createdAt: Date
    let lastUpdated: Date
    
    enum Stage: String, CaseIterable, Codable {
        case lead = "lead"
        case qualified = "qualified"
        case proposal = "proposal"
        case negotiation = "negotiation"
        case closedWon = "closed_won"
        case closedLost = "closed_lost"
        
        var color: Color {
            switch self {
            case .lead: return .blue
            case .qualified: return .cyan
            case .proposal: return .orange
            case .negotiation: return .yellow
            case .closedWon: return .green
            case .closedLost: return .red
            }
        }
    }
}

struct CRMTask: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let clientId: String?
    let type: TaskType
    let priority: TaskPriority
    let dueDate: Date?
    let isCompleted: Bool
    let createdAt: Date
    let completedAt: Date?
    
    enum TaskType: String, CaseIterable, Codable {
        case call = "call"
        case email = "email"
        case meeting = "meeting"
        case followUp = "follow_up"
        case proposal = "proposal"
        case other = "other"
        
        var icon: String {
            switch self {
            case .call: return "phone.fill"
            case .email: return "envelope.fill"
            case .meeting: return "calendar"
            case .followUp: return "arrow.clockwise"
            case .proposal: return "doc.text.fill"
            case .other: return "checkmark.circle.fill"
            }
        }
    }
    
    enum TaskPriority: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case urgent = "urgent"
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .blue
            case .high: return .orange
            case .urgent: return .red
            }
        }
    }
}

struct CRMNote: Codable, Identifiable {
    let id: String
    let clientId: String
    let content: String
    let author: String
    let createdAt: Date
    let isPrivate: Bool
}

struct CRMTag: Codable, Identifiable {
    let id: String
    let name: String
    let color: String
    let description: String?
}

struct CRMCustomField: Codable, Identifiable {
    let id: String
    let name: String
    let type: FieldType
    let isRequired: Bool
    let options: [String]?
    
    enum FieldType: String, CaseIterable, Codable {
        case text = "text"
        case number = "number"
        case date = "date"
        case boolean = "boolean"
        case select = "select"
        case multiSelect = "multi_select"
    }
}

struct CRMEmailTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let subject: String
    let content: String
    let type: TemplateType
    let isActive: Bool
    let createdAt: Date
    
    enum TemplateType: String, CaseIterable, Codable {
        case welcome = "welcome"
        case followUp = "follow_up"
        case reminder = "reminder"
        case promotion = "promotion"
        case support = "support"
    }
}

struct CRMAnalytics: Codable {
    let totalClients: Int
    let activeClients: Int
    let totalLeads: Int
    let conversionRate: Double
    let averageLifetimeValue: Double
    let totalRevenue: Double
    let monthlyGrowth: Double
    let topSources: [String: Int]
    let clientSatisfaction: Double
}

struct CRMInsight: Codable, Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let priority: Priority
    let actionable: Bool
    
    enum InsightType: String, CaseIterable, Codable {
        case highValue = "high_value"
        case engagement = "engagement"
        case pattern = "pattern"
        case risk = "risk"
        case opportunity = "opportunity"
    }
    
    enum Priority: String, CaseIterable, Codable {
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
