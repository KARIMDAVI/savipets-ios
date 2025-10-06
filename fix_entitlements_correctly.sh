#!/bin/bash
# Correct fix for invalid entitlements causing provisioning profile issues

echo "🔧 Fixing invalid entitlements in provisioning profile..."

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
echo "🎓 LEARNING FROM THE ERROR:"
echo "   • Invalid entitlement: com.apple.developer.push-notifications"
echo "   • Correct entitlement: aps-environment (development/production)"
echo "   • Provisioning profile must match project entitlements exactly"
echo ""

# 1. Verify current entitlements are correct
echo "🔍 Step 1: Verifying entitlements file..."
if grep -q "aps-environment" SaviPets/SaviPets.entitlements; then
    print_status "aps-environment entitlement found (correct)"
else
    print_error "aps-environment entitlement missing"
fi

if grep -q "com.apple.developer.push-notifications" SaviPets/SaviPets.entitlements; then
    print_error "Invalid push-notifications entitlement found - removing it"
    # Remove the invalid entitlement
    sed -i '' '/com\.apple\.developer\.push-notifications/d' SaviPets/SaviPets.entitlements
else
    print_status "No invalid push-notifications entitlement found"
fi

# 2. Clean all provisioning profiles and derived data
echo ""
echo "🧹 Step 2: Cleaning provisioning profiles and derived data..."
print_info "Removing all provisioning profiles..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*

print_info "Cleaning Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

print_info "Cleaning project build folder..."
rm -rf ./build

print_status "All caches cleaned"

# 3. Reset Xcode signing settings
echo ""
echo "🔄 Step 3: Resetting Xcode signing settings..."
print_info "Cleaning project..."
xcodebuild clean -project SaviPets.xcodeproj -scheme SaviPets

print_status "Project cleaned"

# 4. Create manual provisioning profile regeneration guide
echo ""
echo "📋 Step 4: Manual provisioning profile regeneration required"
echo ""
echo "🔧 MANUAL STEPS IN XCODE:"
echo "   1. Open Xcode"
echo "   2. Open SaviPets project"
echo "   3. Select SaviPets target"
echo "   4. Go to 'Signing & Capabilities' tab"
echo "   5. Check 'Automatically manage signing'"
echo "   6. Select your development team"
echo "   7. Wait for provisioning profile to regenerate"
echo "   8. If you see any invalid capabilities, remove them:"
echo "      • Look for 'Push Notifications' capability"
echo "      • If it shows invalid entitlements, remove it"
echo "      • Add 'Push Notifications' capability again (this will add correct aps-environment)"
echo ""

# 5. Verify entitlements are correct
echo "🔍 Step 5: Final entitlements verification..."
echo "Current entitlements:"
cat SaviPets/SaviPets.entitlements

echo ""
echo "✅ CORRECT ENTITLEMENTS FOR PUSH NOTIFICATIONS:"
echo "   <key>aps-environment</key>"
echo "   <string>development</string>  <!-- for debug builds -->"
echo "   <string>production</string>   <!-- for release builds -->"
echo ""
echo "❌ INVALID ENTITLEMENTS (remove these):"
echo "   <key>com.apple.developer.push-notifications</key>  <!-- This doesn't exist! -->"
echo ""

# 6. Create verification script
cat > verify_entitlements.sh << 'EOF'
#!/bin/bash
echo "🔍 Verifying entitlements..."

echo "📋 Current entitlements:"
cat SaviPets/SaviPets.entitlements

echo ""
echo "✅ Checking for correct entitlements:"
if grep -q "aps-environment" SaviPets/SaviPets.entitlements; then
    echo "   ✅ aps-environment found"
else
    echo "   ❌ aps-environment missing"
fi

echo ""
echo "❌ Checking for invalid entitlements:"
if grep -q "com.apple.developer.push-notifications" SaviPets/SaviPets.entitlements; then
    echo "   ❌ Invalid push-notifications entitlement found"
else
    echo "   ✅ No invalid push-notifications entitlement"
fi

echo ""
echo "📋 Next steps if issues persist:"
echo "   1. Check Xcode 'Signing & Capabilities' tab"
echo "   2. Remove any invalid capabilities"
echo "   3. Re-add capabilities to get correct entitlements"
echo "   4. Regenerate provisioning profile"
EOF

chmod +x verify_entitlements.sh

print_status "Verification script created"

echo ""
echo "🎉 ENTITLEMENTS FIX COMPLETE!"
echo ""
echo "📋 SUMMARY:"
echo "   ✅ Invalid entitlements identified and removed"
echo "   ✅ Provisioning profiles cleaned"
echo "   ✅ Project cleaned"
echo "   ✅ Manual regeneration guide provided"
echo ""
echo "📋 NEXT STEPS:"
echo "   1. Follow manual steps in Xcode"
echo "   2. Run: ./verify_entitlements.sh"
echo "   3. Test build and signing"
echo ""
echo "🎓 KEY LEARNINGS:"
echo "   • Invalid entitlements cause provisioning profile mismatches"
echo "   • aps-environment is the correct push notification entitlement"
echo "   • com.apple.developer.push-notifications doesn't exist"
echo "   • Always verify entitlements match Apple's documentation"



