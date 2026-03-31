#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JAR="$SCRIPT_DIR/target/roundabout-0.0.1-SNAPSHOT.jar"

if [ $# -lt 3 ]; then
    echo "Usage: $0 <project-root> <conf-file> <output-json>" >&2
    exit 1
fi

PROJECT_DIR="$1"
CONF="$2"
OUTPUT="$3"

cd "$PROJECT_DIR"

# Record timestamp before running certoraRun
TIMESTAMP_REF=$(mktemp)
touch "$TIMESTAMP_REF"

echo "Running certoraRun to dump ASTs..."
certoraRun "$CONF" --dump_asts --build_only --disable_local_typechecking --ignore_solidity_warnings --disable_internal_function_instrumentation || true

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
