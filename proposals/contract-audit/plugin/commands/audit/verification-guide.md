# Audit Self-Verification Guide

Complete verification checklist for behavioral contract audit output.

---

## When to Verify

Execute **after generating YAML output, before saving** to `.sourceatlas/audit/{module}.yaml`.

---

## Purpose

Ensure all contracts have valid evidence references, correct IDs, complete metadata, and pass all quality gates defined in the skeleton prompt.

---

## Verification Steps

### Step V1: Extract Verifiable Claims

After generating the YAML output, extract all verifiable claims.

**Claim Types to Extract:**

| Type | YAML Path | Verification Method |
|------|-----------|---------------------|
| **Evidence File** | `contracts[].evidence[].file` | `test -f path` |
| **Evidence Line** | `contracts[].evidence[].line` | Line exists in file |
| **Contract ID** | `contracts[].id` | Matches `^[MLNSECDP]-[0-9]{3}$` |
| **Contract Count** | `total_contracts` | Equals `contracts` array length |
| **Pinch Point Count** | `pinch_points` | Equals count of `pinch_point: true` |
| **CONFIRM Ratio** | `adversary_summary.confirm_ratio` | Equals `confirm_count / (confirm + dispute + add)` |
| **Language** | `language` | Matches detected language |

---

### Step V2: Quality Gates Verification

Run **ALL** 10 quality gates from the skeleton prompt.

#### Gate 1: Every Contract Has Evidence

```bash
# Verify all evidence files exist
for file in [all evidence file paths]; do
    if [ ! -f "$file" ]; then
        echo "FAIL [Gate 1]: Evidence file not found: $file"
    fi
done
```

**Check:**
- Every `contracts[].evidence[]` has at least one `file:line` reference
- The referenced file exists
- The referenced line number is within the file's line count

#### Gate 2: No Unsourced Inferences

**Check:**
- Every contract has `evidence` array with `minItems: 1`
- No contract description claims behavior without a code reference
- If evidence cannot be found, contract must explicitly state it

#### Gate 3: Every Contract Has Risk Level

**Check:**
- Every `contracts[].severity` is set to one of: critical, high, medium, low
- No empty or null severity fields

#### Gate 4: Ordering Contracts Are Explicit

**Check:**
- Contracts with "before X" or "after Y" in description reference specific contract IDs or line numbers
- Lifecycle (L) contracts specify exact sequence

#### Gate 5: Verification Patterns Compile

```bash
# For grep patterns
for pattern in [all grep_patterns]; do
    echo "test" | grep -q "$pattern" 2>/dev/null
    if [ $? -eq 2 ]; then
        echo "FAIL [Gate 5]: Invalid grep pattern: $pattern"
    fi
done

# For ast-grep rules (if applicable)
# Verify YAML syntax and $VAR/$$$  usage
```

**Check:**
- All `verification.grep_pattern` values are valid regex
- All `verification.ast_grep_rule` files use correct ast-grep syntax

#### Gate 6: grep Patterns Are Distinctive

**Check:**
- Each `grep_pattern` matches the intended contract location
- Pattern does not match unrelated code elsewhere in the module
- Test: `grep -c "pattern" target_file` should return a small number (1-5)

#### Gate 7: Line Attribution Complete (Artifact 4)

**Check:**
- Every executable line in the target module appears in the line attribution table
- `Unclassified: 0` in the attribution summary
- Every `CONTRACT` line maps to a contract ID that exists in the contract list

#### Gate 8: Metadata Complete

**Check:**
- Every contract has `scope` field (method/class/module)
- Every contract has `seam_type` field (object/preprocessing/link/none)
- Every contract has `pinch_point` field (true/false)

#### Gate 9: Feathers Analysis Complete

**Check:**
- F1 (Tell the Story): `feathers_analysis.story` is non-empty, `lies` array has items
- F2 (Scratch Refactoring): `scratch_refactoring_count` >= 3
- F3 (Effect Propagation): `effect_traces_count` matches public method count

#### Gate 10: Completeness Declaration

**Check:**
- Output ends with one of:
  - `COMPLETE: All executable lines attributed. No known audit gaps.`
  - `INCOMPLETE: [N] lines unresolved -- [list line numbers and why]`

---

### Step V3: CONFIRM_RATIO Verification

```bash
# Calculate CONFIRM_RATIO
TOTAL=$((confirm_count + dispute_count + add_count))
RATIO=$(echo "scale=1; $confirm_count * 100 / $TOTAL" | bc)

if [ $(echo "$RATIO > 70" | bc) -eq 1 ]; then
    echo "FAIL: CONFIRM_RATIO $RATIO% exceeds 70% threshold"
    echo "Action: Adversarial reviewer needs stricter analysis"
fi
```

**Check:**
- `adversary_summary.confirm_ratio` <= 70%
- If exceeded, adversarial review must be re-run with stricter criteria

---

### Step V4: Contract ID Consistency

```bash
# Verify all IDs match pattern
for id in [all contract IDs]; do
    if ! echo "$id" | grep -qE '^[MLNSECDP]-[0-9]{3}$'; then
        echo "FAIL: Invalid contract ID format: $id"
    fi
done

# Verify no duplicate IDs
DUPES=$(echo "[all IDs]" | sort | uniq -d)
if [ -n "$DUPES" ]; then
    echo "FAIL: Duplicate contract IDs: $DUPES"
fi

# Verify type prefix matches type field
# e.g., M-001 must have type: M
```

**Check:**
- All IDs match `^[MLNSECDP]-[0-9]{3}$`
- No duplicate IDs
- ID prefix matches `type` field (e.g., `M-001` has `type: M`)

---

### Step V5: Counts Verification

```bash
# Verify total_contracts matches array length
CLAIMED=$total_contracts
ACTUAL=$(echo "[contracts array]" | wc -l)
if [ "$CLAIMED" -ne "$ACTUAL" ]; then
    echo "FAIL: total_contracts=$CLAIMED but array has $ACTUAL items"
fi

# Verify pinch_points count
CLAIMED_PP=$pinch_points
ACTUAL_PP=$(grep -c 'pinch_point: true' output.yaml)
if [ "$CLAIMED_PP" -ne "$ACTUAL_PP" ]; then
    echo "FAIL: pinch_points=$CLAIMED_PP but found $ACTUAL_PP"
fi
```

---

### Step V6: Handle Verification Results

Based on verification outcomes:

#### If All Checks Pass

```yaml
verification_status:
  verified: true
  gates_passed: 10
  confidence: high
```

**Action:**
- Continue to save
- Add verification summary to footer

#### If Minor Issues Found (1-2 gates failed)

**Examples:**
- One evidence file path incorrect
- Contract count off by 1
- One ID format mismatch

**Action:**
1. **Correct the specific issues** without regenerating entire output
2. Re-verify corrected items
3. Note corrections in verification summary

#### If Major Issues Found (3+ gates failed)

**Examples:**
- Multiple evidence files don't exist
- CONFIRM_RATIO exceeds threshold
- Many contracts missing metadata

**Action:**
1. **STOP** -- do not save current output
2. Re-execute relevant pipeline steps:
   - If evidence wrong: re-run Step 2 (Structured Audit)
   - If CONFIRM_RATIO wrong: re-run Step 3 (Adversarial Review)
   - If metadata missing: re-run Step 4 (Merge)
3. Regenerate affected sections
4. Re-run full verification

---

### Step V7: Verification Summary

Add to footer (before `SourceAtlas Audit v1.0`):

#### If All Verifications Passed

```markdown
Verified: [N] contracts, [M] pinch points, line attribution complete
```

**Example:**
```markdown
Verified: 49 contracts, 3 pinch points, line attribution complete

-------------------------------
SourceAtlas Audit v1.0
```

#### If Corrections Were Made

```markdown
Self-corrected: [list specific corrections]
Verified: [N] contracts, [M] pinch points, line attribution complete
```

**Example:**
```markdown
Self-corrected: Evidence path corrected for M-003, pinch_points count updated to 3
Verified: 49 contracts, 3 pinch points, line attribution complete

-------------------------------
SourceAtlas Audit v1.0
```

---

## Verification Checklist

Before finalizing output, confirm:

- [ ] All `contracts[].evidence[].file` entries verified to exist
- [ ] All `contracts[].evidence[].line` entries within valid range
- [ ] All `contracts[].id` match `^[MLNSECDP]-[0-9]{3}$` with no duplicates
- [ ] All `contracts[].id` prefix matches `contracts[].type`
- [ ] `total_contracts` matches actual contracts array length
- [ ] `pinch_points` matches count of `pinch_point: true` contracts
- [ ] `adversary_summary.confirm_ratio` <= 70%
- [ ] Every contract has `severity`, `scope`, `seam_type`, `pinch_point`
- [ ] Every contract has at least one evidence entry
- [ ] All `verification.grep_pattern` values are valid regex
- [ ] Feathers analysis (F1, F2, F3) completed
- [ ] Line attribution table has `Unclassified: 0`
- [ ] Completeness declaration present (COMPLETE or INCOMPLETE)
- [ ] No placeholder values in output

---

## Quality Gate Summary Table

| # | Gate | Verification | Failure Action |
|---|------|-------------|----------------|
| 1 | Evidence exists | `test -f` on all evidence files | Fix paths or re-scan |
| 2 | No unsourced inferences | Check evidence array | Add evidence or remove contract |
| 3 | Risk level set | Check severity field | Set appropriate level |
| 4 | Ordering explicit | Check L/S descriptions | Add specific IDs/lines |
| 5 | Patterns compile | Test grep/ast-grep syntax | Fix pattern syntax |
| 6 | Patterns distinctive | Count matches | Narrow pattern scope |
| 7 | Attribution complete | Check Unclassified count | Classify remaining lines |
| 8 | Metadata complete | Check scope/seam/pinch | Fill missing fields |
| 9 | Feathers complete | Check F1/F2/F3 | Execute missing analyses |
| 10 | Completeness declared | Check footer | Add declaration |

---

## Phase B CI Verification

### Purpose

Verify that Phase B CI rules can be generated and executed from the contract output.

### Checks

1. **grep script generation**: Can `verify-contracts-{module}.sh` be generated from contract output?
2. **ast-grep rule generation**: Can `.ast-grep/rules/{module}/` be populated? (language permitting)
3. **Dry run**: Execute verification against current source -- all should pass (contracts describe existing behavior)

```bash
# Dry run: all contracts should pass against current source
bash verify-contracts-{ModuleName}.sh
# Expected: 0 failures (contracts describe what currently exists)
```

If any assertion fails in dry run:
- The contract evidence is likely incorrect
- Re-verify the specific contract
- Update evidence or remove contract

---

## Best Practices

1. **Always verify evidence paths** -- LLM may hallucinate file paths
2. **Check contract ID uniqueness** -- Merge step may introduce duplicates
3. **Validate CONFIRM_RATIO** -- Too high suggests insufficient adversarial review
4. **Dry run CI rules** -- Contracts must pass against current code
5. **Note all corrections** -- Transparency in verification summary
6. **Check line attribution completeness** -- Missing lines are audit gaps
7. **Verify Feathers analysis integration** -- F1/F2/F3 results should produce contracts

---

## Handoff to Next Steps

After verification:
- If confidence HIGH: proceed to save, optionally generate Phase B CI rules
- If confidence MEDIUM: save with corrections noted, flag for human review
- If confidence LOW: re-execute pipeline steps, do not save
