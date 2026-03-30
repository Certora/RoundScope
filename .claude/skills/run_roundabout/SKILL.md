---
name: run-roundabout
description: Run RoundAbout analysis and generate an HTML viewer for a Certora conf file
---

# Run RoundAbout

Runs the RoundAbout rounding-analysis pipeline and generates an interactive HTML viewer.

## When to Use

- User wants to run RoundAbout on a project
- User wants to analyze rounding behavior
- User wants to generate a RoundAbout viewer
- Keywords: run roundabout, analyze rounding, generate viewer

## Command

`bash .claude/skills/run_roundabout/run_roundabout.sh <conf-file>`

### Arguments

- `conf-file` — path to a `.conf` file (relative to the project root or absolute)

## Usage Examples

```bash
# Run on a conf file in the current project
bash .claude/skills/run_roundabout/run_roundabout.sh certora/conf/MyConf.conf
```

## What It Does

1. Uses the current working directory as the project root
2. Runs `certoraRun` with `--dump_asts --compilation_steps_only` to produce AST JSON
3. Runs the RoundAbout Java analysis on the dumped ASTs
4. Runs `generate_viewer.py` to produce a self-contained HTML viewer
5. Prints the path to the generated HTML file

## Output

Output files are placed next to the conf file, derived from its name:
- `<name>_roundabout.json` — raw analysis results
- `<name>_roundabout.html` — interactive HTML viewer
