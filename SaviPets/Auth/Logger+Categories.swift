import Foundation
import OSLog

extension Logger {
    private static var appSubsystem: String {
        Bundle.main.bundleIdentifier ?? "com.savipets"
    }
    
    static let auth = Logger(subsystem: appSubsystem, category: "Authentication")
    static let network = Logger(subsystem: appSubsystem, category: "Network")
    static let ui = Logger(subsystem: appSubsystem, category: "UI")
    static let data = Logger(subsystem: appSubsystem, category: "Data")
    static let timer = Logger(subsystem: appSubsystem, category: "Timer")
    static let chat = Logger(subsystem: appSubsystem, category: "Chat")
}
