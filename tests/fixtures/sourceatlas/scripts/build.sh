#!/bin/bash

# Build script for the project

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

build_ios() {
    echo "Building iOS app..."
    xcodebuild -project "$PROJECT_ROOT/ios/App.xcodeproj" -scheme App
}

build_android() {
    echo "Building Android app..."
    cd "$PROJECT_ROOT/android"
    ./gradlew build
}

main() {
    case "$1" in
        ios)
            build_ios
            ;;
        android)
            build_android
            ;;
        all)
            build_ios
            build_android
            ;;
        *)
            echo "Usage: $0 {ios|android|all}"
            exit 1
            ;;
    esac
}

main "$@"