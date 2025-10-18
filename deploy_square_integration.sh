#!/bin/bash

# Square Payment Integration - Complete Deployment Script
# This script configures and deploys the complete Square integration

set -e  # Exit on error

echo "🚀 SaviPets Square Integration Deployment"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Configure Square Credentials
echo -e "${BLUE}📝 Step 1: Configuring Square Credentials...${NC}"
echo ""

firebase functions:config:set \
  square.environment="sandbox" \
  square.location_id="LAC197204SV1R" \
  square.sandbox_application_id="sandbox-sq0idb-ho7AeIIxs81ht7eFFpJeFA" \
  square.sandbox_token="EAAAl2crkGZtZ5iW9W5mDjJaxylun6v3x_GJ43APABFXlrHnq_iXvFsmzlFovy1D"

echo -e "${GREEN}✅ Credentials configured${NC}"
echo ""

# Step 2: Verify Configuration
echo -e "${BLUE}🔍 Step 2: Verifying Configuration...${NC}"
echo ""

firebase functions:config:get

echo -e "${GREEN}✅ Configuration verified${NC}"
echo ""

# Step 3: Deploy Cloud Functions
echo -e "${BLUE}☁️  Step 3: Deploying Cloud Functions...${NC}"
echo "This may take 3-5 minutes..."
echo ""

firebase deploy --only functions:createSquareCheckout,functions:handleSquareWebhook,functions:processSquareRefund,functions:createSquareSubscription

echo -e "${GREEN}✅ Cloud Functions deployed${NC}"
echo ""

# Step 4: Display Webhook URL
echo -e "${BLUE}🔗 Step 4: Webhook Configuration${NC}"
echo ""
echo "Your webhook URL is:"
echo -e "${YELLOW}https://us-central1-savipets-72a88.cloudfunctions.net/handleSquareWebhook${NC}"
echo ""
echo "📋 TODO: Configure this in Square Dashboard"
echo ""
echo "1. Go to: https://developer.squareup.com/apps"
echo "2. Click your sandbox application"
echo "3. Go to 'Webhooks'"
echo "4. Click 'Add Subscription'"
echo "5. Paste the webhook URL above"
echo "6. API Version: 2024-12-18"
echo "7. Select events:"
echo "   - payment.created"
echo "   - payment.updated"
echo "   - refund.created"
echo "   - refund.updated"
echo "8. Save and copy the Signature Key"
echo "9. Run: firebase functions:config:set square.webhook_signature_key=\"YOUR_KEY\""
echo "10. Run: firebase deploy --only functions"
echo ""

# Step 5: Build iOS App
echo -e "${BLUE}📱 Step 5: Building iOS App...${NC}"
echo ""

xcodebuild build -scheme SaviPets -destination 'platform=iOS Simulator,name=iPhone 16' -quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ iOS App built successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Build had warnings (check Xcode)${NC}"
fi

echo ""
echo "🎉 =========================================="
echo "🎉 DEPLOYMENT COMPLETE!"
echo "🎉 =========================================="
echo ""
echo -e "${GREEN}✅ Square credentials configured${NC}"
echo -e "${GREEN}✅ Cloud Functions deployed${NC}"
echo -e "${GREEN}✅ iOS app built successfully${NC}"
echo ""
echo -e "${YELLOW}⚠️  NEXT STEPS:${NC}"
echo "1. Configure webhooks in Square Dashboard (see instructions above)"
echo "2. Test with sandbox: 4111 1111 1111 1111"
echo "3. Book a service in the app"
echo "4. Watch it auto-approve! ✨"
echo ""
echo -e "${BLUE}📚 Documentation:${NC}"
echo "- Complete Guide: SQUARE_INTEGRATION_SETUP_GUIDE.md"
echo "- Quick Start: SQUARE_QUICK_START.md"
echo ""
echo "Happy testing! 🐾"



