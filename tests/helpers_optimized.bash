#!/usr/bin/env bash
# Optimized test helpers for SourceAtlas E2E tests
# Reduces redundant operations and enables parallel execution

# Import base helpers
source "$(dirname "${BASH_SOURCE[0]}")/helpers.bash"

# Global cache directory for shared fixtures
export SATLAS_TEST_CACHE_DIR="${SATLAS_TEST_CACHE_DIR:-/tmp/satlas-test-cache-$$}"
export SATLAS_TEST_CACHE_LOCK="${SATLAS_TEST_CACHE_DIR}.lock"

# Initialize shared cache (call once per test suite)
init_shared_cache() {
    if [[ ! -d "$SATLAS_TEST_CACHE_DIR" ]]; then
        (
            flock -x 200
            if [[ ! -d "$SATLAS_TEST_CACHE_DIR" ]]; then
                mkdir -p "$SATLAS_TEST_CACHE_DIR"
                echo "initialized:$(date +%s)" > "$SATLAS_TEST_CACHE_DIR/.cache_metadata"
            fi
        ) 200>"$SATLAS_TEST_CACHE_LOCK"
    fi
}

# Cleanup shared cache (call in final teardown)
cleanup_shared_cache() {
    if [[ -d "$SATLAS_TEST_CACHE_DIR" ]]; then
        rm -rf "$SATLAS_TEST_CACHE_DIR"
        rm -f "$SATLAS_TEST_CACHE_LOCK"
    fi
}

# Get or create cached fixture set
get_cached_fixtures() {
    local fixture_name="${1:-sourceatlas}"
    local cache_key="${2:-default}"
    local cached_dir="$SATLAS_TEST_CACHE_DIR/fixtures/$cache_key"
    
    if [[ ! -d "$cached_dir" ]]; then
        (
            flock -x 200
            if [[ ! -d "$cached_dir" ]]; then
                mkdir -p "$cached_dir"
                cp -r "${BATS_TEST_DIRNAME}/../fixtures/${fixture_name}"/* "$cached_dir/"
                echo "cached:$(date +%s)" > "$cached_dir/.cache_metadata"
            fi
        ) 200>"$SATLAS_TEST_CACHE_LOCK"
    fi
    
    echo "$cached_dir"
}

# Get or create cached index
get_cached_index() {
    local fixture_dir="${1}"
    local cache_key="${2:-default}"
    local cached_index="$SATLAS_TEST_CACHE_DIR/indexes/$cache_key"
    
    if [[ ! -d "$cached_index/.sourceatlas" ]]; then
        (
            flock -x 200
            if [[ ! -d "$cached_index/.sourceatlas" ]]; then
                mkdir -p "$cached_index"
                cd "$cached_index"
                
                # Copy fixtures to index directory
                cp -r "$fixture_dir"/* "$cached_index/" 2>/dev/null || true
                
                # Generate index once
                satlas init >/dev/null 2>&1
                satlas run >/dev/null 2>&1
                
                echo "indexed:$(date +%s)" > "$cached_index/.cache_metadata"
            fi
        ) 200>"$SATLAS_TEST_CACHE_LOCK"
    fi
    
    echo "$cached_index"
}

# Setup test with cached fixtures and index
setup_cached_test() {
    local test_type="${1:-read-only}"
    
    init_shared_cache
    export TEST_TEMP_DIR="$(mktemp -d -t sourceatlas-test-XXXXXX)"
    
    case "$test_type" in
        "read-only")
            # Use shared cached index for read-only tests
            local cached_fixtures=$(get_cached_fixtures "sourceatlas" "shared")
            local cached_index=$(get_cached_index "$cached_fixtures" "shared")
            
            # Link to cached index (read-only)
            ln -s "$cached_index/.sourceatlas" "$TEST_TEMP_DIR/.sourceatlas"
            ln -s "$cached_index"/*.* "$TEST_TEMP_DIR/" 2>/dev/null || true
            ;;
            
        "modify")
            # Copy cached index for modification tests
            local cached_fixtures=$(get_cached_fixtures "sourceatlas" "shared")
            local cached_index=$(get_cached_index "$cached_fixtures" "shared")
            
            # Copy cached index (writable)
            cp -r "$cached_index"/* "$TEST_TEMP_DIR/"
            ;;
            
        "minimal")
            # Use minimal fixtures for timing/performance tests
            local cached_fixtures=$(get_cached_fixtures "sourceatlas" "minimal")
            cp -r "$cached_fixtures"/* "$TEST_TEMP_DIR/"
            cd "$TEST_TEMP_DIR"
            satlas init >/dev/null 2>&1
            ;;
            
        "empty")
            # Just empty directory
            cd "$TEST_TEMP_DIR"
            ;;
    esac
    
    export SATLAS_ROOT="${TEST_TEMP_DIR}"
    export PATH="${BATS_TEST_DIRNAME}/../../bin:${PATH}"
}

# Cleanup cached test
cleanup_cached_test() {
    if [[ -n "${TEST_TEMP_DIR}" ]] && [[ -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# Ensure index exists (lazy generation)
ensure_index() {
    if [[ ! -f ".sourceatlas/sourceatlas.index.jsonl" ]]; then
        satlas run >/dev/null 2>&1
    fi
}

# Run tests in parallel groups
run_parallel_test_groups() {
    local group_a=()
    local group_b=()
    local group_c=()
    
    # Group A: Read-only tests
    group_a+=(18_cli_query.bats)
    group_a+=(19_cli_segment.bats)
    group_a+=(20_cli_export_dsl.bats)
    group_a+=(22_cli_verify.bats)
    group_a+=(phase2_*.bats)
    
    # Group B: Modification tests
    group_b+=(17_cli_delta.bats)
    group_b+=(21_cli_clean.bats)
    group_b+=(30_phase3_*.bats)
    group_b+=(60_phase6_*.bats)
    
    # Group C: Independent tests
    group_c+=(00_framework.bats)
    group_c+=(01_fixtures.bats)
    group_c+=(10_cli_version.bats)
    group_c+=(11_cli_init.bats)
    
    # Run groups in parallel
    (
        echo "Running Group A (read-only)..."
        bats "${group_a[@]/#/tests/e2e/}"
    ) &
    
    (
        echo "Running Group B (modification)..."
        bats "${group_b[@]/#/tests/e2e/}"
    ) &
    
    (
        echo "Running Group C (independent)..."
        bats "${group_c[@]/#/tests/e2e/}"
    ) &
    
    # Wait for all groups
    wait
}

# Benchmark test execution time
benchmark_test() {
    local test_name="$1"
    local start_time=$(get_timestamp)
    
    # Run the actual test
    "$@"
    local exit_code=$?
    
    local end_time=$(get_timestamp)
    local duration_ms=$(calculate_duration_ms "$start_time" "$end_time")
    
    # Log benchmark data
    echo "BENCHMARK: $test_name completed in ${duration_ms}ms" >> "$SATLAS_TEST_CACHE_DIR/benchmarks.log"
    
    return $exit_code
}

# Create minimal fixture set for specific test types
create_minimal_fixtures() {
    local fixture_type="$1"
    local target_dir="$2"
    
    mkdir -p "$target_dir"
    
    case "$fixture_type" in
        "timing")
            # Just 2 small files for timing tests
            echo "class Test { }" > "$target_dir/test.swift"
            echo "func main() { }" > "$target_dir/main.swift"
            ;;
            
        "symbols")
            # One file per language
            echo "class SwiftTest { }" > "$target_dir/test.swift"
            echo "class KotlinTest { }" > "$target_dir/test.kt"
            echo "@interface ObjCTest @end" > "$target_dir/test.m"
            ;;
            
        "performance")
            # Generate many small files
            for i in {1..20}; do
                echo "class Test$i { }" > "$target_dir/test$i.swift"
            done
            ;;
    esac
}