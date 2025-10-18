import Foundation

/// Minimal debug logger. Toggle `isEnabled` to silence verbose logs in production.
enum DLog {
    static var isEnabled: Bool = true

    static func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard isEnabled else { return }
        let message = items.map { String(describing: $0) }.joined(separator: separator)
        print(message, terminator: terminator)
    }
}






