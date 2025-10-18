import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import OSLog
import Charts

// MARK: - Advanced Reporting & Analytics Service

class AdminReportingService: ObservableObject {
    @Published var reports: [Report] = []
    @Published var analyticsData: AnalyticsData = AnalyticsData()
    @Published var customReports: [CustomReport] = []
    @Published var reportTemplates: [ReportTemplate] = []
    @Published var scheduledReports: [ScheduledReport] = []
    @Published var exportHistory: [ExportRecord] = []
    @Published var insights: [AnalyticsInsight] = []
    @Published var isGeneratingReport = false
    @Published var isExporting = false
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "SaviPets", category: "Reporting")
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadReportTemplates()
        loadCustomReports()
        loadScheduledReports()
        generateInitialInsights()
    }
    
    // MARK: - Report Generation
    
    func generateReport(type: ReportType, timeRange: TimeRange, filters: ReportFilters = ReportFilters()) async {
        await MainActor.run {
            isGeneratingReport = true
        }
        
        do {
            let report = try await createReport(type: type, timeRange: timeRange, filters: filters)
            
            await MainActor.run {
                reports.append(report)
                isGeneratingReport = false
            }
            
            // Save to Firebase
            try await saveReport(report)
            
        } catch {
            logger.error("Failed to generate report: \(error.localizedDescription)")
            await MainActor.run {
                isGeneratingReport = false
            }
        }
    }
    
    func generateCustomReport(template: ReportTemplate, data: [String: Any]) async {
        await MainActor.run {
            isGeneratingReport = true
        }
        
        do {
            let report = try await createCustomReport(template: template, data: data)
            
            await MainActor.run {
                customReports.append(report)
                isGeneratingReport = false
            }
            
            try await saveCustomReport(report)
            
        } catch {
            logger.error("Failed to generate custom report: \(error.localizedDescription)")
            await MainActor.run {
                isGeneratingReport = false
            }
        }
    }
    
    // MARK: - Analytics Data Collection
    
    func updateAnalyticsData() async {
        do {
            let bookingData = await collectBookingAnalytics()
            let revenueData = await collectRevenueAnalytics()
            let customerData = await collectCustomerAnalytics()
            let sitterData = await collectSitterAnalytics()
            let operationalData = await collectOperationalAnalytics()
            
            await MainActor.run {
                analyticsData = AnalyticsData(
                    bookingAnalytics: bookingData,
                    revenueAnalytics: revenueData,
                    customerAnalytics: customerData,
                    sitterAnalytics: sitterData,
                    operationalAnalytics: operationalData,
                    lastUpdated: Date()
                )
            }
            
            try await saveAnalyticsData(analyticsData)
            
        } catch {
            logger.error("Failed to update analytics data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Export Functions
    
    func exportReport(_ report: Report, format: ExportFormat) async -> URL? {
        await MainActor.run {
            isExporting = true
        }
        
        do {
            let url = try await createExportFile(report: report, format: format)
            
            let exportRecord = ExportRecord(
                id: UUID().uuidString,
                reportId: report.id,
                reportName: report.name,
                format: format,
                exportedAt: Date(),
                fileSize: 0, // Will be updated after file creation
                downloadUrl: url.absoluteString
            )
            
            await MainActor.run {
                exportHistory.append(exportRecord)
                isExporting = false
            }
            
            try await saveExportRecord(exportRecord)
            return url
            
        } catch {
            logger.error("Failed to export report: \(error.localizedDescription)")
            await MainActor.run {
                isExporting = false
            }
            return nil
        }
    }
    
    // MARK: - Scheduled Reports
    
    func createScheduledReport(template: ReportTemplate, schedule: ReportSchedule, recipients: [String]) async {
        let scheduledReport = ScheduledReport(
            id: UUID().uuidString,
            templateId: template.id,
            templateName: template.name,
            schedule: schedule,
            recipients: recipients,
            isActive: true,
            lastRun: nil,
            nextRun: calculateNextRun(schedule: schedule),
            createdAt: Date()
        )
        
        await MainActor.run {
            scheduledReports.append(scheduledReport)
        }
        
        try? await saveScheduledReport(scheduledReport)
    }
    
    func runScheduledReports() async {
        let now = Date()
        let dueReports = scheduledReports.filter { report in
            report.isActive && (report.nextRun ?? Date.distantFuture) <= now
        }
        
        for scheduledReport in dueReports {
            if let template = reportTemplates.first(where: { $0.id == scheduledReport.templateId }) {
                await generateCustomReport(template: template, data: [:])
                
                // Update next run time
                if let index = scheduledReports.firstIndex(where: { $0.id == scheduledReport.id }) {
                    scheduledReports[index].lastRun = now
                    scheduledReports[index].nextRun = calculateNextRun(schedule: scheduledReport.schedule)
                }
            }
        }
    }
    
    // MARK: - Insights Generation
    
    func generateInsights() async {
        let newInsights = await analyzeDataForInsights()
        
        await MainActor.run {
            insights = newInsights
        }
        
        try? await saveInsights(newInsights)
    }
    
    // MARK: - Private Helper Methods
    
    private func createReport(type: ReportType, timeRange: TimeRange, filters: ReportFilters) async throws -> Report {
        let data = await collectReportData(type: type, timeRange: timeRange, filters: filters)
        
        return Report(
            id: UUID().uuidString,
            name: "\(type.displayName) - \(timeRange.displayName)",
            type: type,
            timeRange: timeRange,
            filters: filters,
            data: data,
            generatedAt: Date(),
            generatedBy: Auth.auth().currentUser?.uid ?? "system"
        )
    }
    
    private func createCustomReport(template: ReportTemplate, data: [String: Any]) async throws -> CustomReport {
        return CustomReport(
            id: UUID().uuidString,
            templateId: template.id,
            templateName: template.name,
            data: data,
            generatedAt: Date(),
            generatedBy: Auth.auth().currentUser?.uid ?? "system"
        )
    }
    
    private func collectReportData(type: ReportType, timeRange: TimeRange, filters: ReportFilters) async -> [String: Any] {
        switch type {
        case .booking:
            return await collectBookingData(timeRange: timeRange, filters: filters)
        case .revenue:
            return await collectRevenueData(timeRange: timeRange, filters: filters)
        case .customer:
            return await collectCustomerData(timeRange: timeRange, filters: filters)
        case .sitter:
            return await collectSitterData(timeRange: timeRange, filters: filters)
        case .operational:
            return await collectOperationalData(timeRange: timeRange, filters: filters)
        case .financial:
            return await collectFinancialData(timeRange: timeRange, filters: filters)
        case .marketing:
            return await collectMarketingData(timeRange: timeRange, filters: filters)
        case .custom:
            return [:]
        }
    }
    
    private func collectBookingData(timeRange: TimeRange, filters: ReportFilters) async -> [String: Any] {
        // Sample booking analytics data
        return [
            "totalBookings": Int.random(in: 100...500),
            "completedBookings": Int.random(in: 80...450),
            "cancelledBookings": Int.random(in: 5...50),
            "averageBookingValue": Double.random(in: 50...150),
            "bookingTrends": generateTrendData(days: timeRange.days),
            "topServices": [
                ["name": "Dog Walking", "count": Int.random(in: 20...80)],
                ["name": "Pet Sitting", "count": Int.random(in: 15...60)],
                ["name": "Overnight Care", "count": Int.random(in: 10...40)]
            ],
            "peakHours": generatePeakHoursData(),
            "seasonalTrends": generateSeasonalData()
        ]
    }
    
    private func collectRevenueData(timeRange: TimeRange, filters: ReportFilters) async -> [String: Any] {
        return [
            "totalRevenue": Double.random(in: 5000...50000),
            "averageOrderValue": Double.random(in: 60...120),
            "revenueGrowth": Double.random(in: -10...25),
            "revenueByService": [
                ["service": "Dog Walking", "revenue": Double.random(in: 1000...5000)],
                ["service": "Pet Sitting", "revenue": Double.random(in: 800...4000)],
                ["service": "Overnight Care", "revenue": Double.random(in: 600...3000)]
            ],
            "revenueTrends": generateTrendData(days: timeRange.days),
            "paymentMethods": [
                ["method": "Credit Card", "percentage": 65.0],
                ["method": "PayPal", "percentage": 20.0],
                ["method": "Cash", "percentage": 15.0]
            ]
        ]
    }
    
    private func collectCustomerData(timeRange: TimeRange, filters: ReportFilters) async -> [String: Any] {
        return [
            "totalCustomers": Int.random(in: 200...1000),
            "newCustomers": Int.random(in: 20...100),
            "returningCustomers": Int.random(in: 150...800),
            "customerSatisfaction": Double.random(in: 4.0...5.0),
            "customerRetentionRate": Double.random(in: 70...95),
            "customerLifetimeValue": Double.random(in: 200...800),
            "customerSegments": [
                ["segment": "High Value", "count": Int.random(in: 50...200)],
                ["segment": "Regular", "count": Int.random(in: 100...400)],
                ["segment": "Occasional", "count": Int.random(in: 50...300)]
            ],
            "customerFeedback": generateFeedbackData()
        ]
    }
    
    private func collectSitterData(timeRange: TimeRange, filters: ReportFilters) async -> [String: Any] {
        return [
            "totalSitters": Int.random(in: 20...100),
            "activeSitters": Int.random(in: 15...80),
            "averageRating": Double.random(in: 4.0...5.0),
            "sitterUtilization": Double.random(in: 60...90),
            "topPerformers": generateTopPerformersData(),
            "sitterRetention": Double.random(in: 80...95),
            "certificationStatus": [
                ["status": "Certified", "count": Int.random(in: 10...50)],
                ["status": "Pending", "count": Int.random(in: 5...20)],
                ["status": "Expired", "count": Int.random(in: 2...10)]
            ]
        ]
    }
    
    private func collectOperationalData(timeRange: TimeRange, filters: ReportFilters) async -> [String: Any] {
        return [
            "systemUptime": Double.random(in: 95...99.9),
            "averageResponseTime": Double.random(in: 100...500),
            "errorRate": Double.random(in: 0.1...2.0),
            "supportTickets": Int.random(in: 10...100),
            "resolutionTime": Double.random(in: 2...24),
            "operationalEfficiency": Double.random(in: 80...95),
            "resourceUtilization": [
                ["resource": "CPU", "usage": Double.random(in: 20...80)],
                ["resource": "Memory", "usage": Double.random(in: 30...70)],
                ["resource": "Storage", "usage": Double.random(in: 40...90)]
            ]
        ]
    }
    
    private func collectFinancialData(timeRange: TimeRange, filters: ReportFilters) async -> [String: Any] {
        return [
            "totalRevenue": Double.random(in: 10000...100000),
            "totalExpenses": Double.random(in: 5000...50000),
            "netProfit": Double.random(in: 2000...60000),
            "profitMargin": Double.random(in: 15...40),
            "cashFlow": generateCashFlowData(days: timeRange.days),
            "expenseCategories": [
                ["category": "Staff", "amount": Double.random(in: 2000...15000)],
                ["category": "Marketing", "amount": Double.random(in: 500...3000)],
                ["category": "Operations", "amount": Double.random(in: 1000...8000)]
            ]
        ]
    }
    
    private func collectMarketingData(timeRange: TimeRange, filters: ReportFilters) async -> [String: Any] {
        return [
            "campaigns": Int.random(in: 5...20),
            "totalSpend": Double.random(in: 1000...10000),
            "roi": Double.random(in: 200...800),
            "conversionRate": Double.random(in: 2...8),
            "acquisitionCost": Double.random(in: 20...100),
            "marketingChannels": [
                ["channel": "Social Media", "leads": Int.random(in: 50...200)],
                ["channel": "Google Ads", "leads": Int.random(in: 30...150)],
                ["channel": "Referrals", "leads": Int.random(in: 20...100)]
            ]
        ]
    }
    
    // MARK: - Analytics Collection Methods
    
    private func collectBookingAnalytics() async -> BookingAnalytics {
        return BookingAnalytics(
            totalBookings: Int.random(in: 1000...5000),
            completedBookings: Int.random(in: 900...4800),
            cancelledBookings: Int.random(in: 50...200),
            averageBookingValue: Double.random(in: 60...120),
            bookingTrends: generateTrendData(days: 30),
            peakHours: generatePeakHoursData(),
            seasonalTrends: generateSeasonalData(),
            serviceDistribution: generateServiceDistribution(),
            customerSegments: generateCustomerSegments()
        )
    }
    
    private func collectRevenueAnalytics() async -> RevenueAnalytics {
        return RevenueAnalytics(
            totalRevenue: Double.random(in: 50000...200000),
            monthlyRevenue: Double.random(in: 5000...20000),
            revenueGrowth: Double.random(in: -5...25),
            averageOrderValue: Double.random(in: 70...130),
            revenueByService: generateRevenueByService(),
            paymentMethodDistribution: generatePaymentMethods(),
            revenueTrends: generateTrendData(days: 30),
            profitMargins: generateProfitMargins()
        )
    }
    
    private func collectCustomerAnalytics() async -> CustomerAnalytics {
        return CustomerAnalytics(
            totalCustomers: Int.random(in: 500...2000),
            newCustomers: Int.random(in: 50...200),
            returningCustomers: Int.random(in: 400...1800),
            customerSatisfaction: Double.random(in: 4.2...5.0),
            retentionRate: Double.random(in: 75...95),
            lifetimeValue: Double.random(in: 300...1000),
            customerSegments: generateCustomerSegments(),
            feedbackAnalysis: generateFeedbackAnalysis()
        )
    }
    
    private func collectSitterAnalytics() async -> SitterAnalytics {
        return SitterAnalytics(
            totalSitters: Int.random(in: 50...200),
            activeSitters: Int.random(in: 40...180),
            averageRating: Double.random(in: 4.3...5.0),
            utilizationRate: Double.random(in: 65...90),
            topPerformers: generateTopPerformers(),
            retentionRate: Double.random(in: 80...95),
            certificationStatus: generateCertificationStatus(),
            performanceMetrics: generatePerformanceMetrics()
        )
    }
    
    private func collectOperationalAnalytics() async -> OperationalAnalytics {
        return OperationalAnalytics(
            systemUptime: Double.random(in: 98...99.9),
            averageResponseTime: Double.random(in: 150...400),
            errorRate: Double.random(in: 0.1...1.5),
            supportTickets: Int.random(in: 20...150),
            averageResolutionTime: Double.random(in: 4...12),
            operationalEfficiency: Double.random(in: 85...95),
            resourceUtilization: generateResourceUtilization(),
            performanceMetrics: generateSystemPerformanceMetrics()
        )
    }
    
    // MARK: - Data Generation Helpers
    
    private func generateTrendData(days: Int) -> [TrendDataPoint] {
        var data: [TrendDataPoint] = []
        let baseValue = Double.random(in: 50...200)
        
        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let value = baseValue + Double.random(in: -20...20)
            data.append(TrendDataPoint(date: date, value: value))
        }
        
        return data.reversed()
    }
    
    private func generatePeakHoursData() -> [PeakHourData] {
        let hours = Array(0...23)
        return hours.map { hour in
            let isPeak = (hour >= 8 && hour <= 10) || (hour >= 17 && hour <= 19)
            let bookings = isPeak ? Int.random(in: 15...30) : Int.random(in: 2...10)
            return PeakHourData(hour: hour, bookings: bookings, isPeak: isPeak)
        }
    }
    
    private func generateSeasonalData() -> [SeasonalData] {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months.enumerated().map { index, month in
            let isPeakSeason = [5, 6, 7, 11].contains(index) // Summer and holidays
            let bookings = isPeakSeason ? Int.random(in: 80...150) : Int.random(in: 40...80)
            return SeasonalData(month: month, bookings: bookings, isPeak: isPeakSeason)
        }
    }
    
    private func generateServiceDistribution() -> [ServiceDistribution] {
        return [
            ServiceDistribution(service: "Dog Walking", count: Int.random(in: 100...300), percentage: 40.0),
            ServiceDistribution(service: "Pet Sitting", count: Int.random(in: 80...250), percentage: 35.0),
            ServiceDistribution(service: "Overnight Care", count: Int.random(in: 50...150), percentage: 25.0)
        ]
    }
    
    private func generateCustomerSegments() -> [CustomerSegment] {
        return [
            CustomerSegment(segment: "High Value", count: Int.random(in: 50...200), percentage: 20.0),
            CustomerSegment(segment: "Regular", count: Int.random(in: 150...400), percentage: 50.0),
            CustomerSegment(segment: "Occasional", count: Int.random(in: 100...300), percentage: 30.0)
        ]
    }
    
    private func generateRevenueByService() -> [RevenueByService] {
        return [
            RevenueByService(service: "Dog Walking", revenue: Double.random(in: 10000...30000)),
            RevenueByService(service: "Pet Sitting", revenue: Double.random(in: 8000...25000)),
            RevenueByService(service: "Overnight Care", revenue: Double.random(in: 5000...20000))
        ]
    }
    
    private func generatePaymentMethods() -> [PaymentMethodDistribution] {
        return [
            PaymentMethodDistribution(method: "Credit Card", percentage: 65.0),
            PaymentMethodDistribution(method: "PayPal", percentage: 20.0),
            PaymentMethodDistribution(method: "Cash", percentage: 15.0)
        ]
    }
    
    private func generateProfitMargins() -> [ProfitMarginData] {
        return [
            ProfitMarginData(service: "Dog Walking", margin: Double.random(in: 20...35)),
            ProfitMarginData(service: "Pet Sitting", margin: Double.random(in: 25...40)),
            ProfitMarginData(service: "Overnight Care", margin: Double.random(in: 30...45))
        ]
    }
    
    private func generateFeedbackAnalysis() -> [FeedbackAnalysis] {
        return [
            FeedbackAnalysis(category: "Excellent", count: Int.random(in: 200...400), percentage: 60.0),
            FeedbackAnalysis(category: "Good", count: Int.random(in: 100...200), percentage: 30.0),
            FeedbackAnalysis(category: "Needs Improvement", count: Int.random(in: 10...50), percentage: 10.0)
        ]
    }
    
    private func generateTopPerformers() -> [TopPerformer] {
        return [
            TopPerformer(name: "Sarah Johnson", rating: 4.9, bookings: Int.random(in: 50...100)),
            TopPerformer(name: "Mike Chen", rating: 4.8, bookings: Int.random(in: 45...95)),
            TopPerformer(name: "Emily Davis", rating: 4.7, bookings: Int.random(in: 40...90))
        ]
    }
    
    private func generateCertificationStatus() -> [CertificationStatus] {
        return [
            CertificationStatus(status: "Certified", count: Int.random(in: 30...80)),
            CertificationStatus(status: "Pending", count: Int.random(in: 10...30)),
            CertificationStatus(status: "Expired", count: Int.random(in: 5...15))
        ]
    }
    
    private func generatePerformanceMetrics() -> [ReportPerformanceMetric] {
        return [
            ReportPerformanceMetric(metric: "Response Time", value: Double.random(in: 2...8), unit: "minutes"),
            ReportPerformanceMetric(metric: "Completion Rate", value: Double.random(in: 85...98), unit: "%"),
            ReportPerformanceMetric(metric: "Customer Rating", value: Double.random(in: 4.2...5.0), unit: "stars")
        ]
    }
    
    private func generateResourceUtilization() -> [ResourceUtilization] {
        return [
            ResourceUtilization(resource: "CPU", usage: Double.random(in: 20...80), capacity: 100.0),
            ResourceUtilization(resource: "Memory", usage: Double.random(in: 30...70), capacity: 100.0),
            ResourceUtilization(resource: "Storage", usage: Double.random(in: 40...90), capacity: 100.0)
        ]
    }
    
    private func generateSystemPerformanceMetrics() -> [SystemPerformanceMetric] {
        return [
            SystemPerformanceMetric(metric: "Uptime", value: Double.random(in: 98...99.9), unit: "%"),
            SystemPerformanceMetric(metric: "Response Time", value: Double.random(in: 100...400), unit: "ms"),
            SystemPerformanceMetric(metric: "Error Rate", value: Double.random(in: 0.1...1.5), unit: "%")
        ]
    }
    
    private func generateCashFlowData(days: Int) -> [CashFlowData] {
        var data: [CashFlowData] = []
        let baseRevenue = Double.random(in: 1000...3000)
        let baseExpenses = Double.random(in: 500...1500)
        
        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let revenue = baseRevenue + Double.random(in: -200...200)
            let expenses = baseExpenses + Double.random(in: -100...100)
            let netCashFlow = revenue - expenses
            
            data.append(CashFlowData(date: date, revenue: revenue, expenses: expenses, netCashFlow: netCashFlow))
        }
        
        return data.reversed()
    }
    
    private func generateFeedbackData() -> [FeedbackData] {
        return [
            FeedbackData(rating: 5, count: Int.random(in: 100...300)),
            FeedbackData(rating: 4, count: Int.random(in: 50...150)),
            FeedbackData(rating: 3, count: Int.random(in: 20...80)),
            FeedbackData(rating: 2, count: Int.random(in: 5...30)),
            FeedbackData(rating: 1, count: Int.random(in: 2...15))
        ]
    }
    
    private func generateTopPerformersData() -> [TopPerformerData] {
        return [
            TopPerformerData(name: "Sarah Johnson", bookings: Int.random(in: 50...100), rating: 4.9),
            TopPerformerData(name: "Mike Chen", bookings: Int.random(in: 45...95), rating: 4.8),
            TopPerformerData(name: "Emily Davis", bookings: Int.random(in: 40...90), rating: 4.7)
        ]
    }
    
    private func calculateNextRun(schedule: ReportSchedule) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch schedule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: now) ?? now
        }
    }
    
    private func analyzeDataForInsights() async -> [AnalyticsInsight] {
        return [
            AnalyticsInsight(
                id: UUID().uuidString,
                title: "Revenue Growth Opportunity",
                description: "Your weekend bookings are 25% higher than weekdays. Consider promoting weekend services.",
                type: .opportunity,
                priority: .high,
                category: .revenue,
                metrics: ["weekend_bookings": 125, "weekday_bookings": 100],
                recommendations: ["Increase weekend service promotion", "Consider weekend pricing adjustments"],
                createdAt: Date()
            ),
            AnalyticsInsight(
                id: UUID().uuidString,
                title: "Customer Satisfaction Alert",
                description: "Customer satisfaction has decreased by 5% this month. Review recent feedback.",
                type: .alert,
                priority: .medium,
                category: .customer,
                metrics: ["satisfaction_current": 4.2, "satisfaction_previous": 4.4],
                recommendations: ["Review customer feedback", "Check sitter performance"],
                createdAt: Date()
            ),
            AnalyticsInsight(
                id: UUID().uuidString,
                title: "Peak Hour Optimization",
                description: "Most bookings occur between 8-10 AM and 5-7 PM. Optimize sitter availability.",
                type: .insight,
                priority: .low,
                category: .operational,
                metrics: ["peak_hours": "8-10 AM, 5-7 PM", "booking_concentration": 65.0],
                recommendations: ["Schedule more sitters during peak hours", "Consider off-peak discounts"],
                createdAt: Date()
            )
        ]
    }
    
    private func generateInitialInsights() {
        insights = [
            AnalyticsInsight(
                id: UUID().uuidString,
                title: "Welcome to Analytics",
                description: "Your analytics dashboard is ready. Generate reports to see insights.",
                type: .info,
                priority: .low,
                category: .general,
                metrics: [:],
                recommendations: ["Generate your first report", "Set up scheduled reports"],
                createdAt: Date()
            )
        ]
    }
    
    // MARK: - Firebase Operations
    
    private func saveReport(_ report: Report) async throws {
        try await db.collection("reports").document(report.id).setData(from: report)
    }
    
    private func saveCustomReport(_ report: CustomReport) async throws {
        try await db.collection("custom_reports").document(report.id).setData(from: report)
    }
    
    private func saveAnalyticsData(_ data: AnalyticsData) async throws {
        try await db.collection("analytics").document("current").setData(from: data)
    }
    
    private func saveScheduledReport(_ report: ScheduledReport) async throws {
        try await db.collection("scheduled_reports").document(report.id).setData(from: report)
    }
    
    private func saveExportRecord(_ record: ExportRecord) async throws {
        try await db.collection("export_history").document(record.id).setData(from: record)
    }
    
    private func saveInsights(_ insights: [AnalyticsInsight]) async throws {
        for insight in insights {
            try await db.collection("insights").document(insight.id).setData(from: insight)
        }
    }
    
    private func loadReportTemplates() {
        reportTemplates = [
            ReportTemplate(
                id: "booking_summary",
                name: "Booking Summary Report",
                description: "Comprehensive overview of booking metrics",
                type: .booking,
                fields: ["total_bookings", "completion_rate", "average_value"],
                isDefault: true
            ),
            ReportTemplate(
                id: "revenue_analysis",
                name: "Revenue Analysis Report",
                description: "Detailed revenue breakdown and trends",
                type: .revenue,
                fields: ["total_revenue", "growth_rate", "service_breakdown"],
                isDefault: true
            ),
            ReportTemplate(
                id: "customer_insights",
                name: "Customer Insights Report",
                description: "Customer behavior and satisfaction analysis",
                type: .customer,
                fields: ["satisfaction", "retention", "segments"],
                isDefault: true
            )
        ]
    }
    
    private func loadCustomReports() {
        // Load from Firebase in real implementation
    }
    
    private func loadScheduledReports() {
        // Load from Firebase in real implementation
    }
    
    private func createExportFile(report: Report, format: ExportFormat) async throws -> URL {
        // Create temporary file for export
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "\(report.name.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        // In a real implementation, you would generate the actual file content
        // For now, create a simple text file
        let content = "Report: \(report.name)\nGenerated: \(report.generatedAt)\nType: \(report.type.displayName)"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
}

// MARK: - Data Models

struct Report: Codable, Identifiable {
    let id: String
    let name: String
    let type: ReportType
    let timeRange: TimeRange
    let filters: ReportFilters
    let data: [String: Any]
    let generatedAt: Date
    let generatedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, timeRange, filters, generatedAt, generatedBy
    }
    
    init(id: String, name: String, type: ReportType, timeRange: TimeRange, filters: ReportFilters, data: [String: Any], generatedAt: Date, generatedBy: String) {
        self.id = id
        self.name = name
        self.type = type
        self.timeRange = timeRange
        self.filters = filters
        self.data = data
        self.generatedAt = generatedAt
        self.generatedBy = generatedBy
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ReportType.self, forKey: .type)
        timeRange = try container.decode(TimeRange.self, forKey: .timeRange)
        filters = try container.decode(ReportFilters.self, forKey: .filters)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        generatedBy = try container.decode(String.self, forKey: .generatedBy)
        data = [:] // Simplified for demo
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(timeRange, forKey: .timeRange)
        try container.encode(filters, forKey: .filters)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(generatedBy, forKey: .generatedBy)
    }
}

struct CustomReport: Codable, Identifiable {
    let id: String
    let templateId: String
    let templateName: String
    let data: [String: Any]
    let generatedAt: Date
    let generatedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id, templateId, templateName, generatedAt, generatedBy
    }
    
    init(id: String, templateId: String, templateName: String, data: [String: Any], generatedAt: Date, generatedBy: String) {
        self.id = id
        self.templateId = templateId
        self.templateName = templateName
        self.data = data
        self.generatedAt = generatedAt
        self.generatedBy = generatedBy
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        templateId = try container.decode(String.self, forKey: .templateId)
        templateName = try container.decode(String.self, forKey: .templateName)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        generatedBy = try container.decode(String.self, forKey: .generatedBy)
        data = [:] // Simplified for demo
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(templateId, forKey: .templateId)
        try container.encode(templateName, forKey: .templateName)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(generatedBy, forKey: .generatedBy)
    }
}

struct ReportTemplate: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let type: ReportType
    let fields: [String]
    let isDefault: Bool
}

struct ScheduledReport: Codable, Identifiable {
    let id: String
    let templateId: String
    let templateName: String
    let schedule: ReportSchedule
    let recipients: [String]
    var isActive: Bool
    var lastRun: Date?
    var nextRun: Date?
    let createdAt: Date
}

struct ReportSchedule: Codable {
    let frequency: ScheduleFrequency
    let time: String // HH:MM format
    let dayOfWeek: Int? // 1-7 for weekly
    let dayOfMonth: Int? // 1-31 for monthly
}

enum ScheduleFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
}

struct ReportFilters: Codable {
    let dateRange: DateRange?
    let serviceTypes: [String]?
    let sitterIds: [String]?
    let customerSegments: [String]?
    let customFilters: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case dateRange, serviceTypes, sitterIds, customerSegments
    }
    
    init(dateRange: DateRange? = nil, serviceTypes: [String]? = nil, sitterIds: [String]? = nil, customerSegments: [String]? = nil, customFilters: [String: Any]? = nil) {
        self.dateRange = dateRange
        self.serviceTypes = serviceTypes
        self.sitterIds = sitterIds
        self.customerSegments = customerSegments
        self.customFilters = customFilters
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateRange = try container.decodeIfPresent(DateRange.self, forKey: .dateRange)
        serviceTypes = try container.decodeIfPresent([String].self, forKey: .serviceTypes)
        sitterIds = try container.decodeIfPresent([String].self, forKey: .sitterIds)
        customerSegments = try container.decodeIfPresent([String].self, forKey: .customerSegments)
        customFilters = nil // Simplified for demo
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(dateRange, forKey: .dateRange)
        try container.encodeIfPresent(serviceTypes, forKey: .serviceTypes)
        try container.encodeIfPresent(sitterIds, forKey: .sitterIds)
        try container.encodeIfPresent(customerSegments, forKey: .customerSegments)
    }
}

struct DateRange: Codable {
    let startDate: Date
    let endDate: Date
}

enum ReportType: String, CaseIterable, Codable {
    case booking = "booking"
    case revenue = "revenue"
    case customer = "customer"
    case sitter = "sitter"
    case operational = "operational"
    case financial = "financial"
    case marketing = "marketing"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .booking: return "Booking Report"
        case .revenue: return "Revenue Report"
        case .customer: return "Customer Report"
        case .sitter: return "Sitter Report"
        case .operational: return "Operational Report"
        case .financial: return "Financial Report"
        case .marketing: return "Marketing Report"
        case .custom: return "Custom Report"
        }
    }
    
    var icon: String {
        switch self {
        case .booking: return "calendar"
        case .revenue: return "dollarsign.circle"
        case .customer: return "person.2"
        case .sitter: return "figure.walk"
        case .operational: return "gearshape"
        case .financial: return "chart.line.uptrend.xyaxis"
        case .marketing: return "megaphone"
        case .custom: return "doc.text"
        }
    }
}

enum TimeRange: String, CaseIterable, Codable {
    case last7Days = "last_7_days"
    case last30Days = "last_30_days"
    case last90Days = "last_90_days"
    case lastYear = "last_year"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .lastYear: return "Last Year"
        case .custom: return "Custom Range"
        }
    }
    
    var days: Int {
        switch self {
        case .last7Days: return 7
        case .last30Days: return 30
        case .last90Days: return 90
        case .lastYear: return 365
        case .custom: return 30
        }
    }
}

enum ExportFormat: String, CaseIterable, Codable {
    case pdf = "pdf"
    case csv = "csv"
    case excel = "excel"
    case json = "json"
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .csv: return "CSV"
        case .excel: return "Excel"
        case .json: return "JSON"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .csv: return "csv"
        case .excel: return "xlsx"
        case .json: return "json"
        }
    }
}

struct ExportRecord: Codable, Identifiable {
    let id: String
    let reportId: String
    let reportName: String
    let format: ExportFormat
    let exportedAt: Date
    let fileSize: Int64
    let downloadUrl: String
}

// MARK: - Analytics Data Models

struct AnalyticsData: Codable {
    let bookingAnalytics: BookingAnalytics
    let revenueAnalytics: RevenueAnalytics
    let customerAnalytics: CustomerAnalytics
    let sitterAnalytics: SitterAnalytics
    let operationalAnalytics: OperationalAnalytics
    let lastUpdated: Date
    
    init(bookingAnalytics: BookingAnalytics = BookingAnalytics(), revenueAnalytics: RevenueAnalytics = RevenueAnalytics(), customerAnalytics: CustomerAnalytics = CustomerAnalytics(), sitterAnalytics: SitterAnalytics = SitterAnalytics(), operationalAnalytics: OperationalAnalytics = OperationalAnalytics(), lastUpdated: Date = Date()) {
        self.bookingAnalytics = bookingAnalytics
        self.revenueAnalytics = revenueAnalytics
        self.customerAnalytics = customerAnalytics
        self.sitterAnalytics = sitterAnalytics
        self.operationalAnalytics = operationalAnalytics
        self.lastUpdated = lastUpdated
    }
}

struct BookingAnalytics: Codable {
    let totalBookings: Int
    let completedBookings: Int
    let cancelledBookings: Int
    let averageBookingValue: Double
    let bookingTrends: [TrendDataPoint]
    let peakHours: [PeakHourData]
    let seasonalTrends: [SeasonalData]
    let serviceDistribution: [ServiceDistribution]
    let customerSegments: [CustomerSegment]
    
    init(totalBookings: Int = 0, completedBookings: Int = 0, cancelledBookings: Int = 0, averageBookingValue: Double = 0.0, bookingTrends: [TrendDataPoint] = [], peakHours: [PeakHourData] = [], seasonalTrends: [SeasonalData] = [], serviceDistribution: [ServiceDistribution] = [], customerSegments: [CustomerSegment] = []) {
        self.totalBookings = totalBookings
        self.completedBookings = completedBookings
        self.cancelledBookings = cancelledBookings
        self.averageBookingValue = averageBookingValue
        self.bookingTrends = bookingTrends
        self.peakHours = peakHours
        self.seasonalTrends = seasonalTrends
        self.serviceDistribution = serviceDistribution
        self.customerSegments = customerSegments
    }
}

struct RevenueAnalytics: Codable {
    let totalRevenue: Double
    let monthlyRevenue: Double
    let revenueGrowth: Double
    let averageOrderValue: Double
    let revenueByService: [RevenueByService]
    let paymentMethodDistribution: [PaymentMethodDistribution]
    let revenueTrends: [TrendDataPoint]
    let profitMargins: [ProfitMarginData]
    
    init(totalRevenue: Double = 0.0, monthlyRevenue: Double = 0.0, revenueGrowth: Double = 0.0, averageOrderValue: Double = 0.0, revenueByService: [RevenueByService] = [], paymentMethodDistribution: [PaymentMethodDistribution] = [], revenueTrends: [TrendDataPoint] = [], profitMargins: [ProfitMarginData] = []) {
        self.totalRevenue = totalRevenue
        self.monthlyRevenue = monthlyRevenue
        self.revenueGrowth = revenueGrowth
        self.averageOrderValue = averageOrderValue
        self.revenueByService = revenueByService
        self.paymentMethodDistribution = paymentMethodDistribution
        self.revenueTrends = revenueTrends
        self.profitMargins = profitMargins
    }
}

struct CustomerAnalytics: Codable {
    let totalCustomers: Int
    let newCustomers: Int
    let returningCustomers: Int
    let customerSatisfaction: Double
    let retentionRate: Double
    let lifetimeValue: Double
    let customerSegments: [CustomerSegment]
    let feedbackAnalysis: [FeedbackAnalysis]
    
    init(totalCustomers: Int = 0, newCustomers: Int = 0, returningCustomers: Int = 0, customerSatisfaction: Double = 0.0, retentionRate: Double = 0.0, lifetimeValue: Double = 0.0, customerSegments: [CustomerSegment] = [], feedbackAnalysis: [FeedbackAnalysis] = []) {
        self.totalCustomers = totalCustomers
        self.newCustomers = newCustomers
        self.returningCustomers = returningCustomers
        self.customerSatisfaction = customerSatisfaction
        self.retentionRate = retentionRate
        self.lifetimeValue = lifetimeValue
        self.customerSegments = customerSegments
        self.feedbackAnalysis = feedbackAnalysis
    }
}

struct SitterAnalytics: Codable {
    let totalSitters: Int
    let activeSitters: Int
    let averageRating: Double
    let utilizationRate: Double
    let topPerformers: [TopPerformer]
    let retentionRate: Double
    let certificationStatus: [CertificationStatus]
    let performanceMetrics: [ReportPerformanceMetric]
    
    init(totalSitters: Int = 0, activeSitters: Int = 0, averageRating: Double = 0.0, utilizationRate: Double = 0.0, topPerformers: [TopPerformer] = [], retentionRate: Double = 0.0, certificationStatus: [CertificationStatus] = [], performanceMetrics: [ReportPerformanceMetric] = []) {
        self.totalSitters = totalSitters
        self.activeSitters = activeSitters
        self.averageRating = averageRating
        self.utilizationRate = utilizationRate
        self.topPerformers = topPerformers
        self.retentionRate = retentionRate
        self.certificationStatus = certificationStatus
        self.performanceMetrics = performanceMetrics
    }
}

struct OperationalAnalytics: Codable {
    let systemUptime: Double
    let averageResponseTime: Double
    let errorRate: Double
    let supportTickets: Int
    let averageResolutionTime: Double
    let operationalEfficiency: Double
    let resourceUtilization: [ResourceUtilization]
    let performanceMetrics: [SystemPerformanceMetric]
    
    init(systemUptime: Double = 0.0, averageResponseTime: Double = 0.0, errorRate: Double = 0.0, supportTickets: Int = 0, averageResolutionTime: Double = 0.0, operationalEfficiency: Double = 0.0, resourceUtilization: [ResourceUtilization] = [], performanceMetrics: [SystemPerformanceMetric] = []) {
        self.systemUptime = systemUptime
        self.averageResponseTime = averageResponseTime
        self.errorRate = errorRate
        self.supportTickets = supportTickets
        self.averageResolutionTime = averageResolutionTime
        self.operationalEfficiency = operationalEfficiency
        self.resourceUtilization = resourceUtilization
        self.performanceMetrics = performanceMetrics
    }
}

// MARK: - Supporting Data Models

struct TrendDataPoint: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    
    enum CodingKeys: String, CodingKey {
        case date, value
    }
}

struct PeakHourData: Codable, Identifiable {
    let id = UUID()
    let hour: Int
    let bookings: Int
    let isPeak: Bool
    
    enum CodingKeys: String, CodingKey {
        case hour, bookings, isPeak
    }
}

struct SeasonalData: Codable, Identifiable {
    let id = UUID()
    let month: String
    let bookings: Int
    let isPeak: Bool
    
    enum CodingKeys: String, CodingKey {
        case month, bookings, isPeak
    }
}

struct ServiceDistribution: Codable, Identifiable {
    let id = UUID()
    let service: String
    let count: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case service, count, percentage
    }
}

struct CustomerSegment: Codable, Identifiable {
    let id = UUID()
    let segment: String
    let count: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case segment, count, percentage
    }
}

struct RevenueByService: Codable, Identifiable {
    let id = UUID()
    let service: String
    let revenue: Double
    
    enum CodingKeys: String, CodingKey {
        case service, revenue
    }
}

struct PaymentMethodDistribution: Codable, Identifiable {
    let id = UUID()
    let method: String
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case method, percentage
    }
}

struct ProfitMarginData: Codable, Identifiable {
    let id = UUID()
    let service: String
    let margin: Double
    
    enum CodingKeys: String, CodingKey {
        case service, margin
    }
}

struct FeedbackAnalysis: Codable, Identifiable {
    let id = UUID()
    let category: String
    let count: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case category, count, percentage
    }
}

struct TopPerformer: Codable, Identifiable {
    let id = UUID()
    let name: String
    let rating: Double
    let bookings: Int
    
    enum CodingKeys: String, CodingKey {
        case name, rating, bookings
    }
}

struct CertificationStatus: Codable, Identifiable {
    let id = UUID()
    let status: String
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case status, count
    }
}

struct ReportPerformanceMetric: Codable, Identifiable {
    let id = UUID()
    let metric: String
    let value: Double
    let unit: String
    
    enum CodingKeys: String, CodingKey {
        case metric, value, unit
    }
}

struct ResourceUtilization: Codable, Identifiable {
    let id = UUID()
    let resource: String
    let usage: Double
    let capacity: Double
    
    enum CodingKeys: String, CodingKey {
        case resource, usage, capacity
    }
}

struct SystemPerformanceMetric: Codable, Identifiable {
    let id = UUID()
    let metric: String
    let value: Double
    let unit: String
    
    enum CodingKeys: String, CodingKey {
        case metric, value, unit
    }
}

struct CashFlowData: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let revenue: Double
    let expenses: Double
    let netCashFlow: Double
    
    enum CodingKeys: String, CodingKey {
        case date, revenue, expenses, netCashFlow
    }
}

struct FeedbackData: Codable, Identifiable {
    let id = UUID()
    let rating: Int
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case rating, count
    }
}

struct TopPerformerData: Codable, Identifiable {
    let id = UUID()
    let name: String
    let bookings: Int
    let rating: Double
    
    enum CodingKeys: String, CodingKey {
        case name, bookings, rating
    }
}

struct AnalyticsInsight: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let type: InsightType
    let priority: InsightPriority
    let category: InsightCategory
    let metrics: [String: Any]
    let recommendations: [String]
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, type, priority, category, recommendations, createdAt
    }
    
    init(id: String, title: String, description: String, type: InsightType, priority: InsightPriority, category: InsightCategory, metrics: [String: Any], recommendations: [String], createdAt: Date) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.priority = priority
        self.category = category
        self.metrics = metrics
        self.recommendations = recommendations
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        type = try container.decode(InsightType.self, forKey: .type)
        priority = try container.decode(InsightPriority.self, forKey: .priority)
        category = try container.decode(InsightCategory.self, forKey: .category)
        recommendations = try container.decode([String].self, forKey: .recommendations)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        metrics = [:] // Simplified for demo
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(type, forKey: .type)
        try container.encode(priority, forKey: .priority)
        try container.encode(category, forKey: .category)
        try container.encode(recommendations, forKey: .recommendations)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

enum InsightType: String, CaseIterable, Codable {
    case insight = "insight"
    case opportunity = "opportunity"
    case alert = "alert"
    case info = "info"
    
    var color: Color {
        switch self {
        case .insight: return .blue
        case .opportunity: return .green
        case .alert: return .red
        case .info: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .insight: return "lightbulb.fill"
        case .opportunity: return "star.fill"
        case .alert: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

enum InsightPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

enum InsightCategory: String, CaseIterable, Codable {
    case general = "general"
    case revenue = "revenue"
    case customer = "customer"
    case operational = "operational"
    case marketing = "marketing"
    case financial = "financial"
}
