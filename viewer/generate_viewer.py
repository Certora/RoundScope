#!/usr/bin/env python3
"""Generate a self-contained HTML viewer for RoundScope JSON output."""

import json
import os
import sys
from collections import defaultdict


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
    1. Normalize Inconsistent -> Either
    2. Filter out Neither
    3. If no significant values -> Neither
    4. If all same -> that value
    5. Otherwise -> Either
    """
    normalized = []
    for v in values:
        if v == "Inconsistent":
            normalized.append("Either")
        else:
            normalized.append(v)

    significant = [v for v in normalized if v != "Neither"]
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
    # Collect all rounding entries: (filename, range_key) -> list of {rounding, source, expr}
    raw = defaultdict(list)

    for graph in data["graphs"]:
        for node in graph["nodes"].values():
            md = node["metadata"]
            method_pos = md.get("methodPosition", "")
            if not method_pos:
                continue
            filename = extract_filename_from_method_position(method_pos)

            for range_key, info in md.get("roundings", {}).items():
                raw[(filename, range_key)].append(info)

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
            }
        )

    return dict(aggregated)


def normalize_path(filepath, project_root):
    """Make a path relative to project_root."""
    if os.path.isabs(filepath):
        try:
            return os.path.relpath(filepath, project_root)
        except ValueError:
            return filepath
    return filepath


def collect_referenced_files(aggregated, project_root):
    """Read source files referenced in the annotations."""
    source_files = {}
    for rel_path in aggregated:
        abs_path = os.path.join(project_root, rel_path)
        try:
            with open(abs_path, "r") as f:
                source_files[rel_path] = f.read()
        except FileNotFoundError:
            print(f"Warning: source file not found: {abs_path}", file=sys.stderr)
            source_files[rel_path] = f"// File not found: {abs_path}"
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


def generate_html(project_root, source_files, directory_tree, contexts):
    """Generate the self-contained HTML string."""
    data_json = json.dumps(
        {
            "projectRoot": project_root,
            "sourceFiles": source_files,
            "directoryTree": directory_tree,
            "contexts": contexts,
        }
    )

    return (
        HTML_TEMPLATE_START
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
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { height: 100%; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
body { display: flex; flex-direction: column; background: #1e1e2e; color: #cdd6f4; }

#top-bar {
  background: #181825; border-bottom: 1px solid #313244;
  padding: 8px 16px; font-size: 13px; color: #a6adc8;
  display: flex; align-items: center; gap: 16px; flex-shrink: 0;
}
#top-bar .project-root { font-family: 'SF Mono', 'Fira Code', monospace; color: #cdd6f4; }

#context-bar {
  background: #181825; border-bottom: 1px solid #313244;
  padding: 6px 16px; display: flex; gap: 8px; flex-shrink: 0;
}
.ctx-btn {
  padding: 4px 12px; border: 1px solid #45475a; border-radius: 4px;
  background: transparent; color: #a6adc8; cursor: pointer; font-size: 12px;
}
.ctx-btn.active { background: #45475a; color: #cdd6f4; border-color: #585b70; }

#main { display: flex; flex: 1; overflow: hidden; }

#tree-panel {
  width: 260px; min-width: 180px; background: #181825;
  border-right: 1px solid #313244; overflow-y: auto; padding: 8px 0;
  flex-shrink: 0; font-size: 13px;
}

.tree-dir, .tree-file {
  padding: 3px 8px; cursor: pointer; white-space: nowrap;
  overflow: hidden; text-overflow: ellipsis;
}
.tree-dir { color: #89b4fa; font-weight: 500; }
.tree-dir:hover { background: #313244; }
.tree-file { color: #cdd6f4; padding-left: 4px; }
.tree-file:hover { background: #313244; }
.tree-file.active { background: #45475a; color: #f5e0dc; }
.tree-children { padding-left: 14px; }
.tree-toggle { display: inline-block; width: 14px; text-align: center; color: #6c7086; font-size: 11px; }

#source-panel { flex: 1; overflow: auto; background: #1e1e2e; }

#source-header {
  position: sticky; top: 0; z-index: 10; background: #181825;
  border-bottom: 1px solid #313244; padding: 8px 16px;
  font-family: 'SF Mono', 'Fira Code', monospace; font-size: 13px; color: #a6adc8;
}
#source-placeholder {
  display: flex; align-items: center; justify-content: center;
  height: 100%; color: #6c7086; font-size: 14px;
}

table.source-code {
  border-collapse: collapse; width: 100%;
  font-family: 'SF Mono', 'Fira Code', monospace; font-size: 13px; line-height: 1.5;
}
table.source-code td { padding: 0 12px; vertical-align: top; white-space: pre; }
td.line-num {
  text-align: right; color: #6c7086; user-select: none;
  width: 1%; min-width: 48px; border-right: 1px solid #313244;
  padding-right: 8px;
}
td.line-content { padding-left: 12px; }

/* Rounding underline classes */
.r-up { text-decoration: underline; text-decoration-color: #2563eb; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-down { text-decoration: underline; text-decoration-color: #ea580c; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-either { text-decoration: underline; text-decoration-color: #dc2626; text-underline-offset: 3px; text-decoration-thickness: 2px; }
.r-neither { text-decoration: underline; text-decoration-color: #d1d5db; text-underline-offset: 3px; text-decoration-thickness: 2px; }

/* Tooltip */
.r-up, .r-down, .r-either, .r-neither { position: relative; cursor: default; }
.annotation-span:hover .tooltip, .annotation-span:focus .tooltip { display: block; }
.tooltip {
  display: none; position: fixed; z-index: 1000;
  background: #313244; border: 1px solid #45475a; border-radius: 6px;
  padding: 8px 12px; font-size: 12px; line-height: 1.5;
  color: #cdd6f4; white-space: pre-wrap; max-width: 500px;
  pointer-events: none; box-shadow: 0 4px 12px rgba(0,0,0,0.4);
}
.tooltip .tt-label { color: #a6adc8; }
.tooltip .tt-rounding-up { color: #2563eb; font-weight: 600; }
.tooltip .tt-rounding-down { color: #ea580c; font-weight: 600; }
.tooltip .tt-rounding-either { color: #dc2626; font-weight: 600; }
.tooltip .tt-rounding-neither { color: #d1d5db; font-weight: 600; }

/* Legend */
#legend {
  display: flex; gap: 16px; align-items: center; margin-left: auto; font-size: 12px;
}
.legend-item { display: flex; align-items: center; gap: 4px; }
.legend-swatch {
  width: 20px; height: 3px; border-radius: 1px;
}

/* Resize handle */
#resize-handle {
  width: 4px; cursor: col-resize; background: transparent; flex-shrink: 0;
}
#resize-handle:hover { background: #45475a; }
</style>
</head>
<body>

<div id="top-bar">
  <span style="font-weight:600;">RoundScope</span>
  <span class="project-root" id="project-root-display"></span>
  <div id="legend">
    <div class="legend-item"><div class="legend-swatch" style="background:#2563eb"></div> Up</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#ea580c"></div> Down</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#dc2626"></div> Either</div>
    <div class="legend-item"><div class="legend-swatch" style="background:#d1d5db"></div> Neither</div>
  </div>
</div>

<div id="context-bar">
  <button class="ctx-btn active" onclick="switchContext('contextFree')">Context-Free</button>
</div>

<div id="main">
  <div id="tree-panel"></div>
  <div id="resize-handle"></div>
  <div id="source-panel">
    <div id="source-placeholder">Select a file from the tree to view source</div>
  </div>
</div>

<script>
"""

HTML_TEMPLATE_END = r"""
let currentFile = null;
let currentContext = 'contextFree';

function init() {
  document.getElementById('project-root-display').textContent = DATA.projectRoot;
  renderTree(DATA.directoryTree, document.getElementById('tree-panel'), '');
  setupResize();
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
  header.textContent = filePath;
  panel.appendChild(header);

  const source = DATA.sourceFiles[filePath];
  if (!source && source !== '') {
    const msg = document.createElement('div');
    msg.id = 'source-placeholder';
    msg.textContent = 'Source not available for ' + filePath;
    panel.appendChild(msg);
    return;
  }

  const annotations = (DATA.contexts[currentContext] || {})[filePath] || [];
  const table = renderSource(source, annotations);
  panel.appendChild(table);
}

function renderSource(source, annotations) {
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
      tdContent.textContent = lineText || ' ';
    } else {
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
    btn.classList.toggle('active', btn.textContent.includes(name === 'contextFree' ? 'Context-Free' : name));
  });
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

    # Read source files
    source_files = collect_referenced_files(aggregated, project_root)

    # Build directory tree
    dir_tree = build_directory_tree(sorted(source_files.keys()))

    # Build contexts dict
    contexts = {"contextFree": {}}
    for filename, annotations in aggregated.items():
        contexts["contextFree"][filename] = annotations

    # Generate HTML
    html = generate_html(project_root, source_files, dir_tree, contexts)

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
