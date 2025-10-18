# Visit Timer System - Quick Reference Guide

## 🚀 Quick Start

### For Developers

**Key Files**:
- `SitterDashboardView.swift` - Main timer UI and logic
- `firestore.rules` - Security rules for visit updates
- `firestore.indexes.json` - Required database indexes

**Key State Variables**:
```swift
@State private var actualStartTimes: [String: Date] = [:]  // visitId -> actual start
@State private var actualEndTimes: [String: Date] = [:]    // visitId -> actual end
@State private var pendingWrites: Set<String> = []         // visitIds with pending writes
```

**Key Firestore Fields**:
```
visits/{visitId}/
  ├─ scheduledStart: Timestamp           # Never changes
  ├─ scheduledEnd: Timestamp             # Never changes
  ├─ timeline.checkIn.timestamp: Timestamp?   # Set when sitter taps "Start"
  └─ timeline.checkOut.timestamp: Timestamp?  # Set when sitter taps "End"
```

---

## 🔧 Common Tasks

### Debugging Timer Issues

**1. Timer not counting down**
```swift
// Add to VisitCard
print("🔍 Timer Debug:")
print("  actualStartTime: \(String(describing: actualStartTime))")
print("  scheduledEndTime: \(scheduledEndTime)")
print("  isVisitStarted: \(isVisitStarted)")
print("  timerTick: \(timerTick)")
```

**2. Pending indicator stuck**
```swift
// Check pending writes
print("🔍 Pending Writes: \(pendingWrites)")
print("🔍 Is Pending: \(isPendingWrite)")
```

**3. Times not syncing from Firestore**
```swift
// Add to loadVisitsRealtime() listener
print("📊 Snapshot metadata:")
print("  isFromCache: \(snapshot.metadata.isFromCache)")
print("  hasPendingWrites: \(snapshot.metadata.hasPendingWrites)")
print("  checkIn from Firestore: \(data["timeline.checkIn.timestamp"])")
```

---

### Adding New Timer Features

**Pattern to follow**:
1. Add `@State` variable in parent view (`SitterDashboardView`)
2. Pass as `@Binding` to `VisitCard`
3. Update Firestore with `updateData()` and server timestamp
4. Update listener to populate new state variable
5. Add UI in `VisitCard` that reacts to state changes

**Example - Adding pause/resume**:
```swift
// 1. Add state in SitterDashboardView
@State private var pausedVisits: Set<String> = []

// 2. Pass to VisitCard
VisitCard(
    visit: visit,
    pausedVisits: $pausedVisits,
    // ... other bindings
)

// 3. Write to Firestore in VisitCard
func pauseVisit() {
    pausedVisits.insert(visit.id)
    
    Firestore.firestore().collection("visits").document(visit.id)
        .updateData([
            "timeline.paused.timestamp": FieldValue.serverTimestamp(),
            "status": "paused"
        ]) { error in
            if error != nil {
                pausedVisits.remove(visit.id)
            }
        }
}

// 4. Update listener in loadVisitsRealtime()
if let pausedTimestamp = data["timeline.paused.timestamp"] as? Timestamp {
    pausedVisits.insert(doc.documentID)
}

// 5. Add UI
if isPaused {
    Button("Resume") { resumeVisit() }
} else {
    Button("Pause") { pauseVisit() }
}
```

---

### Modifying Firestore Security Rules

**Location**: `firestore.rules`

**Test locally before deploying**:
```bash
# Install emulator
firebase emulators:start --only firestore

# Run tests against emulator
# (Add your test cases in SaviPetsTests/)
```

**Deploy to production**:
```bash
firebase deploy --only firestore:rules
```

**Common patterns**:
```javascript
// Allow only if field is being set for first time
!('actualStart' in resource.data) && ('actualStart' in request.resource.data)

// Allow only admin to modify existing field
('actualStart' in resource.data) && isAdmin()

// Validate timestamp is not in future
request.resource.data.actualStart <= request.time
```

---

## 🧪 Testing Checklist (Condensed)

### Before Each Release
- [ ] Start visit → timer counts up, countdown works
- [ ] End visit → times saved correctly
- [ ] Undo → resets to scheduled state
- [ ] Offline start → syncs when online
- [ ] Multiple devices → updates in real-time
- [ ] Early start → shows "Started X min early"
- [ ] Overtime → shows "+MM:SS" in red

### Performance Check
```bash
# Build without warnings
xcodebuild clean build -scheme SaviPets -destination 'platform=iOS Simulator,name=iPhone 15'

# Check for memory leaks
# Run Instruments → Leaks while navigating to/from dashboard
```

---

## 📊 Key Metrics to Monitor

### In Firebase Console
1. **Firestore Usage**:
   - Document reads (should not spike on timer ticks)
   - Document writes (one per start, one per end)
   - Listener connections (should match active users)

2. **Errors**:
   - Security rule violations (investigate immediately)
   - Failed writes (check network/permissions)

### In Xcode Console
```bash
# Filter for timer logs
grep "🔍\|⏳\|✅\|❌" console.log

# Check for warnings
grep "⚠️" console.log

# Monitor pending writes
grep "Pending" console.log
```

---

## 🔥 Firestore Best Practices

### DO ✅
```swift
// Use server timestamps
"actualStart": FieldValue.serverTimestamp()

// Use updateData for nested fields
updateData(["timeline.checkIn.timestamp": ...])

// Handle errors
visitRef.updateData([...]) { error in
    if let error = error {
        print("Error: \(error)")
        // Show to user
    }
}

// Remove listeners
deinit {
    visitsListener?.remove()
}
```

### DON'T ❌
```swift
// Don't use client time
"actualStart": Timestamp(date: Date()) // ❌ Clock skew!

// Don't use setData for nested fields
setData(["timeline.checkIn.timestamp": ...], merge: true) // ❌ Creates literal field name!

// Don't ignore errors
visitRef.updateData([...]) // ❌ No error handling

// Don't forget to remove listeners
// (Memory leak!)
```

---

## 🆘 Emergency Fixes

### Users reporting wrong times

**Quick check**:
1. Open Firestore console → find affected visit
2. Check `timeline.checkIn.timestamp` exists and is correct
3. Check device timezone matches expected
4. Check for clock skew (compare device time to server time)

**Quick fix**:
```swift
// Add fallback in actualStartTime computed property
var actualStartTime: Date {
    if let actual = actualStartTimes[visit.id] {
        return actual
    }
    if let checkIn = visit.checkIn {
        return checkIn
    }
    // Last resort - log error and use scheduled
    print("⚠️ No actual start time for visit \(visit.id), using scheduled")
    return visit.start
}
```

### Pending indicator won't clear

**Quick fix**:
```swift
// Add timeout to startVisit() / completeVisit()
let visitId = visit.id
pendingWrites.insert(visitId)

// Auto-clear after 30 seconds
DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
    if pendingWrites.contains(visitId) {
        print("⚠️ Clearing stuck pending write for \(visitId)")
        pendingWrites.remove(visitId)
    }
}
```

### Timer not ticking

**Quick fix**:
```swift
// Ensure timer is in correct state
.onReceive(timer) { _ in
    guard isVisitStarted,  // Must be started
          !isVisitCompleted,  // Must not be completed
          actualStartTime != nil  // Must have actual start
    else { return }
    
    timerTick += 1  // Force UI update
}
```

---

## 📚 Code Snippets Library

### Format time duration
```swift
func formatDuration(_ seconds: TimeInterval) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", mins, secs)
}
```

### Format time with timezone
```swift
func formatTime(_ date: Date, timezone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.timeZone = timezone
    return formatter.string(from: date)
}
```

### Check if visit is overtime
```swift
func isOvertime(actualStart: Date, scheduledDuration: TimeInterval) -> Bool {
    let elapsed = Date().timeIntervalSince(actualStart)
    return elapsed > scheduledDuration
}
```

### Calculate early/late minutes
```swift
func startVariance(actual: Date, scheduled: Date) -> Int {
    let difference = actual.timeIntervalSince(scheduled)
    return Int(difference / 60)  // Convert to minutes
}
```

---

## 🎯 Performance Optimization

### Reduce Firestore Reads
```swift
// ✅ Good - One listener for all visits
.addSnapshotListener { snapshot, error in
    // Process all visits at once
}

// ❌ Bad - One listener per visit
visits.forEach { visit in
    .addSnapshotListener { snapshot, error in
        // Separate listener for each visit
    }
}
```

### Optimize Timer Updates
```swift
// ✅ Good - Update only when needed
.onReceive(timer) { _ in
    guard isVisitStarted && !isVisitCompleted else { return }
    timerTick += 1
}

// ❌ Bad - Always update
.onReceive(timer) { _ in
    timerTick += 1  // Even when not started!
}
```

### Cache Date Formatters
```swift
// ✅ Good - Reuse formatters
private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

// ❌ Bad - Create new formatter each time
func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()  // Expensive!
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
}
```

---

## 🔗 Quick Links

- **Full Documentation**: `TIMER_FIX_COMPREHENSIVE_SUMMARY.md`
- **PR Summary**: `TIMER_FIX_PR.md`
- **Testing Checklist**: `TIMER_TESTING_CHECKLIST.md`
- **Firestore Rules**: `firestore.rules`
- **Firestore Indexes**: `firestore.indexes.json`

---

## 📞 Support

**For timer issues**:
1. Check console logs for 🔍 debug messages
2. Verify Firestore document structure in console
3. Test offline behavior in simulator
4. Check this guide for common fixes

**For Firestore issues**:
1. Check security rules in Firebase console
2. Verify indexes are deployed
3. Check usage limits (free tier: 50K reads/day)
4. Review error logs in Firebase console

---

*Quick Reference v1.0 - Last Updated: October 8, 2025*

