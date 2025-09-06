#!/usr/bin/env bash

# Phase 9 Test Runner
# Executes comprehensive tests for sophisticated architectural enhancements

set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
PHASE9_TESTS=(
    "117_phase9_streaming_fallback.bats"
    "118_phase9_checkpoint_restore.bats" 
    "119_phase9_ema_monitoring.bats"
    "121_phase9_end_to_end.bats"
)

# Statistics
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

echo -e "${BLUE}🧪 Phase 9 Sophisticated Architecture Test Suite${NC}"
echo "=============================================="
echo

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check for bats
    if ! command -v bats >/dev/null 2>&1; then
        echo -e "${RED}❌ bats-core not found. Please install bats for testing.${NC}"
        exit 1
    fi
    
    # Check for required tools
    local missing_tools=()
    local tools=("awk" "jq" "timeout")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Optional tools missing: ${missing_tools[*]}${NC}"
        echo "   Tests will use fallbacks where possible"
    else
        echo -e "${GREEN}✅ All prerequisites available${NC}"
    fi
    
    # Verify Phase 9 files exist
    local missing_files=()
    local files=("lib/batch_optimize.awk" "lib/parallel_optimize.sh" "lib/command_validation.sh")
    
    for file in "${files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Phase 9 files missing: ${missing_files[*]}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Phase 9 implementation files verified${NC}"
    echo
}

# Run individual test suite
run_test_suite() {
    local test_file="$1"
    local test_path="$SCRIPT_DIR/e2e/$test_file"
    
    if [[ ! -f "$test_path" ]]; then
        echo -e "${RED}❌ Test file not found: $test_file${NC}"
        ((FAILED_TESTS++))
        return 1
    fi
    
    echo -e "${BLUE}🔬 Running: $test_file${NC}"
    
    # Run bats with timeout
    local output
    local exit_code=0
    
    if output=$(timeout 300 bats --formatter pretty "$test_path" 2>&1); then
        # Parse bats output
        local tests_in_file
        tests_in_file=$(echo "$output" | grep -c "✓\|✗" || echo "0")
        local passed_in_file  
        passed_in_file=$(echo "$output" | grep -c "✓" || echo "0")
        local failed_in_file
        failed_in_file=$(echo "$output" | grep -c "✗" || echo "0")
        
        ((TOTAL_TESTS += tests_in_file))
        ((PASSED_TESTS += passed_in_file))
        ((FAILED_TESTS += failed_in_file))
        
        if [[ $failed_in_file -eq 0 ]]; then
            echo -e "${GREEN}✅ $test_file: $passed_in_file/$tests_in_file tests passed${NC}"
        else
            echo -e "${RED}❌ $test_file: $failed_in_file/$tests_in_file tests failed${NC}"
            # Show failed test details
            echo "$output" | grep -A 5 "✗" || true
        fi
    else
        exit_code=$?
        echo -e "${RED}❌ $test_file: Test suite failed to run (exit code: $exit_code)${NC}"
        
        if [[ $exit_code -eq 124 ]]; then
            echo -e "${YELLOW}⏱️  Test suite timed out after 5 minutes${NC}"
        fi
        
        # Show error output
        echo "$output" | tail -10 || true
        ((FAILED_TESTS++))
        return 1
    fi
    
    echo
}

# Generate test report
generate_report() {
    echo -e "${BLUE}📊 Phase 9 Test Results${NC}"
    echo "======================"
    echo -e "Total Tests: ${TOTAL_TESTS}"
    echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
    
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
    else
        echo -e "Failed: ${FAILED_TESTS}"
    fi
    
    if [[ $SKIPPED_TESTS -gt 0 ]]; then
        echo -e "${YELLOW}Skipped: ${SKIPPED_TESTS}${NC}"
    fi
    
    echo
    
    # Calculate success rate
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        
        if [[ $success_rate -ge 90 ]]; then
            echo -e "${GREEN}🎉 Success Rate: ${success_rate}% - Excellent!${NC}"
        elif [[ $success_rate -ge 75 ]]; then
            echo -e "${YELLOW}⚠️  Success Rate: ${success_rate}% - Good${NC}"
        else
            echo -e "${RED}💥 Success Rate: ${success_rate}% - Needs Attention${NC}"
        fi
    fi
    
    echo
    
    # Feature summary
    echo -e "${BLUE}🎯 Phase 9 Features Tested:${NC}"
    echo "• 🧠 Automatic Streaming Mode Fallback"
    echo "• 🔄 Checkpoint/Restore System"  
    echo "• ⚡ EMA-based Performance Monitoring"
    echo "• 🚀 End-to-End Integration"
    echo
}

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    check_prerequisites
    
    echo -e "${BLUE}🏃 Running Phase 9 Test Suites${NC}"
    echo "=============================="
    echo
    
    local start_time
    start_time=$(date +%s)
    
    # Run each test suite
    for test_file in "${PHASE9_TESTS[@]}"; do
        run_test_suite "$test_file"
    done
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo -e "${BLUE}⏱️  Total Test Duration: ${duration}s${NC}"
    echo
    
    generate_report
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎊 All Phase 9 tests passed! Enterprise architecture validated.${NC}"
        exit 0
    else
        echo -e "${RED}💥 Some Phase 9 tests failed. Please review implementation.${NC}"
        exit 1
    fi
}

# Handle script arguments
case "${1:-run}" in
    "run")
        main
        ;;
    "help"|"--help"|"-h")
        echo "Phase 9 Test Runner"
        echo
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  run     Run all Phase 9 tests (default)"
        echo "  help    Show this help message"
        echo
        echo "Environment Variables:"
        echo "  BATS_FORMATTER    Set bats formatter (default: pretty)"
        echo "  TEST_TIMEOUT      Test timeout in seconds (default: 300)"
        echo
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac