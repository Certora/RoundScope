"""Integration tests: run the viewer pipeline on all test/data examples.

Test categories:
A. Pre-generated JSON tests (fast, no certoraRun/Java needed)
B. Clean pipeline tests (full pipeline, needs certoraRun + Java + jar)
C. Fault injection tests (compilation fixer validation)
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

import json5
import pytest

from tests.integration.conftest import (
    REPO_ROOT,
    VIEWER_SCRIPT,
    derive_project_root,
    discover_conf_files,
    discover_json_files,
    discover_sol_files,
    requires_full_pipeline,
    validate_viewer_html,
)

# =========================================================================
# Parametrize IDs
# =========================================================================

_CONF_FILES = discover_conf_files()
_SOL_FILES = discover_sol_files()
_JSON_FILES = discover_json_files()

_conf_ids = [name for name, _ in _CONF_FILES]
_sol_ids = [name for name, _ in _SOL_FILES]
_json_ids = [name for name, _, _ in _JSON_FILES]


# =========================================================================
# A. Pre-generated JSON tests (no certoraRun needed)
# =========================================================================


@pytest.mark.parametrize("name,json_path,conf_path", _JSON_FILES, ids=_json_ids)
def test_viewer_from_json(name, json_path, conf_path, tmp_path):
    """Test viewer HTML generation from pre-generated roundabout JSON.

    These tests validate the viewer itself (extraction + HTML generation)
    without needing certoraRun or Java.
    """
    project_root = derive_project_root(conf_path) if conf_path else REPO_ROOT
    output_html = str(tmp_path / f"{name}_viewer.html")

    cmd = [
        sys.executable, VIEWER_SCRIPT,
        "--project-root", project_root,
        "--json-input", json_path,
        "--output", output_html,
    ]
    if conf_path:
        cmd.extend(["--conf-file", conf_path])

    result = subprocess.run(cmd, capture_output=True, text=True)
    assert result.returncode == 0, f"generate_viewer.py failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"

    data = validate_viewer_html(output_html)
    print(f"  {name}: {len(data['contexts'])} contexts, validated OK")


# =========================================================================
# B. Clean pipeline tests (full pipeline)
# =========================================================================


@requires_full_pipeline
@pytest.mark.parametrize("name,conf_path", _CONF_FILES, ids=_conf_ids)
def test_viewer_from_conf(name, conf_path, tmp_path):
    """Run the full pipeline (certoraRun → roundabout Java → viewer) on each .conf file."""
    project_root = derive_project_root(conf_path)
    output_html = str(tmp_path / f"{name}_viewer.html")

    cmd = [
        sys.executable, VIEWER_SCRIPT,
        "--project-root", project_root,
        "--input-file", conf_path,
        "--output", output_html,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    assert result.returncode == 0, (
        f"Full pipeline failed for {name}:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )

    data = validate_viewer_html(output_html)
    print(f"  {name}: {len(data['contexts'])} contexts, validated OK")


@requires_full_pipeline
@pytest.mark.parametrize("name,sol_path", _SOL_FILES, ids=_sol_ids)
def test_viewer_from_sol(name, sol_path, tmp_path):
    """Run the full pipeline on each .sol file directly (auto-generated conf)."""
    # Use the sol file's directory as project root
    project_root = os.path.dirname(sol_path)
    sol_relative = os.path.basename(sol_path)
    output_html = str(tmp_path / f"{name}_viewer.html")

    cmd = [
        sys.executable, VIEWER_SCRIPT,
        "--project-root", project_root,
        "--input-file", sol_relative,
        "--output", output_html,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    assert result.returncode == 0, (
        f"Full pipeline failed for {name}:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )

    # Relaxed validation for single-file mode — may have fewer annotations
    data = validate_viewer_html(output_html, min_size=3000, require_non_neither=False)
    print(f"  {name}: {len(data['contexts'])} contexts, validated OK")


# =========================================================================
# C. Fault injection tests (compilation fixer validation)
# =========================================================================


def _make_faulted_conf(conf_path, fault_fn, tmp_path):
    """Read a conf file, apply a fault function, write to tmp_path. Returns new conf path."""
    with open(conf_path) as f:
        conf_data = json5.load(f)
    fault_fn(conf_data)
    faulted_conf = str(tmp_path / "faulted.conf")
    with open(faulted_conf, "w") as f:
        json.dump(conf_data, f, indent=4)
    return faulted_conf


def _copy_sol_with_pragma(sol_path, pragma_version, tmp_dir):
    """Copy a .sol file, uncommenting/adding a pragma solidity line.

    Returns the path to the new .sol file (in tmp_dir with same basename).
    """
    with open(sol_path) as f:
        content = f.read()

    # Replace commented-out pragma with active one
    content = content.replace("// pragma solidity ^0.8;", f"pragma solidity {pragma_version};")
    content = content.replace("// pragma solidity ^0.8.0;", f"pragma solidity {pragma_version};")

    # If no pragma was uncommented, insert one at the top (after SPDX if present)
    if f"pragma solidity {pragma_version};" not in content:
        lines = content.split("\n")
        insert_idx = 0
        for i, line in enumerate(lines):
            if line.startswith("// SPDX"):
                insert_idx = i + 1
                break
        lines.insert(insert_idx, f"pragma solidity {pragma_version};")
        content = "\n".join(lines)

    new_path = os.path.join(tmp_dir, os.path.basename(sol_path))
    with open(new_path, "w") as f:
        f.write(content)
    return new_path


@requires_full_pipeline
@pytest.mark.parametrize("name,conf_path", _CONF_FILES, ids=_conf_ids)
def test_fault_nonexistent_solc(name, conf_path, tmp_path):
    """Inject a nonexistent solc binary — fixer should fall back to default."""
    def inject(conf_data):
        conf_data["solc"] = "solc99.99"

    faulted_conf = _make_faulted_conf(conf_path, inject, tmp_path)
    project_root = derive_project_root(conf_path)
    output_html = str(tmp_path / f"{name}_fault_solc.html")

    cmd = [
        sys.executable, VIEWER_SCRIPT,
        "--project-root", project_root,
        "--input-file", faulted_conf,
        "--output", output_html,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    assert result.returncode == 0, (
        f"Pipeline failed with faulted solc for {name}:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )

    data = validate_viewer_html(output_html)
    print(f"  {name}: fixer recovered from nonexistent solc, {len(data['contexts'])} contexts")


@requires_full_pipeline
@pytest.mark.parametrize("name,conf_path", _CONF_FILES, ids=_conf_ids)
def test_fault_version_mismatch(name, conf_path, tmp_path):
    """Uncomment pragmas with exact version, leave solc unset — fixer should detect mismatch and resolve.

    Uses pragma solidity 0.8.20 (exact) which will likely mismatch the default solc.
    The fixer should detect the ParserError and resolve the pragma to the correct version.
    """
    project_root = derive_project_root(conf_path)

    # Read conf to find all .sol files
    with open(conf_path) as f:
        conf_data = json5.load(f)

    # Copy all .sol files from the project to tmp, uncommenting pragmas
    sol_dir = str(tmp_path / "sol")
    os.makedirs(sol_dir, exist_ok=True)

    file_entries = conf_data.get("files", [])
    for entry in file_entries:
        sol_name = entry.split(":")[0]
        sol_abs = os.path.join(project_root, sol_name)
        if os.path.isfile(sol_abs):
            _copy_sol_with_pragma(sol_abs, "0.8.20", sol_dir)

    # Also copy any spec files referenced
    verify = conf_data.get("verify", "")
    if ":" in verify:
        spec_name = verify.split(":")[1]
        spec_abs = os.path.join(project_root, spec_name)
        if os.path.isfile(spec_abs):
            shutil.copy2(spec_abs, sol_dir)

    # Build new conf pointing to the temp sol copies (relative to sol_dir)
    new_files = []
    for entry in file_entries:
        parts = entry.split(":")
        sol_basename = os.path.basename(parts[0])
        if len(parts) > 1:
            new_files.append(f"{sol_basename}:{parts[1]}")
        else:
            new_files.append(sol_basename)
    conf_data["files"] = new_files

    # Remove solc to let the fixer detect and set it
    conf_data.pop("solc", None)
    conf_data.pop("compiler_map", None)

    faulted_conf = str(tmp_path / "faulted_version.conf")
    with open(faulted_conf, "w") as f:
        json.dump(conf_data, f, indent=4)

    output_html = str(tmp_path / f"{name}_fault_version.html")
    cmd = [
        sys.executable, VIEWER_SCRIPT,
        "--project-root", sol_dir,
        "--input-file", faulted_conf,
        "--output", output_html,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    assert result.returncode == 0, (
        f"Pipeline failed with version mismatch for {name}:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )

    data = validate_viewer_html(output_html, require_non_neither=False)
    print(f"  {name}: fixer recovered from version mismatch, {len(data['contexts'])} contexts")


@requires_full_pipeline
@pytest.mark.parametrize("name,conf_path", _CONF_FILES, ids=_conf_ids)
def test_fault_ignore_warnings(name, conf_path, tmp_path):
    """Inject ignore_solidity_warnings=false — if compilation produces warnings, fixer should re-enable."""
    def inject(conf_data):
        # Force solidity warnings to NOT be ignored — if the compilation produces
        # unnamed return warnings, the fixer should re-enable this
        conf_data.pop("ignore_solidity_warnings", None)

    # This test just verifies the pipeline succeeds regardless
    # (the default extra_flags include --ignore_solidity_warnings so roundabout may handle it)
    faulted_conf = _make_faulted_conf(conf_path, inject, tmp_path)
    project_root = derive_project_root(conf_path)
    output_html = str(tmp_path / f"{name}_fault_warnings.html")

    cmd = [
        sys.executable, VIEWER_SCRIPT,
        "--project-root", project_root,
        "--input-file", faulted_conf,
        "--output", output_html,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    assert result.returncode == 0, (
        f"Pipeline failed with warnings fault for {name}:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )

    data = validate_viewer_html(output_html, require_non_neither=False)
    print(f"  {name}: pipeline succeeded, {len(data['contexts'])} contexts")
