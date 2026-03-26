# Contract Audit Output Template

Complete format specification for contract audit reports.

---

## Standard Output

```markdown
🔍 SourceAtlas: Audit
───────────────────────────────
📋 $MODULE │ $LANGUAGE │ $CONTRACT_COUNT contracts

📊 **Contract Summary**:
- M (Mutation): [count]
- L (Lifecycle): [count]
- N (Notification): [count]
- S (Synchronization): [count]
- E (Error Handling): [count]
- C (Cancellation): [count]
- D (Dependency): [count]
- P (Propagation): [count]

🎯 **Cross-Validation**:
- Gemini found: [count] behaviors
- Codex confirmed: [confirmed] / disputed: [disputed] / added: [added]
- CONFIRM_RATIO: [ratio]% [✅ healthy | ⚠️ too high]
- DEGRADED: [yes/no]

---

## Contracts

### [Category]-[NNN]: [Title]

```
Trigger:      [What activates this behavior]
Input:        [What data flows in]
Output:       [What data flows out or side effects]
Condition:    [Preconditions that must hold]
Ordering:     [Temporal constraints]
Risk:         [LOW|MEDIUM|HIGH] -- [explanation]
Evidence:     [file:line] -- [code snippet]
Scope:        [method|class|module]
Seam_Type:    [object|preprocessing|link|none]
Pinch_Point:  [true|false]
```

**Verification**:
```bash
# grep assertion
grep -q '[pattern]' [file]
```

[Repeat for each contract]

---

## Risk Assessment

### High Risk Contracts
[List contracts with Risk: HIGH]

### Refactoring Recommendations
1. [recommendation with evidence]
2. [recommendation with evidence]

### Seam Analysis
- Object Seams: [count] (dependency injection points)
- Preprocessing Seams: [count] (compile-time switches)
- Link Seams: [count] (dynamic linking points)
- Pinch Points: [count] (high-ROI verification targets)

---

## Phase B CI Rules

```bash
# Auto-generated verification rules for CI/CD
# Add to your CI pipeline to prevent refactoring regressions

[grep/ast-grep rules for each contract]
```

---

## Verification Summary

✅ Verified: [count] claims
❌ Failed: [count] claims (details below)
⚠️ Skipped: [count] claims (unable to verify)

[failure details if any]

---

📁 Saved to: .sourceatlas/audit/$MODULE.yaml
💡 Use `/atlas.audit $FILE --force` to re-audit
```

---

## Degraded Mode Output

When LLM CLIs are unavailable:

```markdown
🔍 SourceAtlas: Audit (DEGRADED)
───────────────────────────────
📋 $MODULE │ $LANGUAGE │ Prompt files generated

⚠️ Missing tools: [gemini|codex|both]

📝 Prompt files saved to: .sourceatlas/audit/prompts/
  1. step1-gemini.md  → Feed to Gemini
  2. step2-claude.md  → Feed to Claude (include Gemini output)
  3. step3-codex.md   → Feed to Codex (include Claude output)

After manual execution:
  /atlas.audit $FILE --force
```

---

## YAML Save Format

The auto-saved YAML follows `pipeline/output-template.yaml` schema:

```yaml
module: $MODULE
language: $LANGUAGE
file: $FILE_PATH
generated: $TIMESTAMP
degraded: false
pipeline_version: "1.0"

summary:
  total_contracts: N
  by_category:
    M: N
    L: N
    N: N
    S: N
    E: N
    C: N
    D: N
    P: N

cross_validation:
  gemini_behaviors: N
  codex_confirmed: N
  codex_disputed: N
  codex_added: N
  confirm_ratio: N.N

contracts:
  - id: "M-001"
    category: Mutation
    title: "..."
    trigger: "..."
    input: "..."
    output: "..."
    condition: "..."
    ordering: "..."
    risk: "MEDIUM"
    risk_reason: "..."
    evidence:
      file: "path/to/file.ext"
      line: 42
      snippet: "..."
    scope: method
    seam_type: object
    pinch_point: true
    verification:
      type: grep
      command: "grep -q 'pattern' file"

risk_assessment:
  high_risk_count: N
  recommendations:
    - "..."
  seam_analysis:
    object: N
    preprocessing: N
    link: N
    pinch_points: N
```
