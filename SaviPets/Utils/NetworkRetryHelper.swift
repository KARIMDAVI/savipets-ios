import Foundation

actor NetworkRetryHelper {
    static func retry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                AppLogger.logError(error, context: "Network Retry Attempt \(attempt + 1)/\(maxAttempts)", logger: .network)
                
                if attempt < maxAttempts - 1 {
                    let backoff = delay * pow(2.0, Double(attempt))
                    AppLogger.logEvent("Retrying operation", parameters: [
                        "attempt": attempt + 1,
                        "maxAttempts": maxAttempts,
                        "backoffSeconds": backoff
                    ], logger: .network)
                    
                    try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                }
            }
        }
        
        AppLogger.logError(lastError ?? NSError(domain: "NetworkRetry", code: -1), 
                          context: "Network operation failed after \(maxAttempts) attempts", 
                          logger: .network)
        throw lastError ?? NSError(domain: "NetworkRetry", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Network operation failed after \(maxAttempts) attempts"
        ])
    }
    
    static func retryWithExponentialBackoff<T>(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 10.0,
        jitter: Bool = true,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                AppLogger.logError(error, context: "Network Retry Attempt \(attempt + 1)/\(maxAttempts)", logger: .network)
                
                if attempt < maxAttempts - 1 {
                    let exponentialDelay = min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
                    let finalDelay = jitter ? exponentialDelay + Double.random(in: 0...0.1) : exponentialDelay
                    
                    AppLogger.logEvent("Retrying operation with exponential backoff", parameters: [
                        "attempt": attempt + 1,
                        "maxAttempts": maxAttempts,
                        "delaySeconds": finalDelay
                    ], logger: .network)
                    
                    try? await Task.sleep(nanoseconds: UInt64(finalDelay * 1_000_000_000))
                }
            }
        }
        
        AppLogger.logError(lastError ?? NSError(domain: "NetworkRetry", code: -1), 
                          context: "Network operation failed after \(maxAttempts) attempts", 
                          logger: .network)
        throw lastError ?? NSError(domain: "NetworkRetry", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Network operation failed after \(maxAttempts) attempts"
        ])
    }
}
