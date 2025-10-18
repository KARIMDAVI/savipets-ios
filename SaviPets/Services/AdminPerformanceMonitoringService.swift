import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import OSLog
import Network

// MARK: - Advanced Performance Monitoring Service

class AdminPerformanceMonitoringService: ObservableObject {
    @Published var systemMetrics: SystemMetrics = SystemMetrics(
        cpuUsage: 0.0,
        memoryUsage: 0.0,
        networkMetrics: NetworkMetrics(bytesReceived: 0, bytesSent: 0, latency: 0.0, packetLoss: 0.0),
        databaseMetrics: DatabaseMetrics(connectionCount: 0, queryTime: 0.0, cacheHitRate: 0.0, storageUsed: 0.0),
        timestamp: Date()
    )
    @Published var performanceAlerts: [PerformanceAlert] = []
    @Published var kpiMetrics: KPIMetrics = KPIMetrics(
        bookingMetrics: PerformanceBookingMetrics(totalBookings: 0, completedBookings: 0, cancelledBookings: 0, averageBookingValue: 0.0, bookingConversionRate: 0.0),
        revenueMetrics: RevenueMetrics(dailyRevenue: 0.0, weeklyRevenue: 0.0, monthlyRevenue: 0.0, averageOrderValue: 0.0, revenueGrowth: 0.0),
        customerMetrics: CustomerMetrics(totalCustomers: 0, activeCustomers: 0, newCustomers: 0, customerSatisfaction: 0.0, customerRetentionRate: 0.0),
        sitterMetrics: SitterMetrics(totalSitters: 0, activeSitters: 0, averageRating: 0.0, completionRate: 0.0, utilizationRate: 0.0),
        timestamp: Date()
    )
    @Published var sitterPerformance: [SitterPerformance] = []
    @Published var systemHealth: SystemHealth = SystemHealth(
        overallStatus: .healthy,
        databaseStatus: .healthy,
        networkStatus: .connected,
        apiStatus: .healthy,
        storageStatus: .healthy,
        lastCheck: Date(),
        uptime: 99.9
    )
    @Published var realTimeMetrics: RealTimeMetrics = RealTimeMetrics(
        activeBookings: 0,
        activeSitters: 0,
        todayRevenue: 0.0,
        lastUpdate: Date()
    )
    @Published var alertRules: [AlertRule] = []
    @Published var monitoringConfig: MonitoringConfig = MonitoringConfig()
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "SaviPets", category: "PerformanceMonitoring")
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private let networkMonitor = NWPathMonitor()
    
    init() {
        setupMonitoring()
        loadInitialData()
        startRealTimeMonitoring()
    }
    
    deinit {
        monitoringTimer?.invalidate()
        networkMonitor.cancel()
    }
    
    // MARK: - System Metrics Monitoring
    
    func startSystemMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.collectSystemMetrics()
            }
        }
    }
    
    func stopSystemMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func collectSystemMetrics() async {
        // Collect CPU usage
        let cpuUsage = await getCPUUsage()
        
        // Collect memory usage
        let memoryUsage = await getMemoryUsage()
        
        // Collect network metrics
        let networkMetrics = await getNetworkMetrics()
        
        // Collect database metrics
        let databaseMetrics = await getDatabaseMetrics()
        
        // Update system metrics
        await MainActor.run {
            systemMetrics = SystemMetrics(
                cpuUsage: cpuUsage,
                memoryUsage: memoryUsage,
                networkMetrics: networkMetrics,
                databaseMetrics: databaseMetrics,
                timestamp: Date()
            )
            
            // Check for alerts
            checkSystemAlerts()
        }
    }
    
    // MARK: - KPI Monitoring
    
    func updateKPIMetrics() async {
        let bookingMetrics = await getPerformanceBookingMetrics()
        let revenueMetrics = await getRevenueMetrics()
        let customerMetrics = await getCustomerMetrics()
        let sitterMetrics = await getSitterMetrics()
        
        await MainActor.run {
            kpiMetrics = KPIMetrics(
                bookingMetrics: bookingMetrics,
                revenueMetrics: revenueMetrics,
                customerMetrics: customerMetrics,
                sitterMetrics: sitterMetrics,
                timestamp: Date()
            )
            
            // Check for KPI alerts
            checkKPIAlerts()
        }
    }
    
    // MARK: - Sitter Performance Monitoring
    
    func updateSitterPerformance() async {
        let sitters = await fetchSitterData()
        var performanceData: [SitterPerformance] = []
        
        for sitter in sitters {
            let performance = await calculateSitterPerformance(sitter)
            performanceData.append(performance)
        }
        
        await MainActor.run {
            sitterPerformance = performanceData
            checkSitterPerformanceAlerts()
        }
    }
    
    // MARK: - Alert Management
    
    func createAlertRule(_ rule: AlertRule) async throws {
        try db.collection("alert_rules").document(rule.id).setData(from: rule)
        logger.info("Alert rule created: \(rule.name)")
    }
    
    func updateAlertRule(_ rule: AlertRule) async throws {
        try db.collection("alert_rules").document(rule.id).setData(from: rule)
        logger.info("Alert rule updated: \(rule.name)")
    }
    
    func deleteAlertRule(_ ruleId: String) async throws {
        try await db.collection("alert_rules").document(ruleId).delete()
        logger.info("Alert rule deleted: \(ruleId)")
    }
    
    func acknowledgeAlert(_ alertId: String) async throws {
        try await db.collection("performance_alerts").document(alertId).updateData([
            "status": PerformanceAlert.Status.acknowledged.rawValue,
            "acknowledgedAt": Timestamp(date: Date())
        ])
        logger.info("Alert acknowledged: \(alertId)")
    }
    
    func resolveAlert(_ alertId: String, resolution: String) async throws {
        try await db.collection("performance_alerts").document(alertId).updateData([
            "status": PerformanceAlert.Status.resolved.rawValue,
            "resolvedAt": Timestamp(date: Date()),
            "resolution": resolution
        ])
        logger.info("Alert resolved: \(alertId)")
    }
    
    // MARK: - System Health Monitoring
    
    func checkSystemHealth() async {
        let healthStatus = await performHealthChecks()
        
        await MainActor.run {
            systemHealth = healthStatus
            checkHealthAlerts()
        }
    }
    
    // MARK: - Real-Time Metrics
    
    func startRealTimeMonitoring() {
        // Monitor booking activity
        db.collection("service_bookings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.realTimeMetrics.activeBookings = documents.count
                    self?.realTimeMetrics.lastUpdate = Date()
                }
            }
        
        // Monitor sitter activity
        db.collection("sitters")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.realTimeMetrics.activeSitters = documents.filter { 
                        $0.data()["status"] as? String == "active" 
                    }.count
                }
            }
        
        // Monitor revenue
        db.collection("payments")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let todayRevenue = documents.compactMap { doc in
                    doc.data()["amount"] as? Double
                }.reduce(0, +)
                
                DispatchQueue.main.async {
                    self?.realTimeMetrics.todayRevenue = todayRevenue
                }
            }
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // Setup network monitoring
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.systemHealth.networkStatus = path.status == .satisfied ? .connected : .disconnected
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
        
        // Load alert rules
        loadAlertRules()
        
        // Start system monitoring
        startSystemMonitoring()
    }
    
    private func loadInitialData() {
        loadSampleData()
    }
    
    private func loadAlertRules() {
        db.collection("alert_rules")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.alertRules = documents.compactMap { doc in
                        try? doc.data(as: AlertRule.self)
                    }
                }
            }
    }
    
    private func loadSampleData() {
        // Sample system metrics
        systemMetrics = SystemMetrics(
            cpuUsage: 45.0,
            memoryUsage: 60.0,
            networkMetrics: NetworkMetrics(
                bytesReceived: 1024000,
                bytesSent: 512000,
                latency: 25.0,
                packetLoss: 0.0
            ),
            databaseMetrics: DatabaseMetrics(
                connectionCount: 15,
                queryTime: 12.5,
                cacheHitRate: 85.0,
                storageUsed: 2.5
            ),
            timestamp: Date()
        )
        
        // Sample KPI metrics
        kpiMetrics = KPIMetrics(
            bookingMetrics: PerformanceBookingMetrics(
                totalBookings: 150,
                completedBookings: 140,
                cancelledBookings: 10,
                averageBookingValue: 75.0,
                bookingConversionRate: 85.0
            ),
            revenueMetrics: RevenueMetrics(
                dailyRevenue: 5000.0,
                weeklyRevenue: 35000.0,
                monthlyRevenue: 150000.0,
                averageOrderValue: 75.0,
                revenueGrowth: 12.5
            ),
            customerMetrics: CustomerMetrics(
                totalCustomers: 500,
                activeCustomers: 450,
                newCustomers: 25,
                customerSatisfaction: 4.5,
                customerRetentionRate: 85.0
            ),
            sitterMetrics: SitterMetrics(
                totalSitters: 25,
                activeSitters: 20,
                averageRating: 4.7,
                completionRate: 95.0,
                utilizationRate: 80.0
            ),
            timestamp: Date()
        )
        
        // Sample sitter performance
        sitterPerformance = [
            SitterPerformance(
                sitterId: "1",
                sitterName: "Sarah Johnson",
                rating: 4.8,
                completionRate: 98.0,
                responseTime: 5.0,
                customerSatisfaction: 4.7,
                bookingsCompleted: 45,
                revenueGenerated: 3375.0,
                lastActive: Date(),
                performanceScore: 92.0
            ),
            SitterPerformance(
                sitterId: "2",
                sitterName: "Mike Chen",
                rating: 4.6,
                completionRate: 95.0,
                responseTime: 8.0,
                customerSatisfaction: 4.5,
                bookingsCompleted: 38,
                revenueGenerated: 2850.0,
                lastActive: Date(),
                performanceScore: 88.0
            )
        ]
        
        // Sample performance alerts
        performanceAlerts = [
            PerformanceAlert(
                id: "1",
                title: "High CPU Usage",
                message: "CPU usage has exceeded 80% for the last 5 minutes",
                severity: .warning,
                category: .system,
                status: .active,
                createdAt: Date(),
                acknowledgedAt: nil,
                resolvedAt: nil,
                resolution: nil,
                metrics: ["cpuUsage": "85.2"]
            ),
            PerformanceAlert(
                id: "2",
                title: "Low Customer Satisfaction",
                message: "Customer satisfaction has dropped below 4.0",
                severity: .critical,
                category: .customer,
                status: .active,
                createdAt: Date(),
                acknowledgedAt: nil,
                resolvedAt: nil,
                resolution: nil,
                metrics: ["customerSatisfaction": "3.8"]
            )
        ]
        
        // Sample alert rules
        alertRules = [
            AlertRule(
                id: "1",
                name: "High CPU Usage",
                description: "Alert when CPU usage exceeds 80%",
                metric: "cpuUsage",
                threshold: 80.0,
                operator: .greaterThan,
                severity: .warning,
                isEnabled: true,
                createdAt: Date()
            ),
            AlertRule(
                id: "2",
                name: "Low Customer Satisfaction",
                description: "Alert when customer satisfaction drops below 4.0",
                metric: "customerSatisfaction",
                threshold: 4.0,
                operator: .lessThan,
                severity: .critical,
                isEnabled: true,
                createdAt: Date()
            )
        ]
        
        // Sample system health
        systemHealth = SystemHealth(
            overallStatus: .healthy,
            databaseStatus: .healthy,
            networkStatus: .connected,
            apiStatus: .healthy,
            storageStatus: .healthy,
            lastCheck: Date(),
            uptime: 99.9
        )
        
        // Sample real-time metrics
        realTimeMetrics = RealTimeMetrics(
            activeBookings: 15,
            activeSitters: 8,
            todayRevenue: 1250.0,
            lastUpdate: Date()
        )
    }
    
    private func checkSystemAlerts() {
        // Check CPU usage
        if systemMetrics.cpuUsage > 80.0 {
            createAlertIfNotExists(
                title: "High CPU Usage",
                message: "CPU usage has exceeded 80%",
                severity: .warning,
                category: .system,
                metrics: ["cpuUsage": "\(systemMetrics.cpuUsage)"]
            )
        }
        
        // Check memory usage
        if systemMetrics.memoryUsage > 90.0 {
            createAlertIfNotExists(
                title: "High Memory Usage",
                message: "Memory usage has exceeded 90%",
                severity: .critical,
                category: .system,
                metrics: ["memoryUsage": "\(systemMetrics.memoryUsage)"]
            )
        }
    }
    
    private func checkKPIAlerts() {
        // Check customer satisfaction
        if kpiMetrics.customerMetrics.customerSatisfaction < 4.0 {
            createAlertIfNotExists(
                title: "Low Customer Satisfaction",
                message: "Customer satisfaction has dropped below 4.0",
                severity: .critical,
                category: .customer,
                metrics: ["customerSatisfaction": "\(kpiMetrics.customerMetrics.customerSatisfaction)"]
            )
        }
        
        // Check booking conversion rate
        if kpiMetrics.bookingMetrics.bookingConversionRate < 70.0 {
            createAlertIfNotExists(
                title: "Low Booking Conversion",
                message: "Booking conversion rate has dropped below 70%",
                severity: .warning,
                category: .booking,
                metrics: ["bookingConversionRate": "\(kpiMetrics.bookingMetrics.bookingConversionRate)"]
            )
        }
    }
    
    private func checkSitterPerformanceAlerts() {
        for sitter in sitterPerformance {
            if sitter.performanceScore < 70.0 {
                createAlertIfNotExists(
                    title: "Low Sitter Performance",
                    message: "\(sitter.sitterName) performance score is below 70%",
                    severity: .warning,
                    category: .sitter,
                    metrics: ["sitterId": sitter.sitterId, "performanceScore": "\(sitter.performanceScore)"]
                )
            }
        }
    }
    
    private func checkHealthAlerts() {
        if systemHealth.overallStatus != .healthy {
            createAlertIfNotExists(
                title: "System Health Issue",
                message: "System health status: \(systemHealth.overallStatus.rawValue)",
                severity: .critical,
                category: .system,
                metrics: ["overallStatus": systemHealth.overallStatus.rawValue]
            )
        }
    }
    
    private func createAlertIfNotExists(title: String, message: String, severity: PerformanceAlert.Severity, category: PerformanceAlert.Category, metrics: [String: String]) {
        // Check if alert already exists
        let existingAlert = performanceAlerts.first { alert in
            alert.title == title && alert.status == .active
        }
        
        if existingAlert == nil {
            let newAlert = PerformanceAlert(
                id: UUID().uuidString,
                title: title,
                message: message,
                severity: severity,
                category: category,
                status: .active,
                createdAt: Date(),
                acknowledgedAt: nil,
                resolvedAt: nil,
                resolution: nil,
                metrics: metrics
            )
            
            performanceAlerts.append(newAlert)
            
            // Save to database
            Task {
                try? db.collection("performance_alerts").document(newAlert.id).setData(from: newAlert)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCPUUsage() async -> Double {
        // Simulate CPU usage calculation
        return Double.random(in: 20...90)
    }
    
    private func getMemoryUsage() async -> Double {
        // Simulate memory usage calculation
        return Double.random(in: 30...80)
    }
    
    private func getNetworkMetrics() async -> NetworkMetrics {
        return NetworkMetrics(
            bytesReceived: UInt64.random(in: 1000000...5000000),
            bytesSent: UInt64.random(in: 500000...2500000),
            latency: Double.random(in: 10...50),
            packetLoss: Double.random(in: 0...2)
        )
    }
    
    private func getDatabaseMetrics() async -> DatabaseMetrics {
        return DatabaseMetrics(
            connectionCount: Int.random(in: 10...25),
            queryTime: Double.random(in: 5...20),
            cacheHitRate: Double.random(in: 80...95),
            storageUsed: Double.random(in: 1...5)
        )
    }
    
    private func getPerformanceBookingMetrics() async -> PerformanceBookingMetrics {
        return PerformanceBookingMetrics(
            totalBookings: Int.random(in: 100...200),
            completedBookings: Int.random(in: 90...180),
            cancelledBookings: Int.random(in: 5...20),
            averageBookingValue: Double.random(in: 60...90),
            bookingConversionRate: Double.random(in: 70...95)
        )
    }
    
    private func getRevenueMetrics() async -> RevenueMetrics {
        return RevenueMetrics(
            dailyRevenue: Double.random(in: 3000...8000),
            weeklyRevenue: Double.random(in: 20000...50000),
            monthlyRevenue: Double.random(in: 100000...200000),
            averageOrderValue: Double.random(in: 60...90),
            revenueGrowth: Double.random(in: 5...20)
        )
    }
    
    private func getCustomerMetrics() async -> CustomerMetrics {
        return CustomerMetrics(
            totalCustomers: Int.random(in: 400...600),
            activeCustomers: Int.random(in: 350...500),
            newCustomers: Int.random(in: 15...35),
            customerSatisfaction: Double.random(in: 3.5...5.0),
            customerRetentionRate: Double.random(in: 75...95)
        )
    }
    
    private func getSitterMetrics() async -> SitterMetrics {
        return SitterMetrics(
            totalSitters: Int.random(in: 20...30),
            activeSitters: Int.random(in: 15...25),
            averageRating: Double.random(in: 4.0...5.0),
            completionRate: Double.random(in: 85...98),
            utilizationRate: Double.random(in: 70...90)
        )
    }
    
    private func fetchSitterData() async -> [SitterData] {
        // Simulate fetching sitter data
        return [
            SitterData(id: "1", name: "Sarah Johnson", status: "active"),
            SitterData(id: "2", name: "Mike Chen", status: "active")
        ]
    }
    
    private func calculateSitterPerformance(_ sitter: SitterData) async -> SitterPerformance {
        return SitterPerformance(
            sitterId: sitter.id,
            sitterName: sitter.name,
            rating: Double.random(in: 4.0...5.0),
            completionRate: Double.random(in: 85...98),
            responseTime: Double.random(in: 3...15),
            customerSatisfaction: Double.random(in: 4.0...5.0),
            bookingsCompleted: Int.random(in: 20...50),
            revenueGenerated: Double.random(in: 1500...4000),
            lastActive: Date(),
            performanceScore: Double.random(in: 70...95)
        )
    }
    
    private func performHealthChecks() async -> SystemHealth {
        return SystemHealth(
            overallStatus: .healthy,
            databaseStatus: .healthy,
            networkStatus: .connected,
            apiStatus: .healthy,
            storageStatus: .healthy,
            lastCheck: Date(),
            uptime: 99.9
        )
    }
}

// MARK: - Performance Monitoring Data Models

struct SystemMetrics: Codable {
    let cpuUsage: Double
    let memoryUsage: Double
    let networkMetrics: NetworkMetrics
    let databaseMetrics: DatabaseMetrics
    let timestamp: Date
}

struct NetworkMetrics: Codable {
    let bytesReceived: UInt64
    let bytesSent: UInt64
    let latency: Double
    let packetLoss: Double
}

struct DatabaseMetrics: Codable {
    let connectionCount: Int
    let queryTime: Double
    let cacheHitRate: Double
    let storageUsed: Double
}

struct KPIMetrics: Codable {
    let bookingMetrics: PerformanceBookingMetrics
    let revenueMetrics: RevenueMetrics
    let customerMetrics: CustomerMetrics
    let sitterMetrics: SitterMetrics
    let timestamp: Date
}

struct PerformanceBookingMetrics: Codable {
    let totalBookings: Int
    let completedBookings: Int
    let cancelledBookings: Int
    let averageBookingValue: Double
    let bookingConversionRate: Double
}

struct RevenueMetrics: Codable {
    let dailyRevenue: Double
    let weeklyRevenue: Double
    let monthlyRevenue: Double
    let averageOrderValue: Double
    let revenueGrowth: Double
}

struct CustomerMetrics: Codable {
    let totalCustomers: Int
    let activeCustomers: Int
    let newCustomers: Int
    let customerSatisfaction: Double
    let customerRetentionRate: Double
}

struct SitterMetrics: Codable {
    let totalSitters: Int
    let activeSitters: Int
    let averageRating: Double
    let completionRate: Double
    let utilizationRate: Double
}

struct SitterPerformance: Codable, Identifiable {
    let id = UUID()
    let sitterId: String
    let sitterName: String
    let rating: Double
    let completionRate: Double
    let responseTime: Double
    let customerSatisfaction: Double
    let bookingsCompleted: Int
    let revenueGenerated: Double
    let lastActive: Date
    let performanceScore: Double
}

struct PerformanceAlert: Codable, Identifiable {
    let id: String
    let title: String
    let message: String
    let severity: Severity
    let category: Category
    let status: Status
    let createdAt: Date
    let acknowledgedAt: Date?
    let resolvedAt: Date?
    let resolution: String?
    let metrics: [String: String]
    
    enum Severity: String, CaseIterable, Codable {
        case info = "info"
        case warning = "warning"
        case critical = "critical"
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .critical: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.circle.fill"
            }
        }
    }
    
    enum Category: String, CaseIterable, Codable {
        case system = "system"
        case performance = "performance"
        case customer = "customer"
        case sitter = "sitter"
        case booking = "booking"
        case revenue = "revenue"
        
        var color: Color {
            switch self {
            case .system: return .blue
            case .performance: return .green
            case .customer: return .purple
            case .sitter: return .orange
            case .booking: return .cyan
            case .revenue: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .system: return "gearshape.fill"
            case .performance: return "speedometer"
            case .customer: return "person.2.fill"
            case .sitter: return "figure.walk"
            case .booking: return "calendar"
            case .revenue: return "dollarsign.circle.fill"
            }
        }
    }
    
    enum Status: String, CaseIterable, Codable {
        case active = "active"
        case acknowledged = "acknowledged"
        case resolved = "resolved"
        
        var color: Color {
            switch self {
            case .active: return .red
            case .acknowledged: return .orange
            case .resolved: return .green
            }
        }
    }
}

struct AlertRule: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let metric: String
    let threshold: Double
    let `operator`: Operator
    let severity: PerformanceAlert.Severity
    let isEnabled: Bool
    let createdAt: Date
    
    enum Metric: String, CaseIterable, Codable {
        case cpuUsage = "cpu_usage"
        case memoryUsage = "memory_usage"
        case networkLatency = "network_latency"
        case databaseConnections = "database_connections"
        case bookingCount = "booking_count"
        case revenue = "revenue"
        case customerSatisfaction = "customer_satisfaction"
        case sitterRating = "sitter_rating"
    }
    
    enum Condition: String, CaseIterable, Codable {
        case greaterThan = "greater_than"
        case lessThan = "less_than"
        case equal = "equal"
        case notEqual = "not_equal"
        
        var symbol: String {
            switch self {
            case .greaterThan: return ">"
            case .lessThan: return "<"
            case .equal: return "="
            case .notEqual: return "≠"
            }
        }
    }
    
    enum Severity: String, CaseIterable, Codable {
        case info = "info"
        case warning = "warning"
        case critical = "critical"
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .critical: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.circle.fill"
            }
        }
    }
    
    enum Operator: String, CaseIterable, Codable {
        case greaterThan = "greater_than"
        case lessThan = "less_than"
        case equal = "equal"
        case notEqual = "not_equal"
        
        var symbol: String {
            switch self {
            case .greaterThan: return ">"
            case .lessThan: return "<"
            case .equal: return "="
            case .notEqual: return "≠"
            }
        }
    }
}

struct SystemHealth: Codable {
    var overallStatus: HealthStatus
    var databaseStatus: HealthStatus
    var networkStatus: NetworkStatus
    var apiStatus: HealthStatus
    var storageStatus: HealthStatus
    var lastCheck: Date
    var uptime: Double
    
    enum HealthStatus: String, CaseIterable, Codable {
        case healthy = "healthy"
        case degraded = "degraded"
        case unhealthy = "unhealthy"
        
        var color: Color {
            switch self {
            case .healthy: return .green
            case .degraded: return .orange
            case .unhealthy: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .degraded: return "exclamationmark.triangle.fill"
            case .unhealthy: return "xmark.circle.fill"
            }
        }
    }
    
    enum NetworkStatus: String, CaseIterable, Codable {
        case connected = "connected"
        case disconnected = "disconnected"
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .red
            }
        }
    }
}

struct RealTimeMetrics: Codable {
    var activeBookings: Int
    var activeSitters: Int
    var todayRevenue: Double
    var lastUpdate: Date
}

struct MonitoringConfig: Codable {
    let monitoringInterval: Double = 30.0
    let alertRetentionDays: Int = 30
    let metricsRetentionDays: Int = 90
    let isRealTimeEnabled: Bool = true
    let isAlertsEnabled: Bool = true
}

struct SitterData: Codable {
    let id: String
    let name: String
    let status: String
}
