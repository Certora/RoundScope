#!/usr/bin/env python3
"""Generate a self-contained HTML viewer for RoundScope JSON output."""

import json
import os
import sys
from collections import defaultdict

from pygments import highlight as pygments_highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_for_filename
from pygments.lexers.solidity import SolidityLexer


def parse_args():
    if len(sys.argv) != 4:
        print(
            "Usage: python3 generate_viewer.py <project-root> <roundscope-output.json> <output.html>",
            file=sys.stderr,
        )
        sys.exit(1)
    return sys.argv[1], sys.argv[2], sys.argv[3]


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

            # Determine return rounding (from the node's own roundings)
            return_rounding = ""
            roundings = md.get("roundings", {})
            if roundings:
                values = [r.get("rounding", "Neither") for r in roundings.values()]
                agg = aggregate_rounding(values)
                if agg != "Neither":
                    return_rounding = agg

            nodes[node_id] = {
                "label": label,
                "file": file_path,
                "sl": sl,
                "sc": sc,
                "el": el,
                "ec": ec,
                "returnRounding": return_rounding,
            }

        for edge in graph.get("edges", []):
            source = edge.get("source", "")
            target = edge.get("target", "")
            edge_label = edge.get("label", "")

            # Parse call-site info from edge label (e.g., "file.sol:42")
            call_file = ""
            call_sl = 0
            if edge_label:
                # Edge labels may contain file:line info
                parts = edge_label.rsplit(":", 1)
                if len(parts) == 2:
                    try:
                        call_sl = int(parts[1])
                        call_file = normalize_path(parts[0], project_root)
                    except ValueError:
                        pass

            edges.append({
                "source": source,
                "target": target,
                "file": call_file,
                "sl": call_sl,
            })

        graphs.append({"nodes": nodes, "edges": edges})

    return graphs


def normalize_path(filepath, project_root):
    """Make a path relative to project_root."""
    if os.path.isabs(filepath):
        try:
            return os.path.relpath(filepath, project_root)
        except ValueError:
            return filepath
    return filepath


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


def generate_html(project_root, source_files, directory_tree, contexts, graphs):
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

    return (
        HTML_TEMPLATE_START
        + "\n/* Pygments syntax highlighting */\n"
        + pygments_css
        + "\n"
        + HTML_TEMPLATE_SCRIPT_START
        + "\nconst DATA = "
        + data_json
        + ";\n"
        + HTML_TEMPLATE_END
    )


HTML_TEMPLATE_START = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>RoundScope Viewer</title>
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
  padding: 6px 16px; display: flex; gap: 8px; flex-shrink: 0;
}
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
.r-inconsistent { text-decoration: underline; text-decoration-color: #ea580c; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-either { text-decoration: underline; text-decoration-color: #dc2626; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-neither { text-decoration: underline; text-decoration-color: #d1d5db; text-underline-offset: 3px; text-decoration-thickness: 2px; }

/* Tooltip */
.r-up, .r-down, .r-inconsistent, .r-either, .r-neither { position: relative; cursor: default; }
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
.tooltip .tt-rounding-inconsistent { color: #ea580c; font-weight: 600; }
.tooltip .tt-rounding-either { color: #dc2626; font-weight: 600; }
.tooltip .tt-rounding-neither { color: #d1d5db; font-weight: 600; }

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
.nb-callsite { font-size: 11px; color: #7c3aed; margin-top: 2px; }
.nb-return { font-size: 11px; color: #94a3b8; margin-top: 2px; }
.pane-empty { color: #94a3b8; font-size: 12px; padding: 12px; }
.annotation-span { cursor: pointer; }
"""

HTML_TEMPLATE_SCRIPT_START = r"""
</style>
</head>
<body>

<div id="top-bar">
  <span style="font-weight:600;">RoundScope</span>
  <span class="project-root" id="project-root-display"></span>
  <div id="legend">
    <div class="legend-item"><div class="legend-swatch" style="background:#2563eb"></div> Up</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#4ade80"></div> Down</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#ea580c"></div> Inconsistent</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#dc2626"></div> Either</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#d1d5db"></div> Neither</div>
  </div>
</div>

<div id="context-bar">
  <button class="ctx-btn active" data-context="contextFree" onclick="switchContext('contextFree')">Context-Free</button>
</div>

<div id="main">
  <div id="tree-panel"></div>
  <div id="resize-handle"></div>
  <div id="source-panel">
    <div id="source-placeholder">Select a file from the tree to view source</div>
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
let currentFile = null;
let currentContext = 'contextFree';
let currentFindings = [];
let currentFindingIdx = -1;
let nodePositionIndex = {};

function init() {
  document.getElementById('project-root-display').textContent = DATA.projectRoot;
  renderTree(DATA.directoryTree, document.getElementById('tree-panel'), '');
  setupResize();
  setupBottomResize();
  updateContextCounts();
  updateTreeHighlights();
  buildNodePositionIndex();
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
    const count = annotations.length;
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
    for (const file in ctx) total += ctx[file].length;
    const label = ctxName === 'contextFree' ? 'Context-Free' : ctxName;
    btn.textContent = label + ' (' + total + ')';
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
  const findingLines = [...new Set(annotations.map(a => a.sl))].sort((a, b) => a - b);
  currentFindings = findingLines;
  currentFindingIdx = -1;

  const nav = document.createElement('span');
  nav.id = 'source-nav';
  const upBtn = document.createElement('button');
  upBtn.textContent = '\u25B2';
  upBtn.disabled = true;
  upBtn.addEventListener('click', () => navigateToFinding(-1));
  const counter = document.createElement('span');
  counter.className = 'nav-counter';
  counter.textContent = findingLines.length > 0 ? '0/' + findingLines.length : '0/0';
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

function navigateToFinding(direction) {
  if (currentFindings.length === 0) return;
  let idx = currentFindingIdx + direction;
  if (idx < 0) idx = 0;
  if (idx >= currentFindings.length) idx = currentFindings.length - 1;
  currentFindingIdx = idx;

  const nav = document.getElementById('source-nav');
  if (nav) {
    nav.querySelector('.nav-counter').textContent = (idx + 1) + '/' + currentFindings.length;
    const btns = nav.querySelectorAll('button');
    btns[0].disabled = idx === 0;
    btns[1].disabled = idx === currentFindings.length - 1;
  }

  const lineNum = currentFindings[idx];
  const table = document.querySelector('table.source-code');
  if (table) {
    const tr = table.rows[lineNum - 1];
    if (tr) {
      tr.scrollIntoView({ behavior: 'smooth', block: 'center' });
      tr.style.transition = 'background 0.15s';
      tr.style.background = '#fef9c3';
      setTimeout(() => { tr.style.background = ''; }, 800);
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
    // Compute character range on this line (1-based columns)
    let startCol = (a.sl === lineNum) ? a.sc : 1;
    let endCol = (a.el === lineNum) ? a.ec : lineLen + 1;
    result.push({
      startCol, endCol,
      rounding: a.rounding,
      source: a.source || '',
      expr: a.expr || '',
      nodeRefs: a.nodeRefs || [],
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
    const start = ann.startCol - 1; // convert 1-based to 0-based
    const end = Math.min(ann.endCol - 1, lineText.length); // endCol is exclusive
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
        if (ann.nodeRefs && ann.nodeRefs.length > 0) {
          showNodeRelationships(ann.nodeRefs);
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
    default: return '';
  }
}

function buildTooltipHTML(ann) {
  const rcls = 'tt-rounding-' + ann.rounding.toLowerCase();
  let html = '<span class="tt-label">Rounding:</span> <span class="' + rcls + '">' + escapeHtml(ann.rounding) + '</span>';
  if (ann.source) {
    html += '\n<span class="tt-label">Expression:</span> ' + escapeHtml(ann.source);
  }
  if (ann.expr) {
    html += '\n<span class="tt-label">In:</span> ' + escapeHtml(ann.expr);
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

function showNodeRelationships(nodeRefs) {
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
        const key = ref.g + ':' + edge.source;
        if (!parentMap[key]) {
          parentMap[key] = { g: ref.g, n: edge.source, callFile: edge.file, callLine: edge.sl };
        }
      }
      if (edge.source === ref.n) {
        const key = ref.g + ':' + edge.target;
        if (!childMap[key]) {
          childMap[key] = { g: ref.g, n: edge.target, callFile: edge.file, callLine: edge.sl };
        }
      }
    }
  }

  const parents = Object.values(parentMap);
  const children = Object.values(childMap);

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
    el.textContent = 'No callees found';
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
    csEl.textContent = 'call at line ' + info.callLine;
    box.appendChild(csEl);
  }

  if (node && node.returnRounding) {
    const retEl = document.createElement('div');
    retEl.className = 'nb-return';
    retEl.textContent = 'rounding: ' + node.returnRounding;
    box.appendChild(retEl);
  }

  box.addEventListener('click', () => {
    if (node && node.file && DATA.sourceFiles[node.file]) {
      showFile(node.file);
      setTimeout(() => {
        const table = document.querySelector('table.source-code');
        if (table && node.sl > 0) {
          const tr = table.rows[node.sl - 1];
          if (tr) {
            tr.scrollIntoView({ behavior: 'smooth', block: 'center' });
            tr.style.transition = 'background 0.15s';
            tr.style.background = '#fef9c3';
            setTimeout(() => { tr.style.background = ''; }, 800);
          }
        }
      }, 50);
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

init();
</script>
</body>
</html>
"""


def main():
    project_root, json_input, html_output = parse_args()
    project_root = os.path.abspath(project_root)

    # Load JSON
    with open(json_input, "r") as f:
        data = json.load(f)

    # Extract and aggregate roundings
    aggregated = extract_roundings(data, project_root)

    # Extract graphs
    graphs = extract_graphs(data, project_root)

    # Collect all referenced file paths (annotations + graph nodes)
    all_files = set(aggregated.keys())
    for g in graphs:
        for node in g["nodes"].values():
            if node["file"]:
                all_files.add(node["file"])

    # Read source files
    source_files = collect_referenced_files_from_paths(all_files, project_root)

    # Build directory tree
    dir_tree = build_directory_tree(sorted(source_files.keys()))

    # Build contexts dict
    contexts = {"contextFree": {}}
    for filename, annotations in aggregated.items():
        contexts["contextFree"][filename] = annotations

    # Generate HTML
    html = generate_html(project_root, source_files, dir_tree, contexts, graphs)

    # Write output
    os.makedirs(os.path.dirname(os.path.abspath(html_output)), exist_ok=True)
    with open(html_output, "w") as f:
        f.write(html)

    print(f"Generated: {html_output}")
    print(f"  {len(source_files)} source files")
    total_annotations = sum(len(v) for v in aggregated.values())
    print(f"  {total_annotations} rounding annotations")


if __name__ == "__main__":
    main()
