"""Tests for generate_viewer.py CLI argument parsing."""

import os
import subprocess
import sys
import tempfile

import pytest


VIEWER_SCRIPT = os.path.join(os.path.dirname(__file__), "..", "generate_viewer.py")
FIXTURE_JSON = os.path.join(os.path.dirname(__file__), "fixtures", "output-Hub.json")
STAKER_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "test", "data", "Staker")
STAKER_CONF = os.path.join(STAKER_DIR, "run.conf")


def test_help_shows_named_flags():
    """--help should list named flags, not positional args."""
    result = subprocess.run(
        [sys.executable, VIEWER_SCRIPT, "--help"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0
    assert "--project-root" in result.stdout
    assert "--input-file" in result.stdout
    assert "--output" in result.stdout
    assert "--json-input" in result.stdout
    assert "--conf-file" in result.stdout


def test_json_input_without_input_file():
    """--json-input mode should work without --input-file."""
    with tempfile.TemporaryDirectory() as tmpdir:
        output_html = os.path.join(tmpdir, "out.html")
        result = subprocess.run(
            [
                sys.executable, VIEWER_SCRIPT,
                "--json-input", FIXTURE_JSON,
                "--project-root", tmpdir,
                "--output", output_html,
            ],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        assert os.path.exists(output_html)
        with open(output_html) as f:
            content = f.read()
        assert "<html" in content.lower()


def test_json_input_with_conf_file():
    """--json-input with --conf-file should extract contract names."""
    if not os.path.exists(STAKER_CONF):
        pytest.skip("Staker test fixture not available")
    with tempfile.TemporaryDirectory() as tmpdir:
        output_html = os.path.join(tmpdir, "out.html")
        result = subprocess.run(
            [
                sys.executable, VIEWER_SCRIPT,
                "--json-input", FIXTURE_JSON,
                "--project-root", tmpdir,
                "--output", output_html,
                "--conf-file", STAKER_CONF,
            ],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        assert os.path.exists(output_html)


def test_standard_mode_requires_input_file():
    """Standard mode (no --json-input) should fail without --input-file."""
    with tempfile.TemporaryDirectory() as tmpdir:
        output_html = os.path.join(tmpdir, "out.html")
        result = subprocess.run(
            [
                sys.executable, VIEWER_SCRIPT,
                "--project-root", tmpdir,
                "--output", output_html,
            ],
            capture_output=True, text=True,
        )
        assert result.returncode != 0
        assert "--input-file is required" in result.stderr


def test_missing_required_args_fails():
    """Missing --project-root or --output should fail."""
    result = subprocess.run(
        [sys.executable, VIEWER_SCRIPT, "--input-file", "foo.conf"],
        capture_output=True, text=True,
    )
    assert result.returncode != 0
