#!/usr/bin/env bats

# Phase 2 Step 2.1: Swift symbol extraction tests
# Tests extraction of class/struct/enum/protocol/extension/actor/func with line numbers and visibility

load '../helpers'

setup() {
    setup_test_env
    copy_fixtures "sourceatlas"
    cd "${TEST_TEMP_DIR}"
    # Initialize sourceatlas
    satlas init
}

teardown() {
    cleanup_test_env
}

@test "Swift symbol extraction - protocol with correct name and line numbers" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Check that ViewModel.swift was indexed
    grep -q "ios/ViewModel.swift" .sourceatlas/sourceatlas.index.jsonl
    
    # Extract the symbols for ViewModel.swift (note: path includes ./ prefix)
    symbols=$(jq -r 'select(.path == "./ios/ViewModel.swift") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that protocol ViewModelProtocol is extracted
    protocol_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "protocol" and .name == "ViewModelProtocol")')
    [ -n "$protocol_symbol" ]
    
    # Check line number (should be 4 based on fixture)
    line_start=$(echo "$protocol_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 4 ]
}

@test "Swift symbol extraction - class with correct name and visibility" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for ViewModel.swift
    symbols=$(jq -r 'select(.path == "./ios/ViewModel.swift") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that class MainViewModel is extracted
    class_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "class" and .name == "MainViewModel")')
    [ -n "$class_symbol" ]
    
    # Check line number (should be 9 based on fixture)
    line_start=$(echo "$class_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 9 ]
    
    # Check visibility (should be internal by default)
    visibility=$(echo "$class_symbol" | jq -r '.visibility')
    [ "$visibility" = "internal" ]
}

@test "Swift symbol extraction - struct with correct name" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for ViewModel.swift
    symbols=$(jq -r 'select(.path == "./ios/ViewModel.swift") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that struct DataRepository is extracted
    struct_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "struct" and .name == "DataRepository")')
    [ -n "$struct_symbol" ]
    
    # Check line number (should be 28 based on fixture)
    line_start=$(echo "$struct_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 28 ]
}

@test "Swift symbol extraction - function with correct name" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for ViewModel.swift
    symbols=$(jq -r 'select(.path == "./ios/ViewModel.swift") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that func loadData is extracted
    func_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "func" and .name == "loadData")')
    [ -n "$func_symbol" ]
}

@test "Swift symbol extraction - AppDelegate class with @main visibility detection" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for AppDelegate.swift
    symbols=$(jq -r 'select(.path == "./ios/AppDelegate.swift") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that class AppDelegate is extracted
    class_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "class" and .name == "AppDelegate")')
    [ -n "$class_symbol" ]
    
    # Check line number (should be 5 based on fixture - @main is on line 4, class is on line 5)
    line_start=$(echo "$class_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 5 ]
}

@test "Swift symbol extraction - function visibility detection (public/private/internal)" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for AppDelegate.swift
    symbols=$(jq -r 'select(.path == "./ios/AppDelegate.swift") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check for private function setupDependencies
    private_func=$(echo "$symbols" | jq -r '.[] | select(.kind == "func" and .name == "setupDependencies" and .visibility == "private")')
    [ -n "$private_func" ]
    
    # Check for internal function configureAppearance
    internal_func=$(echo "$symbols" | jq -r '.[] | select(.kind == "func" and .name == "configureAppearance" and .visibility == "internal")')
    [ -n "$internal_func" ]
    
    # Check for public function applicationDidBecomeActive
    public_func=$(echo "$symbols" | jq -r '.[] | select(.kind == "func" and .name == "applicationDidBecomeActive" and .visibility == "public")')
    [ -n "$public_func" ]
}

@test "Swift symbol extraction - imports are correctly detected" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Check imports for ViewModel.swift
    imports=$(jq -r 'select(.path == "./ios/ViewModel.swift") | .imports[]' .sourceatlas/sourceatlas.index.jsonl)
    echo "$imports" | grep -q "Foundation"
    echo "$imports" | grep -q "Combine"
    
    # Check imports for AppDelegate.swift
    imports=$(jq -r 'select(.path == "./ios/AppDelegate.swift") | .imports[]' .sourceatlas/sourceatlas.index.jsonl)
    echo "$imports" | grep -q "UIKit"
    echo "$imports" | grep -q "Combine"
}