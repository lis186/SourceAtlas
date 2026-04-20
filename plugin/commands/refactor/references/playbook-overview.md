# 13-Step Legacy Code Migration Playbook

Based on Michael Feathers' *Working Effectively with Legacy Code*.

Steps 1-7 are **tool-assisted** by `/atlas.refactor`. Steps 8-13 are **user-driven**.

---

## Phase I: Build the Safety Net (Steps 1-7) — Tool-Assisted

### Step 1: Select Target
**Input**: Codebase
**Action**: Identify the module to refactor using git hotspot analysis and impact assessment.
**Tool**: `/atlas.history` (hotspots, co-change) + `/atlas.impact` (blast radius)
**Output**: `1_target.yaml` — target file, change frequency, coupling score, risk assessment.

### Step 2: Inventory Contracts
**Input**: Target file
**Action**: For large files (200+ lines), first discover responsibility zones, then extract behavioral contracts for the chosen zone.
**Tool**: `/atlas.seam` (Step 2a: zone discovery) + `/atlas.audit --zone` (contract extraction)
**Output**: `2a_zones.yaml` (zone map), `2_contracts.yaml` (behavioral contracts with M/L/N/S/E/C/D/P taxonomy)

### Step 3: Find Seams
**Input**: Contracts from Step 2
**Action**: Analyze dependencies to identify seam points — places where behavior can be altered without editing the source.
**Tool**: Dependency graph analysis, language-group-specific seam identification
**Output**: `3_seams.yaml` — dependency graph, seam candidates ranked by feasibility, recommended seam with enabling point.

### Step 4: Record Behavior
**Input**: Seams from Step 3
**Action**: Generate tests that capture current behavior before any changes.
**Tool**: Language-specific test framework generation
**Output**: `4_tests.{ext}` — Layer A (spike tests, zero-assertion, verify code runs) + Layer B (characterization test skeletons, need Step 5 interface to mock).
**Gate**: Layer A spike tests must pass (green).

### Step 5: Define Interface — User Decision Point
**Input**: Contracts + seams from Steps 2-3
**Action**: Propose a Seam Interface based on the behavioral contracts.
**Tool**: Language-group dispatch:
- **Group A** (Java, ObjC, Kotlin, Swift, Rust): Generate full interface/protocol/trait file
- **Group B** (Go, TypeScript): Generate small interface (1-2 methods, Pike's principle), check if already satisfied
- **Group C** (JavaScript, Python): Output message contract + mock guidance (no interface file)
**Output**: `5_interface.{ext}` or `5_message_contract.md`
**Gate**: User reviews and approves the interface design.

### Step 6: Legacy Adapter
**Input**: Interface from Step 5
**Action**: Create a thin adapter that makes the old implementation satisfy the new interface.
**Tool**: Language-group dispatch:
- **Group A**: Generate adapter class implementing the interface, delegating to legacy code + minimal diff on original file
- **Group B**: Check if legacy impl already satisfies interface implicitly → only generate adapter if needed
- **Group C**: Generate mock setup code (`jest.mock` / `mock.patch`) — no adapter class needed
**Output**: `6_adapter.{ext}`, `6_diff.patch`

### Step 7: Verification Gate — Hard Gate
**Input**: All artifacts from Steps 1-6
**Action**: Run the complete safety net to verify nothing is broken.
**Checks**:
1. Layer A spike tests (from Step 4) — pass?
2. Characterization tests with mock/adapter (from Steps 4+5+6) — pass?
3. Contract CI rules (grep/ast-grep assertions from Step 2) — pass?
**Output**: `7_gate_results.yaml`
**Gate**: **ALL checks must pass.** Do not proceed until green.

---

## Phase II: Extract and Replace (Steps 8-13) — User-Driven

> Tools step back. You execute these steps — each one names what to start from, what to do, and how to know it's done.

### Step 8: Write New Implementation

**Start from**: `5_interface.{ext}` (approved Seam Interface) + `4_tests.{ext}` (characterization tests)

**Do**:
- [ ] Create a new file implementing the Seam Interface — pick the permanent class/module name now (this becomes the Target Interface in Step 12)
- [ ] No imports from the legacy file (the new impl must stand alone)
- [ ] Inject collaborators via constructor / parameters — no globals, no singletons
- [ ] Write unit tests alongside the new code (characterization tests cover behavior, unit tests cover the new structure)

**Done when**: New file compiles, unit tests green, characterization tests still green, `grep -l "<LegacyClass>" <new-file>` returns no hits.

### Step 9: Swap Implementation

**Start from**: New impl from Step 8 + `3_seams.yaml` (the chosen `enabling_point`)

**Do**:
- [ ] Open the injection site at `3_seams.yaml.recommended.enabling_point`
- [ ] Replace the `LegacyAdapter` (or equivalent) with the new impl at that ONE line
- [ ] Do not modify any other file in this commit
- [ ] Commit as `refactor: swap LegacyAdapter → NewImpl at <enabling_point>`

**Done when**: A single-file, single-line wiring change is committed and characterization tests still pass.

### Step 10: Run Verification

**Start from**: Swapped code from Step 9 + `7_gate_results.yaml` (baseline from Step 7)

**Do**:
- [ ] Re-run `gate-step7.sh` (or the project equivalent)
- [ ] Compare each section against `7_gate_results.yaml`: spike tests (Layer A), characterization tests (Layer B), contract CI rules
- [ ] If anything regresses, the new impl has a behavioral difference — DO NOT proceed; diagnose and fix

**Done when**: New gate output matches the baseline 1:1 — same passes, same counts, no new failures.

### Step 11: Integration Testing

**Start from**: Verified swap from Step 10

**Do**:
- [ ] Run the full application test suite (`xcodebuild test`, `pytest`, `go test ./...`, etc.)
- [ ] Manual smoke: walk through every user-facing flow that touches this module
- [ ] Check for performance regressions on the module's hot paths (latency, memory, allocation count)
- [ ] Verify cross-module interactions — anything that called the legacy module should still work

**Done when**: Full suite green, manual smoke flows pass, no perf regression flagged.

### Step 12: Clean Up

**Start from**: Integrated swap from Step 11

**Do**:
- [ ] Delete `6_adapter.{ext}` and any adapter class it defined — it has no callers now
- [ ] If the new impl was named with a temporary "Seam" prefix/suffix, rename it to its final Target Interface name
- [ ] Delete temporary test helpers, mocks, or shims introduced solely for the swap
- [ ] Update all imports / re-exports / barrel files that referenced the old or temporary names

**Done when**: `grep -r "<AdapterName>" .` and `grep -r "<TemporarySeamName>" .` both return zero hits, full test suite still green.

### Step 13: Delete Legacy Code

**Start from**: Cleaned codebase from Step 12

**Do**:
- [ ] Run `grep -r "<LegacyClassName>" .` — confirm zero remaining references
- [ ] Delete the legacy file(s) and any helper files only it used
- [ ] Run the full test suite one final time
- [ ] Commit as a single dedicated change: `chore: remove legacy <name> (replaced by <new-name>)`

**Done when**: Legacy file no longer exists, full suite green, the deletion is its own commit (not bundled with refactor work).
