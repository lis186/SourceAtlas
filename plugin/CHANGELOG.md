# Changelog

All notable changes to SourceAtlas Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.13.0] - 2026-01-14

### Changed
- **Progressive Disclosure Architecture** - All 5 core commands refactored to follow Claude Code official best practices ⭐ Major Improvement
  - SKILL.md files reduced by 57% (3,440 → 1,496 lines)
  - Initial load tokens reduced by 70% (~37,500 → ~11,343 tokens)
  - Each command now has 4 support files (workflow.md, output-template.md, verification-guide.md, reference.md)
  - Claude loads detailed documentation on-demand instead of upfront
- **Improved Maintainability** - Shared concepts (cache, verification, handoffs) now centralized in reference.md
- **Better Discoverability** - Clear navigation with markdown links between SKILL.md and support files

### Technical
- Commands refactored: impact, deps, history, pattern, overview
- File structure: SKILL.md (~200-350 lines) + 4 support files (~150-600 lines each)
- 100% backward compatible - all functionality preserved
- 100% link integrity and format compliance

### Quality Improvements
- Readability: 2/5 → 5/5 (+3)
- Discoverability: 2/5 → 5/5 (+3)
- Maintainability: 2/5 → 5/5 (+3)
- Learning curve: 3/5 → 4/5 (+1)

### Tested
- All 5 commands verified: 100% functionality preserved
- Link integrity: 20/20 links working (100%)
- Format compliance: 5/5 YAML frontmatter correct (100%)
- User experience: Significantly improved across all metrics

### ⚠️ OpenSkills Users Note
This version uses Progressive Disclosure Architecture - SKILL.md files are now more concise with detailed steps in separate files (workflow.md, output-template.md, etc.).

**If you're using OpenSkills (Cursor, Gemini CLI, Aider, Windsurf):**
- Core functionality should work normally (SKILL.md still contains all execution logic)
- If you encounter any issues with detailed steps or error handling, please report at: https://github.com/lis186/SourceAtlas/issues
- We're monitoring feedback to ensure the best experience across all platforms

## [2.12.0] - 2026-01-10

### Added
- **OpenSkills Cross-Platform Support** - SourceAtlas now works with Cursor, Gemini CLI, Aider, Windsurf ⭐ Major Feature
  - Commands converted to `{name}/SKILL.md` directory format
  - Compatible with [OpenSkills](https://github.com/numman-ali/openskills) universal skills loader
  - Install via: `openskills install lis186/SourceAtlas`
- **Detailed Cursor Usage Guide** - Step-by-step instructions for Cursor users in README

### Changed
- **Command Structure** - All 8 commands now use directory format for OpenSkills compatibility
  - `overview.md` → `overview/SKILL.md`
  - `pattern.md` → `pattern/SKILL.md`
  - (and 6 more commands)
- **SKILL.md Format** - Added `name:` field to frontmatter for OpenSkills discovery
- **README.md** - Expanded Method 2 with Cursor, Gemini CLI, Aider examples

### Technical
- Single source of truth: One SKILL.md serves both Claude Code and OpenSkills
- Extra Claude Code fields (`model`, `allowed-tools`, `argument-hint`) are ignored by OpenSkills
- No breaking changes for existing Claude Code users

### Tested
- Claude Code: All 8 commands verified working
- OpenSkills: install, list, read, sync all passed
- AGENTS.md generation: 8 skills correctly listed

## [2.11.0] - 2026-01-02

### Added
- **atlas.flow Tiered Architecture** - On-demand loading reduces context by 91% ⭐ Major Feature
  - Tier 1: 5 built-in modes (Standard, Reverse, Error, Data Flow, Event)
  - Tier 2-3: 9 external modes loaded only when needed
  - 14 total analysis modes (was 5)
- **3 New Analysis Modes**:
  - Mode 12: Taint Analysis (security data flow)
  - Mode 13: Dead Code Detection
  - Mode 14: Concurrency Flow Analysis
- **Permission Flow (Mode 10)** - RBAC/PBAC analysis for access control systems

### Changed
- **Context Optimization** - CLAUDE.md reduced from 12.9k → 839 tokens (93% reduction)
- **atlas.flow.md** - Reduced from 2,708 → 239 lines with tiered dispatch
- **External Mode Files** - 9 files in `scripts/atlas/flow-modes/` for on-demand loading

### Fixed
- **Dispatch Logic** - Imperative table format ensures Claude executes rather than outputs

### Tested
- 15/15 test cases passed (100%)
- Test projects: TTCA-iOS (Swift), cal.com (TypeScript), Express.js (JavaScript)

## [2.10.1] - 2025-12-23

### Added
- **Official Plugin Marketplace** - Now installable via Claude Code plugin system ⭐
  ```bash
  /plugin marketplace add lis186/SourceAtlas
  /plugin install sourceatlas@lis186-SourceAtlas
  ```
- **`.claude-plugin/marketplace.json`** - Marketplace manifest for plugin distribution

### Fixed
- **`plugin.json` repository format** - Changed from object to string per Claude Code spec

### Changed
- **Simplified Command Names** - Plugin commands now use `/sourceatlas:XXX` format ⭐
  - `/sourceatlas:overview` (was `/sourceatlas:atlas.overview`)
  - `/sourceatlas:pattern` (was `/sourceatlas:atlas.pattern`)
  - All 8 commands follow this simplified naming
- Updated all documentation with official plugin installation method
- Removed references to deprecated `install-global.sh`

## [2.10.0] - 2025-12-22

### Added
- **Agent Skills** - 6 model-invoked skills for automatic analysis triggering ⭐ Major Feature
  - `codebase-overview`: Triggers `/atlas.overview` for architecture questions
  - `pattern-finder`: Triggers `/atlas.pattern` for implementation examples
  - `impact-analyzer`: Triggers `/atlas.impact` for change impact questions
  - `code-flow-tracer`: Triggers `/atlas.flow` for execution flow questions
  - `history-analyzer`: Triggers `/atlas.history` for code ownership questions
  - `dependency-analyzer`: Triggers `/atlas.deps` for upgrade planning
  - No commands to memorize — Claude automatically chooses the right analysis

### Removed
- **`/atlas.init` command** - Replaced by Agent Skills (auto-trigger without modifying project files)
- **`install-global.sh`** - Replaced by plugin-based installation

### Changed
- **Plugin-first installation** - Use `claude --plugin-dir ./plugin` instead of global script
- **Total commands now: 8** (removed init, kept overview, pattern, impact, history, flow, deps, list, clear)
- Updated README with new installation method and Skills documentation

## [2.9.6] - 2025-12-20

### Added
- **Tuist Project Support** - Detect Swift projects using Tuist build system ⭐
  - Support `Project.swift` and `Tuist/` directory detection
  - Prioritize Swift detection over Ruby (avoid Gemfile misdetection)
- **New Language Syntax Support** ⭐
  - **Swift 6**: `consuming func`, `borrowing func`, access-controlled imports
  - **Python 3.12**: Generic class syntax `class Name[T]:`
  - **Rust 2024**: Async closures `async || {}`

### Fixed
- **Language Detection** - Fixed glob pattern not expanding in `[[ -d ]]` tests
- **Swift ast-grep Patterns** - Fixed `op_definition` and `op_type` patterns
- **Rust op_call** - Added macro support (`println!`, `format!`, etc.)

### Changed
- Updated 11 files with Tuist support and pattern fixes
- Comprehensive QA testing: 30 tests, 100% pass rate
- Bumped version to 2.9.6

## [2.9.5] - 2025-12-19

### Added
- **Branded Output Format** - Unified Header/Footer for all 6 analysis commands ⭐
  - **Unified Header**: `🗺️ SourceAtlas: [Command Name]` + separator line + emoji + target + key metric
  - **Command-Specific Emojis**: 🔭 overview, 🧩 pattern, 📜 history, 💥 impact, 🔀 flow, 📦 deps
  - **Unified Footer**: `🗺️ v2.9.5 │ Constitution v1.1`
  - **Design Decisions**: 30-char separator (narrow terminal friendly), `│` delimiter (aesthetics)
  - **Implementation**: ~1.5 hours across 6 command files

### Changed
- Updated all 6 analysis command files with new branded format
- Bumped version to 2.9.5

## [2.9.4] - 2025-12-19

### Added
- **AI Collaboration Detection Enhancement** - Support 12+ AI coding tools ⭐
  - **Tier 1 High-Confidence Tools**: Claude Code, Cursor, Windsurf, GitHub Copilot, Cline/Roo, Aider, Continue.dev, JetBrains AI, AGENTS.md, Sourcegraph Cody, Replit, Ruler
  - **Tier 2 Indirect Indicators**: Comment density >15%, Code consistency >98%, Conventional Commits, Docs-to-code ratio
  - **Level 0-4 Detection**: Refined maturity model definitions
  - **Output Enhancement**: New `tools_detected` array in YAML output
  - **Detection Commands**: Automated config file scanning during analysis

### Changed
- Updated `/atlas.overview` with comprehensive AI tool detection logic
- Bumped version to 2.9.4

## [2.9.3] - 2025-12-18

### Added
- **Progressive Disclosure for `/atlas.pattern`** - Smart output mode based on file count ⭐
  - **Smart Mode (default)**: ≤5 files → full analysis; >5 files → selection interface
  - **`--brief` parameter**: List files only, skip full analysis
  - **`--full` parameter**: Force full analysis for all files
  - **Selection Interface**: Interactive file picker when >5 matches found
  - Reduces token usage for large result sets
  - Improves user experience with progressive information disclosure

### Changed
- Bumped version to 2.9.3

## [2.9.2] - 2025-12-14

### Added
- **ast-grep Integration** - Enhanced code search precision for 4 commands ⭐
  - `/atlas.flow`: Function call tracing, async/await flow detection
  - `/atlas.impact`: Type reference search, dependency analysis
  - `/atlas.deps`: API usage inventory, library detection
  - `/atlas.pattern`: Pattern detection with false positive elimination
  - **Unified Script**: Single entry point (`scripts/atlas/ast-grep-search.sh`)
  - **6 Operations**: `call`, `type`, `pattern`, `usage`, `async`, `boundary`
  - **Multi-language**: Swift, TypeScript/TSX, Kotlin, Python
  - **Graceful Degradation**: `--fallback` option provides grep commands when ast-grep unavailable
  - **False Positive Elimination**: 14-93% reduction depending on pattern type
  - **Grade A (9.5/10)**: QA tested with 61 test cases, 100% pass rate

### Changed
- Synced all 4 command files with latest local implementations
- Bumped version to 2.9.2

## [2.9.0] - 2025-12-12

### Added
- **`/atlas.deps` command** - Dependency analysis for library/framework upgrades ⭐ Major Feature
  - **Phase 0 Rule Confirmation**: Upgrade rules preview with user confirmation
  - **Built-in Rules**: iOS 16→17, React 17→18, Python 3.11→3.12
  - **WebSearch Integration**: Dynamic rule generation from latest migration guides
  - **Dual Modes**: Upgrade analysis vs Pure inventory (automatic detection)
  - **Multi-ecosystem Support**: iOS, Android, Python, React, and more
  - **Output Sections**: required_changes, modernization_opportunities, usage_summary, third_party_dependencies, migration_checklist
  - **Constitution v1.1 Compliant**: Full adherence to analysis principles
  - **Production Ready**: Grade A+ (9.7/10), 100% accuracy (42/42 samples tested)
- Updated `/atlas.init` with auto-trigger rules for `/atlas.deps`
- **Total commands now: 7** (init, overview, pattern, impact, history, flow, deps)

### Changed
- Enhanced plugin description to include dependency analysis
- Updated README with complete `/atlas.deps` documentation
- Bumped version to 2.9.0 for major feature release
- **Model Performance Optimization**: Each command now specifies optimal Claude model
  - `/atlas.init`: Haiku (simple text injection)
  - `/atlas.overview`, `pattern`, `history`, `impact`, `deps`: Sonnet (moderate complexity)
  - `/atlas.flow`: Opus (complex multi-layer flow tracing)
  - Expected benefits: 50%+ faster for Haiku commands, 20-30% faster for Sonnet, 40-70% cost reduction

### Tested
- **4 Scenarios**: iOS 16→17, Android API 35, Kotlin coroutines inventory, Flask upgrade
- **100% Accuracy**: 42/42 samples validated
- **Multi-module Support**: Tested on 30-module Android project
- **Edge Cases**: Missing dependency files, mixed framework imports
- **Performance**: 3-30 minutes depending on project size

## [2.7.0] - 2025-12-01

### Added
- **`/atlas.flow` command** - Trace code execution and data flow ⭐ Major Feature
  - 11 Analysis Modes: Forward, Reverse, Error Path, Data Flow, State Machine, Feature Toggle, Comparison, Event/Message, Transaction, Permission/Role, Cache Flow
  - Call Graph visualization (ASCII tree format)
  - Boundary Detection: 🌐 [API], 💾 [DB], 📦 [LIB], 🔄 [LOOP], 📡 [MQ], ☁️ [CLOUD], 🔐 [AUTH], 💳 [PAY], 📁 [FILE], 📲 [PUSH]
  - Depth Limit Control: `--depth=N`, `--cross-boundary`, `--only-internal`
  - Recursion and Cycle Detection (direct and indirect)
  - Newbie Mode: auto-enabled for beginners with tooltips and progressive disclosure (7±2 rule)
  - Summary/Detailed output modes
  - Multi-language support: TypeScript/JavaScript, Swift/iOS, Kotlin/Android, Python
  - Natural language queries in Chinese and English
  - **Language-Specific Entry Point Detection** (P0-A Enhancement):
    - Swift/iOS: `@main`, `AppDelegate`, `SceneDelegate`, `UIViewController`, `SwiftUI.App`
    - TypeScript/React: `main.tsx`, `App.tsx`, `page.tsx`, `layout.tsx`, API routes
    - Kotlin/Android: `MainActivity`, `Application`, `@Composable`, `Fragment`
    - Python: `main.py`, `app.py`, `manage.py`, `wsgi.py`, FastAPI/Flask routes
  - **Enhanced Boundary Detection** with confidence scoring
- Updated `/atlas.init` with auto-trigger rules for `/atlas.history` and `/atlas.flow`
- **Total commands now: 6** (init, overview, pattern, impact, history, flow)

### Changed
- Enhanced plugin description to include flow analysis
- Updated README with complete `/atlas.flow` documentation
- Bumped version to 2.7.0 for major feature release
- Improved entry point detection accuracy across 4 language ecosystems

## [2.5.4] - 2025-11-30

### Added
- **TypeScript/React/Vue Patterns Support** - 50 patterns (25 Tier 1 + 25 Tier 2) for `/atlas.pattern`
  - React Tier 1 (18): component, hook, context, hoc, error boundary, suspense, portal, lazy, ref, zustand, tanstack query, redux, framer motion, form hook, jest test, storybook, i18n, theme
  - Vue Tier 1 (7): sfc, composable, pinia, directive, plugin, provide inject, nuxt
  - React Tier 2 (14): middleware, server component, client component, route, loader, action, api route, server action, layout, page, recoil, jotai, swr, msw mock
  - Vue Tier 2 (11): router guard, transition, teleport, slot component, watcher, lifecycle, emit, prop, ref template, slot, test util
  - Tested on 7 projects: Excalidraw, Mantine, Shadcn UI, Bulletproof React, Element Plus, VueUse, Naive UI
- **Total patterns now: 141** (iOS 34, TypeScript/React/Vue 50, Android/Kotlin 31, Python 26)

### Fixed
- Vue directive pattern was too broad (`v*.ts` matched vars.ts, version.ts) - changed to `*Directive.ts v-*.ts`
- Removed path-based patterns that don't work with `find -name` (e.g., `composables/*.ts`)

## [2.5.3] - 2025-11-30

### Added
- **Python Patterns Support** - 26 patterns (12 Tier 1 + 14 Tier 2) for `/atlas.pattern`
  - Tier 1: model, view, serializer, service, repository, api/router, form, task, test, admin, middleware, config
  - Tier 2: migration, command, util, exception, validator, factory, fixture, signal, manager, mixin, decorator, client, pipeline, spider
  - Framework support: Django, FastAPI, Flask, Celery, Scrapy, Pydantic, SQLAlchemy, Starlette
  - Tested on 10 Python projects (60 ~ 2884 files each)
- `/atlas.init` command - Initialize SourceAtlas in any project by injecting auto-trigger rules into CLAUDE.md
- `/atlas.impact` command - Analyze change impact using static dependency analysis
  - API impact analysis (backend → frontend call chain)
  - Model impact analysis (database layer → business logic → controllers)
  - Component impact analysis (general dependency search)
  - Risk level assessment (🔴 HIGH / 🟡 MEDIUM / 🟢 LOW)
  - Migration checklist generation
  - Test coverage gap detection
  - Swift/Objective-C interop risk analysis for iOS projects

### Changed
- Updated `/atlas.overview` with global script fallback support
- Updated `/atlas.pattern` with improved workflow and global script fallback
- Enhanced plugin description to reflect all 4 commands
- Updated README with complete documentation for all commands
- **Project detection order**: Python now checked before TypeScript (Python projects often have package.json for frontend assets)

### Fixed
- Synced all commands with latest local implementations
- Fixed routing pattern for Starlette/FastAPI (added `routing.py` support)

## [2.5.1] - 2025-11-20

### Added
- Initial plugin release
- `/atlas.pattern` command - Learn design patterns from existing codebase
- Self-contained architecture (zero dependencies)
- Support for multiple languages (JavaScript, TypeScript, Python, Ruby, PHP, Go, Rust)
- Comprehensive pattern detection for:
  - API endpoints
  - Background jobs
  - File uploads
  - Authentication/Authorization
  - Database queries
  - Validation
  - Error handling
  - Testing patterns

### Features
- High-entropy file prioritization (scan <5% of files)
- Pattern recognition and extraction
- Actionable implementation guidance
- Test pattern analysis
- Project-aware recommendations

### Documentation
- Complete README with installation instructions
- Usage examples
- Development guide
- MIT License

## [Unreleased]

### Planned
- `/atlas` - Complete three-stage codebase analysis (Stage 0 + 1 + 2)
- `/atlas.explain` - Deep dive file explanation
- Usage examples document
- Video tutorials
