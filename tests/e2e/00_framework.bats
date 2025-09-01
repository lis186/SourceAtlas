#!/usr/bin/env bats

# Test that bats-core framework is working

@test "bats framework is operational" {
    run echo "bats is working"
    [ "$status" -eq 0 ]
    [ "$output" = "bats is working" ]
}

@test "test helpers can be loaded" {
    # Load test helpers
    load ../helpers
    
    # Verify helper functions are available
    type setup_test_env >/dev/null 2>&1
    type cleanup_test_env >/dev/null 2>&1
    type copy_fixtures >/dev/null 2>&1
}

@test "temporary directory creation works" {
    load ../helpers
    
    setup_test_env
    
    # Verify temp directory was created
    [ -n "${TEST_TEMP_DIR}" ]
    [ -d "${TEST_TEMP_DIR}" ]
    
    # Cleanup
    cleanup_test_env
    
    # Verify cleanup worked
    [ ! -d "${TEST_TEMP_DIR}" ]
}