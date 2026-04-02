#!/bin/bash
ROUNDABOUT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

# --- Defaults ---
CERTORA_RUN_CMD="certoraRun"

# --- Parse named options ---
while [ $# -gt 0 ]; do
    case "$1" in
        --certora-run-command)
            [ $# -lt 2 ] && { echo "Error: --certora-run-command requires a value." >&2; exit 1; }
            CERTORA_RUN_CMD="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        --*)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -lt 1 ]; then
    echo "Usage: $0 [--certora-run-command <cmd>] <conf-file>" >&2
    echo "  conf-file: path to a .conf file (relative to project root or absolute)" >&2
    echo "  --certora-run-command <cmd>: command to use instead of certoraRun (default: certoraRun)" >&2
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
if ! bash "$ROUNDABOUT_DIR/roundabout.sh" --certora-run-command "$CERTORA_RUN_CMD" "$PROJECT_DIR" "$CONF" "$OUTPUT_JSON" >> "$LOG_FILE" 2>&1; then
    echo "Error: Analysis failed. See $LOG_FILE for details." >&2
    exit 1
fi

echo "Generating HTML viewer..."
if ! python3 "$ROUNDABOUT_DIR/viewer/generate_viewer.py" "$PROJECT_DIR" "$OUTPUT_JSON" "$OUTPUT_HTML" "$CONF"; then
    echo "Error: HTML viewer generation failed." >&2
    exit 1
fi

echo "Done! Viewer generated at: $OUTPUT_HTML"
