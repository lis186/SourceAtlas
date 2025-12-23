---
name: history-analyzer
description: Analyze git history for hotspots, coupling, and knowledge distribution. Use when user asks "who knows this code", "what files change most", "hotspots", "bus factor", "knowledge silos", or needs to understand code evolution.
---

# History Analyzer

## When to Use

Trigger this skill when the user:
- Wants to find code hotspots (frequently changed files)
- Needs to identify who knows specific code areas
- Asks about bus factor or knowledge distribution
- Wants to find hidden coupling between files
- Asks "who should I ask about X"

## Instructions

1. Run `/sourceatlas:history` for the entire repo, or `/sourceatlas:history <path>` for specific directory
2. Optionally specify time range: `/sourceatlas:history . 6` for last 6 months
3. Returns hotspots, coupling analysis, and contributor distribution

## Command Formats

- Full repo: `/sourceatlas:history`
- Specific directory: `/sourceatlas:history src/`
- With time range: `/sourceatlas:history . 6` (last 6 months)

## What User Gets

- Hotspots: Files with most changes (complexity indicators)
- Temporal Coupling: Files that always change together (hidden dependencies)
- Recent Contributors: Who knows what areas
- Bus Factor Risk: Single-contributor files
- Priority actions for refactoring

## Example Triggers

- "What are the hotspots in this codebase?"
- "Who knows the payment module best?"
- "What files always change together?"
- "Is there any bus factor risk?"
- "Show me knowledge distribution"
