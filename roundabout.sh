#!/bin/bash
set -e

# Helper script used for internal testing and debugging the JSON-AST workflow.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JAR="$SCRIPT_DIR/target/roundabout-0.0.1-SNAPSHOT.jar"

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

if [ $# -lt 3 ]; then
    echo "Usage: $0 [--certora-run-command <cmd>] <project-root> <conf-file> <output-json>" >&2
    exit 1
fi

PROJECT_DIR="$1"
CONF="$2"
OUTPUT="$3"

cd "$PROJECT_DIR"

# Record timestamp before running certoraRun
TIMESTAMP_REF=$(mktemp)
touch "$TIMESTAMP_REF"

echo "Running $CERTORA_RUN_CMD to dump ASTs..."
"$CERTORA_RUN_CMD" "$CONF" --dump_asts --build_only --disable_local_typechecking --ignore_solidity_warnings --disable_internal_function_instrumentation || true

ASTS_FILE=".certora_internal/latest/.asts.json"
if [ ! -f "$ASTS_FILE" ] || [ "$ASTS_FILE" -ot "$TIMESTAMP_REF" ]; then
    rm -f "$TIMESTAMP_REF"
    echo "Error: $ASTS_FILE not found or not updated by certoraRun." >&2
    exit 1
fi
rm -f "$TIMESTAMP_REF"

echo "Running RoundAbout analysis..."
java -jar "$JAR" \
     "$CONF" \
     "$OUTPUT" \
     --combined "$ASTS_FILE"
