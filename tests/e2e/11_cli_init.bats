#!/usr/bin/env bats

load ../helpers

setup() {
    setup_test_env
    cd "${TEST_TEMP_DIR}"
}

teardown() {
    cleanup_test_env
}

@test "satlas init creates .sourceatlas directory" {
    run satlas init
    assert_success
    assert_dir_exists "${TEST_TEMP_DIR}/.sourceatlas"
}

@test "satlas init creates default config file" {
    run satlas init
    assert_success
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/config.toml"
}

@test "satlas init creates default .gitignore" {
    run satlas init
    assert_success
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/.gitignore"
    assert_file_contains "${TEST_TEMP_DIR}/.sourceatlas/.gitignore" "*.jsonl"
    assert_file_contains "${TEST_TEMP_DIR}/.sourceatlas/.gitignore" "*.tsv"
}

@test "satlas init creates exclude patterns file" {
    run satlas init
    assert_success
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/exclude_patterns.txt"
}

@test "default exclude patterns include build directories" {
    run satlas init
    assert_success
    
    local exclude_file="${TEST_TEMP_DIR}/.sourceatlas/exclude_patterns.txt"
    assert_file_contains "${exclude_file}" "**/build/**"
    assert_file_contains "${exclude_file}" "**/.gradle/**"
    assert_file_contains "${exclude_file}" "**/.git/**"
    assert_file_contains "${exclude_file}" "**/Pods/**"
    assert_file_contains "${exclude_file}" "**/vendor/**"
}

@test "default exclude patterns include sensitive files" {
    run satlas init
    assert_success
    
    local exclude_file="${TEST_TEMP_DIR}/.sourceatlas/exclude_patterns.txt"
    assert_file_contains "${exclude_file}" "*.mobileprovision"
    assert_file_contains "${exclude_file}" "*.cer"
    assert_file_contains "${exclude_file}" "*.p12"
}

@test "satlas init is idempotent" {
    run satlas init
    assert_success
    local first_output="$output"
    
    # Run again
    run satlas init
    assert_success
    assert_output_contains "already initialized"
}

@test "satlas init --force overwrites existing config" {
    # First init
    run satlas init
    assert_success
    
    # Modify config
    echo "# Modified" >> "${TEST_TEMP_DIR}/.sourceatlas/config.toml"
    
    # Force reinit
    run satlas init --force
    assert_success
    
    # Check that modified comment is gone
    run grep "# Modified" "${TEST_TEMP_DIR}/.sourceatlas/config.toml"
    assert_failure
}

@test "config file contains expected sections" {
    run satlas init
    assert_success
    
    local config_file="${TEST_TEMP_DIR}/.sourceatlas/config.toml"
    assert_file_contains "${config_file}" "[general]"
    assert_file_contains "${config_file}" "[languages]"
    assert_file_contains "${config_file}" "[output]"
    assert_file_contains "${config_file}" "[limits]"
}

@test "config file contains language settings" {
    run satlas init
    assert_success
    
    local config_file="${TEST_TEMP_DIR}/.sourceatlas/config.toml"
    assert_file_contains "${config_file}" "swift"
    assert_file_contains "${config_file}" "kotlin"
    assert_file_contains "${config_file}" "objc"
    assert_file_contains "${config_file}" "ruby"
    assert_file_contains "${config_file}" "python"
    assert_file_contains "${config_file}" "shell"
}

@test "config file contains shard limits" {
    run satlas init
    assert_success
    
    local config_file="${TEST_TEMP_DIR}/.sourceatlas/config.toml"
    assert_file_contains "${config_file}" "shard_max_bytes"
    assert_file_contains "${config_file}" "shard_max_records"
}