<!-- 52dbd0cb-71da-43c2-90bd-49a0b440a2b3 ff38ea6e-0134-4429-9f4c-7bd736a45d85 -->
# Live Map of All Active Sitters

## Implementation Approach

Create a unified live map component that displays all active sitters in real-time, with the ability to toggle between the current individual visit cards view and the new unified map view.

## Key Components

### 1. Create UnifiedLiveMapView Component

**New file**: `SaviPets/Views/UnifiedLiveMapView.swift`

This component will:

- Accept array of `LiveVisit` objects as input
- Listen to Firestore `locations` collection for each active sitterId
- Display all sitters on a single map with custom markers
- Auto-calculate map region to fit all sitter locations
- Show marker callouts with visit details on tap

Key implementation details:

```swift
// Use @Published dictionary to track all sitter locations
@Published var sitterLocations: [String: CLLocationCoordinate2D] = [:]

// Listen to locations/{sitterId} for each active visit
// Update map region using MKCoordinateRegion to fit all markers

// Custom map marker showing:
// - Sitter name
// - Client name  
// - Time remaining (calculated from scheduledEnd - Date())
// - Status indicator color
```

### 2. Add Toggle to AdminDashboardView

**File**: `SaviPets/Dashboards/AdminDashboardView.swift` (lines 202-267)

Modifications to the `liveVisits` computed property:

- Add `@State private var showUnifiedMap: Bool = false`
- Add toggle button next to the "Refresh" button in the header (line 211)
- Conditionally render either:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Current individual visit cards (lines 226-235)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - New `UnifiedLiveMapView(visits: activeVisits)` component
```swift
// Add toggle button in header
Button(action: { showUnifiedMap.toggle() }) {
    Image(systemName: showUnifiedMap ? "list.bullet" : "map")
    Text(showUnifiedMap ? "List" : "Map")
}
```


### 3. Multi-Location Listener

Create an ObservableObject to manage multiple location listeners efficiently:

```swift
class MultiSitterLocationListener: ObservableObject {
    @Published var locations: [String: CLLocationCoordinate2D] = [:]
    private var listeners: [String: ListenerRegistration] = [:]
    
    func startListening(to sitterIds: [String]) {
        // Remove old listeners not in new list
        // Add listeners for new sitter IDs
        // Update locations dictionary on changes
    }
    
    func stopAll() {
        // Clean up all listeners
    }
}
```

### 4. Map Region Auto-Fit Calculation

Utility function to calculate region encompassing all markers:

```swift
func calculateMapRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
    guard !coordinates.isEmpty else {
        // Default to San Francisco area
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                                 span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    }
    
    // Calculate min/max lat/lng
    // Add 20% padding to span
    // Return region
}
```

### 5. Marker Detail View

When marker is tapped, show callout with:

- Client name (bold)
- Sitter name
- Address (if available)
- Time remaining until scheduledEnd
- Status with colored indicator
- Quick action buttons (View Details, Message Sitter, End Visit)

Use `.annotationSubtitle` or custom annotation view with detail disclosure.

## Technical Details

**Firestore Structure** (already exists):

```
locations/{sitterId}
 - lat: number
 - lng: number  
 - updatedAt: timestamp
```

**SwiftUI Map API**:

```swift
Map(coordinateRegion: $region, 
    annotationItems: sitterAnnotations) { item in
    MapAnnotation(coordinate: item.coordinate) {
        // Custom marker view
    }
}
```

**Real-time Updates**:

- Use `addSnapshotListener` for each sitter location
- Automatically update map when locations change
- Update region if new sitters appear

**Performance Considerations**:

- Limit to active visits only (already filtered via `inProgressVisits`)
- Debounce region updates to avoid excessive recalculations
- Remove listeners when view disappears or sitters become inactive

## Files to Modify

1. **SaviPets/Dashboards/AdminDashboardView.swift**

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Add `@State private var showUnifiedMap: Bool = false`
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Add toggle button in liveVisits header (around line 211)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Add conditional rendering of UnifiedLiveMapView (around line 216)

2. **Create: SaviPets/Views/UnifiedLiveMapView.swift** (new file)

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Main map component with multi-sitter tracking
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - MultiSitterLocationListener class
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - SitterAnnotation model
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Map region calculation utilities

3. **Update: SaviPets.xcodeproj/project.pbxproj** (if needed)

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - Add new UnifiedLiveMapView.swift file to project

## Design System Compliance

- Use `SPCard` for detail overlays
- Use `SPDesignSystem.Colors` for status indicators
- Use `SPDesignSystem.Typography` for text styles
- Follow color scheme awareness with `primaryAdjusted(colorScheme)`
- Status colors: green (in_progress), yellow (delayed), red (issue)

### To-dos

- [ ] Create UnifiedLiveMapView component with multi-sitter location tracking and auto-fit region calculation
- [ ] Add toggle button in AdminDashboardView liveVisits section to switch between list and map views
- [ ] Implement detailed marker annotations showing visit info with action buttons
- [ ] Test real-time location updates and verify map auto-updates as sitters move