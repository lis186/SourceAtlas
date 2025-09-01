#!/usr/bin/env bats

@test "coverage matrix exists" {
    [ -f "${BATS_TEST_DIRNAME}/../coverage-matrix.md" ]
}

@test "coverage matrix contains all CLI commands" {
    local matrix="${BATS_TEST_DIRNAME}/../coverage-matrix.md"
    
    # Check for all required CLI commands from PRD
    grep -q "satlas version" "$matrix"
    grep -q "satlas init" "$matrix"
    grep -q "satlas scan" "$matrix"
    grep -q "satlas symbols" "$matrix"
    grep -q "satlas stats" "$matrix"
    grep -q "satlas manifest" "$matrix"
    grep -q "satlas shard" "$matrix"
    grep -q "satlas delta" "$matrix"
    grep -q "satlas query" "$matrix"
    grep -q "satlas segment" "$matrix"
    grep -q "satlas export-dsl" "$matrix"
    grep -q "satlas clean" "$matrix"
    grep -q "satlas run" "$matrix"
    grep -q "satlas verify" "$matrix"
}

@test "coverage matrix includes all language support" {
    local matrix="${BATS_TEST_DIRNAME}/../coverage-matrix.md"
    
    grep -q "Swift" "$matrix"
    grep -q "Kotlin" "$matrix"
    grep -q "Objective-C" "$matrix"
    grep -q "Ruby" "$matrix"
    grep -q "Shell" "$matrix"
    grep -q "Python" "$matrix"
}

@test "coverage matrix defines validation gates" {
    local matrix="${BATS_TEST_DIRNAME}/../coverage-matrix.md"
    
    grep -q "Gate A.*Coverage <95%" "$matrix"
    grep -q "Gate B.*Hit@5 <80%" "$matrix"
    grep -q "Gate C.*Median >3s" "$matrix"
    grep -q "Gate D.*semantic recall" "$matrix"
    grep -q "Gate E.*False positive >20%" "$matrix"
}

@test "coverage matrix includes UAT criteria" {
    local matrix="${BATS_TEST_DIRNAME}/../coverage-matrix.md"
    
    grep -q "File coverage.*≥95%" "$matrix"
    grep -q "Hit@5 accuracy.*≥80%" "$matrix"
    grep -q "False positive rate.*<20%" "$matrix"
}

@test "coverage matrix defines test priorities" {
    local matrix="${BATS_TEST_DIRNAME}/../coverage-matrix.md"
    
    grep -q "P0.*Critical" "$matrix"
    grep -q "P1.*Important" "$matrix"
    grep -q "P2.*Nice to have" "$matrix"
}