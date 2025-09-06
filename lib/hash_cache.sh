#!/bin/bash

# SourceAtlas Hash Caching System
# Eliminates redundant hash calculations across optimization levels

# Hash cache configuration
HASH_CACHE_DIR=".sourceatlas/cache/hashes"
HASH_CACHE_DB="$HASH_CACHE_DIR/content_hashes.tsv"
BATCH_HASH_SIZE="${SOURCEATLAS_BATCH_HASH_SIZE:-50}"  # Files per batch hash operation
HASH_CACHE_MAX_AGE="${SOURCEATLAS_HASH_CACHE_HOURS:-24}"  # Cache validity in hours

# Initialize hash caching system
init_hash_cache() {
    mkdir -p "$HASH_CACHE_DIR"
    
    # Create hash cache index if it doesn't exist
    if [[ ! -f "$HASH_CACHE_DB" ]]; then
        echo -e "file_path\thash\tmtime\tcached_at" > "$HASH_CACHE_DB"
    fi
    
    # Clean expired cache entries (older than configured hours)
    cleanup_hash_cache
}

# Clean up expired hash cache entries
cleanup_hash_cache() {
    if [[ ! -f "$HASH_CACHE_DB" ]]; then
        return 0
    fi
    
    local cutoff_time
    cutoff_time=$(($(date +%s) - (HASH_CACHE_MAX_AGE * 3600)))
    
    # Keep header + non-expired entries
    local temp_file
    temp_file=$(mktemp)
    
    {
        head -1 "$HASH_CACHE_DB"  # Keep header
        awk -F'\t' -v cutoff="$cutoff_time" 'NR>1 && $4 >= cutoff {print}' "$HASH_CACHE_DB"
    } > "$temp_file"
    
    mv "$temp_file" "$HASH_CACHE_DB"
}

# Get cached hash for a file (if valid)
get_cached_hash() {
    local file_path="$1"
    
    if [[ ! -f "$HASH_CACHE_DB" ]] || [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    # Get current file mtime
    local current_mtime
    current_mtime=$(get_file_mtime "$file_path")
    
    # Look for cached entry with matching mtime
    local cached_entry
    cached_entry=$(awk -F'\t' -v file="$file_path" -v mtime="$current_mtime" \
        'NR>1 && $1==file && $3==mtime {print $2; exit}' "$HASH_CACHE_DB")
    
    if [[ -n "$cached_entry" ]]; then
        echo "$cached_entry"
        return 0
    fi
    
    return 1
}

# Cache a hash result
cache_hash() {
    local file_path="$1"
    local hash="$2"
    local mtime="$3"
    local cached_at="${4:-$(date +%s)}"
    
    # Ensure cache directory exists
    mkdir -p "$HASH_CACHE_DIR"
    
    # Remove any existing entry for this file
    if [[ -f "$HASH_CACHE_DB" ]]; then
        local temp_file
        temp_file=$(mktemp)
        awk -F'\t' -v file="$file_path" '$1 != file {print}' "$HASH_CACHE_DB" > "$temp_file"
        mv "$temp_file" "$HASH_CACHE_DB"
    fi
    
    # Add new entry
    printf "%s\t%s\t%s\t%s\n" "$file_path" "$hash" "$mtime" "$cached_at" >> "$HASH_CACHE_DB"
}

# Calculate hash with caching
calculate_cached_file_hash() {
    local file_path="$1"
    
    # Try to get from cache first
    local cached_hash
    if cached_hash=$(get_cached_hash "$file_path"); then
        echo "$cached_hash"
        return 0
    fi
    
    # Calculate new hash using validation utilities
    local hash mtime
    hash=$(calculate_file_hash "$file_path")
    mtime=$(get_file_mtime "$file_path")
    
    # Cache the result
    cache_hash "$file_path" "$hash" "$mtime"
    
    echo "$hash"
}

# Batch hash calculation for multiple files
batch_calculate_hashes() {
    local file_list="$1"
    local output_file="$2"
    
    if [[ ! -f "$file_list" ]]; then
        return 1
    fi
    
    # Process files in batches to optimize hash calculation
    local temp_batch
    temp_batch=$(mktemp)
    local batch_count=0
    local total_files=0
    
    echo "Starting batch hash calculation..." >&2
    
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        [[ ! -f "$file_path" ]] && continue
        
        echo "$file_path" >> "$temp_batch"
        ((batch_count++))
        ((total_files++))
        
        # Process batch when it reaches configured size
        if [[ $batch_count -ge $BATCH_HASH_SIZE ]]; then
            process_hash_batch "$temp_batch" "$output_file"
            > "$temp_batch"  # Clear batch file
            batch_count=0
            echo "Processed batch ($total_files files so far)..." >&2
        fi
    done < "$file_list"
    
    # Process remaining files in final batch
    if [[ $batch_count -gt 0 ]]; then
        process_hash_batch "$temp_batch" "$output_file"
    fi
    
    rm -f "$temp_batch"
    echo "Batch hash calculation complete: $total_files files processed" >&2
}

# Process a single batch of files for hashing
process_hash_batch() {
    local batch_file="$1"
    local output_file="$2"
    
    # Optimize for openssl batch processing if available
    if validate_command "openssl"; then
        # Use parallel openssl calls for better performance
        while IFS= read -r file_path; do
            {
                local cached_hash
                if cached_hash=$(get_cached_hash "$file_path"); then
                    printf "%s\t%s\n" "$file_path" "$cached_hash" >> "$output_file"
                else
                    local hash mtime
                    hash=$(openssl dgst -md5 "$file_path" 2>/dev/null | cut -d' ' -f2 || echo "unknown")
                    mtime=$(get_file_mtime "$file_path")
                    cache_hash "$file_path" "$hash" "$mtime"
                    printf "%s\t%s\n" "$file_path" "$hash" >> "$output_file"
                fi
            } &
            
            # Limit concurrent processes to avoid overwhelming system
            local job_count
            job_count=$(jobs -r | wc -l)
            if [[ $job_count -ge 8 ]]; then
                wait  # Wait for some jobs to complete
            fi
        done < "$batch_file"
        
        wait  # Wait for all background jobs
    else
        # Fallback to sequential processing with caching
        while IFS= read -r file_path; do
            local hash
            hash=$(calculate_cached_file_hash "$file_path")
            printf "%s\t%s\n" "$file_path" "$hash" >> "$output_file"
        done < "$batch_file"
    fi
}

# Get hash cache statistics
get_hash_cache_stats() {
    local total_entries=0
    local cache_hits=0
    local cache_size=0
    
    if [[ -f "$HASH_CACHE_DB" ]]; then
        total_entries=$(($(wc -l < "$HASH_CACHE_DB") - 1))  # Subtract header
        cache_size=$(wc -c < "$HASH_CACHE_DB")
    fi
    
    # Calculate cache hit rate from recent operations (simplified)
    local hit_rate="N/A"
    
    cat << EOF
Hash Cache Statistics:
  Cache file: $HASH_CACHE_DB
  Total entries: $total_entries
  Cache size: $cache_size bytes
  Cache hit rate: $hit_rate
  Max age: $HASH_CACHE_MAX_AGE hours
  Batch size: $BATCH_HASH_SIZE files
EOF
}

# Export functions for use in optimization modules
export -f init_hash_cache
export -f cleanup_hash_cache
export -f get_cached_hash
export -f cache_hash
export -f calculate_cached_file_hash
export -f batch_calculate_hashes
export -f get_hash_cache_stats