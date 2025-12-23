---
name: pattern-finder
description: Find implementation examples and design patterns in the codebase. Use when user asks "how to implement X", "how does this project do X", "show me examples of X", "where is X implemented", or needs to follow existing code conventions.
---

# Pattern Finder

## When to Use

Trigger this skill when the user:
- Asks how to implement a specific feature
- Wants to see existing implementation examples
- Needs to follow project conventions
- Asks "how does this project do X"
- Asks "show me examples of X"

## Instructions

1. Identify what pattern the user is looking for
2. Run `/sourceatlas:pattern "<pattern>"` with the relevant pattern name
3. Returns best example files with line numbers and implementation guide

## Common Patterns

- API endpoints: `/sourceatlas:pattern "api endpoint"`
- Authentication: `/sourceatlas:pattern "authentication"`
- Database queries: `/sourceatlas:pattern "database query"`
- Background jobs: `/sourceatlas:pattern "background job"`
- File uploads: `/sourceatlas:pattern "file upload"`
- Error handling: `/sourceatlas:pattern "error handling"`
- Validation: `/sourceatlas:pattern "validation"`
- Testing: `/sourceatlas:pattern "unit test"`

## What User Gets

- Best example files with exact line numbers
- Standard implementation flow
- Key conventions to follow
- Common pitfalls to avoid
- Testing patterns

## Example Triggers

- "How do I add a new API endpoint?"
- "Show me how authentication works here"
- "Where can I find examples of database queries?"
- "How does this project handle errors?"
