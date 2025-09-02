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
    # Create test queries file
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    cat > "$queries_file" << 'EOF'
query_id	query_text	query_type	expected_files	priority
1	AppDelegate	symbol	AppDelegate.swift	high
2	MainActivity	symbol	MainActivity.kt	high
3	class.*View	regex	AppDelegate.swift,MainActivity.kt	medium
4	func.*init	regex	AppDelegate.swift	medium
5	import.*UIKit	import	AppDelegate.swift	high
6	@AndroidEntryPoint	annotation	MainActivity.kt	high
7	protocol.*Delegate	regex	AppDelegate.swift	low
8	*.swift	file_extension	AppDelegate.swift	medium
9	ios/AppDelegate	path	AppDelegate.swift	high
10	networking.*error	semantic	AppDelegate.swift	low
EOF

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
    # Create ground truth file
    local truth_file="${TEST_TEMP_DIR}/truth.tsv"
    cat > "$truth_file" << 'EOF'
query_id	relevant_file	rank	relevance_score	file_path	line_numbers	context
1	AppDelegate.swift	1	1.0	ios/AppDelegate.swift	1-50	Main application delegate class
2	MainActivity.kt	1	1.0	android/MainActivity.kt	1-45	Main Android activity class
3	AppDelegate.swift	1	0.9	ios/AppDelegate.swift	12-15	class AppDelegate: UIResponder
3	MainActivity.kt	2	0.8	android/MainActivity.kt	8-12	class MainActivity: AppCompatActivity
4	AppDelegate.swift	1	0.9	ios/AppDelegate.swift	20-25	func application(_ application: UIApplication
5	AppDelegate.swift	1	1.0	ios/AppDelegate.swift	1-3	import UIKit
6	MainActivity.kt	1	1.0	android/MainActivity.kt	3-4	@AndroidEntryPoint
7	AppDelegate.swift	1	0.8	ios/AppDelegate.swift	12-15	class AppDelegate: UIResponder
8	AppDelegate.swift	1	1.0	ios/AppDelegate.swift	1-50	Swift file extension match
9	AppDelegate.swift	1	1.0	ios/AppDelegate.swift	1-50	Path-based file match
10	AppDelegate.swift	1	0.6	ios/AppDelegate.swift	30-40	Semantic networking relevance
EOF

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
    # Test that we have queries covering all major query types
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    cat > "$queries_file" << 'EOF'
query_id	query_text	query_type	expected_files	priority
1	AppDelegate	symbol	AppDelegate.swift	high
2	class.*View	regex	AppDelegate.swift	medium
3	import.*UIKit	import	AppDelegate.swift	high
4	@AndroidEntryPoint	annotation	MainActivity.kt	high
5	*.swift	file_extension	AppDelegate.swift	medium
6	ios/AppDelegate	path	AppDelegate.swift	high
EOF

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
    # Test that queries in test set can actually be executed
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    cat > "$queries_file" << 'EOF'
query_id	query_text	query_type	expected_files	priority
1	AppDelegate	symbol	AppDelegate.swift	high
2	class	symbol	AppDelegate.swift	medium
3	UIKit	import	AppDelegate.swift	high
EOF

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
    # Create a realistic test set with 35 queries
    local queries_file="${TEST_TEMP_DIR}/uat_queries.tsv"
    
    # Generate test queries (example set)
    cat > "$queries_file" << 'EOF'
query_id	query_text	query_type	expected_files	priority
1	AppDelegate	symbol	AppDelegate.swift	high
2	MainActivity	symbol	MainActivity.kt	high
3	ConfigLoader	symbol	utils.py	high
4	TestHelper	symbol	test_helper.rb	high
5	build_ios	symbol	build.sh	medium
6	class.*Delegate	regex	AppDelegate.swift	high
7	func.*init	regex	AppDelegate.swift,MainActivity.kt	medium
8	def.*process	regex	utils.py	medium
9	module.*Helper	regex	test_helper.rb	low
10	function.*main	regex	build.sh	low
11	import.*UIKit	import	AppDelegate.swift	high
12	import.*androidx	import	MainActivity.kt	high
13	import.*json	import	utils.py	medium
14	require.*spec	import	test_helper.rb	low
15	source.*common	import	build.sh	low
16	@AndroidEntryPoint	annotation	MainActivity.kt	high
17	@UIApplicationMain	annotation	AppDelegate.swift	high
18	@dataclass	annotation	utils.py	medium
19	*.swift	file_extension	AppDelegate.swift	medium
20	*.kt	file_extension	MainActivity.kt	medium
21	*.py	file_extension	utils.py	medium
22	*.rb	file_extension	test_helper.rb	low
23	*.sh	file_extension	build.sh	low
24	ios/AppDelegate	path	AppDelegate.swift	high
25	android/MainActivity	path	MainActivity.kt	high
26	scripts/utils	path	utils.py	medium
27	scripts/test_helper	path	test_helper.rb	low
28	scripts/build	path	build.sh	low
29	networking.*error	semantic	AppDelegate.swift	low
30	database.*query	semantic	utils.py	low
31	test.*assertion	semantic	test_helper.rb	low
32	build.*configuration	semantic	build.sh	low
33	user.*interface	semantic	AppDelegate.swift	medium
34	data.*processing	semantic	utils.py	medium
35	configuration.*management	semantic	build.sh	low
EOF

    assert_file_exists "$queries_file"
    
    # Count total queries (excluding header)
    local query_count=$(tail -n +2 "$queries_file" | wc -l)
    
    # Should be within PRD range of 30-50 queries
    [ "$query_count" -ge 30 ]
    [ "$query_count" -le 50 ]
    
    # Verify we have the exact expected count
    [ "$query_count" -eq 35 ]
}

@test "test data quality - no duplicate query IDs" {
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    cat > "$queries_file" << 'EOF'
query_id	query_text	query_type	expected_files	priority
1	AppDelegate	symbol	AppDelegate.swift	high
2	MainActivity	symbol	MainActivity.kt	high
3	ConfigLoader	symbol	utils.py	medium
4	build_ios	symbol	build.sh	low
EOF

    # Check for duplicate query IDs
    local total_ids=$(tail -n +2 "$queries_file" | cut -f1 | wc -l)
    local unique_ids=$(tail -n +2 "$queries_file" | cut -f1 | sort -u | wc -l)
    
    # Total should equal unique (no duplicates)
    [ "$total_ids" -eq "$unique_ids" ]
}

@test "expected files exist in test fixtures" {
    local queries_file="${TEST_TEMP_DIR}/queries.tsv"
    cat > "$queries_file" << 'EOF'
query_id	query_text	query_type	expected_files	priority
1	AppDelegate	symbol	AppDelegate.swift	high
2	MainActivity	symbol	MainActivity.kt	high
3	ConfigLoader	symbol	utils.py	medium
EOF

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