# Changelog

All notable changes to SourceAtlas Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.7.0] - 2025-12-01

### Added
- **`/atlas.flow` command** - Trace code execution and data flow ⭐ Major Feature
  - 11 Analysis Modes: Forward, Reverse, Error Path, Data Flow, State Machine, Feature Toggle, Comparison, Event/Message, Transaction, Permission/Role, Cache Flow
  - Call Graph visualization (ASCII tree format)
  - Boundary Detection: 🌐 [API], 💾 [DB], 📦 [LIB], 🔄 [LOOP], 📡 [MQ], ☁️ [CLOUD]
  - Depth Limit Control: `--depth=N`, `--cross-boundary`, `--only-internal`
  - Recursion and Cycle Detection (direct and indirect)
  - Newbie Mode: auto-enabled for beginners with tooltips and progressive disclosure (7±2 rule)
  - Summary/Detailed output modes
  - Multi-language support: TypeScript/JavaScript, Swift/iOS, Kotlin/Android, Python
  - Natural language queries in Chinese and English
- Updated `/atlas.init` with auto-trigger rules for `/atlas.history` and `/atlas.flow`
- **Total commands now: 6** (init, overview, pattern, impact, history, flow)

### Changed
- Enhanced plugin description to include flow analysis
- Updated README with complete `/atlas.flow` documentation
- Bumped version to 2.7.0 for major feature release

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
