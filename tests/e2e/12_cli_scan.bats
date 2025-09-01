#!/usr/bin/env bats

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize before scan
    satlas init
}

teardown() {
    cleanup_test_env
}

@test "satlas scan creates index file" {
    run satlas scan
    assert_success
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
}

@test "satlas scan indexes Swift files" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    assert_file_contains "${index_file}" "AppDelegate.swift"
    assert_file_contains "${index_file}" "ViewModel.swift"
}

@test "satlas scan indexes Kotlin files" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    assert_file_contains "${index_file}" "MainActivity.kt"
    assert_file_contains "${index_file}" "MainViewModel.kt"
}

@test "satlas scan indexes script files" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    assert_file_contains "${index_file}" "build.sh"
    assert_file_contains "${index_file}" "test_helper.rb"
    assert_file_contains "${index_file}" "utils.py"
}

@test "satlas scan indexes config files" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    assert_file_contains "${index_file}" "app.json"
    assert_file_contains "${index_file}" "build.gradle"
    assert_file_contains "${index_file}" "settings.yml"
}

@test "satlas scan excludes sensitive files" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Should not contain excluded files
    run grep -F "private_key.p12" "${index_file}"
    assert_failure
    
    run grep -F "cert.cer" "${index_file}"
    assert_failure
}

@test "index contains required fields" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Check first line has required fields
    local first_line=$(head -n 1 "${index_file}")
    
    # Check for required fields in JSON
    echo "${first_line}" | jq -e '.path' >/dev/null
    echo "${first_line}" | jq -e '.file_name' >/dev/null
    echo "${first_line}" | jq -e '.ext' >/dev/null
    echo "${first_line}" | jq -e '.lang' >/dev/null
    echo "${first_line}" | jq -e '.size_bytes' >/dev/null
    echo "${first_line}" | jq -e '.loc' >/dev/null
    echo "${first_line}" | jq -e '.content_hash' >/dev/null
}

@test "index detects language correctly" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Check Swift file has correct language
    local swift_line=$(grep -F "AppDelegate.swift" "${index_file}")
    echo "${swift_line}" | jq -e '.lang == "swift"' >/dev/null
    
    # Check Kotlin file has correct language
    local kotlin_line=$(grep -F "MainActivity.kt" "${index_file}")
    echo "${kotlin_line}" | jq -e '.lang == "kotlin"' >/dev/null
    
    # Check Python file has correct language
    local python_line=$(grep -F "utils.py" "${index_file}")
    echo "${python_line}" | jq -e '.lang == "python"' >/dev/null
}

@test "satlas scan with --root option" {
    mkdir -p subdir
    mv ios android scripts config subdir/
    
    run satlas scan --root subdir
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    assert_file_contains "${index_file}" "AppDelegate.swift"
}

@test "satlas scan with --out option" {
    mkdir -p output
    
    run satlas scan --out output
    assert_success
    
    assert_file_exists "${TEST_TEMP_DIR}/output/sourceatlas.index.jsonl"
}

@test "index is valid JSONL format" {
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Validate each line is valid JSON
    while IFS= read -r line; do
        echo "${line}" | jq empty || return 1
    done < "${index_file}"
}

@test "satlas scan respects exclude patterns" {
    # Create a build directory with a file
    mkdir -p build
    echo "test" > build/test.txt
    
    run satlas scan
    assert_success
    
    local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
    
    # Should not contain build directory files
    run grep -F "build/test.txt" "${index_file}"
    assert_failure
}