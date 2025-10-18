# Timer System - QA Testing Checklist

## 🎯 **Testing Overview**

Following Time-To-Pet's authoritative timestamp pattern, test the timer system for accuracy, offline resilience, and edge cases.

---

## ✅ **Test Suite 1: Basic Functionality**

### **Test 1.1: Normal Start → End Cycle**

**Setup:**
- Scheduled: 10:00 AM - 11:00 AM (60 minutes)
- Device time: Accurate
- Network: Online

**Steps:**
1. Navigate to today's schedule
2. Find the test visit
3. Tap "Start Visit" at exactly 10:00:05 AM
4. Wait 30 seconds
5. Observe timer display
6. Tap "End Visit" at 11:00:10 AM

**Expected Results:**
- [ ] Button shows "Starting..." with spinner (200-500ms)
- [ ] Console: `"✅ Visit started successfully"`
- [ ] Console: `"📝 Wrote timeline.checkIn.timestamp to Firestore"`
- [ ] Console: `"✅ checkIn SET to 2025-10-08 10:00:05"`
- [ ] START shows: `10:00 AM` (no early/late indicator)
- [ ] ELAPSED shows: `00:30` after 30 seconds
- [ ] TIME LEFT shows: `59:30` (counting down)
- [ ] After 1 second: `59:29`, then `59:28`, etc.
- [ ] Button shows "Saving..." during end
- [ ] Visit card gets green border when completed
- [ ] Final ELAPSED shows: `60:05` (actual duration)

**Firestore Verification:**
```javascript
// Open Firebase Console → visits/[visitId]
{
  "scheduledStart": Timestamp(10:00:00),
  "scheduledEnd": Timestamp(11:00:00),
  "timeline": {
    "checkIn": {
      "timestamp": Timestamp(10:00:05) // ✅
    },
    "checkOut": {
      "timestamp": Timestamp(11:00:10) // ✅
    }
  },
  "status": "completed"
}
```

---

### **Test 1.2: Start Late**

**Setup:**
- Scheduled: 10:00 AM - 11:00 AM
- Actual start: 10:15 AM (15 minutes late)

**Steps:**
1. Wait until 10:15 AM
2. Tap "Start Visit"
3. Observe timer at 10:20 AM
4. Let timer count down to scheduled end
5. Continue 5 minutes past scheduled end
6. End visit at 11:05 AM

**Expected Results:**
- [ ] START shows: `10:15 AM (15m late)` ✅
- [ ] At 10:20 (5min elapsed):
  - ELAPSED: `05:00` ✅
  - TIME LEFT: `40:00` ✅ (45min remaining until 11:00)
- [ ] At 10:59 (44min elapsed):
  - TIME LEFT: `01:00` (orange warning)
- [ ] At 11:00 (45min elapsed):
  - TIME LEFT: `00:00`
- [ ] At 11:01 (46min elapsed):
  - TIME LEFT: `+01:00` (red overtime) ✅
  - Background turns red
- [ ] At 11:05 (tap End):
  - Final ELAPSED: `50:00` ✅ (actual duration)
- [ ] Firestore: checkIn = 10:15, checkOut = 11:05

---

### **Test 1.3: Start Early**

**Setup:**
- Scheduled: 10:00 AM - 11:00 AM  
- Actual start: 9:50 AM (10 minutes early)

**Steps:**
1. Tap "Start Visit" at 9:50 AM
2. Observe timer at 9:55 AM

**Expected Results:**
- [ ] START shows: `9:50 AM (10m early)` ✅
- [ ] At 9:55 (5min elapsed):
  - ELAPSED: `05:00` ✅
  - TIME LEFT: `65:00` ✅ (until 11:00 AM)
- [ ] Timer counts: 65:00 → 64:59 → 64:58 ...
- [ ] At 11:00 (70min elapsed):
  - ELAPSED: `70:00`
  - TIME LEFT: `00:00`
- [ ] No overtime (ended at scheduled time)

---

### **Test 1.4: Undo Functionality**

**Setup:**
- Scheduled: 10:00 AM - 11:00 AM
- Start visit at 10:05 AM

**Steps:**
1. Tap "Start Visit" at 10:05 AM
2. Wait 2 minutes (timer shows 53:00 remaining)
3. Tap "Undo" button
4. Confirm in alert dialog
5. Observe complete reset

**Expected Results:**
- [ ] Undo confirmation dialog appears with:
  - Title: "Undo Timer?"
  - Message: "This will reset the visit timer back to 'Start Visit'..."
  - Buttons: [Cancel] [Yes, Reset Timer] (red/destructive)
- [ ] After confirmation:
  - [ ] Console: `"⏪ Undoing visit start"`
  - [ ] Console: `"🗑️ checkIn REMOVED (undo)"`
  - [ ] Console: `"✅ Visit timer reset successfully"`
- [ ] UI changes:
  - [ ] Timer section disappears
  - [ ] "Start Visit" button reappears
  - [ ] No elapsed time shown
  - [ ] No countdown shown
  - [ ] Status returns to "scheduled"
- [ ] Firestore changes:
  - [ ] status: "scheduled"
  - [ ] timeline.checkIn: DELETED ✅
  - [ ] startedAt: DELETED ✅
- [ ] Can start again → Works normally

---

## 🔌 **Test Suite 2: Offline & Network**

### **Test 2.1: Start Visit Offline**

**Setup:**
- Enable Airplane Mode
- Scheduled: 10:00 AM - 11:00 AM

**Steps:**
1. Enable Airplane Mode on device
2. Tap "Start Visit" at 10:00:05
3. Observe UI for 10 seconds
4. Disable Airplane Mode
5. Wait for sync

**Expected Results:**
- [ ] While offline (0-10 seconds):
  - Button shows: "Starting..." 🔄
  - Console: No Firestore confirmations
  - isPendingWrite: true
  - No timer visible yet
- [ ] When back online (~5s after reconnect):
  - Console: `"✅ Visit started successfully"`
  - Console: `"✅ checkIn SET to [server timestamp]"`
  - Timer appears with server time
  - Small discrepancy OK (device 10:00:05 vs server 10:00:10)
- [ ] Timer counts down from server-confirmed time
- [ ] Orange spinner disappears

**Notes:**
- Server time is authoritative ✅
- Small (<5s) discrepancy is acceptable
- Pending write indicator shows sync status

---

### **Test 2.2: End Visit Offline**

**Setup:**
- Visit already started and running
- Timer showing: 15:30 remaining

**Steps:**
1. Enable Airplane Mode
2. Tap "End Visit"
3. Observe for 10 seconds
4. Disable Airplane Mode

**Expected Results:**
- [ ] While offline:
  - "Saving..." button
  - isPendingWrite: true
  - Timer continues counting (local only)
- [ ] When online:
  - Write completes
  - Console: `"✅ Visit completed successfully"`
  - Timer stops at server-confirmed end time
  - Completed status applied

---

### **Test 2.3: Undo While Offline**

**Setup:**
- Visit started
- Enable Airplane Mode

**Steps:**
1. Tap "Undo"
2. Confirm
3. Observe behavior
4. Go back online

**Expected Results:**
- [ ] Undo queued (pending write)
- [ ] UI shows attempting to reset
- [ ] When online: reset completes
- [ ] Timer fully reset
- [ ] Status: scheduled

---

## ⏰ **Test Suite 3: Clock Skew & Time Zones**

### **Test 3.1: Device Clock 5 Minutes Fast**

**Setup:**
- Set device time to 10:05:00 (manually)
- Actual server time: 10:00:00
- Scheduled: 10:00 AM - 11:00 AM

**Steps:**
1. Tap "Start Visit"
2. Observe local timer
3. Wait for server confirmation
4. Note any timer jump

**Expected Results:**
- [ ] Local shows: 10:05 AM (device time)
- [ ] Pending write: true
- [ ] Timer uses local estimate temporarily
- [ ] Server confirms: 10:00 AM (authoritative) ✅
- [ ] Timer jumps back 5 minutes
- [ ] Console: Shows both device and server times
- [ ] Final timer: Based on server time (10:00)

**Learning:** Server timestamp is always authoritative. Small jump expected.

---

### **Test 3.2: Different Time Zone**

**Setup:**
- Change device timezone
- Server in UTC
- Scheduled: 2:00 PM - 3:00 PM (local)

**Steps:**
1. Start visit
2. Verify times display in local timezone
3. Check Firestore (should be UTC)

**Expected Results:**
- [ ] UI shows local time: "2:00 PM"
- [ ] Firestore stores UTC timestamp
- [ ] Conversion handled correctly
- [ ] Timer countdown accurate

---

## ⚡ **Test Suite 4: Edge Cases**

### **Test 4.1: Rapid Start/Undo/Start**

**Steps:**
1. Tap "Start Visit"
2. Immediately tap "Undo" (while "Starting...")
3. Confirm undo
4. Immediately tap "Start Visit" again

**Expected Results:**
- [ ] First start queued
- [ ] Undo queued
- [ ] Second start queued
- [ ] All operations complete in order
- [ ] Final state: started (second start wins)
- [ ] No errors or race conditions

---

### **Test 4.2: Double-Tap Prevention**

**Steps:**
1. Rapidly tap "Start Visit" 10 times

**Expected Results:**
- [ ] Button disabled after first tap
- [ ] Only ONE write sent to Firestore
- [ ] No duplicate checkIn timestamps
- [ ] UI shows pending state until confirmed

---

### **Test 4.3: Overtime Notifications**

**Setup:**
- Scheduled: 10:00 AM - 10:15 AM (15 min visit)

**Steps:**
1. Start at 10:00
2. Let run until 10:10 (5min warning)
3. Continue until 10:15 (scheduled end)
4. Continue until 10:20 (5min overtime)

**Expected Results:**
- [ ] At 10:10 (5min left):
  - TIME LEFT: 05:00 (orange)
  - Background: orange
  - Notification: "Visit Ending Soon"
  - Console: `"⚠️ Sending 5-minute warning"`
- [ ] At 10:15 (scheduled end):
  - TIME LEFT: 00:00
- [ ] At 10:16 (1min overtime):
  - TIME LEFT: +01:00 (red)
  - Background: red
- [ ] Notifications sent only ONCE (not every second)

---

### **Test 4.4: Zero Duration Visit**

**Setup:**
- Scheduled: 10:00 AM - 10:00 AM (0 minutes)

**Expected Results:**
- [ ] Timer shows: 00:00
- [ ] Immediately overtime when started
- [ ] No crash or division by zero

---

## 📊 **Test Suite 5: Data Integrity**

### **Test 5.1: Firestore Console Inspection**

**After starting a visit, verify in Firebase Console:**

```javascript
visits/[visitId] {
  ✅ "status": "in_adventure",
  ✅ "scheduledStart": Timestamp,
  ✅ "scheduledEnd": Timestamp,
  ✅ "timeline": {
       ✅ "checkIn": {
            ✅ "timestamp": Timestamp
          }
     },
  ✅ "startedAt": Timestamp,
  ✅ "sitterId": "[uid]"
}
```

**Verify checkIn timestamp:**
- [ ] Exists under nested path: `timeline.checkIn.timestamp`
- [ ] Is a Timestamp type (not string)
- [ ] Matches server time (within 1 second)
- [ ] NOT a flat key `"timeline.checkIn.timestamp"`

---

### **Test 5.2: Security Rules Validation**

**Test as Sitter:**
1. Try to modify another sitter's visit → ❌ Should fail
2. Try to modify scheduledStart → ❌ Should fail  
3. Try to modify timeline.checkIn after set → ❌ Should fail
4. Try to delete visit → ❌ Should fail
5. Update own visit timeline → ✅ Should succeed

**Test as Admin:**
1. Modify any visit → ✅ Should succeed
2. Change checkIn timestamp → ✅ Should succeed
3. Delete visit → ✅ Should succeed

---

## 🔄 **Test Suite 6: Real-Time Updates**

### **Test 6.1: Multi-Device Sync**

**Setup:**
- Two devices logged in as same sitter
- Same visit visible on both

**Steps:**
1. Device A: Start visit
2. Device B: Observe
3. Device B: Should see timer appear
4. Device A: End visit
5. Device B: Should see completion

**Expected:**
- [ ] Device B receives realtime updates
- [ ] Timer syncs within 1-2 seconds
- [ ] No conflicts or race conditions

---

### **Test 6.2: Admin Override**

**Setup:**
- Sitter started visit at 10:05
- Admin needs to correct to 10:00

**Steps:**
1. Admin edits visit in console
2. Changes checkIn timestamp
3. Sitter's device updates

**Expected:**
- [ ] Sitter sees timer jump
- [ ] New time is authoritative
- [ ] No errors

---

## 📱 **Test Suite 7: UI/UX Validation**

### **Test 7.1: Visual States**

**Not Started:**
```
┌────────────────────────────┐
│ 10:00 AM - 11:00 AM        │
│ [Start Visit]              │
└────────────────────────────┘
```

**Pending Start:**
```
┌────────────────────────────┐
│ [Starting...] 🔄           │
│ Orange background          │
└────────────────────────────┘
```

**Running (On Time):**
```
┌────────────────────────────┐
│ START     ELAPSED  TIME LEFT│
│ 10:00 AM  15:30    44:30   │
│                             │
│ [↶ Undo] [End Visit]       │
└────────────────────────────┘
```

**Running (Late):**
```
┌────────────────────────────┐
│ START     ELAPSED  TIME LEFT│
│ 10:10 AM  15:30    34:30   │
│ 10m late                    │
└────────────────────────────┘
```

**Overtime:**
```
┌────────────────────────────┐
│ START     ELAPSED  TIME LEFT│
│ 10:00 AM  65:30   +05:30   │
│           ↑        ↑        │
│         Total    Overtime   │
│ Red background             │
└────────────────────────────┘
```

**Completed:**
```
┌────────────────────────────┐
│ ✅ Completed               │
│ Duration: 60:05            │
│ STARTED: 10:00 AM          │
│ ENDED: 11:00 AM            │
└────────────────────────────┘
```

**Collapsed View (Running):**
```
┌────────────────────────────┐
│ Max            [⏱ 15:30][↶]│
│ Dog Walking                │
└────────────────────────────┘
```

---

### **Test 7.2: Countdown Accuracy**

**Verify countdown ticks every second:**

- [ ] At 15:00: Shows `15:00`
- [ ] 1 second later: Shows `14:59` ✅
- [ ] 1 second later: Shows `14:58` ✅
- [ ] Continues smoothly to `00:00`
- [ ] Then: `+00:01` (overtime)
- [ ] Timer never freezes or jumps unexpectedly

---

## 🐛 **Test Suite 8: Error Handling**

### **Test 8.1: Firestore Write Failure**

**Setup:**
- Simulate Firestore error (disable network mid-write)

**Expected:**
- [ ] Error dialog appears
- [ ] User-friendly message shown
- [ ] Console shows detailed error
- [ ] UI returns to previous state
- [ ] Can retry operation

---

### **Test 8.2: Permission Denied**

**Setup:**
- Try to update another sitter's visit

**Expected:**
- [ ] Write fails with permission error
- [ ] Console: Error code 7 (PERMISSION_DENIED)
- [ ] User sees: "You don't have permission to update this visit"

---

## 📋 **Acceptance Criteria**

### **Must Have:**
- [x] Timer shows actual start time (not scheduled) when visit started
- [x] Countdown format: MM:SS (not "Xm Ys")
- [x] Undo resets timer completely
- [x] Server timestamps (not device time)
- [x] Metadata checking (skip pending writes)
- [x] Visual feedback during Firestore writes
- [x] Error handling with user-friendly messages
- [x] Build succeeds
- [x] No crashes on nil values

### **Should Have:**
- [x] Early/late indicators
- [x] Overtime detection with red UI
- [x] 5-minute warning with orange UI
- [x] Elapsed time display
- [x] Undo button in collapsed view
- [x] Duration shown for completed visits
- [x] Security rules prevent tampering

### **Nice to Have:**
- [x] Audit trail (VisitTimerViewModel logs all actions)
- [ ] Admin edit UI (future enhancement)
- [ ] Mileage tracking (future enhancement)
- [ ] GPS route tracking (exists via LocationService)

---

## 🎓 **Lessons Learned from Time-To-Pet**

### **1. Authoritative Timestamps**
✅ Always use `FieldValue.serverTimestamp()`  
✅ Never trust device time for billing/reports  
✅ Handle clock skew gracefully

### **2. Proper Nested Fields**
✅ Use `updateData()` for dot notation  
✅ Don't use `setData()` with `"field.nested.path"` keys  
✅ Verify structure in Firestore console

### **3. Pending Write UX**
✅ Show spinners during writes  
✅ Skip snapshots with `hasPendingWrites`  
✅ Clear feedback when operation completes

### **4. Reliability Metrics**
✅ Track early/late starts  
✅ Track duration variance  
✅ Enable business analytics

---

## 📸 **Screenshots to Capture**

For documentation:
1. Timer before start
2. Timer during "Starting..." (spinner)
3. Timer running (normal)
4. Timer with "10m late" indicator
5. Timer in overtime (red +05:00)
6. Undo confirmation dialog
7. Firestore console showing nested timeline structure
8. Completed visit with duration

---

## ✅ **Sign-Off**

**Tested By:** _________________  
**Date:** _________________  
**Build Version:** _________________  

**Result:** ☐ PASS  ☐ FAIL (describe issues)  

**Notes:**
___________________________________________
___________________________________________
___________________________________________

