import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import Combine

final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let db = Firestore.firestore()
    @Published private(set) var isTracking: Bool = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // meters
        manager.pausesLocationUpdatesAutomatically = true
    }

    // Helper to get current authorization status with iOS 14+ compatibility
    private var currentAuthorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return manager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }

    func requestWhenInUseIfNeeded() {
        if currentAuthorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysIfNeeded() {
        let status = currentAuthorizationStatus
        switch status {
        case .notDetermined:
            // Must request When In Use first
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Eligible to escalate to Always
            manager.requestAlwaysAuthorization()
        default:
            break // .authorizedAlways, .denied, .restricted, etc.
        }
    }

    func startVisitTracking() {
        guard !isTracking else { return }
        requestWhenInUseIfNeeded()
        requestAlwaysIfNeeded()
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        isTracking = true
    }

    func stopVisitTracking() {
        guard isTracking else { return }
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isTracking = false
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate,
              let uid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "lat": coord.latitude,
            "lng": coord.longitude,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        db.collection("locations").document(uid).setData(data, merge: true)
    }

    // iOS 14+ delegate
    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // no-op; UI can observe isTracking and authorization via higher-level flow
        // You could inspect `manager.authorizationStatus` here if needed.
    }

    // Pre–iOS 14 delegate
    @available(iOS, introduced: 4.2, deprecated: 14.0)
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // no-op; UI can observe isTracking and authorization via higher-level flow
    }
}
