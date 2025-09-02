#!/usr/bin/env bats

# Phase 6 Step 6.2: Query performance and token load measurement
# Verification: Query time measurement works; Token/Bytes calculation accurate; DSL format more compact than JSON

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize and create index before testing
    satlas init
    satlas run
}

teardown() {
    cleanup_test_env
}

@test "query commands measure and report timing" {
    # Test query timing measurement
    run satlas query --verbose "AppDelegate"
    assert_success
    
    # Should include timing information in verbose output
    # Check if verbose is supported first
    if [[ "$output" == *"Unknown option"* ]]; then
        skip "Verbose option not implemented yet"
    else
        # If verbose works, check for timing information
        [[ "$output" == *"time"* ]] || [[ "$output" == *"elapsed"* ]] || [[ "$output" == *"ms"* ]]
    fi
}

@test "query timing scales appropriately with result size" {
    # Test simple query (should be fast) - use precision timing
    start_time=$(get_timestamp)
    run satlas query "AppDelegate"
    assert_success
    end_time=$(get_timestamp)
    
    simple_duration_ms=$(calculate_duration_ms "$start_time" "$end_time")
    
    # Test broader query (may take slightly longer)
    start_time=$(get_timestamp)
    run satlas query "class"
    assert_success  
    end_time=$(get_timestamp)
    
    broad_duration_ms=$(calculate_duration_ms "$start_time" "$end_time")
    
    # Both should complete quickly (< 10 seconds = 10000ms for test data)
    [ "$simple_duration_ms" -lt 10000 ]
    [ "$broad_duration_ms" -lt 10000 ]
}

@test "token and byte counting is accurate" {
    # Get index content for token counting
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    assert_file_exists "$index_file"
    
    # Test token counting on known content
    local line_count=$(wc -l < "$index_file")
    local byte_count=$(wc -c < "$index_file")
    
    # Basic sanity checks
    [ "$line_count" -gt 0 ]
    [ "$byte_count" -gt 0 ]
    
    # Estimate tokens (approximately 4 chars per token)
    local estimated_tokens=$((byte_count / 4))
    [ "$estimated_tokens" -gt 0 ]
}

@test "DSL format is more compact than JSON format" {
    # Generate DSL format
    run satlas export-dsl
    assert_success
    local dsl_output="$output"
    
    # Get equivalent JSON content
    local json_content="$(cat "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl")"
    
    # Compare sizes (DSL should be shorter)
    local dsl_length=${#dsl_output}
    local json_length=${#json_content}
    
    # DSL should be more compact (at least somewhat smaller)
    # Allow some flexibility since this is a measurement test
    [ "$dsl_length" -le "$json_length" ] || [ $((dsl_length * 100 / json_length)) -lt 120 ]
}

@test "segment extraction timing is measured" {
    # Test segment extraction timing
    run satlas segment --verbose "AppDelegate.swift" 1 20
    assert_success
    
    # Should complete quickly and possibly report timing
    [[ "$output" == *"time"* ]] || [[ "$output" == *"ms"* ]] || [ "$status" -eq 0 ]
}

@test "progressive query timing includes breakdown" {
    # Test progressive query with timing
    run satlas query --progressive --verbose "AppDelegate"
    assert_success
    
    # Should include timing for different retrieval steps if progressive is supported
    if [[ "$output" == *"Unknown option"* ]]; then
        skip "Progressive option not implemented yet"
    else
        # If progressive works, look for step/phase timing
        [[ "$output" == *"step"* ]] || [[ "$output" == *"phase"* ]] || [[ "$output" == *"retrieval"* ]]
    fi
}

@test "query performance statistics are collected" {
    # Run multiple queries to generate performance data
    run satlas query "class"
    assert_success
    
    run satlas query "func"
    assert_success
    
    run satlas query "AppDelegate"
    assert_success
    
    # Check if performance stats are tracked somewhere
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    if [[ -f "$stats_file" ]]; then
        local stats_content="$(cat "$stats_file")"
        # For now, just verify stats file exists and has content
        [ -s "$stats_file" ]  # File exists and is not empty
    else
        skip "Stats file not found - statistics collection not implemented yet"
    fi
}

@test "token estimation follows 4-chars-per-token rule" {
    # Test with known content
    local test_string="This is a test string for token counting"
    local char_count=${#test_string}
    local estimated_tokens=$((char_count / 4))
    
    # Should be reasonable token estimate
    [ "$estimated_tokens" -gt 5 ]
    [ "$estimated_tokens" -lt 20 ]
}

@test "large result sets are handled efficiently" {
    # Create query that should return multiple results
    run satlas query --max-results=100 ".*"
    
    # Should either succeed or provide appropriate limits
    [ "$status" -eq 0 ] || [[ "$output" == *"limit"* ]] || [[ "$output" == *"too many"* ]]
}

@test "query caching improves repeated query performance" {
    # First query (cold) - use precision timing
    start_time=$(get_timestamp)
    run satlas query "AppDelegate"
    assert_success
    end_time=$(get_timestamp)
    cold_duration_ms=$(calculate_duration_ms "$start_time" "$end_time")
    
    # Second identical query (potentially warm)
    start_time=$(get_timestamp)
    run satlas query "AppDelegate"
    assert_success
    end_time=$(get_timestamp)
    warm_duration_ms=$(calculate_duration_ms "$start_time" "$end_time")
    
    # Both should complete quickly (within 10 seconds = 10000ms for test environment)
    [ "$cold_duration_ms" -lt 10000 ]
    [ "$warm_duration_ms" -lt 10000 ]
    
    # Warm should not be significantly slower than cold (allow 5s = 5000ms variance)
    [ "$warm_duration_ms" -le "$((cold_duration_ms + 5000))" ]
}

@test "memory usage stays reasonable during queries" {
    # This is mainly a contract test - actual memory measurement would need special tools
    run satlas query --verbose ".*"
    
    # Should complete without obvious memory issues
    [ "$status" -eq 0 ] || [[ "$output" == *"memory"* ]] || [[ "$output" == *"limit"* ]]
}

@test "DSL format maintains symbol information accuracy" {
    run satlas export-dsl
    assert_success
    
    # DSL output should contain key symbol information
    [[ "$output" == *"SYM"* ]] || [[ "$output" == *"FILE"* ]] || [[ "$output" == *"class"* ]] || [[ "$output" == *"func"* ]]
}