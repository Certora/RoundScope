#!/usr/bin/env python3
"""Run the RoundAbout pipeline and generate an HTML viewer for a Certora conf or sol file."""

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
        "input_file",
        help="Path to a .conf or .sol file (relative to project root or absolute)",
    )
    args = parser.parse_args()

    roundabout_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    project_dir = os.getcwd()

    conf = args.input_file
    conf_dir = os.path.dirname(conf)
    conf_base = os.path.splitext(os.path.basename(conf))[0]
    output_html = f"{conf_base}_roundabout.html"

    print("Running RoundAbout pipeline and generating HTML viewer...")
    cmd = [
        sys.executable,
        os.path.join(roundabout_dir, "viewer", "generate_viewer.py"),
    ]
    if args.certora_run_command != "certoraRun":
        cmd.extend(["--certora-run-command", args.certora_run_command])
    cmd.extend([project_dir, conf, output_html])
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print("Error: HTML viewer generation failed.", file=sys.stderr)
        sys.exit(1)

    print(f"Done! Viewer generated at: {output_html}")


if __name__ == "__main__":
    main()
