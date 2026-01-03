---
description: Get project overview - scan <5% of files to achieve 70-80% understanding
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: [path] [--force] (e.g., "src/api" or ". --force")
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

**Auto-Save**: Results automatically saved to `.sourceatlas/overview.yaml`
- Creates `.sourceatlas/` directory if needed
- `--save` flag is deprecated, no longer needed

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
if [ -f ~/.claude/scripts/atlas/detect-project.sh ]; then
    bash ~/.claude/scripts/atlas/detect-project.sh ${ARGUMENTS:-.}
elif [ -f scripts/atlas/detect-project.sh ]; then
    bash scripts/atlas/detect-project.sh ${ARGUMENTS:-.}
else
    echo "Warning: detect-project.sh not found, using manual detection"
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

Detect AI tool usage by scanning for tool-specific configuration files:

**Tier 1: High-Confidence Indicators (Tool-Specific Config Files)**

| Tool | Files to Check | Confidence Boost |
|------|----------------|------------------|
| **Claude Code** | `CLAUDE.md`, `.claude/` | +0.30 |
| **Cursor** | `.cursorrules`, `.cursor/rules/*.mdc` | +0.25 |
| **Windsurf** | `.windsurfrules`, `.windsurf/rules/` | +0.25 |
| **GitHub Copilot** | `.github/copilot-instructions.md`, `**/.instructions.md` | +0.20 |
| **Cline/Roo** | `.clinerules`, `.clinerules/`, `.roo/` | +0.25 |
| **Aider** | `CONVENTIONS.md`, `.aider.conf.yml`, `.aider.input.history` | +0.25 |
| **Continue.dev** | `.continuerules`, `.continue/rules/` | +0.25 |
| **JetBrains AI** | `.aiignore` | +0.20 |
| **AGENTS.md** | `AGENTS.md` (Linux Foundation standard, 60K+ projects) | +0.20 |
| **Sourcegraph Cody** | `.vscode/cody.json` | +0.15 |
| **Replit** | `replit.nix` + `.replit` (may indicate Replit Agent) | +0.15 |
| **Ruler** | `.ruler/` (multi-tool manager) | +0.20 |

**Tier 2: Indirect Indicators**

| Indicator | Threshold | Interpretation |
|-----------|-----------|----------------|
| Comment density | >15% | AI-generated code (vs 5-8% manual) |
| Code consistency | >98% | Systematic AI assistance |
| Conventional Commits | 100% | AI tool integration |
| Docs-to-code ratio | >1:1 | AI documentation generation |

**Level Definitions**:
- **Level 0**: No AI - No config files, low comment density (5-8%), inconsistent style
- **Level 1**: Occasional use - 1 tool config with minimal content
- **Level 2**: Frequent use - 1-2 tool configs + some indirect indicators
- **Level 3**: Systematic collaboration - Complete AI config + high comment density + consistent style
- **Level 4**: Ecosystem-level - Multiple tool configs (Ruler/.ruler/) or AGENTS.md + team-wide standards

**Detection Script** (run during Phase 2):
```bash
# Use helper script for comprehensive AI tool detection
if [ -f ~/.claude/scripts/atlas/detect-ai-tools.sh ]; then
    bash ~/.claude/scripts/atlas/detect-ai-tools.sh ${ARGUMENTS:-.}
elif [ -f scripts/atlas/detect-ai-tools.sh ]; then
    bash scripts/atlas/detect-ai-tools.sh ${ARGUMENTS:-.}
else
    # Fallback: manual checks
    echo "Warning: detect-ai-tools.sh not found, checking manually"
    ls -la CLAUDE.md .cursorrules .windsurfrules CONVENTIONS.md AGENTS.md .aiignore 2>/dev/null
    ls -la .claude/ .cursor/rules/ .windsurf/rules/ .clinerules/ .roo/ .continue/rules/ .ruler/ 2>/dev/null
    ls -la .github/copilot-instructions.md .vscode/cody.json .aider.conf.yml 2>/dev/null
fi
```

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

Generate output with **branded header**, then **YAML format** (standard, ecosystem-supported):

```markdown
🗺️ SourceAtlas: Overview
───────────────────────────────
🔭 [project_name] │ [SCALE] ([file count] files)
```

Then YAML content:

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
    tools_detected:
      - tool: "[tool name]"
        config_file: "[file path]"
        content_quality: "[minimal|basic|comprehensive]"
    indicators:
      - "[indicator 1]"
      - "[indicator 2]"
    # Level interpretation:
    # 0: No AI (no config files, 5-8% comments)
    # 1: Occasional (1 config, minimal content)
    # 2: Frequent (1-2 configs + indirect indicators)
    # 3: Systematic (complete config + high comments + consistent style)
    # 4: Ecosystem (multiple tools/AGENTS.md + team standards)

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
| 1 | `/sourceatlas:pattern "[pattern name]"` | [reason based on findings] |
| 2 | `/sourceatlas:flow "[entry point]"` | [reason based on findings] |

💡 Enter a number (e.g., `1`) or copy the command to execute

───────────────────────────────
🗺️ v2.11.0 │ Constitution v1.1
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
| Clear design patterns | `/sourceatlas:pattern` | Discovered pattern name |
| Complex architecture (multi-layer/microservices) | `/sourceatlas:flow` | Main entry point file |
| Scale ≥ LARGE | `/sourceatlas:history` | No parameters needed |
| High risk areas | `/sourceatlas:impact` | Risk file/module name |

### Output Format (Section 7.3)

Use numbered table:
```markdown
| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:pattern "repository"` | Found Repository pattern used in 15 places |
```

### Quality Requirements (Section 7.4-7.5)

- **Specific parameters**: e.g., `"repository"` not `"related pattern"`
- **Quantity limit**: 1-2 suggestions, don't force fill
- **Purpose column**: Reference specific findings (numbers, file names)

---

## Self-Verification Phase (REQUIRED)

> **Purpose**: Prevent hallucinated file paths, incorrect counts, and fictional configurations from appearing in output.
> This phase runs AFTER output generation, BEFORE save.

### Step V1: Extract Verifiable Claims

After generating the YAML output, extract all verifiable claims:

**Claim Types to Extract:**

| Type | Pattern | Verification Method |
|------|---------|---------------------|
| **File Path** | `scanned_files.file` entries | `test -f path` |
| **Directory** | Architecture directories mentioned | `test -d path` |
| **File Count** | `total_files`, `scanned_files` | `find . -type f \| wc -l` |
| **Config File** | AI tools `config_file` entries | `test -f config_file` |
| **Git Branch** | `context.git_branch` | `git branch --show-current` |

### Step V2: Parallel Verification Execution

Run **ALL** verification checks in parallel:

```bash
# Execute all verifications in a single parallel block

# 1. Verify scanned_files entries exist
for path in "path/to/file1" "path/to/file2"; do
    if [ ! -f "$path" ]; then
        echo "❌ FILE_NOT_FOUND: $path"
    fi
done

# 2. Verify AI tool config files
for config in "CLAUDE.md" ".cursorrules" ".github/copilot-instructions.md"; do
    if [ ! -f "$config" ] && [ ! -d "$config" ]; then
        echo "❌ CONFIG_NOT_FOUND: $config"
    fi
done

# 3. Verify file count is reasonable
claimed_count=150
actual_count=$(find . -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" 2>/dev/null | wc -l | tr -d ' ')
# Allow 10% variance for dynamic counts
if [ $((actual_count * 90 / 100)) -gt $claimed_count ] || [ $((actual_count * 110 / 100)) -lt $claimed_count ]; then
    echo "⚠️ COUNT_CHECK: claimed $claimed_count, actual ~$actual_count"
fi

# 4. Verify git branch if claimed
claimed_branch="main"
actual_branch=$(git branch --show-current 2>/dev/null)
if [ "$actual_branch" != "$claimed_branch" ]; then
    echo "❌ BRANCH_MISMATCH: claimed $claimed_branch, actual $actual_branch"
fi
```

### Step V3: Handle Verification Results

**If ALL checks pass:**
- Continue to output/save

**If ANY check fails:**
1. **DO NOT output the uncorrected analysis**
2. Fix each failed claim:
   - `FILE_NOT_FOUND` → Remove from scanned_files or find correct path
   - `CONFIG_NOT_FOUND` → Remove from tools_detected or verify path
   - `COUNT_CHECK` → Update total_files with actual count
   - `BRANCH_MISMATCH` → Update context.git_branch
3. Re-generate affected YAML sections with corrected information
4. Re-run verification on corrected sections

### Step V4: Verification Summary (Append to Output)

Add to footer (before `🗺️ v2.11.0 │ Constitution v1.1`):

**If all verifications passed:**
```
✅ Verified: [N] scanned files, [M] config paths, file count
```

**If corrections were made:**
```
🔧 Self-corrected: [list specific corrections made]
✅ Verified: [N] scanned files, [M] config paths, file count
```

### Verification Checklist

Before finalizing output, confirm:
- [ ] All `scanned_files.file` entries verified to exist
- [ ] All `tools_detected.config_file` entries verified to exist
- [ ] `total_files` count verified against filesystem
- [ ] `context.git_branch` verified against current branch
- [ ] `evidence` file references in hypotheses verified to exist

---

## Auto-Save (Default Behavior)

After analysis completes, automatically:

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

---

## Deprecated: --save flag

If `--save` is in arguments:
- Show: `⚠️ --save is deprecated, auto-save is now default`
- Remove `--save` from arguments
- Continue normal execution (still auto-saves)
