#!/usr/bin/env bats

# Test Phase 9 Checkpoint/Restore System
# Tests atomic checkpoint creation, recovery, and state preservation

load '../helpers'

setup() {
    setup_test_environment
    mkdir -p "$TEST_DIR/.sourceatlas"
    mkdir -p "$TEST_DIR/.sourceatlas/checkpoints"
    
    # Source the parallel optimization functions
    source lib/parallel_optimize.sh
}

teardown() {
    cleanup_test_environment
}

@test "checkpoint: creates checkpoint with correct format" {
    local checkpoint_file="$TEST_DIR/.sourceatlas/checkpoints/test_checkpoint.checkpoint"
    local temp_dir="$TEST_DIR/temp_workers"
    local trace_id="test-checkpoint-$(date +%s)"
    
    mkdir -p "$temp_dir"
    
    # Create mock worker output files
    echo '{"test": "data1"}' > "$temp_dir/worker_0_output.jsonl"
    echo '{"test": "data2"}' > "$temp_dir/worker_1_output.jsonl"
    echo "100" > "$temp_dir/worker_0_count.txt"
    echo "150" > "$temp_dir/worker_1_count.txt"
    
    echo "# Testing checkpoint creation"
    
    # Create checkpoint
    run create_checkpoint "$checkpoint_file" "$temp_dir" "2" "$trace_id" "RUNNING"
    [ "$status" -eq 0 ]
    
    # Verify checkpoint file exists and has correct format
    [ -f "$checkpoint_file" ]
    
    # Check checkpoint contents
    grep -q "TRACE_ID=$trace_id" "$checkpoint_file"
    grep -q "STATUS=RUNNING" "$checkpoint_file"
    grep -q "TOTAL_WORKERS=2" "$checkpoint_file"
    grep -q "WORKER_0_COMPLETED=100" "$checkpoint_file"
    grep -q "WORKER_1_COMPLETED=150" "$checkpoint_file"
    grep -q "TIMESTAMP=" "$checkpoint_file"
    
    # Verify secure permissions
    local perms
    perms=$(stat -c "%a" "$checkpoint_file" 2>/dev/null || stat -f "%Lp" "$checkpoint_file")
    [ "$perms" = "600" ]
    
    echo "✓ Checkpoint created with correct format and secure permissions"
}

@test "checkpoint: restores from valid checkpoint" {
    local checkpoint_file="$TEST_DIR/.sourceatlas/checkpoints/restore_test.checkpoint"
    local checkpoint_dir="$TEST_DIR/.sourceatlas/checkpoints"
    local output_file="$TEST_DIR/restored_output.jsonl"
    local trace_id="restore-test-$(date +%s)"
    local current_time=$(date +%s)
    
    # Create mock preserved worker outputs
    echo '{"restored": "data1"}' > "$checkpoint_dir/worker_0_output.jsonl"
    echo '{"restored": "data2"}' > "$checkpoint_dir/worker_1_output.jsonl"
    echo '{"restored": "data3"}' > "$checkpoint_dir/worker_2_output.jsonl"
    
    # Create valid checkpoint file
    cat > "$checkpoint_file" << EOF
# SourceAtlas Parallel Processing Checkpoint
# Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
TRACE_ID=$trace_id
STATUS=RUNNING
TIMESTAMP=$current_time
TOTAL_WORKERS=3
WORKER_0_COMPLETED=50
WORKER_1_COMPLETED=75
WORKER_2_COMPLETED=100
WORKER_0_OUTPUT_LINES=1
WORKER_1_OUTPUT_LINES=1
WORKER_2_OUTPUT_LINES=1

# Worker Output Files
OUTPUT_FILE=worker_0_output.jsonl
OUTPUT_FILE=worker_1_output.jsonl
OUTPUT_FILE=worker_2_output.jsonl
EOF
    
    echo "# Testing checkpoint restoration"
    
    # Attempt restoration
    run restore_from_checkpoint "$checkpoint_file" "/dev/null" "$output_file" "$trace_id"
    [ "$status" -eq 0 ]
    
    # Verify output file was created and contains merged data
    [ -f "$output_file" ]
    
    # Check that all worker outputs were merged
    grep -q '{"restored": "data1"}' "$output_file"
    grep -q '{"restored": "data2"}' "$output_file" 
    grep -q '{"restored": "data3"}' "$output_file"
    
    # Verify line count
    local line_count
    line_count=$(wc -l < "$output_file")
    [ "$line_count" -eq 3 ]
    
    echo "✓ Checkpoint restored successfully with merged output"
}

@test "checkpoint: rejects invalid checkpoints" {
    local checkpoint_file="$TEST_DIR/.sourceatlas/checkpoints/invalid_checkpoint.checkpoint"
    local output_file="$TEST_DIR/should_not_exist.jsonl"
    local trace_id="invalid-test-$(date +%s)"
    
    echo "# Testing invalid checkpoint rejection"
    
    # Test 1: Old checkpoint (should be rejected)
    local old_time=$(($(date +%s) - 7200))  # 2 hours ago
    cat > "$checkpoint_file" << EOF
TRACE_ID=$trace_id
STATUS=RUNNING
TIMESTAMP=$old_time
TOTAL_WORKERS=1
EOF
    
    run restore_from_checkpoint "$checkpoint_file" "/dev/null" "$output_file" "$trace_id"
    [ "$status" -eq 1 ]
    [ ! -f "$output_file" ]
    
    # Test 2: Failed status checkpoint
    cat > "$checkpoint_file" << EOF
TRACE_ID=$trace_id
STATUS=FAILED
TIMESTAMP=$(date +%s)
TOTAL_WORKERS=1
EOF
    
    run restore_from_checkpoint "$checkpoint_file" "/dev/null" "$output_file" "$trace_id"
    [ "$status" -eq 1 ]
    [ ! -f "$output_file" ]
    
    echo "✓ Invalid checkpoints properly rejected"
}

@test "checkpoint: emergency checkpoint on signal works" {
    local checkpoint_file="$TEST_DIR/.sourceatlas/checkpoints/emergency_checkpoint.checkpoint"
    local temp_dir="$TEST_DIR/emergency_temp"
    local trace_id="emergency-test-$(date +%s)"
    
    mkdir -p "$temp_dir"
    
    # Create mock worker state
    echo "200" > "$temp_dir/worker_0_count.txt"
    echo '{"emergency": "test"}' > "$temp_dir/worker_0_output.jsonl"
    
    # Set global variables for signal handler
    PARALLEL_CHECKPOINT_FILE="$checkpoint_file"
    PARALLEL_TEMP_DIR="$temp_dir"
    PARALLEL_WORKER_COUNT="1"
    PARALLEL_TRACE_ID="$trace_id"
    
    echo "# Testing emergency checkpoint creation"
    
    # Simulate signal handler creating emergency checkpoint
    create_checkpoint "$checkpoint_file" "$temp_dir" "1" "$trace_id" "INTERRUPTED"
    
    # Verify emergency checkpoint was created
    [ -f "$checkpoint_file" ]
    grep -q "STATUS=INTERRUPTED" "$checkpoint_file"
    grep -q "TRACE_ID=$trace_id" "$checkpoint_file"
    
    echo "✓ Emergency checkpoint created successfully"
}

@test "checkpoint: atomic operations prevent corruption" {
    local checkpoint_file="$TEST_DIR/.sourceatlas/checkpoints/atomic_test.checkpoint"
    local temp_dir="$TEST_DIR/atomic_temp"
    local trace_id="atomic-test-$(date +%s)"
    
    mkdir -p "$temp_dir"
    
    # Create worker data
    echo "100" > "$temp_dir/worker_0_count.txt"
    
    echo "# Testing atomic checkpoint operations"
    
    # Create initial checkpoint
    run create_checkpoint "$checkpoint_file" "$temp_dir" "1" "$trace_id" "RUNNING"
    [ "$status" -eq 0 ]
    [ -f "$checkpoint_file" ]
    
    # Verify no temporary files left behind
    [ ! -f "${checkpoint_file}.tmp."* ]
    
    # Verify checkpoint is not corrupted (can be read properly)
    grep -q "TRACE_ID=$trace_id" "$checkpoint_file"
    grep -q "STATUS=RUNNING" "$checkpoint_file"
    
    echo "✓ Atomic checkpoint operations work correctly"
}

@test "checkpoint: periodic checkpointing simulation" {
    local checkpoint_dir="$TEST_DIR/.sourceatlas/checkpoints"
    local checkpoint_file="$checkpoint_dir/periodic_test.checkpoint" 
    local temp_dir="$TEST_DIR/periodic_temp"
    local trace_id="periodic-test-$(date +%s)"
    
    mkdir -p "$temp_dir"
    
    echo "# Testing periodic checkpoint behavior"
    
    # Simulate multiple periodic checkpoints
    for i in {1..3}; do
        echo "$((i * 50))" > "$temp_dir/worker_0_count.txt"
        echo "{\"iteration\": $i}" > "$temp_dir/worker_0_output.jsonl"
        
        # Create checkpoint
        create_checkpoint "$checkpoint_file" "$temp_dir" "1" "$trace_id" "RUNNING"
        
        # Verify checkpoint was updated
        grep -q "WORKER_0_COMPLETED=$((i * 50))" "$checkpoint_file"
        
        sleep 1  # Ensure timestamp differences
    done
    
    # Verify final checkpoint state
    [ -f "$checkpoint_file" ]
    grep -q "WORKER_0_COMPLETED=150" "$checkpoint_file"
    
    echo "✓ Periodic checkpointing simulation successful"
}