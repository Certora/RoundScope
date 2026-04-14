#!/usr/bin/env python3
"""Generate a self-contained HTML viewer for Certora RoundAbout JSON output."""

import json
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict

from pygments import highlight as pygments_highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_for_filename
from pygments.lexers.solidity import SolidityLexer


def parse_args():
    import argparse
    parser = argparse.ArgumentParser(
        description="Generate an HTML viewer from a Certora .conf or .sol file."
    )
    parser.add_argument("--project-root", required=True, help="Project root directory")
    parser.add_argument("--input-file", default=None, help="Path to a .conf or .sol file (required unless --json-input is used)")
    parser.add_argument("--output", required=True, help="Path for the output HTML file")
    parser.add_argument("--conf-file", default=None, help="Optional .conf file for contract extraction")
    parser.add_argument("--json-input", default=None, help="Path to pre-generated roundabout JSON (skips roundabout.py)")
    parser.add_argument("--full-context-breakdown", action="store_true", help="Enable full context breakdown mode")
    parser.add_argument("--certora-run-command", default="certoraRun", help="Command to use instead of certoraRun")
    args = parser.parse_args()
    return (args.project_root, args.input_file, args.output, args.conf_file,
            args.full_context_breakdown, args.certora_run_command, args.json_input)


def clean_graph_label(label):
    """Clean graph label into a readable function name.

    'graph of < solidity, Lcontract Hub.previewRemoveByShares (uint256,uint256) --> uint256, do(...)... > ([...])'
    -> 'Hub.previewRemoveByShares'
    """
    # Extract the function signature part
    m = re.match(r'graph of < solidity, Lcontract (\w+\.\w+)', label)
    if m:
        return m.group(1)
    # Static functions: 'graph of < solidity, Lstatic _require (bool,uint256), ...' -> 'static _require'
    m = re.match(r'graph of < solidity, Lstatic (\w+)', label)
    if m:
        return 'static ' + m.group(1)
    # Fallback: try to find any Contract.method pattern
    m = re.search(r'Lcontract (\w+\.\w+)', label)
    if m:
        return m.group(1)
    # Try to clean up <init> patterns
    m = re.match(r'graph of < solidity, Lcontract (\w+)\.<init>', label)
    if m:
        return m.group(1) + '.constructor'
    return label


def extract_per_graph_roundings(data, project_root):
    """Extract roundings per graph (each graph is a separate context).

    Returns a dict of context_name -> {filename -> [annotation dicts]}.
    """
    per_graph = {}

    for graph_idx, graph in enumerate(data["graphs"]):
        label = graph.get("label", f"Graph {graph_idx}")
        context_name = clean_graph_label(label)

        # Collect roundings for this graph only
        raw = defaultdict(list)  # (filename, range_key) -> list of entries
        for node_id, node in graph["nodes"].items():
            md = node["metadata"]
            method_pos = md.get("methodPosition", "")
            if not method_pos:
                continue
            filename = extract_filename_from_method_position(method_pos)
            for range_key, info in md.get("roundings", {}).items():
                entry = dict(info)
                entry["_graphIdx"] = graph_idx
                entry["_nodeId"] = node_id
                raw[(filename, range_key)].append(entry)

            for param in md.get("parameters", []):
                pos = param.get("position")
                if not pos:
                    continue
                entry = {
                    "rounding": param.get("rounding", "Neither"),
                    "source": param.get("source", ""),
                    "expr": "",
                    "_graphIdx": graph_idx,
                    "_nodeId": node_id,
                }
                raw[(filename, pos)].append(entry)

        if not raw:
            per_graph[context_name] = {}
            continue

        file_annotations = defaultdict(list)
        for (filename, range_key), entries in raw.items():
            rounding_values = [e["rounding"] for e in entries]
            agg_rounding = aggregate_rounding(rounding_values)

            sl, sc, el, ec = parse_range_key(range_key)

            source = ""
            expr = ""
            for e in entries:
                if not source and e.get("source"):
                    source = e["source"]
                if not expr and e.get("expr"):
                    expr = e["expr"]

            node_refs = [{"g": graph_idx, "n": entries[0]["_nodeId"]}]
            seen = {entries[0]["_nodeId"]}
            for e in entries[1:]:
                if e["_nodeId"] not in seen:
                    seen.add(e["_nodeId"])
                    node_refs.append({"g": graph_idx, "n": e["_nodeId"]})

            rel_filename = normalize_path(filename, project_root)
            file_annotations[rel_filename].append({
                "sl": sl, "sc": sc, "el": el, "ec": ec,
                "rounding": agg_rounding,
                "source": source, "expr": expr,
                "nodeRefs": node_refs,
            })

        per_graph[context_name] = dict(file_annotations)

    return per_graph


def extract_per_graph_return_annotations(data, project_root, source_files):
    """Extract return annotations per graph.

    Returns a dict of context_name -> {filename -> [annotation dicts]}.
    """
    per_graph = {}

    for graph_idx, graph in enumerate(data["graphs"]):
        label = graph.get("label", f"Graph {graph_idx}")
        context_name = clean_graph_label(label)

        # Collect return values for this graph, grouped by method position
        grouped = defaultdict(list)
        for node_id, node in graph["nodes"].items():
            md = node["metadata"]
            method_pos = md.get("methodPosition", "")
            ret = md.get("return")
            if not method_pos or ret is None:
                continue
            parsed = parse_method_position(method_pos)
            if not parsed:
                continue
            filename, sl, sc, el, ec = parsed
            rel_filename = normalize_path(filename, project_root)
            grouped[(rel_filename, sl, el)].append((ret, graph_idx, node_id))

        file_annotations = defaultdict(list)
        for (rel_filename, method_sl, method_el), entries in grouped.items():
            file_data = source_files.get(rel_filename)
            if not file_data:
                continue
            raw_lines = file_data["raw"].split("\n")
            clause = find_returns_clause(raw_lines, method_sl, method_el)
            if not clause:
                continue

            r_sl, r_sc, r_el, r_ec = clause
            flat_roundings = []
            element_roundings = defaultdict(list)
            node_refs = []
            seen_refs = set()

            for ret_val, g_idx, n_id in entries:
                if (g_idx, n_id) not in seen_refs:
                    seen_refs.add((g_idx, n_id))
                    node_refs.append({"g": g_idx, "n": n_id})
                if isinstance(ret_val, str):
                    flat_roundings.append(ret_val)
                elif isinstance(ret_val, dict):
                    for type_key, rounding in ret_val.items():
                        flat_roundings.append(rounding)
                        element_roundings[type_key].append(rounding)

            significant = [v for v in flat_roundings if v != "Neither"]
            if not significant:
                rounding = "Neither"
            elif len(set(significant)) == 1:
                rounding = significant[0]
            else:
                rounding = "Mixed returns"

            annotation = {
                "sl": r_sl, "sc": r_sc, "el": r_el, "ec": r_ec,
                "rounding": rounding, "source": "return type", "expr": "",
                "nodeRefs": node_refs,
            }

            if element_roundings and rounding == "Mixed returns":
                breakdown = []
                sorted_keys = sorted(
                    element_roundings.keys(),
                    key=lambda k: int(re.search(r'Ltuple,\s*(\d+)', k).group(1))
                    if re.search(r'Ltuple,\s*(\d+)', k) else 0,
                )
                for i, type_key in enumerate(sorted_keys):
                    roundings = element_roundings[type_key]
                    agg = aggregate_rounding(roundings)
                    inner_match = re.search(r'<\s*solidity\s*,\s*[PL]\w+\s*>', type_key)
                    sol_type = clean_wala_type(inner_match.group(0)) if inner_match else f"[{i}]"
                    breakdown.append({"index": i, "type": sol_type, "rounding": agg})
                annotation["returnBreakdown"] = breakdown

            file_annotations[rel_filename].append(annotation)

        # Only store if we got annotations (may have been merged into an existing context_name)
        if context_name not in per_graph:
            per_graph[context_name] = dict(file_annotations)
        else:
            # Merge into existing
            for fname, anns in file_annotations.items():
                if fname not in per_graph[context_name]:
                    per_graph[context_name][fname] = []
                per_graph[context_name][fname].extend(anns)

    return per_graph


def extract_contracts_from_conf(conf_path):
    """Extract contract names from the 'files' list in a Certora conf file."""
    with open(conf_path, "r") as f:
        text = f.read()
    # Strip single-line // comments and trailing commas (conf files allow them but JSON doesn't)
    text = re.sub(r"//.*", "", text)
    text = re.sub(r",\s*([}\]])", r"\1", text)
    conf = json.loads(text)
    contracts = []
    for entry in conf.get("files", []):
        # "src/hub/Hub.sol" -> "Hub"
        basename = os.path.basename(entry)
        name = os.path.splitext(basename)[0]
        contracts.append(name)
    return contracts


def extract_filename_from_method_position(method_position):
    """Extract filename from 'path/to/file.sol:[sl,sc-el,ec]' format."""
    idx = method_position.rfind(":[")
    if idx == -1:
        return method_position
    return method_position[:idx]


def parse_range_key(range_key):
    """Parse '[sl,sc-el,ec]' into (start_line, start_col, end_line, end_col)."""
    inner = range_key.strip("[]")
    start, end = inner.split("-")
    sl, sc = start.split(",")
    el, ec = end.split(",")
    return int(sl), int(sc), int(el), int(ec)


def aggregate_rounding(values):
    """
    Context-free aggregation:
    1. Filter out Neither
    2. If no significant values -> Neither
    3. If all same -> that value
    4. Otherwise -> Either
    """
    significant = [v for v in values if v != "Neither"]
    if not significant:
        return "Neither"
    if len(set(significant)) == 1:
        return significant[0]
    return "Either"


def extract_roundings(data, project_root):
    """
    Extract all (filename, range_key, rounding, source, expr) tuples from JSON,
    then aggregate per (filename, range_key) for context-free view.
    """
    # Collect all rounding entries: (filename, range_key) -> list of {rounding, source, expr, graphIdx, nodeId}
    raw = defaultdict(list)

    for graph_idx, graph in enumerate(data["graphs"]):
        for node_id, node in graph["nodes"].items():
            md = node["metadata"]
            method_pos = md.get("methodPosition", "")
            if not method_pos:
                continue
            filename = extract_filename_from_method_position(method_pos)

            for range_key, info in md.get("roundings", {}).items():
                entry = dict(info)
                entry["_graphIdx"] = graph_idx
                entry["_nodeId"] = node_id
                raw[(filename, range_key)].append(entry)

            for param in md.get("parameters", []):
                pos = param.get("position")
                if not pos:
                    continue
                entry = {
                    "rounding": param.get("rounding", "Neither"),
                    "source": param.get("source", ""),
                    "expr": "",
                    "_graphIdx": graph_idx,
                    "_nodeId": node_id,
                }
                raw[(filename, pos)].append(entry)

    # Aggregate
    aggregated = defaultdict(list)  # filename -> list of annotation dicts
    for (filename, range_key), entries in raw.items():
        rounding_values = [e["rounding"] for e in entries]
        agg_rounding = aggregate_rounding(rounding_values)

        sl, sc, el, ec = parse_range_key(range_key)

        # Pick source/expr from any entry that has them
        source = ""
        expr = ""
        for e in entries:
            if not source and e.get("source"):
                source = e["source"]
            if not expr and e.get("expr"):
                expr = e["expr"]

        # Collect unique (graphIdx, nodeId) pairs
        seen_refs = set()
        node_refs = []
        for e in entries:
            key = (e["_graphIdx"], e["_nodeId"])
            if key not in seen_refs:
                seen_refs.add(key)
                node_refs.append({"g": e["_graphIdx"], "n": e["_nodeId"]})

        # Normalize filename: make relative to project_root
        rel_filename = normalize_path(filename, project_root)

        aggregated[rel_filename].append(
            {
                "sl": sl,
                "sc": sc,
                "el": el,
                "ec": ec,
                "rounding": agg_rounding,
                "source": source,
                "expr": expr,
                "nodeRefs": node_refs,
            }
        )

    return dict(aggregated)


def extract_roundings_root_only(data, project_root):
    """Extract roundings using only node '0' (root function) from each graph.

    No cross-context aggregation needed since each annotation comes directly
    from a single graph's entry-point function.
    """
    raw = defaultdict(list)  # (filename, range_key) -> list of entries

    for graph_idx, graph in enumerate(data["graphs"]):
        node = graph["nodes"].get("0")
        if not node:
            continue
        md = node["metadata"]
        method_pos = md.get("methodPosition", "")
        if not method_pos:
            continue
        filename = extract_filename_from_method_position(method_pos)

        for range_key, info in md.get("roundings", {}).items():
            raw[(filename, range_key)].append({
                "rounding": info.get("rounding", "Neither"),
                "source": info.get("source", ""),
                "expr": info.get("expr", ""),
                "_graphIdx": graph_idx,
            })

        for param in md.get("parameters", []):
            pos = param.get("position")
            if not pos:
                continue
            raw[(filename, pos)].append({
                "rounding": param.get("rounding", "Neither"),
                "source": param.get("source", ""),
                "expr": "",
                "_graphIdx": graph_idx,
            })

    # Deduplicate by (filename, range_key), collecting nodeRefs
    result = defaultdict(list)
    for (filename, range_key), entries in raw.items():
        sl, sc, el, ec = parse_range_key(range_key)
        rel_filename = normalize_path(filename, project_root)

        # If same position appears from multiple graphs, aggregate
        rounding_values = [e["rounding"] for e in entries]
        rounding = aggregate_rounding(rounding_values)

        source = ""
        expr = ""
        for e in entries:
            if not source and e.get("source"):
                source = e["source"]
            if not expr and e.get("expr"):
                expr = e["expr"]

        node_refs = []
        seen = set()
        for e in entries:
            if e["_graphIdx"] not in seen:
                seen.add(e["_graphIdx"])
                node_refs.append({"g": e["_graphIdx"], "n": "0"})

        result[rel_filename].append({
            "sl": sl, "sc": sc, "el": el, "ec": ec,
            "rounding": rounding,
            "source": source, "expr": expr,
            "nodeRefs": node_refs,
        })

    return dict(result)


def extract_return_annotations_root_only(data, project_root, source_files):
    """Extract return-type rounding annotations using only node '0' from each graph."""
    grouped = defaultdict(list)  # (rel_filename, method_sl, method_el) -> entries

    for graph_idx, graph in enumerate(data["graphs"]):
        node = graph["nodes"].get("0")
        if not node:
            continue
        md = node["metadata"]
        method_pos = md.get("methodPosition", "")
        ret = md.get("return")
        if not method_pos or ret is None:
            continue

        parsed = parse_method_position(method_pos)
        if not parsed:
            continue
        filename, sl, sc, el, ec = parsed
        rel_filename = normalize_path(filename, project_root)
        grouped[(rel_filename, sl, el)].append((ret, graph_idx))

    result = defaultdict(list)
    for (rel_filename, method_sl, method_el), entries in grouped.items():
        file_data = source_files.get(rel_filename)
        if not file_data:
            continue
        raw_lines = file_data["raw"].split("\n")
        clause = find_returns_clause(raw_lines, method_sl, method_el)
        if not clause:
            continue

        r_sl, r_sc, r_el, r_ec = clause
        flat_roundings = []
        element_roundings = defaultdict(list)
        node_refs = []
        seen_refs = set()

        for ret_val, g_idx in entries:
            if g_idx not in seen_refs:
                seen_refs.add(g_idx)
                node_refs.append({"g": g_idx, "n": "0"})
            if isinstance(ret_val, str):
                flat_roundings.append(ret_val)
            elif isinstance(ret_val, dict):
                for type_key, rounding in ret_val.items():
                    flat_roundings.append(rounding)
                    element_roundings[type_key].append(rounding)

        significant = [v for v in flat_roundings if v != "Neither"]
        if not significant:
            rounding = "Neither"
        elif len(set(significant)) == 1:
            rounding = significant[0]
        else:
            rounding = "Mixed returns"

        annotation = {
            "sl": r_sl, "sc": r_sc, "el": r_el, "ec": r_ec,
            "rounding": rounding, "source": "return type", "expr": "",
            "nodeRefs": node_refs,
        }

        if element_roundings and rounding == "Mixed returns":
            breakdown = []
            sorted_keys = sorted(
                element_roundings.keys(),
                key=lambda k: int(re.search(r'Ltuple,\s*(\d+)', k).group(1))
                if re.search(r'Ltuple,\s*(\d+)', k) else 0,
            )
            for i, type_key in enumerate(sorted_keys):
                roundings = element_roundings[type_key]
                agg = aggregate_rounding(roundings)
                inner_match = re.search(r'<\s*solidity\s*,\s*[PL]\w+\s*>', type_key)
                sol_type = clean_wala_type(inner_match.group(0)) if inner_match else f"[{i}]"
                breakdown.append({"index": i, "type": sol_type, "rounding": agg})
            annotation["returnBreakdown"] = breakdown

        result[rel_filename].append(annotation)

    return dict(result)


def clean_node_label(label):
    """Clean graph node labels: '<Code body of function repay>' -> 'repay'."""
    if label.startswith("<Code body of "):
        inner = label[len("<Code body of "):]
        if inner.endswith(">"):
            inner = inner[:-1]
        if inner.startswith("function "):
            return inner[len("function "):]
        return inner
    return label


def parse_method_position(method_position):
    """Parse 'path/to/file.sol:[sl,sc-el,ec]' into (filename, sl, sc, el, ec) or None."""
    idx = method_position.rfind(":[")
    if idx == -1:
        return None
    filename = method_position[:idx]
    range_part = method_position[idx + 1:]
    try:
        sl, sc, el, ec = parse_range_key(range_part)
        return filename, sl, sc, el, ec
    except (ValueError, IndexError):
        return None


def extract_graphs(data, project_root):
    """Process JGF graphs into a frontend-friendly structure."""
    graphs = []
    for graph in data["graphs"]:
        nodes = {}
        edges = []

        for node_id, node in graph["nodes"].items():
            label = clean_node_label(node.get("label", node_id))
            md = node.get("metadata", {})
            method_pos = md.get("methodPosition", "")

            file_path = ""
            sl = sc = el = ec = 0
            if method_pos:
                parsed = parse_method_position(method_pos)
                if parsed:
                    file_path, sl, sc, el, ec = parsed
                    file_path = normalize_path(file_path, project_root)

            # Determine return rounding from metadata.return field
            return_rounding = md.get("return", "")
            if return_rounding == "Neither":
                return_rounding = ""
            roundings = md.get("roundings", {})

            # Parse individual roundings for graph view source rendering
            parsed_roundings = []
            for range_key, info in roundings.items():
                try:
                    r_sl, r_sc, r_el, r_ec = parse_range_key(range_key)
                    if info.get("rounding", "Neither") != "Neither":
                        parsed_roundings.append({
                            "sl": r_sl, "sc": r_sc, "el": r_el, "ec": r_ec,
                            "rounding": info["rounding"],
                            "source": info.get("source", ""),
                            "expr": info.get("expr", ""),
                        })
                except (ValueError, IndexError):
                    pass

            nodes[node_id] = {
                "label": label,
                "file": file_path,
                "sl": sl,
                "sc": sc,
                "el": el,
                "ec": ec,
                "returnRounding": return_rounding,
                "roundings": parsed_roundings,
            }

        for edge in graph.get("edges", []):
            source = edge.get("source", "")
            target = edge.get("target", "")
            edge_label = edge.get("label", "")

            # Parse call-site info from edge label (e.g., "file.sol:[sl,sc-el,ec]")
            call_file = ""
            call_sl = 0
            call_sc = 0
            if edge_label:
                parsed = parse_method_position(edge_label)
                if parsed:
                    call_file = normalize_path(parsed[0], project_root)
                    call_sl = parsed[1]   # start line
                    call_sc = parsed[2]   # start col

            edges.append({
                "source": source,
                "target": target,
                "file": call_file,
                "sl": call_sl,
                "sc": call_sc,
            })

        graph_label = clean_graph_label(graph.get("label", f"Graph {len(graphs)}"))
        graphs.append({"nodes": nodes, "edges": edges, "label": graph_label})

    return graphs


def normalize_path(filepath, project_root):
    """Make a path relative to project_root."""
    if os.path.isabs(filepath):
        try:
            return os.path.relpath(filepath, project_root)
        except ValueError:
            return filepath
    return filepath


def find_returns_clause(source_lines, method_sl, method_el):
    """Find 'returns (...)' clause in function signature. Returns (sl, sc, el, ec) or None.

    Searches from a few lines before method_sl through method_sl for the 'returns'
    keyword followed by balanced parentheses.
    """
    # Search window: up to 10 lines before method start through the opening brace
    search_start = max(0, method_sl - 11)  # 0-indexed

    # Extend past method_sl to find the opening '{' (covers multi-line signatures)
    search_end_line = method_sl  # 1-indexed, default to method start
    for j in range(method_sl - 1, min(len(source_lines), method_sl + 20)):
        if '{' in source_lines[j]:
            search_end_line = j + 1  # 0-indexed -> 1-indexed
            break
    search_end = min(len(source_lines), search_end_line)

    # Join the search window into one string to handle multi-line returns clauses
    window_lines = source_lines[search_start:search_end]
    window_text = "\n".join(window_lines)

    # Find the last 'returns' keyword (whole word) in the search window
    # We want the last one because there might be comments mentioning 'returns'
    matches = list(re.finditer(r'\breturns\s*\(', window_text))
    if not matches:
        return None

    match = matches[-1]
    returns_pos = match.start()

    # Find balanced closing paren
    paren_start = match.end() - 1  # position of '('
    depth = 1
    pos = paren_start + 1
    while pos < len(window_text) and depth > 0:
        if window_text[pos] == '(':
            depth += 1
        elif window_text[pos] == ')':
            depth -= 1
        pos += 1

    if depth != 0:
        return None

    paren_end = pos  # one past the closing ')'

    # Convert positions back to (line, col) in 1-indexed source coordinates
    # returns_pos and paren_end are offsets into window_text
    def offset_to_line_col(offset):
        line_offset = 0
        for i, line in enumerate(window_lines):
            line_len = len(line) + 1  # +1 for the \n
            if offset < line_offset + line_len:
                col = offset - line_offset
                return (search_start + i + 1, col)  # 1-indexed line, 0-indexed col
            line_offset += line_len
        # Shouldn't reach here
        return (search_start + len(window_lines), 0)

    sl, sc = offset_to_line_col(returns_pos)
    el, ec = offset_to_line_col(paren_end - 1)
    ec += 1  # exclusive end column

    return (sl, sc, el, ec)


def clean_wala_type(wala_type):
    """Extract Solidity type name from WALA type descriptor.

    '<solidity,Puint256>' -> 'uint256'
    '<solidity,Laddress>' -> 'address'
    '<solidity, Puint120>' -> 'uint120'
    """
    m = re.search(r'<\s*solidity\s*,\s*[PL](\w+)\s*>', wala_type)
    if m:
        return m.group(1)
    return wala_type


def extract_return_annotations(data, project_root, source_files):
    """Extract return-type rounding annotations from graph node metadata.

    Returns a dict of filename -> list of annotation dicts, same format as extract_roundings()
    but with an optional 'returnBreakdown' field for mixed roundings.
    """
    # Group by (filename, method_sl, method_el) to deduplicate across graph nodes
    # that share the same methodPosition
    grouped = defaultdict(list)  # (rel_filename, method_sl, method_el) -> list of return values

    for graph_idx, graph in enumerate(data["graphs"]):
        for node_id, node in graph["nodes"].items():
            md = node["metadata"]
            method_pos = md.get("methodPosition", "")
            ret = md.get("return")
            if not method_pos or ret is None:
                continue

            parsed = parse_method_position(method_pos)
            if not parsed:
                continue

            filename, sl, sc, el, ec = parsed
            rel_filename = normalize_path(filename, project_root)
            key = (rel_filename, sl, el)
            grouped[key].append((ret, graph_idx, node_id))

    # Process each unique method position
    result = defaultdict(list)  # rel_filename -> list of annotation dicts

    for (rel_filename, method_sl, method_el), entries in grouped.items():
        # Get source lines for this file
        file_data = source_files.get(rel_filename)
        if not file_data:
            continue

        raw_lines = file_data["raw"].split("\n")

        # Find the returns clause
        clause = find_returns_clause(raw_lines, method_sl, method_el)
        if not clause:
            continue

        r_sl, r_sc, r_el, r_ec = clause

        # Aggregate return roundings across all nodes for this method
        all_return_values = []
        node_refs = []
        seen_refs = set()
        for ret_val, g_idx, n_id in entries:
            ref_key = (g_idx, n_id)
            if ref_key not in seen_refs:
                seen_refs.add(ref_key)
                node_refs.append({"g": g_idx, "n": n_id})

            if isinstance(ret_val, str):
                all_return_values.append({"_single": ret_val})
            elif isinstance(ret_val, dict):
                all_return_values.append(ret_val)

        # Determine the final rounding
        # Flatten all individual rounding values
        flat_roundings = []
        # Also collect per-element info for breakdown
        element_roundings = defaultdict(list)  # wala_type_key -> list of rounding values

        for rv in all_return_values:
            if "_single" in rv:
                flat_roundings.append(rv["_single"])
            else:
                for type_key, rounding in rv.items():
                    flat_roundings.append(rounding)
                    element_roundings[type_key].append(rounding)

        # Filter out Neither for aggregate determination
        significant = [v for v in flat_roundings if v != "Neither"]
        if not significant:
            rounding = "Neither"
        elif len(set(significant)) == 1:
            rounding = significant[0]
        else:
            rounding = "Mixed returns"

        annotation = {
            "sl": r_sl,
            "sc": r_sc,
            "el": r_el,
            "ec": r_ec,
            "rounding": rounding,
            "source": "return type",
            "expr": "",
            "nodeRefs": node_refs,
        }

        # Add breakdown for multi-value returns
        if element_roundings and rounding == "Mixed returns":
            breakdown = []
            # Sort by tuple index extracted from the type key
            sorted_keys = sorted(
                element_roundings.keys(),
                key=lambda k: int(re.search(r'Ltuple,\s*(\d+)', k).group(1))
                if re.search(r'Ltuple,\s*(\d+)', k)
                else 0,
            )
            for i, type_key in enumerate(sorted_keys):
                roundings = element_roundings[type_key]
                agg = aggregate_rounding(roundings)
                # Extract the inner type
                # type_key looks like "< solidity, Ltuple, 1, <solidity,Puint256> >"
                inner_match = re.search(r'<\s*solidity\s*,\s*[PL]\w+\s*>', type_key)
                sol_type = clean_wala_type(inner_match.group(0)) if inner_match else f"[{i}]"
                breakdown.append({"index": i, "type": sol_type, "rounding": agg})
            annotation["returnBreakdown"] = breakdown

        result[rel_filename].append(annotation)

    return dict(result)


def collect_referenced_files_from_paths(file_paths, project_root):
    """Read source files by path, with Pygments highlighting."""
    formatter = HtmlFormatter(nowrap=True)
    sol_lexer = SolidityLexer()
    source_files = {}
    for rel_path in file_paths:
        abs_path = os.path.join(project_root, rel_path)
        try:
            with open(abs_path, "r") as f:
                raw = f.read()
        except FileNotFoundError:
            print(f"Warning: source file not found: {abs_path}", file=sys.stderr)
            raw = f"// File not found: {abs_path}"

        # Choose lexer: .sol -> SolidityLexer, else try by filename
        if rel_path.endswith(".sol"):
            lexer = sol_lexer
        else:
            try:
                lexer = get_lexer_for_filename(rel_path)
            except Exception:
                lexer = sol_lexer  # fallback

        highlighted = pygments_highlight(raw, lexer, formatter)
        highlighted_lines = highlighted.split("\n")
        # Pygments adds a trailing newline, so the last element is usually empty
        if highlighted_lines and highlighted_lines[-1] == "":
            highlighted_lines.pop()

        source_files[rel_path] = {
            "raw": raw,
            "highlightedLines": highlighted_lines,
        }
    return source_files


def build_directory_tree(file_paths):
    """Build a nested directory tree from a list of file paths."""
    root = {"name": "", "children": [], "files": []}

    for path in sorted(file_paths):
        parts = path.split("/")
        node = root
        for part in parts[:-1]:
            # Find or create child directory
            found = None
            for child in node["children"]:
                if child["name"] == part:
                    found = child
                    break
            if found is None:
                found = {"name": part, "children": [], "files": []}
                node["children"].append(found)
            node = found
        node["files"].append(parts[-1])

    return root


def generate_html(project_root, source_files, directory_tree, contexts, graphs, contracts=None):
    """Generate the self-contained HTML string."""
    data_json = json.dumps(
        {
            "projectRoot": project_root,
            "sourceFiles": source_files,
            "directoryTree": directory_tree,
            "contexts": contexts,
            "graphs": graphs,
        }
    )

    pygments_css = HtmlFormatter(style="default").get_style_defs(".line-content")

    # Load dagre.js for graph visualization
    dagre_path = os.path.join(os.path.dirname(__file__), "dagre.min.js")
    try:
        with open(dagre_path, "r") as f:
            dagre_js = f.read()
    except FileNotFoundError:
        dagre_js = "/* dagre.min.js not found */"
        print(f"Warning: {dagre_path} not found, graph view will be disabled", file=sys.stderr)

    title = "Certora RoundAbout — " + os.path.basename(project_root)
    if contracts:
        title += " — " + ", ".join(contracts)
    html_start = HTML_TEMPLATE_START.replace(
        "<title>Certora RoundAbout</title>",
        "<title>" + title + "</title>",
    )

    return (
        html_start
        + "\n/* Pygments syntax highlighting */\n"
        + pygments_css
        + "\n"
        + HTML_TEMPLATE_SCRIPT_START
        + "\n/* dagre.js graph layout library */\n"
        + dagre_js
        + "\n\nconst DATA = "
        + data_json
        + ";\n"
        + HTML_TEMPLATE_END
    )


HTML_TEMPLATE_START = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Certora RoundAbout</title>
<link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'%3E%3Ccircle cx='50' cy='50' r='44' fill='none' stroke='%231e293b' stroke-width='5.5'/%3E%3Ccircle cx='50' cy='50' r='13' fill='none' stroke='%231e293b' stroke-width='5.5'/%3E%3Cpath d='M 35,23 A 30,30 0 0,1 65,23' fill='none' stroke='%231e293b' stroke-width='5' stroke-linecap='round'/%3E%3Cpolygon points='60,14 72,23 60,32' fill='%231e293b'/%3E%3Cpath d='M 77,65 A 30,30 0 0,0 77,35' fill='none' stroke='%231e293b' stroke-width='5' stroke-linecap='round'/%3E%3Cpolygon points='69,38 77,26 85,38' fill='%231e293b'/%3E%3Cpath d='M 65,77 A 30,30 0 0,1 35,77' fill='none' stroke='%231e293b' stroke-width='5' stroke-linecap='round'/%3E%3Cpolygon points='40,68 28,77 40,86' fill='%231e293b'/%3E%3Cpath d='M 23,65 A 30,30 0 0,1 23,35' fill='none' stroke='%231e293b' stroke-width='5' stroke-linecap='round'/%3E%3Cpolygon points='15,38 23,26 31,38' fill='%231e293b'/%3E%3C/svg%3E">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { height: 100%; font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
body { display: flex; flex-direction: column; background: #f8fafc; color: #333; }

#top-bar {
  background: linear-gradient(135deg, #1e293b, #334155);
  border-bottom: 1px solid #1e293b;
  padding: 8px 16px; font-size: 13px; color: #fff;
  display: flex; align-items: center; gap: 16px; flex-shrink: 0;
}
#top-bar .project-root { font-family: 'JetBrains Mono', Consolas, monospace; color: rgba(255,255,255,0.85); }

#context-bar {
  background: #fff; border-bottom: 1px solid #e2e8f0;
  padding: 6px 16px; display: flex; gap: 6px; flex-shrink: 0;
  overflow-x: auto; overflow-y: auto; flex-wrap: wrap;
}
.ctx-btn { white-space: nowrap; }
.ctx-btn {
  padding: 4px 12px; border: 1px solid #e2e8f0; border-radius: 4px;
  background: transparent; color: #64748b; cursor: pointer; font-size: 12px;
}
.ctx-btn.active { background: #e2e8f0; color: #1e293b; border-color: #cbd5e1; }

#main { display: flex; flex: 1; overflow: hidden; }

#tree-panel {
  width: 260px; min-width: 180px; background: #f8f9fa;
  border-right: 1px solid #e0e0e0; overflow-y: auto; padding: 8px 0;
  flex-shrink: 0; font-size: 13px;
}

.tree-dir, .tree-file {
  padding: 3px 8px; cursor: pointer; white-space: nowrap;
  overflow: hidden; text-overflow: ellipsis;
}
.tree-dir { color: #1e293b; font-weight: 600; }
.tree-dir:hover { background: #e9ecef; }
.tree-file { color: #333; padding-left: 4px; }
.tree-file:hover { background: #e9ecef; }
.tree-file.active { background: #d0e1fd; color: #1e293b; }
.tree-children { padding-left: 14px; }
.tree-toggle { display: inline-block; width: 14px; text-align: center; color: #94a3b8; font-size: 11px; }

#source-panel { flex: 1; overflow: auto; background: #fff; }

#source-header {
  position: sticky; top: 0; z-index: 10; background: #f8f9fa;
  border-bottom: 1px solid #e0e0e0; padding: 8px 16px;
  font-family: 'JetBrains Mono', Consolas, monospace; font-size: 13px; color: #64748b;
  display: flex; align-items: center; gap: 12px;
}
#source-nav {
  display: flex; align-items: center; gap: 6px;
  margin-left: auto;
}
#source-nav .nav-counter {
  font-size: 12px; color: #64748b; min-width: 50px; text-align: center;
}
#source-nav button {
  background: none; border: 1px solid #e0e0e0; border-radius: 4px;
  cursor: pointer; padding: 2px 8px; font-size: 14px; color: #64748b;
  line-height: 1;
}
#source-nav button:hover { background: #e9ecef; }
#source-nav button:disabled { opacity: 0.3; cursor: default; }
#source-placeholder {
  display: flex; align-items: center; justify-content: center;
  height: 100%; color: #94a3b8; font-size: 14px;
}

table.source-code {
  border-collapse: collapse; width: 100%;
  font-family: 'JetBrains Mono', Consolas, monospace; font-size: 13px; line-height: 1.5;
}
table.source-code td { padding: 0 12px; vertical-align: top; white-space: pre; }
td.line-num {
  text-align: right; color: #adb5bd; user-select: none;
  width: 1%; min-width: 48px; border-right: 1px solid #eee;
  padding-right: 8px;
}
td.line-content { padding-left: 12px; }

/* Rounding underline classes */
.r-up { text-decoration: underline; text-decoration-color: #2563eb; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-down { text-decoration: underline; text-decoration-color: #4ade80; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-inconsistent { text-decoration: underline; text-decoration-color: #dc2626; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-either { text-decoration: underline; text-decoration-color: #f59e0b; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-neither { text-decoration: underline; text-decoration-color: #d1d5db; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-mixed { text-decoration: underline; text-decoration-color: #000; text-underline-offset: 3px; text-decoration-thickness: 2px; }

/* Tooltip */
.r-up, .r-down, .r-inconsistent, .r-either, .r-neither, .r-mixed { position: relative; cursor: default; }
.annotation-span:hover .tooltip, .annotation-span:focus .tooltip { display: block; }
.tooltip {
  display: none; position: fixed; z-index: 1000;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 6px;
  padding: 8px 12px; font-size: 12px; line-height: 1.5;
  color: #333; white-space: pre-wrap; max-width: 500px;
  pointer-events: none; box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}
.tooltip .tt-label { color: #64748b; }
.tooltip .tt-rounding-up { color: #2563eb; font-weight: 600; }
.tooltip .tt-rounding-down { color: #4ade80; font-weight: 600; }
.tooltip .tt-rounding-inconsistent { color: #f59e0b; font-weight: 600; }
.tooltip .tt-rounding-either { color: #dc2626; font-weight: 600; }
.tooltip .tt-rounding-neither { color: #d1d5db; font-weight: 600; }
.tooltip .tt-rounding-mixed-returns { color: #000; font-weight: 600; }
.tooltip .tt-breakdown { margin-top: 4px; padding-top: 4px; border-top: 1px solid #e2e8f0; }
.tooltip .tt-breakdown-entry { margin-top: 2px; }

/* Legend */
#legend {
  display: flex; gap: 16px; align-items: center; margin-left: auto; font-size: 12px;
}
.legend-item { display: flex; align-items: center; gap: 4px; color: rgba(255,255,255,0.85); }
.legend-swatch {
  width: 20px; height: 3px; border-radius: 1px;
}

/* Resize handle */
#resize-handle {
  width: 4px; cursor: col-resize; background: transparent; flex-shrink: 0;
}
#resize-handle:hover { background: #dee2e6; }
#method-list-resize-handle {
  display: none; width: 4px; cursor: col-resize; background: transparent; flex-shrink: 0;
}
#method-list-resize-handle:hover { background: #dee2e6; }
.tree-file.has-findings { background: #fefce8; }
.tree-file.has-findings:hover { background: #fef9c3; }
.tree-file.has-findings.active { background: #d0e1fd; }
.finding-count { color: #a16207; font-size: 11px; margin-left: 4px; }

/* Bottom pane */
#bottom-resize-handle {
  display: none; height: 4px; cursor: row-resize; background: transparent; flex-shrink: 0;
}
#bottom-resize-handle:hover { background: #dee2e6; }
#bottom-resize-handle.visible { display: block; }
#bottom-pane {
  display: none; height: 220px; min-height: 100px; flex-shrink: 0;
  border-top: 1px solid #e0e0e0; background: #f8f9fa;
}
#bottom-pane.visible { display: flex; }
#parents-pane, #children-pane {
  flex: 1; display: flex; flex-direction: column; overflow: hidden;
}
#parents-pane { border-right: 1px solid #e0e0e0; }
.pane-header {
  position: sticky; top: 0; padding: 6px 12px; font-size: 12px; font-weight: 600;
  color: #64748b; background: #f1f5f9; border-bottom: 1px solid #e2e8f0; flex-shrink: 0;
}
.pane-content {
  flex: 1; overflow-y: auto; padding: 8px; display: flex; flex-wrap: wrap;
  gap: 8px; align-content: flex-start;
}
.node-box {
  border: 1px solid #e2e8f0; border-radius: 6px; padding: 8px 10px;
  background: #fff; cursor: pointer; min-width: 160px; max-width: 260px;
  transition: box-shadow 0.15s;
}
.node-box:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
.nb-func { font-family: 'JetBrains Mono', Consolas, monospace; font-weight: 600; font-size: 13px; color: #1e293b; }
.nb-file { font-size: 11px; color: #94a3b8; margin-top: 2px; }
.nb-callsite { font-size: 11px; color: #7c3aed; margin-top: 2px; text-decoration: underline; cursor: pointer; }
.nb-callsite:hover { color: #6d28d9; }
.nb-return { font-size: 11px; color: #94a3b8; margin-top: 2px; }
.pane-empty { color: #94a3b8; font-size: 12px; padding: 12px; }
.annotation-span { cursor: pointer; }
.ann-selected { background: rgba(124, 58, 237, 0.12); border-radius: 2px; }

.type-counts { display: inline-flex; align-items: center; gap: 4px; }
.type-badge {
  display: inline-flex; align-items: center; gap: 2px;
  background: #f1f5f9; border-radius: 4px; padding: 2px 6px; font-size: 11px;
}
.type-badge .badge-label { font-weight: 600; }
.type-badge .badge-count { color: #64748b; }
.type-badge.empty { opacity: 0.4; }
.type-badge { position: relative; cursor: default; }
.type-badge .badge-tooltip {
  display: none; position: fixed; z-index: 1000;
  background: #1e293b; color: #e2e8f0; border-radius: 4px; padding: 4px 8px;
  font-size: 11px; white-space: nowrap;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15); pointer-events: none;
}

/* View toggle */
.view-toggle { display: flex; gap: 4px; margin-left: 16px; }
.view-btn {
  padding: 4px 12px; border: 1px solid rgba(255,255,255,0.2); border-radius: 4px;
  background: transparent; color: rgba(255,255,255,0.7); cursor: pointer; font-size: 12px;
}
.view-btn:hover { background: rgba(255,255,255,0.1); }
.view-btn.active { background: rgba(255,255,255,0.2); color: #fff; border-color: rgba(255,255,255,0.4); }

/* Method list (graph view left pane) */
#method-list {
  display: none; width: 260px; min-width: 180px; background: #f8f9fa;
  border-right: 1px solid #e0e0e0; overflow-y: auto; padding: 8px 0;
  flex-shrink: 0; font-size: 13px;
}
.method-item {
  padding: 5px 12px; cursor: pointer; white-space: nowrap;
  overflow: hidden; text-overflow: ellipsis; display: flex; align-items: center; gap: 6px;
}
.method-item:hover { background: #e9ecef; }
.method-item.active { background: #d0e1fd; color: #1e293b; }
.method-name { overflow: hidden; text-overflow: ellipsis; }
.method-badge {
  flex-shrink: 0; width: 8px; height: 8px; border-radius: 50%;
}
.method-count { flex-shrink: 0; font-size: 11px; color: #94a3b8; }

/* Graph panel */
#graph-panel { display: none; flex: 1; overflow: hidden; position: relative; background: #f1f5f9; flex-direction: column; }
#graph-scroll { flex: 1; overflow: auto; }
#graph-container { position: relative; min-width: 100%; min-height: 100%; }
#graph-edges { position: absolute; top: 0; left: 0; pointer-events: none; overflow: visible; }
.graph-edge { stroke: #94a3b8; stroke-width: 1.5; fill: none; }

/* Graph nodes */
.graph-node {
  position: absolute; border: 1px solid #d0d5dd; border-radius: 6px;
  background: #fff; box-shadow: 0 1px 4px rgba(0,0,0,0.08); overflow: hidden;
  cursor: pointer; transition: box-shadow 0.15s;
  width: 320px;
}
.graph-node:hover { box-shadow: 0 2px 12px rgba(0,0,0,0.15); }
.graph-node.focused { border: 2px solid #3b82f6; box-shadow: 0 2px 12px rgba(59,130,246,0.25); width: auto; min-width: 320px; }
.graph-node.compact { width: 220px; }
.graph-node.compact .graph-node-source { display: none; }
.graph-node-header {
  padding: 5px 10px; font-weight: 600; font-size: 12px;
  border-bottom: 1px solid #e2e8f0; background: #f8f9fa;
  display: flex; align-items: center; gap: 6px;
}
.graph-node-header .go-to-source {
  margin-left: auto; font-weight: 400; font-size: 10px; color: #3b82f6;
  text-decoration: none; flex-shrink: 0; padding: 1px 4px; border-radius: 3px;
}
.graph-node-header .go-to-source:hover { background: #eff6ff; text-decoration: underline; }
#graph-breadcrumb {
  display: none; padding: 6px 12px; background: #e2e8f0; font-size: 12px;
  border-bottom: 1px solid #cbd5e1; align-items: center; gap: 4px; flex-shrink: 0;
}
#graph-breadcrumb .bc-item { color: #3b82f6; cursor: pointer; }
#graph-breadcrumb .bc-item:hover { text-decoration: underline; }
#graph-breadcrumb .bc-sep { color: #94a3b8; }
#graph-breadcrumb .bc-current { color: #1e293b; font-weight: 600; }
.graph-node-header .node-rounding-dot {
  width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0;
}
.graph-node-file { font-size: 10px; color: #64748b; padding: 2px 10px; background: #fafbfc; border-bottom: 1px solid #f0f0f0; }
.graph-node-source {
  padding: 4px 8px; font-family: 'JetBrains Mono', Consolas, monospace; font-size: 11px;
  line-height: 1.4; white-space: pre; overflow-x: auto;
  color: #333;
}
/* Reuse existing .r-up, .r-down, etc. for source annotations inside graph nodes */
"""

HTML_TEMPLATE_SCRIPT_START = r"""
</style>
</head>
<body>

<div id="top-bar">
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="22" height="22" style="vertical-align:middle;margin-right:6px;"><circle cx="50" cy="50" r="44" fill="none" stroke="#fff" stroke-width="5.5"/><circle cx="50" cy="50" r="13" fill="none" stroke="#fff" stroke-width="5.5"/><path d="M 35,23 A 30,30 0 0,1 65,23" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/><polygon points="60,14 72,23 60,32" fill="#fff"/><path d="M 77,65 A 30,30 0 0,0 77,35" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/><polygon points="69,38 77,26 85,38" fill="#fff"/><path d="M 65,77 A 30,30 0 0,1 35,77" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/><polygon points="40,68 28,77 40,86" fill="#fff"/><path d="M 23,65 A 30,30 0 0,1 23,35" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round"/><polygon points="15,38 23,26 31,38" fill="#fff"/></svg><span style="font-weight:600;">Certora RoundAbout</span>
  <span class="project-root" id="project-root-display"></span>
  <div class="view-toggle">
    <button class="view-btn active" onclick="switchView('graph')">Graph</button>
    <button class="view-btn" onclick="switchView('source')">Source</button>
  </div>
  <div id="legend">
    <div class="legend-item"><div class="legend-swatch" style="background:#2563eb"></div> Up</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#4ade80"></div> Down</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#f59e0b"></div> Either</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#dc2626"></div> Inconsistent</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#000"></div> Mixed returns</div>
  </div>
</div>

<div id="context-bar"></div>

<div id="main">
  <div id="tree-panel"></div>
  <div id="method-list"></div>
  <div id="method-list-resize-handle"></div>
  <div id="resize-handle"></div>
  <div id="source-panel">
    <div id="source-placeholder">Select a file from the tree to view source</div>
  </div>
  <div id="graph-panel">
    <div id="graph-breadcrumb"></div>
    <div id="graph-scroll">
      <div id="graph-container">
        <svg id="graph-edges"><defs><marker id="arrowhead" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0, 8 3, 0 6" fill="#94a3b8"/></marker></defs></svg>
        <div id="graph-nodes"></div>
      </div>
    </div>
  </div>
</div>

<div id="bottom-resize-handle"></div>
<div id="bottom-pane">
  <div id="parents-pane">
    <div class="pane-header">Parents (callers)</div>
    <div class="pane-content" id="parents-content"></div>
  </div>
  <div id="children-pane">
    <div class="pane-header">Children (callees)</div>
    <div class="pane-content" id="children-content"></div>
  </div>
</div>

<script>
"""

HTML_TEMPLATE_END = r"""
const ROUNDING_TYPES = ['Up', 'Down', 'Either', 'Inconsistent'];
const ROUNDING_COLORS = { Up:'#2563eb', Down:'#4ade80', Either:'#f59e0b', Inconsistent:'#dc2626', Neither:'#d1d5db', 'Mixed returns':'#000' };
const ROUNDING_SHORT = { Up:'U', Down:'D', Inconsistent:'I', Either:'E', Neither:'N', 'Mixed returns':'MR' };

let currentFile = null;
let currentContext = Object.keys(DATA.contexts)[0] || 'contextFree';
let currentFindings = [];
let currentFindingIdx = -1;
let nodePositionIndex = {};
let highlightedRow = null;

function highlightLine(tr) {
  if (highlightedRow) highlightedRow.style.background = '';
  tr.style.transition = 'background 0.15s';
  tr.style.background = '#fef9c3';
  highlightedRow = tr;
}

function init() {
  document.getElementById('project-root-display').textContent = DATA.projectRoot;
  renderTree(DATA.directoryTree, document.getElementById('tree-panel'), '');
  const contextNames = Object.keys(DATA.contexts);
  if (contextNames.length > 1) {
    buildContextBar();
    updateContextCounts();
  } else {
    document.getElementById('context-bar').style.display = 'none';
  }
  setupResize();
  setupMethodListResize();
  setupBottomResize();
  updateTreeHighlights();
  buildNodePositionIndex();
  document.getElementById('source-panel').addEventListener('click', (e) => {
    if (!e.target.closest('.annotation-span')) {
      document.querySelectorAll('.ann-selected').forEach(el => el.classList.remove('ann-selected'));
    }
  });
  switchView('graph');
}

function buildContextBar() {
  const bar = document.getElementById('context-bar');
  const names = Object.keys(DATA.contexts);
  // Put allContexts first, then sort the rest alphabetically
  const sorted = names.filter(n => n === 'allContexts').concat(
    names.filter(n => n !== 'allContexts').sort()
  );
  for (const name of sorted) {
    const btn = document.createElement('button');
    btn.className = 'ctx-btn' + (name === 'allContexts' ? ' active' : '');
    btn.dataset.context = name;
    btn.textContent = name === 'allContexts' ? 'All' : name;
    btn.addEventListener('click', () => switchContext(name));
    bar.appendChild(btn);
  }
}

function buildNodePositionIndex() {
  nodePositionIndex = {};
  for (let g = 0; g < (DATA.graphs || []).length; g++) {
    const graph = DATA.graphs[g];
    for (const n in graph.nodes) {
      const node = graph.nodes[n];
      if (node.file && node.sl) {
        const key = node.file + ':' + node.sl;
        if (!nodePositionIndex[key]) nodePositionIndex[key] = [];
        nodePositionIndex[key].push({g: g, n: n});
      }
    }
  }
}

function renderTree(node, container, pathPrefix) {
  // Render subdirectories
  for (const child of (node.children || [])) {
    const childPath = pathPrefix ? pathPrefix + '/' + child.name : child.name;
    const dirEl = document.createElement('div');

    const dirHeader = document.createElement('div');
    dirHeader.className = 'tree-dir';

    const toggle = document.createElement('span');
    toggle.className = 'tree-toggle';
    toggle.textContent = '\u25BE';
    dirHeader.appendChild(toggle);
    dirHeader.appendChild(document.createTextNode(' ' + child.name));
    dirEl.appendChild(dirHeader);

    const childrenEl = document.createElement('div');
    childrenEl.className = 'tree-children';
    renderTree(child, childrenEl, childPath);
    dirEl.appendChild(childrenEl);

    dirHeader.addEventListener('click', () => {
      const collapsed = childrenEl.style.display === 'none';
      childrenEl.style.display = collapsed ? '' : 'none';
      toggle.textContent = collapsed ? '\u25BE' : '\u25B8';
    });

    container.appendChild(dirEl);
  }

  // Render files
  for (const file of (node.files || [])) {
    const filePath = pathPrefix ? pathPrefix + '/' + file : file;
    const fileEl = document.createElement('div');
    fileEl.className = 'tree-file';
    fileEl.textContent = file;
    fileEl.dataset.path = filePath;
    fileEl.addEventListener('click', () => showFile(filePath));
    container.appendChild(fileEl);
  }
}

function updateTreeHighlights() {
  const ctx = DATA.contexts[currentContext] || {};
  document.querySelectorAll('.tree-file').forEach(el => {
    const path = el.dataset.path;
    const annotations = ctx[path] || [];
    const count = annotations.filter(a => a.rounding !== 'Neither').length;
    const old = el.querySelector('.finding-count');
    if (old) old.remove();
    if (count > 0) {
      el.classList.add('has-findings');
      const span = document.createElement('span');
      span.className = 'finding-count';
      span.textContent = '(' + count + ')';
      el.appendChild(span);
    } else {
      el.classList.remove('has-findings');
    }
  });
}

function updateContextCounts() {
  document.querySelectorAll('.ctx-btn').forEach(btn => {
    const ctxName = btn.dataset.context;
    const ctx = DATA.contexts[ctxName] || {};
    let total = 0;
    for (const file in ctx) total += ctx[file].filter(a => a.rounding !== 'Neither').length;
    const label = ctxName === 'allContexts' ? 'All' : ctxName;
    btn.textContent = label + (total > 0 ? ' (' + total + ')' : '');
  });
}

function showFile(filePath) {
  // Update active state in tree
  document.querySelectorAll('.tree-file').forEach(el => {
    el.classList.toggle('active', el.dataset.path === filePath);
  });

  currentFile = filePath;
  const panel = document.getElementById('source-panel');
  panel.innerHTML = '';

  const header = document.createElement('div');
  header.id = 'source-header';
  const pathSpan = document.createElement('span');
  pathSpan.textContent = filePath;
  header.appendChild(pathSpan);
  panel.appendChild(header);

  const fileData = DATA.sourceFiles[filePath];
  if (!fileData) {
    const msg = document.createElement('div');
    msg.id = 'source-placeholder';
    msg.textContent = 'Source not available for ' + filePath;
    panel.appendChild(msg);
    currentFindings = [];
    currentFindingIdx = -1;
    return;
  }

  const annotations = (DATA.contexts[currentContext] || {})[filePath] || [];
  for (let i = 0; i < annotations.length; i++) annotations[i]._id = i;
  const findingLines = [...new Set(annotations.filter(a => a.rounding !== 'Neither').map(a => a.sl))].sort((a, b) => a - b);
  currentFindings = findingLines;
  currentFindingIdx = -1;

  const typeCounts = document.createElement('span');
  typeCounts.className = 'type-counts';
  for (const t of ROUNDING_TYPES) {
    const matching = annotations.filter(a => a.rounding === t);
    const lines = [...new Set(matching.map(a => a.sl))].sort((a, b) => a - b);
    const compressed = [];
    let ci = 0;
    while (ci < lines.length) {
      let cj = ci;
      while (cj + 1 < lines.length && lines[cj + 1] === lines[cj] + 1) cj++;
      compressed.push(cj > ci ? lines[ci] + '-' + lines[cj] : '' + lines[ci]);
      ci = cj + 1;
    }
    const count = compressed.length;
    const badge = document.createElement('span');
    badge.className = 'type-badge' + (count === 0 ? ' empty' : '');
    const lbl = document.createElement('span');
    lbl.className = 'badge-label';
    lbl.style.color = ROUNDING_COLORS[t];
    lbl.textContent = ROUNDING_SHORT[t] + ':';
    const cnt = document.createElement('span');
    cnt.className = 'badge-count';
    cnt.textContent = count;
    badge.appendChild(lbl);
    badge.appendChild(cnt);
    if (count > 0) {
      const tip = document.createElement('span');
      tip.className = 'badge-tooltip';
      tip.textContent = 'Lines: ' + compressed.join(', ');
      badge.appendChild(tip);
      badge.addEventListener('mouseenter', (e) => {
        tip.style.display = 'block';
        const r = tip.getBoundingClientRect();
        let x = e.clientX;
        let y = e.clientY + 16;
        if (x + r.width > window.innerWidth - 24) x = window.innerWidth - r.width - 24;
        if (x < 16) x = 16;
        if (y + r.height > window.innerHeight - 24) y = e.clientY - r.height - 16;
        tip.style.left = x + 'px';
        tip.style.top = y + 'px';
      });
      badge.addEventListener('mouseleave', () => { tip.style.display = 'none'; });
    }
    typeCounts.appendChild(badge);
  }
  header.appendChild(typeCounts);

  const nav = document.createElement('span');
  nav.id = 'source-nav';
  const upBtn = document.createElement('button');
  upBtn.textContent = '\u25B2';
  upBtn.disabled = true;
  upBtn.addEventListener('click', () => navigateToFinding(-1));
  const counter = document.createElement('span');
  counter.className = 'nav-counter';
  counter.textContent = findingLines.length > 0 ? '0/' + findingLines.length + ' sites' : '0/0 sites';
  const downBtn = document.createElement('button');
  downBtn.textContent = '\u25BC';
  downBtn.disabled = findingLines.length === 0;
  downBtn.addEventListener('click', () => navigateToFinding(+1));
  nav.appendChild(upBtn);
  nav.appendChild(counter);
  nav.appendChild(downBtn);
  header.appendChild(nav);

  const table = renderSource(fileData.raw, fileData.highlightedLines || [], annotations);
  panel.appendChild(table);
}

function updateFindingNav(idx) {
  const nav = document.getElementById('source-nav');
  if (nav) {
    nav.querySelector('.nav-counter').textContent = (idx + 1) + '/' + currentFindings.length + ' sites';
    const btns = nav.querySelectorAll('button');
    btns[0].disabled = idx === 0;
    btns[1].disabled = idx === currentFindings.length - 1;
  }
}

function navigateToFinding(direction) {
  if (currentFindings.length === 0) return;
  let idx = currentFindingIdx + direction;
  if (idx < 0) idx = 0;
  if (idx >= currentFindings.length) idx = currentFindings.length - 1;
  currentFindingIdx = idx;
  updateFindingNav(idx);

  const lineNum = currentFindings[idx];
  const table = document.querySelector('table.source-code');
  if (table) {
    const tr = table.rows[lineNum - 1];
    if (tr) {
      tr.scrollIntoView({ behavior: 'smooth', block: 'center' });
      highlightLine(tr);
    }
  }
}

function renderSource(source, highlightedLines, annotations) {
  const lines = source.split('\n');
  const table = document.createElement('table');
  table.className = 'source-code';

  for (let i = 0; i < lines.length; i++) {
    const lineNum = i + 1;
    const tr = document.createElement('tr');

    const tdNum = document.createElement('td');
    tdNum.className = 'line-num';
    tdNum.textContent = lineNum;
    tr.appendChild(tdNum);

    const tdContent = document.createElement('td');
    tdContent.className = 'line-content';

    const lineText = lines[i];
    const lineAnnotations = getAnnotationsForLine(annotations, lineNum, lineText.length);

    if (lineAnnotations.length === 0) {
      // Use Pygments-highlighted HTML for lines without rounding annotations
      if (highlightedLines[i] !== undefined && highlightedLines[i] !== '') {
        tdContent.innerHTML = highlightedLines[i];
      } else {
        tdContent.textContent = lineText || ' ';
      }
    } else {
      // Use raw text + annotation spans for lines with rounding underlines
      tdContent.appendChild(buildAnnotatedLine(lineText, lineAnnotations, lineNum));
    }

    tr.appendChild(tdContent);
    table.appendChild(tr);
  }

  return table;
}

function getAnnotationsForLine(annotations, lineNum, lineLen) {
  // Find annotations that overlap this line
  const result = [];
  for (const a of annotations) {
    if (a.sl > lineNum || a.el < lineNum) continue;
    if (a.rounding === 'Neither') continue;
    // Compute character range on this line (0-based columns, exclusive end)
    let startCol = (a.sl === lineNum) ? a.sc : 0;
    let endCol = (a.el === lineNum) ? a.ec : lineLen;
    result.push({
      startCol, endCol,
      rounding: a.rounding,
      source: a.source || '',
      expr: a.expr || '',
      nodeRefs: a.nodeRefs || [],
      returnBreakdown: a.returnBreakdown || null,
      _id: a._id,
      origSl: a.sl, origSc: a.sc, origEl: a.el, origEc: a.ec,
      // size for sorting: total span
      size: (a.el - a.sl) * 10000 + (a.ec - a.sc)
    });
  }
  return result;
}

function buildAnnotatedLine(lineText, annotations, lineNum) {
  const frag = document.createDocumentFragment();
  if (lineText.length === 0) {
    frag.appendChild(document.createTextNode(' '));
    return frag;
  }

  // For each character position, find the innermost (smallest) annotation
  // Sort annotations by size ascending -> smallest first
  const sorted = [...annotations].sort((a, b) => a.size - b.size);

  // Build array: for each char index (0-based), which annotation (or null)
  const charAnnotation = new Array(lineText.length).fill(null);
  // Apply largest first, then smallest overwrites -> smallest wins
  const bySizeLargest = [...sorted].reverse();
  for (const ann of bySizeLargest) {
    const start = ann.startCol;
    const end = Math.min(ann.endCol, lineText.length);
    for (let i = start; i < end; i++) {
      charAnnotation[i] = ann;
    }
  }

  // Build segments of consecutive chars with the same annotation
  let segStart = 0;
  while (segStart < lineText.length) {
    const ann = charAnnotation[segStart];
    let segEnd = segStart + 1;
    while (segEnd < lineText.length && charAnnotation[segEnd] === ann) {
      segEnd++;
    }

    const text = lineText.substring(segStart, segEnd);
    if (ann === null) {
      frag.appendChild(document.createTextNode(text));
    } else {
      const span = document.createElement('span');
      span.className = 'annotation-span ' + roundingClass(ann.rounding);
      span.dataset.annId = ann._id;
      span.textContent = text;

      // Tooltip
      const tooltip = document.createElement('span');
      tooltip.className = 'tooltip';
      tooltip.innerHTML = buildTooltipHTML(ann);
      span.appendChild(tooltip);

      // Position tooltip on hover
      span.addEventListener('mouseenter', (e) => {
        tooltip.style.display = 'block';
        positionTooltip(tooltip, e);
      });
      span.addEventListener('mousemove', (e) => {
        positionTooltip(tooltip, e);
      });
      span.addEventListener('mouseleave', () => {
        tooltip.style.display = 'none';
      });

      span.addEventListener('click', (e) => {
        e.stopPropagation();
        document.querySelectorAll('.ann-selected').forEach(el => el.classList.remove('ann-selected'));
        document.querySelectorAll('[data-ann-id="' + ann._id + '"]').forEach(el => el.classList.add('ann-selected'));
        if (ann.nodeRefs && ann.nodeRefs.length > 0) {
          showNodeRelationships(ann.nodeRefs, {
            file: currentFile,
            sl: ann.origSl, sc: ann.origSc,
            el: ann.origEl, ec: ann.origEc
          });
        }
        const findIdx = currentFindings.indexOf(ann.origSl);
        if (findIdx !== -1) {
          currentFindingIdx = findIdx;
          updateFindingNav(findIdx);
        }
      });

      frag.appendChild(span);
    }

    segStart = segEnd;
  }

  return frag;
}

function positionTooltip(tooltip, e) {
  const x = e.clientX + 12;
  const y = e.clientY + 12;
  // Keep tooltip on screen
  const rect = tooltip.getBoundingClientRect();
  const maxX = window.innerWidth - (rect.width || 300) - 8;
  const maxY = window.innerHeight - (rect.height || 80) - 8;
  tooltip.style.left = Math.min(x, Math.max(0, maxX)) + 'px';
  tooltip.style.top = Math.min(y, Math.max(0, maxY)) + 'px';
}

function roundingClass(rounding) {
  switch (rounding) {
    case 'Up': return 'r-up';
    case 'Down': return 'r-down';
    case 'Inconsistent': return 'r-inconsistent';
    case 'Either': return 'r-either';
    case 'Neither': return 'r-neither';
    case 'Mixed returns': return 'r-mixed';
    default: return '';
  }
}

function tooltipClass(rounding) {
  return 'tt-rounding-' + rounding.toLowerCase().replace(/\s+/g, '-');
}

function buildTooltipHTML(ann) {
  const rcls = tooltipClass(ann.rounding);
  let html = '<span class="tt-label">Rounding:</span> <span class="' + rcls + '">' + escapeHtml(ann.rounding) + '</span>';
  if (ann.source) {
    html += '\n<span class="tt-label">Expression:</span> ' + escapeHtml(ann.source);
  }
  if (ann.expr) {
    html += '\n<span class="tt-label">In:</span> ' + escapeHtml(ann.expr);
  }
  if (ann.returnBreakdown && ann.returnBreakdown.length > 0) {
    html += '\n<div class="tt-breakdown">';
    for (const entry of ann.returnBreakdown) {
      const entryRcls = tooltipClass(entry.rounding);
      html += '<div class="tt-breakdown-entry">return[' + entry.index + '] (' + escapeHtml(entry.type) + '): <span class="' + entryRcls + '">' + escapeHtml(entry.rounding) + '</span></div>';
    }
    html += '</div>';
  }
  return html;
}

function escapeHtml(str) {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function switchContext(name) {
  currentContext = name;
  document.querySelectorAll('.ctx-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.context === name);
  });
  updateContextCounts();
  updateTreeHighlights();
  if (currentFile) showFile(currentFile);
}

function setupResize() {
  const handle = document.getElementById('resize-handle');
  const treePanel = document.getElementById('tree-panel');
  let startX, startWidth;

  handle.addEventListener('mousedown', (e) => {
    startX = e.clientX;
    startWidth = treePanel.offsetWidth;
    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
    e.preventDefault();
  });

  function onMouseMove(e) {
    const newWidth = startWidth + (e.clientX - startX);
    treePanel.style.width = Math.max(120, Math.min(600, newWidth)) + 'px';
  }

  function onMouseUp() {
    document.removeEventListener('mousemove', onMouseMove);
    document.removeEventListener('mouseup', onMouseUp);
  }
}

function setupMethodListResize() {
  const handle = document.getElementById('method-list-resize-handle');
  const methodList = document.getElementById('method-list');
  let startX, startWidth;

  handle.addEventListener('mousedown', (e) => {
    startX = e.clientX;
    startWidth = methodList.offsetWidth;
    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
    e.preventDefault();
  });

  function onMouseMove(e) {
    const newWidth = startWidth + (e.clientX - startX);
    methodList.style.width = Math.max(120, Math.min(600, newWidth)) + 'px';
  }

  function onMouseUp() {
    document.removeEventListener('mousemove', onMouseMove);
    document.removeEventListener('mouseup', onMouseUp);
  }
}

function setupBottomResize() {
  const handle = document.getElementById('bottom-resize-handle');
  const pane = document.getElementById('bottom-pane');
  let startY, startHeight;

  handle.addEventListener('mousedown', (e) => {
    startY = e.clientY;
    startHeight = pane.offsetHeight;
    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
    e.preventDefault();
  });

  function onMouseMove(e) {
    const newHeight = startHeight - (e.clientY - startY);
    pane.style.height = Math.max(80, Math.min(500, newHeight)) + 'px';
  }

  function onMouseUp() {
    document.removeEventListener('mousemove', onMouseMove);
    document.removeEventListener('mouseup', onMouseUp);
  }
}

function isPositionInRange(file, line, col, range) {
  if (file !== range.file) return false;
  if (line < range.sl || line > range.el) return false;
  if (line === range.sl && col < range.sc) return false;
  if (line === range.el && col >= range.ec) return false;
  return true;
}

function showNodeRelationships(nodeRefs, annRange) {
  const handle = document.getElementById('bottom-resize-handle');
  const pane = document.getElementById('bottom-pane');
  const parentsCont = document.getElementById('parents-content');
  const childrenCont = document.getElementById('children-content');

  handle.classList.add('visible');
  pane.classList.add('visible');
  parentsCont.innerHTML = '';
  childrenCont.innerHTML = '';

  const parentMap = {};
  const childMap = {};

  for (const ref of nodeRefs) {
    const graph = DATA.graphs[ref.g];
    if (!graph) continue;
    for (const edge of graph.edges) {
      if (edge.target === ref.n) {
        const pNode = graph.nodes[edge.source];
        const key = pNode ? (pNode.label + ':' + pNode.file + ':' + pNode.sl) : (ref.g + ':' + edge.source);
        if (!parentMap[key]) {
          parentMap[key] = { g: ref.g, n: edge.source, callFile: edge.file, callLine: edge.sl, callCol: edge.sc || 0 };
        }
      }
      if (edge.source === ref.n) {
        const cNode = graph.nodes[edge.target];
        const key = cNode ? (cNode.label + ':' + cNode.file + ':' + cNode.sl) : (ref.g + ':' + edge.target);
        if (!childMap[key]) {
          childMap[key] = { g: ref.g, n: edge.target, callFile: edge.file, callLine: edge.sl, callCol: edge.sc || 0 };
        }
      }
    }
  }

  const parents = Object.values(parentMap);
  let children = Object.values(childMap);

  if (annRange) {
    children = children.filter(c =>
      c.callFile && c.callLine && isPositionInRange(c.callFile, c.callLine, c.callCol, annRange)
    );
  }

  if (parents.length === 0) {
    const el = document.createElement('div');
    el.className = 'pane-empty';
    el.textContent = 'No callers found';
    parentsCont.appendChild(el);
  } else {
    for (const p of parents) parentsCont.appendChild(createNodeBox(p));
  }

  if (children.length === 0) {
    const el = document.createElement('div');
    el.className = 'pane-empty';
    el.textContent = annRange ? 'No callees for this expression' : 'No callees found';
    childrenCont.appendChild(el);
  } else {
    for (const c of children) childrenCont.appendChild(createNodeBox(c));
  }
}

function abbreviatePath(filePath) {
  if (!filePath) return '';
  const parts = filePath.split('/');
  return parts.length > 2 ? parts.slice(-2).join('/') : filePath;
}

function navigateToLocation(file, line) {
  if (file && DATA.sourceFiles[file]) {
    showFile(file);
    setTimeout(() => {
      const table = document.querySelector('table.source-code');
      if (table && line > 0) {
        const tr = table.rows[line - 1];
        if (tr) {
          tr.scrollIntoView({ behavior: 'smooth', block: 'center' });
          highlightLine(tr);
        }
      }
    }, 50);
  }
}

function createNodeBox(info) {
  const graph = DATA.graphs[info.g];
  const node = graph ? graph.nodes[info.n] : null;
  const box = document.createElement('div');
  box.className = 'node-box';

  const funcEl = document.createElement('div');
  funcEl.className = 'nb-func';
  funcEl.textContent = node ? node.label : info.n;
  box.appendChild(funcEl);

  if (node && node.file) {
    const fileEl = document.createElement('div');
    fileEl.className = 'nb-file';
    fileEl.textContent = abbreviatePath(node.file) + ':' + node.sl;
    box.appendChild(fileEl);
  }

  if (info.callFile && info.callLine) {
    const csEl = document.createElement('div');
    csEl.className = 'nb-callsite';
    const sameFile = node && node.file && info.callFile === node.file;
    csEl.textContent = sameFile
      ? 'call at line ' + info.callLine
      : 'call at ' + abbreviatePath(info.callFile) + ':' + info.callLine;
    csEl.addEventListener('click', (e) => {
      e.stopPropagation();
      navigateToLocation(info.callFile, info.callLine);
    });
    box.appendChild(csEl);
  }

  if (node && node.returnRounding) {
    const retEl = document.createElement('div');
    retEl.className = 'nb-return';
    retEl.textContent = 'rounding: ' + node.returnRounding;
    box.appendChild(retEl);
  }

  box.addEventListener('click', () => {
    // Navigate to function definition
    const defFile = node && node.file;
    const defLine = node && node.sl;

    if (defFile && DATA.sourceFiles[defFile]) {
      navigateToLocation(defFile, defLine);
    }

    // Look up all nodes at this position and update bottom pane
    const allRefs = [];
    if (node && node.file && node.sl) {
      const key = node.file + ':' + node.sl;
      const posRefs = nodePositionIndex[key] || [];
      for (const r of posRefs) allRefs.push(r);
    }
    if (allRefs.length === 0) allRefs.push({g: info.g, n: info.n});
    showNodeRelationships(allRefs);
  });

  return box;
}

// ---- Graph View ----

let currentView = 'source';
let currentGraphIdx = -1;
let focusedNodeId = '0';
let graphChildrenOf = {};  // nodeId -> [childNodeId, ...]
let graphParentOf = {};    // nodeId -> parentNodeId

function switchView(view) {
  currentView = view;
  document.querySelectorAll('.view-btn').forEach(b => {
    b.classList.toggle('active', b.textContent.toLowerCase() === view);
  });

  const treePanel = document.getElementById('tree-panel');
  const methodList = document.getElementById('method-list');
  const sourcePanel = document.getElementById('source-panel');
  const graphPanel = document.getElementById('graph-panel');
  const resizeHandle = document.getElementById('resize-handle');
  const methodListResizeHandle = document.getElementById('method-list-resize-handle');
  const contextBar = document.getElementById('context-bar');
  const bottomHandle = document.getElementById('bottom-resize-handle');
  const bottomPane = document.getElementById('bottom-pane');

  if (view === 'source') {
    treePanel.style.display = 'block';
    methodList.style.display = 'none';
    methodListResizeHandle.style.display = 'none';
    sourcePanel.style.display = 'block';
    graphPanel.style.display = 'none';
    resizeHandle.style.display = 'block';
    if (Object.keys(DATA.contexts).length > 1) contextBar.style.display = 'flex';
  } else {
    treePanel.style.display = 'none';
    methodList.style.display = 'block';
    methodListResizeHandle.style.display = 'block';
    sourcePanel.style.display = 'none';
    graphPanel.style.display = 'flex';
    resizeHandle.style.display = 'none';
    contextBar.style.display = 'none';
    bottomHandle.classList.remove('visible');
    bottomPane.classList.remove('visible');
    if (methodList.children.length === 0) buildMethodList();
    if (currentGraphIdx < 0) {
      // Show the first graph that has roundings
      const firstItem = methodList.querySelector('.method-item');
      if (firstItem) showGraph(parseInt(firstItem.dataset.graphIdx));
    }
  }
}

function graphHasRoundings(graph) {
  // Check if any node has non-Neither roundings
  for (const nodeId in graph.nodes) {
    const node = graph.nodes[nodeId];
    if (node.roundings && node.roundings.length > 0) return true;
    if (node.returnRounding && node.returnRounding !== 'Neither') return true;
  }
  return false;
}

function buildMethodList() {
  const list = document.getElementById('method-list');
  list.innerHTML = '';

  // Build sorted index, filtering out graphs with no real roundings
  const indices = DATA.graphs.map((g, i) => i).filter(i => graphHasRoundings(DATA.graphs[i]));
  indices.sort((a, b) => (DATA.graphs[a].label || '').localeCompare(DATA.graphs[b].label || ''));

  for (const idx of indices) {
    const graph = DATA.graphs[idx];
    const item = document.createElement('div');
    item.className = 'method-item';
    item.dataset.graphIdx = idx;

    // Rounding badge (dot showing aggregated rounding color)
    const node0 = graph.nodes['0'];
    if (node0 && node0.returnRounding) {
      const dot = document.createElement('span');
      dot.className = 'method-badge';
      dot.style.background = ROUNDING_COLORS[node0.returnRounding] || '#d1d5db';
      dot.title = node0.returnRounding;
      item.appendChild(dot);
    }

    const name = document.createElement('span');
    name.className = 'method-name';
    name.textContent = graph.label || ('Graph ' + idx);
    item.appendChild(name);

    const count = document.createElement('span');
    count.className = 'method-count';
    count.textContent = Object.keys(graph.nodes).length;
    item.appendChild(count);

    item.addEventListener('click', () => showGraph(idx));
    list.appendChild(item);
  }
}

function showGraph(graphIdx, focusNode) {
  currentGraphIdx = graphIdx;

  // Update active state
  document.querySelectorAll('.method-item').forEach(el => {
    el.classList.toggle('active', parseInt(el.dataset.graphIdx) === graphIdx);
  });

  const graph = DATA.graphs[graphIdx];
  if (!graph) return;

  // Build adjacency maps
  graphChildrenOf = {};
  graphParentOf = {};
  for (const nodeId in graph.nodes) {
    graphChildrenOf[nodeId] = [];
  }
  for (const edge of graph.edges) {
    if (!graphChildrenOf[edge.source]) graphChildrenOf[edge.source] = [];
    graphChildrenOf[edge.source].push(edge.target);
    graphParentOf[edge.target] = edge.source;
  }

  // Set focus node (default to root '0')
  focusedNodeId = focusNode || '0';
  if (!graph.nodes[focusedNodeId]) focusedNodeId = '0';

  renderFocusedGraph(graphIdx);
}

function renderFocusedGraph(graphIdx) {
  const graph = DATA.graphs[graphIdx];
  if (!graph) return;

  // Compute visible nodes: parent of focused + focused + children of focused
  const visibleNodes = new Set();
  visibleNodes.add(focusedNodeId);
  const childIds = (graphChildrenOf[focusedNodeId] || []);
  for (const childId of childIds) {
    visibleNodes.add(childId);
  }
  const parentId = graphParentOf[focusedNodeId];
  if (parentId !== undefined) {
    visibleNodes.add(parentId);
  }

  // Sort children by call-site position
  const edgeSl = {};
  for (const edge of graph.edges) {
    if (edge.source === focusedNodeId) {
      edgeSl[edge.target] = { sl: edge.sl || 0, sc: edge.sc || 0 };
    }
  }
  const sortedChildren = [...childIds].sort((a, b) => {
    const ea = edgeSl[a] || { sl: 0, sc: 0 };
    const eb = edgeSl[b] || { sl: 0, sc: 0 };
    return ea.sl !== eb.sl ? ea.sl - eb.sl : ea.sc - eb.sc;
  });

  // Update breadcrumb
  updateBreadcrumb(graph, graphIdx);

  const container = document.getElementById('graph-container');
  const nodesEl = document.getElementById('graph-nodes');
  const edgesSvg = document.getElementById('graph-edges');
  nodesEl.innerHTML = '';
  const defs = edgesSvg.querySelector('defs');
  edgesSvg.innerHTML = '';
  edgesSvg.appendChild(defs);

  // Build call-site lookup
  const callSiteOf = {};
  for (const edge of graph.edges) {
    callSiteOf[edge.target] = { file: edge.file, sl: edge.sl, sc: edge.sc };
  }

  // Create node elements for visible nodes
  const nodeElements = {};
  for (const nodeId of visibleNodes) {
    const node = graph.nodes[nodeId];
    if (!node) continue;
    const callSite = callSiteOf[nodeId] || null;
    const hasChildren = (graphChildrenOf[nodeId] || []).length > 0;
    const el = createGraphNode(nodeId, node, callSite, nodeId === focusedNodeId, hasChildren);
    el.style.visibility = 'hidden';
    el.style.position = 'absolute';
    nodesEl.appendChild(el);
    nodeElements[nodeId] = el;
  }

  // Double-rAF to measure then position
  requestAnimationFrame(() => { requestAnimationFrame(() => {
    // Measure all nodes
    const sizes = {};
    for (const nodeId in nodeElements) {
      const el = nodeElements[nodeId];
      sizes[nodeId] = {
        w: Math.max(el.offsetWidth, 120),
        h: Math.max(el.offsetHeight, 40)
      };
    }

    // Custom diagonal layout
    const pad = 30;
    const gapX = 40;   // horizontal step per child
    const gapY = 16;   // vertical gap between children
    const positions = {};  // nodeId -> {x, y, w, h} (x,y = top-left corner)

    // Place parent (if any) at top-left
    let curY = pad;
    if (parentId !== undefined && sizes[parentId]) {
      positions[parentId] = { x: pad, y: curY, w: sizes[parentId].w, h: sizes[parentId].h };
      curY += sizes[parentId].h + 40;
    }

    // Place focused node
    if (sizes[focusedNodeId]) {
      positions[focusedNodeId] = { x: pad, y: curY, w: sizes[focusedNodeId].w, h: sizes[focusedNodeId].h };
      curY += sizes[focusedNodeId].h + 40;
    }

    // Place children in rows, wrapping left-to-right
    const maxRowWidth = Math.max(800, document.getElementById('graph-scroll').clientWidth - pad * 2);
    let childX = pad;
    let childY = curY;
    let rowMaxH = 0;
    for (const childId of sortedChildren) {
      if (!sizes[childId]) continue;
      // Wrap to next row if this child would exceed max width
      if (childX > pad && childX + sizes[childId].w > maxRowWidth + pad) {
        childX = pad;
        childY += rowMaxH + gapY;
        rowMaxH = 0;
      }
      positions[childId] = { x: childX, y: childY, w: sizes[childId].w, h: sizes[childId].h };
      childX += sizes[childId].w + gapX;
      rowMaxH = Math.max(rowMaxH, sizes[childId].h);
    }

    // Position all nodes and compute bounds
    let maxX = 0, maxY = 0;
    for (const nodeId in positions) {
      const pos = positions[nodeId];
      const el = nodeElements[nodeId];
      if (!el) continue;
      el.style.left = pos.x + 'px';
      el.style.top = pos.y + 'px';
      el.style.visibility = '';
      maxX = Math.max(maxX, pos.x + pos.w);
      maxY = Math.max(maxY, pos.y + pos.h);
    }

    container.style.width = (maxX + pad) + 'px';
    container.style.height = (maxY + pad) + 'px';
    edgesSvg.setAttribute('width', maxX + pad);
    edgesSvg.setAttribute('height', maxY + pad);

    // Draw edges as smooth curves
    function drawEdge(srcId, tgtId) {
      const src = positions[srcId];
      const tgt = positions[tgtId];
      if (!src || !tgt) return;
      // Start from bottom-center of source, end at top-center of target
      const x1 = src.x + src.w / 2;
      const y1 = src.y + src.h;
      const x2 = tgt.x + tgt.w / 2;
      const y2 = tgt.y;
      // Control point for a smooth curve
      const cy1 = y1 + (y2 - y1) * 0.4;
      const cy2 = y1 + (y2 - y1) * 0.6;
      const d = 'M ' + x1 + ' ' + y1 + ' C ' + x1 + ' ' + cy1 + ' ' + x2 + ' ' + cy2 + ' ' + x2 + ' ' + y2;

      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', d);
      path.setAttribute('class', 'graph-edge');
      path.setAttribute('marker-end', 'url(#arrowhead)');
      edgesSvg.appendChild(path);
    }

    // Edge from parent to focused
    if (parentId !== undefined) {
      drawEdge(parentId, focusedNodeId);
    }
    // Edges from focused to each child
    for (const childId of sortedChildren) {
      drawEdge(focusedNodeId, childId);
    }

    // Scroll to top
    const graphScroll = document.getElementById('graph-scroll');
    graphScroll.scrollLeft = 0;
    graphScroll.scrollTop = 0;
  }); });
}

function updateBreadcrumb(graph, graphIdx) {
  const bc = document.getElementById('graph-breadcrumb');
  bc.innerHTML = '';

  // Build path from root to focused node
  const path = [];
  let cur = focusedNodeId;
  while (cur !== undefined) {
    path.unshift(cur);
    cur = graphParentOf[cur];
  }

  if (path.length <= 1) {
    // At root, hide breadcrumb
    bc.style.display = 'none';
    return;
  }

  bc.style.display = 'flex';
  for (let i = 0; i < path.length; i++) {
    const nodeId = path[i];
    const node = graph.nodes[nodeId];
    const label = node ? (node.label || nodeId) : nodeId;

    if (i > 0) {
      const sep = document.createElement('span');
      sep.className = 'bc-sep';
      sep.textContent = ' \u203a ';
      bc.appendChild(sep);
    }

    if (i === path.length - 1) {
      // Current node (not clickable)
      const span = document.createElement('span');
      span.className = 'bc-current';
      span.textContent = label;
      bc.appendChild(span);
    } else {
      const link = document.createElement('span');
      link.className = 'bc-item';
      link.textContent = label;
      link.addEventListener('click', ((nid) => () => {
        focusedNodeId = nid;
        renderFocusedGraph(graphIdx);
      })(nodeId));
      bc.appendChild(link);
    }
  }
}

function createGraphNode(nodeId, node, callSite, isFocused, hasChildren) {
  const el = document.createElement('div');
  el.className = 'graph-node' + (isFocused ? ' focused' : ' compact');

  // Header
  const header = document.createElement('div');
  header.className = 'graph-node-header';
  if (node.returnRounding) {
    const dot = document.createElement('span');
    dot.className = 'node-rounding-dot';
    dot.style.background = ROUNDING_COLORS[node.returnRounding] || '#d1d5db';
    dot.title = 'Return: ' + node.returnRounding;
    header.appendChild(dot);
  }
  const labelSpan = document.createElement('span');
  labelSpan.textContent = node.label || nodeId;
  header.appendChild(labelSpan);

  // "Go to source" link in header
  if (node.file && DATA.sourceFiles[node.file]) {
    const srcLink = document.createElement('span');
    srcLink.className = 'go-to-source';
    srcLink.textContent = 'source \u2192';
    srcLink.title = 'Go to source view';
    srcLink.addEventListener('click', (e) => {
      e.stopPropagation();
      switchView('source');
      setTimeout(() => {
        showFile(node.file);
        setTimeout(() => {
          const table = document.querySelector('table.source-code');
          if (table && table.rows[node.sl - 1]) {
            table.rows[node.sl - 1].scrollIntoView({ behavior: 'smooth', block: 'center' });
            highlightLine(table.rows[node.sl - 1]);
          }
        }, 50);
      }, 50);
    });
    header.appendChild(srcLink);
  }
  el.appendChild(header);

  // File info + call site
  if (node.file) {
    const fileEl = document.createElement('div');
    fileEl.className = 'graph-node-file';
    let fileText = abbreviatePath(node.file) + ':' + node.sl + '-' + node.el;
    if (callSite && callSite.file) {
      fileText += '  \u2190 called at ' + abbreviatePath(callSite.file) + ':' + callSite.sl;
    }
    fileEl.textContent = fileText;
    el.appendChild(fileEl);
  }

  // Source with annotations
  const sourceEl = document.createElement('div');
  sourceEl.className = 'graph-node-source';
  sourceEl.innerHTML = renderNodeSource(node);
  el.appendChild(sourceEl);

  // Click to refocus graph on this node
  el.addEventListener('click', () => {
    if (nodeId !== focusedNodeId) {
      focusedNodeId = nodeId;
      renderFocusedGraph(currentGraphIdx);
    }
  });

  return el;
}

function renderNodeSource(node) {
  if (!node.file || !DATA.sourceFiles[node.file]) return '<span style="color:#94a3b8">Source not available</span>';

  const raw = DATA.sourceFiles[node.file].raw;
  const lines = raw.split('\n');
  const startLine = Math.max(1, node.sl);
  const endLine = Math.min(lines.length, node.el);

  const roundings = (node.roundings || []).filter(r => r.rounding !== 'Neither');

  const gutterWidth = String(endLine).length;
  let html = '';
  for (let lineNum = startLine; lineNum <= endLine; lineNum++) {
    const lineText = lines[lineNum - 1] || '';
    const numStr = String(lineNum).padStart(gutterWidth);
    html += '<span style="color:#adb5bd;user-select:none">' + numStr + ' </span>';
    // Find annotations on this line
    const lineAnns = [];
    for (const r of roundings) {
      if (r.sl > lineNum || r.el < lineNum) continue;
      const sc = (r.sl === lineNum) ? r.sc : 0;
      const ec = (r.el === lineNum) ? r.ec : lineText.length;
      lineAnns.push({ sc: sc, ec: ec, rounding: r.rounding, size: (r.el - r.sl) * 10000 + (r.ec - r.sc) });
    }

    if (lineAnns.length === 0) {
      html += escapeHtml(lineText) + '\n';
    } else {
      // Build char-to-annotation map (smallest wins)
      const sorted = [...lineAnns].sort((a, b) => a.size - b.size);
      const charAnn = new Array(lineText.length).fill(null);
      const byLargest = [...sorted].reverse();
      for (const ann of byLargest) {
        for (let i = ann.sc; i < Math.min(ann.ec, lineText.length); i++) {
          charAnn[i] = ann;
        }
      }

      // Build segments
      let pos = 0;
      while (pos < lineText.length) {
        const ann = charAnn[pos];
        let end = pos + 1;
        while (end < lineText.length && charAnn[end] === ann) end++;
        const text = escapeHtml(lineText.substring(pos, end));
        if (ann) {
          html += '<span class="' + roundingClass(ann.rounding) + '">' + text + '</span>';
        } else {
          html += text;
        }
        pos = end;
      }
      html += '\n';
    }
  }

  return html;
}

init();
</script>
</body>
</html>
"""


def run_roundabout_pipeline(project_root, input_file, output_json, certora_run_command="certoraRun"):
    """Run roundabout.py on a .conf or .sol file, writing results to output_json."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    roundabout_py = os.path.join(script_dir, "..", "roundabout.py")

    log_dir = os.path.join(project_root, ".certora_internal")
    os.makedirs(log_dir, exist_ok=True)
    log_file = os.path.join(log_dir, "roundabout.log")

    cmd = [sys.executable, roundabout_py]
    if certora_run_command != "certoraRun":
        cmd.extend(["--certora-run-command", certora_run_command])
    cmd.extend([project_root, input_file, output_json])
    print(f"Running RoundAbout pipeline on {input_file}...")
    with open(log_file, "a") as log:
        result = subprocess.run(cmd, stdout=log, stderr=log)
    if result.returncode != 0:
        print(f"Error: RoundAbout pipeline failed. See {log_file} for details.", file=sys.stderr)
        sys.exit(result.returncode)


def generate_html_from_json_data(data, project_root, html_output, conf_file=None, full_context_breakdown=False):
    """Generate HTML viewer from pre-loaded roundabout JSON data.

    This is the core generation logic, usable both from main() and as a library function.

    Args:
        data: Parsed roundabout JSON (dict with "graphs" key).
        project_root: Absolute path to the project root directory.
        html_output: Path for the output HTML file.
        conf_file: Optional .conf file path for contract name extraction.
        full_context_breakdown: If True, show per-graph contexts; otherwise root-only mode.
    """
    # Extract graphs (needed for both modes — caller-callee navigation)
    graphs = extract_graphs(data, project_root)

    if full_context_breakdown:
        # Full context breakdown: aggregate across all nodes, build per-graph contexts
        aggregated = extract_roundings(data, project_root)

        all_files = set(aggregated.keys())
        for g in graphs:
            for node in g["nodes"].values():
                if node["file"]:
                    all_files.add(node["file"])

        source_files = collect_referenced_files_from_paths(all_files, project_root)

        return_annotations = extract_return_annotations(data, project_root, source_files)
        per_graph_roundings = extract_per_graph_roundings(data, project_root)
        per_graph_returns = extract_per_graph_return_annotations(data, project_root, source_files)

        # Build multi-context dict
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

        # Filter out per-graph contexts where all findings are Neither
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

        total_annotations = sum(len(v) for v in aggregated.values())
        total_return = sum(len(v) for v in return_annotations.values())
    else:
        # Default mode: only use node "0" (root function) from each graph
        aggregated = extract_roundings_root_only(data, project_root)

        all_files = set(aggregated.keys())
        for g in graphs:
            for node in g["nodes"].values():
                if node["file"]:
                    all_files.add(node["file"])

        source_files = collect_referenced_files_from_paths(all_files, project_root)

        return_annotations = extract_return_annotations_root_only(data, project_root, source_files)

        # Single context — no per-graph breakdown
        contexts = {"contextFree": {}}
        for filename, anns in aggregated.items():
            contexts["contextFree"][filename] = list(anns)
        for filename, ret_anns in return_annotations.items():
            contexts["contextFree"].setdefault(filename, []).extend(ret_anns)

        total_annotations = sum(len(v) for v in aggregated.values())
        total_return = sum(len(v) for v in return_annotations.values())

    # Build directory tree
    dir_tree = build_directory_tree(sorted(source_files.keys()))

    # Generate HTML
    if conf_file:
        conf_path = conf_file if os.path.isabs(conf_file) else os.path.join(project_root, conf_file)
        contracts = extract_contracts_from_conf(conf_path)
    else:
        contracts = None
    html_content = generate_html(project_root, source_files, dir_tree, contexts, graphs, contracts)

    # Write output
    os.makedirs(os.path.dirname(os.path.abspath(html_output)), exist_ok=True)
    with open(html_output, "w") as f:
        f.write(html_content)

    mode = "full context breakdown" if full_context_breakdown else "default (root-only)"
    print(f"Generated ({mode}): {html_output}")
    print(f"  {len(source_files)} source files")
    print(f"  {total_annotations} rounding annotations")
    print(f"  {total_return} return annotations")


def main():
    (project_root, input_file, html_output, conf_file,
     full_context_breakdown, certora_run_command, json_input) = parse_args()
    project_root = os.path.abspath(project_root)

    if json_input:
        # JSON-input mode: load pre-generated roundabout JSON directly
        with open(json_input, "r") as f:
            data = json.load(f)
        if conf_file is None and input_file and input_file.endswith(".conf"):
            conf_file = input_file
        generate_html_from_json_data(data, project_root, html_output, conf_file, full_context_breakdown)
    else:
        # Standard mode: run roundabout pipeline then generate HTML
        if input_file is None:
            print("Error: --input-file is required unless --json-input is provided.", file=sys.stderr)
            sys.exit(1)
        if not (input_file.endswith(".conf") or input_file.endswith(".sol")):
            print("Error: Input file must be a .conf or .sol file.", file=sys.stderr)
            sys.exit(1)

        if conf_file is None and input_file.endswith(".conf"):
            conf_file = input_file

        with tempfile.TemporaryDirectory(prefix="roundabout_") as tmpdir:
            temp_json = os.path.join(tmpdir, "output.json")
            run_roundabout_pipeline(project_root, input_file, temp_json, certora_run_command)

            with open(temp_json, "r") as f:
                data = json.load(f)

            generate_html_from_json_data(data, project_root, html_output, conf_file, full_context_breakdown)


if __name__ == "__main__":
    main()
