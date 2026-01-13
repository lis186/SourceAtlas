# Overview Workflow Guide

Complete step-by-step execution guide for Stage 0 fingerprint analysis.

---

## Overview

This workflow generates a project fingerprint by scanning <5% of files to achieve 70-80% understanding in 10-15 minutes using information theory principles.

**Time Budget**: 10-15 minutes (typically 0-5 minutes)

---

## Phase 1: Project Detection & Scale-Aware Planning (2-3 minutes)

### Purpose

Detect project type, count files, determine scale, and set scan limits.

### Step 1.1: Run Enhanced Detection Script

**IMPORTANT**: Use the script for accurate file counts and recommendations.

```bash
# Try global install first, then local
if [ -f ~/.claude/scripts/atlas/detect-project.sh ]; then
    bash ~/.claude/scripts/atlas/detect-project.sh ${ARGUMENTS:-.}
elif [ -f scripts/atlas/detect-project.sh ]; then
    bash scripts/atlas/detect-project.sh ${ARGUMENTS:-.}
else
    echo "⚠️ Warning: detect-project.sh not found, using manual detection"
fi
```

**Script outputs:**
- Project type and language
- Actual code file count (excluding .venv, node_modules, vendor, etc.)
- Project scale classification
- Recommended file scan limits
- Hypothesis targets
- Context (git branch, monorepo subdirectory, package name)

### Step 1.2: Manual Detection Fallback

If script not available, manually detect:

```bash
# Detect primary language
echo "=== Language Detection ==="
find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.swift" -o -name "*.kt" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    -not -path "*/vendor/*" \
    2>/dev/null | head -10

# Count code files
echo "=== File Count ==="
find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.swift" -o -name "*.kt" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    -not -path "*/vendor/*" \
    2>/dev/null | wc -l | tr -d ' '

# Detect project type
echo "=== Project Type ==="
if [ -f "package.json" ]; then
    echo "Node.js project detected"
    cat package.json | grep -A 5 "\"name\""
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    echo "Python project detected"
elif [ -f "Podfile" ] || [ -f "*.xcodeproj" ]; then
    echo "iOS project detected"
elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    echo "Android project detected"
fi

# Detect git context
echo "=== Git Context ==="
git branch --show-current 2>/dev/null || echo "Not a git repository"
git rev-parse --show-toplevel 2>/dev/null
```

### Step 1.3: Determine Project Scale

Based on file count:

| Scale | File Count | Scan Limit | Hypothesis Target |
|-------|------------|------------|-------------------|
| **TINY** | <5 files | 1-2 files (50% max) | 5-8 hypotheses |
| **SMALL** | 5-15 files | 2-3 files (10-20%) | 7-10 hypotheses |
| **MEDIUM** | 15-50 files | 4-6 files (8-12%) | 10-15 hypotheses |
| **LARGE** | 50-150 files | 6-10 files (4-7%) | 12-18 hypotheses |
| **VERY_LARGE** | >150 files | 10-15 files (3-7%) | 15-20 hypotheses |

**Example calculation:**
- 120 files detected → **LARGE**
- Scan limit: 6-10 files (5-8%)
- Hypothesis target: 12-18 hypotheses

---

## Phase 2: High-Entropy File Prioritization (5-8 minutes)

### Purpose

Apply information theory - **high-entropy files contain disproportionate information**.

### Step 2.1: Execute Helper Script (Recommended)

```bash
# Use helper script if available (try global first, then local)
if [ -f ~/.claude/scripts/atlas/scan-entropy.sh ]; then
    bash ~/.claude/scripts/atlas/scan-entropy.sh ${ARGUMENTS:-.}
elif [ -f scripts/atlas/scan-entropy.sh ]; then
    bash scripts/atlas/scan-entropy.sh ${ARGUMENTS:-.}
else
    echo "⚠️ Warning: scan-entropy.sh not found, scanning manually"
fi
```

### Step 2.2: Manual Scan Priority Order

Scan in this order, respecting scale limits from Phase 1:

#### 2.2.1: Documentation (Highest Entropy)

```bash
# Scan README first (often contains 30-40% of understanding)
find . -maxdepth 2 -iname "README*" -type f 2>/dev/null | head -3

# Other high-value docs
find . -maxdepth 2 \( -name "CLAUDE.md" -o -name "CONTRIBUTING.md" -o -name "ARCHITECTURE.md" \) -type f 2>/dev/null

# Docs directory
find . -path "*/docs/*" -o -path "*/documentation/*" -type f 2>/dev/null | head -5
```

**Action**: Use Read tool on top 1-2 documentation files.

#### 2.2.2: Configuration Files (Project-Level Decisions)

```bash
# Language-specific config
find . -maxdepth 2 \( -name "package.json" -o -name "composer.json" -o -name "Gemfile" \
    -o -name "requirements.txt" -o -name "pyproject.toml" -o -name "Podfile" \
    -o -name "build.gradle" -o -name "pom.xml" \) -type f 2>/dev/null

# Docker
find . -maxdepth 2 \( -name "docker-compose.yml" -o -name "Dockerfile" \) -type f 2>/dev/null

# Root configs
find . -maxdepth 1 -name "*.json" -o -name "*.yaml" -o -name "*.toml" -type f 2>/dev/null | head -5
```

**Action**: Use Read tool on 2-3 key config files.

#### 2.2.3: Core Models (Data Structure - Scan 2-3 Only)

```bash
# Find model directories
find . -type d \( -name "models" -o -name "entities" -o -name "domain" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    2>/dev/null | head -3

# Find model files
find . -path "*/models/*" -o -path "*/entities/*" -o -path "*/domain/*" -type f \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    2>/dev/null | head -10
```

**Action**: Use Read tool on 2-3 most important models only.

#### 2.2.4: Entry Points (Architecture Patterns - Scan 1-2 Examples)

```bash
# Find entry point files
find . -maxdepth 3 \( -name "main.*" -o -name "index.*" -o -name "app.*" -o -name "server.*" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    -type f 2>/dev/null

# Find controller/route directories
find . -type d \( -name "controllers" -o -name "routes" -o -name "api" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    2>/dev/null | head -5

# Sample controllers
find . -path "*/controllers/*" -o -path "*/routes/*" -type f \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    2>/dev/null | head -5
```

**Action**: Use Read tool on 1-2 example entry points/controllers.

#### 2.2.5: Tests (Development Practices - Scan 1-2 Examples)

```bash
# Find test directories
find . -type d \( -name "test" -o -name "tests" -o -name "spec" -o -name "__tests__" \) \
    -not -path "*/node_modules/*" \
    2>/dev/null | head -5

# Find test files
find . \( -name "*.test.*" -o -name "*.spec.*" \) -type f \
    -not -path "*/node_modules/*" \
    2>/dev/null | head -10
```

**Action**: Use Read tool on 1-2 example test files to understand testing approach.

### Step 2.3: AI Tool Detection

Run AI collaboration detection:

```bash
# Use helper script for comprehensive detection
if [ -f ~/.claude/scripts/atlas/detect-ai-tools.sh ]; then
    bash ~/.claude/scripts/atlas/detect-ai-tools.sh ${ARGUMENTS:-.}
elif [ -f scripts/atlas/detect-ai-tools.sh ]; then
    bash scripts/atlas/detect-ai-tools.sh ${ARGUMENTS:-.}
else
    # Fallback: manual checks
    echo "=== AI Tool Detection ==="

    # Tier 1: Tool-specific config files
    ls -la CLAUDE.md .cursorrules .windsurfrules CONVENTIONS.md AGENTS.md .aiignore 2>/dev/null
    ls -la .claude/ .cursor/rules/ .windsurf/rules/ .clinerules/ .roo/ .continue/rules/ .ruler/ 2>/dev/null
    ls -la .github/copilot-instructions.md .vscode/cody.json .aider.conf.yml .aider.input.history 2>/dev/null
    ls -la replit.nix .replit 2>/dev/null

    # If found, read key config files
    [ -f "CLAUDE.md" ] && echo "Found: CLAUDE.md"
    [ -f ".cursorrules" ] && echo "Found: .cursorrules"
    [ -f "AGENTS.md" ] && echo "Found: AGENTS.md"
fi
```

**Tier 1 Indicators (High-Confidence)**:

| Tool | Files | Confidence Boost |
|------|-------|------------------|
| Claude Code | `CLAUDE.md`, `.claude/` | +0.30 |
| Cursor | `.cursorrules`, `.cursor/rules/*.mdc` | +0.25 |
| Windsurf | `.windsurfrules`, `.windsurf/rules/` | +0.25 |
| GitHub Copilot | `.github/copilot-instructions.md`, `**/.instructions.md` | +0.20 |
| Cline/Roo | `.clinerules`, `.clinerules/`, `.roo/` | +0.25 |
| Aider | `CONVENTIONS.md`, `.aider.conf.yml`, `.aider.input.history` | +0.25 |
| Continue.dev | `.continuerules`, `.continue/rules/` | +0.25 |
| JetBrains AI | `.aiignore` | +0.20 |
| AGENTS.md | `AGENTS.md` (Linux Foundation standard, 60K+ projects) | +0.20 |
| Sourcegraph Cody | `.vscode/cody.json` | +0.15 |
| Replit | `replit.nix` + `.replit` | +0.15 |
| Ruler | `.ruler/` (multi-tool manager) | +0.20 |

**Tier 2 Indicators (Indirect)**:

| Indicator | Threshold | Interpretation |
|-----------|-----------|----------------|
| Comment density | >15% | AI-generated code (vs 5-8% manual) |
| Code consistency | >98% | Systematic AI assistance |
| Conventional Commits | 100% | AI tool integration |
| Docs-to-code ratio | >1:1 | AI documentation generation |

---

## Phase 3: Generate Hypotheses (3-5 minutes)

### Purpose

Based on scanned files, generate **scale-appropriate hypotheses** with confidence levels and evidence.

### Step 3.1: Technology Stack Hypotheses

Based on config files and imports:

**Example hypothesis:**
```yaml
tech_stack:
  - hypothesis: "Primary framework is Express.js v4.18 with TypeScript"
    confidence: 0.95
    evidence: "package.json:12, src/app.ts:1-5"
    validation_method: "grep 'express' package.json; check TypeScript config"
```

**Categories:**
- Primary language(s) and versions
- Framework(s) and major dependencies
- Database(s) and storage solutions
- Testing frameworks

### Step 3.2: Architecture Hypotheses

Based on directory structure and entry points:

**Example hypothesis:**
```yaml
architecture:
  - hypothesis: "3-layer architecture: Controller → Service → Repository"
    confidence: 0.85
    evidence: "src/controllers/, src/services/, src/repositories/ exist"
    validation_method: "trace UserController.ts flow"
```

**Categories:**
- Overall pattern (MVC, Clean Architecture, Microservices, etc.)
- Directory structure conventions
- Layering and separation of concerns
- Design patterns used

### Step 3.3: Development Practices Hypotheses

Based on tests, docs, and code quality:

**Example hypothesis:**
```yaml
development:
  - hypothesis: "Jest + Supertest for API testing, 80%+ coverage"
    confidence: 0.75
    evidence: "package.json:25, tests/api/users.test.ts:1-20"
    validation_method: "run npm test -- --coverage"
```

**Categories:**
- Code quality indicators
- Testing coverage and approach
- Documentation depth
- Git workflow patterns

### Step 3.4: AI Collaboration Hypotheses

Based on Tier 1 + Tier 2 indicators:

**Level Definitions:**
- **Level 0**: No AI - No config files, low comment density (5-8%), inconsistent style
- **Level 1**: Occasional use - 1 tool config with minimal content
- **Level 2**: Frequent use - 1-2 tool configs + some indirect indicators
- **Level 3**: Systematic collaboration - Complete AI config + high comment density + consistent style
- **Level 4**: Ecosystem-level - Multiple tool configs (Ruler/.ruler/) or AGENTS.md + team-wide standards

**Example hypothesis:**
```yaml
ai_collaboration:
  level: 3
  confidence: 0.90
  tools_detected:
    - tool: "Claude Code"
      config_file: "CLAUDE.md"
      content_quality: "comprehensive"
    - tool: "Cursor"
      config_file: ".cursorrules"
      content_quality: "basic"
  indicators:
    - "High comment density (18% vs typical 5-8%)"
    - "Consistent code style across all files"
    - "Comprehensive inline documentation"
```

### Step 3.5: Business Domain Hypotheses

Based on README, models, and code:

**Example hypothesis:**
```yaml
business:
  - hypothesis: "E-commerce platform with user, product, order management"
    confidence: 0.80
    evidence: "README.md:15-30, models/User.ts, models/Product.ts, models/Order.ts"
    validation_method: "review core entity relationships"
```

**Categories:**
- What does this project do?
- Key entities and concepts
- Main features

### Step 3.6: Hypothesis Quality Requirements

Each hypothesis MUST include:
- **hypothesis**: Clear, specific statement
- **confidence**: 0.0-1.0 (aim for >0.7)
- **evidence**: Specific file:line references
- **validation_method**: How to verify in Stage 1

**Scale-Aware Targets** (from Phase 1):
- TINY: 5-8 hypotheses
- SMALL: 7-10 hypotheses
- MEDIUM: 10-15 hypotheses
- LARGE: 12-18 hypotheses
- VERY_LARGE: 15-20 hypotheses

---

## Performance Tips

### For Large Codebases

```bash
# Limit search depth
find . -maxdepth 3 -name "*.py" ...

# Limit results
... | head -20

# Exclude large directories early
find . -path "*/vendor" -prune -o -path "*/dist" -prune -o ...
```

### For Monorepos

```bash
# Search specific package only
find packages/api -name "*.ts" ...

# Or multiple related packages
find packages/{api,core} -name "*.ts" ...
```

---

## Common Issues

### Issue 1: Script Not Found

**Symptom:** Helper scripts not available

**Solution:**
- Check global: `~/.claude/scripts/atlas/`
- Check local: `scripts/atlas/`
- Use manual fallback commands provided in each step

### Issue 2: Too Many Files

**Symptom:** Project scale is VERY_LARGE, overwhelming

**Solution:**
- Respect scan limits (10-15 files max)
- Focus on highest entropy files only
- Trust the 70-80% understanding goal

### Issue 3: Git Not Available

**Symptom:** `git branch` fails

**Solution:**
- Set `context.git_branch: null`
- Continue analysis without git context

---

## Output Transition

After Phase 3 completes:
1. Compile all findings
2. Structure as YAML (see [output-template.md](output-template.md))
3. Execute verification (see [verification-guide.md](verification-guide.md))
4. Save result (see [reference.md#auto-save](reference.md#auto-save))
