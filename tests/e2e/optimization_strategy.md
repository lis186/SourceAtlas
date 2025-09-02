# Test Suite Optimization Strategy

## 🚨 Critical Performance Issues Identified

### Current Redundancy Metrics:
- **52x** `satlas init` calls → Should be ~5x max
- **57x** `satlas run` calls → Should be ~10x max  
- **23x** fixture copies → Should be ~5x max
- **29** test files running sequentially → Could parallelize

### Estimated Time Waste:
- If each `satlas run` = 2s: **114s wasted**
- If each `satlas init` = 0.5s: **26s wasted**
- If each fixture copy = 0.3s: **7s wasted**
- **Total: ~147s (2.5 minutes) of waste per CI run**

## 🎯 Optimization Strategy

### 1. **Shared Fixture Caching** (40% speedup)
```bash
# Create once, reuse many times
setup_file() {  # BATS 1.5+ feature
    export SHARED_FIXTURE_DIR="$(mktemp -d)"
    copy_fixtures "sourceatlas" "$SHARED_FIXTURE_DIR"
    cd "$SHARED_FIXTURE_DIR"
    satlas init
    satlas run
    export SHARED_INDEX="$SHARED_FIXTURE_DIR/.sourceatlas"
}

teardown_file() {
    rm -rf "$SHARED_FIXTURE_DIR"
}
```

### 2. **Test Parallelization Groups** (60% speedup)

#### Group A: Read-Only Tests (can share index)
- `18_cli_query.bats`
- `19_cli_segment.bats`  
- `20_cli_export_dsl.bats`
- `22_cli_verify.bats`
- Phase 2 symbol tests (read existing index)

#### Group B: Modification Tests (need isolation)
- `17_cli_delta.bats`
- `21_cli_clean.bats`
- Scale tests

#### Group C: Independent Tests (no fixtures needed)
- `10_cli_version.bats`
- `11_cli_init.bats`
- Helper/framework tests

### 3. **Lazy Index Generation** (30% speedup)
```bash
# Only generate index if not exists
ensure_index() {
    if [[ ! -f ".sourceatlas/sourceatlas.index.jsonl" ]]; then
        satlas run
    fi
}
```

### 4. **Minimal Fixture Sets** (20% speedup)
```bash
# Use minimal fixtures for specific tests
copy_minimal_fixtures() {
    case "$1" in
        "timing") 
            # Just 2-3 small files for timing tests
            ;;
        "symbols")
            # Just language-specific files
            ;;
        "performance")
            # Generated files, not copied
            ;;
    esac
}
```

### 5. **Parallel Execution with BATS**
```bash
# Run test groups in parallel
bats --jobs 4 \
    tests/e2e/group_a/*.bats \
    tests/e2e/group_b/*.bats \
    tests/e2e/group_c/*.bats
```

## 📊 Expected Performance Gains

| Optimization | Time Saved | Implementation Effort |
|-------------|------------|----------------------|
| Shared Fixtures | ~60s | Low |
| Parallel Groups | ~90s | Medium |
| Lazy Index | ~40s | Low |
| Minimal Fixtures | ~20s | Medium |
| **Total** | **~210s (3.5 min)** | **2-3 hours** |

## 🚀 Implementation Plan

### Phase 1: Quick Wins (1 hour)
1. Implement shared fixture caching for read-only tests
2. Add lazy index generation helper
3. Group tests by dependency type

### Phase 2: Parallelization (2 hours)
1. Reorganize tests into parallel groups
2. Update CI configuration for parallel execution
3. Add resource locks for shared resources

### Phase 3: Advanced Optimization (1 hour)
1. Create minimal fixture sets
2. Implement test result caching
3. Add performance benchmarking

## 🎪 CI Configuration

```yaml
# .github/workflows/test.yml
test:
  strategy:
    matrix:
      group: [read-only, modification, independent]
  steps:
    - run: bats --jobs 2 tests/e2e/${{ matrix.group }}/*.bats
```

## 📈 Monitoring & Metrics

Track these metrics:
- Total test execution time
- Time per test group
- Cache hit rates
- Resource utilization

## 🔒 Safety Considerations

1. **Test Isolation**: Ensure parallel tests don't interfere
2. **Resource Locks**: Use flock for shared resources
3. **Cleanup**: Ensure proper cleanup even with parallel execution
4. **Determinism**: Tests must produce same results regardless of execution order