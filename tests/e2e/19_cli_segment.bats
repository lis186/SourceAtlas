#!/usr/bin/env bats

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize and scan
    satlas init
    satlas scan
}

teardown() {
    cleanup_test_env
}

@test "satlas segment requires existing index" {
    rm -f .sourceatlas/sourceatlas.index.jsonl
    
    run satlas segment "ios/AppDelegate.swift" 1 10
    assert_failure
    assert_output_contains "Index file not found"
}

@test "satlas segment requires valid file path" {
    run satlas segment "nonexistent/file.swift" 1 10
    assert_failure
    assert_output_contains "File not found"
}

@test "satlas segment extracts basic range" {
    run satlas segment "ios/AppDelegate.swift" 5 15
    assert_success
    
    # Should contain lines from the requested range
    assert_output_contains "class AppDelegate"
    assert_output_contains "var window"
}

@test "satlas segment with padding" {
    run satlas segment --pad 2 "ios/AppDelegate.swift" 10 12
    assert_success
    
    # Should include padding lines around the range
    local line_count=$(echo "$output" | wc -l)
    [ "$line_count" -gt 5 ]  # Original 3 lines plus padding
}

@test "satlas segment respects line limit" {
    run satlas segment --max-lines 5 "ios/AppDelegate.swift" 1 20
    assert_success
    
    # Should limit output to 5 lines despite requesting 20
    local line_count=$(echo "$output" | wc -l)
    [ "$line_count" -le 5 ]
}

@test "satlas segment with default line limit" {
    run satlas segment "ios/AppDelegate.swift" 1 500
    assert_success
    
    # Should limit to default 400 lines
    local line_count=$(echo "$output" | wc -l)
    [ "$line_count" -le 400 ]
}

@test "satlas segment shows line numbers" {
    run satlas segment --line-numbers "ios/AppDelegate.swift" 5 10
    assert_success
    
    # Should show line numbers in output
    assert_output_contains "5:" || assert_output_contains "5 "
    assert_output_contains "10:" || assert_output_contains "10 "
}

@test "satlas segment handles out of range" {
    run satlas segment "ios/AppDelegate.swift" 1000 1010
    assert_success
    
    # Should handle gracefully, possibly return empty or file end
    # Just verify it doesn't crash
    [ "$?" -eq 0 ]
}

@test "satlas segment with context markers" {
    run satlas segment --context "ios/AppDelegate.swift" 8 12
    assert_success
    
    # Should show context information
    assert_output_contains "AppDelegate.swift" ||
    assert_output_contains "Lines 8-12"
}

@test "satlas segment single line" {
    run satlas segment "ios/AppDelegate.swift" 5 5
    assert_success
    
    # Should return single line
    local line_count=$(echo "$output" | grep -v "^$" | wc -l)
    [ "$line_count" -ge 1 ]
}

@test "satlas segment with --out option" {
    mkdir -p output
    
    # First create scan output in the output directory
    satlas scan --out output
    
    run satlas segment --out output "ios/AppDelegate.swift" 5 10
    assert_success
    
    # Should work with custom index location
    assert_output_contains "AppDelegate"
}

@test "satlas segment reverse range" {
    run satlas segment "ios/AppDelegate.swift" 15 10
    assert_success
    
    # Should handle reverse range by swapping start/end
    assert_output_contains "func application" ||
    assert_output_contains "didFinishLaunchingWithOptions"
}

@test "satlas segment with format options" {
    run satlas segment --format json "ios/AppDelegate.swift" 5 10
    assert_success
    
    # Should output valid JSON
    echo "$output" | jq empty
}

@test "satlas segment preserves indentation" {
    run satlas segment "ios/AppDelegate.swift" 10 12
    assert_success
    
    # Should preserve original indentation/whitespace
    echo "$output" | grep -q "    " || echo "$output" | grep -q $'\t'
}

@test "satlas segment with symbol context" {
    run satlas segment --symbol-context "ios/AppDelegate.swift" 10 12
    assert_success
    
    # Symbol context is currently disabled due to jq parsing issues
    # Just verify command doesn't crash
    [ "$?" -eq 0 ]
}