#!/usr/bin/env bats

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize and create files
    satlas init
    satlas scan
    satlas symbols
    satlas stats
    satlas manifest
}

teardown() {
    cleanup_test_env
}

@test "satlas clean removes output files" {
    run satlas clean
    assert_success
    
    # Should remove all output files
    [ ! -f ".sourceatlas/sourceatlas.index.jsonl" ]
    [ ! -f ".sourceatlas/sourceatlas.symbols.tsv" ]
    [ ! -f ".sourceatlas/sourceatlas.stats.json" ]
    [ ! -f ".sourceatlas/sourceatlas.manifest.json" ]
}

@test "satlas clean preserves source files" {
    run satlas clean
    assert_success
    
    # Should not remove source files
    assert_file_exists "ios/AppDelegate.swift"
    assert_file_exists "android/MainActivity.kt"
    assert_file_exists "config/app.json"
}

@test "satlas clean preserves config files" {
    run satlas clean
    assert_success
    
    # Should preserve config and exclude files
    assert_file_exists ".sourceatlas/config.toml"
    assert_file_exists ".sourceatlas/exclude_patterns.txt"
}

@test "satlas clean with --out option" {
    mkdir -p output
    satlas scan --out output
    satlas symbols --out output
    
    run satlas clean --out output
    assert_success
    
    # Should clean custom output directory
    [ ! -f "output/sourceatlas.index.jsonl" ]
    [ ! -f "output/sourceatlas.symbols.tsv" ]
}

@test "satlas clean removes shard files" {
    # Create shard files
    satlas shard
    
    run satlas clean
    assert_success
    
    # Should remove shard files
    local shard_count=$(ls .sourceatlas/sourceatlas.index.*.jsonl 2>/dev/null | wc -l)
    [ "$shard_count" -eq 0 ]
}

@test "satlas clean handles missing files gracefully" {
    # Remove files first
    rm -f .sourceatlas/sourceatlas.*.jsonl .sourceatlas/sourceatlas.*.tsv .sourceatlas/sourceatlas.*.json
    
    run satlas clean
    assert_success
    
    # Should not error when files are already missing
    assert_output_contains "No output files found to clean" || [ "$?" -eq 0 ]
}

@test "satlas clean dry run mode" {
    run satlas clean --dry-run
    assert_success
    
    # Should not actually remove files in dry run
    assert_file_exists ".sourceatlas/sourceatlas.index.jsonl"
    assert_file_exists ".sourceatlas/sourceatlas.symbols.tsv"
    
    # Should show what would be cleaned
    assert_output_contains "DRY RUN - Files that would be removed"
}

@test "satlas clean shows cleaned files" {
    run satlas clean
    assert_success
    
    # Should report what was cleaned
    assert_output_contains "Cleaned" || assert_output_contains "Removed"
}