---
description: Guided legacy code migration using the 13-step Playbook (Steps 1-7 tool-assisted)
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "<file-path> [--zone <zone-id>] [--step <1-7>] [--zones-only] [--status] [--force]"
---

# SourceAtlas: Refactor

## Context

**Refactor Target**: $ARGUMENTS

## Your Task

Execute the Playbook Navigator as defined in [plugin/commands/refactor/SKILL.md](../../plugin/commands/refactor/SKILL.md).

Follow the complete workflow in [plugin/commands/refactor/workflow.md](../../plugin/commands/refactor/workflow.md).

### Quick Reference

1. Parse arguments (file path + language + flags)
2. Initialize or load state from `.sourceatlas/refactor/{module}/state.yaml`
3. Execute steps sequentially (or resume from `--step`)
4. Each step reads previous artifact, produces new artifact
5. Step 7 is a hard gate — all tests must pass
6. Output Steps 8-13 guidance after gate passes

### Language Groups

See [plugin/commands/seam/references/language-groups.md](../../plugin/commands/seam/references/language-groups.md) for dispatch rules.

### If stuck

See [plugin/commands/refactor/references/playbook-overview.md](../../plugin/commands/refactor/references/playbook-overview.md) for the full 13-step overview.
