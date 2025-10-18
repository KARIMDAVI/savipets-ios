# Enhanced Booking System Implementation Plan

## 🎯 **Immediate Implementation Priorities**

Based on the current SaviPets codebase analysis, here are the specific enhancements we can implement immediately:

---

## **1. Rescheduling System Implementation**

### **Step 1: Extend Booking Model**
```swift
// Add to ServiceBooking.swift
struct ServiceBooking: Identifiable {
    // ... existing properties ...
    
    // NEW: Rescheduling support
    let rescheduledFrom: Date?           // Original date if rescheduled
    let rescheduledAt: Date?             // When it was rescheduled
    let rescheduledBy: String?           // Who rescheduled it
    let rescheduleReason: String?        // Reason for rescheduling
    let rescheduleHistory: [RescheduleEntry] // Full history
    
    // NEW: Enhanced status tracking
    let lastModified: Date
    let lastModifiedBy: String
    let modificationReason: String?
}

struct RescheduleEntry {
    let originalDate: Date
    let newDate: Date
    let reason: String
    let requestedBy: String
    let requestedAt: Date
    let approvedBy: String?
    let approvedAt: Date?
}

enum BookingModificationType: String {
    case created = "created"
    case rescheduled = "rescheduled"
    case cancelled = "cancelled"
    case approved = "approved"
    case assigned = "assigned"
}
```

### **Step 2: Rescheduling Service Methods**
```swift
// Add to ServiceBookingDataService.swift
extension ServiceBookingDataService {
    
    /// Reschedule a booking to a new date/time
    func rescheduleBooking(
        bookingId: String,
        newDate: Date,
        reason: String,
        requestedBy: String
    ) async throws -> Bool {
        
        let bookingRef = db.collection("serviceBookings").document(bookingId)
        
        // Check if rescheduling is allowed
        let booking = try await getBooking(bookingId: bookingId)
        let hoursUntilVisit = booking.scheduledDate.timeIntervalSince(Date()) / 3600
        
        // Business rules: Can't reschedule within 2 hours of visit
        if hoursUntilVisit < 2 {
            throw BookingError.rescheduleTooLate
        }
        
        // Check for sitter conflicts
        if let sitterId = booking.sitterId {
            let hasConflict = try await checkSitterConflict(
                sitterId: sitterId,
                newDate: newDate,
                duration: booking.duration,
                excludeBookingId: bookingId
            )
            
            if hasConflict {
                throw BookingError.sitterConflict
            }
        }
        
        // Update booking with reschedule information
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let newScheduledTime = timeFormatter.string(from: newDate)
        
        let updateData: [String: Any] = [
            "scheduledDate": Timestamp(date: newDate),
            "scheduledTime": newScheduledTime,
            "rescheduledFrom": Timestamp(date: booking.scheduledDate),
            "rescheduledAt": FieldValue.serverTimestamp(),
            "rescheduledBy": requestedBy,
            "rescheduleReason": reason,
            "lastModified": FieldValue.serverTimestamp(),
            "lastModifiedBy": requestedBy,
            "modificationReason": "Rescheduled: \(reason)",
            "status": booking.status.rawValue // Keep same status
        ]
        
        try await bookingRef.updateData(updateData)
        
        // Send notifications
        await sendRescheduleNotifications(
            booking: booking,
            newDate: newDate,
            reason: reason
        )
        
        return true
    }
    
    /// Check if sitter has conflicts at new time
    private func checkSitterConflict(
        sitterId: String,
        newDate: Date,
        duration: Int,
        excludeBookingId: String
    ) async throws -> Bool {
        
        let startTime = newDate
        let endTime = newDate.addingTimeInterval(TimeInterval(duration * 60))
        
        let conflictQuery = db.collection("serviceBookings")
            .whereField("sitterId", isEqualTo: sitterId)
            .whereField("status", in: ["approved", "in_adventure"])
            .whereField("scheduledDate", isGreaterThan: Timestamp(date: startTime.addingTimeInterval(-3600)))
            .whereField("scheduledDate", isLessThan: Timestamp(date: endTime.addingTimeInterval(3600)))
        
        let snapshot = try await conflictQuery.getDocuments()
        
        for doc in snapshot.documents {
            if doc.documentID != excludeBookingId {
                let data = doc.data()
                let existingDate = (data["scheduledDate"] as? Timestamp)?.dateValue() ?? Date()
                let existingDuration = data["duration"] as? Int ?? 0
                let existingEnd = existingDate.addingTimeInterval(TimeInterval(existingDuration * 60))
                
                // Check for time overlap
                if (startTime < existingEnd && endTime > existingDate) {
                    return true // Conflict found
                }
            }
        }
        
        return false // No conflicts
    }
}

enum BookingError: Error, LocalizedError {
    case rescheduleTooLate
    case sitterConflict
    case bookingNotFound
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .rescheduleTooLate:
            return "Cannot reschedule within 2 hours of scheduled visit"
        case .sitterConflict:
            return "Sitter is not available at the requested time"
        case .bookingNotFound:
            return "Booking not found"
        case .insufficientPermissions:
            return "You don't have permission to modify this booking"
        }
    }
}
```

---

## **2. Enhanced Admin Dashboard**

### **Step 1: Advanced Booking Management View**
```swift
// Create new file: AdminBookingManagementView.swift
struct AdminBookingManagementView: View {
    @ObservedObject var serviceBookings: ServiceBookingDataService
    @State private var selectedBookings: Set<String> = []
    @State private var searchText: String = ""
    @State private var selectedStatus: ServiceBooking.BookingStatus? = nil
    @State private var selectedDateRange: DateRange = .today
    @State private var showRescheduleSheet: Bool = false
    @State private var showBulkActions: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Bulk Actions Bar (when selections made)
                if !selectedBookings.isEmpty {
                    bulkActionsBar
                }
                
                // Bookings List
                bookingsList
            }
            .navigationTitle("Booking Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportBookings()
                    }
                }
            }
        }
        .sheet(isPresented: $showRescheduleSheet) {
            RescheduleBookingSheet(
                bookingIds: Array(selectedBookings),
                onReschedule: { newDate, reason in
                    Task {
                        await bulkReschedule(newDate: newDate, reason: reason)
                    }
                }
            )
        }
    }
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search bookings...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Filter Controls
            HStack(spacing: 12) {
                // Status Filter
                Picker("Status", selection: $selectedStatus) {
                    Text("All").tag(nil as ServiceBooking.BookingStatus?)
                    ForEach(ServiceBooking.BookingStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status as ServiceBooking.BookingStatus?)
                    }
                }
                .pickerStyle(.menu)
                
                // Date Range Filter
                Picker("Date Range", selection: $selectedDateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                // Clear Filters
                Button("Clear") {
                    selectedStatus = nil
                    selectedDateRange = .today
                    searchText = ""
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var bulkActionsBar: some View {
        HStack {
            Text("\(selectedBookings.count) selected")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Reschedule") {
                    showRescheduleSheet = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Assign Sitter") {
                    // Show sitter assignment sheet
                }
                .buttonStyle(.bordered)
                
                Button("Cancel") {
                    // Show bulk cancellation sheet
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }
    
    private var bookingsList: some View {
        List {
            ForEach(filteredBookings) { booking in
                EnhancedBookingCard(
                    booking: booking,
                    isSelected: selectedBookings.contains(booking.id),
                    onSelect: { toggleSelection(booking.id) },
                    onReschedule: { showRescheduleSheet = true },
                    onCancel: { cancelBooking(booking.id) }
                )
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Filtering Logic
    private var filteredBookings: [ServiceBooking] {
        var bookings = serviceBookings.allBookings
        
        // Apply status filter
        if let status = selectedStatus {
            bookings = bookings.filter { $0.status == status }
        }
        
        // Apply date range filter
        bookings = bookings.filter { booking in
            selectedDateRange.contains(booking.scheduledDate)
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            bookings = bookings.filter { booking in
                booking.serviceType.localizedCaseInsensitiveContains(searchText) ||
                booking.clientId.localizedCaseInsensitiveContains(searchText) ||
                (booking.sitterName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return bookings.sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    // MARK: - Actions
    private func toggleSelection(_ bookingId: String) {
        if selectedBookings.contains(bookingId) {
            selectedBookings.remove(bookingId)
        } else {
            selectedBookings.insert(bookingId)
        }
    }
    
    private func bulkReschedule(newDate: Date, reason: String) async {
        for bookingId in selectedBookings {
            do {
                try await serviceBookings.rescheduleBooking(
                    bookingId: bookingId,
                    newDate: newDate,
                    reason: reason,
                    requestedBy: "admin"
                )
            } catch {
                AppLogger.ui.error("Failed to reschedule booking \(bookingId): \(error)")
            }
        }
        selectedBookings.removeAll()
    }
    
    private func exportBookings() {
        // Implementation for CSV export
        let csvData = generateCSV(from: filteredBookings)
        // Share or save CSV data
    }
}

enum DateRange: String, CaseIterable {
    case today = "today"
    case tomorrow = "tomorrow"
    case thisWeek = "thisWeek"
    case nextWeek = "nextWeek"
    case thisMonth = "thisMonth"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeek: return "This Week"
        case .nextWeek: return "Next Week"
        case .thisMonth: return "This Month"
        case .custom: return "Custom Range"
        }
    }
    
    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.isDate(date, inSameDayAs: tomorrow)
        case .thisWeek:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .nextWeek:
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            return calendar.isDate(date, equalTo: nextWeek, toGranularity: .weekOfYear)
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .custom:
            return true // Custom range would be handled separately
        }
    }
}
```

### **Step 2: Enhanced Booking Card Component**
```swift
// Create new file: EnhancedBookingCard.swift
struct EnhancedBookingCard: View {
    let booking: ServiceBooking
    let isSelected: Bool
    let onSelect: () -> Void
    let onReschedule: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDetails: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with selection and status
            HStack {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.serviceType)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(booking.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                        Text("at \(booking.scheduledTime)")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                
                Spacer()
                
                // Status badge
                StatusBadge(status: booking.status)
                
                // Quick actions menu
                Menu {
                    Button("View Details") {
                        showingDetails = true
                    }
                    
                    Button("Reschedule") {
                        onReschedule()
                    }
                    
                    Button("Cancel", role: .destructive) {
                        onCancel()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            // Client and Sitter info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Client: \(booking.clientId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let sitterName = booking.sitterName {
                        Text("Sitter: \(sitterName)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("No sitter assigned")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                // Price
                Text("$\(booking.price)")
                    .font(.headline)
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
            }
            
            // Reschedule indicator
            if booking.rescheduledFrom != nil {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Rescheduled from \(booking.rescheduledFrom?.formatted(date: .abbreviated, time: .omitted) ?? "unknown")")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .sheet(isPresented: $showingDetails) {
            BookingDetailsSheet(booking: booking)
        }
    }
}

struct StatusBadge: View {
    let status: ServiceBooking.BookingStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}
```

---

## **3. Quick Implementation Steps**

### **Step 1: Update AdminDashboardView**
```swift
// Replace existing AdminBookingsView with enhanced version
AdminBookingManagementView(serviceBookings: serviceBookings)
    .tabItem { Label("Bookings", systemImage: "calendar") }
```

### **Step 2: Add Reschedule Button to Existing Booking Cards**
```swift
// In existing AdminBookingFullCard, add reschedule button
HStack(spacing: 12) {
    Button("Reschedule") {
        // Show reschedule sheet
    }
    .buttonStyle(.bordered)
    
    Button("Cancel") {
        // Show cancellation confirmation
    }
    .buttonStyle(.bordered)
    .foregroundColor(.red)
}
```

### **Step 3: Implement Basic Rescheduling UI**
```swift
// Create RescheduleBookingSheet.swift
struct RescheduleBookingSheet: View {
    let bookingIds: [String]
    let onReschedule: (Date, String) -> Void
    
    @State private var newDate: Date = Date()
    @State private var reason: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Reschedule \(bookingIds.count) booking(s)")
                    .font(.headline)
                
                DatePicker("New Date & Time", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                
                TextField("Reason for rescheduling", text: $reason, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Reschedule Bookings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reschedule") {
                        onReschedule(newDate, reason)
                        dismiss()
                    }
                    .disabled(reason.isEmpty)
                }
            }
        }
    }
}
```

---

## **4. Database Schema Updates**

### **Add to Firestore Rules**
```javascript
// Update firestore.rules
match /serviceBookings/{bookingId} {
  allow create: if isSignedIn() && request.resource.data.clientId == request.auth.uid;
  
  allow read: if isSignedIn() && (
    resource.data.clientId == request.auth.uid || 
    resource.data.sitterId == request.auth.uid || 
    isAdmin()
  );
  
  allow update: if isAdmin() 
              // Client can reschedule their own bookings (with restrictions)
              || (isSignedIn() 
                  && resource.data.clientId == request.auth.uid 
                  && request.resource.data.rescheduledBy == request.auth.uid
                  && 'rescheduledFrom' in request.resource.data.keys())
              // Client can cancel their own bookings
              || (isSignedIn() 
                  && resource.data.clientId == request.auth.uid 
                  && request.resource.data.status == "cancelled")
              // Sitters can update status/timeline
              || (isSignedIn() 
                  && resource.data.sitterId == request.auth.uid);
}
```

---

## **5. Testing Checklist**

### **Rescheduling Tests**
- [ ] Client can reschedule their own booking
- [ ] Admin can reschedule any booking
- [ ] Cannot reschedule within 2 hours of visit
- [ ] Conflict detection works correctly
- [ ] Notifications sent to all parties
- [ ] Reschedule history is maintained

### **Admin Dashboard Tests**
- [ ] Search functionality works
- [ ] Filtering by status works
- [ ] Date range filtering works
- [ ] Bulk selection works
- [ ] Bulk operations work
- [ ] Export functionality works

### **UI/UX Tests**
- [ ] Mobile responsiveness
- [ ] Accessibility compliance
- [ ] Loading states
- [ ] Error handling
- [ ] Success feedback

---

## **6. Performance Considerations**

### **Database Optimization**
```swift
// Add composite indexes for common queries
// In firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "serviceBookings",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "sitterId", "order": "ASCENDING" },
        { "fieldPath": "scheduledDate", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "serviceBookings", 
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "clientId", "order": "ASCENDING" },
        { "fieldPath": "scheduledDate", "order": "DESCENDING" }
      ]
    }
  ]
}
```

### **Caching Strategy**
```swift
// Implement local caching for frequently accessed data
class BookingCache {
    private var cache: [String: ServiceBooking] = [:]
    private let cacheExpiry: TimeInterval = 300 // 5 minutes
    
    func get(bookingId: String) -> ServiceBooking? {
        // Return cached booking if not expired
    }
    
    func set(_ booking: ServiceBooking) {
        cache[booking.id] = booking
    }
    
    func invalidate(bookingId: String) {
        cache.removeValue(forKey: bookingId)
    }
}
```

This implementation plan provides a solid foundation for enhancing the SaviPets booking system with immediate, practical improvements that can be implemented incrementally while maintaining system stability.
