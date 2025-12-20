# SourceAtlas

> 🌐 **English** | [繁體中文](./README.zh-TW.md)

**9 slash commands to quickly understand any codebase**

For Claude Code | Supports iOS/TypeScript/Android/Python

[![Version](https://img.shields.io/badge/version-v2.9.5-blue)](https://github.com/lis186/SourceAtlas/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)
[![Constitution](https://img.shields.io/badge/constitution-v1.1-purple)](./ANALYSIS_CONSTITUTION.md)

---

## 💡 What Problem Does It Solve?

- ❌ Taking over a new project, spending days still not understanding the architecture
- ❌ Want to modify code, but afraid to touch it, worried about affecting other parts
- ❌ Want to learn the project's design patterns, can't find good examples

**→ With SourceAtlas: 5-15 minutes to understand a project, 0.1-30 seconds to find examples, 1-2 minutes to analyze impact**

---

## 🚀 Nine Commands

### 1. Quick Project Understanding

```bash
/atlas.overview
```

**Get in 5-15 minutes**: Tech stack, architecture patterns, code quality, project scale

**Example**: Taking over a 50K LOC project, know within 10-15 minutes what framework it uses, MVVM or Clean Architecture, what the test coverage is

---

### 2. Learn Design Patterns

```bash
/atlas.pattern "api endpoint"
/atlas.pattern "file upload"
/atlas.pattern "authentication"
```

**Find in 0.1-30 seconds**: 2-3 best example files + file:line references + implementation guide

**Example**: Want to know how this project handles APIs, directly find `UserAPI.swift:45` and test examples

**Supports 141 patterns**: MVVM, Networking, Core Data, React Hook, Next.js API, Jetpack Compose, Vue Composable, Pinia, Zustand...

---

### 3. Analyze Code Impact

```bash
/atlas.impact "src/api/users.ts"
/atlas.impact api "/api/users/{id}"
```

**Get in 1-2 minutes**: Dependency list, Breaking Changes risk, test impact scope, migration steps

**Example**: Want to refactor User API, know within 1-2 minutes that 23 files are using it, with 5 breaking changes

**iOS Project Special Feature**: Auto-check Swift/ObjC interop risks (nullability, @objc exposure, memory issues)

---

### 4. Temporal Analysis (Git History)

```bash
/atlas.history
/atlas.history src/
/atlas.history . 6    # Last 6 months
```

**Get in 5-10 minutes**: Hotspots (high-churn files), Coupling (hidden dependencies), Recent Contributors (knowledge distribution)

**Example**: Want to refactor a core module, know within 5-10 minutes which files change most frequently, which files always change together, who's most familiar with this code

**Auto-handles**:
- Detects Shallow Clone and provides solutions
- Auto-installs code-maat (first use)
- Identifies Bus Factor risks (single contributor)

---

### 5. Flow Tracing (Data Flow Analysis) ⭐ NEW

```bash
/atlas.flow "user login"
/atlas.flow "from LoginViewController"
/atlas.flow "checkout process"
```

**Get in 3-5 minutes**: Entry points, execution paths, boundary identification (API/DB/Auth/Payment), data flow

**Example**: Want to understand login flow, trace within 3-5 minutes from `LoginViewController` to `AuthService` → `APIClient` → `UserRepository`

**11 Analysis Modes**:
- Language-specific entry point detection (Swift, TypeScript, Kotlin, Python)
- 10 boundary types: API 🌐, DB 💾, Auth 🔐, Payment 💳, File 📁, Push 📲...
- Confidence scoring: Distinguish high/low confidence identification results

---

### 6. Dependency Analysis (Upgrade Planning) ⭐ NEW

```bash
/atlas.deps "iOS 16 → 17"
/atlas.deps "React 17 → 18"
/atlas.deps "Flask 1.x → 3.x"
/atlas.deps "kotlinx.coroutines"  # Pure inventory
```

**Get in 3-30 minutes**: Removable checks, Deprecated APIs, new features, third-party compatibility, Migration Checklist

**Example**: Upgrading to iOS 17, get a complete upgrade plan in 15-30 minutes: 10 version checks removable, 35 deprecated APIs to update, 16 modernization opportunities, 40-60 hours estimated effort

**Core Features**:
- **Phase 0 Rule Confirmation** - Preview rules before upgrade, can supplement or adjust
- **Built-in Rules** - iOS 16→17, React 17→18, Python 3.11→3.12
- **Dynamic Rule Generation** - WebSearch auto-queries latest migration guides
- **Dual Mode** - Auto-identifies "upgrade analysis" vs "pure inventory"
- **Multi-module Support** - Handles Android projects with 30 modules
- **Graceful Degradation** - Can analyze even without requirements.txt

**Production Ready** - Grade A+ (9.7/10), 100% accuracy (42/42 sample tests)

---

### 7. Project Initialization

```bash
/atlas.init
```

**One-time setup**: Injects auto-trigger rules into CLAUDE.md, afterwards Claude will automatically suggest appropriate commands

---

### 8. View Saved Analyses

```bash
/atlas.list
```

**Instant view**: Lists all caches in `.sourceatlas/`, shows expiration status (⚠️ >30 days), provides copy-ready re-analysis commands

---

### 9. Clear Cache

```bash
/atlas.clear              # Clear all
/atlas.clear patterns     # Only clear patterns/
```

**Cache management**: Clear saved analysis results, free up space or force re-analysis

---

## ⚡ Quick Start

### Prerequisites

| Requirement | Minimum Version | Recommended | Notes |
|-------------|-----------------|-------------|-------|
| **Claude Code** | 0.3+ | Latest | [Installation Guide](https://claude.ai/code)<br/>Requires Slash Commands support |
| **Git** | 2.0+ | 2.30+ | Version control tool |
| **Bash** | 4.0+ | 5.0+ | macOS pre-installs 3.2 which works, but upgrade recommended |
| **OS** | - | - | macOS 12+ or Linux (Ubuntu 20.04+) |

<details>
<summary><b>⚠️ Compatibility Notes</b></summary>

**Claude Code Version Requirements**:
- ✅ **v0.3+**: Full support (Slash Commands)
- ❌ **v0.2-**: Not supported (please upgrade)

**Operating System Support**:
- ✅ **macOS 12+** (Monterey): Fully tested
- ✅ **macOS 11** (Big Sur): Should work (not fully tested)
- ✅ **Linux (Ubuntu 20.04+)**: Basic support
- ⚠️ **Linux (other distros)**: May need script adjustments
- ❌ **Windows**: Not supported (WSL untested)

**Bash Version**:
- macOS pre-installed Bash 3.2 **works**, but some features limited
- Upgrade to Bash 5.0+ for better performance: `brew install bash`

**Project Language Support**:
- ✅ **iOS/Swift**: Full support (34 patterns)
- ✅ **TypeScript/React/Vue**: Full support (50 patterns)
- ✅ **Android/Kotlin**: Full support (31 patterns)
- ✅ **Python**: Full support (26 patterns)
- 🔵 **Go/Rust**: Planned (v2.6)

</details>

### Installation (2 minutes)

```bash
# 1. Clone the project
git clone https://github.com/lis186/SourceAtlas.git ~/dev/sourceatlas2

# 2. Run installation
cd ~/dev/sourceatlas2 && ./install-global.sh
```

✅ Install once, use in all projects:

```bash
cd ~/projects/any-project
/atlas.init      # First use: inject auto-trigger rules
/atlas.overview  # Quick project understanding
```

### Verify Installation

```bash
# Check if commands are installed
ls ~/.claude/commands/atlas.*.md

# Should see 9 files:
# atlas.init.md
# atlas.overview.md
# atlas.pattern.md
# atlas.impact.md
# atlas.history.md
# atlas.flow.md
# atlas.deps.md
# atlas.list.md
# atlas.clear.md
```

📚 **Complete Installation Guide**: [GLOBAL_INSTALLATION.md](./GLOBAL_INSTALLATION.md)

---

## 🧭 Command Decision Tree

**Not sure which command to use?** Follow this flow:

```
What do you want to do?
│
├─ ⚙️ First time using SourceAtlas in this project
│   → Use /atlas.init
│   → Injects auto-trigger rules into CLAUDE.md
│   → Afterwards Claude will auto-suggest appropriate commands
│
├─ 📚 Just took over a project, want to understand quickly
│   → Use /atlas.overview
│   → Get in 5-15 minutes: tech stack, architecture, quality
│
├─ 🔍 Want to learn a specific implementation pattern
│   → Use /atlas.pattern "keyword"
│   → Find in 0.1-30 seconds: example files + implementation guide
│   → Example: /atlas.pattern "api endpoint"
│
├─ ⚠️ About to modify code, worried about affecting other parts
│   → Use /atlas.impact "file or API"
│   → Get in 1-2 minutes: dependency list + Breaking Changes
│   → Example: /atlas.impact "src/api/users.ts"
│
├─ 📊 Want to understand project hotspots and knowledge distribution
│   → Use /atlas.history [scope]
│   → Get in 5-10 minutes: Hotspots + Coupling + Contributors
│   → Example: /atlas.history src/
│
├─ 🔀 Want to trace a feature's execution flow
│   → Use /atlas.flow "description or entry point"
│   → Get in 3-5 minutes: entry points + execution path + boundaries
│   → Example: /atlas.flow "user login"
│
└─ ❓ Still not sure
    → Start with /atlas.overview to build the big picture
    → Then use other commands as needed
```

**Common Workflows**:

1. **New Project Onboarding**: `/atlas.init` → `/atlas.overview` → `/atlas.pattern` to learn key patterns
2. **Preparing to Refactor**: `/atlas.history` find hotspots → `/atlas.impact` analyze impact → start modifying
3. **Learning Architecture**: `/atlas.overview` → read key files → `/atlas.pattern` learn details
4. **Taking Over Legacy Project**: `/atlas.history` see hotspots + knowledge distribution → `/atlas.overview` understand architecture

---

## 📖 Documentation

### Core Documentation

- **[Usage Guide](./USAGE_GUIDE.md)** - Complete command reference, 141 patterns, troubleshooting
- **[Global Installation](./GLOBAL_INSTALLATION.md)** - Installation options, management commands, troubleshooting
- **[Benchmark](./BENCHMARK.md)** - Test results from 8 real projects, accuracy data

### Developer Resources

- **[CLAUDE.md](./CLAUDE.md)** - AI collaboration guide, project architecture, development standards
- **[Development History](./dev-notes/HISTORY.md)** - Complete evolution timeline
- **[PRD](./PRD.md)** - Product Requirements Document (v2.7.0)

---

## 💬 FAQ

<details>
<summary><b>Q: What do I need?</b></summary>

Claude Code + 2 minutes installation

</details>

<details>
<summary><b>Q: What languages are supported?</b></summary>

- **iOS/Swift**: 34 patterns (MVVM, Coordinator, Core Data, SwiftUI...)
- **TypeScript/React/Vue**: 50 patterns (Hooks, Next.js, Zustand, Pinia...)
- **Android/Kotlin**: 31 patterns (ViewModel, Room, Compose, Hilt, MVI...)
- **Python**: 26 patterns (Django, FastAPI, Flask, Celery...)

Complete list in [USAGE_GUIDE.md](./USAGE_GUIDE.md#supported-patterns-141)

</details>

<details>
<summary><b>Q: Is it accurate?</b></summary>

**Tested on 5 public open-source projects**:

| Metric | Result | Projects |
|--------|--------|----------|
| **Pattern Detection** | 73% Good, 27% Fair | 5 projects |
| **Swift Quality** | 100% Good | Swiftfin, WordPress-iOS |
| **Execution Speed** | 0.3s - 14s | All patterns |
| **Scan Efficiency** | <1.5% files | All projects |

**Test Projects**: [Swiftfin](https://github.com/jellyfin/Swiftfin), [WordPress-iOS](https://github.com/wordpress-mobile/WordPress-iOS), [Signal-Android](https://github.com/signalapp/Signal-Android), [AntennaPod](https://github.com/AntennaPod/AntennaPod), [FastAPI](https://github.com/tiangolo/fastapi)

📊 **Complete Data**: [BENCHMARK.md](./BENCHMARK.md)

</details>

<details>
<summary><b>Q: Is it slow?</b></summary>

| Command | Time | Notes |
|---------|------|-------|
| `/atlas.overview` | 5-15 minutes | Depends on project size |
| `/atlas.pattern` | 0.1-30 seconds | Usually <5 seconds |
| `/atlas.impact` | 1-2 minutes | Large projects 2-3 minutes |
| `/atlas.history` | 5-10 minutes | Depends on Git history size |

</details>

<details>
<summary><b>Q: Can I use it with private codebases?</b></summary>

Yes! All analysis runs locally, but note:

- ⚠️ Code is sent to Claude API for analysis
- ⚠️ Please review [Anthropic Privacy Policy](https://www.anthropic.com/legal/privacy)
- ✅ You can choose to only use it on public projects

</details>

<details>
<summary><b>Q: When is it NOT suitable?</b></summary>

❌ **Not recommended for**:

1. **Small projects** (<2K LOC) - Reading directly is faster
2. **Need 100% precision** (e.g., production decisions) - Use static analysis tools
3. **Highly sensitive code** (finance, medical) - Consider privacy policy restrictions
4. **Offline environments** - Requires network connection to Claude API

✅ **Suitable for**:

- Quickly understanding medium to large projects (>2K LOC)
- Learning project design patterns
- Evaluating technical debt and architecture
- Impact analysis before refactoring

</details>

<details>
<summary><b>Q: What if I don't have Claude Code?</b></summary>

You can use the manual method (see [PROMPTS.md](./PROMPTS.md)), but Claude Code is recommended for the best experience.

</details>

<details>
<summary><b>Q: Can analysis results be saved?</b></summary>

**Yes!** All analysis commands support the `--save` parameter:

```bash
/atlas.overview --save           # Save to .sourceatlas/overview.yaml
/atlas.pattern "api" --save      # Save to .sourceatlas/patterns/api.md
/atlas.flow "login" --save       # Save to .sourceatlas/flows/login.md
/atlas.history --save            # Save to .sourceatlas/history.md
/atlas.impact "User" --save      # Save to .sourceatlas/impact/user.md
/atlas.deps "react" --save       # Save to .sourceatlas/deps/react.md
```

**Clear saved analyses**:

```bash
/atlas.clear              # Clear all
/atlas.clear patterns     # Only clear patterns/
```

**Use cases**:
- 📝 Keep analysis results for future reference
- 👥 New team members can read existing analyses
- 🔄 Avoid re-running the same analysis

</details>

---

## 📜 Analysis Constitution

**New in v2.8.0**: All analysis commands follow [ANALYSIS_CONSTITUTION.md](./ANALYSIS_CONSTITUTION.md)

### Core Principles

| Principle | Description |
|-----------|-------------|
| **Information Theory** | High-entropy priority, scan ratio limits (TINY 50%, LARGE 5%) |
| **Exclusion Policy** | Mandatory exclusion of node_modules, .venv, build, etc. |
| **Hypothesis Policy** | Structured hypotheses + confidence levels + evidence references |
| **Evidence Policy** | `file:line` precise references, no unsupported assertions |
| **Handoffs** | Discovery-driven dynamic next-step suggestions (new in v1.1) |

### Validation Tool

```bash
# Check if analysis output complies with Constitution
bash scripts/atlas/validate-constitution.sh <analysis-output.yaml>

# Check project structure compliance
bash scripts/atlas/validate-constitution.sh --check-structure
```

### Measured Results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| file:line references | 0.3 | 12 | +3900% |
| Validation cost | Manual review | Auto 1 sec | -95% |
| Output lines | 361 lines | 133 lines | -63% |

---

## 🗺️ Development Status

**v2.9.4 (Current)**: AI Collaboration Detection - Support 12+ AI tools ✅

- ✅ `/atlas.init` - Project initialization (auto-trigger rules)
- ✅ `/atlas.overview` - Project overview
- ✅ `/atlas.pattern` - Design pattern learning
- ✅ `/atlas.impact` - Impact analysis (static analysis)
- ✅ `/atlas.history` - Temporal analysis (Git history)
- ✅ `/atlas.flow` - Flow tracing (data flow analysis)
- ✅ `/atlas.deps` - Dependency analysis (upgrade planning) ⭐ NEW
- ✅ `/atlas.list` - View saved analyses ⭐ NEW
- ✅ `/atlas.clear` - Clear cache
- ✅ **Persistence v2.0** - `--save` parameter, 30-day expiration warning, informative caching

**v3.0 (Planned)**: Go/Rust/Ruby patterns, AST analysis integration, SourceAtlas Monitor

---

## 🤝 Feedback & Contributions

- 💬 **Report Issues**: [GitHub Issues](https://github.com/lis186/SourceAtlas/issues)
- 🔧 **Contribute Code**: PRs welcome
- 🌍 **Add Languages**: Python, Ruby, Go, Rust...

---

**SourceAtlas** - Code Analysis Assistant for Claude Code
v2.9.4 | Last Updated: 2025-12-19 | MIT License

Made with ❤️ and 🤖
