#!/usr/bin/env bats

# Phase 2 Step 2.4: Other languages minimal extraction test
# Tests symbol extraction for Python, Ruby, and Shell

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize sourceatlas
    satlas init >/dev/null 2>&1
}

teardown() {
    cleanup_test_env
}

@test "Python class extraction" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that ConfigLoader class is extracted
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/utils.py\") | .symbols[] | select(.kind==\"class\") | .name' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Python class output: $output" >&3
    [[ "$output" == *"ConfigLoader"* ]]
}

@test "Python function extraction" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that DataProcessor class is extracted
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/utils.py\") | .symbols[] | select(.kind==\"class\") | .name' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Python class output: $output" >&3
    [[ "$output" == *"DataProcessor"* ]]
}

@test "Python function process_files extraction" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that process_files function is extracted
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/utils.py\") | .symbols[] | select(.kind==\"def\") | .name' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Python function output: $output" >&3
    [[ "$output" == *"process_files"* ]]
}

@test "Python symbol visibility" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that symbols have public visibility (Python default)
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/utils.py\") | .symbols[] | select(.name==\"ConfigLoader\") | .visibility' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Python visibility output: $output" >&3
    [[ "$output" == "public" ]]
}

@test "Ruby class extraction" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that Runner class is extracted
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/test_helper.rb\") | .symbols[] | select(.kind==\"class\") | .name' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Ruby class output: $output" >&3
    [[ "$output" == *"Runner"* ]]
}

@test "Ruby module extraction" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that TestHelper module is extracted
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/test_helper.rb\") | .symbols[] | select(.kind==\"module\") | .name' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Ruby module output: $output" >&3
    [[ "$output" == *"TestHelper"* ]]
}

@test "Ruby method extraction" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that run_tests method is extracted
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/test_helper.rb\") | .symbols[] | select(.kind==\"def\") | .name' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Ruby method output: $output" >&3
    [[ "$output" == *"run_tests"* ]]
}

@test "Shell function extraction" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that build_ios function is extracted
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/build.sh\") | .symbols[] | select(.kind==\"function\") | .name' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Shell function output: $output" >&3
    [[ "$output" == *"build_ios"* ]]
}

@test "Shell main function extraction" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that main function is extracted
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/build.sh\") | .symbols[] | select(.kind==\"function\") | .name' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Shell function output: $output" >&3
    [[ "$output" == *"main"* ]]
}

@test "All languages have non-empty symbols" {
    # Run scan to generate index
    run satlas scan
    assert_success
    
    # Check that Python file has symbols
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/utils.py\") | .symbols | length' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Python symbols count: $output" >&3
    [ "$output" -gt 0 ]
    
    # Check that Ruby file has symbols  
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/test_helper.rb\") | .symbols | length' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Ruby symbols count: $output" >&3
    [ "$output" -gt 0 ]
    
    # Check that Shell file has symbols
    run bash -c "jq -r 'select(.path==\"./sourceatlas/scripts/build.sh\") | .symbols | length' .sourceatlas/sourceatlas.index.jsonl"
    assert_success
    echo "Shell symbols count: $output" >&3
    [ "$output" -gt 0 ]
}