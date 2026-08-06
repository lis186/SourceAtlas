---
name: audit
description: Extracts implicit behavior contracts from legacy code before refactoring, using a cross-validated pipeline (blind scan → Claude structured audit → adversarial review, each in an independent context) with machine-verifiable grep/ast-grep assertions. Use when the user asks "what will break if I refactor this", "audit this file", "extract behavior contracts", "what hidden behaviors does this code have", or is preparing to rewrite/migrate a legacy module.
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write, Task
argument-hint: "<file-path> [--language objc|swift|typescript|javascript] [--zone <zone-id>] [--force]"
---

# SourceAtlas: Contract Audit (Cross-Validation)

**Arguments**: $ARGUMENTS

Extract the implicit behavioral contracts of one target file so a refactor can prove it preserved them. One module at a time — never batch files.

## 1. Cache check (do this first)

Module name = basename, extension stripped, lowercased (`NYHTTPSClient.m` → `nyhttpsclient`). Cache path: `.sourceatlas/audit/{module}.yaml`.

If the cache exists and `--force` is NOT in the arguments: read it, output its content, then STOP.

```
📁 Loading cache: .sourceatlas/audit/{module}.yaml (N days ago)
💡 Add --force to re-audit
```

Warn if older than 30 days — code may have changed.

## 2. Setup

- **Target**: first non-flag argument. If not a file, fuzzy-search (`find . -name "*<basename>*"`, excluding `.git/`, `node_modules/`) and ask the user to pick.
- **Language**: `--language` flag wins; else map extension (`.m/.h`→objc, `.swift`→swift, `.ts/.tsx`→typescript, `.js/.jsx`→javascript, `.kt`→kotlin, `.py`→python, `.go`→go, `.rs`→rust, `.java`→java). Unknown → generic analysis with a note.
- **Zone scoping**: with `--zone <id>`, read `.sourceatlas/seam/{module}.yaml` (from `/atlas.seam`), extract that zone's `start_line`/`end_line`, and audit only `sed -n "${START},${END}p"` of the file. Keep contract line references absolute to the original file. If the seam file or zone is missing, list available zones and stop.
- **Reviewers**: blind scan runs on the `agy` CLI (`agy -p "<prompt>"`); adversarial review on the `codex` CLI (`codex exec -`). If either is missing or fails (e.g. quota), substitute a **fresh-context Claude subagent** (Task tool) given the exact same prompt — independence comes from the clean context, not the vendor. Record which reviewer actually ran (see report).

## 3. Pipeline

**Step 0 — Boundary discovery.** `rg` the codebase for the module's neighbors: imports/includes of it, references to its types, and notification/event names it posts or observes. These files are context for every later step.

**Step 1 — Blind scan.** Ask the blind reviewer (`agy`, or subagent fallback) to independently list hidden behaviors of the target (plus boundary context), with file:line evidence. Blind means: do NOT show the reviewer the contract taxonomy or your own draft — independence prevents confirmation bias.

**Step 2 — Claude structured audit (you).** Read the target and boundary files. Extract formal contracts using this taxonomy:

| ID | Category | What to capture |
|----|----------|-----------------|
| M | Mutation | Side-effect modifications to requests or data |
| L | Lifecycle | Implicit state transitions |
| N | Notification | Publish/subscribe coupling |
| S | Synchronization | Blocking, locking, ordering guarantees |
| E | Error Handling | Error swallowing vs propagation |
| C | Cancellation | Cancel scope and residual state |
| D | Dependency | Behavior depends on an external entity; must separate before migration |
| P | Propagation | Effect paths: return-value chains, parameter mutation, global state |

Each contract records: Trigger, Input, Output, Condition, Ordering, Risk (LOW/MEDIUM/HIGH + reason), Evidence (file:line + snippet), Scope (method/class/module), Seam_Type (object/preprocessing/link/none), Pinch_Point (true/false), and a machine-verifiable grep or ast-grep assertion.

**Step 3 — Adversarial review.** Feed the contract list to the adversarial reviewer (`codex`, or subagent fallback) with an adversarial brief: for each contract answer CONFIRM, DISPUTE (with reasoning), or ADD missing contracts. CONFIRM_RATIO = confirmed/total; healthy range is 30–70% (unvalidated heuristic — treat as a reference value, not a gate). >70% means the review wasn't critical enough; <30% means the contracts need revision.

**Step 4 — Merge (you).** Resolve disputes, integrate additions, produce the final list plus CI rules.

**Methodology rules** (non-negotiable):
1. Every contract cites file:line evidence — no evidence, no contract.
2. A contract needs at least 2 of the 3 independent reviewers agreeing to survive the merge.
3. Every contract ships a runnable grep/ast-grep assertion (grep fallback when ast-grep is unavailable, e.g. Objective-C).
4. Adversarial DISPUTEs often reveal real issues — resolve them explicitly, don't discard.
5. If no contracts are found, say so: the file may be a leaf module — suggest `/atlas.impact` instead.

## 4. Reviewer fallback

The pipeline never blocks on a missing CLI. Blind scan: `agy` unavailable/failing → spawn a fresh-context Claude subagent with the same blind prompt (no taxonomy, no draft). Adversarial: `codex` unavailable/failing → same, with the adversarial brief. The subagent must not see this session's reasoning — pass only the prompt and file paths. Record the substitution in `reviewers:` so readers know the vendor diversity of this run.

## 5. Report

Start with:

```markdown
🗺️ SourceAtlas: Audit
───────────────────────────────
📋 [module] │ [language] │ [N] contracts
```

Then YAML:

```yaml
module: ...
language: ...
file: ...
reviewers: {blind: agy|claude-subagent, adversarial: codex|claude-subagent}
summary:
  total_contracts: ...
  by_category: {M: ..., L: ..., N: ..., S: ..., E: ..., C: ..., D: ..., P: ...}
cross_validation:
  blind_behaviors: ...
  adversarial: {confirmed: ..., disputed: ..., added: ...}
  confirm_ratio: ...        # reference range 30–70% (unvalidated heuristic)
contracts:
  - id: M-001               # unique, category prefix + 3 digits
    title: ...
    trigger: ...
    input: ...
    output: ...
    condition: ...
    ordering: ...
    risk: MEDIUM            # + risk_reason
    evidence: {file: ..., line: ..., snippet: ...}
    scope: method           # method|class|module
    seam_type: object       # object|preprocessing|link|none
    pinch_point: true
    verification: {type: grep, command: "grep -q 'pattern' file"}
risk_assessment:
  high_risk: [...]          # contracts with risk HIGH + refactoring recommendations
  seam_analysis: {object: ..., preprocessing: ..., link: ..., pinch_points: ...}
ci_rules: [...]             # the grep/ast-grep assertions, ready to paste into CI
```

## 6. Verify, then save

Before saving: `test -f` every file claimed in contract evidence; check each evidence line with `sed -n "${line}p"` against the snippet (fix the line number or flag the contract as possibly hallucinated); confirm contract IDs are unique; run every verification assertion and drop or relax ones that fail; sanity-check CONFIRM_RATIO. If fewer than 3 categories appear, note that the analysis may be shallow. Then `mkdir -p .sourceatlas/audit` and write the YAML to `.sourceatlas/audit/{module}.yaml`. Confirm: `💾 Saved to .sourceatlas/audit/{module}.yaml`

## Recommended next

| Finding | Command |
|---------|---------|
| High-risk dependencies (D contracts) | `/atlas.impact <module>` |
| Need to trace call chains | `/atlas.flow <function>` |
| Planning refactoring scope | `/atlas.deps` |
| File too big to audit whole | `/atlas.seam <file>` then `--zone` |
| Need historical context / hotspots | `/atlas.history` |

💡 Enter a number (e.g., `1`) or copy the command to execute
