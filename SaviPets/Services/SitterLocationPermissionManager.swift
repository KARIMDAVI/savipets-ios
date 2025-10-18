import Foundation
import CoreLocation
import SwiftUI
import OSLog
import Combine

final class SitterLocationPermissionManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var showPermissionAlert: Bool = false
    @Published var permissionAlertMessage: String = ""
    
    private let locationManager = CLLocationManager()
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// Check if sitter has proper location permissions for visits
    var hasRequiredPermissions: Bool {
        switch authorizationStatus {
        case .authorizedAlways:
            return true
        case .authorizedWhenInUse:
            // For sitters, we need "Always Allow" for background tracking
            return false
        default:
            return false
        }
    }
    
    /// Request location permissions with sitter-specific messaging
    func requestLocationPermissions() {
        guard appState.role == .petSitter else {
            AppLogger.ui.warning("Location permission requested by non-sitter user")
            return
        }
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showPermissionAlert = true
            permissionAlertMessage = "Location access is required for pet sitting. Please enable location permissions in Settings to continue."
        case .authorizedWhenInUse:
            // Sitter needs "Always Allow" - show upgrade prompt
            showPermissionAlert = true
            permissionAlertMessage = "For pet sitting, SaviPets needs 'Always Allow' location access to track visits in the background. Please upgrade your permission in Settings."
        case .authorizedAlways:
            AppLogger.ui.info("Sitter has required location permissions")
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    /// Check permissions before starting a visit
    func checkPermissionsBeforeVisit() -> Bool {
        guard appState.role == .petSitter else { return true }
        
        if !hasRequiredPermissions {
            showPermissionAlert = true
            permissionAlertMessage = "You must enable 'Always Allow' location access to start visits. This ensures clients can track your location during pet care sessions."
            return false
        }
        
        return true
    }
    
    /// Open Settings app to location permissions
    func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension SitterLocationPermissionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            // Log permission changes for sitters
            if self.appState.role == .petSitter {
                AppLogger.ui.info("Sitter location permission changed to: \(self.authorizationStatusString)")
                
                // Show upgrade prompt if sitter only has "When In Use"
                if status == .authorizedWhenInUse {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.showPermissionAlert = true
                        self.permissionAlertMessage = "For pet sitting, please upgrade to 'Always Allow' location access in Settings to enable background tracking during visits."
                    }
                }
            }
        }
    }
    
    private var authorizationStatusString: String {
        switch authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always Allow"
        case .authorizedWhenInUse: return "When In Use"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - SwiftUI View Extension
extension View {
    /// Show location permission alert for sitters
    func sitterLocationPermissionAlert(isPresented: Binding<Bool>, message: String, onOpenSettings: @escaping () -> Void) -> some View {
        self.alert("Location Permission Required", isPresented: isPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                onOpenSettings()
            }
        } message: {
            Text(message)
        }
    }
}
