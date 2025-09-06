#!/bin/bash

# SourceAtlas Command Validation and Fallback Utilities
# Ensures external command dependencies are available with graceful degradation

# Global cache for command availability
declare -A COMMAND_CACHE

# Check if command is available and cache result
validate_command() {
    local cmd="$1"
    local cache_key="${cmd// /_}"  # Replace spaces with underscores for cache key
    
    # Check cache first
    if [[ -n "${COMMAND_CACHE[$cache_key]:-}" ]]; then
        return "${COMMAND_CACHE[$cache_key]}"
    fi
    
    # Test command availability
    if command -v "$cmd" >/dev/null 2>&1; then
        COMMAND_CACHE[$cache_key]=0
        return 0
    else
        COMMAND_CACHE[$cache_key]=1
        return 1
    fi
}

# Get file size with fallbacks
get_file_size() {
    local file="$1"
    local size=0
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    
    # Primary: stat command (most reliable)
    if validate_command "stat"; then
        if [[ "$OSTYPE" =~ darwin ]]; then
            size=$(stat -f "%z" "$file" 2>/dev/null || echo "0")
        else
            size=$(stat -c "%s" "$file" 2>/dev/null || echo "0")
        fi
    # Fallback 1: wc -c (byte count)
    elif validate_command "wc"; then
        size=$(wc -c < "$file" 2>/dev/null | tr -d ' ' || echo "0")
    # Fallback 2: ls -l parsing (less reliable but universal)
    elif validate_command "ls"; then
        size=$(ls -l "$file" 2>/dev/null | awk '{print $5}' || echo "0")
    fi
    
    # Ensure numeric result
    [[ "$size" =~ ^[0-9]+$ ]] && echo "$size" || echo "0"
}

# Get file modification time with fallbacks
get_file_mtime() {
    local file="$1"
    local mtime=0
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    
    # Primary: stat command
    if validate_command "stat"; then
        if [[ "$OSTYPE" =~ darwin ]]; then
            mtime=$(stat -f "%m" "$file" 2>/dev/null || echo "0")
        else
            mtime=$(stat -c "%Y" "$file" 2>/dev/null || echo "0")
        fi
    # Fallback 1: date command with file reference
    elif validate_command "date"; then
        # This is less portable but may work
        mtime=$(date -r "$file" +%s 2>/dev/null || echo "0")
    # Fallback 2: ls -l with date parsing (complex, avoid if possible)
    else
        # Return current time as fallback
        mtime=$(date +%s 2>/dev/null || echo "0")
    fi
    
    # Ensure numeric result
    [[ "$mtime" =~ ^[0-9]+$ ]] && echo "$mtime" || echo "0"
}

# Count lines with fallbacks
count_file_lines() {
    local file="$1"
    local lines=0
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    
    # Primary: wc -l (most efficient)
    if validate_command "wc"; then
        lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ' || echo "0")
    # Fallback 1: grep -c (count all lines including empty)
    elif validate_command "grep"; then
        lines=$(grep -c '^' "$file" 2>/dev/null || echo "0")
    # Fallback 2: awk (slower but universal)
    elif validate_command "awk"; then
        lines=$(awk 'END{print NR}' "$file" 2>/dev/null || echo "0")
    # Fallback 3: cat + wc (inefficient but works)
    elif validate_command "cat"; then
        lines=$(cat "$file" 2>/dev/null | wc -l 2>/dev/null | tr -d ' ' || echo "0")
    fi
    
    # Ensure numeric result
    [[ "$lines" =~ ^[0-9]+$ ]] && echo "$lines" || echo "0"
}

# Calculate file hash with fallbacks
calculate_file_hash() {
    local file="$1"
    local hash="unknown"
    
    if [[ ! -f "$file" ]]; then
        echo "unknown"
        return
    fi
    
    # Primary: openssl (most common)
    if validate_command "openssl"; then
        hash=$(openssl dgst -md5 "$file" 2>/dev/null | cut -d' ' -f2 || echo "unknown")
    # Fallback 1: md5sum (Linux)
    elif validate_command "md5sum"; then
        hash=$(md5sum "$file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
    # Fallback 2: md5 (macOS)
    elif validate_command "md5"; then
        hash=$(md5 -q "$file" 2>/dev/null || echo "unknown")
    # Fallback 3: shasum (SHA instead of MD5, but better than nothing)
    elif validate_command "shasum"; then
        hash=$(shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
    # Fallback 4: Simple checksum based on size+mtime (weak but functional)
    else
        local size mtime
        size=$(get_file_size "$file")
        mtime=$(get_file_mtime "$file")
        hash="simple-${size}-${mtime}"
    fi
    
    echo "$hash"
}

# Validate all required commands for Phase 9 optimizations
validate_phase9_dependencies() {
    local missing_commands=()
    local degraded_features=()
    
    # Critical commands (Phase 9 will work but with degraded performance)
    local critical_commands=("awk" "wc" "find")
    
    # Performance commands (fallbacks available)
    local performance_commands=("openssl" "stat" "md5sum" "parallel")
    
    echo "=== Phase 9 Dependency Validation ===" >&2
    
    # Check critical commands
    for cmd in "${critical_commands[@]}"; do
        if ! validate_command "$cmd"; then
            missing_commands+=("$cmd")
        else
            echo "✓ $cmd: available" >&2
        fi
    done
    
    # Check performance commands with fallback info
    for cmd in "${performance_commands[@]}"; do
        if validate_command "$cmd"; then
            echo "✓ $cmd: available" >&2
        else
            degraded_features+=("$cmd")
            echo "⚠ $cmd: missing (fallback available)" >&2
        fi
    done
    
    # Report results
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        echo "❌ CRITICAL: Missing required commands: ${missing_commands[*]}" >&2
        echo "Phase 9 optimizations cannot run without these commands." >&2
        return 1
    fi
    
    if [[ ${#degraded_features[@]} -gt 0 ]]; then
        echo "⚠ WARNING: Missing performance commands: ${degraded_features[*]}" >&2
        echo "Phase 9 optimizations will use fallbacks (reduced performance)." >&2
    fi
    
    echo "✅ Phase 9 dependencies validated successfully" >&2
    return 0
}

# Get optimal parallel worker count
get_optimal_worker_count() {
    local max_workers=8  # Reasonable default
    
    # Method 1: nproc (most reliable on Linux)
    if validate_command "nproc"; then
        local nproc_count
        nproc_count=$(nproc 2>/dev/null || echo "4")
        max_workers=$((nproc_count * 2))
    # Method 2: /proc/cpuinfo (Linux fallback)
    elif [[ -r "/proc/cpuinfo" ]]; then
        local cpu_count
        cpu_count=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "4")
        max_workers=$((cpu_count * 2))
    # Method 3: sysctl (macOS)
    elif validate_command "sysctl" && sysctl -n hw.ncpu >/dev/null 2>&1; then
        local cpu_count
        cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
        max_workers=$((cpu_count * 2))
    fi
    
    # Enforce reasonable bounds
    [[ $max_workers -lt 2 ]] && max_workers=2
    [[ $max_workers -gt 16 ]] && max_workers=16
    
    echo "$max_workers"
}

# Export functions for use in other scripts
export -f validate_command
export -f get_file_size
export -f get_file_mtime  
export -f count_file_lines
export -f calculate_file_hash
export -f validate_phase9_dependencies
export -f get_optimal_worker_count