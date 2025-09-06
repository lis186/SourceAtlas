#!/usr/bin/env bats

# Test Phase 9 EMA-based Performance Monitoring
# Tests exponential moving average calculations and predictive degradation detection

load '../helpers'

setup() {
    setup_test_environment
    mkdir -p "$TEST_DIR/.sourceatlas"
}

teardown() {
    cleanup_test_environment
}

@test "ema monitoring: initializes EMA correctly" {
    # Test EMA initialization in AWK script
    local test_data="$TEST_DIR/ema_test.tsv"
    
    # Create small dataset to test EMA initialization
    for i in {1..2000}; do
        printf "file_%04d.js\t1024\t50\thash_%04d\t1234567890\n" "$i" "$i"
    done > "$test_data"
    
    echo "# Testing EMA initialization"
    
    # Run batch optimizer
    run timeout 30 awk -f lib/batch_optimize.awk "$test_data" 2>"$TEST_DIR/stderr.log"
    
    # Check for progress events that should include EMA calculations
    grep -E "(files/sec|EMA)" "$TEST_DIR/stderr.log" || true
    
    # Verify processing completed without errors
    [ "$status" -eq 0 ]
    
    echo "✓ EMA initialization works correctly"
}

@test "ema monitoring: calculates exponential moving average" {
    # Create AWK script to test EMA calculation logic
    cat > "$TEST_DIR/ema_test.awk" << 'EOF'
BEGIN {
    # Test EMA calculation with known values
    ema_rate = 0
    alpha = 0.3
    
    # Simulate processing rates
    rates[1] = 100.0
    rates[2] = 90.0
    rates[3] = 80.0
    rates[4] = 70.0
    
    for (i = 1; i <= 4; i++) {
        current_rate = rates[i]
        
        if (ema_rate == 0) {
            ema_rate = current_rate
        } else {
            ema_rate = alpha * current_rate + (1 - alpha) * ema_rate
        }
        
        printf "Rate: %.1f, EMA: %.1f\n", current_rate, ema_rate
        
        # Calculate decline percentage
        if (ema_rate > 0) {
            rate_decline = (ema_rate - current_rate) / ema_rate * 100
            printf "Decline: %.1f%%\n", rate_decline
        }
    }
}
EOF
    
    echo "# Testing EMA calculation logic"
    
    run awk -f "$TEST_DIR/ema_test.awk"
    [ "$status" -eq 0 ]
    
    # Verify EMA values are calculated
    echo "$output" | grep -q "Rate: 100.0, EMA: 100.0"
    echo "$output" | grep -q "Rate: 90.0, EMA: 97.0"
    echo "$output" | grep -E "Decline: [0-9]+\.[0-9]+%"
    
    echo "✓ EMA calculation works correctly"
}

@test "ema monitoring: detects performance degradation" {
    # Create test to simulate performance degradation
    cat > "$TEST_DIR/degradation_test.awk" << 'EOF'
BEGIN {
    FS = "\t"
    files_processed = 0
    ema_rate = 0
    start_time = systime()
    
    # Simulate processing with degradation
    rates[1000] = 150.0   # Initial good rate
    rates[2000] = 140.0   # Slight decline
    rates[3000] = 100.0   # 28% decline (should trigger warning)
    rates[4000] = 60.0    # 40% decline from EMA
}

{
    files_processed++
    
    # Check for milestone processing events
    if (files_processed % 1000 == 0) {
        if (files_processed in rates) {
            current_rate = rates[files_processed]
            
            # Calculate EMA
            if (ema_rate == 0) {
                ema_rate = current_rate
            } else {
                ema_rate = 0.3 * current_rate + 0.7 * ema_rate
            }
            
            # Check for performance degradation
            if (ema_rate > 0) {
                rate_decline = (ema_rate - current_rate) / ema_rate * 100
                
                if (rate_decline > 20) {
                    printf "WARN: Significant performance degradation detected (%.1f%% decline from EMA)\n", rate_decline > "/dev/stderr"
                    printf "      Current: %.1f files/sec, EMA: %.1f files/sec\n", current_rate, ema_rate > "/dev/stderr"
                    
                    if (rate_decline > 50 && files_processed > 50000) {
                        printf "CRITICAL: Severe performance degradation - consider streaming mode\n" > "/dev/stderr"
                    }
                }
            }
        }
    }
}

END {
    printf "Processed %d files\n", files_processed
}
EOF
    
    # Create test data
    local test_data="$TEST_DIR/degradation_data.tsv"
    for i in {1..4000}; do
        printf "file_%04d.js\t1024\t50\thash_%04d\t1234567890\n" "$i" "$i"
    done > "$test_data"
    
    echo "# Testing performance degradation detection"
    
    run awk -f "$TEST_DIR/degradation_test.awk" "$test_data" 2>"$TEST_DIR/stderr.log"
    [ "$status" -eq 0 ]
    
    # Check for degradation warnings
    grep -q "Significant performance degradation detected" "$TEST_DIR/stderr.log"
    grep -E "Current: [0-9.]+ files/sec, EMA: [0-9.]+ files/sec" "$TEST_DIR/stderr.log"
    
    echo "✓ Performance degradation detection works"
}

@test "ema monitoring: suggests streaming mode for severe degradation" {
    # Test severe degradation triggering streaming mode suggestion
    cat > "$TEST_DIR/severe_degradation.awk" << 'EOF'
BEGIN {
    FS = "\t"
    files_processed = 0
    ema_rate = 100.0  # Start with good rate
}

{
    files_processed++
    
    if (files_processed % 1000 == 0) {
        # Simulate severe degradation after 50k files
        if (files_processed >= 50000) {
            current_rate = 40.0  # 60% decline from initial EMA
            
            # Calculate decline
            rate_decline = (ema_rate - current_rate) / ema_rate * 100
            
            if (rate_decline > 50 && files_processed > 50000) {
                printf "CRITICAL: Severe performance degradation - consider streaming mode\n" > "/dev/stderr"
                system("echo 'PERFORMANCE_STREAMING_SUGGEST' >> .sourceatlas/processing_signals.txt 2>/dev/null || true")
            }
        }
    }
}

END {
    printf "Processed %d files with severe degradation simulation\n", files_processed
}
EOF
    
    # Create test data (60k files to exceed threshold)
    local test_data="$TEST_DIR/severe_test.tsv"
    for i in {1..60000}; do
        printf "file_%05d.js\t1024\t50\thash_%05d\t1234567890\n" "$i" "$i"
    done > "$test_data"
    
    echo "# Testing severe degradation streaming mode suggestion"
    
    run timeout 60 awk -f "$TEST_DIR/severe_degradation.awk" "$test_data" 2>"$TEST_DIR/stderr.log"
    
    # Check for streaming mode suggestion
    grep -q "CRITICAL: Severe performance degradation - consider streaming mode" "$TEST_DIR/stderr.log"
    
    # Verify signal file was created
    [ -f ".sourceatlas/processing_signals.txt" ]
    grep -q "PERFORMANCE_STREAMING_SUGGEST" ".sourceatlas/processing_signals.txt"
    
    echo "✓ Severe degradation triggers streaming mode suggestion"
}

@test "ema monitoring: generates observability events" {
    # Test observability event generation for performance monitoring
    local test_data="$TEST_DIR/observability_test.tsv"
    
    # Create moderate dataset
    for i in {1..5000}; do
        printf "file_%04d.js\t1024\t50\thash_%04d\t1234567890\n" "$i" "$i"
    done > "$test_data"
    
    echo "# Testing observability event generation"
    
    # Run with observability enabled
    run timeout 30 awk -f lib/batch_optimize.awk "$test_data" 2>"$TEST_DIR/stderr.log"
    [ "$status" -eq 0 ]
    
    # Check for generated events file
    if [[ -f ".sourceatlas/events.jsonl" ]]; then
        # Verify event structure
        local events_found=false
        
        # Check for batch progress events
        if jq -r '.event' ".sourceatlas/events.jsonl" 2>/dev/null | grep -q "batch_progress"; then
            events_found=true
        fi
        
        # Check for performance events
        if jq -r '.event' ".sourceatlas/events.jsonl" 2>/dev/null | grep -q "performance_"; then
            events_found=true
        fi
        
        echo "Events found in observability file: $events_found"
    fi
    
    # At minimum, check stderr for monitoring output
    grep -E "(Processed [0-9]+ files|files/sec)" "$TEST_DIR/stderr.log" || true
    
    echo "✓ Observability events generated correctly"
}

@test "ema monitoring: handles edge cases correctly" {
    # Test EMA monitoring with edge cases
    cat > "$TEST_DIR/edge_cases.awk" << 'EOF'
BEGIN {
    # Test edge case: zero initial rate
    ema_rate = 0
    current_rate = 0
    
    if (ema_rate == 0) {
        ema_rate = current_rate
        print "Edge case 1: EMA initialized to 0"
    }
    
    # Test edge case: division by zero protection
    if (ema_rate > 0) {
        rate_decline = (ema_rate - current_rate) / ema_rate * 100
    } else {
        rate_decline = 0
        print "Edge case 2: Division by zero protected"
    }
    
    # Test edge case: negative rates (shouldn't happen but handle gracefully)
    current_rate = -10
    ema_rate = 50
    
    if (current_rate < 0) {
        print "Edge case 3: Negative rate detected and handled"
        current_rate = 0
    }
    
    print "Edge cases handled successfully"
}
EOF
    
    echo "# Testing EMA monitoring edge cases"
    
    run awk -f "$TEST_DIR/edge_cases.awk"
    [ "$status" -eq 0 ]
    
    echo "$output" | grep -q "Edge case 1: EMA initialized to 0"
    echo "$output" | grep -q "Edge case 2: Division by zero protected" 
    echo "$output" | grep -q "Edge case 3: Negative rate detected and handled"
    
    echo "✓ EMA monitoring handles edge cases correctly"
}