import SwiftUI
import MapKit
import FirebaseFirestore
import Combine
import OSLog

// MARK: - Privacy Compliance
/// This component tracks ONLY sitter locations via Firestore locations/{sitterId}
/// Pet owner locations are NEVER tracked or accessed to protect user privacy
/// Only sitters with active visits have their GPS location monitored in real-time

// MARK: - Sitter Annotation Model
struct SitterAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let visit: LiveVisit
    
    var sitterName: String { visit.sitterName }
    var clientName: String { visit.clientName }
    var status: String { visit.status }
    var scheduledEnd: Date { visit.scheduledEnd }
    var address: String? { visit.address }
    var serviceSummary: String { visit.serviceSummary }
    var pets: [String] { visit.pets }
    var note: String { visit.note }
    
    var statusColor: Color {
        switch status {
        case "in_progress": return .green
        case "delayed": return .yellow
        case "issue": return .red
        default: return .gray
        }
    }
    
    var timeRemaining: String {
        let remaining = scheduledEnd.timeIntervalSince(Date())
        if remaining <= 0 {
            return "Overdue"
        }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }
}

// MARK: - Multi-Sitter Location Listener
/// Manages real-time GPS location tracking for active sitters
/// PRIVACY: This listener ONLY tracks sitter locations (via locations/{sitterId})
/// It NEVER tracks or accesses pet owner locations for privacy protection
final class MultiSitterLocationListener: ObservableObject {
    @Published var locations: [String: CLLocationCoordinate2D] = [:]
    @Published var locationsUpdateTrigger: Int = 0
    private var listeners: [String: ListenerRegistration] = [:]
    private let db = Firestore.firestore()
    
    /// Starts listening to real-time GPS locations for the specified sitters
    /// - Parameter sitterIds: Array of sitter user IDs (NOT pet owner IDs)
    /// - Important: Only sitter locations are tracked. Owner locations are never accessed.
    func startListening(to sitterIds: [String]) {
        let currentIds = Set(sitterIds)
        let existingIds = Set(listeners.keys)
        
        // Remove listeners for sitters no longer in the list
        let toRemove = existingIds.subtracting(currentIds)
        for sitterId in toRemove {
            listeners[sitterId]?.remove()
            listeners.removeValue(forKey: sitterId)
            Task { @MainActor in
                self.locations.removeValue(forKey: sitterId)
                self.locationsUpdateTrigger += 1
            }
        }
        
        // Add listeners for new sitters
        let toAdd = currentIds.subtracting(existingIds)
        for sitterId in toAdd {
            guard !sitterId.isEmpty else { continue }
            
            // PRIVACY: Listen to locations/{sitterId} where sitterId is the SITTER's user ID
            // This collection only contains sitter GPS locations updated by LocationService
            // Pet owners never update this collection, ensuring owner privacy
            let listener = db.collection("locations").document(sitterId)
                .addSnapshotListener { [weak self] document, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        AppLogger.ui.error("Error listening to location for sitter \(sitterId): \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = document?.data(),
                          let lat = data["lat"] as? CLLocationDegrees,
                          let lng = data["lng"] as? CLLocationDegrees else {
                        return
                    }
                    
                    Task { @MainActor in
                        self.locations[sitterId] = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        self.locationsUpdateTrigger += 1
                    }
                }
            
            listeners[sitterId] = listener
        }
    }
    
    func stopAll() {
        // Remove all listeners
        for (sitterId, listener) in listeners {
            listener.remove()
            listeners.removeValue(forKey: sitterId)
        }
        
        // Clear locations on main thread
        Task { @MainActor in
            self.locations.removeAll()
            self.locationsUpdateTrigger += 1
        }
    }
    
    deinit {
        // Cleanup synchronously on deinit
        for listener in listeners.values {
            listener.remove()
        }
        listeners.removeAll()
    }
}

// MARK: - Unified Live Map View
struct UnifiedLiveMapView: View {
    @Environment(\.colorScheme) private var colorScheme
    let visits: [LiveVisit]
    
    @StateObject private var locationListener = MultiSitterLocationListener()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedAnnotation: SitterAnnotation?
    @State private var showDetails: Bool = false
    @State private var detailsVisit: LiveVisit? = nil
    
    var sitterAnnotations: [SitterAnnotation] {
        var annotations: [SitterAnnotation] = []
        for visit in visits {
            if let coordinate = locationListener.locations[visit.sitterId] {
                annotations.append(SitterAnnotation(
                    id: visit.id,
                    coordinate: coordinate,
                    visit: visit
                ))
            }
        }
        return annotations
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(coordinateRegion: $region, annotationItems: sitterAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    SitterMarkerView(annotation: annotation) {
                        selectedAnnotation = annotation
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .task {
                await startTrackingAsync()
            }
            .onChange(of: visits) { _ in
                Task {
                    await updateTrackingAsync()
                }
            }
            .onChange(of: locationListener.locationsUpdateTrigger) { _ in
                Task {
                    await updateMapRegionAsync()
                }
            }
            .onDisappear {
                locationListener.stopAll()
            }
            
            // Recenter button
            if !sitterAnnotations.isEmpty {
                Button(action: updateMapRegion) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .padding()
            }
        }
        .sheet(item: $selectedAnnotation) { annotation in
            SitterDetailSheet(
                annotation: annotation,
                onViewDetails: {
                    selectedAnnotation = nil
                    detailsVisit = annotation.visit
                    showDetails = true
                },
                onMessageSitter: {
                    selectedAnnotation = nil
                    // TODO: Implement messaging
                },
                onEndVisit: {
                    selectedAnnotation = nil
                    endVisit(annotation.visit)
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDetails) {
            if let visit = detailsVisit {
                NavigationStack {
                    VisitDetailsView(visit: visit)
                        .navigationTitle("Visit Details")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showDetails = false
                                    detailsVisit = nil
                                }
                            }
                        }
                }
                .presentationDetents([.large])
            }
        }
    }
    
    private func startTrackingAsync() async {
        // PRIVACY: Extract ONLY sitter IDs from visits (never owner IDs)
        let sitterIds = visits.map { $0.sitterId }
        locationListener.startListening(to: sitterIds)
        
        // Initial region update after short delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        await updateMapRegionAsync()
    }
    
    private func updateTrackingAsync() async {
        // PRIVACY: Extract ONLY sitter IDs from visits (never owner IDs)
        let sitterIds = visits.map { $0.sitterId }
        locationListener.startListening(to: sitterIds)
        await updateMapRegionAsync()
    }
    
    private func updateMapRegionAsync() async {
        let coordinates = Array(locationListener.locations.values)
        let newRegion = calculateMapRegion(for: coordinates)
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                region = newRegion
            }
        }
    }
    
    // Synchronous version for button action
    private func updateMapRegion() {
        Task {
            await updateMapRegionAsync()
        }
    }
    
    private func calculateMapRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            // Default to San Francisco area
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        // Single coordinate case
        if coordinates.count == 1 {
            return MKCoordinateRegion(
                center: coordinates[0],
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // Calculate bounds
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLng = coordinates[0].longitude
        var maxLng = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLng = min(minLng, coord.longitude)
            maxLng = max(maxLng, coord.longitude)
        }
        
        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (minLng + maxLng) / 2
        
        // Calculate span with 20% padding
        let latDelta = (maxLat - minLat) * 1.2
        let lngDelta = (maxLng - minLng) * 1.2
        
        // Ensure minimum span
        let minSpan = 0.01
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, minSpan),
                longitudeDelta: max(lngDelta, minSpan)
            )
        )
    }
    
    private func endVisit(_ visit: LiveVisit) {
        let db = Firestore.firestore()
        db.collection("visits").document(visit.id).setData([
            "status": "completed",
            "timeline.checkOut.timestamp": FieldValue.serverTimestamp()
        ], merge: true)
    }
}

// MARK: - Sitter Marker View
private struct SitterMarkerView: View {
    let annotation: SitterAnnotation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Status indicator
                Circle()
                    .fill(annotation.statusColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "figure.walk")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Pointer
                Triangle()
                    .fill(annotation.statusColor)
                    .frame(width: 10, height: 8)
                    .offset(y: -1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Triangle Shape for Marker Pointer
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Sitter Detail Sheet
private struct SitterDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let annotation: SitterAnnotation
    let onViewDetails: () -> Void
    let onMessageSitter: () -> Void
    let onEndVisit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Circle()
                    .fill(annotation.statusColor)
                    .frame(width: 12, height: 12)
                
                Text(annotation.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(SPDesignSystem.Typography.footnote())
                    .foregroundColor(annotation.statusColor)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Visit Info - Sitter details FIRST (most important for tracking)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sitter")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                    Text(annotation.sitterName)
                        .font(SPDesignSystem.Typography.heading3())
                }
                
                if !annotation.serviceSummary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Service")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        Text(annotation.serviceSummary)
                            .font(SPDesignSystem.Typography.body())
                    }
                }
                
                if !annotation.pets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pet\(annotation.pets.count > 1 ? "s" : "")")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        Text(annotation.pets.joined(separator: ", "))
                            .font(SPDesignSystem.Typography.body())
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Client")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                    Text(annotation.clientName)
                        .font(SPDesignSystem.Typography.body())
                }
                
                if let address = annotation.address, !address.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Address")
                            .font(SPDesignSystem.Typography.footnote())
                            .foregroundColor(.secondary)
                        Text(address)
                            .font(SPDesignSystem.Typography.body())
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time Remaining")
                        .font(SPDesignSystem.Typography.footnote())
                        .foregroundColor(.secondary)
                    Text(annotation.timeRemaining)
                        .font(SPDesignSystem.Typography.body())
                        .foregroundColor(annotation.timeRemaining == "Overdue" ? .red : .primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: {
                    dismiss()
                    onViewDetails()
                }) {
                    Text("View Full Details")
                        .font(SPDesignSystem.Typography.body())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        dismiss()
                        onMessageSitter()
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Message")
                        }
                        .font(SPDesignSystem.Typography.body())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        dismiss()
                        onEndVisit()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("End Visit")
                        }
                        .font(SPDesignSystem.Typography.body())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Visit Details View
private struct VisitDetailsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let visit: LiveVisit
    
    private var statusColor: Color {
        switch visit.status {
        case "in_progress", "in_adventure": return .green
        case "delayed": return .yellow
        case "issue": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section with Sitter Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(visit.sitterName)
                        .font(SPDesignSystem.Typography.heading1())
                    
                    if !visit.serviceSummary.isEmpty {
                        HStack {
                            Image(systemName: "briefcase.fill")
                                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                            Text(visit.serviceSummary)
                                .font(SPDesignSystem.Typography.heading3())
                        }
                    }
                    
                    if !visit.pets.isEmpty {
                        HStack {
                            Image(systemName: "pawprint.fill")
                                .foregroundColor(SPDesignSystem.Colors.primaryAdjusted(colorScheme))
                            Text(visit.pets.joined(separator: ", "))
                                .font(SPDesignSystem.Typography.body())
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SPDesignSystem.Colors.primaryAdjusted(colorScheme).opacity(0.1))
                .cornerRadius(12)
                
                // Status & Client Info
                SPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Status")
                                .font(SPDesignSystem.Typography.footnote())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(visit.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(SPDesignSystem.Typography.body())
                                .foregroundColor(statusColor)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Client")
                                .font(SPDesignSystem.Typography.footnote())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(visit.clientName)
                                .font(SPDesignSystem.Typography.body())
                        }
                    }
                }
                
                SPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schedule")
                            .font(SPDesignSystem.Typography.heading3())
                        
                        HStack {
                            Text("Start")
                                .font(SPDesignSystem.Typography.footnote())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(visit.scheduledStart.formatted(date: .abbreviated, time: .shortened))
                                .font(SPDesignSystem.Typography.body())
                        }
                        
                        HStack {
                            Text("End")
                                .font(SPDesignSystem.Typography.footnote())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(visit.scheduledEnd.formatted(date: .abbreviated, time: .shortened))
                                .font(SPDesignSystem.Typography.body())
                        }
                        
                        if let checkIn = visit.checkIn {
                            Divider()
                            HStack {
                                Text("Checked In")
                                    .font(SPDesignSystem.Typography.footnote())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(checkIn.formatted(date: .omitted, time: .shortened))
                                    .font(SPDesignSystem.Typography.body())
                            }
                        }
                        
                        if let checkOut = visit.checkOut {
                            HStack {
                                Text("Checked Out")
                                    .font(SPDesignSystem.Typography.footnote())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(checkOut.formatted(date: .omitted, time: .shortened))
                                    .font(SPDesignSystem.Typography.body())
                            }
                        }
                    }
                }
                
                if let address = visit.address, !address.isEmpty {
                    SPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Address")
                                .font(SPDesignSystem.Typography.heading3())
                            Text(address)
                                .font(SPDesignSystem.Typography.body())
                        }
                    }
                }
                
                if !visit.serviceSummary.isEmpty {
                    SPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Service")
                                .font(SPDesignSystem.Typography.heading3())
                            Text(visit.serviceSummary)
                                .font(SPDesignSystem.Typography.body())
                        }
                    }
                }
                
                if !visit.pets.isEmpty {
                    SPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pet\(visit.pets.count > 1 ? "s" : "")")
                                .font(SPDesignSystem.Typography.heading3())
                            Text(visit.pets.joined(separator: ", "))
                                .font(SPDesignSystem.Typography.body())
                        }
                    }
                }
                
                if !visit.note.isEmpty {
                    SPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(SPDesignSystem.Typography.heading3())
                            Text(visit.note)
                                .font(SPDesignSystem.Typography.body())
                        }
                    }
                }
                
                // Debug: Show if data is missing
                if visit.serviceSummary.isEmpty && visit.pets.isEmpty && visit.note.isEmpty {
                    SPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                Text("Some visit details are not available")
                                    .font(SPDesignSystem.Typography.body())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(SPDesignSystem.Colors.background(scheme: colorScheme))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
#Preview {
    let sampleVisits = [
        LiveVisit(
            id: "1",
            clientName: "John Doe",
            sitterName: "Jane Smith",
            sitterId: "sitter1",
            scheduledStart: Date(),
            scheduledEnd: Date().addingTimeInterval(3600),
            checkIn: Date(),
            checkOut: nil,
            status: "in_progress",
            address: "123 Main St, San Francisco, CA",
            serviceSummary: "Dog Walking",
            pets: ["Max", "Bella"],
            petPhotoURLs: [],
            note: "Max needs to stay on leash"
        )
    ]
    
    return UnifiedLiveMapView(visits: sampleVisits)
}

