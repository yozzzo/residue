#!/bin/bash
# Residue: Test → Build → Archive → Upload pipeline
# Tests MUST pass before build proceeds.

set -e

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

cd "$PROJECT_DIR"

echo "============================================"
echo "  Residue Build Pipeline"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

# ── Step 1: Run Tests ──
echo "── Step 1: Running Tests ──"
bash scripts/run_tests.sh
echo ""

# ── Step 2: Export iOS ──
echo "── Step 2: Exporting iOS build ──"
mkdir -p "$BUILD_DIR/ios"
"$GODOT" --headless --export-debug "iOS" "$BUILD_DIR/ios/Residue.xcodeproj"
echo "Export complete."
echo ""

# ── Step 3: Archive ──
echo "── Step 3: Archiving ──"
cd "$BUILD_DIR/ios"
xcodebuild archive \
    -project Residue.xcodeproj \
    -scheme Residue \
    -archivePath "$BUILD_DIR/Residue.xcarchive" \
    -destination 'generic/platform=iOS' \
    DEVELOPMENT_TEAM=VFXCM2MZXL \
    CODE_SIGN_IDENTITY="Apple Development" \
    CODE_SIGN_STYLE=Automatic \
    | tail -20
cd "$PROJECT_DIR"
echo "Archive complete."
echo ""

# ── Step 4: Export IPA ──
echo "── Step 4: Exporting IPA ──"
mkdir -p "$BUILD_DIR/export"
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/Residue.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR/export" \
    | tail -10
echo "IPA export complete."
echo ""

# ── Step 5: Upload to TestFlight ──
echo "── Step 5: Uploading to TestFlight ──"
xcrun altool --upload-app \
    -f "$BUILD_DIR/export/Residue.ipa" \
    -t ios \
    --apiKey ZA6JN86PAF \
    --apiIssuer dfcc0e25-db7c-4adc-9c2f-17b42d7ef421
echo ""

echo "============================================"
echo "  Build pipeline complete!"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
