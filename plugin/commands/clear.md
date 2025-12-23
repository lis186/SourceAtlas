---
description: Clear saved SourceAtlas analysis results
model: haiku
allowed-tools: Bash, Read
argument-hint: (optional) [target: overview|patterns|flows|history|impact|deps]
---

# SourceAtlas: Clear Saved Results

## Context

**Target**: $ARGUMENTS (default: all)

## Your Task

Help user clear saved analysis results from `.sourceatlas/` directory.

### Step 1: Check what exists

```bash
ls -la .sourceatlas/ 2>/dev/null || echo "No .sourceatlas/ directory found"
```

Also check subdirectories:

```bash
# Count files in each subdirectory
for dir in patterns flows impact deps; do
    if [ -d ".sourceatlas/$dir" ]; then
        count=$(ls -1 ".sourceatlas/$dir" 2>/dev/null | wc -l)
        echo "$dir/: $count files"
    fi
done
```

### Step 2: Report findings

List what will be deleted based on target:
- If no argument or "all": list everything
- If specific target (e.g., "patterns"): list only that

Example output:
```
Found the following saved analyses:
- overview.yaml (2025-12-12)
- patterns/ (3 files)
- history.md (2025-12-11)

Are you sure you want to delete?
```

### Step 3: Wait for confirmation

Ask user to confirm. Do NOT proceed without explicit confirmation.

Acceptable confirmations:
- "yes"
- "ok"
- "confirm"
- "delete"
- "sure"
- etc.

### Step 4: Delete if confirmed

Based on target:

```bash
# All (default, no argument)
rm -rf .sourceatlas/*

# Specific targets
rm -f .sourceatlas/overview.yaml    # for "overview"
rm -rf .sourceatlas/patterns/       # for "patterns"
rm -rf .sourceatlas/flows/          # for "flows"
rm -f .sourceatlas/history.md       # for "history"
rm -rf .sourceatlas/impact/         # for "impact"
rm -rf .sourceatlas/deps/           # for "deps"
```

### Step 5: Confirm deletion

```
✅ Cleared [target or ".sourceatlas/"]
```

---

## If nothing to clear

```
.sourceatlas/ directory does not exist or is already empty
```

---

## Target Reference

| Target | Path | Description |
|--------|------|-------------|
| `overview` | `.sourceatlas/overview.yaml` | Project overview |
| `patterns` | `.sourceatlas/patterns/` | Pattern analysis |
| `flows` | `.sourceatlas/flows/` | Flow analysis |
| `history` | `.sourceatlas/history.md` | Temporal analysis |
| `impact` | `.sourceatlas/impact/` | Impact analysis |
| `deps` | `.sourceatlas/deps/` | Dependency analysis |
| (no argument) | `.sourceatlas/*` | Clear all |
