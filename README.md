# SourceAtlas

> 🌐 **English** | [繁體中文](./README.zh-TW.md)

**Get project overview in ~3 minutes by scanning <5% of files**

[![Version](https://img.shields.io/badge/version-v2.9.6-blue)](https://github.com/lis186/SourceAtlas/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

---

## Have You Ever...

- Spent **3 days** on a new project and still don't understand the architecture?
- Wanted to change one line, but **afraid it might break everything**?
- Asked a colleague "how do I write this", and got "just look at file XXX"?
- Needed to upgrade iOS 16 → 17, but had **no idea how much work** it would take?

**SourceAtlas solves these in minutes, not days.**

---

## Before & After

| Task | Before | After |
|------|--------|-------|
| Understand project architecture | 2-3 days | **~3-15 minutes** ✓ |
| Find API implementation examples | Ask colleagues / random searching | **~seconds** ✓ |
| Analyze impact of code changes | Manual tracking, hope for the best | **~1-2 minutes** |
| Plan framework upgrade | Weeks of research | **~15-30 minutes** |
| Find code hotspots & experts | Ask around | **~5-10 minutes** |

<sub>✓ = benchmarked on 5 open-source projects. Others are estimates based on usage.</sub>

---

## 6 Commands for 6 Real Problems

### 1. "I just joined the project, where do I start?"

```bash
/atlas.overview
```

**In 5-15 minutes, get**: Tech stack, architecture patterns, project scale, code quality signals

> *"Within 10 minutes, I knew it was Swift 5.10 + MVVM + Coordinator, with 12K files and decent test coverage"*

---

### 2. "I want to write an API, how does this project do it?"

```bash
/atlas.pattern "api endpoint"
/atlas.pattern "authentication"
/atlas.pattern "database query"
```

**In 0.1-30 seconds, get**: 2-3 best example files with exact line numbers + implementation guide

> *"Found `UserAPI.swift:45` with tests — copied the pattern, done in 5 minutes"*

**221 patterns supported**: MVVM, Networking, Core Data, React Hooks, Next.js API, Jetpack Compose, Vue Composable, FastAPI, Rails Controller...

---

### 3. "I want to change this file, what else will break?"

```bash
/atlas.impact "src/api/users.ts"
/atlas.impact api "/api/users/{id}"
```

**In 1-2 minutes, get**: All dependents, Breaking Change risks, test coverage, migration steps

> *"Found 23 files depending on it, 5 breaking changes — knew exactly what to update"*

---

### 4. "Who knows this code best? What's the danger zone?"

```bash
/atlas.history
/atlas.history src/
```

**In 5-10 minutes, get**: Hotspots (files that change constantly), Hidden Coupling, Knowledge Distribution

> *"Discovered `PaymentService.swift` changed 47 times in 6 months, only 1 person touched it — bus factor alert!"*

---

### 5. "How does the login flow actually work?"

```bash
/atlas.flow "user login"
/atlas.flow "checkout process"
```

**In 3-5 minutes, get**: Entry points, complete execution path, boundary identification (API/DB/Auth/Payment)

> *"Traced from `LoginViewController` → `AuthService` → `APIClient` → `TokenManager` in one shot"*

---

### 6. "We need to upgrade to iOS 17, how much work is that?"

```bash
/atlas.deps "iOS 16 → 17"
/atlas.deps "React 17 → 18"
/atlas.deps "Python 3.11 → 3.12"
```

**In 15-30 minutes, get**: Deprecated APIs, version checks to remove, third-party compatibility, effort estimate

> *"Got a complete migration checklist: 10 version checks removable, 35 deprecated APIs, estimated 40-60 hours"*

---

## Benchmark Results

**Tested on 5 open-source projects**: Firefox iOS, Discourse, Cal.com, Prefect, Thunderbird

### `/atlas.overview` - Project Understanding

| Metric | Result |
|--------|--------|
| **Overall Accuracy** | 93% (56/60 points) |
| **Tech Stack Detection** | 90% |
| **Architecture Detection** | 90% |
| **Core Modules** | 100% |
| **Business Domain** | 100% |
| **AI Collaboration Level** | 100% |
| **Average Speed** | ~2 min 41 sec per project |

### `/atlas.pattern` - Pattern Search

| Metric | Result |
|--------|--------|
| **Search Precision** | 98.6% |
| **Test Cases** | 7/7 passed |
| **Languages Tested** | Swift, Ruby, Python, TypeScript, Kotlin |

### `/atlas.impact` - Impact Analysis

| Metric | Result |
|--------|--------|
| **Internal Consistency** | 100% (5/5 projects) |
| **Languages Tested** | Swift, Ruby, Python, TypeScript, Kotlin |
| **Total Dependencies Analyzed** | 2,068 files |

<sub>Note: Internal Consistency = category subtotals sum to total (no double-counting). LLM-based analysis may vary from simple grep counts.</sub>

### `/atlas.flow` - Flow Tracing ✓

| Metric | Result |
|--------|--------|
| **Entry Point Detection** | 100% (5/5 projects) |
| **Call Chain Depth** | 4-5 levels per project |
| **Boundary Identification** | 100% (4-5 types per project) |
| **Languages Tested** | Swift, Ruby, Python, TypeScript, Kotlin |

<sub>✓ = E2E verified on 2025-12-21. [Verification Report](./dev-notes/2025-12/2025-12-21-flow-e2e-verification.md)</sub>

<sub>Note: Other commands not yet formally benchmarked.</sub>

---

## Quick Start (2 minutes)

### Requirements

- **Claude Code** 0.3+ ([Get it here](https://claude.ai/code))
- **Git** 2.0+
- **macOS 12+** or **Linux**

### Installation

```bash
# 1. Clone
git clone https://github.com/lis186/SourceAtlas.git ~/dev/sourceatlas2

# 2. Install
cd ~/dev/sourceatlas2 && ./install-global.sh
```

### First Use

```bash
cd ~/projects/any-project
/atlas.init      # One-time: inject auto-trigger rules
/atlas.overview  # Start understanding
```

**Verify installation**:
```bash
ls ~/.claude/commands/atlas.*.md
# Should see 9 files
```

---

## All 9 Commands

| Command | Problem It Solves | Time |
|---------|------------------|------|
| `/atlas.overview` | New to project, need the big picture | ~3-15 min ✓ |
| `/atlas.pattern "X"` | Need to implement X, want examples | ~seconds ✓ |
| `/atlas.impact "file"` | About to change code, worried about side effects | ~1-2 min |
| `/atlas.history` | Need to find hotspots and experts | ~5-10 min |
| `/atlas.flow "feature"` | Need to understand a feature's execution path | ~3-5 min |
| `/atlas.deps "upgrade"` | Planning framework/SDK upgrade | ~15-30 min |
| `/atlas.init` | First time using SourceAtlas | ~10 sec |
| `/atlas.list` | Check what analyses are cached | instant |
| `/atlas.clear` | Clear outdated cache | instant |

<sub>✓ = benchmarked. Times without ✓ are estimates.</sub>

---

## Supported Languages

| Language | Patterns | Example Patterns |
|----------|----------|------------------|
| **Swift/iOS** | 34 | MVVM, Coordinator, Core Data, SwiftUI, Combine |
| **TypeScript/React/Vue** | 50 | Hooks, Next.js, Zustand, Pinia, tRPC |
| **Kotlin/Android** | 31 | ViewModel, Room, Compose, Hilt, MVI |
| **Python** | 26 | Django, FastAPI, Flask, Celery, SQLAlchemy |
| **Ruby/Rails** | 26 | ActiveRecord, Controller, Service, Job |
| **Go** | 26 | Handler, Service, Middleware, Repository |
| **Rust** | 28 | Handler, Service, Middleware, Async Runtime |

**Total: 221 patterns**

---

## Limitations

| Limitation | Details |
|------------|---------|
| **Benchmark scope** | Only `/atlas.overview` tested; other commands are estimates |
| **Tech Stack detection** | May miss secondary languages (e.g., React in a Python project) |
| **Architecture detection** | May miss secondary patterns (e.g., MVI in Clean Architecture) |
| **Best for mature projects** | Works best with README, config files; limited for undocumented legacy code |
| **Language coverage** | 7 languages supported; non-mainstream languages need manual verification |

---

## When NOT to Use

| Situation | Why | Alternative |
|-----------|-----|-------------|
| Small projects (<2K LOC) | Reading directly is faster | Just read the code |
| Need 100% precision | AI has ~93% accuracy | Use static analysis tools |
| Highly sensitive code | Code sent to Claude API | Check your compliance policy |
| Offline environment | Requires API connection | Use local tools |

---

## Save & Share Analyses

All commands support `--save`:

```bash
/atlas.overview --save          # → .sourceatlas/overview.yaml
/atlas.pattern "api" --save     # → .sourceatlas/patterns/api.md
/atlas.history --save           # → .sourceatlas/history.md
```

**Benefits**:
- New team members can read existing analyses
- Avoid re-running expensive analyses
- Track how the codebase evolves

**Manage cache**:
```bash
/atlas.list   # View all cached analyses
/atlas.clear  # Clear all or specific caches
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [Usage Guide](./USAGE_GUIDE.md) | Complete command reference, all 221 patterns |
| [Installation Guide](./GLOBAL_INSTALLATION.md) | Detailed installation options |
| [Analysis Constitution](./ANALYSIS_CONSTITUTION.md) | Quality principles all analyses follow |
| [CLAUDE.md](./CLAUDE.md) | Developer guide, architecture |

---

## Feedback & Contributions

- **Report Issues**: [GitHub Issues](https://github.com/lis186/SourceAtlas/issues)
- **Contribute Code**: PRs welcome
- **Add Languages**: Python, Ruby, Go, Rust patterns welcome

---

**SourceAtlas** — Understand any codebase in minutes, not days.

v2.9.6 | MIT License | Made with Claude Code
