import Foundation

enum AppConstants {
    enum URLs {
        static let terms = "https://www.savipets.com/terms"
        static let privacy = "https://www.savipets.com/privacy-policy"
        static let emergency = "tel://4845677999"
    }
    
    enum Validation {
        static let minPasswordLength = 8
        static let minAge = 18
    }
    
    enum Firebase {
        // Note: App ID is a client-side identifier, not sensitive.
        // For better configuration management, consider loading from GoogleService-Info.plist
        static let appId = "1:367657554735:ios:05871c65559a6a40b007da"
    }
    
    enum TimeZone {
        static let defaultTimeZone = Foundation.TimeZone(identifier: "America/New_York") ?? .current
    }
}
