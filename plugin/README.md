# SourceAtlas Plugin

**AI-powered codebase understanding assistant for Claude Code**

SourceAtlas helps developers quickly understand any codebase through pattern learning and impact analysis.

## ✨ Features

### Slash Commands (User-invoked)

- **🔍 Project Overview** (`/sourceatlas:overview`) - Quick project understanding (<5% file scan)
- **🎯 Pattern Learning** (`/sourceatlas:pattern`) - Learn design patterns from existing code
- **📊 Impact Analysis** (`/sourceatlas:impact`) - Analyze change impact with static dependency analysis
- **📈 History Analysis** (`/sourceatlas:history`) - Git history temporal analysis (Hotspots, Coupling, Contributors)
- **🔄 Flow Analysis** (`/sourceatlas:flow`) - Trace code execution and data flow (11 analysis modes)
- **📦 Dependency Analysis** (`/sourceatlas:deps`) - Library/framework upgrade analysis (iOS, Android, Python, React)
- **🔍 Contract Audit** (`/sourceatlas:audit`) - Extract behavior contracts from legacy code (multi-LLM cross-validation)
- **🔬 Seam Discovery** (`/sourceatlas:seam`) - Discover responsibility zones and seams in large files to narrow scope before contract audit
- **🔧 Refactor Playbook** (`/sourceatlas:refactor`) - Guided legacy code migration using the 13-step Playbook (Steps 1-7 tool-assisted)
- **📋 List Results** (`/sourceatlas:list`) - List saved SourceAtlas analysis results
- **🗑️ Reset Results** (`/sourceatlas:reset`) - Clear saved SourceAtlas analysis results

### Agent Skills (Model-invoked)

Claude automatically triggers the right analysis based on your questions:

| You Ask | Claude Runs |
|---------|-------------|
| "What's the architecture of this project?" | `/sourceatlas:overview` |
| "How do I add an API endpoint?" | `/sourceatlas:pattern "api endpoint"` |
| "What breaks if I change this file?" | `/sourceatlas:impact` |
| "How does login work?" | `/sourceatlas:flow "login"` |
| "Who knows this code best?" | `/sourceatlas:history` |
| "How much work to upgrade to iOS 17?" | `/sourceatlas:deps "iOS 16 → 17"` |

No need to remember commands — just ask naturally!

## 🚀 Installation

### Method 1: Via Claude Code Plugin (Recommended)

```bash
# Step 1: Add the SourceAtlas marketplace
/plugin marketplace add lis186/SourceAtlas

# Step 2: Install the plugin
/plugin install sourceatlas@lis186-SourceAtlas

# Step 3: Start using in any project
/sourceatlas:overview
/sourceatlas:pattern "api endpoint"
```

**Installation Scopes**:
- **User scope** (default): Available across all your projects
- **Project scope**: `--scope project` to share with collaborators

> ⚠️ **Known Issue**: If you install with `--scope project` in one repo, you may get "already installed" errors in other repos. This is a [Claude Code bug](https://github.com/anthropics/claude-code/issues/14202). **Workaround**: Use default user scope (no `--scope` flag).

### Method 2: Via OpenSkills (For Cursor, Gemini CLI, Aider, Windsurf)

SourceAtlas works with non-Claude Code agents via [OpenSkills](https://github.com/numman-ali/openskills).

#### Prerequisites

- **Node.js 18+** installed
- **An AI coding agent**: Cursor, Gemini CLI, Aider, or Windsurf
- **A project directory** where you want to use SourceAtlas

#### Quick Start (TL;DR)

```bash
npm i -g openskills
cd your-project
openskills install lis186/SourceAtlas
touch AGENTS.md && openskills sync -y
```

Then ask your AI agent: *"Help me understand this codebase"*

#### Step-by-Step Installation

**Step 1: Install OpenSkills CLI**

```bash
npm i -g openskills
```

Expected output:
```
added 50 packages in 9s
```

**Step 2: Install SourceAtlas skills in your project**

```bash
cd your-project
openskills install lis186/SourceAtlas
```

Expected output:
```
Installing from: lis186/SourceAtlas
✔ Repository cloned
Found 14 skill(s)

? Select skills to install (Press <space> to select)
❯ ◉ overview   - Project architecture overview
  ◉ pattern    - Learn design patterns from existing code
  ◉ flow       - Trace code execution and data flow
  ... (select the 8 SourceAtlas skills)

✅ Installation complete: 8 skill(s) installed
```

> **Tip**: Select only the 8 skills starting with common names (overview, pattern, flow, history, impact, deps, list, clear). Skip agent skills like "codebase-overview" to avoid duplicates.

**Step 3: Generate AGENTS.md**

```bash
touch AGENTS.md
openskills sync -y
```

Expected output:
```
✅ Synced 8 skill(s) to AGENTS.md
```

**Step 4: Verify installation**

```bash
openskills list | grep -E "overview|pattern|flow"
```

You should see:
```
  overview    (project)   Get project overview...
  pattern     (project)   Learn design patterns...
  flow        (project)   Extract business logic flow...
```

**Step 5 (Optional): Commit to share with your team**

```bash
git add AGENTS.md .claude/
git commit -m "Add SourceAtlas skills for AI agents"
```

#### Using with Cursor

After installation, open Cursor and use the AI Chat (Cmd+L or Ctrl+L). Just ask naturally:

| You Ask | What Happens |
|---------|--------------|
| "Help me understand this codebase" | Runs `openskills read overview` → Project architecture analysis |
| "How do I add an API endpoint here?" | Runs `openskills read pattern` → Shows existing patterns to follow |
| "What files are affected if I change UserService?" | Runs `openskills read impact` → Dependency impact analysis |
| "Trace the login flow" | Runs `openskills read flow` → Execution path visualization |
| "Show me the hotspots in this repo" | Runs `openskills read history` → Git history analysis |
| "What's needed to upgrade to React 18?" | Runs `openskills read deps` → Migration checklist |

> **Note**: If Cursor doesn't auto-detect skills, explicitly ask: *"Use `openskills read overview` to analyze this project"*

#### Using with Gemini CLI

```bash
gemini
```

Then ask:
```
> Analyze this project's architecture using the overview skill
```

Gemini will execute `openskills read overview` and provide analysis.

#### Using with Aider

```bash
aider
```

Then ask:
```
> What patterns does this codebase use for API endpoints? Use openskills read pattern
```

#### Available Skills Reference

| Skill | Description | Use When |
|-------|-------------|----------|
| `overview` | Project architecture (<5% file scan) | Starting on a new codebase |
| `pattern` | Learn design patterns | Implementing new features |
| `impact` | Change impact analysis | Before refactoring |
| `flow` | Code execution tracing | Understanding business logic |
| `history` | Git history analysis | Finding hotspots & experts |
| `deps` | Dependency analysis | Planning upgrades |
| `audit` | Contract extraction (multi-LLM) | Before refactoring legacy code |
| `seam` | Responsibility zone discovery | Narrowing scope for large files |
| `refactor` | Guided 13-step migration | Safely extracting from God Classes |
| `list` | List cached results | Checking previous analyses |
| `reset` | Clear cached results | Forcing fresh analysis |

#### Troubleshooting

**"SKILL.md not found at plugin/commands"**

Use the repo root path (skills are discovered recursively):
```bash
openskills install lis186/SourceAtlas
```

**Skills not appearing in your AI agent**

1. Check AGENTS.md exists and contains `<available_skills>`:
   ```bash
   grep "available_skills" AGENTS.md
   ```

2. Re-sync if needed:
   ```bash
   openskills sync -y
   ```

**"openskills: command not found"**

Ensure global npm bin is in PATH:
```bash
npm bin -g  # Shows the path
export PATH="$PATH:$(npm bin -g)"  # Add to PATH
```

#### v2.13.0 Testing Note (Progressive Disclosure Architecture)

**What changed**: Starting from v2.13.0, SKILL.md files are now more concise with detailed steps in separate support files (workflow.md, output-template.md, etc.). This follows Claude Code's Progressive Disclosure Architecture best practice.

**For OpenSkills users**:
- ✅ Core functionality should work normally - SKILL.md still contains all execution logic
- ⚠️ If your AI agent cannot access support files, you may notice less detailed error handling instructions
- 💬 **We need your feedback!** Please test and report issues at: https://github.com/lis186/SourceAtlas/issues

**Quick Test**:
```bash
# In your project with SourceAtlas installed:
cd your-project

# Ask your AI agent:
"Use openskills read overview to analyze this project"

# Expected: Analysis completes successfully with proper output format
# If you see issues: Please report with your AI agent name (Cursor/Gemini/Aider/Windsurf)
```

### Method 3: Local Development/Testing

```bash
# Test plugin locally without installation
claude --plugin-dir ./plugin

# Or add as local marketplace
/plugin marketplace add ./path/to/SourceAtlas
/plugin install sourceatlas@lis186-SourceAtlas
```

## 📖 Usage

### `/sourceatlas:overview` - Project Overview

Get a quick understanding of any codebase by scanning <5% of files.

```bash
# Analyze entire project
/sourceatlas:overview

# Analyze specific directory
/sourceatlas:overview src/api
```

**What you get:**
- Project fingerprint (type, scale, tech stack)
- Architecture hypotheses with confidence levels
- AI collaboration level detection (Level 0-4)
- Recommended next steps

### `/sourceatlas:pattern` - Learn Design Patterns

Learn how the current codebase implements specific patterns.

**Examples:**

```bash
# Learn API endpoint patterns
/sourceatlas:pattern "api endpoint"

# Learn background job patterns
/sourceatlas:pattern "background job"

# Learn file upload patterns
/sourceatlas:pattern "file upload"

# Learn authentication patterns
/sourceatlas:pattern "authentication"

# Learn database query patterns
/sourceatlas:pattern "database query"
```

**What you get:**
- 📁 Best example files with line numbers
- 🎯 Standard implementation flow
- 📐 Key conventions to follow
- ⚠️ Common pitfalls to avoid
- 🧪 Testing patterns
- 📚 Concrete implementation steps

### `/sourceatlas:impact` - Impact Analysis

Analyze the impact scope of code changes using static dependency analysis.

```bash
# Analyze API change impact
/sourceatlas:impact "api /api/users/{id}"

# Analyze model change impact
/sourceatlas:impact "User model"

# Analyze component change impact
/sourceatlas:impact "authentication"
```

**What you get:**
- 📊 Impact summary (backend, frontend, test files)
- 🔴🟡🟢 Risk level assessment
- 📋 Migration checklist
- 🧪 Test coverage gaps
- ⚠️ Language-specific risks (Swift/ObjC interop for iOS)

### `/sourceatlas:history` - History Analysis

Analyze git history to identify hotspots, temporal coupling, and knowledge distribution.

```bash
# Analyze entire repository
/sourceatlas:history

# Analyze specific directory
/sourceatlas:history src/

# Analyze last 6 months
/sourceatlas:history . 6
```

**What you get:**
- 🔥 Hotspots - Files with most changes (complexity indicators)
- 🔗 Temporal Coupling - Files that change together (hidden dependencies)
- 👥 Recent Contributors - Knowledge distribution by area
- ⚠️ Bus Factor Risk - Single-contributor files
- 📊 Risk Assessment - Priority actions for refactoring

**Auto-features:**
- Detects shallow clone and offers one-click fix
- Auto-installs code-maat dependency if needed

### `/sourceatlas:flow` - Flow Analysis

Trace code execution flow and data flow with natural language queries.

```bash
# Trace user flow
/sourceatlas:flow "user login flow"
/sourceatlas:flow "What happens when user clicks submit"

# Trace specific function
/sourceatlas:flow "handleSubmit"
/sourceatlas:flow "trace processOrder function"

# Error path analysis
/sourceatlas:flow "API error handling"

# Data flow tracing
/sourceatlas:flow "where does userProfile data come from"

# Reverse tracing
/sourceatlas:flow "who calls validateToken"
```

**What you get:**
- 📊 Call Graph visualization (ASCII tree format)
- 🌐 Boundary detection (API, DB, LIB, CLOUD markers)
- 🔄 Recursion and cycle detection
- 📈 Depth-controlled tracing
- 🎯 11 analysis modes:
  - Forward/Reverse tracing
  - Error path analysis
  - Data flow tracing
  - State machine visualization
  - Feature toggle detection
  - Event/Message flow
  - Transaction boundary
  - Permission/Role check
  - Cache flow analysis
  - Comparison mode

**For beginners (Newbie Mode auto-enabled):**
- Terms explained with tooltips
- Progressive disclosure (7±2 items per level)

### `/sourceatlas:deps` - Dependency Analysis

Analyze library/framework dependencies for upgrade planning and migration.

```bash
# iOS SDK upgrade
/sourceatlas:deps "iOS 16 → 17"
/sourceatlas:deps "Upgrade minimum iOS to 17, use iOS 26 SDK"

# Android SDK upgrade
/sourceatlas:deps "Android API 35"

# Python library upgrade
/sourceatlas:deps "Flask 1.x → 3.x"
/sourceatlas:deps "Python 3.11 → 3.12"

# React upgrade
/sourceatlas:deps "React 17 → 18"

# Pure inventory (no upgrade)
/sourceatlas:deps "kotlinx.coroutines"
/sourceatlas:deps "Check AFNetworking usage"
```

**What you get:**
- 📋 **Phase 0 Rule Confirmation** - Preview upgrade rules before scanning
- ✅ **Required Changes** - Removable checks, deprecated APIs, breaking changes
- 🚀 **Modernization Opportunities** - New features you can adopt
- 📊 **Usage Summary** - All API usage points with file:line references
- 📦 **Third-party Dependencies** - Compatibility checks
- ✅ **Migration Checklist** - Step-by-step upgrade plan with time estimates

**Auto-features:**
- **Built-in Rules**: iOS 16→17, React 17→18, Python 3.11→3.12
- **WebSearch Integration**: Dynamically fetch latest migration guides
- **Dual Modes**: Automatic detection of upgrade vs pure inventory
- **Multi-module Support**: Handles Android multi-module projects
- **Graceful Degradation**: Works even without requirements.txt or package.json
- **Constitution v1.1 Compliant**: Full evidence with file:line references

**Tested on:**
- ✅ iOS projects (2,108 files) - 100% accuracy
- ✅ Android multi-module (30 modules) - 100% accuracy
- ✅ Python projects (missing deps files) - 100% accuracy
- ✅ Kotlin workspaces (1,509 imports) - 100% accuracy

### `/sourceatlas:seam` - Seam Discovery

Discover responsibility zones and seam points in large files to narrow scope before contract audit.

```bash
# Discover zones in a large file
/sourceatlas:seam src/NYHTTPSClient.m

# With explicit language
/sourceatlas:seam src/api-gateway.ts --language typescript

# Re-run (bypass cache)
/sourceatlas:seam src/UserService.swift --force
```

**What you get:**
- 🗺️ Responsibility zone map with line ranges
- 🔬 Seam type identification (Object/Link/Preprocessing)
- 📊 Zones ranked by refactoring priority (complexity × coupling)
- 📋 Copy-pasteable `/sourceatlas:audit --zone <id>` commands

**When to use:**
- File is 200+ lines with multiple responsibilities
- `/sourceatlas:audit` produces too many contracts to act on
- You need to choose which zone to refactor first

### `/sourceatlas:audit` - Contract Audit

Extract implicit behavioral contracts from legacy code before refactoring, using a 3-LLM cross-validation pipeline.

```bash
# Audit entire file
/sourceatlas:audit src/NYHTTPSClient.m

# Audit a specific zone (from /sourceatlas:seam)
/sourceatlas:audit src/NYHTTPSClient.m --zone crypto

# With explicit language
/sourceatlas:audit src/api.ts --language typescript

# Re-run (bypass cache)
/sourceatlas:audit src/UserService.swift --force
```

**What you get:**
- 📋 Behavioral contracts with M/L/N/S/E/C/D/P taxonomy
- 🔁 3-LLM cross-validation (Gemini blind scan → Claude structured → Codex adversarial)
- ✅ Machine-verifiable CI assertions (grep/ast-grep rules)
- ⚠️ Risk assessment — which behaviors will break during refactoring

**Pipeline:**
1. Gemini blind scan — discovers contracts without prior context
2. Claude structured audit — taxonomizes and formalizes
3. Codex adversarial review — challenges and stress-tests

### `/sourceatlas:refactor` - Refactor Playbook

Guided legacy code migration using the 13-step Playbook (based on Feathers' *Working Effectively with Legacy Code*). Steps 1-7 are tool-assisted; Steps 8-13 are user-driven.

```bash
# Discovery mode — find best refactoring targets
/sourceatlas:refactor

# Start refactoring a specific file
/sourceatlas:refactor src/NYHTTPSClient.m

# Focus on a specific zone
/sourceatlas:refactor src/NYHTTPSClient.m --zone crypto

# Check progress
/sourceatlas:refactor src/NYHTTPSClient.m --status

# Resume from a specific step
/sourceatlas:refactor src/NYHTTPSClient.m --step 3
```

**What you get:**
- 🎯 Step 1: Target selection (hotspot + impact analysis)
- 📋 Step 2: Contract inventory (seam zones + behavioral contracts)
- 🔬 Step 3: Seam discovery (dependency graph + seam candidates)
- 🧪 Step 4: Behavior recording (spike tests + characterization skeletons)
- 🏗️ Step 5: Interface design (user-approved Seam Interface)
- 🔌 Step 6: Legacy adapter (bridges old impl to new interface)
- ✅ Step 7: Verification gate (all tests green — hard gate)
- 📖 Steps 8-13: Guidance for write/swap/verify/cleanup/delete

**Session boundaries** are enforced after Steps 2 and 5 to prevent confirmation bias. Each step produces a versioned artifact in `.sourceatlas/refactor/{module}/`.

### `/sourceatlas:list` - List Saved Results

List all saved analysis results from previous SourceAtlas commands.

```bash
/sourceatlas:list
```

**What you get:**
- 📋 Table of all cached analyses with type, size, age
- ⚠️ Expired items (>30 days) flagged with re-analysis commands

### `/sourceatlas:reset` - Clear Saved Results

Clear cached analysis results from `.sourceatlas/`.

```bash
# Clear everything (prompts for confirmation)
/sourceatlas:reset

# Clear specific type
/sourceatlas:reset patterns
/sourceatlas:reset overview
/sourceatlas:reset history
```

## 🧠 Agent Skills (Auto-triggered)

SourceAtlas includes 6 Agent Skills that let Claude automatically choose the right analysis tool based on your natural language questions.

### Available Skills

| Skill | Triggers When You Ask About |
|-------|----------------------------|
| `codebase-overview` | Project structure, architecture, tech stack, onboarding |
| `pattern-finder` | How to implement features, code examples, conventions |
| `impact-analyzer` | Change impact, dependencies, breaking changes, safety |
| `code-flow-tracer` | How features work, execution paths, data flow |
| `history-analyzer` | Hotspots, code ownership, bus factor, knowledge silos |
| `dependency-analyzer` | Upgrades, migrations, deprecated APIs, version changes |

### Example Conversations

**You**: "I just joined this project, can you help me understand it?"
**Claude**: *automatically runs `/sourceatlas:overview`*

**You**: "I need to add a new API endpoint, how does this project do it?"
**Claude**: *automatically runs `/sourceatlas:pattern "api endpoint"`*

**You**: "Is it safe to refactor UserService.ts?"
**Claude**: *automatically runs `/sourceatlas:impact "UserService.ts"`*

### Skills Location

```
plugin/skills/
├── codebase-overview/SKILL.md
├── pattern-finder/SKILL.md
├── impact-analyzer/SKILL.md
├── code-flow-tracer/SKILL.md
├── history-analyzer/SKILL.md
└── dependency-analyzer/SKILL.md
```

---

## 🎓 How It Works

SourceAtlas uses **information theory principles** to understand codebases efficiently:

1. **High-Entropy File Prioritization** - Scans <5% of files to achieve 70-80% understanding
2. **Pattern Recognition** - Extracts reusable design patterns from existing code
3. **Static Dependency Analysis** - Traces code dependencies without runtime execution
4. **Actionable Guidance** - Provides concrete steps to follow existing conventions

**Key Principles:**
- ✅ Scan <5% of files (targeted, not exhaustive)
- ✅ Focus on patterns, not implementation details
- ✅ Provide actionable, concrete guidance
- ✅ Always cite specific file locations

## 🧪 Example Output

When you run `/sourceatlas:pattern "api endpoint"` in a Next.js project:

```markdown
# Pattern: REST API Endpoints (Next.js API Routes)

## Overview

This project uses Next.js API routes with TypeScript, following a
consistent controller pattern with centralized error handling and
Zod validation.

## Best Examples

- **`src/pages/api/users/[id].ts:15`** - Complete CRUD endpoint example
- **`src/pages/api/auth/login.ts:8`** - POST endpoint with validation
- **`src/lib/api/errorHandler.ts:5`** - Centralized error handling

## Key Conventions

1. **Define route** in `src/pages/api/[route].ts`
2. **Validate request** using Zod schema
3. **Call service layer** for business logic
4. **Return standardized response** (success/error format)
5. **Handle errors** through centralized error handler

... (and more)
```

## 🛠️ Development

### Project Structure

```
sourceatlas-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── commands/                # Slash commands (user-invoked)
│   ├── overview/SKILL.md    # Project overview
│   ├── pattern/SKILL.md     # Pattern learning
│   ├── impact/SKILL.md      # Impact analysis
│   ├── history/SKILL.md     # Git history analysis
│   ├── flow/SKILL.md        # Code flow tracing
│   ├── deps/SKILL.md        # Dependency analysis
│   ├── audit/SKILL.md       # Contract extraction (multi-LLM)
│   ├── seam/SKILL.md        # Responsibility zone discovery
│   ├── refactor/SKILL.md    # Guided 13-step migration
│   ├── list/SKILL.md        # List saved analyses
│   └── reset/SKILL.md       # Clear saved analyses
├── skills/                  # Agent Skills (model-invoked)
│   ├── codebase-overview/SKILL.md
│   ├── pattern-finder/SKILL.md
│   ├── impact-analyzer/SKILL.md
│   ├── code-flow-tracer/SKILL.md
│   ├── history-analyzer/SKILL.md
│   └── dependency-analyzer/SKILL.md
├── README.md
├── CHANGELOG.md
├── TESTING.md
└── LICENSE
```

**Note**: Commands use `{name}/SKILL.md` format for OpenSkills compatibility.

### Testing Locally

```bash
# Option 1: Direct plugin loading (fastest for development)
claude --plugin-dir ./plugin

# Option 2: Local marketplace
# From the SourceAtlas repository root:
/plugin marketplace add ./
/plugin install sourceatlas@lis186-SourceAtlas

# Test in any project
cd ~/your-project
/sourceatlas:overview
/sourceatlas:pattern "api endpoint"
/sourceatlas:impact "User model"

# After making changes to plugin/
/plugin uninstall sourceatlas@lis186-SourceAtlas
/plugin install sourceatlas@lis186-SourceAtlas
```

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes locally
4. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) for details

## 🙏 Acknowledgments

Built on SourceAtlas methodology:
- Three-stage analysis framework
- Information theory principles
- High-entropy file prioritization
- Static dependency analysis

## 📚 Resources

- [SourceAtlas Documentation](https://github.com/lis186/SourceAtlas)
- [Claude Code Plugin Docs](https://code.claude.com/docs/en/plugins)

---

**SourceAtlas v2.13.1** - Understanding codebases at the speed of thought 🚀
