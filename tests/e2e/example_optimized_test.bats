#!/usr/bin/env bats
# Example of optimized test using cached fixtures and indexes

load ../helpers_optimized

# Setup once for entire file (BATS 1.5+ feature)
setup_file() {
    # Initialize shared cache for all tests in this file
    init_shared_cache
}

# Cleanup once after all tests
teardown_file() {
    # Only cleanup if this is the last test file
    # In CI, this would be handled by the test runner
    if [[ "${BATS_SUITE_FINAL:-}" == "true" ]]; then
        cleanup_shared_cache
    fi
}

# Example: Read-only test using shared cached index
@test "query uses cached index (read-only)" {
    # Setup with shared cached index (no copying, just linking)
    setup_cached_test "read-only"
    
    # cd to test directory
    cd "$TEST_TEMP_DIR"
    
    # Query already-built index (instant!)
    run satlas query "AppDelegate"
    assert_success
    
    # Cleanup test directory (cache remains)
    cleanup_cached_test
}

# Example: Modification test with copy of cached index
@test "delta updates cached index copy (modify)" {
    # Setup with writable copy of cached index
    setup_cached_test "modify"
    
    cd "$TEST_TEMP_DIR"
    
    # Modify a file
    echo "// Modified" >> swift_example.swift
    
    # Run delta update (only updates changed files)
    run satlas delta
    assert_success
    
    cleanup_cached_test
}

# Example: Performance test with minimal fixtures
@test "timing test with minimal fixtures" {
    # Setup with minimal fixtures (no full index needed)
    setup_cached_test "minimal"
    
    cd "$TEST_TEMP_DIR"
    
    # Benchmark the operation
    benchmark_test "scan-minimal" satlas scan
    assert_success
    
    cleanup_cached_test
}

# Example: Empty directory test (no fixtures needed)
@test "init in empty directory" {
    # Setup with just empty directory
    setup_cached_test "empty"
    
    cd "$TEST_TEMP_DIR"
    
    run satlas init
    assert_success
    
    cleanup_cached_test
}

# Example: Parallel-safe test groups
@test "multiple queries can run in parallel" {
    setup_cached_test "read-only"
    cd "$TEST_TEMP_DIR"
    
    # These can all run simultaneously on the same cached index
    (
        satlas query "class" &
        satlas query "func" &
        satlas query "import" &
        wait
    )
    
    # All should succeed
    [ $? -eq 0 ]
    
    cleanup_cached_test
}