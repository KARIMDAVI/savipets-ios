import SwiftUI
import OSLog

struct BookingHistoryView: View {
    @EnvironmentObject var serviceBookings: ServiceBookingDataService
    @StateObject private var offlineCache = OfflineBookingCache()
    
    @State private var searchText: String = ""
    @State private var selectedStatus: ServiceBooking.BookingStatus? = nil
    @State private var selectedTimeframe: TimeFrame = .all
    @State private var selectedSort: SortOption = .dateDescending
    @State private var showFilters: Bool = false
    @State private var showOfflineIndicator: Bool = false
    
    enum TimeFrame: String, CaseIterable {
        case all = "All Time"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case custom = "Custom Range"
        
        var dateRange: (start: Date, end: Date) {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .all:
                return (start: Date.distantPast, end: Date.distantFuture)
            case .today:
                let startOfDay = calendar.startOfDay(for: now)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
                return (start: startOfDay, end: endOfDay)
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? now
                return (start: startOfWeek, end: endOfWeek)
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
                return (start: startOfMonth, end: endOfMonth)
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? lastMonth
                let endOfLastMonth = calendar.date(byAdding: .month, value: 1, to: startOfLastMonth) ?? lastMonth
                return (start: startOfLastMonth, end: endOfLastMonth)
            case .custom:
                // Custom range will be handled separately
                return (start: Date.distantPast, end: Date.distantFuture)
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case dateDescending = "Date (Newest)"
        case dateAscending = "Date (Oldest)"
        case priceDescending = "Price (High to Low)"
        case priceAscending = "Price (Low to High)"
        case status = "Status"
        case serviceType = "Service Type"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Offline indicator
                if !offlineCache.isOnline {
                    OfflineIndicatorView(offlineCache: offlineCache)
                }
                
                // Search and filter bar
                SearchAndFilterBar(
                    searchText: $searchText,
                    selectedStatus: $selectedStatus,
                    selectedTimeframe: $selectedTimeframe,
                    showFilters: $showFilters
                )
                
                // Results summary
                ResultsSummaryView(
                    totalCount: filteredBookings.count,
                    filteredCount: filteredBookings.count,
                    selectedTimeframe: selectedTimeframe
                )
                
                // Bookings list
                if filteredBookings.isEmpty {
                    SPEmptyStateView(
                        icon: searchText.isEmpty ? "calendar.badge.clock" : "magnifyingglass",
                        title: emptyStateTitle,
                        message: emptyStateMessage,
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    BookingsListView(
                        bookings: sortedBookings,
                        sortOption: selectedSort,
                        onBookingTap: handleBookingTap,
                        onReschedule: handleReschedule,
                        onCancel: handleCancel
                    )
                }
            }
            .navigationTitle("Booking History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(SortOption.allCases, id: \.id) { option in
                            Button(action: { selectedSort = option }) {
                                HStack {
                                    Text(option.rawValue)
                                    if selectedSort == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFilters.toggle() }) {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSheetView(
                    selectedStatus: $selectedStatus,
                    selectedTimeframe: $selectedTimeframe,
                    onApply: { showFilters = false }
                )
            }
        }
        .onAppear {
            setupOfflineSupport()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - Computed Properties
    private var filteredBookings: [ServiceBooking] {
        let bookings = offlineCache.isOnline ? serviceBookings.userBookings : offlineCache.getBookings(for: getCurrentUserId())
        
        return bookings.filter { booking in
            // Search filter
            let matchesSearch = searchText.isEmpty || 
                               booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
                               booking.sitterName?.localizedCaseInsensitiveContains(searchText) == true
            
            // Status filter
            let matchesStatus = selectedStatus == nil || booking.status == selectedStatus
            
            // Timeframe filter
            let dateRange = selectedTimeframe.dateRange
            let matchesTimeframe = booking.scheduledDate >= dateRange.start && booking.scheduledDate <= dateRange.end
            
            return matchesSearch && matchesStatus && matchesTimeframe
        }
    }
    
    private var sortedBookings: [ServiceBooking] {
        switch selectedSort {
        case .dateDescending:
            return filteredBookings.sorted { $0.scheduledDate > $1.scheduledDate }
        case .dateAscending:
            return filteredBookings.sorted { $0.scheduledDate < $1.scheduledDate }
        case .priceDescending:
            return filteredBookings.sorted { 
                Double($0.price) ?? 0 > Double($1.price) ?? 0 
            }
        case .priceAscending:
            return filteredBookings.sorted { 
                Double($0.price) ?? 0 < Double($1.price) ?? 0 
            }
        case .status:
            return filteredBookings.sorted { $0.status.rawValue < $1.status.rawValue }
        case .serviceType:
            return filteredBookings.sorted { $0.serviceType < $1.serviceType }
        }
    }
    
    private var hasActiveFilters: Bool {
        return selectedStatus != nil || selectedTimeframe != .all || !searchText.isEmpty
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No Results Found"
        } else if hasActiveFilters {
            return "No Bookings Match Filters"
        } else {
            return "No Booking History"
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms or filters to find what you're looking for."
        } else if hasActiveFilters {
            return "Try removing some filters to see more bookings."
        } else {
            return "Your booking history will appear here once you start making reservations."
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserId() -> String {
        // This should get the current user's ID from your auth service
        return "current_user_id" // Replace with actual implementation
    }
    
    private func setupOfflineSupport() {
        // Initialize offline cache with current user's bookings
        Task {
            await offlineCache.refreshCache()
        }
    }
    
    private func refreshData() async {
        if offlineCache.isOnline {
            await offlineCache.refreshCache()
        }
    }
    
    private func handleBookingTap(_ booking: ServiceBooking) {
        // Navigate to booking details
        AppLogger.ui.info("Tapped booking: \(booking.id)")
    }
    
    private func handleReschedule(_ booking: ServiceBooking) {
        // Handle reschedule action
        AppLogger.ui.info("Reschedule booking: \(booking.id)")
    }
    
    private func handleCancel(_ booking: ServiceBooking) {
        // Handle cancel action
        AppLogger.ui.info("Cancel booking: \(booking.id)")
    }
}

// MARK: - Supporting Views
private struct OfflineIndicatorView: View {
    let offlineCache: OfflineBookingCache
    
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            Text(offlineCache.offlineIndicatorText)
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
            if offlineCache.hasPendingChanges {
                Text("\(offlineCache.pendingChanges.count) pending")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
}

private struct SearchAndFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedStatus: ServiceBooking.BookingStatus?
    @Binding var selectedTimeframe: BookingHistoryView.TimeFrame
    @Binding var showFilters: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search bookings...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filter chips
            if showFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All Status",
                            isSelected: selectedStatus == nil,
                            onTap: { selectedStatus = nil }
                        )
                        
                        ForEach(ServiceBooking.BookingStatus.allCases, id: \.rawValue) { status in
                            FilterChip(
                                title: status.displayName,
                                isSelected: selectedStatus == status,
                                onTap: { selectedStatus = status }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BookingHistoryView.TimeFrame.allCases, id: \.rawValue) { timeframe in
                            FilterChip(
                                title: timeframe.rawValue,
                                isSelected: selectedTimeframe == timeframe,
                                onTap: { selectedTimeframe = timeframe }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

private struct ResultsSummaryView: View {
    let totalCount: Int
    let filteredCount: Int
    let selectedTimeframe: BookingHistoryView.TimeFrame
    
    var body: some View {
        HStack {
            Text("\(filteredCount) booking\(filteredCount == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if selectedTimeframe != .all {
                Text("in \(selectedTimeframe.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}


private struct BookingsListView: View {
    let bookings: [ServiceBooking]
    let sortOption: BookingHistoryView.SortOption
    let onBookingTap: (ServiceBooking) -> Void
    let onReschedule: (ServiceBooking) -> Void
    let onCancel: (ServiceBooking) -> Void
    
    var body: some View {
        List {
            ForEach(bookings) { booking in
                SwipeableBookingCard(
                    booking: booking,
                    clientName: nil, // This would come from user data
                    sitterName: booking.sitterName,
                    onReschedule: onReschedule,
                    onCancel: onCancel,
                    onViewDetails: onBookingTap
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
    }
}

private struct FilterSheetView: View {
    @Binding var selectedStatus: ServiceBooking.BookingStatus?
    @Binding var selectedTimeframe: BookingHistoryView.TimeFrame
    let onApply: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Status filter
                VStack(alignment: .leading, spacing: 12) {
                    Text("Status")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        FilterChip(
                            title: "All Status",
                            isSelected: selectedStatus == nil,
                            onTap: { selectedStatus = nil }
                        )
                        
                        ForEach(ServiceBooking.BookingStatus.allCases, id: \.rawValue) { status in
                            FilterChip(
                                title: status.displayName,
                                isSelected: selectedStatus == status,
                                onTap: { selectedStatus = status }
                            )
                        }
                    }
                }
                
                // Timeframe filter
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time Period")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(BookingHistoryView.TimeFrame.allCases, id: \.rawValue) { timeframe in
                            FilterChip(
                                title: timeframe.rawValue,
                                isSelected: selectedTimeframe == timeframe,
                                onTap: { selectedTimeframe = timeframe }
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    BookingHistoryView()
        .environmentObject(ServiceBookingDataService())
}
