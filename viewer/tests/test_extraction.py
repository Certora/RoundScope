"""Snapshot tests: run extraction functions on real data, compare to golden files."""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from helpers import assert_golden, normalize_annotations

from generate_viewer import (
    aggregate_rounding,
    collect_referenced_files_from_paths,
    extract_graphs,
    extract_per_graph_return_annotations,
    extract_per_graph_roundings,
    extract_return_annotations,
    extract_return_annotations_root_only,
    extract_roundings,
    extract_roundings_root_only,
)


def test_extract_roundings(hub_data, aave_project_root, update_golden):
    """Test context-free rounding extraction against golden file."""
    result = extract_roundings(hub_data, aave_project_root)

    # Normalize for deterministic comparison
    normalized = {}
    for filename in sorted(result.keys()):
        normalized[filename] = normalize_annotations(result[filename])

    assert_golden(normalized, "hub-annotations.json", update_golden)


def test_extract_return_annotations(hub_data, aave_project_root, hub_source_files, update_golden):
    """Test return annotation extraction against golden file."""
    result = extract_return_annotations(hub_data, aave_project_root, hub_source_files)

    normalized = {}
    for filename in sorted(result.keys()):
        normalized[filename] = normalize_annotations(result[filename])

    assert_golden(normalized, "hub-return-annotations.json", update_golden)


def test_contexts_summary(hub_data, aave_project_root, hub_source_files, update_golden):
    """Test that per-graph contexts have expected names and annotation counts."""
    # Build all contexts the same way main() does
    aggregated = extract_roundings(hub_data, aave_project_root)
    return_annotations = extract_return_annotations(hub_data, aave_project_root, hub_source_files)
    per_graph_roundings = extract_per_graph_roundings(hub_data, aave_project_root)
    per_graph_returns = extract_per_graph_return_annotations(hub_data, aave_project_root, hub_source_files)

    contexts = {"allContexts": {}}
    for filename, annotations in aggregated.items():
        contexts["allContexts"][filename] = annotations
    for filename, ret_anns in return_annotations.items():
        if filename not in contexts["allContexts"]:
            contexts["allContexts"][filename] = []
        contexts["allContexts"][filename].extend(ret_anns)

    for ctx_name, file_anns in per_graph_roundings.items():
        if ctx_name not in contexts:
            contexts[ctx_name] = {}
        for filename, anns in file_anns.items():
            if filename not in contexts[ctx_name]:
                contexts[ctx_name][filename] = []
            contexts[ctx_name][filename].extend(anns)

    for ctx_name, file_anns in per_graph_returns.items():
        if ctx_name not in contexts:
            contexts[ctx_name] = {}
        for filename, anns in file_anns.items():
            if filename not in contexts[ctx_name]:
                contexts[ctx_name][filename] = []
            contexts[ctx_name][filename].extend(anns)

    # Filter out all-Neither contexts (same as main())
    for ctx_name in list(contexts.keys()):
        if ctx_name == "allContexts":
            continue
        all_neither = all(
            a["rounding"] == "Neither"
            for anns in contexts[ctx_name].values()
            for a in anns
        )
        if all_neither:
            del contexts[ctx_name]

    # Build summary
    summary = {}
    for ctx_name in sorted(contexts.keys()):
        ctx = contexts[ctx_name]
        summary[ctx_name] = {
            "file_count": len(ctx),
            "annotation_count": sum(len(anns) for anns in ctx.values()),
        }

    assert_golden(summary, "hub-contexts-summary.json", update_golden)


def test_extract_graphs(hub_data, aave_project_root, update_golden):
    """Test graph extraction against golden file."""
    result = extract_graphs(hub_data, aave_project_root)

    # Normalize: sort edges, ensure deterministic node ordering
    normalized = []
    for graph in result:
        g = {
            "nodes": {k: graph["nodes"][k] for k in sorted(graph["nodes"].keys())},
            "edges": sorted(
                graph["edges"],
                key=lambda e: (e["source"], e["target"], e.get("file", ""), e.get("sl", 0)),
            ),
        }
        normalized.append(g)

    assert_golden(normalized, "hub-graphs.json", update_golden)


def test_extract_roundings_root_only(hub_data, aave_project_root, update_golden):
    """Test root-only rounding extraction against golden file."""
    result = extract_roundings_root_only(hub_data, aave_project_root)

    normalized = {}
    for filename in sorted(result.keys()):
        normalized[filename] = normalize_annotations(result[filename])

    assert_golden(normalized, "hub-annotations-root-only.json", update_golden)


def test_extract_return_annotations_root_only(hub_data, aave_project_root, hub_source_files, update_golden):
    """Test root-only return annotation extraction against golden file."""
    result = extract_return_annotations_root_only(hub_data, aave_project_root, hub_source_files)

    normalized = {}
    for filename in sorted(result.keys()):
        normalized[filename] = normalize_annotations(result[filename])

    assert_golden(normalized, "hub-return-annotations-root-only.json", update_golden)


def test_root_only_annotations_are_subset(hub_data, aave_project_root):
    """Root-only annotations should reference only node '0' in their nodeRefs."""
    result = extract_roundings_root_only(hub_data, aave_project_root)

    for filename, annotations in result.items():
        for ann in annotations:
            for ref in ann["nodeRefs"]:
                assert ref["n"] == "0", (
                    f"Root-only annotation in {filename} at line {ann['sl']} "
                    f"references node '{ref['n']}' instead of '0'"
                )


def test_root_only_has_fewer_or_equal_annotations(hub_data, aave_project_root):
    """Root-only mode should produce <= annotations compared to full extraction."""
    full = extract_roundings(hub_data, aave_project_root)
    root_only = extract_roundings_root_only(hub_data, aave_project_root)

    full_count = sum(len(v) for v in full.values())
    root_count = sum(len(v) for v in root_only.values())
    assert root_count <= full_count, (
        f"Root-only ({root_count}) should have <= annotations than full ({full_count})"
    )
