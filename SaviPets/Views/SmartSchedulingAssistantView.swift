import SwiftUI
import Charts

/// SwiftUI view for displaying and managing AI-powered scheduling suggestions
struct SmartSchedulingAssistantView: View {
    
    // MARK: - Properties
    
    @StateObject private var assistant: SmartSchedulingAssistant
    @State private var selectedSuggestion: SchedulingSuggestion?
    @State private var showingSuggestionDetail = false
    @State private var selectedTimeRange: AnalyticsTimeframe = .last7Days
    @State private var showingFilters = false
    @State private var selectedSuggestionTypes: Set<SuggestionType> = Set(SuggestionType.allCases)
    @State private var selectedImpactLevels: Set<SuggestionImpact> = Set(SuggestionImpact.allCases)
    @State private var showingMetrics = false
    
    // MARK: - Initialization
    
    init(assistant: SmartSchedulingAssistant) {
        self._assistant = StateObject(wrappedValue: assistant)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with metrics
                headerSection
                
                // Filters section
                if showingFilters {
                    filtersSection
                }
                
                // Suggestions list
                suggestionsList
            }
            .navigationTitle("Smart Scheduling")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showingMetrics.toggle() }) {
                            Image(systemName: "chart.bar.fill")
                        }
                        
                        Button(action: { showingFilters.toggle() }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: { Task { await assistant.generateSuggestions() } }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(assistant.isLoading)
                    }
                }
            }
            .sheet(isPresented: $showingSuggestionDetail) {
                if let suggestion = selectedSuggestion {
                    SuggestionDetailView(
                        suggestion: suggestion,
                        onApply: { suggestion in
                            Task {
                                let success = await assistant.applySuggestion(suggestion)
                                if success {
                                    showingSuggestionDetail = false
                                }
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showingMetrics) {
                OptimizationMetricsView(metrics: assistant.optimizationMetrics)
            }
            .task {
                await assistant.generateSuggestions()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            if let metrics = assistant.optimizationMetrics {
                HStack(spacing: 20) {
                    MetricCard(
                        title: "Suggestions",
                        value: "\(metrics.totalSuggestions)",
                        icon: "lightbulb.fill",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Est. Savings",
                        value: "$\(Int(metrics.estimatedSavings))",
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                    
                    MetricCard(
                        title: "Confidence",
                        value: "\(Int(metrics.averageConfidence * 100))%",
                        icon: "checkmark.shield.fill",
                        color: .orange
                    )
                }
                .padding(.horizontal)
            }
            
            if assistant.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing schedule patterns...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            if let errorMessage = assistant.errorMessage {
                ErrorBanner(message: errorMessage)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Filters Section
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filters")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    selectedSuggestionTypes = Set(SuggestionType.allCases)
                    selectedImpactLevels = Set(SuggestionImpact.allCases)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Suggestion type filters
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggestion Types")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(SuggestionType.allCases, id: \.self) { type in
                        FilterChip(
                            title: type.displayName,
                            isSelected: selectedSuggestionTypes.contains(type),
                            icon: type.icon
                        ) {
                            if selectedSuggestionTypes.contains(type) {
                                selectedSuggestionTypes.remove(type)
                            } else {
                                selectedSuggestionTypes.insert(type)
                            }
                        }
                    }
                }
            }
            
            // Impact level filters
            VStack(alignment: .leading, spacing: 8) {
                Text("Impact Levels")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    ForEach(SuggestionImpact.allCases, id: \.self) { impact in
                        FilterChip(
                            title: impact.displayName,
                            isSelected: selectedImpactLevels.contains(impact),
                            color: impact.color
                        ) {
                            if selectedImpactLevels.contains(impact) {
                                selectedImpactLevels.remove(impact)
                            } else {
                                selectedImpactLevels.insert(impact)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Suggestions List
    
    private var suggestionsList: some View {
        List {
            ForEach(filteredSuggestions) { suggestion in
                SuggestionCard(suggestion: suggestion) {
                    selectedSuggestion = suggestion
                    showingSuggestionDetail = true
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            
            if filteredSuggestions.isEmpty && !assistant.isLoading {
                EmptyStateView(
                    title: "No Suggestions Found",
                    message: "Try adjusting your filters or check back later for new suggestions.",
                    systemImage: "lightbulb"
                )
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await assistant.generateSuggestions()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredSuggestions: [SchedulingSuggestion] {
        assistant.suggestions.filter { suggestion in
            selectedSuggestionTypes.contains(suggestion.type) &&
            selectedImpactLevels.contains(suggestion.impact)
        }
        .sorted { suggestion1, suggestion2 in
            // Sort by relevance score, then by impact, then by confidence
            if suggestion1.relevanceScore != suggestion2.relevanceScore {
                return suggestion1.relevanceScore > suggestion2.relevanceScore
            }
            
            let impactOrder: [SuggestionImpact] = [.critical, .high, .medium, .low]
            let impact1Index = impactOrder.firstIndex(of: suggestion1.impact) ?? 0
            let impact2Index = impactOrder.firstIndex(of: suggestion2.impact) ?? 0
            
            if impact1Index != impact2Index {
                return impact1Index < impact2Index
            }
            
            return suggestion1.confidence > suggestion2.confidence
        }
    }
}

// MARK: - Supporting Views

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct SuggestionCard: View {
    let suggestion: SchedulingSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: suggestion.type.icon)
                        .foregroundColor(suggestion.impact.color)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(suggestion.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(suggestion.impact.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(suggestion.impact.color)
                        
                        Text("\(Int(suggestion.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Description
                Text(suggestion.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                // Metrics
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("$\(Int(suggestion.estimatedSavings))")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(suggestion.implementationEffort.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(Int(suggestion.relevanceScore * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let icon: String?
    let color: Color?
    let action: () -> Void
    
    init(
        title: String,
        isSelected: Bool,
        icon: String? = nil,
        color: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? (color ?? .blue) : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detail Views

struct SuggestionDetailView: View {
    let suggestion: SchedulingSuggestion
    let onApply: (SchedulingSuggestion) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isApplying = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: suggestion.type.icon)
                                .font(.title)
                                .foregroundColor(suggestion.impact.color)
                            
                            VStack(alignment: .leading) {
                                Text(suggestion.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(suggestion.type.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Text(suggestion.description)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Metrics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Suggestion Metrics")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            MetricDetailCard(
                                title: "Confidence",
                                value: "\(Int(suggestion.confidence * 100))%",
                                icon: "checkmark.shield.fill",
                                color: .green
                            )
                            
                            MetricDetailCard(
                                title: "Impact",
                                value: suggestion.impact.displayName,
                                icon: "bolt.fill",
                                color: suggestion.impact.color
                            )
                            
                            MetricDetailCard(
                                title: "Est. Savings",
                                value: "$\(Int(suggestion.estimatedSavings))",
                                icon: "dollarsign.circle.fill",
                                color: .blue
                            )
                            
                            MetricDetailCard(
                                title: "Effort",
                                value: suggestion.implementationEffort.displayName,
                                icon: "wrench.fill",
                                color: suggestion.implementationEffort.color
                            )
                        }
                    }
                    
                    // Target Audience
                    if !suggestion.targetAudience.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Target Audience")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(suggestion.targetAudience, id: \.displayName) { audience in
                                    Text(audience.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    // Metadata
                    if !suggestion.metadata.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional Information")
                                .font(.headline)
                            
                            ForEach(Array(suggestion.metadata.keys.sorted()), id: \.self) { key in
                                if let value = suggestion.metadata[key] {
                                    HStack {
                                        Text(key.capitalized)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text(value)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Suggestion Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: applySuggestion) {
                        if isApplying {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Apply")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isApplying)
                }
            }
        }
    }
    
    private func applySuggestion() {
        isApplying = true
        onApply(suggestion)
        isApplying = false
    }
}

struct MetricDetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct OptimizationMetricsView: View {
    let metrics: OptimizationMetrics?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let metrics = metrics {
                        // Overview metrics
                        VStack(spacing: 16) {
                            Text("Optimization Overview")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                                MetricCard(
                                    title: "Total Suggestions",
                                    value: "\(metrics.totalSuggestions)",
                                    icon: "lightbulb.fill",
                                    color: .blue
                                )
                                
                                MetricCard(
                                    title: "Est. Savings",
                                    value: "$\(Int(metrics.estimatedSavings))",
                                    icon: "dollarsign.circle.fill",
                                    color: .green
                                )
                                
                                MetricCard(
                                    title: "Avg. Confidence",
                                    value: "\(Int(metrics.averageConfidence * 100))%",
                                    icon: "checkmark.shield.fill",
                                    color: .orange
                                )
                                
                                MetricCard(
                                    title: "High Impact",
                                    value: "\(metrics.highImpactSuggestions)",
                                    icon: "bolt.fill",
                                    color: .red
                                )
                            }
                        }
                        
                        // Optimization potential chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Optimization Potential")
                                .font(.headline)
                            
                            OptimizationPotentialChart(potential: metrics.optimizationPotential)
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                        
                    } else {
                        EmptyStateView(
                            title: "No Metrics Available",
                            message: "Generate suggestions to see optimization metrics.",
                            systemImage: "chart.bar"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Optimization Metrics")
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

struct OptimizationPotentialChart: View {
    let potential: Double
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: potential)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                // Center text
                VStack {
                    Text("\(Int(potential * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Potential")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Optimization Potential")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

struct SmartSchedulingAssistantView_Previews: PreviewProvider {
    static var previews: some View {
        SmartSchedulingAssistantView(
            assistant: SmartSchedulingAssistant(
                bookingDataService: ServiceBookingDataService(),
                analyticsService: BookingAnalyticsService(),
                businessRules: AutomatedBusinessRules(),
                waitlistService: WaitlistService()
            )
        )
    }
}
