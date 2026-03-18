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

Combine history + impact to assess:

```yaml
# 1_target.yaml
module: "{module_name}"
file: "{file_path}"
language: "{language}"
language_group: "A|B|C"
line_count: {n}
suitability:
  change_frequency: {high|medium|low}
  coupling_score: {0-100}
  blast_radius: {n files}
  recommendation: "proceed|caution|skip"
  reason: "{why}"
history_ref: ".sourceatlas/history/{module}.yaml"
impact_ref: ".sourceatlas/impact/{module}.yaml"
```

**Decision**: If `recommendation: skip`, warn user but allow override with `--force`.

### 1.4 Update State

Set `1_target: { status: completed, completed_at: {now} }` and `current_step: 2`.

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

Save result as `2_contracts.yaml`.

### 2.3 Update State

Set `2a_zones`, `2_contracts` to completed. Set `zone_id` in state. Set `current_step: 3`.

---

## Step 3: Find Seams

**Input**: `2_contracts.yaml`, `2a_zones.yaml` (if exists)
**Action**: Analyze dependencies and identify seam points
**Output**: `3_seams.yaml`

### 3.1 Build Dependency Graph

From the contracts, extract:
- **External dependencies**: Classes/modules/functions called by the target zone
- **Internal dependencies**: Methods within the zone that call each other
- **Shared state**: Global variables, singletons, class-level state

### 3.2 Identify Seam Candidates

For each external dependency, evaluate as a potential seam point:

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

### 3.3 Rank and Recommend

Score each seam candidate:

```
feasibility = ease_of_injection × coverage_of_contracts × (1 / risk)
```

Present ranked list with recommended seam.

### 3.4 Output

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
  - seam_type: "object|module|preprocessing|monkey_patch"
    target_dependency: "{dep_name}"
    enabling_point: "{description}"
    feasibility: {0-100}
    contracts_covered: ["C-001", "C-002"]
    risk: "{low|medium|high}"
    notes: "{language-specific notes}"
recommended_seam:
  seam_type: "{type}"
  target_dependency: "{dep_name}"
  enabling_point: "{description}"
  reason: "{why this is the best seam}"
```

### 3.5 Update State

Set `3_seams: { status: completed }`, `current_step: 4`.

---

## Step 4: Record Behavior

**Input**: `3_seams.yaml`, `2_contracts.yaml`
**Action**: Generate tests to capture current behavior
**Output**: `4_tests.{ext}`
**Gate**: Layer A spike tests must pass

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

Set `4_tests: { status: completed }`, `current_step: 5`.

---

## Step 5: Define Interface — User Decision Point

**Input**: `2_contracts.yaml`, `3_seams.yaml`
**Action**: Propose a Seam Interface for the recommended seam
**Output**: `5_interface.{ext}` or `5_message_contract.md`

> **This is the key design decision.** Claude proposes, user reviews and modifies.

### 5.1 Map Contracts to Interface Methods

For the recommended seam from Step 3:

1. Identify all contracts that touch the target dependency
2. Group related contracts that could map to a single method
3. Define method signatures based on contract triggers and inputs

### 5.2 Language Group Dispatch

#### Group A (Nominal): Full Interface File

Generate a complete interface/protocol/trait:

```
// ObjC: @protocol {Name}Protocol
// Swift: protocol {Name}Protocol
// Java: interface I{Name}
// Kotlin: interface I{Name}
// Rust: trait {Name}
```

Include:
- One method per contract group
- Clear parameter types derived from contract inputs
- Return types derived from contract outputs
- Error handling strategy (throws/Result/NSError)
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

### 5.3 Present to User

Display the proposed interface with:
- Method list and rationale (which contracts map to which methods)
- Trade-offs considered
- Ask user to review, modify, and confirm

**Wait for user confirmation before proceeding.**

### 5.4 Update State

Set `5_interface: { status: completed }`, `current_step: 6`.

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

Set `6_adapter: { status: completed }`, `current_step: 7`.

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

Set `7_gate: { status: completed }` (only if passed), `current_step: 8`.

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
Cannot execute Step {N}: artifact from Step {N-1} not found.
Expected: .sourceatlas/refactor/{module}/{artifact_name}

Run: /atlas.refactor {file} --step {N-1}
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
