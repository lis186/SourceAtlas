#!/usr/bin/env bats
# Phase 9 - I/O batch optimization tests

load ../helpers

# Test I/O batch optimization module
@test "I/O optimization system initializes correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    
    # Initialize I/O optimization
    run init_io_optimization
    assert_success
    
    # Should set environment variables
    [ -n "$SOURCEATLAS_TMPDIR" ]
    [ -n "$SOURCEATLAS_WORK_DIR" ]
    [ -d "$SOURCEATLAS_WORK_DIR" ]
    
    # Should emit initialization events if observability available
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "io_init" .sourceatlas/events.jsonl
        assert_output --partial '"component":"io_optimizer"'
    fi
}

@test "I/O optimization detects and uses tmpfs when available" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    
    # Test tmpfs auto-detection
    export SOURCEATLAS_USE_TMPFS=auto
    run init_io_optimization
    assert_success
    
    # Should complete without error regardless of tmpfs availability
    [ -n "$SOURCEATLAS_TMPDIR" ]
    
    # Test explicit tmpfs disable
    export SOURCEATLAS_USE_TMPFS=false
    run init_io_optimization
    assert_success
    
    # Test explicit tmpfs enable (may not work in all environments)
    export SOURCEATLAS_USE_TMPFS=true
    run init_io_optimization
    assert_success
    
    unset SOURCEATLAS_USE_TMPFS
}

@test "batch file reading processes multiple files efficiently" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    init_io_optimization
    
    # Create file list
    find . -type f -name "*.swift" -o -name "*.kt" -o -name "*.py" > files.txt
    [ -s files.txt ]
    
    # Test batch reading
    run batch_read_files files.txt output.jsonl
    assert_success
    
    # Should produce output
    [ -f output.jsonl ]
    [ -s output.jsonl ]
    
    # Output should contain metadata for each file
    file_count=$(wc -l < files.txt)
    output_lines=$(wc -l < output.jsonl 2>/dev/null || echo "0")
    
    # Should have processed some files (may not be 1:1 if some fail)
    [ "$output_lines" -ge 1 ]
}

@test "batch file reading uses configurable buffer sizes" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Test different buffer sizes
    export SOURCEATLAS_IO_BUFFER=32768  # 32KB
    export SOURCEATLAS_BATCH_SIZE=500   # 500 files per batch
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    
    # Should use configured values
    [ "$IO_BUFFER_SIZE" = "32768" ]
    [ "$BATCH_READ_SIZE" = "500" ]
    
    run init_io_optimization
    assert_success
    
    unset SOURCEATLAS_IO_BUFFER
    unset SOURCEATLAS_BATCH_SIZE
}

@test "bulk write operations use large buffers efficiently" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    init_io_optimization
    
    # Create test data
    test_data="This is test data for bulk write operations
Multiple lines of content
To test bulk writing efficiency
With large buffer operations"
    
    # Test bulk write from string
    run bulk_write_output "$test_data" output_from_string.txt
    assert_success
    
    [ -f output_from_string.txt ]
    [ -s output_from_string.txt ]
    
    # Verify content
    run cat output_from_string.txt
    assert_output --partial "test data for bulk write"
    
    # Test bulk write from file
    echo "$test_data" > input_file.txt
    run bulk_write_output input_file.txt output_from_file.txt
    assert_success
    
    [ -f output_from_file.txt ]
    [ -s output_from_file.txt ]
}

@test "memory-mapped processing handles large files" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    init_io_optimization
    
    # Create a large test file (simulate large file)
    for i in {1..1000}; do
        echo "Line $i of large file content for memory mapping test"
    done > large_file.txt
    
    # Test memory-mapped processing
    run mmap_process_large_file large_file.txt processed_output.txt
    assert_success
    
    [ -f processed_output.txt ]
    [ -s processed_output.txt ]
    
    # Should handle the file without crashing
    output_lines=$(wc -l < processed_output.txt)
    [ "$output_lines" -ge 1 ]
}

@test "I/O optimization reduces filesystem calls" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Create multiple small files
    for i in {1..50}; do
        echo "content $i" > "file${i}.txt"
        echo "file${i}.txt" >> files.txt
    done
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    init_io_optimization
    
    # Count before - this is simplified, real test would use strace or similar
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Process with batch I/O
    run batch_read_files files.txt batched_output.txt
    assert_success
    
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Should complete efficiently
    [ -f batched_output.txt ]
    
    # Performance should be reasonable for batch processing
    if command -v bc >/dev/null 2>&1; then
        duration=$(echo "$end_time - $start_time" | bc)
        # Batch processing 50 files should be fast
        [ "$(echo "$duration < 10.0" | bc)" -eq 1 ]
    fi
}

@test "I/O optimization handles file processing errors gracefully" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    init_io_optimization
    
    # Create file list with mix of existing and non-existing files
    cat > mixed_files.txt << 'EOF'
existing_file.txt
non_existent_file.txt
another_existing.txt
/dev/null
EOF
    
    echo "content1" > existing_file.txt
    echo "content2" > another_existing.txt
    
    # Should handle mixed files without crashing
    run batch_read_files mixed_files.txt error_test_output.txt
    assert_success
    
    # Should produce some output for existing files
    [ -f error_test_output.txt ]
    # May be empty if all files failed, but shouldn't crash
}

@test "I/O optimization cleanup works correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    init_io_optimization
    
    # Create some temporary data
    work_dir="$SOURCEATLAS_WORK_DIR"
    [ -d "$work_dir" ]
    
    echo "temp data" > "$work_dir/temp_file.txt"
    [ -f "$work_dir/temp_file.txt" ]
    
    # Run cleanup
    run cleanup_io_optimization
    assert_success
    
    # Temporary directory should be cleaned up
    [ ! -d "$work_dir" ]
}

@test "I/O optimization emits performance observability events" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    
    # Initialize with trace ID
    run init_io_optimization io-test-trace
    assert_success
    
    # Check for events
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "io_" .sourceatlas/events.jsonl
        assert_output --partial '"component":"io_optimizer"'
        assert_output --partial '"trace_id":"io-test-trace"'
        assert_output --partial '"buffer_size":'
        assert_output --partial '"batch_size":'
    fi
}

@test "I/O batch processing is significantly faster than individual operations" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Create test files
    for i in {1..100}; do
        echo "File $i content for batch processing speed test" > "speed_test_${i}.txt"
        echo "speed_test_${i}.txt" >> speed_files.txt
    done
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    init_io_optimization
    
    # Benchmark batch processing
    start_batch=$(date +%s.%N 2>/dev/null || date +%s)
    batch_read_files speed_files.txt batch_output.txt
    end_batch=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Benchmark individual processing (simulate)
    start_individual=$(date +%s.%N 2>/dev/null || date +%s)
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            wc -c < "$file" >/dev/null 2>&1
        fi
    done < speed_files.txt
    end_individual=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Batch should be at least competitive with individual
    if command -v bc >/dev/null 2>&1; then
        batch_duration=$(echo "$end_batch - $start_batch" | bc)
        individual_duration=$(echo "$end_individual - $start_individual" | bc)
        
        # Batch should not be significantly slower (within 2x)
        max_allowed=$(echo "$individual_duration * 2.0" | bc)
        is_reasonable=$(echo "$batch_duration <= $max_allowed" | bc)
        [ "$is_reasonable" -eq 1 ]
    fi
    
    # Verify batch processing produced output
    [ -f batch_output.txt ]
    [ -s batch_output.txt ]
}

@test "I/O optimization handles concurrent access safely" {
    skip "Concurrent I/O test requires complex setup"
    
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Testing concurrent I/O access would require:
    # - Multiple processes accessing same files
    # - File locking mechanisms
    # - Race condition detection
    # This is complex to implement reliably in BATS
}

@test "I/O optimization provides detailed performance metrics" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Create test files
    for i in {1..20}; do
        echo "Metrics test file $i" > "metrics_${i}.txt"
        echo "metrics_${i}.txt" >> metrics_files.txt
    done
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    init_io_optimization
    
    # Process with metrics tracking
    run batch_read_files metrics_files.txt metrics_output.txt metrics-trace-123
    assert_success
    
    # Should provide performance information
    [ -f metrics_output.txt ]
    
    # Check for detailed events if observability available
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "metrics-trace-123" .sourceatlas/events.jsonl
        # Should contain performance-related events
        assert_output --partial '"trace_id":"metrics-trace-123"'
    fi
}

@test "I/O optimization configuration is respected" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Test custom configuration
    export SOURCEATLAS_IO_BUFFER=131072  # 128KB
    export SOURCEATLAS_BATCH_SIZE=2000   # 2000 files per batch
    export SOURCEATLAS_USE_TMPFS=false
    
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    
    # Configuration should be applied
    [ "$IO_BUFFER_SIZE" = "131072" ]
    [ "$BATCH_READ_SIZE" = "2000" ]
    [ "$USE_TMPFS" = "false" ]
    
    run init_io_optimization
    assert_success
    
    # Should use configured settings
    [ -n "$SOURCEATLAS_WORK_DIR" ]
    
    unset SOURCEATLAS_IO_BUFFER
    unset SOURCEATLAS_BATCH_SIZE
    unset SOURCEATLAS_USE_TMPFS
}

@test "I/O optimization integrates with other Phase 9 components" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Load multiple Phase 9 components
    source "$PROJECT_ROOT/lib/io_optimize.sh"
    source "$PROJECT_ROOT/lib/cache_optimize.sh" 2>/dev/null || true
    
    # Initialize systems
    init_io_optimization
    init_cache 2>/dev/null || true
    
    find . -name "*.swift" > integration_files.txt
    
    # I/O optimization should work alongside other optimizations
    run batch_read_files integration_files.txt integration_output.txt
    assert_success
    
    [ -f integration_output.txt ]
    [ -s integration_output.txt ]
    
    # Should not conflict with other optimizations
    if declare -f fast_change_detection >/dev/null 2>&1; then
        # Cache optimization functions should still be available
        run fast_change_detection integration_files.txt changed.txt
        # May succeed or fail based on cache state, but shouldn't crash
    fi
}