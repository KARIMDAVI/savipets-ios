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
