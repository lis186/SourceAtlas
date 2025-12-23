---
name: dependency-analyzer
description: Analyze dependencies for upgrade planning and migration. Use when user asks "upgrade to X", "migrate from X to Y", "what breaks if we upgrade", "iOS 17 migration", "React 18 upgrade", or planning framework/SDK upgrades.
---

# Dependency Analyzer

## When to Use

Trigger this skill when the user:
- Is planning a framework or SDK upgrade
- Wants to know migration effort for version changes
- Asks about deprecated APIs or breaking changes
- Needs to audit usage of a specific library
- Asks "how much work to upgrade X"

## Instructions

1. Identify the upgrade path or library to analyze
2. Run `/sourceatlas:deps "<upgrade>"` with the migration description
3. Returns deprecated APIs, breaking changes, and migration checklist

## Command Formats

- iOS upgrade: `/sourceatlas:deps "iOS 16 → 17"`
- Android: `/sourceatlas:deps "Android API 35"`
- React: `/sourceatlas:deps "React 17 → 18"`
- Python: `/sourceatlas:deps "Python 3.11 → 3.12"`
- Library audit: `/sourceatlas:deps "kotlinx.coroutines"`

## What User Gets

- Phase 0 Rule Confirmation (preview before scanning)
- Required Changes: Removable checks, deprecated APIs
- Modernization Opportunities: New features available
- Usage Summary: All API usage with file:line references
- Third-party compatibility
- Migration Checklist with effort estimates

## Example Triggers

- "We need to upgrade to iOS 17, how much work?"
- "What breaks if we upgrade React to 18?"
- "Plan the Python 3.12 migration"
- "Check our usage of AFNetworking"
- "How hard is the Swift 6 migration?"
