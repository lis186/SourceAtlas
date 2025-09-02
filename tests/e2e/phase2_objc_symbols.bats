#!/usr/bin/env bats

# Phase 2 Step 2.2: Objective-C symbol extraction tests  
# Tests extraction of @interface/@implementation/@property/methods -/+ with line numbers and imports

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

@test "Objective-C symbol extraction - @interface with correct name and line numbers" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Check that DataManager.h was indexed
    grep -q "ios/DataManager.h" .sourceatlas/sourceatlas.index.jsonl
    
    # Extract the symbols for DataManager.h (note: path includes ./ prefix)
    symbols=$(jq -r 'select(.path == "./ios/DataManager.h") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that @interface DataManager is extracted
    interface_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "interface" and .name == "DataManager")')
    [ -n "$interface_symbol" ]
    
    # Check line number (should be 6 based on fixture)
    line_start=$(echo "$interface_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 6 ]
}

@test "Objective-C symbol extraction - @implementation with correct name" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for DataManager.m
    symbols=$(jq -r 'select(.path == "./ios/DataManager.m") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that @implementation DataManager is extracted
    implementation_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "implementation" and .name == "DataManager")')
    [ -n "$implementation_symbol" ]
    
    # Check line number (should be 13 based on fixture)
    line_start=$(echo "$implementation_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 13 ]
}

@test "Objective-C symbol extraction - @property with correct names" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for DataManager.h
    symbols=$(jq -r 'select(.path == "./ios/DataManager.h") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that @property apiKey is extracted
    apikey_property=$(echo "$symbols" | jq -r '.[] | select(.kind == "property" and .name == "apiKey")')
    [ -n "$apikey_property" ]
    
    # Check that @property delegate is extracted
    delegate_property=$(echo "$symbols" | jq -r '.[] | select(.kind == "property" and .name == "delegate")')
    [ -n "$delegate_property" ]
    
    # Check that @property isConnected is extracted
    connected_property=$(echo "$symbols" | jq -r '.[] | select(.kind == "property" and .name == "isConnected")')
    [ -n "$connected_property" ]
}

@test "Objective-C symbol extraction - class methods (+) with correct names" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for DataManager.h
    symbols=$(jq -r 'select(.path == "./ios/DataManager.h") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that + (instancetype)sharedInstance is extracted
    shared_instance=$(echo "$symbols" | jq -r '.[] | select(.kind == "class_method" and .name == "sharedInstance")')
    [ -n "$shared_instance" ]
    
    # Check that + (void)configure is extracted
    configure_method=$(echo "$symbols" | jq -r '.[] | select(.kind == "class_method" and .name == "configure")')
    [ -n "$configure_method" ]
}

@test "Objective-C symbol extraction - instance methods (-) with correct names" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for DataManager.h
    symbols=$(jq -r 'select(.path == "./ios/DataManager.h") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that - (instancetype)initWithConfiguration is extracted
    init_method=$(echo "$symbols" | jq -r '.[] | select(.kind == "instance_method" and .name == "initWithConfiguration")')
    [ -n "$init_method" ]
    
    # Check that - (void)fetchDataWithCompletion is extracted
    fetch_method=$(echo "$symbols" | jq -r '.[] | select(.kind == "instance_method" and .name == "fetchDataWithCompletion")')
    [ -n "$fetch_method" ]
    
    # Check that - (BOOL)validateData is extracted
    validate_method=$(echo "$symbols" | jq -r '.[] | select(.kind == "instance_method" and .name == "validateData")')
    [ -n "$validate_method" ]
}

@test "Objective-C symbol extraction - @protocol with correct name" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for DataManager.h
    symbols=$(jq -r 'select(.path == "./ios/DataManager.h") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that @protocol DataManagerDelegate is extracted
    protocol_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "protocol" and .name == "DataManagerDelegate")')
    [ -n "$protocol_symbol" ]
    
    # Check line number (should be 4 based on fixture)
    line_start=$(echo "$protocol_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 4 ]
}

@test "Objective-C symbol extraction - imports are correctly detected" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Check imports for DataManager.h
    imports=$(jq -r 'select(.path == "./ios/DataManager.h") | .imports[]' .sourceatlas/sourceatlas.index.jsonl)
    echo "$imports" | grep -q "Foundation/Foundation.h"
    echo "$imports" | grep -q "UIKit/UIKit.h"
    
    # Check imports for DataManager.m
    imports=$(jq -r 'select(.path == "./ios/DataManager.m") | .imports[]' .sourceatlas/sourceatlas.index.jsonl)
    echo "$imports" | grep -q "DataManager.h"
    echo "$imports" | grep -q "NetworkClient.h"
}

@test "Objective-C symbol extraction - visibility is public by default" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for DataManager.h
    symbols=$(jq -r 'select(.path == "./ios/DataManager.h") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that interface visibility is public
    interface_visibility=$(echo "$symbols" | jq -r '.[] | select(.kind == "interface") | .visibility')
    [ "$interface_visibility" = "public" ]
    
    # Check that method visibility is public
    method_visibility=$(echo "$symbols" | jq -r '.[] | select(.kind == "instance_method") | .visibility' | head -1)
    [ "$method_visibility" = "public" ]
    
    # Check that property visibility is public
    property_visibility=$(echo "$symbols" | jq -r '.[] | select(.kind == "property") | .visibility' | head -1)
    [ "$property_visibility" = "public" ]
}