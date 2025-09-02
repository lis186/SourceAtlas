#!/usr/bin/env bats

# Phase 5 Step 5.2: Certificate/signature file filtering
# Verification: Sensitive files (*.mobileprovision, *.cer, *.p12) are not indexed; 
# reports show statistics of excluded quantities (optional)

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Create sensitive files that should be excluded
    mkdir -p ios/Certificates
    mkdir -p android/keystore
    mkdir -p config/secrets
    
    # iOS sensitive files
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > ios/Certificates/Development.mobileprovision
    echo "-----BEGIN CERTIFICATE-----" > ios/Certificates/Distribution.cer
    echo "Binary certificate data" > ios/Certificates/Private.p12
    echo "Binary certificate data" > ios/Certificates/Development.p8
    echo "Binary certificate data" > ios/Certificates/AuthKey.p8
    
    # Android sensitive files  
    echo "Binary keystore data" > android/keystore/release.keystore
    echo "Binary keystore data" > android/keystore/debug.jks
    
    # Other sensitive files
    echo "ssh-rsa AAAAB3..." > config/secrets/id_rsa.pub
    echo "-----BEGIN PRIVATE KEY-----" > config/secrets/private_key.pem
    echo "API_KEY=secret123" > config/secrets/.env
    echo "password=secret" > config/secrets/credentials.txt
    
    # Create some legitimate files that should be indexed
    echo "// Regular Swift code" > ios/AppDelegate.swift
    echo "// Regular Kotlin code" > android/MainActivity.kt
    echo "# Configuration" > config/app.toml
    
    # Initialize after creating structure
    satlas init
}

teardown() {
    cleanup_test_env
}

@test "mobileprovision files are not indexed" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    assert_file_exists "$index_file"
    
    # Verify .mobileprovision files are excluded
    run grep -F ".mobileprovision" "$index_file"
    [ "$status" -ne 0 ]
    
    # But regular files should be indexed
    assert_file_contains "$index_file" "AppDelegate.swift"
}

@test "certificate files (.cer) are not indexed" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Verify .cer files are excluded
    run grep -F ".cer" "$index_file"
    [ "$status" -ne 0 ]
}

@test "private key files (.p12, .p8) are not indexed" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Verify .p12 and .p8 files are excluded
    run grep -F ".p12" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".p8" "$index_file"
    [ "$status" -ne 0 ]
}

@test "keystore files (.keystore, .jks) are not indexed" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Verify keystore files are excluded
    run grep -F ".keystore" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".jks" "$index_file"
    [ "$status" -ne 0 ]
}

@test "credential files (.pem, .env, credentials) are not indexed" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Verify credential files are excluded
    run grep -F "private_key.pem" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".env" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F "credentials.txt" "$index_file"
    [ "$status" -ne 0 ]
}

@test "SSH keys are not indexed" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Verify SSH keys are excluded
    run grep -F "id_rsa" "$index_file"
    [ "$status" -ne 0 ]
}

@test "sensitive files do not appear in symbols table" {
    run satlas run
    assert_success
    
    local symbols_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    assert_file_exists "$symbols_file"
    
    # Verify sensitive files don't appear in symbols
    run grep -F ".mobileprovision" "$symbols_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".p12" "$symbols_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".keystore" "$symbols_file"
    [ "$status" -ne 0 ]
}

@test "sensitive file patterns are in default exclude patterns" {
    local exclude_file="${TEST_TEMP_DIR}/.sourceatlas/exclude_patterns.txt"
    assert_file_exists "$exclude_file"
    
    # Verify sensitive file patterns are included by default
    assert_file_contains "$exclude_file" "*.mobileprovision" || assert_file_contains "$exclude_file" ".mobileprovision"
    assert_file_contains "$exclude_file" "*.p12" || assert_file_contains "$exclude_file" ".p12"
    assert_file_contains "$exclude_file" "*.keystore" || assert_file_contains "$exclude_file" ".keystore"
    assert_file_contains "$exclude_file" "*.pem" || assert_file_contains "$exclude_file" ".pem"
}

@test "stats report includes excluded sensitive file counts" {
    run satlas run
    assert_success
    
    local stats_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.stats.json"
    assert_file_exists "$stats_file"
    
    # Stats should include information about excluded sensitive files
    local stats_content="$(cat "$stats_file")"
    [[ "$stats_content" == *"excluded"* ]] || [[ "$stats_content" == *"sensitive"* ]] || [[ "$stats_content" == *"filtered"* ]] || [ "$?" -eq 0 ]
}

@test "query operations do not return sensitive files" {
    run satlas run  
    assert_success
    
    # Try to query for sensitive file patterns
    run satlas query "mobileprovision"
    [ "$status" -eq 0 ]
    
    # Should not return sensitive files even if they exist
    [[ "$output" != *".mobileprovision"* ]]
    
    run satlas query "keystore"
    [ "$status" -eq 0 ]
    [[ "$output" != *".keystore"* ]]
}

@test "segment extraction cannot access sensitive files" {
    run satlas run
    assert_success
    
    # Try to extract segments from sensitive files - should fail safely
    run satlas segment "ios/Certificates/Development.mobileprovision" 1 10
    
    # Should either fail with appropriate error or return empty result
    if [ "$status" -ne 0 ]; then
        [[ "$output" == *"not found"* ]] || [[ "$output" == *"excluded"* ]] || [[ "$output" == *"access denied"* ]]
    else
        [[ "$output" == "" ]] || [[ "$output" == *"no content"* ]]
    fi
}

@test "regular config files are still indexed while secrets are excluded" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Regular config files should be indexed
    assert_file_contains "$index_file" "app.toml"
    
    # But secret files should not
    run grep -F "credentials.txt" "$index_file"
    [ "$status" -ne 0 ]
    
    run grep -F ".env" "$index_file"
    [ "$status" -ne 0 ]
}