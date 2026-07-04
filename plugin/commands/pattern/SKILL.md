---
name: pattern
description: Learn how THIS codebase implements a specific pattern — find the 2-3 best example files, extract conventions, and produce an implementation guide, cached to .sourceatlas/patterns/. Use when the user asks "how do I implement X here", "how does this project do X", "show me examples of X", "where is X implemented", or needs to follow existing code conventions before writing new code.
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "[pattern, e.g. 'api endpoint', 'background job'] [--force] [--brief|--full]"
---

# SourceAtlas: Pattern

**Arguments**: $ARGUMENTS

Learn how this specific codebase implements the requested pattern. Extract reusable conventions from real code — not generic internet advice. Every claim needs a real `file:line` reference.

## 1. Cache check (do this first)

Cache path: `.sourceatlas/patterns/<pattern-name>.md` — pattern name lowercased, spaces → hyphens, special characters removed, truncated to 50 chars (e.g. "API Endpoint" → `api-endpoint.md`).

If the cache exists and `--force` is NOT in the arguments: read it, output its content under this header, then STOP — no analysis.

```
📁 Loading cache: .sourceatlas/patterns/api-endpoint.md (N days ago)
💡 Add --force to re-analyze
```

Warn if the cache is older than 30 days.

## 2. Find candidate files

Run the bundled detector (auto-detects Swift/Kotlin/TypeScript/Python/Ruby/Go/Rust project type and returns the top 10 files, ranked by filename + directory relevance):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/atlas/find-patterns.sh" "<pattern>" [path]
```

Run it with no arguments to list supported pattern names for the detected language. If the script is unavailable or reports "Unknown pattern", fall back to Grep/Glob using keywords from the pattern name.

Notes:
- The script matches filenames/directories only. For **content-based patterns** (async/await, Combine publishers, suspend functions, custom hooks, decorators), go straight to Grep on code content.
- It already excludes vendored/build dirs, and test dirs unless the pattern itself is test-related.
- If results are too broad (>50 files), ask the user for a more specific pattern (e.g. "payment service" instead of "service").

**Output modes**: `--brief` → list the ranked files and stop. `--full` → analyze all found files. Default: ≤5 files → analyze all; >5 → show the ranked list and ask which to analyze.

## 3. Analyze

Read the top 2-3 files only — prefer complete, production implementation files (~100-500 lines) over utilities, trivial code, or generated files. Extract:

1. How this codebase handles the pattern (2-3 sentences)
2. Standard execution flow (numbered steps across layers)
3. Naming, structure, and dependency-injection conventions
4. Error handling approach
5. How the pattern is tested (locate the matching test files)
6. Pitfalls implied by the code (what the examples deliberately avoid)

## 4. Report

Start with:

```markdown
🗺️ SourceAtlas: Pattern
───────────────────────────────
🧩 [Pattern Name] │ [N] files found
```

Then YAML:

```yaml
overview: ...                # 2-3 sentences: how THIS codebase does it
best_examples:               # 2-3 entries, best first
  - {file: path:line, purpose: ..., key_points: [...]}   # + short code snippet
key_conventions:             # observable rules with locations
  - ...
testing_pattern:             # test location, framework, approach; or "no tests found"
  ...
common_pitfalls:             # what to avoid + the correct approach
  - ...
implementation_guide:        # concrete numbered steps with target file paths
  - ...
related_patterns: [...]      # optional
```

Include a 5-15 line code snippet for each best example, taken verbatim from the file.

## 5. Verify, then save

Before saving, `test -f` every claimed file path and `test -d` every claimed directory; spot-check that each code snippet actually appears in its file (`grep`). Correct anything that fails; if most claims fail, redo the analysis.

Then save:

```bash
mkdir -p .sourceatlas/patterns
# write the full report to the cache path from step 1
```

Confirm: `💾 Saved to .sourceatlas/patterns/<pattern-name>.md`

## 6. Recommended next steps

If the pattern is simple and self-contained, end with:

```markdown
✅ **Pattern analysis complete** — start implementing with the guide above
```

Otherwise suggest follow-ups (only those with concrete parameters from your findings):

```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:flow "src/api/UserController.ts"` | Pattern spans 3 layers — trace the full flow |
| 2 | `/sourceatlas:impact "src/services/BaseService.ts"` | Used by 23 services — map dependencies |
| 3 | `/sourceatlas:pattern "repository"` | Controllers depend on repositories — learn that next |

💡 Enter a number (e.g., `1`) or copy the command to execute
```
