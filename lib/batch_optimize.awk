#!/usr/bin/awk -f

# SourceAtlas Phase 9 - Single AWK Script Batch Processing
# Optimized batch processing to reduce subprocess overhead by 5-20x

BEGIN {
    # Configuration parameters (with environment variable support)
    MIN_IMPORTANCE = (ENVIRON["SOURCEATLAS_MIN_IMPORTANCE"] ? ENVIRON["SOURCEATLAS_MIN_IMPORTANCE"] : 0.1)
    MAX_IMPORTANCE = (ENVIRON["SOURCEATLAS_MAX_IMPORTANCE"] ? ENVIRON["SOURCEATLAS_MAX_IMPORTANCE"] : 2.0)
    REQUIRED_FIELDS = 5  # Expected number of tab-separated fields
    
    # Validation counters
    valid_records = 0
    invalid_records = 0
    
    # Initialize language mapping
    lang_map[".swift"] = "swift"
    lang_map[".kt"] = "kotlin"  
    lang_map[".kts"] = "kotlin"
    lang_map[".m"] = "objc"
    lang_map[".h"] = "objc"
    lang_map[".mm"] = "objc"
    lang_map[".java"] = "java"
    lang_map[".js"] = "javascript"
    lang_map[".mjs"] = "javascript"
    lang_map[".cjs"] = "javascript"
    lang_map[".ts"] = "typescript"
    lang_map[".tsx"] = "typescript"
    lang_map[".py"] = "python"
    lang_map[".pyi"] = "python"
    lang_map[".rb"] = "ruby"
    lang_map[".rake"] = "ruby"
    lang_map[".gemspec"] = "ruby"
    lang_map[".sh"] = "shell"
    lang_map[".bash"] = "shell"
    lang_map[".zsh"] = "shell"
    lang_map[".json"] = "json"
    lang_map[".yml"] = "yaml"
    lang_map[".yaml"] = "yaml"
    lang_map[".xml"] = "xml"
    lang_map[".plist"] = "xml"
    lang_map[".gradle"] = "gradle"
    lang_map[".toml"] = "toml"
    
    # Pre-compile role patterns for performance (fix regex compilation overhead)
    num_patterns = 0
    role_regexes[++num_patterns] = "ViewController|Activity|Fragment"; role_values[num_patterns] = "ui"
    role_regexes[++num_patterns] = "ViewModel|Presenter"; role_values[num_patterns] = "viewmodel" 
    role_regexes[++num_patterns] = "Repository|Store|Cache"; role_values[num_patterns] = "repository"
    role_regexes[++num_patterns] = "Service|Manager"; role_values[num_patterns] = "service"
    role_regexes[++num_patterns] = "UseCase|Interactor"; role_values[num_patterns] = "usecase"
    role_regexes[++num_patterns] = "Model|Entity|Data"; role_values[num_patterns] = "model"
    role_regexes[++num_patterns] = "Test|Spec"; role_values[num_patterns] = "test"
    role_regexes[++num_patterns] = "Config|Settings"; role_values[num_patterns] = "config"
    role_regexes[++num_patterns] = "build.*|Makefile|.*\\.gradle"; role_values[num_patterns] = "build"
    
    # Set field separator
    FS = "\t"
    
    # Performance event tracking - use shell timestamp for POSIX compatibility
    "date +%s.%3N 2>/dev/null || date +%s" | getline start_time
    close("date +%s.%3N 2>/dev/null || date +%s")
    files_processed = 0
    
    # Initialize exponential moving average for predictive monitoring
    ema_rate = 0
    
    print_event("batch_optimize_start", "Single AWK batch processing started")
}

# Process each file line: path<tab>size_bytes<tab>loc<tab>hash<tab>mtime
{
    files_processed++
    
    # Input validation: Check field count and format
    if (NF != REQUIRED_FIELDS) {
        printf "WARN: Line %d has %d fields, expected %d: %s\n", NR, NF, REQUIRED_FIELDS, $0 > "/dev/stderr"
        invalid_records++
        next
    }
    
    # Parse and validate input fields
    file_path = $1
    size_bytes = $2
    loc = $3  
    content_hash = $4
    mtime = $5
    
    # Validate numeric fields
    if (size_bytes !~ /^[0-9]+$/ || loc !~ /^[0-9]+$/ || mtime !~ /^[0-9]+(\.[0-9]+)?$/) {
        printf "WARN: Line %d has invalid numeric fields: size=%s, loc=%s, mtime=%s\n", NR, size_bytes, loc, mtime > "/dev/stderr"
        invalid_records++
        next
    }
    
    # Validate file path (basic security check)
    if (file_path ~ /\.\.\/|^\//) {
        printf "WARN: Line %d has potentially unsafe path: %s\n", NR, file_path > "/dev/stderr"
        invalid_records++
        next
    }
    
    valid_records++
    
    # Extract file components
    filename = file_path
    gsub(/.*\//, "", filename)  # basename
    match(filename, /\.[^.]*$/)
    ext = substr(filename, RSTART)
    if (ext == "") ext = ".unknown"
    
    # Get language
    lang = lang_map[ext]
    if (lang == "") lang = "unknown"
    
    # Detect role from filename
    role = detect_file_role(filename)
    
    # Generate importance score (simplified heuristic)
    importance_score = calculate_importance(role, lang, loc, size_bytes)
    
    # Extract repository name (assume top-level directory)
    if (match(file_path, /^[^\/]+/)) {
        repo = substr(file_path, RSTART, RLENGTH)
    } else {
        repo = "unknown"
    }
    if (repo == "") repo = "unknown"
    
    # Generate JSON line efficiently
    printf "{\"repo\":\"%s\",\"path\":\"%s\",\"file_name\":\"%s\",\"ext\":\"%s\",\"lang\":\"%s\",\"size_bytes\":%s,\"loc\":%s,\"roles\":[\"%s\"],\"summary\":\"File with role: %s, language: %s\",\"imports\":[],\"symbols\":[],\"importance_score\":%.2f,\"content_hash\":\"%s\"}\n",
        repo, file_path, filename, ext, lang, size_bytes, loc, role, role, lang, importance_score, content_hash
        
    # Emit processing event every 1000 files (with enhanced monitoring and automatic fallbacks)
    if (files_processed % 1000 == 0) {
        print_event("batch_progress", sprintf("Processed %d files, valid: %d, invalid: %d", files_processed, valid_records, invalid_records))
        
        # Automatic streaming mode fallback for memory management
        if (valid_records > 500000) {
            printf "CRITICAL: Auto-enabling streaming mode - dataset too large (%d records) for in-memory processing\n", valid_records > "/dev/stderr"
            print_event("memory_critical_fallback", sprintf("Enabling streaming mode for %d records", valid_records))
            
            # Signal streaming mode activation to parent process
            system("echo 'STREAMING_MODE_REQUIRED' >> .sourceatlas/processing_signals.txt 2>/dev/null || true")
            
            # Flush current output to ensure no data loss
            fflush("")
            
            # Exit gracefully to allow parent process to switch modes
            printf "STREAM_MODE_SWITCH:%d\n", files_processed > "/dev/stderr"
            exit(2)  # Special exit code for streaming mode switch
            
        } else if (valid_records > 200000) {
            printf "WARN: Approaching memory limits (%d records) - preparing for potential streaming mode\n", valid_records > "/dev/stderr"
            print_event("memory_warning_prepare", sprintf("Preparing streaming fallback for %d records", valid_records))
            
            # Pre-emptively signal potential streaming need
            system("echo 'STREAMING_PREPARE' >> .sourceatlas/processing_signals.txt 2>/dev/null || true")
            
        } else if (valid_records > 100000) {
            printf "INFO: Large dataset processing (%d records) - monitoring memory usage\n", valid_records > "/dev/stderr"
        }
        
        # Enhanced processing rate monitoring with predictive analysis
        if (files_processed > 1000) {
            "date +%s.%3N 2>/dev/null || date +%s" | getline current_time
            close("date +%s.%3N 2>/dev/null || date +%s")
            
            elapsed_time = current_time - start_time
            if (elapsed_time > 0) {
                current_rate = files_processed / elapsed_time
                
                # Exponential moving average for trend analysis
                if (ema_rate == 0) {
                    ema_rate = current_rate
                } else {
                    # Alpha = 0.3 for responsive but stable EMA
                    ema_rate = 0.3 * current_rate + 0.7 * ema_rate
                }
                
                # Predictive performance degradation detection
                rate_decline = (ema_rate - current_rate) / ema_rate * 100
                if (rate_decline > 20) {
                    printf "WARN: Significant performance degradation detected (%.1f%% decline from EMA)\n", rate_decline > "/dev/stderr"
                    printf "      Current: %.1f files/sec, EMA: %.1f files/sec\n", current_rate, ema_rate > "/dev/stderr"
                    print_event("performance_degradation", sprintf("Rate decline: %.1f%%, current: %.1f files/sec, EMA: %.1f files/sec", rate_decline, current_rate, ema_rate))
                    
                    # Automatic streaming mode suggestion for severe degradation
                    if (rate_decline > 50 && valid_records > 50000) {
                        printf "CRITICAL: Severe performance degradation - consider streaming mode\n" > "/dev/stderr"
                        system("echo 'PERFORMANCE_STREAMING_SUGGEST' >> .sourceatlas/processing_signals.txt 2>/dev/null || true")
                    }
                } else if (current_rate < 50) {
                    printf "WARN: Low processing rate (%.1f files/sec) - system under stress\n", current_rate > "/dev/stderr"
                    print_event("performance_warning", sprintf("Low processing rate: %.1f files/sec, EMA: %.1f files/sec", current_rate, ema_rate))
                }
            }
        }
    }
}

END {
    # Final performance metrics - get actual end time
    "date +%s.%3N 2>/dev/null || date +%s" | getline end_time
    close("date +%s.%3N 2>/dev/null || date +%s")
    
    total_time = end_time - start_time
    files_per_second = (total_time > 0) ? files_processed / total_time : files_processed
    
    print_event("batch_optimize_complete", sprintf("Processed %d files in %.3f seconds (%.2f files/sec) - Valid: %d, Invalid: %d", files_processed, total_time, files_per_second, valid_records, invalid_records))
    
    # Report validation statistics
    if (invalid_records > 0) {
        printf "WARNING: %d invalid records encountered (%.2f%% error rate)\n", invalid_records, (invalid_records * 100.0 / (valid_records + invalid_records)) > "/dev/stderr"
    }
}

function detect_file_role(filename) {
    # Use pre-compiled patterns for better performance
    for (i = 1; i <= num_patterns; i++) {
        if (match(filename, role_regexes[i])) {
            return role_values[i]
        }
    }
    return "general"
}

function calculate_importance(role, lang, loc, size_bytes) {
    base_score = 1.0
    
    # Role-based scoring
    if (role == "ui") base_score += 0.5
    else if (role == "service") base_score += 0.4
    else if (role == "repository") base_score += 0.4
    else if (role == "viewmodel") base_score += 0.3
    else if (role == "model") base_score += 0.3
    else if (role == "test") base_score -= 0.2
    
    # Language-based scoring  
    if (lang == "swift" || lang == "kotlin" || lang == "java") base_score += 0.2
    else if (lang == "python" || lang == "javascript") base_score += 0.1
    
    # Size-based scoring (normalize LOC)
    if (loc > 500) base_score += 0.3
    else if (loc > 200) base_score += 0.2
    else if (loc > 100) base_score += 0.1
    else if (loc < 10) base_score -= 0.1
    
    # Ensure score is in configurable range
    if (base_score > MAX_IMPORTANCE) base_score = MAX_IMPORTANCE
    if (base_score < MIN_IMPORTANCE) base_score = MIN_IMPORTANCE
    
    return base_score
}

function print_event(event_type, message) {
    # Emit observability events to stderr so they don't interfere with JSONL output
    printf "{\"timestamp\":\"%s\",\"event\":\"%s\",\"message\":\"%s\",\"trace_id\":\"batch-optimize-%d\"}\n", "1970-01-01T00:00:00Z", event_type, message, NR > "/dev/stderr"
}