"""Shared fixtures for viewer tests."""

import json
import os
import sys

import pytest

# Add viewer directory to path so we can import generate_viewer
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

TESTS_DIR = os.path.dirname(__file__)
FIXTURE_DIR = os.path.join(TESTS_DIR, "fixtures")


def pytest_addoption(parser):
    parser.addoption(
        "--update-golden",
        action="store_true",
        default=False,
        help="Update golden files with actual test output instead of asserting equality",
    )


@pytest.fixture
def update_golden(request):
    return request.config.getoption("--update-golden")


@pytest.fixture
def hub_data():
    """Load the Hub RoundAbout JSON fixture."""
    path = os.path.join(FIXTURE_DIR, "output-Hub.json")
    with open(path, "r") as f:
        return json.load(f)


@pytest.fixture
def aave_project_root():
    """Path to the aave-v4 project root (source files).

    Uses AAVE_V4_ROOT env var if set, else /tmp/aave-v4 (CI clone location).
    Skips the test if not available.
    """
    root = os.environ.get("AAVE_V4_ROOT", "/tmp/aave-v4")
    if not os.path.isdir(root):
        pytest.skip(f"aave-v4 project root not found at {root}. Set AAVE_V4_ROOT env var.")
    return root


@pytest.fixture
def hub_source_files(hub_data, aave_project_root):
    """Read source files referenced by the Hub fixture."""
    from generate_viewer import (
        collect_referenced_files_from_paths,
        extract_graphs,
        extract_roundings,
    )

    aggregated = extract_roundings(hub_data, aave_project_root)
    all_files = set(aggregated.keys())
    graphs = extract_graphs(hub_data, aave_project_root)
    for g in graphs:
        for node in g["nodes"].values():
            if node["file"]:
                all_files.add(node["file"])

    return collect_referenced_files_from_paths(all_files, aave_project_root)
