"""
Lean compilation fixer for RoundAbout.

Iteratively applies workarounds (solc version, packages, via-ir, EVM version, etc.)
to a certoraRun conf until compilation succeeds. Self-contained — no dependency on
certora-autosetup.
Customized for the single-file-at-a-time roundabout use case (flat config keys, no per-contract maps).
"""

import json
import os
import re
import shutil
import subprocess
import threading
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from packaging.specifiers import SpecifierSet
from packaging.version import Version

# =========================================================================
# Constants
# =========================================================================

DEFAULT_SOLC_VERSION = "solc8.34"

FALLBACK_SOLC_VERSIONS = [
    "0.8.33", "0.8.30", "0.8.28", "0.8.26", "0.8.24",
    "0.8.20", "0.8.0", "0.7.6", "0.6.12", "0.5.17", "0.4.26",
]

_PREFIX = "[fixcomp]"

# =========================================================================
# Solc version utilities (inlined from autosetup's solc_version_resolver.py
# and config_manager.py)
# =========================================================================

_solc_versions_cache: list[str] | None = None
_cache_lock = threading.Lock()
_solc_convention_cache: str | None = None  # "certora" or "solc-select"


def _log(msg: str) -> None:
    print(f"{_PREFIX} {msg}")


def fetch_available_solc_versions() -> list[str]:
    """Fetch available solc versions from soliditylang.org, with caching and fallback."""
    global _solc_versions_cache

    if _solc_versions_cache is not None:
        return _solc_versions_cache

    with _cache_lock:
        if _solc_versions_cache is not None:
            return _solc_versions_cache

        url = "https://binaries.soliditylang.org/macosx-amd64/list.json"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "RoundAbout/1.0"})
            response = urllib.request.urlopen(req, timeout=10)
            data = json.loads(response.read().decode("utf-8"))
            versions = list(data.get("releases", {}).keys())
            if not versions:
                raise ValueError("No versions found in response")
            _solc_versions_cache = versions
            return versions
        except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, KeyError, ValueError) as e:
            _log(f"Failed to fetch solc versions: {e}. Using fallback list.")
            _solc_versions_cache = FALLBACK_SOLC_VERSIONS
            return FALLBACK_SOLC_VERSIONS


def extract_pragma_spec(text: str) -> str | None:
    """Extract pragma solidity specification from source code or error output.

    Examples:
        "pragma solidity ^0.8.0;" -> "^0.8.0"
        "pragma  solidity  >=0.8.0 <0.8.6;" -> ">=0.8.0 <0.8.6"
    """
    pragma_match = re.search(r"pragma\s+solidity\s+([^;]+);", text)
    if pragma_match:
        return pragma_match.group(1).strip()
    return None


def parse_pragma_constraint(pragma_spec: str) -> SpecifierSet | None:
    """Convert pragma solidity specification to packaging.SpecifierSet.

    Handles exact version ("0.8.26"), caret ("^0.8.0"), and range (">=0.8.0 <0.8.6").
    """
    try:
        # Exact version
        if re.match(r"^\d+\.\d+\.\d+$", pragma_spec):
            return SpecifierSet(f"=={pragma_spec}")

        # Caret: "^0.8.0" -> ">=0.8.0,<0.9.0"
        caret_match = re.match(r"^\^(\d+)\.(\d+)\.(\d+)$", pragma_spec)
        if caret_match:
            major, minor, patch = caret_match.groups()
            if major == "0":
                next_minor = int(minor) + 1
                return SpecifierSet(f">={major}.{minor}.{patch},<{major}.{next_minor}.0")
            else:
                next_major = int(major) + 1
                return SpecifierSet(f">={major}.{minor}.{patch},<{next_major}.0.0")

        # Space-separated range: normalize and parse
        normalized = re.sub(r"\s+", "", pragma_spec)
        normalized = re.sub(r"(\d)([><=!~^])", r"\1,\2", normalized)
        return SpecifierSet(normalized)

    except Exception as e:
        _log(f"Failed to parse pragma constraint '{pragma_spec}': {e}")
        return None


def resolve_pragma_to_version(pragma_spec: str) -> str | None:
    """Resolve pragma specification to a concrete solc version string (e.g., "0.8.26")."""
    constraint = parse_pragma_constraint(pragma_spec)
    if constraint is None:
        return None

    available = fetch_available_solc_versions()
    matching = [v for v in available if Version(v) in constraint]
    if not matching:
        _log(f"No solc version found matching pragma '{pragma_spec}'")
        return None

    return max(matching, key=Version)


def detect_solc_convention() -> str:
    """Detect whether the system uses 'solc8.X' (Certora) or 'solc-0.8.X' (solc-select)."""
    global _solc_convention_cache
    if _solc_convention_cache is not None:
        return _solc_convention_cache

    # Check for Certora convention first (solc8.34)
    if shutil.which("solc8.34"):
        _solc_convention_cache = "certora"
        return "certora"

    # Check for solc-select convention (solc-0.8.34)
    if shutil.which("solc-0.8.34"):
        _solc_convention_cache = "solc-select"
        return "solc-select"

    # Default to Certora convention
    _solc_convention_cache = "certora"
    return "certora"


def format_solc_version(version: str) -> str:
    """Format a raw version string (e.g. '0.8.26') to the appropriate solc binary name."""
    v = version.lstrip("v")
    convention = detect_solc_convention()
    if convention == "solc-select":
        if not v.startswith("0."):
            v = f"0.{v}"
        return f"solc-{v}"
    else:
        # Certora format: "0.8.26" -> "solc8.26"
        if v.startswith("0."):
            return f"solc{v[2:]}"
        return f"solc{v}"


def certora_format_to_raw_version(certora_version: str) -> str | None:
    """Convert solc binary name to raw version: 'solc8.19' -> '0.8.19', 'solc-0.8.19' -> '0.8.19'."""
    if not certora_version:
        return None
    s = certora_version.strip()
    if s.startswith("solc-"):
        s = s[len("solc-"):]
    elif s.startswith("solc"):
        s = s[len("solc"):]
        if s and not s.startswith("0."):
            s = f"0.{s}"
    if s.count(".") >= 1 and s[0].isdigit():
        return s
    return None


# =========================================================================
# Detection functions
# =========================================================================

def _detect_version_mismatch(output: str) -> str | None:
    """Detect compiler version mismatch and return the pragma spec from the error."""
    if "ParserError: Source file requires different compiler version" not in output:
        return None

    lines = output.split("\n")
    for i, line in enumerate(lines):
        if "ParserError: Source file requires different compiler version" in line:
            # Look for pragma in subsequent lines
            for k in range(i + 1, min(i + 10, len(lines))):
                spec = extract_pragma_spec(lines[k])
                if spec:
                    return spec
    return None


def _detect_solc_not_found(output: str) -> str | None:
    """Detect 'Cannot run solcX.XX' error. Returns the failed binary name."""
    match = re.search(r"attribute/flag 'solc': Cannot run (solc\S+)", output)
    if match:
        return match.group(1)
    return None


def _detect_remappings_conflict(output: str) -> bool:
    return "package.json and remappings.txt include duplicated keys in" in output


def _detect_source_not_found(output: str) -> bool:
    return 'ParserError: Source "' in output and "File not found" in output


def _detect_stack_too_deep(output: str) -> bool:
    return "CompilerError: Stack too deep" in output


def _detect_unsupported_solc_via_ir(output: str) -> bool:
    return "Unsupported solc version" in output and "solc_via_ir" in output


def _detect_cancun_opcodes(output: str) -> bool:
    return any(
        f'DeclarationError: Function "{op}" not found' in output
        for op in ("mcopy", "tload", "tstore")
    )


def _detect_unnamed_return_warning(output: str) -> bool:
    return "Unnamed return variable can remain unassigned" in output


def _detect_yul_stack_too_deep(output: str) -> bool:
    return bool(re.search(r"YulException:.*Stack too deep", output, re.IGNORECASE))


# =========================================================================
# Apply functions — each modifies conf_data in place
# =========================================================================

def _apply_version_fix(conf_data: dict[str, Any], pragma_spec: str, project_root: str) -> None:
    """Set solc to the version resolved from the pragma spec."""
    version = resolve_pragma_to_version(pragma_spec)
    if not version:
        _log(f"Could not resolve pragma '{pragma_spec}' to a version")
        return
    solc_binary = format_solc_version(version)
    _log(f"Setting solc to {solc_binary} (from pragma '{pragma_spec}')")
    conf_data["solc"] = solc_binary


def _apply_solc_fallback(conf_data: dict[str, Any], failed_solc: str, project_root: str) -> None:
    """Fall back from a missing versioned solc binary."""
    # Try plain 'solc' first
    fallback = "solc"

    # Check if default versioned binary exists
    default = DEFAULT_SOLC_VERSION
    convention = detect_solc_convention()
    if convention == "solc-select":
        raw = certora_format_to_raw_version(DEFAULT_SOLC_VERSION)
        if raw:
            default = f"solc-{raw}"

    if shutil.which(default):
        fallback = default

    _log(f"Falling back from '{failed_solc}' to '{fallback}'")
    conf_data["solc"] = fallback


def _apply_packages_from_remappings(conf_data: dict[str, Any], _detection: Any, project_root: str) -> None:
    """Build explicit packages list from remappings.txt and package.json."""
    packages = []
    remapping_keys: dict[str, str] = {}

    remappings_path = Path(project_root) / "remappings.txt"
    if remappings_path.exists():
        for line in remappings_path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            packages.append(line)
            parts = line.split("=", 1)
            key = parts[0].rstrip("/")
            remapping_keys[key] = parts[1] if len(parts) > 1 else ""

    package_json_path = Path(project_root) / "package.json"
    if package_json_path.exists():
        try:
            package_data = json.loads(package_json_path.read_text())
            for section in ("dependencies", "devDependencies", "resolutions"):
                for key in package_data.get(section, {}):
                    normalized = key.rstrip("/")
                    if normalized not in remapping_keys:
                        packages.append(f"{key}=node_modules/{key}")
                        remapping_keys[normalized] = f"node_modules/{key}"
        except (json.JSONDecodeError, KeyError):
            pass

    _log(f"Setting packages ({len(packages)} entries)")
    conf_data["packages"] = packages


def _apply_via_ir(conf_data: dict[str, Any], _detection: Any, _project_root: str) -> None:
    _log("Enabling solc_via_ir for stack-too-deep error")
    conf_data["solc_via_ir"] = True


def _apply_disable_via_ir(conf_data: dict[str, Any], _detection: Any, _project_root: str) -> None:
    _log("Disabling solc_via_ir (unsupported by solc version)")
    conf_data.pop("solc_via_ir", None)
    conf_data.pop("solc_via_ir_map", None)


def _apply_evm_cancun(conf_data: dict[str, Any], _detection: Any, _project_root: str) -> None:
    _log("Setting solc_evm_version to cancun")
    conf_data["solc_evm_version"] = "cancun"


def _apply_ignore_warnings(conf_data: dict[str, Any], _detection: Any, _project_root: str) -> None:
    _log("Setting ignore_solidity_warnings")
    conf_data["ignore_solidity_warnings"] = True


def _apply_optimizer(conf_data: dict[str, Any], _detection: Any, _project_root: str) -> None:
    _log("Adding solc_optimize 200 for YulException stack-too-deep")
    conf_data["solc_optimize"] = "200"


# =========================================================================
# Workaround definitions
# =========================================================================

# Each workaround: (name, detect_fn, apply_fn, guard_fn)
# - detect_fn(output) -> truthy detection result or None
# - apply_fn(conf_data, detection_result, project_root) -> None (modifies conf_data in place)
# - guard_fn(conf_data) -> bool (should this workaround be attempted?)

def _workarounds(project_root: str) -> list[tuple[str, Any, Any, Any]]:
    return [
        (
            "solc_not_found_fallback",
            _detect_solc_not_found,
            _apply_solc_fallback,
            lambda d: "solc" in d,
        ),
        (
            "remappings_conflict",
            lambda output: True if _detect_remappings_conflict(output) else None,
            _apply_packages_from_remappings,
            lambda d: "packages" not in d,
        ),
        (
            "source_not_found_packages",
            lambda output: True if _detect_source_not_found(output) else None,
            _apply_packages_from_remappings,
            lambda d: "packages" not in d and Path(project_root, "remappings.txt").exists(),
        ),
        (
            "compiler_version_mismatch",
            _detect_version_mismatch,
            _apply_version_fix,
            lambda d: "solc" not in d and "compiler_map" not in d,
        ),
        (
            "stack_too_deep_via_ir",
            lambda output: True if _detect_stack_too_deep(output) else None,
            _apply_via_ir,
            lambda d: not d.get("solc_via_ir") and "solc_via_ir_map" not in d,
        ),
        (
            "unsupported_solc_via_ir",
            lambda output: True if _detect_unsupported_solc_via_ir(output) else None,
            _apply_disable_via_ir,
            lambda d: d.get("solc_via_ir", False),
        ),
        (
            "cancun_opcode_evm_version",
            lambda output: True if _detect_cancun_opcodes(output) else None,
            _apply_evm_cancun,
            lambda d: "solc_evm_version" not in d and "solc_evm_version_map" not in d,
        ),
        (
            "unnamed_return_warning",
            lambda output: True if _detect_unnamed_return_warning(output) else None,
            _apply_ignore_warnings,
            lambda d: "ignore_solidity_warnings" not in d,
        ),
        (
            "yul_exception_add_optimizer",
            lambda output: True if _detect_yul_stack_too_deep(output) else None,
            _apply_optimizer,
            lambda d: "solc_optimize" not in d,
        ),
    ]


# =========================================================================
# Main entry point
# =========================================================================

def fix_compilation(
    conf_path: str,
    conf_data: dict[str, Any],
    cmd: list[str],
    project_root: str,
) -> tuple[bool, dict[str, Any]]:
    """Iteratively fix compilation errors by applying workarounds.

    Runs certoraRun, inspects error output, applies the first matching workaround,
    rewrites the conf file, and retries. Repeats until compilation succeeds or no
    workaround applies.

    Args:
        conf_path: Path to the working .conf file (will be rewritten on each fix)
        conf_data: Parsed conf dict (modified in place)
        cmd: certoraRun command list (including conf_path)
        project_root: Project root directory

    Returns:
        (success, conf_data) — success is True if compilation eventually succeeded
    """
    max_retries = 10
    applied: set[str] = set()
    workarounds = _workarounds(project_root)

    for attempt in range(max_retries):
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        output = result.stdout + result.stderr

        if result.returncode == 0:
            if attempt > 0:
                _log(f"Compilation succeeded after {attempt} workaround(s)")
            return True, conf_data

        # Try workarounds in priority order
        fixed = False
        for name, detect_fn, apply_fn, guard_fn in workarounds:
            if name in applied:
                continue
            if not guard_fn(conf_data):
                continue
            detection = detect_fn(output)
            if detection is not None:
                _log(f"Applying workaround: {name}")
                apply_fn(conf_data, detection, project_root)
                # Rewrite conf file
                with open(conf_path, "w") as f:
                    json.dump(conf_data, f, indent=4)
                applied.add(name)
                fixed = True
                break

        if not fixed:
            _log("Compilation failed with no applicable workaround")
            return False, conf_data

    _log(f"Max retries ({max_retries}) exceeded")
    return False, conf_data
