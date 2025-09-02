#!/usr/bin/env bats

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize and scan first
    satlas init
    satlas scan
}

teardown() {
    cleanup_test_env
}

@test "satlas stats requires index file" {
    rm -f .sourceatlas/sourceatlas.index.jsonl
    
    run satlas stats
    assert_failure
    assert_output_contains "Index file not found"
}

@test "satlas stats creates JSON file" {
    run satlas stats
    assert_success
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
}

@test "stats JSON is valid format" {
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Validate JSON format
    jq empty < "${stats_file}"
}

@test "stats contains file count" {
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Check for file count
    local file_count=$(jq -r '.files.total_count' "${stats_file}")
    [ "$file_count" -gt 0 ]
}

@test "stats contains language distribution" {
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Check for language distribution
    jq -e '.languages' "${stats_file}" >/dev/null
    
    # Language distribution should exist (counts may be zero if no files indexed)
    local swift_count=$(jq -r '.languages.swift // 0' "${stats_file}")
    local kotlin_count=$(jq -r '.languages.kotlin // 0' "${stats_file}")
    
    # At least check that the fields are numeric
    [[ "$swift_count" =~ ^[0-9]+$ ]]
    [[ "$kotlin_count" =~ ^[0-9]+$ ]]
}

@test "stats contains LOC metrics" {
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Check for LOC metrics
    jq -e '.lines_of_code.total' "${stats_file}" >/dev/null
    jq -e '.lines_of_code.average' "${stats_file}" >/dev/null
    jq -e '.lines_of_code.median' "${stats_file}" >/dev/null
    jq -e '.lines_of_code.max' "${stats_file}" >/dev/null
    jq -e '.lines_of_code.min' "${stats_file}" >/dev/null
}

@test "stats contains size metrics" {
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Check for size metrics
    jq -e '.file_sizes.total_bytes' "${stats_file}" >/dev/null
    jq -e '.file_sizes.average_bytes' "${stats_file}" >/dev/null
    jq -e '.file_sizes.largest_file' "${stats_file}" >/dev/null
}

@test "stats contains symbol count" {
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Check for symbol metrics
    jq -e '.symbols.total_count' "${stats_file}" >/dev/null
    jq -e '.symbols.by_kind' "${stats_file}" >/dev/null
}

@test "stats contains indexing timestamp" {
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Check for timestamp
    jq -e '.generated_at' "${stats_file}" >/dev/null
    
    # Should be recent timestamp
    local timestamp=$(jq -r '.generated_at' "${stats_file}")
    [ -n "$timestamp" ]
}

@test "stats contains repository info" {
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Check for repo info
    jq -e '.repository.name' "${stats_file}" >/dev/null
    jq -e '.repository.schema_version' "${stats_file}" >/dev/null
}

@test "satlas stats with --out option" {
    mkdir -p output
    
    # First create scan output in the output directory
    satlas scan --out output
    
    run satlas stats --out output
    assert_success
    
    assert_file_exists "${TEST_TEMP_DIR}/output/sourceatlas.stats.json"
}

@test "stats handles empty index gracefully" {
    # Create empty index
    echo "" > .sourceatlas/sourceatlas.index.jsonl
    
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Should have zero counts
    local file_count=$(jq -r '.files.total_count' "${stats_file}")
    [ "$file_count" -eq 0 ]
}

@test "stats role distribution" {
    run satlas stats
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    
    # Check for role distribution
    jq -e '.roles' "${stats_file}" >/dev/null
    
    # Should have various roles
    local general_count=$(jq -r '.roles.general // 0' "${stats_file}")
    [ "$general_count" -ge 0 ]
}