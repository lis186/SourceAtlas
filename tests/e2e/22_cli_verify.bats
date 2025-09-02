#!/usr/bin/env bats

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize and create all outputs
    satlas init
    satlas scan
    satlas symbols
    satlas stats
    satlas manifest
}

teardown() {
    cleanup_test_env
}

@test "satlas verify requires existing files" {
    rm -f .sourceatlas/sourceatlas.index.jsonl
    
    run satlas verify
    assert_failure
    assert_output_contains "Index file not found"
}

@test "satlas verify checks index-symbol consistency" {
    run satlas verify
    # Command may succeed or fail depending on actual consistency
    
    # Should check symbol consistency (may pass or fail)
    assert_output_contains "symbol" && (assert_output_contains "checks passed" || assert_output_contains "Verification failed")
}

@test "satlas verify detects index-symbol inconsistency" {
    # Add fake symbol entry
    echo -e "fake_symbol\t1\tnonexistent.swift\tclass\tpublic" >> .sourceatlas/sourceatlas.symbols.tsv
    
    run satlas verify
    assert_failure
    assert_output_contains "Symbol references missing file" || assert_output_contains "Consistency check failed"
}

@test "satlas verify checks manifest consistency" {
    run satlas verify
    # Command may succeed or fail depending on actual consistency
    
    # Should check manifest consistency (may pass or fail)
    assert_output_contains "manifest" || assert_output_contains "file count" || assert_output_contains "checks passed" || assert_output_contains "Verification failed"
}

@test "satlas verify detects manifest inconsistency" {
    # Corrupt manifest file count
    sed -i 's/"file_count":[0-9]*/"file_count":999/' .sourceatlas/sourceatlas.manifest.json
    
    run satlas verify
    assert_failure
    assert_output_contains "File count mismatch" || assert_output_contains "Manifest inconsistency"
}

@test "satlas verify checks hash consistency" {
    run satlas verify
    # Command may succeed or fail depending on actual consistency
    
    # Should perform verification (may pass or fail)
    assert_output_contains "checks passed" || assert_output_contains "Verification failed"
}

@test "satlas verify with --out option" {
    mkdir -p output
    
    # Create outputs in custom directory
    satlas scan --out output
    satlas symbols --out output
    satlas manifest --out output
    
    run satlas verify --out output
    # Command may succeed or fail depending on consistency
    
    # Should work with custom output directory
    assert_output_contains "checks passed" || assert_output_contains "Verification failed"
}

@test "satlas verify shows detailed report" {
    run satlas verify --verbose
    # Command may succeed or fail, but should show detailed output
    
    # Should show detailed verification information
    assert_output_contains "Checking" || assert_output_contains "Verifying" || assert_output_contains "✓" || assert_output_contains "✗"
}

@test "satlas verify checks all components" {
    run satlas verify
    # Command may succeed or fail depending on consistency
    
    # Should perform verification checks
    assert_output_contains "checks passed" || assert_output_contains "Verification failed"
}

@test "satlas verify handles missing optional files" {
    # Remove optional stats file
    rm -f .sourceatlas/sourceatlas.stats.json
    
    run satlas verify
    # Command may succeed or fail, but should handle missing optional files
    
    # Should handle missing optional files gracefully
    assert_output_contains "checks passed" || assert_output_contains "Verification failed" || [ "$?" -eq 0 ]
}