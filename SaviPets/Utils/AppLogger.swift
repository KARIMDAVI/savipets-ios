import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.savipets"
    
    static let auth = Logger(subsystem: subsystem, category: "Authentication")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let data = Logger(subsystem: subsystem, category: "Data")
    
    static func logError(_ error: Error, context: String, logger: Logger = .auth) {
        logger.error("[\(context)] \(error.localizedDescription)")
    }
    
    static func logEvent(_ event: String, parameters: [String: Any]? = nil, logger: Logger = .ui) {
        let params = parameters?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? ""
        logger.info("[\(event)] \(params)")
    }
}
