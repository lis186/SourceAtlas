---
name: pattern
description: Learn design patterns from the current codebase
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: [pattern type, e.g., "api endpoint", "background job"] [--force] [--brief|--full]
---

# SourceAtlas: Pattern Learning Mode

> **Constitution**: [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md) v1.0

## Context

**Pattern requested:** $ARGUMENTS
**Goal:** Learn how THIS specific codebase implements the requested pattern
**Time Limit:** 5-10 minutes maximum

## Quick Start

1. **Check cache** (skip if `--force` flag present)
2. **Detect pattern** using `find-patterns.sh` script
3. **Apply output mode** (--brief / --full / smart)
4. **Analyze top 2-3 files** (high-entropy priority)
5. **Extract conventions** and best practices
6. **Generate implementation guide**
7. **Verify output** using [verification-guide.md](verification-guide.md)
8. **Auto-save** to `.sourceatlas/patterns/`

## Your Task

You are analyzing how THIS codebase implements a specific pattern by:
1. Finding 2-3 best example files
2. Extracting design patterns and conventions
3. Providing actionable implementation guidance

### Output Modes

| Parameter | Behavior | Use Case |
|-----------|----------|----------|
| `--brief` | List files only | Quick file browser |
| `--full` | Analyze all files | Deep learning |
| (default) | Smart: ≤5 files→full; >5→selection UI | Balanced |

---

## Core Workflow

Execute these steps in order. See [workflow.md](workflow.md) for complete details.

### Step 0: Parse Output Mode (10 seconds)

**Purpose:** Determine how much analysis to perform.

Detect flags:
- `--brief` → List files only, no analysis
- `--full` → Analyze all found files
- No flag → Smart mode (adapt based on file count)

→ See [workflow.md#step-0](workflow.md#step-0-parse-output-mode-10-seconds)

### Step 1: Execute Pattern Detection (1-2 minutes)

**Purpose:** Find relevant files using optimized search.

**Use find-patterns.sh script first:**
```bash
# Locate script (global → local)
if [ -f ~/.claude/scripts/atlas/find-patterns.sh ]; then
    SCRIPT_PATH=~/.claude/scripts/atlas/find-patterns.sh
elif [ -f scripts/atlas/find-patterns.sh ]; then
    SCRIPT_PATH=scripts/atlas/find-patterns.sh
fi

bash "$SCRIPT_PATH" "$ARGUMENTS"
```

**Supported patterns:**
- api endpoint / api / endpoint
- background job / job / queue
- swiftui view / view
- view controller / viewcontroller
- authentication / auth / login
- file upload / upload
- database query / database
- networking / network

**If unsupported:** Fallback to manual Glob/Grep search

→ See [workflow.md#step-1](workflow.md#step-1-execute-pattern-detection-1-2-minutes)

### Step 1.5: ast-grep Enhanced Search (Optional)

**Purpose:** More precise search for content-based patterns.

**Use ast-grep-search.sh for:**
- async/await patterns
- suspend functions (Kotlin)
- custom hooks (React)
- goroutines (Go)

**Graceful degradation:** Script handles ast-grep unavailability

→ See [workflow.md#step-1-5](workflow.md#step-1-5-ast-grep-enhanced-search-optional)

### Step 2: Apply Output Mode Logic (30 seconds)

**Purpose:** Decide analysis depth based on file count.

**Smart mode logic:**
```
FILE_COUNT = 0      → "No files found"
FILE_COUNT ≤ 5      → Full analysis
FILE_COUNT > 5      → Selection interface
```

**Brief mode:** List files, end immediately

**Full mode:** Analyze all files (warn if >10)

→ See [workflow.md#step-2](workflow.md#step-2-apply-output-mode-logic-30-seconds)

### Step 3: Analyze Selected Files (3-5 minutes)

**Purpose:** Extract patterns from 2-3 best examples.

**High-entropy priority:**
- ✅ Main implementation files
- ✅ Complete examples (100-500 lines)
- ✅ Well-structured production code
- ❌ NOT: Utilities, trivial code, generated files

**Focus areas:**
1. Overall structure
2. Standard flow
3. Naming conventions
4. Dependencies
5. Error handling
6. Configuration

→ See [workflow.md#step-3](workflow.md#step-3-analyze-selected-files-3-5-minutes)

### Step 4: Extract the Pattern (2 minutes)

**Purpose:** Distill findings into reusable guidance.

**Extract:**
1. How this codebase handles it (2-3 sentences)
2. Standard flow (numbered steps)
3. Key conventions (bullet points)
4. Testing patterns
5. Common pitfalls

→ See [workflow.md#step-4](workflow.md#step-4-extract-the-pattern-2-minutes)

### Step 5: Find Related Tests (1 minute, optional)

**Purpose:** Understand how pattern is tested.

```bash
find . \( -path "*/test/*" -o -path "*/tests/*" -o -name "*.test.*" \) \
    -type f -not -path "*/node_modules/*" | head -20
```

→ See [workflow.md#step-5](workflow.md#step-5-find-related-tests-1-minute-optional)

### Step 6: Generate Implementation Guide (1 minute)

**Purpose:** Provide concrete steps to follow.

Create actionable, step-by-step guide with:
- Specific file locations
- Code structure templates
- Configuration steps
- Testing approach

→ See [workflow.md#step-6](workflow.md#step-6-generate-implementation-guide-1-minute)

---

## Output Format

Your analysis should follow this Markdown structure:

```markdown
🗺️ SourceAtlas: Pattern
───────────────────────────────
🧩 [Pattern Name] │ [N] files found

## Overview
[2-3 sentence summary]

## Best Examples
### 1. [File Path]:[line]
[Purpose, Key Code, Key Points]

### 2. [File Path]:[line]
[Same structure]

## Key Conventions
- [Convention 1]
- [Convention 2]
- [Convention 3]

## Testing Pattern
[Test location, approach, examples]

## Common Pitfalls to Avoid
1. [Pitfall 1]
2. [Pitfall 2]

## Step-by-Step Implementation Guide
1. [Step 1]
2. [Step 2]
...

## Related Patterns (Optional)
[If applicable]

## Recommended Next (Optional)
[Dynamic suggestions based on findings]
```

→ See [output-template.md](output-template.md) for complete specification and examples

---

## Critical Rules

### 1. Scan <5% of Files
- Use script for targeted search
- Read only top 2-3 files
- High-entropy priority

### 2. Focus on PATTERNS
- Extract reusable approaches
- Not line-by-line details
- Actionable conventions

### 3. Be Specific to THIS Codebase
- Not generic internet advice
- Actual code from this project
- Real file paths and examples

### 4. Provide Evidence
- file:line references always
- Code snippets from actual files
- Directory paths must exist

### 5. Time Limit: 5-10 Minutes
- Be efficient
- Don't read entire codebase
- Progressive disclosure

### 6. Verification Required
- Execute [verification-guide.md](verification-guide.md) after analysis
- Verify file paths, line numbers, code snippets
- Correct discrepancies before output

### 7. Constitutional Compliance
Follow [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md):
- **Article I**: High-entropy priority (scan 2-3 best examples)
- **Article II**: Mandatory exclusions (node_modules, .venv, Pods)
- **Article IV**: Evidence format (file:line references)

---

## Self-Verification

After generating your analysis, execute verification steps:

### Step V1: Extract Verifiable Claims
- File paths (with line numbers)
- Directory paths
- Code snippets
- File counts

### Step V2: Parallel Verification
- Verify file paths exist
- Verify line numbers within bounds
- Verify code snippets match files
- Verify directories exist
- Verify file counts (±2 tolerance)

### Step V3: Handle Results
- ✅ All checks pass → Proceed to output
- ⚠️ Minor issues (1-2 checks) → Correct and note
- ❌ Major issues (3+ checks) → Re-execute analysis

### Step V4: Add Verification Summary
```yaml
verification_summary:
  checks_performed: [...]
  confidence_level: "high"  # high|medium|low
  notes: [...]
```

→ See [verification-guide.md](verification-guide.md) for complete checklist

---

## Advanced

### Cache Behavior
- **Default**: Use cache if exists
- **Force flag**: Skip cache with `--force`
- **Cache location**: `.sourceatlas/patterns/${PATTERN_NAME}.md`
- **Cache age warning**: If >30 days old

→ See [reference.md#cache-behavior](reference.md#cache-behavior)

### Auto-Save Mechanism
Complete Markdown report auto-saves after verification:
```
💾 Saved to .sourceatlas/patterns/[pattern-name].md
```

→ See [reference.md#auto-save-behavior](reference.md#auto-save-behavior)

### Handoffs to Next Commands
Based on findings, suggest:
- Complex flow → `/sourceatlas:flow "[entry point]"`
- Wide usage → `/sourceatlas:impact "[core file]"`
- Related pattern → `/sourceatlas:pattern "[related]"`

→ See [reference.md#handoffs](reference.md#handoffs)

### find-patterns.sh Script
- Pre-tested patterns for common use cases
- Optimized search (<20 seconds)
- Relevance ranking (⭐⭐⭐ / ⭐⭐ / ⭐)
- Graceful fallback to manual search

### ast-grep Integration
- Content-based pattern search
- Higher precision for Type B patterns
- 14-93% false positive reduction
- Automatic fallback if unavailable

---

## Support Files

Detailed documentation available in:

- **[workflow.md](workflow.md)** - Complete Step 0-6 execution guide with bash commands
- **[output-template.md](output-template.md)** - Full Markdown structure and examples
- **[verification-guide.md](verification-guide.md)** - Self-verification steps V1-V4
- **[reference.md](reference.md)** - Cache, scripts, handoffs

---

## Output Header

Start your output with:

```markdown
🗺️ SourceAtlas: Pattern
───────────────────────────────
🧩 [Pattern Name] │ [N] files found
```

Then follow complete structure in [output-template.md](output-template.md).
