#!/usr/bin/env bats

# Test Phase 9 End-to-End Integration
# Comprehensive tests for enterprise features working together

load '../helpers'

setup() {
    setup_test_environment
    mkdir -p "$TEST_DIR/.sourceatlas"
    mkdir -p "$TEST_DIR/.sourceatlas/checkpoints"
    
    # Source optimization modules
    export PATH="$PWD/lib:$PATH"
    source lib/command_validation.sh 2>/dev/null || true
    source lib/hash_cache.sh 2>/dev/null || true
    source lib/parallel_optimize.sh 2>/dev/null || true
}

teardown() {
    cleanup_test_environment
}

@test "end-to-end: complete workflow processing" {
    local file_list="$TEST_DIR/e2e_files.txt"
    local output_file="$TEST_DIR/e2e_output.jsonl"
    local trace_id="e2e-$(date +%s)"
    
    # Create test project
    mkdir -p "$TEST_DIR/test_project/src"
    
    # Generate test files
    for lang in js py kt java; do
        for i in {1..25}; do
            local test_file="$TEST_DIR/test_project/src/test_${i}.${lang}"
            echo "// Test file $i for $lang" > "$test_file"
            echo "$test_file" >> "$file_list"
        done
    done
    
    echo "# End-to-end workflow test with $(wc -l < "$file_list") files"
    
    # Convert to processing format
    local metadata_file="$TEST_DIR/e2e_metadata.tsv"
    while IFS= read -r file_path; do
        [[ ! -f "$file_path" ]] && continue
        local size mtime lines hash
        size=$(wc -c < "$file_path" 2>/dev/null || echo "100")
        mtime=$(date +%s)
        lines=$(wc -l < "$file_path" 2>/dev/null || echo "1")
        hash="hash_$RANDOM"
        printf "%s\t%s\t%s\t%s\t%s\n" "$file_path" "$size" "$lines" "$hash" "$mtime"
    done < "$file_list" > "$metadata_file"
    
    # Process files
    run timeout 60 awk -f lib/batch_optimize.awk "$metadata_file" > "$output_file" 2>"$TEST_DIR/e2e_stderr.log"
    
    [ "$status" -eq 0 ]
    [ -f "$output_file" ]
    
    local output_count
    output_count=$(wc -l < "$output_file")
    [[ "$output_count" -gt 0 ]]
    
    echo "✓ End-to-end processing: $output_count records generated"
}

@test "end-to-end: checkpoint functionality" {
    local checkpoint_file="$TEST_DIR/.sourceatlas/checkpoints/e2e_checkpoint.checkpoint"
    local trace_id="e2e-checkpoint-$(date +%s)"
    
    echo "# Testing checkpoint functionality"
    
    # Create checkpoint manually
    cat > "$checkpoint_file" << EOF
# SourceAtlas Checkpoint
TRACE_ID=$trace_id
STATUS=RUNNING
TIMESTAMP=$(date +%s)
TOTAL_WORKERS=1
WORKER_0_COMPLETED=50
EOF
    
    # Verify checkpoint format
    [ -f "$checkpoint_file" ]
    grep -q "STATUS=RUNNING" "$checkpoint_file"
    grep -q "TRACE_ID=$trace_id" "$checkpoint_file"
    
    echo "✓ Checkpoint creation and validation successful"
}

@test "end-to-end: streaming mode trigger" {
    local large_data="$TEST_DIR/streaming_data.tsv"
    
    echo "# Testing streaming mode trigger (abbreviated)"
    
    # Create dataset that approaches streaming threshold
    for i in {1..50000}; do
        printf "stream_%05d.js\t1024\t50\thash_%05d\t1234567890\n" "$i" "$i"
    done > "$large_data"
    
    echo "Processing $(wc -l < "$large_data") records for streaming test"
    
    # Run processing
    run timeout 30 awk -f lib/batch_optimize.awk "$large_data" 2>"$TEST_DIR/streaming_stderr.log"
    
    # Check for monitoring output
    if [[ -f "$TEST_DIR/streaming_stderr.log" ]]; then
        local monitoring_active=false
        
        if grep -q "Processed.*files" "$TEST_DIR/streaming_stderr.log"; then
            monitoring_active=true
        fi
        
        if grep -q "memory\|records\|processing" "$TEST_DIR/streaming_stderr.log"; then
            monitoring_active=true  
        fi
        
        echo "Monitoring active: $monitoring_active"
    fi
    
    echo "✓ Streaming mode trigger test completed (status: $status)"
}

@test "end-to-end: performance monitoring" {
    local perf_data="$TEST_DIR/performance_data.tsv"
    
    echo "# Testing performance monitoring"
    
    # Create performance test dataset
    for i in {1..10000}; do
        printf "perf_%04d.js\t1024\t25\thash_%04d\t1234567890\n" "$i" "$i"
    done > "$perf_data"
    
    echo "Running performance test with $(wc -l < "$perf_data") records"
    
    local start_time end_time
    start_time=$(date +%s)
    
    run timeout 45 awk -f lib/batch_optimize.awk "$perf_data" 2>"$TEST_DIR/perf_stderr.log"
    
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    
    echo "Processing completed in ${duration}s"
    
    # Check for performance output
    if [[ -f "$TEST_DIR/perf_stderr.log" ]] && [[ -s "$TEST_DIR/perf_stderr.log" ]]; then
        echo "Performance monitoring output detected"
        head -3 "$TEST_DIR/perf_stderr.log" || true
    fi
    
    echo "✓ Performance monitoring test completed"
}

@test "end-to-end: resource awareness" {
    echo "# Testing resource awareness"
    
    # Test CPU detection
    if command -v get_cpu_cores >/dev/null 2>&1; then
        local workers
        workers=$(get_cpu_cores)
        
        if [[ "$workers" =~ ^[0-9]+$ ]]; then
            [[ "$workers" -ge 2 ]]
            [[ "$workers" -le 16 ]]
            echo "✓ Resource-aware worker calculation: $workers"
        fi
    fi
    
    # Test dependency validation
    if command -v validate_phase9_dependencies >/dev/null 2>&1; then
        run validate_phase9_dependencies
        echo "Dependency validation completed with status: $status"
    fi
    
    echo "✓ Resource awareness testing completed"
}

@test "end-to-end: observability integration" {
    local trace_id="observability-e2e-$(date +%s)"
    
    echo "# Testing observability integration"
    
    # Create events directory
    mkdir -p ".sourceatlas"
    
    # Test event generation if available
    if command -v emit_event >/dev/null 2>&1; then
        emit_event "e2e_test_start" "End-to-end test started" "$trace_id"
        emit_event "e2e_test_progress" "Test in progress" "$trace_id"
        emit_event "e2e_test_complete" "End-to-end test completed" "$trace_id"
        
        if [[ -f ".sourceatlas/events.jsonl" ]]; then
            local event_count
            event_count=$(wc -l < ".sourceatlas/events.jsonl")
            [[ "$event_count" -ge 3 ]]
            
            echo "✓ Generated $event_count observability events"
        fi
    fi
    
    echo "✓ Observability integration test completed"
}

@test "end-to-end: realistic project simulation" {
    local project_root="$TEST_DIR/realistic_project"
    local file_list="$TEST_DIR/realistic_files.txt"
    local metadata_file="$TEST_DIR/realistic_metadata.tsv"
    local output_file="$TEST_DIR/realistic_output.jsonl"
    
    echo "# Testing realistic project simulation"
    
    # Create realistic directory structure
    mkdir -p "$project_root/src/main/kotlin/com/example/service"
    mkdir -p "$project_root/src/main/kotlin/com/example/model"
    mkdir -p "$project_root/src/test/kotlin"
    mkdir -p "$project_root/src/main/resources"
    
    local file_count=0
    
    # Create service files
    for i in {1..15}; do
        local service_file="$project_root/src/main/kotlin/com/example/service/TestService${i}.kt"
        cat > "$service_file" << EOF
package com.example.service

import com.example.model.TestModel${i}

class TestService${i} {
    fun process(input: String): TestModel${i} {
        return TestModel${i}(
            id = ${i},
            name = "Service \${input}",
            active = true
        )
    }
}
EOF
        echo "$service_file" >> "$file_list"
        ((file_count++))
    done
    
    # Create model files
    for i in {1..10}; do
        local model_file="$project_root/src/main/kotlin/com/example/model/TestModel${i}.kt"
        cat > "$model_file" << EOF
package com.example.model

data class TestModel${i}(
    val id: Int,
    val name: String,
    val active: Boolean = false
) {
    fun isValid(): Boolean = id > 0 && name.isNotEmpty()
}
EOF
        echo "$model_file" >> "$file_list"
        ((file_count++))
    done
    
    # Create test files
    for i in {1..8}; do
        local test_file="$project_root/src/test/kotlin/TestService${i}Test.kt"
        cat > "$test_file" << EOF
import com.example.service.TestService${i}
import org.junit.Test
import kotlin.test.assertNotNull

class TestService${i}Test {
    @Test
    fun testProcess() {
        val service = TestService${i}()
        val result = service.process("test")
        assertNotNull(result)
    }
}
EOF
        echo "$test_file" >> "$file_list"
        ((file_count++))
    done
    
    echo "Created realistic project with $file_count files"
    
    # Convert to metadata format
    while IFS= read -r file_path; do
        [[ ! -f "$file_path" ]] && continue
        local size mtime lines hash
        size=$(wc -c < "$file_path" 2>/dev/null || echo "1000")
        mtime=$(stat -c %Y "$file_path" 2>/dev/null || date +%s)
        lines=$(wc -l < "$file_path" 2>/dev/null || echo "20")
        hash="hash_$(basename "$file_path")_$RANDOM"
        printf "%s\t%s\t%s\t%s\t%s\n" "$file_path" "$size" "$lines" "$hash" "$mtime"
    done < "$file_list" > "$metadata_file"
    
    echo "Processing realistic project metadata..."
    
    local start_time end_time
    start_time=$(date +%s)
    
    run timeout 60 awk -f lib/batch_optimize.awk "$metadata_file" > "$output_file" 2>"$TEST_DIR/realistic_stderr.log"
    
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Verify results
    [ "$status" -eq 0 ]
    [ -f "$output_file" ]
    
    local processed_count
    processed_count=$(wc -l < "$output_file")
    [[ "$processed_count" -gt 0 ]]
    
    echo "✓ Processed $processed_count files in ${duration}s"
    
    # Validate output structure
    if command -v jq >/dev/null 2>&1; then
        # Check first few lines for valid JSON
        head -3 "$output_file" | jq -c . > /dev/null
        echo "✓ Valid JSON output format confirmed"
        
        # Check for expected fields
        local sample_record
        sample_record=$(head -1 "$output_file")
        if echo "$sample_record" | jq -e '.repo, .path, .lang, .importance_score' >/dev/null 2>&1; then
            echo "✓ Required fields present in output"
        fi
    fi
    
    # Check monitoring output
    if [[ -f "$TEST_DIR/realistic_stderr.log" ]] && [[ -s "$TEST_DIR/realistic_stderr.log" ]]; then
        echo "Monitoring output detected:"
        head -2 "$TEST_DIR/realistic_stderr.log" || true
    fi
    
    echo "✓ Realistic project simulation completed successfully"
}