#!/usr/bin/env python3
"""Run the RoundAbout pipeline and generate an HTML viewer for a Certora conf file."""

import argparse
import os
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(
        description="Run RoundAbout analysis and generate an HTML viewer."
    )
    parser.add_argument(
        "--certora-run-command",
        default="certoraRun",
        help="Command to use instead of certoraRun (default: certoraRun)",
    )
    parser.add_argument(
        "conf_file",
        help="Path to a .conf file (relative to project root or absolute)",
    )
    args = parser.parse_args()

    roundabout_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    project_dir = os.getcwd()

    conf = args.conf_file
    conf_dir = os.path.dirname(conf)
    conf_base = os.path.splitext(os.path.basename(conf))[0]
    output_json = os.path.join(conf_dir, f"{conf_base}_roundabout.json")
    output_html = os.path.join(conf_dir, f"{conf_base}_roundabout.html")

    # Set up logging
    log_dir = os.path.join(project_dir, ".certora_internal")
    os.makedirs(log_dir, exist_ok=True)
    log_file = os.path.join(log_dir, "roundabout.log")

    print("Analyzing...")
    with open(log_file, "a") as log:
        result = subprocess.run(
            [
                sys.executable,
                os.path.join(roundabout_dir, "roundabout.py"),
                "--certora-run-command", args.certora_run_command,
                project_dir, conf, output_json,
            ],
            stdout=log,
            stderr=log,
        )
    if result.returncode != 0:
        print(f"Error: Analysis failed. See {log_file} for details.", file=sys.stderr)
        sys.exit(1)

    print("Generating HTML viewer...")
    result = subprocess.run(
        [
            sys.executable,
            os.path.join(roundabout_dir, "viewer", "generate_viewer.py"),
            project_dir, output_json, output_html, conf,
        ],
    )
    if result.returncode != 0:
        print("Error: HTML viewer generation failed.", file=sys.stderr)
        sys.exit(1)

    print(f"Done! Viewer generated at: {output_html}")


if __name__ == "__main__":
    main()
