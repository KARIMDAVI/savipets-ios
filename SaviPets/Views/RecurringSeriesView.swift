import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// View for managing recurring booking series
struct RecurringSeriesView: View {
    let booking: ServiceBooking
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var seriesBookings: [ServiceBooking] = []
    @State private var isLoading = true
    @State private var showingModifySeries = false
    @State private var showingPauseSeries = false
    @State private var showingCancelSeries = false
    @State private var selectedAction: SeriesAction?
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Services
    private let auditService = AuditTrailService()
    
    enum SeriesAction: String, CaseIterable {
        case modify = "Modify Series"
        case pause = "Pause Series"
        case cancel = "Cancel Series"
        
        var systemImage: String {
            switch self {
            case .modify: return "pencil"
            case .pause: return "pause.circle"
            case .cancel: return "xmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .modify: return .blue
            case .pause: return .orange
            case .cancel: return .red
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.l) {
                    if isLoading {
                        loadingView
                    } else {
                        // Series Overview
                        seriesOverviewSection
                        
                        // Calendar Grid
                        calendarSection
                        
                        // Upcoming Visits List
                        upcomingVisitsSection
                        
                        // Series Actions
                        seriesActionsSection
                    }
                }
                .padding(SPDesignSystem.Spacing.m)
            }
            .navigationTitle("Recurring Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $showingModifySeries) {
                ModifySeriesSheet(booking: booking) { success in
                    if success {
                        loadSeriesBookings()
                    }
                }
            }
            .sheet(isPresented: $showingPauseSeries) {
                PauseSeriesSheet(booking: booking) { success in
                    if success {
                        loadSeriesBookings()
                    }
                }
            }
            .sheet(isPresented: $showingCancelSeries) {
                CancelSeriesSheet(booking: booking) { success in
                    if success {
                        dismiss()
                    }
                }
            }
            .task {
                loadSeriesBookings()
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: SPDesignSystem.Spacing.m) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading series information...")
                .font(SPDesignSystem.Typography.body())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, SPDesignSystem.Spacing.xl)
    }
    
    // MARK: - Series Overview Section
    
    private var seriesOverviewSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Series Overview")
                    .font(SPDesignSystem.Typography.heading2())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                OverviewRow(
                    label: "Service",
                    value: booking.serviceType
                )
                
                if booking.isRecurring {
                    OverviewRow(
                        label: "Frequency",
                        value: "Weekly" // Default to weekly for recurring bookings
                    )
                }
                
                OverviewRow(
                    label: "Total Visits",
                    value: "\(seriesBookings.count)"
                )
                
                OverviewRow(
                    label: "Remaining Visits",
                    value: "\(remainingVisits)"
                )
                
                OverviewRow(
                    label: "Next Visit",
                    value: nextVisitText
                )
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Calendar Section
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Series Calendar")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            // Simple calendar grid showing series dates
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Day headers
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
                
                // Calendar days with series dates highlighted
                ForEach(daysInCurrentMonth, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSeriesDate: isSeriesDate(date),
                        isCurrentDate: Calendar.current.isDateInToday(date),
                        isPast: date < Date()
                    )
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Upcoming Visits Section
    
    private var upcomingVisitsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Upcoming Visits")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            if upcomingBookings.isEmpty {
                Text("No upcoming visits in this series")
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, SPDesignSystem.Spacing.m)
            } else {
                VStack(spacing: 8) {
                    ForEach(upcomingBookings.prefix(5)) { visit in
                        VisitRow(visit: visit)
                    }
                    
                    if upcomingBookings.count > 5 {
                        Button("Show All Visits") {
                            // Show full list
                        }
                        .font(SPDesignSystem.Typography.callout())
                        .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .padding(.top, SPDesignSystem.Spacing.s)
                    }
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Series Actions Section
    
    private var seriesActionsSection: some View {
        VStack(alignment: .leading, spacing: SPDesignSystem.Spacing.s) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                
                Text("Series Management")
                    .font(SPDesignSystem.Typography.heading3())
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            VStack(spacing: 12) {
                ForEach(SeriesAction.allCases, id: \.self) { action in
                    SeriesActionButton(
                        action: action,
                        onTap: { handleSeriesAction(action) }
                    )
                }
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(SPDesignSystem.Colors.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Computed Properties
    
    private var remainingVisits: Int {
        seriesBookings.filter { $0.scheduledDate > Date() && $0.status != .cancelled }.count
    }
    
    private var nextVisitText: String {
        guard let nextVisit = seriesBookings
            .filter({ $0.scheduledDate > Date() && $0.status != .cancelled })
            .min(by: { $0.scheduledDate < $1.scheduledDate }) else {
            return "No upcoming visits"
        }
        
        return dateFormatter.string(from: nextVisit.scheduledDate)
    }
    
    private var upcomingBookings: [ServiceBooking] {
        seriesBookings
            .filter { $0.scheduledDate > Date() && $0.status != .cancelled }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    private var daysInCurrentMonth: [Date] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let range = calendar.range(of: .day, in: .month, for: now) ?? 1..<32
        
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
        
        // Add padding days
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let paddingDays = firstWeekday - 1
        
        var allDays: [Date] = []
        
        // Previous month days
        for i in 0..<paddingDays {
            if let date = calendar.date(byAdding: .day, value: -(paddingDays - i), to: startOfMonth) {
                allDays.append(date)
            }
        }
        
        // Current month days
        allDays.append(contentsOf: days)
        
        // Next month days to fill the grid
        let remainingDays = 42 - allDays.count
        for i in 0..<remainingDays {
            if let date = calendar.date(byAdding: .day, value: i + 1, to: days.last ?? startOfMonth) {
                allDays.append(date)
            }
        }
        
        return allDays
    }
    
    // MARK: - Helper Methods
    
    private func isSeriesDate(_ date: Date) -> Bool {
        seriesBookings.contains { booking in
            Calendar.current.isDate(booking.scheduledDate, inSameDayAs: date)
        }
    }
    
    private func handleSeriesAction(_ action: SeriesAction) {
        selectedAction = action
        
        switch action {
        case .modify:
            showingModifySeries = true
        case .pause:
            showingPauseSeries = true
        case .cancel:
            showingCancelSeries = true
        }
    }
    
    private func loadSeriesBookings() {
        Task {
            do {
                let db = Firestore.firestore()
                
                // Query for all bookings in this series
                // In a real implementation, you'd have a seriesId field to group bookings
                let snapshot = try await db.collection("serviceBookings")
                    .whereField("clientId", isEqualTo: booking.clientId)
                    .whereField("serviceType", isEqualTo: booking.serviceType)
                    .whereField("isRecurring", isEqualTo: true)
                    .whereField("scheduledDate", isGreaterThan: Date().addingTimeInterval(-86400 * 30)) // Last 30 days
                    .order(by: "scheduledDate")
                    .getDocuments()
                
                let bookings = snapshot.documents.compactMap { document in
                    // Parse booking from document (simplified)
                    ServiceBooking(
                        id: document.documentID,
                        clientId: booking.clientId,
                        serviceType: booking.serviceType,
                        scheduledDate: (document.data()["scheduledDate"] as? Timestamp)?.dateValue() ?? Date(),
                        scheduledTime: booking.scheduledTime,
                        duration: booking.duration,
                        pets: booking.pets,
                        specialInstructions: booking.specialInstructions,
                        status: ServiceBooking.BookingStatus(rawValue: document.data()["status"] as? String ?? "pending") ?? .pending,
                        sitterId: booking.sitterId,
                        sitterName: booking.sitterName,
                        createdAt: booking.createdAt,
                        address: booking.address,
                        checkIn: booking.checkIn,
                        checkOut: booking.checkOut,
                        price: booking.price,
                        recurringSeriesId: booking.recurringSeriesId,
                        visitNumber: document.data()["visitNumber"] as? Int,
                        isRecurring: true,
                        paymentStatus: PaymentStatus(rawValue: document.data()["paymentStatus"] as? String ?? "pending") ?? .pending,
                        paymentTransactionId: booking.paymentTransactionId,
                        paymentAmount: booking.paymentAmount,
                        paymentMethod: booking.paymentMethod,
                        rescheduledFrom: booking.rescheduledFrom,
                        rescheduledAt: booking.rescheduledAt,
                        rescheduledBy: booking.rescheduledBy,
                        rescheduleReason: booking.rescheduleReason,
                        rescheduleHistory: booking.rescheduleHistory,
                        lastModified: Date(),
                        lastModifiedBy: booking.clientId,
                        modificationReason: nil
                    )
                }
                
                await MainActor.run {
                    seriesBookings = bookings
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load series bookings: \(error.localizedDescription)"
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct OverviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

private struct CalendarDayView: View {
    let date: Date
    let isSeriesDate: Bool
    let isCurrentDate: Bool
    let isPast: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text("\(Calendar.current.component(.day, from: date))")
            .font(SPDesignSystem.Typography.footnote())
            .foregroundColor(textColor)
            .frame(width: 30, height: 30)
            .background(backgroundColor)
            .clipShape(Circle())
    }
    
    private var textColor: Color {
        if isCurrentDate {
            return .white
        } else if isSeriesDate {
            return .white
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isCurrentDate {
            return SPDesignSystem.Colors.primaryAdjusted(colorScheme)
        } else if isSeriesDate {
            return .blue
        } else {
            return Color.clear
        }
    }
}

private struct VisitRow: View {
    let visit: ServiceBooking
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: visit.scheduledDate))
                    .font(SPDesignSystem.Typography.bodyMedium())
                    .foregroundColor(.primary)
                
                Text(visit.pets.joined(separator: ", "))
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(status: visit.status)
        }
        .padding(SPDesignSystem.Spacing.s)
        .background(SPDesignSystem.Colors.surface(colorScheme).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SeriesActionButton: View {
    let action: RecurringSeriesView.SeriesAction
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: action.systemImage)
                    .foregroundColor(action.color)
                
                Text(action.rawValue)
                    .font(SPDesignSystem.Typography.bodyMedium())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(SPDesignSystem.Spacing.m)
            .background(SPDesignSystem.Colors.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(action.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder Sheets

private struct ModifySeriesSheet: View {
    let booking: ServiceBooking
    let onCompletion: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Modify Series")
                    .font(SPDesignSystem.Typography.heading2())
                
                Text("This feature allows you to modify the frequency, preferred days/times, and number of remaining visits in your recurring series.")
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Modify Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onCompletion(true)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PauseSeriesSheet: View {
    let booking: ServiceBooking
    let onCompletion: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Pause Series")
                    .font(SPDesignSystem.Typography.heading2())
                
                Text("This feature allows you to pause your recurring series for a specified number of visits or until a certain date.")
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Pause Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Pause") {
                        onCompletion(true)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CancelSeriesSheet: View {
    let booking: ServiceBooking
    let onCompletion: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Cancel Series")
                    .font(SPDesignSystem.Typography.heading2())
                
                Text("This will cancel all future visits in your recurring series. Past visits will remain unaffected.")
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Cancel Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel Series") {
                        onCompletion(true)
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RecurringSeriesView(
        booking: ServiceBooking(
            id: "preview",
            clientId: "client1",
            serviceType: "Dog Walking",
            scheduledDate: Date().addingTimeInterval(3600),
            scheduledTime: "10:00 AM",
            duration: 30,
            pets: ["Buddy"],
            specialInstructions: "",
            status: .approved,
            sitterId: "sitter1",
            sitterName: "Sarah Johnson",
            createdAt: Date(),
            address: "123 Main St",
            checkIn: nil,
            checkOut: nil,
            price: "25.00",
            recurringSeriesId: "series-123",
            visitNumber: 1,
            isRecurring: true,
            paymentStatus: .confirmed,
            paymentTransactionId: nil,
            paymentAmount: 25.0,
            paymentMethod: "credit_card",
            rescheduledFrom: nil,
            rescheduledAt: nil,
            rescheduledBy: nil,
            rescheduleReason: nil,
            rescheduleHistory: [],
            lastModified: Date(),
            lastModifiedBy: "client1",
            modificationReason: nil
        )
    )
}
