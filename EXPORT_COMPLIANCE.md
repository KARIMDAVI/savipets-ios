# Export Compliance Documentation

## Overview
This document describes SaviPets' use of encryption and export compliance status as required by Apple App Store submission guidelines.

## Encryption Usage

### Does the app use encryption?
**Yes**, but it qualifies for exemption under standard categories.

### Types of Encryption Used

#### 1. **HTTPS/TLS (Exempt)**
- **Purpose**: Secure communication with Firebase services (Auth, Firestore, Cloud Messaging)
- **Implementation**: Standard iOS URLSession and Firebase SDK
- **Exemption**: Qualifies for exemption under Category 5 Part 2 (standard HTTPS)
- **Category**: (a)(2) - Encryption for authentication only
- **No Export Authorization Required**

#### 2. **Firebase Authentication (Exempt)**
- **Purpose**: User authentication and session management
- **Implementation**: Firebase Auth SDK
- **Encryption Type**: Standard TLS/SSL for credential transmission
- **Exemption**: Authentication encryption - standard cryptographic protocols

#### 3. **Push Notifications (Exempt)**
- **Purpose**: Remote notifications via APNs (Apple Push Notification Service)
- **Implementation**: Standard iOS push notification framework
- **Exemption**: Uses Apple's standard encryption, automatically exempt

#### 4. **Apple Sign In (Exempt)**
- **Purpose**: User authentication via Apple ID
- **Implementation**: Standard Apple AuthenticationServices framework
- **Exemption**: Apple's standard authentication, automatically exempt

#### 5. **Google Sign In (Exempt)**
- **Purpose**: User authentication via Google account
- **Implementation**: Standard Google Sign In SDK
- **Exemption**: OAuth 2.0 over HTTPS, standard protocol

## Export Compliance Status

### ITSAppUsesNonExemptEncryption: NO

**Justification:**
All encryption used in SaviPets falls under **exempt categories**:

1. **Standard HTTPS/TLS**: Exempt under Category 5 Part 2
2. **Authentication Only**: Encryption used solely for authentication purposes
3. **Standard Cryptographic Protocols**: iOS native frameworks and well-known SDKs
4. **No Proprietary Encryption**: No custom encryption algorithms implemented

### Exemption Categories

According to U.S. Export Administration Regulations (EAR):

- **ECCN**: 5D992 - Not subject to EAR
- **Reason**: Uses only standard encryption for:
  - HTTPS communications
  - User authentication
  - Data in transit to/from Firebase
  - Local keychain storage (iOS system-level)

## Third-Party SDKs Using Encryption

| SDK | Encryption Type | Exempt | Purpose |
|-----|----------------|--------|---------|
| Firebase Auth | TLS/SSL | ✅ Yes | User authentication |
| Firebase Firestore | TLS/SSL | ✅ Yes | Database communication |
| Firebase Cloud Messaging | TLS/SSL | ✅ Yes | Push notifications |
| Google Sign In | OAuth 2.0/HTTPS | ✅ Yes | Authentication |
| Apple AuthenticationServices | Standard Apple | ✅ Yes | Sign in with Apple |
| URLSession (iOS) | HTTPS/TLS | ✅ Yes | Network requests |

## App Store Submission

### Export Compliance Questions

When submitting to App Store Connect, answer as follows:

**Q: "Does your app use encryption?"**
- **A: Yes**

**Q: "Does your app qualify for any of the exemptions provided in Category 5, Part 2 of the U.S. Export Administration Regulations?"**
- **A: Yes**

**Q: "Does your app implement any encryption algorithms that are proprietary or not accepted as standard by international standards bodies?"**
- **A: No**

**Q: "Does your app contain encryption that is only used for the app's internal use?"**
- **A: No** (encryption is for network communication)

**Q: "Is your app designed to be used by government clients?"**
- **A: No**

### Result
✅ **No ERN (Export Regulations Number) required**
✅ **No additional documentation required**
✅ **Automatic exemption applies**

## Info.plist Configuration

The following key is set in `Info.plist`:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

This declares that the app:
- Uses encryption (via HTTPS/Firebase)
- But only uses **exempt** encryption types
- Therefore answers "NO" to non-exempt encryption

## Compliance Verification

### Checklist
- ✅ All encryption is standard HTTPS/TLS
- ✅ No custom encryption algorithms
- ✅ Only iOS/Firebase standard SDKs
- ✅ No encryption for proprietary data protection
- ✅ No end-to-end encrypted messaging
- ✅ No encrypted file storage (beyond iOS keychain)
- ✅ `ITSAppUsesNonExemptEncryption` set to `false` in Info.plist

## References

- [Apple Export Compliance Documentation](https://developer.apple.com/documentation/security/complying_with_encryption_export_regulations)
- [U.S. Export Administration Regulations](https://www.bis.doc.gov/index.php/policy-guidance/encryption)
- [Firebase Security Documentation](https://firebase.google.com/docs/security)

## Updates

- **2025-10-10**: Initial documentation
- **Status**: ✅ Export compliance properly configured

---

**Note for Developers**: 
This app qualifies for automatic exemption. No manual export compliance forms or ERN numbers are required. The `ITSAppUsesNonExemptEncryption: false` setting in Info.plist will automatically handle App Store Connect submission requirements.




