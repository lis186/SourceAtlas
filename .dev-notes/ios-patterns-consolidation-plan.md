# iOS Patterns 整合計劃

**日期**: 2025-11-23
**目標**: 合併 Architecture patterns 到 Tier 1/2，消除重複

---

## 1. 當前狀況 (Before)

**結構**: Tier 1 (10) + Tier 2 (8) + Architecture (16) = **34 patterns**

### Tier 1 Core Patterns (10)
1. protocol / delegate / protocol delegate
2. combine / publisher / combine publisher (⚠️ needs content analysis)
3. async / await / async await / concurrency (⚠️ needs content analysis)
4. repository / repo
5. service / service layer / manager
6. usecase / use case / interactor
7. layout / collection view layout / uicollectionviewlayout
8. factory / builder
9. animation / animator / transition
10. router / route / routing

### Tier 2 Supplementary Patterns (8)
11. observable / observableobject / observable object
12. reducer / tca reducer / state reducer
13. environment / configuration / config
14. cache / caching
15. theme / style / appearance
16. mock / stub / fake / test double
17. middleware / interceptor
18. localization / i18n / l10n

### Architecture Patterns (16) ⚠️ 重複問題
1. api endpoint / api / endpoint ← **重複 `router`**
2. background job / job / queue
3. file upload / upload / file storage
4. database query / database / query ← **部分重複 `repository`**
5. authentication / auth / login
6. swiftui view / view
7. view controller / viewcontroller
8. networking / network ← **重複 `service`**
9. view model / viewmodel / mvvm ← **重複 `observable`**
10. coordinator / navigation coordinator
11. core data / coredata / persistence / data persistence
12. dependency injection / di / injection ← **重複 `factory`**
13. table view cell / collection view cell / cell / cells
14. extension / extensions
15. view modifier / viewmodifier / swiftui modifier / modifier
16. error handling / error / errors

---

## 2. 重複分析

### 重複 Patterns (需合併)

| Architecture Pattern | 重複的 Tier 1/2 Pattern | 建議處理 |
|---------------------|------------------------|---------|
| `api endpoint` | `router` (Tier 1) | 合併：`router / api endpoint / api` |
| `networking` | `service` (Tier 1) | 合併：`service / networking / network` |
| `dependency injection` | `factory` (Tier 1) | 合併：`factory / di / dependency injection` |
| `viewmodel` | `observable` (Tier 2) | 合併：`viewmodel / mvvm / observable` 並移到 Tier 1 |
| `database query` | `repository` (Tier 1) | 擴展 `repository` 別名：`repository / database / query` |

### 獨特 Architecture Patterns (需移入 Tier 1/2)

**移入 Tier 1** (高頻使用):
- `view controller` ⭐⭐⭐⭐⭐ (UIKit 核心)
- `swiftui view` ⭐⭐⭐⭐⭐ (SwiftUI 核心)
- `coordinator` ⭐⭐⭐⭐⭐ (導航核心)
- `core data` ⭐⭐⭐⭐ (資料持久化)

**移入 Tier 2** (補充):
- `authentication`
- `background job`
- `file upload`
- `table view cell / collection view cell`
- `extension`
- `view modifier`
- `error handling`

---

## 3. 合併後結構 (After)

**新結構**: Tier 1 (14) + Tier 2 (15) = **29 patterns** (-5 重複)

### 新 Tier 1 - Core Patterns (14)

1. **protocol / delegate / protocol delegate** ⭐⭐⭐⭐⭐
   - 保持不變

2. **combine / publisher / combine publisher** ⭐⭐⭐⭐ (⚠️ needs content analysis)
   - 保持不變

3. **async / await / async await / concurrency** ⭐⭐⭐⭐ (⚠️ needs content analysis)
   - 保持不變

4. **repository / repo / database / query** ⭐⭐⭐⭐⭐
   - **合併** `database query` 別名

5. **service / service layer / manager / networking / network** ⭐⭐⭐⭐⭐
   - **合併** `networking` 別名

6. **usecase / use case / interactor** ⭐⭐⭐⭐⭐
   - 保持不變

7. **router / route / routing / api endpoint / api / endpoint** ⭐⭐⭐⭐⭐
   - **合併** `api endpoint` 別名

8. **factory / builder / dependency injection / di / injection** ⭐⭐⭐⭐
   - **合併** `dependency injection` 別名

9. **viewmodel / mvvm / view model / observable / observableobject** ⭐⭐⭐⭐⭐
   - **從 Tier 2 移入 + 合併** `observable`
   - **合併** Architecture 的 `viewmodel`

10. **view controller / viewcontroller** ⭐⭐⭐⭐⭐
    - **從 Architecture 移入** (UIKit 核心)

11. **swiftui view / view** ⭐⭐⭐⭐⭐
    - **從 Architecture 移入** (SwiftUI 核心)

12. **coordinator / navigation coordinator** ⭐⭐⭐⭐⭐
    - **從 Architecture 移入** (導航核心)

13. **core data / coredata / persistence / data persistence** ⭐⭐⭐⭐
    - **從 Architecture 移入** (資料核心)

14. **layout / collection view layout / uicollectionviewlayout** ⭐⭐⭐⭐
    - 保持不變

### 新 Tier 2 - Supplementary Patterns (15)

1. **reducer / tca reducer / state reducer** ⭐⭐⭐
   - 保持不變

2. **environment / configuration / config** ⭐⭐⭐
   - 保持不變

3. **cache / caching** ⭐⭐⭐
   - 保持不變

4. **theme / style / appearance** ⭐⭐⭐
   - 保持不變

5. **mock / stub / fake / test double** ⭐⭐⭐
   - 保持不變

6. **middleware / interceptor** ⭐⭐⭐
   - 保持不變

7. **localization / i18n / l10n** ⭐⭐⭐
   - 保持不變

8. **animation / animator / transition** ⭐⭐⭐
   - **從 Tier 1 移出** (更適合 Tier 2)

9. **authentication / auth / login** ⭐⭐⭐⭐
   - **從 Architecture 移入**

10. **background job / job / queue** ⭐⭐⭐
    - **從 Architecture 移入**

11. **file upload / upload / file storage** ⭐⭐⭐
    - **從 Architecture 移入**

12. **table view cell / collection view cell / cell / cells** ⭐⭐⭐
    - **從 Architecture 移入**

13. **extension / extensions** ⭐⭐⭐
    - **從 Architecture 移入**

14. **view modifier / viewmodifier / swiftui modifier / modifier** ⭐⭐⭐
    - **從 Architecture 移入**

15. **error handling / error / errors** ⭐⭐⭐
    - **從 Architecture 移入**

---

## 4. 變更摘要

### 移除 (重複)
- ❌ Architecture section 完全移除
- ❌ `observable` 從 Tier 2 移除（合併進 `viewmodel`）
- ❌ 5 個重複 patterns 合併

### 新增別名
- ✅ `repository` + `database / query`
- ✅ `service` + `networking / network`
- ✅ `router` + `api endpoint / api / endpoint`
- ✅ `factory` + `dependency injection / di / injection`
- ✅ `viewmodel` + `observable / observableobject`

### 移動
- 📦 `viewmodel` (Tier 2 → Tier 1)
- 📦 `animation` (Tier 1 → Tier 2)
- 📦 `view controller` (Architecture → Tier 1)
- 📦 `swiftui view` (Architecture → Tier 1)
- 📦 `coordinator` (Architecture → Tier 1)
- 📦 `core data` (Architecture → Tier 1)
- 📦 7 個 patterns (Architecture → Tier 2)

---

## 5. 向後相容性

✅ **所有現有別名仍然可用**:
- `api endpoint` → `router`
- `networking` → `service`
- `dependency injection` → `factory`
- `viewmodel` → `viewmodel`
- `observable` → `viewmodel`
- `database query` → `repository`

---

## 6. 優勢

### Before (當前)
- 34 patterns (10 + 8 + 16)
- 三層結構混亂
- 5+ 重複 patterns
- Architecture section 不清楚

### After (優化後)
- **29 patterns** (14 + 15) ✅ **-5 重複**
- **兩層結構清晰** ✅
- **無重複** ✅
- **Tier 1/2 語義明確** ✅
- **向後相容** ✅

---

## 7. 實作步驟

1. ✅ 分析重複問題
2. ⏳ 更新 file patterns (合併別名)
3. ⏳ 更新 directory patterns (合併別名)
4. ⏳ 更新 help 訊息 (新 Tier 1/2 結構)
5. ⏳ 測試所有 patterns
6. ⏳ 建立測試報告
7. ⏳ 建立優化報告

---

## 8. 測試計劃

測試專案: `test_targets/wikipedia-ios` 或 `test_targets/ios-mail`

**測試項目**:
1. 所有新 Tier 1 patterns (14)
2. 所有新 Tier 2 patterns (15)
3. 所有合併的別名 (5+)
4. Help 訊息顯示
5. 向後相容性

---

## 9. 成功指標

- ✅ 29 patterns 全部運作
- ✅ 所有別名向後相容
- ✅ Help 訊息清晰（Tier 1: 14, Tier 2: 15）
- ✅ 無重複 patterns
- ✅ 100% 測試通過率
