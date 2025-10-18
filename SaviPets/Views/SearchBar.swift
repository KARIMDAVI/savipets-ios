import SwiftUI

/// Reusable search bar component
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    var onClear: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onClear: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onClear = onClear
    }
    
    var body: some View {
        HStack(spacing: SPDesignSystem.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SPDesignSystem.Spacing.m)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? SPDesignSystem.Colors.primaryAdjusted(colorScheme) : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Filter Button Component

struct FilterButton: View {
    let activeFilters: Int
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 16, weight: .medium))
                
                if activeFilters > 0 {
                    Text("\(activeFilters)")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .foregroundColor(SPDesignSystem.Colors.dark)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
            .padding(.vertical, SPDesignSystem.Spacing.s)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Sheet Component

struct FilterOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
    
    static func == (lhs: FilterOption, rhs: FilterOption) -> Bool {
        lhs.value == rhs.value
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

struct FilterSheet: View {
    @Binding var selectedStatuses: Set<String>
    @Binding var selectedServiceTypes: Set<String>
    @Binding var dateRange: ClosedRange<Date>?
    
    let statusOptions: [FilterOption]
    let serviceTypeOptions: [FilterOption]
    let showDateFilter: Bool
    let onApply: () -> Void
    let onReset: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var tempStatuses: Set<String>
    @State private var tempServiceTypes: Set<String>
    @State private var tempDateRange: ClosedRange<Date>?
    @State private var showDatePicker = false
    
    init(
        selectedStatuses: Binding<Set<String>>,
        selectedServiceTypes: Binding<Set<String>>,
        dateRange: Binding<ClosedRange<Date>?> = .constant(nil),
        statusOptions: [FilterOption] = [],
        serviceTypeOptions: [FilterOption] = [],
        showDateFilter: Bool = false,
        onApply: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self._selectedStatuses = selectedStatuses
        self._selectedServiceTypes = selectedServiceTypes
        self._dateRange = dateRange
        self.statusOptions = statusOptions
        self.serviceTypeOptions = serviceTypeOptions
        self.showDateFilter = showDateFilter
        self.onApply = onApply
        self.onReset = onReset
        
        // Initialize temp state
        _tempStatuses = State(initialValue: selectedStatuses.wrappedValue)
        _tempServiceTypes = State(initialValue: selectedServiceTypes.wrappedValue)
        _tempDateRange = State(initialValue: dateRange.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            List {
                if !statusOptions.isEmpty {
                    Section("Status") {
                        ForEach(statusOptions) { option in
                            Toggle(option.title, isOn: Binding(
                                get: { tempStatuses.contains(option.value) },
                                set: { isSelected in
                                    if isSelected {
                                        tempStatuses.insert(option.value)
                                    } else {
                                        tempStatuses.remove(option.value)
                                    }
                                }
                            ))
                            .tint(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        }
                    }
                }
                
                if !serviceTypeOptions.isEmpty {
                    Section("Service Type") {
                        ForEach(serviceTypeOptions) { option in
                            Toggle(option.title, isOn: Binding(
                                get: { tempServiceTypes.contains(option.value) },
                                set: { isSelected in
                                    if isSelected {
                                        tempServiceTypes.insert(option.value)
                                    } else {
                                        tempServiceTypes.remove(option.value)
                                    }
                                }
                            ))
                            .tint(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        }
                    }
                }
                
                if showDateFilter {
                    Section("Date Range") {
                        Button(action: { showDatePicker.toggle() }) {
                            HStack {
                                Text("Select Date Range")
                                    .foregroundColor(.primary)
                                Spacer()
                                if let range = tempDateRange {
                                    Text("\(formattedDate(range.lowerBound)) - \(formattedDate(range.upperBound))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        if showDatePicker {
                            DatePicker(
                                "Start Date",
                                selection: Binding(
                                    get: { tempDateRange?.lowerBound ?? Date() },
                                    set: { newStart in
                                        let end = tempDateRange?.upperBound ?? newStart
                                        tempDateRange = newStart...end
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            
                            DatePicker(
                                "End Date",
                                selection: Binding(
                                    get: { tempDateRange?.upperBound ?? Date() },
                                    set: { newEnd in
                                        let start = tempDateRange?.lowerBound ?? newEnd
                                        tempDateRange = start...newEnd
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            
                            if tempDateRange != nil {
                                Button("Clear Date Range") {
                                    tempDateRange = nil
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        tempStatuses.removeAll()
                        tempServiceTypes.removeAll()
                        tempDateRange = nil
                        selectedStatuses.removeAll()
                        selectedServiceTypes.removeAll()
                        dateRange = nil
                        onReset()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        selectedStatuses = tempStatuses
                        selectedServiceTypes = tempServiceTypes
                        dateRange = tempDateRange
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Search and Filter Container

struct SearchableList<Content: View>: View {
    @Binding var searchText: String
    let placeholder: String
    let showFilter: Bool
    let activeFilters: Int
    let onFilter: () -> Void
    let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        searchText: Binding<String>,
        placeholder: String = "Search...",
        showFilter: Bool = false,
        activeFilters: Int = 0,
        onFilter: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.showFilter = showFilter
        self.activeFilters = activeFilters
        self.onFilter = onFilter
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar and filter button
            HStack(spacing: SPDesignSystem.Spacing.m) {
                SearchBar(text: $searchText, placeholder: placeholder)
                
                if showFilter {
                    FilterButton(activeFilters: activeFilters, action: onFilter)
                }
            }
            .padding(.horizontal, SPDesignSystem.Spacing.m)
            .padding(.vertical, SPDesignSystem.Spacing.s)
            .background(SPDesignSystem.Colors.background(scheme: colorScheme))
            
            // Content
            content
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        SearchBar(text: .constant("test search"))
            .padding()
        
        FilterButton(activeFilters: 3, action: {})
    }
    .padding()
}
