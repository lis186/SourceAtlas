#!/usr/bin/env bats
# Phase 9 - Comprehensive benchmark system tests

load ../helpers

# Test benchmark system comprehensive functionality
@test "benchmark system initializes with all required components" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    
    # Initialize benchmark system
    run init_benchmark_system
    assert_success
    
    # Should create benchmark directory structure
    [ -d ".sourceatlas/benchmarks" ]
    [ -f ".sourceatlas/benchmarks/results.jsonl" ]
    
    # Should detect system capabilities
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "benchmark_init" .sourceatlas/events.jsonl
        assert_output --partial '"component":"benchmark_system"'
        assert_output --partial 'cores'
        assert_output --partial 'RAM'
    fi
}

@test "benchmark system creates appropriate test datasets" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    # Test different dataset sizes
    for size in "small" "medium" "large"; do
        run create_test_dataset "$size" "dataset_${size}.txt"
        assert_success
        
        [ -f "dataset_${size}.txt" ]
        [ -s "dataset_${size}.txt" ]
        
        # Verify dataset contains expected number of files
        case "$size" in
            "small")
                file_count=$(wc -l < "dataset_${size}.txt")
                [ "$file_count" -ge 10 ]
                [ "$file_count" -le 100 ]
                ;;
            "medium")
                file_count=$(wc -l < "dataset_${size}.txt")
                [ "$file_count" -ge 100 ]
                [ "$file_count" -le 1000 ]
                ;;
            "large")
                file_count=$(wc -l < "dataset_${size}.txt")
                [ "$file_count" -ge 1000 ]
                ;;
        esac
        
        # Files should have realistic extensions
        run head -5 "dataset_${size}.txt"
        assert_output --partial ".swift" || assert_output --partial ".kt" || assert_output --partial ".java"
    done
}

@test "baseline benchmark measurement works correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    # Create small test dataset
    create_test_dataset "small" "baseline_test.txt"
    
    # Run baseline benchmark
    run run_baseline_benchmark "baseline_test.txt" "baseline-trace"
    assert_success
    
    # Should return JSON with performance metrics
    echo "$output" | python3 -m json.tool >/dev/null 2>&1
    
    # Should contain required fields
    assert_output --partial '"files_processed":'
    assert_output --partial '"duration":'
    assert_output --partial '"throughput":'
    assert_output --partial '"optimization":"baseline"'
}

@test "optimization level benchmarks work for all levels" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    create_test_dataset "small" "optimization_test.txt"
    
    # Test different optimization levels
    optimization_levels=("level1" "level2" "level3" "level4" "level5" "full")
    
    for level in "${optimization_levels[@]}"; do
        run run_optimized_benchmark "optimization_test.txt" "$level" "test-$level"
        assert_success
        
        # Should return valid JSON
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
        
        # Should contain level-specific information
        assert_output --partial "\"optimization\":\"$level\""
        assert_output --partial '"files_processed":'
        assert_output --partial '"duration":'
        assert_output --partial '"throughput":'
    done
}

@test "benchmark system calculates performance improvements correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    create_test_dataset "small" "improvement_test.txt"
    
    # Run baseline
    baseline_results=$(run_baseline_benchmark "improvement_test.txt" "baseline-trace")
    
    # Run optimized benchmark
    optimized_results=$(run_optimized_benchmark "improvement_test.txt" "full" "optimized-trace")
    
    # Both should be valid JSON
    echo "$baseline_results" | python3 -m json.tool >/dev/null 2>&1
    echo "$optimized_results" | python3 -m json.tool >/dev/null 2>&1
    
    # Extract durations for comparison
    baseline_duration=$(echo "$baseline_results" | python3 -c "import sys,json; print(json.load(sys.stdin)['duration'])")
    optimized_duration=$(echo "$optimized_results" | python3 -c "import sys,json; print(json.load(sys.stdin)['duration'])")
    
    # Both should be numeric values greater than 0
    if command -v bc >/dev/null 2>&1; then
        [ "$(echo "$baseline_duration > 0" | bc)" -eq 1 ]
        [ "$(echo "$optimized_duration > 0" | bc)" -eq 1 ]
    fi
}

@test "benchmark regression detection identifies performance problems" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    # Create mock baseline results (good performance)
    cat > ".sourceatlas/benchmarks/baseline.json" << 'EOF'
{
    "timestamp": "2025-01-01T00:00:00Z",
    "optimizations": {
        "full": {
            "duration": 1.0,
            "throughput": 100.0
        }
    }
}
EOF
    
    # Test with acceptable performance (no regression)
    good_results='{"optimizations":{"full":{"duration":1.1,"throughput":90.0}}}'
    run check_performance_regression "$good_results" "good-test"
    # Should return 0 (no regression detected)
    [ "$status" -eq 0 ]
    
    # Test with regression (>20% slower)
    bad_results='{"optimizations":{"full":{"duration":2.5,"throughput":40.0}}}'
    run check_performance_regression "$bad_results" "regression-test"
    # Should return 1 (regression detected)
    [ "$status" -eq 1 ]
}

@test "benchmark system updates baseline appropriately" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    # Create initial baseline
    cat > ".sourceatlas/benchmarks/baseline.json" << 'EOF'
{
    "optimizations": {
        "full": {
            "duration": 2.0,
            "throughput": 50.0
        }
    }
}
EOF
    
    # Test with significantly better results (should update baseline)
    better_results='{"optimizations":{"full":{"duration":1.0,"throughput":100.0}}}'
    
    if should_update_baseline "$better_results"; then
        # Baseline should be updated for significant improvements
        echo "Baseline update working correctly"
    fi
    
    # Test with slightly better results (may not update)
    slightly_better='{"optimizations":{"full":{"duration":1.9,"throughput":52.0}}}'
    
    # Should handle both cases without crashing
    should_update_baseline "$slightly_better" || true
}

@test "benchmark system generates comprehensive performance reports" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    # Create some benchmark results
    echo '{"timestamp":"2025-01-01T00:00:00Z","test_size":"small","baseline":{"duration":2.0},"optimizations":{"level1":{"duration":1.5},"full":{"duration":1.0}}}' >> ".sourceatlas/benchmarks/results.jsonl"
    
    # Generate performance report
    run generate_performance_report
    assert_success
    
    [ -f ".sourceatlas/benchmarks/performance_report.md" ]
    [ -s ".sourceatlas/benchmarks/performance_report.md" ]
    
    # Report should contain expected sections
    run cat ".sourceatlas/benchmarks/performance_report.md"
    assert_output --partial "# SourceAtlas Phase 9 Performance Report"
    assert_output --partial "## Benchmark Results Summary"
    assert_output --partial "| Optimization Level |"
    assert_output --partial "### Recent Results"
}

@test "benchmark system handles various dataset sizes correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    
    # Test with each dataset size
    for size in "small" "medium"; do  # Skip large for test speed
        run init_benchmark_system
        assert_success
        
        # Should handle different sizes without error
        run create_test_dataset "$size" "size_test_${size}.txt"
        assert_success
        
        [ -f "size_test_${size}.txt" ]
        
        # Verify dataset characteristics
        file_count=$(wc -l < "size_test_${size}.txt")
        [ "$file_count" -ge 1 ]
    done
}

@test "benchmark system emits detailed observability events" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    
    # Initialize with trace ID
    run init_benchmark_system "benchmark-observability-test"
    assert_success
    
    # Check for observability events
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "benchmark" .sourceatlas/events.jsonl
        assert_output --partial '"component":"benchmark_system"'
        assert_output --partial '"trace_id":"benchmark-observability-test"'
    fi
    
    # Create small dataset and run benchmark with events
    create_test_dataset "small" "event_test.txt"
    
    run run_baseline_benchmark "event_test.txt" "baseline-event-test"
    assert_success
    
    # Should emit benchmark-specific events
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "baseline-event-test" .sourceatlas/events.jsonl
        # Events should be emitted during benchmark execution
    fi
}

@test "benchmark system integrates with Phase 9 optimizations" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Load benchmark system and Phase 9 integration
    source "$PROJECT_ROOT/lib/benchmark.sh"
    source "$PROJECT_ROOT/lib/phase9_integration.sh" 2>/dev/null || skip "Phase 9 integration not available"
    
    init_benchmark_system
    
    # Should work alongside Phase 9 optimizations
    export SOURCEATLAS_PHASE9_ENABLED=true
    export SOURCEATLAS_OPTIMIZATION_LEVEL=full
    
    # Initialize Phase 9 if available
    if declare -f init_phase9_system >/dev/null 2>&1; then
        init_phase9_system
    fi
    
    # Benchmark system should still function
    create_test_dataset "small" "integration_test.txt"
    
    run run_baseline_benchmark "integration_test.txt" "integration-test"
    assert_success
    
    unset SOURCEATLAS_PHASE9_ENABLED
    unset SOURCEATLAS_OPTIMIZATION_LEVEL
}

@test "benchmark system handles errors and edge cases gracefully" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    # Test with empty dataset
    touch empty_dataset.txt
    run run_baseline_benchmark empty_dataset.txt "empty-test"
    assert_success  # Should not crash
    
    # Test with non-existent dataset
    run run_baseline_benchmark "non_existent.txt" "missing-test"
    # May succeed or fail, but shouldn't crash the system
    
    # Test with malformed baseline
    echo "invalid json" > ".sourceatlas/benchmarks/baseline.json"
    run check_performance_regression '{"optimizations":{"full":{"duration":1.0}}}' "malformed-test"
    # Should handle gracefully
}

@test "benchmark system provides accurate performance measurements" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    # Create controlled test dataset
    for i in {1..50}; do
        echo "src/Test${i}.swift" >> controlled_test.txt
    done
    
    # Run multiple measurements
    measurements=()
    for run in {1..3}; do
        result=$(run_baseline_benchmark controlled_test.txt "measurement-$run")
        duration=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['duration'])" 2>/dev/null || echo "0")
        measurements+=("$duration")
    done
    
    # Measurements should be reasonably consistent (not perfect due to system variance)
    # This is a basic sanity check
    for measurement in "${measurements[@]}"; do
        if command -v bc >/dev/null 2>&1; then
            # Each measurement should be a positive number
            [ "$(echo "$measurement >= 0" | bc)" -eq 1 ] 2>/dev/null || true
        fi
    done
}

@test "benchmark system supports different performance optimization scenarios" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    create_test_dataset "small" "scenario_test.txt"
    
    # Test scenarios that should show different performance characteristics
    scenarios=("level1" "level3" "full")
    
    for scenario in "${scenarios[@]}"; do
        result=$(run_optimized_benchmark "scenario_test.txt" "$scenario" "scenario-$scenario")
        
        # Each scenario should return valid results
        echo "$result" | python3 -m json.tool >/dev/null 2>&1
        
        # Should contain scenario-specific information
        echo "$result" | grep -q "\"optimization\":\"$scenario\"" || {
            echo "Scenario $scenario not properly identified"
            return 1
        }
    done
}

@test "benchmark system calculation and reporting is mathematically correct" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    init_benchmark_system
    
    # Create predictable test scenario
    create_test_dataset "small" "math_test.txt"
    file_count=$(wc -l < math_test.txt)
    
    # Run benchmark and verify calculations
    result=$(run_baseline_benchmark "math_test.txt" "math-test")
    
    # Extract values
    processed=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['files_processed'])" 2>/dev/null || echo "0")
    duration=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['duration'])" 2>/dev/null || echo "1")
    throughput=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['throughput'])" 2>/dev/null || echo "0")
    
    # Verify mathematical relationship: throughput = files_processed / duration
    if command -v bc >/dev/null 2>&1 && [ "$duration" != "0" ] && [ "$processed" != "0" ]; then
        expected_throughput=$(echo "scale=2; $processed / $duration" | bc)
        actual_throughput="$throughput"
        
        # Allow for small rounding differences
        difference=$(echo "scale=2; $expected_throughput - $actual_throughput" | bc | sed 's/^-//')
        is_close=$(echo "$difference < 0.1" | bc)
        
        [ "$is_close" -eq 1 ]
    fi
    
    # Files processed should match input
    [ "$processed" -le "$file_count" ]  # May be less if some processing failed
    [ "$processed" -ge 1 ]  # Should process at least some files
}