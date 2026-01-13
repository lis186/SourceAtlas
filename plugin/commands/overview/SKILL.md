---
name: overview
description: Get project overview - scan <5% of files to achieve 70-80% understanding
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "[path] [--force] (e.g., 'src/api' or '. --force')"
---

# SourceAtlas: Project Overview (Stage 0 Fingerprint)

> **Constitution**: [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md) v1.0

## Context

**Arguments**: ${ARGUMENTS:-.}

**Goal**: Generate project fingerprint by scanning <5% of files to achieve 70-80% understanding in 10-15 minutes.

**Auto-Save**: Results automatically saved to `.sourceatlas/overview.yaml` (or subdirectory-specific path)

**Time Limit**: 10-15 minutes (typically 0-5 minutes)

---

## Cache Check (Highest Priority)

**If `--force` is NOT in arguments**, check cache first:

1. Calculate cache path:
   - No path argument or `.`: `.sourceatlas/overview.yaml`
   - With path (e.g., `src/api`): `.sourceatlas/overview-src-api.yaml`

2. Check if cache exists:
   ```bash
   ls -la .sourceatlas/overview.yaml 2>/dev/null
   ```

3. **If cache exists**:
   - Calculate days since modification
   - Use Read tool to read cache
   - Output:
     ```
     📁 Loading cache: .sourceatlas/overview.yaml (N days ago)
     💡 Add --force to re-analyze
     ```
   - **If over 30 days**: Show warning
   - Output cache content
   - **End, do not execute analysis**

4. **If cache does not exist**: Continue with analysis

**If `--force` is in arguments**: Skip cache, execute analysis

---

## Your Task

Execute **Stage 0 Analysis Only** - generate project fingerprint using information theory principles.

**Information Theory Approach:**
- **High-entropy files** contain disproportionate information
- Scan priority: Documentation → Configuration → Models → Entry Points → Tests
- **Scale-aware**: TINY/SMALL/MEDIUM/LARGE/VERY_LARGE projects need different approaches

---

## Core Workflow

Execute these phases in order. See [workflow.md](workflow.md) for complete details.

### Phase 1: Project Detection & Scale-Aware Planning (2-3 minutes)

**Purpose:** Detect project type, count files, determine scale, set scan limits.

**Execute detection:**
```bash
# Try helper script first (recommended)
if [ -f ~/.claude/scripts/atlas/detect-project.sh ]; then
    bash ~/.claude/scripts/atlas/detect-project.sh ${ARGUMENTS:-.}
elif [ -f scripts/atlas/detect-project.sh ]; then
    bash scripts/atlas/detect-project.sh ${ARGUMENTS:-.}
else
    echo "Warning: detect-project.sh not found, using manual detection"
fi
```

**Scale-Aware Scan Limits:**
- **TINY** (<5 files): 1-2 files (50% max)
- **SMALL** (5-15 files): 2-3 files (10-20%)
- **MEDIUM** (15-50 files): 4-6 files (8-12%)
- **LARGE** (50-150 files): 6-10 files (4-7%)
- **VERY_LARGE** (>150 files): 10-15 files (3-7%)

→ See [workflow.md#phase-1](workflow.md#phase-1-project-detection--scale-aware-planning-2-3-minutes) for manual fallback

### Phase 2: High-Entropy File Prioritization (5-8 minutes)

**Purpose:** Scan highest information-density files first.

**Scan Priority Order:**
1. **Documentation** (README.md, CLAUDE.md, docs/)
2. **Configuration** (package.json, docker-compose.yml, etc.)
3. **Core Models** (models/, entities/, domain/) - pick 2-3 only
4. **Entry Points** (app.ts, routes/) - pick 1-2 examples
5. **Tests** - pick 1-2 examples

**Execute scanning:**
```bash
# Use helper script if available
if [ -f ~/.claude/scripts/atlas/scan-entropy.sh ]; then
    bash ~/.claude/scripts/atlas/scan-entropy.sh ${ARGUMENTS:-.}
else
    echo "Warning: scan-entropy.sh not found, scanning manually"
fi
```

**AI Tool Detection:**
```bash
# Detect AI collaboration level (Tier 1 + Tier 2)
if [ -f ~/.claude/scripts/atlas/detect-ai-tools.sh ]; then
    bash ~/.claude/scripts/atlas/detect-ai-tools.sh ${ARGUMENTS:-.}
else
    # Fallback: manual checks
    ls -la CLAUDE.md .cursorrules .windsurfrules CONVENTIONS.md AGENTS.md .aiignore 2>/dev/null
    ls -la .claude/ .cursor/rules/ .windsurf/rules/ .clinerules/ .roo/ .continue/rules/ .ruler/ 2>/dev/null
fi
```

→ See [workflow.md#phase-2](workflow.md#phase-2-high-entropy-file-prioritization-5-8-minutes) for manual commands

### Phase 3: Generate Hypotheses (3-5 minutes)

**Purpose:** Generate scale-appropriate hypotheses with confidence levels and evidence.

**Hypothesis Categories:**
- **Technology Stack**: Languages, frameworks, databases, testing
- **Architecture**: Patterns, structure, layering
- **Development Practices**: Code quality, testing, documentation
- **AI Collaboration**: Tool detection (Level 0-4)
- **Business Domain**: Purpose, entities, features

**Scale-Aware Targets:**
- TINY: 5-8 hypotheses
- SMALL: 7-10 hypotheses
- MEDIUM: 10-15 hypotheses
- LARGE: 12-18 hypotheses
- VERY_LARGE: 15-20 hypotheses

**Each hypothesis must include:**
- hypothesis: Clear statement
- confidence: 0.0-1.0 (aim for >0.7)
- evidence: file:line references
- validation_method: How to verify

→ See [workflow.md#phase-3](workflow.md#phase-3-generate-hypotheses-3-5-minutes) for detailed guidance

---

## Output Format

Generate output with **branded header**, then **YAML format**:

```markdown
🗺️ SourceAtlas: Overview
───────────────────────────────
🔭 [project_name] │ [SCALE] ([file count] files)
```

Then YAML content with sections:
- `metadata`: project_name, scan_time, total_files, scanned_files, scan_ratio, project_scale, context
- `project_fingerprint`: project_type, scale, primary_language, framework, architecture
- `tech_stack`: backend, frontend (optional), infrastructure (optional)
- `hypotheses`: architecture, tech_stack, development, ai_collaboration, business
- `scanned_files`: List with file, reason, key_insight
- `summary`: understanding_depth, key_findings

→ See [output-template.md](output-template.md) for complete YAML structure and examples

---

## Critical Rules

1. **Scale-Aware Scanning**: Follow recommended file limits from Phase 1
2. **Exclude Common Bloat**: Never scan .venv/, node_modules/, vendor/, __pycache__, .git/
3. **Time Limit**: Complete in 10-15 minutes (typically 0-5 minutes)
4. **Hypothesis Quality**: Each must have confidence >0.7 and evidence
5. **Scale-Aware Targets**: Use hypothesis targets appropriate for project scale
6. **No Deep Diving**: Understand structure > implementation details
7. **STOP after Stage 0**: Do not proceed to validation or git analysis

---

## Handoffs Decision Rules

> Follow **Constitution Article VII: Handoffs Principles**

**⚠️ Choose ONE output, NOT both:**

**Case A - End (No Table):**
When any condition is met:
- Project too small: TINY (<10 files)
- Findings too vague: Cannot provide high confidence (>0.7) parameters
- Goal achieved: AI collaboration Level ≥3 and scale TINY/SMALL

Output:
```markdown
✅ **Analysis sufficient** - Project is small, can read all files directly
```

**Case B - Suggestions (Table):**
When project scale is large enough or clear next steps exist.

| Finding | Command | Parameter |
|---------|---------|-----------|
| Clear patterns | `/sourceatlas:pattern` | Pattern name |
| Complex architecture | `/sourceatlas:flow` | Entry point file |
| Scale ≥ LARGE | `/sourceatlas:history` | No parameters |
| High risk areas | `/sourceatlas:impact` | Risk file/module |

Format:
```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:pattern "repository"` | Found Repository pattern in 15 files |

💡 Enter a number (e.g., `1`) or copy the command to execute
```

→ See [reference.md#handoffs](reference.md#handoffs-decision-rules) for detailed logic

---

## Self-Verification Phase (REQUIRED)

> **Purpose**: Prevent hallucinated file paths, incorrect counts, fictional configs.
> Execute AFTER output generation, BEFORE save.

**Verification Steps:**

### Step V1: Extract Verifiable Claims

Extract from generated YAML:
- File paths (`scanned_files[].file`)
- Config files (`tools_detected[].config_file`)
- File count (`metadata.total_files`)
- Git branch (`metadata.context.git_branch`)
- Evidence references (`hypotheses.*.evidence`)

### Step V2: Parallel Verification

Run ALL checks in parallel:
- Verify scanned files exist: `test -f path`
- Verify AI tool configs exist: `test -f config`
- Verify file count: ±10% tolerance
- Verify git branch: `git branch --show-current`
- Verify evidence files exist

### Step V3: Handle Results

- ✅ All pass → Continue to output/save
- ⚠️ 1-2 fail → Correct claims, note in summary
- ❌ 3+ fail → Re-execute analysis phases

### Step V4: Verification Summary

Add to footer:

**If all passed:**
```
✅ Verified: [N] scanned files, [M] config paths, file count
```

**If corrected:**
```
🔧 Self-corrected: [list corrections]
✅ Verified: [N] scanned files, [M] config paths, file count
```

→ See [verification-guide.md](verification-guide.md) for complete checklist and examples

---

## Auto-Save (Default Behavior)

After verification passes, automatically:

1. Create directory: `mkdir -p .sourceatlas`
2. Save YAML output to:
   - Root: `.sourceatlas/overview.yaml`
   - Subdirectory: `.sourceatlas/overview-[path].yaml`
3. Confirm: `💾 Saved to .sourceatlas/overview.yaml`

→ See [reference.md#auto-save](reference.md#auto-save-behavior) for details

---

## Advanced

- **Scale-aware analysis**: [reference.md#scale-aware-analysis](reference.md#scale-aware-analysis)
- **Helper scripts**: [reference.md#helper-scripts](reference.md#helper-scripts)
- **Cache behavior**: [reference.md#cache-behavior](reference.md#cache-behavior)
- **AI collaboration detection**: [reference.md#ai-collaboration-detection](reference.md#ai-collaboration-detection)
- **Information theory**: [reference.md#information-theory-principles](reference.md#information-theory-principles)

---

## Output Header

Start your output with:

```markdown
🗺️ SourceAtlas: Overview
───────────────────────────────
🔭 [project_name] │ [SCALE] ([file count] files)
```

Then follow YAML structure in [output-template.md](output-template.md).
