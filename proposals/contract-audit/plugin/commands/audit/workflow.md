# Audit Workflow Guide

Complete step-by-step execution guide for behavioral contract audit (Phase A + Phase B).

---

## Overview

This workflow extracts implicit behavioral contracts from legacy code modules using multi-LLM cross-validation, producing machine-verifiable assertions for CI/CD integration.

**Time Budget**: 30-60 minutes (depending on module complexity)

**Pipeline**: Step 0 -> 0.5 -> 1 -> 1.5 -> 2 -> 2.5 -> 3 -> 4 -> 5

---

## Phase A: Contract Extraction (One-Time)

### Step 0: Boundary Discovery

#### Purpose

Use `rg` to statically scan files related to the target module, establishing the audit perimeter.

#### Step 0.1: Identify Target Files

```bash
# Locate target module
TARGET="${ARGUMENTS%%--*}"  # Strip flags
TARGET=$(echo "$TARGET" | xargs)  # Trim whitespace

# Find the target file
find . -name "$TARGET" -not -path "*/node_modules/*" -not -path "*/.venv/*" 2>/dev/null
```

#### Step 0.2: Discover Related Files

```bash
MODULE_NAME="${TARGET%.*}"  # Strip extension

# Find files that import/include the target module
rg -l "$MODULE_NAME" --type-add 'code:*.{m,h,swift,ts,tsx,go,kt,py,rs,java}' -t code 2>/dev/null

# Find test files
find . -name "*${MODULE_NAME}*test*" -o -name "*${MODULE_NAME}*spec*" -o -name "*test*${MODULE_NAME}*" 2>/dev/null | head -10
```

#### Step 0.3: Discover Patterns

Based on language, scan for relevant patterns:

```bash
# Observer/notification patterns (language-specific, examples below)
rg 'NSNotification|NotificationCenter|addEventListener|EventEmitter|channel\s' "$TARGET_FILE" 2>/dev/null

# Synchronization primitives
rg 'dispatch_semaphore|mutex|sync\.Mutex|Lock|Semaphore|synchronized' "$TARGET_FILE" 2>/dev/null

# External dependencies (imports)
rg '^import |^#import |^from .* import |^require\(' "$TARGET_FILE" 2>/dev/null
```

#### Step 0.4: Boundary Summary

Compile a boundary report:

```
Boundary Discovery Report
-------------------------
Target: [filename] ([N] lines)
Related files: [count]
Import dependencies: [list]
Observer patterns found: [count]
Sync primitives found: [count]
Test coverage: [exists/none]
```

---

### Step 0.5: Language Plugin Loading

#### Purpose

Load the appropriate language plugin to configure language-specific analysis parameters.

#### Step 0.5.1: Determine Language

```bash
# From --language flag or file extension
LANG_FLAG=$(echo "${ARGUMENTS}" | grep -oP '(?<=--language\s)\w+')
if [ -z "$LANG_FLAG" ]; then
    # Auto-detect from file extension
    EXT="${TARGET##*.}"
    case "$EXT" in
        m|h) LANGUAGE="objc" ;;
        swift) LANGUAGE="swift" ;;
        ts|tsx) LANGUAGE="typescript" ;;
        go) LANGUAGE="go" ;;
        kt) LANGUAGE="kotlin" ;;
        py) LANGUAGE="python" ;;
        rs) LANGUAGE="rust" ;;
        java) LANGUAGE="java" ;;
        *) echo "Unsupported language: $EXT"; exit 1 ;;
    esac
else
    LANGUAGE="$LANG_FLAG"
fi
```

#### Step 0.5.2: Load Plugin

Read the language plugin file for language-specific configuration:

```bash
# Check plugin locations
PLUGIN_PATH=""
for path in \
    "prompts/languages/${LANGUAGE}.md" \
    "proposals/contract-audit/prompts/languages/${LANGUAGE}.md"; do
    if [ -f "$path" ]; then
        PLUGIN_PATH="$path"
        break
    fi
done

if [ -z "$PLUGIN_PATH" ]; then
    echo "Warning: Language plugin not found for ${LANGUAGE}, using skeleton only"
fi
```

Plugin provides:
- Notification/event primitives specific to the language
- Synchronization primitives specific to the language
- Lifecycle patterns (framework-specific hooks)
- Verification strategy (grep / ast-grep / both)
- Effect firewall mechanisms
- Seam types and recommended dependency-breaking techniques
- Sprout/Wrap safe change strategies
- Common implicit contract examples

#### Step 0.5.3: Determine Verification Strategy

| Language | ast-grep | grep | Recommended |
|----------|----------|------|-------------|
| Swift | Yes | Yes | ast-grep primary |
| Go | Yes | Yes | ast-grep primary |
| TypeScript | Yes | Yes | ast-grep primary |
| Python | Yes | Yes | ast-grep primary |
| Rust | Yes | Yes | ast-grep primary |
| Java | Yes | Yes | ast-grep primary |
| Kotlin | Yes | Yes | ast-grep primary |
| Objective-C | No | Yes | grep only |

---

### Step 1: Blind Scan (Gemini)

#### Purpose

Independent contract discovery without prior context. Gemini reads the target module and produces a raw list of implicit behaviors.

#### Agent

Gemini (or equivalent broad-context LLM)

#### Input

- Target module source code (full text, every line)
- Language identifier
- No prior analysis results (blind)

#### Output

- Raw contract candidates (not necessarily in final taxonomy format)
- External dependency discoveries
- Suspected behavioral patterns

#### Degradation Strategy

If Gemini is unavailable:
- Use Claude with explicit instruction to perform "blind scan" mode
- Mark output as `blind_scan_agent: claude_fallback`
- Proceed to Step 2 with awareness that cross-validation independence is reduced

---

### Step 1.5: Dependency Graph Analysis

#### Purpose

Identify Seams (from Feathers methodology), map dependency directions, and find Pinch Points before structured audit.

#### Agent

Claude (strong reasoning for graph analysis)

#### Step 1.5.1: Build Dependency Direction Graph

From import/include statements, build a module-level dependency graph:

```
ModuleA -> ModuleB (import)
ModuleA -> ModuleC (import)
ModuleB -> ModuleD (import)
ModuleC -> ModuleD (import)  <- ModuleD is a Pinch Point
```

#### Step 1.5.2: Seam Identification

For each dependency, identify the Seam type:

| Seam Type | Description | Example |
|-----------|-------------|---------|
| Object | Replaceable via object substitution (DI, Protocol/Interface) | `init(service: ServiceProtocol)` |
| Preprocessing | Compile-time replaceable (macros, conditional compilation) | `#if DEBUG` |
| Link | Link-time replaceable (dynamic library, module alias) | `@testable import` |
| None | Hard dependency, no seam available | Direct class instantiation |

#### Step 1.5.3: Pinch Point Identification

Find nodes where multiple dependency paths converge. These contracts have highest ROI for CI rules.

#### Output

```yaml
dependency_analysis:
  total_dependencies: [N]
  seams:
    object: [count]
    preprocessing: [count]
    link: [count]
    none: [count]
  pinch_points:
    - module: [name]
      converging_paths: [count]
      recommended_action: [description]
```

---

### Step 2: Structured Audit (Claude)

#### Purpose

Systematic contract extraction using the skeleton prompt + language plugin. Produces Artifact 1-4.

#### Agent

Claude Opus (strong reasoning for contract analysis)

#### Input

- Target module source code (full text)
- Language plugin configuration
- Boundary discovery report (Step 0)
- Dependency graph analysis (Step 1.5)
- Skeleton prompt (`prompts/skeleton.md`)

#### Process

1. Apply Contract Taxonomy (M/L/N/S/E/C/D/P) to every line
2. For each contract:
   - Assign stable ID (e.g., `M-001`)
   - Document trigger, input, output, condition, ordering, risk
   - Attach evidence (file:line)
   - Set metadata (scope, seam_type, pinch_point)
3. Generate verification scripts (grep and/or ast-grep)

#### Output

- **Artifact 1**: Contract Spec Document
- **Artifact 2**: Verification Scripts (grep + ast-grep)
- **Artifact 3**: Coverage Table
- **Artifact 4**: Line Attribution Table

---

### Step 2.5: Feathers Analysis

#### Purpose

Apply three analytical techniques from "Working Effectively with Legacy Code" to discover contracts that taxonomy-based scanning might miss.

#### Agent

Claude Opus (integrated with Step 2)

#### F1: Tell the Story

Describe the module in 3 core concepts, then list the "lies" (omissions that are dangerous during refactoring).

```
STORY: [one-sentence description using 3 concepts]
LIES:
- [omission 1]: [why dangerous during refactoring]
- [omission 2]: ...
```

#### F2: Scratch Refactoring

Describe (not execute) top 3 refactoring operations. For each, identify hidden contracts revealed.

```
SCRATCH_REFACTORING:
1. [operation]
   REVEALS: [contract IDs or "NEW"]
2. ...
```

If new contracts are discovered, add them to Artifact 1 immediately.

#### F3: Effect Propagation Tracing

For every public method, trace three effect types:

```
EFFECT_TRACE: [method signature]
  RETURN:  [chain description or "void"]
  MUTATES: [parameter list or "none"]
  GLOBAL:  [global state changes or "none"]
  DEPTH:   [propagation depth]
```

Tag results as Category P contracts in Artifact 1.

---

### Step 3: Adversarial Review (Codex)

#### Purpose

Cross-validate contracts from Step 1 (Blind Scan) and Step 2 (Structured Audit) with adversarial perspective.

#### Agent

Codex (or equivalent adversarial reviewer)

#### Input

- Contract list from Step 2
- Blind scan results from Step 1
- Target module source code

#### Process

For each contract, produce one verdict:

| Verdict | Meaning | Action |
|---------|---------|--------|
| CONFIRM | Contract is valid and well-evidenced | Keep as-is |
| DISPUTE | Contract is incorrect, over-stated, or under-evidenced | Mark for revision |
| ADD | New contract discovered by adversarial analysis | Add to contract list |

#### Quality Gate

**CONFIRM_RATIO must be <=70%**

If CONFIRM_RATIO > 70%, the structured audit may have been too conservative. The adversarial reviewer should:
- Look harder for edge cases
- Challenge assumptions about error handling
- Verify ordering/timing claims

#### Degradation Strategy

If Codex is unavailable:
- Use Claude with explicit adversarial persona instruction
- Mark output as `adversary_agent: claude_fallback`
- Apply stricter self-review

---

### Step 4: Merge (Claude)

#### Purpose

Mechanically apply adversarial corrections to produce final contract set.

#### Agent

Claude (merger role -- no judgment, only apply changes with evidence)

#### Process

1. Apply all CONFIRM verdicts: keep contracts unchanged
2. Apply all DISPUTE verdicts: revise or remove contracts per adversary reasoning
3. Apply all ADD verdicts: add new contracts with full metadata
4. Recalculate totals and Pinch Point count
5. Identify final Pinch Points from dependency analysis

#### Rules

- Do not add judgment beyond what the adversary provided
- Do not infer changes without explicit evidence
- Preserve contract ID stability (do not renumber)

---

### Step 5: Output Generation

#### Purpose

Compile final contracts into YAML output conforming to `contract-output.schema.yaml`.

#### Process

1. Generate branded header
2. Compile YAML with all required fields
3. Execute self-verification (see [verification-guide.md](verification-guide.md))
4. Save to `.sourceatlas/audit/{module}.yaml`

---

## Phase B: CI Rules (Per PR)

### Purpose

Deterministic, no-LLM CI checks that validate contracts are not violated by code changes.

### B1: grep Assertions

```bash
# Run verification script
bash verify-contracts-{ModuleName}.sh
```

Each contract has a `grep -qn` assertion. Any failure blocks the PR.

### B2: ast-grep Rules

```bash
# Run ast-grep with contract rules
ast-grep scan --rule .ast-grep/rules/{ModuleName}/
```

Each contract has a `.yml` rule file. Any violation blocks the PR.

### B3: Failure Handling

| Failure Type | Action |
|-------------|--------|
| grep assertion fails | Contract may have been removed/refactored -- requires human review |
| ast-grep rule violation | Structural contract violated -- requires fix or contract update |
| Multiple failures | Possible major refactoring -- re-run Phase A audit |

---

## Error Handling and Degradation

### LLM Unavailability

| Agent | Role | Fallback |
|-------|------|----------|
| Gemini | Blind scan | Claude with blind-scan persona |
| Claude | Structured audit | No fallback (core agent) |
| Codex | Adversarial review | Claude with adversarial persona |

When fallback is used:
- Mark in output: `fallback_agents: [list]`
- Note reduced cross-validation independence
- Consider re-running with proper agents when available

### Target Module Issues

| Issue | Recovery |
|-------|----------|
| File not found | Search by module name, prompt for correct path |
| File too large (>2000 lines) | Split into logical sections, audit each |
| Binary/generated file | Skip with warning |
| No language plugin | Use skeleton only, mark `language_plugin: none` |

---

## Performance Tips

### For Large Modules

- Focus on public API first (highest contract density)
- Use Step 0 boundary discovery to limit scope
- Split into logical sections if > 1000 lines

### For Multiple Related Modules

- Run `--recommend` first to prioritize
- Audit highest-risk module first
- Reuse dependency graph for related modules

---

## Common Issues

### Issue 1: CONFIRM_RATIO Too High

**Symptom**: Adversarial review confirms >70% of contracts

**Solution**:
- Instruct adversary to look harder for edge cases
- Check if error handling contracts (E) are over-simplified
- Verify synchronization claims (S) with concrete thread analysis

### Issue 2: Too Many Contracts

**Symptom**: >100 contracts for a single module

**Solution**:
- Merge contracts with same trigger and similar effects
- Check for duplicates between M and P categories
- Verify each contract is truly independent

### Issue 3: Language Plugin Not Found

**Symptom**: No plugin for target language

**Solution**:
- Use skeleton.md only (language-agnostic parts)
- Mark output with `language_plugin: none`
- Consider creating a new language plugin (see plugin template)

---

## Output Transition

After Step 5 completes:
1. Compile all contracts into YAML
2. Structure as per [output-template.md](output-template.md)
3. Execute verification (see [verification-guide.md](verification-guide.md))
4. Save result to `.sourceatlas/audit/{module}.yaml`
