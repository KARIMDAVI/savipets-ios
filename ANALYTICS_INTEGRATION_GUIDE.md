# Analytics Integration Guide

## Overview
This guide shows where to add AnalyticsManager tracking calls throughout the SaviPets app.

---

## 📍 INTEGRATION POINTS

### 1. Authentication (AuthViewModel.swift)
**Already Integrated:** ✅
```swift
// In signIn():
AnalyticsManager.trackUserSignIn(userId: uid, role: role, method: "email")

// TODO: Add to signUp() when user registration completes:
AnalyticsManager.trackUserSignUp(userId: uid, role: role, method: "email")

// TODO: Add to signOut():
AnalyticsManager.trackUserSignOut()
```

---

### 2. Service Bookings (BookServiceView.swift)
**Location:** After successful booking creation

```swift
// In submitBooking() after Firestore write succeeds:
AnalyticsManager.trackBookingCreated(
    serviceType: selectedService,
    price: estimatedCost,
    duration: selectedDuration,
    sitterId: selectedSitter.id,
    clientId: Auth.auth().currentUser?.uid ?? ""
)
```

---

### 3. Visit Management (VisitTimerViewModel.swift)
**Locations:** startVisit(), endVisit()

```swift
// In startVisit() after successful start:
AnalyticsManager.trackVisitStarted(
    visitId: visitId,
    sitterId: sitterId,
    clientId: clientId,
    serviceType: serviceSummary
)

// In endVisit() after successful end:
let duration = Int(actualEnd.timeIntervalSince(actualStart) / 60)
let wasOvertime = isOvertime
AnalyticsManager.trackVisitEnded(
    visitId: visitId,
    sitterId: sitterId,
    duration: duration,
    wasOvertime: wasOvertime
)

// When overtime detected:
AnalyticsManager.trackVisitOvertime(
    visitId: visitId,
    overtimeMinutes: overtimeMinutes
)
```

---

### 4. Chat Messages (ConversationChatView.swift / ResilientChatService.swift)
**Location:** After message sent successfully

```swift
// In sendMessageSmart() after successful send:
AnalyticsManager.trackMessageSent(
    conversationId: conversationId,
    messageLength: text.count,
    senderRole: currentUserRole.rawValue,
    isAdminInquiry: conversationType == .adminInquiry
)
```

---

### 5. Pet Profiles (PetProfileView.swift / PetDataService.swift)
**Locations:** Pet creation and updates

```swift
// After creating new pet:
AnalyticsManager.trackPetProfileCreated(
    petId: petId,
    petType: pet.species,
    ownerId: Auth.auth().currentUser?.uid ?? ""
)

// After updating pet:
AnalyticsManager.trackPetProfileUpdated(
    petId: petId,
    petType: pet.species
)
```

---

### 6. Screen Views (All Dashboard Views)
**Location:** Add to each main view's onAppear

```swift
// OwnerDashboardView:
.trackScreen(name: "Owner Dashboard")

// SitterDashboardView:
.trackScreen(name: "Sitter Dashboard")

// AdminDashboardView:
.trackScreen(name: "Admin Dashboard")

// PetProfileView:
.trackScreen(name: "Pet Profile")

// ConversationChatView:
.trackScreen(name: "Chat Conversation")
```

---

### 7. Error Tracking (Throughout App)
**Location:** All catch blocks

```swift
// In catch blocks:
AnalyticsManager.trackError(
    error: error,
    context: "Booking Creation",
    isCritical: false
)
```

---

### 8. Feature Usage (Custom Features)
**Examples:**

```swift
// When user uses map navigation:
AnalyticsManager.trackFeatureUsed(
    feature: "map_navigation",
    userRole: appState.role,
    metadata: ["visit_id": visitId]
)

// When user uploads photo:
AnalyticsManager.trackFeatureUsed(
    feature: "photo_upload",
    userRole: appState.role,
    metadata: ["pet_id": petId]
)
```

---

## 🎯 PRIORITY TRACKING

### High Priority (Implement First):
1. ✅ User sign in/sign up/sign out
2. ⏳ Booking created
3. ⏳ Visit started/ended
4. ⏳ Chat message sent
5. ⏳ Pet profile created

### Medium Priority:
6. ⏳ Screen views (dashboards)
7. ⏳ Error tracking
8. ⏳ Visit overtime
9. ⏳ Booking approved/completed

### Low Priority:
10. ⏳ Feature usage tracking
11. ⏳ Pet profile updated

---

## 📊 VIEWING ANALYTICS

### Firebase Console:
1. Go to Firebase Console → Analytics
2. View Events tab
3. Filter by event name
4. Check user properties segmentation

### Custom Dashboards:
- Create custom dashboards for key metrics
- Set up conversion funnels
- Track user retention

---

## ⚙️ CONFIGURATION

### Remote Config Parameters:
All configurable via RemoteConfigManager:

```swift
// Feature flags:
RemoteConfigManager.shared.enableChatApproval
RemoteConfigManager.shared.enableLocationTracking
RemoteConfigManager.shared.maintenanceMode

// Values:
RemoteConfigManager.shared.maxMessageLength
RemoteConfigManager.shared.minBookingAdvanceHours
RemoteConfigManager.shared.chatBatchDelay

// Business rules:
RemoteConfigManager.shared.cancellationPolicyHours
RemoteConfigManager.shared.supportEmail
```

---

## 🔍 DEBUGGING

### Check if analytics is working:
```swift
// Enable debug mode in development
Analytics.setAnalyticsCollectionEnabled(true)

// View in Xcode console:
// -FIRDebugEnabled in scheme arguments
```

### DebugView in Firebase Console:
1. Firebase Console → Analytics → DebugView
2. Run app with debug enabled
3. See real-time events

---

## ✅ IMPLEMENTATION CHECKLIST

- ✅ AnalyticsManager created
- ✅ RemoteConfigManager created
- ✅ PerformanceMonitor created
- ✅ ErrorBoundary created
- ✅ User sign in tracking added
- ⏳ Add tracking to booking creation
- ⏳ Add tracking to visit start/end
- ⏳ Add tracking to chat messages
- ⏳ Add tracking to pet profiles
- ⏳ Add screen view tracking
- ⏳ Deploy Remote Config values

---

**Next Steps:** Add tracking calls to the locations listed above




