---
name: overview
description: Generate a project fingerprint — tech stack, architecture, development practices, and AI-collaboration level — by reading a small set of high-information files, cached to .sourceatlas/overview.yaml. Use when the user asks "what is this project", "give me an overview", "how is this codebase structured", "what tech stack does this use", or when onboarding to an unfamiliar codebase.
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "[path] [--force] (e.g., 'src/api' or '. --force')"
---

# SourceAtlas: Project Overview

**Arguments**: ${ARGUMENTS:-.}

Generate a project fingerprint by reading a small number of high-information files. Understand structure, not implementation details — do not deep-dive into code.

## 1. Cache check (do this first)

Cache path: `.sourceatlas/overview.yaml` for the repo root; for a subdirectory argument, replace `/` with `-` (e.g. `src/api` → `.sourceatlas/overview-src-api.yaml`).

If the cache exists and `--force` is NOT in the arguments: read it, output its content under this header, then STOP — no analysis.

```
📁 Loading cache: .sourceatlas/overview.yaml (N days ago)
💡 Add --force to re-analyze
```

Warn if the cache is older than 30 days.

## 2. Explore

Read files in descending information density. Always exclude `.git/`, `node_modules/`, `.venv/`, `vendor/`, `__pycache__/`, build output.

1. **Documentation** — README, CLAUDE.md / AGENTS.md, ARCHITECTURE, CONTRIBUTING, top-level docs/
2. **Configuration** — package manifests (package.json, pyproject.toml, Podfile, build.gradle, …), docker-compose, CI config
3. **Core models/entities** — 2–3 representative files
4. **Entry points / routing** — 1–2 examples
5. **Tests** — 1–2 examples

Scale reading to the project: a few files for small projects, ~10–15 for very large ones. Note the git branch and whether the target is a monorepo subdirectory.

### AI collaboration detection

Direct markers (any of these present is high confidence): `CLAUDE.md` / `.claude/`, `.cursorrules` / `.cursor/rules/`, `.windsurfrules`, `.github/copilot-instructions.md`, `.clinerules` / `.roo/`, `CONVENTIONS.md` / `.aider.conf.yml`, `.continue/rules/`, `AGENTS.md`, `.ruler/`.

Indirect signals: unusually high comment density, near-perfect style consistency, 100% conventional commits, docs-to-code ratio > 1:1.

Levels: **0** none · **1** occasional (one minimal config) · **2** frequent (1–2 configs + indirect signals) · **3** systematic (comprehensive config + consistent signals) · **4** ecosystem-level (multiple tool configs or AGENTS.md as team standard).

## 3. Report

Start with:

```markdown
🗺️ SourceAtlas: Overview
───────────────────────────────
🔭 [project_name] │ [file count] files
```

Then YAML:

```yaml
metadata:
  project_name: ...
  scan_time: ...
  total_files: ...        # code files, excluding vendored/generated
  scanned_files: ...
  context: {git_branch: ..., subdirectory: ...}   # if applicable
project_fingerprint:
  project_type: ...       # e.g. web-api, ios-app, cli-tool
  primary_language: ...
  framework: ...
  architecture: ...       # e.g. MVC, clean-architecture, monolith
tech_stack:
  backend: [...]
  frontend: [...]         # omit if N/A
  infrastructure: [...]   # omit if N/A
hypotheses:               # one list per relevant category:
  architecture: [...]     #   tech_stack, architecture, development,
  development: [...]      #   ai_collaboration, business
  ai_collaboration: {level: 0-4, tools_detected: [...]}
  business: [...]
scanned_files:
  - {file: ..., reason: ..., key_insight: ...}
summary:
  key_findings: [...]
```

Each hypothesis needs: a clear statement, `confidence` (0.0–1.0; only include ≥0.7), `evidence` (file:line references), and `validation_method`. Write as many well-evidenced hypotheses as the project supports — quality over quantity.

## 4. Verify, then save

Before saving, verify every path the report claims: `test -f` each entry in `scanned_files` and each detected tool config, and confirm the git branch with `git branch --show-current`. Correct anything that fails; if most claims fail, redo the analysis.

Then save:

```bash
mkdir -p .sourceatlas
# write the YAML to the cache path from step 1
```

Confirm: `💾 Saved to .sourceatlas/overview.yaml`

## 5. Recommended next steps

If the project is small enough to read directly or findings are too thin for confident parameters, end with:

```markdown
✅ **Analysis sufficient** - Project is small, can read all files directly
```

Otherwise suggest follow-ups (pick only those with concrete parameters from your findings):

```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:pattern "repository"` | Found Repository pattern in 15 files |
| 2 | `/sourceatlas:flow "src/app.ts"` | Trace the main request flow |
| 3 | `/sourceatlas:history` | Large codebase — find hotspots |

💡 Enter a number (e.g., `1`) or copy the command to execute
```
