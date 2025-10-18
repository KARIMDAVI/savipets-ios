import SwiftUI
import OSLog

struct BookingCalendarView: View {
    @EnvironmentObject var serviceBookings: ServiceBookingDataService
    @StateObject private var calendarSyncService = CalendarSyncService()
    
    @State private var selectedDate: Date = Date()
    @State private var selectedView: CalendarViewType = .month
    @State private var showingDatePicker: Bool = false
    @State private var showingSyncSettings: Bool = false
    @State private var showingFeedbackSheet: Bool = false
    @State private var selectedBooking: ServiceBooking?
    @State private var dragOffset: CGSize = .zero
    @State private var draggedBooking: ServiceBooking?
    
    enum CalendarViewType: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Calendar Header
                CalendarHeaderView(
                    selectedDate: $selectedDate,
                    selectedView: $selectedView,
                    showingDatePicker: $showingDatePicker
                )
                
                // Calendar Content
                CalendarContentView(
                    selectedDate: selectedDate,
                    selectedView: selectedView,
                    serviceBookings: serviceBookings.userBookings,
                    onBookingTap: { booking in
                        selectedBooking = booking
                    },
                    onBookingDrag: handleBookingDrag,
                    onBookingDrop: handleBookingDrop
                )
                
                // Sync Status Bar
                CalendarSyncStatusBar(
                    calendarSyncService: calendarSyncService,
                    onSyncTap: {
                        showingSyncSettings = true
                    }
                )
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Sync button
                    Button(action: { showingSyncSettings = true }) {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(calendarSyncService.isAuthorized ? .blue : .gray)
                    }
                    
                    // View type picker
                    Menu {
                        ForEach(CalendarViewType.allCases, id: \.id) { viewType in
                            Button(viewType.rawValue) {
                                selectedView = viewType
                            }
                        }
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate)
            }
            .sheet(isPresented: $showingSyncSettings) {
                CalendarSyncSettingsSheet(calendarSyncService: calendarSyncService)
            }
            .sheet(item: $selectedBooking) { booking in
                BookingDetailSheet(booking: booking)
            }
            .sheet(isPresented: $showingFeedbackSheet) {
                if let booking = selectedBooking {
                    ServiceFeedbackView(booking: booking)
                }
            }
        }
    }
    
    // MARK: - Drag and Drop Handlers
    private func handleBookingDrag(_ booking: ServiceBooking, offset: CGSize) {
        draggedBooking = booking
        dragOffset = offset
    }
    
    private func handleBookingDrop(_ booking: ServiceBooking, targetDate: Date) {
        // Handle booking reschedule via drag and drop
        Task {
            // Here you would integrate with the BookingRescheduleService
            // For now, we'll just log the action
            AppLogger.ui.info("Booking \(booking.id) dropped on \(targetDate)")
            
            // Reset drag state
            draggedBooking = nil
            dragOffset = .zero
        }
    }
}

// MARK: - Calendar Header
private struct CalendarHeaderView: View {
    @Binding var selectedDate: Date
    @Binding var selectedView: BookingCalendarView.CalendarViewType
    @Binding var showingDatePicker: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Date navigation
            HStack {
                Button(action: { navigateDate(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: { showingDatePicker = true }) {
                    VStack(spacing: 2) {
                        Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Tap to change")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: { navigateDate(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // View type selector
            HStack(spacing: 0) {
                ForEach(BookingCalendarView.CalendarViewType.allCases, id: \.id) { viewType in
                    Button(action: { selectedView = viewType }) {
                        Text(viewType.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedView == viewType ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedView == viewType ? Color.blue : Color.clear)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private func navigateDate(_ direction: Int) {
        let calendar = Calendar.current
        let newDate: Date
        
        switch selectedView {
        case .day:
            newDate = calendar.date(byAdding: .day, value: direction, to: selectedDate) ?? selectedDate
        case .week:
            newDate = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate) ?? selectedDate
        case .month:
            newDate = calendar.date(byAdding: .month, value: direction, to: selectedDate) ?? selectedDate
        }
        
        selectedDate = newDate
    }
}

// MARK: - Calendar Content
private struct CalendarContentView: View {
    let selectedDate: Date
    let selectedView: BookingCalendarView.CalendarViewType
    let serviceBookings: [ServiceBooking]
    let onBookingTap: (ServiceBooking) -> Void
    let onBookingDrag: (ServiceBooking, CGSize) -> Void
    let onBookingDrop: (ServiceBooking, Date) -> Void
    
    var body: some View {
        Group {
            switch selectedView {
            case .day:
                DayView(
                    date: selectedDate,
                    bookings: filteredBookings,
                    onBookingTap: onBookingTap,
                    onBookingDrag: onBookingDrag,
                    onBookingDrop: onBookingDrop
                )
            case .week:
                WeekView(
                    date: selectedDate,
                    bookings: filteredBookings,
                    onBookingTap: onBookingTap,
                    onBookingDrag: onBookingDrag,
                    onBookingDrop: onBookingDrop
                )
            case .month:
                MonthView(
                    date: selectedDate,
                    bookings: filteredBookings,
                    onBookingTap: onBookingTap,
                    onBookingDrag: onBookingDrag,
                    onBookingDrop: onBookingDrop
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedView)
    }
    
    private var filteredBookings: [ServiceBooking] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay: Date
        
        switch selectedView {
        case .day:
            endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        case .week:
            endOfDay = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfDay) ?? startOfDay
        case .month:
            endOfDay = calendar.date(byAdding: .month, value: 1, to: startOfDay) ?? startOfDay
        }
        
        return serviceBookings.filter { booking in
            booking.scheduledDate >= startOfDay && booking.scheduledDate < endOfDay
        }
    }
}

// MARK: - Day View
private struct DayView: View {
    let date: Date
    let bookings: [ServiceBooking]
    let onBookingTap: (ServiceBooking) -> Void
    let onBookingDrag: (ServiceBooking, CGSize) -> Void
    let onBookingDrop: (ServiceBooking, Date) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(hourSlots, id: \.hour) { hourSlot in
                    HourSlotView(
                        hourSlot: hourSlot,
                        bookings: bookingsForHour(hourSlot.hour),
                        onBookingTap: onBookingTap,
                        onBookingDrag: onBookingDrag,
                        onBookingDrop: onBookingDrop
                    )
                }
            }
            .padding()
        }
    }
    
    private var hourSlots: [HourSlot] {
        let calendar = Calendar.current
        let startHour = 6 // 6 AM
        let endHour = 22 // 10 PM
        
        return (startHour...endHour).map { hour in
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: self.date) ?? self.date
            return HourSlot(hour: hour, date: date)
        }
    }
    
    private func bookingsForHour(_ hour: Int) -> [ServiceBooking] {
        let calendar = Calendar.current
        let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let hourEnd = calendar.date(bySettingHour: hour + 1, minute: 0, second: 0, of: date) ?? date
        
        return bookings.filter { booking in
            booking.scheduledDate >= hourStart && booking.scheduledDate < hourEnd
        }
    }
}

// MARK: - Week View
private struct WeekView: View {
    let date: Date
    let bookings: [ServiceBooking]
    let onBookingTap: (ServiceBooking) -> Void
    let onBookingDrag: (ServiceBooking, CGSize) -> Void
    let onBookingDrop: (ServiceBooking, Date) -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Week header with day names
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { weekDate in
                    WeekDayHeader(
                        date: weekDate,
                        isToday: calendar.isDateInToday(weekDate),
                        isSelected: calendar.isDate(weekDate, inSameDayAs: date)
                    )
                }
            }
            .background(Color(.systemGray6))
            
            // Week content
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(hourSlots, id: \.hour) { hourSlot in
                        WeekHourRow(
                            hourSlot: hourSlot,
                            weekDates: weekDates,
                            bookings: bookings,
                            onBookingTap: onBookingTap,
                            onBookingDrag: onBookingDrag,
                            onBookingDrop: onBookingDrop
                        )
                    }
                }
            }
        }
    }
    
    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    private var hourSlots: [HourSlot] {
        let startHour = 6
        let endHour = 22
        
        return (startHour...endHour).map { hour in
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: self.date) ?? self.date
            return HourSlot(hour: hour, date: date)
        }
    }
}

// MARK: - Month View
private struct MonthView: View {
    let date: Date
    let bookings: [ServiceBooking]
    let onBookingTap: (ServiceBooking) -> Void
    let onBookingDrag: (ServiceBooking, CGSize) -> Void
    let onBookingDrop: (ServiceBooking, Date) -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header with day names
            HStack(spacing: 0) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { dayName in
                    Text(dayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .background(Color(.systemGray6))
            
            // Month grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 1) {
                ForEach(monthDates, id: \.self) { monthDate in
                    MonthDayCell(
                        date: monthDate,
                        bookings: bookingsForDate(monthDate),
                        isToday: calendar.isDateInToday(monthDate),
                        isCurrentMonth: calendar.isDate(monthDate, equalTo: date, toGranularity: .month),
                        onBookingTap: onBookingTap,
                        onBookingDrag: onBookingDrag,
                        onBookingDrop: onBookingDrop
                    )
                }
            }
            .background(Color(.systemGray6))
        }
    }
    
    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthStart = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start else {
            return []
        }
        
        let endDate = calendar.date(byAdding: .month, value: 1, to: monthInterval.start) ?? date
        let monthEnd = calendar.dateInterval(of: .weekOfYear, for: endDate)?.end ?? endDate
        
        var dates: [Date] = []
        var currentDate = monthStart
        
        while currentDate < monthEnd {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    private func bookingsForDate(_ date: Date) -> [ServiceBooking] {
        return bookings.filter { booking in
            calendar.isDate(booking.scheduledDate, inSameDayAs: date)
        }
    }
}

// MARK: - Supporting Views
private struct HourSlot: Identifiable {
    let id = UUID()
    let hour: Int
    let date: Date
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct HourSlotView: View {
    let hourSlot: HourSlot
    let bookings: [ServiceBooking]
    let onBookingTap: (ServiceBooking) -> Void
    let onBookingDrag: (ServiceBooking, CGSize) -> Void
    let onBookingDrop: (ServiceBooking, Date) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time label
            Text(hourSlot.timeString)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Bookings
            VStack(spacing: 4) {
                ForEach(bookings) { booking in
                    DraggableBookingCard(
                        booking: booking,
                        onTap: { onBookingTap(booking) },
                        onDrag: { offset in onBookingDrag(booking, offset) },
                        onDrop: { targetDate in onBookingDrop(booking, targetDate) }
                    )
                }
                
                if bookings.isEmpty {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WeekDayHeader: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(date.formatted(.dateTime.day()))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(isToday ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(isToday ? Color.blue : (isSelected ? Color.blue.opacity(0.2) : Color.clear))
                .clipShape(Circle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct WeekHourRow: View {
    let hourSlot: HourSlot
    let weekDates: [Date]
    let bookings: [ServiceBooking]
    let onBookingTap: (ServiceBooking) -> Void
    let onBookingDrag: (ServiceBooking, CGSize) -> Void
    let onBookingDrop: (ServiceBooking, Date) -> Void
    
    var body: some View {
        HStack(spacing: 1) {
            // Time label
            Text(hourSlot.timeString)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 50)
                .background(Color(.systemBackground))
            
            // Day columns
            ForEach(weekDates, id: \.self) { weekDate in
                WeekDayCell(
                    date: weekDate,
                    hour: hourSlot.hour,
                    bookings: bookingsForDateAndHour(weekDate, hourSlot.hour),
                    onBookingTap: onBookingTap,
                    onBookingDrag: onBookingDrag,
                    onBookingDrop: onBookingDrop
                )
            }
        }
        .frame(height: 60)
        .background(Color(.systemGray6))
    }
    
    private func bookingsForDateAndHour(_ date: Date, _ hour: Int) -> [ServiceBooking] {
        let calendar = Calendar.current
        let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let hourEnd = calendar.date(bySettingHour: hour + 1, minute: 0, second: 0, of: date) ?? date
        
        return bookings.filter { booking in
            booking.scheduledDate >= hourStart && booking.scheduledDate < hourEnd
        }
    }
}

private struct WeekDayCell: View {
    let date: Date
    let hour: Int
    let bookings: [ServiceBooking]
    let onBookingTap: (ServiceBooking) -> Void
    let onBookingDrag: (ServiceBooking, CGSize) -> Void
    let onBookingDrop: (ServiceBooking, Date) -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(bookings.prefix(2)) { booking in
                DraggableBookingCard(
                    booking: booking,
                    onTap: { onBookingTap(booking) },
                    onDrag: { offset in onBookingDrag(booking, offset) },
                    onDrop: { targetDate in onBookingDrop(booking, targetDate) }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .border(Color(.systemGray5), width: 0.5)
    }
}

private struct MonthDayCell: View {
    let date: Date
    let bookings: [ServiceBooking]
    let isToday: Bool
    let isCurrentMonth: Bool
    let onBookingTap: (ServiceBooking) -> Void
    let onBookingDrag: (ServiceBooking, CGSize) -> Void
    let onBookingDrop: (ServiceBooking, Date) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Date number
            Text(date.formatted(.dateTime.day()))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isCurrentMonth ? (isToday ? .white : .primary) : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Bookings (show up to 3)
            ForEach(bookings.prefix(3)) { booking in
                DraggableBookingCard(
                    booking: booking,
                    onTap: { onBookingTap(booking) },
                    onDrag: { offset in onBookingDrag(booking, offset) },
                    onDrop: { targetDate in onBookingDrop(booking, targetDate) }
                )
            }
            
            if bookings.count > 3 {
                Text("+\(bookings.count - 3) more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(isToday ? Color.blue : Color(.systemBackground))
        .border(Color(.systemGray5), width: 0.5)
    }
}

// MARK: - Draggable Booking Card
private struct DraggableBookingCard: View {
    let booking: ServiceBooking
    let onTap: () -> Void
    let onDrag: (CGSize) -> Void
    let onDrop: (Date) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.serviceType)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(booking.pets.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                
                Text(booking.scheduledDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(booking.status.color.opacity(0.8))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .offset(dragOffset)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .shadow(radius: isDragging ? 4 : 1)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                    }
                    dragOffset = value.translation
                    onDrag(value.translation)
                }
                .onEnded { value in
                    isDragging = false
                    dragOffset = .zero
                    onDrop(booking.scheduledDate)
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
}

// MARK: - Calendar Sync Status Bar
private struct CalendarSyncStatusBar: View {
    @ObservedObject var calendarSyncService: CalendarSyncService
    let onSyncTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: calendarSyncService.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(calendarSyncService.isAuthorized ? .green : .orange)
            
            Text(calendarSyncService.isAuthorized ? "Calendar synced" : "Calendar not connected")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let lastSync = calendarSyncService.lastSyncTime {
                Text("Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button("Sync") {
                onSyncTap()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// MARK: - Supporting Sheets
private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct BookingDetailSheet: View {
    let booking: ServiceBooking
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Booking details
                    VStack(alignment: .leading, spacing: 8) {
                        Text(booking.serviceType)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("with \(booking.sitterName ?? "your sitter")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(booking.scheduledDate.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Status
                    HStack {
                        Text("Status:")
                            .fontWeight(.medium)
                        
                        StatusBadge(status: booking.status)
                    }
                    
                    // Pets
                    if !booking.pets.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pets:")
                                .fontWeight(.medium)
                            
                            ForEach(booking.pets, id: \.self) { pet in
                                Text("• \(pet)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Instructions
                    if let instructions = booking.specialInstructions {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Instructions:")
                                .fontWeight(.medium)
                            
                            Text(instructions)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Booking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CalendarSyncSettingsSheet: View {
    @ObservedObject var calendarSyncService: CalendarSyncService
    @Environment(\.dismiss) private var dismiss
    @State private var isRequestingAccess: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Calendar Sync")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Keep your SaviPets bookings in sync with your calendar app")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Status
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: calendarSyncService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(calendarSyncService.isAuthorized ? .green : .red)
                        
                        Text(calendarSyncService.isAuthorized ? "Calendar connected" : "Calendar not connected")
                            .fontWeight(.medium)
                    }
                    
                    if calendarSyncService.isAuthorized {
                        Text("Your bookings are automatically synced to your calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Actions
                VStack(spacing: 12) {
                    if !calendarSyncService.isAuthorized {
                        Button(action: requestAccess) {
                            HStack {
                                if isRequestingAccess {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                
                                Text("Connect Calendar")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isRequestingAccess)
                    } else {
                        Button(action: { dismiss() }) {
                            Text("Done")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Calendar Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func requestAccess() {
        isRequestingAccess = true
        
        Task {
            let granted = await calendarSyncService.requestCalendarAccess()
            
            await MainActor.run {
                isRequestingAccess = false
                if granted {
                    // Access granted, dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Preview
#Preview {
    BookingCalendarView()
        .environmentObject(ServiceBookingDataService())
}
