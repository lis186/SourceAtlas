#!/usr/bin/env bash
# detect-zones.sh — Detect responsibility zones in a source file
#
# Usage: detect-zones.sh <file-path> [--language objc|swift|typescript|javascript|go|java|kotlin|python|rust]
#
# Output: YAML zone map to stdout
#
# Zone detection strategy per language:
#   ObjC:       #pragma mark sections
#   Swift:      // MARK: sections + extension boundaries
#   TypeScript: // region / #region + class sections
#   Default:    blank-line separated method clusters
#
# Exit codes:
#   0 - success
#   1 - file not found
#   2 - unsupported/undetected language

set -uo pipefail

FILE_PATH="${1:?Usage: detect-zones.sh <file-path> [--language <lang>]}"
LANGUAGE=""

# Parse optional --language flag
shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --language) LANGUAGE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ ! -f "$FILE_PATH" ]]; then
    echo "error: file not found: $FILE_PATH" >&2
    exit 1
fi

# Auto-detect language from extension
if [[ -z "$LANGUAGE" ]]; then
    ext="${FILE_PATH##*.}"
    case "$ext" in
        m|h)    LANGUAGE="objc" ;;
        mm)     LANGUAGE="objcpp" ;;
        swift)  LANGUAGE="swift" ;;
        ts|tsx) LANGUAGE="typescript" ;;
        js|jsx) LANGUAGE="javascript" ;;
        go)     LANGUAGE="go" ;;
        java)   LANGUAGE="java" ;;
        kt|kts) LANGUAGE="kotlin" ;;
        py)     LANGUAGE="python" ;;
        rs)     LANGUAGE="rust" ;;
        *)      echo "error: cannot detect language for .$ext" >&2; exit 2 ;;
    esac
fi

TOTAL_LINES=$(wc -l < "$FILE_PATH" | tr -d ' ')
FILENAME=$(basename "$FILE_PATH")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# --- Clang AST extraction (ObjC/Swift) ---

CLANG_METHODS_JSON=""

extract_clang_methods() {
    if ! command -v clang &>/dev/null; then
        echo "# clang not found, skipping AST extraction" >&2
        return 1
    fi

    local header_flags=""
    if [[ -f "$SCRIPT_DIR/resolve-header-paths.sh" ]]; then
        header_flags=$(bash "$SCRIPT_DIR/resolve-header-paths.sh" "$FILE_PATH" 2>/dev/null || true)
    fi

    local clang_script="$PLUGIN_DIR/scripts/clang-extract-methods.py"
    if [[ ! -f "$clang_script" ]]; then
        echo "# clang-extract-methods.py not found" >&2
        return 1
    fi

    # Run clang AST → JSONL extraction
    eval clang -Xclang -ast-dump=json -fsyntax-only \
        $header_flags \
        -fmodules \
        "$FILE_PATH" 2>/dev/null \
        | python3 "$clang_script" 2>/dev/null
}

if [[ "$LANGUAGE" == "objc" || "$LANGUAGE" == "objcpp" || "$LANGUAGE" == "swift" ]]; then
    CLANG_METHODS_JSON=$(extract_clang_methods 2>/dev/null || true)
fi

# --- Language-specific zone marker detection ---

detect_markers_objc() {
    # #pragma mark - Section Name  or  #pragma mark Section Name
    grep -n '#pragma mark' "$FILE_PATH" | sed 's/#pragma mark -\{0,1\} *//' | while IFS=: read -r line rest; do
        # Clean up the marker name
        name=$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        echo "${line}:${name}"
    done
}

detect_markers_swift() {
    # // MARK: - Section  or  // MARK: Section
    # Also detect extension boundaries
    {
        grep -n '// MARK:' "$FILE_PATH" | sed 's|// MARK: -\{0,1\} *||' | while IFS=: read -r line rest; do
            name=$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            echo "${line}:${name}"
        done
        grep -n '^extension ' "$FILE_PATH" | while IFS=: read -r line rest; do
            name=$(echo "$rest" | sed 's/{.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
            echo "${line}:${name}"
        done
    } | sort -t: -k1 -n
}

detect_markers_typescript() {
    # // #region Name  or  // region Name  or  //#region Name
    {
        grep -n -E '//\s*#?region\s+' "$FILE_PATH" | sed -E 's|//\s*#?region\s+||' | while IFS=: read -r line rest; do
            name=$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            echo "${line}:${name}"
        done
    }
}

detect_markers_go() {
    # Go: detect func boundaries and // --- Section --- style comments
    {
        grep -n -E '^func |^// ---' "$FILE_PATH" | while IFS=: read -r line rest; do
            name=$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/ {$//')
            echo "${line}:${name}"
        done
    }
}

detect_markers_java() {
    # Java: // region, inner class boundaries
    {
        grep -n -E '//\s*region\s+|^\s*(public|private|protected)?\s*(static\s+)?(class|interface|enum)\s+' "$FILE_PATH" | while IFS=: read -r line rest; do
            name=$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/ {$//')
            echo "${line}:${name}"
        done
    }
}

detect_markers_kotlin() {
    # Kotlin: // region, companion object, inner class
    {
        grep -n -E '//\s*region\s+|^\s*(companion\s+object|inner\s+class|object\s+)' "$FILE_PATH" | while IFS=: read -r line rest; do
            name=$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/ {$//')
            echo "${line}:${name}"
        done
    }
}

detect_markers_python() {
    # Python: # --- Section --- style or class definitions
    {
        grep -n -E '^# ---.*---|^class ' "$FILE_PATH" | while IFS=: read -r line rest; do
            name=$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/:$//')
            echo "${line}:${name}"
        done
    }
}

detect_markers_rust() {
    # Rust: // --- Section --- style, impl blocks, mod blocks
    {
        grep -n -E '^// ---.*---|^impl |^mod |^pub mod ' "$FILE_PATH" | while IFS=: read -r line rest; do
            name=$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/ {$//')
            echo "${line}:${name}"
        done
    }
}

# --- Method detection per language ---

detect_methods_objc() {
    local start=$1 end=$2
    sed -n "${start},${end}p" "$FILE_PATH" | grep -c '^[+-] *(' || echo 0
}

detect_methods_swift() {
    local start=$1 end=$2
    sed -n "${start},${end}p" "$FILE_PATH" | grep -cE '^\s*(func |init\(|deinit)' || echo 0
}

detect_methods_typescript() {
    local start=$1 end=$2
    sed -n "${start},${end}p" "$FILE_PATH" | grep -cE '^\s*(async\s+)?(function |.*\(.*\)\s*[:{])' || echo 0
}

detect_methods_generic() {
    local start=$1 end=$2
    sed -n "${start},${end}p" "$FILE_PATH" | grep -cE '^\s*(pub\s+)?(fn |func |def |fun )' || echo 0
}

count_methods() {
    local start=$1 end=$2
    case "$LANGUAGE" in
        objc|objcpp) detect_methods_objc "$start" "$end" ;;
        swift)      detect_methods_swift "$start" "$end" ;;
        typescript|javascript) detect_methods_typescript "$start" "$end" ;;
        *)          detect_methods_generic "$start" "$end" ;;
    esac
}

# --- Dependency detection ---

# ObjC/ObjC++: bracket call syntax + limited singleton dot-syntax
detect_deps_in_range_objc() {
    local start=$1 end=$2
    local noise='self|super|NSString|NSArray|NSDictionary|NSNumber|NSError|NSData|NSURL|NSLog|NSMutableString|NSMutableDictionary|NSMutableArray|NSURLComponents|NSURLQueryItem|NSPredicate|NSFileManager|NSSearchPathForDirectoriesInDomains|NSNotificationCenter|NSBundle|NSDate|NSTimeInterval|NSLocale|NSUUID|NSOperation|NSURLSessionDataTask|NSHTTPURLResponse|NSJSONSerialization|NSURLRequest|BOOL|YES|NO|nil|dispatch_once|dispatch_semaphore_create|dispatch_semaphore_signal|dispatch_semaphore_wait|DISPATCH_TIME_FOREVER|void|id|AnyPromise|PMKResolver|PMKManifold'

    sed -n "${start},${end}p" "$FILE_PATH" \
        | grep -oE '\[([A-Z][A-Za-z0-9_]+) ' \
        | sed 's/\[//;s/ $//' \
        | grep -vE "^(${noise})$" \
        | sort -u

    sed -n "${start},${end}p" "$FILE_PATH" \
        | grep -oE '[A-Z][A-Za-z0-9_]+\.(shared|default|alloc|new|policy)' \
        | sed 's/\..*//' \
        | grep -vE "^(${noise})$" \
        | sort -u
}

# Swift: dot-call syntax, generics, type annotations, conformance lists
detect_deps_in_range_swift() {
    local start=$1 end=$2
    # Swift stdlib + UIKit/SwiftUI/Foundation noise
    local noise='Self|self|super|Any|AnyObject|AnyClass|Type|Void|Never|String|Int|UInt|Int8|Int16|Int32|Int64|UInt8|UInt16|UInt32|UInt64|Bool|Float|Double|Decimal|Character|Array|Dictionary|Set|Optional|Result|Range|ClosedRange|URL|URLRequest|URLSession|URLResponse|HTTPURLResponse|URLSessionTask|URLSessionDataTask|Data|Date|DateComponents|DateFormatter|TimeInterval|Calendar|Locale|TimeZone|UUID|IndexPath|Notification|NotificationCenter|JSONDecoder|JSONEncoder|JSONSerialization|PropertyListEncoder|PropertyListDecoder|FileManager|Bundle|UserDefaults|NSError|NSObject|NSString|NSArray|NSDictionary|NSNumber|NSData|NSDate|NSUUID|NSNotification|NSNotificationCenter|NSIndexPath|UIView|UIViewController|UIColor|UIImage|UIImageView|UILabel|UIButton|UITableView|UITableViewCell|UICollectionView|UICollectionViewCell|UIStackView|UIScrollView|UITextField|UITextView|UISwitch|UISlider|UIAlertController|UINavigationController|UITabBarController|UIWindow|UIScreen|UIApplication|UIStoryboard|UINib|CGFloat|CGPoint|CGSize|CGRect|CGAffineTransform|CATransform3D|Published|State|Binding|ObservedObject|StateObject|EnvironmentObject|Environment|View|Text|VStack|HStack|ZStack|Image|Button|List|NavigationView|NavigationLink|Publisher|AnyPublisher|AnyCancellable|PassthroughSubject|CurrentValueSubject|Just|Empty|Future|Task|TaskGroup|MainActor|Sendable|Error|Codable|Encodable|Decodable|Equatable|Hashable|Comparable|Identifiable|CustomStringConvertible|ExpressibleByStringLiteral|IteratorProtocol|Sequence|Collection|RandomAccessCollection|StringProtocol|BinaryInteger|FloatingPoint|print|debugPrint|assert|precondition|fatalError|true|false|nil'

    # 1. Capitalized.identifier(   → method call on a type
    # 2. Capitalized.shared|default|self|Type  → singleton/type access
    # 3. : Capitalized  → type annotations, conformance
    # 4. -> Capitalized → return type
    # 5. <Capitalized  → generic argument
    # 6. class|struct|enum|extension|protocol Capitalized : Capitalized → inheritance
    (
        # Method calls and type access: X.foo( or X.bar
        sed -n "${start},${end}p" "$FILE_PATH" \
            | grep -oE '\b[A-Z][A-Za-z0-9_]+\.([a-zA-Z_][A-Za-z0-9_]*)' \
            | sed 's/\..*//'

        # Type annotations after colon: `: TypeName` and `: TypeName<...>`
        sed -n "${start},${end}p" "$FILE_PATH" \
            | grep -oE ': [A-Z][A-Za-z0-9_]+' \
            | sed 's/: //'

        # Return types: `-> TypeName`
        sed -n "${start},${end}p" "$FILE_PATH" \
            | grep -oE '-> [A-Z][A-Za-z0-9_]+' \
            | sed 's/-> //'

        # Generic arguments: `<TypeName>` or `<TypeName,` or `<TypeName:`
        sed -n "${start},${end}p" "$FILE_PATH" \
            | grep -oE '<[A-Z][A-Za-z0-9_]+[,>: ]' \
            | sed -E 's/^<//; s/[,>: ]$//'

        # Conformance / inheritance: declaration followed by `: SuperType, P1, P2`
        sed -n "${start},${end}p" "$FILE_PATH" \
            | grep -oE '(class|struct|enum|extension|protocol) [A-Z][A-Za-z0-9_]+' \
            | awk '{print $2}'
    ) \
        | grep -vE "^(${noise})$" \
        | grep -vE '^$' \
        | sort -u
}

detect_deps_in_range() {
    local start=$1 end=$2
    case "$LANGUAGE" in
        objc|objcpp) detect_deps_in_range_objc "$start" "$end" ;;
        swift)       detect_deps_in_range_swift "$start" "$end" ;;
        *)           detect_deps_in_range_objc "$start" "$end" ;;
    esac
}

# --- Main: collect markers and build zone map ---

detect_markers() {
    case "$LANGUAGE" in
        objc|objcpp) detect_markers_objc ;;
        swift)      detect_markers_swift ;;
        typescript|javascript) detect_markers_typescript ;;
        go)         detect_markers_go ;;
        java)       detect_markers_java ;;
        kotlin)     detect_markers_kotlin ;;
        python)     detect_markers_python ;;
        rust)       detect_markers_rust ;;
        *)          echo "" ;;
    esac
}

MARKERS=$(detect_markers)

MARKER_COUNT=$(echo "$MARKERS" | grep -c . || echo 0)

# --- Output YAML ---

echo "# Zone Map: ${FILENAME}"
echo "# Generated by detect-zones.sh"
echo "file: \"${FILE_PATH}\""
echo "language: ${LANGUAGE}"
echo "total_lines: ${TOTAL_LINES}"
echo "marker_count: ${MARKER_COUNT}"

if [[ "$MARKER_COUNT" -eq 0 ]]; then
    echo "zones: []"
    echo "# WARNING: No zone markers found. Claude should use method-clustering fallback."
    exit 0
fi

echo "zones:"

# Build array of line numbers and names
declare -a ZONE_LINES=()
declare -a ZONE_NAMES=()

while IFS=: read -r line name; do
    [[ -z "$line" ]] && continue
    ZONE_LINES+=("$line")
    ZONE_NAMES+=("$name")
done <<< "$MARKERS"

ZONE_COUNT=${#ZONE_LINES[@]}

for i in $(seq 0 $((ZONE_COUNT - 1))); do
    start=${ZONE_LINES[$i]}
    if [[ $i -lt $((ZONE_COUNT - 1)) ]]; then
        end=$((${ZONE_LINES[$((i + 1))]} - 1))
    else
        end=$TOTAL_LINES
    fi

    name="${ZONE_NAMES[$i]}"
    # Trim whitespace; fall back to "Zone N (unnamed)" for blank markers
    name="$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$name" ]] && name="Zone $((i + 1)) (unnamed)"

    line_count=$((end - start + 1))
    method_count=$(count_methods "$start" "$end")

    # Slugify the name for zone_id; fall back to zone-N for non-ASCII names
    zone_id=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
    [[ -z "$zone_id" ]] && zone_id="zone-$((i + 1))"

    echo "  - id: \"${zone_id}\""
    echo "    name: \"${name}\""
    echo "    lines: [${start}, ${end}]"
    echo "    line_count: ${line_count}"
    echo "    method_count: ${method_count}"

    # Collect dependencies
    deps=$(detect_deps_in_range "$start" "$end" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    if [[ -n "$deps" ]]; then
        echo "    deps: [$(echo "$deps" | sed 's/,/, /g')]"
    else
        echo "    deps: []"
    fi
done

# --- Layer 2/3: Clang AST method details (if available) ---

if [[ -n "$CLANG_METHODS_JSON" ]]; then
    echo ""
    echo "# Layer 2/3: Method implementations from clang AST (compiler-accurate)"
    echo "methods:"
    echo "$CLANG_METHODS_JSON" | python3 -c "
import json, sys

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    m = json.loads(line)
    name = m['name']
    kind = m['kind']
    start = m['start']
    end = m['end']
    sends = m['sends']
    line_count = end - start + 1

    print(f'  - name: \"{kind}[{name}]\"')
    print(f'    lines: [{start}, {end}]')
    print(f'    line_count: {line_count}')
    if sends:
        # Show up to 20 most interesting sends (skip common Foundation selectors)
        noise = {'alloc','init','mutableCopy','copy','class','isKindOfClass:',
                 'stringWithFormat:','isEqual:','isEqualToString:',
                 'objectForKeyedSubscript:','setObject:forKeyedSubscript:',
                 'dataUsingEncoding:','length','count'}
        interesting = [s for s in sends if s not in noise]
        if interesting:
            items = ', '.join(f'\"{s}\"' for s in interesting[:20])
            print(f'    sends: [{items}]')
            print(f'    send_count: {len(sends)}')
        else:
            print(f'    sends: []')
            print(f'    send_count: {len(sends)}')
    else:
        print(f'    sends: []')
        print(f'    send_count: 0')
" 2>/dev/null
else
    echo ""
    echo "# Layer 2/3: clang AST not available (grep fallback in zone deps above)"
fi
