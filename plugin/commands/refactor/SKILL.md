---
name: refactor
description: Guided legacy code migration using the 13-step Playbook (Steps 1-7 tool-assisted)
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "<file-path> [--zone <zone-id>] [--step <1-7>] [--zones-only] [--status] [--force]"
---

# SourceAtlas: Refactor (Playbook Navigator)

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md) v1.0
>
> Key principles enforced:
> - Article I: Structure over details (behavioral contracts before code changes)
> - Article IV: Evidence format (file:line references)
> - Article VI: Scale awareness (one module at a time)

## Context

**Refactor Target:** $ARGUMENTS

**Goal:** Guide the user through a 13-step legacy code migration Playbook (based on Feathers' *Working Effectively with Legacy Code*), with tool-assisted Steps 1-7 producing artifacts at each step.

**Time Limit:** Steps 1-3: 5-10 minutes each. Steps 4-7: 10-20 minutes each.

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

1. **Three-state lifecycle** — every step: `pending → produced → verified`. Next step requires previous `verified`
2. **Trust artifacts, not prompts** — each step reads ONLY the previous step's artifact file, never re-derives from source
3. **Deterministic gates over LLM review** — Gate 2 (grep dry-run) and Gate 3 (enabling point check) are automated, zero human involvement
4. **Session boundaries are mandatory** — STOP after Step 2 and Step 5. New session reads artifacts, not prior reasoning
5. **Step 2 must use /atlas.audit** — inline contract analysis is NOT acceptable. Check for `.sourceatlas/audit/` artifact
6. **Step 7 is a hard gate** — do NOT proceed to Step 8 until all tests pass
7. **Claude proposes, user decides** — Step 5 (interface design) is the only human decision point
8. **One module at a time** — do not batch-process multiple files
9. **Evidence-based** — every contract and seam references file:line with `verification_grep`
10. **Seam Interfaces are temporary** — label them clearly (see language-groups.md)

---

## Steps 8-13: Post-Tool Guidance

Steps 8-13 are **user-driven** without tool assistance. After Step 7 passes, output guidance:

| Step | Name | What to Do |
|------|------|-----------|
| 8 | Write New Implementation | Implement the interface with clean code |
| 9 | Swap Implementation | Replace adapter with new impl in injection site |
| 10 | Run Verification | Re-run Step 7 gate with new impl |
| 11 | Integration Testing | Test in broader system context |
| 12 | Clean Up | Remove adapter, Seam Interface → Target Interface |
| 13 | Delete Legacy | Remove old code, run full test suite |

> See [references/playbook-overview.md](references/playbook-overview.md) for the complete 13-step overview.

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
