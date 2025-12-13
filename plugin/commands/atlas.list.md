---
description: List saved SourceAtlas analysis results
model: haiku
allowed-tools: Bash
---

# SourceAtlas: List Saved Results

## Your Task

列出 `.sourceatlas/` 目錄中所有已儲存的分析結果。

### Step 1: Check directory exists

```bash
ls -la .sourceatlas/ 2>/dev/null || echo "NOT_FOUND"
```

如果輸出包含 `NOT_FOUND` 或目錄為空：

```
📁 尚無已儲存的分析

使用 `--save` 參數儲存分析結果：
- `/atlas.overview --save`
- `/atlas.pattern "api" --save`
- `/atlas.history --save`
```

結束。

### Step 2: List all files with details

```bash
find .sourceatlas -type f -exec ls -lh {} \; 2>/dev/null | sort
```

### Step 3: Format output

將結果整理成表格，計算距今天數，並標記過期狀態（>30 天）：

```
📁 .sourceatlas/ 已儲存的分析：

| 類型 | 檔案 | 大小 | 修改時間 | 狀態 |
|------|------|------|----------|------|
| overview | overview.yaml | 2.3 KB | 3 天前 | ✅ |
| pattern | patterns/api.md | 1.5 KB | 45 天前 | ⚠️ |
| pattern | patterns/repository.md | 2.1 KB | 5 天前 | ✅ |
| history | history.md | 4.2 KB | 60 天前 | ⚠️ |
| flow | flows/checkout.md | 3.1 KB | 2 天前 | ✅ |
| impact | impact/user-model.md | 1.8 KB | 4 天前 | ✅ |
| deps | deps/react.md | 2.5 KB | 6 天前 | ✅ |

📊 統計：7 個快取，2 個已過期（>30 天）

💡 提示：
- 清空快取：`/atlas.clear`
- 清空特定類型：`/atlas.clear patterns`
```

### Step 4: List expired items with refresh commands

如果有過期項目（>30 天），額外輸出可複製的重新分析命令：

```
⚠️ 過期項目（建議重新分析）：

| 檔案 | 天數 | 重新分析命令 |
|------|------|--------------|
| patterns/api.md | 45 天 | `/atlas.pattern "api" --force --save` |
| history.md | 60 天 | `/atlas.history --force --save` |

💡 複製上方命令即可重新分析
```

**命令生成規則**：

| 類型 | 命令格式 |
|------|----------|
| overview | `/atlas.overview --force --save` |
| overview-{dir} | `/atlas.overview {dir} --force --save` |
| patterns/{name}.md | `/atlas.pattern "{name}" --force --save` |
| history.md | `/atlas.history --force --save` |
| flows/{name}.md | `/atlas.flow "{name}" --force --save` |
| impact/{name}.md | `/atlas.impact "{name}" --force --save` |
| deps/{name}.md | `/atlas.deps "{name}" --force --save` |

**注意**：將檔名中的 `-` 轉回空格作為參數（如 `api-endpoint.md` → `"api endpoint"`）

---

## 類型判斷規則

| 檔案路徑 | 類型 |
|----------|------|
| `overview.yaml` 或 `overview-*.yaml` | overview |
| `patterns/*.md` | pattern |
| `flows/*.md` | flow |
| `history.md` | history |
| `impact/*.md` | impact |
| `deps/*.md` | deps |
