#!/usr/bin/env python3
"""
clang-extract-methods.py — Extract ObjC method implementations from clang AST JSON.

Usage:
    clang -Xclang -ast-dump=json -fsyntax-only file.m 2>/dev/null | python3 clang-extract-methods.py

stdin:  clang AST JSON (from -ast-dump=json)
stdout: JSONL — one JSON object per method implementation:
        {"name": "selector:", "kind": "+|-", "start": 52, "end": 62, "sends": ["alloc", "init"]}

Exit codes:
    0 - success (even if zero methods found)
    1 - JSON parse error
    2 - unexpected AST structure
"""

import json
import sys


def find_sends(node, sends):
    """Recursively collect all ObjC message selectors sent within a node."""
    if node.get("kind") == "ObjCMessageExpr":
        sel = node.get("selector", "")
        if sel:
            sends.append(sel)
    for child in node.get("inner", []):
        find_sends(child, sends)


def extract_methods(impl_node):
    """Extract method implementations from an ObjCImplementationDecl node."""
    methods = []
    for child in impl_node.get("inner", []):
        if child.get("kind") != "ObjCMethodDecl":
            continue

        # Only methods with a CompoundStmt body (= has implementation)
        has_body = any(
            c.get("kind") == "CompoundStmt" for c in child.get("inner", [])
        )
        if not has_body:
            continue

        loc = child.get("loc", {})
        start_line = loc.get("line", loc.get("expansionLoc", {}).get("line"))
        end_line = child.get("range", {}).get("end", {}).get("line")
        name = child.get("name", "?")
        is_class = child.get("storageClass") == "static" or "+" in str(
            child.get("mangledName", "")
        )
        kind = "+" if is_class else "-"

        # Collect message sends
        sends = []
        find_sends(child, sends)
        unique_sends = sorted(set(sends))

        if start_line and end_line:
            methods.append(
                {
                    "name": name,
                    "kind": kind,
                    "start": start_line,
                    "end": end_line,
                    "sends": unique_sends,
                }
            )

    return methods


def walk_for_impls(node):
    """Walk AST to find all ObjCImplementationDecl nodes."""
    if node.get("kind") == "ObjCImplementationDecl":
        yield node
        return
    for child in node.get("inner", []):
        yield from walk_for_impls(child)


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"error: failed to parse clang AST JSON: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(data, dict) or "kind" not in data:
        print("error: unexpected AST structure (no root node)", file=sys.stderr)
        sys.exit(2)

    for impl in walk_for_impls(data):
        for method in extract_methods(impl):
            print(json.dumps(method, ensure_ascii=False))


if __name__ == "__main__":
    main()
