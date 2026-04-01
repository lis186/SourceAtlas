#!/usr/bin/env bash
# resolve-header-paths.sh — Resolve header search paths for clang AST parsing
#
# Usage: resolve-header-paths.sh <source-file>
#
# Output: space-separated -I flags for clang, e.g.:
#   -I/path/to/Pods/AFNetworking -I/path/to/Pods/CocoaSecurity ...
#
# Strategy (by priority):
#   1. compile_commands.json (if exists near source file)
#   2. CocoaPods xcconfig (find Pods/ + parse HEADER_SEARCH_PATHS)
#   3. SPM .build/ directory
#   4. Fallback: scan for common framework header dirs near source
#
# Exit codes:
#   0 - found paths
#   1 - no paths found (clang will run without -I, best-effort)

set -uo pipefail

SOURCE_FILE="${1:?Usage: resolve-header-paths.sh <source-file>}"
SOURCE_DIR=$(dirname "$SOURCE_FILE")

# --- Strategy 1: compile_commands.json ---
find_compile_commands() {
    local dir="$SOURCE_DIR"
    local basename=$(basename "$SOURCE_FILE")
    # Walk up to find compile_commands.json
    for _ in $(seq 1 8); do
        if [[ -f "$dir/compile_commands.json" ]]; then
            # Extract -I flags for this specific file
            python3 -c "
import json, sys, os
with open('$dir/compile_commands.json') as f:
    commands = json.load(f)
for cmd in commands:
    if os.path.basename(cmd.get('file','')) == '$basename':
        parts = cmd.get('command','').split()
        flags = [p for p in parts if p.startswith('-I')]
        if flags:
            print(' '.join(flags))
            sys.exit(0)
sys.exit(1)
" 2>/dev/null && return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# --- Strategy 2: CocoaPods xcconfig ---
find_cocoapods_paths() {
    local dir="$SOURCE_DIR"
    # Walk up to find Pods/ directory
    for _ in $(seq 1 8); do
        if [[ -d "$dir/Pods" ]]; then
            # Find any debug xcconfig
            local xcconfig
            xcconfig=$(find "$dir/Pods/Target Support Files" -name "*.debug.xcconfig" 2>/dev/null | head -1)
            if [[ -n "$xcconfig" ]]; then
                # Extract HEADER_SEARCH_PATHS and resolve to -I flags
                # The xcconfig uses ${PODS_CONFIGURATION_BUILD_DIR} but we need raw paths
                # Fallback: just find all Headers/ dirs under Pods/
                find "$dir/Pods" -type d -name "Headers" -path "*/Pod/Headers" 2>/dev/null | while read -r hdir; do
                    echo -n "-I\"$hdir\" "
                done

                # Add direct pod source dirs (for #import "X.h" style)
                # AND their parents (for framework-style #import <X/Y.h>)
                find "$dir/Pods" -maxdepth 2 -type d 2>/dev/null | while read -r pdir; do
                    if ls "$pdir"/*.h &>/dev/null; then
                        echo -n "-I\"$pdir\" "
                        # Also add parent for framework-style imports
                        local parent
                        parent=$(dirname "$pdir")
                        echo -n "-I\"$parent\" "
                    fi
                done
                return 0
            fi
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# --- Strategy 3: SPM .build/ ---
find_spm_paths() {
    local dir="$SOURCE_DIR"
    for _ in $(seq 1 8); do
        if [[ -d "$dir/.build" ]]; then
            find "$dir/.build" -type d -name "include" 2>/dev/null | while read -r idir; do
                echo -n "-I\"$idir\" "
            done
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# --- Strategy 4: Fallback — scan nearby for headers ---
find_nearby_headers() {
    local dir="$SOURCE_DIR"
    # Walk up to project root (look for .xcodeproj or Package.swift)
    for _ in $(seq 1 8); do
        if ls "$dir"/*.xcodeproj &>/dev/null || [[ -f "$dir/Package.swift" ]]; then
            # Add the source dir itself and immediate children
            echo -n "-I\"$dir\" "
            find "$dir" -maxdepth 3 -type d -name "Classes" -o -name "Sources" -o -name "include" 2>/dev/null | while read -r sdir; do
                echo -n "-I\"$sdir\" "
            done
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# --- Main: try strategies in order ---
RESULT=""
RESULT=$(find_compile_commands 2>/dev/null) || \
RESULT=$(find_cocoapods_paths 2>/dev/null) || \
RESULT=$(find_spm_paths 2>/dev/null) || \
RESULT=$(find_nearby_headers 2>/dev/null) || \
true

if [[ -n "$RESULT" ]]; then
    echo "$RESULT"
    exit 0
else
    exit 1
fi
