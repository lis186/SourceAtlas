---
description: Extract behavior contracts from legacy code using multi-LLM cross-validation
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "<file-path> [--language objc|swift|typescript|javascript] [--force]"
---

# SourceAtlas: Contract Audit

## Context

**Audit Target**: $ARGUMENTS

## Your Task

Execute the contract audit pipeline as defined in [plugin/commands/audit/SKILL.md](../../plugin/commands/audit/SKILL.md).

Follow the complete workflow in [plugin/commands/audit/workflow.md](../../plugin/commands/audit/workflow.md).

### Quick Reference

1. Parse arguments (file path + language)
2. Check cache in `.sourceatlas/audit/`
3. Check environment (gemini, codex CLIs)
4. Execute pipeline via `proposals/contract-audit/pipeline/run-baseline.sh`
5. Verify output via [plugin/commands/audit/verification-guide.md](../../plugin/commands/audit/verification-guide.md)
6. Auto-save to `.sourceatlas/audit/`

### Output Format

See [plugin/commands/audit/output-template.md](../../plugin/commands/audit/output-template.md).

### If stuck

See [plugin/commands/audit/reference.md](../../plugin/commands/audit/reference.md) for cache, language support, and degraded mode details.
