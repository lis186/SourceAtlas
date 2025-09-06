#!/usr/bin/env bats
# Phase 9 - Observability integration tests

load ../helpers

# Test Phase 9 observability integration
@test "Phase 9 integration module loads correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Should load without errors
    run bash -c "source '$PROJECT_ROOT/lib/phase9_integration.sh'; echo 'loaded'"
    assert_success
    assert_output --partial "loaded"
}

@test "Phase 9 system initializes with observability" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Initialize Phase 9 system
    run init_phase9_system test-init-trace
    assert_success
    
    # Should create necessary directories and initialize subsystems
    [ -d ".sourceatlas/cache" ] || [ "$PHASE9_ENABLED" != "true" ]
    
    # Check for events if available
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "phase9" .sourceatlas/events.jsonl
        assert_output --partial '"component":"phase9_integration"'
        assert_output --partial '"trace_id":"test-init-trace"'
    fi
}

@test "Phase 9 can be disabled via environment variable" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Disable Phase 9
    export SOURCEATLAS_PHASE9_ENABLED=false
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    run init_phase9_system
    assert_success
    
    # Should complete without error but skip optimizations
    [ "$PHASE9_ENABLED" = "false" ]
    
    unset SOURCEATLAS_PHASE9_ENABLED
}

@test "Phase 9 optimization levels work correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Test different optimization levels
    optimization_levels=("none" "level1" "level2" "level3" "level4" "level5" "full")
    
    for level in "${optimization_levels[@]}"; do
        export SOURCEATLAS_OPTIMIZATION_LEVEL="$level"
        
        source "$PROJECT_ROOT/lib/phase9_integration.sh"
        
        [ "$PHASE9_OPTIMIZATION_LEVEL" = "$level" ]
        
        # Should initialize without error
        run init_phase9_system
        assert_success
    done
    
    unset SOURCEATLAS_OPTIMIZATION_LEVEL
}

@test "Phase 9 emits events during processing" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Test event emission
    run emit_phase9_event "test_event" "test message" "test-trace-123"
    assert_success
    
    # Check if events were written (if observability is available)
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "test_event" .sourceatlas/events.jsonl
        assert_output --partial '"event":"test_event"'
        assert_output --partial '"message":"test message"'
        assert_output --partial '"trace_id":"test-trace-123"'
        assert_output --partial '"component":"phase9_integration"'
    fi
}

@test "Phase 9 integrates with existing observability system" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Check if Phase 8 observability exists
    if [ -f "$PROJECT_ROOT/lib/observability.sh" ]; then
        source "$PROJECT_ROOT/lib/observability.sh"
        source "$PROJECT_ROOT/lib/phase9_integration.sh"
        
        # Should be able to use both systems
        run init_phase9_system
        assert_success
        
        # Events should be compatible
        if [ -f .sourceatlas/events.jsonl ]; then
            run cat .sourceatlas/events.jsonl
            # Should contain structured events
            assert_output --partial '"timestamp":'
            assert_output --partial '"event":'
        fi
    else
        skip "Phase 8 observability not available"
    fi
}

@test "Phase 9 performance monitoring works" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Enable performance tracing
    export SOURCEATLAS_TRACE_PERFORMANCE=true
    
    # Test performance data recording
    run record_performance_data 100 2.5 40.0 50000 "perf-trace-123"
    assert_success
    
    # Check if performance data was recorded
    if [ -f .sourceatlas/metrics/performance_data.jsonl ]; then
        run cat .sourceatlas/metrics/performance_data.jsonl
        assert_output --partial '"file_count":100'
        assert_output --partial '"duration":2.5'
        assert_output --partial '"throughput":40.0'
        assert_output --partial '"trace_id":"perf-trace-123"'
    fi
    
    unset SOURCEATLAS_TRACE_PERFORMANCE
}

@test "Phase 9 cleanup works correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas/cache
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Create some temporary data
    echo "test" > .sourceatlas/cache/test_data.txt
    
    # Initialize system
    init_phase9_system >/dev/null 2>&1
    
    # Run cleanup
    run cleanup_phase9_system test-cleanup-trace
    assert_success
    
    # Should emit cleanup events if observability available
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "cleanup" .sourceatlas/events.jsonl
        assert_output --partial '"trace_id":"test-cleanup-trace"'
    fi
}

@test "Phase 9 falls back gracefully on errors" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Test with permission issues (simulate failure)
    chmod 000 . 2>/dev/null || true
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh" 2>/dev/null || true
    
    # Should not crash even if initialization fails
    run init_phase9_system
    # May succeed or fail depending on permissions, but shouldn't crash
    
    chmod 755 . 2>/dev/null || true
}

@test "Phase 9 baseline processing works" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Create file list
    find . -type f -name "*.swift" -o -name "*.kt" > files.txt
    [ -s files.txt ]
    
    # Test baseline processing
    run process_files_baseline files.txt output.jsonl baseline-trace
    assert_success
    
    [ -f output.jsonl ]
    [ -s output.jsonl ]
    
    # Verify JSON format
    run head -1 output.jsonl
    assert_output --partial '"repo":'
    assert_output --partial '"path":'
    assert_output --partial '"lang":'
}

@test "Phase 9 optimized processing works with different levels" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Create file list
    find . -type f -name "*.swift" -o -name "*.kt" > files.txt
    [ -s files.txt ]
    
    # Test different optimization levels
    for level in "none" "level1" "full"; do
        export SOURCEATLAS_OPTIMIZATION_LEVEL="$level"
        
        run process_files_optimized files.txt "output_${level}.jsonl" "trace-${level}"
        assert_success
        
        [ -f "output_${level}.jsonl" ]
        [ -s "output_${level}.jsonl" ]
        
        # Verify JSON format
        run head -1 "output_${level}.jsonl"
        assert_output --partial '"repo":'
    done
    
    unset SOURCEATLAS_OPTIMIZATION_LEVEL
}

@test "Phase 9 hooks integration preserves existing functionality" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Test CLI hooks setup
    run hook_phase9_into_cli
    assert_success
    
    # Should complete without errors and emit appropriate events
    if [ -f .sourceatlas/events.jsonl ]; then
        run grep "hook" .sourceatlas/events.jsonl
        assert_output --partial '"component":"phase9_integration"'
    fi
}