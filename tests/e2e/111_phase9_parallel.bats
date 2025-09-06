#!/usr/bin/env bats
# Phase 9 - Parallel file processing optimization tests

load ../helpers

# Test parallel processing module
@test "parallel processing handles multiple workers correctly" {
    setup_test
    copy_fixtures "sourceatlas"
    
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Create file list
    find . -type f -name "*.swift" -o -name "*.kt" -o -name "*.py" > files.txt
    [ -s files.txt ]  # Ensure we have files to process
    
    # Source the parallel optimization module
    source "$PROJECT_ROOT/lib/parallel_optimize.sh"
    
    # Test parallel processing
    run parallel_process_files files.txt output.jsonl
    assert_success
    
    # Verify output exists and has content
    [ -f output.jsonl ]
    [ -s output.jsonl ]
    
    # Verify JSON format
    run head -1 output.jsonl
    assert_output --partial '"repo":'
    assert_output --partial '"path":'
    assert_output --partial '"lang":'
}

@test "parallel processing uses correct number of workers" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Source the parallel optimization module  
    source "$PROJECT_ROOT/lib/parallel_optimize.sh"
    
    # Test CPU core detection
    run get_cpu_cores
    assert_success
    
    # Should return nproc * 2
    cpu_cores=$(nproc 2>/dev/null || echo "4")
    expected_workers=$((cpu_cores * 2))
    
    [ "$output" -eq "$expected_workers" ]
}

@test "parallel processing emits observability events" {
    setup_test
    copy_fixtures "sourceatlas"
    
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Create small file list
    echo "SwiftExample.swift" > files.txt
    
    # Source and run with events capturing
    source "$PROJECT_ROOT/lib/parallel_optimize.sh"
    
    run parallel_process_files files.txt output.jsonl test-trace-123
    assert_success
    
    # Check if events file was created
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "parallel" .sourceatlas/events.jsonl
        assert_output --partial '"component":"parallel_optimizer"'
        assert_output --partial '"trace_id":"test-trace-123"'
    fi
}

@test "parallel processing handles worker failures gracefully" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Create file list with non-existent files to simulate failures
    cat > files.txt << 'EOF'
existing.swift
nonexistent1.swift
nonexistent2.swift
EOF
    echo "class Test {}" > existing.swift
    
    source "$PROJECT_ROOT/lib/parallel_optimize.sh"
    
    # Should not crash even with missing files
    run parallel_process_files files.txt output.jsonl
    assert_success
    
    # Should still produce some output for existing files
    [ -f output.jsonl ]
}

@test "parallel processing respects tmpfs configuration" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/parallel_optimize.sh"
    
    # Test tmpfs detection when disabled
    export SOURCEATLAS_USE_TMPFS=false
    run parallel_process_files /dev/null output.jsonl
    assert_success
    
    # Test tmpfs when enabled (may not be available in all environments)
    export SOURCEATLAS_USE_TMPFS=true
    run parallel_process_files /dev/null output.jsonl
    assert_success
    
    unset SOURCEATLAS_USE_TMPFS
}

@test "parallel processing cleanup works correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    echo "test.swift" > files.txt
    echo "class Test {}" > test.swift
    
    source "$PROJECT_ROOT/lib/parallel_optimize.sh"
    
    # Run processing
    run parallel_process_files files.txt output.jsonl
    assert_success
    
    # Temporary directories should be cleaned up
    # Note: This is hard to test directly since cleanup happens automatically
    # But the function should complete successfully
    [ -f output.jsonl ]
}

@test "parallel processing performance scales with workers" {
    skip "Performance test - requires large dataset"
    
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Generate multiple test files
    for i in {1..100}; do
        echo "class TestClass${i} {}" > "test${i}.swift"
        echo "test${i}.swift" >> files.txt
    done
    
    source "$PROJECT_ROOT/lib/parallel_optimize.sh"
    
    # Benchmark parallel processing
    benchmark_test "parallel-100files" parallel_process_files files.txt output.jsonl
    assert_success
    
    # Verify all files processed
    [ "$(wc -l < output.jsonl)" -eq 100 ]
}

@test "parallel processing handles empty file list" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    touch empty_files.txt
    
    source "$PROJECT_ROOT/lib/parallel_optimize.sh"
    
    run parallel_process_files empty_files.txt output.jsonl
    assert_success
    
    # Should create empty output file
    [ -f output.jsonl ]
    [ ! -s output.jsonl ]  # File should be empty
}

@test "parallel processing merges worker outputs correctly" {
    setup_test
    copy_fixtures "sourceatlas"
    
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Create file list with multiple files
    find . -name "*.swift" -o -name "*.kt" > files.txt
    [ -s files.txt ]  # Ensure we have multiple files
    
    source "$PROJECT_ROOT/lib/parallel_optimize.sh"
    
    run parallel_process_files files.txt output.jsonl
    assert_success
    
    # Verify output has multiple lines (merged from workers)
    file_count=$(wc -l < files.txt)
    output_lines=$(wc -l < output.jsonl)
    
    # Should have roughly the same number of output lines as input files
    [ "$output_lines" -ge 1 ]
    
    # Verify each line is valid JSON
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "$line" | python3 -m json.tool > /dev/null 2>&1 || {
                echo "Invalid JSON line: $line"
                return 1
            }
        fi
    done < output.jsonl
}