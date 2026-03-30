#!/bin/bash
set -e

ROUNDABOUT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <conf-file>" >&2
    echo "  conf-file: path to a .conf file (relative to project root or absolute)" >&2
    exit 1
fi

CONF="$1"
PROJECT_DIR="$(pwd)"

# Derive output paths next to the conf file
CONF_DIR="$(dirname "$CONF")"
CONF_BASE="$(basename "$CONF" .conf)"
OUTPUT_JSON="${CONF_DIR}/${CONF_BASE}_roundabout.json"
OUTPUT_HTML="${CONF_DIR}/${CONF_BASE}_roundabout.html"

# Log verbose output to file
LOG_FILE=".certora_internal/roundabout.log"
mkdir -p .certora_internal

echo "Analyzing..."
bash "$ROUNDABOUT_DIR/roundabout.sh" "$PROJECT_DIR" "$CONF" "$OUTPUT_JSON" > "$LOG_FILE" 2>&1

echo "Generating HTML viewer..."
python3 "$ROUNDABOUT_DIR/viewer/generate_viewer.py" "$PROJECT_DIR" "$OUTPUT_JSON" "$OUTPUT_HTML" "$CONF"

echo "Done! Viewer generated at: $OUTPUT_HTML"
