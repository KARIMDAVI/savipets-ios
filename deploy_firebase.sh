#!/bin/bash

# ============================================================================
# Firebase Deployment Script for SaviPets
# ============================================================================
# This script deploys Firestore indexes, rules, and Cloud Functions
# Run from project root: ./deploy_firebase.sh
# ============================================================================

set -e

echo "🔥 SaviPets Firebase Deployment Script"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found${NC}"
    echo "Install with: npm install -g firebase-tools"
    exit 1
fi

echo -e "${GREEN}✅ Firebase CLI found${NC}"
echo ""

# Check if logged in
echo "Checking Firebase authentication..."
if ! firebase projects:list &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Firebase${NC}"
    echo "Running: firebase login"
    firebase login
fi

echo -e "${GREEN}✅ Firebase authenticated${NC}"
echo ""

# Show current project
CURRENT_PROJECT=$(firebase use 2>&1 | grep "Active Project" | awk '{print $3}' || echo "unknown")
echo "Current Firebase project: ${CURRENT_PROJECT}"
echo ""

# Prompt for confirmation
echo -e "${YELLOW}This will deploy:${NC}"
echo "  1. Firestore Security Rules"
echo "  2. Firestore Indexes (11 indexes)"
echo "  3. Cloud Functions (12 functions)"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "🚀 Starting deployment..."
echo ""

# ============================================================================
# STEP 1: Deploy Firestore Indexes
# ============================================================================

echo "📊 [1/4] Deploying Firestore indexes..."
if firebase deploy --only firestore:indexes; then
    echo -e "${GREEN}✅ Indexes deployed successfully${NC}"
else
    echo -e "${RED}❌ Index deployment failed${NC}"
    exit 1
fi
echo ""

# ============================================================================
# STEP 2: Deploy Firestore Rules
# ============================================================================

echo "🔐 [2/4] Deploying Firestore security rules..."
if firebase deploy --only firestore:rules; then
    echo -e "${GREEN}✅ Rules deployed successfully${NC}"
else
    echo -e "${RED}❌ Rules deployment failed${NC}"
    exit 1
fi
echo ""

# ============================================================================
# STEP 3: Build Cloud Functions
# ============================================================================

echo "🔨 [3/4] Building Cloud Functions..."
cd functions

if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

echo "Building TypeScript..."
if npm run build; then
    echo -e "${GREEN}✅ Functions built successfully${NC}"
else
    echo -e "${RED}❌ Function build failed${NC}"
    exit 1
fi

cd ..
echo ""

# ============================================================================
# STEP 4: Deploy Cloud Functions
# ============================================================================

echo "☁️  [4/4] Deploying Cloud Functions..."
if firebase deploy --only functions; then
    echo -e "${GREEN}✅ Functions deployed successfully${NC}"
else
    echo -e "${RED}❌ Function deployment failed${NC}"
    exit 1
fi
echo ""

# ============================================================================
# VERIFICATION
# ============================================================================

echo "🔍 Verifying deployment..."
echo ""

echo "Deployed Functions:"
firebase functions:list 2>&1 | grep -E "onNewMessage|onBookingApproved|onVisitStarted|dailyCleanupJob|weeklyAnalytics|dailyBackup|cleanupExpiredSessions|trackDailyActiveUser|aggregateSitterRevenue|auditAdminActions" || true
echo ""

echo "Firestore Indexes:"
firebase firestore:indexes 2>&1 | head -20 || true
echo ""

# ============================================================================
# POST-DEPLOYMENT REMINDERS
# ============================================================================

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}📋 POST-DEPLOYMENT CHECKLIST:${NC}"
echo ""
echo "1. Enable Cloud Scheduler API for scheduled functions:"
echo "   → https://console.cloud.google.com/cloudscheduler"
echo ""
echo "2. Enable Cloud Firestore Admin API for backup function:"
echo "   → https://console.cloud.google.com/apis/library/firestore.googleapis.com"
echo ""
echo "3. Test push notifications:"
echo "   • Send a test message in the app"
echo "   • Check logs: firebase functions:log --only onNewMessage"
echo ""
echo "4. Monitor function execution:"
echo "   • firebase functions:log"
echo "   • Check Firebase Console → Functions"
echo ""
echo "5. Verify scheduled jobs are configured:"
echo "   • Firebase Console → Functions"
echo "   • Look for scheduler icons on:"
echo "     - dailyCleanupJob (2 AM EST daily)"
echo "     - cleanupExpiredSessions (every 6 hours)"
echo "     - weeklyAnalytics (Monday 3 AM EST)"
echo "     - dailyBackup (1 AM EST daily)"
echo ""

echo -e "${GREEN}🎉 Firebase backend is now fully configured and deployed!${NC}"
echo ""




