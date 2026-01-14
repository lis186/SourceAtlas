# Overview Reference Guide

Advanced features, scale-aware analysis, helper scripts, and best practices.

---

## Scale-Aware Analysis

### Scale Definitions

| Scale | File Count | LOC Range | Scan Limit | Hypothesis Target |
|-------|------------|-----------|------------|-------------------|
| **TINY** | <5 | <500 | 1-2 files (50% max) | 5-8 hypotheses |
| **SMALL** | 5-15 | 500-2K | 2-3 files (10-20%) | 7-10 hypotheses |
| **MEDIUM** | 15-50 | 2K-10K | 4-6 files (8-12%) | 10-15 hypotheses |
| **LARGE** | 50-150 | 10K-50K | 6-10 files (4-7%) | 12-18 hypotheses |
| **VERY_LARGE** | >150 | >50K | 10-15 files (3-7%) | 15-20 hypotheses |

### Why Scale-Aware?

**Problem:** Fixed 5% scan ratio doesn't work for all sizes
- TINY projects: 5% of 4 files = 0 files (unusable)
- VERY_LARGE projects: 5% of 1000 files = 50 files (wasteful)

**Solution:** Adaptive scan limits
- TINY: Higher ratio (50%) because each file matters
- VERY_LARGE: Lower ratio (3-7%) because diminishing returns

### Scale Detection Logic

```bash
# Count code files (excluding dependencies)
FILE_COUNT=$(find . -type f \
    \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.swift" -o -name "*.kt" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    -not -path "*/vendor/*" \
    -not -path "*/__pycache__/*" \
    2>/dev/null | wc -l | tr -d ' ')

# Determine scale
if [ $FILE_COUNT -lt 5 ]; then
    SCALE="TINY"
    SCAN_LIMIT="1-2 files"
elif [ $FILE_COUNT -lt 15 ]; then
    SCALE="SMALL"
    SCAN_LIMIT="2-3 files"
elif [ $FILE_COUNT -lt 50 ]; then
    SCALE="MEDIUM"
    SCAN_LIMIT="4-6 files"
elif [ $FILE_COUNT -lt 150 ]; then
    SCALE="LARGE"
    SCAN_LIMIT="6-10 files"
else
    SCALE="VERY_LARGE"
    SCAN_LIMIT="10-15 files"
fi
```

---

## Helper Scripts

### detect-project.sh

**Location:**
- Global: `~/.claude/scripts/atlas/detect-project.sh`
- Local: `scripts/atlas/detect-project.sh`

**Purpose:** Comprehensive project detection and scale analysis

**Output:**
```
Project Type: WEB_APP
Primary Language: TypeScript
Framework: Express.js 4.18
File Count: 127 (after exclusions)
Scale: LARGE
Recommended Scan: 6-10 files (4-7%)
Hypothesis Target: 12-18 hypotheses

Context:
- Git Branch: main
- Package Name: @company/api
- Relative Path: (root)
```

**Usage:**
```bash
bash ~/.claude/scripts/atlas/detect-project.sh .
bash ~/.claude/scripts/atlas/detect-project.sh src/api  # subdirectory
```

---

### scan-entropy.sh

**Location:**
- Global: `~/.claude/scripts/atlas/scan-entropy.sh`
- Local: `scripts/atlas/scan-entropy.sh`

**Purpose:** Execute high-entropy file prioritization

**Output:**
```
=== High-Entropy Files (Priority Order) ===

[1] Documentation:
- README.md
- CLAUDE.md
- docs/architecture.md

[2] Configuration:
- package.json
- tsconfig.json
- docker-compose.yml

[3] Models (top 3):
- src/models/User.ts
- src/models/Product.ts
- src/models/Order.ts

[4] Entry Points (top 2):
- src/app.ts
- src/routes/index.ts

[5] Tests (top 2):
- tests/integration/api.test.ts
- tests/unit/services/user.test.ts
```

**Usage:**
```bash
bash ~/.claude/scripts/atlas/scan-entropy.sh .
```

---

### detect-ai-tools.sh

**Location:**
- Global: `~/.claude/scripts/atlas/detect-ai-tools.sh`
- Local: `scripts/atlas/detect-ai-tools.sh`

**Purpose:** Detect AI tool configurations (Tier 1 + Tier 2)

**Output:**
```
=== AI Tool Detection ===

Tier 1 (Tool-Specific Config Files):
✅ Claude Code: CLAUDE.md (+0.30)
✅ Cursor: .cursorrules (+0.25)
❌ Windsurf: not found
❌ GitHub Copilot: not found
✅ AGENTS.md: AGENTS.md (+0.20)

Tier 2 (Indirect Indicators):
- Comment density: 18% (vs typical 5-8%) ✅
- Code consistency: 95% (>98% threshold) ❌
- Conventional Commits: 100% ✅

AI Collaboration Level: 3
Confidence: 0.85
```

**Tier 1 Tools Detected:**

| Tool | Config Files | Boost |
|------|--------------|-------|
| Claude Code | `CLAUDE.md`, `.claude/` | +0.30 |
| Cursor | `.cursorrules`, `.cursor/rules/*.mdc` | +0.25 |
| Windsurf | `.windsurfrules`, `.windsurf/rules/` | +0.25 |
| GitHub Copilot | `.github/copilot-instructions.md`, `**/.instructions.md` | +0.20 |
| Cline/Roo | `.clinerules`, `.clinerules/`, `.roo/` | +0.25 |
| Aider | `CONVENTIONS.md`, `.aider.conf.yml`, `.aider.input.history` | +0.25 |
| Continue.dev | `.continuerules`, `.continue/rules/` | +0.25 |
| JetBrains AI | `.aiignore` | +0.20 |
| AGENTS.md | `AGENTS.md` | +0.20 |
| Sourcegraph Cody | `.vscode/cody.json` | +0.15 |
| Replit | `replit.nix` + `.replit` | +0.15 |
| Ruler | `.ruler/` | +0.20 |

**Usage:**
```bash
bash ~/.claude/scripts/atlas/detect-ai-tools.sh .
```

---

## Cache Behavior

### Cache Location

**Root analysis:**
```
.sourceatlas/overview.yaml
```

**Subdirectory analysis:**
```
# For: /sourceatlas:overview "src/api"
.sourceatlas/overview-src-api.yaml

# For: /sourceatlas:overview "packages/backend"
.sourceatlas/overview-packages-backend.yaml
```

**Naming rule:** Replace `/` with `-`, lowercase

### Cache Check Logic

```bash
# Parse arguments
if echo "$ARGUMENTS" | grep -q "\-\-force"; then
    echo "⚠️ --force flag detected, skipping cache"
    # Skip cache, execute analysis
else
    # Calculate cache file name
    if [ "$ARGUMENTS" = "." ] || [ -z "$ARGUMENTS" ]; then
        CACHE_FILE=".sourceatlas/overview.yaml"
    else
        # Convert path to cache name
        CACHE_NAME=$(echo "$ARGUMENTS" | tr '/' '-' | tr '[:upper:]' '[:lower:]')
        CACHE_FILE=".sourceatlas/overview-${CACHE_NAME}.yaml"
    fi

    # Check if cache exists
    if [ -f "$CACHE_FILE" ]; then
        # Get modification time
        MTIME=$(stat -f "%Sm" -t "%Y-%m-%d" "$CACHE_FILE" 2>/dev/null || stat -c "%y" "$CACHE_FILE" 2>/dev/null | cut -d' ' -f1)

        # Calculate age
        AGE_DAYS=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$MTIME" +%s 2>/dev/null || date -d "$MTIME" +%s 2>/dev/null)) / 86400 ))

        echo "📁 Loading cache: $CACHE_FILE ($AGE_DAYS days ago)"
        echo "💡 Add --force to re-analyze"

        if [ $AGE_DAYS -gt 30 ]; then
            echo "⚠️ Cache is over 30 days old, recommend re-analysis"
        fi

        # Output cache content
        cat "$CACHE_FILE"
        exit 0
    fi
fi
```

### Cache Age Warning

- **<30 days**: No warning
- **>30 days**: Show warning
- **>90 days**: Strong warning

**Rationale:** Projects evolve, old fingerprints may be stale.

---

## Auto-Save Behavior

### Save Timing

Auto-save occurs **after V4 verification passes**:

```
Phase 1 → Phase 2 → Phase 3 → Generate YAML → V1-V4 Verification → Auto-Save
```

### Save Location

```bash
mkdir -p .sourceatlas

# Root analysis
SAVE_PATH=".sourceatlas/overview.yaml"

# Subdirectory analysis (e.g., "src/api")
SAVE_PATH=".sourceatlas/overview-src-api.yaml"
```

### Confirmation Message

```
💾 Saved to .sourceatlas/overview.yaml
```

---

## Handoffs Decision Rules

> Follow **Constitution Article VII: Handoffs Principles**

### Decision Logic

**Choose ONE of these outputs, NOT both:**

#### Case A: End Condition (No Table)

When **any** of these are true:
- Project too small: TINY (<10 files) can be read directly
- Findings too vague: Cannot provide high confidence (>0.7) specific parameters
- Goal achieved: AI collaboration Level ≥3 and scale TINY/SMALL (can start development)

**Output:**
```markdown
✅ **Analysis sufficient** - Project is small, can read all files directly to start development
```

#### Case B: Suggestions (Table Output)

When project scale is large enough or there are clear next steps.

**Suggestion Selection:**

| Finding | Command | Parameter Source |
|---------|---------|------------------|
| Clear design patterns | `/sourceatlas:pattern` | Discovered pattern name |
| Complex architecture (multi-layer/microservices) | `/sourceatlas:flow` | Main entry point file |
| Scale ≥ LARGE | `/sourceatlas:history` | No parameters |
| High risk areas | `/sourceatlas:impact` | Risk file/module name |

**Output Format:**
```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:pattern "repository pattern"` | Found Repository pattern used in 15 files |
| 2 | `/sourceatlas:flow "src/app.ts"` | Trace 3-layer architecture flow |

💡 Enter a number (e.g., `1`) or copy the command to execute
```

**Quality Requirements:**
- **Specific parameters**: Use actual discovered names (e.g., `"repository pattern"` not `"some pattern"`)
- **Quantity limit**: 1-2 suggestions max, don't force fill
- **Purpose column**: Reference specific findings (numbers, file names)

---

## Information Theory Principles

### High-Entropy Files

**Entropy** = Information density = How much you learn per line read

**Ranking (highest to lowest):**

1. **Documentation** (README, ARCHITECTURE docs)
   - Entropy: ~10 bits/line
   - Why: Summarizes entire project purpose, architecture, usage

2. **Configuration** (package.json, docker-compose.yml)
   - Entropy: ~8 bits/line
   - Why: Technology stack decisions in one place

3. **Models/Entities** (User.ts, Product.ts)
   - Entropy: ~6 bits/line
   - Why: Data structure defines business domain

4. **Entry Points** (app.ts, routes/index.ts)
   - Entropy: ~5 bits/line
   - Why: Architecture patterns visible

5. **Tests** (user.test.ts)
   - Entropy: ~4 bits/line
   - Why: Development practices visible

6. **Implementation** (services, controllers)
   - Entropy: ~2 bits/line
   - Why: Details, not structure

**Strategy:** Read top 3 categories, sample categories 4-5.

---

## AI Collaboration Detection

### Level Definitions

| Level | Criteria | Examples |
|-------|----------|----------|
| **0: No AI** | No config files, 5-8% comments, inconsistent style | Manual development |
| **1: Occasional** | 1 tool config with minimal content | Experimenting with AI |
| **2: Frequent** | 1-2 tool configs + some indirect indicators | Regular AI usage |
| **3: Systematic** | Complete AI config + high comments + consistent style | Mature AI workflow |
| **4: Ecosystem** | Multiple tools (Ruler) or AGENTS.md + team standards | Organization-wide |

### Content Quality Assessment

When config file is found, assess quality:

**Minimal (<5 lines):**
```markdown
# .cursorrules
Use TypeScript
Follow ESLint rules
```

**Basic (5-50 lines):**
```markdown
# CLAUDE.md
## Project Overview
This is an Express API for user management.

## Code Style
- Use TypeScript
- Follow 3-layer architecture
- Write tests for all endpoints
```

**Comprehensive (>50 lines):**
```markdown
# CLAUDE.md (full structure)
## What is this project
[Detailed explanation]

## Key Files
[File-by-file breakdown]

## Must Follow
[Detailed guidelines]

## Development Workflow
[Step-by-step instructions]
```

**Scoring:**
- minimal → confidence: 0.5-0.6
- basic → confidence: 0.7-0.8
- comprehensive → confidence: 0.9-1.0

---

## Best Practices

### For Different Project Sizes

**TINY projects (<5 files):**
- Read ALL files if possible
- Focus on purpose and usage
- Simple hypotheses (5-8)

**SMALL projects (5-15 files):**
- Read docs + config + 1-2 models
- Focus on architecture pattern
- Moderate hypotheses (7-10)

**MEDIUM projects (15-50 files):**
- Standard entropy-based scanning
- Focus on patterns and conventions
- Balanced hypotheses (10-15)

**LARGE projects (50-150 files):**
- Strict entropy prioritization
- Focus on high-level architecture
- Comprehensive hypotheses (12-18)

**VERY_LARGE projects (>150 files):**
- Maximum efficiency required
- Focus on fingerprint only, not details
- Extensive hypotheses (15-20)

---

## Integration with Other Commands

After overview fingerprint, consider:

| Finding | Next Command | Reason |
|---------|--------------|--------|
| Clear patterns mentioned | `/sourceatlas:pattern` | Learn implementation |
| Complex architecture | `/sourceatlas:flow` | Trace execution |
| Large codebase | `/sourceatlas:history` | Find hotspots |
| High-risk areas identified | `/sourceatlas:impact` | Assess change impact |

---

## Deprecated Features

### --save flag (v2.8.0)

Auto-save is now default behavior.

**If user provides `--save`:**
```bash
if echo "$ARGUMENTS" | grep -q "\-\-save"; then
    echo "⚠️ --save is deprecated, auto-save is now default"
    # Remove --save from arguments
    ARGUMENTS=$(echo "$ARGUMENTS" | sed 's/--save//g')
    # Continue normal execution (still auto-saves)
fi
```

---

## Troubleshooting

### Issue 1: Helper Scripts Not Found

**Symptom:** Scripts not in ~/.claude/scripts/atlas/ or scripts/atlas/

**Solution:**
- Use manual fallback commands provided in workflow.md
- All core functionality works without scripts
- Scripts are optimization only

### Issue 2: File Count Varies

**Symptom:** Different counts on different runs

**Solution:**
- Normal if files are created/deleted between runs
- Use same exclusions in verification
- ±10% variance acceptable

### Issue 3: Git Commands Fail

**Symptom:** Not a git repository

**Solution:**
- Set `context.git_branch: null`
- Set `context.relative_path: null`
- Continue analysis without git context

### Issue 4: Too Many/Few Hypotheses

**Symptom:** Generated hypotheses don't match scale targets

**Solution:**
- Use scale targets as guidelines, not strict limits
- Quality > quantity
- Each hypothesis must have >0.7 confidence

---

## Version History

- **v2.12.0**: Current version with Constitution v1.1
- **v2.8.2**: Added branch-aware context
- **v2.8.0**: Auto-save default, deprecated --save flag
- **v2.5.0**: Added scale-aware analysis
- **v2.0.0**: YAML output format
