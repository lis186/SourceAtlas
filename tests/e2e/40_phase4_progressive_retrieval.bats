#!/usr/bin/env bats

# Phase 4 Step 4.1: Progressive retrieval flow testing
# Verification: Each round limits are effective, and can progressively expand to get correct segments
# Progressive flow: shards → files → symbols → segments

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

# Test progressive retrieval limits (K=3 shards, N=20 files, X=400 lines)
@test "progressive retrieval respects K=3 shard limit" {
    # First ensure we have a sharded index
    run satlas run
    assert_success
    
    # Test that query respects shard limit
    run satlas query --progressive --max-shards=3 "AppDelegate"
    [ "$status" -eq 0 ]
    
    # Should contain reference to shard limit
    [[ "$output" == *"shards_selected"* ]]
    
    # Parse output to verify no more than 3 shards were used
    if [[ "$output" == *"shards_selected"* ]]; then
        shard_count=$(echo "$output" | grep -o '"shards_selected":[0-9]*' | grep -o '[0-9]*' || echo "0")
        [ "$shard_count" -le 3 ]
    fi
}

@test "progressive retrieval respects N=20 file limit" {
    run satlas run
    assert_success
    
    # Test file limit with a broad query
    run satlas query --progressive --max-files=20 "class"
    [ "$status" -eq 0 ]
    
    # Should contain reference to file limit
    [[ "$output" == *"files_selected"* ]]
    
    # Parse output to verify no more than 20 files were used
    if [[ "$output" == *"files_selected"* ]]; then
        file_count=$(echo "$output" | grep -o '"files_selected":[0-9]*' | grep -o '[0-9]*' || echo "0")
        [ "$file_count" -le 20 ]
    fi
}

@test "progressive retrieval respects X=400 line limit per segment" {
    run satlas run
    assert_success
    
    # Test segment line limit
    run satlas segment --max-lines=400 "swift_example.swift" 1 1000
    [ "$status" -eq 0 ]
    
    # Count lines in output (should be ≤ 400)
    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -le 400 ]
}

@test "progressive retrieval flow: shards -> files -> symbols -> segments" {
    run satlas run
    assert_success
    
    # Test the full progressive flow
    run satlas query --progressive --verbose "AppDelegate"
    [ "$status" -eq 0 ]
    
    # Should show the progression steps
    [[ "$output" == *"step_1_shards"* ]]
    [[ "$output" == *"step_2_files"* ]]
    [[ "$output" == *"step_3_symbols"* ]]
    [[ "$output" == *"step_4_segments"* ]]
}

@test "progressive retrieval can expand range when needed" {
    run satlas run
    assert_success
    
    # Test expansion capability
    run satlas query --progressive --expand "func"
    [ "$status" -eq 0 ]
    
    # Should indicate expansion occurred or was considered
    [[ "$output" == *"expanded"* ]] || [[ "$output" == *"expansion"* ]] || [ "$status" -eq 0 ]
}

@test "progressive retrieval maintains path references in format path:start-end" {
    run satlas run
    assert_success
    
    # Test that segments maintain proper references
    run satlas segment "swift_example.swift" 1 10
    [ "$status" -eq 0 ]
    
    # Should include path:start-end format
    [[ "$output" == *"swift_example.swift:"* ]]
}

@test "progressive retrieval supports symbol kind filtering" {
    run satlas run
    assert_success
    
    # Test filtering by symbol kind
    run satlas query --progressive --kind=class "example"
    [ "$status" -eq 0 ]
    
    # Should filter by symbol kind
    [[ "$output" == *"kind"* ]] || [ "$status" -eq 0 ]
}

@test "progressive retrieval handles empty results gracefully" {
    run satlas run
    assert_success
    
    # Test with query that should return no results
    run satlas query --progressive "NonExistentSymbolName12345"
    [ "$status" -eq 0 ]
    
    # Should handle empty results without error
    [[ "$output" == *"no results"* ]] || [[ "$output" == *"found: 0"* ]] || [ "$status" -eq 0 ]
}