# find-patterns.sh 修復報告

**日期**: 2025-12-21
**版本**: v2.9.6 → v2.9.7 (pending)

## 問題發現

在 `/atlas.pattern` benchmark 測試中發現三個問題：

| # | 問題 | 影響 | 嚴重度 |
|---|------|------|--------|
| 1 | `*Store.swift` 太寬泛 | Firefox iOS viewmodel 80% precision | 中 |
| 2 | 測試目錄未排除 | Prefect model/api 30-50% precision | 高 |
| 3 | Help message 不完整 | Ruby/Go/Rust 顯示 Swift patterns | 低 |

## 5 Why 根因分析

### 問題 1: `*Store.swift` 太寬泛

- **Why 1**: TabSessionStore.swift 被返回
- **Why 2**: file pattern 包含 `*Store.swift`
- **Why 3**: 設計上把 Store 視為類似 ViewModel（TCA 架構）
- **Why 4**: TabDataStore 目錄名包含 `Store` → 加 8 分
- **根源**: `*Store.swift` 會匹配 DataStore、SessionStore 等非 ViewModel

### 問題 2: 測試目錄未排除

- **Why 1**: `test_workers.py` 被返回
- **Why 2**: 在 `tests/server/models/` 目錄下
- **Why 3**: dir_patterns `"models"` 是 substring match
- **Why 4**: 排除規則不包含 `tests/`
- **根源**: 非 test pattern 應自動排除測試目錄

### 問題 3: Help message 不完整

- **Why 1**: Discourse (ruby) 顯示 Swift patterns
- **Why 2**: 進入 `else` 分支
- **Why 3**: main() 只有 android/typescript/python 三個分支
- **根源**: 語言擴充時遺漏 ruby/go/rust 分支

## 修復內容

### 修復 1: 移除寬泛的 Store 匹配

```diff
- echo "*ViewModel.swift ... *Store.swift ..."
+ echo "*ViewModel.swift *ViewModel.m *ViewModel.h *VM.swift *VM.m *VM.h"
```

位置: Line 765-768, 1503-1505

### 修復 2: 動態排除測試目錄

```bash
# 判斷是否為測試相關 pattern
local is_test_pattern=false
case "$normalized" in
    "test"|"tests"|"testing"|"mock"|...)
        is_test_pattern=true
        ;;
esac

# 非 test pattern 排除測試目錄
if [ "$is_test_pattern" = false ]; then
    exclude_args+=(
        ! -path "*/tests/*"
        ! -path "*/test/*"
        ! -path "*/spec/*"
        ...
    )
fi
```

位置: Line 1779-1813

### 修復 3: 新增 Ruby/Go/Rust help message

新增三個 elif 分支顯示對應語言的 patterns。

位置: Line 1712-1799

## 驗證結果

| 專案 | Pattern | 修復前 | 修復後 |
|------|---------|--------|--------|
| Firefox iOS | viewmodel | 80% | **100%** |
| Prefect | model | 50% | **100%** |
| Prefect | api | 30% | **100%** |
| Discourse | help msg | Swift | **Ruby** |

**平均 Precision: 78.6% → 98.6%**

## 影響檔案

- `scripts/atlas/find-patterns.sh` (via symlink: `~/.claude/scripts/atlas/find-patterns.sh`)

## 後續建議

1. 考慮增加更精確的目錄匹配（完整路徑段落 vs substring）
2. 對其他語言進行類似的 pattern 精確度測試
