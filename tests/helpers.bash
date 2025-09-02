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

# Platform-aware timing function
get_timestamp() {
    # Try millisecond precision first (GNU date)
    if date +%s%3N >/dev/null 2>&1; then
        date +%s%3N
    else
        # Fall back to second precision (macOS/BSD date)
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