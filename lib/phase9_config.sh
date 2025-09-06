#!/bin/bash

# SourceAtlas Phase 9 - Centralized Configuration Management
# Provides centralized defaults and environment variable management for enterprise features

# Global configuration file path
SOURCEATLAS_CONFIG_FILE="${SOURCEATLAS_CONFIG_FILE:-${HOME}/.sourceatlas/config}"

# ==========================================
# Performance & Resource Configuration
# ==========================================

# Worker Management
export SOURCEATLAS_MIN_WORKERS="${SOURCEATLAS_MIN_WORKERS:-2}"
export SOURCEATLAS_MAX_WORKERS="${SOURCEATLAS_MAX_WORKERS:-16}"
export SOURCEATLAS_WORKER_MULTIPLIER="${SOURCEATLAS_WORKER_MULTIPLIER:-2}"  # CPU cores * multiplier

# Memory Management (in records)
export SOURCEATLAS_MEMORY_WARNING_THRESHOLD="${SOURCEATLAS_MEMORY_WARNING_THRESHOLD:-100000}"
export SOURCEATLAS_MEMORY_PREPARE_THRESHOLD="${SOURCEATLAS_MEMORY_PREPARE_THRESHOLD:-200000}"  
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD="${SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD:-500000}"

# Performance Monitoring
export SOURCEATLAS_EMA_ALPHA="${SOURCEATLAS_EMA_ALPHA:-0.3}"  # EMA smoothing factor (0.1-0.5)
export SOURCEATLAS_PERFORMANCE_WARNING_THRESHOLD="${SOURCEATLAS_PERFORMANCE_WARNING_THRESHOLD:-20}"  # % decline
export SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD="${SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD:-50}"  # % decline
export SOURCEATLAS_MIN_PROCESSING_RATE="${SOURCEATLAS_MIN_PROCESSING_RATE:-50}"  # files/sec

# ==========================================
# Checkpoint & Recovery Configuration  
# ==========================================

# Checkpoint Settings
export SOURCEATLAS_CHECKPOINT_INTERVAL="${SOURCEATLAS_CHECKPOINT_INTERVAL:-60}"  # seconds
export SOURCEATLAS_CHECKPOINT_RETENTION="${SOURCEATLAS_CHECKPOINT_RETENTION:-5}"  # number of checkpoints to keep
export SOURCEATLAS_EMERGENCY_CHECKPOINT="${SOURCEATLAS_EMERGENCY_CHECKPOINT:-true}"  # enable/disable

# Recovery Settings
export SOURCEATLAS_AUTO_RECOVERY="${SOURCEATLAS_AUTO_RECOVERY:-true}"
export SOURCEATLAS_RECOVERY_TIMEOUT="${SOURCEATLAS_RECOVERY_TIMEOUT:-300}"  # seconds

# ==========================================
# Observability & Monitoring Configuration
# ==========================================

# Event Logging
export SOURCEATLAS_EVENTS_ENABLED="${SOURCEATLAS_EVENTS_ENABLED:-true}"
export SOURCEATLAS_EVENTS_FILE="${SOURCEATLAS_EVENTS_FILE:-.sourceatlas/events.jsonl}"
export SOURCEATLAS_EVENTS_BUFFER_SIZE="${SOURCEATLAS_EVENTS_BUFFER_SIZE:-1000}"

# Metrics Export
export SOURCEATLAS_METRICS_ENABLED="${SOURCEATLAS_METRICS_ENABLED:-false}"
export SOURCEATLAS_METRICS_FILE="${SOURCEATLAS_METRICS_FILE:-.sourceatlas/metrics.jsonl}"
export SOURCEATLAS_METRICS_INTERVAL="${SOURCEATLAS_METRICS_INTERVAL:-30}"  # seconds

# Progress Reporting
export SOURCEATLAS_PROGRESS_INTERVAL="${SOURCEATLAS_PROGRESS_INTERVAL:-1000}"  # files processed
export SOURCEATLAS_PROGRESS_VERBOSE="${SOURCEATLAS_PROGRESS_VERBOSE:-false}"

# Dashboard Integration
export SOURCEATLAS_DASHBOARD_WEBHOOK="${SOURCEATLAS_DASHBOARD_WEBHOOK:-}"  # HTTP endpoint
export SOURCEATLAS_DASHBOARD_API_KEY="${SOURCEATLAS_DASHBOARD_API_KEY:-}"
export SOURCEATLAS_DASHBOARD_ENABLED="${SOURCEATLAS_DASHBOARD_ENABLED:-false}"

# ==========================================
# Quality & Validation Configuration
# ==========================================

# Importance Scoring
export SOURCEATLAS_MIN_IMPORTANCE="${SOURCEATLAS_MIN_IMPORTANCE:-0.1}"
export SOURCEATLAS_MAX_IMPORTANCE="${SOURCEATLAS_MAX_IMPORTANCE:-2.0}"

# Input Validation
export SOURCEATLAS_STRICT_VALIDATION="${SOURCEATLAS_STRICT_VALIDATION:-true}"
export SOURCEATLAS_MAX_PATH_LENGTH="${SOURCEATLAS_MAX_PATH_LENGTH:-4096}"
export SOURCEATLAS_MAX_FILE_SIZE_MB="${SOURCEATLAS_MAX_FILE_SIZE_MB:-100}"

# ==========================================
# Environment-Specific Overrides
# ==========================================

# Load user configuration file if it exists
load_user_config() {
    if [[ -f "$SOURCEATLAS_CONFIG_FILE" ]]; then
        echo "Loading configuration from: $SOURCEATLAS_CONFIG_FILE" >&2
        
        # Source the config file safely
        if source "$SOURCEATLAS_CONFIG_FILE" 2>/dev/null; then
            echo "✓ Configuration loaded successfully" >&2
        else
            echo "⚠ Warning: Failed to load configuration file" >&2
        fi
    fi
}

# Validate configuration values
validate_config() {
    local errors=()
    local warnings=()
    
    # ==========================================
    # Critical Threshold Validation
    # ==========================================
    
    # Validate memory threshold progression
    if [[ $SOURCEATLAS_MEMORY_WARNING_THRESHOLD -ge $SOURCEATLAS_MEMORY_PREPARE_THRESHOLD ]]; then
        errors+=("MEMORY_WARNING_THRESHOLD ($SOURCEATLAS_MEMORY_WARNING_THRESHOLD) must be < MEMORY_PREPARE_THRESHOLD ($SOURCEATLAS_MEMORY_PREPARE_THRESHOLD)")
    fi
    
    if [[ $SOURCEATLAS_MEMORY_PREPARE_THRESHOLD -ge $SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD ]]; then
        errors+=("MEMORY_PREPARE_THRESHOLD ($SOURCEATLAS_MEMORY_PREPARE_THRESHOLD) must be < MEMORY_CRITICAL_THRESHOLD ($SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD)")
    fi
    
    # Validate threshold values are reasonable
    if [[ $SOURCEATLAS_MEMORY_WARNING_THRESHOLD -lt 1000 ]]; then
        warnings+=("MEMORY_WARNING_THRESHOLD ($SOURCEATLAS_MEMORY_WARNING_THRESHOLD) is very low, may trigger frequently")
    fi
    
    if [[ $SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD -gt 2000000 ]]; then
        warnings+=("MEMORY_CRITICAL_THRESHOLD ($SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD) is very high, may cause memory issues")
    fi
    
    # Validate threshold gaps are reasonable
    local warning_prepare_gap=$((SOURCEATLAS_MEMORY_PREPARE_THRESHOLD - SOURCEATLAS_MEMORY_WARNING_THRESHOLD))
    local prepare_critical_gap=$((SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD - SOURCEATLAS_MEMORY_PREPARE_THRESHOLD))
    
    if [[ $warning_prepare_gap -lt 50000 ]]; then
        warnings+=("Gap between WARNING and PREPARE thresholds ($warning_prepare_gap) is small, may not provide enough reaction time")
    fi
    
    if [[ $prepare_critical_gap -lt 100000 ]]; then
        warnings+=("Gap between PREPARE and CRITICAL thresholds ($prepare_critical_gap) is small, may not provide enough reaction time")
    fi
    
    # ==========================================
    # EMA Alpha Validation (Enhanced)
    # ==========================================
    
    # Validate EMA alpha is numeric and in valid range
    if ! echo "$SOURCEATLAS_EMA_ALPHA" | grep -qE '^0\.[0-9]+$'; then
        errors+=("SOURCEATLAS_EMA_ALPHA must be numeric decimal between 0.1-0.5 (got: '$SOURCEATLAS_EMA_ALPHA')")
    else
        # Check if EMA alpha is in recommended range (0.1-0.5)
        local ema_check
        ema_check=$(echo "$SOURCEATLAS_EMA_ALPHA >= 0.1 && $SOURCEATLAS_EMA_ALPHA <= 0.5" | bc -l 2>/dev/null || echo "0")
        
        if [[ "$ema_check" != "1" ]]; then
            errors+=("SOURCEATLAS_EMA_ALPHA must be between 0.1-0.5 for optimal performance (got: $SOURCEATLAS_EMA_ALPHA)")
        fi
        
        # Provide specific guidance based on EMA value
        local ema_value_check
        ema_value_check=$(echo "$SOURCEATLAS_EMA_ALPHA < 0.2" | bc -l 2>/dev/null || echo "0")
        if [[ "$ema_value_check" == "1" ]]; then
            warnings+=("EMA_ALPHA ($SOURCEATLAS_EMA_ALPHA) is low - EMA will be very stable but slow to detect changes")
        fi
        
        ema_value_check=$(echo "$SOURCEATLAS_EMA_ALPHA > 0.4" | bc -l 2>/dev/null || echo "0")
        if [[ "$ema_value_check" == "1" ]]; then
            warnings+=("EMA_ALPHA ($SOURCEATLAS_EMA_ALPHA) is high - EMA will be responsive but may be noisy")
        fi
    fi
    
    # ==========================================
    # Worker Count System Limits Validation
    # ==========================================
    
    # Get system CPU count for validation
    local system_cpu_count=4  # Default fallback
    if command -v nproc >/dev/null 2>&1; then
        system_cpu_count=$(nproc 2>/dev/null || echo "4")
    elif [[ -r /proc/cpuinfo ]]; then
        system_cpu_count=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "4")
    elif command -v sysctl >/dev/null 2>&1 && sysctl -n hw.ncpu >/dev/null 2>&1; then
        system_cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
    fi
    
    # Validate worker bounds against system capabilities
    if [[ $SOURCEATLAS_MIN_WORKERS -lt 1 ]] || [[ $SOURCEATLAS_MIN_WORKERS -gt 32 ]]; then
        errors+=("SOURCEATLAS_MIN_WORKERS must be between 1-32 (got: $SOURCEATLAS_MIN_WORKERS)")
    fi
    
    if [[ $SOURCEATLAS_MAX_WORKERS -lt $SOURCEATLAS_MIN_WORKERS ]]; then
        errors+=("SOURCEATLAS_MAX_WORKERS ($SOURCEATLAS_MAX_WORKERS) must be >= MIN_WORKERS ($SOURCEATLAS_MIN_WORKERS)")
    fi
    
    if [[ $SOURCEATLAS_MAX_WORKERS -gt 64 ]]; then
        errors+=("SOURCEATLAS_MAX_WORKERS must be <= 64 (got: $SOURCEATLAS_MAX_WORKERS)")
    fi
    
    # Check worker count against system CPU limits
    local recommended_max=$((system_cpu_count * 3))  # Conservative recommendation
    local absolute_max=$((system_cpu_count * 6))     # Absolute maximum
    
    if [[ $SOURCEATLAS_MAX_WORKERS -gt $absolute_max ]]; then
        errors+=("MAX_WORKERS ($SOURCEATLAS_MAX_WORKERS) exceeds system limit of ${absolute_max} (${system_cpu_count} CPUs × 6)")
    elif [[ $SOURCEATLAS_MAX_WORKERS -gt $recommended_max ]]; then
        warnings+=("MAX_WORKERS ($SOURCEATLAS_MAX_WORKERS) exceeds recommended limit of ${recommended_max} (${system_cpu_count} CPUs × 3)")
    fi
    
    # Check if worker count is too low for the system
    if [[ $SOURCEATLAS_MAX_WORKERS -lt $system_cpu_count ]] && [[ $system_cpu_count -gt 2 ]]; then
        warnings+=("MAX_WORKERS ($SOURCEATLAS_MAX_WORKERS) is less than CPU count ($system_cpu_count), may underutilize system")
    fi
    
    # ==========================================
    # Performance Threshold Validation
    # ==========================================
    
    # Validate performance thresholds are logical
    if [[ $SOURCEATLAS_PERFORMANCE_WARNING_THRESHOLD -ge $SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD ]]; then
        errors+=("PERFORMANCE_WARNING_THRESHOLD ($SOURCEATLAS_PERFORMANCE_WARNING_THRESHOLD) must be < CRITICAL_THRESHOLD ($SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD)")
    fi
    
    # Validate performance threshold ranges
    if [[ $SOURCEATLAS_PERFORMANCE_WARNING_THRESHOLD -lt 5 ]] || [[ $SOURCEATLAS_PERFORMANCE_WARNING_THRESHOLD -gt 50 ]]; then
        warnings+=("PERFORMANCE_WARNING_THRESHOLD ($SOURCEATLAS_PERFORMANCE_WARNING_THRESHOLD) outside recommended range 5-50%")
    fi
    
    if [[ $SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD -lt 20 ]] || [[ $SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD -gt 80 ]]; then
        warnings+=("PERFORMANCE_CRITICAL_THRESHOLD ($SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD) outside recommended range 20-80%")
    fi
    
    # ==========================================
    # Additional System Validation
    # ==========================================
    
    # Validate checkpoint interval is reasonable
    if [[ $SOURCEATLAS_CHECKPOINT_INTERVAL -lt 10 ]]; then
        warnings+=("CHECKPOINT_INTERVAL ($SOURCEATLAS_CHECKPOINT_INTERVAL) is very frequent, may impact performance")
    elif [[ $SOURCEATLAS_CHECKPOINT_INTERVAL -gt 600 ]]; then
        warnings+=("CHECKPOINT_INTERVAL ($SOURCEATLAS_CHECKPOINT_INTERVAL) is very infrequent, may lose more work on failure")
    fi
    
    # Validate progress interval
    if [[ $SOURCEATLAS_PROGRESS_INTERVAL -lt 100 ]]; then
        warnings+=("PROGRESS_INTERVAL ($SOURCEATLAS_PROGRESS_INTERVAL) is very frequent, may generate excessive output")
    elif [[ $SOURCEATLAS_PROGRESS_INTERVAL -gt 10000 ]]; then
        warnings+=("PROGRESS_INTERVAL ($SOURCEATLAS_PROGRESS_INTERVAL) is infrequent, may provide poor progress visibility")
    fi
    
    # ==========================================
    # Report Results
    # ==========================================
    
    # Report validation errors (blocking)
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "❌ Configuration validation errors:" >&2
        for error in "${errors[@]}"; do
            echo "   • $error" >&2
        done
        echo "" >&2
    fi
    
    # Report validation warnings (non-blocking)
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo "⚠️  Configuration warnings:" >&2
        for warning in "${warnings[@]}"; do
            echo "   • $warning" >&2
        done
        echo "" >&2
    fi
    
    # Summary
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "❌ Configuration validation failed with ${#errors[@]} error(s) and ${#warnings[@]} warning(s)" >&2
        return 1
    else
        echo "✅ Configuration validation passed (${#warnings[@]} warning(s), ${#errors[@]} error(s))" >&2
        return 0
    fi
}

# Generate sample configuration file
generate_sample_config() {
    local config_file="$1"
    local config_dir
    config_dir=$(dirname "$config_file")
    
    # Create config directory if needed
    mkdir -p "$config_dir"
    
    cat > "$config_file" << 'EOF'
# SourceAtlas Phase 9 Configuration
# Customize these values for your environment

# Performance Tuning
export SOURCEATLAS_MAX_WORKERS=8
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=300000
export SOURCEATLAS_EMA_ALPHA=0.2

# Observability
export SOURCEATLAS_METRICS_ENABLED=true
export SOURCEATLAS_PROGRESS_VERBOSE=true

# Dashboard Integration (uncomment and configure)
# export SOURCEATLAS_DASHBOARD_ENABLED=true
# export SOURCEATLAS_DASHBOARD_WEBHOOK="https://your-dashboard.com/api/metrics"
# export SOURCEATLAS_DASHBOARD_API_KEY="your-api-key"

# Development/Debug Settings
# export SOURCEATLAS_STRICT_VALIDATION=false
# export SOURCEATLAS_CHECKPOINT_INTERVAL=30
EOF

    echo "✅ Sample configuration generated: $config_file" >&2
    echo "   Edit this file to customize Phase 9 behavior" >&2
}

# Print current configuration summary
print_config_summary() {
    echo "📊 Phase 9 Configuration Summary:" >&2
    echo "=================================" >&2
    echo "Workers: ${SOURCEATLAS_MIN_WORKERS}-${SOURCEATLAS_MAX_WORKERS} (multiplier: ${SOURCEATLAS_WORKER_MULTIPLIER}x)" >&2
    echo "Memory thresholds: ${SOURCEATLAS_MEMORY_WARNING_THRESHOLD}/${SOURCEATLAS_MEMORY_PREPARE_THRESHOLD}/${SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD} records" >&2
    echo "EMA alpha: ${SOURCEATLAS_EMA_ALPHA}, Performance thresholds: ${SOURCEATLAS_PERFORMANCE_WARNING_THRESHOLD}%/${SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD}%" >&2
    echo "Checkpoints: ${SOURCEATLAS_CHECKPOINT_INTERVAL}s interval, ${SOURCEATLAS_CHECKPOINT_RETENTION} retention" >&2
    echo "Observability: Events=${SOURCEATLAS_EVENTS_ENABLED}, Metrics=${SOURCEATLAS_METRICS_ENABLED}, Dashboard=${SOURCEATLAS_DASHBOARD_ENABLED}" >&2
    echo "=================================" >&2
}

# Apply configuration based on detected environment
auto_configure_environment() {
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")
    
    # Adjust worker count based on CPU cores
    local optimal_workers=$((cpu_cores * SOURCEATLAS_WORKER_MULTIPLIER))
    
    # Apply bounds
    if [[ $optimal_workers -lt $SOURCEATLAS_MIN_WORKERS ]]; then
        optimal_workers=$SOURCEATLAS_MIN_WORKERS
    elif [[ $optimal_workers -gt $SOURCEATLAS_MAX_WORKERS ]]; then
        optimal_workers=$SOURCEATLAS_MAX_WORKERS
    fi
    
    export SOURCEATLAS_OPTIMAL_WORKERS="$optimal_workers"
    
    # Detect CI environment and adjust settings
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${JENKINS_URL:-}" ]]; then
        echo "🔧 CI environment detected - applying optimized settings" >&2
        export SOURCEATLAS_METRICS_ENABLED="true"
        export SOURCEATLAS_PROGRESS_VERBOSE="false"
        export SOURCEATLAS_CHECKPOINT_INTERVAL="120"  # Less frequent in CI
        export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD="750000"  # Higher threshold for CI
    fi
    
    # Detect resource-constrained environment
    local available_memory_kb
    if [[ -r /proc/meminfo ]]; then
        available_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "4194304")
        
        # If less than 2GB available, use conservative settings
        if [[ $available_memory_kb -lt 2097152 ]]; then
            echo "⚠ Low memory detected - applying conservative settings" >&2
            export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD="250000"
            export SOURCEATLAS_MAX_WORKERS="4"
            export SOURCEATLAS_CHECKPOINT_INTERVAL="30"  # More frequent checkpoints
        fi
    fi
}

# Initialize configuration system
init_phase9_config() {
    # Load user configuration
    load_user_config
    
    # Auto-configure based on environment
    auto_configure_environment
    
    # Validate configuration
    if ! validate_config; then
        echo "❌ Configuration validation failed - using defaults" >&2
        return 1
    fi
    
    # Print summary if verbose
    if [[ "${SOURCEATLAS_PROGRESS_VERBOSE:-false}" == "true" ]]; then
        print_config_summary
    fi
    
    return 0
}

# Export configuration functions
export -f load_user_config
export -f validate_config
export -f generate_sample_config
export -f print_config_summary
export -f auto_configure_environment
export -f init_phase9_config

# Auto-initialize if sourced (not executed directly)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_phase9_config
fi