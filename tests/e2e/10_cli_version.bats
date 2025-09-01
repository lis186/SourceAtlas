#!/usr/bin/env bats

load ../helpers

@test "satlas command exists" {
    run which satlas
    assert_success
}

@test "sourceatlas command exists" {
    run which sourceatlas
    assert_success
}

@test "satlas version displays version info" {
    run satlas version
    assert_success
    assert_output_contains "SourceAtlas"
    assert_output_contains "Version:"
    assert_output_contains "Schema Version:"
}

@test "sourceatlas version displays version info" {
    run sourceatlas version
    assert_success
    assert_output_contains "SourceAtlas"
    assert_output_contains "Version:"
    assert_output_contains "Schema Version:"
}

@test "satlas and sourceatlas version output is identical" {
    run satlas version
    assert_success
    local satlas_output="$output"
    
    run sourceatlas version
    assert_success
    local sourceatlas_output="$output"
    
    [ "$satlas_output" = "$sourceatlas_output" ]
}

@test "version output includes schema version 1" {
    run satlas version
    assert_success
    assert_output_contains "Schema Version: 1"
}

@test "satlas without arguments shows help" {
    run satlas
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "Commands:"
}

@test "sourceatlas without arguments shows help" {
    run sourceatlas
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "Commands:"
}

@test "satlas --help shows help" {
    run satlas --help
    assert_success
    assert_output_contains "Usage:"
    assert_output_contains "Commands:"
    assert_output_contains "version"
}