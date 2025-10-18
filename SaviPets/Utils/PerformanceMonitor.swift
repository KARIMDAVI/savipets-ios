import Foundation
import SwiftUI
import FirebasePerformance
import OSLog

/// Performance monitoring manager for tracking app performance
enum PerformanceMonitor {
    
    // MARK: - Network Performance
    
    /// Track network request performance
    static func trackNetworkRequest(
        url: String,
        method: String,
        operation: @escaping () async throws -> Void
    ) async throws {
        let metric = Performance.startTrace(name: "network_\(method.lowercased())_request")
        metric?.setValue(url, forAttribute: "url")
        metric?.setValue(method, forAttribute: "method")
        
        let startTime = Date()
        
        do {
            try await operation()
            metric?.setValue("success", forAttribute: "status")
        } catch {
            metric?.setValue("error", forAttribute: "status")
            metric?.setValue(String(describing: type(of: error)), forAttribute: "error_type")
            throw error
        }
        
        let duration = Date().timeIntervalSince(startTime)
        metric?.setValue(Int64(duration * 1000), forMetric: "duration_ms")
        metric?.stop()
        
        AppLogger.network.debug("Network request completed: \(method) \(url) in \(duration)s")
    }
    
    // MARK: - Database Operations
    
    /// Track Firestore read performance
    static func trackFirestoreRead(
        collection: String,
        operation: @escaping () async throws -> Void
    ) async throws {
        let metric = Performance.startTrace(name: "firestore_read")
        metric?.setValue(collection, forAttribute: "collection")
        
        let startTime = Date()
        
        do {
            try await operation()
            metric?.setValue("success", forAttribute: "status")
        } catch {
            metric?.setValue("error", forAttribute: "status")
            throw error
        }
        
        let duration = Date().timeIntervalSince(startTime)
        metric?.setValue(Int64(duration * 1000), forMetric: "duration_ms")
        metric?.stop()
        
        AppLogger.data.debug("Firestore read: \(collection) in \(duration)s")
    }
    
    /// Track Firestore write performance
    static func trackFirestoreWrite(
        collection: String,
        operation: @escaping () async throws -> Void
    ) async throws {
        let metric = Performance.startTrace(name: "firestore_write")
        metric?.setValue(collection, forAttribute: "collection")
        
        let startTime = Date()
        
        do {
            try await operation()
            metric?.setValue("success", forAttribute: "status")
        } catch {
            metric?.setValue("error", forAttribute: "status")
            throw error
        }
        
        let duration = Date().timeIntervalSince(startTime)
        metric?.setValue(Int64(duration * 1000), forMetric: "duration_ms")
        metric?.stop()
        
        AppLogger.data.debug("Firestore write: \(collection) in \(duration)s")
    }
    
    // MARK: - Screen Performance
    
    /// Track screen load time
    static func trackScreenLoad(
        screenName: String,
        operation: @escaping () async -> Void
    ) async {
        let metric = Performance.startTrace(name: "screen_load")
        metric?.setValue(screenName, forAttribute: "screen_name")
        
        let startTime = Date()
        await operation()
        let duration = Date().timeIntervalSince(startTime)
        
        metric?.setValue(Int64(duration * 1000), forMetric: "duration_ms")
        metric?.stop()
        
        AppLogger.ui.debug("Screen load: \(screenName) in \(duration)s")
    }
    
    // MARK: - Custom Traces
    
    /// Start a custom performance trace
    static func startTrace(name: String) -> Trace? {
        let trace = Performance.startTrace(name: name)
        AppLogger.ui.debug("Started trace: \(name)")
        return trace
    }
    
    /// Track a custom operation
    static func trackOperation<T>(
        name: String,
        attributes: [String: String]? = nil,
        operation: () async throws -> T
    ) async rethrows -> T {
        let metric = Performance.startTrace(name: name)
        
        if let attributes = attributes {
            for (key, value) in attributes {
                metric?.setValue(value, forAttribute: key)
            }
        }
        
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        
        metric?.setValue(Int64(duration * 1000), forMetric: "duration_ms")
        metric?.stop()
        
        AppLogger.ui.debug("Operation \(name) completed in \(duration)s")
        return result
    }
    
    // MARK: - Automatic Network Trace
    
    /// Create an HTTP metric for tracking network requests
    /// Note: HTTPMetric is deprecated in Firebase Performance SDK
    /// Use custom traces instead
    static func createHTTPMetric(url: URL, method: HTTPMethod) -> Trace? {
        let trace = Performance.startTrace(name: "http_\(method.rawValue.lowercased())")
        trace?.setValue(url.absoluteString, forAttribute: "url")
        trace?.setValue(method.rawValue, forAttribute: "method")
        return trace
    }
    
    // MARK: - App Start Performance
    
    /// Track app cold start time
    static func trackAppStart() {
        let metric = Performance.startTrace(name: "app_start")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            metric?.stop()
            AppLogger.ui.info("App start trace completed")
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - View Modifier for Performance Tracking

extension View {
    /// Track view load performance
    func trackPerformance(screen: String) -> some View {
        self.task {
            await PerformanceMonitor.trackScreenLoad(screenName: screen) {
                // View appeared
            }
        }
    }
}

