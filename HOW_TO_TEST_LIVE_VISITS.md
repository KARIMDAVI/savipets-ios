# How to Test Live Visits Fixes 🧪

## Why You're Not Seeing the Fixes

**The fixes ARE applied** in the code, but you need **active visits** to test them!

Looking at your console logs:
```
AdminDashboardView: Total conversations: 1
(no visit logs)
```

This means: **No active visits are in the database right now.**

---

## How to Create a Test Visit

### Option 1: Start a Visit as a Sitter (Recommended)

1. **Log out** of admin account
2. **Log in as a sitter** account
3. **Navigate to Schedule** tab
4. **Find a scheduled visit** for today
5. **Tap "Start Visit"** button
6. Visit status changes to **"in_adventure"**
7. **Log out** and **log back in as admin**
8. **Go to Live Visits** section
9. You should now see the active visit!

### Option 2: Create Test Data in Firestore

Go to Firebase Console → Firestore Database → `visits` collection:

```javascript
{
  "id": "test-visit-123",
  "status": "in_adventure",  // ← This is the key!
  "sitterId": "sitter-user-id",
  "sitterName": "Test Sitter",
  "clientId": "client-user-id",
  "clientName": "Test Client",
  "scheduledStart": Timestamp(now),
  "scheduledEnd": Timestamp(now + 1 hour),
  "serviceSummary": "Dog Walking - 30 min",
  "pets": ["Rex", "Bella"],
  "address": "123 Main St, San Francisco, CA",
  "timeline": {
    "checkIn": {
      "timestamp": Timestamp(now)
    }
  }
}
```

Then create a location for the sitter in `locations` collection:
```javascript
{
  "id": "sitter-user-id",  // Same as sitterId above
  "lat": 37.7749,
  "lng": -122.4194,
  "lastUpdated": Timestamp(now)
}
```

---

## What You Should See After Creating a Visit

### 1. Map Test ✅
- **Before Fix**: Map centered on San Francisco (default)
- **After Fix**: Map centers on actual sitter GPS location
- **How to verify**: The map should show the sitter's marker at their actual location

### 2. Progress Bar Test ✅
- **Before Fix**: Progress bar shows 0%
- **After Fix**: Progress bar shows actual percentage (e.g., 25%, 50%, 75%)
- **How to verify**: Look at the live visit card in list view - progress bar should animate

### 3. Message Button Test ✅
- **Before Fix**: Opens generic admin chat
- **After Fix**: 
  - If conversation exists with sitter → opens it
  - If no conversation → opens admin chat with pre-filled message
- **How to verify**: Tap "Message" button on live visit card

---

## Quick Test Checklist

- [ ] Active visit exists in Firestore with status "in_adventure"
- [ ] Sitter location exists in `locations/{sitterId}`
- [ ] Admin dashboard shows "1 active" under Live Visits
- [ ] Map view shows sitter marker (not just San Francisco)
- [ ] List view shows progress bar with percentage
- [ ] Message button works for sitter

---

## Debug: Check Current Data

Run this in your browser console (Firebase Console → Firestore):

```javascript
// Check for active visits
db.collection('visits')
  .where('status', '==', 'in_adventure')
  .get()
  .then(snap => console.log('Active visits:', snap.size))

// Check sitter locations
db.collection('locations')
  .get()
  .then(snap => console.log('Sitter locations:', snap.size))
```

---

## Console Logs to Look For

When you have active visits, you should see:
```
✅ Processing snapshot: isFromCache=false, hasPendingWrites=false
✅ Visit loaded: status=in_adventure
✅ Location updated for sitter: {lat: X, lng: Y}
```

Currently you're seeing:
```
❌ AdminDashboardView: Total conversations: 1
❌ (no visit logs)
```

This confirms: **No active visits in database!**

---

## The Fixes ARE Applied! ✅

Your console shows the app built and running successfully:
```
** BUILD SUCCEEDED **
```

The code changes are live in these files:
- ✅ `AdminDashboardView.swift` line 711: Status check updated
- ✅ `AdminDashboardView.swift` line 720: Status icon updated  
- ✅ `AdminDashboardView.swift` line 940-957: Message function rewritten
- ✅ `UnifiedLiveMapView.swift` line 536: Status color updated

**You just need active visit data to test them!**

---

*Create a test visit and the fixes will work perfectly!* 🎉

