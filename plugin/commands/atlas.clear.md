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
        echo "$dir/: $count 個檔案"
    fi
done
```

### Step 2: Report findings

List what will be deleted based on target:
- If no argument or "all": list everything
- If specific target (e.g., "patterns"): list only that

Example output:
```
找到以下已儲存的分析：
- overview.yaml (2025-12-12)
- patterns/ (3 個檔案)
- history.md (2025-12-11)

確定要刪除嗎？
```

### Step 3: Wait for confirmation

Ask user to confirm. Do NOT proceed without explicit confirmation.

Acceptable confirmations:
- "好"
- "是"
- "確定"
- "yes"
- "ok"
- "刪除"
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
✅ 已清空 [target or ".sourceatlas/"]
```

---

## If nothing to clear

```
.sourceatlas/ 目錄不存在或已經是空的
```

---

## Target Reference

| Target | Path | Description |
|--------|------|-------------|
| `overview` | `.sourceatlas/overview.yaml` | 專案概覽 |
| `patterns` | `.sourceatlas/patterns/` | Pattern 分析 |
| `flows` | `.sourceatlas/flows/` | 流程分析 |
| `history` | `.sourceatlas/history.md` | 時序分析 |
| `impact` | `.sourceatlas/impact/` | 影響分析 |
| `deps` | `.sourceatlas/deps/` | 依賴分析 |
| (no argument) | `.sourceatlas/*` | 全部清空 |
