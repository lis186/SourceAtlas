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

@test "satlas manifest requires index file" {
    rm -f .sourceatlas/sourceatlas.index.jsonl
    
    run satlas manifest
    assert_failure
    assert_output_contains "Index file not found"
}

@test "satlas manifest creates JSON file" {
    run satlas manifest
    assert_success
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
}

@test "manifest JSON is valid format" {
    run satlas manifest
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Validate JSON format
    jq empty < "${manifest_file}"
}

@test "manifest contains version info" {
    run satlas manifest
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check for version and schema
    jq -e '.version' "${manifest_file}" >/dev/null
    jq -e '.schema_version' "${manifest_file}" >/dev/null
    
    local schema_version=$(jq -r '.schema_version' "${manifest_file}")
    [ "$schema_version" = "1" ]
}

@test "manifest contains generation timestamp" {
    run satlas manifest
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check for timestamp
    jq -e '.generated_at' "${manifest_file}" >/dev/null
    
    # Should be recent timestamp
    local timestamp=$(jq -r '.generated_at' "${manifest_file}")
    [ -n "$timestamp" ]
}

@test "manifest contains repository info" {
    run satlas manifest
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check for repo info
    jq -e '.repository.name' "${manifest_file}" >/dev/null
    jq -e '.repository.root_path' "${manifest_file}" >/dev/null
}

@test "manifest contains file summary" {
    run satlas manifest
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check for file summary
    jq -e '.files.total_count' "${manifest_file}" >/dev/null
    jq -e '.files.languages' "${manifest_file}" >/dev/null
    jq -e '.files.total_size_bytes' "${manifest_file}" >/dev/null
}

@test "manifest contains output files info" {
    run satlas manifest
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check for output files
    jq -e '.outputs' "${manifest_file}" >/dev/null
    jq -e '.outputs.index' "${manifest_file}" >/dev/null
    
    # Index file should exist and have correct path
    local index_path=$(jq -r '.outputs.index.path' "${manifest_file}")
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/${index_path}"
}

@test "manifest includes hash information" {
    run satlas manifest
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check for hash info
    jq -e '.outputs.index.hash' "${manifest_file}" >/dev/null
    
    # Hash should not be empty
    local index_hash=$(jq -r '.outputs.index.hash' "${manifest_file}")
    [ -n "$index_hash" ]
    [ "$index_hash" != "null" ]
}

@test "satlas manifest with --out option" {
    mkdir -p output
    
    # First create scan output in the output directory
    satlas scan --out output
    
    run satlas manifest --out output
    assert_success
    
    assert_file_exists "${TEST_TEMP_DIR}/output/sourceatlas.manifest.json"
}

@test "manifest handles symbols file if present" {
    # Generate symbols first
    satlas symbols
    
    run satlas manifest
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Should include symbols file in outputs
    jq -e '.outputs.symbols' "${manifest_file}" >/dev/null
    
    local symbols_path=$(jq -r '.outputs.symbols.path' "${manifest_file}")
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/${symbols_path}"
}

@test "manifest handles stats file if present" {
    # Generate stats first
    satlas stats
    
    run satlas manifest
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Should include stats file in outputs
    jq -e '.outputs.stats' "${manifest_file}" >/dev/null
    
    local stats_path=$(jq -r '.outputs.stats.path' "${manifest_file}")
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/${stats_path}"
}

@test "manifest is deterministic" {
    # Generate manifest twice
    satlas manifest
    cp .sourceatlas/sourceatlas.manifest.json first_manifest.json
    
    sleep 1
    satlas manifest
    cp .sourceatlas/sourceatlas.manifest.json second_manifest.json
    
    # Timestamps will differ, but structure should be same
    local first_version=$(jq -r '.version' first_manifest.json)
    local second_version=$(jq -r '.version' second_manifest.json)
    [ "$first_version" = "$second_version" ]
    
    local first_schema=$(jq -r '.schema_version' first_manifest.json)
    local second_schema=$(jq -r '.schema_version' second_manifest.json)
    [ "$first_schema" = "$second_schema" ]
}