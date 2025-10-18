import SwiftUI

/// Reusable empty state view for when lists have no data
struct SPEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: SPDesignSystem.Spacing.l) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.6))
            
            VStack(spacing: SPDesignSystem.Spacing.s) {
                Text(title)
                    .font(SPDesignSystem.Typography.heading2())
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(SPDesignSystem.Typography.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SPDesignSystem.Spacing.xl)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, SPDesignSystem.Spacing.xl)
                .padding(.top, SPDesignSystem.Spacing.m)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SPDesignSystem.Spacing.xl)
    }
    
    // MARK: - Preset Empty States for Common Scenarios
    enum Preset {
        /// Empty state for when user has no pets
        static func noPets(action: @escaping () -> Void) -> SPEmptyStateView {
            Self.make(icon: "pawprint.circle",
                      title: "No Pets Yet",
                      message: "Add your first pet to get started with booking services and tracking visits.",
                      actionTitle: "Add Your First Pet",
                      action: action)
        }

        /// Empty state for when user has no bookings
        static func noBookings(action: @escaping () -> Void) -> SPEmptyStateView {
            Self.make(icon: "calendar.badge.plus",
                      title: "No Bookings",
                      message: "You haven't booked any services yet. Browse available services and schedule your first visit!",
                      actionTitle: "Book a Service",
                      action: action)
        }

        /// Empty state for when user has no visits (sitter view)
        static func noVisits() -> SPEmptyStateView {
            Self.make(icon: "calendar.badge.clock",
                      title: "No Visits Scheduled",
                      message: "You don't have any visits scheduled at the moment. Check back soon for new assignments!",
                      actionTitle: nil,
                      action: nil)
        }

        /// Empty state for when user has no conversations
        static func noConversations(action: @escaping () -> Void) -> SPEmptyStateView {
            Self.make(icon: "bubble.left.and.bubble.right",
                      title: "No Conversations",
                      message: "You haven't started any conversations yet. Reach out to admin if you have questions!",
                      actionTitle: "Contact Support",
                      action: action)
        }

        /// Empty state for when admin has no pending bookings
        static func noPendingBookings() -> SPEmptyStateView {
            Self.make(icon: "checkmark.circle",
                      title: "All Caught Up!",
                      message: "There are no pending bookings to review. Great job staying on top of approvals!",
                      actionTitle: nil,
                      action: nil)
        }

        /// Empty state for when admin has no inquiries
        static func noInquiries() -> SPEmptyStateView {
            Self.make(icon: "tray",
                      title: "No Inquiries",
                      message: "There are no pending inquiries at this time. All support requests have been addressed!",
                      actionTitle: nil,
                      action: nil)
        }

        /// Empty state for when search returns no results
        static func noSearchResults(searchTerm: String) -> SPEmptyStateView {
            Self.make(icon: "magnifyingglass",
                      title: "No Results Found",
                      message: "We couldn't find anything matching \"\(searchTerm)\". Try a different search term.",
                      actionTitle: nil,
                      action: nil)
        }

        /// Empty state for when filter returns no results
        static func noFilterResults() -> SPEmptyStateView {
            Self.make(icon: "line.3.horizontal.decrease.circle",
                      title: "No Matches",
                      message: "No items match your current filters. Try adjusting your filters to see more results.",
                      actionTitle: nil,
                      action: nil)
        }

        /// Empty state for network errors
        static func networkError(action: @escaping () -> Void) -> SPEmptyStateView {
            Self.make(icon: "wifi.slash",
                      title: "Connection Error",
                      message: "We couldn't load your data. Please check your internet connection and try again.",
                      actionTitle: "Try Again",
                      action: action)
        }

        /// Empty state for loading errors
        static func loadError(action: @escaping () -> Void) -> SPEmptyStateView {
            Self.make(icon: "exclamationmark.triangle",
                      title: "Something Went Wrong",
                      message: "We encountered an error loading your data. Please try again.",
                      actionTitle: "Retry",
                      action: action)
        }

        // Helper to centralize initialization
        private static func make(icon: String, title: String, message: String, actionTitle: String?, action: (() -> Void)?) -> SPEmptyStateView {
            SPEmptyStateView(icon: icon, title: title, message: message, actionTitle: actionTitle, action: action)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        SPEmptyStateView.Preset.noPets(action: {})
    }
}
