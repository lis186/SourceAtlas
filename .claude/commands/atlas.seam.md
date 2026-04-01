---
description: Discover responsibility zones and seams in large files to narrow scope before contract audit
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "<file-path> [--language objc|swift|typescript|javascript|go|java|kotlin|python|rust] [--force]"
---

# SourceAtlas: Seam Discovery

## Context

**Target**: $ARGUMENTS

## Your Task

Execute the Seam Discovery analysis as defined in [SKILL.md](/Users/justinlee/dev/sourceatlas2/plugin/commands/seam/SKILL.md).

Follow the complete workflow in [workflow.md](/Users/justinlee/dev/sourceatlas2/plugin/commands/seam/workflow.md).

### Quick Reference

1. Parse arguments (file path + language + `--force`)
2. Check cache in `.sourceatlas/seam/`
3. Run `detect-zones.sh` to get raw zone map
4. Cluster by responsibility, rank by complexity × coupling
5. Present zones with copy-pasteable `/atlas.audit --zone <id>` commands

### Language Groups

See [language-groups.md](/Users/justinlee/dev/sourceatlas2/plugin/commands/seam/references/language-groups.md) for dispatch rules.

### If stuck

See [SKILL.md](/Users/justinlee/dev/sourceatlas2/plugin/commands/seam/SKILL.md) for full arguments and composability.
