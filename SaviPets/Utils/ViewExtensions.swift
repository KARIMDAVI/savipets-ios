import SwiftUI

// MARK: - Pull to Refresh Extension

extension View {
    /// Add pull-to-refresh with haptic feedback
    func pullToRefresh(isRefreshing: Binding<Bool>, action: @escaping () async -> Void) -> some View {
        self.refreshable {
            await MainActor.run {
                isRefreshing.wrappedValue = true
                
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            
            await action()
            
            await MainActor.run {
                isRefreshing.wrappedValue = false
            }
        }
    }
}

// MARK: - Conditional Content Extension

extension View {
    /// Show content or empty state based on condition
    @ViewBuilder
    func emptyState<EmptyContent: View>(
        when condition: Bool,
        @ViewBuilder emptyContent: () -> EmptyContent
    ) -> some View {
        if condition {
            emptyContent()
        } else {
            self
        }
    }
}

// MARK: - Loading Overlay Extension

extension View {
    /// Show loading overlay while async operation is in progress
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        self.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: SPDesignSystem.Spacing.m) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text(message)
                            .font(SPDesignSystem.Typography.callout())
                            .foregroundColor(.white)
                    }
                    .padding(SPDesignSystem.Spacing.l)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
        }
    }
}

// MARK: - Searchable Extension

extension View {
    /// Add search functionality to a list
    func searchable<Items: RandomAccessCollection>(
        items: Items,
        searchText: Binding<String>,
        searchPredicate: @escaping (Items.Element, String) -> Bool
    ) -> some View where Items.Element: Identifiable {
        self.modifier(SearchableModifier(
            items: items,
            searchText: searchText,
            searchPredicate: searchPredicate
        ))
    }
}

private struct SearchableModifier<Items: RandomAccessCollection>: ViewModifier where Items.Element: Identifiable {
    let items: Items
    @Binding var searchText: String
    let searchPredicate: (Items.Element, String) -> Bool
    
    func body(content: Content) -> some View {
        content
            .searchable(text: $searchText, prompt: "Search")
    }
}

// MARK: - Haptic Feedback Extension

extension View {
    /// Trigger haptic feedback
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let impact = UIImpactFeedbackGenerator(style: style)
            impact.impactOccurred()
        }
    }
    
    /// Trigger success haptic
    func hapticSuccess() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }
    
    /// Trigger error haptic
    func hapticError() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.error)
    }
    
    /// Trigger warning haptic
    func hapticWarning() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let petsDidChange = Notification.Name("petsDidChange")
    static let bookingsDidChange = Notification.Name("bookingsDidChange")
    static let visitsDidChange = Notification.Name("visitsDidChange")
    static let conversationsDidChange = Notification.Name("conversationsDidChange")
    static let openMessagesTab = Notification.Name("openMessagesTab")
}

// MARK: - List Style Extension

extension View {
    /// Apply standard list styling
    func standardListStyle() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
    }
}

// MARK: - Card Animation Extension

extension View {
    /// Add subtle animation when card appears
    func cardAppearAnimation(delay: Double = 0) -> some View {
        self
            .opacity(0)
            .offset(y: 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    // Triggers implicit animation
                }
            }
    }
}

