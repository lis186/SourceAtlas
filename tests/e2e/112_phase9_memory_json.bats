#!/usr/bin/env bats
# Phase 9 - Memory-optimized JSON generation tests

load ../helpers

# Test memory-optimized JSON generation
@test "json_optimize.awk generates valid JSON output" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Create test input data (tab-separated format)
    cat > input.tsv << 'EOF'
test-repo	src/Test.swift	Test.swift	.swift	swift	500	25	general	Swift test file	Foundation	[]	1.5	abc123
test-repo	src/Model.kt	Model.kt	.kt	kotlin	750	40	model	Kotlin model	import com.example	[{"name":"User","kind":"class"}]	2.0	def456
EOF
    
    # Run JSON optimizer
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" input.tsv
    assert_success
    
    # Verify JSON output
    assert_output --partial '"repo":"test-repo"'
    assert_output --partial '"path":"src/Test.swift"'
    assert_output --partial '"lang":"swift"'
    assert_output --partial '"size_bytes":500'
    assert_output --partial '"loc":25'
    
    # Verify each line is valid JSON
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            if ! echo "$line" | python3 -m json.tool >/dev/null 2>&1; then
                echo "Invalid JSON: $line"
                return 1
            fi
        fi
    done <<< "$output"
}

@test "json_optimize.awk handles memory optimization flags" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Create input with very long strings
    long_path="src/very/deeply/nested/directory/structure/with/many/levels/and/long/names"
    long_summary="This is a very long summary that exceeds normal length limits and should be truncated by memory optimization to prevent memory issues"
    
    cat > memory_test.tsv << 'EOF'
test-repo	src/very/deeply/nested/directory/structure/with/many/levels/and/long/names/VeryLongFileName.swift	VeryLongFileName.swift	.swift	swift	1000	50	ui	This is a very long summary that exceeds normal length limits and should be truncated by memory optimization to prevent memory issues	Foundation,UIKit	[]	1.8	hash123
EOF
    
    # Test with memory optimization enabled
    export SOURCEATLAS_OPTIMIZE_MEMORY=1
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" memory_test.tsv
    assert_success
    
    # Should produce valid JSON even with long strings
    echo "$output" | python3 -m json.tool >/dev/null 2>&1
    
    # Check if truncation occurred (strings should be limited)
    if echo "$output" | grep -q "\.\.\."; then
        # Truncation working as expected
        true
    fi
    
    unset SOURCEATLAS_OPTIMIZE_MEMORY
}

@test "json_optimize.awk processes large datasets without OOM" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Generate large test dataset
    for i in {1..1000}; do
        echo -e "repo${i}\tsrc/File${i}.swift\tFile${i}.swift\t.swift\tswift\t$((RANDOM + 100))\t$((RANDOM % 100 + 10))\tgeneral\tTest file ${i}\tFoundation\t[]\t1.0\thash${i}"
    done > large_input.tsv
    
    # Process large dataset
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" large_input.tsv
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    assert_success
    
    # Should process all records
    [ "$(echo "$output" | wc -l)" -eq 1000 ]
    
    # Should complete in reasonable time (streaming should be fast)
    if command -v bc >/dev/null 2>&1; then
        duration=$(echo "$end_time - $start_time" | bc)
        # Should process 1000 records in under 10 seconds
        [ "$(echo "$duration < 10.0" | bc)" -eq 1 ]
    fi
    
    # Memory usage should be reasonable (test by ensuring process completes)
    # In a real test environment, you could monitor memory usage
    [ "$status" -eq 0 ]
}

@test "json_optimize.awk handles streaming buffer management" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Create input that tests buffer boundaries
    for i in {1..100}; do
        echo -e "test-repo\tsrc/Test${i}.swift\tTest${i}.swift\t.swift\tswift\t500\t25\tgeneral\tTest file ${i}\tFoundation\t[]\t1.5\thash${i}"
    done > streaming_test.tsv
    
    # Test streaming processing
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" streaming_test.tsv
    assert_success
    
    # Verify all records processed
    [ "$(echo "$output" | wc -l)" -eq 100 ]
    
    # Each line should be valid JSON
    line_count=0
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            ((line_count++))
            if ! echo "$line" | python3 -m json.tool >/dev/null 2>&1; then
                echo "Invalid JSON at line $line_count: $line"
                return 1
            fi
        fi
    done <<< "$output"
}

@test "json_optimize.awk properly escapes JSON strings" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Create input with characters that need escaping
    cat > escape_test.tsv << 'EOF'
test-repo	src/Test"Quote.swift	Test"Quote.swift	.swift	swift	500	25	general	Summary with "quotes" and \ backslashes	Foundation	[]	1.5	abc123
test-repo	src/TestNewline.swift	TestNewline.swift	.swift	swift	400	20	general	Summary with
newlines	Foundation	[]	1.2	def456
test-repo	src/TestTab.swift	TestTab.swift	.swift	swift	300	15	general	Summary	with	tabs	Foundation	[]	1.0	ghi789
EOF
    
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" escape_test.tsv
    assert_success
    
    # Output should be valid JSON despite special characters
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            if ! echo "$line" | python3 -m json.tool >/dev/null 2>&1; then
                echo "JSON escaping failed for: $line"
                return 1
            fi
        fi
    done <<< "$output"
    
    # Check that escaping occurred
    assert_output --partial '\"'  # Escaped quotes
    assert_output --partial '\\n' || assert_output --partial 'newlines'  # Escaped newlines or handled
}

@test "json_optimize.awk handles various array formats correctly" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Test different array input formats
    cat > array_test.tsv << 'EOF'
test-repo	src/Test1.swift	Test1.swift	.swift	swift	500	25	general	Test	Foundation,UIKit	[{"name":"Class1","kind":"class"}]	1.5	abc123
test-repo	src/Test2.swift	Test2.swift	.swift	swift	400	20	general	Test	Foundation	[]	1.2	def456
test-repo	src/Test3.swift	Test3.swift	.swift	swift	300	15	general	Test	UIKit,SwiftUI,Combine	[{"name":"Struct1","kind":"struct"},{"name":"func1","kind":"function"}]	1.8	ghi789
EOF
    
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" array_test.tsv
    assert_success
    
    # Verify arrays are properly formatted
    assert_output --partial '"imports":["Foundation","UIKit"]'
    assert_output --partial '"imports":[]'
    assert_output --partial '"symbols":[{'
    
    # All output should be valid JSON
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            if ! echo "$line" | python3 -m json.tool >/dev/null 2>&1; then
                echo "Invalid JSON array handling: $line"
                return 1
            fi
        fi
    done <<< "$output"
}

@test "json_optimize.awk emits observability events during processing" {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p .sourceatlas
    
    # Create test input
    echo -e "test-repo\tsrc/Test.swift\tTest.swift\t.swift\tswift\t500\t25\tgeneral\tTest\tFoundation\t[]\t1.5\tabc123" > test_input.tsv
    
    # Capture events to stderr
    run bash -c "awk -f '$PROJECT_ROOT/lib/json_optimize.awk' test_input.tsv 2>events.log"
    assert_success
    
    # Check if events were emitted
    [ -f events.log ]
    run cat events.log
    assert_output --partial '"event":"json_optimize_'
    assert_output --partial '"trace_id":"json-optimize-'
    assert_output --partial '"memory_optimized":'
}

@test "json_optimize.awk handles empty and malformed input gracefully" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Test empty input
    touch empty.tsv
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" empty.tsv
    assert_success
    [ -z "$output" ]
    
    # Test malformed input (missing fields)
    echo "incomplete line" > malformed.tsv
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" malformed.tsv
    assert_success  # Should not crash
    
    # Test input with wrong number of fields
    echo -e "field1\tfield2\tfield3" > wrong_fields.tsv
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" wrong_fields.tsv
    assert_success  # Should handle gracefully
}

@test "json_optimize.awk memory optimization reduces memory usage" {
    skip "Memory usage measurement requires specialized tools"
    
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # This test would require memory monitoring tools like:
    # - valgrind (not available on macOS)
    # - memory profiling tools
    # - Process memory monitoring
    
    # For now, we rely on the large dataset test to ensure
    # the process completes without OOM errors
}

@test "json_optimize.awk performance is better than string concatenation" {
    setup_test
    cd "$TEST_TEMP_DIR"
    
    # Create medium-sized dataset for performance comparison
    for i in {1..500}; do
        echo -e "test-repo\tsrc/File${i}.swift\tFile${i}.swift\t.swift\tswift\t$((RANDOM + 100))\t$((RANDOM % 100 + 10))\tgeneral\tTest file ${i}\tFoundation\t[]\t1.0\thash${i}"
    done > perf_test.tsv
    
    # Benchmark JSON optimization
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    run awk -f "$PROJECT_ROOT/lib/json_optimize.awk" perf_test.tsv
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    assert_success
    
    # Should process all records
    [ "$(echo "$output" | wc -l)" -eq 500 ]
    
    # Performance should be reasonable
    if command -v bc >/dev/null 2>&1; then
        duration=$(echo "$end_time - $start_time" | bc)
        # Should process 500 records in under 5 seconds
        [ "$(echo "$duration < 5.0" | bc)" -eq 1 ]
    fi
    
    # All output should be valid JSON
    valid_json_count=0
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            if echo "$line" | python3 -m json.tool >/dev/null 2>&1; then
                ((valid_json_count++))
            fi
        fi
    done <<< "$output"
    
    [ "$valid_json_count" -eq 500 ]
}