import SwiftUI
import OSLog

struct ServiceFeedbackView: View {
    let booking: ServiceBooking
    @StateObject private var feedbackService = FeedbackService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var selectedCategories: Set<FeedbackCategory> = []
    @State private var isAnonymous: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    FeedbackHeaderView(booking: booking)
                    
                    // Rating Section
                    RatingSectionView(rating: $rating)
                    
                    // Categories Section
                    CategoriesSectionView(selectedCategories: $selectedCategories)
                    
                    // Comment Section
                    CommentSectionView(comment: $comment)
                    
                    // Privacy Section
                    PrivacySectionView(isAnonymous: $isAnonymous)
                    
                    // Submit Button
                    SubmitButtonView(
                        isSubmitting: isSubmitting,
                        canSubmit: canSubmit,
                        onSubmit: submitFeedback
                    )
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Service Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Feedback Submitted", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your feedback! It helps us improve our services.")
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canSubmit: Bool {
        return rating >= 1 && rating <= 5 && !selectedCategories.isEmpty
    }
    
    // MARK: - Actions
    private func submitFeedback() {
        guard canSubmit else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            let result = await feedbackService.submitFeedback(
                bookingId: booking.id,
                clientId: booking.clientId,
                sitterId: booking.sitterId ?? "",
                rating: rating,
                comment: comment.isEmpty ? nil : comment,
                categories: Array(selectedCategories)
            )
            
            await MainActor.run {
                isSubmitting = false
                
                switch result {
                case .success:
                    showSuccessAlert = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Feedback Header
private struct FeedbackHeaderView: View {
    let booking: ServiceBooking
    
    var body: some View {
        VStack(spacing: 12) {
            // Service info
            VStack(spacing: 8) {
                Text(booking.serviceType)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("with \(booking.sitterName ?? "your sitter")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(booking.scheduledDate.formatted(date: .complete, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Pets info
            if !booking.pets.isEmpty {
                HStack {
                    Image(systemName: "pawprint.fill")
                        .foregroundColor(.orange)
                    
                    Text(booking.pets.joined(separator: ", "))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Rating Section
private struct RatingSectionView: View {
    @Binding var rating: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Rating")
                .font(.headline)
            
            Text("How would you rate your experience?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: { rating = star }) {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(star <= rating ? .yellow : .gray)
                    }
                }
                
                Spacer()
                
                Text(ratingText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var ratingText: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very Good"
        case 5: return "Excellent"
        default: return ""
        }
    }
}

// MARK: - Categories Section
private struct CategoriesSectionView: View {
    @Binding var selectedCategories: Set<FeedbackCategory>
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 2)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What went well?")
                .font(.headline)
            
            Text("Select all that apply (required)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(FeedbackCategory.allCases, id: \.rawValue) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategories.contains(category),
                        onTap: { toggleCategory(category) }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func toggleCategory(_ category: FeedbackCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
}

private struct CategoryChip: View {
    let category: FeedbackCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Comment Section
private struct CommentSectionView: View {
    @Binding var comment: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Comments")
                .font(.headline)
            
            Text("Share more details about your experience (optional)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Tell us about your experience...", text: $comment, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(4...8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Privacy Section
private struct PrivacySectionView: View {
    @Binding var isAnonymous: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy")
                .font(.headline)
            
            HStack {
                Toggle("Submit anonymously", isOn: $isAnonymous)
                    .font(.subheadline)
                
                Spacer()
            }
            
            if isAnonymous {
                Text("Your name will not be shown to the sitter, but your feedback will still help improve our services.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Submit Button
private struct SubmitButtonView: View {
    let isSubmitting: Bool
    let canSubmit: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        Button(action: onSubmit) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                }
                
                Text(isSubmitting ? "Submitting..." : "Submit Feedback")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSubmit ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canSubmit || isSubmitting)
    }
}

// MARK: - Feedback History View
struct FeedbackHistoryView: View {
    @StateObject private var feedbackService = FeedbackService()
    @State private var selectedFilter: FeedbackFilter = .all
    @State private var searchText: String = ""
    
    enum FeedbackFilter: String, CaseIterable {
        case all = "All"
        case fiveStar = "5 Stars"
        case fourStar = "4+ Stars"
        case threeStar = "3+ Stars"
        case withComments = "With Comments"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with filters
                FeedbackHistoryHeaderView(
                    selectedFilter: $selectedFilter,
                    searchText: $searchText
                )
                
                // Feedback list
                if filteredFeedbacks.isEmpty {
                    EmptyFeedbackHistoryView()
                } else {
                    FeedbackHistoryListView(
                        feedbacks: filteredFeedbacks,
                        onFeedbackTap: { feedback in
                            // Show feedback details
                        }
                    )
                }
            }
            .navigationTitle("Feedback History")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await feedbackService.refreshFeedbacks()
            }
        }
    }
    
    // MARK: - Computed Properties
    private var filteredFeedbacks: [ServiceFeedback] {
        var feedbacks = feedbackService.feedbacks
        
        // Apply rating filter
        switch selectedFilter {
        case .all:
            break
        case .fiveStar:
            feedbacks = feedbacks.filter { $0.rating == 5 }
        case .fourStar:
            feedbacks = feedbacks.filter { $0.rating >= 4 }
        case .threeStar:
            feedbacks = feedbacks.filter { $0.rating >= 3 }
        case .withComments:
            feedbacks = feedbacks.filter { !($0.comment?.isEmpty ?? true) }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            feedbacks = feedbacks.filter { feedback in
                feedback.comment?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        return feedbacks
    }
}

// MARK: - Feedback History Header
private struct FeedbackHistoryHeaderView: View {
    @Binding var selectedFilter: FeedbackHistoryView.FeedbackFilter
    @Binding var searchText: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search feedback...", text: $searchText)
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
                    ForEach(FeedbackHistoryView.FeedbackFilter.allCases, id: \.id) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            onTap: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal)
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

// MARK: - Feedback History List
private struct FeedbackHistoryListView: View {
    let feedbacks: [ServiceFeedback]
    let onFeedbackTap: (ServiceFeedback) -> Void
    
    var body: some View {
        List {
            ForEach(feedbacks) { feedback in
                FeedbackHistoryRow(
                    feedback: feedback,
                    onTap: { onFeedbackTap(feedback) }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
    }
}

private struct FeedbackHistoryRow: View {
    let feedback: ServiceFeedback
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with rating and date
                HStack {
                    // Rating stars
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= feedback.rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(star <= feedback.rating ? .yellow : .gray)
                        }
                    }
                    
                    Spacer()
                    
                    Text(feedback.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Categories
                if !feedback.categories.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                        ForEach(Array(feedback.categories.prefix(6)), id: \.rawValue) { category in
                            Text(category.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
                
                // Comment preview
                if let comment = feedback.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Status
                HStack {
                    Text("Submitted")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    if feedback.helpfulVotes > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup")
                                .font(.caption)
                            Text("\(feedback.helpfulVotes)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty State
private struct EmptyFeedbackHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Feedback Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your feedback history will appear here once you start rating services.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}


// MARK: - Preview
#Preview {
    ServiceFeedbackView(
        booking: ServiceBooking(
            id: "test-booking",
            clientId: "test-client",
            serviceType: "Dog Walking",
            scheduledDate: Date(),
            scheduledTime: "10:00 AM",
            duration: 30,
            pets: ["Buddy", "Bella"],
            specialInstructions: "Please walk them separately",
            status: .completed,
            sitterId: "test-sitter",
            sitterName: "John Doe",
            createdAt: Date(),
            address: "123 Main St",
            checkIn: nil,
            checkOut: nil,
            price: "25.00",
            recurringSeriesId: nil,
            visitNumber: nil,
            isRecurring: false,
            paymentStatus: nil,
            paymentTransactionId: nil,
            paymentAmount: nil,
            paymentMethod: nil,
            rescheduledFrom: nil,
            rescheduledAt: nil,
            rescheduledBy: nil,
            rescheduleReason: nil,
            rescheduleHistory: [],
            lastModified: Date(),
            lastModifiedBy: nil,
            modificationReason: nil
        )
    )
}
