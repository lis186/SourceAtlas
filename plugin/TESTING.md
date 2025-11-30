# Testing Guide

How to test the SourceAtlas Plugin locally before publishing.

## Prerequisites

- Claude Code installed and running
- Access to a test project (any codebase to analyze)

## Quick Start

### 1. Create Test Marketplace

```bash
# Create a temporary marketplace directory
mkdir -p ~/sourceatlas-test-marketplace

# Copy the plugin to the marketplace
cp -r ***REMOVED***/plugin ~/sourceatlas-test-marketplace/sourceatlas-plugin

# Verify structure
ls -la ~/sourceatlas-test-marketplace/sourceatlas-plugin/
# Should see:
# .claude-plugin/
# commands/
# README.md
# LICENSE
# CHANGELOG.md
```

### 2. Add Test Marketplace to Claude Code

Open Claude Code and run:

```
/plugin marketplace add file://***REMOVED***/sourceatlas-test-marketplace
```

Expected output: Marketplace added successfully

### 3. Install the Plugin

```
/plugin install sourceatlas-plugin@sourceatlas-test-marketplace
```

Expected output: Plugin installed successfully

### 4. Verify Installation

```
/help
```

Look for `/atlas.pattern` in the commands list. It should show:
```
/atlas.pattern - Learn design patterns from the current codebase (user)
```

### 5. Test the Command

Navigate to any project and run:

```bash
cd ~/any-project
/atlas.pattern "api endpoint"
```

## Test Cases

### Test Case 1: Basic Pattern Detection

**Project:** Next.js/React project
**Command:** `/atlas.pattern "api endpoint"`

**Expected behavior:**
- Should detect Next.js API routes
- Should find files in `pages/api/` or `app/api/`
- Should show standard Next.js API route pattern
- Should provide actionable implementation steps

### Test Case 2: Background Jobs

**Project:** Rails or Laravel project
**Command:** `/atlas.pattern "background job"`

**Expected behavior:**
- Should find job/worker files
- Should explain job queue system
- Should show how to enqueue jobs

### Test Case 3: Generic Search

**Project:** Any project
**Command:** `/atlas.pattern "authentication"`

**Expected behavior:**
- Should find auth-related files
- Should explain auth flow
- Should show middleware/guards

### Test Case 4: No Results

**Project:** Minimal project with no relevant files
**Command:** `/atlas.pattern "payment processing"`

**Expected behavior:**
- Should gracefully handle no results
- Should suggest closest matches or related patterns

## Iteration Workflow

When you make changes to the plugin:

```bash
# 1. Uninstall current version
/plugin uninstall sourceatlas-plugin@sourceatlas-test-marketplace

# 2. Update files
# Edit plugin/commands/atlas.pattern.md or other files

# 3. Copy updated plugin to test marketplace
cp -r ***REMOVED***/plugin ~/sourceatlas-test-marketplace/sourceatlas-plugin

# 4. Reinstall
/plugin install sourceatlas-plugin@sourceatlas-test-marketplace

# 5. Test again
cd ~/test-project
/atlas.pattern "your test query"
```

## Testing Checklist

Before publishing, verify:

- [ ] Plugin installs without errors
- [ ] `/atlas.pattern` appears in `/help`
- [ ] Command accepts arguments correctly
- [ ] Works in JavaScript/TypeScript project
- [ ] Works in Python project
- [ ] Works in Ruby project
- [ ] Works in PHP project (if available)
- [ ] Handles "no results" gracefully
- [ ] Output format is consistent
- [ ] File paths are correct and clickable
- [ ] Inline bash commands execute correctly
- [ ] No external script dependencies
- [ ] README instructions are accurate
- [ ] plugin.json metadata is correct

## Test Projects

Good test projects to use:

1. **Next.js project** - Tests API routes, React patterns
2. **Express.js project** - Tests REST API patterns
3. **Rails project** - Tests MVC, background jobs, ActiveRecord
4. **Laravel project** - Tests PHP patterns, Eloquent
5. **Django project** - Tests Python patterns, views, ORM

## Common Issues

### Issue: Plugin not found after adding marketplace

**Solution:** Check the marketplace path is correct:
```bash
ls -la ~/sourceatlas-test-marketplace/sourceatlas-plugin/.claude-plugin/plugin.json
```

### Issue: Command not appearing in /help

**Solution:**
1. Verify `description` field exists in command frontmatter
2. Reinstall the plugin
3. Restart Claude Code

### Issue: Inline bash commands not executing

**Solution:**
1. Check `allowed-tools` includes `Bash`
2. Verify `!` prefix is used correctly: `!`command``
3. Test bash commands manually in terminal first

### Issue: "Permission denied" errors

**Solution:**
1. Check file permissions: `chmod +r plugin/commands/*.md`
2. Verify marketplace directory is readable

## Advanced Testing

### Test with Different Claude Code Settings

1. Test with minimal context window
2. Test with different allowed-tools restrictions
3. Test with `.claude/settings.json` configurations

### Performance Testing

```bash
# Time the command execution
time /atlas.pattern "api endpoint"
```

Should complete in <10 seconds for most projects.

### Edge Cases

- Empty project (no code files)
- Very large project (>100k files)
- Non-standard project structure
- Mixed-language project
- Monorepo with multiple apps

## Debugging

### Enable Verbose Output

If you need to debug, add temporary logging to the command:

```markdown
## Context

DEBUG: Arguments received: $ARGUMENTS
DEBUG: PWD: !`pwd`
DEBUG: File count: !`find . -type f | wc -l`
```

### Check Claude Code Logs

```bash
# Location varies by OS
# macOS: ~/Library/Logs/Claude Code/
# Linux: ~/.config/claude-code/logs/
```

## Next Steps

Once testing is complete:

1. ✅ All test cases pass
2. ✅ README is accurate
3. ✅ No external dependencies
4. ✅ Works across different project types
5. → Ready to publish to GitHub
6. → Create public marketplace
7. → Share with community

---

Happy testing! 🧪
