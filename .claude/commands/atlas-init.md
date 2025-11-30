---
description: Initialize SourceAtlas in current project - inject auto-trigger rules into CLAUDE.md
allowed-tools: Read, Write, Edit, Glob
---

# SourceAtlas: Project Initialization

## Purpose

Inject SourceAtlas auto-trigger rules into the project's CLAUDE.md so you (Claude Code)
know when to automatically suggest using Atlas commands.

---

## Your Task

### Step 1: Check Current State

First, check if CLAUDE.md exists and if SourceAtlas is already configured:

```bash
# Check for CLAUDE.md in project root
ls -la CLAUDE.md 2>/dev/null || echo "CLAUDE.md does not exist"
```

If CLAUDE.md exists, read it to check for existing SourceAtlas configuration:
- Look for `## SourceAtlas` or `# SourceAtlas` section
- If found, inform user that SourceAtlas is already configured and stop

### Step 2: Prepare the Content to Inject

Use the following content block (in English):

```markdown
---

## SourceAtlas Auto-Trigger Rules

When encountering these situations, automatically execute the corresponding command:

| User Intent | Command |
|-------------|---------|
| "What is this project", "Help me understand the codebase", "I'm new to this project" | `/atlas-overview` |
| "How does this project implement X", "Learn the pattern for Y", "Show me examples of Z" | `/atlas-pattern [pattern]` |
| "What will this change affect", "Impact of modifying X", "Dependencies of Y" | `/atlas-impact [target]` |
| User just joined project and seems unfamiliar with codebase structure | `/atlas-overview` |

### When NOT to auto-trigger

- User is asking about a specific file they already know
- User is doing routine coding tasks
- User explicitly says they don't need overview/analysis

### Available Commands Reference

- `/atlas-overview [dir]` - Quick project fingerprint (<5% file scan, 70-80% understanding)
- `/atlas-pattern [type]` - Learn how this codebase implements specific patterns
- `/atlas-impact [target]` - Analyze impact scope of code changes
```

### Step 3: Apply Changes

**If CLAUDE.md exists:**
1. Append the content block to the end of the file
2. Report success

**If CLAUDE.md does not exist:**
1. Create a new CLAUDE.md with this template:

```markdown
# CLAUDE.md

This file provides guidance for Claude Code when working with this codebase.

## Project Overview

[Brief description of the project - to be filled in]

## SourceAtlas Auto-Trigger Rules

When encountering these situations, automatically execute the corresponding command:

| User Intent | Command |
|-------------|---------|
| "What is this project", "Help me understand the codebase", "I'm new to this project" | `/atlas-overview` |
| "How does this project implement X", "Learn the pattern for Y", "Show me examples of Z" | `/atlas-pattern [pattern]` |
| "What will this change affect", "Impact of modifying X", "Dependencies of Y" | `/atlas-impact [target]` |
| User just joined project and seems unfamiliar with codebase structure | `/atlas-overview` |

### When NOT to auto-trigger

- User is asking about a specific file they already know
- User is doing routine coding tasks
- User explicitly says they don't need overview/analysis

### Available Commands Reference

- `/atlas-overview [dir]` - Quick project fingerprint (<5% file scan, 70-80% understanding)
- `/atlas-pattern [type]` - Learn how this codebase implements specific patterns
- `/atlas-impact [target]` - Analyze impact scope of code changes
```

2. Report that a new CLAUDE.md was created

---

## Output

After completion, provide a summary:

```
✅ SourceAtlas initialized successfully!

Changes made:
- [Created new CLAUDE.md | Updated existing CLAUDE.md]

You can now use these commands in this project:
- /atlas-overview  - Quick project understanding
- /atlas-pattern   - Learn design patterns
- /atlas-impact    - Analyze change impact

Claude Code will now automatically suggest these commands when appropriate.
```

---

## Important Notes

- Always use English for the injected content (international standard)
- Do not duplicate if SourceAtlas section already exists
- Preserve all existing content in CLAUDE.md
- Add a separator (---) before the new section when appending
