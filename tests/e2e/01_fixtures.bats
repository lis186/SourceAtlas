#!/usr/bin/env bats

load ../helpers

@test "fixtures directory exists" {
    assert_dir_exists "${BATS_TEST_DIRNAME}/../fixtures/sourceatlas"
}

@test "can copy fixtures to test directory" {
    setup_test_env
    
    copy_fixtures "sourceatlas"
    
    # Verify key fixture files were copied
    assert_file_exists "${TEST_TEMP_DIR}/ios/AppDelegate.swift"
    assert_file_exists "${TEST_TEMP_DIR}/android/MainActivity.kt"
    assert_file_exists "${TEST_TEMP_DIR}/scripts/build.sh"
    assert_file_exists "${TEST_TEMP_DIR}/scripts/test_helper.rb"
    assert_file_exists "${TEST_TEMP_DIR}/scripts/utils.py"
    assert_file_exists "${TEST_TEMP_DIR}/config/app.json"
    assert_file_exists "${TEST_TEMP_DIR}/config/build.gradle"
    assert_file_exists "${TEST_TEMP_DIR}/config/settings.yml"
    
    cleanup_test_env
}

@test "fixtures contain expected language files" {
    local fixture_dir="${BATS_TEST_DIRNAME}/../fixtures/sourceatlas"
    
    # Swift files
    assert_file_exists "${fixture_dir}/ios/AppDelegate.swift"
    assert_file_exists "${fixture_dir}/ios/ViewModel.swift"
    
    # Kotlin files
    assert_file_exists "${fixture_dir}/android/MainActivity.kt"
    assert_file_exists "${fixture_dir}/android/MainViewModel.kt"
    
    # Script files
    assert_file_exists "${fixture_dir}/scripts/build.sh"
    assert_file_exists "${fixture_dir}/scripts/test_helper.rb"
    assert_file_exists "${fixture_dir}/scripts/utils.py"
    
    # Config files
    assert_file_exists "${fixture_dir}/config/app.json"
    assert_file_exists "${fixture_dir}/config/build.gradle"
    assert_file_exists "${fixture_dir}/config/settings.yml"
}

@test "excluded files are present for testing" {
    local fixture_dir="${BATS_TEST_DIRNAME}/../fixtures/sourceatlas"
    
    assert_file_exists "${fixture_dir}/excluded/private_key.p12"
    assert_file_exists "${fixture_dir}/excluded/cert.cer"
}

@test "swift fixtures contain expected symbols" {
    local swift_file="${BATS_TEST_DIRNAME}/../fixtures/sourceatlas/ios/AppDelegate.swift"
    
    assert_file_contains "${swift_file}" "class AppDelegate"
    assert_file_contains "${swift_file}" "func application"
    assert_file_contains "${swift_file}" "@main"
}

@test "kotlin fixtures contain expected symbols" {
    local kotlin_file="${BATS_TEST_DIRNAME}/../fixtures/sourceatlas/android/MainActivity.kt"
    
    assert_file_contains "${kotlin_file}" "class MainActivity"
    assert_file_contains "${kotlin_file}" "@AndroidEntryPoint"
    assert_file_contains "${kotlin_file}" "override fun onCreate"
}