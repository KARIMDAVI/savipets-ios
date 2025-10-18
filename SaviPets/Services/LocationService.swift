import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import Combine
import OSLog

/// Enhanced LocationService with geofencing, auto check-in, route tracking, and ETA notifications
/// Implements battery-efficient location updates and stores complete location history in Firestore
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    // MARK: - Core Properties
    private let manager = CLLocationManager()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published State
    @Published private(set) var isTracking: Bool = false
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var locationAccuracy: CLLocationAccuracy = 0
    @Published private(set) var isInsideGeofence: Bool = false
    @Published private(set) var estimatedArrivalMinutes: Int?
    
    // MARK: - Visit Tracking
    private var currentVisitId: String?
    private var visitStartLocation: CLLocation?
    private var routePoints: [CLLocation] = []
    private var geofenceRegion: CLCircularRegion?
    private var destinationCoordinate: CLLocationCoordinate2D?
    private var hasAutoCheckedIn: Bool = false
    private var lastLocationUpdate: Date?
    private var has5MinuteNotificationSent: Bool = false
    
    // MARK: - Configuration Constants
    private struct Config {
        static let autoCheckinRadius: CLLocationDistance = 100 // meters
        static let geofenceRadius: CLLocationDistance = 200 // meters
        static let routePointInterval: TimeInterval = 30 // seconds
        static let etaUpdateInterval: TimeInterval = 60 // seconds
        static let minimumAccuracy: CLLocationAccuracy = 50 // meters
        static let batteryEfficientAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
        static let highAccuracyForCheckin: CLLocationAccuracy = kCLLocationAccuracyBest
        static let etaThreshold: TimeInterval = 300 // 5 minutes in seconds
    }

    private override init() {
        super.init()
        setupLocationManager()
    }
    
    deinit {
        cleanup()
    }
    
    /// Setup location manager with optimal settings
    private func setupLocationManager() {
        manager.delegate = self
        manager.desiredAccuracy = Config.batteryEfficientAccuracy  // Battery-efficient by default
        manager.distanceFilter = 50 // meters - only update when moved significantly
        manager.pausesLocationUpdatesAutomatically = true  // Battery optimization
        manager.activityType = .otherNavigation  // Optimized for walking/running
        manager.showsBackgroundLocationIndicator = true  // iOS 11+ transparency
    }
    
    /// Cleanup method for memory management
    func cleanup() {
        stopAllTracking()
        manager.delegate = nil
        cancellables.removeAll()
        AppLogger.data.debug("LocationService cleaned up")
    }

    // Helper to get current authorization status with iOS 14+ compatibility
    private var currentAuthorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return manager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }

    // MARK: - Permission Requests

    func requestWhenInUseIfNeeded() {
        if currentAuthorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysIfNeeded() {
        let status = currentAuthorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }
    
    // MARK: - Enhanced Visit Tracking
    
    /// Start tracking with geofencing and route recording for a specific visit
    /// - Parameters:
    ///   - visitId: Unique identifier for the visit
    ///   - destinationAddress: Client's address for auto check-in
    ///   - clientId: Client user ID for notifications
    func startEnhancedVisitTracking(visitId: String, destinationAddress: String, clientId: String) async throws {
        guard !isTracking else {
            AppLogger.data.warning("Already tracking a visit")
            return
        }
        
        // Reset state
        currentVisitId = visitId
        routePoints = []
        hasAutoCheckedIn = false
        has5MinuteNotificationSent = false
        lastLocationUpdate = Date()
        
        // Geocode destination address
        if let coordinate = try? await geocodeAddress(destinationAddress) {
            destinationCoordinate = coordinate
            
            // Set up geofencing
            setupGeofence(for: coordinate, visitId: visitId)
            
            AppLogger.data.info("✅ Enhanced tracking started for visit \(visitId) at \(destinationAddress)")
        } else {
            AppLogger.data.error("Failed to geocode address: \(destinationAddress)")
            throw NSError(domain: "LocationService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Could not find destination address"
            ])
        }
        
        // Request permissions
        requestWhenInUseIfNeeded()
        requestAlwaysIfNeeded()
        
        // Start high-accuracy tracking initially
        manager.desiredAccuracy = Config.highAccuracyForCheckin
        manager.distanceFilter = 10 // More frequent updates near destination
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        
        isTracking = true
        
        // Create visit tracking document in Firestore
        try await createVisitTrackingDocument(visitId: visitId, clientId: clientId)
    }

    /// Legacy method - simple tracking without enhancements
    func startVisitTracking() {
        guard !isTracking else { return }
        requestWhenInUseIfNeeded()
        requestAlwaysIfNeeded()
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        isTracking = true
    }

    /// Stop all tracking and clean up
    func stopVisitTracking() {
        guard isTracking else { return }
        
        // Finalize route tracking
        if let visitId = currentVisitId {
            Task {
                await finalizeVisitRoute(visitId: visitId)
            }
        }
        
        stopAllTracking()
    }
    
    /// Stop all tracking and remove geofences
    private func stopAllTracking() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        
        // Remove all monitored regions (geofences)
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        
        // Reset state
        isTracking = false
        currentVisitId = nil
        visitStartLocation = nil
        routePoints = []
        geofenceRegion = nil
        destinationCoordinate = nil
        hasAutoCheckedIn = false
        has5MinuteNotificationSent = false
        
        AppLogger.data.info("🛑 All tracking stopped and cleaned up")
    }
    
    // MARK: - Geofencing
    
    /// Set up circular geofence around destination
    private func setupGeofence(for coordinate: CLLocationCoordinate2D, visitId: String) {
        let region = CLCircularRegion(
            center: coordinate,
            radius: Config.geofenceRadius,
            identifier: "visit-\(visitId)"
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        geofenceRegion = region
        manager.startMonitoring(for: region)
        
        AppLogger.data.info("📍 Geofence established: radius \(Config.geofenceRadius)m around \(coordinate.latitude), \(coordinate.longitude)")
    }
    
    // MARK: - Geocoding
    
    /// Geocode address string to coordinates
    private func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            guard let location = placemarks.first?.location else {
                return nil
            }
            return location.coordinate
        } catch {
            AppLogger.data.error("Geocoding failed for \(address): \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Firestore Operations
    
    /// Create visit tracking document in Firestore
    private func createVisitTrackingDocument(visitId: String, clientId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let data: [String: Any] = [
            "visitId": visitId,
            "sitterId": uid,
            "clientId": clientId,
            "startedAt": FieldValue.serverTimestamp(),
            "isActive": true,
            "routePoints": [],
            "totalDistance": 0.0,
            "checkInLocation": NSNull(),
            "checkInTime": NSNull(),
            "autoCheckedIn": false
        ]
        
        try await db.collection("visitTracking").document(visitId).setData(data)
        AppLogger.data.info("📝 Visit tracking document created for visit \(visitId)")
    }
    
    /// Store location history point in Firestore
    private func storeLocationPoint(_ location: CLLocation) async {
        guard let visitId = currentVisitId else { return }
        guard Auth.auth().currentUser?.uid != nil else { return }  // Swift 6: unused value fix
        
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "altitude": location.altitude,
            "horizontalAccuracy": location.horizontalAccuracy,
            "verticalAccuracy": location.verticalAccuracy,
            "speed": location.speed,
            "course": location.course,
            "timestamp": Timestamp(date: location.timestamp)
        ]
        
        // Add to route points array
        try? await db.collection("visitTracking").document(visitId).updateData([
            "routePoints": FieldValue.arrayUnion([locationData]),
            "lastLocation": locationData,
            "lastUpdated": FieldValue.serverTimestamp()
        ])
    }
    
    /// Update current location in real-time (for live map)
    private func updateCurrentLocation(_ location: CLLocation) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let data: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "speed": location.speed,
            "heading": location.course,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try? await db.collection("locations").document(uid).setData(data, merge: true)
    }
    
    /// Finalize route tracking when visit ends
    private func finalizeVisitRoute(visitId: String) async {
        guard !self.routePoints.isEmpty else { return }  // Explicit self for closure
        
        // Calculate total distance traveled
        var totalDistance: CLLocationDistance = 0
        for i in 1..<self.routePoints.count {  // Explicit self for closure
            totalDistance += self.routePoints[i].distance(from: self.routePoints[i-1])  // Explicit self for closure
        }
        
        // Update Firestore with final statistics
        try? await db.collection("visitTracking").document(visitId).updateData([
            "endedAt": FieldValue.serverTimestamp(),
            "isActive": false,
            "totalDistance": totalDistance,
            "totalRoutePoints": self.routePoints.count  // Explicit self for closure
        ])
        
        AppLogger.data.info("📊 Visit \(visitId) finalized: \(totalDistance)m traveled, \(self.routePoints.count) points")  // Explicit self for closure
    }
    
    // MARK: - Auto Check-In
    
    /// Attempt auto check-in if within radius
    private func attemptAutoCheckin(currentLocation: CLLocation) async {
        guard let visitId = currentVisitId,
              let destination = destinationCoordinate,
              !hasAutoCheckedIn else { return }
        
        let destinationLocation = CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        
        let distance = currentLocation.distance(from: destinationLocation)
        
        // Check if within auto check-in radius
        if distance <= Config.autoCheckinRadius {
            AppLogger.data.info("🎯 Auto check-in triggered! Distance: \(Int(distance))m")
            
            // Mark as checked in
            hasAutoCheckedIn = true
            visitStartLocation = currentLocation
            
            // Store check-in in Firestore
            try? await db.collection("visitTracking").document(visitId).updateData([
                "autoCheckedIn": true,
                "checkInTime": FieldValue.serverTimestamp(),
                "checkInLocation": [
                    "latitude": currentLocation.coordinate.latitude,
                    "longitude": currentLocation.coordinate.longitude,
                    "accuracy": currentLocation.horizontalAccuracy
                ],
                "checkInDistance": distance
            ])
            
            // Notify admin and client
            await sendCheckInNotification(visitId: visitId, distance: distance)
            
            // Switch to battery-efficient mode after check-in
            await MainActor.run {
                manager.desiredAccuracy = Config.batteryEfficientAccuracy
                manager.distanceFilter = 50 // Less frequent updates during visit
            }
        }
    }
    
    // MARK: - ETA Calculation & Notifications
    
    /// Calculate and send ETA notification if sitter is 5 minutes away
    private func calculateAndNotifyETA(currentLocation: CLLocation) async {
        guard let visitId = currentVisitId,
              let destination = destinationCoordinate,
              !has5MinuteNotificationSent else { return }
        
        let destinationLocation = CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        
        let distance = currentLocation.distance(from: destinationLocation)
        
        // Estimate time based on average walking speed (1.4 m/s = 5 km/h)
        let averageWalkingSpeed: CLLocationDistance = 1.4 // meters per second
        let estimatedSeconds = distance / averageWalkingSpeed
        let estimatedMinutes = Int(estimatedSeconds / 60)
        
        // Update published ETA
        await MainActor.run {
            estimatedArrivalMinutes = estimatedMinutes
        }
        
        // Send notification if ~5 minutes away
        if estimatedSeconds <= Config.etaThreshold && estimatedSeconds > 240 { // Between 4-5 minutes
            has5MinuteNotificationSent = true
            await send5MinuteAwayNotification(visitId: visitId, eta: estimatedMinutes)
            
            // Update Firestore
            try? await db.collection("visitTracking").document(visitId).updateData([
                "fiveMinuteNotificationSent": true,
                "fiveMinuteNotificationAt": FieldValue.serverTimestamp(),
                "estimatedArrivalMinutes": estimatedMinutes,
                "distanceToDestination": distance
            ])
        }
    }
    
    // MARK: - Route Tracking
    
    /// Record route point if enough time has passed
    private func recordRoutePoint(_ location: CLLocation) async {
        guard currentVisitId != nil else { return }  // Swift 6: unused value fix
        
        // Check if enough time has passed since last update
        if let lastUpdate = lastLocationUpdate {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            guard timeSinceLastUpdate >= Config.routePointInterval else { return }
        }
        
        // Add to route points
        routePoints.append(location)
        lastLocationUpdate = Date()
        
        // Store in Firestore
        await storeLocationPoint(location)
        
        AppLogger.data.debug("📍 Route point recorded: \(self.routePoints.count) total points")  // Explicit self for closure
    }
    
    // MARK: - Location Accuracy Validation
    
    /// Validate location accuracy meets minimum requirements
    private func isLocationAccurate(_ location: CLLocation) -> Bool {
        let isAccurate = location.horizontalAccuracy >= 0 && 
                        location.horizontalAccuracy <= Config.minimumAccuracy
        
        if !isAccurate {
            AppLogger.data.warning("⚠️ Location accuracy poor: \(location.horizontalAccuracy)m (threshold: \(Config.minimumAccuracy)m)")
        }
        
        return isAccurate
    }
    
    // MARK: - Notifications
    
    /// Send notification when sitter is 5 minutes away
    private func send5MinuteAwayNotification(visitId: String, eta: Int) async {
        guard let visitDoc = try? await db.collection("serviceBookings").document(visitId).getDocument(),
              let data = visitDoc.data() else { return }
        _ = data["clientId"] as? String  // Swift 6: unused value fix - will use in future notification targeting
        
        // TODO: Send push notification when notification methods are available
        // For now, log the event
        AppLogger.data.info("Would send notification: Sitter is \(eta) minutes away")
        
        AppLogger.data.info("🔔 5-minute ETA notification sent for visit \(visitId)")
    }
    
    /// Send notification when sitter checks in
    private func sendCheckInNotification(visitId: String, distance: Double) async {
        // TODO: Send push notification when notification methods are available
        // For now, log the event and store in Firestore
        try? await db.collection("notifications").document().setData([
            "type": "checkin",
            "visitId": visitId,
            "message": "Your sitter has checked in within \(Int(distance))m of your location.",
            "timestamp": FieldValue.serverTimestamp()
        ])
        
        AppLogger.data.info("🔔 Check-in notification logged for visit \(visitId)")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Validate location accuracy
        guard isLocationAccurate(location) else {
            AppLogger.data.warning("Skipping inaccurate location update")
            return
        }
        
        // Update published properties
        Task { @MainActor in
            currentLocation = location
            locationAccuracy = location.horizontalAccuracy
        }
        
        // Update current location for live map
        Task {
            await updateCurrentLocation(location)
        }
        
        // Enhanced visit tracking (if active)
        if isTracking, currentVisitId != nil {
            Task {
                // Record route point
                await recordRoutePoint(location)
                
                // Calculate and send ETA notification
                await calculateAndNotifyETA(currentLocation: location)
                
                // Attempt auto check-in
                await attemptAutoCheckin(currentLocation: location)
            }
        }
    }
    
    // MARK: - Geofencing Delegate Methods
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region as? CLCircularRegion != nil,  // Swift 6: unused value fix
              let visitId = currentVisitId,
              region.identifier.hasPrefix("visit-") else { return }
        
        AppLogger.data.info("🚀 Entered geofence for visit \(visitId)")
        
        Task { @MainActor in
            self.isInsideGeofence = true
        }
        
        // Store geofence entry in Firestore
        Task {
            try? await self.db.collection("visitTracking").document(visitId).updateData([
                "enteredGeofenceAt": FieldValue.serverTimestamp(),
                "isInsideGeofence": true
            ])
            
            // Switch to high-accuracy mode when entering geofence
            await MainActor.run {
                manager.desiredAccuracy = Config.highAccuracyForCheckin
                manager.distanceFilter = 5 // Very frequent updates inside geofence
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region as? CLCircularRegion != nil,  // Swift 6: unused value fix
              let visitId = currentVisitId,
              region.identifier.hasPrefix("visit-") else { return }
        
        AppLogger.data.info("🚪 Exited geofence for visit \(visitId)")
        
        Task { @MainActor in
            self.isInsideGeofence = false
        }
        
        // Store geofence exit in Firestore
        Task {
            try? await self.db.collection("visitTracking").document(visitId).updateData([
                "exitedGeofenceAt": FieldValue.serverTimestamp(),
                "isInsideGeofence": false
            ])
            
            // Switch back to battery-efficient mode when exiting
            await MainActor.run {
                manager.desiredAccuracy = Config.batteryEfficientAccuracy
                manager.distanceFilter = 50
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        AppLogger.data.error("❌ Geofence monitoring failed: \(error.localizedDescription)")
    }

    // MARK: - Authorization Delegate Methods
    
    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        AppLogger.data.info("📱 Location authorization changed: \(status.rawValue)")
        
        // If authorized and tracking should be active, ensure it's running
        if isTracking && (status == .authorizedWhenInUse || status == .authorizedAlways) {
            manager.startUpdatingLocation()
        }
    }

    @available(iOS, introduced: 4.2, deprecated: 14.0)
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        AppLogger.data.info("📱 Location authorization changed: \(status.rawValue)")
    }
    
    // MARK: - Error Handling
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.data.error("❌ Location manager failed: \(error.localizedDescription)")
        
        // If error is related to denied permissions, stop tracking
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                AppLogger.data.warning("Location access denied by user")
                stopAllTracking()
            case .network:
                AppLogger.data.warning("Network error in location services")
            default:
                AppLogger.data.error("Location error code: \(clError.code.rawValue)")
            }
        }
    }
}

// MARK: - Public Helper Methods

extension LocationService {
    
    /// Get distance from current location to a coordinate
    func distanceTo(latitude: Double, longitude: Double) -> CLLocationDistance? {
        guard let current = currentLocation else { return nil }
        let destination = CLLocation(latitude: latitude, longitude: longitude)
        return current.distance(from: destination)
    }
    
    /// Check if current location is within radius of an address
    func isWithinRadius(_ radius: CLLocationDistance, of address: String) async -> Bool {
        guard let current = currentLocation,
              let coordinate = try? await geocodeAddress(address) else {
            return false
        }
        
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = current.distance(from: destination)
        return distance <= radius
    }
    
    /// Get route statistics for a visit
    func getRouteStatistics(for visitId: String) async -> RouteStatistics? {
        do {
            let doc = try await db.collection("visitTracking").document(visitId).getDocument()
            guard let data = doc.data() else { return nil }
            
            let totalDistance = data["totalDistance"] as? Double ?? 0
            let totalPoints = data["totalRoutePoints"] as? Int ?? 0
            let autoCheckedIn = data["autoCheckedIn"] as? Bool ?? false
            
            return RouteStatistics(
                visitId: visitId,
                totalDistance: totalDistance,
                totalPoints: totalPoints,
                autoCheckedIn: autoCheckedIn
            )
        } catch {
            AppLogger.data.error("Failed to fetch route statistics: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get full route history for admin review
    func getRouteHistory(for visitId: String) async -> [LocationPoint]? {
        do {
            let doc = try await db.collection("visitTracking").document(visitId).getDocument()
            guard let data = doc.data(),
                  let routeData = data["routePoints"] as? [[String: Any]] else {
                return nil
            }
            
            let points = routeData.compactMap { pointData -> LocationPoint? in
                guard let lat = pointData["latitude"] as? Double,
                      let lng = pointData["longitude"] as? Double,
                      let timestamp = pointData["timestamp"] as? Timestamp else {
                    return nil
                }
                
                return LocationPoint(
                    latitude: lat,
                    longitude: lng,
                    altitude: pointData["altitude"] as? Double ?? 0,
                    horizontalAccuracy: pointData["horizontalAccuracy"] as? Double ?? 0,
                    speed: pointData["speed"] as? Double ?? 0,
                    course: pointData["course"] as? Double ?? 0,
                    timestamp: timestamp.dateValue()
                )
            }
            
            return points
        } catch {
            AppLogger.data.error("Failed to fetch route history: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Supporting Models

/// Location point data structure
struct LocationPoint: Codable, Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let speed: Double  // meters per second
    let course: Double  // degrees
    let timestamp: Date
    
    init(id: String = UUID().uuidString, latitude: Double, longitude: Double, altitude: Double, horizontalAccuracy: Double, speed: Double, course: Double, timestamp: Date) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.course = course
        self.timestamp = timestamp
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var speedKmh: Double {
        speed * 3.6  // Convert m/s to km/h
    }
}

/// Route statistics summary
struct RouteStatistics {
    let visitId: String
    let totalDistance: Double  // meters
    let totalPoints: Int
    let autoCheckedIn: Bool
    
    var totalDistanceKm: Double {
        totalDistance / 1000.0
    }
    
    var totalDistanceMiles: Double {
        totalDistance * 0.000621371
    }
}
