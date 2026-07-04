---
name: deps
description: Analyze dependency usage for library/framework/SDK upgrades — detects the installed version, finds breaking changes and deprecated API usage, and produces a migration checklist with effort estimates, cached to .sourceatlas/deps/. Use when the user asks "upgrade to X", "migrate from X to Y", "what breaks if we upgrade", "how much work is the iOS 17 / React 18 / Python 3.12 migration", or wants to audit usage of a specific library.
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write, WebSearch, WebFetch
argument-hint: [target, e.g., "react 17 → 18", "iOS 16", "lodash"] [--force]
---

# SourceAtlas: Dependencies

**Arguments**: $ARGUMENTS

Analyze how a dependency is used and what a version upgrade requires: current state, required changes, modernization opportunities, migration path, and risk. Every usage point needs a `file:line` reference; all counts come from actual searches.

## 1. Cache check (do this first)

Cache path: `.sourceatlas/deps/{name}.md`, where `{name}` is the target with `--force` removed, lowercased, non-alphanumeric runs → single `-`, trimmed (e.g. `"react 17 → 18"` → `react-17-18.md`, `"iOS 16"` → `ios-16.md`, `"@types/node"` → `types-node.md`).

If the cache exists and `--force` is NOT in the arguments: read it, output its content under this header, then STOP — no analysis.

```
📁 Loading cache: .sourceatlas/deps/{name}.md (N days ago)
💡 Add --force to re-analyze
```

Warn if the cache is older than 30 days.

## 2. Analyze

**Classify the request** — it sets the focus:

| Input pattern | Type | Focus |
|---------------|------|-------|
| `iOS 17`, `iOS 16 → 17` | Minimum-version upgrade | Removable `#available` checks, deprecated APIs, new opportunities |
| `iOS SDK 26`, `Xcode 16` | SDK/compiler upgrade | Compilation warnings, Swift version, new syntax |
| `react 17 → 18`, `pandas 1.x → 2.x` | Major version upgrade | Breaking changes, deprecated APIs, new patterns |
| `react` (no version) | Usage inventory | List usage points only |

For upgrades, briefly state the planned checks and where the rules come from before scanning.

**Detect the current version from manifests — never guess.** Prefer lock files (package-lock.json, Podfile.lock, …) for the actually-installed version; if it differs from the manifest spec, report the lock-file version and note the spec. Not in any manifest → check for a transitive dependency or a different package name; ask if unclear. Monorepo with multiple versions → tell the user and analyze one scope.

**Get upgrade rules.** WebSearch for the official migration guide and changelog (query with exact versions). Source priority: official docs > maintainer posts > community. Always disclose the rule source in the report; if no guide exists, produce the usage inventory only and recommend a manual changelog review.

**Find usage and match against the rules.** Search imports and API call sites, group by category (hooks/components/utilities, frameworks/APIs, availability checks), with exact counts and `file:line`. Exclude vendored code (`node_modules/`, `Pods/`, `dist/`, `build/`). Per-ecosystem checks:

- **iOS/Swift**: deployment target in Podfile / Package.swift / project settings. `#available(iOS N)` checks below the new minimum are removable — count them. Known deprecations (e.g. `UIWebView`, `@UIApplicationMain` → `@main`). New-minimum opportunities (e.g. iOS 17+ → `@Observable` replacing `ObservableObject + @Published`).
- **Android/Kotlin**: `compileSdk` / `minSdk` / `targetSdk` in build.gradle(.kts); `Build.VERSION.SDK_INT` checks below the new minSdk are removable.
- **React/JS**: search all of `.js/.jsx/.ts/.tsx`; legacy lifecycle methods (`componentWillMount`, `componentWillReceiveProps`), string refs, `ReactDOM.render` → `createRoot`.
- **Python**: version in pyproject.toml / requirements / lock files; removed stdlib modules and deprecation warnings for the target version per the changelog.

**Effort and risk.** Rate each required change low/medium/high. Overall effort follows the dominant category; overall risk 🟢/🟡/🔴 from four factors: breaking_changes (none/minor/major), usage_breadth (isolated/moderate/widespread), test_coverage, migration_guide_quality. No usage found → verify the dependency is actually installed; it may be unused.

## 3. Report

```markdown
🗺️ SourceAtlas: Deps
───────────────────────────────
📦 [target] │ [N] APIs found
```

Then YAML:

```yaml
dependency_analysis: {target: ..., type: library|sdk|framework|runtime, analysis_time: ...}
version_info: {current: ..., source: ..., target: ...}   # source = manifest/lock file
rules_applied: {source: built-in|web_search|user_provided, rule_count: N}
required_changes:                 # must-do for the upgrade
  removable_availability_checks: {total: N, items: [{file: path:line, code: ..., action: ...}]}
  deprecated_api_usages: {total: N, items: [{file: ..., api: ..., replacement: ..., migration_effort: ...}]}
  breaking_change_impacts: {total: N, items: [{file: ..., change: ..., action: ...}]}
modernization_opportunities:      # optional wins unlocked by the upgrade
  items: [{category: ..., current_pattern: ..., new_pattern: ..., affected_files: N, benefit: ..., effort: ...}]
usage_inventory:
  total_files: N
  total_usage_points: N
  by_category: [{name: ..., count: N, files: [path:line, ...]}]
migration_checklist:
  estimated_effort: low|medium|high
  recommended_approach: ...
  steps: [{step: 1, action: ..., command/files_affected: ...}]
risk_assessment:
  overall_risk: 🟢 low|🟡 medium|🔴 high
  factors: {breaking_changes: ..., usage_breadth: ..., test_coverage: ..., migration_guide_quality: ...}
  recommendations: [...]
```

For a plain usage inventory (no upgrade), omit `required_changes` and `migration_checklist`.

## 4. Verify, then save

Before saving, re-check the detected version against the manifest, `test -f` every claimed file path, and spot-check counts with a fresh search; fix or drop anything that fails. Then `mkdir -p .sourceatlas/deps`, save the full report to the cache path from step 1, and confirm: `💾 Saved to .sourceatlas/deps/{name}.md`

## 5. Recommended next steps

If risk is 🟢 low or this was a plain inventory, end with:

```markdown
✅ **Dependency analysis complete** — Safe to proceed with the Migration Checklist
```

Otherwise suggest 1–2 follow-ups with concrete parameters from your findings:

```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:impact "[high-risk component]"` | N deprecated usages here — check blast radius first |
| 2 | `/sourceatlas:pattern "[library usage pattern]"` | Learn how the project wraps this library |

💡 Enter a number (e.g., `1`) or copy the command to execute
```
