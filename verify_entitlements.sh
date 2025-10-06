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
