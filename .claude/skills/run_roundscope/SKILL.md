---
name: run-roundscope
description: Run RoundScope analysis and generate an HTML viewer for a Certora conf file
---

# Run RoundScope

Runs the RoundScope rounding-analysis pipeline and generates an interactive HTML viewer.

## When to Use

- User wants to run RoundScope on a project
- User wants to analyze rounding behavior
- User wants to generate a RoundScope viewer
- Keywords: run roundscope, analyze rounding, generate viewer

## Command

`bash .claude/skills/run_roundscope/run_roundscope.sh <conf-file>`

### Arguments

- `conf-file` — path to a `.conf` file (relative to the project root or absolute)

## Usage Examples

```bash
# Run on a conf file in the current project
bash .claude/skills/run_roundscope/run_roundscope.sh certora/conf/MyConf.conf
```

## What It Does

1. Uses the current working directory as the project root
2. Runs `roundscope.sh` to perform the Java-based rounding analysis
3. Runs `generate_viewer.py` to produce a self-contained HTML viewer
4. Prints the path to the generated HTML file

## Output

Output files are placed next to the conf file, derived from its name:
- `<name>_roundscope.json` — raw analysis results
- `<name>_roundscope.html` — interactive HTML viewer
