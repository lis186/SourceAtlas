# SourceAtlas Test Coverage Matrix

## Overview

This document maps PRD requirements to test cases, ensuring comprehensive coverage across all features.

## Coverage Areas

### 1. CLI Commands (PRD Section 23)

| Command | Test File | Priority | Status |
|---------|-----------|----------|--------|
| `satlas version` | `10_cli_version.bats` | P0 | Pending |
| `sourceatlas version` | `10_cli_version.bats` | P0 | Pending |
| `satlas init` | `11_cli_init.bats` | P0 | Pending |
| `satlas scan` | `12_cli_scan.bats` | P0 | Pending |
| `satlas symbols` | `13_cli_symbols.bats` | P0 | Pending |
| `satlas stats` | `14_cli_stats.bats` | P1 | Pending |
| `satlas manifest` | `15_cli_manifest.bats` | P1 | Pending |
| `satlas shard` | `16_cli_shard.bats` | P1 | Pending |
| `satlas delta` | `17_cli_delta.bats` | P2 | Pending |
| `satlas query` | `18_cli_query.bats` | P1 | Pending |
| `satlas segment` | `19_cli_segment.bats` | P2 | Pending |
| `satlas export-dsl` | `20_cli_export_dsl.bats` | P2 | Pending |
| `satlas clean` | `21_cli_clean.bats` | P1 | Pending |
| `satlas run` | `22_cli_run.bats` | P0 | Pending |
| `satlas verify` | `23_cli_verify.bats` | P1 | Pending |

### 2. Index Schema (PRD Section 4)

| Field | Test Coverage | Priority | Status |
|-------|---------------|----------|--------|
| Basic fields (repo, path, file_name, ext) | `30_schema_basic.bats` | P0 | Pending |
| Language detection | `31_schema_language.bats` | P0 | Pending |
| Size and LOC | `32_schema_metrics.bats` | P1 | Pending |
| Roles detection | `33_schema_roles.bats` | P1 | Pending |
| Summary generation | `34_schema_summary.bats` | P2 | Pending |
| Imports extraction | `35_schema_imports.bats` | P0 | Pending |
| Symbols extraction | `36_schema_symbols.bats` | P0 | Pending |
| Entry points | `37_schema_entry_points.bats` | P1 | Pending |
| Content hash | `38_schema_hash.bats` | P0 | Pending |

### 3. Language Support (PRD Section 2, 6)

| Language | Symbol Extraction | Test File | Priority | Status |
|----------|------------------|-----------|----------|--------|
| Swift | class, struct, enum, protocol, func | `40_lang_swift.bats` | P0 | Pending |
| Kotlin | class, object, interface, fun | `41_lang_kotlin.bats` | P0 | Pending |
| Objective-C | @interface, @implementation | `42_lang_objc.bats` | P1 | Pending |
| Ruby | class, module, def | `43_lang_ruby.bats` | P2 | Pending |
| Shell | function definitions | `44_lang_shell.bats` | P2 | Pending |
| Python | class, def | `45_lang_python.bats` | P2 | Pending |

### 4. Symbol Table (PRD Section 5)

| Feature | Test File | Priority | Status |
|---------|-----------|----------|--------|
| TSV format | `50_symbols_format.bats` | P0 | Pending |
| Symbol lookup | `51_symbols_lookup.bats` | P0 | Pending |
| Line range accuracy | `52_symbols_lines.bats` | P0 | Pending |

### 5. Sharding (PRD Section 15)

| Feature | Test File | Priority | Status |
|---------|-----------|----------|--------|
| Size limits (2MB) | `60_shard_size.bats` | P1 | Pending |
| Record limits (10k) | `61_shard_records.bats` | P1 | Pending |
| Directory-based sharding | `62_shard_directory.bats` | P1 | Pending |
| Language-based sharding | `63_shard_language.bats` | P2 | Pending |
| Manifest generation | `64_shard_manifest.bats` | P1 | Pending |

### 6. Progressive Retrieval (PRD Section 17)

| Feature | Test File | Priority | Status |
|---------|-----------|----------|--------|
| K shards limit | `70_retrieval_shards.bats` | P2 | Pending |
| N files limit | `71_retrieval_files.bats` | P2 | Pending |
| X lines limit | `72_retrieval_lines.bats` | P2 | Pending |
| Segment padding | `73_retrieval_padding.bats` | P2 | Pending |

### 7. Security & Privacy (PRD Section 8)

| Feature | Test File | Priority | Status |
|---------|-----------|----------|--------|
| Exclude patterns | `80_security_exclude.bats` | P0 | Pending |
| Certificate filtering | `81_security_certs.bats` | P0 | Pending |
| Private key filtering | `82_security_keys.bats` | P0 | Pending |
| Build directory exclusion | `83_security_build.bats` | P0 | Pending |

### 8. Performance (PRD Section 7, 22)

| Metric | Target | Test File | Priority | Status |
|--------|--------|-----------|----------|--------|
| Index generation time | ≤10 min (medium project) | `90_perf_generation.bats` | P1 | Pending |
| Query response time | Median <3s | `91_perf_query.bats` | P2 | Pending |
| Memory usage | <1GB | `92_perf_memory.bats` | P2 | Pending |

### 9. Incremental Updates (PRD Section 30)

| Feature | Test File | Priority | Status |
|---------|-----------|----------|--------|
| Change detection | `95_delta_detection.bats` | P2 | Pending |
| Hash comparison | `96_delta_hash.bats` | P2 | Pending |
| Partial rebuild | `97_delta_partial.bats` | P2 | Pending |

### 10. UAT Criteria (PRD Section 9, 24)

| Criteria | Target | Test File | Priority | Status |
|----------|--------|-----------|----------|--------|
| File coverage | ≥95% | `100_uat_coverage.bats` | P0 | Pending |
| Hit@5 accuracy | ≥80% | `101_uat_accuracy.bats` | P0 | Pending |
| False positive rate | <20% | `102_uat_false_positive.bats` | P1 | Pending |

### 11. Phase 9 Performance Optimizations (Task.md Phase 9)

| Optimization | Performance Target | Test File | Priority | Status |
|--------------|-------------------|-----------|----------|--------|
| AWK batch processing | 5-20x improvement | `110_phase9_awk_batch.bats` | P0 | Pending |
| Parallel file processing | 10-50x improvement | `111_phase9_parallel.bats` | P0 | Pending |
| Memory-optimized JSON | No OOM on large files | `112_phase9_memory_json.bats` | P1 | Pending |
| Cache optimization | 100x+ for repeated scans | `113_phase9_cache.bats` | P0 | Pending |
| I/O batch optimization | 50%+ I/O reduction | `114_phase9_io_batch.bats` | P1 | Pending |
| Benchmark system | Regression detection | `115_phase9_benchmarks.bats` | P1 | Pending |
| Observability integration | Events preserved | `116_phase9_observability.bats` | P0 | Pending |

### 12. Phase 9 Integration Testing

| Feature | Test Coverage | Priority | Status |
|---------|---------------|----------|--------|
| Phase 8 + Phase 9 compatibility | `120_phase9_integration.bats` | P0 | Pending |
| Optimization level switching | `121_phase9_levels.bats` | P1 | Pending |
| Fallback mechanisms | `122_phase9_fallback.bats` | P0 | Pending |
| Environment variables | `123_phase9_config.bats` | P1 | Pending |
| Cache corruption recovery | `124_phase9_cache_recovery.bats` | P1 | Pending |
| Parallel processing safety | `125_phase9_parallel_safety.bats` | P0 | Pending |

### 13. Phase 9 Performance Regression Testing

| Metric | Baseline | Regression Threshold | Test File | Priority | Status |
|--------|----------|---------------------|-----------|----------|--------|
| File processing speed | Baseline run | >20% slower | `130_phase9_regression_speed.bats` | P0 | Pending |
| Memory usage | Phase 8 baseline | >50% increase | `131_phase9_regression_memory.bats` | P1 | Pending |
| Cache hit rate | >90% for repeated | <70% hit rate | `132_phase9_regression_cache.bats` | P1 | Pending |
| Parallel efficiency | Linear scaling | <50% efficiency | `133_phase9_regression_parallel.bats` | P1 | Pending |
| I/O operation count | Baseline count | >30% increase | `134_phase9_regression_io.bats` | P1 | Pending |

## Test Execution Priority

### Phase 1 (P0 - Critical)
- CLI basic commands (version, init, scan, run)
- Basic schema fields
- Primary languages (Swift, Kotlin)
- Security exclusions
- File coverage
- **Phase 9 Core Optimizations** (AWK batch, parallel, cache, observability)
- **Phase 9 Integration** (Phase 8 compatibility, fallback mechanisms, parallel safety)
- **Phase 9 Speed Regression** (20% performance threshold)

### Phase 2 (P1 - Important)
- Additional CLI commands
- Sharding and manifest
- Symbol table
- Performance metrics
- UAT accuracy
- **Phase 9 Advanced** (memory optimization, I/O batch, benchmarks)
- **Phase 9 Configuration** (environment variables, optimization levels)
- **Phase 9 Reliability** (cache recovery, memory/parallel regression testing)

### Phase 3 (P2 - Nice to have)
- Advanced features (delta, DSL export)
- Secondary languages
- Progressive retrieval
- Legacy optimization features

## Risk Areas

1. **High Risk**: Symbol extraction accuracy across languages
2. **High Risk**: **Phase 9 Performance Claims** (5-100x improvements unverified)
3. **High Risk**: **Phase 9 Integration Failures** (Phase 8 + Phase 9 compatibility)
4. **Medium Risk**: Performance on large codebases
5. **Medium Risk**: **Phase 9 Cache Corruption** (data loss in incremental mode)
6. **Medium Risk**: **Phase 9 Parallel Race Conditions** (concurrent file access)
7. **Low Risk**: Configuration and stats generation

## Test Data Requirements

- Small fixture set (current): ~10 files per language
- Medium fixture set: ~100 files per language  
- Large fixture set: ~1000 files (performance testing)
- **Phase 9 Performance Test Sets**:
  - Tiny set: ~5 files (AWK batch processing verification)
  - Parallel set: ~500 files (parallel processing testing)
  - Cache set: Repeated runs on same ~100 files (cache effectiveness)
  - Large I/O set: ~2000 files (I/O optimization testing)
  - Memory stress set: Files with 10k+ LOC (memory optimization)

## Validation Gates (PRD Section 24)

| Gate | Condition | Action |
|------|-----------|--------|
| Gate A | Coverage <95% | Fix scan rules |
| Gate B | Hit@5 <80% | Enhance roles/summary |
| Gate C | Median >3s or Token >8k | Enable sharding/DSL |
| Gate D | Poor semantic recall | Enable embeddings |
| Gate E | False positive >20% | Adjust ranking |

### Phase 9 Validation Gates

| Gate | Condition | Action |
|------|-----------|--------|
| Gate F | **Performance regression >20%** | Disable Phase 9, investigate bottlenecks |
| Gate G | **Cache corruption detected** | Reset cache, fallback to Phase 8 |
| Gate H | **Parallel processing failure** | Reduce worker count or disable parallelization |
| Gate I | **Memory usage >2x baseline** | Enable memory optimization limits |
| Gate J | **Observability events missing** | Fix event emission, ensure Phase 8 compatibility |

## Notes

- All test files use bats-core framework
- Helper functions in `tests/helpers.bash`
- Fixtures in `tests/fixtures/sourceatlas/`
- Tests should be idempotent and isolated
- Use temporary directories for all write operations

## Phase 9 Test Coverage Summary

**Total Phase 9 Tests Required: 18**
- 7 Core optimization tests (110-116)
- 6 Integration tests (120-125)  
- 5 Regression tests (130-134)

**Tests Created: 6 Critical Tests (33% Coverage)**
- ✅ `110_phase9_awk_batch.bats` - AWK batch processing (6 tests)
- ✅ `111_phase9_parallel.bats` - Parallel processing (9 tests) 
- ✅ `113_phase9_cache.bats` - Cache optimization (9 tests)
- ✅ `116_phase9_observability.bats` - Observability integration (12 tests)
- ✅ `120_phase9_integration.bats` - Phase 8+9 compatibility (11 tests)
- ✅ `130_phase9_regression_speed.bats` - Performance regression (6 tests)

**Coverage Status:** **PARTIAL** - Critical P0 optimizations covered
**Risk Level:** 🟡 **MEDIUM** - Core functionality testable, advanced features still untested

**Remaining P0 Tests Needed:**
- `112_phase9_memory_json.bats` - Memory optimization
- `114_phase9_io_batch.bats` - I/O optimization  
- `115_phase9_benchmarks.bats` - Benchmark system