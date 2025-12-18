---
description: Get project overview - scan <5% of files to achieve 70-80% understanding
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: [path] [--save] [--force] (e.g., "src/api" or ". --save")
---

# SourceAtlas: Project Overview (Stage 0 Fingerprint)

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.0
>
> Key principles enforced:
> - Article I: High-entropy priority, scan ratio limits
> - Article II: Mandatory directory exclusions
> - Article III: Hypothesis count limits, required elements
> - Article IV: Evidence format requirements

## Context

**Arguments**: ${ARGUMENTS:-.}

**Save Mode**: Check if `--save` is in arguments. If present:
- Remove `--save` from path argument
- After analysis, save YAML to `.sourceatlas/overview.yaml`
- Create `.sourceatlas/` directory if needed

**Analysis Target**: Parse from arguments (default: current directory)

**Goal**: Generate a comprehensive project fingerprint by scanning <5% of files to achieve 70-80% understanding in 10-15 minutes.

---

## Cache Check (Highest Priority)

**If `--force` is NOT in arguments**, check cache first:

1. Calculate cache path:
   - No path argument or `.`: `.sourceatlas/overview.yaml`
   - With path argument (e.g., `src/api`): `.sourceatlas/overview-src-api.yaml` (slashes to `-`)

2. Check if cache exists:
   ```bash
   ls -la .sourceatlas/overview.yaml 2>/dev/null
   ```

3. **If cache exists**:
   - Read modification date from `ls` output
   - Calculate days since modification
   - Use Read tool to read cache content
   - Output:
     ```
     📁 Loading cache: .sourceatlas/overview.yaml (N days ago)
     💡 Add --force to re-analyze
     ```
   - **If over 30 days**, also show:
     ```
     ⚠️ Cache is over 30 days old, recommend re-analysis
     ```
   - Then output:
     ```
     ---
     [cache content]
     ```
   - **End, do not execute subsequent analysis**

4. **If cache does not exist**: Continue with the analysis flow below

**If `--force` is in arguments**: Skip cache check, execute analysis directly

---

## Your Task

Execute **Stage 0 Analysis Only** - generate a project overview using information theory principles.

### Phase 1: Project Detection & Scale-Aware Planning (2-3 minutes)

**IMPORTANT**: Use the enhanced detection script for accurate file counts and scale-aware recommendations.

```bash
# Run enhanced detection script (RECOMMENDED)
# Try global install first, then local
if [ -f ~/.claude/scripts/atlas/detect-project-enhanced.sh ]; then
    bash ~/.claude/scripts/atlas/detect-project-enhanced.sh ${ARGUMENTS:-.}
elif [ -f scripts/atlas/detect-project-enhanced.sh ]; then
    bash scripts/atlas/detect-project-enhanced.sh ${ARGUMENTS:-.}
else
    echo "Warning: detect-project-enhanced.sh not found, using manual detection"
fi
```

The script will:
- Detect project type and language
- Count actual code files (excluding .venv, node_modules, vendor, etc.)
- Determine project scale (TINY/SMALL/MEDIUM/LARGE/VERY_LARGE)
- Recommend file scan limits (to stay <10%)
- Suggest hypothesis targets (scale-aware)
- **Detect context** (Git branch, monorepo subdirectory, package name)

**Scale-Aware Scan Limits**:
- **TINY** (<5 files): Scan 1-2 files max (50% max to avoid over-scanning tiny projects)
- **SMALL** (5-15 files): Scan 2-3 files (10-20%)
- **MEDIUM** (15-50 files): Scan 4-6 files (8-12%)
- **LARGE** (50-150 files): Scan 6-10 files (4-7%)
- **VERY_LARGE** (>150 files): Scan 10-15 files (3-7%)

**Scale-Aware Hypothesis Targets**:
- **TINY**: 5-8 hypotheses (simple projects have fewer dimensions)
- **SMALL**: 7-10 hypotheses
- **MEDIUM**: 10-15 hypotheses
- **LARGE**: 12-18 hypotheses
- **VERY_LARGE**: 15-20 hypotheses

### Phase 2: High-Entropy File Prioritization (5-8 minutes)

Apply information theory - **high-entropy files contain disproportionate information**.

**Scan Priority Order**:

1. **Documentation** (Highest entropy)
   - README.md, CLAUDE.md, CONTRIBUTING.md
   - docs/, documentation/

2. **Configuration Files** (Project-level decisions)
   - package.json, composer.json, Gemfile, etc.
   - Config files in root
   - docker-compose.yml, Dockerfile

3. **Core Models** (Data structure - scan 3-5 only)
   - models/, entities/, domain/
   - Pick the most important ones

4. **Entry Points** (Architecture patterns - scan 1-2 examples)
   - Controllers, Routes, API definitions
   - main.*, index.*, app.*

5. **Tests** (Development practices - scan 1-2 examples)
   - Key test files to understand testing approach

**Execute scans**:

```bash
# Use helper script if available (try global first, then local)
if [ -f ~/.claude/scripts/atlas/scan-entropy.sh ]; then
    bash ~/.claude/scripts/atlas/scan-entropy.sh ${ARGUMENTS:-.}
elif [ -f scripts/atlas/scan-entropy.sh ]; then
    bash scripts/atlas/scan-entropy.sh ${ARGUMENTS:-.}
else
    echo "Warning: scan-entropy.sh not found, scanning manually"
fi
```

### Phase 3: Generate Hypotheses (3-5 minutes)

Based on scanned files, generate **scale-appropriate hypotheses** (use targets from Phase 1) about:

**Technology Stack**:
- Primary language(s) and versions
- Framework(s) and major dependencies
- Database(s) and storage solutions
- Testing frameworks

**Architecture**:
- Overall pattern (MVC, Clean Architecture, Microservices, etc.)
- Directory structure conventions
- Layering and separation of concerns
- Design patterns used

**Development Practices**:
- Code quality indicators
- Testing coverage and approach
- Documentation depth
- Git workflow patterns

**AI Collaboration** (SourceAtlas Signature Analysis):
- Level 0-4 detection:
  - Level 0: Traditional development (5-8% comments, inconsistent style)
  - Level 3: Systematic AI collaboration (CLAUDE.md present, 15-20% comments, 98%+ consistency)
- Look for: CLAUDE.md, .cursor/rules/, high comment density, conventional commits

**Business Domain**:
- What does this project do?
- Key entities and concepts
- Main features

Each hypothesis must include:
- **Confidence level** (0.0-1.0)
- **Evidence** (specific files/lines)
- **Validation method** (how to verify in Stage 1)

---

## Output Format

Generate output in **YAML format** (standard, ecosystem-supported):

```yaml
metadata:
  project_name: "[detected name]"
  scan_time: "[ISO 8601 timestamp]"
  target_path: "${ARGUMENTS:-.}"
  total_files: [actual count after exclusions]
  scanned_files: [files read]
  scan_ratio: "[percentage]"
  project_scale: "[TINY|SMALL|MEDIUM|LARGE|VERY_LARGE]"
  constitution_version: "1.1"
  # Branch-Aware Context (v2.8.2)
  context:
    git_branch: "[branch name or null]"
    relative_path: "[path within repo or null]"
    package_name: "[detected package name or null]"

project_fingerprint:
  project_type: "[WEB_APP|CLI|LIBRARY|MOBILE_APP|MICROSERVICE|MONOREPO]"
  scale: "[TINY|SMALL|MEDIUM|LARGE|VERY_LARGE]"
  # TINY: <500 LOC, SMALL: 500-2k, MEDIUM: 2k-10k, LARGE: 10k-50k, VERY_LARGE: >50k
  primary_language: "[language + version]"
  framework: "[framework + version]"
  architecture: "[pattern name]"

tech_stack:
  backend:
    language: "[name + version]"
    framework: "[name + version]"
    database: "[name + version]"

  frontend:  # if applicable
    language: "[name]"
    framework: "[name]"

  infrastructure:  # if applicable
    containerization: "[Docker/none]"
    orchestration: "[K8s/none]"

hypotheses:
  architecture:
    - hypothesis: "[architectural pattern description]"
      confidence: 0.0-1.0
      evidence: "[file:line references]"
      validation_method: "[how to verify]"

  tech_stack:
    - hypothesis: "[technology decision]"
      confidence: 0.0-1.0
      evidence: "[file:line references]"
      validation_method: "[how to verify]"

  development:
    - hypothesis: "[development practice]"
      confidence: 0.0-1.0
      evidence: "[file:line references]"
      validation_method: "[how to verify]"

  ai_collaboration:
    level: 0-4
    confidence: 0.0-1.0
    evidence: "[specific indicators]"
    indicators:
      - "[indicator 1]"
      - "[indicator 2]"

  business:
    - hypothesis: "[business domain insight]"
      confidence: 0.0-1.0
      evidence: "[file:line references]"
      validation_method: "[how to verify]"

scanned_files:
  - file: "[path/to/file]"
    reason: "[why scanned]"
    key_insight: "[main learning]"

summary:
  understanding_depth: "[70-80%]"
  key_findings:
    - "[finding 1]"
    - "[finding 2]"
    - "[finding 3]"

## Recommended Next

<!-- Dynamic suggestions based on findings, omit this section if end condition is met -->

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/atlas.pattern "[pattern name]"` | [reason based on findings] |
| 2 | `/atlas.flow "[entry point]"` | [reason based on findings] |

💡 Enter a number (e.g., `1`) or copy the command to execute
```

---

## Critical Rules

1. **Scale-Aware Scanning**: Follow recommended file limits from Phase 1 detection
2. **Exclude Common Bloat**: Never scan .venv/, node_modules/, vendor/, __pycache__, .git/
3. **Time Limit**: Complete in 10-15 minutes (though usually takes 0-5 minutes)
4. **Hypothesis Quality**: Each must have confidence level and evidence
5. **Scale-Aware Targets**: Use hypothesis targets appropriate for project scale
6. **No Deep Diving**: Understand structure > implementation details
7. **STOP after Stage 0**: Do not proceed to validation or git analysis

---

## Tips for Efficient Analysis

- **README first**: Often contains 30-40% of project understanding
- **Config files are gold**: Technology decisions in one place
- **Sample, don't enumerate**: Read 2-3 models, not all 50
- **Pattern over detail**: Identify the pattern from 1-2 examples
- **Trust your hypotheses**: 70-80% confidence is the goal, not 100%

---

## Handoffs Decision Rules

> Follow **Constitution Article VII: Handoffs Principles**

### End Condition vs Suggestions (Choose One, Not Both)

**⚠️ Important: The following two outputs are mutually exclusive, choose only one**

**Case A - End (Omit Recommended Next)**:
When any of the following conditions are met, **only output end message, no table**:
- Project too small: TINY (<10 files) can be read directly
- Findings too vague: Cannot provide high confidence (>0.7) specific parameters
- Goal achieved: AI collaboration Level ≥3 and scale TINY/SMALL (can start development directly)

Output:
```markdown
✅ **Analysis sufficient** - Project is small, can read all files directly to start development
```

**Case B - Suggestions (Output Recommended Next Table)**:
When project scale is large enough or there are clear next steps, **only output table, no end message**.

### Suggestion Selection (For Case B)

| Finding | Suggested Command | Parameter Source |
|---------|-------------------|------------------|
| Clear design patterns | `/atlas.pattern` | Discovered pattern name |
| Complex architecture (multi-layer/microservices) | `/atlas.flow` | Main entry point file |
| Scale ≥ LARGE | `/atlas.history` | No parameters needed |
| High risk areas | `/atlas.impact` | Risk file/module name |

### Output Format (Section 7.3)

Use numbered table:
```markdown
| # | Command | Purpose |
|---|---------|---------|
| 1 | `/atlas.pattern "repository"` | Found Repository pattern used in 15 places |
```

### Quality Requirements (Section 7.4-7.5)

- **Specific parameters**: e.g., `"repository"` not `"related pattern"`
- **Quantity limit**: 1-2 suggestions, don't force fill
- **Purpose column**: Reference specific findings (numbers, file names)

---

## Save Mode (--save)

If `--save` flag is present in arguments:

1. **Create directory** (if needed):
```bash
mkdir -p .sourceatlas
```

2. **Save YAML output** to `.sourceatlas/overview.yaml`

3. **Confirm save**:
```
💾 Saved to .sourceatlas/overview.yaml
```

**File naming for subdirectory analysis**:
- Root analysis: `.sourceatlas/overview.yaml`
- Subdirectory (e.g., `src/api`): `.sourceatlas/overview-src-api.yaml`
