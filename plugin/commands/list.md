---
description: List saved SourceAtlas analysis results
model: haiku
allowed-tools: Bash
---

# SourceAtlas: List Saved Results

## Your Task

List all saved analysis results in the `.sourceatlas/` directory.

### Step 1: Check directory exists

```bash
ls -la .sourceatlas/ 2>/dev/null || echo "NOT_FOUND"
```

If output contains `NOT_FOUND` or directory is empty:

```
📁 No saved analyses yet

Use the `--save` parameter to save analysis results:
- `/sourceatlas:overview --save`
- `/sourceatlas:pattern "api" --save`
- `/sourceatlas:history --save`
```

End.

### Step 2: List all files with details

```bash
find .sourceatlas -type f -exec ls -lh {} \; 2>/dev/null | sort
```

### Step 3: Format output

Format results into a table, calculate days since modification, and mark expired status (>30 days):

```
📁 .sourceatlas/ saved analyses:

| Type | File | Size | Modified | Status |
|------|------|------|----------|--------|
| overview | overview.yaml | 2.3 KB | 3 days ago | ✅ |
| pattern | patterns/api.md | 1.5 KB | 45 days ago | ⚠️ |
| pattern | patterns/repository.md | 2.1 KB | 5 days ago | ✅ |
| history | history.md | 4.2 KB | 60 days ago | ⚠️ |
| flow | flows/checkout.md | 3.1 KB | 2 days ago | ✅ |
| impact | impact/user-model.md | 1.8 KB | 4 days ago | ✅ |
| deps | deps/react.md | 2.5 KB | 6 days ago | ✅ |

📊 Stats: 7 cached, 2 expired (>30 days)

💡 Tips:
- Clear cache: `/sourceatlas:clear`
- Clear specific type: `/sourceatlas:clear patterns`
```

### Step 4: List expired items with refresh commands

If there are expired items (>30 days), output copyable re-analysis commands:

```
⚠️ Expired items (recommend re-analysis):

| File | Days | Re-analyze Command |
|------|------|-------------------|
| patterns/api.md | 45 days | `/sourceatlas:pattern "api" --force --save` |
| history.md | 60 days | `/sourceatlas:history --force --save` |

💡 Copy the commands above to re-analyze
```

**Command generation rules**:

| Type | Command Format |
|------|----------------|
| overview | `/sourceatlas:overview --force --save` |
| overview-{dir} | `/sourceatlas:overview {dir} --force --save` |
| patterns/{name}.md | `/sourceatlas:pattern "{name}" --force --save` |
| history.md | `/sourceatlas:history --force --save` |
| flows/{name}.md | `/sourceatlas:flow "{name}" --force --save` |
| impact/{name}.md | `/sourceatlas:impact "{name}" --force --save` |
| deps/{name}.md | `/sourceatlas:deps "{name}" --force --save` |

**Note**: Convert `-` in filenames back to spaces for parameters (e.g., `api-endpoint.md` → `"api endpoint"`)

---

## Type Detection Rules

| File Path | Type |
|-----------|------|
| `overview.yaml` or `overview-*.yaml` | overview |
| `patterns/*.md` | pattern |
| `flows/*.md` | flow |
| `history.md` | history |
| `impact/*.md` | impact |
| `deps/*.md` | deps |
