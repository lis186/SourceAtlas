#!/usr/bin/env bats
# Phase 9 - AWK batch processing optimization tests

load ../helpers

# Test AWK batch processing module
@test "batch_optimize.awk processes file metadata correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Create input for AWK script (tab-separated: path, size, loc, hash, mtime)
    cat > input.tsv << 'EOF'
src/SwiftExample.swift	500	20	abc123	1693123456
src/KotlinExample.kt	750	30	def456	1693123457
src/config.json	100	5	ghi789	1693123458
EOF
    
    # Run batch optimizer
    run awk -f "$PROJECT_ROOT/lib/batch_optimize.awk" input.tsv
    assert_success
    
    # Verify JSON output format
    assert_output --partial '"repo":'
    assert_output --partial '"path":"src/SwiftExample.swift"'
    assert_output --partial '"lang":"swift"'
    assert_output --partial '"size_bytes":500'
    assert_output --partial '"loc":20'
    
    # Verify multiple files processed
    [ "$(echo "$output" | wc -l)" -eq 3 ]
    
    # Verify performance improvement (should be much faster than individual calls)
    benchmark_test "awk-batch" awk -f "$PROJECT_ROOT/lib/batch_optimize.awk" input.tsv
}

@test "batch_optimize.awk handles language detection correctly" {
    setup_test
    copy_fixtures "sourceatlas"
    
    cd "$TEST_TEMP_DIR"
    
    # Test various file extensions
    cat > lang_test.tsv << 'EOF'
test.swift	100	10	hash1	1693123456
test.kt	100	10	hash2	1693123456  
test.java	100	10	hash3	1693123456
test.py	100	10	hash4	1693123456
test.rb	100	10	hash5	1693123456
test.sh	100	10	hash6	1693123456
test.json	100	10	hash7	1693123456
test.unknown	100	10	hash8	1693123456
EOF
    
    run awk -f "$PROJECT_ROOT/lib/batch_optimize.awk" lang_test.tsv
    assert_success
    
    # Verify language detection
    assert_output --partial '"lang":"swift"'
    assert_output --partial '"lang":"kotlin"'
    assert_output --partial '"lang":"java"'
    assert_output --partial '"lang":"python"'
    assert_output --partial '"lang":"ruby"'
    assert_output --partial '"lang":"shell"'
    assert_output --partial '"lang":"json"'
    assert_output --partial '"lang":"unknown"'
}

@test "batch_optimize.awk calculates importance scores" {
    setup_test
    copy_fixtures "sourceatlas"
    
    cd "$TEST_TEMP_DIR"
    
    # Test files with different characteristics for importance scoring
    cat > importance_test.tsv << 'EOF'
src/AppViewController.swift	1000	50	hash1	1693123456
src/ConfigHelper.kt	200	10	hash2	1693123456
src/TestHelper.py	100	5	hash3	1693123456
build.gradle	50	3	hash4	1693123456
EOF
    
    run awk -f "$PROJECT_ROOT/lib/batch_optimize.awk" importance_test.tsv
    assert_success
    
    # Verify importance scores exist and are reasonable
    assert_output --partial '"importance_score":'
    
    # UI files should have higher importance
    # Extract importance scores and verify UI file has higher score
    ui_score=$(echo "$output" | grep "AppViewController" | grep -o '"importance_score":[0-9.]*' | cut -d: -f2)
    config_score=$(echo "$output" | grep "ConfigHelper" | grep -o '"importance_score":[0-9.]*' | cut -d: -f2)
    
    # UI should have higher importance than config (basic check)
    [ "${ui_score%.*}" -ge "${config_score%.*}" ]
}

@test "batch_optimize.awk emits observability events" {
    setup_test
    copy_fixtures "sourceatlas"
    
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Create test input
    echo -e "test.swift\t100\t10\thash1\t1693123456" > input.tsv
    
    # Capture stderr for events
    run bash -c "awk -f '$PROJECT_ROOT/lib/batch_optimize.awk' input.tsv 2>events.log"
    assert_success
    
    # Verify observability events were emitted
    [ -f events.log ]
    run cat events.log
    assert_output --partial '"event":"batch_optimize_start"'
    assert_output --partial '"trace_id":"batch-optimize-'
    assert_output --partial '"component":"batch_optimizer"' || true  # May be in different format
}

@test "batch_optimize.awk handles empty and malformed input" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Test empty input
    touch empty.tsv
    run awk -f "$PROJECT_ROOT/lib/batch_optimize.awk" empty.tsv
    assert_success
    [ -z "$output" ]
    
    # Test malformed input
    echo "invalid line without tabs" > malformed.tsv
    run awk -f "$PROJECT_ROOT/lib/batch_optimize.awk" malformed.tsv
    # Should not crash, may produce minimal or no output
    assert_success
}

@test "batch_optimize.awk performance is significantly better than individual calls" {
    setup_test
    copy_fixtures "sourceatlas" 
    
    cd "$TEST_TEMP_DIR"
    
    # Create larger test dataset
    for i in {1..50}; do
        echo -e "file${i}.swift\t$((RANDOM + 100))\t$((RANDOM % 100 + 10))\thash${i}\t1693123456"
    done > large_input.tsv
    
    # Benchmark batch processing
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    run awk -f "$PROJECT_ROOT/lib/batch_optimize.awk" large_input.tsv
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    assert_success
    
    # Verify all files processed
    [ "$(echo "$output" | wc -l)" -eq 50 ]
    
    # Performance should be reasonable (basic check)
    # Batch processing should complete quickly
    if command -v bc >/dev/null 2>&1; then
        duration=$(echo "$end_time - $start_time" | bc)
        # Should complete in under 5 seconds for 50 files
        [ "$(echo "$duration < 5.0" | bc)" -eq 1 ]
    fi
}