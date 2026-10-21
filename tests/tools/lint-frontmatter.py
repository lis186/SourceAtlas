#!/usr/bin/env python3
"""Validate YAML frontmatter in SourceAtlas command and skill files."""

from pathlib import Path
import sys

import yaml


def files_to_check(root):
    patterns = (
        "plugin/commands/*/SKILL.md",
        "plugin/skills/*/SKILL.md",
        ".claude/commands/*.md",
    )
    return sorted(
        {path for pattern in patterns for path in root.glob(pattern)},
        key=lambda path: path.relative_to(root).as_posix(),
    )


def validate(path, root):
    relative = path.relative_to(root).as_posix()
    problems = []
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()

    if not lines or lines[0].strip() != "---":
        return [(relative, "missing frontmatter opening ---")]

    closing = next((index for index in range(1, len(lines)) if lines[index].strip() == "---"), None)
    if closing is None:
        return [(relative, "unterminated frontmatter (missing closing ---)")]

    try:
        metadata = yaml.safe_load("\n".join(lines[1:closing]))
    except yaml.YAMLError as error:
        mark = getattr(error, "problem_mark", None)
        line = mark.line + 2 if mark is not None else "?"
        detail = getattr(error, "problem", None) or str(error).splitlines()[0]
        return [(relative, f"YAML parse error at line {line}: {detail}")]

    if not isinstance(metadata, dict):
        problems.append((relative, "frontmatter must parse to a mapping"))
        return problems

    if "argument-hint" in metadata and not isinstance(metadata["argument-hint"], str):
        problems.append((relative, "argument-hint must be a string"))

    description = metadata.get("description")
    if not isinstance(description, str) or not description.strip():
        problems.append((relative, "description must exist and be a non-empty string"))

    if path.name == "SKILL.md":
        name = metadata.get("name")
        if not isinstance(name, str) or not name.strip():
            problems.append((relative, "name must exist and be a non-empty string"))
    # Claude Code derives command names from filenames, so .claude command name is optional.
    elif "name" in metadata and not isinstance(metadata["name"], str):
        problems.append((relative, "name must be a string when present"))

    return problems


def main():
    if len(sys.argv) > 2:
        print("usage: lint-frontmatter.py [repo-root]", file=sys.stderr)
        return 2
    root = Path(sys.argv[1] if len(sys.argv) == 2 else Path.cwd()).resolve()
    paths = files_to_check(root)
    if not paths:
        print(f"error: no frontmatter files found under {root}", file=sys.stderr)
        return 2
    failures = [problem for path in paths for problem in validate(path, root)]
    for path, reason in failures:
        print(f"{path}: {reason}")
    failed_files = len({path for path, _ in failures})
    print(f"{len(paths)} files checked, {failed_files} files failed ({len(failures)} problems)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
