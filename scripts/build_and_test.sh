#!/bin/bash
# Build & Test Pipeline for Residue
# テスト通らなきゃビルドしない。t-wadaの前でも胸を張れるように。

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

# ── Step 1: Pre-flight Check ──
echo "── Step 1: Pre-flight Check ──"
"$GODOT" --headless -s scripts/build_preflight_check.gd
echo ""

# ── Step 2: Unit Tests (GUT) ──
echo "── Step 2: Unit Tests ──"
bash scripts/run_tests.sh
echo ""

# ── Step 3: Export iOS ──
echo "── Step 3: Exporting iOS build ──"
mkdir -p "$BUILD_DIR/ios"
"$GODOT" --headless --export-debug "iOS" "$BUILD_DIR/ios/Residue.xcodeproj"
echo "Export complete."
echo ""

# ── Step 4: Archive ──
echo "── Step 4: Archiving ──"
cd "$BUILD_DIR/ios"
xcodebuild archive \
    -project Residue.xcodeproj \
    -scheme Residue \
    -archivePath "$BUILD_DIR/Residue.xcarchive" \
    -destination 'generic/platform=iOS' \
    DEVELOPMENT_TEAM=VFXCM2MZXL \
    CODE_SIGN_IDENTITY="Apple Development" \
    CODE_SIGN_STYLE=Automatic \
    -quiet
cd "$PROJECT_DIR"
echo "Archive complete."
echo ""

# ── Step 5: Export IPA & Upload ──
echo "── Step 5: Exporting IPA & Uploading to TestFlight ──"
rm -rf "$BUILD_DIR/export"
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/Residue.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR/export" \
    -allowProvisioningUpdates \
    -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_ZA6JN86PAF.p8 \
    -authenticationKeyID ZA6JN86PAF \
    -authenticationKeyIssuerID dfcc0e25-db7c-4adc-9c2f-17b42d7ef421
echo ""

echo "============================================"
echo "  ✅ Build pipeline complete!"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
