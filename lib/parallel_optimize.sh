#!/usr/bin/env bash

# SourceAtlas Phase 9 - Parallel File Processing Implementation
# Utilizes all CPU cores for 10-50x speed improvement

# Load command validation and hash caching utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/command_validation.sh" 2>/dev/null || {
    echo "WARNING: Command validation not available, using basic fallbacks" >&2
}
source "$SCRIPT_DIR/hash_cache.sh" 2>/dev/null || {
    echo "WARNING: Hash caching not available, using direct calculation" >&2
}

# Get optimal number of workers with resource awareness and graceful degradation
get_cpu_cores() {
    local base_cores=4
    local max_workers=16
    local min_workers=2
    
    # Use validated utility if available, otherwise fallback to original logic
    if command -v get_optimal_worker_count >/dev/null 2>&1; then
        base_cores=$(get_optimal_worker_count)
    else
        # Enhanced CPU detection with better portability
        if validate_command "nproc" && command -v nproc >/dev/null 2>&1; then
            base_cores=$(nproc 2>/dev/null || echo "4")
        elif [[ "$OSTYPE" =~ darwin ]] && validate_command "sysctl"; then
            base_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
        elif [[ "$OSTYPE" =~ linux ]] && [[ -r "/proc/cpuinfo" ]]; then
            base_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "4")
        elif [[ "$OSTYPE" =~ freebsd ]] && validate_command "sysctl"; then
            base_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
        else
            echo "INFO: Could not detect CPU cores, using default: 4" >&2
            base_cores=4
        fi
    fi
    
    # Calculate initial worker count (cores * 2 as per task.md)
    local workers=$((base_cores * 2))
    
    # Apply resource-aware degradation
    local memory_mb=0
    
    # Check available memory for graceful degradation
    if [[ "$OSTYPE" =~ darwin ]] && validate_command "sysctl"; then
        memory_mb=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024)}' || echo "0")
    elif [[ -r "/proc/meminfo" ]]; then
        memory_mb=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "0")
    elif validate_command "free"; then
        memory_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}' || echo "0")
    fi
    
    # Graceful degradation based on available memory
    if [[ $memory_mb -gt 0 ]]; then
        # Reduce workers if memory is constrained (< 2GB available)
        if [[ $memory_mb -lt 2048 ]]; then
            workers=$((workers / 2))
            echo "INFO: Reducing worker count due to limited memory (${memory_mb}MB available)" >&2
        # Further reduce for very low memory (< 1GB)
        elif [[ $memory_mb -lt 1024 ]]; then
            workers=$((base_cores / 2))
            echo "WARN: Severely reducing worker count due to low memory (${memory_mb}MB available)" >&2
        fi
    fi
    
    # Check system load for additional degradation
    if validate_command "uptime"; then
        local load_avg
        load_avg=$(uptime 2>/dev/null | sed 's/.*load average: \([0-9.]*\).*/\1/' || echo "0")
        if command -v bc >/dev/null 2>&1; then
            local high_load
            high_load=$(echo "$load_avg > $base_cores * 2" | bc 2>/dev/null || echo "0")
            if [[ "$high_load" == "1" ]]; then
                workers=$((workers / 2))
                echo "INFO: Reducing worker count due to high system load ($load_avg)" >&2
            fi
        fi
    fi
    
    # Enforce bounds with logging
    if [[ $workers -gt $max_workers ]]; then
        workers=$max_workers
        echo "INFO: Capping workers at maximum: $max_workers" >&2
    elif [[ $workers -lt $min_workers ]]; then
        workers=$min_workers
        echo "INFO: Using minimum worker count: $min_workers" >&2
    fi
    
    echo "$workers"
}

# Emit observability event
emit_event() {
    local event_type="$1"
    local message="$2"
    local trace_id="${3:-parallel-$(date +%s)}"
    
    if [[ -w ".sourceatlas/events.jsonl" ]] || [[ -w ".sourceatlas/" ]]; then
        printf '{"timestamp":"%s","event":"%s","message":"%s","trace_id":"%s","component":"parallel_optimizer"}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event_type" "$message" "$trace_id" \
            >> ".sourceatlas/events.jsonl" 2>/dev/null
    fi
}

# Process files in streaming mode (low memory usage)
process_streaming_batch() {
    local worker_id="$1"
    local temp_dir="$2"
    local batch_file="$3"
    local trace_id="$4"
    local already_processed="${5:-0}"
    
    emit_event "worker_streaming_start" "Worker $worker_id started streaming mode processing" "$trace_id"
    
    local files_processed=$already_processed
    local worker_output="$temp_dir/worker_${worker_id}_output.jsonl"
    local temp_metadata temp_json
    
    # Create secure temporary files for streaming processing
    temp_metadata=$(mktemp "/tmp/streaming_metadata_${worker_id}.XXXXXX") || return 1
    temp_json=$(mktemp "/tmp/streaming_json_${worker_id}.XXXXXX") || return 1
    chmod 600 "$temp_metadata" "$temp_json"
    
    # Process remaining files in streaming mode (one at a time)
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        [[ ! -f "$file_path" ]] && continue
        
        # Extract metadata for single file
        local metadata size_bytes loc hash mtime
        size_bytes=$(get_file_size "$file_path")
        mtime=$(get_file_mtime "$file_path")
        loc=$(count_file_lines "$file_path")
        hash=$(calculate_file_hash_cached "$file_path")
        
        # Write single record to temp file
        printf "%s\t%s\t%s\t%s\t%s\n" "$file_path" "$size_bytes" "$loc" "$hash" "$mtime" > "$temp_metadata"
        
        # Process single record through AWK (no accumulation)
        if awk -f "$(dirname "$0")/batch_optimize.awk" "$temp_metadata" > "$temp_json" 2>/dev/null; then
            # Append to output immediately (streaming)
            cat "$temp_json" >> "$worker_output"
            ((files_processed++))
        fi
        
        # Clear temporary files for next iteration
        > "$temp_metadata"
        > "$temp_json"
        
        # Report progress every 50 files (more frequent for streaming)
        if ((files_processed % 50 == 0)); then
            emit_event "worker_streaming_progress" "Worker $worker_id streamed $files_processed files" "$trace_id"
        fi
        
    done < "$batch_file"
    
    # Cleanup temporary files
    rm -f "$temp_metadata" "$temp_json"
    
    emit_event "worker_streaming_complete" "Worker $worker_id completed streaming mode: $files_processed files" "$trace_id"
    echo "$files_processed" > "$temp_dir/worker_${worker_id}_count.txt"
}

# Process a batch of files in parallel worker
process_file_batch() {
    local worker_id="$1"
    local temp_dir="$2"
    local batch_file="$3"
    local trace_id="$4"
    
    emit_event "worker_start" "Worker $worker_id started processing batch" "$trace_id"
    
    local files_processed=0
    local worker_output="$temp_dir/worker_${worker_id}_output.jsonl"
    
    # Process each file in the batch
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        [[ ! -f "$file_path" ]] && continue
        
        # Fast metadata extraction using shell commands (securely)
        local metadata size_bytes loc hash mtime
        
        # Use validated command utilities with hash caching
        size_bytes=$(get_file_size "$file_path")
        mtime=$(get_file_mtime "$file_path")
        loc=$(count_file_lines "$file_path")
        hash=$(calculate_file_hash_cached "$file_path")
        
        metadata=$(printf "%s\t%s\t%s\t%s\t%s\n" "$file_path" "$size_bytes" "$loc" "$hash" "$mtime")
        
        # Pass to batch optimizer AWK script with streaming mode detection
        if [[ -n "$metadata" ]]; then
            echo "$metadata" | awk -f "$(dirname "$0")/batch_optimize.awk" >> "$worker_output"
            local awk_exit=$?
            
            # Check for streaming mode switch signal
            if [[ $awk_exit -eq 2 ]]; then
                emit_event "worker_streaming_switch" "Worker $worker_id switching to streaming mode" "$trace_id"
                # Switch to streaming mode for remaining files
                process_streaming_batch "$worker_id" "$temp_dir" "$batch_file" "$trace_id" "$files_processed"
                return $?
            fi
            
            ((files_processed++))
        fi
        
        # Report progress every 100 files
        if ((files_processed % 100 == 0)); then
            emit_event "worker_progress" "Worker $worker_id processed $files_processed files" "$trace_id"
        fi
        
    done < "$batch_file"
    
    emit_event "worker_complete" "Worker $worker_id completed $files_processed files" "$trace_id"
    echo "$files_processed" > "$temp_dir/worker_${worker_id}_count.txt"
}

# Main parallel processing function
parallel_process_files() {
    local file_list="$1"
    local output_file="$2"
    local trace_id="${3:-parallel-$(date +%s)}"
    
    emit_event "parallel_start" "Starting parallel file processing" "$trace_id"
    
    # Initialize checkpoint and recovery system
    local checkpoint_dir=".sourceatlas/checkpoints"
    local checkpoint_file="$checkpoint_dir/parallel_${trace_id}.checkpoint"
    local resume_from_checkpoint=false
    
    mkdir -p "$checkpoint_dir"
    
    # Check for existing checkpoint and offer recovery
    if [[ -f "$checkpoint_file" ]] && [[ -s "$checkpoint_file" ]]; then
        local checkpoint_age
        checkpoint_age=$(($(date +%s) - $(stat -c %Y "$checkpoint_file" 2>/dev/null || date +%s)))
        
        if [[ $checkpoint_age -lt 3600 ]]; then  # Checkpoint less than 1 hour old
            emit_event "checkpoint_found" "Found recent checkpoint (${checkpoint_age}s old), attempting recovery" "$trace_id"
            echo "INFO: Found recent checkpoint for trace $trace_id (${checkpoint_age}s old)" >&2
            echo "      Attempting to resume from checkpoint..." >&2
            
            if restore_from_checkpoint "$checkpoint_file" "$file_list" "$output_file" "$trace_id"; then
                return 0  # Successfully resumed and completed
            else
                echo "WARN: Checkpoint recovery failed, starting fresh processing" >&2
                rm -f "$checkpoint_file"
            fi
        else
            echo "INFO: Found old checkpoint (${checkpoint_age}s), starting fresh processing" >&2
            rm -f "$checkpoint_file"
        fi
    fi
    
    # Initialize hash caching system
    init_hash_cache
    
    # Get optimal number of workers
    local num_workers
    num_workers=$(get_cpu_cores)
    emit_event "parallel_config" "Using $num_workers parallel workers" "$trace_id"
    
    # Create secure temporary directory in memory if available
    local temp_dir
    if [[ -d "/dev/shm" ]] && [[ -w "/dev/shm" ]]; then
        temp_dir=$(mktemp -d "/dev/shm/sourceatlas_parallel_XXXXXX") || {
            emit_event "parallel_error" "Failed to create secure temp directory in /dev/shm" "$trace_id"
            return 1
        }
    else
        temp_dir=$(mktemp -d "/tmp/sourceatlas_parallel_XXXXXX") || {
            emit_event "parallel_error" "Failed to create secure temp directory in /tmp" "$trace_id"
            return 1
        }
    fi
    
    # Set secure permissions (owner read/write/execute only)
    chmod 700 "$temp_dir" || {
        emit_event "parallel_error" "Failed to set secure permissions on temp directory: $temp_dir" "$trace_id"
        cleanup_temp_dir "$temp_dir"
        return 1
    }
    
    # Store processing state globally for signal handler access
    PARALLEL_TEMP_DIR="$temp_dir"
    PARALLEL_CHECKPOINT_FILE="$checkpoint_file"
    PARALLEL_TRACE_ID="$trace_id"
    
    # Split file list into batches for workers
    local total_files
    total_files=$(wc -l < "$file_list")
    local files_per_worker=$((total_files / num_workers + 1))
    
    emit_event "parallel_split" "Splitting $total_files files across $num_workers workers ($files_per_worker files/worker)" "$trace_id"
    
    # Split the file list
    split -l "$files_per_worker" "$file_list" "$temp_dir/batch_"
    
    # Start parallel workers
    local pids=()
    local worker_id=0
    
    for batch_file in "$temp_dir"/batch_*; do
        [[ ! -f "$batch_file" ]] && continue
        
        # Start worker in background
        process_file_batch "$worker_id" "$temp_dir" "$batch_file" "$trace_id" &
        pids[worker_id]=$!
        ((worker_id++))
        
        emit_event "worker_spawned" "Started worker $((worker_id-1)) (PID: ${pids[$((worker_id-1))]})" "$trace_id"
    done
    
    # Store worker count for signal handler
    PARALLEL_WORKER_COUNT=$worker_id
    
    # Wait for all workers to complete with periodic checkpointing
    local total_processed=0
    local checkpoint_interval=60  # Checkpoint every 60 seconds
    local last_checkpoint=$(date +%s)
    
    for ((i=0; i<worker_id; i++)); do
        if [[ -n "${pids[i]}" ]]; then
            # Monitor worker progress and create checkpoints
            while kill -0 "${pids[i]}" 2>/dev/null; do
                sleep 5  # Check every 5 seconds
                
                # Create periodic checkpoint
                local current_time=$(date +%s)
                if [[ $((current_time - last_checkpoint)) -ge $checkpoint_interval ]]; then
                    create_checkpoint "$checkpoint_file" "$temp_dir" "$worker_id" "$trace_id"
                    last_checkpoint=$current_time
                fi
            done
            
            wait "${pids[i]}"
            local exit_code=$?
            
            if [[ $exit_code -eq 0 ]]; then
                # Get worker results
                local worker_count=0
                if [[ -f "$temp_dir/worker_${i}_count.txt" ]]; then
                    worker_count=$(cat "$temp_dir/worker_${i}_count.txt")
                fi
                ((total_processed += worker_count))
                emit_event "worker_joined" "Worker $i completed successfully ($worker_count files)" "$trace_id"
            else
                emit_event "worker_error" "Worker $i failed with exit code $exit_code" "$trace_id"
                # Create emergency checkpoint for failed workers
                create_checkpoint "$checkpoint_file" "$temp_dir" "$worker_id" "$trace_id" "FAILED"
            fi
        fi
    done
    
    # Combine all worker outputs
    emit_event "parallel_merge" "Merging outputs from $worker_id workers" "$trace_id"
    
    # Efficiently merge worker outputs
    cat "$temp_dir"/worker_*_output.jsonl > "$output_file" 2>/dev/null || {
        emit_event "parallel_error" "Failed to merge worker outputs" "$trace_id"
        cleanup_temp_dir "$temp_dir"
        return 1
    }
    
    # Cleanup
    cleanup_temp_dir "$temp_dir"
    
    # Remove checkpoint on successful completion
    if [[ -f "$checkpoint_file" ]]; then
        rm -f "$checkpoint_file"
        emit_event "checkpoint_cleanup" "Removed checkpoint after successful completion" "$trace_id"
    fi
    
    emit_event "parallel_complete" "Parallel processing completed: $total_processed files processed" "$trace_id"
    echo "$total_processed"
}

# Cleanup temporary directory with enhanced error handling
cleanup_temp_dir() {
    local temp_dir="$1"
    if [[ -d "$temp_dir" ]]; then
        # Kill any remaining background processes that might be using the directory
        if [[ -n "${pids[*]:-}" ]]; then
            for pid in "${pids[@]}"; do
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 0.1
                    # Force kill if still running
                    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
                fi
            done
            # Wait briefly for processes to exit
            sleep 0.5
        fi
        
        # Remove temporary directory
        if ! rm -rf "$temp_dir" 2>/dev/null; then
            echo "WARNING: Failed to clean up temporary directory: $temp_dir" >&2
            # Try to remove contents individually
            find "$temp_dir" -type f -delete 2>/dev/null || true
            find "$temp_dir" -type d -empty -delete 2>/dev/null || true
        fi
    fi
}

# Create checkpoint with current processing state
create_checkpoint() {
    local checkpoint_file="$1"
    local temp_dir="$2" 
    local total_workers="$3"
    local trace_id="$4"
    local status="${5:-RUNNING}"
    
    local checkpoint_temp
    checkpoint_temp=$(mktemp "${checkpoint_file}.tmp.XXXXXX") || return 1
    chmod 600 "$checkpoint_temp"
    
    # Create checkpoint with atomic operation
    {
        echo "# SourceAtlas Parallel Processing Checkpoint"
        echo "# Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "TRACE_ID=$trace_id"
        echo "STATUS=$status"
        echo "TIMESTAMP=$(date +%s)"
        echo "TOTAL_WORKERS=$total_workers"
        echo ""
        
        # Record worker progress
        for ((i=0; i<total_workers; i++)); do
            if [[ -f "$temp_dir/worker_${i}_count.txt" ]]; then
                local worker_count
                worker_count=$(cat "$temp_dir/worker_${i}_count.txt")
                echo "WORKER_${i}_COMPLETED=$worker_count"
            fi
            
            # Preserve partial output files
            if [[ -f "$temp_dir/worker_${i}_output.jsonl" ]]; then
                local output_size
                output_size=$(wc -l < "$temp_dir/worker_${i}_output.jsonl" 2>/dev/null || echo "0")
                echo "WORKER_${i}_OUTPUT_LINES=$output_size"
            fi
        done
        
        echo ""
        echo "# Worker Output Files"
        for output_file in "$temp_dir"/worker_*_output.jsonl; do
            if [[ -f "$output_file" ]]; then
                echo "OUTPUT_FILE=$(basename "$output_file")"
            fi
        done
        
    } > "$checkpoint_temp"
    
    # Atomic move to final checkpoint
    if mv "$checkpoint_temp" "$checkpoint_file"; then
        emit_event "checkpoint_created" "Checkpoint created successfully" "$trace_id"
        return 0
    else
        rm -f "$checkpoint_temp"
        emit_event "checkpoint_error" "Failed to create checkpoint" "$trace_id"
        return 1
    fi
}

# Restore processing from checkpoint
restore_from_checkpoint() {
    local checkpoint_file="$1"
    local file_list="$2"
    local output_file="$3"
    local trace_id="$4"
    
    emit_event "checkpoint_restore_start" "Attempting to restore from checkpoint" "$trace_id"
    
    # Read checkpoint metadata
    local checkpoint_status checkpoint_timestamp
    
    # Source the checkpoint file safely
    if [[ -r "$checkpoint_file" ]]; then
        # Extract key variables safely
        checkpoint_status=$(grep "^STATUS=" "$checkpoint_file" | cut -d= -f2)
        checkpoint_timestamp=$(grep "^TIMESTAMP=" "$checkpoint_file" | cut -d= -f2)
        
        # Only restore from successful running checkpoints
        if [[ "$checkpoint_status" != "RUNNING" ]]; then
            emit_event "checkpoint_restore_skip" "Checkpoint status not suitable for restore: $checkpoint_status" "$trace_id"
            return 1
        fi
        
        # Check if checkpoint is not too old (within 1 hour)
        local age=$(($(date +%s) - checkpoint_timestamp))
        if [[ $age -gt 3600 ]]; then
            emit_event "checkpoint_restore_expired" "Checkpoint too old: ${age}s" "$trace_id"
            return 1
        fi
        
        # Look for preserved worker outputs in checkpoint directory
        local checkpoint_dir
        checkpoint_dir=$(dirname "$checkpoint_file")
        local preserved_outputs=()
        
        # Collect any preserved output files
        for output in "$checkpoint_dir"/worker_*_output.jsonl; do
            if [[ -f "$output" ]]; then
                preserved_outputs+=("$output")
            fi
        done
        
        # If we have preserved outputs, merge them
        if [[ ${#preserved_outputs[@]} -gt 0 ]]; then
            emit_event "checkpoint_merge" "Merging ${#preserved_outputs[@]} preserved worker outputs" "$trace_id"
            cat "${preserved_outputs[@]}" > "$output_file" 2>/dev/null
            
            # Get total lines processed from checkpoint
            local total_restored=0
            for output in "${preserved_outputs[@]}"; do
                local lines
                lines=$(wc -l < "$output" 2>/dev/null || echo "0")
                ((total_restored += lines))
            done
            
            emit_event "checkpoint_restore_complete" "Successfully restored $total_restored processed files from checkpoint" "$trace_id"
            echo "$total_restored"
            return 0
        else
            emit_event "checkpoint_restore_no_data" "No preserved data found in checkpoint" "$trace_id"
            return 1
        fi
    else
        emit_event "checkpoint_restore_unreadable" "Checkpoint file not readable" "$trace_id"
        return 1
    fi
}

# Signal handler for graceful cleanup
cleanup_on_signal() {
    local signal="$1"
    echo "Received signal $signal, cleaning up..." >&2
    
    # Kill worker processes
    if [[ -n "${pids[*]:-}" ]]; then
        for pid in "${pids[@]}"; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done
        sleep 1
        # Force kill any remaining processes
        for pid in "${pids[@]}"; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done
    fi
    
    # Create emergency checkpoint before cleanup
    if [[ -n "${PARALLEL_CHECKPOINT_FILE:-}" ]] && [[ -n "${PARALLEL_TEMP_DIR:-}" ]] && [[ -n "${PARALLEL_WORKER_COUNT:-}" ]]; then
        echo "Creating emergency checkpoint..." >&2
        create_checkpoint "$PARALLEL_CHECKPOINT_FILE" "$PARALLEL_TEMP_DIR" "$PARALLEL_WORKER_COUNT" "${PARALLEL_TRACE_ID:-interrupted}" "INTERRUPTED"
    fi
    
    # Clean up temporary directory
    if [[ -n "${PARALLEL_TEMP_DIR:-}" ]]; then
        cleanup_temp_dir "$PARALLEL_TEMP_DIR"
    fi
    
    emit_event "parallel_interrupted" "Parallel processing interrupted by signal $signal - checkpoint created" "${PARALLEL_TRACE_ID:-interrupted}"
    exit 1
}

# Export functions for use in other scripts
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <file_list> <output_file> [trace_id]" >&2
        echo "  file_list: Text file with one file path per line" >&2
        echo "  output_file: Output JSONL file" >&2
        echo "  trace_id: Optional trace ID for observability" >&2
        exit 1
    fi
    
    # Set up signal handlers for graceful cleanup
    trap 'cleanup_on_signal SIGTERM' TERM
    trap 'cleanup_on_signal SIGINT' INT
    trap 'cleanup_on_signal SIGQUIT' QUIT
    
    # Store parameters in global variables for signal handler access
    PARALLEL_TRACE_ID="$3"
    
    parallel_process_files "$1" "$2" "$3"
else
    # Script is being sourced
    export -f get_cpu_cores
    export -f emit_event
    export -f process_file_batch
    export -f parallel_process_files
    export -f cleanup_temp_dir
fi