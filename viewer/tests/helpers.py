"""Shared test utilities."""

import json
import os

import pytest

TESTS_DIR = os.path.dirname(__file__)
FIXTURE_DIR = os.path.join(TESTS_DIR, "fixtures")
GOLDEN_DIR = os.path.join(TESTS_DIR, "golden")


def normalize_annotations(annotations):
    """Sort annotations deterministically and normalize their nodeRefs."""
    normalized = []
    for ann in annotations:
        ann = dict(ann)
        if "nodeRefs" in ann and ann["nodeRefs"]:
            ann["nodeRefs"] = sorted(ann["nodeRefs"], key=lambda r: (r["g"], str(r["n"])))
        normalized.append(ann)
    return sorted(
        normalized,
        key=lambda a: (a.get("sl", 0), a.get("sc", 0), a.get("el", 0), a.get("ec", 0)),
    )


def assert_golden(actual, golden_name, update_golden):
    """Compare actual JSON-serializable data against a golden file.

    If update_golden is True, writes actual as the new golden file.
    """
    golden_path = os.path.join(GOLDEN_DIR, golden_name)
    actual_json = json.dumps(actual, indent=2, sort_keys=False) + "\n"

    if update_golden:
        os.makedirs(os.path.dirname(golden_path), exist_ok=True)
        with open(golden_path, "w") as f:
            f.write(actual_json)
        pytest.skip(f"Golden file updated: {golden_name}")

    with open(golden_path, "r") as f:
        expected_json = f.read()

    assert actual_json == expected_json, (
        f"Output differs from golden file {golden_name}.\n"
        f"Run with --update-golden to update, then review the diff."
    )
