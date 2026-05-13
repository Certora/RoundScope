"""Shared fixtures for integration tests."""

import json
import os
import re
import shutil

import json5
import pytest

# Repo root: two levels up from this file (tests/integration/conftest.py → repo root)
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEST_DATA_DIR = os.path.join(REPO_ROOT, "test", "data")
VIEWER_SCRIPT = os.path.join(REPO_ROOT, "viewer", "generate_viewer.py")
ROUNDABOUT_SCRIPT = os.path.join(REPO_ROOT, "roundabout.py")
JAR_PATH = os.path.join(REPO_ROOT, "target", "roundabout-0.0.1-SNAPSHOT.jar")


def _has_certorarun():
    return shutil.which("certoraRun") is not None


def _has_java_and_jar():
    return shutil.which("java") is not None and os.path.isfile(JAR_PATH)


requires_certorarun = pytest.mark.skipif(not _has_certorarun(), reason="certoraRun not found on PATH")
requires_java = pytest.mark.skipif(not _has_java_and_jar(), reason="java not found or jar not built")
requires_full_pipeline = pytest.mark.skipif(
    not (_has_certorarun() and _has_java_and_jar()),
    reason="Full pipeline requires certoraRun + java + built jar",
)


def discover_conf_files():
    """Find all .conf files in test/data/ subdirectories."""
    confs = []
    for entry in sorted(os.listdir(TEST_DATA_DIR)):
        subdir = os.path.join(TEST_DATA_DIR, entry)
        if not os.path.isdir(subdir):
            continue
        for fname in os.listdir(subdir):
            if fname.endswith(".conf"):
                confs.append((entry, os.path.join(subdir, fname)))
    return confs


def discover_sol_files():
    """Find all unique .sol files in test/data/ (deduplicate shared files like ERC20ish.sol)."""
    seen = set()
    sols = []
    for entry in sorted(os.listdir(TEST_DATA_DIR)):
        subdir = os.path.join(TEST_DATA_DIR, entry)
        if not os.path.isdir(subdir):
            continue
        for fname in sorted(os.listdir(subdir)):
            if fname.endswith(".sol") and fname not in seen:
                seen.add(fname)
                sols.append((fname, os.path.join(subdir, fname)))
    return sols


def discover_json_files():
    """Find all pre-generated run_roundabout.json files in test/data/."""
    jsons = []
    for entry in sorted(os.listdir(TEST_DATA_DIR)):
        subdir = os.path.join(TEST_DATA_DIR, entry)
        if not os.path.isdir(subdir):
            continue
        json_path = os.path.join(subdir, "run_roundabout.json")
        if os.path.isfile(json_path):
            # Find the corresponding conf file
            conf_path = None
            for fname in os.listdir(subdir):
                if fname.endswith(".conf"):
                    conf_path = os.path.join(subdir, fname)
                    break
            jsons.append((entry, json_path, conf_path))
    return jsons


def derive_project_root(conf_path):
    """Derive the project root for a conf file by checking where its file paths resolve."""
    try:
        with open(conf_path) as f:
            conf_data = json5.load(f)
    except Exception:
        return os.path.dirname(conf_path)

    files = conf_data.get("files", [])
    file_paths = [entry.split(":")[0] for entry in files]
    if not file_paths:
        return os.path.dirname(conf_path)

    # Try conf dir first, then repo root
    conf_dir = os.path.dirname(conf_path)
    candidates = [conf_dir, REPO_ROOT]
    for candidate in candidates:
        resolved = sum(1 for p in file_paths if os.path.isfile(os.path.join(candidate, p)))
        if resolved == len(file_paths):
            return candidate

    # Fallback: whichever resolves more
    return max(candidates, key=lambda c: sum(1 for p in file_paths if os.path.isfile(os.path.join(c, p))))


def validate_viewer_html(html_path, min_size=5000, require_non_neither=True):
    """Validate generated viewer HTML. Returns parsed DATA dict.

    Assertions:
    1. File exists and size > min_size
    2. Starts with <!DOCTYPE html>, ends with </html>
    3. Contains 'const DATA =' with parseable JSON
    4. DATA.contexts has at least 1 context
    5. At least 1 file has at least 1 annotation
    6. Optionally: at least 1 annotation has rounding != "Neither"
    """
    assert os.path.isfile(html_path), f"HTML file not found: {html_path}"
    size = os.path.getsize(html_path)
    assert size > min_size, f"HTML file too small: {size} bytes (expected > {min_size})"

    with open(html_path) as f:
        html = f.read()

    assert html.startswith("<!DOCTYPE html>"), "HTML doesn't start with <!DOCTYPE html>"
    assert "</html>" in html, "HTML doesn't contain </html>"
    assert "const DATA =" in html, "HTML doesn't contain embedded DATA"
    assert "Certora RoundAbout" in html, "HTML doesn't contain 'Certora RoundAbout'"

    # Parse the embedded DATA JSON
    data_match = re.search(r"const DATA = ({.*?});\n", html, re.DOTALL)
    assert data_match, "Could not extract DATA JSON from HTML"
    data = json.loads(data_match.group(1))

    # Validate contexts
    contexts = data.get("contexts", {})
    assert len(contexts) >= 1, "DATA.contexts is empty"

    # Count total annotations
    total_annotations = 0
    has_non_neither = False
    for ctx_name, file_anns in contexts.items():
        for filename, anns in file_anns.items():
            total_annotations += len(anns)
            for ann in anns:
                if ann.get("rounding") != "Neither":
                    has_non_neither = True

    assert total_annotations > 0, "No annotations found in any context"

    if require_non_neither:
        assert has_non_neither, "All annotations are 'Neither' — analysis produced no meaningful results"

    return data
