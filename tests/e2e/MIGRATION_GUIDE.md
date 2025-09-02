# Test Optimization Migration Guide

## 🎯 Goal: Reduce test execution time by 70%+ 

From **~5 minutes** to **~1.5 minutes**

## 📊 Current Issues

| Issue | Current | Target | Impact |
|-------|---------|--------|---------|
| `satlas init` calls | 52x | 5x | -47 calls |
| `satlas run` calls | 57x | 10x | -47 calls |
| Fixture copies | 23x | 5x | -18 copies |
| Serial execution | 100% | 25% | 4x speedup |

## 🔄 Migration Steps

### Step 1: Update Test Files to Use Optimized Helpers

#### Before (Slow):
```bash
load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"  # Copies every time!
    cd "${TEST_TEMP_DIR}"
    satlas init  # Initializes every time!
    satlas run   # Rebuilds index every time!
}
```

#### After (Fast):
```bash
load ../helpers_optimized

setup() {
    # Automatically uses cached index!
    setup_cached_test "read-only"  # or "modify" / "minimal" / "empty"
    cd "$TEST_TEMP_DIR"
}

teardown() {
    cleanup_cached_test
}
```

### Step 2: Categorize Tests

#### Category A: Read-Only Tests (60% of tests)
Use shared cached index - **10x faster**
```bash
setup() {
    setup_cached_test "read-only"
}
```

Files to migrate:
- `18_cli_query.bats`
- `19_cli_segment.bats`
- `20_cli_export_dsl.bats`
- `22_cli_verify.bats`
- All Phase 2 symbol tests

#### Category B: Modification Tests (30% of tests)
Use copy of cached index - **5x faster**
```bash
setup() {
    setup_cached_test "modify"
}
```

Files to migrate:
- `17_cli_delta.bats`
- `21_cli_clean.bats`
- Phase 3 shard tests
- Phase 5 exclude tests

#### Category C: Minimal Tests (10% of tests)
Use minimal fixtures - **3x faster**
```bash
setup() {
    setup_cached_test "minimal"  # or "empty"
}
```

Files to migrate:
- `10_cli_version.bats`
- `11_cli_init.bats`
- Performance timing tests

### Step 3: Enable Parallel Execution

#### Update CI Configuration:
```yaml
# .github/workflows/test.yml
jobs:
  test:
    strategy:
      matrix:
        test-group: 
          - "read-only"
          - "modification"
          - "independent"
    steps:
      - name: Run tests
        run: |
          if [[ "${{ matrix.test-group }}" == "read-only" ]]; then
            bats --jobs 4 tests/e2e/{18,19,20,22}_*.bats tests/e2e/phase2_*.bats
          elif [[ "${{ matrix.test-group }}" == "modification" ]]; then
            bats --jobs 2 tests/e2e/{17,21}_*.bats tests/e2e/{30,31}_*.bats
          else
            bats --jobs 4 tests/e2e/{00,01,10,11}_*.bats
          fi
```

### Step 4: Add Benchmarking

Wrap critical operations with benchmarking:
```bash
@test "performance critical operation" {
    setup_cached_test "read-only"
    
    # Benchmark the operation
    benchmark_test "query-complex" satlas query "complex pattern"
    assert_success
    
    cleanup_cached_test
}
```

## 🚀 Quick Migration Script

```bash
#!/bin/bash
# migrate_tests.sh - Automated migration helper

migrate_test_file() {
    local file="$1"
    local category="$2"
    
    # Backup original
    cp "$file" "$file.backup"
    
    # Update load statement
    sed -i 's/load ..\/helpers$/load ..\/helpers_optimized/' "$file"
    
    # Update setup function
    case "$category" in
        "read-only")
            sed -i '/setup() {/,/^}/ {
                s/setup_test_env/setup_cached_test "read-only"/
                s/copy_fixtures.*//
                s/satlas init.*//
                s/satlas run.*//
            }' "$file"
            ;;
        "modify")
            sed -i '/setup() {/,/^}/ {
                s/setup_test_env/setup_cached_test "modify"/
                s/copy_fixtures.*//
                s/satlas init.*//
                s/satlas run.*//
            }' "$file"
            ;;
    esac
    
    # Update teardown
    sed -i 's/cleanup_test_env/cleanup_cached_test/' "$file"
}

# Migrate read-only tests
for file in tests/e2e/{18,19,20,22}_*.bats; do
    migrate_test_file "$file" "read-only"
done

# Migrate modification tests
for file in tests/e2e/{17,21}_*.bats; do
    migrate_test_file "$file" "modify"
done
```

## 📈 Expected Results

### Before Migration:
```
Total test time: 5 minutes
Init operations: 52
Run operations: 57
Disk I/O: High
CPU usage: Single core
```

### After Migration:
```
Total test time: 1.5 minutes (70% reduction!)
Init operations: 5 (90% reduction!)
Run operations: 10 (82% reduction!)
Disk I/O: Minimal
CPU usage: Multi-core (4x parallelism)
```

## ⚠️ Important Notes

1. **BATS Version**: Parallel execution requires BATS 1.5+
2. **File Locking**: Uses `flock` for cache safety (Linux/macOS)
3. **Cleanup**: Shared cache cleaned after all tests complete
4. **Debugging**: Set `SATLAS_TEST_DEBUG=1` for cache diagnostics

## 🔍 Verification

After migration, verify:
```bash
# Run optimized tests
time bats tests/e2e/example_optimized_test.bats

# Check benchmark logs
cat /tmp/satlas-test-cache-*/benchmarks.log

# Compare with original
time bats tests/e2e/original_test.bats.backup
```

## 🎉 Success Metrics

- [ ] Test execution time < 2 minutes
- [ ] Cache hit rate > 90%
- [ ] Zero test flakiness
- [ ] CI costs reduced by 50%+