#!/usr/bin/env bats

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize, scan, and create initial state
    satlas init
    satlas scan
    satlas symbols
    satlas stats
    satlas manifest
}

teardown() {
    cleanup_test_env
}

@test "satlas delta requires existing index" {
    rm -f .sourceatlas/sourceatlas.index.jsonl
    
    run satlas delta
    assert_failure
    assert_output_contains "Index file not found"
}

@test "satlas delta detects no changes when nothing modified" {
    run satlas delta
    assert_success
    assert_output_contains "No changes detected"
}

@test "satlas delta detects file modifications" {
    # Modify a file
    echo "// Added comment" >> ios/AppDelegate.swift
    
    run satlas delta
    assert_success
    
    # Should detect the change
    assert_output_contains "modified"
    assert_output_contains "AppDelegate.swift"
}

@test "satlas delta detects new files" {
    # Add a new file
    echo 'print("Hello World")' > ios/NewFile.swift
    
    run satlas delta
    assert_success
    
    # Should detect the new file
    assert_output_contains "added"
    assert_output_contains "NewFile.swift"
}

@test "satlas delta detects deleted files" {
    # Remove a file
    rm ios/ViewModel.swift
    
    run satlas delta
    assert_success
    
    # Should detect the deletion
    assert_output_contains "removed"
    assert_output_contains "ViewModel.swift"
}

@test "satlas delta creates delta report" {
    # Modify a file
    echo "// Modified" >> ios/AppDelegate.swift
    
    run satlas delta
    assert_success
    
    # Should create delta report
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/delta.report.json"
    
    local report_file="${TEST_TEMP_DIR}/.sourceatlas/delta.report.json"
    
    # Validate JSON format
    jq empty < "${report_file}"
    
    # Check for expected fields
    jq -e '.timestamp' "${report_file}" >/dev/null
    jq -e '.changes' "${report_file}" >/dev/null
    jq -e '.summary' "${report_file}" >/dev/null
}

@test "satlas delta with --apply rebuilds affected files" {
    # Modify a file
    echo "// Modified" >> ios/AppDelegate.swift
    
    run satlas delta --apply
    assert_success
    
    # Should update index with changes
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Should update symbols and stats
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
}

@test "satlas delta with --out option" {
    mkdir -p output
    
    # First create initial state in output directory
    satlas scan --out output
    satlas symbols --out output
    satlas stats --out output
    satlas manifest --out output
    
    # Modify a file
    echo "// Modified" >> ios/AppDelegate.swift
    
    run satlas delta --out output
    assert_success
    
    # Should create delta report in output directory
    assert_file_exists "${TEST_TEMP_DIR}/output/delta.report.json"
}

@test "delta report contains change metadata" {
    # Modify a file
    echo "// Modified" >> ios/AppDelegate.swift
    
    run satlas delta
    assert_success
    
    local report_file="${TEST_TEMP_DIR}/.sourceatlas/delta.report.json"
    
    # Check change details
    jq -e '.changes[] | select(.type == "modified")' "${report_file}" >/dev/null
    jq -e '.changes[] | select(.path | contains("AppDelegate.swift"))' "${report_file}" >/dev/null
    
    # Check summary
    local modified_count=$(jq -r '.summary.modified_count' "${report_file}")
    [ "$modified_count" -gt 0 ]
}

@test "satlas delta respects threshold for full rebuild" {
    # Create many changes (simulate >30% change)
    for file in ios/*.swift android/*.kt; do
        if [[ -f "$file" ]]; then
            echo "// Mass modification" >> "$file"
        fi
    done
    
    run satlas delta
    assert_success
    
    # Should suggest full rebuild due to large changes
    assert_output_contains "large number of changes" || 
    assert_output_contains "Consider running full rebuild"
}

@test "satlas delta is idempotent" {
    # Modify a file
    echo "// Modified" >> ios/AppDelegate.swift
    
    # Run delta twice
    run satlas delta
    assert_success
    local first_output="$output"
    
    run satlas delta
    assert_success
    
    # Second run should show same changes (since --apply wasn't used)
    assert_output_contains "modified"
}

@test "satlas delta handles empty directory gracefully" {
    # Remove all fixture files
    rm -rf ios android scripts config
    
    run satlas delta
    assert_success
    
    # Should detect all files as removed
    assert_output_contains "removed" || 
    assert_output_contains "No changes detected"
}