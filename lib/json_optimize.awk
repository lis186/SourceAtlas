#!/usr/bin/awk -f

# SourceAtlas Phase 9 - Memory-optimized JSON generation
# Stream-based JSON generation to prevent OOM on large files

BEGIN {
    # JSON streaming configuration
    buffer_size = 1000  # Process in chunks of 1000 records
    current_buffer_count = 0
    total_records = 0
    
    # Memory optimization flags
    optimize_memory = (ENVIRON["SOURCEATLAS_OPTIMIZE_MEMORY"] == "1")
    max_string_length = 1000  # Truncate very long strings
    
    # Track memory usage
    start_time = systime()
    
    # Initialize escape character mapping for performance
    escape_map["\""] = "\\\""
    escape_map["\\"] = "\\\\"
    escape_map["\n"] = "\\n"
    escape_map["\r"] = "\\r"
    escape_map["\t"] = "\\t"
    escape_map["\b"] = "\\b"
    escape_map["\f"] = "\\f"
    
    emit_event("json_optimize_start", "Memory-optimized JSON generation started")
}

# Process input record by record for streaming
{
    # Parse input (tab-separated fields)
    repo = $1
    path = $2
    file_name = $3
    ext = $4
    lang = $5
    size_bytes = $6
    loc = $7
    roles = $8
    summary = $9
    imports = $10
    symbols = $11
    importance_score = $12
    content_hash = $13
    
    # Memory optimization: truncate very long strings
    if (optimize_memory) {
        if (length(path) > max_string_length) path = substr(path, 1, max_string_length) "..."
        if (length(summary) > max_string_length) summary = substr(summary, 1, max_string_length) "..."
    }
    
    # Generate optimized JSON record
    json_record = generate_json_record(repo, path, file_name, ext, lang, size_bytes, loc, roles, summary, imports, symbols, importance_score, content_hash)
    
    # Output immediately (streaming)
    print json_record
    
    total_records++
    current_buffer_count++
    
    # Periodic memory management
    if (current_buffer_count >= buffer_size) {
        # Force garbage collection in some AWK implementations
        if (optimize_memory) {
            system("true")  # Minimal system call to trigger GC
        }
        
        current_buffer_count = 0
        emit_event("json_buffer_processed", sprintf("Processed %d records (total: %d)", buffer_size, total_records))
    }
}

END {
    end_time = systime()
    total_time = end_time - start_time
    records_per_second = (total_time > 0) ? total_records / total_time : total_records
    
    emit_event("json_optimize_complete", sprintf("Generated %d JSON records in %d seconds (%.2f records/sec)", total_records, total_time, records_per_second))
}

# Optimized JSON record generation
function generate_json_record(repo, path, file_name, ext, lang, size_bytes, loc, roles, summary, imports, symbols, importance_score, content_hash) {
    # Use string concatenation instead of sprintf for better memory efficiency
    local json = "{"
    
    # Required fields with proper escaping
    json = json "\"repo\":\"" json_escape(repo) "\""
    json = json ",\"path\":\"" json_escape(path) "\""
    json = json ",\"file_name\":\"" json_escape(file_name) "\""
    json = json ",\"ext\":\"" json_escape(ext) "\""
    json = json ",\"lang\":\"" json_escape(lang) "\""
    json = json ",\"size_bytes\":" (size_bytes+0)  # Ensure numeric
    json = json ",\"loc\":" (loc+0)  # Ensure numeric
    
    # Array fields (optimize for common cases)
    if (roles && roles != "[]" && roles != "") {
        json = json ",\"roles\":" format_json_array(roles)
    } else {
        json = json ",\"roles\":[\"general\"]"
    }
    
    json = json ",\"summary\":\"" json_escape(summary) "\""
    
    if (imports && imports != "[]" && imports != "") {
        json = json ",\"imports\":" format_json_array(imports)
    } else {
        json = json ",\"imports\":[]"
    }
    
    if (symbols && symbols != "[]" && symbols != "") {
        json = json ",\"symbols\":" symbols
    } else {
        json = json ",\"symbols\":[]"
    }
    
    json = json ",\"importance_score\":" (importance_score+0.0)  # Ensure float
    json = json ",\"content_hash\":\"" json_escape(content_hash) "\""
    
    json = json "}"
    
    return json
}

# Fast JSON string escaping
function json_escape(str) {
    if (!str) return ""
    
    local result = str
    
    # Replace each character that needs escaping
    gsub(/\\/, "\\\\", result)
    gsub(/"/, "\\\"", result)
    gsub(/\n/, "\\n", result)
    gsub(/\r/, "\\r", result)
    gsub(/\t/, "\\t", result)
    gsub(/\b/, "\\b", result)
    gsub(/\f/, "\\f", result)
    
    return result
}

# Format JSON array from string representation
function format_json_array(array_str) {
    # If already JSON array format, return as-is
    if (match(array_str, /^\[.*\]$/)) {
        return array_str
    }
    
    # If comma-separated values, convert to JSON array
    if (index(array_str, ",")) {
        local result = "["
        local first = 1
        local n = split(array_str, parts, ",")
        
        for (i = 1; i <= n; i++) {
            local part = parts[i]
            gsub(/^[ \t]+|[ \t]+$/, "", part)  # Trim whitespace
            if (part) {
                if (!first) result = result ","
                result = result "\"" json_escape(part) "\""
                first = 0
            }
        }
        result = result "]"
        return result
    }
    
    # Single value
    return "[\"" json_escape(array_str) "\"]"
}

# Emit observability event (to stderr to avoid mixing with JSON output)
function emit_event(event_type, message) {
    printf "{\"timestamp\":\"%s\",\"event\":\"%s\",\"message\":\"%s\",\"trace_id\":\"json-optimize-%d\",\"memory_optimized\":%s}\n", 
        strftime("%Y-%m-%dT%H:%M:%SZ"), event_type, message, systime(), (optimize_memory ? "true" : "false") > "/dev/stderr"
}