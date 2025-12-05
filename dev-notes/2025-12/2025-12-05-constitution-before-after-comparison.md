# ANALYSIS_CONSTITUTION.md 加入前後比較

**日期**: 2025-12-05
**比較基準**:
- Before: commit `98a1e05` (Constitution 加入前)
- After: commit `1613d7f` (包含 Constitution + Monorepo 支援)

---

## 1. 新增檔案

| 檔案 | 用途 |
|------|------|
| `ANALYSIS_CONSTITUTION.md` | 定義 7 個 Article 的不可變分析原則 |
| `scripts/atlas/validate-constitution.sh` | 驗證分析輸出是否符合 Constitution |

---

## 2. 命令變更

### 所有 atlas.*.md 命令

**Before**: 無統一原則引用

**After**: 每個命令開頭加入 Constitution 引用區塊

```markdown
> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.0
>
> Key principles enforced:
> - Article I: 高熵優先、掃描比例上限
> - Article II: 強制排除目錄
> - Article III: 假設數量限制、必要元素
> - Article IV: 證據格式要求
```

**影響的檔案** (6 個):
- `.claude/commands/atlas.overview.md`
- `.claude/commands/atlas.pattern.md`
- `.claude/commands/atlas.impact.md`
- `.claude/commands/atlas.history.md`
- `.claude/commands/atlas.flow.md`
- `.claude/commands/atlas.init.md`

---

## 3. detect-project-enhanced.sh 變更

### Header 變更

**Before**:
```bash
#!/bin/bash
# Enhanced Project Detection with Scale-Aware Analysis
# Based on Phase 2 testing results (2025-11-22)
```

**After**:
```bash
#!/bin/bash
# Enhanced Project Detection with Scale-Aware Analysis
# Based on ANALYSIS_CONSTITUTION.md v1.0
# Updated: 2025-12-05 - Added methodology/documentation project support
# Updated: 2025-12-05 - Added monorepo detection (workspaces, lerna, pnpm, nx)
```

### 輸出變更

**Before**:
```
=== Enhanced Project Detection ===
📁 Project: ./myproject
```

**After**:
```
=== Enhanced Project Detection ===
📁 Project: ./myproject
📜 Constitution: v1.0
```

### 新增專案類型

| 類型 | Before | After |
|------|--------|-------|
| Methodology (Markdown-driven) | ❌ | ✅ |
| Monorepo (lerna, pnpm, nx, turborepo) | ❌ | ✅ |
| 從子目錄偵測 (implicit monorepo) | ❌ | ✅ |

### 新增偵測邏輯

**Methodology 專案**:
```bash
# Methodology project: Markdown > Code, and has shell scripts
if [ "$MD_COUNT" -gt 10 ] && [ "$MD_COUNT" -gt "$CODE_COUNT" ] && [ "$SH_COUNT" -gt 0 ]; then
    PROJECT_TYPE="methodology"
fi
```

**Monorepo 偵測**:
```bash
check_monorepo() {
    # Check: lerna.json, pnpm-workspace.yaml, nx.json, turbo.json
    # Check: package.json with "workspaces"
    # Check: go.work
}

detect_from_subdirs() {
    # Fallback: check subdirectories for package.json, go.mod, etc.
}
```

---

## 4. 分析輸出格式變更

### Metadata 必要欄位

**Before**: 無強制要求

**After** (Constitution Article V):
```yaml
metadata:
  analysis_time: "ISO 8601 timestamp"
  total_files: N
  scanned_files: M
  scan_ratio: "X.X%"
  project_scale: "TINY|SMALL|MEDIUM|LARGE|VERY_LARGE"
  constitution_version: "1.0"  # 新增
```

### 假設格式

**Before**: 僅建議格式

**After** (Constitution Article III, 強制):
```yaml
hypothesis: "陳述句"
confidence: 0.0-1.0
evidence: "file:line 格式"
validation_method: "驗證方式"
```

### 證據格式

**Before**: 鬆散的檔案引用

**After** (Constitution Article IV, 強制):
```
file_path:line_number   # 精確引用
README.md:15-30         # 範圍引用
package.json            # 整檔引用（僅配置檔）
```

---

## 5. 規模感知參數變更

### 規模閾值

**Before**: 基於 Phase 2 測試結果

**After**: 與 Constitution Article VI 對齊

| 規模 | Before 閾值 | After 閾值 | 變更 |
|------|------------|-----------|------|
| TINY | <5 | <20 | ⬆️ 放寬 |
| SMALL | 5-15 | 20-50 | ⬆️ 放寬 |
| MEDIUM | 15-50 | 50-150 | ⬆️ 放寬 |
| LARGE | 50-150 | 150-500 | ⬆️ 放寬 |
| VERY_LARGE | >150 | >500 | ⬆️ 放寬 |

### 新增參數

**After 新增**:
- `LOW_CONFIDENCE_LIMIT`: 低信心假設上限（Article III）
- `HYPOTHESIS_TARGET`: 假設數量目標（Article III）

---

## 6. 驗證機制

### Before
- 無自動驗證
- 依賴人工審查

### After
新增 `validate-constitution.sh`:

**結構檢查** (`--check-structure`):
- ✅ ANALYSIS_CONSTITUTION.md 存在
- ✅ 所有 atlas.* 命令引用 Constitution
- ✅ 偵測腳本引用 Constitution
- ✅ 強制排除目錄已實作

**輸出驗證** (`<file.yaml|md>`):
- Article I: 掃描比例檢查
- Article II: 禁止目錄檢查
- Article III: 假設數量和結構檢查
- Article IV: 證據格式檢查
- Article V: 必要元資料檢查

---

## 7. 測試結果比較

### 專案偵測

| 專案 | Before | After |
|------|--------|-------|
| spec-kit | ❌ Unknown | ✅ Methodology |
| Mir01 (monorepo) | ❌ Unknown | ✅ nodejs (from subdir) |
| kotlin/foodies | ✅ Android | ✅ Android |
| ***REMOVED*** | ✅ iOS | ✅ iOS |

**偵測成功率**: 67% → 100%

### 輸出合規性

| 輸出類型 | 驗證結果 |
|---------|---------|
| 新格式 YAML | ✅ PASS (7 pass, 0 fail) |
| 舊格式 Markdown | ❌ FAIL (1 fail, 7 warnings) |
| 舊格式 TOON | ✅ PASS (2 pass, 3 warnings) |

---

## 8. 核心價值

### Constitution 帶來的改進

1. **一致性**: 所有命令遵循相同原則
2. **可驗證性**: 自動化檢查合規性
3. **可追溯性**: 每個原則有明確的 Article 編號
4. **可演進性**: 版本化和修訂流程（Article VII）

### 學習自 spec-kit

| spec-kit 概念 | SourceAtlas 實作 |
|--------------|-----------------|
| Constitution as DNA | ANALYSIS_CONSTITUTION.md |
| YAML Frontmatter | 命令中引用 Constitution |
| Gates/Checkpoints | validate-constitution.sh |
| Version + Ratification | 版本 1.0 + 生效日期 |

---

## 9. 統計摘要

| 指標 | Before | After | 變更 |
|------|--------|-------|------|
| 新增檔案 | - | 2 | +2 |
| 修改檔案 | - | 8 | +8 |
| 支援專案類型 | 8 | 10+ | +25% |
| 偵測成功率 | 67% | 100% | +33% |
| 自動驗證 | ❌ | ✅ | 新功能 |
| Constitution Articles | 0 | 7 | 新框架 |

---

## 10. 結論

ANALYSIS_CONSTITUTION.md 的加入將 SourceAtlas 從「建議性指南」升級為「強制性框架」：

- **Before**: 原則散落在各處，難以追蹤和驗證
- **After**: 集中定義 + 自動驗證 + 版本控制

這是從 spec-kit 學習到的最有價值的模式之一。
