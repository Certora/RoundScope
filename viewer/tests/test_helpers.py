"""Unit tests for pure helper functions in generate_viewer.py."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from generate_viewer import (
    aggregate_rounding,
    clean_graph_label,
    clean_node_label,
    clean_wala_type,
    extract_filename_from_method_position,
    find_returns_clause,
    normalize_path,
    parse_method_position,
    parse_range_key,
)


# --- parse_range_key ---


class TestParseRangeKey:
    def test_normal(self):
        assert parse_range_key("[5,2-10,3]") == (5, 2, 10, 3)

    def test_single_line(self):
        assert parse_range_key("[42,0-42,15]") == (42, 0, 42, 15)

    def test_large_numbers(self):
        assert parse_range_key("[1146,2-1152,3]") == (1146, 2, 1152, 3)


# --- aggregate_rounding ---


class TestAggregateRounding:
    def test_all_neither(self):
        assert aggregate_rounding(["Neither", "Neither"]) == "Neither"

    def test_single_up(self):
        assert aggregate_rounding(["Up"]) == "Up"

    def test_all_same(self):
        assert aggregate_rounding(["Down", "Down", "Down"]) == "Down"

    def test_all_same_with_neither(self):
        assert aggregate_rounding(["Up", "Neither", "Up"]) == "Up"

    def test_mixed(self):
        assert aggregate_rounding(["Up", "Down"]) == "Either"

    def test_mixed_with_neither(self):
        assert aggregate_rounding(["Up", "Neither", "Down"]) == "Either"

    def test_empty(self):
        assert aggregate_rounding([]) == "Neither"

    def test_single_neither(self):
        assert aggregate_rounding(["Neither"]) == "Neither"

    def test_inconsistent_and_up(self):
        assert aggregate_rounding(["Inconsistent", "Up"]) == "Either"


# --- clean_graph_label ---


class TestCleanGraphLabel:
    def test_normal_function(self):
        label = "graph of < solidity, Lcontract Hub.previewRemoveByShares (uint256,uint256) --> uint256, do(Puint256;Puint256;)Puint256; > ([<solidity,Lcontract Hub>])"
        assert clean_graph_label(label) == "Hub.previewRemoveByShares"

    def test_constructor(self):
        label = "graph of < solidity, Lcontract AccessManaged.<init> (address), do(Laddress;)V > ([<solidity,Lcontract Hub>])"
        assert clean_graph_label(label) == "AccessManaged.constructor"

    def test_no_params(self):
        label = "graph of < solidity, Lcontract Hub.getAssetCount () --> uint256, do()Puint256; > ([<solidity,Lcontract Hub>])"
        assert clean_graph_label(label) == "Hub.getAssetCount"

    def test_fallback_plain_label(self):
        assert clean_graph_label("something unexpected") == "something unexpected"


# --- clean_node_label ---


class TestCleanNodeLabel:
    def test_code_body(self):
        assert clean_node_label("<Code body of function repay>") == "repay"

    def test_code_body_non_function(self):
        assert clean_node_label("<Code body of modifier onlyAdmin>") == "modifier onlyAdmin"

    def test_plain_label(self):
        assert clean_node_label("myFunction") == "myFunction"


# --- clean_wala_type ---


class TestCleanWalaType:
    def test_uint256(self):
        assert clean_wala_type("<solidity,Puint256>") == "uint256"

    def test_address(self):
        assert clean_wala_type("<solidity,Laddress>") == "address"

    def test_with_spaces(self):
        assert clean_wala_type("< solidity, Puint120 >") == "uint120"

    def test_int_type(self):
        assert clean_wala_type("<solidity,Pint200>") == "int200"

    def test_no_match(self):
        assert clean_wala_type("unknown") == "unknown"


# --- find_returns_clause ---


class TestFindReturnsClause:
    def test_single_line(self):
        lines = [
            "pragma solidity ^0.8.0;",
            "",
            "  function foo(uint256 x) external view returns (uint256) {",
            "    return x;",
            "  }",
        ]
        result = find_returns_clause(lines, method_sl=3, method_el=5)
        assert result is not None
        sl, sc, el, ec = result
        assert sl == 3
        assert lines[sl - 1][sc:ec] == "returns (uint256)"

    def test_multi_line_signature(self):
        lines = [
            "  function bar(",
            "    uint256 a,",
            "    uint256 b",
            "  ) external view returns (uint256) {",
            "    return a + b;",
            "  }",
        ]
        result = find_returns_clause(lines, method_sl=4, method_el=6)
        assert result is not None
        sl, sc, el, ec = result
        assert sl == 4
        assert "returns" in lines[sl - 1][sc:ec]

    def test_no_returns(self):
        lines = [
            "  function baz(uint256 x) external {",
            "    // do something",
            "  }",
        ]
        result = find_returns_clause(lines, method_sl=1, method_el=3)
        assert result is None

    def test_return_statement_not_matched(self):
        """'return x;' should not be matched, only 'returns (...)'."""
        lines = [
            "  function foo() external {",
            "    return;",
            "  }",
        ]
        result = find_returns_clause(lines, method_sl=1, method_el=3)
        assert result is None

    def test_tuple_returns(self):
        lines = [
            "  function getOwed(uint256 id) external view returns (uint256, uint256) {",
            "    return (a, b);",
            "  }",
        ]
        result = find_returns_clause(lines, method_sl=1, method_el=3)
        assert result is not None
        sl, sc, el, ec = result
        assert "returns (uint256, uint256)" in lines[sl - 1][sc:ec]

    def test_returns_with_named_params(self):
        lines = [
            "  function fromRayUp(uint256 a) internal pure returns (uint256 b) {",
            "    assembly ('memory-safe') {",
            "      b := add(div(a, RAY), gt(mod(a, RAY), 0))",
            "    }",
            "  }",
        ]
        result = find_returns_clause(lines, method_sl=1, method_el=5)
        assert result is not None
        sl, sc, el, ec = result
        assert "returns (uint256 b)" in lines[sl - 1][sc:ec]


# --- normalize_path ---


class TestNormalizePath:
    def test_absolute_to_relative(self):
        result = normalize_path("/home/user/project/src/file.sol", "/home/user/project")
        assert result == "src/file.sol"

    def test_already_relative(self):
        result = normalize_path("src/file.sol", "/home/user/project")
        assert result == "src/file.sol"


# --- extract_filename_from_method_position ---


class TestExtractFilename:
    def test_normal(self):
        assert extract_filename_from_method_position("src/hub/Hub.sol:[511,2-514,3]") == "src/hub/Hub.sol"

    def test_no_range(self):
        assert extract_filename_from_method_position("src/hub/Hub.sol") == "src/hub/Hub.sol"


# --- parse_method_position ---


class TestParseMethodPosition:
    def test_normal(self):
        result = parse_method_position("src/hub/Hub.sol:[511,2-514,3]")
        assert result == ("src/hub/Hub.sol", 511, 2, 514, 3)

    def test_missing_range(self):
        assert parse_method_position("src/hub/Hub.sol") is None

    def test_absolute_path(self):
        result = parse_method_position("/abs/path/file.sol:[1,0-5,1]")
        assert result == ("/abs/path/file.sol", 1, 0, 5, 1)
