// Firebase Admin Script to Add Test Location for Sitter
// Run this in Firebase Console or using Firebase Admin SDK

// To run in Firebase Console:
// 1. Go to: https://console.firebase.google.com/project/savipets-72a88/firestore
// 2. Click "locations" collection (create if doesn't exist)
// 3. Click "Add document"
// 4. Document ID: Dk0133
// 5. Add fields:
//    - lat (number): 34.0522
//    - lng (number): -118.2437
//    - lastUpdated (timestamp): [Click "..." → "Use current timestamp"]

// OR copy this code and run in Firebase Functions/Console:
const admin = require('firebase-admin');
const db = admin.firestore();

async function addTestLocation() {
  try {
    await db.collection('locations').doc('Dk0133').set({
      lat: 34.0522,  // Los Angeles latitude (change to actual location)
      lng: -118.2437, // Los Angeles longitude
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ Location added successfully for sitter Dk0133');
  } catch (error) {
    console.error('❌ Error adding location:', error);
  }
}

addTestLocation();

