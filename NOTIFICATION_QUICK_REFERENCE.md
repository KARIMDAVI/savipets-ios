# Notification System - Quick Reference 🔔

## When Notifications Are Sent

| Event | Trigger | Recipients | Notification Title |
|-------|---------|------------|-------------------|
| **Visit Start** | Sitter clicks "Start Visit" | Admin + Pet Owner | "Visit Started" |
| **New Booking** | Pet Owner books a service | Admin | "New Booking" |
| **Needs Approval** | Booking created with pending status | Admin | "Booking Needs Approval" |

---

## How to Use

### Send Visit Start Notification
```swift
// Automatic - no code needed!
// Triggered when VisitTimerViewModel.startVisit() succeeds
```

### Send Booking Notifications
```swift
// Automatic - no code needed!
// Triggered when ServiceBookingDataService.createBooking() succeeds
```

### Manual Notification (if needed)
```swift
// Visit start
SmartNotificationManager.shared.sendVisitStartNotification(
    visitId: "visit123",
    sitterName: "Jane Doe",
    clientId: "client456",
    clientName: "John Smith",
    serviceSummary: "30-minute Dog Walk",
    address: "123 Main St"
)

// Booking created
SmartNotificationManager.shared.sendBookingCreatedNotification(
    bookingId: "booking789",
    clientName: "John Smith",
    clientId: "client456",
    serviceType: "Dog Walking - 30 min",
    scheduledDate: Date(),
    scheduledTime: "10:00 AM",
    pets: ["Rex", "Bella"]
)

// Booking needs approval
SmartNotificationManager.shared.sendBookingNeedsApprovalNotification(
    bookingId: "booking789",
    clientName: "John Smith",
    clientId: "client456",
    serviceType: "Dog Walking - 30 min",
    scheduledDate: Date(),
    scheduledTime: "10:00 AM"
)
```

---

## Testing

### Simulator Testing
1. Run app on iOS Simulator
2. Grant notification permission when prompted
3. Perform action (start visit or create booking)
4. Notification should appear in Notification Center

### Device Testing
1. Install app on physical device
2. Grant notification permission in Settings
3. Lock device or move app to background
4. Perform action from another device/admin panel
5. Notification should appear on lock screen

---

## Troubleshooting

### Notifications Not Showing
1. ✅ Check notification permission: Settings → SaviPets → Notifications
2. ✅ Verify `SmartNotificationManager.shared.isNotificationEnabled == true`
3. ✅ Check logs for "📍 Visit start notification sent" or "📝 Booking created notification sent"
4. ✅ Ensure app has `UserNotifications` framework imported

### Notifications Show But No Content
1. ✅ Check Firestore data exists (visit document, user document)
2. ✅ Verify no Firestore permission errors in console
3. ✅ Check logs for "Error fetching" messages

### Notifications Too Frequent
1. ✅ Batching is enabled by default (3-second delay for chat messages)
2. ✅ Visit/booking notifications are immediate (no batching)
3. ✅ Rate limiting: 2-second minimum interval between notifications per conversation

---

## Key Files

| File | Purpose |
|------|---------|
| `SmartNotificationManager.swift` | All notification logic |
| `VisitTimerViewModel.swift` | Visit start trigger |
| `ServiceBookingDataService.swift` | Booking notification triggers |

---

## Notification Categories

```swift
"VISIT_START"       // Visit start events
"BOOKING_CREATED"   // New booking events
"BOOKING_APPROVAL"  // Pending approval events
"CHAT_MESSAGE"      // Chat notifications (existing)
"MESSAGE_APPROVAL"  // Message approval (existing)
"SYSTEM_MESSAGE"    // System notifications (existing)
```

---

*Last Updated: October 12, 2025*

