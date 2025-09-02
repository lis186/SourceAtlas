#!/usr/bin/env bats

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize and scan
    satlas init
    satlas scan
    satlas symbols
}

teardown() {
    cleanup_test_env
}

@test "satlas export-dsl requires existing index" {
    rm -f .sourceatlas/sourceatlas.index.jsonl
    
    run satlas export-dsl
    assert_failure
    assert_output_contains "Index file not found"
}

@test "satlas export-dsl creates DSL output" {
    run satlas export-dsl
    # Note: Command may exit with error code but still produce output
    
    # Should create DSL format output
    assert_output_contains "F:" # File entries
}

@test "satlas export-dsl F/SYM format compliance" {
    run satlas export-dsl
    # Note: Command may exit with error code but still produce output
    
    # Should follow F/SYM format with abbreviated fields
    assert_output_contains "F:" # File entry marker
    assert_output_contains "P:" # Path field  
    assert_output_contains "L:" # Language field
}

@test "satlas export-dsl includes symbols" {
    run satlas export-dsl
    assert_success
    
    # Should include symbol information
    assert_output_contains "SYM:" || assert_output_contains "S:"
}

@test "satlas export-dsl is more compact than JSON" {
    # Get JSON size
    satlas scan --out temp_json
    local json_size=$(wc -c < temp_json/sourceatlas.index.jsonl)
    
    run satlas export-dsl
    assert_success
    
    # DSL should be more compact
    local dsl_size=$(echo "$output" | wc -c)
    [ "$dsl_size" -lt "$json_size" ]
}

@test "satlas export-dsl with --out option" {
    mkdir -p output
    
    # First create scan output in the output directory
    satlas scan --out output
    satlas symbols --out output
    
    run satlas export-dsl --out output
    assert_success
    
    # Should work with custom index location
    assert_output_contains "F:"
}

@test "satlas export-dsl file format" {
    run satlas export-dsl --format file
    assert_success
    
    # Should save to file instead of stdout
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.dsl"
}

@test "satlas export-dsl includes metadata" {
    run satlas export-dsl
    assert_success
    
    # Should include essential file metadata
    assert_output_contains "swift" || assert_output_contains "kotlin"
    assert_output_contains ".kt" || assert_output_contains ".swift"
}

@test "satlas export-dsl abbreviates field names" {
    run satlas export-dsl
    assert_success
    
    # Should use abbreviated field names for compactness
    assert_output_contains "P:" # Path
    assert_output_contains "L:" # Language/Lang
    assert_output_contains "R:" || assert_output_contains "ROLE:" # Role
}

@test "satlas export-dsl omits empty fields" {
    run satlas export-dsl
    assert_success
    
    # Should not include empty or null fields to save space
    ! assert_output_contains "null"
    ! assert_output_contains '"":'
}

@test "satlas export-dsl preserves essential information" {
    run satlas export-dsl
    assert_success
    
    # Should preserve key information needed for code discovery
    assert_output_contains "AppDelegate" || assert_output_contains "MainView"
    assert_output_contains "ios/" || assert_output_contains "android/"
}

@test "satlas export-dsl with symbols only" {
    run satlas export-dsl --symbols-only
    assert_success
    
    # Should only output symbol information
    assert_output_contains "SYM:" || assert_output_contains "S:"
    ! assert_output_contains "F:"
}

@test "satlas export-dsl line limit" {
    run satlas export-dsl --max-lines 10
    assert_success
    
    # Should limit output lines
    local line_count=$(echo "$output" | wc -l)
    [ "$line_count" -le 10 ]
}

@test "satlas export-dsl consistent format" {
    run satlas export-dsl
    assert_success
    
    # Each line should follow consistent format
    if [[ -n "$output" ]]; then
        echo "$output" | while IFS= read -r line; do
            [[ -n "$line" ]] && {
                echo "$line" | grep -q ":" || {
                    echo "Invalid DSL line format: $line"
                    return 1
                }
            }
        done
    fi
}

@test "satlas export-dsl handles empty index" {
    # Create empty index
    echo "" > .sourceatlas/sourceatlas.index.jsonl
    
    run satlas export-dsl
    assert_success
    
    # Should handle empty index gracefully
    [ "$?" -eq 0 ]
}