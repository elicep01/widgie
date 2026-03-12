#!/bin/bash
set -euo pipefail

#─────────────────────────────────────────────────────────
# widgie — Release Build & DMG Packaging Script
#─────────────────────────────────────────────────────────
# Usage:
#   ./scripts/build-release.sh              # Development-signed build
#   ./scripts/build-release.sh --notarize   # Build + notarize (requires Developer ID cert)
#
# Output: build/widgie-<version>.dmg
#─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/widgie.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_NAME="widgie"
SCHEME="widgie"
NOTARIZE=false

# Parse args
for arg in "$@"; do
    case $arg in
        --notarize) NOTARIZE=true ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}▸${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }

#─────────────────────────────────────────────────────────
echo -e "\n${BOLD}widgie — Release Build${NC}\n"

# Clean previous build artifacts
info "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Extract version from project
VERSION=$(grep -A1 "MARKETING_VERSION" "$PROJECT_DIR/pane.xcodeproj/project.pbxproj" | grep -o '[0-9]\+\.[0-9]\+' | head -1)
BUILD_NUMBER=$(grep -A1 "CURRENT_PROJECT_VERSION" "$PROJECT_DIR/pane.xcodeproj/project.pbxproj" | grep -o '[0-9]\+' | head -1)
info "Version: $VERSION (build $BUILD_NUMBER)"

#─────────────────────────────────────────────────────────
# Step 1: Archive
#─────────────────────────────────────────────────────────
info "Archiving $SCHEME (Release)..."
xcodebuild archive \
    -project "$PROJECT_DIR/pane.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -quiet \
    CODE_SIGN_STYLE=Automatic \
    2>&1 | tail -5

if [ ! -d "$ARCHIVE_PATH" ]; then
    error "Archive failed — $ARCHIVE_PATH not found"
    exit 1
fi
success "Archive created"

#─────────────────────────────────────────────────────────
# Step 2: Export .app from archive
#─────────────────────────────────────────────────────────
info "Exporting .app..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$PROJECT_DIR/ExportOptions.plist" \
    -quiet \
    2>&1 | tail -5

APP_PATH="$EXPORT_DIR/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    error "Export failed — $APP_PATH not found"
    exit 1
fi
success "Exported $APP_NAME.app"

#─────────────────────────────────────────────────────────
# Step 3: Verify code signature
#─────────────────────────────────────────────────────────
info "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH" 2>&1 && success "Code signature valid" || {
    error "Code signature verification failed"
    exit 1
}

# Show signing info
codesign -dvv "$APP_PATH" 2>&1 | grep -E "^(Authority|TeamIdentifier|Identifier)" | while read line; do
    info "  $line"
done

#─────────────────────────────────────────────────────────
# Step 4: Notarize (optional)
#─────────────────────────────────────────────────────────
if [ "$NOTARIZE" = true ]; then
    info "Creating ZIP for notarization..."
    NOTARIZE_ZIP="$BUILD_DIR/$APP_NAME-notarize.zip"
    ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

    info "Submitting to Apple for notarization..."
    echo -e "${BLUE}  This may take several minutes...${NC}"

    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --keychain-profile "notarytool-profile" \
        --wait \
        2>&1 | tee "$BUILD_DIR/notarize-log.txt"

    if grep -q "status: Accepted" "$BUILD_DIR/notarize-log.txt"; then
        success "Notarization accepted!"

        info "Stapling notarization ticket..."
        xcrun stapler staple "$APP_PATH"
        success "Stapled"
    else
        error "Notarization failed — check build/notarize-log.txt"
        echo -e "${RED}  To set up notarization credentials:${NC}"
        echo -e "${RED}  xcrun notarytool store-credentials notarytool-profile --apple-id YOUR_APPLE_ID --team-id 7V5Q2J643P${NC}"
        exit 1
    fi

    rm -f "$NOTARIZE_ZIP"
fi

#─────────────────────────────────────────────────────────
# Step 5: Create DMG
#─────────────────────────────────────────────────────────
DMG_NAME="$APP_NAME-$VERSION"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"

info "Creating DMG..."
mkdir -p "$DMG_STAGING"

# Copy app
cp -R "$APP_PATH" "$DMG_STAGING/"

# Create Applications symlink for drag-to-install
ln -s /Applications "$DMG_STAGING/Applications"

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH" \
    > /dev/null 2>&1

rm -rf "$DMG_STAGING"

if [ ! -f "$DMG_PATH" ]; then
    error "DMG creation failed"
    exit 1
fi

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)
success "DMG created: $DMG_PATH ($DMG_SIZE)"

#─────────────────────────────────────────────────────────
# Step 6: Also create a ZIP for direct distribution
#─────────────────────────────────────────────────────────
ZIP_PATH="$BUILD_DIR/$DMG_NAME.zip"
info "Creating ZIP..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1 | xargs)
success "ZIP created: $ZIP_PATH ($ZIP_SIZE)"

#─────────────────────────────────────────────────────────
# Summary
#─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Build complete!${NC}"
echo -e "  ${GREEN}DMG:${NC} $DMG_PATH"
echo -e "  ${GREEN}ZIP:${NC} $ZIP_PATH"
echo -e "  ${GREEN}App:${NC} $APP_PATH"
echo ""

if [ "$NOTARIZE" = false ]; then
    echo -e "${BLUE}Note:${NC} This build is development-signed."
    echo -e "For public distribution, you need a Developer ID certificate."
    echo -e "  1. Enroll at https://developer.apple.com/programs/"
    echo -e "  2. Create a 'Developer ID Application' certificate in Xcode"
    echo -e "  3. Update ExportOptions.plist method to 'developer-id'"
    echo -e "  4. Run: ./scripts/build-release.sh --notarize"
fi
