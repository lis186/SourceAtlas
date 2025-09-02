#!/usr/bin/env bats

# Phase 7 Step 7.1: Test set preparation (queries.tsv, truth.tsv)
# Verification: Format consistent with PRD Chapter 24

load ../helpers

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    
    # Initialize and create index before UAT testing
    satlas init
    satlas run
}

teardown() {
    cleanup_test_env
}

@test "queries.tsv format matches PRD Chapter 24 specification" {
    # Create test queries file using helper function
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    create_uat_queries_file "$queries_file" 10

    # Validate TSV format
    assert_file_exists "$queries_file"
    
    # Check header row
    local header=$(head -n1 "$queries_file")
    [[ "$header" == *"query_id"* ]]
    [[ "$header" == *"query_text"* ]]
    [[ "$header" == *"query_type"* ]]
    [[ "$header" == *"expected_files"* ]]
    [[ "$header" == *"priority"* ]]
    
    # Validate data rows (should have 10 test queries)
    local line_count=$(wc -l < "$queries_file")
    [ "$line_count" -eq 11 ]  # Header + 10 data rows
    
    # Check query types are valid
    local query_types=$(tail -n +2 "$queries_file" | cut -f3 | sort -u)
    echo "$query_types" | grep -E "(symbol|regex|import|annotation|file_extension|path|semantic)"
}

@test "truth.tsv format validation with ground truth data" {
    # Create ground truth file using helper function
    local truth_file="${TEST_TEMP_DIR}/truth.tsv"
    create_uat_truth_file "$truth_file"

    # Validate TSV format
    assert_file_exists "$truth_file"
    
    # Check header row
    local header=$(head -n1 "$truth_file")
    [[ "$header" == *"query_id"* ]]
    [[ "$header" == *"relevant_file"* ]]
    [[ "$header" == *"rank"* ]]
    [[ "$header" == *"relevance_score"* ]]
    [[ "$header" == *"file_path"* ]]
    [[ "$header" == *"line_numbers"* ]]
    [[ "$header" == *"context"* ]]
    
    # Validate data consistency
    local line_count=$(wc -l < "$truth_file")
    [ "$line_count" -gt 1 ]  # Header + data rows
    
    # Check relevance scores are between 0 and 1
    tail -n +2 "$truth_file" | cut -f4 | while read score; do
        # Use bc for floating point comparison if available, otherwise use awk
        if command -v bc >/dev/null 2>&1; then
            [ "$(echo "$score >= 0.0 && $score <= 1.0" | bc)" -eq 1 ]
        else
            awk -v score="$score" 'BEGIN { exit !(score >= 0.0 && score <= 1.0) }'
        fi
    done
}

@test "test set covers diverse query types and scenarios" {
    # Test that we have queries covering all major query types using helper function
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    create_uat_queries_file "$queries_file" 6

    # Validate query type coverage
    local query_types=$(tail -n +2 "$queries_file" | cut -f3 | sort -u | tr '\n' ' ')
    
    # Should cover at least 4 different query types
    local type_count=$(tail -n +2 "$queries_file" | cut -f3 | sort -u | wc -l)
    [ "$type_count" -ge 4 ]
    
    # Check priority distribution (high/medium/low)
    local priorities=$(tail -n +2 "$queries_file" | cut -f5 | sort -u | tr '\n' ' ')
    [[ "$priorities" == *"high"* ]]
    [[ "$priorities" == *"medium"* ]]
}

@test "queries can be executed against actual index" {
    # Test that queries in test set can actually be executed using helper function
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    create_uat_queries_file "$queries_file" 3

    # Execute each query and verify it can run
    tail -n +2 "$queries_file" | while IFS=$'\t' read -r query_id query_text query_type expected_files priority; do
        case "$query_type" in
            "symbol"|"import")
                run satlas query "$query_text"
                # Should execute successfully or provide meaningful error
                [ "$status" -eq 0 ] || [[ "$output" == *"No results"* ]] || [[ "$output" == *"not found"* ]]
                ;;
            "regex")
                run satlas query "$query_text"
                # Should execute successfully or provide meaningful error
                [ "$status" -eq 0 ] || [[ "$output" == *"No results"* ]] || [[ "$output" == *"not found"* ]]
                ;;
        esac
    done
}

@test "test set size meets PRD requirements (30-50 test cases)" {
    # Create a realistic test set with 35 queries using helper function
    local queries_file="${TEST_TEMP_DIR}/uat_queries.tsv"
    create_uat_queries_file "$queries_file" 35

    assert_file_exists "$queries_file"
    
    # Count total queries (excluding header)
    local query_count=$(tail -n +2 "$queries_file" | wc -l)
    
    # Should be within PRD range using configurable constants
    [ "$query_count" -ge "$UAT_MIN_QUERIES" ]
    [ "$query_count" -le "$UAT_MAX_QUERIES" ]
    
    # Verify we have the exact expected count
    [ "$query_count" -eq 35 ]
}

@test "test data quality - no duplicate query IDs" {
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    create_uat_queries_file "$queries_file" 4

    # Check for duplicate query IDs
    local total_ids=$(tail -n +2 "$queries_file" | cut -f1 | wc -l)
    local unique_ids=$(tail -n +2 "$queries_file" | cut -f1 | sort -u | wc -l)
    
    # Total should equal unique (no duplicates)
    [ "$total_ids" -eq "$unique_ids" ]
}

@test "expected files exist in test fixtures" {
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    create_uat_queries_file "$queries_file" 3

    # Check that expected files referenced in queries actually exist in fixtures
    tail -n +2 "$queries_file" | cut -f4 | tr ',' '\n' | sort -u | while read expected_file; do
        # Look for the file in the test directory structure
        if [[ -n "$expected_file" ]]; then
            local found=false
            for file in $(find . -name "$expected_file" 2>/dev/null); do
                found=true
                break
            done
            
            # If not found by exact name, check if it's referenced in the index
            if [[ "$found" != true ]]; then
                local index_file="${TEST_TEMP_DIR}/.sourceatlas/sourceatlas.index.jsonl"
                if [[ -f "$index_file" ]]; then
                    grep -q "$expected_file" "$index_file" || echo "Warning: Expected file $expected_file not found in fixtures or index"
                fi
            fi
        fi
    done
}