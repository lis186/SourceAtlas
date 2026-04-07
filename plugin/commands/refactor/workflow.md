# Refactor Workflow

Complete step-by-step guide for executing the 13-step Playbook (Steps 1-7 tool-assisted).

---

## Initialization

### Parse Arguments

```bash
FILE_PATH=""
ZONE_ID=""
STEP=""
ZONES_ONLY=false
STATUS_ONLY=false
FORCE=false

for arg in $ARGUMENTS; do
    case "$arg" in
        --zone) NEXT_IS_ZONE=true ;;
        --step) NEXT_IS_STEP=true ;;
        --zones-only) ZONES_ONLY=true ;;
        --status) STATUS_ONLY=true ;;
        --force) FORCE=true ;;
        *)
            if [ "$NEXT_IS_ZONE" = true ]; then
                ZONE_ID="$arg"; NEXT_IS_ZONE=false
            elif [ "$NEXT_IS_STEP" = true ]; then
                STEP="$arg"; NEXT_IS_STEP=false
            else
                FILE_PATH="$arg"
            fi
            ;;
    esac
done
```

### No Arguments: Discovery Mode

If `$FILE_PATH` is empty and `--status` is not set, enter **Discovery Mode** — help the user find the best refactoring target.

#### Step A: Check In-Progress Refactors

```bash
# Check for existing state files
if ls .sourceatlas/refactor/*/state.yaml 1>/dev/null 2>&1; then
    # Show in-progress refactors with current step
    echo "🔄 In-progress refactors:"
    for state in .sourceatlas/refactor/*/state.yaml; do
        module=$(grep 'module:' "$state" | awk '{print $2}' | tr -d '"')
        step=$(grep 'current_step:' "$state" | awk '{print $2}')
        file=$(grep 'file:' "$state" | awk '{print $2}' | tr -d '"')
        echo "  - $module (Step $step/7): $file"
        echo "    Resume: /atlas.refactor $file"
    done
    echo ""
fi
```

#### Step B: Auto-Discover Candidates

Run the deterministic ranking script — no LLM, pure git log + wc:

```bash
PLUGIN_ATLAS=~/.claude/plugins/marketplaces/lis186-SourceAtlas/scripts/atlas
if [ -f ~/.claude/scripts/atlas/rank-candidates.sh ]; then
    RANK_SCRIPT=~/.claude/scripts/atlas/rank-candidates.sh
elif [ -f "$PLUGIN_ATLAS/rank-candidates.sh" ]; then
    RANK_SCRIPT="$PLUGIN_ATLAS/rank-candidates.sh"
elif [ -f plugin/commands/refactor/scripts/rank-candidates.sh ]; then
    RANK_SCRIPT=plugin/commands/refactor/scripts/rank-candidates.sh
else
    echo "❌ rank-candidates.sh not found — install SourceAtlas plugin or scripts to ~/.claude/scripts/atlas/"
    exit 1
fi
bash "$RANK_SCRIPT" .
# Output: .sourceatlas/refactor/candidates.json (cached 1 hour)
```

The script scores every source file as `commits_90d × lines`, filters to files >200 lines, and outputs a sorted JSON array. Read the result directly — **do not re-rank or re-filter**.

If the script fails (not a git repo, no source files), fall back to asking the user to specify a file directly.

#### Step C: Present Ranked Candidates

Read `candidates.json` and display top 5. **Use the script's rank order exactly** — do not re-rank. Add one sentence of qualitative context per candidate (why it's worth refactoring), but this is annotation only, not selection logic.

```
🔧 SourceAtlas: Refactor — Discovery Mode
───────────────────────────────────────────

🔄 In-progress (1):
  NYHTTPSClient (Step 3/7) — resume: /atlas.refactor NYCore/.../NYHTTPSClient.m

📊 Recommended targets (score = commits_90d × lines):

  #1 ⚡ NYHTTPSClient.m        score 39,574  │ 842 lines, 47 commits
     Group A (ObjC) │ audit ✅ cached │ seam ✅ cached
     Handles auth + network + retry — classic God Class.
     /atlas.refactor NYCore/NYCore/Classes/NYHTTPSClient.m

  #2   NYDataManager.swift     score 7,130   │ 310 lines, 23 commits
     Group A (Swift) │ no prior analysis
     /atlas.refactor NYCore/NYCore/Classes/NYDataManager.swift

  #3   api-gateway.ts          score 5,320   │ 280 lines, 19 commits
     Group B (TypeScript) │ audit ✅ cached
     /atlas.refactor src/services/api-gateway.ts

Select a target to begin, or run:
  /atlas.history           — full hotspot analysis
  /atlas.refactor --status — show all in-progress refactors
```

**Key DX principles**:
- Zero-arg = smart discovery, not help page
- Show resumable work first (respect user's existing investment)
- Every candidate has a copy-pasteable command
- Rank order comes from script, not LLM judgment
- Prior analysis is an asset, surface it ("audit ✅ cached" = head start)

After the user selects a target, proceed to Step 1 below.

### Language Detection

Same as `/atlas.audit` — detect from file extension or `detect-language.sh`.

### Language Group Classification

```
Group A (Nominal):    java, objc, kotlin, swift, rust
Group B (Structural): go, typescript
Group C (Dynamic):    javascript, python
```

> See [../seam/references/language-groups.md](../seam/references/language-groups.md) for full details.

### State Management

```bash
MODULE_NAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]')
STATE_DIR=".sourceatlas/refactor/${MODULE_NAME}"
STATE_FILE="${STATE_DIR}/state.yaml"

# Initialize state if not exists
if [ ! -f "$STATE_FILE" ]; then
    mkdir -p "$STATE_DIR"
    # Copy from templates/state.yaml and fill in values
fi

# If --status, display state and exit
# If --step N, set current_step = N and continue
# Otherwise, auto-detect current_step from state
```

### Step Status Lifecycle

Each step follows a **three-state lifecycle**:

```
pending → produced → verified
```

- **pending**: Not yet started
- **produced**: Artifact file exists in `.sourceatlas/refactor/{module}/`
- **verified**: Deterministic gate passed (or no gate required for this step)

**Rule: A step can only start when the previous step is `verified`.**

Steps without a deterministic gate transition directly from `produced` to `verified` (Steps 1, 2a, 4, 5, 6).

Steps WITH a deterministic gate require passing before reaching `verified`:
- **Step 2 (contracts)** → Gate 2: contract verification rules dry-run
- **Step 3 (seams)** → Gate 3: enabling point existence check
- **Step 7 (final)** → Gate 7: all tests + contract CI

### Session Boundaries

To prevent confirmation bias (same agent writing and verifying in one session), certain steps **force a session break**:

```yaml
session_boundaries: [2, 5]
```

After completing Step 2 (with gate), the workflow **stops** and outputs:

```
✅ Step 2 complete — contracts extracted and verified.
   {rules_passed}/{rules_total} verification rules passed.

⏸️ Session boundary — start a new session to continue:
   /atlas.refactor {file_path} --step 3

   Why: Step 3 (seam analysis) reads contracts as input.
   A fresh session prevents anchoring to Step 2's reasoning.
```

After completing Step 5 (interface, user-approved), the same pattern applies before Step 6.

This is automatic — the agent does NOT continue past a session boundary.

### File Hash Check

```bash
CURRENT_HASH=$(shasum -a 256 "$FILE_PATH" | cut -d' ' -f1)
SAVED_HASH=$(grep 'file_hash:' "$STATE_FILE" | awk '{print $2}' | tr -d '"')

if [ "$CURRENT_HASH" != "$SAVED_HASH" ] && [ -n "$SAVED_HASH" ]; then
    echo "⚠️ File has changed since last run"
    echo "Artifacts from previous steps may be stale"
    echo "Consider --force to re-run affected steps"
fi
```

---

## Step 1: Select Target

**Input**: File path from arguments
**Action**: Assess refactoring suitability using history + impact analysis
**Output**: `1_target.yaml`

### 1.1 Run History Analysis

Call `/atlas.history` on the target file to get:
- Change frequency (commits in last 6 months)
- Co-change partners (files that change together)
- Knowledge concentration (bus factor)

Read the cached result from `.sourceatlas/history/` if available.

### 1.2 Run Impact Analysis

Call `/atlas.impact` on the target file to get:
- Direct dependents (files that import/include this file)
- Transitive dependents (2nd-degree impact)
- Blast radius score

Read the cached result from `.sourceatlas/impact/` if available.

### 1.3 Assess Suitability

Read `candidates.json` for the score of this file (or compute inline if not cached):

```bash
LINES=$(wc -l < "$FILE_PATH" | tr -d ' ')
COMMITS=$(git log --oneline --since="$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d)" -- "$FILE_PATH" | wc -l | tr -d ' ')
SCORE=$(( LINES * COMMITS ))
```

Apply fixed thresholds to determine `recommendation` — **do not use LLM judgment**:

```
score > 10000  → proceed
score 3000-10000 → caution
score < 3000   → skip
```

Then read `/atlas.impact` output (or cache) to get `blast_radius`.

```yaml
# 1_target.yaml
module: "{module_name}"
file: "{file_path}"
language: "{language}"
language_group: "A|B|C"
line_count: {n}
suitability:
  commits_90d: {n}
  score: {commits_90d × lines}        # deterministic
  blast_radius: {n files}             # from /atlas.impact
  recommendation: "proceed|caution|skip"  # from fixed thresholds above
  reason: "{qualitative explanation}"     # LLM fills this only
history_ref: ".sourceatlas/history/{module}.yaml"
impact_ref: ".sourceatlas/impact/{module}.yaml"
```

**Decision**: If `recommendation: skip`, warn user but allow override with `--force`.

### 1.4 Update State

Set `1_target: { status: completed, completed_at: {now} }` and `current_step: 2`.

Lock the candidate selection so future runs do not re-rank:

```bash
sed -i '' "s/  locked: false/  locked: true/" "$STATE_FILE"
sed -i '' "s/  score: null/  score: $SCORE/" "$STATE_FILE"
sed -i '' "s/  locked_at: null/  locked_at: \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"/" "$STATE_FILE"
```

**Rule**: If `candidate_lock.locked: true` and `--force` is NOT passed, skip Step B and Step 1.1–1.3 entirely — jump directly to the current step. This prevents re-ranking from changing the target mid-refactor.

---

## Step 2: Inventory Contracts

**Input**: `1_target.yaml`
**Action**: Discover zones (2a) then extract contracts (2b)
**Output**: `2a_zones.yaml`, `2_contracts.yaml`

### Step 2a: Zone Discovery

If file has **200+ lines**:

1. Run `/atlas.seam {file_path}` (or read from `.sourceatlas/seam/` cache)
2. Save zone map as `2a_zones.yaml`
3. Present zones to user with priority ranking
4. **User selects a zone** (or pass `--zone <zone-id>`)

If file has **< 200 lines**:
- Skip 2a, treat entire file as one zone
- Set `zone_id: "full"` in state

If `--zones-only` was passed, **stop here** and display zones.

### Step 2b: Contract Extraction

Run `/atlas.audit {file_path} --zone {zone_id}` on the selected zone.

- If zone was selected, audit only those lines
- If no zone (small file), audit the entire file
- **IMPORTANT**: This MUST invoke the actual `/atlas.audit` command (which runs the multi-LLM pipeline: Gemini blind scan → Claude structured audit → Codex adversarial review). Do NOT perform inline contract analysis as a substitute.

Save result as `2_contracts.yaml`.

Record `audit_mode` in state:
- `full` — all three LLMs ran (gemini + codex available)
- `degraded` — one or more LLMs unavailable, Claude-only analysis

### 2.3 Verify: Check Audit Artifact

Before proceeding, verify the audit artifact exists and was produced by the pipeline:

```bash
AUDIT_FILE=".sourceatlas/audit/${MODULE_NAME}.yaml"
if [ ! -f "$AUDIT_FILE" ]; then
    echo "❌ Audit artifact not found: $AUDIT_FILE"
    echo "Step 2b requires /atlas.audit to produce this file."
    echo "Run: /atlas.audit $FILE_PATH --zone $ZONE_ID"
    exit 1
fi
```

Copy or symlink to `2_contracts.yaml`:
```bash
cp "$AUDIT_FILE" "${STATE_DIR}/2_contracts.yaml"
```

Set `2_contracts: { status: produced }`.

### Gate 2: Contract Verification Dry-Run

**Purpose**: Verify that contracts describe behaviors that actually exist in the code.
**Method**: Run each contract's verification rules (grep/ast-grep) against the source file.
**Equivalent to**: nineyiappshop Phase A Step 5 (self-verification dry-run).

**Execute the gate script** — this is a deterministic check, not an LLM judgment:

```bash
PLUGIN_ATLAS=~/.claude/plugins/marketplaces/lis186-SourceAtlas/scripts/atlas
if [ -f ~/.claude/scripts/atlas/gate-contracts.sh ]; then
    GATE_CONTRACTS=~/.claude/scripts/atlas/gate-contracts.sh
elif [ -f "$PLUGIN_ATLAS/gate-contracts.sh" ]; then
    GATE_CONTRACTS="$PLUGIN_ATLAS/gate-contracts.sh"
elif [ -f plugin/commands/refactor/scripts/gate-contracts.sh ]; then
    GATE_CONTRACTS=plugin/commands/refactor/scripts/gate-contracts.sh
else
    echo "❌ gate-contracts.sh not found — install SourceAtlas plugin or scripts to ~/.claude/scripts/atlas/"
    exit 1
fi
bash "$GATE_CONTRACTS" \
    "${STATE_DIR}/2_contracts.yaml" \
    "${STATE_DIR}"
```

The script:
1. Looks for an existing `verify-contracts-*.sh` from `/atlas.audit` pipeline output (gold standard)
2. Falls back to extracting `verification_grep` fields from the contracts YAML
3. Runs each rule against the source file
4. Updates `state.yaml` with `2_gate: { status: pass|fail, rules_total: N, rules_passed: N }`
5. Exits 0 (pass) or 1 (fail)

**Gate pass** (exit 0): ALL verification rules match → `2_contracts: { status: verified }`

**Gate fail** (exit 1): Any rule fails → stop, suggest re-running audit with `--force`.

**Degraded** (exit 0 with `status: degraded`): No verification rules found in contracts. Proceed with caution.

### 2.4 Session Boundary

After Gate 2 passes, **STOP**. Output session boundary message and do not continue to Step 3.

```
✅ Step 2 complete — {rules_passed}/{rules_total} contract rules verified.
   audit_mode: {full|degraded}

⏸️ Session boundary — start a new session to continue:
   /atlas.refactor {file_path} --step 3
```

Set `current_step: 3` in state, but do NOT execute Step 3 in this session.

---

## Step 3: Find Seams

**Input**: `2_contracts.yaml` (must be `verified`), `2a_zones.yaml` (if exists)
**Action**: Analyze dependencies and identify seam points
**Output**: `3_seams.yaml`

### 3.0 Prerequisite Check

Before starting, verify Step 2 artifacts exist and are verified:

```bash
if [ ! -f "${STATE_DIR}/2_contracts.yaml" ]; then
    echo "❌ Cannot start Step 3: 2_contracts.yaml not found"
    echo "Run: /atlas.refactor $FILE_PATH --step 2"
    exit 1
fi

# Check state — 2_contracts must be "verified" (gate passed)
CONTRACT_STATUS=$(grep -A1 '2_contracts:' "$STATE_FILE" | grep 'status:' | awk '{print $2}')
if [ "$CONTRACT_STATUS" != "verified" ]; then
    echo "❌ Cannot start Step 3: contracts not verified"
    echo "Gate 2 (contract dry-run) must pass first"
    echo "Run: /atlas.refactor $FILE_PATH --step 2"
    exit 1
fi

# Check LLM CLI availability (degraded mode if missing)
SEAM_DEGRADED=false
SEAM_MISSING=""
command -v gemini &>/dev/null || { SEAM_MISSING="$SEAM_MISSING gemini"; SEAM_DEGRADED=true; }
command -v codex  &>/dev/null || { SEAM_MISSING="$SEAM_MISSING codex";  SEAM_DEGRADED=true; }
[ "$SEAM_DEGRADED" = true ] && echo "⚠️ Seam analysis degraded mode: missing$SEAM_MISSING"
```

**Only read the artifact file. Do NOT re-derive contracts from source code.**

### 3.1 Build Dependency Graph

From the contracts, extract:
- **External dependencies**: Classes/modules/functions called by the target zone
- **Internal dependencies**: Methods within the zone that call each other
- **Shared state**: Global variables, singletons, class-level state

### 3.2a Gemini Blind Scan

> Skip if `SEAM_DEGRADED=true` — generate `.sourceatlas/refactor/{module}/3_seams_gemini_prompt.md` instead.

Gemini receives **only** the source file and `2_contracts.yaml` — **no** Feathers taxonomy, no language group table, no schema. Independence is the value.

Ask Gemini: "Find every external dependency boundary in this file — places where an external class, function, or global is used directly. List them with file:line evidence. Do not classify them."

Save Gemini output to `${STATE_DIR}/3_seams_gemini.md`.

### 3.2b Claude Structured Analysis (was 3.2)

With Gemini's blind scan in hand, evaluate each external dependency as a potential seam point:

**Group A (Nominal)**:
- Object Seam: Can we inject this dependency via constructor/init?
- Preprocessing Seam: Is there a `#ifdef` / `cfg()` / `@available` we can use?
- Enabling point: Constructor parameter, method parameter, or factory method

**Group B (Structural)**:
- Object Seam: Does the dependency expose methods that match a small interface?
- Module Seam (TS only): Can we `jest.mock` the import?
- Check: Does the legacy impl already satisfy a potential interface?
- Enabling point: Struct field (Go), constructor parameter (TS)

**Group C (Dynamic)**:
- Module Seam: Can we `jest.mock('./dep')` or `mock.patch('module.dep')`?
- Monkey-patch Seam: Can we override at runtime?
- Enabling point: Import statement, module-level reference

Also check Gemini's output for dependencies Claude might have missed — every item in Gemini's list that is not in Claude's candidates must be explicitly accounted for (incorporated or dismissed with reasoning).

Save Claude's draft candidates to `${STATE_DIR}/3_seams_claude_draft.md`.

### 3.2c Codex Adversarial Review

> Skip if `SEAM_DEGRADED=true` — generate `.sourceatlas/refactor/{module}/3_seams_codex_prompt.md` instead.

Codex receives: source file, `2_contracts.yaml`, Gemini blind scan, Claude's draft candidates.

Codex issues one verdict per candidate, and independently adds any missing:

| Verdict | Meaning |
|---------|---------|
| **CONFIRM** | Seam valid, enabling point exists, coverage claim accurate |
| **DISPUTE** | Seam type wrong, enabling point absent, or coverage overstated |
| **ADD** | Missing dependency or seam type |
| **FLAG** | Architectural issue seams cannot solve (e.g., shared mutable state) |

Save Codex output to `${STATE_DIR}/3_seams_codex.md`.

### 3.2d Claude Merge

Produce the final seam candidates:
1. **DISPUTED**: Re-evaluate — drop if Codex's objection holds, keep with explicit reasoning if not
2. **ADDED**: Incorporate with seam type classification + `verification_grep`
3. **FLAGGED**: Record in `seam_validation.architectural_concerns` — not candidates, structural issues

### 3.3 Rank and Recommend

Score each seam candidate:

```
feasibility = ease_of_injection × coverage_of_contracts × (1 / risk)
```

Present ranked list with recommended seam.

### 3.4 Output

Each seam candidate MUST include a `verification_grep` field — a grep/ast-grep command that proves the enabling point exists in source code.

```yaml
# 3_seams.yaml
module: "{module_name}"
zone_id: "{zone_id}"
language_group: "A|B|C"
dependencies:
  - name: "{dep_name}"
    type: "class|module|function|global"
    usage_count: {n}
    contracts_affected: ["C-001", "C-002"]
seam_candidates:
  - id: "{seam_id}"
    seam_type: "object|module|preprocessing|monkey_patch"
    target_dependency: "{dep_name}"
    enabling_point: "{description}"
    verification_grep: "grep -n '{pattern}' {file_path}"  # REQUIRED
    feasibility: {0-100}
    contracts_covered: ["C-001", "C-002"]
    risk: "{low|medium|high}"
    notes: "{language-specific notes}"
recommended_seam:
  seam_type: "{type}"
  target_dependency: "{dep_name}"
  enabling_point: "{description}"
  reason: "{why this is the best seam}"
seam_validation:
  mode: "full|degraded"
  gemini_candidates: {n}
  claude_candidates: {n}
  codex_confirmed: {n}
  codex_disputed: {n}
  codex_added: {n}
  codex_flagged: {n}
  architectural_concerns:
    - "{description of structural issue no seam can fix}"
```

Set `3_seams: { status: produced, seam_mode: full|degraded }`.

### Gate 3: Enabling Point Existence Check

**Purpose**: Verify that each seam candidate's enabling point actually exists in source code. Eliminates hallucinated seams.
**Method**: Run the `verification_grep` for each candidate.

**Execute the gate script**:

```bash
PLUGIN_ATLAS=~/.claude/plugins/marketplaces/lis186-SourceAtlas/scripts/atlas
if [ -f ~/.claude/scripts/atlas/gate-seams.sh ]; then
    GATE_SEAMS=~/.claude/scripts/atlas/gate-seams.sh
elif [ -f "$PLUGIN_ATLAS/gate-seams.sh" ]; then
    GATE_SEAMS="$PLUGIN_ATLAS/gate-seams.sh"
elif [ -f plugin/commands/refactor/scripts/gate-seams.sh ]; then
    GATE_SEAMS=plugin/commands/refactor/scripts/gate-seams.sh
else
    echo "❌ gate-seams.sh not found — install SourceAtlas plugin or scripts to ~/.claude/scripts/atlas/"
    exit 1
fi
bash "$GATE_SEAMS" \
    "${STATE_DIR}/3_seams.yaml" \
    "${STATE_DIR}"
```

The script:
1. Parses each `seam_candidate` from `3_seams.yaml`
2. Runs its `verification_grep` against the source file
3. Eliminates candidates whose enabling point doesn't exist
4. Updates `state.yaml` with `3_gate: { status: pass|fail, candidates_total: N, candidates_verified: N }`
5. Exits 0 (≥1 candidate verified) or 1 (zero verified)

**Gate pass** (exit 0): At least 1 candidate verified → auto-select highest-feasibility verified candidate as `recommended_seam`.

**Gate fail** (exit 1): Zero candidates verified → stop, suggest re-running Step 3 with `--force`.

Update state: `3_seams: { status: verified }`, `3_gate: { status: pass, candidates_total: N, candidates_verified: N }`

### 3.5 Update State

Set `current_step: 4`.

---

## Step 4: Record Behavior

**Input**: `3_seams.yaml` (must be `verified`), `2_contracts.yaml`
**Action**: Generate tests to capture current behavior
**Output**: `4_tests.{ext}`
**Gate**: Layer A spike tests must pass (runtime gate, not deterministic)

### 4.1 Determine Test Framework

| Language | Framework | File Extension |
|----------|-----------|----------------|
| ObjC | XCTest | `.m` |
| Swift | XCTest | `.swift` |
| TypeScript | Jest/Vitest | `.test.ts` |
| JavaScript | Jest/Vitest | `.test.js` |
| Go | go test | `_test.go` |
| Python | pytest | `test_{module}.py` |
| Java | JUnit 5 | `Test.java` |
| Kotlin | JUnit 5 | `Test.kt` |
| Rust | `#[cfg(test)]` | (inline in `.rs`) |

Auto-detect the project's test framework by scanning for existing test files and config (`jest.config`, `pytest.ini`, `go.mod`, etc.).

### 4.2 Generate Layer A: Spike Tests

Spike tests verify the code **runs** without crashing. Zero behavioral assertions.

```
For each contract in 2_contracts.yaml:
    Generate a test that:
    1. Creates an instance of the target class/module
    2. Calls the method referenced in the contract
    3. Asserts nothing (or assert "did not throw")
```

These tests use **real dependencies** (no mocks). They are the first safety net.

### 4.3 Generate Layer B: Characterization Test Skeletons

Characterization tests capture **actual behavior**. They need the interface from Step 5 to mock dependencies.

```
For each contract in 2_contracts.yaml:
    Generate a test skeleton with:
    1. TODO: Set up mock for {dependency} using {seam_type}
    2. Call the method
    3. TODO: Assert actual behavior (fill in after running)
```

Mark these as **skipped/pending** — they cannot run until Step 5+6 provide the mock infrastructure.

### 4.4 Gate: Run Spike Tests

```bash
# Run only Layer A tests
# Language-specific command:
# ObjC:  xcodebuild test -only-testing:{SpikeTestClass}
# Swift: swift test --filter Spike
# TS/JS: jest --testPathPattern spike
# Go:    go test -run TestSpike
# Python: pytest -k spike
# Java:  mvn test -Dtest=SpikeTest
# Rust:  cargo test spike
```

**If spike tests pass**: Proceed to Step 5.
**If spike tests fail**: The code has a setup issue (missing deps, broken build). Fix before continuing. Do NOT proceed.

### 4.5 Update State

Set `4_tests: { status: verified }` (spike tests passing = verified), `current_step: 5`.

---

## Step 5: Define Interface — User Decision Point

**Input**: `2_contracts.yaml`, `3_seams.yaml`
**Action**: Propose a Seam Interface for the recommended seam
**Output**: `5_interface.{ext}` or `5_message_contract.md`

> **This is the key design decision.** Claude proposes, user reviews and modifies.

### 5.0 Prerequisite Checklist

Before designing the interface, read these artifacts and extract the listed fields. **Do not proceed if any required input is missing.**

#### Inputs (must read)

| Source | Fields to Extract | Why |
|--------|-------------------|-----|
| `3_seams.yaml` → `recommended_seam` | `seam_type`, `enabling_point`, `target_dependency` | Determines what the interface wraps |
| `3_seams.yaml` → `seam_candidates[recommended].codex_note` | Parameter requirements, disputed items | Codex may impose constraints on method signature |
| `2_contracts.yaml` → contracts matching `recommended_seam.contracts_covered` | `trigger`, `input`, `output`, `ordering` | Method parameters derive from these |
| Target file header (`.h` / class declaration) | Existing API style, naming conventions, init methods | Interface must match codebase conventions (Group A/B only; Group C skip) |
| `1_target.yaml` → `language`, `language_group` | Language group for dispatch | Determines Group A/B/C path |

#### Outputs (must produce)

| Artifact | Required For | Group |
|----------|-------------|-------|
| Interface/protocol file (`5_interface.{ext}`) | Step 6 adapter implementation | A, B |
| Message contract (`5_message_contract.md`) | Step 6 mock setup | C |
| `5_interface.yaml` | State tracking, Step 12 migration | All |
| Updated `state.yaml` | Progress tracking | All |

#### Validation (must confirm before presenting to user)

- [ ] Protocol parameters cover **all** fields required by Codex verdict
- [ ] At least one enabling point (init/constructor parameter) declared in target header
- [ ] Every contract in `recommended_seam.contracts_covered` is mapped to either: a method on the protocol, OR a concrete interceptor/conformer
- [ ] Layer B test skeletons (from `4_tests`) reference the protocol name — verify with: `grep -l '{ProtocolName}' {test_file}`
- [ ] `migration_type` determined (same-language or cross-language)

### 5.1 Map Contracts to Interface Methods

For the recommended seam from Step 3:

1. Identify all contracts that touch the target dependency
2. Group related contracts that could map to a single method
3. Define method signatures based on contract triggers and inputs

### 5.2 Language Group Dispatch

#### 5.2.0 Cross-Language Migration Check

Before generating the interface, determine the **migration type**:

```
source_language = language of the target file (from 1_target.yaml)
target_language = language of the new implementation (if known)
```

| Migration Type | Condition | Seam Interface | Target Interface |
|---------------|-----------|----------------|------------------|
| **same-language** | source == target (or target unknown) | Written in source language. Evolves to Target in Step 12. | Same file, renamed in Step 12. |
| **cross-language** | source ≠ target (e.g., ObjC→Swift, Java→Kotlin, JS→TS) | Written in **source language** (must be callable from target file). | Written in **target language** (may already exist or be designed separately). |

**Cross-language rules:**

1. **Seam Interface** = temporary bridge in the source language. It enables dependency injection in the *existing* code without rewriting it. Named with `Legacy` or source-language convention (e.g., `@protocol NYPostResponseInterceptor` for ObjC).
2. **Target Interface** = permanent API in the target language. If it already exists (e.g., a Swift protocol was designed earlier), reference it in `5_interface.yaml` under `target_interface_ref`. Do not duplicate it.
3. **Parameter mapping** between the two must be documented in `5_interface.yaml` under `target_alignment` block. Each Seam parameter maps to a Target parameter (name, type, semantic equivalence). This is Step 12's migration spec — without it, Step 12 cannot mechanically replace Seam with Target.
4. **Common cross-language pairs:**
   - ObjC → Swift: ObjC `@protocol` (Seam) → Swift `protocol` (Target)
   - Java → Kotlin: Java `interface` (Seam) → Kotlin `interface` (Target)
   - JavaScript → TypeScript: No Seam Interface needed (TS is a superset); use TS `interface` directly
   - Go, Rust, Python: Cross-language migration uncommon; if needed, apply the same Seam/Target split
5. **Step 12 contract**: When `migration_type: cross-language`, Step 12 must:
   - Delete the Seam Interface file (source language)
   - Migrate all conformers to the Target Interface (target language)
   - Update all injection sites to use the Target type
   - The `target_alignment` block tells Step 12 exactly which parameters map where

Record in state:

```yaml
5_interface:
  status: produced
  migration_type: "same-language|cross-language"
  source_language: "{lang}"
  target_language: "{lang|null}"
  target_interface_ref: "{path to existing target interface file|null}"
```

If `migration_type: same-language`, proceed to Group A/B/C dispatch below as normal.
If `migration_type: cross-language`, apply Group A/B/C dispatch for the **source language**, then document the target mapping.

#### Group A (Nominal): Full Interface File

Generate a complete interface/protocol/trait:

```
// ObjC: @protocol {Name}Protocol
// Swift: protocol {Name}Protocol
// Java: interface I{Name}
// Kotlin: interface I{Name}
// Rust: trait {Name}
```

**Determine the interface mode** from `3_seams.yaml` → `recommended_seam`:

##### Mode 1: Direct Interface (default)

**When**: `recommended_seam.target_dependency` names a **single** dependency (e.g., inject a `DatabaseClient` protocol instead of a concrete `MySQLClient`). This is the standard Feathers Object Seam.

- One method per contract group
- Clear parameter types derived from contract inputs
- Return types derived from contract outputs
- Error handling strategy (throws/Result/NSError)

##### Mode 2: Interceptor Chain

**When**: The seam replaces a **cluster of side effects** with an ordered array of interceptors (e.g., post-response notification + shop-id check + logout = three interceptors behind one protocol).

**How to detect**: `recommended_seam.target_dependency` contains multiple dependencies joined by `+` or describes a "cluster" / "chain".

- **Single method** on the protocol — all interceptors share the same signature
- Parameters derived from the **call-site context** (e.g., completion handler parameters), not from individual contracts
- Contracts are covered by **concrete interceptor conformers**, not by protocol methods
- Execution order guaranteed by `NSArray` / `List` / `Vec` insertion order at injection time
- Document which concrete interceptor covers which contracts in `5_interface.yaml` → `execution_order`

**Decision rule**: If `recommended_seam.contracts_covered` spans 3+ different categories (e.g., N + L + M), it is almost certainly Mode 2.

**Common for both modes**:
- Comment: `// Seam Interface (temporary) — will evolve to Target Interface`

#### Group B (Structural): Small Interface

Generate a minimal interface (1-2 methods per Pike's principle):

```
// Go: type {Name} interface { Method() }
// TS: interface I{Name} { method(): ReturnType }
```

Then check: does the legacy implementation already satisfy this interface?
- **Go**: Compare method set. If legacy struct has all required methods → no adapter needed (note in output).
- **TypeScript**: Compare method signatures. If class already matches → no adapter needed.

If already satisfied, note it — Step 6 can be skipped.

#### Group C (Dynamic): Message Contract

Do NOT generate an interface file. Instead, output a message contract document:

```markdown
# Message Contract: {dependency_name}

## Messages (methods the zone sends to this dependency)

| Message | Arguments | Returns | Contract IDs |
|---------|-----------|---------|--------------|
| encrypt(data) | Buffer | Buffer | C-001, C-002 |
| verify(token) | string | boolean | C-003 |

## Mock Guidance

### Jest (JavaScript)
jest.mock('./crypto-module', () => ({
  encrypt: jest.fn().mockReturnValue(Buffer.from('...')),
  verify: jest.fn().mockReturnValue(true),
}));

### pytest (Python)
@mock.patch('module.crypto.encrypt', return_value=b'...')
@mock.patch('module.crypto.verify', return_value=True)
```

### 5.3 Build Verification (Group A/B only)

Before presenting to the user, verify the generated interface file compiles:

```bash
# Language-specific build check:
# ObjC/Swift: xcodebuild build -workspace *.xcworkspace -scheme {scheme} 2>&1 | tail -5
# Java/Kotlin: ./gradlew compileDebugJavaWithJavac 2>&1 | tail -5
# Go:          go build ./...
# TypeScript:  npx tsc --noEmit
# Rust:        cargo check
```

**If build fails**: Fix the interface file before presenting. Common issues:
- Missing import/include for parameter types
- Incorrect nullability annotations
- Naming conflicts with existing declarations

**If no build system** (Group C, or project not buildable): Skip this check and note it in `5_interface.yaml`.

### 5.4 Present to User

Display the proposed interface with:
- Method list and rationale (which contracts map to which methods)
- Trade-offs considered
- Ask user to review, modify, and confirm

**Wait for user confirmation before proceeding.**

### 5.5 Output Artifact: `5_interface.yaml`

```yaml
# 5_interface.yaml
module: "{module_name}"
zone_id: "{zone_id}"
language_group: "A|B|C"
seam_id: "{from recommended_seam}"
migration_type: "same-language|cross-language"

interface_type: "objc_protocol|swift_protocol|java_interface|kotlin_interface|rust_trait|go_interface|ts_interface|message_contract"
interface_file: "{path to generated file}"
interface_mode: "direct|interceptor_chain"  # Group A only

protocol:
  name: "{ProtocolName}"
  methods:
    - selector: "{method signature}"
      parameters:
        - { name: "{name}", type: "{type}", purpose: "{contract reference}" }
      return: "{type}"

# Group A Mode 2 only:
execution_order:
  - { position: 1, interceptor: "{Name}", contracts: ["C-001"] }

# Cross-language only (omit entirely for same-language):
target_alignment:
  target_protocol: "{TargetProtocolName} ({file path})"
  mapping:
    - seam_param: "{ObjC param name and type}"
      target_param: "{Swift param name and type}"
      semantic: "{equivalent|narrowed|widened}"
  migration_steps:
    - "Rewrite each ObjC conformer in target language"
    - "Update injection site to use target type"
    - "Delete Seam Interface file"

contracts_covered:
  direct: ["C-001"]           # covered by protocol methods
  via_conformers: ["C-002"]   # covered by concrete interceptors (Mode 2)
  not_covered: ["C-003"]
  not_covered_reason: "{why}"
```

### 5.6 Update State

Set `5_interface: { status: verified, migration_type: same-language|cross-language }` (user approval = verified), `current_step: 6`.

If `cross-language`, also set `target_interface_ref` and `target_language` in state.

### 5.7 Session Boundary

After user approves the interface, **STOP**. Output session boundary message.

```
✅ Step 5 complete — interface approved by user.

⏸️ Session boundary — start a new session to continue:
   /atlas.refactor {file_path} --step 6
```

This prevents the adapter (Step 6) from being generated by the same agent that proposed the interface. A fresh session reads only the approved artifact.

---

## Step 6: Legacy Adapter

**Input**: `5_interface.{ext}`, `3_seams.yaml`
**Action**: Create adapter bridging legacy code to new interface
**Output**: `6_adapter.{ext}`, `6_diff.patch`

### 6.1 Language Group Dispatch

#### Group A (Nominal): Adapter Class

Generate an adapter class that:
1. Implements/conforms to the Seam Interface from Step 5
2. Holds a reference to the legacy class/module
3. Delegates each interface method to the corresponding legacy method
4. Handles any type/error translation

```
// ObjC: @interface Legacy{Name}Adapter : NSObject <{Name}Protocol>
// Swift: class Legacy{Name}Adapter: {Name}Protocol
// Java: class Legacy{Name}Adapter implements I{Name}
// Kotlin: class Legacy{Name}Adapter : I{Name}
// Rust: struct Legacy{Name}Adapter; impl {Name} for Legacy{Name}Adapter
```

Also generate a **minimal diff** (`6_diff.patch`) showing:
- Adding the interface import/include
- Adding a constructor/init parameter for the interface
- Replacing direct dependency usage with interface calls

#### Group B (Structural): Conditional Adapter

First, check if the legacy impl already satisfies the interface (noted in Step 5):
- **If yes**: No adapter needed. Generate only `6_diff.patch` showing the constructor parameter addition.
- **If no**: Generate a thin adapter similar to Group A, plus `6_diff.patch`.

For Go: If adapter is needed, warn — the interface may be too broad (Pike's principle).

#### Group C (Dynamic): Mock Setup Code

No adapter class. Instead, generate the mock setup code for the test framework:

```javascript
// 6_adapter.js — Jest mock setup
jest.mock('./crypto-module', () => ({
  encrypt: jest.fn(),
  verify: jest.fn(),
}));

// Helper to configure mock behavior
function setupCryptoMock({ encryptResult, verifyResult }) {
  const crypto = require('./crypto-module');
  crypto.encrypt.mockReturnValue(encryptResult);
  crypto.verify.mockReturnValue(verifyResult);
}
```

```python
# 6_adapter.py — pytest mock setup
import pytest
from unittest import mock

@pytest.fixture
def crypto_mock():
    with mock.patch('module.crypto') as m:
        m.encrypt.return_value = b'encrypted'
        m.verify.return_value = True
        yield m
```

### 6.2 Update State

Set `6_adapter: { status: verified }` (no deterministic gate, produced = verified), `current_step: 7`.

---

## Step 7: Verification Gate — Hard Gate

**Input**: All artifacts from Steps 1-6
**Action**: Run the complete safety net
**Output**: `7_gate_results.yaml`
**Gate**: **ALL checks must pass**

### 7.1 Run Spike Tests (Layer A)

Re-run the spike tests from Step 4. They should still pass (we haven't changed production code yet, only added test files and interface/adapter).

### 7.2 Run Characterization Tests (Layer B)

Now that the interface and adapter/mock exist, the characterization test skeletons from Step 4 can be completed and run:

1. Update Layer B tests to use the adapter (Group A/B) or mock setup (Group C)
2. Run the tests
3. Capture actual outputs as assertions (characterization)

### 7.3 Run Contract CI Rules

From `2_contracts.yaml`, run the grep/ast-grep verification rules:

```bash
# For each contract with a verification rule:
# Run the grep/ast-grep command
# Check exit code
```

### 7.4 Compile Results

```yaml
# 7_gate_results.yaml
module: "{module_name}"
zone_id: "{zone_id}"
timestamp: "{iso_date}"
checks:
  spike_tests:
    status: "pass|fail"
    total: {n}
    passed: {n}
    failed: {n}
    failures: []
  characterization_tests:
    status: "pass|fail"
    total: {n}
    passed: {n}
    failed: {n}
    failures: []
  contract_rules:
    status: "pass|fail"
    total: {n}
    passed: {n}
    failed: {n}
    failures: []
overall: "pass|fail"
```

### 7.5 Gate Decision

**If ALL pass** (`overall: pass`):
- Print: "Safety net is in place. You are ready for Step 8."
- Output Steps 8-13 guidance (from [references/playbook-overview.md](references/playbook-overview.md))
- Suggest: "Next: Write the new implementation of the interface"

**If ANY fail** (`overall: fail`):
- Print which checks failed with details
- Do NOT suggest proceeding
- Suggest fixes for each failure
- User must fix and re-run Step 7

### 7.6 Update State

Set `7_gate: { status: verified }` (only if passed), `current_step: 8`.

---

## Error Handling

### File Not Found

```bash
echo "File not found: $FILE_PATH"
echo "Did you mean one of these?"
find . -name "*$(basename "$FILE_PATH" .${FILE_PATH##*.})*" -type f \
    | grep -v node_modules | grep -v .git | head -5
```

### Missing Previous Artifact

```
Cannot execute Step {N}: previous step not verified.
Expected: .sourceatlas/refactor/{module}/{artifact_name} with status: verified

Run: /atlas.refactor {file} --step {N-1}
```

### Gate 2 Failure (Contract Dry-Run)

```
Gate 2 FAILED — {rules_passed}/{rules_total} verification rules passed.

Failed rules:
- grep -n 'aesEncryptWithData:' NYHTTPSClient.m  (contract M15)
- grep -n 'hmacSha512:' NYHTTPSClient.m  (contract M16)

This means these contracts describe behaviors not found in source code.
The contracts may be hallucinated or the source file has changed.

Fix: /atlas.audit {file} --zone {zone_id} --force
Then: /atlas.refactor {file} --step 2
```

### Gate 3 Failure (Enabling Point Check)

```
Gate 3 FAILED — 0/{n} seam candidates have verifiable enabling points.

Eliminated:
- Object Seam (CocoaSecurity): grep found no constructor injection point
- Module Seam (dispatch_semaphore): no import statement to mock

This likely means the seam analysis hallucinated enabling points.

Fix: /atlas.refactor {file} --step 3 --force
```

### Step 7 Gate Failure

Do NOT auto-proceed. Display:
```
Gate FAILED — safety net is not complete.

Failures:
- {check_name}: {details}

Suggested fixes:
- {fix_1}
- {fix_2}

Re-run: /atlas.refactor {file} --step 7
```
