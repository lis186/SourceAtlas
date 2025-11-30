# Changelog

All notable changes to SourceAtlas Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
