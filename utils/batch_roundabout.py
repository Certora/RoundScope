#!/usr/bin/env python3
"""Batch-run RoundAbout over all certora/**/*.conf files under a root directory."""

import argparse
import csv
import json5
import os
import re
import subprocess
import sys

SKIP_DIRS = {".certora_internal", ".certora_sources"}


def find_conf_files(root_path):
    """Find all .conf files under any certora/ directory, skipping internal dirs."""
    confs = []
    for dirpath, dirnames, filenames in os.walk(root_path):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]

        # Check if we're inside a certora/ directory path component
        rel = os.path.relpath(dirpath, root_path)
        parts = rel.split(os.sep)
        if "certora" not in parts:
            continue

        for fname in filenames:
            if fname.endswith(".conf"):
                confs.append(os.path.join(dirpath, fname))

    return sorted(confs)


def _git_info(project_dir):
    """Return (repo_url, branch) for project_dir, or ("", "") on failure."""
    try:
        url = subprocess.run(
            ["git", "-C", project_dir, "config", "--get", "remote.origin.url"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except Exception:
        url = ""
    try:
        branch = subprocess.run(
            ["git", "-C", project_dir, "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except Exception:
        branch = ""
    return url, branch


def _extract_file_paths(conf_data):
    """Extract Solidity file paths from conf data, stripping :ContractName suffixes."""
    paths = []
    for entry in conf_data.get("files", []):
        # "src/Foo.sol:Bar" -> "src/Foo.sol"
        path = entry.split(":")[0]
        paths.append(path)
    return paths


def _count_resolved_files(candidate_dir, file_paths):
    """Count how many file paths resolve relative to candidate_dir."""
    return sum(
        1 for p in file_paths
        if os.path.isfile(os.path.join(candidate_dir, p))
    )


def derive_project_dir(conf_abs, root_path):
    """Derive the project directory by finding where conf file paths resolve.

    Starts with the parent of the certora/ directory component, then tries
    up to two levels higher. Picks the candidate that resolves the most files
    (some may be missing due to uninitialized submodules, etc.).
    """
    rel = os.path.relpath(conf_abs, root_path)
    parts = rel.split(os.sep)
    try:
        certora_idx = parts.index("certora")
    except ValueError:
        return root_path

    if certora_idx == 0:
        base_dir = root_path
    else:
        base_dir = os.path.join(root_path, *parts[:certora_idx])

    # Try to parse the conf and resolve file paths
    try:
        with open(conf_abs) as f:
            conf_data = json5.load(f)
        file_paths = _extract_file_paths(conf_data)
    except Exception:
        return base_dir

    if not file_paths:
        return base_dir

    # Pick the candidate that resolves the most files
    candidates = [base_dir, os.path.dirname(base_dir), os.path.dirname(os.path.dirname(base_dir))]
    best = max(candidates, key=lambda c: _count_resolved_files(c, file_paths))
    return best


def main():
    parser = argparse.ArgumentParser(
        description="Scan a directory for certora/**/*.conf files and run RoundAbout on each."
    )
    parser.add_argument(
        "--certora-run-command",
        default="certoraRun",
        help="Command to use instead of certoraRun (default: certoraRun)",
    )
    parser.add_argument(
        "root_path",
        help="Root directory to scan for certora conf files",
    )
    args = parser.parse_args()

    root_path = os.path.abspath(args.root_path)
    if not os.path.isdir(root_path):
        print(f"Error: {root_path} is not a valid directory.", file=sys.stderr)
        sys.exit(1)
    csv_file = os.path.join(root_path, "roundabout_results.csv")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    run_roundabout = os.path.join(script_dir, "..", ".claude", "skills", "run_roundabout", "run_roundabout.py")

    conf_files = find_conf_files(root_path)

    with open(csv_file, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["repo_url", "branch", "project_dir", "path_to_conf", "success_html", "error"])

        for conf_abs in conf_files:
            project_dir = derive_project_dir(conf_abs, root_path)
            conf_rel = os.path.relpath(conf_abs, project_dir)
            repo_url, branch = _git_info(project_dir)

            print(f"=== Running: {conf_rel} (project: {project_dir}) ===")

            log_file = os.path.join(project_dir, ".certora_internal", "roundabout.log")

            # Record current log line count
            log_start = 0
            if os.path.isfile(log_file):
                with open(log_file) as lf:
                    log_start = sum(1 for _ in lf)

            success_html = ""
            error = ""

            result = subprocess.run(
                [
                    sys.executable, run_roundabout,
                    "--certora-run-command", args.certora_run_command,
                    conf_rel,
                ],
                cwd=project_dir,
                capture_output=True,
                text=True,
            )

            if result.returncode == 0:
                # Extract HTML path from output
                match = re.search(r"Viewer generated at: (.+)", result.stdout)
                if match:
                    html_path = match.group(1).strip()
                    if not os.path.isabs(html_path):
                        html_path = os.path.join(project_dir, html_path)
                    success_html = html_path
                print(f"  SUCCESS: {success_html}")
            else:
                # Extract log lines from this run
                if os.path.isfile(log_file):
                    with open(log_file) as lf:
                        lines = lf.readlines()
                    error = "".join(lines[log_start:][-20:])
                if not error:
                    error = result.stdout + result.stderr
                print("  FAILED")

            writer.writerow([repo_url, branch, project_dir, conf_rel, success_html, error])
            f.flush()

    print()
    print(f"Results written to: {csv_file}")


if __name__ == "__main__":
    main()
