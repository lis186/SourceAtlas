---
name: impact-analyzer
description: Analyze what code will be affected by changes. Use when user asks "what will break if I change X", "impact of changing X", "dependencies of X", "is it safe to modify X", or before making significant code changes.
---

# Impact Analyzer

## When to Use

Trigger this skill when the user:
- Is about to modify code and wants to know the impact
- Asks what depends on a file or component
- Wants to understand breaking change risks
- Asks "what will break if I change X"
- Asks "is it safe to modify this"

## Instructions

1. Identify the file, component, or API the user wants to change
2. Run `/sourceatlas:impact "<target>"` with the target
3. Returns dependency analysis, risk assessment, and migration checklist

## Target Formats

- File path: `/sourceatlas:impact "src/api/users.ts"`
- API endpoint: `/sourceatlas:impact "api /api/users/{id}"`
- Component: `/sourceatlas:impact "UserService"`
- Model: `/sourceatlas:impact "User model"`

## What User Gets

- Impact summary (backend, frontend, test files affected)
- Risk level assessment (red/yellow/green)
- Breaking change risks
- Migration checklist
- Test coverage gaps

## Example Triggers

- "What happens if I change this file?"
- "What depends on UserService?"
- "Is it safe to modify the authentication module?"
- "Impact of changing the User model"
