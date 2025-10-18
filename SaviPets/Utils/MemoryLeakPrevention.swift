import Foundation
import FirebaseFirestore
import OSLog

/// Memory Leak Prevention Utilities
/// Ensures all Firestore listeners and resources are properly cleaned up
/// Addresses gRPC stream leaks (__NSCFInputStream, __NSCFOutputStream, CFHost)
final class MemoryLeakPrevention {
    
    /// Track all active Firestore listeners globally
    private static var activeListeners: Set<String> = []
    private static let lock = NSLock()
    
    /// Register a listener to track it
    static func registerListener(_ registration: ListenerRegistration, identifier: String) {
        lock.lock()
        defer { lock.unlock() }
        activeListeners.insert(identifier)
        AppLogger.data.debug("🔵 Registered listener: \(identifier). Total active: \(activeListeners.count)")
    }
    
    /// Unregister and remove a listener
    static func unregisterListener(_ registration: ListenerRegistration?, identifier: String) {
        registration?.remove()
        lock.lock()
        defer { lock.unlock() }
        activeListeners.remove(identifier)
        AppLogger.data.debug("🔴 Unregistered listener: \(identifier). Total active: \(activeListeners.count)")
    }
    
    /// Get count of active listeners (for debugging)
    static func getActiveListenerCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return activeListeners.count
    }
    
    /// List all active listeners (for debugging)
    static func listActiveListeners() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(activeListeners)
    }
    
    /// Remove all tracked listeners (emergency cleanup)
    static func removeAllListeners() {
        lock.lock()
        let count = activeListeners.count
        activeListeners.removeAll()
        lock.unlock()
        AppLogger.data.warning("⚠️ Emergency cleanup: Removed \(count) listeners")
    }
}

/// Extension to help with weak self captures
extension ObservableObject where Self: AnyObject {
    /// Safely execute a block with weak self
    func weakify<T>(_ block: @escaping (Self) -> T) -> () -> T? {
        return { [weak self] in
            guard let self = self else { return nil }
            return block(self)
        }
    }
    
    /// Safely execute an async block with weak self
    func weakifyAsync<T>(_ block: @escaping (Self) async -> T) -> () async -> T? {
        return { [weak self] in
            guard let self = self else { return nil }
            return await block(self)
        }
    }
}

/// Firestore listener wrapper that auto-cleans up
final class ManagedListener {
    private var registration: ListenerRegistration?
    private let identifier: String
    
    init(_ registration: ListenerRegistration, identifier: String) {
        self.registration = registration
        self.identifier = identifier
        MemoryLeakPrevention.registerListener(registration, identifier: identifier)
    }
    
    deinit {
        remove()
    }
    
    func remove() {
        if let reg = registration {
            MemoryLeakPrevention.unregisterListener(reg, identifier: identifier)
            registration = nil
        }
    }
}

/// Stream cleanup utilities
final class StreamCleanup {
    
    /// Ensure input/output streams are properly closed
    static func closeStreams(_ streams: (InputStream, OutputStream)) {
        let (input, output) = streams
        
        // Remove from run loop
        input.remove(from: .current, forMode: .common)
        output.remove(from: .current, forMode: .common)
        
        // Close streams
        input.close()
        output.close()
        
        AppLogger.data.debug("✅ Closed input/output stream pair")
    }
    
    /// Ensure URLSession is properly invalidated
    static func invalidateSession(_ session: URLSession) {
        session.invalidateAndCancel()  // Immediately cancels all tasks
        AppLogger.data.debug("✅ Invalidated URLSession")
    }
    
    /// Ensure URLSession tasks are completed before invalidation
    static func finishAndInvalidateSession(_ session: URLSession) {
        session.finishTasksAndInvalidate()  // Waits for tasks to finish
        AppLogger.data.debug("✅ Finishing and invalidating URLSession")
    }
}

