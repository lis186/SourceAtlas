#!/bin/bash
# Parallel test execution script implementing optimization strategy from MIGRATION_GUIDE.md

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 SourceAtlas Parallel Test Execution${NC}"
echo "======================================"

# Configuration
export SATLAS_TEST_CACHE_DIR="${SATLAS_TEST_CACHE_DIR:-/tmp/satlas-test-cache-$$}"
export BATS_JOBS="${BATS_JOBS:-4}"

# Track start time
SCRIPT_START_TIME=$(date +%s)

# Cleanup function
cleanup_on_exit() {
    local exit_code=$?
    echo ""
    echo -e "${YELLOW}🧹 Cleaning up test environment...${NC}"
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Cleanup shared cache
    if [[ -d "$SATLAS_TEST_CACHE_DIR" ]]; then
        rm -rf "$SATLAS_TEST_CACHE_DIR" 2>/dev/null || true
    fi
    
    # Report total time
    local script_end_time=$(date +%s)
    local total_duration=$((script_end_time - SCRIPT_START_TIME))
    echo -e "${BLUE}⏱️  Total execution time: ${total_duration}s${NC}"
    
    exit $exit_code
}

# Set trap for cleanup
trap cleanup_on_exit EXIT INT TERM

# Validate environment
echo -e "${YELLOW}🔍 Validating test environment...${NC}"

if ! command -v bats >/dev/null 2>&1; then
    echo -e "${RED}❌ bats not found. Please install bats-core.${NC}" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}❌ jq not found. Please install jq.${NC}" >&2
    exit 1
fi

if [[ ! -x "bin/satlas" ]]; then
    echo -e "${RED}❌ bin/satlas not executable${NC}" >&2
    exit 1
fi

echo -e "${GREEN}✅ Environment validated${NC}"

# Initialize shared cache
echo -e "${YELLOW}🏗️  Initializing shared test cache...${NC}"
mkdir -p "$SATLAS_TEST_CACHE_DIR"
echo "initialized:$(date +%s)" > "$SATLAS_TEST_CACHE_DIR/.cache_metadata"

# Define test groups based on MIGRATION_GUIDE strategy
declare -a READ_ONLY_TESTS=(
    "tests/e2e/18_cli_query.bats"
    "tests/e2e/19_cli_segment.bats"
    "tests/e2e/20_cli_export_dsl.bats" 
    "tests/e2e/22_cli_verify.bats"
    "tests/e2e/phase2_swift_symbols.bats"
    "tests/e2e/phase2_kotlin_symbols.bats"
    "tests/e2e/phase2_objc_symbols.bats"
    "tests/e2e/phase2_other_languages.bats"
)

declare -a MODIFICATION_TESTS=(
    "tests/e2e/17_cli_delta.bats"
    "tests/e2e/21_cli_clean.bats"
    "tests/e2e/30_phase3_shard_limits.bats"
    "tests/e2e/31_phase3_change_detection.bats"
)

declare -a INDEPENDENT_TESTS=(
    "tests/e2e/00_framework.bats"
    "tests/e2e/01_fixtures.bats"
    "tests/e2e/10_cli_version.bats"
    "tests/e2e/11_cli_init.bats"
    "tests/e2e/12_cli_scan.bats"
    "tests/e2e/13_cli_symbols.bats"
    "tests/e2e/14_cli_stats.bats"
    "tests/e2e/15_cli_manifest.bats"
    "tests/e2e/16_cli_shard.bats"
    "tests/e2e/22_cli_run.bats"
)

declare -a PERFORMANCE_TESTS=(
    "tests/e2e/40_phase4_progressive_retrieval.bats"
    "tests/e2e/41_phase4_rate_limiting.bats"
    "tests/e2e/50_phase5_exclude_patterns.bats"
    "tests/e2e/51_phase5_sensitive_files.bats"
    "tests/e2e/60_phase6_index_performance.bats"
    "tests/e2e/61_phase6_query_performance.bats"
)

# Function to run test group
run_test_group() {
    local group_name="$1"
    local jobs="$2"
    shift 2
    local tests=("$@")
    
    echo -e "${BLUE}🧪 Running $group_name tests (${#tests[@]} tests, $jobs jobs)...${NC}"
    
    local start_time=$(date +%s)
    local result=0
    
    # Run tests with specified parallelism
    if bats --jobs "$jobs" --tap "${tests[@]}"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✅ $group_name completed successfully in ${duration}s${NC}"
    else
        result=1
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}❌ $group_name failed after ${duration}s${NC}"
    fi
    
    return $result
}

# Main execution with parallel groups
echo ""
echo -e "${BLUE}🎯 Starting parallel test execution...${NC}"
echo ""

# Track results
declare -a RESULTS=()
declare -a PIDS=()

# Start test groups in parallel
(
    echo -e "${YELLOW}📖 Group A: Read-Only Tests (shared cache, 4 jobs)${NC}"
    if run_test_group "read-only" 4 "${READ_ONLY_TESTS[@]}"; then
        echo "read-only:success" > "$SATLAS_TEST_CACHE_DIR/group_a_result"
    else
        echo "read-only:failure" > "$SATLAS_TEST_CACHE_DIR/group_a_result" 
    fi
) &
PIDS+=($!)

(
    echo -e "${YELLOW}🔧 Group B: Modification Tests (isolated, 2 jobs)${NC}"
    if run_test_group "modification" 2 "${MODIFICATION_TESTS[@]}"; then
        echo "modification:success" > "$SATLAS_TEST_CACHE_DIR/group_b_result"
    else
        echo "modification:failure" > "$SATLAS_TEST_CACHE_DIR/group_b_result"
    fi
) &
PIDS+=($!)

(
    echo -e "${YELLOW}🎯 Group C: Independent Tests (maximum parallelism, 4 jobs)${NC}"
    if run_test_group "independent" 4 "${INDEPENDENT_TESTS[@]}"; then
        echo "independent:success" > "$SATLAS_TEST_CACHE_DIR/group_c_result"
    else
        echo "independent:failure" > "$SATLAS_TEST_CACHE_DIR/group_c_result"
    fi
) &
PIDS+=($!)

(
    echo -e "${YELLOW}🚀 Group D: Performance Tests (careful resource management, 2 jobs)${NC}"
    if run_test_group "performance" 2 "${PERFORMANCE_TESTS[@]}"; then
        echo "performance:success" > "$SATLAS_TEST_CACHE_DIR/group_d_result"
    else
        echo "performance:failure" > "$SATLAS_TEST_CACHE_DIR/group_d_result"
    fi
) &
PIDS+=($!)

echo -e "${BLUE}⏳ Waiting for all test groups to complete...${NC}"

# Wait for all background jobs
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

echo ""
echo -e "${BLUE}📊 Test Results Summary${NC}"
echo "======================="

# Collect and analyze results
declare -a FAILED_GROUPS=()
declare -a SUCCESSFUL_GROUPS=()

for result_file in "$SATLAS_TEST_CACHE_DIR"/group_*_result; do
    if [[ -f "$result_file" ]]; then
        local result_content="$(cat "$result_file")"
        local group_name="${result_content%:*}"
        local status="${result_content#*:}"
        
        if [[ "$status" == "success" ]]; then
            SUCCESSFUL_GROUPS+=("$group_name")
            echo -e "${GREEN}✅ $group_name: PASSED${NC}"
        else
            FAILED_GROUPS+=("$group_name")
            echo -e "${RED}❌ $group_name: FAILED${NC}"
        fi
    fi
done

echo ""

# Final summary
if [[ ${#FAILED_GROUPS[@]} -eq 0 ]]; then
    echo -e "${GREEN}🎉 All test groups passed! (${#SUCCESSFUL_GROUPS[@]}/4)${NC}"
    
    # Display performance metrics if available
    if [[ -f "$SATLAS_TEST_CACHE_DIR/benchmarks.log" ]]; then
        echo ""
        echo -e "${BLUE}📈 Performance Benchmarks:${NC}"
        cat "$SATLAS_TEST_CACHE_DIR/benchmarks.log" | tail -5
    fi
    
    exit 0
else
    echo -e "${RED}💥 ${#FAILED_GROUPS[@]} test group(s) failed: ${FAILED_GROUPS[*]}${NC}"
    echo -e "${GREEN}✅ ${#SUCCESSFUL_GROUPS[@]} test group(s) passed: ${SUCCESSFUL_GROUPS[*]}${NC}"
    exit 1
fi