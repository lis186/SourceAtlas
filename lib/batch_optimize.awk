#!/usr/bin/awk -f

# SourceAtlas Phase 9 - Single AWK Script Batch Processing
# Optimized batch processing to reduce subprocess overhead by 5-20x

BEGIN {
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
    
    # Initialize role patterns
    role_patterns["ViewController|Activity|Fragment"] = "ui"
    role_patterns["ViewModel|Presenter"] = "viewmodel"
    role_patterns["Repository|Store|Cache"] = "repository"
    role_patterns["Service|Manager"] = "service"
    role_patterns["UseCase|Interactor"] = "usecase"
    role_patterns["Model|Entity|Data"] = "model"
    role_patterns["Test|Spec"] = "test"
    role_patterns["Config|Settings"] = "config"
    role_patterns["build.*|Makefile|.*\\.gradle"] = "build"
    
    # Set field separator
    FS = "\t"
    
    # Performance event tracking
    start_time = systime()
    files_processed = 0
    
    print_event("batch_optimize_start", "Single AWK batch processing started")
}

# Process each file line: path<tab>size_bytes<tab>loc<tab>hash<tab>mtime
{
    files_processed++
    
    # Parse input fields
    file_path = $1
    size_bytes = $2
    loc = $3  
    content_hash = $4
    mtime = $5
    
    # Extract file components
    gsub(/.*\//, "", filename = file_path)  # basename
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
    match(file_path, /^[^/]+/)
    repo = substr(file_path, RSTART, RLENGTH)
    if (repo == "") repo = "unknown"
    
    # Generate JSON line efficiently
    printf "{\"repo\":\"%s\",\"path\":\"%s\",\"file_name\":\"%s\",\"ext\":\"%s\",\"lang\":\"%s\",\"size_bytes\":%s,\"loc\":%s,\"roles\":[\"%s\"],\"summary\":\"File with role: %s, language: %s\",\"imports\":[],\"symbols\":[],\"importance_score\":%.2f,\"content_hash\":\"%s\"}\n",
        repo, file_path, filename, ext, lang, size_bytes, loc, role, role, lang, importance_score, content_hash
        
    # Emit processing event every 1000 files
    if (files_processed % 1000 == 0) {
        print_event("batch_progress", sprintf("Processed %d files", files_processed))
    }
}

END {
    # Final performance metrics
    end_time = systime()
    total_time = end_time - start_time
    files_per_second = (total_time > 0) ? files_processed / total_time : files_processed
    
    print_event("batch_optimize_complete", sprintf("Processed %d files in %d seconds (%.2f files/sec)", files_processed, total_time, files_per_second))
}

function detect_file_role(filename) {
    for (pattern in role_patterns) {
        if (match(filename, pattern)) {
            return role_patterns[pattern]
        }
    }
    return "general"
}

function calculate_importance(role, lang, loc, size_bytes) {
    local base_score = 1.0
    
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
    
    # Ensure score is in reasonable range
    if (base_score > 2.0) base_score = 2.0
    if (base_score < 0.1) base_score = 0.1
    
    return base_score
}

function print_event(event_type, message) {
    # Emit observability events to stderr so they don't interfere with JSONL output
    printf "{\"timestamp\":\"%s\",\"event\":\"%s\",\"message\":\"%s\",\"trace_id\":\"batch-optimize-%d\"}\n", strftime("%Y-%m-%dT%H:%M:%SZ"), event_type, message, systime() > "/dev/stderr"
}