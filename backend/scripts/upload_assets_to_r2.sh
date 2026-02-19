#!/bin/bash
# Upload game assets to R2 and generate manifest.json
# Usage: CLOUDFLARE_API_TOKEN=xxx ./upload_assets_to_r2.sh

set -e

RESIDUE_DIR="$HOME/dev/residue"
BUCKET="residue-shared"
MANIFEST_FILE="/tmp/residue_manifest.json"
ACCOUNT_ID="848813969a5dbe909336b748d210ec8c"

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN not set"
  exit 1
fi

# Collect all assets
ASSETS=()

# Background images
for f in "$RESIDUE_DIR/assets/generated/backgrounds/"*.png; do
  [ -f "$f" ] && ASSETS+=("backgrounds/$(basename "$f"):$f:image")
done

# Title images
for f in "$RESIDUE_DIR/assets/generated/title/"*.png; do
  [ -f "$f" ] && ASSETS+=("title/$(basename "$f"):$f:image")
done

# Silhouettes
for f in "$RESIDUE_DIR/assets/generated/silhouettes/"*.png; do
  [ -f "$f" ] && ASSETS+=("silhouettes/$(basename "$f"):$f:image")
done

# Button images
for f in "$RESIDUE_DIR/assets/generated/buttons/"*.png; do
  [ -f "$f" ] && ASSETS+=("buttons/$(basename "$f"):$f:image")
done

# BGM
for f in "$RESIDUE_DIR/assets/audio/bgm/"*.ogg; do
  [ -f "$f" ] && ASSETS+=("audio/bgm/$(basename "$f"):$f:audio")
done

# SE
for f in "$RESIDUE_DIR/assets/audio/se/"*.ogg; do
  [ -f "$f" ] && ASSETS+=("audio/se/$(basename "$f"):$f:audio")
done

echo "Found ${#ASSETS[@]} assets to upload"

# Build manifest JSON
echo '{"version":"1.0.0","assets":[' > "$MANIFEST_FILE"
FIRST=true

for entry in "${ASSETS[@]}"; do
  IFS=':' read -r rel_path full_path asset_type <<< "$entry"
  
  # Calculate SHA256 hash
  hash=$(shasum -a 256 "$full_path" | cut -d' ' -f1)
  # Get file size
  size=$(stat -f%z "$full_path" 2>/dev/null || stat -c%s "$full_path" 2>/dev/null)
  
  # Upload to R2 via wrangler
  echo "Uploading: assets/$rel_path"
  npx wrangler r2 object put "$BUCKET/assets/$rel_path" --file="$full_path" --content-type="$(file --mime-type -b "$full_path")" --remote 2>/dev/null || {
    echo "  Warning: upload failed for $rel_path, retrying..."
    npx wrangler r2 object put "$BUCKET/assets/$rel_path" --file="$full_path" --remote 2>/dev/null || echo "  FAILED: $rel_path"
  }
  
  # Add to manifest
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo ',' >> "$MANIFEST_FILE"
  fi
  printf '{"path":"%s","hash":"%s","size":%s,"type":"%s"}' "$rel_path" "$hash" "$size" "$asset_type" >> "$MANIFEST_FILE"
done

echo ']}' >> "$MANIFEST_FILE"

echo ""
echo "Uploading manifest.json..."
npx wrangler r2 object put "$BUCKET/manifest.json" --file="$MANIFEST_FILE" --content-type="application/json" --remote

echo ""
echo "Done! Uploaded ${#ASSETS[@]} assets + manifest.json"
cat "$MANIFEST_FILE" | python3 -m json.tool 2>/dev/null || cat "$MANIFEST_FILE"
