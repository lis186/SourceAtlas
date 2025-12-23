# SourceAtlas Plugin

**AI-powered codebase understanding assistant for Claude Code**

SourceAtlas helps developers quickly understand any codebase through pattern learning and impact analysis.

## ✨ Features

### Slash Commands (User-invoked)

- **🔍 Project Overview** (`/atlas.overview`) - Quick project understanding (<5% file scan)
- **🎯 Pattern Learning** (`/atlas.pattern`) - Learn design patterns from existing code
- **📊 Impact Analysis** (`/atlas.impact`) - Analyze change impact with static dependency analysis
- **📈 History Analysis** (`/atlas.history`) - Git history temporal analysis (Hotspots, Coupling, Contributors)
- **🔄 Flow Analysis** (`/atlas.flow`) - Trace code execution and data flow (11 analysis modes)
- **📦 Dependency Analysis** (`/atlas.deps`) - Library/framework upgrade analysis (iOS, Android, Python, React)

### Agent Skills (Model-invoked)

Claude automatically triggers the right analysis based on your questions:

| You Ask | Claude Runs |
|---------|-------------|
| "What's the architecture of this project?" | `/atlas.overview` |
| "How do I add an API endpoint?" | `/atlas.pattern "api endpoint"` |
| "What breaks if I change this file?" | `/atlas.impact` |
| "How does login work?" | `/atlas.flow "login"` |
| "Who knows this code best?" | `/atlas.history` |
| "How much work to upgrade to iOS 17?" | `/atlas.deps "iOS 16 → 17"` |

No need to remember commands — just ask naturally!

## 🚀 Installation

### Method 1: Via Claude Code Plugin (Recommended)

```bash
# Step 1: Add the SourceAtlas marketplace
/plugin marketplace add lis186/SourceAtlas

# Step 2: Install the plugin
/plugin install sourceatlas@lis186-SourceAtlas

# Step 3: Start using in any project
/atlas.overview
/atlas.pattern "api endpoint"
```

**Installation Scopes**:
- **User scope** (default): Available across all your projects
- **Project scope**: `--scope project` to share with collaborators

### Method 2: Local Development/Testing

```bash
# Test plugin locally without installation
claude --plugin-dir ./plugin

# Or add as local marketplace
/plugin marketplace add ./path/to/SourceAtlas
/plugin install sourceatlas@lis186-SourceAtlas
```

## 📖 Usage

### `/atlas.overview` - Project Overview

Get a quick understanding of any codebase by scanning <5% of files.

```bash
# Analyze entire project
/atlas.overview

# Analyze specific directory
/atlas.overview src/api
```

**What you get:**
- Project fingerprint (type, scale, tech stack)
- Architecture hypotheses with confidence levels
- AI collaboration level detection (Level 0-4)
- Recommended next steps

### `/atlas.pattern` - Learn Design Patterns

Learn how the current codebase implements specific patterns.

**Examples:**

```bash
# Learn API endpoint patterns
/atlas.pattern "api endpoint"

# Learn background job patterns
/atlas.pattern "background job"

# Learn file upload patterns
/atlas.pattern "file upload"

# Learn authentication patterns
/atlas.pattern "authentication"

# Learn database query patterns
/atlas.pattern "database query"
```

**What you get:**
- 📁 Best example files with line numbers
- 🎯 Standard implementation flow
- 📐 Key conventions to follow
- ⚠️ Common pitfalls to avoid
- 🧪 Testing patterns
- 📚 Concrete implementation steps

### `/atlas.impact` - Impact Analysis

Analyze the impact scope of code changes using static dependency analysis.

```bash
# Analyze API change impact
/atlas.impact "api /api/users/{id}"

# Analyze model change impact
/atlas.impact "User model"

# Analyze component change impact
/atlas.impact "authentication"
```

**What you get:**
- 📊 Impact summary (backend, frontend, test files)
- 🔴🟡🟢 Risk level assessment
- 📋 Migration checklist
- 🧪 Test coverage gaps
- ⚠️ Language-specific risks (Swift/ObjC interop for iOS)

### `/atlas.history` - History Analysis

Analyze git history to identify hotspots, temporal coupling, and knowledge distribution.

```bash
# Analyze entire repository
/atlas.history

# Analyze specific directory
/atlas.history src/

# Analyze last 6 months
/atlas.history . 6
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

### `/atlas.flow` - Flow Analysis

Trace code execution flow and data flow with natural language queries.

```bash
# Trace user flow
/atlas.flow "user login flow"
/atlas.flow "What happens when user clicks submit"

# Trace specific function
/atlas.flow "handleSubmit"
/atlas.flow "trace processOrder function"

# Error path analysis
/atlas.flow "API error handling"

# Data flow tracing
/atlas.flow "where does userProfile data come from"

# Reverse tracing
/atlas.flow "who calls validateToken"
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

### `/atlas.deps` - Dependency Analysis

Analyze library/framework dependencies for upgrade planning and migration.

```bash
# iOS SDK upgrade
/atlas.deps "iOS 16 → 17"
/atlas.deps "Upgrade minimum iOS to 17, use iOS 26 SDK"

# Android SDK upgrade
/atlas.deps "Android API 35"

# Python library upgrade
/atlas.deps "Flask 1.x → 3.x"
/atlas.deps "Python 3.11 → 3.12"

# React upgrade
/atlas.deps "React 17 → 18"

# Pure inventory (no upgrade)
/atlas.deps "kotlinx.coroutines"
/atlas.deps "Check AFNetworking usage"
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
**Claude**: *automatically runs `/atlas.overview`*

**You**: "I need to add a new API endpoint, how does this project do it?"
**Claude**: *automatically runs `/atlas.pattern "api endpoint"`*

**You**: "Is it safe to refactor UserService.ts?"
**Claude**: *automatically runs `/atlas.impact "UserService.ts"`*

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

When you run `/atlas.pattern "api endpoint"` in a Next.js project:

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
│   ├── atlas.overview.md
│   ├── atlas.pattern.md
│   ├── atlas.impact.md
│   ├── atlas.history.md
│   ├── atlas.flow.md
│   ├── atlas.deps.md
│   ├── atlas.list.md
│   └── atlas.clear.md
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
/atlas.overview
/atlas.pattern "api endpoint"
/atlas.impact "User model"

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

**SourceAtlas v2.10.1** - Understanding codebases at the speed of thought 🚀
