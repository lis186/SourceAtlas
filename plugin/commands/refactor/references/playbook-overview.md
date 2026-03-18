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

> Tools step back. These steps require human judgment and project-specific decisions.

### Step 8: Write New Implementation
Write a clean implementation of the Seam Interface defined in Step 5. This is where you design the Target Interface (the permanent API) and implement it.

**Guidance**:
- Start with the simplest implementation that passes characterization tests
- The new impl should be independently testable (no legacy dependencies)
- Write unit tests for the new impl alongside the code

### Step 9: Swap Implementation
Replace the Legacy Adapter (Step 6) with the new implementation at the injection site.

**Guidance**:
- Change only the wiring (constructor parameter, dependency injection)
- The adapter served its purpose — remove it
- Run Step 7 gate again to verify the swap

### Step 10: Run Verification
Re-run the Step 7 verification gate with the new implementation in place.

**Guidance**:
- All spike tests should still pass
- All characterization tests should still pass (behavior preserved)
- Contract CI rules should still pass
- If anything fails, the new implementation has a behavioral difference — investigate

### Step 11: Integration Testing
Test the new implementation in the broader system context.

**Guidance**:
- Run the full application test suite
- Manual smoke test critical user flows
- Check for performance regressions
- Verify cross-module interactions

### Step 12: Clean Up
Remove temporary scaffolding and evolve Seam Interface to Target Interface.

**Guidance**:
- Delete the Legacy Adapter class (no longer needed)
- Rename Seam Interface to Target Interface (or replace with clean design)
- Remove any temporary test helpers or mocks
- Update import paths and references

### Step 13: Delete Legacy Code
Remove the original God Class or legacy module.

**Guidance**:
- Verify no remaining references to the old code
- Run full test suite one final time
- Commit the deletion as a separate, clearly labeled change
- Celebrate — the migration is complete
