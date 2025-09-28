# SaviPets (SwiftUI iOS App)

## What’s new (this session)

- Theme: All brand yellows are scheme-aware.
  - Light mode: dark yellow `#262200` for text/accents; bright gold reserved for key CTAs where specified.
  - Dark mode: bright gold gradient retained.
- Sign In/Sign Up (light mode): restored bright gold background and toggle tint per request; dark mode unchanged.
- Buttons: new `PrimaryButtonStyleBrightInLight` for CTAs that must be bright gold in light mode. Applied to Booking flow (“Select”, “Book Now”).
- Pet Photos: immediate upload on pick; cards refresh instantly; images resized/compressed for Firebase Spark.
- Colors API: `SPDesignSystem.Colors.primaryAdjusted(_:)` and `goldenGradient(_:)` unify yellow usage app‑wide.

## Run

1) Xcode 16 beta (iOS 26 sim OK) or Xcode 15+ (target iOS 16).
2) Open `SaviPets.xcodeproj` and run the `SaviPets` scheme on an iOS Simulator.

## Firebase setup

1) Add `GoogleService-Info.plist` to `SaviPets/` target (top level of the app bundle).
2) Ensure URL Types include the REVERSED_CLIENT_ID from the plist (Info.plist already wired).

## Notable implementation details

- DesignSystem
  - `primaryAdjusted(_:)`: returns bright gold in dark mode, dark yellow in light mode.
  - `goldenGradient(_:)`: gradient adapted to color scheme.
  - `FloatingTextField` label/border colors use scheme‑aware yellow on focus.
- Booking
  - `BookServiceView`: “Select” and “Book Now” use `PrimaryButtonStyleBrightInLight()` so light mode shows bright gold, dark mode keeps the golden gradient.
- Owner Pets
  - Photo upload immediately updates `photoURL`; list reload via `Notification.Name.petsDidChange`.
  - Storage uploads perform resize/compress to reduce Spark usage.

## Style hooks to use

- Use `SPButton(kind: .primary)` for standard primary actions (scheme aware).
- Use `PrimaryButtonStyleBrightInLight()` only for CTAs that must be bright gold in light mode.
- Use `SPDesignSystem.Colors.primaryAdjusted(colorScheme)` instead of raw primary for fills/tints.

## Known

- Admin/Owner/Sitter dashboards compile and run; further wiring to live Firestore data is incremental.
- RN project (`SaviPetsMobile/`) exists separately; this README covers the SwiftUI app.


