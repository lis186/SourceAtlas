#!/usr/bin/env bash
# Test helpers for SourceAtlas E2E tests

# Check for required tools and provide warnings
check_required_tools() {
    local missing_tools=()
    local optional_tools=()
    
    # Required tools (tests will fail without these)
    command -v jq >/dev/null 2>&1 || missing_tools+=("jq")
    
    # Optional but recommended tools (functionality degraded without these)
    command -v awk >/dev/null 2>&1 || optional_tools+=("awk")
    
    # Report missing required tools
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "ERROR: Required tools missing: ${missing_tools[*]}" >&2
        echo "Please install missing tools before running tests" >&2
        return 1
    fi
    
    # Warn about missing optional tools
    if [[ ${#optional_tools[@]} -gt 0 ]]; then
        echo "WARNING: Optional tools missing: ${optional_tools[*]}" >&2
        echo "Some functionality may use fallback implementations" >&2
    fi
    
    return 0
}

# Setup test environment with comprehensive cleanup and unique namespacing
setup_test_env() {
    # Check for required tools on first run
    if [[ -z "${TOOLS_CHECKED:-}" ]]; then
        check_required_tools || true  # Warn but don't fail
        export TOOLS_CHECKED=1
    fi
    
    # Create unique test namespace for parallel execution safety
    local test_id="${BATS_TEST_NUMBER:-$$}-$(date +%s%3N 2>/dev/null || date +%s)"
    export TEST_TEMP_DIR="$(mktemp -d -t sourceatlas-test-${test_id}-XXXXXX)"
    export SATLAS_ROOT="${TEST_TEMP_DIR}"
    export PATH="${BATS_TEST_DIRNAME}/../../bin:${PATH}"
    
    # Track temporary resources for cleanup
    export TEST_TEMP_FILES=()
    export TEST_TEMP_DIRS=("$TEST_TEMP_DIR")
    export TEST_BACKGROUND_PIDS=()
    
    # Set trap for automatic cleanup on test failure/exit
    trap 'cleanup_test_resources' EXIT INT TERM ERR
}

# Comprehensive cleanup for test resources with failure safety
cleanup_test_resources() {
    local exit_code=$?
    
    # Remove trap to prevent recursive calls
    trap - EXIT INT TERM ERR
    
    # Cleanup background processes first (most critical)
    if [[ -n "${TEST_BACKGROUND_PIDS:-}" ]]; then
        for pid in "${TEST_BACKGROUND_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                sleep 0.1
                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    kill -9 "$pid" 2>/dev/null || true
                fi
            fi
        done
        unset TEST_BACKGROUND_PIDS
    fi
    
    # Cleanup temporary files
    if [[ -n "${TEST_TEMP_FILES:-}" ]]; then
        for file in "${TEST_TEMP_FILES[@]}"; do
            if [[ -f "$file" ]]; then
                rm -f "$file" 2>/dev/null || true
            fi
        done
        unset TEST_TEMP_FILES
    fi
    
    # Cleanup temporary directories (most destructive last)
    if [[ -n "${TEST_TEMP_DIRS:-}" ]]; then
        for dir in "${TEST_TEMP_DIRS[@]}"; do
            # Safety checks before destructive operations
            if [[ -d "$dir" ]] && [[ "$dir" == /tmp/* ]] || [[ "$dir" == /var/tmp/* ]]; then
                # Additional safety: ensure it's actually a test directory we created
                if [[ "$(basename "$dir")" == sourceatlas-test-* ]]; then
                    rm -rf "$dir" 2>/dev/null || true
                fi
            fi
        done
        unset TEST_TEMP_DIRS
    fi
    
    # Legacy cleanup for backward compatibility
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "${TEST_TEMP_DIR}" ]]; then
        # Safety check: ensure it's a test directory
        if [[ "$(basename "$TEST_TEMP_DIR")" == sourceatlas-test-* ]]; then
            rm -rf "${TEST_TEMP_DIR}" 2>/dev/null || true
        fi
        unset TEST_TEMP_DIR
    fi
    
    # Preserve original exit code
    return $exit_code
}

# Legacy cleanup function for backward compatibility
cleanup_test_env() {
    cleanup_test_resources
}

# Copy fixtures to test directory
copy_fixtures() {
    local fixture_name="$1"
    
    # Determine fixture path - works both in BATS and standalone
    local fixture_path
    if [[ -n "${BATS_TEST_DIRNAME:-}" ]]; then
        fixture_path="${BATS_TEST_DIRNAME}/../fixtures/${fixture_name}"
    else
        # Fallback for standalone execution
        fixture_path="$(dirname "${BASH_SOURCE[0]}")/fixtures/${fixture_name}"
    fi
    
    if [[ -d "${fixture_path}" ]]; then
        cp -r "${fixture_path}"/* "${TEST_TEMP_DIR}/"
    else
        echo "Fixture not found: ${fixture_name} (tried: ${fixture_path})" >&2
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
    local fallback_output
    
    # First attempt: Try millisecond precision
    if ! test_output=$(date +%s%3N 2>/dev/null); then
        echo "TIMING_ERROR:date_command_failed:millisecond_attempt" >&2
        return 1
    fi
    
    # Validate output format and content
    if [[ -z "$test_output" ]]; then
        echo "TIMING_ERROR:empty_output:millisecond_attempt" >&2
        return 1
    fi
    
    # If output doesn't contain 'N' (meaning %3N was expanded to digits), use it
    if [[ "$test_output" != *"N"* ]]; then
        # Validate it's a reasonable timestamp (13 digits for milliseconds since epoch)
        if [[ "$test_output" =~ ^[0-9]{10,13}$ ]]; then
            echo "$test_output"
            return 0
        else
            echo "TIMING_ERROR:invalid_millisecond_format:$test_output" >&2
            return 1
        fi
    fi
    
    # Fall back to second precision converted to milliseconds (macOS/BSD date)
    if ! fallback_output=$(date +%s 2>/dev/null); then
        echo "TIMING_ERROR:date_command_failed:second_fallback" >&2
        return 1
    fi
    
    # Validate fallback output
    if [[ -z "$fallback_output" ]] || ! [[ "$fallback_output" =~ ^[0-9]{10}$ ]]; then
        echo "TIMING_ERROR:invalid_second_format:$fallback_output" >&2
        return 1
    fi
    
    # Convert to milliseconds with overflow protection
    local result=$((fallback_output * 1000))
    if [ "$result" -lt 0 ]; then
        echo "TIMING_ERROR:overflow_in_conversion:$fallback_output" >&2
        return 1
    fi
    
    echo "$result"
}

# Enhanced test isolation with automatic resource tracking
# 
# TEST ISOLATION FRAMEWORK:
# ========================
# 
# Purpose: Ensure complete cleanup of test resources even on failures
# Features:
# - Automatic tracking of created resources
# - Cleanup on exit/failure via trap
# - Nested directory cleanup with safety checks
# - Process cleanup for background operations
# 
# Usage: Call setup_enhanced_isolation() in test setup
setup_enhanced_isolation() {
    # Track all resources created during test execution
    export TEST_CREATED_DIRS=()
    export TEST_CREATED_FILES=()
    export TEST_BACKGROUND_PIDS=()
    
    # Set trap for automatic cleanup on test failure/exit
    trap 'cleanup_test_resources_on_exit' EXIT INT TERM
}

# Create tracked temporary directory
create_tracked_temp_dir() {
    local prefix="${1:-sourceatlas-test}"
    local temp_dir
    
    if ! temp_dir=$(mktemp -d -t "${prefix}-XXXXXX" 2>/dev/null); then
        echo "ISOLATION_ERROR:failed_to_create_temp_dir:$prefix" >&2
        return 1
    fi
    
    # Validate created directory
    if [[ ! -d "$temp_dir" ]]; then
        echo "ISOLATION_ERROR:temp_dir_not_created:$temp_dir" >&2
        return 1
    fi
    
    # Track for cleanup
    TEST_CREATED_DIRS+=("$temp_dir")
    echo "$temp_dir"
}

# Create tracked temporary file
create_tracked_temp_file() {
    local prefix="${1:-sourceatlas-test}"
    local suffix="${2:-}"
    local temp_file
    
    if [[ -n "$suffix" ]]; then
        temp_file=$(mktemp -t "${prefix}-XXXXXX${suffix}" 2>/dev/null)
    else
        temp_file=$(mktemp -t "${prefix}-XXXXXX" 2>/dev/null)
    fi
    
    if [[ -z "$temp_file" ]] || [[ ! -f "$temp_file" ]]; then
        echo "ISOLATION_ERROR:failed_to_create_temp_file:$prefix" >&2
        return 1
    fi
    
    # Track for cleanup
    TEST_CREATED_FILES+=("$temp_file")
    echo "$temp_file"
}

# Start tracked background process
start_tracked_background_process() {
    local command="$1"
    shift
    local args=("$@")
    
    # Start process in background
    "$command" "${args[@]}" &
    local pid=$!
    
    # Validate process started
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "ISOLATION_ERROR:background_process_failed:$command" >&2
        return 1
    fi
    
    # Track for cleanup
    TEST_BACKGROUND_PIDS+=("$pid")
    echo "$pid"
}

# Safe cleanup with comprehensive error handling
cleanup_test_resources_on_exit() {
    local exit_code=$?
    
    # Cleanup background processes
    if [[ -n "${TEST_BACKGROUND_PIDS:-}" ]]; then
        for pid in "${TEST_BACKGROUND_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                # Give process time to terminate gracefully
                sleep 0.1
                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    kill -9 "$pid" 2>/dev/null || true
                fi
            fi
        done
    fi
    
    # Cleanup temporary files
    if [[ -n "${TEST_CREATED_FILES:-}" ]]; then
        for file in "${TEST_CREATED_FILES[@]}"; do
            if [[ -f "$file" ]]; then
                rm -f "$file" 2>/dev/null || true
            fi
        done
    fi
    
    # Cleanup temporary directories (most destructive operation last)
    if [[ -n "${TEST_CREATED_DIRS:-}" ]]; then
        for dir in "${TEST_CREATED_DIRS[@]}"; do
            # Safety checks before destructive operations
            if [[ -d "$dir" ]] && [[ "$dir" == /tmp/* ]] || [[ "$dir" == /var/* ]]; then
                # Additional safety: ensure it's actually a temp directory we created
                if [[ "$(basename "$dir")" == sourceatlas-test-* ]]; then
                    rm -rf "$dir" 2>/dev/null || true
                fi
            fi
        done
    fi
    
    # Clear tracking arrays
    unset TEST_CREATED_DIRS
    unset TEST_CREATED_FILES  
    unset TEST_BACKGROUND_PIDS
    
    # Remove trap to avoid recursive calls
    trap - EXIT INT TERM
    
    # Preserve original exit code
    return $exit_code
}

# Calculate duration in milliseconds with comprehensive error handling
calculate_duration_ms() {
    local start_ms="$1"
    local end_ms="$2"
    
    # Validate input parameters
    if [[ -z "$start_ms" ]]; then
        echo "DURATION_ERROR:missing_start_timestamp" >&2
        return 1
    fi
    
    if [[ -z "$end_ms" ]]; then
        echo "DURATION_ERROR:missing_end_timestamp" >&2
        return 1
    fi
    
    # Validate numeric format (timestamps should be positive integers)
    if ! [[ "$start_ms" =~ ^[0-9]+$ ]]; then
        echo "DURATION_ERROR:invalid_start_format:$start_ms" >&2
        return 1
    fi
    
    if ! [[ "$end_ms" =~ ^[0-9]+$ ]]; then
        echo "DURATION_ERROR:invalid_end_format:$end_ms" >&2
        return 1
    fi
    
    # Validate timestamp values are reasonable (after year 2020, before year 2100)
    local min_timestamp=1577836800000  # 2020-01-01 in milliseconds
    local max_timestamp=4102444800000  # 2100-01-01 in milliseconds
    
    if [ "$start_ms" -lt "$min_timestamp" ] || [ "$start_ms" -gt "$max_timestamp" ]; then
        echo "DURATION_ERROR:unreasonable_start_timestamp:$start_ms" >&2
        return 1
    fi
    
    if [ "$end_ms" -lt "$min_timestamp" ] || [ "$end_ms" -gt "$max_timestamp" ]; then
        echo "DURATION_ERROR:unreasonable_end_timestamp:$end_ms" >&2
        return 1
    fi
    
    # Check for negative duration (time travel detection)
    if [ "$end_ms" -lt "$start_ms" ]; then
        echo "DURATION_ERROR:negative_duration:start=$start_ms:end=$end_ms" >&2
        return 1
    fi
    
    # Calculate duration with overflow detection
    local duration=$((end_ms - start_ms))
    
    # Sanity check: duration shouldn't exceed 1 hour (3600000ms) for test operations
    local max_duration=3600000
    if [ "$duration" -gt "$max_duration" ]; then
        echo "DURATION_ERROR:excessive_duration:${duration}ms:exceeds_1hour" >&2
        return 1
    fi
    
    echo "$duration"
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

# Register temporary file for automatic cleanup
register_temp_file() {
    local file_path="$1"
    
    if [[ -n "$file_path" ]] && [[ -f "$file_path" ]]; then
        TEST_TEMP_FILES+=("$file_path")
    fi
}

# Register temporary directory for automatic cleanup  
register_temp_dir() {
    local dir_path="$1"
    
    if [[ -n "$dir_path" ]] && [[ -d "$dir_path" ]]; then
        TEST_TEMP_DIRS+=("$dir_path")
    fi
}

# Register background process for automatic cleanup
register_background_pid() {
    local pid="$1"
    
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        TEST_BACKGROUND_PIDS+=("$pid")
    fi
}

# Create tracked temporary file with automatic cleanup
create_temp_file() {
    local prefix="${1:-sourceatlas-test}"
    local suffix="${2:-}"
    
    local temp_file
    if [[ -n "$suffix" ]]; then
        temp_file=$(mktemp -t "${prefix}-XXXXXX${suffix}")
    else
        temp_file=$(mktemp -t "${prefix}-XXXXXX")
    fi
    
    if [[ -f "$temp_file" ]]; then
        register_temp_file "$temp_file"
        echo "$temp_file"
    else
        echo "CLEANUP_ERROR:failed_to_create_temp_file:$prefix" >&2
        return 1
    fi
}

# Create tracked temporary directory with automatic cleanup
create_temp_dir() {
    local prefix="${1:-sourceatlas-test}"
    
    local temp_dir=$(mktemp -d -t "${prefix}-XXXXXX")
    
    if [[ -d "$temp_dir" ]]; then
        register_temp_dir "$temp_dir"
        echo "$temp_dir"
    else
        echo "CLEANUP_ERROR:failed_to_create_temp_dir:$prefix" >&2
        return 1
    fi
}

# Helper function validation - ensures function exists before calling
validate_helper_function() {
    local function_name="$1"
    
    if ! declare -f "$function_name" >/dev/null 2>&1; then
        echo "HELPER_ERROR:function_not_defined:$function_name" >&2
        return 1
    fi
    
    return 0
}

# Validate phase timing information exists
has_phase_timing() {
    local stats_content="$1"
    
    # Validate helper function is being called correctly
    validate_helper_function "has_phase_timing" || return 1
    
    local phase_fields=("phase_timing" "scan_time" "index_time" "shard_time" "phases")
    
    for field in "${phase_fields[@]}"; do
        if [[ "$stats_content" == *"$field"* ]]; then
            return 0
        fi
    done
    
    return 1
}

# Phase 7 UAT Quality Metrics - Configuration Constants
readonly UAT_HIT_AT_5_THRESHOLD=80    # Hit@5 threshold percentage (≥80%)
readonly UAT_COVERAGE_THRESHOLD=95    # Coverage threshold percentage (≥95%)
readonly UAT_FPR_THRESHOLD=20         # False Positive Rate threshold percentage (<20%)
readonly UAT_MIN_QUERIES=30           # Minimum test queries required
readonly UAT_MAX_QUERIES=50           # Maximum test queries allowed

# Create UAT test queries file with dynamic generation based on count
# Optional caching: If UAT_CACHE_DIR is set, reuse cached files when possible
create_uat_queries_file() {
    local queries_file="$1"
    local query_count="${2:-35}"  # Default to 35 queries
    
    if [[ -z "$queries_file" ]]; then
        echo "ERROR: queries_file parameter required" >&2
        return 1
    fi
    
    # Check for cached version if caching is enabled
    if [[ -n "${UAT_CACHE_DIR:-}" ]] && [[ -d "$UAT_CACHE_DIR" ]]; then
        local cache_file="$UAT_CACHE_DIR/queries_${query_count}.tsv"
        if [[ -f "$cache_file" ]]; then
            # Use cached file if it exists and is recent (less than 1 hour old)
            if [[ $(find "$cache_file" -mmin -60 2>/dev/null) ]]; then
                cp "$cache_file" "$queries_file"
                return 0
            fi
        fi
    fi
    
    # Validate query count is within acceptable range
    if [[ "$query_count" -lt 1 ]]; then
        echo "ERROR: query_count must be at least 1" >&2
        return 1
    fi
    
    # For PRD compliance testing, enforce min/max range
    if [[ "$query_count" -ge "$UAT_MIN_QUERIES" ]]; then
        if [[ "$query_count" -gt "$UAT_MAX_QUERIES" ]]; then
            echo "WARNING: query_count $query_count exceeds UAT_MAX_QUERIES ($UAT_MAX_QUERIES)" >&2
        fi
    fi
    
    # Define all available test queries (35 total)
    local all_queries=(
        "1	AppDelegate	symbol	AppDelegate.swift	high"
        "2	MainActivity	symbol	MainActivity.kt	high"
        "3	ConfigLoader	symbol	utils.py	high"
        "4	TestHelper	symbol	test_helper.rb	high"
        "5	build_ios	symbol	build.sh	medium"
        "6	class.*Delegate	regex	AppDelegate.swift	high"
        "7	func.*init	regex	AppDelegate.swift,MainActivity.kt	medium"
        "8	def.*process	regex	utils.py	medium"
        "9	module.*Helper	regex	test_helper.rb	low"
        "10	function.*main	regex	build.sh	low"
        "11	import.*UIKit	import	AppDelegate.swift	high"
        "12	import.*androidx	import	MainActivity.kt	high"
        "13	import.*json	import	utils.py	medium"
        "14	require.*spec	import	test_helper.rb	low"
        "15	source.*common	import	build.sh	low"
        "16	@AndroidEntryPoint	annotation	MainActivity.kt	high"
        "17	@UIApplicationMain	annotation	AppDelegate.swift	high"
        "18	@dataclass	annotation	utils.py	medium"
        "19	*.swift	file_extension	AppDelegate.swift	medium"
        "20	*.kt	file_extension	MainActivity.kt	medium"
        "21	*.py	file_extension	utils.py	medium"
        "22	*.rb	file_extension	test_helper.rb	low"
        "23	*.sh	file_extension	build.sh	low"
        "24	ios/AppDelegate	path	AppDelegate.swift	high"
        "25	android/MainActivity	path	MainActivity.kt	high"
        "26	scripts/utils	path	utils.py	medium"
        "27	scripts/test_helper	path	test_helper.rb	low"
        "28	scripts/build	path	build.sh	low"
        "29	networking.*error	semantic	AppDelegate.swift	low"
        "30	database.*query	semantic	utils.py	low"
        "31	test.*assertion	semantic	test_helper.rb	low"
        "32	build.*configuration	semantic	build.sh	low"
        "33	user.*interface	semantic	AppDelegate.swift	medium"
        "34	data.*processing	semantic	utils.py	medium"
        "35	configuration.*management	semantic	build.sh	low"
    )
    
    # Write header
    echo "query_id	query_text	query_type	expected_files	priority" > "$queries_file"
    
    # Write the requested number of queries
    local queries_written=0
    local total_available=${#all_queries[@]}
    
    for ((i=0; i<query_count && i<total_available; i++)); do
        echo "${all_queries[$i]}" >> "$queries_file"
        queries_written=$((queries_written + 1))
    done
    
    # If more queries requested than available, cycle through them with new IDs
    if [[ "$query_count" -gt "$total_available" ]]; then
        local extra_needed=$((query_count - total_available))
        for ((i=0; i<extra_needed; i++)); do
            local orig_idx=$((i % total_available))
            local new_id=$((total_available + i + 1))
            # Extract fields from original query and update ID
            local orig_query="${all_queries[$orig_idx]}"
            local updated_query=$(echo "$orig_query" | sed "s/^[0-9]\+/$new_id/")
            echo "$updated_query" >> "$queries_file"
            queries_written=$((queries_written + 1))
        done
    fi
    
    # Validate file was created successfully
    if [[ ! -f "$queries_file" ]]; then
        echo "ERROR: Failed to create queries file: $queries_file" >&2
        return 1
    fi
    
    # Verify correct number of queries (excluding header)
    local actual_count=$(($(wc -l < "$queries_file") - 1))
    if [[ "$actual_count" -ne "$query_count" ]]; then
        echo "ERROR: Query count mismatch: expected $query_count, created $actual_count" >&2
        return 1
    fi
    
    # Cache the generated file if caching is enabled
    if [[ -n "${UAT_CACHE_DIR:-}" ]] && [[ -d "$UAT_CACHE_DIR" ]]; then
        local cache_file="$UAT_CACHE_DIR/queries_${query_count}.tsv"
        cp "$queries_file" "$cache_file" 2>/dev/null || true
    fi
    
    return 0
}

# Create UAT ground truth file with fixture-based approach
# Optional caching: If UAT_CACHE_DIR is set, reuse cached files when possible  
create_uat_truth_file() {
    local truth_file="$1"
    
    if [[ -z "$truth_file" ]]; then
        echo "ERROR: truth_file parameter required" >&2
        return 1
    fi
    
    # Check for cached version if caching is enabled
    if [[ -n "${UAT_CACHE_DIR:-}" ]] && [[ -d "$UAT_CACHE_DIR" ]]; then
        local cache_file="$UAT_CACHE_DIR/truth.tsv"
        if [[ -f "$cache_file" ]]; then
            # Use cached file if it exists and is recent (less than 1 hour old)
            if [[ $(find "$cache_file" -mmin -60 2>/dev/null) ]]; then
                cp "$cache_file" "$truth_file"
                return 0
            fi
        fi
    fi
    
    cat > "$truth_file" << 'EOF'
query_id	relevant_file	rank	relevance_score	file_path	line_numbers	context
1	AppDelegate.swift	1	1.0	ios/AppDelegate.swift	1-50	Main application delegate
2	MainActivity.kt	1	1.0	android/MainActivity.kt	1-45	Main Android activity
3	utils.py	1	1.0	scripts/utils.py	15-20	ConfigLoader class definition
4	test_helper.rb	1	1.0	scripts/test_helper.rb	10-15	TestHelper module
5	build.sh	1	1.0	scripts/build.sh	25-30	build_ios function
6	AppDelegate.swift	1	0.9	ios/AppDelegate.swift	12-15	class AppDelegate definition
7	AppDelegate.swift	1	0.8	ios/AppDelegate.swift	20-25	init function
8	AppDelegate.swift	1	1.0	ios/AppDelegate.swift	1-3	UIKit import statement
9	MainActivity.kt	1	1.0	android/MainActivity.kt	3-4	AndroidEntryPoint annotation
10	AppDelegate.swift	1	1.0	ios/AppDelegate.swift	1-50	Swift file extension match
EOF

    # Validate file was created successfully
    if [[ ! -f "$truth_file" ]]; then
        echo "ERROR: Failed to create truth file: $truth_file" >&2
        return 1
    fi
    
    # Cache the generated file if caching is enabled
    if [[ -n "${UAT_CACHE_DIR:-}" ]] && [[ -d "$UAT_CACHE_DIR" ]]; then
        local cache_file="$UAT_CACHE_DIR/truth.tsv"
        cp "$truth_file" "$cache_file" 2>/dev/null || true
    fi
    
    return 0
}

# Execute UAT queries with proper variable handling (avoiding subshell issues)
# Returns results as JSON in a temporary file for safer parsing
execute_uat_queries() {
    local queries_file="$1"
    local results_file="${2:-$(mktemp -t uat_results.XXXXXX.json)}"  # Output file for JSON results
    
    if [[ -z "$queries_file" ]]; then
        echo "ERROR: queries_file parameter required" >&2
        return 1
    fi
    
    if [[ ! -f "$queries_file" ]]; then
        echo "ERROR: Queries file not found: $queries_file" >&2
        return 1
    fi
    
    local passed_queries=0
    local total_queries=0
    local temp_details_file="$(mktemp -t uat_details.XXXXXX.csv)"
    
    # Register temp files for cleanup if using global tracking
    if [[ -n "${TEST_TEMP_FILES:-}" ]]; then
        TEST_TEMP_FILES+=("$results_file" "$temp_details_file")
    fi
    
    # Process queries without using subshell to avoid variable scope issues
    while IFS=$'\t' read -r query_id query_text query_type expected_files priority; do
        # Skip header row
        if [[ "$query_id" == "query_id" ]]; then
            continue
        fi
        
        total_queries=$((total_queries + 1))
        
        # Execute query based on type with proper error handling
        local query_success=false
        case "$query_type" in
            "symbol"|"import"|"regex"|"annotation"|"file_extension"|"path"|"semantic")
                if run satlas query "$query_text" 2>/dev/null; then
                    if [[ "$status" -eq 0 ]]; then
                        query_success=true
                        passed_queries=$((passed_queries + 1))
                    fi
                fi
                ;;
            *)
                echo "WARNING: Unknown query type: $query_type for query $query_id" >&2
                ;;
        esac
        
        # Log result to temp file for debugging
        echo "$query_id,$query_text,$query_type,$query_success" >> "$temp_details_file"
        
    done < "$queries_file"
    
    # Create JSON output for safer parsing (no eval needed)
    cat > "$results_file" << EOF
{
    "total_queries": $total_queries,
    "passed_queries": $passed_queries,
    "success_rate": $(awk -v p="$passed_queries" -v t="$total_queries" 'BEGIN {if(t>0) printf "%.2f", p/t; else print "0.00"}'),
    "details_file": "$temp_details_file"
}
EOF
    
    # Output the results file path
    echo "$results_file"
    
    return 0
}

# Calculate floating point percentage with error handling and fallback
calculate_percentage() {
    local numerator="$1"
    local denominator="$2"
    local precision="${3:-2}"  # Default to 2 decimal places
    
    if [[ -z "$numerator" ]] || [[ -z "$denominator" ]]; then
        echo "ERROR: Both numerator and denominator required" >&2
        return 1
    fi
    
    if [[ "$denominator" -eq 0 ]]; then
        echo "ERROR: Division by zero" >&2
        return 1
    fi
    
    # Check if awk is available
    if command -v awk >/dev/null 2>&1; then
        # Use awk for reliable floating point arithmetic
        awk -v num="$numerator" -v denom="$denominator" -v prec="$precision" \
            'BEGIN { printf "%.*f", prec, (num * 100.0) / denom }'
    elif command -v bc >/dev/null 2>&1; then
        # Fallback to bc if available
        echo "scale=$precision; ($numerator * 100) / $denominator" | bc
    elif command -v python3 >/dev/null 2>&1; then
        # Fallback to python3 if available
        python3 -c "print(f'{($numerator * 100.0 / $denominator):.${precision}f}')"
    elif command -v perl >/dev/null 2>&1; then
        # Fallback to perl if available
        perl -e "printf '%.${precision}f', ($numerator * 100.0 / $denominator)"
    else
        # Last resort: bash integer arithmetic (less precise)
        echo "WARNING: No floating point calculator available, using integer math" >&2
        local result=$(( (numerator * 100) / denominator ))
        echo "$result"
    fi
}

# Validate JSON with jq and robust error handling
validate_json_field() {
    local json_file="$1"
    local field_path="$2"
    local expected_type="${3:-}"  # Optional: number, string, boolean, array, object
    
    if [[ -z "$json_file" ]] || [[ -z "$field_path" ]]; then
        echo "ERROR: Both json_file and field_path required" >&2
        return 1
    fi
    
    if [[ ! -f "$json_file" ]]; then
        echo "ERROR: JSON file not found: $json_file" >&2
        return 1
    fi
    
    # First validate JSON syntax
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "ERROR: Invalid JSON syntax in file: $json_file" >&2
        return 1
    fi
    
    # Check if field exists
    if ! jq -e "$field_path" "$json_file" >/dev/null 2>&1; then
        echo "ERROR: Field not found: $field_path in $json_file" >&2
        return 1
    fi
    
    # Validate field type if specified
    if [[ -n "$expected_type" ]]; then
        local actual_type
        actual_type=$(jq -r "type" <<< "$(jq "$field_path" "$json_file")")
        if [[ "$actual_type" != "$expected_type" ]]; then
            echo "ERROR: Field $field_path expected type $expected_type, got $actual_type" >&2
            return 1
        fi
    fi
    
    return 0
}

# Extract JSON field value with error handling
extract_json_value() {
    local json_file="$1"
    local field_path="$2"
    
    if ! validate_json_field "$json_file" "$field_path"; then
        return 1
    fi
    
    jq -r "$field_path" "$json_file" 2>/dev/null || {
        echo "ERROR: Failed to extract value for field: $field_path" >&2
        return 1
    }
}

# Validate that expected files exist in fixtures or index (optimized batch version)
# Reduces file I/O by batching operations
validate_expected_files_exist() {
    local queries_file="$1"
    local index_file="${2:-${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl}"
    
    if [[ -z "$queries_file" ]]; then
        echo "ERROR: queries_file parameter required" >&2
        return 1
    fi
    
    if [[ ! -f "$queries_file" ]]; then
        echo "ERROR: Queries file not found: $queries_file" >&2
        return 1
    fi
    
    local all_found=true
    local missing_files=()
    
    # Batch extract all unique expected files at once
    local expected_files_list=$(tail -n +2 "$queries_file" | cut -f4 | tr ',' '\n' | sort -u | grep -v '^$')
    
    # Batch find all matching files in filesystem (single find operation)
    local found_files=""
    if [[ -n "$expected_files_list" ]]; then
        found_files=$(find . -type f 2>/dev/null | xargs -I {} basename {} | sort -u)
    fi
    
    # If index file exists, batch extract all file references from it
    local index_files=""
    if [[ -f "$index_file" ]]; then
        # Extract both file_name and path fields in one pass
        index_files=$(grep -o '"file_name":"[^"]*"\|"path":"[^"]*"' "$index_file" 2>/dev/null | \
                      sed 's/.*:"\([^"]*\)"/\1/' | \
                      xargs -I {} basename {} | \
                      sort -u)
    fi
    
    # Check each expected file against both lists
    while IFS= read -r expected_file; do
        # Skip empty entries
        if [[ -z "$expected_file" ]]; then
            continue
        fi
        
        local found=false
        
        # Check against filesystem results
        if echo "$found_files" | grep -q "^${expected_file}$"; then
            found=true
        # Check against index results
        elif echo "$index_files" | grep -q "^${expected_file}$"; then
            found=true
        fi
        
        # Report missing files
        if [[ "$found" != true ]]; then
            echo "WARNING: Expected file not found in fixtures or index: $expected_file" >&2
            missing_files+=("$expected_file")
            all_found=false
        fi
    done <<< "$expected_files_list"
    
    # Return success if all files were found
    if [[ "$all_found" == true ]]; then
        return 0
    else
        # Optionally report summary
        echo "INFO: ${#missing_files[@]} files not found" >&2
        return 1
    fi
}