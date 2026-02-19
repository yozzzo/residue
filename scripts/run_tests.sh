#!/bin/bash
# Run GUT tests headless
# Usage: ./scripts/run_tests.sh

set -e

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$GODOT" ]; then
    echo "ERROR: Godot not found at $GODOT"
    exit 1
fi

echo "=== Running Residue Tests ==="
echo "Project: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# Import resources first (needed for headless on first run)
if [ ! -d "$PROJECT_DIR/.godot/global_script_class_cache.cfg" ] || [ "$1" = "--reimport" ]; then
    "$GODOT" --headless --import 2>/dev/null || true
fi

# Run GUT tests
"$GODOT" --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/ \
    -gexit \
    -glog=2

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "=== ALL TESTS PASSED ==="
else
    echo ""
    echo "=== TESTS FAILED (exit code: $EXIT_CODE) ==="
fi

exit $EXIT_CODE
