#!/usr/bin/env bash
# seam-patterns.sh — Canonical verification_grep generator per language.
#
# Step 3 of the refactor Playbook produces seam candidates, each with a
# `verification_grep` field used by gate-seams.sh. Hand-authored greps
# tend to be ObjC-flavoured (e.g. "initWithBaseURL:") even for Swift
# targets (which use "init(baseURL:"). This helper emits canonical
# patterns so every candidate ships with a grep that actually matches
# its target language.
#
# Usage:
#   seam-patterns.sh <language> <seam_type> <symbol> <file>
#
# Languages: swift | objc | objcpp
# Seam types:
#   object_init      — constructor/initializer seam
#   method_dispatch  — instance method dispatch
#   class_method     — class/static method
#   property_access  — property read/write
#   delegate         — delegate protocol conformance
#   notification     — NotificationCenter subscription
#   extension        — Swift extension or ObjC category on a type
#   protocol         — protocol definition (Swift) / @protocol (ObjC)
#   protocol_adopt   — type adopting a protocol
#   mainactor        — @MainActor / main-thread boundary (Swift)
#
# Outputs ONE line: a shell-executable `grep -qn ...` command suitable
# for the verification_grep field in 3_seams.yaml.
#
set -euo pipefail

LANG_ID="${1:?usage: seam-patterns.sh <lang> <seam_type> <symbol> <file>}"
SEAM_TYPE="${2:?usage: seam-patterns.sh <lang> <seam_type> <symbol> <file>}"
SYMBOL="${3:?usage: seam-patterns.sh <lang> <seam_type> <symbol> <file>}"
FILE="${4:?usage: seam-patterns.sh <lang> <seam_type> <symbol> <file>}"

# Emit a grep command that:
#  - returns 0 if pattern found in file
#  - uses ERE for richer expressions
emit() {
    echo "grep -qnE '$1' '$FILE'"
}

case "$LANG_ID" in
    objc|objcpp)
        case "$SEAM_TYPE" in
            object_init)
                # ObjC init: -(instancetype)initWithX:…
                emit "^-[[:space:]]*\\([^)]*\\)[[:space:]]*init[A-Za-z0-9_]*[[:space:]]*(:|$)"
                ;;
            method_dispatch)
                # [receiver symbol:…] or [receiver symbol]
                emit "\\[[A-Za-z_][A-Za-z0-9_]*[[:space:]]+${SYMBOL}[[:space:]]*(:|\\])"
                ;;
            class_method)
                emit "^\\+[[:space:]]*\\([^)]*\\)[[:space:]]*${SYMBOL}[[:space:]]*(:|$|\\{)"
                ;;
            property_access)
                # @property … SYMBOL or self.SYMBOL or ->SYMBOL
                emit "@property[^;]*[[:space:]]${SYMBOL}[[:space:]]*;|self\\.${SYMBOL}\\b|->${SYMBOL}\\b"
                ;;
            delegate)
                # Protocol conformance in @interface X : Y <SYMBOL, ...>
                emit "@interface [A-Za-z_][A-Za-z0-9_]*[^<]*<[^>]*\\b${SYMBOL}\\b[^>]*>"
                ;;
            notification)
                # addObserver:…name:SYMBOL or postNotificationName:SYMBOL
                emit "(addObserver[^;]*name:[^;]*${SYMBOL}|postNotificationName:[^;]*${SYMBOL})"
                ;;
            extension|category)
                # @interface Type (SYMBOL)
                emit "^@interface [A-Za-z_][A-Za-z0-9_]*[[:space:]]*\\(${SYMBOL}\\)"
                ;;
            protocol)
                emit "^@protocol[[:space:]]+${SYMBOL}\\b"
                ;;
            protocol_adopt)
                emit "@interface [A-Za-z_][A-Za-z0-9_]*[^<]*<[^>]*\\b${SYMBOL}\\b[^>]*>"
                ;;
            *)
                echo "error: unknown seam_type '$SEAM_TYPE' for language '$LANG_ID'" >&2
                exit 2
                ;;
        esac
        ;;

    swift)
        case "$SEAM_TYPE" in
            object_init)
                # init(label: ...) or convenience init or required init
                emit "(^|[[:space:]])(convenience[[:space:]]+|required[[:space:]]+)?init[?!]?\\([A-Za-z_][^)]*\\)"
                ;;
            method_dispatch)
                # func SYMBOL( or instance.SYMBOL(
                emit "(func[[:space:]]+${SYMBOL}[[:space:]]*[<(]|[.]${SYMBOL}[[:space:]]*\\()"
                ;;
            class_method)
                # static func SYMBOL( or class func SYMBOL(
                emit "^[[:space:]]*(static|class)[[:space:]]+func[[:space:]]+${SYMBOL}\\b"
                ;;
            property_access)
                # var/let SYMBOL: or property wrapper use, or .SYMBOL access
                emit "(^[[:space:]]*(private[[:space:]]+|fileprivate[[:space:]]+|internal[[:space:]]+|public[[:space:]]+|open[[:space:]]+)?(var|let)[[:space:]]+${SYMBOL}\\b|[.]${SYMBOL}\\b[[:space:]]*(=|$))"
                ;;
            delegate)
                # Delegate protocol adoption in class/struct decl, or as property type
                emit "(class|struct|extension)[^:]*:[^{]*\\b${SYMBOL}\\b|delegate:[[:space:]]*${SYMBOL}"
                ;;
            notification)
                # NotificationCenter.default.addObserver(…,name:…SYMBOL…) or .post(name:…SYMBOL…)
                emit "NotificationCenter[^;]*(addObserver|post)[^)]*${SYMBOL}"
                ;;
            extension)
                # extension Type { … } or extension Type: Protocol { … }
                # SYMBOL = the type being extended
                emit "^extension[[:space:]]+${SYMBOL}([[:space:]]|:|\\{)"
                ;;
            protocol)
                emit "^(public[[:space:]]+|internal[[:space:]]+)?protocol[[:space:]]+${SYMBOL}\\b"
                ;;
            protocol_adopt)
                # class/struct/enum X: Protocol or X: Foo, Protocol
                emit "(class|struct|enum|extension)[[:space:]]+[A-Z][A-Za-z0-9_]*[^:]*:[^{]*\\b${SYMBOL}\\b"
                ;;
            mainactor)
                # @MainActor on a type, function, or property
                emit "@MainActor\\b"
                ;;
            *)
                echo "error: unknown seam_type '$SEAM_TYPE' for language '$LANG_ID'" >&2
                exit 2
                ;;
        esac
        ;;

    *)
        echo "error: unsupported language '$LANG_ID' (expected: swift|objc|objcpp)" >&2
        exit 2
        ;;
esac
