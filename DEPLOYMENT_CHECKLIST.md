# SaviPets Timer Fix - Deployment Checklist

## 📋 Pre-Deployment Checklist

### 1. Code Quality ✅
- [x] All files compile without errors
- [x] No force unwraps (`!`) in timer code
- [x] All `print()` statements include emoji prefixes for filtering
- [x] No TODO/FIXME comments in timer-critical code
- [x] Code follows SaviPets project standards

### 2. Firebase Configuration 🔥
- [ ] Firestore indexes deployed
- [ ] Firestore security rules deployed
- [ ] Rules tested in emulator
- [ ] No hardcoded project IDs or secrets

### 3. Testing 🧪
- [ ] Manual QA checklist completed (see TIMER_TESTING_CHECKLIST.md)
- [ ] Tested on physical device (not just simulator)
- [ ] Tested offline scenarios
- [ ] Tested with poor network (Network Link Conditioner)
- [ ] Tested timezone edge cases
- [ ] Tested early/late start scenarios
- [ ] Tested overtime scenarios
- [ ] Tested "Undo" feature

### 4. Performance ⚡
- [ ] No memory leaks (verified with Instruments)
- [ ] Listener cleanup verified (deinit called)
- [ ] Timer updates smooth (no UI lag)
- [ ] Firestore reads within limits (< 50K/day free tier)

### 5. Documentation 📚
- [x] TIMER_FIX_COMPREHENSIVE_SUMMARY.md created
- [x] TIMER_QUICK_REFERENCE.md created
- [x] DEPLOYMENT_CHECKLIST.md created (this file)
- [ ] CHANGELOG.md updated

---

## 🚀 Deployment Steps

### Step 1: Deploy Firestore Configuration
```bash
# Navigate to project
cd /Users/kimo/Documents/KMO/Apps/SaviPets

# Deploy indexes (do this FIRST, wait for completion)
firebase deploy --only firestore:indexes

# Wait for indexes to build (check Firebase console)
# Status: Building → Active (may take 5-10 minutes)

# Deploy security rules
firebase deploy --only firestore:rules

# Verify deployment
firebase firestore:indexes
firebase firestore:rules
```

**Expected Output**:
```
✔ Deploy complete!

Firestore Indexes:
  - visits (collection group): sitterId ASC, status ASC, scheduledStart ASC [ACTIVE]

Security Rules:
  - Last updated: [timestamp]
  - Version: [version]
```

### Step 2: Build iOS App
```bash
# Clean build directory
xcodebuild clean -scheme SaviPets

# Build for simulator (quick test)
xcodebuild build \
  -scheme SaviPets \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

# Build for device (production)
xcodebuild archive \
  -scheme SaviPets \
  -archivePath ./build/SaviPets.xcarchive \
  -destination 'generic/platform=iOS'

# Export IPA
xcodebuild -exportArchive \
  -archivePath ./build/SaviPets.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

### Step 3: Test on Device
```bash
# Install on connected device
# (Or use Xcode: Product → Run)

# Monitor console for timer logs
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "SaviPets"' --level=debug
```

**What to verify**:
- [ ] Visit cards load correctly
- [ ] "Start Visit" button appears on scheduled visits
- [ ] Tapping "Start Visit" shows pending indicator
- [ ] Timer starts counting after sync
- [ ] "Time Left" counts down accurately
- [ ] "End Visit" completes visit correctly
- [ ] Console shows ✅ success messages, no ❌ errors

### Step 4: Production Upload (TestFlight)
```bash
# Upload to App Store Connect
xcrun altool --upload-app \
  --type ios \
  --file ./build/SaviPets.ipa \
  --apiKey [YOUR_API_KEY] \
  --apiIssuer [YOUR_ISSUER_ID]

# Or use Xcode:
# Window → Organizer → Archives → Distribute App → TestFlight
```

### Step 5: Monitor Production
```bash
# Watch Firestore usage
# Firebase Console → Firestore → Usage

# Watch for errors
# Firebase Console → Firestore → Logs

# Monitor Analytics
# Firebase Console → Analytics → Events
# Look for: visit_started, visit_completed, visit_undo
```

---

## 🔍 Post-Deployment Verification

### Immediate Checks (First Hour)
- [ ] No spike in Firestore errors
- [ ] Visit starts/ends writing correctly to Firestore
- [ ] Real-time updates working across devices
- [ ] No crash reports in Crashlytics

### First Day Checks
- [ ] Monitor user feedback for timer issues
- [ ] Check Firestore usage (should be ~2 writes per visit)
- [ ] Verify no security rule violations
- [ ] Verify indexes are being used (check query performance)

### First Week Checks
- [ ] Review Analytics events (visit_started, visit_completed counts)
- [ ] Check average time variance (early/late starts)
- [ ] Review overtime frequency
- [ ] Monitor "Undo" usage (if high, investigate why)

---

## 🐛 Rollback Plan

### If Critical Issues Found

**Option 1: Quick Fix**
```bash
# Fix code locally
# Build and deploy hotfix
xcodebuild archive -scheme SaviPets ...
xcrun altool --upload-app ...
```

**Option 2: Rollback Code**
```bash
# Revert to previous commit
git log --oneline  # Find commit hash before timer changes
git revert [commit-hash]
git push origin main

# Redeploy previous version
```

**Option 3: Disable Feature**
```swift
// Add feature flag to SitterDashboardView
private let timerFeatureEnabled = false

// Wrap timer code
if timerFeatureEnabled {
    // New timer logic
} else {
    // Old logic
}
```

**Firestore Rollback** (if needed):
```bash
# Rollback rules
git checkout HEAD~1 firestore.rules
firebase deploy --only firestore:rules

# Note: Cannot rollback indexes (delete manually in console)
```

---

## 📊 Success Metrics

### Week 1 Targets
- [ ] Zero crashes related to timer code
- [ ] < 1% failed visit starts
- [ ] < 1% failed visit completions
- [ ] Average sync time < 2 seconds
- [ ] No security rule violations

### Month 1 Targets
- [ ] Positive user feedback on timer accuracy
- [ ] Firestore usage within budget
- [ ] No clock skew issues reported
- [ ] Offline mode working reliably

---

## 🔧 Troubleshooting Production Issues

### Issue: Times not syncing
**Debug**:
1. Check Firebase Console → Firestore → visit document
2. Verify `timeline.checkIn.timestamp` exists
3. Check device network connection
4. Check Firestore usage limits

**Fix**:
- If over limits: upgrade Firebase plan
- If network issue: add retry logic
- If data missing: check security rules

### Issue: Pending indicator stuck
**Debug**:
1. Check console logs for error messages
2. Check Firebase Console → Firestore → Logs
3. Verify device time is correct

**Fix**:
- Add timeout to pending writes (30s)
- Show error message to user
- Add retry button

### Issue: Timer showing wrong time
**Debug**:
1. Compare device time to server time
2. Check timezone settings
3. Verify `actualStartTime` is not nil

**Fix**:
- Use server timestamps (already implemented)
- Add timezone indicator in UI
- Add debug logs to identify source of discrepancy

---

## 📞 Emergency Contacts

**Firebase Issues**:
- Console: https://console.firebase.google.com/project/savipets-72a88
- Support: Firebase Support (login required)

**App Store Issues**:
- App Store Connect: https://appstoreconnect.apple.com
- Support: Apple Developer Support

**Team**:
- Lead Developer: [Your Name]
- Backend: [Name]
- QA: [Name]

---

## 📝 Post-Deployment Notes

### What Went Well
- 

### What Could Be Improved
- 

### Issues Encountered
- 

### User Feedback
- 

---

## ✅ Final Sign-Off

**Deployed By**: ________________  
**Date**: ________________  
**Version**: ________________  
**Build Number**: ________________  

**Verification**:
- [ ] All checklist items completed
- [ ] Production testing passed
- [ ] Documentation updated
- [ ] Team notified

**Notes**:


---

*Deployment Checklist v1.0 - Last Updated: October 8, 2025*

