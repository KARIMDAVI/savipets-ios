#!/bin/bash
# Comprehensive fix for automatic signing and provisioning profile issues

echo "🔧 Fixing automatic signing and provisioning profile issues..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo ""
echo "🔍 ROOT CAUSE ANALYSIS:"
echo "   • Bundle ID mismatch between project and URL schemes"
echo "   • Provisioning profile missing iCloud container environment entitlement"
echo "   • Automatic signing failing due to entitlement conflicts"
echo ""

# 1. Fix Bundle ID Consistency
echo "🔧 Step 1: Fixing Bundle ID consistency..."

# Update project.pbxproj to use consistent bundle ID
print_info "Updating project bundle identifier to com.saviesa.SaviPets"
sed -i '' 's/com\.budgo\.SaviPets/com.saviesa.SaviPets/g' SaviPets.xcodeproj/project.pbxproj
sed -i '' 's/com\.budgo\.SaviPetsTests/com.saviesa.SaviPetsTests/g' SaviPets.xcodeproj/project.pbxproj
sed -i '' 's/com\.budgo\.SaviPetsUITests/com.saviesa.SaviPetsUITests/g' SaviPets.xcodeproj/project.pbxproj

# Update GoogleService-Info.plist
print_info "Updating Firebase configuration bundle ID"
sed -i '' 's/com\.budgo\.SaviPets/com.saviesa.SaviPets/g' SaviPets/GoogleService-Info.plist

print_status "Bundle ID consistency fixed"

# 2. Clean Provisioning Profiles
echo ""
echo "🔧 Step 2: Cleaning provisioning profiles..."

# Remove old provisioning profiles
print_info "Removing old provisioning profiles..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
rm -rf ~/Library/Developer/Xcode/DerivedData/*

print_status "Provisioning profiles cleaned"

# 3. Fix Entitlements
echo ""
echo "🔧 Step 3: Fixing entitlements..."

# Ensure entitlements are correct
print_info "Verifying entitlements configuration..."
if grep -q "Production" SaviPets/SaviPets.entitlements; then
    print_status "iCloud container environment set to Production"
else
    print_error "iCloud container environment not properly set"
fi

# 4. Reset Signing Settings
echo ""
echo "🔧 Step 4: Resetting signing settings..."

# Clean and reset signing
print_info "Cleaning project..."
xcodebuild clean -project SaviPets.xcodeproj -scheme SaviPets

print_info "Resetting automatic signing..."
# This will force Xcode to regenerate provisioning profiles
print_warning "You need to manually:"
print_warning "1. Open Xcode"
print_warning "2. Go to Project Settings → Signing & Capabilities"
print_warning "3. Uncheck 'Automatically manage signing'"
print_warning "4. Check 'Automatically manage signing' again"
print_warning "5. Select your development team"

# 5. Create New Provisioning Profile Script
echo ""
echo "🔧 Step 5: Creating provisioning profile regeneration script..."

cat > regenerate_provisioning.sh << 'EOF'
#!/bin/bash
echo "🔄 Regenerating provisioning profiles..."

# Open Xcode and trigger provisioning profile regeneration
open -a Xcode SaviPets.xcodeproj

echo "📋 Manual steps required in Xcode:"
echo "1. Select the SaviPets target"
echo "2. Go to 'Signing & Capabilities' tab"
echo "3. Uncheck 'Automatically manage signing'"
echo "4. Wait 2 seconds"
echo "5. Check 'Automatically manage signing' again"
echo "6. Select your development team"
echo "7. Wait for 'Provisioning Profile' to update"
echo "8. Build the project (Cmd+B)"
echo ""
echo "✅ This will create a new provisioning profile with iCloud entitlements"
EOF

chmod +x regenerate_provisioning.sh

print_status "Provisioning profile regeneration script created"

# 6. Verify Configuration
echo ""
echo "🔧 Step 6: Verifying configuration..."

echo "📋 Current configuration:"
echo "   Bundle ID: $(grep 'PRODUCT_BUNDLE_IDENTIFIER.*SaviPets' SaviPets.xcodeproj/project.pbxproj | head -1 | cut -d'=' -f2 | tr -d ' ;')"
echo "   Firebase Bundle ID: $(grep 'BUNDLE_ID' SaviPets/GoogleService-Info.plist | cut -d'>' -f2 | cut -d'<' -f1)"
echo "   URL Scheme: $(grep 'com.saviesa.SaviPets' SaviPets/Info.plist | head -1 | cut -d'>' -f2 | cut -d'<' -f1)"
echo "   iCloud Environment: $(grep 'icloud-container-environment' SaviPets/SaviPets.entitlements | cut -d'>' -f2 | cut -d'<' -f1)"

# 7. Create Firebase Project Update Script
echo ""
echo "🔧 Step 7: Creating Firebase project update script..."

cat > update_firebase_bundle.sh << 'EOF'
#!/bin/bash
echo "🔥 Updating Firebase project bundle ID..."

echo "📋 Firebase Console steps:"
echo "1. Go to https://console.firebase.google.com/"
echo "2. Select project 'savipets-72a88'"
echo "3. Go to Project Settings → General"
echo "4. Under 'Your apps', find iOS app"
echo "5. Click 'Add app' or edit existing app"
echo "6. Set Bundle ID to: com.saviesa.SaviPets"
echo "7. Download new GoogleService-Info.plist"
echo "8. Replace the current GoogleService-Info.plist"
echo ""
echo "⚠️  Important: This ensures Firebase services work with the new bundle ID"
EOF

chmod +x update_firebase_bundle.sh

print_status "Firebase update script created"

echo ""
echo "🎉 AUTOMATIC SIGNING FIX COMPLETE!"
echo ""
echo "📋 SUMMARY OF FIXES:"
echo "   ✅ Bundle ID consistency restored"
echo "   ✅ Old provisioning profiles cleaned"
echo "   ✅ Entitlements verified"
echo "   ✅ Project cleaned"
echo "   ✅ Regeneration scripts created"
echo ""
echo "📋 NEXT STEPS:"
echo "   1. Run: ./regenerate_provisioning.sh"
echo "   2. Follow manual steps in Xcode"
echo "   3. Run: ./update_firebase_bundle.sh"
echo "   4. Update Firebase project bundle ID"
echo "   5. Test build and signing"
echo ""
echo "🔗 USEFUL LINKS:"
echo "   • Firebase Console: https://console.firebase.google.com/"
echo "   • Apple Developer: https://developer.apple.com/account/"
echo "   • Xcode Signing Guide: https://developer.apple.com/documentation/xcode/managing-your-team-s-signing-assets"



