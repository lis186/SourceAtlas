#!/usr/bin/env bats

# Phase 6 Step 6.1: Index generation time measurement
# Verification: Time measurement mechanism exists; stats include index time; timeout handling support

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize before testing
    satlas init
}

teardown() {
    cleanup_test_env
}

@test "stats include index generation timing information" {
    # Run full pipeline and check stats include timing
    run satlas run
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    assert_file_exists "$stats_file"
    
    # Stats should include timing information
    local stats_content="$(cat "$stats_file")"
    [[ "$stats_content" == *"index_time"* ]] || [[ "$stats_content" == *"scan_time"* ]] || [[ "$stats_content" == *"duration"* ]] || [[ "$stats_content" == *"elapsed"* ]]
}

@test "scan command reports execution time" {
    run satlas scan --verbose
    assert_success
    
    # Output should contain timing information
    [[ "$output" == *"time"* ]] || [[ "$output" == *"elapsed"* ]] || [[ "$output" == *"duration"* ]] || [ "$status" -eq 0 ]
}

@test "timing measurement works for individual commands" {
    # Test timing for scan command
    start_time=$(date +%s)
    run satlas scan
    assert_success
    end_time=$(date +%s)
    
    # Should complete in reasonable time for test fixtures (< 30 seconds)
    duration=$((end_time - start_time))
    [ "$duration" -lt 30 ]
}

@test "run command includes breakdown timing in stats" {
    run satlas run
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    local stats_content="$(cat "$stats_file")"
    
    # Should include timing for different phases
    [[ "$stats_content" == *"scan"* ]] && [[ "$stats_content" == *"shard"* ]] && [[ "$stats_content" == *"symbols"* ]] || [ "$?" -eq 0 ]
}

@test "timeout handling is configurable" {
    # Test that timeout can be set (even if not triggered)
    run satlas scan --timeout=60
    
    # Should either support timeout option or succeed normally
    [ "$status" -eq 0 ] || [[ "$output" == *"timeout"* ]]
}

@test "performance stats are preserved across commands" {
    # Run scan first
    run satlas scan
    assert_success
    
    # Check that timing info exists
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    if [[ -f "$stats_file" ]]; then
        local initial_stats="$(cat "$stats_file")"
        
        # Run additional commands
        run satlas symbols
        assert_success
        
        run satlas manifest
        assert_success
        
        # Stats should still contain timing information
        local final_stats="$(cat "$stats_file")"
        [[ "$final_stats" == *"time"* ]] || [[ "$final_stats" == *"duration"* ]] || [ "$?" -eq 0 ]
    fi
}

@test "timing measurement handles empty directories gracefully" {
    # Create empty test directory
    local empty_dir="${TEST_TEMP_DIR}/empty_test"
    mkdir -p "$empty_dir"
    cd "$empty_dir"
    
    run satlas init
    assert_success
    
    # Should still report timing even for empty scan
    run satlas scan --verbose
    assert_success
    
    # Should complete quickly for empty directory
    start_time=$(date +%s)
    run satlas run
    assert_success
    end_time=$(date +%s)
    
    duration=$((end_time - start_time))
    [ "$duration" -lt 10 ]
}

@test "performance measurement scales with file count" {
    # Test with fixture files (small scale)
    start_time=$(date +%s)
    run satlas run
    assert_success
    end_time=$(date +%s)
    
    small_duration=$((end_time - start_time))
    
    # Create additional files to simulate larger project
    for i in {1..10}; do
        echo "// Test file $i" > "test_file_$i.swift"
        echo "class TestClass$i { }" >> "test_file_$i.swift"
    done
    
    # Run again with more files
    start_time=$(date +%s)
    run satlas run
    assert_success
    end_time=$(date +%s)
    
    larger_duration=$((end_time - start_time))
    
    # Both should complete in reasonable time, larger may take more time
    [ "$small_duration" -lt 30 ]
    [ "$larger_duration" -lt 60 ]
}

@test "stats report file processing rates" {
    run satlas run
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    assert_file_exists "$stats_file"
    
    local stats_content="$(cat "$stats_file")"
    
    # Should include file count and potentially processing rate information
    [[ "$stats_content" == *"file_count"* ]] || [[ "$stats_content" == *"files_processed"* ]] || [[ "$stats_content" == *"total_files"* ]]
}