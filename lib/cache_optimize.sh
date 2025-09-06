#!/usr/bin/env bash

# SourceAtlas Phase 9 - Cache and incremental optimization
# Smart file change detection and result caching for 100x+ speed improvement

# Load command validation utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/command_validation.sh" 2>/dev/null || {
    echo "WARNING: Command validation not available, using basic fallbacks" >&2
}

# Cache directory structure
CACHE_DIR=".sourceatlas/cache"
CONTENT_HASH_CACHE="$CACHE_DIR/content_hashes.db"
METADATA_CACHE="$CACHE_DIR/file_metadata.db"
RESULT_CACHE="$CACHE_DIR/index_results.jsonl"

# Streaming cache lookup to avoid loading entire cache into memory
stream_cache_lookup() {
    local file_path="$1"
    local cache_file="$2"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    # Use grep for efficient single-file lookup
    # Format: file_path\tmtime\tsize
    local result
    result=$(grep -F "$file_path"$'\t' "$cache_file" 2>/dev/null | head -1)
    
    if [[ -n "$result" ]]; then
        # Extract mtime and size (skip file_path)
        echo "$result" | cut -f2,3
        return 0
    fi
    
    return 1
}

# Initialize cache system
init_cache() {
    local trace_id="${1:-cache-init-$(date +%s)}"
    
    emit_cache_event "cache_init_start" "Initializing cache system" "$trace_id"
    
    # Create cache directories with detailed error reporting
    if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
        local error_details=""
        if [[ ! -w "$(dirname "$CACHE_DIR")" ]]; then
            error_details="Permission denied: cannot write to parent directory $(dirname "$CACHE_DIR")"
        elif [[ $(df "$CACHE_DIR" 2>/dev/null | awk 'NR==2 {print $4}') -lt 1024 ]]; then
            error_details="Insufficient disk space: less than 1MB available"
        else
            error_details="Unknown filesystem error creating directory $CACHE_DIR"
        fi
        emit_cache_event "cache_init_error" "Failed to create cache directory: $error_details" "$trace_id"
        echo "ERROR: Cache initialization failed - $error_details" >&2
        return 1
    fi
    
    # Initialize cache databases if they don't exist
    if [[ ! -f "$CONTENT_HASH_CACHE" ]]; then
        touch "$CONTENT_HASH_CACHE"
        emit_cache_event "cache_init_created" "Created content hash cache" "$trace_id"
    fi
    
    if [[ ! -f "$METADATA_CACHE" ]]; then
        touch "$METADATA_CACHE"
        emit_cache_event "cache_init_created" "Created metadata cache" "$trace_id"
    fi
    
    if [[ ! -f "$RESULT_CACHE" ]]; then
        touch "$RESULT_CACHE"
        emit_cache_event "cache_init_created" "Created result cache" "$trace_id"
    fi
    
    emit_cache_event "cache_init_complete" "Cache system initialized" "$trace_id"
}

# Fast mtime-based pre-screening
fast_change_detection() {
    local file_list="$1"
    local changed_files="$2"
    local trace_id="${3:-change-detect-$(date +%s)}"
    
    emit_cache_event "change_detect_start" "Starting fast change detection" "$trace_id"
    
    local total_files=0
    local changed_count=0
    local cached_count=0
    
    > "$changed_files"  # Clear output file
    
    # Use streaming approach to avoid loading entire cache into memory
    # First pass: process files and check against cache via external lookups
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        [[ ! -f "$file_path" ]] && continue
        
        ((total_files++))
        
        # Get current file metadata
        local current_mtime current_size
        current_mtime=$(get_file_mtime "$file_path")
        current_size=$(get_file_size "$file_path")
        
        # Check cache using streaming lookup (avoids loading full cache)
        local cached_entry
        cached_entry=$(stream_cache_lookup "$file_path" "$METADATA_CACHE")
        
        if [[ -n "$cached_entry" ]]; then
            # Parse cached entry
            local cached_mtime cached_size
            IFS=$'\t' read -r cached_mtime cached_size <<< "$cached_entry"
            
            # Compare metadata
            if [[ "$current_mtime" != "$cached_mtime" ]] || [[ "$current_size" != "$cached_size" ]]; then
                echo "$file_path" >> "$changed_files"
                ((changed_count++))
            else
                ((cached_count++))
            fi
        else
            # File not in cache, mark as changed
            echo "$file_path" >> "$changed_files"
            ((changed_count++))
        fi
        
        # Emit progress every 1000 files with memory monitoring
        if [[ $((total_files % 1000)) -eq 0 ]]; then
            emit_cache_event "change_detect_progress" "Processed $total_files files ($changed_count changed, $cached_count cached)" "$trace_id"
            # Memory monitoring for large datasets
            monitor_memory_usage "$total_files" "$trace_id"
        fi
    done < "$file_list"
    
    emit_cache_event "change_detect_complete" "Detected $changed_count changed files, $cached_count cached" "$trace_id"
    
    # If most files are unchanged (>90%), use incremental mode
    if [[ $total_files -gt 0 ]]; then
        local cache_ratio=$((cached_count * 100 / total_files))
        if [[ $cache_ratio -ge 90 ]]; then
            emit_cache_event "cache_mode_incremental" "Using incremental mode ($cache_ratio% cached)" "$trace_id"
            return 0  # Incremental mode
        else
            emit_cache_event "cache_mode_full" "Using full rebuild mode ($cache_ratio% cached)" "$trace_id"
            return 1  # Full rebuild mode
        fi
    fi
    
    return 1  # Default to full rebuild
}

# Content hash based change detection (more accurate but slower)
content_hash_detection() {
    local file_list="$1"
    local changed_files="$2"
    local trace_id="${3:-hash-detect-$(date +%s)}"
    
    emit_cache_event "hash_detect_start" "Starting content hash detection" "$trace_id"
    
    > "$changed_files"
    
    local files_processed=0
    local hash_hits=0
    local hash_misses=0
    
    # Process files in batches for better performance
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        [[ ! -f "$file_path" ]] && continue
        
        # Calculate current hash
        local current_hash
        current_hash=$(calculate_fast_hash "$file_path")
        
        # Check cached hash
        local cached_hash
        cached_hash=$(awk -v path="$file_path" '$1 == path {print $2; exit}' "$CONTENT_HASH_CACHE" 2>/dev/null)
        
        if [[ "$current_hash" != "$cached_hash" ]] || [[ -z "$cached_hash" ]]; then
            echo "$file_path" >> "$changed_files"
            ((hash_misses++))
            
            # Update cache with new hash
            update_hash_cache "$file_path" "$current_hash"
        else
            ((hash_hits++))
        fi
        
        ((files_processed++))
        
        # Progress reporting
        if ((files_processed % 1000 == 0)); then
            emit_cache_event "hash_detect_progress" "Processed $files_processed files ($hash_hits hits, $hash_misses misses)" "$trace_id"
        fi
        
    done < "$file_list"
    
    emit_cache_event "hash_detect_complete" "Hash detection complete: $hash_hits hits, $hash_misses misses" "$trace_id"
}

# Calculate fast hash (MD5 for speed, not security)
calculate_fast_hash() {
    local file_path="$1"
    
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$file_path" | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$file_path"
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -md5 "$file_path" | cut -d' ' -f2
    else
        # Fallback: use file size and mtime as "hash"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            stat -f "%z-%m" "$file_path"
        else
            stat -c "%s-%Y" "$file_path"
        fi
    fi
}

# Update hash cache
update_hash_cache() {
    local file_path="$1"
    local hash="$2"
    
    # Create secure temporary file for atomic operation
    local temp_file
    temp_file=$(mktemp "${CONTENT_HASH_CACHE}.XXXXXX") || {
        echo "ERROR: Failed to create secure temporary file for hash cache update" >&2
        return 1
    }
    
    # Set secure permissions
    chmod 600 "$temp_file" || {
        echo "ERROR: Failed to set secure permissions on temporary file" >&2
        rm -f "$temp_file"
        return 1
    }
    
    # Update or append the hash entry using atomic operation
    if ! grep -v "^$file_path	" "$CONTENT_HASH_CACHE" > "$temp_file" 2>/dev/null; then
        # Create new cache if grep fails
        > "$temp_file"
    fi
    echo -e "$file_path\t$hash" >> "$temp_file" || {
        echo "ERROR: Failed to write to temporary hash cache file" >&2
        rm -f "$temp_file"
        return 1
    }
    mv "$temp_file" "$CONTENT_HASH_CACHE" || {
        echo "ERROR: Failed to update hash cache atomically" >&2
        rm -f "$temp_file"
        return 1
    }
}

# Update metadata cache
update_metadata_cache() {
    local file_path="$1"
    local mtime="$2"
    local size="$3"
    
    # Create secure temporary file for atomic operation
    local temp_file
    temp_file=$(mktemp "${METADATA_CACHE}.XXXXXX") || {
        echo "ERROR: Failed to create secure temporary file for metadata cache update" >&2
        return 1
    }
    
    # Set secure permissions
    chmod 600 "$temp_file" || {
        echo "ERROR: Failed to set secure permissions on temporary file" >&2
        rm -f "$temp_file"
        return 1
    }
    
    # Update or append the metadata entry using atomic operation
    if ! grep -v "^$file_path	" "$METADATA_CACHE" > "$temp_file" 2>/dev/null; then
        # Create new cache if grep fails
        > "$temp_file"
    fi
    echo -e "$file_path\t$mtime\t$size" >> "$temp_file" || {
        echo "ERROR: Failed to write to temporary metadata cache file" >&2
        rm -f "$temp_file"
        return 1
    }
    mv "$temp_file" "$METADATA_CACHE" || {
        echo "ERROR: Failed to update metadata cache atomically" >&2
        rm -f "$temp_file"
        return 1
    }
}

# Retrieve cached results for unchanged files
retrieve_cached_results() {
    local unchanged_files="$1"
    local output_file="$2"
    local trace_id="${3:-cache-retrieve-$(date +%s)}"
    
    emit_cache_event "cache_retrieve_start" "Retrieving cached results" "$trace_id"
    
    local retrieved_count=0
    
    # Extract cached results efficiently using AWK
    awk -v unchanged_file="$unchanged_files" -v trace_id="$trace_id" '
    BEGIN {
        # Load list of unchanged files
        while ((getline file_path < unchanged_file) > 0) {
            unchanged[file_path] = 1
        }
        close(unchanged_file)
    }
    
    {
        # Parse JSON to extract file path (simple extraction)
        if (match($0, /"path":"([^"]*)"/, path_match)) {
            file_path = path_match[1]
            if (unchanged[file_path]) {
                print $0
                retrieved_count++
            }
        }
    }
    
    END {
        printf "Retrieved %d cached results\n" > "/dev/stderr"
    }
    ' "$RESULT_CACHE" >> "$output_file"
    
    emit_cache_event "cache_retrieve_complete" "Retrieved cached results" "$trace_id"
}

# Update result cache with new results
update_result_cache() {
    local new_results="$1"
    local trace_id="${2:-cache-update-$(date +%s)}"
    
    emit_cache_event "cache_update_start" "Updating result cache" "$trace_id"
    
    # Append new results to cache
    if [[ -f "$new_results" ]]; then
        cat "$new_results" >> "$RESULT_CACHE"
        local new_count
        new_count=$(wc -l < "$new_results" 2>/dev/null || echo "0")
        emit_cache_event "cache_update_complete" "Added $new_count new results to cache" "$trace_id"
    fi
}

# Clean up old cache entries
cleanup_cache() {
    local file_list="$1"
    local trace_id="${2:-cache-cleanup-$(date +%s)}"
    
    emit_cache_event "cache_cleanup_start" "Cleaning up stale cache entries" "$trace_id"
    
    # Create secure temporary files for cache cleanup
    local temp_hash_cache temp_metadata_cache temp_result_cache
    temp_hash_cache=$(mktemp "${CONTENT_HASH_CACHE}.cleanup.XXXXXX") || {
        emit_cache_event "cache_cleanup_error" "Failed to create secure temp file for hash cache cleanup" "$trace_id"
        return 1
    }
    temp_metadata_cache=$(mktemp "${METADATA_CACHE}.cleanup.XXXXXX") || {
        emit_cache_event "cache_cleanup_error" "Failed to create secure temp file for metadata cache cleanup" "$trace_id"
        rm -f "$temp_hash_cache"
        return 1
    }
    temp_result_cache=$(mktemp "${RESULT_CACHE}.cleanup.XXXXXX") || {
        emit_cache_event "cache_cleanup_error" "Failed to create secure temp file for result cache cleanup" "$trace_id"
        rm -f "$temp_hash_cache" "$temp_metadata_cache"
        return 1
    }
    
    # Set secure permissions
    chmod 600 "$temp_hash_cache" "$temp_metadata_cache" "$temp_result_cache" || {
        emit_cache_event "cache_cleanup_error" "Failed to set secure permissions on cleanup temp files" "$trace_id"
        rm -f "$temp_hash_cache" "$temp_metadata_cache" "$temp_result_cache"
        return 1
    }
    
    # Create lookup table of current files
    awk '{current_files[$1] = 1} END {
        # Process hash cache
        while ((getline line < hash_cache) > 0) {
            split(line, parts, "\t")
            if (current_files[parts[1]]) {
                print line > temp_hash
            }
        }
        close(hash_cache)
        
        # Process metadata cache
        while ((getline line < meta_cache) > 0) {
            split(line, parts, "\t")
            if (current_files[parts[1]]) {
                print line > temp_meta
            }
        }
        close(meta_cache)
        
        # Process result cache (more complex JSON parsing needed)
        while ((getline line < result_cache) > 0) {
            if (match(line, /"path":"([^"]*)"/, path_match)) {
                if (current_files[path_match[1]]) {
                    print line > temp_result
                }
            }
        }
        close(result_cache)
    }' hash_cache="$CONTENT_HASH_CACHE" temp_hash="$temp_hash_cache" \
       meta_cache="$METADATA_CACHE" temp_meta="$temp_metadata_cache" \
       result_cache="$RESULT_CACHE" temp_result="$temp_result_cache" \
       "$file_list"
    
    # Replace cache files with cleaned versions (with error handling)
    if mv "$temp_hash_cache" "$CONTENT_HASH_CACHE" && \
       mv "$temp_metadata_cache" "$METADATA_CACHE" && \
       mv "$temp_result_cache" "$RESULT_CACHE"; then
        emit_cache_event "cache_cleanup_complete" "Cache cleanup completed" "$trace_id"
    else
        emit_cache_event "cache_cleanup_error" "Failed to replace cache files after cleanup" "$trace_id"
        # Clean up temporary files if move failed
        rm -f "$temp_hash_cache" "$temp_metadata_cache" "$temp_result_cache"
        return 1
    fi
}

# Emit cache-specific observability event
# Get current memory usage information
get_memory_info() {
    local memory_info=""
    
    # Try different methods based on OS
    if [[ "$OSTYPE" =~ darwin ]]; then
        # macOS - use vm_stat for memory info
        if command -v vm_stat >/dev/null 2>&1; then
            local vm_output
            vm_output=$(vm_stat 2>/dev/null)
            if [[ -n "$vm_output" ]]; then
                local free_pages used_pages
                free_pages=$(echo "$vm_output" | awk '/Pages free:/ {print $3}' | tr -d '.')
                used_pages=$(echo "$vm_output" | awk '/Pages active:/ {print $3}' | tr -d '.')
                if [[ -n "$free_pages" ]] && [[ -n "$used_pages" ]] && [[ $((free_pages + used_pages)) -gt 0 ]]; then
                    local used_percent=$((used_pages * 100 / (free_pages + used_pages)))
                    memory_info="used_percent:${used_percent}%"
                fi
            fi
        fi
    elif [[ -r "/proc/meminfo" ]]; then
        # Linux
        local mem_total mem_available mem_used
        mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
        mem_available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null)
        if [[ -n "$mem_total" ]] && [[ -n "$mem_available" ]]; then
            mem_used=$((mem_total - mem_available))
            local mem_used_percent=$((mem_used * 100 / mem_total))
            memory_info="used_percent:${mem_used_percent}%,available_mb:$((mem_available / 1024))"
        fi
    fi
    
    # Fallback: try free command
    if [[ -z "$memory_info" ]] && command -v free >/dev/null 2>&1; then
        local free_output
        free_output=$(free -m 2>/dev/null | awk '/^Mem:/ {if($2>0) print "used_percent:"int($3*100/$2)"%,total_mb:"$2}')
        memory_info="$free_output"
    fi
    
    echo "$memory_info"
}

# Monitor memory usage and emit warnings
monitor_memory_usage() {
    local record_count="$1"
    local trace_id="$2"
    local warning_threshold=80  # Warning at 80% memory usage
    
    local memory_info
    memory_info=$(get_memory_info)
    
    if [[ -n "$memory_info" ]]; then
        # Extract memory usage percentage
        local mem_percent
        if [[ "$memory_info" =~ used_percent:([0-9]+)% ]]; then
            mem_percent="${BASH_REMATCH[1]}"
        fi
        
        # Emit memory event for significant checkpoints
        if [[ $((record_count % 50000)) -eq 0 ]]; then
            emit_cache_event "memory_monitor" "Memory usage: $memory_info, processing $record_count records" "$trace_id"
        fi
        
        # Check for memory pressure
        if [[ -n "$mem_percent" ]] && [[ $mem_percent -ge $warning_threshold ]]; then
            emit_cache_event "memory_warning" "High memory usage detected: ${mem_percent}% with $record_count records being processed" "$trace_id"
            echo "WARNING: High memory usage (${mem_percent}%) detected while processing $record_count records" >&2
            echo "Consider reducing batch sizes or enabling streaming mode for large datasets" >&2
            return 1  # Signal that memory pressure exists
        fi
        
        # Special monitoring for very large datasets
        if [[ $record_count -gt 500000 ]]; then
            emit_cache_event "memory_large_dataset" "Processing very large dataset: $record_count records, memory: $memory_info" "$trace_id"
            echo "INFO: Processing very large dataset ($record_count records) - monitoring memory usage" >&2
        fi
    fi
    
    return 0  # No memory pressure detected
}

emit_cache_event() {
    local event_type="$1"
    local message="$2"
    local trace_id="$3"
    
    # Add memory info to critical events
    local enhanced_message="$message"
    if [[ "$event_type" =~ (complete|warning|error) ]]; then
        local memory_info
        memory_info=$(get_memory_info)
        if [[ -n "$memory_info" ]]; then
            enhanced_message="$message [memory: $memory_info]"
        fi
    fi
    
    if [[ -w ".sourceatlas/events.jsonl" ]] || [[ -w ".sourceatlas/" ]]; then
        printf '{"timestamp":"%s","event":"%s","message":"%s","trace_id":"%s","component":"cache_optimizer"}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event_type" "$enhanced_message" "$trace_id" \
            >> ".sourceatlas/events.jsonl" 2>/dev/null
    fi
}

# Export functions for use in other scripts
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly - show usage
    echo "Usage: source $0  # This script should be sourced, not executed directly" >&2
    echo "Available functions:" >&2
    echo "  init_cache [trace_id]" >&2
    echo "  fast_change_detection <file_list> <changed_files> [trace_id]" >&2
    echo "  content_hash_detection <file_list> <changed_files> [trace_id]" >&2
    echo "  retrieve_cached_results <unchanged_files> <output_file> [trace_id]" >&2
    echo "  update_result_cache <new_results> [trace_id]" >&2
    echo "  cleanup_cache <file_list> [trace_id]" >&2
    exit 1
else
    # Script is being sourced - export functions
    export CACHE_DIR CONTENT_HASH_CACHE METADATA_CACHE RESULT_CACHE
    export -f init_cache
    export -f fast_change_detection
    export -f content_hash_detection
    export -f calculate_fast_hash
    export -f update_hash_cache
    export -f update_metadata_cache
    export -f retrieve_cached_results
    export -f update_result_cache
    export -f cleanup_cache
    export -f emit_cache_event
fi