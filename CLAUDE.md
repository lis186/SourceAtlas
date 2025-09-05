# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SourceAtlas is a CLI tool for creating lightweight code indexes that help AI agents quickly locate code in large codebases. It generates JSONL indexes with file metadata, symbols, imports, and roles to enable efficient code navigation without requiring full AST parsing.

## Commands

### Building and Running
- `satlas` or `sourceatlas` - Main CLI command (satlas is the short alias)
- Test framework: bats-core for E2E/CLI testing
- No external build system required - POSIX shell scripts

### Testing
- Run tests: `bats tests/e2e/`
- Test fixtures located in: `tests/fixtures/sourceatlas/`
- Coverage matrix: `tests/coverage-matrix.md`

## Architecture

### Core Components
- **Index Format**: JSONL files with one record per source file
- **Symbol Table**: TSV format for reverse symbol lookups
- **Manifest**: JSON file tracking shards and versions
- **Output Directory**: `.sourceatlas/` in target codebase

### Key Design Decisions
- Language-agnostic design with regex-based symbol extraction
- Zero/near-zero dependencies using POSIX tools (find, grep, sed, awk)
- Universal Ctags + ripgrep for symbol extraction when available
- Progressive retrieval with limits (K=3 shards, N=20 files, X=400 lines)
- Sharding for large codebases (≤2MB compressed, ≤10k records per shard)

### Supported Languages
Primary: Swift, Kotlin, Objective-C
Secondary: Ruby, Shell, Python
Config files: JSON, YAML, Gradle, plist

### CLI Commands
- `init` - Generate default config
- `run` - Full pipeline (scan→index→shard→symbols→stats→manifest)
- `scan` - Generate main index
- `shard` - Split index by directory/language
- `symbols` - Generate reverse symbol table
- `stats` - Output statistics
- `manifest` - Create/update manifest
- `delta` - Incremental updates
- `query` - Search by symbol/role/path
- `segment` - Extract code segments
- `export-dsl` - Convert to low-token DSL format
- `verify` - Check consistency
- `clean` - Remove outputs

### Debugging and Observability Commands
- `monitor` - Real-time processing status display
- `events` - Query event stream by trace-id or time range
- `snapshot` - Create/restore/list processing snapshots
- `profile` - Performance bottleneck analysis
- `health` - System health check and diagnostics
- `debug` - Interactive step-by-step debugging mode

## Development Guidelines

### Development Philosophy

#### Core Beliefs

- **Incremental progress over big bangs**: Small changes that compile and pass tests
- **Learning from existing code**: Study and plan before implementing
- **Pragmatic over dogmatic**: Adapt to project reality
- **Clear intent over clever code**: Be boring and obvious

#### Simplicity Means

- Single responsibility per function/class
- Avoid premature abstractions
- No clever tricks - choose the boring solution
- If you need to explain it, it's too complex

### Core Development Principles

#### Speed & Delivery

- **Deploy Fast First**: Remove time constraints, deploy simple features first, iterate quickly
- **Small Batch Development**: Each step must be small and verifiable, avoid large integrations
- **Incremental Value Delivery**: Start with MVP, enhance gradually, each phase operates independently
- **Pragmatism Over Perfection**: "Working" is more important than "perfect", apply 80/20 rule

#### Risk Management

- **Critical Risk First**: Validate most critical parts earliest, confirm technical feasibility first
- **Fail Fast Principle**: Discover non-viable approaches quickly, set time boxes, failure is learning
- **Minimize Assumptions**: Don't assume technology will work, validate every assumption
- **Reversible Design**: Every decision must be rollback-able, keep old versions

#### Validation & Learning

- **Continuous Validation**: Test in actual production environment, not just locally
- **Clear Validation Methods**: Success criteria must be quantifiable, have backup plans
- **Continuous Learning**: Record lessons after each step, document difficult experiences
- **Problems Before Solutions**: Understand "why" before rushing to code

#### Technical Management

- **Observability First**: Add logging from day one, clear error messages
- **Minimize Dependencies**: Use standard library when possible, every dependency is risk
- **Complexity Budget**: Simple systems are easier to maintain
- **Implementation Consistency**: Use same approaches for same problems
- **Hybrid Solutions**: Combine local processing with remote fallbacks
- **Dynamic Configuration**: Context-aware decisions over fixed thresholds
- **Graceful Degradation**: Design to work when dependencies fail
- **Production-Like Testing**: Real usage patterns over engineered test cases
- **Composition over inheritance**: Use dependency injection
- **Interfaces over singletons**: Enable testing and flexibility
- **Singletons via DI when justified**: If a singleton is necessary, create and manage it via the DI/provider layer and expose only through interfaces
- **Explicit over implicit**: Clear data flow and dependencies

### Observability and Debugging

- **Event-Driven Architecture**: All operations emit structured events for traceability
- **State Machine Design**: Use explicit state transitions with recovery capabilities  
- **Circuit Breaker Pattern**: Prevent cascade failures with automatic recovery
- **Time Travel Debugging**: Complete snapshots and state restoration
- **Distributed Tracing**: OpenTelemetry-compatible span tracking across operations
- **Data Lineage Tracking**: Complete audit trail of data transformations
- **Predictive Monitoring**: Anomaly detection based on historical performance
- **Self-Healing Systems**: Automatic retry, fallback, and degradation mechanisms

### Testing Strategy
- Test-first development (TDD)
- E2E tests for all CLI commands
- Language-specific symbol extraction tests
- Performance benchmarks for indexing time

### File Organization
When developing SourceAtlas:
```text
bin/         - CLI executables (satlas, sourceatlas)
lib/         - Core libraries and parsers
configs/     - Language rules and settings
tests/       - Test code and fixtures
docs/        - Documentation
```

### Output Constraints
- Only write to `.sourceatlas/` in target codebase
- Never modify source files
- Exclude sensitive files (certificates, keys, provisions)

### Performance Targets
- Index generation: ≤10 min for medium projects on 4C/8G
- Coverage: ≥95% of readable files indexed
- Query accuracy: Hit@5 ≥80% for common queries

## Current Status

The project has completed core development with PRD and task planning complete. Implementation follows a phased approach:
- Phase 0: Test framework setup ✅ COMPLETED
- Phase 1: CLI contract definition ✅ COMPLETED
- Phase 2: Language symbol extraction ✅ COMPLETED
- Phase 3: Sharding and manifest ✅ COMPLETED
- Phase 4: Progressive retrieval ✅ COMPLETED
- Phase 5: Security filtering ✅ COMPLETED
- Phase 6: Performance validation ✅ COMPLETED
- Phase 7: UAT and metrics ✅ COMPLETED
- Phase 8: Observability and tracing system ✅ COMPLETED
- Phase 9: Extreme performance optimization 🚧 IN PROGRESS

## Key Documentation

- **`prd.md`**: Complete Product Requirements Document with detailed specifications, schemas, and acceptance criteria
- **`task.md`**: Task breakdown, validation plans, and current implementation progress