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

# Get file size with enhanced cross-platform fallbacks
get_file_size() {
    local file="$1"
    local size=0
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    
    # Primary: stat command with comprehensive platform support
    if validate_command "stat"; then
        if [[ "$OSTYPE" =~ darwin ]]; then
            # macOS/BSD stat
            size=$(stat -f "%z" "$file" 2>/dev/null || echo "0")
        elif [[ "$OSTYPE" =~ (freebsd|openbsd|netbsd) ]]; then
            # BSD variants
            size=$(stat -f "%z" "$file" 2>/dev/null || echo "0")
        elif [[ "$OSTYPE" =~ solaris ]]; then
            # Solaris stat (try both GNU and traditional)
            size=$(stat -c "%s" "$file" 2>/dev/null || stat -x "$file" 2>/dev/null | awk '/Size:/ {print $2}' || echo "0")
        else
            # Linux and other GNU stat
            size=$(stat -c "%s" "$file" 2>/dev/null || echo "0")
        fi
    # Fallback 1: find command (very portable)
    elif validate_command "find"; then
        size=$(find "$file" -printf "%s" 2>/dev/null || echo "0")
    # Fallback 2: wc -c (byte count - highly portable)
    elif validate_command "wc"; then
        size=$(wc -c < "$file" 2>/dev/null | tr -d ' \t' || echo "0")
    # Fallback 3: ls -l parsing (universal but slower)
    elif validate_command "ls"; then
        size=$(ls -l "$file" 2>/dev/null | awk '{print $5}' || echo "0")
    # Last resort: du command
    elif validate_command "du"; then
        size=$(du -b "$file" 2>/dev/null | cut -f1 || echo "0")
    fi
    
    # Ensure numeric result and handle edge cases
    if [[ "$size" =~ ^[0-9]+$ ]] && [[ $size -ge 0 ]]; then
        echo "$size"
    else
        echo "0"
    fi
}

# Get file modification time with enhanced cross-platform fallbacks
get_file_mtime() {
    local file="$1"
    local mtime=0
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    
    # Primary: stat command with comprehensive platform support
    if validate_command "stat"; then
        if [[ "$OSTYPE" =~ darwin ]]; then
            # macOS/BSD stat
            mtime=$(stat -f "%m" "$file" 2>/dev/null || echo "0")
        elif [[ "$OSTYPE" =~ (freebsd|openbsd|netbsd) ]]; then
            # BSD variants
            mtime=$(stat -f "%m" "$file" 2>/dev/null || echo "0")
        elif [[ "$OSTYPE" =~ solaris ]]; then
            # Solaris - try GNU stat first, then traditional
            mtime=$(stat -c "%Y" "$file" 2>/dev/null || stat -x "$file" 2>/dev/null | awk '/Modify:/ {print $2}' | sed 's/\..*//' || echo "0")
        else
            # Linux and other GNU stat
            mtime=$(stat -c "%Y" "$file" 2>/dev/null || echo "0")
        fi
    # Fallback 1: find command (very portable)
    elif validate_command "find"; then
        mtime=$(find "$file" -printf "%T@" 2>/dev/null | cut -d. -f1 || echo "0")
    # Fallback 2: date command with file reference (GNU coreutils)
    elif validate_command "date"; then
        # Try different date command variants
        if [[ "$OSTYPE" =~ (darwin|freebsd|openbsd|netbsd) ]]; then
            # BSD date
            mtime=$(stat -f "%m" "$file" 2>/dev/null || echo "0")
        else
            # GNU date
            mtime=$(date -r "$file" +%s 2>/dev/null || echo "0")
        fi
    # Fallback 3: ls with date parsing (less reliable)
    elif validate_command "ls" && validate_command "awk"; then
        # Parse ls output to get approximate timestamp (less accurate)
        local ls_time
        ls_time=$(ls -l --time-style=+%s "$file" 2>/dev/null | awk '{print $6}')
        if [[ "$ls_time" =~ ^[0-9]+$ ]]; then
            mtime="$ls_time"
        else
            # Fallback: current time
            mtime=$(date +%s 2>/dev/null || echo "$(( $(date +%Y) - 1970) * 31536000))")
        fi
    # Last resort: current time
    else
        mtime=$(date +%s 2>/dev/null || echo "0")
    fi
    
    # Ensure numeric result and reasonable bounds
    if [[ "$mtime" =~ ^[0-9]+$ ]] && [[ $mtime -gt 0 ]] && [[ $mtime -lt 2147483647 ]]; then
        echo "$mtime"
    else
        # Return a reasonable default (year 2000 epoch)
        echo "946684800"
    fi
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

# Calculate file hash with fallbacks (non-cached version)
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

# Calculate file hash with caching (preferred method)
calculate_file_hash_cached() {
    local file="$1"
    
    # Use cached version if hash caching is available
    if command -v calculate_cached_file_hash >/dev/null 2>&1; then
        calculate_cached_file_hash "$file"
    else
        # Fallback to non-cached version
        calculate_file_hash "$file"
    fi
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