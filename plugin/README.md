# SourceAtlas Plugin

**AI-powered codebase understanding assistant for Claude Code**

SourceAtlas helps developers quickly understand any codebase through pattern learning and impact analysis.

## ✨ Features

- **🚀 Project Init** (`/atlas.init`) - Initialize SourceAtlas in any project
- **🔍 Project Overview** (`/atlas.overview`) - Quick project understanding (<5% file scan)
- **🎯 Pattern Learning** (`/atlas.pattern`) - Learn design patterns from existing code
- **📊 Impact Analysis** (`/atlas.impact`) - Analyze change impact with static dependency analysis
- **📈 History Analysis** (`/atlas.history`) - Git history temporal analysis (Hotspots, Coupling, Contributors)
- **🔄 Flow Analysis** (`/atlas.flow`) - Trace code execution and data flow (11 analysis modes) ⭐ NEW

## 🚀 Installation

### Method 1: Local Development/Testing

```bash
# Clone or download this repository
cd ~/.claude/commands
git clone https://github.com/lis186/SourceAtlas.git sourceatlas

# Or copy the plugin directory
cp -r /path/to/sourceatlas-plugin ~/.claude/commands/sourceatlas
```

### Method 2: Via Claude Code Plugin (Recommended)

```bash
# In Claude Code, add the marketplace
/plugin marketplace add justinlee/sourceatlas-marketplace

# Install the plugin
/plugin install sourceatlas@sourceatlas-marketplace

# Start using
/atlas.init
/atlas.pattern "api endpoint"
```

## 📖 Usage

### `/atlas.init` - Initialize Project 🆕

Initialize SourceAtlas in your project by injecting auto-trigger rules into CLAUDE.md.

```bash
/atlas.init
```

**What it does:**
- Creates or updates CLAUDE.md with SourceAtlas auto-trigger rules
- Claude Code will automatically suggest Atlas commands when appropriate
- Sets up command reference for quick access

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

### `/atlas.pattern` - Learn Design Patterns ⭐

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

### `/atlas.impact` - Impact Analysis 🆕

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

### `/atlas.history` - History Analysis 🆕

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
- Chinese/English bilingual prompts

### `/atlas.flow` - Flow Analysis ⭐ NEW

Trace code execution flow and data flow with natural language queries.

```bash
# Trace user flow
/atlas.flow "用戶登入流程"
/atlas.flow "What happens when user clicks submit"

# Trace specific function
/atlas.flow "handleSubmit"
/atlas.flow "trace processOrder function"

# Error path analysis
/atlas.flow "API 錯誤處理流程"

# Data flow tracing
/atlas.flow "資料從哪裡來 userProfile"

# Reverse tracing
/atlas.flow "誰調用 validateToken"
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
- Step-by-step expansion

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
├── commands/
│   ├── atlas.init.md        # Project initialization
│   ├── atlas.overview.md    # Project overview
│   ├── atlas.pattern.md     # Pattern learning
│   ├── atlas.impact.md      # Impact analysis
│   ├── atlas.history.md     # History analysis
│   └── atlas.flow.md        # Flow analysis ⭐ NEW
├── README.md
├── CHANGELOG.md
├── TESTING.md
└── LICENSE
```

### Testing Locally

```bash
# Create a test marketplace structure
mkdir -p ~/test-marketplace
cp -r plugin ~/test-marketplace/sourceatlas-plugin

# Add local marketplace in Claude Code
/plugin marketplace add file:///Users/yourname/test-marketplace

# Install and test
/plugin install sourceatlas-plugin@test-marketplace

# Test in any project
cd ~/your-project
/atlas.init
/atlas.overview
/atlas.pattern "api endpoint"
/atlas.impact "User model"

# After making changes
/plugin uninstall sourceatlas-plugin@test-marketplace
# Make your changes
/plugin install sourceatlas-plugin@test-marketplace
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

Based on SourceAtlas v2.5 methodology:
- Three-stage analysis framework
- Information theory principles
- High-entropy file prioritization
- Static dependency analysis

## 📚 Resources

- [SourceAtlas Documentation](https://github.com/lis186/SourceAtlas)
- [Claude Code Plugin Docs](https://code.claude.com/docs/en/plugins)

---

**SourceAtlas v2.7.0** - Understanding codebases at the speed of thought 🚀
