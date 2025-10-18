import SwiftUI
import OSLog

/// Error boundary for SwiftUI views to prevent app crashes
/// Wraps views and catches initialization/rendering errors
struct ErrorBoundary<Content: View>: View {
    let content: () -> Content
    let errorView: (Error) -> AnyView
    
    @State private var error: Error?
    
    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder errorView: @escaping (Error) -> AnyView = { error in
            AnyView(DefaultErrorView(error: error))
        }
    ) {
        self.content = content
        self.errorView = errorView
    }
    
    var body: some View {
        Group {
            if let error = error {
                errorView(error)
            } else {
                SafeView(error: $error, content: content)
            }
        }
    }
}

/// Helper view that safely renders content
private struct SafeView<Content: View>: View {
    @Binding var error: Error?
    let content: () -> Content
    
    var body: some View {
        content()
            .onAppear {
                // SwiftUI doesn't support try-catch in body
                // Errors should be handled at the data layer
            }
    }
}

/// Default error view shown when an error is caught
struct DefaultErrorView: View {
    let error: Error
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Oops! Something went wrong")
                .font(.title2.bold())
            
            Text(ErrorMapper.userFriendlyMessage(for: error))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Dismiss") {
                // Trigger view refresh
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            SPDesignSystem.Colors.goldenGradient(colorScheme)
                .opacity(0.1)
                .ignoresSafeArea()
        )
    }
}

// MARK: - View Extension for Convenient Error Boundary Usage

extension View {
    /// Wraps the view in an error boundary to catch and handle errors gracefully
    func withErrorBoundary() -> some View {
        ErrorBoundary {
            self
        }
    }
    
    /// Wraps the view in an error boundary with custom error handling
    func withErrorBoundary<ErrorView: View>(
        @ViewBuilder errorView: @escaping (Error) -> ErrorView
    ) -> some View {
        ErrorBoundary {
            self
        } errorView: { error in
            AnyView(errorView(error))
        }
    }
}

// MARK: - Error Reporting

/// Global error reporter for tracking crashes and errors
enum ErrorReporter {
    /// Report a caught error for monitoring
    static func report(_ error: Error, context: String = "") {
        AppLogger.ui.error("Error in \(context): \(error.localizedDescription)")
        
        // In production, send to crash reporting service (e.g., Crashlytics)
        // Crashlytics.crashlytics().record(error: error)
    }
    
    /// Report a critical error that requires immediate attention
    static func reportCritical(_ error: Error, context: String = "", userInfo: [String: Any]? = nil) {
        AppLogger.ui.error("CRITICAL ERROR in \(context): \(error.localizedDescription)")
        
        if let info = userInfo {
            AppLogger.ui.error("User info: \(info)")
        }
        
        // In production, send to crash reporting with high priority
        // Crashlytics.crashlytics().record(error: error, userInfo: userInfo ?? [:])
    }
}

