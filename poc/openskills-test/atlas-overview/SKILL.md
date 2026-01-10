---
name: atlas-overview
description: Get project overview - scan <5% of files to achieve 70-80% understanding
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "[path] [--force] (e.g., 'src/api' or '. --force')"
---

# SourceAtlas: Project Overview (Stage 0 Fingerprint)

> **Constitution**: This command operates under ANALYSIS_CONSTITUTION.md v1.0
>
> Key principles enforced:
> - Article I: High-entropy priority, scan ratio limits
> - Article II: Mandatory directory exclusions
> - Article III: Hypothesis count limits, required elements
> - Article IV: Evidence format requirements

## Context

**Arguments**: ${ARGUMENTS:-.}

**Auto-Save**: Results automatically saved to `.sourceatlas/overview.yaml`
- Creates `.sourceatlas/` directory if needed

**Analysis Target**: Parse from arguments (default: current directory)

**Goal**: Generate a comprehensive project fingerprint by scanning <5% of files to achieve 70-80% understanding.

---

## Your Task

Execute **Stage 0 Analysis Only** - generate a project overview using information theory principles.

### Phase 1: Project Detection & Scale-Aware Planning

Use the enhanced detection script for accurate file counts and scale-aware recommendations.

```bash
if [ -f ~/.claude/scripts/atlas/detect-project.sh ]; then
    bash ~/.claude/scripts/atlas/detect-project.sh ${ARGUMENTS:-.}
elif [ -f scripts/atlas/detect-project.sh ]; then
    bash scripts/atlas/detect-project.sh ${ARGUMENTS:-.}
else
    echo "Warning: detect-project.sh not found, using manual detection"
fi
```

**Scale-Aware Scan Limits**:
- **TINY** (<5 files): Scan 1-2 files max (50%)
- **SMALL** (5-15 files): Scan 2-3 files (10-20%)
- **MEDIUM** (15-50 files): Scan 4-6 files (8-12%)
- **LARGE** (50-150 files): Scan 6-10 files (4-7%)
- **VERY_LARGE** (>150 files): Scan 10-15 files (3-7%)

### Phase 2: High-Entropy File Prioritization

Apply information theory - **high-entropy files contain disproportionate information**.

**Scan Priority Order**:
1. **Documentation** - README.md, CLAUDE.md, docs/
2. **Configuration** - package.json, tsconfig.json, etc.
3. **Core Models** - models/, entities/, domain/
4. **Entry Points** - main.*, index.*, app.*
5. **Tests** - Key test files

### Phase 3: Generate Hypotheses

Generate hypotheses about:
- **Technology Stack**: Languages, frameworks, databases
- **Architecture**: Patterns, layering, separation of concerns
- **Development Practices**: Testing, documentation, git workflow
- **AI Collaboration**: Tool detection (CLAUDE.md, .cursorrules, etc.)
- **Business Domain**: What the project does

Each hypothesis must include:
- **Confidence level** (0.0-1.0)
- **Evidence** (specific files/lines)
- **Validation method**

---

## Output Format

```markdown
🗺️ SourceAtlas: Overview
───────────────────────────────
🔭 [project_name] │ [SCALE] ([file count] files)
```

Then YAML content with:
- metadata (project_name, scan_time, total_files, scanned_files, scan_ratio)
- project_fingerprint (type, scale, language, framework, architecture)
- tech_stack (backend, frontend, infrastructure)
- hypotheses (architecture, tech_stack, development, ai_collaboration, business)
- scanned_files (file, reason, key_insight)
- summary (understanding_depth, key_findings)

---

## Critical Rules

1. **Scale-Aware Scanning**: Follow recommended file limits
2. **Exclude Bloat**: Never scan .venv/, node_modules/, vendor/, __pycache__, .git/
3. **Hypothesis Quality**: Each must have confidence level and evidence
4. **No Deep Diving**: Understand structure > implementation details

---

## Auto-Save

After analysis, automatically save to `.sourceatlas/overview.yaml`

```bash
mkdir -p .sourceatlas
```

File naming:
- Root: `.sourceatlas/overview.yaml`
- Subdirectory: `.sourceatlas/overview-src-api.yaml`
