---
name: audit
description: Extracts implicit behavior contracts from legacy code before refactoring, using a 3-LLM cross-validation pipeline (Gemini blind scan → Claude structured audit → Codex adversarial review) with machine-verifiable grep/ast-grep assertions. Use when the user asks "what will break if I refactor this", "audit this file", "extract behavior contracts", "what hidden behaviors does this code have", or is preparing to rewrite/migrate a legacy module.
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "<file-path> [--language objc|swift|typescript|javascript] [--zone <zone-id>] [--force]"
---

# SourceAtlas: Contract Audit (Multi-LLM Cross-Validation)

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
- **LLM CLIs**: check `command -v gemini` and `command -v codex`. Either missing → degraded mode (step 4).

## 3. Pipeline

**Step 0 — Boundary discovery.** `rg` the codebase for the module's neighbors: imports/includes of it, references to its types, and notification/event names it posts or observes. These files are context for every later step.

**Step 1 — Gemini blind scan.** Ask the `gemini` CLI to independently list hidden behaviors of the target (plus boundary context), with file:line evidence. Blind means: do NOT show Gemini the contract taxonomy or your own draft — independence prevents confirmation bias.

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

**Step 3 — Codex adversarial review.** Feed the contract list to the `codex` CLI with an adversarial brief: for each contract answer CONFIRM, DISPUTE (with reasoning), or ADD missing contracts. CONFIRM_RATIO = confirmed/total; healthy range is 30–70%. >70% means the review wasn't critical enough; <30% means the contracts need revision.

**Step 4 — Merge (you).** Resolve disputes, integrate additions, produce the final list plus CI rules.

**Methodology rules** (non-negotiable):
1. Every contract cites file:line evidence — no evidence, no contract.
2. A contract needs at least 2 of 3 LLMs agreeing to survive the merge.
3. Every contract ships a runnable grep/ast-grep assertion (grep fallback when ast-grep is unavailable, e.g. Objective-C).
4. Codex DISPUTEs often reveal real issues — resolve them explicitly, don't discard.
5. If no contracts are found, say so: the file may be a leaf module — suggest `/atlas.impact` instead.

## 4. Degraded mode

If `gemini` or `codex` is missing, generate the prompts as files instead and tell the user how to run them manually:

```
.sourceatlas/audit/prompts/
├── step1-gemini.md   # feed to Gemini
├── step2-claude.md   # feed to Claude, include Gemini output
└── step3-codex.md    # feed to Codex, include Claude output
```

Then: re-run `/atlas.audit <file> --force` and paste the outputs to merge. Still perform Step 2 yourself — Claude's structured audit is always available; mark the result `degraded: true`.

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
degraded: false
summary:
  total_contracts: ...
  by_category: {M: ..., L: ..., N: ..., S: ..., E: ..., C: ..., D: ..., P: ...}
cross_validation:
  gemini_behaviors: ...
  codex: {confirmed: ..., disputed: ..., added: ...}
  confirm_ratio: ...        # healthy 30–70%
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
