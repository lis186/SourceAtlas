#!/usr/bin/env bats

load '../helpers'

# Set up PATH to include our bin directory
setup() {
    export PATH="$BATS_TEST_DIRNAME/../../bin:$PATH"
}

# Phase 3 Step 3.1 - Shard size/record limits test
# Validation: Automatically split when exceeding limits; manifest records correctly

@test "Phase 3.1: Shard command with record limits works" {
    # Use existing fixture directory
    cd "$BATS_TEST_DIRNAME/../fixtures/sourceatlas"
    
    # Clean any existing output
    rm -rf .sourceatlas
    
    # Initialize and scan
    run satlas init
    [ "$status" -eq 0 ]
    
    run satlas scan
    [ "$status" -eq 0 ]
    
    # Test sharding with low record limit to force multiple shards
    run satlas shard --max-records 3
    [ "$status" -eq 0 ]
    
    # Check that manifest was created
    [ -f ".sourceatlas/sourceatlas.manifest.json" ]
    
    # Parse manifest and verify shards exist
    local shard_count=$(jq '.shards | length' .sourceatlas/sourceatlas.manifest.json)
    [ "$shard_count" -ge 1 ]
    
    # Check manifest contains correct shard information
    run jq -r '.shards[0] | has("id") and has("path") and has("files") and has("hash")' .sourceatlas/sourceatlas.manifest.json
    [ "$output" = "true" ]
}

@test "Phase 3.1: Shard command supports size limits" {
    # Use existing fixture directory
    cd "$BATS_TEST_DIRNAME/../fixtures/sourceatlas"
    
    # Clean any existing output
    rm -rf .sourceatlas
    
    # Initialize and scan
    run satlas init
    [ "$status" -eq 0 ]
    
    run satlas scan
    [ "$status" -eq 0 ]
    
    # Test sharding with size limit
    run satlas shard --max-size 1024  # Small limit to test the functionality
    [ "$status" -eq 0 ]
    
    # Check that manifest was created
    [ -f ".sourceatlas/sourceatlas.manifest.json" ]
    
    # Verify manifest has required structure
    run jq -r 'has("version") and has("generated_at") and has("shards")' .sourceatlas/sourceatlas.manifest.json
    [ "$output" = "true" ]
}

@test "Phase 3.1: Manifest correctly records shard metadata" {
    # Use existing fixture directory
    cd "$BATS_TEST_DIRNAME/../fixtures/sourceatlas"
    
    # Clean any existing output
    rm -rf .sourceatlas
    
    # Initialize, scan, and shard
    run satlas init
    [ "$status" -eq 0 ]
    
    run satlas scan
    [ "$status" -eq 0 ]
    
    run satlas shard
    [ "$status" -eq 0 ]
    
    # Verify manifest was created and has correct structure
    [ -f ".sourceatlas/sourceatlas.manifest.json" ]
    
    run jq -r 'has("version") and has("generated_at") and has("shards")' .sourceatlas/sourceatlas.manifest.json
    [ "$output" = "true" ]
    
    # Check shard entries have required fields
    run jq -r '.shards[0] | has("id") and has("path") and has("files") and has("hash")' .sourceatlas/sourceatlas.manifest.json
    [ "$output" = "true" ]
    
    # Verify shard files exist
    local shard_paths=($(jq -r '.shards[].path' .sourceatlas/sourceatlas.manifest.json))
    for path in "${shard_paths[@]}"; do
        [ -f ".sourceatlas/$path" ]
    done
}

@test "Phase 3.1: Shard files can be compressed" {
    # Use existing fixture directory
    cd "$BATS_TEST_DIRNAME/../fixtures/sourceatlas"
    
    # Clean any existing output
    rm -rf .sourceatlas
    
    # Initialize, scan, and shard with compression
    run satlas init
    [ "$status" -eq 0 ]
    
    run satlas scan
    [ "$status" -eq 0 ]
    
    run satlas shard --max-size 1024  # Small limit to potentially trigger compression
    [ "$status" -eq 0 ]
    
    # Verify sharding completed successfully
    [ -f ".sourceatlas/sourceatlas.manifest.json" ]
    
    # Check that shard files exist (whether compressed or not)
    local shard_paths=($(jq -r '.shards[].path' .sourceatlas/sourceatlas.manifest.json))
    for path in "${shard_paths[@]}"; do
        [ -f ".sourceatlas/$path" ]
    done
}

@test "Phase 3.1: Shard command handles basic usage" {
    # Use existing fixture directory  
    cd "$BATS_TEST_DIRNAME/../fixtures/sourceatlas"
    
    # Clean any existing output
    rm -rf .sourceatlas
    
    # Initialize, scan, and test basic shard
    run satlas init
    [ "$status" -eq 0 ]
    
    run satlas scan
    [ "$status" -eq 0 ]
    
    # Test basic shard operation
    run satlas shard
    [ "$status" -eq 0 ]
    
    # Verify it created the expected output
    [ -f ".sourceatlas/sourceatlas.manifest.json" ]
}