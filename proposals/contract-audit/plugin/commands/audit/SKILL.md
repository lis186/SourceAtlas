---
name: audit
description: Multi-LLM cross-validated behavioral contract audit for legacy code refactoring
model: opus
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "<file-or-module> [--language <lang>] [--force] [--recommend]"
---

# SourceAtlas: Audit (Behavioral Contract Audit)

> **Constitution**: [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md) v1.0

## Context

**Arguments**: ${ARGUMENTS}

**Goal**: Extract implicit behavioral contracts from legacy code modules using multi-LLM cross-validation, producing machine-verifiable assertions for CI/CD integration.

**Auto-Save**: Results automatically saved to `.sourceatlas/audit/{module}.yaml`

**Time Limit**: 30-60 minutes (depending on module complexity)

---

## Cache Check (Highest Priority)

**If `--force` is NOT in arguments**, check cache first:

1. Calculate cache path from module name:
   - Extract module name from file path (e.g., `NYHTTPSClient.m` -> `NYHTTPSClient`)
   - Cache path: `.sourceatlas/audit/{module}.yaml`

2. Check if cache exists:
   ```bash
   ls -la .sourceatlas/audit/{module}.yaml 2>/dev/null
   ```

3. **If cache exists**:
   - Calculate days since modification
   - Use Read tool to read cache
   - Output:
     ```
     Loading cache: .sourceatlas/audit/{module}.yaml (N days ago)
     Add --force to re-analyze
     ```
   - **If over 30 days**: Show warning
   - Output cache content
   - **End, do not execute analysis**

4. **If cache does not exist**: Continue with analysis

**If `--force` is in arguments**: Skip cache, execute analysis

---

## Argument Parsing

### Required: Target File or Module

- File path (e.g., `src/NYHTTPSClient.m`)
- Module name (e.g., `NYHTTPSClient`)

### Optional Flags

| Flag | Purpose | Default |
|------|---------|---------|
| `--language <lang>` | Override language detection | Auto-detect |
| `--force` | Skip cache, re-analyze | false |
| `--recommend` | Recommend audit targets instead of auditing | false |

---

## Language Auto-Detection

If `--language` is not specified, detect language from file extension:

```bash
# Use detect-project.sh for language detection
if [ -f ~/.claude/scripts/atlas/detect-project.sh ]; then
    bash ~/.claude/scripts/atlas/detect-project.sh .
elif [ -f scripts/atlas/detect-project.sh ]; then
    bash scripts/atlas/detect-project.sh .
fi
```

**Fallback: Extension-Based Detection**

| Extension | Language | Plugin |
|-----------|----------|--------|
| `.m`, `.h` | Objective-C | `languages/objc.md` |
| `.swift` | Swift | `languages/swift.md` |
| `.ts`, `.tsx` | TypeScript | `languages/typescript.md` |
| `.go` | Go | `languages/go.md` |
| `.kt` | Kotlin | `languages/kotlin.md` |
| `.py` | Python | `languages/python.md` |
| `.rs` | Rust | `languages/rust.md` |
| `.java` | Java | `languages/java.md` |

---

## --recommend Mode

When `--recommend` is specified, do not perform a full audit. Instead, identify the top audit candidates:

```bash
# Step 1: Entropy scan
if [ -f ~/.claude/scripts/atlas/scan-entropy.sh ]; then
    bash ~/.claude/scripts/atlas/scan-entropy.sh .
fi

# Step 2: Git hotspot analysis
git log --format=format: --name-only --since="6 months ago" | sort | uniq -c | sort -rn | head -20
```

**Ranking Criteria**: high entropy x high git change frequency x high coupling

Output format:
```
SourceAtlas: Audit --recommend
-------------------------------

| # | File | Lines | Language | Entropy | Git Changes | Recommendation |
|---|------|-------|----------|---------|-------------|----------------|
| 1 | ... | ... | ... | ... | ... | ... |

Enter a number or run: /sourceatlas:audit "<file>"
```

**End after recommendation output; do not proceed to Phase A.**

---

## Your Task

Execute **Phase A: Contract Extraction** using multi-LLM cross-validation pipeline.

**Theoretical Basis**: Michael Feathers "Working Effectively with Legacy Code" -- characterization tests at the behavioral contract level rather than unit test level.

**Pipeline Overview (Phase A)**:

| Step | Purpose | Agent |
|------|---------|-------|
| Step 0 | Boundary discovery (rg static scan) | Local tools |
| Step 0.5 | Language plugin loading | Local tools |
| Step 1 | Blind scan -- independent contract discovery | Gemini |
| Step 1.5 | Dependency graph analysis -- Seam identification | Claude |
| Step 2 | Structured audit -- contracts + verification scripts | Claude |
| Step 2.5 | Feathers analysis (Tell the Story / Scratch Refactoring / Effect Propagation) | Claude |
| Step 3 | Adversarial review -- CONFIRM/DISPUTE/ADD | Codex |
| Step 4 | Merge -- final contracts + verification rules + Pinch Point identification | Claude |
| Step 5 | Output generation + save | Local tools |

---

## Core Workflow

Execute these phases in order. See [workflow.md](workflow.md) for complete details.

### Step 0: Boundary Discovery

**Purpose**: Use `rg` to statically scan related files around the target module.

Discover:
- Observer/notification patterns
- Synchronization primitives
- External dependencies (imports, includes)
- Related test files

> See [workflow.md#step-0](workflow.md#step-0-boundary-discovery) for detailed commands

### Step 0.5: Language Plugin Loading

**Purpose**: Load the appropriate language plugin based on detected or specified language.

Plugin provides:
- Notification/event primitives
- Synchronization primitives
- Lifecycle patterns
- Verification strategy (grep / ast-grep / both)
- Effect firewall mechanisms
- Seam types and dependency-breaking techniques
- Sprout/Wrap safe change strategies

> See [workflow.md#step-05](workflow.md#step-05-language-plugin-loading) for details

### Step 1-4: Multi-LLM Pipeline

**Purpose**: Three-way cross-validation to extract and verify behavioral contracts.

Contract Taxonomy (8 categories):
- **M**: Mutation -- side-effect modifications
- **L**: Lifecycle -- implicit state transitions
- **N**: Notification -- pub/sub coupling
- **S**: Synchronization -- blocking, locking, ordering
- **E**: Error Handling -- swallowed vs propagated errors
- **C**: Cancellation -- cancel scope and residual state
- **D**: Dependency -- external entity dependencies
- **P**: Propagation -- effect propagation paths

> See [workflow.md#step-1-4](workflow.md#step-1-multi-llm-pipeline) for each agent's role

### Step 5: Output Generation

**Purpose**: Compile final contracts into YAML output conforming to `contract-output.schema.yaml`.

> See [output-template.md](output-template.md) for complete YAML structure

---

## Output Format

Generate output with **branded header**, then **YAML format**:

```markdown
SourceAtlas: Audit
-------------------------------
[module_name] | [language] | [total_contracts] contracts
```

Then YAML content conforming to `contract-output.schema.yaml`:
- `version`: Schema version
- `module`: Module name
- `language`: Language identifier
- `run_id`: Pipeline execution ID
- `refactoring_intent`: Refactoring description
- `total_contracts`: Contract count
- `pinch_points`: Pinch Point count
- `contracts`: Contract list with id, type, description, evidence, severity, scope, seam_type, pinch_point, verification, adversary_status

> See [output-template.md](output-template.md) for complete YAML structure and examples

---

## Critical Rules

1. **Read Every Line**: Do not skip or summarize any part of the target module
2. **Evidence Required**: Every contract must have at least one `file:line` reference
3. **Contract ID Format**: Must match `^[MLNSECDP]-[0-9]{3}$`
4. **CONFIRM_RATIO Threshold**: Adversarial review CONFIRM ratio must be <=70%
5. **Line Attribution Complete**: Every executable line must be classified (CONTRACT/INFRA/SKIP)
6. **Quality Gates**: All 10 quality gates must pass before output
7. **Metadata Complete**: Every contract must include scope, seam_type, pinch_point
8. **Feathers Analysis**: F1, F2, F3 analyses must be executed and integrated

---

## Handoffs Decision Rules

> Follow **Constitution Article VII: Handoffs Principles**

**Choose ONE output, NOT both:**

**Case A - End (No Table):**
When module is simple enough that contracts are straightforward:
- Total contracts < 5
- No CRITICAL or HIGH severity contracts found

Output:
```markdown
Analysis complete -- Module has minimal implicit contracts, safe to refactor directly
```

**Case B - Suggestions (Table):**
When additional analysis would improve refactoring safety:

| Finding | Command | Parameter |
|---------|---------|-----------|
| Complex dependencies | `/sourceatlas:flow` | Module entry point |
| High coupling | `/sourceatlas:deps` | Module name |
| Frequent changes | `/sourceatlas:history` | No parameters |
| Related modules need audit | `/sourceatlas:audit` | Related module file |

Format:
```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:audit "RelatedModule.swift"` | Found 5 D-type contracts referencing this module |

Enter a number (e.g., `1`) or copy the command to execute
```

---

## Self-Verification Phase (REQUIRED)

> **Purpose**: Ensure all contracts have valid evidence, correct IDs, and complete metadata.
> Execute AFTER output generation, BEFORE save.

> See [verification-guide.md](verification-guide.md) for complete verification checklist

---

## Auto-Save (Default Behavior)

After verification passes, automatically:

1. Create directory: `mkdir -p .sourceatlas/audit`
2. Save YAML output to: `.sourceatlas/audit/{module}.yaml`
3. Confirm: `Saved to .sourceatlas/audit/{module}.yaml`

---

## Advanced

- **Contract taxonomy**: [../../README.md#contract-taxonomy](../../README.md#合約分類法語言無關)
- **Language plugins**: [../../prompts/languages/](../../prompts/languages/)
- **Pipeline architecture**: [../../README.md#architecture](../../README.md#架構設計)
- **Feathers methodology**: [../../README.md#feathers](../../README.md#理論基礎feathersworking-effectively-with-legacy-code)
- **Schema definition**: [../../pipeline/contract-output.schema.yaml](../../pipeline/contract-output.schema.yaml)

---

## Output Header

Start your output with:

```markdown
SourceAtlas: Audit
-------------------------------
[module_name] | [language] | [total_contracts] contracts
```

Then follow YAML structure in [output-template.md](output-template.md).
