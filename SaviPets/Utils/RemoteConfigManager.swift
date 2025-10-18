import Foundation
import SwiftUI
import Combine
import FirebaseRemoteConfig
import OSLog

/// Remote configuration manager for feature flags and dynamic values
@MainActor
final class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()
    
    private let remoteConfig = RemoteConfig.remoteConfig()
    @Published private(set) var isReady = false
    
    // MARK: - Feature Flags
    
    @Published private(set) var enableChatApproval = true
    @Published private(set) var enableLocationTracking = true
    @Published private(set) var enablePushNotifications = true
    @Published private(set) var enableAutoResponder = false
    @Published private(set) var maintenanceMode = false
    
    // MARK: - Configuration Values
    
    @Published private(set) var maxMessageLength = 1000
    @Published private(set) var minBookingAdvanceHours = 24
    @Published private(set) var maxPhotosPerPet = 10
    @Published private(set) var chatBatchDelay = 3.0
    @Published private(set) var autoResponseDelay = 300.0 // 5 minutes
    @Published private(set) var locationUpdateInterval = 10.0 // seconds
    
    // MARK: - Business Rules
    
    @Published private(set) var cancellationPolicyHours = 24
    @Published private(set) var overtimeGracePeriodMinutes = 5
    @Published private(set) var supportEmail = "support@savipets.com"
    @Published private(set) var emergencyPhone = "4845677999"
    
    private init() {
        setupDefaults()
        Task {
            await fetchAndActivate()
        }
    }
    
    // MARK: - Setup
    
    private func setupDefaults() {
        let defaults: [String: NSObject] = [
            // Feature flags
            "enable_chat_approval": true as NSObject,
            "enable_location_tracking": true as NSObject,
            "enable_push_notifications": true as NSObject,
            "enable_auto_responder": false as NSObject,
            "maintenance_mode": false as NSObject,
            
            // Configuration values
            "max_message_length": 1000 as NSObject,
            "min_booking_advance_hours": 24 as NSObject,
            "max_photos_per_pet": 10 as NSObject,
            "chat_batch_delay": 3.0 as NSObject,
            "auto_response_delay": 300.0 as NSObject,
            "location_update_interval": 10.0 as NSObject,
            
            // Business rules
            "cancellation_policy_hours": 24 as NSObject,
            "overtime_grace_period_minutes": 5 as NSObject,
            "support_email": "support@savipets.com" as NSObject,
            "emergency_phone": "4845677999" as NSObject,
        ]
        
        remoteConfig.setDefaults(defaults)
        
        // Configure fetch settings
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600 // 1 hour for production
        #if DEBUG
        settings.minimumFetchInterval = 0 // Immediate for development
        #endif
        remoteConfig.configSettings = settings
    }
    
    // MARK: - Fetch & Activate
    
    func fetchAndActivate() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            
            switch status {
            case .successFetchedFromRemote:
                AppLogger.network.info("Remote config fetched from remote")
            case .successUsingPreFetchedData:
                AppLogger.network.info("Remote config using cached data")
            case .error:
                AppLogger.network.error("Remote config fetch failed")
            @unknown default:
                AppLogger.network.warning("Remote config unknown status")
            }
            
            updatePublishedValues()
            isReady = true
            
        } catch {
            AppLogger.network.error("Error fetching remote config: \(error.localizedDescription)")
            // Fall back to defaults
            updatePublishedValues()
            isReady = true
        }
    }
    
    // MARK: - Update Values
    
    private func updatePublishedValues() {
        // Feature flags
        enableChatApproval = remoteConfig["enable_chat_approval"].boolValue
        enableLocationTracking = remoteConfig["enable_location_tracking"].boolValue
        enablePushNotifications = remoteConfig["enable_push_notifications"].boolValue
        enableAutoResponder = remoteConfig["enable_auto_responder"].boolValue
        maintenanceMode = remoteConfig["maintenance_mode"].boolValue
        
        // Configuration values
        maxMessageLength = remoteConfig["max_message_length"].numberValue.intValue
        minBookingAdvanceHours = remoteConfig["min_booking_advance_hours"].numberValue.intValue
        maxPhotosPerPet = remoteConfig["max_photos_per_pet"].numberValue.intValue
        chatBatchDelay = remoteConfig["chat_batch_delay"].numberValue.doubleValue
        autoResponseDelay = remoteConfig["auto_response_delay"].numberValue.doubleValue
        locationUpdateInterval = remoteConfig["location_update_interval"].numberValue.doubleValue
        
        // Business rules
        cancellationPolicyHours = remoteConfig["cancellation_policy_hours"].numberValue.intValue
        overtimeGracePeriodMinutes = remoteConfig["overtime_grace_period_minutes"].numberValue.intValue
        supportEmail = remoteConfig["support_email"].stringValue.isEmpty ? "support@savipets.com" : remoteConfig["support_email"].stringValue  // Nil coalescing fix: stringValue is non-optional
        emergencyPhone = remoteConfig["emergency_phone"].stringValue.isEmpty ? "4845677999" : remoteConfig["emergency_phone"].stringValue  // Nil coalescing fix: stringValue is non-optional
        
        AppLogger.network.info("Remote config values updated")
    }
    
    // MARK: - Manual Refresh
    
    func refresh() {
        Task {
            await fetchAndActivate()
        }
    }
    
    // MARK: - Convenience Getters
    
    var isChatApprovalEnabled: Bool { enableChatApproval }
    var isLocationTrackingEnabled: Bool { enableLocationTracking }
    var isPushNotificationsEnabled: Bool { enablePushNotifications }
    var isAutoResponderEnabled: Bool { enableAutoResponder }
    var isMaintenanceMode: Bool { maintenanceMode }
    
    // MARK: - Feature Flag Checking
    
    func isFeatureEnabled(_ feature: String) -> Bool {
        let key = "enable_\(feature.lowercased().replacingOccurrences(of: " ", with: "_"))"
        return remoteConfig[key].boolValue
    }
    
    func getStringValue(_ key: String, default defaultValue: String = "") -> String {
        let value = remoteConfig[key].stringValue  // Nil coalescing fix: stringValue is non-optional
        return value.isEmpty ? defaultValue : value
    }
    
    func getNumberValue(_ key: String, default defaultValue: Double = 0) -> Double {
        remoteConfig[key].numberValue.doubleValue
    }
    
    func getBoolValue(_ key: String, default defaultValue: Bool = false) -> Bool {
        remoteConfig[key].boolValue
    }
}

// MARK: - Maintenance Mode View

struct MaintenanceModeView: View {
    let config: RemoteConfigManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Under Maintenance")
                .font(.title.bold())
            
            Text("We're making SaviPets even better! We'll be back soon.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Label("Check back in a few minutes", systemImage: "clock")
                Label("Your data is safe", systemImage: "lock.shield")
                Label("Contact support if urgent", systemImage: "phone")
            }
            .foregroundColor(.secondary)
            
            Button("Contact Support") {
                if let url = URL(string: "mailto:\(config.supportEmail)") {
                    UIApplication.shared.open(url)
                }
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

