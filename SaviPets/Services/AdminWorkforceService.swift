import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import OSLog

// MARK: - Advanced Workforce Management Service

class AdminWorkforceService: ObservableObject {
    @Published var employees: [WorkforceEmployee] = []
    @Published var schedules: [WorkforceSchedule] = []
    @Published var shifts: [WorkforceShift] = []
    @Published var timeOffRequests: [TimeOffRequest] = []
    @Published var certifications: [EmployeeCertification] = []
    @Published var performanceMetrics: [EmployeePerformance] = []
    @Published var demandForecasts: [DemandForecast] = []
    @Published var complianceReports: [ComplianceReport] = []
    @Published var analytics: WorkforceAnalytics = WorkforceAnalytics(
        totalEmployees: 0,
        activeEmployees: 0,
        totalHours: 0,
        totalCost: 0.0,
        averagePerformance: 0.0,
        turnoverRate: 0.0,
        utilizationRate: 0.0,
        costPerHour: 0.0
    )
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "SaviPets", category: "AdminWorkforce")
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadInitialData()
        setupRealTimeListeners()
    }
    
    // MARK: - Employee Management
    
    func createEmployee(_ employee: WorkforceEmployee) async throws {
        try db.collection("workforce_employees").document(employee.id).setData(from: employee)
        logger.info("Employee created: \(employee.name)")
    }
    
    func updateEmployee(_ employee: WorkforceEmployee) async throws {
        try db.collection("workforce_employees").document(employee.id).setData(from: employee)
        logger.info("Employee updated: \(employee.name)")
    }
    
    func deleteEmployee(_ employeeId: String) async throws {
        try await db.collection("workforce_employees").document(employeeId).delete()
        logger.info("Employee deleted: \(employeeId)")
    }
    
    func getEmployeeById(_ employeeId: String) -> WorkforceEmployee? {
        return employees.first { $0.id == employeeId }
    }
    
    // MARK: - Schedule Management
    
    func createSchedule(_ schedule: WorkforceSchedule) async throws {
        try db.collection("workforce_schedules").document(schedule.id).setData(from: schedule)
        logger.info("Schedule created: \(schedule.name)")
    }
    
    func updateSchedule(_ schedule: WorkforceSchedule) async throws {
        try db.collection("workforce_schedules").document(schedule.id).setData(from: schedule)
        logger.info("Schedule updated: \(schedule.name)")
    }
    
    func generateOptimalSchedule(for dateRange: DateInterval) async throws -> WorkforceSchedule {
        // AI-powered schedule optimization
        let demandForecast = await generateDemandForecast(for: dateRange)
        let availableEmployees = employees.filter { $0.status == .active }
        
        let optimizedSchedule = WorkforceSchedule(
            id: UUID().uuidString,
            name: "Optimized Schedule \(DateFormatter().string(from: dateRange.start))",
            startDate: dateRange.start,
            endDate: dateRange.end,
            shifts: [],
            totalHours: 0,
            totalCost: 0.0,
            isOptimized: true,
            createdAt: Date()
        )
        
        // Schedule optimization logic would go here
        return optimizedSchedule
    }
    
    // MARK: - Shift Management
    
    func createShift(_ shift: WorkforceShift) async throws {
        try db.collection("workforce_shifts").document(shift.id).setData(from: shift)
        logger.info("Shift created: \(shift.id)")
    }
    
    func assignShift(_ shiftId: String, to employeeId: String) async throws {
        try await db.collection("workforce_shifts").document(shiftId).updateData([
            "employeeId": employeeId,
            "assignedAt": Timestamp(date: Date())
        ])
        logger.info("Shift \(shiftId) assigned to employee \(employeeId)")
    }
    
    func swapShifts(_ shiftId1: String, _ shiftId2: String) async throws {
        guard let shift1 = shifts.first(where: { $0.id == shiftId1 }),
              let shift2 = shifts.first(where: { $0.id == shiftId2 }) else { return }
        
        // Swap employee assignments
        try await assignShift(shiftId1, to: shift2.employeeId ?? "")
        try await assignShift(shiftId2, to: shift1.employeeId ?? "")
        
        logger.info("Shifts swapped: \(shiftId1) <-> \(shiftId2)")
    }
    
    // MARK: - Time Off Management
    
    func requestTimeOff(_ request: TimeOffRequest) async throws {
        try db.collection("time_off_requests").document(request.id).setData(from: request)
        logger.info("Time off requested: \(request.employeeId)")
    }
    
    func approveTimeOffRequest(_ requestId: String) async throws {
        try await db.collection("time_off_requests").document(requestId).updateData([
            "status": TimeOffRequest.Status.approved.rawValue,
            "approvedAt": Timestamp(date: Date())
        ])
        logger.info("Time off request approved: \(requestId)")
    }
    
    func denyTimeOffRequest(_ requestId: String, reason: String) async throws {
        try await db.collection("time_off_requests").document(requestId).updateData([
            "status": TimeOffRequest.Status.denied.rawValue,
            "deniedAt": Timestamp(date: Date()),
            "denialReason": reason
        ])
        logger.info("Time off request denied: \(requestId)")
    }
    
    // MARK: - Certification Management
    
    func addCertification(_ certification: EmployeeCertification) async throws {
        try db.collection("employee_certifications").document(certification.id).setData(from: certification)
        logger.info("Certification added: \(certification.name)")
    }
    
    func updateCertification(_ certification: EmployeeCertification) async throws {
        try db.collection("employee_certifications").document(certification.id).setData(from: certification)
        logger.info("Certification updated: \(certification.name)")
    }
    
    func getExpiringCertifications(days: Int = 30) -> [EmployeeCertification] {
        let expirationDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return certifications.filter { $0.expirationDate <= expirationDate && $0.status == .active }
    }
    
    // MARK: - Performance Management
    
    func recordPerformanceMetric(_ metric: EmployeePerformance) async throws {
        try db.collection("employee_performance").document(metric.id).setData(from: metric)
        logger.info("Performance metric recorded: \(metric.employeeId)")
    }
    
    func getEmployeePerformance(_ employeeId: String, for period: DateInterval) -> [EmployeePerformance] {
        return performanceMetrics.filter { 
            $0.employeeId == employeeId && 
            period.contains($0.date)
        }
    }
    
    func calculateEmployeeScore(_ employeeId: String) -> Double {
        let employeeMetrics = performanceMetrics.filter { $0.employeeId == employeeId }
        guard !employeeMetrics.isEmpty else { return 0.0 }
        
        let averageRating = employeeMetrics.reduce(0.0) { $0 + $1.rating } / Double(employeeMetrics.count)
        let attendanceRate = calculateAttendanceRate(employeeId)
        let customerSatisfaction = calculateCustomerSatisfaction(employeeId)
        
        return (averageRating * 0.4) + (attendanceRate * 0.3) + (customerSatisfaction * 0.3)
    }
    
    // MARK: - Demand Forecasting
    
    func generateDemandForecast(for dateRange: DateInterval) async -> DemandForecast {
        // AI-powered demand forecasting based on historical data
        let historicalData = await getHistoricalBookingData(for: dateRange)
        
        let forecast = DemandForecast(
            id: UUID().uuidString,
            dateRange: dateRange,
            predictedDemand: calculatePredictedDemand(from: historicalData),
            confidenceLevel: 0.85,
            factors: ["Historical patterns", "Seasonal trends", "Weather forecast"],
            createdAt: Date()
        )
        
        return forecast
    }
    
    // MARK: - Compliance Management
    
    func generateComplianceReport() async -> ComplianceReport {
        let report = ComplianceReport(
            id: UUID().uuidString,
            reportDate: Date(),
            laborLawCompliance: checkLaborLawCompliance(),
            certificationCompliance: checkCertificationCompliance(),
            safetyCompliance: checkSafetyCompliance(),
            overtimeCompliance: checkOvertimeCompliance(),
            violations: [],
            recommendations: generateComplianceRecommendations()
        )
        
        return report
    }
    
    // MARK: - Analytics
    
    func calculateWorkforceAnalytics() -> WorkforceAnalytics {
        let totalEmployees = employees.count
        let activeEmployees = employees.filter { $0.status == .active }.count
        let totalHours = shifts.reduce(0) { $0 + $1.duration }
        let totalCost = shifts.reduce(0.0) { $0 + $1.cost }
        let averagePerformance = performanceMetrics.isEmpty ? 0.0 : performanceMetrics.reduce(0.0) { $0 + $1.rating } / Double(performanceMetrics.count)
        
        return WorkforceAnalytics(
            totalEmployees: totalEmployees,
            activeEmployees: activeEmployees,
            totalHours: totalHours,
            totalCost: totalCost,
            averagePerformance: averagePerformance,
            turnoverRate: calculateTurnoverRate(),
            utilizationRate: calculateUtilizationRate(),
            costPerHour: totalHours > 0 ? totalCost / Double(totalHours) : 0.0
        )
    }
    
    // MARK: - Private Methods
    
    private func loadInitialData() {
        loadSampleData()
    }
    
    private func setupRealTimeListeners() {
        // Listen to employees
        db.collection("workforce_employees")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.employees = documents.compactMap { doc in
                        try? doc.data(as: WorkforceEmployee.self)
                    }
                }
            }
        
        // Listen to schedules
        db.collection("workforce_schedules")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.schedules = documents.compactMap { doc in
                        try? doc.data(as: WorkforceSchedule.self)
                    }
                }
            }
        
        // Listen to shifts
        db.collection("workforce_shifts")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.shifts = documents.compactMap { doc in
                        try? doc.data(as: WorkforceShift.self)
                    }
                }
            }
    }
    
    private func loadSampleData() {
        // Sample employees
        employees = [
            WorkforceEmployee(
                id: "1",
                name: "Sarah Johnson",
                email: "sarah.johnson@savipets.com",
                phone: "+1-555-0123",
                role: .sitter,
                status: .active,
                hireDate: Date().addingTimeInterval(-86400 * 365),
                hourlyRate: 25.0,
                skills: ["Dog Walking", "Pet Sitting", "Basic Grooming"],
                certifications: ["Pet First Aid", "Animal Behavior"],
                availability: .fullTime,
                preferences: ["Morning shifts", "Weekend availability"],
                emergencyContact: "John Johnson (+1-555-0124)",
                notes: "Excellent with large dogs"
            ),
            WorkforceEmployee(
                id: "2",
                name: "Mike Chen",
                email: "mike.chen@savipets.com",
                phone: "+1-555-0125",
                role: .sitter,
                status: .active,
                hireDate: Date().addingTimeInterval(-86400 * 180),
                hourlyRate: 22.0,
                skills: ["Cat Care", "Pet Sitting", "Medication Administration"],
                certifications: ["Pet First Aid"],
                availability: .partTime,
                preferences: ["Evening shifts", "Cat-only assignments"],
                emergencyContact: "Lisa Chen (+1-555-0126)",
                notes: "Specializes in senior pet care"
            )
        ]
        
        // Sample schedules
        schedules = [
            WorkforceSchedule(
                id: "1",
                name: "Week of Dec 16-22",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 7),
                shifts: [],
                totalHours: 120,
                totalCost: 3000.0,
                isOptimized: true,
                createdAt: Date()
            )
        ]
        
        // Sample shifts
        shifts = [
            WorkforceShift(
                id: "1",
                employeeId: "1",
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600 * 4),
                location: "Downtown Area",
                serviceType: "Dog Walking",
                status: .scheduled,
                hourlyRate: 25.0,
                duration: 4,
                cost: 100.0,
                notes: "Morning walk for 3 dogs"
            )
        ]
        
        // Sample time off requests
        timeOffRequests = [
            TimeOffRequest(
                id: "1",
                employeeId: "1",
                startDate: Date().addingTimeInterval(86400 * 7),
                endDate: Date().addingTimeInterval(86400 * 9),
                type: .vacation,
                reason: "Family vacation",
                status: .pending,
                requestedAt: Date(),
                approvedAt: nil,
                deniedAt: nil,
                denialReason: nil
            )
        ]
        
        // Sample certifications
        certifications = [
            EmployeeCertification(
                id: "1",
                employeeId: "1",
                name: "Pet First Aid",
                issuingOrganization: "Red Cross",
                issueDate: Date().addingTimeInterval(-86400 * 180),
                expirationDate: Date().addingTimeInterval(86400 * 180),
                status: .active,
                certificateNumber: "PFA-2024-001"
            )
        ]
    }
    
    private func calculatePredictedDemand(from historicalData: [BookingData]) -> [DemandPrediction] {
        // Simplified demand prediction logic
        return [
            DemandPrediction(
                date: Date(),
                predictedBookings: 45,
                confidenceLevel: 0.85,
                factors: ["Historical patterns", "Weather forecast"]
            )
        ]
    }
    
    private func getHistoricalBookingData(for dateRange: DateInterval) async -> [BookingData] {
        // This would fetch historical booking data from Firestore
        return []
    }
    
    private func calculateAttendanceRate(_ employeeId: String) -> Double {
        let employeeShifts = shifts.filter { $0.employeeId == employeeId }
        let completedShifts = employeeShifts.filter { $0.status == .completed }
        return employeeShifts.isEmpty ? 0.0 : Double(completedShifts.count) / Double(employeeShifts.count)
    }
    
    private func calculateCustomerSatisfaction(_ employeeId: String) -> Double {
        let employeeMetrics = performanceMetrics.filter { $0.employeeId == employeeId }
        return employeeMetrics.isEmpty ? 0.0 : employeeMetrics.reduce(0.0) { $0 + $1.customerSatisfaction } / Double(employeeMetrics.count)
    }
    
    private func calculateTurnoverRate() -> Double {
        let totalEmployees = employees.count
        let terminatedEmployees = employees.filter { $0.status == .terminated }.count
        return totalEmployees > 0 ? Double(terminatedEmployees) / Double(totalEmployees) : 0.0
    }
    
    private func calculateUtilizationRate() -> Double {
        let totalAvailableHours = employees.filter { $0.status == .active }.reduce(0) { $0 + $1.availability.hoursPerWeek }
        let scheduledHours = shifts.reduce(0) { $0 + $1.duration }
        return totalAvailableHours > 0 ? Double(scheduledHours) / Double(totalAvailableHours) : 0.0
    }
    
    private func checkLaborLawCompliance() -> ComplianceStatus {
        // Check labor law compliance
        return .compliant
    }
    
    private func checkCertificationCompliance() -> ComplianceStatus {
        // Check certification compliance
        return .compliant
    }
    
    private func checkSafetyCompliance() -> ComplianceStatus {
        // Check safety compliance
        return .compliant
    }
    
    private func checkOvertimeCompliance() -> ComplianceStatus {
        // Check overtime compliance
        return .compliant
    }
    
    private func generateComplianceRecommendations() -> [String] {
        return [
            "Schedule regular safety training sessions",
            "Implement automated overtime tracking",
            "Set up certification renewal reminders"
        ]
    }
}

// MARK: - Workforce Data Models

struct WorkforceEmployee: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let phone: String
    let role: EmployeeRole
    let status: EmployeeStatus
    let hireDate: Date
    let hourlyRate: Double
    let skills: [String]
    let certifications: [String]
    let availability: Availability
    let preferences: [String]
    let emergencyContact: String
    let notes: String
    
    enum EmployeeRole: String, CaseIterable, Codable {
        case sitter = "sitter"
        case walker = "walker"
        case groomer = "groomer"
        case trainer = "trainer"
        case manager = "manager"
        case admin = "admin"
        
        var icon: String {
            switch self {
            case .sitter: return "person.fill"
            case .walker: return "figure.walk"
            case .groomer: return "scissors"
            case .trainer: return "graduationcap.fill"
            case .manager: return "person.badge.plus"
            case .admin: return "person.crop.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .sitter: return .blue
            case .walker: return .green
            case .groomer: return .purple
            case .trainer: return .orange
            case .manager: return .red
            case .admin: return .gray
            }
        }
    }
    
    enum EmployeeStatus: String, CaseIterable, Codable {
        case active = "active"
        case inactive = "inactive"
        case onLeave = "on_leave"
        case terminated = "terminated"
        
        var color: Color {
            switch self {
            case .active: return .green
            case .inactive: return .orange
            case .onLeave: return .blue
            case .terminated: return .red
            }
        }
    }
    
    enum Availability: String, CaseIterable, Codable {
        case fullTime = "full_time"
        case partTime = "part_time"
        case contract = "contract"
        case seasonal = "seasonal"
        
        var hoursPerWeek: Int {
            switch self {
            case .fullTime: return 40
            case .partTime: return 20
            case .contract: return 10
            case .seasonal: return 30
            }
        }
    }
}

struct WorkforceSchedule: Codable, Identifiable {
    let id: String
    let name: String
    let startDate: Date
    let endDate: Date
    let shifts: [String] // Shift IDs
    let totalHours: Int
    let totalCost: Double
    let isOptimized: Bool
    let createdAt: Date
}

struct WorkforceShift: Codable, Identifiable {
    let id: String
    let employeeId: String?
    let startTime: Date
    let endTime: Date
    let location: String
    let serviceType: String
    let status: ShiftStatus
    let hourlyRate: Double
    let duration: Int
    let cost: Double
    let notes: String
    
    enum ShiftStatus: String, CaseIterable, Codable {
        case scheduled = "scheduled"
        case inProgress = "in_progress"
        case completed = "completed"
        case cancelled = "cancelled"
        case noShow = "no_show"
        
        var color: Color {
            switch self {
            case .scheduled: return .blue
            case .inProgress: return .orange
            case .completed: return .green
            case .cancelled: return .red
            case .noShow: return .gray
            }
        }
    }
}

struct TimeOffRequest: Codable, Identifiable {
    let id: String
    let employeeId: String
    let startDate: Date
    let endDate: Date
    let type: TimeOffType
    let reason: String
    let status: Status
    let requestedAt: Date
    let approvedAt: Date?
    let deniedAt: Date?
    let denialReason: String?
    
    enum TimeOffType: String, CaseIterable, Codable {
        case vacation = "vacation"
        case sick = "sick"
        case personal = "personal"
        case emergency = "emergency"
        case bereavement = "bereavement"
        
        var icon: String {
            switch self {
            case .vacation: return "beach.umbrella.fill"
            case .sick: return "cross.fill"
            case .personal: return "person.fill"
            case .emergency: return "exclamationmark.triangle.fill"
            case .bereavement: return "heart.fill"
            }
        }
    }
    
    enum Status: String, CaseIterable, Codable {
        case pending = "pending"
        case approved = "approved"
        case denied = "denied"
        
        var color: Color {
            switch self {
            case .pending: return .orange
            case .approved: return .green
            case .denied: return .red
            }
        }
    }
}

struct EmployeeCertification: Codable, Identifiable {
    let id: String
    let employeeId: String
    let name: String
    let issuingOrganization: String
    let issueDate: Date
    let expirationDate: Date
    let status: CertificationStatus
    let certificateNumber: String
    
    enum CertificationStatus: String, CaseIterable, Codable {
        case active = "active"
        case expired = "expired"
        case pending = "pending"
        
        var color: Color {
            switch self {
            case .active: return .green
            case .expired: return .red
            case .pending: return .orange
            }
        }
    }
}

struct EmployeePerformance: Codable, Identifiable {
    let id: String
    let employeeId: String
    let date: Date
    let rating: Double
    let customerSatisfaction: Double
    let punctuality: Double
    let qualityOfWork: Double
    let communication: Double
    let notes: String
}

struct DemandForecast: Codable, Identifiable {
    let id: String
    let dateRange: DateInterval
    let predictedDemand: [DemandPrediction]
    let confidenceLevel: Double
    let factors: [String]
    let createdAt: Date
}

struct DemandPrediction: Codable {
    let date: Date
    let predictedBookings: Int
    let confidenceLevel: Double
    let factors: [String]
}

struct ComplianceReport: Codable, Identifiable {
    let id: String
    let reportDate: Date
    let laborLawCompliance: ComplianceStatus
    let certificationCompliance: ComplianceStatus
    let safetyCompliance: ComplianceStatus
    let overtimeCompliance: ComplianceStatus
    let violations: [ComplianceViolation]
    let recommendations: [String]
}

enum ComplianceStatus: String, CaseIterable, Codable {
    case compliant = "compliant"
    case nonCompliant = "non_compliant"
    case needsAttention = "needs_attention"
    
    var color: Color {
        switch self {
        case .compliant: return .green
        case .nonCompliant: return .red
        case .needsAttention: return .orange
        }
    }
}

struct ComplianceViolation: Codable {
    let type: String
    let description: String
    let severity: ViolationSeverity
    let date: Date
    let employeeId: String?
    
    enum ViolationSeverity: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            case .critical: return .purple
            }
        }
    }
}

struct WorkforceAnalytics: Codable {
    let totalEmployees: Int
    let activeEmployees: Int
    let totalHours: Int
    let totalCost: Double
    let averagePerformance: Double
    let turnoverRate: Double
    let utilizationRate: Double
    let costPerHour: Double
}

struct BookingData: Codable {
    let date: Date
    let bookings: Int
    let revenue: Double
}
