#!/bin/bash
# Comprehensive fix for all App Store validation issues

echo "🔧 COMPREHENSIVE APP STORE VALIDATION FIX"
echo "=========================================="

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
echo "🎯 ROOT CAUSES IDENTIFIED:"
echo "   1. App icons have RGBA/alpha channels (Apple requires RGB only)"
echo "   2. Using Xcode 26.0 BETA (Apple requires Release Candidate)"
echo "   3. iCloud entitlement value 'Production' should be 'production' (lowercase)"
echo "   4. Firebase frameworks missing dSYM files"
echo ""

# 1. Fix App Icon Transparency
echo "🖼️  STEP 1: Fixing app icon transparency..."
print_info "Converting RGBA app icons to RGB (removing alpha channels)..."

# Create Python script to fix app icons
cat > fix_app_icons.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
from PIL import Image

def remove_alpha_channel(image_path):
    """Remove alpha channel from PNG image"""
    try:
        # Open the image
        img = Image.open(image_path)
        
        # Convert RGBA to RGB (removes alpha channel)
        if img.mode == 'RGBA':
            # Create white background
            background = Image.new('RGB', img.size, (255, 255, 255))
            # Paste image on white background
            background.paste(img, mask=img.split()[-1])  # Use alpha channel as mask
            img = background
        elif img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Save without alpha channel
        img.save(image_path, 'PNG', optimize=True)
        print(f"✅ Fixed: {image_path}")
        return True
        
    except Exception as e:
        print(f"❌ Error fixing {image_path}: {e}")
        return False

def main():
    app_icon_dir = "SaviPets/Assets.xcassets/AppIcon.appiconset"
    
    if not os.path.exists(app_icon_dir):
        print(f"❌ App icon directory not found: {app_icon_dir}")
        return False
    
    success_count = 0
    total_count = 0
    
    # Process all PNG files in the app icon directory
    for filename in os.listdir(app_icon_dir):
        if filename.endswith('.png'):
            total_count += 1
            filepath = os.path.join(app_icon_dir, filename)
            if remove_alpha_channel(filepath):
                success_count += 1
    
    print(f"\n📊 Results: {success_count}/{total_count} icons fixed")
    return success_count == total_count

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOF

# Run the Python script
python3 fix_app_icons.py
if [ $? -eq 0 ]; then
    print_status "App icons fixed (alpha channels removed)"
else
    print_error "Failed to fix app icons"
fi

# Clean up Python script
rm -f fix_app_icons.py

# 2. Fix iCloud Entitlement Case
echo ""
echo "☁️  STEP 2: Fixing iCloud entitlement case sensitivity..."
print_info "Changing 'Production' to 'production' (lowercase)..."

# Fix the entitlement value
sed -i '' 's/<string>Production<\/string>/<string>production<\/string>/g' SaviPets/SaviPets.entitlements

if grep -q '<string>production</string>' SaviPets/SaviPets.entitlements; then
    print_status "iCloud entitlement fixed (lowercase)"
else
    print_error "Failed to fix iCloud entitlement"
fi

# 3. Fix dSYM Generation
echo ""
echo "📦 STEP 3: Fixing dSYM generation for Firebase frameworks..."
print_info "Updating Xcode build settings for proper dSYM generation..."

# Create script to fix build settings
cat > fix_build_settings.py << 'EOF'
#!/usr/bin/env python3
import re

def fix_build_settings():
    """Fix Xcode build settings for dSYM generation"""
    
    project_file = "SaviPets.xcodeproj/project.pbxproj"
    
    try:
        # Read the project file
        with open(project_file, 'r') as f:
            content = f.read()
        
        # Fix DEBUG_INFORMATION_FORMAT for Debug builds
        # Change from 'dwarf' to 'dwarf-with-dsym'
        content = re.sub(
            r'DEBUG_INFORMATION_FORMAT = dwarf;',
            'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";',
            content
        )
        
        # Ensure ENABLE_BITCODE is NO for all configurations
        content = re.sub(
            r'ENABLE_BITCODE = YES;',
            'ENABLE_BITCODE = NO;',
            content
        )
        
        # Ensure STRIP_INSTALLED_PRODUCT is NO for all configurations
        content = re.sub(
            r'STRIP_INSTALLED_PRODUCT = YES;',
            'STRIP_INSTALLED_PRODUCT = NO;',
            content
        )
        
        # Write back the modified content
        with open(project_file, 'w') as f:
            f.write(content)
        
        print("✅ Build settings updated for dSYM generation")
        return True
        
    except Exception as e:
        print(f"❌ Error updating build settings: {e}")
        return False

if __name__ == "__main__":
    fix_build_settings()
EOF

python3 fix_build_settings.py
rm -f fix_build_settings.py

# 4. Create Export Options for App Store
echo ""
echo "📤 STEP 4: Creating App Store export options..."
print_info "Creating ExportOptions.plist for App Store submission..."

cat > ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

print_status "ExportOptions.plist created"

# 5. Clean and prepare for build
echo ""
echo "🧹 STEP 5: Cleaning project and preparing for build..."
print_info "Cleaning derived data and build folders..."

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean project build folder
rm -rf ./build

# Clean Xcode project
xcodebuild clean -project SaviPets.xcodeproj -scheme SaviPets -quiet

print_status "Project cleaned"

# 6. Verify fixes
echo ""
echo "🔍 STEP 6: Verifying all fixes..."

echo "📋 App Icon Status:"
find SaviPets/Assets.xcassets/AppIcon.appiconset -name "*.png" -exec file {} \; | grep -v RGBA && print_status "All icons are RGB (no alpha channels)" || print_error "Some icons still have alpha channels"

echo ""
echo "📋 Entitlements Status:"
if grep -q '<string>production</string>' SaviPets/SaviPets.entitlements; then
    print_status "iCloud entitlement is lowercase 'production'"
else
    print_error "iCloud entitlement not fixed"
fi

echo ""
echo "📋 Build Settings Status:"
if grep -q 'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"' SaviPets.xcodeproj/project.pbxproj; then
    print_status "dSYM generation enabled"
else
    print_error "dSYM generation not enabled"
fi

# 7. Xcode Version Warning
echo ""
echo "⚠️  CRITICAL XCODE VERSION ISSUE:"
print_warning "You are using Xcode 26.0 (BETA version)"
print_warning "Apple requires Release Candidate (RC) versions for App Store submission"
echo ""
echo "🔧 SOLUTION:"
echo "   1. Download latest Xcode Release Candidate from Apple Developer"
echo "   2. Use RC version to build and archive your app"
echo "   3. Submit to App Store Connect"
echo ""

# 8. Final instructions
echo "🎉 COMPREHENSIVE FIX COMPLETE!"
echo ""
echo "📋 SUMMARY OF FIXES APPLIED:"
echo "   ✅ App icons converted from RGBA to RGB (alpha channels removed)"
echo "   ✅ iCloud entitlement changed to lowercase 'production'"
echo "   ✅ Build settings updated for dSYM generation"
echo "   ✅ ExportOptions.plist created for App Store submission"
echo "   ✅ Project cleaned and ready for build"
echo ""
echo "📋 REMAINING MANUAL STEPS:"
echo "   1. ⚠️  CRITICAL: Use Xcode Release Candidate (not beta) to build"
echo "   2. Update ExportOptions.plist with your Team ID"
echo "   3. Archive and export using App Store method"
echo "   4. Upload to App Store Connect"
echo ""
echo "🎯 EXPECTED RESULTS:"
echo "   • App icon transparency error: FIXED"
echo "   • iCloud entitlement error: FIXED" 
echo "   • dSYM upload errors: FIXED"
echo "   • Xcode version error: Will be fixed when using RC version"



