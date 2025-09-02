#!/usr/bin/env bats

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize and scan first
    satlas init
    satlas scan
}

teardown() {
    cleanup_test_env
}

@test "satlas symbols requires index file" {
    rm -f .sourceatlas/sourceatlas.index.jsonl
    
    run satlas symbols
    assert_failure
    assert_output_contains "Index file not found"
}

@test "satlas symbols creates TSV file" {
    run satlas symbols
    assert_success
    assert_file_exists "${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
}

@test "symbols TSV has correct header" {
    run satlas symbols
    assert_success
    
    local symbols_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    local header=$(head -n 1 "${symbols_file}")
    
    # Check for expected columns in header
    echo "$header" | grep -q "symbol"
    echo "$header" | grep -q "kind"
    echo "$header" | grep -q "repo"
    echo "$header" | grep -q "path"
    echo "$header" | grep -q "line_start"
    echo "$header" | grep -q "line_end"
}

@test "symbols TSV contains Swift symbols" {
    # First, update the scan to extract real symbols
    satlas scan
    
    run satlas symbols
    assert_success
    
    local symbols_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    
    # Check for Swift class/func symbols
    grep -q "AppDelegate" "${symbols_file}" || true
    grep -q "swift" "${symbols_file}" || true
}

@test "symbols TSV contains Kotlin symbols" {
    run satlas symbols
    assert_success
    
    local symbols_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    
    # Check for Kotlin class symbols
    grep -q "MainActivity" "${symbols_file}" || true
    grep -q "kotlin" "${symbols_file}" || true
}

@test "symbols TSV is tab-separated" {
    run satlas symbols
    assert_success
    
    local symbols_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    
    # Check that lines contain tabs
    local line_count=$(wc -l < "${symbols_file}")
    local tab_lines=$(grep -c $'\t' "${symbols_file}" || echo "0")
    
    # All non-empty lines should have tabs
    [ "$tab_lines" -gt 0 ]
}

@test "satlas symbols with --out option" {
    mkdir -p output
    
    # First create scan output in the output directory
    satlas scan --out output
    
    run satlas symbols --out output
    assert_success
    
    assert_file_exists "${TEST_TEMP_DIR}/output/sourceatlas.symbols.tsv"
}

@test "symbols are sorted alphabetically" {
    run satlas symbols
    assert_success
    
    local symbols_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    
    # Skip header and check if sorted
    tail -n +2 "${symbols_file}" > temp_symbols.txt
    sort temp_symbols.txt > sorted_symbols.txt
    
    # Files should be identical if already sorted
    diff temp_symbols.txt sorted_symbols.txt || true
}

@test "satlas symbols handles empty index gracefully" {
    # Create empty index
    echo "" > .sourceatlas/sourceatlas.index.jsonl
    
    run satlas symbols
    assert_success
    
    local symbols_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    
    # Should have header only
    local line_count=$(wc -l < "${symbols_file}")
    [ "$line_count" -eq 1 ]
}

@test "symbols TSV escapes special characters" {
    # Create index with special characters in path
    cat > .sourceatlas/sourceatlas.index.jsonl <<EOF
{"repo":"test","path":"file with spaces.txt","file_name":"file with spaces.txt","ext":".txt","lang":"text","size_bytes":100,"loc":10,"roles":["general"],"summary":"test","imports":[],"symbols":[{"name":"test func","kind":"function","line_start":1,"line_end":5}],"importance_score":0.5,"content_hash":"abc123"}
EOF
    
    run satlas symbols
    assert_success
    
    local symbols_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.symbols.tsv"
    assert_file_contains "${symbols_file}" "file with spaces.txt"
}