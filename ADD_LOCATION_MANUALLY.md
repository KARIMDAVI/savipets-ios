# How to Add Test Location for Sitter 📍

## Method 1: Firebase Console (Easiest - 2 minutes)

### Step-by-Step:

1. **Open Firebase Console:**
   ```
   https://console.firebase.google.com/project/savipets-72a88/firestore
   ```

2. **Find or Create `locations` Collection:**
   - If it doesn't exist: Click "Start collection" → Name it "locations"
   - If it exists: Click on "locations" collection

3. **Add Document:**
   - Click "Add document"
   - **Document ID:** `Dk0133` (the sitter's user ID)
   - Click "Add field" for each:

4. **Add These 3 Fields:**

   | Field Name | Type | Value |
   |------------|------|-------|
   | `lat` | **number** | `34.0522` (Los Angeles - change if needed) |
   | `lng` | **number** | `-118.2437` |
   | `lastUpdated` | **timestamp** | Click "..." → "Use current timestamp" |

5. **Click "Save"**

6. **Refresh your app** - Map should now show Los Angeles instead of San Francisco!

---

## Method 2: Using iOS App (Proper Way)

If you want the actual live tracking to work:

1. **Log in as the sitter** (user ID: Dk0133)
2. **Ensure Location Permissions:**
   - Settings → SaviPets → Location → "While Using App"
3. **Start one of the active visits:**
   - Visit: `32344177-519F-4E62-B6B9-45D0CDC3E969`
   - OR Visit: `jRXsUviQhAt3mF9Gm5Xd`
4. **LocationService will automatically:**
   - Request location permissions
   - Start GPS tracking
   - Write to `locations/Dk0133`
5. **Go back to Admin dashboard** - Map will show real-time location!

---

## Method 3: Quick Console Command

If you have Firebase CLI installed:

```bash
# Navigate to project
cd /Users/kimo/Documents/KMO/Apps/SaviPets

# Create a simple script
cat > add_location.js << 'EOF'
const admin = require('firebase-admin');
const serviceAccount = require('./GoogleService-Info.json'); // If you have service account key

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

db.collection('locations').doc('Dk0133').set({
  lat: 34.0522,
  lng: -118.2437,
  lastUpdated: admin.firestore.FieldValue.serverTimestamp()
}).then(() => {
  console.log('✅ Location added!');
  process.exit(0);
}).catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
EOF

# Run it
node add_location.js
```

---

## What You'll See After Adding Location

### Before (Current):
```
Map centered on: San Francisco (37.7749, -122.4194)
Reason: Default fallback location
```

### After:
```
Map centered on: Los Angeles (34.0522, -118.2437)
Showing: Sitter marker at actual location
Active visits: 2 visible on map
```

---

## Verification

After adding the location, check Firebase Console:
```
locations/
  └─ Dk0133/
      ├─ lat: 34.0522
      ├─ lng: -118.2437
      └─ lastUpdated: [timestamp]
```

Then refresh your Admin app and go to Live Visits → Map view!

---

## Need Different Location?

Replace the coordinates with your actual location:
- **New York:** `lat: 40.7128, lng: -74.0060`
- **Chicago:** `lat: 41.8781, lng: -87.6298`
- **Miami:** `lat: 25.7617, lng: -80.1918`
- **Your Address:** Use Google Maps → Right-click → Copy coordinates

---

*After adding this, the map will work perfectly!* 🗺️✅

