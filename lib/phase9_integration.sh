#!/usr/bin/env bash

# SourceAtlas Phase 9 - Observability Integration
# Integrates all Phase 9 optimizations with the existing observability framework

# Source all optimization modules
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Load command validation utilities first
source "$SCRIPT_DIR/command_validation.sh" 2>/dev/null || {
    echo "WARNING: Command validation not available, using basic fallbacks" >&2
}

# Validate Phase 9 dependencies on startup
validate_phase9_dependencies

# Source existing observability components (Phase 8)
[[ -f "$SCRIPT_DIR/observability.sh" ]] && source "$SCRIPT_DIR/observability.sh"

# Source Phase 9 optimization modules
source "$SCRIPT_DIR/cache_optimize.sh"
source "$SCRIPT_DIR/io_optimize.sh"
source "$SCRIPT_DIR/parallel_optimize.sh"
source "$SCRIPT_DIR/benchmark.sh"

# Phase 9 integration configuration
PHASE9_ENABLED="${SOURCEATLAS_PHASE9_ENABLED:-true}"
PHASE9_OPTIMIZATION_LEVEL="${SOURCEATLAS_OPTIMIZATION_LEVEL:-full}"  # none, level1-5, full
PHASE9_TRACE_PERFORMANCE="${SOURCEATLAS_TRACE_PERFORMANCE:-true}"

# Initialize Phase 9 integrated system
init_phase9_system() {
    local trace_id="${1:-phase9-init-$(date +%s)}"
    
    emit_phase9_event "phase9_init_start" "Initializing Phase 9 optimizations with observability" "$trace_id"
    
    # Check if Phase 9 is enabled
    if [[ "$PHASE9_ENABLED" != "true" ]]; then
        emit_phase9_event "phase9_disabled" "Phase 9 optimizations disabled" "$trace_id"
        return 0
    fi
    
    # Initialize individual optimization components
    if [[ "$PHASE9_OPTIMIZATION_LEVEL" != "none" ]]; then
        # Initialize cache system
        init_cache "$trace_id" || {
            emit_phase9_event "phase9_init_error" "Failed to initialize cache system" "$trace_id"
            return 1
        }
        
        # Initialize I/O optimization
        init_io_optimization "$trace_id" || {
            emit_phase9_event "phase9_init_error" "Failed to initialize I/O optimization" "$trace_id"
            return 1
        }
        
        # Initialize benchmark system
        init_benchmark_system "$trace_id" || {
            emit_phase9_event "phase9_init_error" "Failed to initialize benchmark system" "$trace_id"
            return 1
        }
        
        emit_phase9_event "phase9_init_optimizations" "Optimization level: $PHASE9_OPTIMIZATION_LEVEL" "$trace_id"
    fi
    
    # Set up performance monitoring hooks
    if [[ "$PHASE9_TRACE_PERFORMANCE" == "true" ]]; then
        setup_performance_monitoring "$trace_id"
    fi
    
    emit_phase9_event "phase9_init_complete" "Phase 9 system initialized successfully" "$trace_id"
}

# Integrated file processing with all optimizations
process_files_optimized() {
    local file_list="$1"
    local output_file="$2" 
    local trace_id="${3:-process-optimized-$(date +%s)}"
    
    emit_phase9_event "process_optimized_start" "Starting optimized file processing" "$trace_id"
    
    # Performance tracking
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Create processing pipeline based on optimization level
    case "$PHASE9_OPTIMIZATION_LEVEL" in
        "none")
            # No optimizations, use original processing
            process_files_baseline "$file_list" "$output_file" "$trace_id"
            ;;
        "level1")
            # AWK batch processing only
            process_with_awk_optimization "$file_list" "$output_file" "$trace_id"
            ;;
        "level2")
            # AWK + Parallel processing
            process_with_parallel_optimization "$file_list" "$output_file" "$trace_id"
            ;;
        "level3")
            # AWK + Parallel + Memory optimization
            process_with_memory_optimization "$file_list" "$output_file" "$trace_id"
            ;;
        "level4")
            # Add cache optimization
            process_with_cache_optimization "$file_list" "$output_file" "$trace_id"
            ;;
        "level5")
            # Add I/O optimization
            process_with_io_optimization "$file_list" "$output_file" "$trace_id"
            ;;
        "full"|*)
            # Full optimization stack
            process_with_full_optimization "$file_list" "$output_file" "$trace_id"
            ;;
    esac
    
    local end_time
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Calculate performance metrics
    local total_files
    total_files=$(wc -l < "$file_list" 2>/dev/null || echo "0")
    local output_size
    output_size=$(wc -c < "$output_file" 2>/dev/null || echo "0")
    
    local duration
    if command -v bc >/dev/null 2>&1; then
        duration=$(echo "$end_time - $start_time" | bc)
    else
        duration=$(awk "BEGIN {print $end_time - $start_time}")
    fi
    
    local throughput
    if [[ "$duration" != "0" ]] && command -v bc >/dev/null 2>&1; then
        throughput=$(echo "scale=2; $total_files / $duration" | bc)
    else
        throughput="0"
    fi
    
    # Emit performance metrics
    emit_phase9_event "process_optimized_metrics" "Processed $total_files files in ${duration}s (${throughput} files/sec, ${output_size} bytes)" "$trace_id"
    
    # Record performance data
    if [[ "$PHASE9_TRACE_PERFORMANCE" == "true" ]]; then
        record_performance_data "$total_files" "$duration" "$throughput" "$output_size" "$trace_id"
    fi
    
    emit_phase9_event "process_optimized_complete" "Optimized file processing completed" "$trace_id"
}

# Full optimization stack processing
process_with_full_optimization() {
    local file_list="$1"
    local output_file="$2"
    local trace_id="$3"
    
    emit_phase9_event "full_optimization_start" "Starting full optimization stack" "$trace_id"
    
    # Step 1: Cache-based change detection
    local changed_files="$SOURCEATLAS_WORK_DIR/changed_files.txt"
    local unchanged_files="$SOURCEATLAS_WORK_DIR/unchanged_files.txt"
    
    if fast_change_detection "$file_list" "$changed_files" "$trace_id"; then
        emit_phase9_event "optimization_cache_mode" "Using incremental processing mode" "$trace_id"
        
        # Create list of unchanged files
        comm -23 <(sort "$file_list") <(sort "$changed_files") > "$unchanged_files"
        
        # Retrieve cached results for unchanged files
        local cached_output="$SOURCEATLAS_WORK_DIR/cached_results.jsonl"
        retrieve_cached_results "$unchanged_files" "$cached_output" "$trace_id"
        
        # Process only changed files with full optimization
        if [[ -s "$changed_files" ]]; then
            local new_results="$SOURCEATLAS_WORK_DIR/new_results.jsonl"
            process_changed_files_optimized "$changed_files" "$new_results" "$trace_id"
            
            # Update result cache
            update_result_cache "$new_results" "$trace_id"
            
            # Combine cached and new results
            cat "$cached_output" "$new_results" > "$output_file" 2>/dev/null
        else
            # All files cached
            mv "$cached_output" "$output_file"
        fi
    else
        emit_phase9_event "optimization_full_mode" "Using full rebuild mode" "$trace_id"
        
        # Full processing with all optimizations
        process_changed_files_optimized "$file_list" "$output_file" "$trace_id"
        
        # Update cache with all results
        update_result_cache "$output_file" "$trace_id"
    fi
    
    emit_phase9_event "full_optimization_complete" "Full optimization stack completed" "$trace_id"
}

# Process changed files with parallel + I/O + memory optimizations
process_changed_files_optimized() {
    local file_list="$1"
    local output_file="$2"
    local trace_id="$3"
    
    emit_phase9_event "changed_files_process_start" "Processing changed files with optimizations" "$trace_id"
    
    # Step 1: I/O optimized metadata extraction
    local metadata_file="$SOURCEATLAS_WORK_DIR/metadata.tsv"
    batch_read_files "$file_list" "$metadata_file" "$trace_id"
    
    # Step 2: Parallel processing with memory optimization
    SOURCEATLAS_OPTIMIZE_MEMORY=1 parallel_process_files "$file_list" "$output_file" "$trace_id"
    
    emit_phase9_event "changed_files_process_complete" "Changed files processing completed" "$trace_id"
}

# Setup performance monitoring hooks
setup_performance_monitoring() {
    local trace_id="$1"
    
    emit_phase9_event "perf_monitor_setup_start" "Setting up performance monitoring" "$trace_id"
    
    # Create performance metrics directory
    mkdir -p ".sourceatlas/metrics" 2>/dev/null
    
    # Set up automatic benchmark on significant operations
    export SOURCEATLAS_AUTO_BENCHMARK=true
    
    # Enable detailed tracing for performance analysis
    export SOURCEATLAS_DETAILED_TRACE=true
    
    emit_phase9_event "perf_monitor_setup_complete" "Performance monitoring enabled" "$trace_id"
}

# Record performance data for analysis
record_performance_data() {
    local file_count="$1"
    local duration="$2"
    local throughput="$3"
    local output_size="$4"
    local trace_id="$5"
    
    local metrics_file=".sourceatlas/metrics/performance_data.jsonl"
    
    local performance_record
    performance_record=$(cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "trace_id": "$trace_id",
    "optimization_level": "$PHASE9_OPTIMIZATION_LEVEL",
    "file_count": $file_count,
    "duration": $duration,
    "throughput": $throughput,
    "output_size": $output_size,
    "system_info": {
        "cpu_cores": $(nproc 2>/dev/null || echo "null"),
        "memory_gb": $(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "null"),
        "os": "$(uname -s 2>/dev/null || echo "unknown")"
    }
}
EOF
)
    
    echo "$performance_record" >> "$metrics_file"
    
    # Trigger anomaly detection if available
    if declare -f check_performance_anomaly >/dev/null 2>&1; then
        check_performance_anomaly "$performance_record" "$trace_id"
    fi
}

# Baseline processing (no optimizations) for comparison
process_files_baseline() {
    local file_list="$1"
    local output_file="$2"
    local trace_id="$3"
    
    emit_phase9_event "baseline_process_start" "Processing files with baseline method" "$trace_id"
    
    > "$output_file"
    
    local files_processed=0
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        
        # Simulate original processing (multiple subprocess calls)
        local file_name
        file_name=$(basename "$file_path")
        local ext
        ext="${file_name##*.}"
        
        # Generate simple JSON record
        local json_record
        json_record=$(cat << EOF
{"repo":"unknown","path":"$file_path","file_name":"$file_name","ext":".$ext","lang":"unknown","size_bytes":0,"loc":0,"roles":["general"],"summary":"Baseline processing","imports":[],"symbols":[],"importance_score":1.0,"content_hash":"baseline"}
EOF
)
        
        echo "$json_record" >> "$output_file"
        ((files_processed++))
        
    done < "$file_list"
    
    emit_phase9_event "baseline_process_complete" "Baseline processing completed ($files_processed files)" "$trace_id"
}

# Individual optimization level processors (simplified implementations)
process_with_awk_optimization() {
    local file_list="$1"
    local output_file="$2"
    local trace_id="$3"
    
    # Use AWK batch processing
    awk -f "$SCRIPT_DIR/batch_optimize.awk" < "$file_list" > "$output_file"
}

process_with_parallel_optimization() {
    local file_list="$1"
    local output_file="$2"
    local trace_id="$3"
    
    # Use parallel processing
    parallel_process_files "$file_list" "$output_file" "$trace_id"
}

process_with_memory_optimization() {
    local file_list="$1"
    local output_file="$2"
    local trace_id="$3"
    
    # Use memory-optimized JSON generation
    SOURCEATLAS_OPTIMIZE_MEMORY=1 parallel_process_files "$file_list" "$output_file" "$trace_id"
}

process_with_cache_optimization() {
    local file_list="$1"
    local output_file="$2"
    local trace_id="$3"
    
    # Use cache-based processing
    process_with_full_optimization "$file_list" "$output_file" "$trace_id"
}

process_with_io_optimization() {
    local file_list="$1"
    local output_file="$2"
    local trace_id="$3"
    
    # Use I/O optimized processing
    batch_read_files "$file_list" "$output_file" "$trace_id"
}

# Phase 9 cleanup function
cleanup_phase9_system() {
    local trace_id="${1:-phase9-cleanup-$(date +%s)}"
    
    emit_phase9_event "phase9_cleanup_start" "Starting Phase 9 cleanup" "$trace_id"
    
    # Cleanup I/O optimization
    if declare -f cleanup_io_optimization >/dev/null 2>&1; then
        cleanup_io_optimization "$trace_id"
    fi
    
    # Cleanup cache system
    if declare -f cleanup_cache >/dev/null 2>&1; then
        cleanup_cache "" "$trace_id"  # Empty file list for general cleanup
    fi
    
    emit_phase9_event "phase9_cleanup_complete" "Phase 9 cleanup completed" "$trace_id"
}

# Emit Phase 9 specific events
emit_phase9_event() {
    local event_type="$1"
    local message="$2"
    local trace_id="$3"
    
    # Use existing observability system if available
    if declare -f emit_event >/dev/null 2>&1; then
        emit_event "$event_type" "$message" "$trace_id" "phase9_integration"
    else
        # Fallback to direct file writing
        if [[ -w ".sourceatlas/events.jsonl" ]] || [[ -w ".sourceatlas/" ]]; then
            printf '{"timestamp":"%s","event":"%s","message":"%s","trace_id":"%s","component":"phase9_integration","phase":"9"}\n' \
                "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event_type" "$message" "$trace_id" \
                >> ".sourceatlas/events.jsonl" 2>/dev/null
        fi
    fi
}

# Hook into existing CLI commands to enable Phase 9 optimizations
hook_phase9_into_cli() {
    local trace_id="${1:-hook-$(date +%s)}"
    
    emit_phase9_event "cli_hook_start" "Hooking Phase 9 into CLI commands" "$trace_id"
    
    # Override scan command to use optimized processing
    if declare -f original_scan_command >/dev/null 2>&1; then
        emit_phase9_event "cli_hook_skip" "Scan command already hooked" "$trace_id"
    else
        # This would typically be done in the main CLI script
        emit_phase9_event "cli_hook_info" "Phase 9 hooks should be integrated in main CLI" "$trace_id"
    fi
    
    emit_phase9_event "cli_hook_complete" "Phase 9 CLI hooks ready" "$trace_id"
}

# Export all Phase 9 integration functions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    echo "Usage: source $0  # This script should be sourced, not executed directly" >&2
    echo "Available functions:" >&2
    echo "  init_phase9_system [trace_id]" >&2
    echo "  process_files_optimized <file_list> <output_file> [trace_id]" >&2
    echo "  cleanup_phase9_system [trace_id]" >&2
    echo "  hook_phase9_into_cli [trace_id]" >&2
    echo "" >&2
    echo "Environment variables:" >&2
    echo "  SOURCEATLAS_PHASE9_ENABLED - Enable Phase 9 (true|false)" >&2
    echo "  SOURCEATLAS_OPTIMIZATION_LEVEL - Optimization level (none|level1-5|full)" >&2
    echo "  SOURCEATLAS_TRACE_PERFORMANCE - Enable performance tracing (true|false)" >&2
    exit 1
else
    # Script is being sourced
    export PHASE9_ENABLED PHASE9_OPTIMIZATION_LEVEL PHASE9_TRACE_PERFORMANCE
    export -f init_phase9_system
    export -f process_files_optimized
    export -f process_with_full_optimization
    export -f process_changed_files_optimized
    export -f setup_performance_monitoring
    export -f record_performance_data
    export -f cleanup_phase9_system
    export -f emit_phase9_event
    export -f hook_phase9_into_cli
fi