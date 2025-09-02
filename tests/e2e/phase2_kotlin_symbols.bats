#!/usr/bin/env bats

# Phase 2 Step 2.3: Kotlin symbol extraction tests
# Tests extraction of class/object/interface/fun/annotations with correct names and line numbers

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

@test "Kotlin symbol extraction - interface with correct name and line numbers" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Check that MainViewModel.kt was indexed
    grep -q "android/MainViewModel.kt" .sourceatlas/sourceatlas.index.jsonl
    
    # Extract the symbols for MainViewModel.kt (note: path includes ./ prefix)
    symbols=$(jq -r 'select(.path == "./android/MainViewModel.kt") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that interface DataRepository is extracted
    interface_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "interface" and .name == "DataRepository")')
    [ -n "$interface_symbol" ]
    
    # Check line number (should be 8 based on fixture)
    line_start=$(echo "$interface_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 8 ]
}

@test "Kotlin symbol extraction - class with correct name and line numbers" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for MainViewModel.kt
    symbols=$(jq -r 'select(.path == "./android/MainViewModel.kt") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that class MainViewModel is extracted
    class_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "class" and .name == "MainViewModel")')
    [ -n "$class_symbol" ]
    
    # Check line number (should be 12 based on fixture)
    line_start=$(echo "$class_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 12 ]
    
    # Check visibility (should be internal by default)
    visibility=$(echo "$class_symbol" | jq -r '.visibility')
    [ "$visibility" = "internal" ]
}

@test "Kotlin symbol extraction - object with correct name" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for MainViewModel.kt
    symbols=$(jq -r 'select(.path == "./android/MainViewModel.kt") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that object Constants is extracted
    object_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "object" and .name == "Constants")')
    [ -n "$object_symbol" ]
    
    # Check line number (should be 28 based on fixture)
    line_start=$(echo "$object_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 28 ]
}

@test "Kotlin symbol extraction - functions with correct names and visibility" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for MainViewModel.kt
    symbols=$(jq -r 'select(.path == "./android/MainViewModel.kt") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that fun loadData is extracted
    load_func=$(echo "$symbols" | jq -r '.[] | select(.kind == "fun" and .name == "loadData")')
    [ -n "$load_func" ]
    
    # Check that private fun processData is extracted with correct visibility
    process_func=$(echo "$symbols" | jq -r '.[] | select(.kind == "fun" and .name == "processData" and .visibility == "private")')
    [ -n "$process_func" ]
}

@test "Kotlin symbol extraction - @AndroidEntryPoint annotation detection" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for MainActivity.kt
    symbols=$(jq -r 'select(.path == "./android/MainActivity.kt") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that @AndroidEntryPoint annotation is extracted
    annotation_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "annotation" and .name == "AndroidEntryPoint")')
    [ -n "$annotation_symbol" ]
    
    # Check line number (should be 8 based on fixture)
    line_start=$(echo "$annotation_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 8 ]
}

@test "Kotlin symbol extraction - MainActivity class with inheritance" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for MainActivity.kt
    symbols=$(jq -r 'select(.path == "./android/MainActivity.kt") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that class MainActivity is extracted
    class_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "class" and .name == "MainActivity")')
    [ -n "$class_symbol" ]
    
    # Check line number (should be 9 based on fixture)
    line_start=$(echo "$class_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 9 ]
}

@test "Kotlin symbol extraction - function visibility detection (private/internal)" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for MainActivity.kt
    symbols=$(jq -r 'select(.path == "./android/MainActivity.kt") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check for private function setupObservers
    private_func=$(echo "$symbols" | jq -r '.[] | select(.kind == "fun" and .name == "setupObservers" and .visibility == "private")')
    [ -n "$private_func" ]
    
    # Check for internal function updateUI
    internal_func=$(echo "$symbols" | jq -r '.[] | select(.kind == "fun" and .name == "updateUI" and .visibility == "internal")')
    [ -n "$internal_func" ]
}

@test "Kotlin symbol extraction - companion object detection" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Extract the symbols for MainActivity.kt
    symbols=$(jq -r 'select(.path == "./android/MainActivity.kt") | .symbols' .sourceatlas/sourceatlas.index.jsonl)
    
    # Check that companion object is extracted
    companion_symbol=$(echo "$symbols" | jq -r '.[] | select(.kind == "companion_object" and .name == "Companion")')
    [ -n "$companion_symbol" ]
    
    # Check line number (should be 32 based on fixture)
    line_start=$(echo "$companion_symbol" | jq -r '.line_start')
    [ "$line_start" -eq 32 ]
}

@test "Kotlin symbol extraction - imports are correctly detected" {
    # Run scan to generate index
    run satlas scan --root .
    [ "$status" -eq 0 ]
    
    # Check imports for MainViewModel.kt
    imports=$(jq -r 'select(.path == "./android/MainViewModel.kt") | .imports[]' .sourceatlas/sourceatlas.index.jsonl)
    echo "$imports" | grep -q "androidx.lifecycle.LiveData"
    echo "$imports" | grep -q "androidx.lifecycle.MutableLiveData"
    echo "$imports" | grep -q "androidx.lifecycle.ViewModel"
    echo "$imports" | grep -q "javax.inject.Inject"
    
    # Check imports for MainActivity.kt
    imports=$(jq -r 'select(.path == "./android/MainActivity.kt") | .imports[]' .sourceatlas/sourceatlas.index.jsonl)
    echo "$imports" | grep -q "android.os.Bundle"
    echo "$imports" | grep -q "androidx.appcompat.app.AppCompatActivity"
    echo "$imports" | grep -q "androidx.lifecycle.ViewModelProvider"
    echo "$imports" | grep -q "dagger.hilt.android.AndroidEntryPoint"
}