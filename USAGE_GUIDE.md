# SourceAtlas - Usage Guide

> 🌐 **English** | [繁體中文](./USAGE_GUIDE.zh-TW.md)

**Complete usage instructions for 7 slash commands**

For Claude Code | v2.9.0 | Constitution v1.1

---

## Table of Contents

1. [Use Cases](#use-cases)
2. [Recommended Workflow](#recommended-workflow)
3. [Installation](#installation)
4. [Command 1: /atlas.overview](#command-1-atlasoverview)
5. [Command 2: /atlas.pattern](#command-2-atlaspattern)
6. [Command 3: /atlas.impact](#command-3-atlasimpact)
7. [Command 4: /atlas.history](#command-4-atlashistory)
8. [Command 5: /atlas.flow](#command-5-atlasflow)
9. [Command 6: /atlas.deps](#command-6-atlasdeps) ⭐ NEW
10. [Command 7: /atlas.init](#command-7-atlasinit)
11. [FAQ](#faq)

---

## Use Cases

SourceAtlas is suitable for the following common scenarios:

| # | Scenario | Main Commands | Description |
|---|----------|--------------|-------------|
| 1 | **Onboarding to a new project** | `/atlas.overview` | First day on the team, quickly build holistic understanding |
| 2 | **Code Review / Technical Due Diligence** | `/atlas.overview` + `/atlas.history` | Assess code quality and project evolution |
| 3 | **Bug Fixing** | `/atlas.flow` | Trace execution path, locate root cause |
| 4 | **Adding Features** | `/atlas.pattern` + `/atlas.impact` | Learn existing conventions, evaluate impact scope |
| 5 | **Interview Candidate GitHub Assessment** | `/atlas.overview` + `/atlas.history` | Quickly assess development skills and habits |
| 6 | **Learning Open Source Projects** | `/atlas.overview` + `/atlas.pattern` | Understand architectural design and best practices |
| 7 | **Breaking Change Evaluation** | `/atlas.impact` + `/atlas.flow` | Modifying your own API, find all call sites |
| 8 | **Library/Framework Upgrade** | `/atlas.impact` + `/atlas.pattern` | Upgrading third-party packages, find usage points, learn new patterns |

### Entry Points by Experience Level

| Experience Level | Main Challenge | Recommended Starting Point |
|-----------------|----------------|---------------------------|
| **Junior** | Don't know how to "read" code, easily lost in details | `/atlas.overview` for global map → `/atlas.pattern` to learn conventions |
| **Mid-level** | Know how to read, but inefficient, easily miss things | `/atlas.flow` to trace execution → `/atlas.impact` to evaluate change scope |
| **Senior** | Efficiency is decent, but want faster, want to verify hypotheses | `/atlas.history` to see evolution context, quickly verify architectural guesses |

---

## Recommended Workflow

### Standard 5-Step Process (Suitable for Most Scenarios)

```
1. /atlas.overview     → Build holistic understanding (5-10 minutes)
2. /atlas.pattern      → Learn project conventions (as needed)
3. /atlas.flow         → Trace specific feature flows (as needed)
4. /atlas.impact       → Evaluate change impact (when ready to code)
5. /atlas.history      → Understand evolution context (for deeper dive)
```

### Scenario Variations

**Scenarios 1-2: Quick Project Understanding**
```
/atlas.overview → /atlas.history (optional)
```

**Scenario 3: Bug Fixing**
```
/atlas.flow "from [entry point]" → Locate issue
```

**Scenario 4: Adding Features**
```
/atlas.pattern "[feature type]" → /atlas.impact "[related file]"
```

**Scenarios 7-8: Upgrade Evaluation**
```
/atlas.impact "[API or library]" → /atlas.pattern "[new version pattern]"
```

---

## Installation

**Complete installation guide**: [GLOBAL_INSTALLATION.md](./GLOBAL_INSTALLATION.md)

### Quick Start

```bash
git clone https://github.com/lis186/SourceAtlas.git ~/dev/sourceatlas2
cd ~/dev/sourceatlas2 && ./install-global.sh
```

Install once, use in all projects.

---

## Command 1: /atlas.overview

**Quickly understand project overview**

### Usage

```bash
/atlas.overview
```

### What You Get

- **Tech Stack**: Languages, frameworks, databases
- **Architecture Pattern**: MVC, MVVM, Clean Architecture...
- **Project Scale**: File count, lines of code
- **Code Quality**: Test coverage, comment density
- **Directory Structure**: Key folders and files

### When to Use

- ✅ Onboarding to new project
- ✅ Code Review
- ✅ Technical Assessment
- ✅ Hiring evaluation (reviewing candidate's GitHub projects)

### Execution Time

- **Small projects** (<5K LOC): 5-10 minutes
- **Medium projects** (5K-50K LOC): 10-15 minutes
- **Large projects** (>50K LOC): 15-20 minutes

### Usage Examples

#### Example 1: Onboarding to New Project

**Scenario**: First day on the team, need to quickly understand a 50K LOC project

**Command**:
```bash
/atlas.overview
```

**Output** (summary):
```yaml
project_type: WEB_APP
primary_language: TypeScript
frameworks:
  - Next.js 14
  - React 18
  - Prisma
architecture_pattern: CLEAN_ARCHITECTURE
test_coverage: 85%
key_directories:
  - src/app/ (Next.js App Router)
  - src/components/ (React Components)
  - prisma/ (Database Schema)
```

**What You Learned**:
- This is a full-stack project using Next.js 14 + React
- Uses Clean Architecture (high code quality)
- 85% test coverage (professional team)
- Main logic is in src/app/ (App Router architecture)

**Next Step**: Use `/atlas.pattern "api endpoint"` to learn API implementation patterns

---

## Command 2: /atlas.pattern

**Learn project design patterns**

### Usage

```bash
/atlas.pattern "api endpoint"
/atlas.pattern "file upload"
/atlas.pattern "authentication"
```

### What is a "Pattern"?

In SourceAtlas, a **Pattern** refers to recurring code structures and design approaches in a project:

- **Architectural Patterns**: MVVM, Clean Architecture, Repository
- **Implementation Patterns**: API endpoint, file upload, authentication
- **UI Patterns**: SwiftUI view, React component, custom button

Simply put: **"How does this project typically implement X?"**

### What You Get

1. **Best Example Files** (2-3) + file:line references
2. **Key Conventions**: Naming, structure, organization
3. **Testing Patterns**: How to test this feature
4. **Implementation Guide**: Step-by-step guide for new features

### Supported Patterns (141 total)

#### Quick Overview

| Language | Pattern Count | Main Categories |
|----------|--------------|----------------|
| **iOS/Swift** | 34 | Architecture, UI, Data Handling, Feature Modules |
| **TypeScript/React/Vue** | 50 | React Core, Vue Core, Backend Integration |
| **Android/Kotlin** | 31 | Architecture Components, UI, Data Layer |
| **Python** | 26 | Django, FastAPI, Flask, Celery |

#### Popular Patterns (Cross-Language)

1. `api endpoint` - REST/GraphQL API implementation
2. `authentication` - Login/authentication flow
3. `view controller` - Screen/page components
4. `networking` - HTTP client pattern
5. `state management` - Application state management

<details>
<summary><b>📱 iOS/Swift Patterns (34 total)</b></summary>

#### Core Architecture (4)
- `mvvm` - MVVM architecture pattern
- `coordinator` - Coordinator navigation pattern
- `dependency injection` - DI Container/Factory
- `repository` - Repository data access pattern

#### UI Components (7)
- `swiftui view` - SwiftUI view composition
- `view controller` - UIKit ViewController
- `table view cell` - TableView/CollectionView Cell
- `view modifier` - SwiftUI ViewModifier
- `custom view` - Custom UI components
- `collection view layout` - CollectionView custom layout
- `animation` - UI animations

#### Data Handling (8)
- `networking` - Network layer, API Client
- `core data` - Core Data persistence
- `api endpoint` - REST/GraphQL API
- `cache` - Cache management
- `user defaults` - Local storage
- `keychain` - Secure storage
- `codable` - JSON encoding/decoding
- `combine publisher` - Reactive data flow

#### Feature Modules (10)
- `authentication` - Authentication flow
- `file upload` - File upload
- `background job` - Async tasks
- `error handling` - Error handling
- `localization` - Internationalization
- `push notification` - Push notifications
- `deep linking` - Deep Link handling
- `image loading` - Image loading & caching
- `biometric auth` - Face ID/Touch ID
- `analytics` - Event tracking

</details>

<details>
<summary><b>⚛️ TypeScript/React/Vue Patterns (50 total)</b></summary>

#### React Fundamentals (6)
- `react component` - React components
- `react hook` - Custom Hooks
- `state management` - State management
- `form handling` - Form handling
- `context provider` - Context API
- `error boundary` - Error boundaries

#### Next.js Specific (8)
- `nextjs middleware` - Middleware
- `nextjs layout` - App Router layout
- `nextjs page` - Page components
- `nextjs loading` - Loading states
- `nextjs error` - Error handling
- `server component` - Server components
- `server action` - Server Actions
- `route handler` - API route handling

#### Backend Integration (8)
- `api endpoint` - API routes
- `database query` - Prisma/ORM
- `authentication` - Auth.js/NextAuth
- `api client` - Fetch/Axios wrapper
- `websocket` - WebSocket connection
- `graphql` - GraphQL queries
- `file upload` - File upload
- `caching strategy` - Cache strategy

</details>

<details>
<summary><b>🤖 Android/Kotlin Patterns (31 total)</b></summary>

#### Architecture Components (8)
- `view controller` - Activity/Fragment
- `view model` - ViewModel (AAC)
- `repository` - Repository Pattern
- `use case` - UseCase/Interactor
- `dependency injection` - Hilt/Koin
- `navigation component` - Navigation architecture
- `room database` - Room persistence
- `data store` - DataStore preferences

#### UI Layer (6)
- `compose ui` - Jetpack Compose
- `recycler view` - RecyclerView Adapter
- `view binding` - ViewBinding
- `custom view` - Custom View
- `animation` - Animation effects
- `material design` - Material Components

#### Data & Network (6)
- `retrofit api` - Retrofit network requests
- `coroutines` - Kotlin Coroutines
- `flow` - Kotlin Flow
- `api endpoint` - REST API implementation
- `authentication` - Login authentication
- `file handling` - File handling

</details>

**Try it**: `/atlas.pattern "api endpoint"`

### Execution Time

**0.1 - 30 seconds** (depending on project size)

### Usage Examples

#### Example 1: Learning API Design

**Scenario**: Need to add an API endpoint, unsure of project's approach

**Command**:
```bash
/atlas.pattern "api endpoint"
```

**Output** (summary):
```
## Best Examples

1. `src/app/api/users/route.ts:15` - GET /api/users
2. `src/app/api/users/[id]/route.ts:20` - GET /api/users/:id
3. `src/app/api/posts/route.ts:10` - POST /api/posts

## Key Conventions

- File: `app/api/[resource]/route.ts`
- Export: `GET`, `POST`, `PUT`, `DELETE`
- Response: `NextResponse.json(data, { status })`
- Error: Try-catch with NextResponse

## Implementation Guide

1. Create `app/api/[resource]/route.ts`
2. Export async function GET/POST
3. Use Prisma for database access
4. Return NextResponse.json()
```

**What You Learned**:
- This project uses Next.js App Router (not Pages Router)
- All APIs are in `app/api/` directory, named `route.ts`
- Uniformly uses Prisma for database access
- Error handling uses try-catch + NextResponse

**Next Step**: Follow the Implementation Guide to create your new API

#### Example 2: Learning SwiftUI Components

**Scenario**: Need to write a custom SwiftUI component, want to learn project conventions

**Command**:
```bash
/atlas.pattern "swiftui view"
```

**Output** (summary):
```
## Best Examples

1. `Views/ProductCard.swift:10` - Reusable Card Component
2. `Views/UserProfile.swift:25` - Screen-level View
3. `Views/Components/Button.swift:5` - Custom Button

## Key Conventions

- File: `Views/[ComponentName].swift`
- Struct: Conform to `View` protocol
- Body: Use ViewBuilder
- Preview: Always include PreviewProvider

## Implementation Guide

1. Create new Swift file in Views/
2. Import SwiftUI
3. Struct [Name]: View { var body: some View { ... } }
4. Add PreviewProvider
```

**What You Learned**:
- All SwiftUI components are in `Views/` directory
- Small reusable components are in `Views/Components/`
- Every component must have PreviewProvider (team standard)
- Naming convention: PascalCase with capital first letter

**Next Step**: Follow the example file structure to create your new component

---

## Command 3: /atlas.impact

**Analyze code change impact**

### Usage

```bash
# Analyze a file
/atlas.impact "src/api/users.ts"

# Analyze an API
/atlas.impact api "/api/users/{id}"

# Analyze a Model
/atlas.impact "User model"
```

### What You Get

1. **Dependency Tracking**: Which files use this API/Model/Component
2. **Breaking Changes**: Which changes will break existing code
3. **Test Impact**: Which tests need updating
4. **Migration Checklist**: Step-by-step migration guide

**iOS Project Special Features** ⭐:
- Swift/ObjC Interop risk analysis
- Nullability checking
- @objc exposure analysis
- Memory management issues

### Execution Time

**1-2 minutes** (large projects may take 2-3 minutes)

### Usage Examples

#### Example 1: API Refactoring

**Scenario**: Need to refactor `/api/users/{id}` endpoint, worried about impacting existing features

**Command**:
```bash
/atlas.impact api "/api/users/{id}"
```

**Output** (summary):
```
## Impact Analysis: /api/users/{id}

### Direct Dependencies (23 files)

1. `src/components/UserProfile.tsx:45` - Fetch user data
2. `src/components/UserCard.tsx:20` - Display user info
3. `src/app/dashboard/page.tsx:30` - Load user list
...

### Breaking Changes 🔴

1. Changing response structure → 15 components need update
2. Adding authentication → 8 API calls need headers
3. Renaming fields → 12 TypeScript interfaces need update

### Migration Checklist

- [ ] Update UserProfile component
- [ ] Update UserCard component
- [ ] Update TypeScript types
- [ ] Update tests (8 test files)
- [ ] Update API documentation
```

**What You Learned**:
- This API is used by 23 files (large impact scope)
- 3 types of potential Breaking Changes
- Need to update 8 test files
- Complete Migration Checklist to follow

**Next Step**: Follow Migration Checklist step by step to avoid omissions

#### Example 2: iOS Model Modification

**Scenario**: Need to modify Swift Model, worried about impacting Objective-C code (mixed project)

**Command**:
```bash
/atlas.impact "User.swift"
```

**Output** (summary):
```
## Impact Analysis: User.swift

### Swift/ObjC Interop Risks 🔴

**Nullability Coverage**: 6% (CRITICAL)
- 2,255 header files missing NS_ASSUME_NONNULL
- Impact: Properties become `!` in Swift → Runtime crashes

**@objc Exposure**:
- 1,135 classes exposed to ObjC
- Changing User.swift affects 45 ObjC files

**Auto-fix Available**:
```bash
# Add nullability to all headers
find . -name '*.h' -not -path '*/Pods/*' -exec \
  sed -i '' '1i\NS_ASSUME_NONNULL_BEGIN' {} \;
```

### Direct Dependencies (45 files)

1. `UserViewController.m:120` - ObjC View Controller
2. `UserCell.m:35` - TableView Cell
...
```

**What You Learned**:
- This is a Swift/ObjC mixed project (iOS special scenario)
- Nullability coverage is only 6% (high risk!)
- Modifying User.swift affects 45 ObjC files
- Auto-fix script available to add NS_ASSUME_NONNULL

**Next Step**: First run Auto-fix script to improve Nullability, then modify Model

---

## Command 6: /atlas.deps

**Analyze Library/Framework usage for upgrade planning** ⭐ NEW

### Usage

```bash
/atlas.deps "react"
/atlas.deps "axios"
/atlas.deps "lodash" --breaking
```

### What is Dependency Analysis?

When you need to upgrade a library or framework, you need to know:
- Which **APIs** of this library does the project use?
- Which APIs have **breaking changes** in the new version?
- Which **files** need to be modified?

`/atlas.deps` automatically inventories all usage points, compares breaking changes, and generates a migration checklist.

### What You Get

1. **Version Info**: Current version vs latest version
2. **Usage Statistics**: Import count, file count, API types
3. **API Usage Details**: Usage count and location for each API
4. **Breaking Changes Impact**: Which usages will be affected
5. **Migration Checklist**: Files to modify and recommendations

### Execution Time

**1-3 minutes** (depending on project size and library usage)

### Usage Examples

#### Example 1: React Upgrade Evaluation

**Scenario**: Project uses React 17, want to upgrade to React 18

**Command**:
```bash
/atlas.deps "react"
```

**Output** (summary):
```
=== Dependency Analysis: react ===

📦 Version Info:
  - Current Version: 17.0.2
  - Latest Stable: 18.2.0

📊 Usage Statistics:
  - Import Count: 156 occurrences
  - APIs Used: 23 types

🔍 API Usage Details:

| API | Usage Count | React 18 Status |
|-----|------------|-----------------|
| useState | 89 | ✅ Compatible |
| useEffect | 67 | ✅ Compatible |
| ReactDOM.render | 3 | ⚠️ Deprecated |
| componentWillMount | 5 | 🔴 Removed |

⚠️ Breaking Changes Impact:

1. ReactDOM.render (3 occurrences)
   - src/index.tsx:5
   - src/utils/modal.tsx:12
   → Need to use createRoot

2. componentWillMount (5 occurrences)
   - src/legacy/OldComponent.tsx:15
   → Need to use useEffect

📋 Migration Checklist:
- [ ] Update src/index.tsx
- [ ] Refactor Legacy components
- [ ] Update test setup

Estimated Effort: 4-6 hours
Risk Level: 🟡 Medium
```

**What You Learned**:
- Project has 156 React usages
- Most APIs are compatible, but 3 places need to modify `ReactDOM.render`
- 5 Legacy components use removed lifecycle methods
- Estimated 4-6 hours to complete upgrade

**Next Step**: Follow Migration Checklist to modify one by one

#### Example 2: axios Upgrade

**Scenario**: Upgrading axios from 0.x to 1.x

**Command**:
```bash
/atlas.deps "axios" --breaking
```

**Output** (summary):
```
=== Dependency Analysis: axios ===

📦 Version Info:
  - Current Version: 0.27.2
  - Latest Stable: 1.6.2

⚠️ Breaking Changes Impact:

1. Response type changes
   - 12 places using response.data
   - TypeScript types need update

2. Error handling
   - 8 catch blocks need adjustment
   - error.response structure changed

📋 Migration Checklist:
- [ ] Update TypeScript type definitions
- [ ] Adjust 8 error handling blocks
- [ ] Update interceptors pattern

Estimated Effort: 2-3 hours
Risk Level: 🟡 Medium
```

---

## Command 7: /atlas.init

**Initialize SourceAtlas trigger rules**

### Usage

```bash
/atlas.init
```

### Feature Description

Injects SourceAtlas auto-trigger rules into the project's CLAUDE.md, so Claude Code knows when to automatically suggest using Atlas commands.

---

## FAQ

### Q: What if command execution fails?

**A**: Check the following:

1. **Confirm installation**:
   ```bash
   ls ~/.claude/commands/atlas.*.md
   ```

2. **Confirm in project directory**:
   ```bash
   pwd  # Should be at your project root
   ```

3. **Check error messages**: Commands will show detailed errors, usually path issues

### Q: Can I customize patterns?

**A**: Yes! Edit configuration files under `scripts/atlas/patterns/`.

Example: Add custom pattern
```bash
# 1. Copy existing pattern
cp scripts/atlas/patterns/ios/networking.sh scripts/atlas/patterns/ios/custom-pattern.sh

# 2. Modify file content
# 3. Reload Claude Code
```

### Q: Which project types are supported?

**A**: Currently supported:

- ✅ iOS (Swift + Objective-C)
- ✅ TypeScript (React + Next.js)
- ✅ Android (Kotlin)
- 🔵 Python (in development)
- 🔵 Ruby (in development)
- 🔵 Go (in development)

### Q: Where are analysis results saved?

**A**:
- Output is displayed directly in Claude Code conversation
- Not automatically saved to files
- Can manually copy results to save

### Q: Can I analyze private codebases?

**A**: Yes! All analysis runs locally, code is not uploaded.

### Q: How is performance? Will it be slow?

**A**:
- `/atlas.overview`: 10-15 minutes
- `/atlas.pattern`: 0.1-30 seconds
- `/atlas.impact`: 1-2 minutes

Uses information theory principles, scans only <5% of files.

### Q: Does it support Monorepos?

**A**: Yes! Recommended to run commands in each sub-project directory.

Example:
```bash
cd packages/web
/atlas.overview

cd ../api
/atlas.overview
```

---

## Advanced Usage

### Combining Commands

**Scenario**: Onboarding to new project and adding features

```bash
# Step 1: Understand project (10 minutes)
/atlas.overview

# Step 2: Learn existing implementation (0.1 seconds)
/atlas.pattern "api endpoint"
/atlas.pattern "authentication"

# Step 3: Analyze impact (1 minute)
/atlas.impact "src/api/auth.ts"
```

**Total Time**: Complete project mastery within 15 minutes

---

## Troubleshooting

### Issue 1: Patterns not found

**Symptom**: `/atlas.pattern` reports "No patterns found"

**Solution**:
1. Confirm project type is supported (iOS/TypeScript/Android)
2. Check if file structure follows conventions
3. Try more generic pattern name (use "api" instead of "api endpoint")

### Issue 2: Swift Analyzer not executing

**Symptom**: iOS project doesn't show Swift/ObjC interop analysis

**Solution**:
1. Confirm project has `.xcodeproj` or `.xcworkspace`
2. Confirm target file is `.swift`, `.m`, or `.h`
3. Check if `scripts/atlas/analyzers/swift-analyzer.sh` exists

### Issue 3: Execution taking too long

**Symptom**: `/atlas.overview` takes over 20 minutes without completing

**Diagnostic Steps** (run these commands to find the cause):

```bash
# 1. Check actual lines of code (should be <100K)
find . -name "*.swift" -o -name "*.ts" -o -name "*.kt" | \
  grep -v "node_modules\|Pods\|build" | \
  xargs wc -l 2>/dev/null | tail -1

# 2. Check for large binary files (should be excluded)
find . -type f -size +10M | head -10

# 3. Check .gitignore settings
cat .gitignore | grep -E "node_modules|Pods|build|\.app"
```

**Solution**:

| Root Cause | Fix Method | Expected Improvement |
|-----------|------------|---------------------|
| Missing .gitignore | Add `node_modules/`, `Pods/`, `*.app` | 80% speed improvement |
| Project too large (>100K LOC) | Run in subdirectory: `cd src && /atlas.overview` | Time distributed by subdirectories |
| Network latency | Check [Claude API status](https://status.anthropic.com) | Wait or retry later |

**Still slow?** Please [report issue](https://github.com/lis186/SourceAtlas/issues) with diagnostic results

### Issue 4: Command not found

**Symptom**: Running `/atlas.overview` shows "Command not found"

**Diagnostic Steps**:

```bash
# 1. Check if command files exist
ls -la ~/.claude/commands/atlas.*.md

# 2. Check file permissions
ls -l ~/.claude/commands/atlas.*.md

# 3. Check Claude Code version
# In Claude Code, run: /help
```

**Solution**:

| Check Result | Reason | Fix Method |
|-------------|--------|-----------|
| Files don't exist | Not installed or installation failed | Re-run `./install-global.sh` |
| Permission error (---x------) | Symlink points to non-existent location | `./install-global.sh --remove` then reinstall |
| Claude Code version too old | Doesn't support Slash Commands | Update Claude Code to latest version |

### Issue 5: Incorrect output format

**Symptom**: `/atlas.overview` outputs plain text instead of YAML format

**Diagnostic Steps**:

```bash
# Check prompt file content
head -20 ~/.claude/commands/atlas.overview.md
```

**Possible Causes**:

| Symptom | Reason | Fix Method |
|---------|--------|-----------|
| Missing frontmatter (---) | File corrupted | `git restore .claude/commands/` then reinstall |
| Content is old version | Not updated to latest | `cd ~/dev/sourceatlas2 && git pull && ./install-global.sh` |
| YAML syntax error | AI parsing issue | Re-run command (Claude randomness) |

### Issue 6: Pattern search results inaccurate

**Symptom**: `/atlas.pattern "api"` returns irrelevant files

**Common Causes and Solutions**:

| Situation | Reason | Improvement Method |
|-----------|--------|-------------------|
| Finding test files instead of implementation | Pattern too generic | Use more specific keywords: `/atlas.pattern "api endpoint"` |
| Finding old code | Project has legacy code | Check file's last modified date, focus on recent ones |
| Mixed languages | Multi-language project | Specify directory: `cd ios/` then run command |
| Zero results | Keywords don't match project conventions | Try synonyms: `"controller"` → `"view model"` |

**Tips for Improving Search Accuracy**:

1. **From general to specific**: First use `"api"` to see what's there, then refine to `"api endpoint"`
2. **Check Pattern list**: Refer to [Supported Patterns](#supported-patterns-141-total)
3. **Combine with overview**: First use `/atlas.overview` to understand architecture, then search

### Quick Diagnostic Checklist

Run the following commands for a complete health check:

```bash
# === SourceAtlas Health Check ===

echo "1. Check installation..."
ls -la ~/.claude/commands/atlas.*.md

echo -e "\n2. Check scripts..."
ls -la ~/.claude/scripts/atlas/

echo -e "\n3. Check project root..."
pwd

echo -e "\n4. Check Git status..."
git status 2>&1 | head -5

echo -e "\n5. Check code scale..."
find . -name "*.swift" -o -name "*.ts" -o -name "*.kt" 2>/dev/null | \
  grep -v "node_modules\|Pods\|build" | wc -l

echo -e "\n=== Check Complete ==="
```

**Expected Results**:
- ✅ See 7 .md files (init, overview, pattern, impact, history, flow, deps)
- ✅ See scripts/atlas/ directory
- ✅ At project root (has .git/)
- ✅ Code file count < 1000 (TINY/SMALL) or < 5000 (MEDIUM/LARGE)

---

## More Resources

- **Technical Details**: [CLAUDE.md](./CLAUDE.md)
- **Development History**: [dev-notes/HISTORY.md](./dev-notes/HISTORY.md)
- **Feature Proposals**: [proposals/](./proposals/)
- **Report Issues**: [GitHub Issues](https://github.com/lis186/SourceAtlas/issues)

---

**SourceAtlas** - Code analysis assistant for Claude Code
v2.9.0 | Updated: 2025-12-08
