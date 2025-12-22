# CLAUDE.md

This file provides guidance for Claude Code (claude.ai/code) when working in this codebase.

## Project Overview

**SourceAtlas** is an AI-optimized codebase analysis tool designed to rapidly understand any codebase by scanning less than 5% of files to achieve 70-95% comprehension depth. It uses information theory principles, prioritizing high-entropy files (configs, docs, models) over implementation details.

**Core Innovation**: A three-stage analysis framework that saves 95%+ time and tokens compared to traditional code review methods.

**Current Status**:
- **v1.0** ✅ - Methodology validation complete (2025-11-22)
- **v2.7.0** ✅ - Commands architecture complete with flow tracing (2025-12-01)
- **v2.8.0** ✅ - Constitution v1.0 + Monorepo support (2025-12-05)
- **v2.8.1** ✅ - Constitution v1.1 + Handoffs principles (2025-12-06)
- **v2.9.0** ✅ - Dependency Analysis `/atlas.deps` testing complete (2025-12-12)
- **v2.9.1** ✅ - Persistence v2.0: 30-day expiry warnings, Handoffs exclusivity rules (2025-12-13)
- **v2.9.2** ✅ - `/atlas.list` expiry marking enhanced, `/atlas.init` validation mechanism (2025-12-13)
- **v2.9.3** ✅ - `/atlas.pattern` Progressive Disclosure: Smart mode + `--brief`/`--full` parameters (2025-12-18)
- **v2.9.4** ✅ - AI Collaboration Detection: Support 12+ AI tools detection (2025-12-19)
- **v2.9.5** ✅ - Branded Output Format: Unified Header/Footer for all commands (2025-12-19)
- **v2.9.6** ✅ - ast-grep Enhancements: Tuist support, Swift 6/Python 3.12/Rust 2024 syntax, bug fixes (2025-12-20)

## Architecture

### Three-Stage Analysis Process

The system uses a progressive analysis approach:

1. **Stage 0: Project Fingerprint** (~10-15 minutes, ~20k tokens)
   - Scan <5% of files to achieve 70-80% understanding
   - Identify tech stack, architecture patterns, business domain
   - Generate 10-15 hypotheses for validation
   - Output format: `.yaml` (v1.0 decision: YAML > TOON, ecosystem priority)

2. **Stage 1: Hypothesis Validation** (~20-30 minutes, ~30k tokens)
   - Systematically validate Stage 0 hypotheses
   - Achieve 85-95% understanding depth
   - Record evidence for each hypothesis
   - Output format: `.md`

3. **Stage 2: Git Hotspot Analysis** (~15-20 minutes, ~20k tokens)
   - Analyze commit history and file change frequency
   - Identify development patterns and AI collaboration levels
   - Reconstruct project timeline
   - Output format: `.md`

### Core Design Principles

> ⚠️ **Important**: The complete principles for analysis behavior are defined in [ANALYSIS_CONSTITUTION.md](./ANALYSIS_CONSTITUTION.md).
> This section is only a summary; the Constitution is the authoritative source.

**Information Theory Foundation** (see Constitution Article I):

- High-entropy files (configs, READMEs, models) contain disproportionately large amounts of information
- Structure > implementation details, better for rapid understanding
- Progressive refinement beats exhaustive scanning
- Scan ratio limits: TINY 50%, SMALL 20%, MEDIUM 10%, LARGE 5%, VERY_LARGE 3%

**Format Selection** (v1.0 decision):

- **YAML** as primary format (standard ecosystem > 14% token optimization)
- TOON format evaluated but not adopted (see `dev-notes/toon-vs-yaml-analysis.md`)
- Used for Stage 0 output: `.yaml`
- Used for Stage 1-2 output: `.md`

## Directory Structure

```
sourceatlas2/
├── README.md               # User documentation (Chinese)
├── CLAUDE.md               # This file - AI collaboration guide (developing SourceAtlas)
├── ANALYSIS_CONSTITUTION.md # ⭐ Analysis constitution - immutable principles for analysis behavior
├── PROMPTS.md              # Complete prompt templates for all 3 stages
├── PRD.md                  # Product requirements (v2.7 Commands architecture)
├── USAGE_GUIDE.md          # Detailed usage instructions
│
├── .claude-plugin/         # ⭐ Marketplace config (for /plugin marketplace add)
│   └── marketplace.json    # Plugin registry
│
├── plugin/                 # ⭐ Claude Code plugin (for distribution)
│   ├── .claude-plugin/     # Plugin metadata
│   ├── commands/           # Slash commands
│   └── skills/             # Agent Skills
│
├── .claude/commands/       # Claude Code slash commands
│   ├── atlas.overview.md   # ✅ /atlas.overview (Stage 0)
│   └── atlas.pattern.md    # ✅ /atlas.pattern (Pattern Learning)
│
├── scripts/                # Analysis scripts
│   └── atlas/              # ⭐ Atlas command core scripts
│
├── proposals/              # ✅ Feature proposals (unimplemented features) ⭐
│   ├── README.md           # Proposal index
│   └── code-maat-integration/  # code-maat integration design (implemented in v2.6)
│       ├── SOURCEATLAS_CODEMAAT_INTEGRATION.md
│       ├── CODE_MAAT_FORMAT_CHEATSHEET.md
│       ├── PERFORMANCE_CONSIDERATIONS.md
│       └── UPDATES_SUMMARY.md
│
├── examples/               # ✅ External reference projects (for learning) ⭐
│   └── README.md           # Instructions and recommended projects (projects themselves git ignored)
│
├── dev-notes/              # ✅ Development records and methodology ⭐
│   ├── README.md           # SourceAtlas knowledge base index
│   ├── HISTORY.md          # View project evolution by timeline
│   ├── KEY_LEARNINGS.md    # Core learnings and discoveries
│   ├── METHODOLOGY.md      # Development methodology
│   ├── ROADMAP.md          # Future plans
│   ├── 2025-11/            # Monthly implementation records
│   └── archives/           # Historical archives
│
├── ideas/                  # ✅ Experimental ideas (draft notes) ⭐
│   └── README.md           # Usage instructions and current explorations
│
├── test_targets/           # Test projects (git ignore)
└── test_results/           # Analysis outputs (git ignore)
```

## Installation and Usage

### Plugin Installation (Recommended) ⭐

**Method 1: Claude Code `/plugin` Command (Official)**

```bash
# In Claude Code, add SourceAtlas as a marketplace
/plugin marketplace add lis186/SourceAtlas

# Browse and install from the plugin menu
/plugin

# Or install directly
/plugin install sourceatlas@lis186/SourceAtlas
```

**Method 2: Via npx CLI**

```bash
# Install using claude-plugins CLI
npx claude-plugins install lis186/SourceAtlas
```

**Method 3: Manual Installation**

```bash
# Clone repository
git clone https://github.com/lis186/SourceAtlas.git

# Copy plugin contents to Claude Code directories
cp -r SourceAtlas/plugin/commands/* ~/.claude/commands/
cp -r SourceAtlas/plugin/skills/* ~/.claude/skills/
```

📚 **References**:
- [Official Plugin Docs](https://claude.com/blog/claude-code-plugins)
- [Plugin Registry](https://claude-plugins.dev/)

### Using Analysis Prompts

#### When to Run Analysis

Run SourceAtlas analysis in the following situations:

- Taking over a new codebase
- Conducting code review or technical due diligence
- Evaluating developer candidate's GitHub projects
- Learning open-source projects
- Assessing AI collaboration maturity

### Stage Selection Guide

- **<500 LOC**: Skip SourceAtlas, read directly
- **500-2000 LOC**: Use Stage 0-1
- **>2000 LOC with Git history**: Use all 3 stages

### Running Analysis

**v1.0 Method** (Manual Prompts):
1. Copy the relevant stage prompt from `PROMPTS.md`
2. Replace `[PROJECT_PATH]` with actual path
3. Generate output in specified format (Stage 0 uses .yaml, Stage 1-2 use .md)

**v2.9.0 Method** (Commands):
- `/atlas.init` ✅ - Project initialization, inject auto-trigger rules (implemented, 2025-11-30)
- `/atlas.overview` ✅ - Stage 0 project fingerprint (implemented, 2025-11-20) [supports `--save`]
- `/atlas.pattern` ✅ - Learn design patterns (implemented, 2025-11-22) [supports `--save`]
- `/atlas.impact` ✅ - Impact scope analysis (implemented, 2025-11-25) [supports `--save`]
- `/atlas.history` ✅ - Temporal analysis (Git history) (implemented, 2025-11-30) [supports `--save`]
- `/atlas.flow` ✅ - Flow tracing and data flow analysis (implemented, 2025-12-01) [supports `--save`]
- `/atlas.deps` ✅ - Dependency analysis (testing complete, 2025-12-12) [supports `--save`]
- `/atlas.list` ✅ - List saved analysis results (2025-12-13) ⭐ NEW
- `/atlas.clear` ✅ - Clear saved analysis results (2025-12-12)

**Persistence Features**:
- Add `--save` parameter to save analysis results to `.sourceatlas/` directory
- Example: `/atlas.pattern "repository" --save` → saves to `.sourceatlas/patterns/repository.md`
- Use `/atlas.clear` to clear saved analysis results
- Use `/atlas.list` to view saved analysis results
- Saved analyses automatically serve as cache, directly loaded on next identical command execution
- Add `--force` parameter to skip cache and force re-analysis

### Using Project Memory (.sourceatlas/)

**Trigger Conditions**: When user questions involve the following scenarios, proactively query `.sourceatlas/`:
- Project-level questions: "this project", "this codebase", "project architecture", "overall", "big picture"
- Continuing previous analysis: "previous analysis", "last time", "we discussed"
- Explicit overview requests: "overview", "summarize", "give me background"

**Actions**:
1. Execute `ls .sourceatlas/ 2>/dev/null` to check if it exists
2. If exists, prioritize reading `overview.yaml` (project big picture)
3. Based on question content, determine if other cache needs reading:
   - Pattern-related → `.sourceatlas/patterns/`
   - Dependency-related → `.sourceatlas/deps/`
   - History-related → `.sourceatlas/history.md`
   - Impact analysis → `.sourceatlas/impact/`
   - Flow-related → `.sourceatlas/flows/`

**Don't Trigger** (avoid unnecessary token costs):
- "Help me fix this bug" → Fix directly, no cache needed
- "What does this function do" → Read source code directly
- "Run tests" → Execute directly, no background needed

**Complete Three-Stage Analysis** (rare scenarios):
For in-depth due diligence (evaluating open-source projects, hiring assessment, technical DD), use `PROMPTS.md` to manually execute Stage 0-1-2

**Important**: Stage prompts depend on each other. Must complete Stage 0 before Stage 1, complete Stage 1 before Stage 2.

## AI Collaboration Detection

One of SourceAtlas's unique capabilities is identifying AI-assisted development patterns across **12+ AI coding tools**.

### Supported AI Tools Detection (v2.9.4)

| Tool | Config Files | Confidence |
|------|--------------|------------|
| **Claude Code** | `CLAUDE.md`, `.claude/` | High |
| **Cursor** | `.cursorrules`, `.cursor/rules/*.mdc` | High |
| **Windsurf** | `.windsurfrules`, `.windsurf/rules/` | High |
| **GitHub Copilot** | `.github/copilot-instructions.md` | High |
| **Cline/Roo** | `.clinerules`, `.clinerules/`, `.roo/` | High |
| **Aider** | `CONVENTIONS.md`, `.aider.conf.yml` | High |
| **Continue.dev** | `.continuerules`, `.continue/rules/` | High |
| **JetBrains AI** | `.aiignore` | Medium |
| **AGENTS.md** | `AGENTS.md` (Linux Foundation standard) | Medium |
| **Sourcegraph Cody** | `.vscode/cody.json` | Medium |
| **Replit** | `replit.nix` + `.replit` | Low |
| **Ruler** | `.ruler/` (multi-tool manager) | High |

### AI Collaboration Maturity Model

- **Level 0**: No AI (traditional development)
  - No config files detected
  - Low comment density (5-8%)
  - Inconsistent code style
- **Level 1**: Occasional use
  - 1 tool config with minimal content
- **Level 2**: Frequent use
  - 1-2 tool configs + some indirect indicators
- **Level 3**: Systematic AI collaboration ⭐
  - Complete AI config (CLAUDE.md, .cursorrules, etc.)
  - 15-20% comment density (vs. manual 5-8%)
  - 98%+ code consistency
  - 100% Conventional Commits
  - Docs/code ratio >1:1
- **Level 4**: Ecosystem level (team-level AI integration)
  - Multiple tool configs or Ruler/.ruler/
  - AGENTS.md (cross-tool standard)
  - Team-wide AI coding standards

**Indirect Indicators**: High comment density, perfect commit message consistency, rich documentation, consistent code style across files.

## File Formats

### YAML Format (.yaml)

Used for Stage 0 output (v1.0 decision). Key features:

- Standard YAML syntax (broad ecosystem support)
- Structured sections: project fingerprint, hypotheses, scanned files
- Confidence levels for all inferences (0.0-1.0)
- Only 14% more tokens vs. TOON, but gains standard tooling support

Example structure:

```yaml
metadata:
  project_name: example
  scan_time: "2025-11-22T10:00:00Z"
  total_files: 500
  scanned_files: 12
  scan_ratio: "2.4%"

project_fingerprint:
  project_type: WEB_APP
  scale: MEDIUM
  # ...additional fields

hypotheses:
  architecture:
    - hypothesis: "Uses JWT authentication"
      confidence: 0.75
      evidence: "Found jwt dependency, auth middleware present"
```

**Why YAML over TOON?**
- Standard format > custom format (minimalist philosophy)
- 14% token difference is marginal benefit
- Complete analysis in `dev-notes/toon-vs-yaml-analysis.md`

### Markdown Reports (.md)

Used for Stage 1-2 output:

- Standard GitHub-flavored markdown
- Use tables to present structured data
- Use code blocks to present evidence
- Clear section headings

## Output Requirements

### Confidence Levels

Always include confidence levels for inferences:

- **0.0-0.5**: Low confidence (needs validation)
- **0.5-0.7**: Medium confidence
- **0.7-0.85**: High confidence
- **0.85-1.0**: Very high confidence (almost certain)

### Evidence-Based Analysis

Every argument must be supported by evidence:

- File paths with line numbers when relevant
- Shell command outputs
- Direct quotes from documentation
- Statistical analysis (file counts, commit patterns, etc.)

## Common Patterns to Identify

### Architecture Patterns

- **MVC/MVVM**: Look for models/, views/, controllers/ or viewmodels/
- **Microservices**: Multiple service directories, docker-compose.yml, API gateway
- **Monorepo**: workspaces in package.json, multiple package.json files
- **Clean Architecture**: Layered separation (domain/, infrastructure/, application/)

### Tech Stack Indicators

- `package.json` → Node.js/TypeScript/JavaScript
- `composer.json` → PHP/Laravel
- `Cargo.toml` → Rust
- `go.mod` → Go
- `*.csproj` → C#/.NET
- `requirements.txt`/`pyproject.toml` → Python

### Developer Capability Signals

- **Test coverage >90%**: Professional/expert level
- **No tests**: Beginner or rapid prototype
- **Has CLAUDE.md**: Systematic AI collaboration
- **Only 1-2 commits**: Poor Git habits (beginner)
- **Conventional Commits**: Good development practices

## Language and Localization

### Core Principle: English for All Documentation ⭐

**Important**: All documentation uses English terminology.

**Language Usage Guidelines**:
- Primary documentation uses English
- Code and technical terms use English
- Generated reports match the project's primary language
- User documentation (README, USAGE_GUIDE) uses project's language
- Technical specs (PRD, PROMPTS) may mix languages as needed

## Version Control

**Version Number Explanation**:
- **SourceAtlas Product Version** (e.g., v2.6.0): Tracks overall product development stages
- **Proposal Document Version** (e.g., v3.0 under proposals/): Tracks individual proposal design changes

**Current Product Version**:
- **v1.0** ✅ - Methodology validation complete (2025-11-22)
- **v2.7.0** ✅ - Flow analysis complete (2025-12-01)

**Version History** (see `dev-notes/HISTORY.md`):
- v2.7.0 (2025-12-01): `/atlas.flow` - Flow tracing
- v2.6.0 (2025-11-30): `/atlas.history` - Temporal analysis
- v2.5.x (2025-11-30): Multi-language Patterns (141 patterns)
- v1.0 (2025-11-22): Methodology validation complete

### Ignored Directories

- `test_targets/` - Cloned codebases for validation (large, not tracked in git)
- `test_results/` - Generated analysis outputs (can be regenerated)
- `examples/*` - Cloned reference projects (only README.md tracked)

These are git-ignored to keep the codebase lean while protecting test project privacy.

## Development Workflow

### Git and Version Control

- **Never use `git commit` command** - GitButler is using its internal processes and `but` CLI hooks to automatically manage all commits and branches
- **Focus on writing clean code and tests** - Don't worry about commits or branches
- **When task is complete, stop working** and allow GitButler hooks to execute post-processing commands

This workflow ensures clear feature separation and allows GitButler to automatically organize commits and branches without manual intervention.

## v1.0 Key Learnings (Must Read!)

**v1.0 validation completed on 2025-11-22 revealed 6 key insights**:

1. ✅ **Information theory actually works** - <5% scan achieves 70-80% understanding (5/5 project validation)
2. ⭐ **Scale-awareness is critical** - TINY/SMALL/MEDIUM/LARGE/VERY_LARGE need different strategies
3. ⭐ **YAML > TOON** - Standard ecosystem > 14% token savings
4. ✅ **Must exclude .venv/node_modules** - Avoid inflating file counts
5. ✅ **Benchmarking reveals truth** - Test on real projects, not just theory
6. ✅ **AI collaboration patterns are detectable** - Level 0-4 maturity model

> **Detailed analysis and evidence**: See [dev-notes/KEY_LEARNINGS.md](./dev-notes/KEY_LEARNINGS.md) and [dev-notes/HISTORY.md](./dev-notes/HISTORY.md)

**Remember these learnings when implementing any new features!**

---

## Multi-Language Pattern Support

**Total 221 patterns**, covering mainstream tech stacks:

| Language/Framework | Patterns | Detailed Report |
|-----------|----------|----------|
| iOS/Swift | 34 | `dev-notes/2025-11/` |
| Kotlin/Android | 31 | `dev-notes/2025-11/2025-11-30-kotlin-patterns-implementation-report.md` |
| Python | 26 | `dev-notes/2025-11/` |
| TypeScript/React/Vue | 50 | `dev-notes/2025-11/` |
| Ruby/Rails | 26 | `dev-notes/2025-12/` |
| Go | 26 | `dev-notes/2025-12/` |
| Rust | 28 | `dev-notes/2025-12/` |

**Methodology**: See `dev-notes/archives/lessons/new-language-support-methodology.md`

---

## Current Status (v2.9.4)

Based on PRD v2.9.0, v1.0 learnings, and Constitution v1.1:

### ✅ Completed - Core 6 Commands
- [x] `/atlas.init` - Project initialization (auto-trigger rules) ✅ (2025-11-30)
- [x] `/atlas.overview` - Stage 0 project fingerprint ✅ (2025-11-20)
- [x] `/atlas.pattern` - Learn design patterns ✅ (2025-11-22) ⭐⭐⭐⭐⭐
- [x] `/atlas.impact` - Impact scope analysis (static) ✅ (2025-11-25) ⭐⭐⭐⭐
- [x] `/atlas.history` - Temporal analysis (Git history) ✅ (2025-11-30) ⭐⭐⭐⭐⭐
- [x] `/atlas.flow` - Flow tracing (11 analysis modes) ✅ (2025-12-01) ⭐⭐⭐⭐⭐

### ✅ Completed - v2.9.0 Dependency Analysis
- [x] `/atlas.deps` - Dependency analysis ✅ (2025-12-12) ⭐⭐⭐⭐⭐
  - Phase 0 rule confirmation mechanism
  - Built-in rules (iOS, Android, Python)
  - WebSearch dynamic rule generation
  - Pure inventory vs. upgrade mode identification
  - 4 scenario tests, 100% accuracy (42/42 samples)
  - Production Ready (Grade A+ 9.7/10)

### ✅ Completed - Quality Framework
- [x] **Constitution v1.1** - Immutable principles for analysis behavior + Handoffs principles ✅ (2025-12-06)
- [x] **Article VII: Handoffs Principles** - Discovery-driven dynamic next-step suggestions ✅ (2025-12-06)
- [x] **validate-constitution.sh** - Automated compliance validation ✅ (2025-12-05)
- [x] **Monorepo Detection** - lerna/pnpm/nx/turborepo/npm workspaces ✅ (2025-12-05)
- [x] **Branch-Aware Context** - Git branch/subdirectory/Package detection ✅ (2025-12-06)
- [x] **--save Parameter** - All analysis commands support saving to `.sourceatlas/` ✅ (2025-12-12)
- [x] **/atlas.clear** - Clear saved analysis results ✅ (2025-12-12)

### ✅ Completed - Model Performance Optimization (2025-12-12)

Each command uses different Claude models based on task complexity, balancing speed and quality:

| Command | Model | Reason |
|------|-------|------|
| `/atlas.init` | Haiku | Simple text injection, no reasoning needed |
| `/atlas.overview` | Sonnet | Hypothesis generation requires medium reasoning |
| `/atlas.pattern` | Sonnet | Pattern matching and implementation guide generation |
| `/atlas.history` | Sonnet | Git analysis and insight generation |
| `/atlas.impact` | Sonnet | Dependency tracking and risk assessment |
| `/atlas.deps` | Sonnet | Dependency inventory and rule matching |
| `/atlas.flow` | Opus | Complex multi-layer logic flow tracing (11 analysis modes) |
| `/atlas.clear` | Haiku | Simple file deletion operations |

**Expected Benefits**:
- Haiku commands: 50%+ speed increase, 70% cost reduction
- Sonnet commands: 20-30% speed increase, 40% cost reduction
- Overall quality maintained at high standards (E2E tests 100% pass)

### ✅ Completed - Multi-Language Support
- [x] iOS/Swift - 34 patterns
- [x] Kotlin/Android - 31 patterns
- [x] Python - 26 patterns
- [x] TypeScript/React/Vue - 50 patterns
- [x] Ruby/Rails - 26 patterns
- [x] Go - 26 patterns
- [x] Rust - 28 patterns
- **Total: 221 patterns**

### 🔮 Future (v3.0)
- SourceAtlas Monitor - Continuous tracking and trend analysis
- Technical debt quantification
- Health dashboard
- `/atlas.standup` - Integrate GitLab MR tools (cycle-time, branch-health)

**Decision Log**:
- (2025-12-12): **Model Performance Optimization** - Each command specifies optimal Model (Haiku/Sonnet/Opus), E2E tests 100% pass
- (2025-12-08): `/atlas.deps` design started - Dedicated for Library/Framework upgrade scenarios (Scenario 8)
- (2025-11-25): `/atlas.find` canceled - Functionality covered by existing commands
- (2025-11-30): `/atlas.history` implementation complete - Single command + zero parameters + smart output + auto-install code-maat
- (2025-12-01): `/atlas.flow` implementation complete - 11 analysis modes + language-specific entry points + enhanced boundary identification
- (2025-12-05): **Constitution v1.0** implementation complete - 7 Articles + validation script + Monorepo detection
- (2025-12-06): **Constitution v1.1** implementation complete - Added Article VII: Handoffs Principles (5 Sections)
- (2025-12-06): `/atlas.validate` canceled - Changed to built-in quality checks (independent command over-engineered)
- (2025-12-06): **Branch-Aware Context** implementation complete - Git branch/subdirectory/Package detection
- (2025-12-06): **--save Parameter** implementation complete - Optional save to `.sourceatlas/overview.yaml`

**Detailed Roadmap**: See [dev-notes/implementation-roadmap.md](./dev-notes/implementation-roadmap.md) and [PRD.md](./PRD.md)

---

## Implementation Core Principles (Based on v1.0 Experience + Constitution v1.1)

When implementing any new features, **must follow**:

1. **Scale-Aware Design** - Don't one-size-fits-all, adjust based on project size (Constitution Article VI)
2. **Standards Over Custom** - Use YAML, Markdown, don't invent formats (Constitution Article V)
3. **Test First** - Test on 3+ real projects, not just theory
4. **Documentation Sync** - Write docs while developing, don't backfill
5. **Benchmark Measurement** - Establish metrics, track continuously
6. **Exclude Directories** - Always exclude .venv, node_modules, __pycache__ (Constitution Article II)
7. **Information Theory** - High entropy priority, structure > implementation details (Constitution Article I)
8. **Evidence-Based** - Every argument needs `file:line` evidence (Constitution Article IV)
9. **Validate Compliance** - Use `validate-constitution.sh` to validate analysis output

---

## Pre-Release Checklist

**Trigger**: Before asking user "Should we update the version?", complete all checks below

After completing feature implementation, check and update before asking about version bump:

| # | Check Item | File Location | Description |
|---|-----------|---------------|-------------|
| 1 | **README version badge** | `README.md`, `README.zh-TW.md` | Update version badge |
| 2 | **CLAUDE.md Current Status** | `CLAUDE.md` | Version list + section title |
| 3 | **Plugin version** | `plugin/.claude-plugin/plugin.json` | "version" field |
| 4 | **Plugin CHANGELOG** | `plugin/CHANGELOG.md` | New version section |
| 5 | **Dev history** | `dev-notes/HISTORY.md` | Current week entry |
| 6 | **Implementation notes** | `dev-notes/YYYY-MM/YYYY-MM-DD-*.md` | Detailed implementation doc |
| 7 | **Command files sync** | `.claude/commands/` ↔ `plugin/commands/` | Ensure consistency |
| 8 | **New scripts** | `scripts/atlas/*.sh` | Verify existence and executable |
| 9 | **Plugin sync** | `plugin/` ↔ `.claude/` | Ensure commands/skills are synced |

### Checklist Flow

```
1. Feature implementation complete
2. Execute all 9 checks above
3. Fix any missing items
4. Ask user: "Should we update the version to vX.Y.Z?"
5. Only execute version changes after user confirmation
```

### Version Number Rules

- **PATCH** (x.y.Z): Bug fixes, minor improvements, doc updates
- **MINOR** (x.Y.0): New features, new commands, significant improvements
- **MAJOR** (X.0.0): Breaking changes, architecture refactoring
