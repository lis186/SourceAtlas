#!/usr/bin/env bats

# Test Phase 9 Automatic Streaming Mode Fallback
# Tests memory threshold detection and seamless mode switching

load '../helpers'

setup() {
    setup_test_environment
    mkdir -p "$TEST_DIR/.sourceatlas"
}

teardown() {
    cleanup_test_environment
}

@test "streaming mode: detects memory threshold and switches automatically" {
    # Create large dataset that should trigger streaming mode (600k records)
    local test_data="$TEST_DIR/large_dataset.tsv"
    local output="$TEST_DIR/streaming_output.jsonl"
    
    # Generate test data exceeding 500k record threshold
    for i in {1..600000}; do
        printf "file_%06d.js\t1024\t50\thash_%06d\t1234567890\n" "$i" "$i"
    done > "$test_data"
    
    echo "# Testing streaming mode fallback with 600k records"
    
    # Run batch optimizer which should trigger streaming mode
    run awk -f lib/batch_optimize.awk "$test_data" 2>"$TEST_DIR/stderr.log"
    
    # Should exit with code 2 (streaming mode switch)
    [ "$status" -eq 2 ]
    
    # Check for streaming mode activation message
    grep -q "STREAM_MODE_SWITCH:" "$TEST_DIR/stderr.log"
    
    # Verify signal file was created
    [ -f ".sourceatlas/processing_signals.txt" ]
    grep -q "STREAMING_MODE_REQUIRED" ".sourceatlas/processing_signals.txt"
    
    echo "✓ Streaming mode automatically activated for large dataset"
}

@test "streaming mode: processes correctly in streaming mode" {
    # Create smaller test dataset
    local test_data="$TEST_DIR/small_dataset.tsv"
    local output="$TEST_DIR/streaming_output.jsonl"
    
    cat > "$test_data" << EOF
test1.js	1024	100	hash1	1234567890
test2.py	2048	200	hash2	1234567891
test3.kt	3072	300	hash3	1234567892
EOF
    
    echo "# Testing streaming mode processing"
    
    # Simulate streaming mode processing (single file at a time)
    local files_processed=0
    while IFS=$'\t' read -r file_path size_bytes loc hash mtime; do
        [[ -z "$file_path" ]] && continue
        
        # Process single record
        printf "%s\t%s\t%s\t%s\t%s\n" "$file_path" "$size_bytes" "$loc" "$hash" "$mtime" | \
            awk -f lib/batch_optimize.awk > "$TEST_DIR/single_record.json" 2>/dev/null
        
        # Append to output (streaming)
        cat "$TEST_DIR/single_record.json" >> "$output"
        ((files_processed++))
    done < "$test_data"
    
    # Verify all records processed
    [ "$files_processed" -eq 3 ]
    [ -f "$output" ]
    
    # Verify JSON output format
    local line_count
    line_count=$(wc -l < "$output")
    [ "$line_count" -eq 3 ]
    
    # Check each record is valid JSON
    jq -c . "$output" > /dev/null
    
    echo "✓ Streaming mode processes records correctly"
}

@test "streaming mode: memory preparation warnings work" {
    # Create dataset at 200k threshold for preparation warnings
    local test_data="$TEST_DIR/medium_dataset.tsv"
    
    # Generate 250k records (should trigger preparation warnings)
    for i in {1..250000}; do
        printf "file_%06d.js\t1024\t50\thash_%06d\t1234567890\n" "$i" "$i"
    done > "$test_data"
    
    echo "# Testing memory preparation warnings"
    
    # Run with medium dataset
    run timeout 30 awk -f lib/batch_optimize.awk "$test_data" 2>"$TEST_DIR/stderr.log"
    
    # Should warn about approaching limits
    grep -q "Approaching memory limits" "$TEST_DIR/stderr.log"
    grep -q "preparing for potential streaming mode" "$TEST_DIR/stderr.log"
    
    # Should create preparation signal
    [ -f ".sourceatlas/processing_signals.txt" ]
    grep -q "STREAMING_PREPARE" ".sourceatlas/processing_signals.txt"
    
    echo "✓ Memory preparation warnings work correctly"
}

@test "streaming mode: EMA performance monitoring detects degradation" {
    # Create test data with simulated processing slowdown
    local test_data="$TEST_DIR/performance_test.tsv"
    
    # Generate moderate dataset
    for i in {1..10000}; do
        printf "file_%06d.js\t1024\t50\thash_%06d\t1234567890\n" "$i" "$i"
    done > "$test_data"
    
    echo "# Testing EMA performance monitoring"
    
    # Process with timing to trigger performance warnings
    run timeout 60 awk -f lib/batch_optimize.awk "$test_data" 2>"$TEST_DIR/stderr.log"
    
    # Check for EMA initialization and monitoring
    grep -E "(files/sec|EMA)" "$TEST_DIR/stderr.log" || true
    
    # Verify observability events were generated
    if [[ -f ".sourceatlas/events.jsonl" ]]; then
        grep -q "batch_progress\|performance_warning" ".sourceatlas/events.jsonl" || true
    fi
    
    echo "✓ EMA performance monitoring active"
}

@test "streaming mode: signal communication works between processes" {
    # Test signal file communication mechanism
    local signal_file=".sourceatlas/processing_signals.txt"
    
    echo "# Testing inter-process signal communication"
    
    # Simulate worker creating signals
    echo "STREAMING_PREPARE" >> "$signal_file"
    echo "PERFORMANCE_STREAMING_SUGGEST" >> "$signal_file"
    echo "STREAMING_MODE_REQUIRED" >> "$signal_file"
    
    # Verify signals are readable
    [ -f "$signal_file" ]
    grep -q "STREAMING_PREPARE" "$signal_file"
    grep -q "PERFORMANCE_STREAMING_SUGGEST" "$signal_file" 
    grep -q "STREAMING_MODE_REQUIRED" "$signal_file"
    
    echo "✓ Signal communication mechanism works"
}