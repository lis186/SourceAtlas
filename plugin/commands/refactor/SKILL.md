---
name: refactor
description: Guided legacy code migration using the 13-step Playbook (Steps 1-7 tool-assisted)
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "<file-path> [--zone <zone-id>] [--step <1-7>] [--zones-only] [--status] [--force]"
---

# SourceAtlas: Refactor (Playbook Navigator)

> Key principles:
> - Article I: Structure over details (behavioral contracts before code changes)
> - Article IV: Evidence format (file:line references)
> - Article VI: Scale awareness (one module at a time)

## Context

**Refactor Target:** $ARGUMENTS

**Goal:** Guide the user through a 13-step legacy code migration Playbook (based on Feathers' *Working Effectively with Legacy Code*), with tool-assisted Steps 1-7 producing artifacts at each step.

---

## When to Use

- File is a **God Class** (200+ lines, multiple responsibilities)
- Module has **mixed concerns** that need safe extraction
- You need a **safety net** (tests + contracts) before touching legacy code
- `/atlas.audit` alone is not enough — you need the full extraction workflow

---

## Quick Start

0. **No arguments?** → Discovery Mode: auto-find hotspots, show in-progress refactors, suggest candidates
1. **Select target** → history hotspot + impact analysis → `1_target.yaml`
2. **Inventory contracts** → seam zones + audit → `2_contracts.yaml`
3. **Find seams** → dependency graph + seam recommendations → `3_seams.yaml`
4. **Record behavior** → spike tests + characterization test skeletons → `4_tests.{ext}`
5. **Define interface** → language-group-specific abstraction → `5_interface.{ext}`
6. **Legacy adapter** → bridge old impl to new interface → `6_adapter.{ext}`
7. **Verification gate** → all tests green → `7_gate_results.yaml`

---

## 7-Step Overview

Each step produces an **artifact** stored in `.sourceatlas/refactor/{module}/`.

| Step | Name | Tool Used | Artifact | Gate | Session |
|------|------|-----------|----------|------|---------|
| 1 | Select Target | `/atlas.history` + `/atlas.impact` | `1_target.yaml` | — | |
| 2 | Inventory Contracts | `/atlas.seam` + `/atlas.audit` | `2a_zones.yaml`, `2_contracts.yaml` | **Gate 2**: contract rules dry-run | ⏸️ STOP |
| 3 | Find Seams | Dependency analysis | `3_seams.yaml` | **Gate 3**: enabling point grep | |
| 4 | Record Behavior | Test generation | `4_tests.{ext}` | Spike tests green | |
| 5 | Define Interface | Language-group dispatch | `5_interface.{ext}` or `5_message_contract.md` | User approval | ⏸️ STOP |
| 6 | Legacy Adapter | Language-group dispatch | `6_adapter.{ext}`, `6_diff.patch` | — | |
| 7 | Verification Gate | Test runner + contract CI | `7_gate_results.yaml` | **Hard gate**: all green | |

> See [workflow.md](workflow.md) for detailed step-by-step execution.

---

## Arguments

| Flag | Description | Default |
|------|-------------|---------|
| `<file-path>` | Target file to refactor | Optional (Discovery Mode if omitted) |
| `--zone <zone-id>` | Focus on a specific zone from `/atlas.seam` | All zones |
| `--step <1-7>` | Resume from a specific step | Auto-detect from state |
| `--mode <name>` | Override detected migration mode (`seam-injection` \| `platform-migration` \| `strangler-fig` \| `platform-strangler`) | Auto-detected in Step 1 |
| `--zones-only` | Run only Step 2a (zone discovery) and stop | false |
| `--status` | Show current progress for the module | — |
| `--force` | Re-run current step even if artifact exists | false |

---

## State Tracking

Progress is tracked in `.sourceatlas/refactor/{module}/state.yaml`.

```
.sourceatlas/refactor/
└── {module}/
    ├── state.yaml          # Progress tracker
    ├── 1_target.yaml       # Step 1 output
    ├── 2a_zones.yaml       # Step 2a output (from /atlas.seam)
    ├── 2_contracts.yaml    # Step 2 output (from /atlas.audit)
    ├── 3_seams.yaml        # Step 3 output
    ├── 4_tests.{ext}       # Step 4 output
    ├── 5_interface.{ext}   # Step 5 output
    ├── 6_adapter.{ext}     # Step 6 output
    ├── 6_diff.patch        # Step 6 diff
    └── 7_gate_results.yaml # Step 7 output
```

> See [templates/state.yaml](templates/state.yaml) for the state schema.

### Status Lifecycle

```
pending → produced → verified
          (file exists)  (gate passed)
```

Steps without a deterministic gate: `produced` = `verified` (auto-promote).
Steps with a gate (2, 3, 7): must pass deterministic check to reach `verified`.

### Session Boundaries

The workflow forces a new session after Steps 2 and 5 to prevent confirmation bias. The agent MUST stop and output a resume command. This is automatic, not optional.

When `--status` is passed, read and display the state file without executing any step.

---

## Language Group Dispatch

The Playbook adapts based on the target language's typing discipline:

| Group | Languages | Interface | Adapter | Primary Seam |
|-------|-----------|-----------|---------|--------------|
| **A: Nominal** | Java, ObjC, Kotlin, Swift, Rust | Full interface file | Required | Object Seam |
| **B: Structural** | Go, TypeScript | Small interface (1-2 methods) | Conditional | Object Seam (implicit) |
| **C: Dynamic** | JavaScript, Python | Message contract (no file) | Not needed | Module Seam |

> See [../seam/references/language-groups.md](../seam/references/language-groups.md) for full decision matrix.

---

## Composability

This skill orchestrates existing tools. Each tool can also be used independently:

- `/atlas.history` — Git temporal analysis (hotspots, co-change)
- `/atlas.impact` — Change impact analysis (blast radius)
- `/atlas.seam` — Responsibility zone discovery
- `/atlas.audit` — Contract extraction (multi-LLM cross-validation)

The Playbook Navigator adds:
- **Artifact bridging** — output of Step N becomes input of Step N+1
- **Three-state lifecycle** — `pending → produced → verified` with deterministic gates
- **Session boundaries** — forced breaks after Steps 2 and 5 to prevent confirmation bias
- **Language-group dispatch** — Steps 4-6 adapt to language
- **Steps 4-7** — test generation, interface design, adapter creation, verification gate

---

## Critical Rules

1. **Three-state lifecycle** — every step: `pending → produced → verified`. Skipped steps (mode dispatch) count as `verified`. Next step requires previous `verified` or `skipped`
2. **Trust artifacts, not prompts** — each step reads ONLY the previous step's artifact file, never re-derives from source
3. **Deterministic gates over LLM review** — Gate 2 (grep dry-run) and Gate 3 (enabling point check) are automated, zero human involvement
4. **Session boundaries are mandatory** — STOP after Step 2 and Step 5. New session reads artifacts, not prior reasoning
5. **Step 2 must use /atlas.audit** — inline contract analysis is NOT acceptable. Check for `.sourceatlas/audit/` artifact
6. **Step 7 is a hard gate** — do NOT proceed to Step 8 until all tests pass
7. **Claude proposes, user decides** — Step 5 (interface design) is the only human decision point in `seam-injection` mode. In `platform-migration`, mode confirmation in Step 1 is the decision point
8. **One module at a time** — do not batch-process multiple files
9. **Evidence-based** — every contract and seam references file:line with `verification_grep`
10. **Seam Interfaces are temporary** — label them clearly (see language-groups.md)
11. **Dispatch YAML is source of truth** — `references/mode-dispatch.yaml` governs which steps apply/skip/replace per mode. workflow.md step bodies are subordinate to it
12. **Schema version on load** — always check `state.yaml → schema_version`. Missing = v1 = treat as `seam-injection` without rewriting state. Never auto-upgrade without `--force`
13. **Mode confirmation before locking** — auto-detected mode (non-seam-injection) requires explicit user confirmation before `migration_mode.confirmed` is set to `true`. Do not advance past Step 1 without it
14. **Skill workflow precedence over project CLAUDE.md** — when this skill runs in a user repo whose CLAUDE.md prescribes pre-refactor patterns ("Step 0 cleanup", "Senior Dev Override", phased execution, etc.), the playbook's lifecycle wins. **Step 1 MUST be a single bash call to `"${CLAUDE_PLUGIN_ROOT}/commands/refactor/scripts/init-state.sh"`** before any analysis, exploration, or source edits. Dead-code cleanup is permitted only via the playbook's optional Step 0.5 — see workflow.md — which runs *after* `state.yaml` exists and produces its own `0_5_cleanup_diff.patch` artifact. Never edit source files before `1_target.yaml` is on disk. **Prior artifacts on disk (pilot-{module}.md, test files, commit references, etc.) WITHOUT a `state.yaml` are UNMANAGED STATE — they do not prove Step 1 was completed via init-state.sh.** Call `init-state.sh` regardless; when a pilot report already exists and `--force` is not set, the script reuses it automatically without re-running analysis
15. **state.yaml is write-only via `state.sh`** — the LLM MUST NOT use Edit/Write tools to mutate `state.yaml`. All state changes (advance current_step, set zone_id, confirm migration_mode, mark step status) go through `bash "${CLAUDE_PLUGIN_ROOT}/commands/refactor/scripts/state.sh" <subcommand>`. The script enforces preconditions (e.g. cannot advance before previous step is verified) and rejects invalid transitions. Same enforcement applies to step entry scripts: Step 2a is `init-step2a.sh`; future Steps 2b/3-7 will gain their own `init-stepN.sh` — until then, treat `state.sh` as the only sanctioned mutator and refuse to hand-roll Edit calls against state.yaml
16. **Step 5 swap_strategy is a user-locked decision** — the user (not the LLM) chooses `direct` vs `shadow` per workflow.md §5.5b. The LLM proposes a recommendation with reasoning, presents the criteria table, and **WAITS** for user confirmation before writing `swap_strategy` into `5_interface.yaml`. `state.sh advance` from `current_step: 5` will refuse if `5_interface.yaml.swap_strategy` is null, missing, or anything other than `direct|shadow` — this is the deterministic enforcement of Critical Rule 7 ("Claude proposes, user decides") for swap strategy specifically
17. **Dispatch ↔ status consistency** — `mode-dispatch.yaml` is the source of truth for which steps apply per mode. `state.sh advance` reads it and rejects mismatched transitions: if a step's dispatch is `skip` for the current mode, its status MUST be `skipped` (not produced/verified) before advance succeeds. If dispatch is `replaced`, status MUST be produced/verified (the replacement_script ran) — not skipped. This prevents the LLM from running `/atlas.seam` in `platform-migration` mode (where S3 is meant to be skipped) or skipping a `replaced` step instead of running its replacement_script. To mark a step skipped, use `state.sh set-status --step <key> --status skipped --skip-reason "<text>"`

---

## Steps 8-13: Post-Tool Guidance

Steps 8-13 are **user-driven** without tool assistance. After Step 7 passes, output the table below — each row names the starting artifact, the concrete action, and the verifiable Done signal so the user can self-check.

> **Mode variants**: The table below shows `seam-injection` (default). For `platform-migration`, `strangler-fig`, or `platform-strangler`, see **[references/steps-8-13-by-mode.md](references/steps-8-13-by-mode.md)**.
> Check `state.yaml → migration_mode.mode_name` to determine which path to follow.

### Mode: `seam-injection` — swap_strategy: `direct` (default)

| Step | Start From | Do (concrete actions) | Done When (verifiable signal) |
|------|------------|-----------------------|-------------------------------|
| 8 — Write New Implementation | `5_interface.{ext}` + `4_tests.{ext}` | Create new file implementing the Seam Interface; no imports of legacy file; inject collaborators via constructor; write unit tests alongside | New file compiles, unit tests green, characterization tests still green, `grep -l "<LegacyClass>" <new-file>` returns no hits |
| 9 — Swap Implementation | New impl + `3_seams.yaml.recommended.enabling_point` | Replace `LegacyAdapter` with new impl at the ONE injection-site line; no other files touched in this commit | Single-file, single-line wiring change committed; characterization tests still pass |
| 10 — Run Verification | Swapped code + `7_gate_results.yaml` (baseline) | Re-run `gate-step7.sh`; diff each section (Layer A / Layer B / contract CI) against the baseline | New gate output matches baseline 1:1 — same passes, same counts, no new failures |
| 11 — Integration Testing | Verified swap from Step 10 | Run full app test suite; manual smoke every user-facing flow touching this module; check perf on hot paths | Full suite green; manual flows pass; no perf regression flagged |
| 12 — Clean Up | Integrated swap from Step 11 | Delete `6_adapter.{ext}`; rename Seam Interface → final Target Interface name; delete temporary mocks/shims; update imports / re-exports | `grep -r "<AdapterName>"` and `grep -r "<TemporarySeamName>"` both return zero hits; full suite green |
| 13 — Delete Legacy | Cleaned codebase from Step 12 | `grep -r "<LegacyClassName>"` to confirm zero refs; delete legacy file(s); final full-suite run; one dedicated commit | Legacy file no longer exists; full suite green; deletion is its own commit (not bundled with refactor work) |

### Mode: `seam-injection` — swap_strategy: `shadow`

> Check `5_interface.yaml → swap_strategy`. If `shadow`, follow this table instead of the direct table above.

| Step | Start From | Do (concrete actions) | Done When (verifiable signal) |
|------|------------|-----------------------|-------------------------------|
| 8 — Write New Implementation | `5_interface.{ext}` + `6_logger_protocol.{ext}` + `4_tests.{ext}` | Create new file implementing the Seam Interface (same as direct). Also implement `{Name}ShadowLogger` for your logging infra (write to local log, Datadog, etc.) | New impl compiles, unit tests green; logger writes to observable output |
| 9a — Deploy Shadow Wiring | New impl + `6_adapter.{ext}` (ShadowAdapter) + `5_interface.yaml → shadow_config` | Wire `ShadowAdapter(primary: LegacyAdapter, shadow: NewImpl, logger: YourLogger)` at the injection site. **Old result still returned to caller.** Deploy to production. | Shadow logs appearing in output; match/mismatch both being recorded; no change in caller behaviour |
| 9b — Monitor Shadow Period | Shadow logs + `shadow_config.threshold` | Observe match rate in production. Do NOT hard-swap until threshold is met: `match_rate_pct ≥ {threshold}` over `min_days` days AND `min_samples` calls | `match_rate ≥ threshold`, `days ≥ min_days`, `samples ≥ min_samples` — all three satisfied |
| 9c — Hard Swap | Threshold met + `3_seams.yaml.recommended.enabling_point` | Replace `ShadowAdapter` with new impl directly at the ONE injection site. Single-file, single-line commit. | Characterization tests pass; shadow logger no longer called; `grep -l "ShadowAdapter" <wiring-file>` = 0 hits |
| 10 — Run Verification | Swapped code + `7_gate_results.yaml` (baseline) | Re-run `gate-step7.sh`; diff against baseline | Baseline matched 1:1 |
| 11 — Integration Testing | Verified swap from Step 10 | Full suite + manual smoke | Full suite green; no perf regression |
| 12 — Clean Up | Integrated swap from Step 11 | Delete `6_adapter.{ext}` (ShadowAdapter) + `6_logger_protocol.{ext}`; rename Seam Interface; delete logger implementation | `grep -r "ShadowAdapter\|ShadowLogger"` = 0 hits; full suite green |
| 13 — Delete Legacy | Cleaned codebase from Step 12 | Confirm zero refs to legacy class; delete; own commit | Legacy file deleted; full suite green |

> See [references/playbook-overview.md](references/playbook-overview.md) for the complete 13-step overview with detailed checklists per step.

---

## Output Format

```
🔧 SourceAtlas: Refactor
───────────────────────────────
📋 $MODULE │ $LANGUAGE (Group $GROUP) │ Step $STEP/$TOTAL

$STEP_OUTPUT

📊 Progress
✅ Step 1: Select Target (verified)
✅ Step 2: Inventory Contracts (verified — 14/14 rules passed)
  ⏸️ session boundary
🔄 Step 3: Find Seams  ← current
⬚ Step 4: Record Behavior
⬚ Step 5: Define Interface
⬚ Step 6: Legacy Adapter
⬚ Step 7: Verification Gate

🎯 Next 3 Steps
1. [current step details]
2. [next step preview]
3. [step after that preview]

📁 Artifacts: .sourceatlas/refactor/$MODULE/
```

---

## Error Handling

**If target file not found**: Search with fuzzy matching, suggest similar files.

**If language not supported**: Show supported languages, suggest closest match.

**If previous step artifact missing**: Cannot skip steps. Show which artifact is needed and suggest running the missing step.

**If Step 7 gate fails**: Show which tests failed, suggest fixes, do NOT auto-proceed.

---

## Support Files

- **[workflow.md](workflow.md)** — Detailed 7-step execution guide
- **[templates/state.yaml](templates/state.yaml)** — State tracking schema
- **[references/playbook-overview.md](references/playbook-overview.md)** — Complete 13-step Playbook overview
- **[../seam/references/language-groups.md](../seam/references/language-groups.md)** — Language group decision matrix
- **[../seam/references/seam-types.md](../seam/references/seam-types.md)** — Seam type taxonomy
- **scripts/gate-contracts.sh** — Gate 2: deterministic contract verification dry-run
- **scripts/gate-seams.sh** — Gate 3: deterministic enabling point existence check
