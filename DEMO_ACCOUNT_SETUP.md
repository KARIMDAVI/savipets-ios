# Demo Account Setup for App Store Review 📱

## Issue Summary
Apple rejected the app because the demo account `testpp@savipets.com` with password `123TesT321` doesn't work for sign-in.

## Solution: Create Working Demo Account

### Step 1: Create Demo Account in Firebase Console

1. **Go to Firebase Console:**
   ```
   https://console.firebase.google.com/project/savipets-72a88/authentication/users
   ```

2. **Add User:**
   - Click "Add user"
   - **Email:** `demo@savipets.com`
   - **Password:** `Demo123!`
   - Click "Add user"

3. **Set User Role:**
   - Go to Firestore: `https://console.firebase.google.com/project/savipets-72a88/firestore/data`
   - Navigate to `users` collection
   - Find the demo user document (use the UID from Authentication)
   - Add/Update fields:
   ```json
   {
     "role": "petOwner",
     "email": "demo@savipets.com",
     "displayName": "Demo User",
     "firstName": "Demo",
     "lastName": "User",
     "address": "123 Demo Street, Demo City, DC 12345",
     "phoneNumber": "(555) 123-4567",
     "createdAt": [Current Timestamp]
   }
   ```

4. **Create Public Profile:**
   - Navigate to `publicProfiles` collection
   - Create document with same UID
   - Add fields:
   ```json
   {
     "displayName": "Demo User",
     "role": "petOwner",
     "updatedAt": [Current Timestamp]
   }
   ```

### Step 2: Create Demo Pet

1. **Navigate to:** `artifacts/savipets-72a88/users/{DEMO_UID}/pets`
2. **Add Document:**
   ```json
   {
     "name": "Buddy",
     "species": "Dog",
     "breed": "Golden Retriever",
     "age": 3,
     "weight": 65,
     "specialNeeds": "None",
     "createdAt": [Current Timestamp]
   }
   ```

### Step 3: Update App Store Connect

1. **Go to App Store Connect:**
   ```
   https://appstoreconnect.apple.com/apps/[YOUR_APP_ID]/appstore
   ```

2. **App Information → Demo Account:**
   - **Username:** `demo@savipets.com`
   - **Password:** `Demo123!`
   - **Notes:** "Demo account with full access to pet owner features including booking, chat, and profile management."

### Step 4: Test the Demo Account

1. **Install app on device**
2. **Sign in with:**
   - Email: `demo@savipets.com`
   - Password: `Demo123!`
3. **Verify features work:**
   - ✅ Profile loads
   - ✅ Can view pets
   - ✅ Can browse services
   - ✅ Can create bookings
   - ✅ Chat functionality
   - ✅ All core features accessible

---

## Alternative: Create Admin Demo Account

If you want reviewers to see admin features:

### Admin Demo Account Setup:

1. **Create Admin User:**
   - Email: `admin-demo@savipets.com`
   - Password: `AdminDemo123!`

2. **Set Admin Role:**
   ```json
   {
     "role": "admin",
     "email": "admin-demo@savipets.com",
     "displayName": "Admin Demo",
     "createdAt": [Current Timestamp]
   }
   ```

3. **App Store Connect Notes:**
   ```
   Admin Demo Account:
   Username: admin-demo@savipets.com
   Password: AdminDemo123!
   
   This account provides full access to admin features including:
   - Live visit tracking
   - Client management
   - Revenue analytics
   - Chat with users
   - Booking approvals
   ```

---

## Verification Checklist

Before resubmitting, verify:

- [ ] Demo account signs in successfully
- [ ] All major features are accessible
- [ ] No crashes or errors
- [ ] Profile loads correctly
- [ ] Can navigate all main screens
- [ ] Chat/messaging works
- [ ] Booking flow works
- [ ] Location permissions work (if applicable)

---

## Resubmission Notes

When resubmitting, include this in the "Notes" section:

```
Demo Account Updated:
- Username: demo@savipets.com
- Password: Demo123!
- Full access to pet owner features
- Tested on iOS 17+ devices
- All core functionality verified working
```

---

**This should resolve the App Store review issue!** ✅
