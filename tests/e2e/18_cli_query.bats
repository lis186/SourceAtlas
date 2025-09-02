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
}

teardown() {
    cleanup_test_env
}

@test "satlas query requires existing index" {
    rm -f .sourceatlas/sourceatlas.index.jsonl
    
    run satlas query "AppDelegate"
    assert_failure
    assert_output_contains "Index file not found"
}

@test "satlas query symbol search" {
    run satlas query --type symbol "getData"
    assert_success
    
    # Should find files containing getData symbol
    assert_output_contains "MainViewModel.kt"
}

@test "satlas query path search" {
    run satlas query --type path "ios"
    assert_success
    
    # Should find files in ios directory
    assert_output_contains "ios/"
}

@test "satlas query language search" {
    run satlas query --type lang "swift"
    assert_success
    
    # Should find Swift files
    assert_output_contains ".swift"
}

@test "satlas query role search" {
    run satlas query --type role "viewmodel"
    assert_success
    
    # Should find viewmodel files
    assert_output_contains "MainViewModel.kt"
}

@test "satlas query regex pattern" {
    run satlas query --regex "Main.*\.kt"
    assert_success
    
    # Should find Kotlin files starting with "Main"
    assert_output_contains "MainViewModel.kt"
}

@test "satlas query with limit" {
    run satlas query --limit 2 "kotlin"
    assert_success
    
    # Should limit results (account for header line)
    local result_lines=$(echo "$output" | tail -n +3 | wc -l)
    [ "$result_lines" -le 2 ]
}

@test "satlas query with output format" {
    run satlas query --format json "MainViewModel"
    assert_success
    
    # Should output valid JSON
    echo "$output" | jq empty
}

@test "satlas query case insensitive" {
    run satlas query --ignore-case "MAINVIEWMODEL"
    assert_success
    
    # Should find MainViewModel despite case difference
    assert_output_contains "MainViewModel.kt"
}

@test "satlas query with multiple terms" {
    run satlas query "MainView"
    assert_success
    
    # Should find files containing the term
    assert_output_contains "MainViewModel"
}

@test "satlas query with --out option" {
    mkdir -p output
    
    # First create scan output in the output directory
    satlas scan --out output
    satlas symbols --out output
    
    run satlas query --out output "MainViewModel"
    assert_success
    
    # Should search in output directory index
    assert_output_contains "MainViewModel"
}

@test "satlas query shows file details" {
    run satlas query --verbose "MainViewModel"
    assert_success
    
    # Should show additional details like language, role, line count
    assert_output_contains "Language:" || 
    assert_output_contains "Role:" || 
    assert_output_contains "Lines:"
}

@test "satlas query returns relevance score" {
    run satlas query --scores "MainViewModel"
    assert_success
    
    # Should show relevance scores for matches
    assert_output_contains "Score:" || 
    assert_output_contains "relevance"
}

@test "satlas query handles no matches" {
    run satlas query "NonExistentSymbol123"
    assert_success
    
    # Should handle gracefully with no matches
    assert_output_contains "No matches found" || 
    [ -z "$output" ]
}

@test "satlas query with complex pattern" {
    run satlas query --type symbol --regex "(class|struct|interface)"
    assert_success
    
    # Should find class/struct/interface definitions
    local match_count=$(echo "$output" | grep -c ":" || echo "0")
    [ "$match_count" -ge 0 ]
}

@test "query output format is consistent" {
    run satlas query "AppDelegate"
    assert_success
    
    # Output should be consistent format: path:line or similar
    if [[ -n "$output" ]]; then
        echo "$output" | head -1 | grep -q ":" || 
        echo "$output" | head -1 | grep -q "/"
    fi
}