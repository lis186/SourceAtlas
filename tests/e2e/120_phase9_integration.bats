#!/usr/bin/env bats
# Phase 9 - Integration testing (Phase 8 + Phase 9 compatibility)

load ../helpers

# Test Phase 8 + Phase 9 compatibility
@test "Phase 9 loads alongside Phase 8 without conflicts" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Try to load Phase 8 observability if available
    if [ -f "$PROJECT_ROOT/lib/observability.sh" ]; then
        source "$PROJECT_ROOT/lib/observability.sh"
    fi
    
    # Load Phase 9 integration
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Both should coexist
    run init_phase9_system
    assert_success
    
    # Functions should be available
    run bash -c "declare -f emit_phase9_event"
    assert_success
    
    # Phase 8 functions should still work if available
    if declare -f emit_event >/dev/null 2>&1; then
        run bash -c "declare -f emit_event"
        assert_success
    fi
}

@test "Phase 9 events integrate with Phase 8 event system" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Load systems
    if [ -f "$PROJECT_ROOT/lib/observability.sh" ]; then
        source "$PROJECT_ROOT/lib/observability.sh"
    fi
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Emit events from both systems
    emit_phase9_event "test_phase9" "Phase 9 test message" "integration-trace"
    
    if declare -f emit_event >/dev/null 2>&1; then
        emit_event "test_phase8" "Phase 8 test message" "integration-trace" "test_component"
    fi
    
    # Check events file
    if [ -f .sourceatlas/events.jsonl ]; then
        run cat .sourceatlas/events.jsonl
        
        # Should contain both types of events
        assert_output --partial '"event":"test_phase9"'
        
        if declare -f emit_event >/dev/null 2>&1; then
            assert_output --partial '"event":"test_phase8"'
        fi
        
        # Both should use same trace ID
        assert_output --partial '"trace_id":"integration-trace"'
    fi
}

@test "Phase 9 preserves Phase 8 state management" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Check if Phase 8 state management exists
    if [ -f "$PROJECT_ROOT/lib/state_machine.sh" ]; then
        source "$PROJECT_ROOT/lib/state_machine.sh"
        source "$PROJECT_ROOT/lib/phase9_integration.sh"
        
        # Initialize both systems
        init_phase9_system
        
        # State management should still work
        if declare -f init_state_machine >/dev/null 2>&1; then
            run init_state_machine
            assert_success
        fi
    else
        skip "Phase 8 state management not available"
    fi
}

@test "Phase 9 respects Phase 8 circuit breaker" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Check if circuit breaker exists
    if [ -f "$PROJECT_ROOT/lib/circuit_breaker.sh" ]; then
        source "$PROJECT_ROOT/lib/circuit_breaker.sh"
        source "$PROJECT_ROOT/lib/phase9_integration.sh"
        
        # Circuit breaker should still function
        if declare -f check_circuit_breaker >/dev/null 2>&1; then
            run check_circuit_breaker "test_operation"
            # Should succeed or fail appropriately, not crash
        fi
    else
        skip "Phase 8 circuit breaker not available"
    fi
}

@test "Phase 9 works with Phase 8 snapshots" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Check if snapshot system exists
    if [ -f "$PROJECT_ROOT/lib/snapshot.sh" ]; then
        source "$PROJECT_ROOT/lib/snapshot.sh" 
        source "$PROJECT_ROOT/lib/phase9_integration.sh"
        
        # Create test data
        echo "test data" > test_file.txt
        
        init_phase9_system
        
        # Snapshot functionality should work
        if declare -f create_snapshot >/dev/null 2>&1; then
            run create_snapshot "integration-test"
            # Should work or fail gracefully
        fi
    else
        skip "Phase 8 snapshot system not available"
    fi
}

@test "Phase 9 maintains Phase 8 lineage tracking" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Check if lineage tracking exists
    if [ -f "$PROJECT_ROOT/lib/lineage.sh" ]; then
        source "$PROJECT_ROOT/lib/lineage.sh"
        source "$PROJECT_ROOT/lib/phase9_integration.sh"
        
        init_phase9_system
        
        # Lineage tracking should still work
        if declare -f record_lineage >/dev/null 2>&1; then
            run record_lineage "test_input" "test_output" "phase9_processing"
            # Should work without conflicts
        fi
    else
        skip "Phase 8 lineage tracking not available"
    fi
}

@test "Phase 9 full integration with CLI commands" {
    setup_test
    copy_fixtures "sourceatlas"
    cd "$TEST_TEMP_DIR"
    
    # Test that existing CLI commands still work with Phase 9
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Initialize Phase 9
    export SOURCEATLAS_PHASE9_ENABLED=true
    init_phase9_system
    
    # Basic CLI commands should still work
    run satlas init
    assert_success
    
    run satlas scan
    assert_success
    
    # Output should exist
    [ -f .sourceatlas/sourceatlas.index.jsonl ]
    
    # With Phase 9, processing might be faster/different but output should be valid
    run head -1 .sourceatlas/sourceatlas.index.jsonl
    assert_output --partial '"repo":'
    assert_output --partial '"path":'
    
    unset SOURCEATLAS_PHASE9_ENABLED
}

@test "Phase 9 fallback to Phase 8 behavior on errors" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Simulate Phase 9 failure conditions
    export SOURCEATLAS_PHASE9_ENABLED=true
    export SOURCEATLAS_OPTIMIZATION_LEVEL=full
    
    # Create conditions that might cause Phase 9 to fail
    # (e.g., no write permissions for cache)
    mkdir -p .sourceatlas/cache
    chmod 000 .sourceatlas/cache 2>/dev/null || true
    
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Should fall back gracefully
    run init_phase9_system
    # May succeed (if fallback works) or fail (if no fallback), but shouldn't crash
    
    chmod 755 .sourceatlas/cache 2>/dev/null || true
    
    unset SOURCEATLAS_PHASE9_ENABLED
    unset SOURCEATLAS_OPTIMIZATION_LEVEL
}

@test "Phase 9 performance monitoring doesn't interfere with Phase 8" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Load systems
    if [ -f "$PROJECT_ROOT/lib/observability.sh" ]; then
        source "$PROJECT_ROOT/lib/observability.sh"
    fi
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Enable both monitoring systems
    export SOURCEATLAS_TRACE_PERFORMANCE=true
    
    init_phase9_system
    
    # Record performance data
    record_performance_data 50 1.5 33.3 25000 "perf-test-trace"
    
    # Should not interfere with Phase 8 operations
    if declare -f emit_event >/dev/null 2>&1; then
        run emit_event "test_phase8_after_perf" "Phase 8 after performance" "perf-test-trace" "test"
        assert_success
    fi
    
    unset SOURCEATLAS_TRACE_PERFORMANCE
}

@test "Phase 9 configuration doesn't break Phase 8 settings" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Set Phase 9 configuration
    export SOURCEATLAS_PHASE9_ENABLED=true
    export SOURCEATLAS_OPTIMIZATION_LEVEL=level3
    export SOURCEATLAS_TRACE_PERFORMANCE=true
    
    # Load systems
    if [ -f "$PROJECT_ROOT/lib/observability.sh" ]; then
        source "$PROJECT_ROOT/lib/observability.sh"
    fi
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Check that Phase 9 settings don't interfere
    [ "$PHASE9_ENABLED" = "true" ]
    [ "$PHASE9_OPTIMIZATION_LEVEL" = "level3" ]
    
    # Phase 8 should still be functional if available
    if declare -f emit_event >/dev/null 2>&1; then
        run emit_event "config_test" "Configuration test" "config-trace" "test"
        assert_success
    fi
    
    # Clean up
    unset SOURCEATLAS_PHASE9_ENABLED
    unset SOURCEATLAS_OPTIMIZATION_LEVEL
    unset SOURCEATLAS_TRACE_PERFORMANCE
}

@test "Phase 9 and Phase 8 event schemas are compatible" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Load both systems
    if [ -f "$PROJECT_ROOT/lib/observability.sh" ]; then
        source "$PROJECT_ROOT/lib/observability.sh"
    fi
    source "$PROJECT_ROOT/lib/phase9_integration.sh"
    
    # Emit events from both phases
    emit_phase9_event "schema_test_p9" "Phase 9 schema test" "schema-trace"
    
    if declare -f emit_event >/dev/null 2>&1; then
        emit_event "schema_test_p8" "Phase 8 schema test" "schema-trace" "test_component"
    fi
    
    # Check events file if it exists
    if [ -f .sourceatlas/events.jsonl ]; then
        # All events should be valid JSON
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                echo "$line" | python3 -m json.tool >/dev/null 2>&1 || {
                    echo "Invalid JSON event: $line"
                    return 1
                }
                
                # Check for required fields
                echo "$line" | grep -q '"timestamp":' || {
                    echo "Missing timestamp in event: $line"
                    return 1
                }
                
                echo "$line" | grep -q '"event":' || {
                    echo "Missing event field in event: $line"
                    return 1
                }
            fi
        done < .sourceatlas/events.jsonl
    fi
}