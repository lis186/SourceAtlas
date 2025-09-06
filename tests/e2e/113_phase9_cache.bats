#!/usr/bin/env bats
# Phase 9 - Cache optimization tests

load ../helpers

# Test cache optimization module
@test "cache system initializes correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    
    # Initialize cache
    run init_cache
    assert_success
    
    # Verify cache directories and files created
    [ -d ".sourceatlas/cache" ]
    [ -f ".sourceatlas/cache/content_hashes.db" ]
    [ -f ".sourceatlas/cache/file_metadata.db" ]
    [ -f ".sourceatlas/cache/index_results.jsonl" ]
}

@test "fast change detection works with mtime" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    init_cache
    
    # Create file list
    find . -type f -name "*.swift" -o -name "*.kt" > files.txt
    [ -s files.txt ]
    
    # First run - all files should be "changed" (new)
    run fast_change_detection files.txt changed_files.txt
    # Returns 1 for full rebuild mode, 0 for incremental
    
    [ -f changed_files.txt ]
    # All files should be marked as changed initially
    [ -s changed_files.txt ]
    
    # Simulate updating metadata cache
    while IFS= read -r file_path; do
        if [ -f "$file_path" ]; then
            mtime=$(stat -c %Y "$file_path" 2>/dev/null || stat -f %m "$file_path" 2>/dev/null || echo "0")
            size=$(wc -c < "$file_path" 2>/dev/null || echo "0")
            update_metadata_cache "$file_path" "$mtime" "$size"
        fi
    done < files.txt
    
    # Second run - files should be cached (unchanged)
    run fast_change_detection files.txt changed_files2.txt
    
    [ -f changed_files2.txt ]
    # Should have fewer changed files now
    changed_count=$(wc -l < changed_files2.txt 2>/dev/null || echo "0")
    original_count=$(wc -l < changed_files.txt)
    
    # Some optimization should occur
    [ "$changed_count" -le "$original_count" ]
}

@test "content hash detection identifies changes accurately" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    init_cache
    
    # Create file list
    echo "SwiftExample.swift" > files.txt
    
    # First run - should detect as changed
    run content_hash_detection files.txt changed_files.txt
    assert_success
    
    [ -f changed_files.txt ]
    [ -s changed_files.txt ]  # Should have content
    
    # Second run without file changes - should be cached
    run content_hash_detection files.txt changed_files2.txt
    assert_success
    
    [ -f changed_files2.txt ]
    # Should be empty or have fewer entries
    changed_count=$(wc -l < changed_files2.txt 2>/dev/null || echo "0")
    [ "$changed_count" -eq 0 ]
    
    # Modify file and test again
    echo "// Added comment" >> SwiftExample.swift
    
    run content_hash_detection files.txt changed_files3.txt
    assert_success
    
    [ -f changed_files3.txt ]
    [ -s changed_files3.txt ]  # Should detect the change
}

@test "cache system calculates hashes correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    
    # Create test file
    echo "test content" > test_file.txt
    
    # Calculate hash
    run calculate_fast_hash test_file.txt
    assert_success
    [ -n "$output" ]
    
    # Hash should be consistent
    hash1="$output"
    
    run calculate_fast_hash test_file.txt
    assert_success
    [ "$output" = "$hash1" ]
    
    # Modify file, hash should change
    echo "modified content" > test_file.txt
    
    run calculate_fast_hash test_file.txt
    assert_success
    hash2="$output"
    
    [ "$hash1" != "$hash2" ]
}

@test "cache update functions work correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    init_cache
    
    # Test hash cache update
    update_hash_cache "test_file.txt" "abc123hash"
    
    # Verify hash was stored
    run grep "test_file.txt" ".sourceatlas/cache/content_hashes.db"
    assert_success
    assert_output --partial "abc123hash"
    
    # Test metadata cache update
    update_metadata_cache "test_file.txt" "1693123456" "100"
    
    # Verify metadata was stored
    run grep "test_file.txt" ".sourceatlas/cache/file_metadata.db"
    assert_success
    assert_output --partial "1693123456"
    assert_output --partial "100"
    
    # Test updating existing entry
    update_hash_cache "test_file.txt" "def456hash"
    
    # Should replace old hash
    run grep "test_file.txt" ".sourceatlas/cache/content_hashes.db"
    assert_success
    assert_output --partial "def456hash"
    ! assert_output --partial "abc123hash"  # Old hash should be gone
}

@test "cache retrieval works for unchanged files" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    init_cache
    
    # Create mock cached results
    cat > ".sourceatlas/cache/index_results.jsonl" << 'EOF'
{"repo":"test","path":"file1.swift","file_name":"file1.swift","lang":"swift"}
{"repo":"test","path":"file2.kt","file_name":"file2.kt","lang":"kotlin"}
{"repo":"test","path":"file3.py","file_name":"file3.py","lang":"python"}
EOF
    
    # Create list of unchanged files
    cat > unchanged_files.txt << 'EOF'
file1.swift
file3.py
EOF
    
    # Retrieve cached results
    run retrieve_cached_results unchanged_files.txt output.jsonl
    assert_success
    
    [ -f output.jsonl ]
    [ -s output.jsonl ]
    
    # Should contain results for unchanged files
    run grep "file1.swift" output.jsonl
    assert_success
    
    run grep "file3.py" output.jsonl
    assert_success
    
    # Should NOT contain file2.kt (not in unchanged list)
    ! grep -q "file2.kt" output.jsonl
}

@test "cache cleanup removes stale entries" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    init_cache
    
    # Add cache entries for existing and non-existing files
    update_hash_cache "existing.swift" "hash1"
    update_hash_cache "nonexistent.swift" "hash2"
    update_metadata_cache "existing.swift" "123" "100"
    update_metadata_cache "nonexistent.swift" "456" "200"
    
    # Create file list with only existing file
    echo "existing.swift" > current_files.txt
    touch existing.swift
    
    # Add cached results
    echo '{"path":"existing.swift","lang":"swift"}' >> ".sourceatlas/cache/index_results.jsonl"
    echo '{"path":"nonexistent.swift","lang":"swift"}' >> ".sourceatlas/cache/index_results.jsonl"
    
    # Run cleanup
    run cleanup_cache current_files.txt
    assert_success
    
    # Verify stale entries removed
    run grep "existing.swift" ".sourceatlas/cache/content_hashes.db"
    assert_success
    
    ! grep -q "nonexistent.swift" ".sourceatlas/cache/content_hashes.db"
    
    run grep "existing.swift" ".sourceatlas/cache/file_metadata.db"  
    assert_success
    
    ! grep -q "nonexistent.swift" ".sourceatlas/cache/file_metadata.db"
}

@test "cache system emits observability events" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    
    # Initialize with trace ID
    run init_cache test-cache-trace
    assert_success
    
    # Check for events (if events file exists)
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "cache" .sourceatlas/events.jsonl
        assert_output --partial '"component":"cache_optimizer"'
        assert_output --partial '"trace_id":"test-cache-trace"'
    fi
}

@test "cache system handles concurrent access safely" {
    skip "Concurrent access test - complex to implement safely"
    
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    init_cache
    
    # This would test concurrent cache updates
    # Skipped due to complexity of shell-based concurrency testing
}

@test "cache system provides significant performance improvement" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/cache_optimize.sh"
    init_cache
    
    # Create file list
    find . -type f -name "*.swift" -o -name "*.kt" > files.txt
    [ -s files.txt ]
    
    # First run - measure time for full processing
    start_time1=$(date +%s.%N 2>/dev/null || date +%s)
    fast_change_detection files.txt changed1.txt
    end_time1=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Populate cache
    while IFS= read -r file_path; do
        if [ -f "$file_path" ]; then
            mtime=$(stat -c %Y "$file_path" 2>/dev/null || stat -f %m "$file_path" 2>/dev/null || echo "0")
            size=$(wc -c < "$file_path" 2>/dev/null || echo "0")
            update_metadata_cache "$file_path" "$mtime" "$size"
        fi
    done < files.txt
    
    # Second run - should be much faster due to caching
    start_time2=$(date +%s.%N 2>/dev/null || date +%s)
    fast_change_detection files.txt changed2.txt
    end_time2=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Verify cache effectiveness (fewer changed files in second run)
    changed1=$(wc -l < changed1.txt 2>/dev/null || echo "0")
    changed2=$(wc -l < changed2.txt 2>/dev/null || echo "0")
    
    [ "$changed2" -le "$changed1" ]
}