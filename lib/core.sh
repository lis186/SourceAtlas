#!/usr/bin/env bash

# SourceAtlas Core Library
# Shared functions for indexing operations

# Get file extension
get_extension() {
    local file="$1"
    echo ".${file##*.}"
}

# Get language from extension
get_language() {
    local ext="$1"
    
    case "$ext" in
        .swift)
            echo "swift"
            ;;
        .kt|.kts)
            echo "kotlin"
            ;;
        .m|.h|.mm)
            echo "objc"
            ;;
        .java)
            echo "java"
            ;;
        .js|.mjs|.cjs)
            echo "javascript"
            ;;
        .ts|.tsx)
            echo "typescript"
            ;;
        .py|.pyi)
            echo "python"
            ;;
        .rb|.rake|.gemspec)
            echo "ruby"
            ;;
        .sh|.bash|.zsh)
            echo "shell"
            ;;
        .json)
            echo "json"
            ;;
        .yml|.yaml)
            echo "yaml"
            ;;
        .xml|.plist)
            echo "xml"
            ;;
        .gradle)
            echo "gradle"
            ;;
        .toml)
            echo "toml"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Count lines in file
count_lines() {
    local file="$1"
    wc -l < "$file" | tr -d ' '
}

# Get file size in bytes
get_file_size() {
    local file="$1"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f%z "$file"
    else
        stat -c%s "$file"
    fi
}

# Calculate SHA256 hash
calculate_hash() {
    local file="$1"
    
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | cut -d' ' -f2
    else
        echo "no-hash-available"
    fi
}

# Escape JSON string
json_escape() {
    local str="$1"
    # Escape backslashes, quotes, newlines, tabs, etc.
    echo "$str" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//'
}

# Check if path matches exclude pattern
is_excluded() {
    local path="$1"
    local exclude_file="$2"
    
    if [[ ! -f "$exclude_file" ]]; then
        return 1
    fi
    
    while IFS= read -r pattern; do
        # Skip comments and empty lines
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$pattern" ]] && continue
        
        # Check if path matches pattern
        case "$path" in
            $pattern)
                return 0
                ;;
        esac
    done < "$exclude_file"
    
    return 1
}

# Extract imports from file based on language
extract_imports() {
    local file="$1"
    local lang="$2"
    local imports=""
    
    case "$lang" in
        swift)
            imports=$(grep -E '^import\s+' "$file" | sed 's/import\s\+//' | tr '\n' ',' | sed 's/,$//')
            ;;
        kotlin|java)
            imports=$(grep -E '^import\s+' "$file" | sed 's/import\s\+//' | tr '\n' ',' | sed 's/,$//')
            ;;
        python)
            imports=$(grep -E '^(import|from)\s+' "$file" | sed 's/\(import\|from\)\s\+//' | cut -d' ' -f1 | tr '\n' ',' | sed 's/,$//')
            ;;
        ruby)
            imports=$(grep -E '^require(_relative)?\s+' "$file" | sed 's/require\(_relative\)\?\s\+//' | tr '\n' ',' | sed 's/,$//')
            ;;
        javascript|typescript)
            imports=$(grep -E '^(import|require)\s*\(' "$file" | sed 's/.*[("'\'']\([^"'\'']*\)[)"'\''].*/\1/' | tr '\n' ',' | sed 's/,$//')
            ;;
        objc)
            # Extract #import and @import statements
            imports=$(grep -E '^#import\s*[<"]|^@import\s+' "$file" | sed 's/.*[<"]\([^>"]*\)[>"].*/\1/' | sed 's/^@import\s\+\([^;]*\);.*/\1/' | tr '\n' ',' | sed 's/,$//')
            ;;
        *)
            imports=""
            ;;
    esac
    
    echo "$imports"
}

# Extract symbols from file based on language (simplified)
extract_symbols() {
    local file="$1"
    local lang="$2"
    
    case "$lang" in
        swift)
            # Extract class, struct, enum, protocol, extension, actor, func definitions with line numbers
            # Include visibility modifiers (public, private, internal, fileprivate, open)
            grep -n -E '^\s*((public|private|internal|fileprivate|open)\s+)?(class|struct|enum|protocol|extension|actor|func)\s+' "$file" | \
            head -10 | \
            while IFS=':' read -r line_num content; do
                # Extract visibility, kind and name
                local visibility="internal"  # Default for Swift
                local kind=""
                local name=""
                
                # Check if line starts with visibility modifier
                if echo "$content" | grep -qE '^\s*(public|private|internal|fileprivate|open)\s+'; then
                    visibility=$(echo "$content" | awk '{print $1}')
                    kind=$(echo "$content" | awk '{print $2}')
                    name=$(echo "$content" | awk '{print $3}' | sed 's/[:{(].*//')
                else
                    kind=$(echo "$content" | awk '{print $1}')
                    name=$(echo "$content" | awk '{print $2}' | sed 's/[:{(].*//')
                fi
                
                echo "{\"name\":\"$name\",\"kind\":\"$kind\",\"visibility\":\"$visibility\",\"line_start\":$line_num,\"line_end\":$((line_num + 5))}"
            done | jq -s .
            ;;
        kotlin)
            # Extract class, object, interface, fun, data class, sealed class, companion object definitions with line numbers
            # Also capture annotations like @AndroidEntryPoint
            grep -n -E '^\s*(@[A-Za-z0-9_]+|((public|private|internal|protected)\s+)?(class|object|interface|fun|data class|sealed class|companion object)\s+)' "$file" | \
            head -10 | \
            while IFS=':' read -r line_num content; do
                local kind=""
                local name=""
                local visibility="internal"  # Default for Kotlin
                
                # Handle annotations
                if echo "$content" | grep -q "^@"; then
                    kind="annotation"
                    name=$(echo "$content" | awk '{print $1}' | sed 's/@//')
                # Handle visibility modifiers
                elif echo "$content" | grep -qE '^\s*(public|private|internal|protected)\s+'; then
                    visibility=$(echo "$content" | awk '{print $1}')
                    # Extract kind and name after visibility modifier
                    if echo "$content" | grep -q "class"; then
                        kind="class"
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="class") print $(i+1)}' | sed 's/[:{(].*//')
                    elif echo "$content" | grep -q "object"; then
                        kind="object"
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="object") print $(i+1)}' | sed 's/[:{(].*//')
                    elif echo "$content" | grep -q "interface"; then
                        kind="interface"
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="interface") print $(i+1)}' | sed 's/[:{(].*//')
                    elif echo "$content" | grep -q "fun"; then
                        kind="fun"
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="fun") print $(i+1)}' | sed 's/[:{(].*//')
                    fi
                # Handle declarations without explicit visibility modifiers
                else
                    if echo "$content" | grep -q "data class"; then
                        kind="data_class"
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="class") print $(i+1)}' | sed 's/[:{(].*//')
                    elif echo "$content" | grep -q "sealed class"; then
                        kind="sealed_class"  
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="class") print $(i+1)}' | sed 's/[:{(].*//')
                    elif echo "$content" | grep -q "companion object"; then
                        kind="companion_object"
                        # companion object usually doesn't have a name, use "Companion" as default
                        name="Companion"
                    elif echo "$content" | grep -q "class"; then
                        kind="class"
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="class") print $(i+1)}' | sed 's/[:{(].*//')
                    elif echo "$content" | grep -q "object"; then
                        kind="object"
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="object") print $(i+1)}' | sed 's/[:{(].*//')
                    elif echo "$content" | grep -q "interface"; then
                        kind="interface" 
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="interface") print $(i+1)}' | sed 's/[:{(].*//')
                    elif echo "$content" | grep -q "fun"; then
                        kind="fun"
                        name=$(echo "$content" | awk '{for(i=1;i<=NF;i++) if($i=="fun") print $(i+1)}' | sed 's/[:{(].*//')
                    fi
                fi
                
                echo "{\"name\":\"$name\",\"kind\":\"$kind\",\"visibility\":\"$visibility\",\"line_start\":$line_num,\"line_end\":$((line_num + 5))}"
            done | jq -s .
            ;;
        python)
            # Extract class and def definitions with line numbers
            grep -n -E '^(class|def)\s+' "$file" | \
            head -5 | \
            while IFS=':' read -r line_num content; do
                local kind=$(echo "$content" | sed 's/^\([a-z]*\).*/\1/')
                local name=$(echo "$content" | sed 's/^[a-z]*\s*\([^([:space:]]*\).*/\1/')
                local visibility="public"  # Python default
                
                echo "{\"name\":\"$name\",\"kind\":\"$kind\",\"visibility\":\"$visibility\",\"line_start\":$line_num,\"line_end\":$((line_num + 5))}"
            done | jq -s .
            ;;
        objc)
            # Extract @interface, @implementation, @property, and method definitions with line numbers
            # Include both instance methods (-) and class methods (+)
            grep -n -E '^\s*(@interface|@implementation|@property|[-+]\s*\(|@protocol)\s*' "$file" | \
            head -10 | \
            while IFS=':' read -r line_num content; do
                local kind=""
                local name=""
                local visibility="public"  # Default for Objective-C
                
                # Extract different types of Objective-C symbols
                if echo "$content" | grep -q "@interface"; then
                    kind="interface"
                    name=$(echo "$content" | awk '{print $2}')
                elif echo "$content" | grep -q "@implementation"; then
                    kind="implementation" 
                    name=$(echo "$content" | awk '{print $2}')
                elif echo "$content" | grep -q "@property"; then
                    kind="property"
                    name=$(echo "$content" | awk '{print $NF}' | sed 's/[;*]//g')
                elif echo "$content" | grep -q "@protocol"; then
                    kind="protocol"
                    name=$(echo "$content" | awk '{print $2}' | sed 's/[;<].*$//')
                elif echo "$content" | grep -qE '^\s*[-+]\s*\('; then
                    # Method definition
                    if echo "$content" | grep -q "\-"; then
                        kind="instance_method"
                    else
                        kind="class_method"
                    fi
                    # Extract method name (first part before colon or semicolon)
                    name=$(echo "$content" | awk -F'[)(]' '{print $3}' | awk '{print $1}' | sed 's/[:;].*//')
                fi
                
                echo "{\"name\":\"$name\",\"kind\":\"$kind\",\"visibility\":\"$visibility\",\"line_start\":$line_num,\"line_end\":$((line_num + 5))}"
            done | jq -s .
            ;;
        ruby)
            # Extract class, module, def definitions with line numbers
            grep -n -E '^\s*(class|module|def)\s+' "$file" | \
            head -5 | \
            while IFS=':' read -r line_num content; do
                local kind=$(echo "$content" | sed 's/^\s*\([a-z]*\).*/\1/')
                local name=$(echo "$content" | sed 's/^\s*[a-z]*\s*\([^([:space:]]*\).*/\1/')
                local visibility="public"  # Ruby default
                
                echo "{\"name\":\"$name\",\"kind\":\"$kind\",\"visibility\":\"$visibility\",\"line_start\":$line_num,\"line_end\":$((line_num + 5))}"
            done | jq -s .
            ;;
        *)
            echo "[]"
            ;;
    esac
}

# Detect role from file path and name
detect_role() {
    local path="$1"
    local base_name="$(basename "$path")"
    
    # Check for common patterns
    case "$base_name" in
        *ViewController*|*Activity*|*Fragment*)
            echo "ui"
            ;;
        *ViewModel*|*Presenter*)
            echo "viewmodel"
            ;;
        *Repository*|*Store*|*Cache*)
            echo "repository"
            ;;
        *Service*|*Manager*)
            echo "service"
            ;;
        *UseCase*|*Interactor*)
            echo "usecase"
            ;;
        *Model*|*Entity*|*Data*)
            echo "model"
            ;;
        *Test*|*Spec*)
            echo "test"
            ;;
        *Config*|*Settings*)
            echo "config"
            ;;
        build.*|Makefile|*.gradle)
            echo "build"
            ;;
        *)
            echo "general"
            ;;
    esac
}

# Generate summary for file (simplified)
generate_summary() {
    local file="$1"
    local lang="$2"
    local role="$3"
    
    echo "File with role: $role, language: $lang"
}