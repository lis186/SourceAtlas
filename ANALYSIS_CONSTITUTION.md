# SourceAtlas Analysis Constitution

**Version**: 1.1 | **Effective Date**: 2025-12-05 | **Status**: Active

> This document defines the **immutable principles** of SourceAtlas analysis.
> All analysis commands (/atlas.*) must adhere to these principles.
> Analysis results that violate these principles should be considered incomplete.

---

## Article I: Information Theory Principles

### Section 1.1: High-Entropy Priority
> **Immutable**: Always prioritize scanning high-entropy files over linear traversal.

High-entropy file scanning order:
1. **Configuration files** (package.json, go.mod, Cargo.toml, pyproject.toml)
2. **Project documentation** (README.md, CLAUDE.md, ARCHITECTURE.md)
3. **Core models** (models/, entities/, domain/)
4. **Entry points** (main.*, index.*, app.*)
5. **Test samples** (1-2 representative tests)

**Validation**: Each analysis must record the list of "high-entropy files scanned".

### Section 1.2: Scan Ratio Limits
> **Immutable**: The number of scanned files must not exceed the specified ratio of total project files.

| Project Scale | File Count | Max Scan Ratio | Max Scan Count |
|---------------|------------|----------------|----------------|
| TINY | <20 | 50% | 10 |
| SMALL | 20-50 | 20% | 10 |
| MEDIUM | 50-150 | 10% | 15 |
| LARGE | 150-500 | 5% | 25 |
| VERY_LARGE | >500 | 3% | 30 |

**Validation**: Analysis reports must include a `scan_ratio` field; violations should trigger a warning.

### Section 1.3: Structure Over Details
> **Guidance**: Understanding project structure is more important than reading implementation details.

Priority order:
1. Directory structure and naming conventions
2. Module dependencies
3. API contracts and interface definitions
4. Implementation details (only when necessary)

---

## Article II: Exclusion Policy

### Section 2.1: Mandatory Directory Exclusions
> **Immutable**: The following directories must be excluded from file counting and scanning under all circumstances.

```
.venv/           # Python virtual environment
node_modules/    # Node.js dependencies
vendor/          # PHP/Go dependencies
__pycache__/     # Python cache
.git/            # Git internals
Pods/            # iOS CocoaPods
DerivedData/     # Xcode build artifacts
build/           # Generic build directory
dist/            # Generic distribution directory
target/          # Rust/Maven build
.next/           # Next.js build
.nuxt/           # Nuxt.js build
```

**Validation**: Detection scripts must exclude these directories before counting files.

### Section 2.2: Conditional Exclusions
> **Configurable**: The following directories are included by default but can be excluded by users.

```
tests/           # Test directory
docs/            # Documentation directory
examples/        # Examples directory
```

---

## Article III: Hypothesis Policy

### Section 3.1: Hypothesis Count Limits
> **Immutable**: Hypothesis count must be adjusted based on project scale.

| Project Scale | Target Hypothesis Count | Low-Confidence Hypothesis Limit |
|---------------|-------------------------|--------------------------------|
| TINY | 5-8 | 2 |
| SMALL | 7-10 | 3 |
| MEDIUM | 10-15 | 4 |
| LARGE | 12-18 | 5 |
| VERY_LARGE | 15-20 | 6 |

**Definition**: Low-confidence hypothesis = confidence < 0.5

**Validation**: When exceeding the low-confidence limit, prioritize marking the weakest hypotheses as "needs validation" or improve confidence through additional scanning.

### Section 3.2: Required Hypothesis Elements
> **Immutable**: Each hypothesis must include the following fields.

```yaml
hypothesis: "Declarative statement describing the inference"
confidence: 0.0-1.0  # Confidence level
evidence: "Evidence reference in file:line format"
validation_method: "How to validate in subsequent stages"
```

**Validation**: Hypotheses missing any field should be considered incomplete.

### Section 3.3: Confidence Level Calibration
> **Guidance**: Confidence levels should follow these standards.

| Confidence Range | Meaning | Evidence Requirement |
|------------------|---------|---------------------|
| 0.85-1.0 | Almost certain | Explicit declaration in config file |
| 0.7-0.85 | Highly likely | Multiple indirect evidence |
| 0.5-0.7 | Moderately likely | Single indirect evidence |
| 0.0-0.5 | Needs validation | Speculation, lacks direct evidence |

### Section 3.4: Hypothesis Priority
> **Guidance**: When trade-offs are needed, prioritize retaining these hypothesis types.

Priority order (high → low):
1. **Architecture hypotheses** (overall structure, design patterns)
2. **Tech stack hypotheses** (languages, frameworks, databases)
3. **Business domain hypotheses** (what the project does)
4. **Development practice hypotheses** (testing, CI/CD)
5. **AI collaboration hypotheses** (Level 0-4)

---

## Article IV: Evidence Policy

### Section 4.1: Evidence Format
> **Immutable**: All assertions must be supported by evidence using standard format.

```
file_path:line_number  # Precise reference
```

Examples:
- `src/models/User.php:42` - Exact line number
- `README.md:15-30` - Range reference
- `package.json` - Whole file reference (only for config files)

### Section 4.2: Evidence Type Hierarchy
> **Guidance**: Different types of evidence have different credibility levels.

| Evidence Type | Credibility | Example |
|---------------|-------------|---------|
| Config declaration | Highest | dependencies in package.json |
| Documentation statement | High | Project description in README.md |
| Code structure | Medium-high | Directory naming, file organization |
| Code content | Medium | import statements, class definitions |
| Inference | Low | Guesses based on patterns |

### Section 4.3: No Unsupported Assertions
> **Immutable**: Conclusive statements without evidence are prohibited in analysis reports.

❌ Wrong: "This is a high-quality project"
✅ Correct: "This is a high-quality project (evidence: test coverage config `.github/workflows/ci.yml:45`, lint rules `.eslintrc.js`)"

---

## Article V: Output Policy

### Section 5.1: Format Standards
> **Immutable**: Output format must follow these standards.

| Analysis Type | Format | Reason |
|---------------|--------|--------|
| Stage 0 Fingerprint | YAML | Structured, machine-readable |
| Stage 1 Validation | Markdown | Human-readable report |
| Stage 2 History | Markdown | Narrative analysis |
| Quick Commands | Markdown | Immediate feedback |

### Section 5.2: Required Metadata
> **Immutable**: All analysis output must include the following metadata.

```yaml
metadata:
  analysis_time: "ISO 8601 timestamp"
  total_files: N        # Total project files (after exclusions)
  scanned_files: M      # Actual scanned file count
  scan_ratio: "X.X%"    # M/N percentage
  project_scale: "TINY|SMALL|MEDIUM|LARGE|VERY_LARGE"
  constitution_version: "1.0"
```

### Section 5.3: Language Standards
> **Guidance**: Output language should match user preference or the project's primary language.

- Default: Traditional Chinese (Taiwan terminology)
- Technical terms: Keep English originals
- Proper nouns: Do not translate (e.g., React, Django, Kubernetes)

### Section 5.4: Built-in Quality Checks
> **Guidance**: Each command should auto-validate quality before output, embedding warnings when issues are found.

**Check Items** (by priority):

| Check | Severity | Example Warning |
|-------|----------|-----------------|
| scan_ratio exceeds limit | ⚠️ HIGH | `⚠️ scan_ratio 12% exceeds MEDIUM project limit of 10%` |
| Hypothesis missing required fields | ⚠️ HIGH | `⚠️ Hypothesis #3 missing evidence field` |
| Incorrect evidence format | ⚠️ MEDIUM | `⚠️ Evidence format should be file:line, found "src/app.ts"` |
| Missing required metadata | ⚠️ MEDIUM | `⚠️ Missing project_scale metadata` |
| Too many low-confidence hypotheses | ℹ️ INFO | `ℹ️ 5 low-confidence hypotheses, recommend further validation` |

**Warning Format**:
```markdown
---
⚠️ **Quality Warning**
- scan_ratio 12% exceeds limit
- Hypothesis #3 missing evidence field
---
```

**Principles**:
- Warnings should be embedded in output, not blocking the flow
- Display HIGH severity issues first
- Keep concise, one line per warning

---

## Article VI: Scale-Aware Policy

### Section 6.1: Scale Determination
> **Immutable**: Project scale is determined by the number of code files after exclusions.

```
TINY:       < 20 files
SMALL:      20 - 50 files
MEDIUM:     50 - 150 files
LARGE:      150 - 500 files
VERY_LARGE: > 500 files
```

### Section 6.2: Scale-Aware Behavior
> **Immutable**: Projects of different scales require different analysis strategies.

| Behavior | TINY | SMALL | MEDIUM | LARGE | VERY_LARGE |
|----------|------|-------|--------|-------|------------|
| Scan depth | Deep | Medium-deep | Medium | Shallow | Very shallow |
| Hypothesis count | 5-8 | 7-10 | 10-15 | 12-18 | 15-20 |
| Model scanning | All | All | 3-5 | 3-5 | 5-7 |
| Test scanning | All | 2-3 | 1-2 | 1-2 | 2-3 |

### Section 6.3: Tiny Project Exception
> **Guidance**: TINY projects (<20 files) may not need full SourceAtlas analysis.

Recommendations:
- <10 files: Read directly, no systematic analysis needed
- 10-20 files: Use `/atlas.overview` for quick scan only
- >20 files: Normal SourceAtlas workflow

---

## Article VII: Handoffs Policy

### Section 7.1: Discovery-Driven
> **Immutable**: Handoffs must be based on actual analysis findings, not static lists.

Each handoff suggestion must:
- Reference specific findings from the current analysis
- Explain why this suggestion relates to the findings
- Provide specific executable parameters

❌ Forbidden: "You can use /atlas.pattern to learn more"
✅ Correct: "`/atlas.pattern "repository"` - Found Repository pattern used in 15 places, need to understand implementation conventions"

### Section 7.2: End Conditions
> **Immutable**: When any of the following conditions are met, the `recommended_next` section should be omitted.

| Condition | Description |
|-----------|-------------|
| **Sufficient analysis depth** | 4+ commands executed covering multiple dimensions (overview + pattern + flow + history/impact) |
| **Project too small** | TINY project (<10 files) can read all files directly |
| **Findings too vague** | Cannot give high-confidence (>0.7) parameter suggestions |
| **Goal achieved** | User's question has been answered |

When omitting handoffs, provide an end prompt:
```markdown
✅ **Analysis sufficient** - Ready to start implementation

Based on the above findings, recommend prioritizing:
1. [Specific action item]
2. [Specific action item]
```

### Section 7.3: Suggestion Count and Format
> **Immutable**: Handoffs suggestions follow these rules.

- **Primary**: Must be provided (unless end conditions are met)
- **Secondary**: Optional (only when there's a clear relevant second option)

**Forbidden** to force a Secondary suggestion just for format consistency.
When there's only one clear direction, provide only Primary.

**Output Format**: Use numbered table for quick user selection:

```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/atlas.pattern "repository"` | Found Repository pattern used in 15 places, need to understand implementation conventions |
| 2 | `/atlas.flow "checkout"` | Trace the complete execution path of checkout flow |

💡 Enter a number (e.g., `1`) or copy the command to execute
```

Users can enter `1` for quick execution or copy the full command.

### Section 7.4: Parameter Quality
> **Immutable**: Handoffs parameters must meet the following quality standards.

| Requirement | Description | Example |
|-------------|-------------|---------|
| **Specific** | Include executable parameters | ✅ `/atlas.pattern "repository"` |
| **Not generic** | Avoid abstract descriptions | ❌ `/atlas.pattern "relevant pattern"` |
| **Verifiable** | Parameters correspond to actual existing targets | File paths exist, pattern names are valid |
| **Finding-based** | Parameters come from current analysis results | ✅ Use actual file names discovered in analysis |

### Section 7.5: Rationale Quality
> **Immutable**: The `why` field for each suggestion must:

1. Reference **specific findings** from the current analysis (numbers, file names, issues)
2. Explain the **causal relationship** between finding and suggestion
3. Express concisely in **1-2 sentences**

❌ Forbidden: "To learn more details"
✅ Correct: "Found setSQL.py is depended on by 3 modules with no tests, need to assess modification risk"

---

## Article VIII: Amendment Policy

### Section 8.1: Amendment Process
> Amendments to this Constitution require:

1. Propose amendment suggestion in `ideas/`
2. Validate new principles on 3+ projects
3. Update `dev-notes/` to record decision rationale
4. Increment version number
5. Update effective date

### Section 8.2: Version Number Rules

- **MAJOR** (e.g., 1.0 → 2.0): Non-backward-compatible principle changes
- **MINOR** (e.g., 1.0 → 1.1): New principles or clarifications
- **PATCH** (e.g., 1.0.0 → 1.0.1): Typo fixes, formatting adjustments

### Section 8.3: Backward Compatibility
> **Guidance**: Amendments should maintain backward compatibility as much as possible, keeping previously valid analysis results still valid.

---

## Appendix A: Quick Checklist

### Pre-Analysis Checks
- [ ] Confirm correct project path
- [ ] Exclusion directories configured (.venv, node_modules, etc.)
- [ ] Determine project scale (TINY/SMALL/MEDIUM/LARGE/VERY_LARGE)

### During Analysis Checks
- [ ] Prioritize scanning high-entropy files
- [ ] Scan ratio within specified limits
- [ ] Hypothesis count matches project scale
- [ ] Each hypothesis has complete four elements

### Post-Analysis Checks
- [ ] Output includes required metadata
- [ ] Each assertion has supporting evidence
- [ ] Low-confidence hypotheses don't exceed limit
- [ ] Format complies with standards (YAML/Markdown)

### Built-in Quality Checks (Section 5.4)
- [ ] Auto-validate before output
- [ ] HIGH severity issues shown with `⚠️` warning
- [ ] Warnings embedded in output, not blocking flow
- [ ] Warning format correct (one per line, HIGH priority first)

### Handoffs Checks (Article VII)
- [ ] End conditions met? If yes, omit `recommended_next`
- [ ] Primary suggestion has specific parameters (not generic)
- [ ] Secondary only provided when clear second option exists
- [ ] Rationale references specific findings from current analysis
- [ ] Parameters based on actual findings (file names, pattern names)

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **High-entropy file** | Files containing large amounts of project information (configs, docs, models) |
| **Scan ratio** | Actual scanned file count / Total project file count |
| **Hypothesis** | Inference based on scan results, pending later validation |
| **Confidence level** | Subjective estimate of hypothesis correctness (0.0-1.0) |
| **Evidence** | Specific file references supporting assertions |

---

## Appendix C: Relationship with Other Documents

| Document | Relationship |
|----------|--------------|
| `CLAUDE.md` | Development guide (how to develop SourceAtlas); this Constitution focuses on analysis behavior |
| `PROMPTS.md` | Complete prompt templates, should follow this Constitution's principles |
| `.claude/commands/atlas.*.md` | Command implementations, must reference this Constitution |
| `scripts/atlas/*.sh` | Helper scripts, should implement this Constitution's exclusion and counting logic |

---

**End of Document**

*This Constitution is maintained by the SourceAtlas team. For questions or suggestions, please submit them in the `ideas/` directory.*
