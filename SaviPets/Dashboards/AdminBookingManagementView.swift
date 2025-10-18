import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import OSLog

struct AdminBookingManagementView: View {
    @ObservedObject var serviceBookings: ServiceBookingDataService
    @State private var searchText: String = ""
    @State private var selectedStatus: ServiceBooking.BookingStatus? = nil
    @State private var selectedTimeframe: Timeframe = .all
    @State private var selectedSitter: String? = nil
    @State private var sortOrder: SortOrder = .dateAscending
    @State private var showFilters: Bool = false
    @State private var selectedBookings: Set<String> = []
    @State private var showBulkActions: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var clientNames: [String: String] = [:]
    @State private var sitterNames: [String: String] = [:]
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case nextWeek = "Next Week"
        case past = "Past"
        case future = "Future"
        
        var id: String { rawValue }
        
        var dateRange: (start: Date, end: Date) {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .all:
                return (Date.distantPast, Date.distantFuture)
            case .today:
                let start = calendar.startOfDay(for: now)
                let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
                return (start, end)
            case .thisWeek:
                let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? now
                return (start, end)
            case .thisMonth:
                let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let end = calendar.date(byAdding: .month, value: 1, to: start) ?? now
                return (start, end)
            case .nextWeek:
                let start = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
                let end = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? start
                return (weekStart, end)
            case .past:
                return (Date.distantPast, now)
            case .future:
                return (now, Date.distantFuture)
            }
        }
    }
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case dateAscending = "Date ↑"
        case dateDescending = "Date ↓"
        case statusAscending = "Status ↑"
        case statusDescending = "Status ↓"
        case clientAscending = "Client ↑"
        case clientDescending = "Client ↓"
        case priceAscending = "Price ↑"
        case priceDescending = "Price ↓"
        
        var id: String { rawValue }
    }
    
    private var filteredAndSortedBookings: [ServiceBooking] {
        var bookings = serviceBookings.allBookings
        
        // Apply timeframe filter
        let dateRange = selectedTimeframe.dateRange
        bookings = bookings.filter { booking in
            let endDate = booking.scheduledDate.addingTimeInterval(TimeInterval(booking.duration * 60))
            return booking.scheduledDate >= dateRange.start && endDate <= dateRange.end
        }
        
        // Apply status filter
        if let selectedStatus = selectedStatus {
            bookings = bookings.filter { $0.status == selectedStatus }
        }
        
        // Apply sitter filter
        if let selectedSitter = selectedSitter {
            bookings = bookings.filter { $0.sitterId == selectedSitter }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            bookings = bookings.filter { booking in
                let clientName = clientNames[booking.clientId] ?? booking.clientId
                let sitterName = sitterNames[booking.sitterId ?? ""] ?? booking.sitterName ?? ""
                
                return booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
                       clientName.localizedCaseInsensitiveContains(searchText) ||
                       sitterName.localizedCaseInsensitiveContains(searchText) ||
                       booking.pets.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ||
                       (booking.address?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       booking.id.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        bookings.sort { booking1, booking2 in
            switch sortOrder {
            case .dateAscending:
                return booking1.scheduledDate < booking2.scheduledDate
            case .dateDescending:
                return booking1.scheduledDate > booking2.scheduledDate
            case .statusAscending:
                return booking1.status.rawValue < booking2.status.rawValue
            case .statusDescending:
                return booking1.status.rawValue > booking2.status.rawValue
            case .clientAscending:
                let name1 = clientNames[booking1.clientId] ?? booking1.clientId
                let name2 = clientNames[booking2.clientId] ?? booking2.clientId
                return name1 < name2
            case .clientDescending:
                let name1 = clientNames[booking1.clientId] ?? booking1.clientId
                let name2 = clientNames[booking2.clientId] ?? booking2.clientId
                return name1 > name2
            case .priceAscending:
                let price1 = Double(booking1.price.replacingOccurrences(of: "$", with: "")) ?? 0
                let price2 = Double(booking2.price.replacingOccurrences(of: "$", with: "")) ?? 0
                return price1 < price2
            case .priceDescending:
                let price1 = Double(booking1.price.replacingOccurrences(of: "$", with: "")) ?? 0
                let price2 = Double(booking2.price.replacingOccurrences(of: "$", with: "")) ?? 0
                return price1 > price2
            }
        }
        
        return bookings
    }
    
    private var hasSelectedBookings: Bool {
        !selectedBookings.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with search and actions
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search bookings...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // Filter controls
                    if showFilters {
                        FilterControlsView(
                            selectedTimeframe: $selectedTimeframe,
                            selectedStatus: $selectedStatus,
                            selectedSitter: $selectedSitter,
                            sortOrder: $sortOrder,
                            sitterNames: sitterNames
                        )
                        .padding(.horizontal)
                    }
                    
                    // Quick stats and actions
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(filteredAndSortedBookings.count) booking\(filteredAndSortedBookings.count == 1 ? "" : "s")")
                                .font(.headline)
                            Text(selectedTimeframe.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: { showFilters.toggle() }) {
                                Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .foregroundColor(.blue)
                            }
                            
                            if hasSelectedBookings {
                                Button(action: { showBulkActions.toggle() }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Button(action: { showExportSheet.toggle() }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Selection mode indicator
                if hasSelectedBookings {
                    HStack {
                        Text("\(selectedBookings.count) selected")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                        Button("Clear Selection") {
                            selectedBookings.removeAll()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                }
                
                // Bookings list
                if filteredAndSortedBookings.isEmpty {
                    SPEmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: "No Bookings Found",
                        message: searchText.isEmpty ? "No bookings match your current filters." : "Try adjusting your search or filters.",
                        actionTitle: nil,
                        action: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredAndSortedBookings) { booking in
                            EnhancedBookingCard(
                                booking: booking,
                                clientName: clientNames[booking.clientId],
                                sitterName: sitterNames[booking.sitterId ?? ""] ?? booking.sitterName,
                                isSelected: selectedBookings.contains(booking.id),
                                onSelectionToggle: {
                                    if selectedBookings.contains(booking.id) {
                                        selectedBookings.remove(booking.id)
                                    } else {
                                        selectedBookings.insert(booking.id)
                                    }
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Booking Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        refreshData()
                    }
                }
            }
        }
        .sheet(isPresented: $showBulkActions) {
            BulkActionsSheet(
                selectedBookings: selectedBookings,
                allBookings: serviceBookings.allBookings,
                onActionCompleted: {
                    selectedBookings.removeAll()
                    showBulkActions = false
                }
            )
        }
        .sheet(isPresented: $showExportSheet) {
            ExportBookingsSheet(bookings: filteredAndSortedBookings)
        }
        .onAppear {
            loadData()
        }
        .onReceive(serviceBookings.$allBookings) { _ in
            resolveMissingNames()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func loadData() {
        isLoading = true
        serviceBookings.listenToAllBookings()
        resolveMissingNames()
        isLoading = false
    }
    
    private func refreshData() {
        loadData()
    }
    
    private func resolveMissingNames() {
        // Resolve client names
        let clientIds = Set(serviceBookings.allBookings.map { $0.clientId }).subtracting(clientNames.keys)
        if !clientIds.isEmpty {
            resolveClientNames(clientIds)
        }
        
        // Resolve sitter names
        let sitterIds = Set(serviceBookings.allBookings.compactMap { $0.sitterId }).subtracting(sitterNames.keys)
        if !sitterIds.isEmpty {
            resolveSitterNames(sitterIds)
        }
    }
    
    private func resolveClientNames(_ clientIds: Set<String>) {
        let db = Firestore.firestore()
        for uid in clientIds {
            db.collection("users").document(uid).getDocument { doc, error in
                if let error = error {
                    AppLogger.ui.error("Failed to fetch client name: \(error.localizedDescription)")
                    return
                }
                
                let data = doc?.data() ?? [:]
                let email = (data["email"] as? String) ?? ""
                let emailFallback = email.split(separator: "@").first.map(String.init) ?? "Unnamed"
                let rawName = (data["displayName"] as? String) ?? (data["name"] as? String) ?? ""
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emailFallback : rawName
                
                DispatchQueue.main.async {
                    self.clientNames[uid] = name
                }
            }
        }
    }
    
    private func resolveSitterNames(_ sitterIds: Set<String>) {
        let db = Firestore.firestore()
        for uid in sitterIds {
            db.collection("users").document(uid).getDocument { doc, error in
                if let error = error {
                    AppLogger.ui.error("Failed to fetch sitter name: \(error.localizedDescription)")
                    return
                }
                
                let data = doc?.data() ?? [:]
                let email = (data["email"] as? String) ?? ""
                let emailFallback = email.split(separator: "@").first.map(String.init) ?? "Unnamed"
                let rawName = (data["displayName"] as? String) ?? (data["name"] as? String) ?? ""
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emailFallback : rawName
                
                DispatchQueue.main.async {
                    self.sitterNames[uid] = name
                }
            }
        }
    }
}

// MARK: - Filter Controls View
private struct FilterControlsView: View {
    @Binding var selectedTimeframe: AdminBookingManagementView.Timeframe
    @Binding var selectedStatus: ServiceBooking.BookingStatus?
    @Binding var selectedSitter: String?
    @Binding var sortOrder: AdminBookingManagementView.SortOrder
    let sitterNames: [String: String]
    
    var body: some View {
        VStack(spacing: 12) {
            // Timeframe picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AdminBookingManagementView.Timeframe.allCases) { timeframe in
                        FilterChip(
                            title: timeframe.rawValue,
                            isSelected: selectedTimeframe == timeframe,
                            action: { selectedTimeframe = timeframe }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Status filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All Status",
                        isSelected: selectedStatus == nil,
                        action: { selectedStatus = nil }
                    )
                    
                    ForEach(ServiceBooking.BookingStatus.allCases, id: \.rawValue) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: selectedStatus == status,
                            color: status.color,
                            action: { selectedStatus = status }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Sitter filter
            if !sitterNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All Sitters",
                            isSelected: selectedSitter == nil,
                            action: { selectedSitter = nil }
                        )
                        
                        ForEach(Array(sitterNames.keys.sorted()), id: \.self) { sitterId in
                            FilterChip(
                                title: sitterNames[sitterId] ?? "Unknown",
                                isSelected: selectedSitter == sitterId,
                                action: { selectedSitter = sitterId }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Sort order
            HStack {
                Text("Sort by:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Sort Order", selection: $sortOrder) {
                    ForEach(AdminBookingManagementView.SortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

// MARK: - Filter Chip Component
private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
                )
                .foregroundColor(isSelected ? color : .primary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
    }
}



#Preview {
    AdminBookingManagementView(serviceBookings: ServiceBookingDataService())
}
