#!/bin/bash
# Script to fix Firebase dSYM upload issues for App Store submission

echo "🔧 Fixing Firebase dSYM upload issues..."

# Set project paths
PROJECT_NAME="SaviPets"
SCHEME_NAME="SaviPets"
ARCHIVE_PATH="./build/SaviPets.xcarchive"
DSYM_PATH="./build/dSYMs"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf ./build
mkdir -p ./build

# Build for release with debug symbols
echo "🏗️  Building archive with debug symbols..."
xcodebuild archive \
    -project ${PROJECT_NAME}.xcodeproj \
    -scheme ${SCHEME_NAME} \
    -configuration Release \
    -archivePath ${ARCHIVE_PATH} \
    -destination "generic/platform=iOS" \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    ENABLE_BITCODE=NO \
    STRIP_INSTALLED_PRODUCT=NO \
    SEPARATE_STRIP=NO \
    COPY_PHASE_STRIP=NO

# Verify dSYM files exist
echo "🔍 Verifying dSYM files..."
if [ -d "${ARCHIVE_PATH}/dSYMs" ]; then
    echo "✅ dSYM directory found"
    ls -la "${ARCHIVE_PATH}/dSYMs/"
    
    # Check for Firebase frameworks
    echo "🔍 Checking for Firebase frameworks..."
    find "${ARCHIVE_PATH}/dSYMs/" -name "*Firebase*" -type d
    find "${ARCHIVE_PATH}/dSYMs/" -name "*Google*" -type d
    find "${ARCHIVE_PATH}/dSYMs/" -name "*grpc*" -type d
    find "${ARCHIVE_PATH}/dSYMs/" -name "*absl*" -type d
    find "${ARCHIVE_PATH}/dSYMs/" -name "*openssl*" -type d
    
else
    echo "❌ dSYM directory not found!"
    exit 1
fi

# Upload to App Store Connect
echo "📤 Uploading to App Store Connect..."
xcodebuild -exportArchive \
    -archivePath ${ARCHIVE_PATH} \
    -exportPath ./build/export \
    -exportOptionsPlist ExportOptions.plist

echo "🎉 Build process complete!"
echo "📝 Next steps:"
echo "1. Upload the archive to App Store Connect"
echo "2. The dSYM files should now be included properly"







