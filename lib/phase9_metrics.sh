#!/bin/bash

# SourceAtlas Phase 9 - Structured Metrics Export & Monitoring Integration
# Provides comprehensive metrics collection, export, and dashboard integration

# Ensure configuration is loaded
if [[ -z "${SOURCEATLAS_METRICS_ENABLED:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/phase9_config.sh"
fi

# ==========================================
# Metrics Collection System
# ==========================================

METRICS_START_TIME=""
METRICS_BUFFER=()
METRICS_COUNTERS=""
METRICS_GAUGES=""
METRICS_TIMERS=""

# Initialize metrics system
init_metrics() {
    METRICS_START_TIME=$(date +%s.%3N)
    METRICS_COUNTERS=$(mktemp "${TMPDIR:-/tmp}/sourceatlas_metrics_counters.XXXXXX")
    METRICS_GAUGES=$(mktemp "${TMPDIR:-/tmp}/sourceatlas_metrics_gauges.XXXXXX")
    METRICS_TIMERS=$(mktemp "${TMPDIR:-/tmp}/sourceatlas_metrics_timers.XXXXXX")
    
    # Initialize counters file
    cat > "$METRICS_COUNTERS" << EOF
files_processed=0
files_invalid=0
files_streamed=0
checkpoints_created=0
workers_spawned=0
performance_warnings=0
memory_warnings=0
streaming_switches=0
recovery_attempts=0
dashboard_exports=0
EOF

    echo "🔧 Metrics system initialized (file: $METRICS_COUNTERS)" >&2
}

# Record a counter metric
record_counter() {
    local metric_name="$1"
    local increment="${2:-1}"
    
    if [[ ! -f "$METRICS_COUNTERS" ]]; then
        init_metrics
    fi
    
    # Atomic increment using awk
    awk -v metric="$metric_name" -v inc="$increment" '
    BEGIN { FS="="; OFS="=" }
    $1 == metric { $2 = $2 + inc; found=1 }
    { print }
    END { if (!found) print metric "=" inc }
    ' "$METRICS_COUNTERS" > "$METRICS_COUNTERS.tmp" && mv "$METRICS_COUNTERS.tmp" "$METRICS_COUNTERS"
}

# Record a gauge metric (current value)
record_gauge() {
    local metric_name="$1"
    local value="$2"
    local timestamp="${3:-$(date +%s.%3N)}"
    
    if [[ ! -f "$METRICS_GAUGES" ]]; then
        touch "$METRICS_GAUGES"
    fi
    
    echo "${metric_name}:${timestamp}=${value}" >> "$METRICS_GAUGES"
}

# Record a timing metric
record_timer() {
    local metric_name="$1"
    local duration="$2"
    local unit="${3:-ms}"
    
    if [[ ! -f "$METRICS_TIMERS" ]]; then
        touch "$METRICS_TIMERS"
    fi
    
    echo "${metric_name}:$(date +%s.%3N)=${duration}${unit}" >> "$METRICS_TIMERS"
}

# ==========================================
# Performance Metrics Collection
# ==========================================

# Start a performance measurement
start_performance_timer() {
    local timer_name="$1"
    local start_time
    start_time=$(date +%s.%3N)
    
    echo "$start_time" > "${TMPDIR:-/tmp}/timer_${timer_name}.start"
}

# End performance measurement and record
end_performance_timer() {
    local timer_name="$1"
    local start_file="${TMPDIR:-/tmp}/timer_${timer_name}.start"
    
    if [[ -f "$start_file" ]]; then
        local start_time
        start_time=$(cat "$start_file")
        local end_time
        end_time=$(date +%s.%3N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        local duration_ms
        duration_ms=$(echo "$duration * 1000" | bc 2>/dev/null || echo "0")
        
        record_timer "$timer_name" "$duration_ms" "ms"
        rm -f "$start_file"
        
        echo "$duration_ms"
    else
        echo "0"
    fi
}

# Collect system resource metrics
collect_system_metrics() {
    local timestamp
    timestamp=$(date +%s.%3N)
    
    # CPU usage
    if command -v top >/dev/null 2>&1; then
        local cpu_usage
        cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "0")
        record_gauge "system.cpu_usage" "$cpu_usage" "$timestamp"
    fi
    
    # Memory usage
    if [[ -r /proc/meminfo ]]; then
        local mem_total mem_available mem_usage_percent
        mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        mem_usage_percent=$(echo "scale=2; (($mem_total - $mem_available) * 100) / $mem_total" | bc 2>/dev/null || echo "0")
        
        record_gauge "system.memory_usage_percent" "$mem_usage_percent" "$timestamp"
        record_gauge "system.memory_available_mb" "$((mem_available / 1024))" "$timestamp"
    fi
    
    # Load average
    if [[ -r /proc/loadavg ]]; then
        local load_1min
        load_1min=$(cut -d' ' -f1 /proc/loadavg)
        record_gauge "system.load_1min" "$load_1min" "$timestamp"
    fi
    
    # Disk usage for output directory
    if [[ -d ".sourceatlas" ]]; then
        local disk_usage_kb
        disk_usage_kb=$(du -sk .sourceatlas | cut -f1)
        record_gauge "system.output_dir_size_mb" "$((disk_usage_kb / 1024))" "$timestamp"
    fi
}

# ==========================================
# Metrics Export Functions
# ==========================================

# Export metrics to JSON format
export_metrics_json() {
    local output_file="$1"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local session_duration
    session_duration=$(echo "$(date +%s.%3N) - $METRICS_START_TIME" | bc 2>/dev/null || echo "0")
    
    # Create JSON structure
    cat > "$output_file" << EOF
{
  "timestamp": "$timestamp",
  "session_duration_seconds": $session_duration,
  "counters": {
EOF

    # Add counters
    local first_counter=true
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        
        if [[ $first_counter == true ]]; then
            first_counter=false
        else
            echo "," >> "$output_file"
        fi
        
        printf '    "%s": %s' "$key" "$value" >> "$output_file"
    done < "$METRICS_COUNTERS"
    
    echo "" >> "$output_file"
    echo "  }," >> "$output_file"
    
    # Add gauges
    echo '  "gauges": {' >> "$output_file"
    local first_gauge=true
    if [[ -f "$METRICS_GAUGES" ]]; then
        while IFS='=' read -r key_ts value; do
            [[ -z "$key_ts" ]] && continue
            local metric_name="${key_ts%:*}"
            local gauge_timestamp="${key_ts#*:}"
            
            if [[ $first_gauge == true ]]; then
                first_gauge=false
            else
                echo "," >> "$output_file"
            fi
            
            printf '    "%s": {"value": %s, "timestamp": %s}' "$metric_name" "$value" "$gauge_timestamp" >> "$output_file"
        done < "$METRICS_GAUGES"
    fi
    
    echo "" >> "$output_file"
    echo "  }," >> "$output_file"
    
    # Add timers
    echo '  "timers": {' >> "$output_file"
    local first_timer=true
    if [[ -f "$METRICS_TIMERS" ]]; then
        while IFS='=' read -r key_ts value; do
            [[ -z "$key_ts" ]] && continue
            local metric_name="${key_ts%:*}"
            local timer_timestamp="${key_ts#*:}"
            
            if [[ $first_timer == true ]]; then
                first_timer=false
            else
                echo "," >> "$output_file"
            fi
            
            printf '    "%s": {"value": "%s", "timestamp": %s}' "$metric_name" "$value" "$timer_timestamp" >> "$output_file"
        done < "$METRICS_TIMERS"
    fi
    
    echo "" >> "$output_file"
    echo "  }" >> "$output_file"
    echo "}" >> "$output_file"
}

# Export metrics to CSV format
export_metrics_csv() {
    local output_file="$1"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Create CSV header
    echo "timestamp,metric_type,metric_name,value,unit" > "$output_file"
    
    # Add counters
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        echo "$timestamp,counter,$key,$value,count" >> "$output_file"
    done < "$METRICS_COUNTERS"
    
    # Add gauges
    if [[ -f "$METRICS_GAUGES" ]]; then
        while IFS='=' read -r key_ts value; do
            [[ -z "$key_ts" ]] && continue
            local metric_name="${key_ts%:*}"
            echo "$timestamp,gauge,$metric_name,$value," >> "$output_file"
        done < "$METRICS_GAUGES"
    fi
    
    # Add timers
    if [[ -f "$METRICS_TIMERS" ]]; then
        while IFS='=' read -r key_ts value; do
            [[ -z "$key_ts" ]] && continue
            local metric_name="${key_ts%:*}"
            local unit="${value##*[0-9]}"
            local numeric_value="${value%$unit}"
            echo "$timestamp,timer,$metric_name,$numeric_value,$unit" >> "$output_file"
        done < "$METRICS_TIMERS"
    fi
}

# Export metrics to Prometheus format
export_metrics_prometheus() {
    local output_file="$1"
    
    # Prometheus format with HELP and TYPE comments
    cat > "$output_file" << EOF
# HELP sourceatlas_files_processed_total Total number of files processed
# TYPE sourceatlas_files_processed_total counter
EOF

    # Add counters as Prometheus counters
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        local prom_name="sourceatlas_${key}_total"
        echo "${prom_name} ${value}" >> "$output_file"
    done < "$METRICS_COUNTERS"
    
    # Add gauges
    if [[ -f "$METRICS_GAUGES" ]]; then
        while IFS='=' read -r key_ts value; do
            [[ -z "$key_ts" ]] && continue
            local metric_name="${key_ts%:*}"
            local prom_name="sourceatlas_${metric_name//./_}"
            echo "# TYPE ${prom_name} gauge" >> "$output_file"
            echo "${prom_name} ${value}" >> "$output_file"
        done < "$METRICS_GAUGES"
    fi
}

# ==========================================
# Dashboard Integration
# ==========================================

# Send metrics to dashboard webhook
send_to_dashboard() {
    local webhook_url="$1"
    local api_key="$2"
    local metrics_json="$3"
    
    if [[ -z "$webhook_url" ]]; then
        return 0
    fi
    
    local curl_opts=("-X" "POST" "-H" "Content-Type: application/json")
    
    if [[ -n "$api_key" ]]; then
        curl_opts+=("-H" "Authorization: Bearer $api_key")
    fi
    
    curl_opts+=("-d" "@$metrics_json" "$webhook_url")
    
    if curl "${curl_opts[@]}" >/dev/null 2>&1; then
        record_counter "dashboard_exports" 1
        echo "✅ Metrics sent to dashboard: $webhook_url" >&2
    else
        echo "⚠ Failed to send metrics to dashboard: $webhook_url" >&2
        return 1
    fi
}

# Create dashboard-compatible payload
create_dashboard_payload() {
    local temp_json
    temp_json=$(mktemp "${TMPDIR:-/tmp}/dashboard_payload.XXXXXX.json")
    
    # Export to JSON first
    export_metrics_json "$temp_json"
    
    # Wrap in dashboard-specific format
    local wrapped_payload
    wrapped_payload=$(mktemp "${TMPDIR:-/tmp}/dashboard_wrapped.XXXXXX.json")
    
    cat > "$wrapped_payload" << EOF
{
  "source": "sourceatlas-phase9",
  "version": "1.0",
  "environment": "${SOURCEATLAS_ENVIRONMENT:-production}",
  "hostname": "$(hostname 2>/dev/null || echo unknown)",
  "metrics": $(cat "$temp_json")
}
EOF

    rm -f "$temp_json"
    echo "$wrapped_payload"
}

# ==========================================
# Automated Metrics Collection
# ==========================================

# Collect all metrics and export in specified formats
collect_and_export_metrics() {
    local export_formats=("${@:-json}")  # Default to JSON
    
    # Collect system metrics
    collect_system_metrics
    
    # Create output directory if needed
    mkdir -p "$(dirname "${SOURCEATLAS_METRICS_FILE}")"
    
    for format in "${export_formats[@]}"; do
        local output_file="${SOURCEATLAS_METRICS_FILE%.*}.${format}"
        
        case "$format" in
            "json")
                export_metrics_json "$output_file"
                echo "📊 Metrics exported to: $output_file" >&2
                ;;
            "csv") 
                export_metrics_csv "$output_file"
                echo "📊 CSV metrics exported to: $output_file" >&2
                ;;
            "prometheus"|"prom")
                export_metrics_prometheus "$output_file"
                echo "📊 Prometheus metrics exported to: $output_file" >&2
                ;;
            *)
                echo "⚠ Unknown export format: $format" >&2
                ;;
        esac
    done
    
    # Send to dashboard if enabled
    if [[ "${SOURCEATLAS_DASHBOARD_ENABLED:-false}" == "true" ]]; then
        local dashboard_payload
        dashboard_payload=$(create_dashboard_payload)
        
        send_to_dashboard \
            "$SOURCEATLAS_DASHBOARD_WEBHOOK" \
            "$SOURCEATLAS_DASHBOARD_API_KEY" \
            "$dashboard_payload"
            
        rm -f "$dashboard_payload"
    fi
}

# Start background metrics collection
start_metrics_collection() {
    if [[ "${SOURCEATLAS_METRICS_ENABLED:-false}" != "true" ]]; then
        return 0
    fi
    
    echo "🔧 Starting metrics collection (interval: ${SOURCEATLAS_METRICS_INTERVAL}s)" >&2
    
    # Initialize metrics system
    init_metrics
    
    # Start background collection process
    (
        while true; do
            sleep "${SOURCEATLAS_METRICS_INTERVAL}"
            collect_and_export_metrics "json"
        done
    ) &
    
    # Store background PID for cleanup
    echo $! > "${TMPDIR:-/tmp}/sourceatlas_metrics_collector.pid"
}

# Stop background metrics collection
stop_metrics_collection() {
    local pid_file="${TMPDIR:-/tmp}/sourceatlas_metrics_collector.pid"
    
    if [[ -f "$pid_file" ]]; then
        local collector_pid
        collector_pid=$(cat "$pid_file")
        
        if kill "$collector_pid" 2>/dev/null; then
            echo "🔧 Metrics collection stopped (PID: $collector_pid)" >&2
        fi
        
        rm -f "$pid_file"
    fi
    
    # Final metrics export
    if [[ "${SOURCEATLAS_METRICS_ENABLED:-false}" == "true" ]]; then
        collect_and_export_metrics "json" "csv"
    fi
    
    # Cleanup temp files
    [[ -f "$METRICS_COUNTERS" ]] && rm -f "$METRICS_COUNTERS"
}

# Export functions
export -f init_metrics
export -f record_counter
export -f record_gauge
export -f record_timer
export -f collect_system_metrics
export -f export_metrics_json
export -f export_metrics_csv
export -f send_to_dashboard
export -f collect_and_export_metrics
export -f start_metrics_collection
export -f stop_metrics_collection

# Trap to ensure cleanup on exit
trap stop_metrics_collection EXIT

# Auto-start metrics if enabled and sourced (not executed directly)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] && [[ "${SOURCEATLAS_METRICS_ENABLED:-false}" == "true" ]]; then
    start_metrics_collection
fi