#!/bin/bash
# SourceAtlas - Pattern Detection Script (Ultra-Fast Version)
# Multi-Language Support: Swift/iOS and TypeScript/React
#
# Purpose: Identify files matching a given pattern type using filename/directory matching only
# Philosophy: Scripts collect data quickly, AI does deep interpretation
#
# Ranking Algorithm (File/Dir Only - Ultra Fast):
#   - File name match: +10 points
#   - Directory name match: +8 points
#   - Skips content analysis (AI can read top files later)
#   - Skips recency check (too slow on large projects)
#   - Skips file size analysis (minimal value, high cost)
#
# Trade-offs:
#   + Blazing fast (<5s even on LARGE projects)
#   + Simple and reliable
#   + Good enough for pattern detection (80%+ accuracy)
#   - Misses files with non-standard names
#   - Can't rank by content relevance
#
# Usage: ./find-patterns.sh "pattern type" [project_path]
# Example: ./find-patterns.sh "api endpoint" ./my-project
#
# Performance Target: <5s on ALL project sizes

set -euo pipefail

PATTERN="${1:-}"
PROJECT_PATH="${2:-.}"

# Detect project type (swift vs typescript)
detect_project_type() {
    local path="$1"

    # Check for TypeScript/JavaScript indicators
    if [ -f "$path/package.json" ] || [ -f "$path/tsconfig.json" ]; then
        echo "typescript"
        return
    fi

    # Check for Swift/iOS indicators
    if [ -f "$path/Podfile" ] || [ -f "$path/Package.swift" ] || find "$path" -maxdepth 3 -name "*.xcodeproj" -o -name "*.xcworkspace" 2>/dev/null | grep -q .; then
        echo "swift"
        return
    fi

    # Default to swift for backward compatibility
    echo "swift"
}

PROJECT_TYPE=$(detect_project_type "$PROJECT_PATH")

# Normalize pattern (lowercase, trim)
normalize_pattern() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | xargs
}

# Get file patterns for pattern based on project type
get_file_patterns() {
    local pattern="$1"
    local proj_type="$2"

    if [ "$proj_type" = "typescript" ]; then
        # TypeScript/React patterns
        case "$pattern" in
            "api endpoint"|"api"|"endpoint")
                echo "*route.ts *route.tsx *api.ts *api.tsx *controller.ts *service.ts *endpoint.ts *handler.ts *.api.ts"
                ;;
            "react component"|"component")
                echo "*.tsx *Component.tsx *component.tsx"
                ;;
            "react hook"|"hook"|"hooks")
                echo "use*.ts use*.tsx *hook.ts *hooks.ts"
                ;;
            "background job"|"job"|"queue")
                echo "*worker.ts *job.ts *task.ts *queue.ts *processor.ts *cron.ts"
                ;;
            "file upload"|"upload"|"file storage")
                echo "*upload.ts *upload.tsx *storage.ts *file.ts *media.ts"
                ;;
            "database query"|"database"|"query")
                echo "*repository.ts *model.ts *entity.ts *schema.ts *query.ts *dao.ts"
                ;;
            "authentication"|"auth"|"login")
                echo "*auth.ts *auth.tsx *session.ts *login.ts *credential.ts *jwt.ts"
                ;;
            "state management"|"store"|"state")
                echo "*store.ts *slice.ts *reducer.ts *context.tsx *provider.tsx *state.ts"
                ;;
            "networking"|"network"|"http client")
                echo "*client.ts *http.ts *fetch.ts *api.ts *request.ts *axios.ts"
                ;;
            "form handling"|"form")
                echo "*form.tsx *form.ts *validation.ts *schema.ts"
                ;;
            *)
                echo ""
                ;;
        esac
    else
        # Swift/iOS patterns
        case "$pattern" in
            "api endpoint"|"api"|"endpoint")
                echo "*Controller.swift *Router.swift *API.swift routes.* *Endpoint*.swift *Service.swift *Remote*.swift"
                ;;
            "background job"|"job"|"queue")
                echo "*Job.swift *Worker.swift *Task.swift *Queue*.swift *Operation*.swift *Async*.swift"
                ;;
            "file upload"|"upload"|"file storage")
                echo "*Upload*.swift *Storage*.swift *File*.swift *Media*.swift *Image*.swift *Attachment*.swift"
                ;;
            "database query"|"database"|"query")
                echo "*Repository.swift *Query.swift *Model.swift *Store.swift *Database*.swift *Entity*.swift *DAO*.swift"
                ;;
            "authentication"|"auth"|"login")
                echo "*Auth*.swift *Session*.swift *Login*.swift *Credential*.swift *Token*.swift *Security*.swift"
                ;;
            "swiftui view"|"view")
                echo "*View.swift *Screen.swift *Page.swift"
                ;;
            "view controller"|"viewcontroller")
                echo "*ViewController.swift *VC.swift *Controller.swift"
                ;;
            "networking"|"network")
                echo "*Client.swift *Network*.swift *Service.swift *API*.swift *Request*.swift *HTTPClient*.swift"
                ;;
            *)
                echo ""
                ;;
        esac
    fi
}

# Get directory patterns for pattern based on project type
get_dir_patterns() {
    local pattern="$1"
    local proj_type="$2"

    if [ "$proj_type" = "typescript" ]; then
        # TypeScript/React directory patterns
        case "$pattern" in
            "api endpoint"|"api"|"endpoint")
                echo "api routes controllers handlers services app/api pages/api"
                ;;
            "react component"|"component")
                echo "components ui features modules views pages screens"
                ;;
            "react hook"|"hook"|"hooks")
                echo "hooks composables utils lib"
                ;;
            "background job"|"job"|"queue")
                echo "jobs workers tasks queue background cron"
                ;;
            "file upload"|"upload"|"file storage")
                echo "upload storage media files lib"
                ;;
            "database query"|"database"|"query")
                echo "models entities repositories db database prisma"
                ;;
            "authentication"|"auth"|"login")
                echo "auth authentication session security middleware"
                ;;
            "state management"|"store"|"state")
                echo "store state redux context providers slices"
                ;;
            "networking"|"network"|"http client")
                echo "api lib services utils http client"
                ;;
            "form handling"|"form")
                echo "forms components ui features"
                ;;
            *)
                echo ""
                ;;
        esac
    else
        # Swift/iOS directory patterns
        case "$pattern" in
            "api endpoint"|"api"|"endpoint")
                echo "controllers routes api services networking"
                ;;
            "background job"|"job"|"queue")
                echo "jobs workers tasks operations background"
                ;;
            "file upload"|"upload"|"file storage")
                echo "uploads storage media files documents attachments"
                ;;
            "database query"|"database"|"query")
                echo "models repositories queries stores database entities persistence data"
                ;;
            "authentication"|"auth"|"login")
                echo "auth authentication session security credentials login"
                ;;
            "swiftui view"|"view")
                echo "Views Screens Pages UI Components"
                ;;
            "view controller"|"viewcontroller")
                echo "ViewControllers Controllers UI Views"
                ;;
            "networking"|"network")
                echo "Networking Network Services API Client HTTP"
                ;;
            *)
                echo ""
                ;;
        esac
    fi
}

# Main execution
main() {
    if [ -z "$PATTERN" ]; then
        echo "Usage: $0 \"pattern type\" [project_path]" >&2
        echo "" >&2
        echo "Project type detected: $PROJECT_TYPE" >&2
        echo "" >&2
        if [ "$PROJECT_TYPE" = "typescript" ]; then
            echo "Supported patterns (TypeScript/React):" >&2
            echo "  - api endpoint / api / endpoint" >&2
            echo "  - react component / component" >&2
            echo "  - react hook / hook / hooks" >&2
            echo "  - state management / store / state" >&2
            echo "  - form handling / form" >&2
            echo "  - background job / job / queue" >&2
            echo "  - file upload / upload / file storage" >&2
            echo "  - database query / database / query" >&2
            echo "  - authentication / auth / login" >&2
            echo "  - networking / network / http client" >&2
        else
            echo "Supported patterns (Swift/iOS):" >&2
            echo "  - api endpoint / api / endpoint" >&2
            echo "  - background job / job / queue" >&2
            echo "  - file upload / upload / file storage" >&2
            echo "  - database query / database / query" >&2
            echo "  - authentication / auth / login" >&2
            echo "  - swiftui view / view" >&2
            echo "  - view controller / viewcontroller" >&2
            echo "  - networking / network" >&2
        fi
        exit 1
    fi

    # Normalize and get pattern components
    local normalized=$(normalize_pattern "$PATTERN")
    local file_patterns=$(get_file_patterns "$normalized" "$PROJECT_TYPE")
    local dir_patterns=$(get_dir_patterns "$normalized" "$PROJECT_TYPE")

    if [ -z "$file_patterns" ]; then
        echo "Error: Unknown pattern '$PATTERN'" >&2
        echo "Run with no arguments to see supported patterns." >&2
        exit 1
    fi

    # Use find with -name patterns (very fast)
    # Build find command with all file patterns
    local find_args=()
    local first=true
    for pattern in $file_patterns; do
        if [ "$first" = true ]; then
            find_args+=( "-name" "$pattern" )
            first=false
        else
            find_args+=( "-o" "-name" "$pattern" )
        fi
    done

    # Find all matching files and score them
    local temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT

    # Find files matching any of the file patterns
    find "$PROJECT_PATH" -type f \( "${find_args[@]}" \) \
        ! -path "*/node_modules/*" \
        ! -path "*/.venv/*" \
        ! -path "*/venv/*" \
        ! -path "*/vendor/*" \
        ! -path "*/Pods/*" \
        ! -path "*/__pycache__/*" \
        ! -path "*/.git/*" \
        ! -path "*/DerivedData/*" \
        ! -path "*/build/*" \
        ! -path "*/.build/*" \
        ! -path "*/Carthage/*" \
        2>/dev/null | while IFS= read -r file; do

        local score=10  # Base score for file name match

        # Check if in a relevant directory (+8 points)
        local dirname=$(dirname "$file")
        for dir_pattern in $dir_patterns; do
            if echo "$dirname" | tr '[:upper:]' '[:lower:]' | grep -qi "$dir_pattern"; then
                score=$((score + 8))
                break
            fi
        done

        echo "$score|$file"
    done > "$temp_file"

    # Sort by score (descending) and output top 10 files
    sort -t'|' -k1 -nr "$temp_file" | head -10 | cut -d'|' -f2
}

# Run main
main
