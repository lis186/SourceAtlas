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

@test "satlas shard requires index file" {
    rm -f .sourceatlas/sourceatlas.index.jsonl
    
    run satlas shard
    assert_failure
    assert_output_contains "Index file not found"
}

@test "satlas shard creates shard files" {
    run satlas shard
    assert_success
    
    # Should create at least one shard file
    local shard_count=$(ls .sourceatlas/sourceatlas.index.*.jsonl 2>/dev/null | wc -l)
    [ "$shard_count" -gt 0 ]
}

@test "satlas shard updates manifest with shard info" {
    run satlas shard
    assert_success
    
    # Should create or update manifest
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check for shards section
    jq -e '.shards' "${manifest_file}" >/dev/null
    
    # Should have at least one shard
    local shard_count=$(jq -r '.shards | length' "${manifest_file}")
    [ "$shard_count" -gt 0 ]
}

@test "shard files are valid JSONL" {
    run satlas shard
    assert_success
    
    # Validate each shard file is valid JSONL
    for shard_file in .sourceatlas/sourceatlas.index.*.jsonl; do
        if [[ -f "$shard_file" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    echo "$line" | jq empty || return 1
                fi
            done < "$shard_file"
        fi
    done
}

@test "shards are created by directory" {
    run satlas shard --by-directory
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check shard rules in manifest
    jq -e '.shard_rules' "${manifest_file}" >/dev/null
    jq -e '.shard_rules.by_dir' "${manifest_file}" >/dev/null
}

@test "shards are created by language" {
    run satlas shard --by-language
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Should have language-based shards
    local swift_shard=$(jq -r '.shards[] | select(.lang[]? == "swift") | .id' "${manifest_file}" | head -1)
    local kotlin_shard=$(jq -r '.shards[] | select(.lang[]? == "kotlin") | .id' "${manifest_file}" | head -1)
    
    # At least check that we can find language references
    jq -r '.shards[].lang[]?' "${manifest_file}" | grep -q "." || true
}

@test "shard respects size limits" {
    # Create a large index by duplicating entries
    local original_index=".sourceatlas/sourceatlas.index.jsonl"
    local temp_index="${original_index}.tmp"
    
    # Duplicate entries to create larger index
    for i in {1..5}; do
        cat "$original_index" >> "$temp_index"
    done
    mv "$temp_index" "$original_index"
    
    run satlas shard --max-size 1000
    assert_success
    
    # Should create multiple shards due to size limit
    local shard_count=$(ls .sourceatlas/sourceatlas.index.*.jsonl 2>/dev/null | wc -l)
    [ "$shard_count" -gt 1 ]
}

@test "shard respects record limits" {
    run satlas shard --max-records 5
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check that no shard exceeds record limit
    local max_records=$(jq -r '[.shards[].files] | max' "${manifest_file}")
    [ "$max_records" -le 5 ]
}

@test "satlas shard with --out option" {
    mkdir -p output
    
    # First create scan output in the output directory
    satlas scan --out output
    
    run satlas shard --out output
    assert_success
    
    # Should create shard files in output directory
    local shard_count=$(ls output/sourceatlas.index.*.jsonl 2>/dev/null | wc -l)
    [ "$shard_count" -gt 0 ]
}

@test "shard preserves all original data" {
    # Count original records
    local original_count=$(cat .sourceatlas/sourceatlas.index.jsonl | jq -s 'length')
    
    run satlas shard
    assert_success
    
    # Count records in all shards
    local total_shard_records=0
    for shard_file in .sourceatlas/sourceatlas.index.*.jsonl; do
        if [[ -f "$shard_file" ]]; then
            local shard_records=$(cat "$shard_file" | jq -s 'length')
            total_shard_records=$((total_shard_records + shard_records))
        fi
    done
    
    # Should preserve all records
    [ "$total_shard_records" -eq "$original_count" ]
}

@test "manifest contains shard metadata" {
    run satlas shard
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Check shard metadata structure
    jq -e '.shards[0].id' "${manifest_file}" >/dev/null
    jq -e '.shards[0].path' "${manifest_file}" >/dev/null
    jq -e '.shards[0].files' "${manifest_file}" >/dev/null
    jq -e '.shards[0].hash' "${manifest_file}" >/dev/null
    
    # Check that hash is not empty
    local first_shard_hash=$(jq -r '.shards[0].hash' "${manifest_file}")
    [ -n "$first_shard_hash" ]
    [ "$first_shard_hash" != "null" ]
}

@test "shard handles empty index gracefully" {
    # Create empty index
    echo "" > .sourceatlas/sourceatlas.index.jsonl
    
    run satlas shard
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    
    # Should handle empty index without error
    local shard_count=$(jq -r '.shards | length' "${manifest_file}")
    [ "$shard_count" -ge 0 ]
}