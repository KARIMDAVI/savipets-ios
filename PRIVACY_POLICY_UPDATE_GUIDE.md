# Privacy Policy Update Guide for SaviPets

**Last Updated**: January 10, 2025  
**Status**: Required updates for App Store compliance

---

## 🎯 Required Additions to Your Existing Privacy Policy

Based on the SaviPets app functionality, your privacy policy **MUST** include the following sections. Add these to your existing document:

---

## 1. Information We Collect

### Location Data
```
SaviPets collects precise location data when:
- Pet sitters start a visit (to verify visit location)
- During active walks (to track route and provide real-time updates to pet owners)
- Background location is only collected during active visits with user permission

Location data is:
- Stored in our secure Firebase database
- Shared with pet owners for the specific visits they booked
- Retained for [X days/months] for record-keeping and dispute resolution
- NOT sold to third parties
- NOT used for advertising or tracking
```

### Contact Information
```
We collect email addresses for:
- Account creation and authentication
- Service booking confirmations
- Visit notifications
- Support communications

We collect phone numbers (optional) for:
- Emergency contact purposes
- Direct communication between pet owners and sitters
```

### User Identifiers
```
We collect and generate:
- Firebase Authentication UIDs for account management
- Device tokens for push notifications
- User role identifiers (Pet Owner, Sitter, Admin)

These identifiers are used solely for app functionality and are NOT shared with third parties.
```

### Photos and Media
```
We collect pet photos that you upload:
- Stored securely in Firebase Storage
- Only accessible to you and assigned sitters for your pets
- Not used for any purpose other than displaying in your pet profiles
- You can delete photos at any time from your pet profile
```

### Chat Messages
```
We collect messages sent through the in-app chat:
- Messages between pet owners and sitters
- Messages to admin support
- Admin moderation may review messages for safety and quality
- Messages are retained for [X days/months]
- You can request deletion of your messages by contacting support
```

### Service Booking Data
```
We collect booking information including:
- Selected services (dog walking, pet sitting, etc.)
- Scheduled date and time
- Special instructions for pet care
- Booking status and history
- Visit duration and actual start/end times
```

---

## 2. How We Use Your Information

### App Functionality
```
Your data is used to:
- Enable account creation and secure login
- Match pet owners with pet sitters
- Schedule and manage service bookings
- Track visit start/end times accurately
- Send booking confirmations and visit updates
- Facilitate communication between users
- Process payments (if applicable)
```

### Legal Compliance
```
We may use or disclose your information to:
- Comply with legal obligations
- Protect against fraud or abuse
- Enforce our Terms of Service
- Respond to lawful requests from authorities
```

---

## 3. Required Reason API Declarations

**Apple requires disclosure of specific API usage. Add this section:**

```
SaviPets accesses the following device APIs:

1. UserDefaults API
   - Reason: Store user preferences and app settings locally
   - Example: Remembering notification preferences

2. File Timestamp API  
   - Reason: Manage cached data and temporary files
   - Example: Photo upload optimization

3. System Boot Time API
   - Reason: Calculate accurate time intervals for visit tracking
   - Example: Visit duration calculations

4. Disk Space API
   - Reason: Ensure sufficient space before uploading pet photos
   - Example: Pre-upload validation
```

---

## 4. Data Sharing and Third Parties

### Firebase Services (Google)
```
SaviPets uses Firebase (provided by Google) for:
- Authentication (Firebase Auth)
- Database storage (Cloud Firestore)
- File storage (Firebase Storage)
- Push notifications (Firebase Cloud Messaging)
- Analytics (Firebase Analytics)

Firebase Privacy Policy: https://firebase.google.com/support/privacy
Google Privacy Policy: https://policies.google.com/privacy
```

### Apple Services
```
- Sign in with Apple (if user chooses this option)
- Apple Push Notification Service (APNs)

Apple Privacy Policy: https://www.apple.com/legal/privacy/
```

### No Third-Party Data Selling
```
We do NOT sell, rent, or share your personal data with third parties for their 
marketing purposes. Your data is only shared as described in this policy.
```

---

## 5. Data Security

```
We implement industry-standard security measures:
- All data transmitted via HTTPS encryption
- Firebase security rules protect user data
- Server-side authentication and authorization
- Regular security audits and updates
- Secure password hashing (never stored in plain text)

However, no method of transmission over the internet is 100% secure. We cannot 
guarantee absolute security but take reasonable precautions to protect your data.
```

---

## 6. Your Rights and Choices

### Access and Control
```
You have the right to:
- Access your personal data
- Correct inaccurate information
- Delete your account and associated data
- Export your data
- Opt-out of non-essential communications

To exercise these rights, contact us at [your-support-email]
```

### Location Permissions
```
You can control location access via iOS Settings > SaviPets > Location:
- Never: Location features will not work
- While Using: Location only collected during active app use
- Always: Required for background visit tracking (sitters only)

You can change this permission at any time.
```

### Notification Preferences
```
You can disable push notifications via iOS Settings > Notifications > SaviPets

Note: Disabling notifications may impact your ability to receive important visit 
updates and booking confirmations.
```

---

## 7. Data Retention

```
We retain your data for as long as your account is active, plus:
- Booking history: [X years] for tax and legal compliance
- Chat messages: [X months] after account deletion
- Location data: [X months] after visit completion
- Photos: Immediately deleted when you delete them or your account

To delete your account, go to Settings > Account > Delete Account
```

---

## 8. Children's Privacy

```
SaviPets is not intended for users under 18 years of age. We do not knowingly 
collect personal information from children. If we discover that a child has 
provided us with personal information, we will delete it immediately.

If you are a parent/guardian and believe your child has provided us with 
information, please contact us at [your-support-email]
```

---

## 9. California Privacy Rights (CCPA)

**If you have California users, add:**

```
California residents have additional rights under the California Consumer Privacy Act (CCPA):

Right to Know: You can request disclosure of what personal information we collect
Right to Delete: You can request deletion of your personal information
Right to Opt-Out: You can opt-out of the sale of personal information (we don't sell data)
Right to Non-Discrimination: We won't discriminate against you for exercising your rights

To exercise these rights, email [your-support-email] with "California Privacy Request" 
in the subject line.
```

---

## 10. European Users (GDPR)

**If you have EU users, add:**

```
For users in the European Economic Area (EEA), UK, and Switzerland:

Legal Basis for Processing:
- Contract performance (service bookings, visit tracking)
- Legitimate interests (fraud prevention, app improvements)
- Consent (location tracking, optional features)

Your GDPR Rights:
- Right of access
- Right to rectification
- Right to erasure ("right to be forgotten")
- Right to restrict processing
- Right to data portability
- Right to object
- Right to withdraw consent

Data transfers outside the EEA are protected by standard contractual clauses.

To exercise your rights or file a complaint, contact [your-support-email] or your 
local data protection authority.
```

---

## 11. Changes to This Policy

```
We may update this Privacy Policy from time to time. We will notify you of material 
changes by:
- Posting the new policy on our website
- Sending an in-app notification
- Updating the "Last Updated" date

Your continued use after changes constitutes acceptance of the updated policy.
```

---

## 12. Contact Information

```
Questions about this Privacy Policy? Contact us:

Email: [your-support-email]
Website: https://www.savipets.com
Address: [Your Business Address]

Data Protection Officer (if applicable): [DPO contact]
```

---

## ✅ Compliance Checklist

Before publishing, ensure your privacy policy includes:

- [ ] Clear description of what data is collected
- [ ] Why each type of data is collected
- [ ] How data is used
- [ ] What third parties receive data
- [ ] User rights and how to exercise them
- [ ] Data retention periods
- [ ] Security measures
- [ ] Contact information
- [ ] Last updated date
- [ ] Required Reason API disclosures (iOS 17+)
- [ ] CCPA section (if California users)
- [ ] GDPR section (if EU users)
- [ ] Children's privacy statement

---

## 🔗 Where to Host Your Privacy Policy

**Required**: Privacy policy must be publicly accessible

Options:
1. **Your website**: https://www.savipets.com/privacy-policy (RECOMMENDED)
2. **App Store listing**: Link in App Privacy section
3. **In-app**: Settings > Privacy Policy

**Important**: 
- URL must be live and accessible without login
- Must be readable on mobile devices
- Should be available in all languages your app supports

---

## 📱 App Store Connect Privacy Declarations

When filling out App Store Connect > App Privacy, declare:

**Data Linked to User:**
- Precise Location
- Email Address
- Phone Number (if collected)
- User ID
- Photos
- Messages

**Data Not Linked to User:**
- Diagnostics
- Crash Data

**Data Not Collected:**
- Health & Fitness
- Financial Info
- Browsing History
- Search History
- Purchases (unless you add payment features)

---

## ⚠️ Legal Disclaimer

This guide provides recommendations based on SaviPets functionality. 

**You MUST:**
- Review with qualified legal counsel
- Customize for your specific business practices
- Ensure accuracy of all statements
- Keep updated as app features change
- Comply with laws in all jurisdictions where you operate

We are not lawyers. This is not legal advice.

---

**Next Steps:**
1. Review this guide with your legal team
2. Update your existing privacy policy with required sections
3. Host updated policy at https://www.savipets.com/privacy-policy
4. Update App Store Connect with privacy declarations
5. Add in-app link to privacy policy in Settings
6. Keep a dated archive of all policy versions

---

*Guide Version 1.0 - January 10, 2025*

