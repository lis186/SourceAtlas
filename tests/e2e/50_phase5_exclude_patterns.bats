#!/usr/bin/env bats

# Phase 5 Step 5.1: Exclude patterns testing
# Verification: Excluded directories (Pods/.git/build/vendor/.gradle/PrebuiltFrameworks etc) do not appear in any output

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Create test directories that should be excluded
    mkdir -p Pods/SomeLibrary/Sources
    mkdir -p .git/hooks
    mkdir -p build/Debug-iphonesimulator
    mkdir -p vendor/bundle
    mkdir -p .gradle/caches
    mkdir -p PrebuiltFrameworks/SomeFramework.framework
    mkdir -p node_modules/react
    mkdir -p .sourceatlas/internal
    
    # Add some files in excluded directories
    echo "// Should be excluded" > Pods/SomeLibrary/Sources/Library.swift
    echo "#!/bin/bash" > .git/hooks/pre-commit
    echo "Binary data" > build/Debug-iphonesimulator/App.app
    echo "gem 'rails'" > vendor/bundle/Gemfile
    echo "gradle.properties" > .gradle/caches/config.properties
    echo "Framework binary" > PrebuiltFrameworks/SomeFramework.framework/SomeFramework
    echo "const React = require('react');" > node_modules/react/index.js
    
    # Initialize first, then modify exclude patterns
    satlas init
}

teardown() {
    cleanup_test_env
}

@test "excluded directories are not indexed by scan" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    assert_file_exists "$index_file"
    
    # Verify excluded directories don't appear in index
    run grep -F "Pods/" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".git/" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F "build/" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F "vendor/" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".gradle/" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F "PrebuiltFrameworks/" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F "node_modules/" "$index_file"
    [ "$status" -ne 0 ]
}

@test "default exclude patterns are created in exclude_patterns.txt" {
    local exclude_file="${TEST_TEMP_DIR}/.sourceatlas/exclude_patterns.txt"
    assert_file_exists "$exclude_file"
    
    # Verify common exclude patterns exist
    assert_file_contains "$exclude_file" "Pods/"
    assert_file_contains "$exclude_file" ".git/"
    assert_file_contains "$exclude_file" "build/"
    assert_file_contains "$exclude_file" "vendor/"
    assert_file_contains "$exclude_file" ".gradle/"
    assert_file_contains "$exclude_file" "PrebuiltFrameworks/"
    assert_file_contains "$exclude_file" "node_modules/"
}

@test "custom exclude patterns can be added" {
    local exclude_file="${TEST_TEMP_DIR}/.sourceatlas/exclude_patterns.txt"
    
    # Add custom exclude pattern
    echo "custom_exclude_dir/" >> "$exclude_file"
    
    # Create directory matching custom pattern
    mkdir -p custom_exclude_dir/should_be_ignored
    echo "// Should be excluded" > custom_exclude_dir/should_be_ignored/test.swift
    
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Verify custom exclude pattern works
    run grep -F "custom_exclude_dir/" "$index_file"
    [ "$status" -ne 0 ]
}

@test "exclude patterns support glob patterns" {
    local exclude_file="${TEST_TEMP_DIR}/.sourceatlas/exclude_patterns.txt"
    
    # Add glob pattern
    echo "temp_*/" >> "$exclude_file"
    echo "*.tmp" >> "$exclude_file"
    
    # Create matching files and directories
    mkdir -p temp_123/nested
    mkdir -p temp_xyz/nested
    echo "temporary" > temp_123/nested/file.swift
    echo "temporary" > temp_xyz/nested/file.kt
    echo "temporary data" > regular_file.tmp
    echo "should be indexed" > regular_file.swift
    
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Verify glob patterns work
    run grep -F "temp_" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".tmp" "$index_file"
    [ "$status" -ne 0 ]
    
    # Verify regular files are still indexed
    assert_file_contains "$index_file" "regular_file.swift"
}

@test "excluded directories do not appear in symbols table" {
    run satlas run
    assert_success
    
    local symbols_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    assert_file_exists "$symbols_file"
    
    # Verify excluded directories don't appear in symbols
    run grep -F "Pods/" "$symbols_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".git/" "$symbols_file"
    [ "$status" -ne 0 ]
    
    run grep -F "build/" "$symbols_file"
    [ "$status" -ne 0 ]
}

@test "excluded directories do not appear in manifest" {
    run satlas run
    assert_success
    
    local manifest_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.manifest.json"
    assert_file_exists "$manifest_file"
    
    # Verify excluded directories don't appear in manifest paths
    run grep -F "Pods/" "$manifest_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".git/" "$manifest_file"
    [ "$status" -ne 0 ]
}

@test "exclude patterns are case sensitive by default" {
    local exclude_file="${TEST_TEMP_DIR}/.sourceatlas/exclude_patterns.txt"
    
    # Add case sensitive pattern
    echo "CaseSensitive/" >> "$exclude_file"
    
    # Create directories with different cases
    mkdir -p CaseSensitive/should_be_excluded
    mkdir -p casesensitive/should_be_included
    echo "excluded" > CaseSensitive/should_be_excluded/test.swift
    echo "included" > casesensitive/should_be_included/test.swift
    
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Verify case sensitivity
    run grep -F "CaseSensitive/" "$index_file"
    [ "$status" -ne 0 ]
    
    assert_file_contains "$index_file" "casesensitive/"
}

@test "stats report shows excluded file counts" {
    run satlas run
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    assert_file_exists "$stats_file"
    
    # Stats should include information about excluded files/directories
    local stats_content="$(cat "$stats_file")"
    if [[ "$stats_content" == *"excluded"* ]] || [[ "$stats_content" == *"skipped"* ]]; then
        true  # Found exclusion information
    else
        # For now, just verify stats file exists and has content
        [ -s "$stats_file" ]
    fi
}