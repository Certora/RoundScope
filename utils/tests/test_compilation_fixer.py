"""Tests for the compilation fixer module.

Tests detection functions with realistic certoraRun error output,
apply functions with config dicts, and the full retry loop with mocked subprocess.
"""

import json
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

from utils.compilation_fixer import (
    _detect_cancun_opcodes,
    _detect_remappings_conflict,
    _detect_solc_not_found,
    _detect_source_not_found,
    _detect_stack_too_deep,
    _detect_unnamed_return_warning,
    _detect_unsupported_solc_via_ir,
    _detect_version_mismatch,
    _detect_yul_stack_too_deep,
    certora_format_to_raw_version,
    extract_pragma_spec,
    fix_compilation,
    format_solc_version,
    parse_pragma_constraint,
    resolve_pragma_to_version,
)


# =========================================================================
# Pragma / version utility tests
# =========================================================================


class TestExtractPragmaSpec:
    def test_caret(self):
        assert extract_pragma_spec("pragma solidity ^0.8.0;") == "^0.8.0"

    def test_range(self):
        assert extract_pragma_spec("pragma solidity >=0.8.0 <0.8.6;") == ">=0.8.0 <0.8.6"

    def test_exact(self):
        assert extract_pragma_spec("pragma solidity 0.8.26;") == "0.8.26"

    def test_extra_spaces(self):
        assert extract_pragma_spec("pragma  solidity  ^0.8.0;") == "^0.8.0"

    def test_no_pragma(self):
        assert extract_pragma_spec("contract Foo {}") is None

    def test_in_error_output(self):
        output = '  | pragma solidity ^0.8.20;\n  | ^^^^^^^^^^^^^^^^^^^^^^^'
        assert extract_pragma_spec(output) == "^0.8.20"


class TestParsePragmaConstraint:
    def test_exact(self):
        cs = parse_pragma_constraint("0.8.26")
        assert cs is not None
        from packaging.version import Version
        assert Version("0.8.26") in cs
        assert Version("0.8.25") not in cs

    def test_caret(self):
        cs = parse_pragma_constraint("^0.8.0")
        assert cs is not None
        from packaging.version import Version
        assert Version("0.8.26") in cs
        assert Version("0.9.0") not in cs
        assert Version("0.7.6") not in cs

    def test_range(self):
        cs = parse_pragma_constraint(">=0.8.0 <0.8.6")
        assert cs is not None
        from packaging.version import Version
        assert Version("0.8.5") in cs
        assert Version("0.8.6") not in cs

    def test_invalid(self):
        assert parse_pragma_constraint("not a version") is None


class TestResolvePragmaToVersion:
    @patch("utils.compilation_fixer.fetch_available_solc_versions", return_value=["0.8.26", "0.8.20", "0.8.0", "0.7.6"])
    def test_caret(self, _mock):
        assert resolve_pragma_to_version("^0.8.0") == "0.8.26"

    @patch("utils.compilation_fixer.fetch_available_solc_versions", return_value=["0.8.26", "0.8.5", "0.8.0"])
    def test_range(self, _mock):
        assert resolve_pragma_to_version(">=0.8.0 <0.8.6") == "0.8.5"

    @patch("utils.compilation_fixer.fetch_available_solc_versions", return_value=["0.8.26"])
    def test_no_match(self, _mock):
        assert resolve_pragma_to_version("^0.6.0") is None


class TestFormatSolcVersion:
    @patch("utils.compilation_fixer.detect_solc_convention", return_value="certora")
    def test_certora_convention(self, _mock):
        assert format_solc_version("0.8.26") == "solc8.26"

    @patch("utils.compilation_fixer.detect_solc_convention", return_value="solc-select")
    def test_solc_select_convention(self, _mock):
        assert format_solc_version("0.8.26") == "solc-0.8.26"

    @patch("utils.compilation_fixer.detect_solc_convention", return_value="solc-select")
    def test_solc_select_no_leading_zero(self, _mock):
        assert format_solc_version("8.26") == "solc-0.8.26"


class TestCertoraFormatToRawVersion:
    def test_certora_format(self):
        assert certora_format_to_raw_version("solc8.19") == "0.8.19"

    def test_solc_select_format(self):
        assert certora_format_to_raw_version("solc-0.8.19") == "0.8.19"

    def test_raw_version(self):
        assert certora_format_to_raw_version("0.8.19") == "0.8.19"

    def test_empty(self):
        assert certora_format_to_raw_version("") is None

    def test_plain_solc(self):
        assert certora_format_to_raw_version("solc") is None


# =========================================================================
# Detection function tests
# =========================================================================


class TestDetectVersionMismatch:
    def test_detects_mismatch(self):
        output = (
            "Compiling contracts/Foo.sol...\n"
            "contracts/Foo.sol had an error:\n"
            "ParserError: Source file requires different compiler version\n"
            " --> contracts/Foo.sol:2:1:\n"
            "  |\n"
            "2 | pragma solidity ^0.8.20;\n"
            "  | ^^^^^^^^^^^^^^^^^^^^^^^\n"
        )
        result = _detect_version_mismatch(output)
        assert result == "^0.8.20"

    def test_no_mismatch(self):
        assert _detect_version_mismatch("Compilation successful") is None


class TestDetectSolcNotFound:
    def test_detects_missing_binary(self):
        output = "attribute/flag 'solc': Cannot run solc8.26 (No such file or directory)"
        assert _detect_solc_not_found(output) == "solc8.26"

    def test_no_error(self):
        assert _detect_solc_not_found("Compilation successful") is None


class TestDetectRemappingsConflict:
    def test_detects_conflict(self):
        output = "package.json and remappings.txt include duplicated keys in some/path"
        assert _detect_remappings_conflict(output) is True

    def test_no_conflict(self):
        assert _detect_remappings_conflict("Compilation successful") is False


class TestDetectSourceNotFound:
    def test_detects_source_not_found(self):
        output = 'ParserError: Source "@openzeppelin/contracts/token/ERC20/ERC20.sol" not found: File not found.'
        assert _detect_source_not_found(output) is True

    def test_no_error(self):
        assert _detect_source_not_found("Compilation successful") is False


class TestDetectStackTooDeep:
    def test_detects_stack_too_deep(self):
        output = "CompilerError: Stack too deep. Try compiling with `--via-ir`"
        assert _detect_stack_too_deep(output) is True

    def test_no_error(self):
        assert _detect_stack_too_deep("Compilation successful") is False


class TestDetectUnsupportedSolcViaIr:
    def test_detects_unsupported(self):
        output = "Unsupported solc version 0.7.6 for solc_via_ir"
        assert _detect_unsupported_solc_via_ir(output) is True

    def test_no_error(self):
        assert _detect_unsupported_solc_via_ir("Compilation successful") is False


class TestDetectCancunOpcodes:
    def test_detects_mcopy(self):
        output = 'DeclarationError: Function "mcopy" not found'
        assert _detect_cancun_opcodes(output) is True

    def test_detects_tload(self):
        output = 'DeclarationError: Function "tload" not found'
        assert _detect_cancun_opcodes(output) is True

    def test_detects_tstore(self):
        output = 'DeclarationError: Function "tstore" not found'
        assert _detect_cancun_opcodes(output) is True

    def test_no_error(self):
        assert _detect_cancun_opcodes("Compilation successful") is False


class TestDetectUnnamedReturnWarning:
    def test_detects_warning(self):
        output = "Warning: Unnamed return variable can remain unassigned"
        assert _detect_unnamed_return_warning(output) is True

    def test_no_warning(self):
        assert _detect_unnamed_return_warning("Compilation successful") is False


class TestDetectYulStackTooDeep:
    def test_detects_yul_exception(self):
        output = "YulException: Stack too deep when compiling inline assembly"
        assert _detect_yul_stack_too_deep(output) is True

    def test_no_error(self):
        assert _detect_yul_stack_too_deep("Compilation successful") is False


# =========================================================================
# Full retry loop tests (with mocked subprocess)
# =========================================================================


class TestFixCompilation:
    """Test the full fix_compilation retry loop by mocking subprocess.run."""

    def _make_conf(self, conf_data: dict) -> str:
        """Write conf_data to a temp file and return its path."""
        fd, path = tempfile.mkstemp(suffix=".conf")
        with open(fd, "w") as f:
            json.dump(conf_data, f)
        return path

    def test_already_succeeds(self):
        """If compilation already succeeds, no workarounds are applied."""
        conf_data = {"files": ["Foo.sol"], "verify": "Foo:spec.spec"}
        conf_path = self._make_conf(conf_data)

        with patch("utils.compilation_fixer.subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(args=[], returncode=0, stdout="OK", stderr="")
            success, result = fix_compilation(conf_path, conf_data, ["certoraRun", conf_path], "/tmp/project")

        assert success is True
        assert "solc" not in result  # No workaround applied
        Path(conf_path).unlink(missing_ok=True)

    def test_version_mismatch_fixed(self):
        """Version mismatch triggers solc version fix, then succeeds."""
        conf_data = {"files": ["Foo.sol"], "verify": "Foo:spec.spec"}
        conf_path = self._make_conf(conf_data)

        error_output = (
            "Compiling contracts/Foo.sol...\n"
            "ParserError: Source file requires different compiler version\n"
            " --> contracts/Foo.sol:2:1:\n"
            "2 | pragma solidity ^0.8.20;\n"
        )

        call_count = 0

        def mock_run(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                return subprocess.CompletedProcess(args=[], returncode=1, stdout=error_output, stderr="")
            return subprocess.CompletedProcess(args=[], returncode=0, stdout="OK", stderr="")

        with (
            patch("utils.compilation_fixer.subprocess.run", side_effect=mock_run),
            patch("utils.compilation_fixer.resolve_pragma_to_version", return_value="0.8.26"),
            patch("utils.compilation_fixer.format_solc_version", return_value="solc8.26"),
        ):
            success, result = fix_compilation(conf_path, conf_data, ["certoraRun", conf_path], "/tmp/project")

        assert success is True
        assert result["solc"] == "solc8.26"
        Path(conf_path).unlink(missing_ok=True)

    def test_stack_too_deep_enables_via_ir(self):
        """Stack too deep error triggers via-ir, then succeeds."""
        conf_data = {"files": ["Foo.sol"], "verify": "Foo:spec.spec"}
        conf_path = self._make_conf(conf_data)

        error_output = "CompilerError: Stack too deep. Try compiling with `--via-ir`"
        call_count = 0

        def mock_run(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                return subprocess.CompletedProcess(args=[], returncode=1, stdout=error_output, stderr="")
            return subprocess.CompletedProcess(args=[], returncode=0, stdout="OK", stderr="")

        with patch("utils.compilation_fixer.subprocess.run", side_effect=mock_run):
            success, result = fix_compilation(conf_path, conf_data, ["certoraRun", conf_path], "/tmp/project")

        assert success is True
        assert result["solc_via_ir"] is True
        Path(conf_path).unlink(missing_ok=True)

    def test_no_workaround_applies(self):
        """If no workaround matches the error, returns failure."""
        conf_data = {"files": ["Foo.sol"], "verify": "Foo:spec.spec"}
        conf_path = self._make_conf(conf_data)

        with patch("utils.compilation_fixer.subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=1, stdout="SomeUnknownError: something weird happened", stderr=""
            )
            success, result = fix_compilation(conf_path, conf_data, ["certoraRun", conf_path], "/tmp/project")

        assert success is False
        Path(conf_path).unlink(missing_ok=True)

    def test_two_workarounds_chained(self):
        """Version mismatch fixed first, then cancun opcodes, then succeeds."""
        conf_data = {"files": ["Foo.sol"], "verify": "Foo:spec.spec"}
        conf_path = self._make_conf(conf_data)

        version_error = (
            "ParserError: Source file requires different compiler version\n"
            "2 | pragma solidity ^0.8.20;\n"
        )
        cancun_error = 'DeclarationError: Function "mcopy" not found'
        call_count = 0

        def mock_run(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                return subprocess.CompletedProcess(args=[], returncode=1, stdout=version_error, stderr="")
            elif call_count == 2:
                return subprocess.CompletedProcess(args=[], returncode=1, stdout=cancun_error, stderr="")
            return subprocess.CompletedProcess(args=[], returncode=0, stdout="OK", stderr="")

        with (
            patch("utils.compilation_fixer.subprocess.run", side_effect=mock_run),
            patch("utils.compilation_fixer.resolve_pragma_to_version", return_value="0.8.26"),
            patch("utils.compilation_fixer.format_solc_version", return_value="solc8.26"),
        ):
            success, result = fix_compilation(conf_path, conf_data, ["certoraRun", conf_path], "/tmp/project")

        assert success is True
        assert result["solc"] == "solc8.26"
        assert result["solc_evm_version"] == "cancun"
        Path(conf_path).unlink(missing_ok=True)

    def test_packages_from_remappings(self, tmp_path):
        """Source not found triggers packages from remappings.txt."""
        conf_data = {"files": ["Foo.sol"], "verify": "Foo:spec.spec"}
        conf_path = self._make_conf(conf_data)

        # Create remappings.txt in the "project root"
        (tmp_path / "remappings.txt").write_text("@openzeppelin/=lib/openzeppelin-contracts/\n")

        error_output = 'ParserError: Source "@openzeppelin/contracts/token/ERC20.sol" not found: File not found.'
        call_count = 0

        def mock_run(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                return subprocess.CompletedProcess(args=[], returncode=1, stdout=error_output, stderr="")
            return subprocess.CompletedProcess(args=[], returncode=0, stdout="OK", stderr="")

        with patch("utils.compilation_fixer.subprocess.run", side_effect=mock_run):
            success, result = fix_compilation(conf_path, conf_data, ["certoraRun", conf_path], str(tmp_path))

        assert success is True
        assert "packages" in result
        assert "@openzeppelin/=lib/openzeppelin-contracts/" in result["packages"]
        Path(conf_path).unlink(missing_ok=True)
