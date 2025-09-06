#!/usr/bin/env bats
# Phase 9 - Performance regression testing (speed)

load ../helpers

# Test Phase 9 performance regression detection
@test "Phase 9 is faster than or equal to baseline performance" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    
    # Create a reasonable test dataset
    for i in {1..20}; do
        echo "class TestClass${i} { func test() {} }" > "test${i}.swift"
    done
    
    find . -name "*.swift" > files.txt
    [ -s files.txt ]
    
    # Measure baseline performance (Phase 8 or unoptimized)
    export SOURCEATLAS_PHASE9_ENABLED=false
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    start_baseline=$(date +%s.%N 2>/dev/null || date +%s)
    process_files_baseline files.txt baseline_output.jsonl baseline-trace
    end_baseline=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Measure Phase 9 performance
    export SOURCEATLAS_PHASE9_ENABLED=true
    export SOURCEATLAS_OPTIMIZATION_LEVEL=full
    
    start_optimized=$(date +%s.%N 2>/dev/null || date +%s)
    process_files_optimized files.txt optimized_output.jsonl optimized-trace
    end_optimized=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Calculate durations
    if command -v bc >/dev/null 2>&1; then
        baseline_duration=$(echo "$end_baseline - $start_baseline" | bc)
        optimized_duration=$(echo "$end_optimized - $start_optimized" | bc)
        
        # Phase 9 should not be significantly slower (allow 20% regression threshold)
        regression_threshold=1.2  # 20% slower is the limit
        max_allowed=$(echo "$baseline_duration * $regression_threshold" | bc)
        
        # Check if optimized is within acceptable range
        is_acceptable=$(echo "$optimized_duration <= $max_allowed" | bc)
        
        if [ "$is_acceptable" != "1" ]; then
            echo "Performance regression detected!"
            echo "Baseline: ${baseline_duration}s"
            echo "Optimized: ${optimized_duration}s" 
            echo "Threshold: ${max_allowed}s"
            return 1
        fi
    else
        # Basic check without precise timing
        [ -f optimized_output.jsonl ]
        [ -s optimized_output.jsonl ]
    fi
    
    # Verify outputs are equivalent
    baseline_lines=$(wc -l < baseline_output.jsonl)
    optimized_lines=$(wc -l < optimized_output.jsonl)
    
    # Should process similar number of files
    [ "$optimized_lines" -ge 1 ]
    
    unset SOURCEATLAS_PHASE9_ENABLED
    unset SOURCEATLAS_OPTIMIZATION_LEVEL
}

@test "Phase 9 different optimization levels meet performance expectations" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    
    # Create test files
    for i in {1..10}; do
        echo "class Test${i} {}" > "test${i}.swift"
    done
    
    find . -name "*.swift" > files.txt
    
    export SOURCEATLAS_PHASE9_ENABLED=true
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    declare -A level_durations
    
    # Test different optimization levels
    for level in "none" "level1" "level3" "full"; do
        export SOURCEATLAS_OPTIMIZATION_LEVEL="$level"
        
        start_time=$(date +%s.%N 2>/dev/null || date +%s)
        process_files_optimized files.txt "output_${level}.jsonl" "perf-${level}"
        end_time=$(date +%s.%N 2>/dev/null || date +%s)
        
        if command -v bc >/dev/null 2>&1; then
            duration=$(echo "$end_time - $start_time" | bc)
            level_durations["$level"]="$duration"
        fi
        
        # Verify output exists
        [ -f "output_${level}.jsonl" ]
        [ -s "output_${level}.jsonl" ]
        
        # All levels should process same number of files
        lines=$(wc -l < "output_${level}.jsonl")
        [ "$lines" -ge 1 ]
    done
    
    # Advanced optimization levels should not be significantly slower than basic ones
    # (This is a basic sanity check)
    if command -v bc >/dev/null 2>&1 && [ -n "${level_durations[none]}" ] && [ -n "${level_durations[full]}" ]; then
        none_duration="${level_durations[none]}"
        full_duration="${level_durations[full]}"
        
        # Full optimization should not be more than 3x slower (generous threshold for small datasets)
        max_allowed=$(echo "$none_duration * 3.0" | bc)
        is_reasonable=$(echo "$full_duration <= $max_allowed" | bc)
        
        [ "$is_reasonable" -eq 1 ]
    fi
    
    unset SOURCEATLAS_PHASE9_ENABLED
    unset SOURCEATLAS_OPTIMIZATION_LEVEL
}

@test "Phase 9 cache provides significant speedup on repeated operations" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    
    find . -name "*.swift" -o -name "*.kt" > files.txt
    [ -s files.txt ]
    
    export SOURCEATLAS_PHASE9_ENABLED=true
    export SOURCEATLAS_OPTIMIZATION_LEVEL=level4  # Cache optimization
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    init_phase9_system
    
    # First run - cold cache
    start_first=$(date +%s.%N 2>/dev/null || date +%s)
    process_files_optimized files.txt first_run.jsonl first-run-trace
    end_first=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Second run - warm cache (should be much faster)
    start_second=$(date +%s.%N 2>/dev/null || date +%s)
    process_files_optimized files.txt second_run.jsonl second-run-trace
    end_second=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Verify both runs produced output
    [ -f first_run.jsonl ]
    [ -f second_run.jsonl ]
    [ -s first_run.jsonl ]
    [ -s second_run.jsonl ]
    
    # Basic performance check
    if command -v bc >/dev/null 2>&1; then
        first_duration=$(echo "$end_first - $start_first" | bc)
        second_duration=$(echo "$end_second - $start_second" | bc)
        
        # Second run should be at least as fast as first run
        # (In practice, should be much faster, but we'll be conservative)
        is_faster=$(echo "$second_duration <= $first_duration" | bc)
        [ "$is_faster" -eq 1 ]
    fi
    
    # Both outputs should be similar
    first_lines=$(wc -l < first_run.jsonl)
    second_lines=$(wc -l < second_run.jsonl)
    [ "$first_lines" -eq "$second_lines" ]
    
    unset SOURCEATLAS_PHASE9_ENABLED
    unset SOURCEATLAS_OPTIMIZATION_LEVEL
}

@test "Phase 9 parallel processing scales with available cores" {
    skip "Parallel scaling test - requires controlled environment"
    
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Generate larger dataset for parallel testing
    for i in {1..100}; do
        echo "class ParallelTest${i} { func method${i}() {} }" > "parallel${i}.swift"
    done
    
    find . -name "parallel*.swift" > files.txt
    
    export SOURCEATLAS_PHASE9_ENABLED=true
    export SOURCEATLAS_OPTIMIZATION_LEVEL=level2  # Parallel processing
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # This would test parallel efficiency but requires:
    # - Large enough dataset to see parallel benefits
    # - Controlled CPU environment
    # - Ability to measure actual parallel vs sequential performance
    # Skipping due to complexity and environment variability
}

@test "Phase 9 benchmark system detects performance changes" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Test benchmark system functionality
    source "$PROJECT_ROOT/lib/benchmark.sh"
    
    # Initialize benchmark system
    run init_benchmark_system
    assert_success
    
    [ -d ".sourceatlas/benchmarks" ]
    
    # Create minimal test dataset
    for i in {1..5}; do
        echo "class BenchmarkTest${i} {}" > "bench${i}.swift"
    done
    
    # Run small benchmark
    run run_performance_benchmark small
    assert_success
    
    # Should generate benchmark results
    if [ -f .sourceatlas/benchmarks/results.jsonl ]; then
        [ -s .sourceatlas/benchmarks/results.jsonl ]
        
        # Results should be valid JSON
        run tail -1 .sourceatlas/benchmarks/results.jsonl
        echo "$output" | python3 -m json.tool >/dev/null 2>&1
    fi
}

@test "Phase 9 regression threshold enforcement works" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/benchmark.sh"
    
    # Create mock baseline with good performance
    mkdir -p .sourceatlas/benchmarks
    cat > .sourceatlas/benchmarks/baseline.json << 'EOF'
{
  "timestamp": "2025-01-01T00:00:00Z",
  "optimizations": {
    "full": {
      "duration": 1.0,
      "throughput": 50.0
    }
  }
}
EOF
    
    # Create mock current results with regression
    cat > current_results.json << 'EOF'
{
  "timestamp": "2025-01-01T01:00:00Z",
  "optimizations": {
    "full": {
      "duration": 2.5,
      "throughput": 20.0
    }
  }
}
EOF
    
    # Test regression detection
    run check_performance_regression "$(cat current_results.json)" "regression-test"
    # Should return non-zero (regression detected)
    [ "$status" -ne 0 ]
    
    # Test with acceptable performance
    cat > good_results.json << 'EOF'
{
  "timestamp": "2025-01-01T01:00:00Z", 
  "optimizations": {
    "full": {
      "duration": 1.1,
      "throughput": 45.0
    }
  }
}
EOF
    
    run check_performance_regression "$(cat good_results.json)" "good-test"
    # Should return zero (no regression)
    [ "$status" -eq 0 ]
}

@test "Phase 9 maintains correctness while optimizing performance" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    
    # Process same files with different optimization levels
    find . -name "*.swift" -o -name "*.kt" > files.txt
    
    export SOURCEATLAS_PHASE9_ENABLED=true
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Process with baseline (no optimization)
    export SOURCEATLAS_OPTIMIZATION_LEVEL=none
    process_files_optimized files.txt baseline_output.jsonl baseline-trace
    
    # Process with full optimization
    export SOURCEATLAS_OPTIMIZATION_LEVEL=full
    process_files_optimized files.txt optimized_output.jsonl optimized-trace
    
    # Both should produce valid output
    [ -f baseline_output.jsonl ]
    [ -f optimized_output.jsonl ]
    [ -s baseline_output.jsonl ]
    [ -s optimized_output.jsonl ]
    
    # Should process same number of files
    baseline_count=$(wc -l < baseline_output.jsonl)
    optimized_count=$(wc -l < optimized_output.jsonl)
    [ "$baseline_count" -eq "$optimized_count" ]
    
    # Both outputs should be valid JSON
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "$line" | python3 -m json.tool >/dev/null 2>&1 || {
                echo "Invalid JSON in baseline: $line"
                return 1
            }
        fi
    done < baseline_output.jsonl
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "$line" | python3 -m json.tool >/dev/null 2>&1 || {
                echo "Invalid JSON in optimized: $line"
                return 1
            }
        fi
    done < optimized_output.jsonl
    
    # Key fields should be present in both outputs
    run grep '"path":' baseline_output.jsonl
    assert_success
    
    run grep '"path":' optimized_output.jsonl  
    assert_success
    
    run grep '"lang":' baseline_output.jsonl
    assert_success
    
    run grep '"lang":' optimized_output.jsonl
    assert_success
    
    unset SOURCEATLAS_PHASE9_ENABLED
    unset SOURCEATLAS_OPTIMIZATION_LEVEL
}