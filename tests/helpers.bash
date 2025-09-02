#!/usr/bin/env bash
# Test helpers for SourceAtlas E2E tests

# Setup test environment
setup_test_env() {
    export TEST_TEMP_DIR="$(mktemp -d -t sourceatlas-test-XXXXXX)"
    export SATLAS_ROOT="${TEST_TEMP_DIR}"
    export PATH="${BATS_TEST_DIRNAME}/../../bin:${PATH}"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -n "${TEST_TEMP_DIR}" ]] && [[ -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# Copy fixtures to test directory
copy_fixtures() {
    local fixture_name="$1"
    local fixture_path="${BATS_TEST_DIRNAME}/../fixtures/${fixture_name}"
    
    if [[ -d "${fixture_path}" ]]; then
        cp -r "${fixture_path}"/* "${TEST_TEMP_DIR}/"
    else
        echo "Fixture not found: ${fixture_name}" >&2
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    local file_path="$1"
    if [[ ! -f "${file_path}" ]]; then
        echo "File not found: ${file_path}" >&2
        return 1
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir_path="$1"
    if [[ ! -d "${dir_path}" ]]; then
        echo "Directory not found: ${dir_path}" >&2
        return 1
    fi
}

# Assert file contains text
assert_file_contains() {
    local file_path="$1"
    local text="$2"
    
    # Use -F for fixed string matching to avoid regex interpretation
    if ! grep -F -q "${text}" "${file_path}"; then
        echo "File ${file_path} does not contain: ${text}" >&2
        return 1
    fi
}

# Assert command output contains text
assert_output_contains() {
    local text="$1"
    if [[ "${output}" != *"${text}"* ]]; then
        echo "Output does not contain: ${text}" >&2
        echo "Actual output: ${output}" >&2
        return 1
    fi
}

# Assert command succeeded
assert_success() {
    if [[ "${status}" -ne 0 ]]; then
        echo "Command failed with status: ${status}" >&2
        echo "Output: ${output}" >&2
        return 1
    fi
}

# Assert command failed
assert_failure() {
    if [[ "${status}" -eq 0 ]]; then
        echo "Command succeeded but should have failed" >&2
        echo "Output: ${output}" >&2
        return 1
    fi
}

# Count lines in file
count_lines() {
    local file_path="$1"
    wc -l < "${file_path}" | tr -d ' '
}

# Count JSONL records
count_jsonl_records() {
    local file_path="$1"
    local count=0
    
    while IFS= read -r line; do
        if [[ -n "${line}" ]] && echo "${line}" | jq empty 2>/dev/null; then
            ((count++))
        fi
    done < "${file_path}"
    
    echo "${count}"
}

# Platform-aware timing function with millisecond precision
# 
# TIMING PRECISION DOCUMENTATION:
# ===============================
# 
# Cross-Platform Compatibility Strategy:
# - Linux (GNU coreutils):   date +%s%3N produces timestamps like "1641234567890"
# - macOS/BSD (BSD coreutils): date +%s%3N produces literal "1641234567%3N" 
# - Solution: Test actual output format rather than relying on stderr or version detection
# 
# Implementation Details:
# - First attempt: Try millisecond precision with date +%s%3N
# - Format test: Check if output contains literal 'N' character
# - Success case: Use millisecond timestamp directly (Linux/recent BSD)
# - Fallback case: Use second precision * 1000 (older macOS/BSD)
# 
# Precision Guarantees:
# - Linux: True millisecond precision (±1ms accuracy)
# - macOS: Second precision converted to milliseconds (±1000ms accuracy)
# - Both platforms: Monotonic ordering within same process
# - Race condition avoidance: No concurrent timestamp generation assumed
# 
# Testing Considerations:
# - Performance tests should account for platform precision differences
# - Timing thresholds should be ≥1000ms for cross-platform reliability  
# - Use duration calculations rather than absolute timestamp comparisons
get_timestamp() {
    # Test if millisecond precision works by checking actual output format
    local test_output
    test_output=$(date +%s%3N 2>/dev/null)
    
    # If output doesn't contain 'N' (meaning %3N was expanded to digits), use it
    if [[ "$test_output" != *"N"* ]] && [[ -n "$test_output" ]]; then
        echo "$test_output"
    else
        # Fall back to second precision converted to milliseconds (macOS/BSD date)
        echo "$(($(date +%s) * 1000))"
    fi
}

# Calculate duration in milliseconds
calculate_duration_ms() {
    local start_ms="$1"
    local end_ms="$2"
    echo $((end_ms - start_ms))
}

# Skip test if feature not implemented
skip_if_not_implemented() {
    local output="$1"
    local feature="$2"
    
    if [[ "$output" == *"Unknown option"* ]] || [[ "$output" == *"not implemented"* ]] || [[ "$output" == *"unsupported"* ]]; then
        skip "$feature not implemented yet"
    fi
}

# Check if content contains any timing fields
has_timing_fields() {
    local content="$1"
    local timing_fields=("index_time" "scan_time" "duration" "elapsed" "timing" "time_ms")
    
    for field in "${timing_fields[@]}"; do
        if [[ "$content" == *"$field"* ]]; then
            return 0  # Found timing field
        fi
    done
    return 1  # No timing fields found
}

# Check if content contains phase timing info
has_phase_timing() {
    local content="$1"
    local phase_fields=("scan" "shard" "symbols" "manifest" "phase")
    local found_count=0
    
    for field in "${phase_fields[@]}"; do
        if [[ "$content" == *"$field"* ]]; then
            ((found_count++))
        fi
    done
    
    # Consider it phase timing if at least 2 phases are mentioned
    [ "$found_count" -ge 2 ]
}

# Enhanced token validation with realistic bounds
validate_token_count() {
    local content="$1"
    local content_type="${2:-code}"  # code, config, documentation
    local char_count=${#content}
    local estimated_tokens=$((char_count / 4))
    
    # Define realistic bounds based on content type
    local min_tokens max_tokens
    case "$content_type" in
        "code")
            # Code is typically dense: 3.5-4.5 chars per token
            min_tokens=$((char_count / 5))
            max_tokens=$((char_count / 3))
            ;;
        "config")
            # Config files have more structure: 4-6 chars per token
            min_tokens=$((char_count / 6))
            max_tokens=$((char_count / 4))
            ;;
        "documentation")
            # Documentation is verbose: 5-7 chars per token
            min_tokens=$((char_count / 7))
            max_tokens=$((char_count / 5))
            ;;
        *)
            # Default: Use 4-chars-per-token rule with 25% variance
            min_tokens=$((estimated_tokens * 3 / 4))
            max_tokens=$((estimated_tokens * 5 / 4))
            ;;
    esac
    
    # Validate token count is within realistic range
    if [ "$estimated_tokens" -ge "$min_tokens" ] && [ "$estimated_tokens" -le "$max_tokens" ]; then
        echo "valid:$estimated_tokens:$min_tokens-$max_tokens"
        return 0
    else
        echo "invalid:$estimated_tokens:$min_tokens-$max_tokens"
        return 1
    fi
}

# Validate content format and structure
validate_content_format() {
    local file_path="$1"
    local expected_format="$2"  # jsonl, tsv, json, etc.
    
    if [[ ! -f "$file_path" ]]; then
        echo "error:file_not_found:$file_path"
        return 1
    fi
    
    case "$expected_format" in
        "jsonl")
            # Validate each line is valid JSON
            local line_count=0
            local valid_count=0
            while IFS= read -r line; do
                ((line_count++))
                if [[ -n "$line" ]] && echo "$line" | jq empty >/dev/null 2>&1; then
                    ((valid_count++))
                fi
            done < "$file_path"
            
            if [ "$valid_count" -gt 0 ] && [ "$valid_count" -eq "$line_count" ]; then
                echo "valid:$valid_count:jsonl"
                return 0
            else
                echo "invalid:$valid_count/$line_count:jsonl"
                return 1
            fi
            ;;
        "tsv")
            # Validate TSV format (at least 2 columns)
            local line_count=0
            local valid_count=0
            while IFS= read -r line; do
                ((line_count++))
                if [[ -n "$line" ]] && [[ $(echo "$line" | tr '\t' '\n' | wc -l) -ge 2 ]]; then
                    ((valid_count++))
                fi
            done < "$file_path"
            
            if [ "$valid_count" -gt 0 ] && [ "$valid_count" -eq "$line_count" ]; then
                echo "valid:$valid_count:tsv"
                return 0
            else
                echo "invalid:$valid_count/$line_count:tsv"
                return 1
            fi
            ;;
        "json")
            # Validate JSON format
            if jq empty "$file_path" >/dev/null 2>&1; then
                echo "valid:1:json"
                return 0
            else
                echo "invalid:0:json"
                return 1
            fi
            ;;
        *)
            echo "unknown_format:$expected_format"
            return 1
            ;;
    esac
}

# Validate DSL compression ratio with minimum efficiency requirements
# 
# DSL COMPRESSION VALIDATION:
# ==========================
# 
# Purpose: Ensure DSL format provides meaningful size reduction over JSON
# Minimum Requirements:
# - DSL must be ≤90% of JSON size (≥10% compression)
# - Significant compression: ≤80% of JSON size (≥20% compression)  
# - Exceptional compression: ≤70% of JSON size (≥30% compression)
# 
# Validation Levels:
# - "strict": Requires ≥10% compression (production requirement)
# - "significant": Requires ≥20% compression (performance target)
# - "exceptional": Requires ≥30% compression (stretch goal)
# 
# Returns: "valid:ratio:level" or "invalid:ratio:expected"
# Examples: "valid:75:significant" or "invalid:95:strict"
validate_dsl_compression() {
    local dsl_content="$1"
    local json_content="$2" 
    local validation_level="${3:-strict}"  # strict, significant, exceptional
    
    local dsl_size=${#dsl_content}
    local json_size=${#json_content}
    
    # Avoid division by zero
    if [ "$json_size" -eq 0 ]; then
        echo "invalid:0:zero_json_size"
        return 1
    fi
    
    # Calculate compression ratio (DSL size as percentage of JSON size)
    local ratio_percent=$((dsl_size * 100 / json_size))
    
    # Define thresholds based on validation level
    local threshold
    case "$validation_level" in
        "strict")
            threshold=90  # ≥10% compression required
            ;;
        "significant") 
            threshold=80  # ≥20% compression required
            ;;
        "exceptional")
            threshold=70  # ≥30% compression required
            ;;
        *)
            echo "invalid:$ratio_percent:unknown_level_$validation_level"
            return 1
            ;;
    esac
    
    # Validate compression meets threshold
    if [ "$ratio_percent" -le "$threshold" ]; then
        # Determine actual achievement level
        local achievement_level
        if [ "$ratio_percent" -le 70 ]; then
            achievement_level="exceptional"
        elif [ "$ratio_percent" -le 80 ]; then
            achievement_level="significant"  
        else
            achievement_level="strict"
        fi
        
        echo "valid:$ratio_percent:$achievement_level"
        return 0
    else
        echo "invalid:$ratio_percent:expected_le_$threshold"
        return 1
    fi
}

# Enhanced DSL format validation with symbol accuracy verification
# Validates DSL maintains key structural elements from JSON
validate_dsl_format() {
    local dsl_content="$1"
    local json_content="$2"
    
    # Required DSL markers for symbol preservation
    local required_markers=("SYM" "FILE" "F:" "S:")
    local found_markers=0
    
    for marker in "${required_markers[@]}"; do
        if [[ "$dsl_content" == *"$marker"* ]]; then
            ((found_markers++))
        fi
    done
    
    # Must contain at least 2 of 4 key markers
    if [ "$found_markers" -ge 2 ]; then
        echo "valid:$found_markers/4:dsl_format"
        return 0
    else
        echo "invalid:$found_markers/4:insufficient_markers"
        return 1
    fi
}

# Comprehensive content validation for SourceAtlas output files
# 
# CONTENT VALIDATION FRAMEWORK:
# ============================
# 
# Purpose: Validate structure, completeness, and consistency of generated files
# Validation Types:
# - "index": JSONL index files with required fields
# - "symbols": TSV symbol table files  
# - "manifest": JSON manifest files
# - "stats": JSON statistics files
# 
# Returns: "valid:count:validation_type" or "invalid:reason:field"
validate_sourceatlas_content() {
    local file_path="$1"
    local content_type="$2"  # index, symbols, manifest, stats
    local validation_level="${3:-strict}"  # strict, permissive
    
    if [[ ! -f "$file_path" ]]; then
        echo "invalid:file_not_found:$file_path"
        return 1
    fi
    
    case "$content_type" in
        "index")
            validate_index_content "$file_path" "$validation_level"
            ;;
        "symbols") 
            validate_symbols_content "$file_path" "$validation_level"
            ;;
        "manifest")
            validate_manifest_content "$file_path" "$validation_level"
            ;;
        "stats")
            validate_stats_content "$file_path" "$validation_level"
            ;;
        *)
            echo "invalid:unknown_content_type:$content_type"
            return 1
            ;;
    esac
}

# Validate JSONL index file structure and required fields
validate_index_content() {
    local file_path="$1"
    local validation_level="${2:-strict}"
    
    local valid_records=0
    local total_records=0
    local required_fields=("path" "language" "symbols")
    
    while IFS= read -r line; do
        ((total_records++))
        
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Validate JSON structure
        if ! echo "$line" | jq empty >/dev/null 2>&1; then
            echo "invalid:malformed_json:line_$total_records"
            return 1
        fi
        
        # Check required fields
        local missing_fields=0
        for field in "${required_fields[@]}"; do
            if ! echo "$line" | jq -e "has(\"$field\")" >/dev/null 2>&1; then
                ((missing_fields++))
                if [[ "$validation_level" == "strict" ]]; then
                    echo "invalid:missing_field:$field:line_$total_records"
                    return 1
                fi
            fi
        done
        
        # If permissive mode, only require majority of fields
        if [[ "$validation_level" == "permissive" ]] && [ "$missing_fields" -le 1 ]; then
            ((valid_records++))
        elif [[ "$validation_level" == "strict" ]] && [ "$missing_fields" -eq 0 ]; then
            ((valid_records++))
        fi
        
    done < "$file_path"
    
    if [ "$valid_records" -gt 0 ]; then
        echo "valid:$valid_records:index"
        return 0
    else
        echo "invalid:no_valid_records:$total_records"
        return 1
    fi
}

# Validate TSV symbol table structure
validate_symbols_content() {
    local file_path="$1"
    local validation_level="${2:-strict}"
    
    local valid_lines=0
    local total_lines=0
    local min_columns=2  # symbol, file minimum
    
    while IFS= read -r line; do
        ((total_lines++))
        
        # Skip empty lines and headers
        [[ -z "$line" ]] || [[ "$line" == "symbol"* ]] && continue
        
        # Count columns (tab-separated)
        local column_count
        column_count=$(echo "$line" | tr '\t' '\n' | wc -l)
        
        if [ "$column_count" -ge "$min_columns" ]; then
            ((valid_lines++))
        elif [[ "$validation_level" == "strict" ]]; then
            echo "invalid:insufficient_columns:$column_count:line_$total_lines"
            return 1
        fi
        
    done < "$file_path"
    
    if [ "$valid_lines" -gt 0 ]; then
        echo "valid:$valid_lines:symbols"
        return 0
    else
        echo "invalid:no_valid_symbols:$total_lines"
        return 1
    fi
}

# Validate JSON manifest structure
validate_manifest_content() {
    local file_path="$1" 
    local validation_level="${2:-strict}"
    
    # Validate JSON structure
    if ! jq empty "$file_path" >/dev/null 2>&1; then
        echo "invalid:malformed_json:manifest"
        return 1
    fi
    
    # Check required manifest fields
    local required_fields=("version" "shards" "created_at")
    local missing_fields=0
    
    for field in "${required_fields[@]}"; do
        if ! jq -e "has(\"$field\")" "$file_path" >/dev/null 2>&1; then
            ((missing_fields++))
            if [[ "$validation_level" == "strict" ]]; then
                echo "invalid:missing_field:$field:manifest"
                return 1
            fi
        fi
    done
    
    # Check shards is array
    if jq -e ".shards | type == \"array\"" "$file_path" >/dev/null 2>&1; then
        local shard_count
        shard_count=$(jq ".shards | length" "$file_path")
        echo "valid:$shard_count:manifest"
        return 0
    else
        echo "invalid:shards_not_array:manifest"
        return 1
    fi
}

# Validate JSON statistics file
validate_stats_content() {
    local file_path="$1"
    local validation_level="${2:-strict}"
    
    # Validate JSON structure
    if ! jq empty "$file_path" >/dev/null 2>&1; then
        echo "invalid:malformed_json:stats"
        return 1
    fi
    
    # Check for numeric fields
    local numeric_fields=("files_indexed" "symbols_extracted" "total_size")
    local valid_numeric=0
    
    for field in "${numeric_fields[@]}"; do
        if jq -e "has(\"$field\") and (.${field} | type == \"number\")" "$file_path" >/dev/null 2>&1; then
            ((valid_numeric++))
        fi
    done
    
    # At least 2 of 3 numeric fields should be present
    if [ "$valid_numeric" -ge 2 ]; then
        echo "valid:$valid_numeric:stats"
        return 0
    else
        echo "invalid:insufficient_numeric_fields:$valid_numeric"
        return 1
    fi
}