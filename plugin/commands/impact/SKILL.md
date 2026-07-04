---
name: impact
description: Analyze the impact scope of a code change via static dependency analysis — direct and transitive dependents, test impact, risk level, and a migration checklist, cached to .sourceatlas/impact/. Use when the user asks "what will break if I change X", "what depends on X", "impact of changing X", "is it safe to modify X", or before making significant code changes.
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: [target, e.g., "User model", "api /api/users/{id}", "UserService", "src/api/users.ts"] [--force]
---

# SourceAtlas: Impact Analysis

**Arguments**: $ARGUMENTS

Identify all code affected by changes to the target through static dependency analysis (code structure, not runtime behavior). Every claim needs a `file:line` reference; every count comes from an actual search, never an estimate.

## 1. Cache check (do this first)

Cache path: `.sourceatlas/impact/{name}.md`, where `{name}` is the target with `--force` removed, lowercased, spaces and slashes → `-`, `{}` and special characters removed, truncated to 50 chars (e.g. `"User model"` → `user-model.md`, `"api /api/users/{id}"` → `api-users-id.md`).

If the cache exists and `--force` is NOT in the arguments: read it, output its content under this header, then STOP — no analysis.

```
📁 Loading cache: .sourceatlas/impact/{name}.md (N days ago)
💡 Add --force to re-analyze
```

Warn if the cache is older than 30 days.

## 2. Analyze

Always exclude `.git/`, `node_modules/`, `.venv/`, `vendor/`, build output. In monorepos, scope searches to the relevant package to avoid false positives.

**Detect target type** — it sets the tracing strategy:

- **API** (path or "api" in target): endpoint definition → request/response types → frontend call sites → wrapping hooks/services → components using those hooks. Type definitions are the critical link for breaking changes.
- **MODEL**: model file → who imports it → associations (`belongs_to`/`has_many`, foreign keys) → validations → business-logic usage (create/find/update call sites). Associated models cascade: a validation change can break every model that `belongs_to` it.
- **COMPONENT** (anything else): locate the definition → find imports/references → find call sites → categorize.

**Trace both direct and transitive dependents.** Direct = files importing/referencing the target. Transitive = consumers of wrappers (a hook wrapping an API, a service wrapping a model) — they break too. Distinguish them in the report: direct dependents break immediately, transitive ones may break.

**Counting rules** (the classic hallucination points):
- Report exact counts from search results, never "~30".
- Categories (core / coordinators / frontend / others, or whatever fits the project) must be **mutually exclusive** — assign each file to exactly one category and check the category sums equal the deduplicated total.
- Match import/usage statements, not comments or strings. Exclude test/mock files from dependent counts; report them separately as test impact.
- If a field change is in scope, count every usage of that field and note type assumptions (e.g. `user.role === 'admin'` assumes string).

**Test impact**: find tests covering the target (by name pattern and by import). Flag coverage gaps — dependents with no tests are migration risks.

**iOS/Swift extras** (only for Swift/ObjC targets): check `@objc` / `@objcMembers` exposure (renames break ObjC callers), nullability annotation coverage (missing `NS_ASSUME_NONNULL` → crash risk on interop), `unowned` references near the target, and bridging-header involvement.

**Risk classification**:
- 🟢 LOW: 1–5 dependents, well-tested, non-critical
- 🟡 MEDIUM: 5–15 dependents, partial tests, business logic
- 🔴 HIGH: >15 dependents, OR critical path (auth/payment), OR breaking change, OR test coverage <50%

**Edge cases**: target not found → fuzzy-search and suggest similar names, ask to clarify. >100 dependents → show top 20–30 by priority, group by category, give per-category counts, and warn the list is sampled. Zero dependents → verify the target exists; it may be a leaf or dead code.

## 3. Report

```markdown
🗺️ SourceAtlas: Impact
───────────────────────────────
💥 [target] │ [total dependents] dependents

📊 Impact Summary        # counts by layer + Risk Level 🔴/🟡/🟢 with reason
## 1. Definition         # target file:line, key types/associations/validations
## 2. Direct Dependents  # high priority — break immediately; file:line + how each uses the target
## 3. Transitive Impact  # via hooks/services/associations — may break
## 4. Field Usage        # if a field change: exact count, each location, type assumptions
## 5. Test Impact        # tests to update + coverage gaps
## 6. Language-Specific Risks   # iOS/Swift interop only; omit otherwise
## 7. Migration Checklist       # concrete steps with [N] counts; no time estimates
```

## 4. Verify, then save

Before saving, `test -f` every file path the report claims and spot-check that cited imports/usages actually appear in those files; fix or drop anything that fails. Then `mkdir -p .sourceatlas/impact`, save the full report to the cache path from step 1, and confirm: `💾 Saved to .sourceatlas/impact/{name}.md`

## 5. Recommended next steps

If impact is small (<5 dependents) or the checklist is self-sufficient, end with:

```markdown
✅ **Impact analysis complete** — Can start modifications following the Migration Checklist
```

Otherwise suggest 1–2 follow-ups with concrete parameters from your findings:

```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:flow "[entry point]"` | Impact chain spans N layers — trace the full flow |
| 2 | `/sourceatlas:history "[directory]"` | Area changes frequently — check historical patterns |

💡 Enter a number (e.g., `1`) or copy the command to execute
```
