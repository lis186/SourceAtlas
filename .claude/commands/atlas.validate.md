---
description: Validate analysis output quality against Constitution principles ("Unit Tests for Analysis")
allowed-tools: Bash, Glob, Grep, Read
argument-hint: (optional) [path to analysis output file, e.g., "output.yaml" or "analysis.md"]
---

# SourceAtlas: Analysis Quality Validation

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.1
>
> Key principles enforced:
> - **ALL Articles**: This command validates compliance with all 8 Articles
> - Article IV: 證據格式（必須使用 `file:line` 引用）
> - Article V: 輸出格式（必要元資料檢查）

## Context

**Validation Target:** $ARGUMENTS (default: most recent atlas output in conversation)

**Goal:** Validate the quality of SourceAtlas analysis outputs using the "Unit Tests for Analysis" methodology - testing the ANALYSIS QUALITY, not the codebase itself.

**Time Limit:** Complete in 2-5 minutes.

---

## Core Concept: "Unit Tests for Analysis"

**CRITICAL**: This command validates the ANALYSIS QUALITY, not the target project.

**NOT for**:
- ❌ "Does the project have good architecture?"
- ❌ "Is the code well-written?"
- ❌ "Are there security vulnerabilities?"

**FOR**:
- ✅ "Does the analysis output contain all required metadata?"
- ✅ "Are all hypotheses properly evidenced?"
- ✅ "Is the scan ratio within Constitution limits?"
- ✅ "Are file:line references properly formatted?"

---

## Your Task

You are **SourceAtlas Validator**, specialized in quality-assuring analysis outputs against Constitution principles.

Execute a **non-destructive, read-only** validation of the analysis output.

---

## Workflow

### Step 1: Identify Analysis Output (30 seconds)

**If $ARGUMENTS provided**: Read the specified file

**If no arguments**: Look for the most recent atlas output in the conversation context

**Supported formats**:
- YAML output from `/atlas.overview`
- Markdown output from `/atlas.pattern`, `/atlas.flow`, `/atlas.history`, `/atlas.impact`

### Step 2: Build Quality Checklist (1 minute)

Generate a checklist based on Constitution requirements.

**Quality Dimensions** (inspired by spec-kit):

| Dimension | What We're Testing |
|-----------|-------------------|
| **Completeness** | Are all required elements present? |
| **Clarity** | Are statements specific and unambiguous? |
| **Consistency** | Is terminology consistent throughout? |
| **Measurability** | Are confidence levels and metrics provided? |
| **Coverage** | Are all relevant aspects addressed? |
| **Traceability** | Are all claims supported by evidence? |

### Step 3: Execute Validation Checks (2-3 minutes)

#### A. Article I: 資訊理論原則

```markdown
□ CHK001 - Does the output list scanned high-entropy files? [Completeness, §1.1]
□ CHK002 - Is scan_ratio included and within limits? [Measurability, §1.2]
□ CHK003 - Does scan ratio comply with project scale limits? [Compliance, §1.2]
```

#### B. Article II: 排除原則

```markdown
□ CHK004 - Are excluded directories mentioned/respected? [Compliance, §2.1]
□ CHK005 - Is file count post-exclusion (not raw count)? [Accuracy, §2.1]
```

#### C. Article III: 假設原則

```markdown
□ CHK006 - Is hypothesis count appropriate for project scale? [Compliance, §3.1]
□ CHK007 - Does each hypothesis have all 4 required fields? [Completeness, §3.2]
  - hypothesis (statement)
  - confidence (0.0-1.0)
  - evidence (file:line)
  - validation_method
□ CHK008 - Are low-confidence hypotheses within scale limits? [Compliance, §3.1]
□ CHK009 - Is confidence calibration reasonable? [Accuracy, §3.3]
```

#### D. Article IV: 證據原則

```markdown
□ CHK010 - Are all claims supported by evidence? [Traceability, §4.3]
□ CHK011 - Do evidence references use file:line format? [Format, §4.1]
□ CHK012 - Are there any unsupported conclusory statements? [Compliance, §4.3]
```

#### E. Article V: 輸出原則

```markdown
□ CHK013 - Is the output format correct for analysis type? [Format, §5.1]
□ CHK014 - Are all required metadata fields present? [Completeness, §5.2]
  - analysis_time
  - total_files
  - scanned_files
  - scan_ratio
  - project_scale
  - constitution_version
□ CHK015 - Is language appropriate (台灣繁體中文 + 英文術語)? [Compliance, §5.3]
```

#### F. Article VI: 規模感知原則

```markdown
□ CHK016 - Is project scale correctly determined? [Accuracy, §6.1]
□ CHK017 - Are behaviors scale-appropriate? [Compliance, §6.2]
```

#### G. Article VII: Handoffs 原則

```markdown
□ CHK018 - If handoffs present, are they discovery-driven? [Compliance, §7.1]
□ CHK019 - If ending conditions met, is recommended_next omitted? [Compliance, §7.2]
□ CHK020 - Are handoff parameters specific (not vague)? [Quality, §7.4]
□ CHK021 - Do handoff reasons cite specific findings? [Traceability, §7.5]
```

### Step 4: Assign Severity (30 seconds)

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Violates MUST principle (§ marked 不可變) |
| **HIGH** | Missing required field, unsupported claim |
| **MEDIUM** | Format issues, vague statements |
| **LOW** | Style improvements, minor inconsistencies |

**Constitution violations are automatically CRITICAL.**

### Step 5: Generate Report

---

## Output Format

```markdown
# Analysis Quality Validation Report

**Target**: [analysis type and source]
**Validated Against**: Constitution v1.1
**Validation Time**: [ISO 8601]

---

## Summary

| Metric | Value |
|--------|-------|
| Total Checks | N |
| Passed | N (X%) |
| Failed | N |
| Critical Issues | N |
| High Issues | N |
| Medium Issues | N |
| Low Issues | N |

**Overall Quality**: [PASS / NEEDS IMPROVEMENT / FAIL]

---

## Findings

| ID | Check | Severity | Status | Issue | Recommendation |
|----|-------|----------|--------|-------|----------------|
| CHK001 | High-entropy files listed | HIGH | ❌ FAIL | No scanned_files section found | Add scanned_files metadata |
| CHK002 | scan_ratio included | CRITICAL | ❌ FAIL | Missing scan_ratio | Add scan_ratio field |
| CHK007 | Hypothesis completeness | MEDIUM | ⚠️ PARTIAL | 2/5 hypotheses missing validation_method | Complete all 4 fields |
| CHK010 | Evidence traceability | LOW | ✅ PASS | - | - |

---

## Article-by-Article Compliance

### Article I: 資訊理論原則
- ✅ §1.1 高熵優先: [PASS/FAIL + brief note]
- ❌ §1.2 掃描比例上限: [issue description]

### Article II: 排除原則
- ✅ §2.1 強制排除目錄: [PASS/FAIL + brief note]

[... continue for all Articles ...]

---

## Critical Issues (Must Fix)

1. **CHK002**: Missing `scan_ratio` field
   - **Location**: metadata section
   - **Required by**: Article V, Section 5.2
   - **Fix**: Add `scan_ratio: "X.X%"` to metadata

---

## Recommendations

### Immediate Actions (Critical/High)
1. [Specific action for critical issue]
2. [Specific action for high issue]

### Suggested Improvements (Medium/Low)
1. [Improvement suggestion]

---

## Quality Score

| Dimension | Score | Notes |
|-----------|-------|-------|
| Completeness | 8/10 | Missing 2 metadata fields |
| Clarity | 9/10 | Good |
| Consistency | 10/10 | Excellent |
| Measurability | 7/10 | Some hypotheses lack confidence |
| Coverage | 9/10 | Good |
| Traceability | 6/10 | Several unsupported claims |

**Overall Score**: X/10

---

## Next Steps

<!-- 如果有 Critical/High 問題 -->
⚠️ **Action Required**: Fix N critical/high issues before using this analysis

<!-- 如果全部通過 -->
✅ **Analysis Quality Verified** - This analysis complies with Constitution v1.1
```

---

## Critical Rules

1. **READ-ONLY**: Never modify the analysis being validated
2. **Constitution is FINAL**: Violations are non-negotiable
3. **Be Specific**: Cite exact locations of issues
4. **Actionable Feedback**: Every finding must have a fix recommendation
5. **Fair Assessment**: Acknowledge what's done well, not just issues

---

## Anti-Examples: What NOT to Validate

```markdown
❌ WRONG (Testing the TARGET project):
- "The project has poor test coverage"
- "The architecture is not well-designed"
- "Security vulnerabilities found"

✅ CORRECT (Testing the ANALYSIS quality):
- "The analysis claims 'well-designed' without file:line evidence"
- "Hypothesis confidence 0.9 but only one weak evidence cited"
- "scan_ratio exceeds Constitution limit for MEDIUM projects"
```

---

## No Handoffs

This command is typically a terminal action (validating output quality).

If issues are found, the recommendation is to re-run the original command with improvements, not to chain to another atlas command.

✅ **Validation Complete** - Review findings and address critical issues before using the analysis.
