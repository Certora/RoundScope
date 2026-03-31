"""Smoke test: full HTML generation pipeline."""

import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from generate_viewer import (
    build_directory_tree,
    collect_referenced_files_from_paths,
    extract_graphs,
    extract_per_graph_return_annotations,
    extract_per_graph_roundings,
    extract_return_annotations,
    extract_roundings,
    generate_html,
)


def test_full_generation(hub_data, aave_project_root):
    """Run the full pipeline end-to-end and verify the output HTML."""
    project_root = aave_project_root

    # Extract roundings
    aggregated = extract_roundings(hub_data, project_root)
    graphs = extract_graphs(hub_data, project_root)

    # Collect files
    all_files = set(aggregated.keys())
    for g in graphs:
        for node in g["nodes"].values():
            if node["file"]:
                all_files.add(node["file"])

    source_files = collect_referenced_files_from_paths(all_files, project_root)

    # Extract return annotations
    return_annotations = extract_return_annotations(hub_data, project_root, source_files)
    per_graph_roundings = extract_per_graph_roundings(hub_data, project_root)
    per_graph_returns = extract_per_graph_return_annotations(hub_data, project_root, source_files)

    # Build contexts
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

    # Filter all-Neither
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

    dir_tree = build_directory_tree(sorted(source_files.keys()))
    html = generate_html(project_root, source_files, dir_tree, contexts, graphs)

    # Basic sanity checks
    assert len(html) > 10000, "HTML output is suspiciously small"
    assert "const DATA =" in html
    assert "RoundAbout" in html
    assert "r-up" in html
    assert "r-mixed" in html
    assert "allContexts" in html
    assert "Hub.add" in html  # At least one per-graph context should appear

    # Verify it's valid-ish HTML
    assert html.startswith("<!DOCTYPE html>")
    assert "</html>" in html

    # Write to temp file to verify it doesn't crash on disk write
    with tempfile.NamedTemporaryFile(mode="w", suffix=".html", delete=False) as f:
        f.write(html)
        tmp_path = f.name
    assert os.path.getsize(tmp_path) > 10000
    os.unlink(tmp_path)
