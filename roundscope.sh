#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JAR="$SCRIPT_DIR/target/com.certora.RoundScope-0.0.1-SNAPSHOT.jar"

if [ $# -lt 3 ]; then
    echo "Usage: $0 <project-root> <conf-file> <output-json>" >&2
    exit 1
fi

PROJECT_DIR="$1"
CONF="$2"
OUTPUT="$3"

cd "$PROJECT_DIR"

echo "Running certoraRun to dump ASTs..."
certoraRun "$CONF" --dump_asts --compilation_steps_only

echo "Running RoundScope analysis..."
java -jar "$JAR" \
     "$CONF" \
     "$OUTPUT" \
     --combined .certora_internal/latest/.asts.json
