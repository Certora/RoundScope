#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_ROUNDABOUT="$SCRIPT_DIR/../.claude/skills/run_roundabout/run_roundabout.sh"

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
    echo "Usage: $0 [--certora-run-command <cmd>] <root-path>" >&2
    echo "  Scans <root-path> for certora/**/*.conf files and runs RoundAbout on each." >&2
    exit 1
fi

ROOT_PATH="$(cd "$1" && pwd)"
CSV_FILE="$ROOT_PATH/roundabout_results.csv"

echo "project_dir,path_to_conf,success_html,error" > "$CSV_FILE"

escape_csv() {
    local val="$1"
    # If value contains comma, quote, or newline, wrap in quotes and escape inner quotes
    if [[ "$val" == *","* || "$val" == *'"'* || "$val" == *$'\n'* ]]; then
        val="${val//\"/\"\"}"
        val="\"$val\""
    fi
    printf '%s' "$val"
}

# Find all .conf files under any certora/ directory
find "$ROOT_PATH" -path '*/.certora_internal' -prune -o -path '*/certora/*.conf' -type f -print | sort | while read -r conf_abs; do
    # Derive project dir: parent of the certora/ directory
    # e.g. /root/proj/certora/sub/foo.conf -> /root/proj
    certora_rel="${conf_abs#"$ROOT_PATH"/}"
    # Find the certora/ component in the path
    project_rel="${certora_rel%%certora/*}"
    if [ -z "$project_rel" ]; then
        project_dir="$ROOT_PATH"
    else
        project_dir="$ROOT_PATH/${project_rel%/}"
    fi

    # Conf path relative to project dir
    conf_rel="${conf_abs#"$project_dir"/}"

    echo "=== Running: $conf_rel (project: $project_dir) ==="

    log_file="$project_dir/.certora_internal/roundabout.log"

    # Record current log line count before this run
    if [ -f "$log_file" ]; then
        log_start=$(wc -l < "$log_file")
    else
        log_start=0
    fi

    success_html=""
    error=""

    # Run from the project dir
    output=$(cd "$project_dir" && bash "$RUN_ROUNDABOUT" --certora-run-command "$CERTORA_RUN_CMD" "$conf_rel" 2>&1) && rc=0 || rc=$?

    if [ $rc -eq 0 ]; then
        # Extract HTML path from output
        html_path=$(echo "$output" | grep -o 'Viewer generated at: .*' | sed 's/Viewer generated at: //')
        if [ -n "$html_path" ]; then
            # Make absolute if relative
            if [[ "$html_path" != /* ]]; then
                success_html="$project_dir/$html_path"
            else
                success_html="$html_path"
            fi
        fi
        echo "  SUCCESS: $success_html"
    else
        # Extract only the log lines from this run
        if [ -f "$log_file" ]; then
            error=$(tail -n +"$((log_start + 1))" "$log_file" | tail -20)
        fi
        if [ -z "$error" ]; then
            error="$output"
        fi
        echo "  FAILED"
    fi

    # Write CSV row
    printf '%s,%s,%s,%s\n' \
        "$(escape_csv "$project_dir")" \
        "$(escape_csv "$conf_rel")" \
        "$(escape_csv "$success_html")" \
        "$(escape_csv "$error")" >> "$CSV_FILE"
done

echo ""
echo "Results written to: $CSV_FILE"
