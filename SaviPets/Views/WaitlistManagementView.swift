import SwiftUI
import OSLog

struct WaitlistManagementView: View {
    @StateObject private var waitlistService = WaitlistService()
    @State private var selectedFilter: WaitlistFilter = .all
    @State private var searchText: String = ""
    @State private var showAddEntrySheet: Bool = false
    @State private var selectedEntry: WaitlistEntry?
    @State private var showEntryDetails: Bool = false
    
    enum WaitlistFilter: String, CaseIterable {
        case all = "All"
        case waiting = "Waiting"
        case promoted = "Promoted"
        case cancelled = "Cancelled"
        
        var status: WaitlistStatus? {
            switch self {
            case .all: return nil
            case .waiting: return .waiting
            case .promoted: return .promoted
            case .cancelled: return .cancelled
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with filters and search
                WaitlistHeaderView(
                    selectedFilter: $selectedFilter,
                    searchText: $searchText,
                    onAddEntry: { showAddEntrySheet = true }
                )
                
                // Waitlist entries list
                if filteredEntries.isEmpty {
                    EmptyWaitlistView(hasFilters: hasActiveFilters)
                } else {
                    WaitlistEntriesListView(
                        entries: filteredEntries,
                        onEntryTap: { entry in
                            selectedEntry = entry
                            showEntryDetails = true
                        },
                        onRemoveEntry: { entry in
                            Task {
                                _ = await waitlistService.removeFromWaitlist(entry.id)
                            }
                        }
                    )
                }
            }
            .navigationTitle("Waitlist Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Entry") {
                        showAddEntrySheet = true
                    }
                }
            }
            .sheet(isPresented: $showAddEntrySheet) {
                AddWaitlistEntrySheet(waitlistService: waitlistService)
            }
            .sheet(item: $selectedEntry) { entry in
                WaitlistEntryDetailsSheet(
                    entry: entry,
                    waitlistService: waitlistService
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    private var filteredEntries: [WaitlistEntry] {
        var entries = waitlistService.waitlistEntries
        
        // Apply status filter
        if let status = selectedFilter.status {
            entries = entries.filter { $0.status == status }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.clientName.localizedCaseInsensitiveContains(searchText) ||
                entry.serviceType.localizedCaseInsensitiveContains(searchText) ||
                entry.clientEmail.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by priority and creation time
        return entries.sorted { entry1, entry2 in
            if entry1.priority != entry2.priority {
                return entry1.priority > entry2.priority
            }
            return entry1.createdAt < entry2.createdAt
        }
    }
    
    private var hasActiveFilters: Bool {
        return selectedFilter != .all || !searchText.isEmpty
    }
}

// MARK: - Waitlist Header
private struct WaitlistHeaderView: View {
    @Binding var selectedFilter: WaitlistManagementView.WaitlistFilter
    @Binding var searchText: String
    let onAddEntry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search waitlist...", text: $searchText)
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WaitlistManagementView.WaitlistFilter.allCases, id: \.rawValue) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            onTap: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Quick actions
            HStack(spacing: 12) {
                Button(action: onAddEntry) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Entry")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                if !searchText.isEmpty || selectedFilter != .all {
                    Button("Clear Filters") {
                        selectedFilter = .all
                        searchText = ""
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
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

// MARK: - Waitlist Entries List
private struct WaitlistEntriesListView: View {
    let entries: [WaitlistEntry]
    let onEntryTap: (WaitlistEntry) -> Void
    let onRemoveEntry: (WaitlistEntry) -> Void
    
    var body: some View {
        List {
            ForEach(entries) { entry in
                WaitlistEntryRow(
                    entry: entry,
                    onTap: { onEntryTap(entry) },
                    onRemove: { onRemoveEntry(entry) }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
    }
}

private struct WaitlistEntryRow: View {
    let entry: WaitlistEntry
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var showingRemoveAlert: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Priority indicator
                VStack {
                    Text("\(entry.priority)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(priorityColor)
                        .clipShape(Circle())
                    
                    Text("PRIORITY")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Entry details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.clientName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        WaitlistStatusBadge(status: entry.status)
                    }
                    
                    Text(entry.serviceType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(entry.requestedDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("at \(entry.requestedTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(entry.duration) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if entry.status == .waiting {
                        HStack {
                            Text("Position: \(positionText)")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Text("Est. Wait: \(estimatedWaitText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Action button
                Button(action: { showingRemoveAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Remove from Waitlist", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Are you sure you want to remove \(entry.clientName) from the waitlist?")
        }
    }
    
    private var priorityColor: Color {
        switch entry.priority {
        case 90...100: return .red
        case 75...89: return .orange
        case 50...74: return .yellow
        default: return .blue
        }
    }
    
    private var positionText: String {
        // This would be calculated based on other entries
        return "1st"
    }
    
    private var estimatedWaitText: String {
        let hours = Int(entry.estimatedWaitTime / 3600)
        if hours < 1 {
            return "< 1h"
        } else if hours < 24 {
            return "\(hours)h"
        } else {
            let days = hours / 24
            return "\(days)d"
        }
    }
}

// MARK: - Empty State
private struct EmptyWaitlistView: View {
    let hasFilters: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(hasFilters ? "No Matching Entries" : "No Waitlist Entries")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(hasFilters ? 
                 "Try adjusting your search or filters to find waitlist entries." :
                 "Waitlist entries will appear here when clients request unavailable time slots.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Add Waitlist Entry Sheet
private struct AddWaitlistEntrySheet: View {
    let waitlistService: WaitlistService
    @Environment(\.dismiss) private var dismiss
    
    @State private var clientName: String = ""
    @State private var clientEmail: String = ""
    @State private var clientPhone: String = ""
    @State private var serviceType: String = "Dog Walking"
    @State private var requestedDate: Date = Date()
    @State private var requestedTime: String = "10:00 AM"
    @State private var duration: Int = 30
    @State private var pets: [String] = []
    @State private var specialInstructions: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var newPetName: String = ""
    
    private let serviceTypes = ["Dog Walking", "Pet Sitting", "Grooming", "Training"]
    private let timeSlots = ["8:00 AM", "9:00 AM", "10:00 AM", "11:00 AM", "12:00 PM", "1:00 PM", "2:00 PM", "3:00 PM", "4:00 PM", "5:00 PM", "6:00 PM", "7:00 PM"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Client Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Client Information")
                            .font(.headline)
                        
                        TextField("Client Name", text: $clientName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Email", text: $clientEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                        
                        TextField("Phone (Optional)", text: $clientPhone)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.phonePad)
                    }
                    
                    // Service Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service Details")
                            .font(.headline)
                        
                        Picker("Service Type", selection: $serviceType) {
                            ForEach(serviceTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        DatePicker("Requested Date", selection: $requestedDate, displayedComponents: .date)
                        
                        Picker("Requested Time", selection: $requestedTime) {
                            ForEach(timeSlots, id: \.self) { time in
                                Text(time).tag(time)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        HStack {
                            Text("Duration: \(duration) minutes")
                            Spacer()
                            Stepper("", value: $duration, in: 15...180, step: 15)
                        }
                    }
                    
                    // Pets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pets")
                            .font(.headline)
                        
                        HStack {
                            TextField("Pet Name", text: $newPetName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Add") {
                                if !newPetName.isEmpty {
                                    pets.append(newPetName)
                                    newPetName = ""
                                }
                            }
                        }
                        
                        if !pets.isEmpty {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(pets, id: \.self) { pet in
                                    HStack {
                                        Text(pet)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            pets.removeAll { $0 == pet }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Special Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Special Instructions")
                            .font(.headline)
                        
                        TextField("Any special requirements...", text: $specialInstructions, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Waitlist Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addToWaitlist()
                    }
                    .disabled(!canAddToWaitlist || isProcessing)
                }
            }
        }
    }
    
    private var canAddToWaitlist: Bool {
        return !clientName.isEmpty &&
               !clientEmail.isEmpty &&
               !serviceType.isEmpty &&
               !pets.isEmpty
    }
    
    private func addToWaitlist() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            let result = await waitlistService.addToWaitlist(
                serviceType: serviceType,
                requestedDate: requestedDate,
                requestedTime: requestedTime,
                duration: duration,
                pets: pets,
                specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions,
                clientId: "temp_client_id", // This would come from auth
                clientName: clientName,
                clientPhone: clientPhone.isEmpty ? nil : clientPhone,
                clientEmail: clientEmail
            )
            
            await MainActor.run {
                isProcessing = false
                
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Waitlist Entry Details Sheet
private struct WaitlistEntryDetailsSheet: View {
    let entry: WaitlistEntry
    let waitlistService: WaitlistService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingRemoveAlert: Bool = false
    @State private var isProcessing: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status and Priority
                    HStack {
                        WaitlistStatusBadge(status: entry.status)
                        
                        Spacer()
                        
                        VStack {
                            Text("\(entry.priority)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Priority")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Client Information
                    DetailSection(title: "Client Information") {
                        DetailRow(label: "Name", value: entry.clientName)
                        DetailRow(label: "Email", value: entry.clientEmail)
                        if let phone = entry.clientPhone {
                            DetailRow(label: "Phone", value: phone)
                        }
                    }
                    
                    // Service Details
                    DetailSection(title: "Service Details") {
                        DetailRow(label: "Service Type", value: entry.serviceType)
                        DetailRow(label: "Date", value: entry.requestedDate.formatted(date: .complete, time: .omitted))
                        DetailRow(label: "Time", value: entry.requestedTime)
                        DetailRow(label: "Duration", value: "\(entry.duration) minutes")
                        DetailRow(label: "Pets", value: entry.pets.joined(separator: ", "))
                    }
                    
                    // Wait Information
                    if entry.status == .waiting {
                        DetailSection(title: "Wait Information") {
                            DetailRow(label: "Estimated Wait", value: formatWaitTime(entry.estimatedWaitTime))
                            DetailRow(label: "Added to Waitlist", value: entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                            DetailRow(label: "Contact Preferences", value: formatContactPreferences(entry.contactPreferences))
                        }
                    }
                    
                    // Special Instructions
                    if let instructions = entry.specialInstructions, !instructions.isEmpty {
                        DetailSection(title: "Special Instructions") {
                            Text(instructions)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Actions
                    if entry.status == .waiting {
                        VStack(spacing: 12) {
                            Button("Promote to Booking") {
                                promoteToBooking()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            
                            Button("Remove from Waitlist") {
                                showingRemoveAlert = true
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Waitlist Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Remove from Waitlist", isPresented: $showingRemoveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    removeFromWaitlist()
                }
            } message: {
                Text("Are you sure you want to remove this entry from the waitlist?")
            }
        }
    }
    
    private func promoteToBooking() {
        isProcessing = true
        
        Task {
            // This would create a booking from the waitlist entry
            await waitlistService.processWaitlistForTimeSlot(
                serviceType: entry.serviceType,
                date: entry.requestedDate,
                time: entry.requestedTime
            )
            
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        }
    }
    
    private func removeFromWaitlist() {
        isProcessing = true
        
        Task {
            _ = await waitlistService.removeFromWaitlist(entry.id)
            
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        }
    }
    
    private func formatWaitTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval / 3600)
        if hours < 1 {
            return "Less than 1 hour"
        } else if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        }
    }
    
    private func formatContactPreferences(_ preferences: ContactPreferences) -> String {
        var methods: [String] = []
        if preferences.email { methods.append("Email") }
        if preferences.phone { methods.append("Phone") }
        if preferences.push { methods.append("Push") }
        return methods.joined(separator: ", ")
    }
}

// MARK: - Supporting Views
private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Waitlist Status Badge
private struct WaitlistStatusBadge: View {
    let status: WaitlistStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    WaitlistManagementView()
}
