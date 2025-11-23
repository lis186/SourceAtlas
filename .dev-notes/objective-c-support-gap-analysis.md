# Objective-C 支援缺口分析

**日期**: 2025-11-23
**嚴重性**: 🔴 **高優先級** - 遺漏 3-18% 的代碼

---

## 執行摘要

當前 iOS patterns **完全不支援 Objective-C**，導致：
- ❌ **無法分析混合 Swift/Objective-C 專案**
- ❌ **遺漏 18% (wikipedia-ios) 到 3% (Signal-iOS) 的代碼**
- ❌ **所有 Objective-C patterns 都被忽略**

---

## 1. 問題發現

### 1.1 測試結果

```bash
# 測試當前 patterns 是否能找到 Objective-C 檔案
$ ./scripts/atlas/find-patterns.sh "view controller" test_targets/wikipedia-ios | grep -i "\.m\|\.h"
(無輸出) ❌

# 但實際上有 9 個 Objective-C ViewControllers
$ find test_targets/wikipedia-ios -name "*ViewController.m" | wc -l
9
```

**結論**: 當前 patterns 100% 遺漏 Objective-C 檔案 ❌

### 1.2 影響範圍統計

| 專案 | Swift 檔案 | Objective-C 檔案 | ObjC 比例 | 遺漏影響 |
|------|-----------|-----------------|----------|---------|
| **wikipedia-ios** | 559 | 121 | **18%** | 🔴 高 |
| **Signal-iOS** | 2514 | 73 | **3%** | 🟡 中 |
| 平均 | - | - | **~10%** | 🔴 高 |

**結論**: 平均遺漏 10% 的代碼，wikipedia-ios 高達 18% ❌

---

## 2. 當前設計問題

### 2.1 只匹配 .swift 檔案

**當前實作** (`scripts/atlas/find-patterns.sh`):

```bash
"view controller"|"viewcontroller")
    echo "*ViewController.swift *VC.swift *Controller.swift"
    ;;
"service"|"service layer"|"manager"|"networking"|"network")
    echo "*Service.swift *Manager.swift *Provider.swift *Client.swift *Network*.swift ..."
    ;;
"viewmodel"|"view model"|"mvvm"|"observable"|"observableobject"|"observable object")
    echo "*ViewModel.swift *VM.swift *Store.swift"
    ;;
```

**問題**: 所有 patterns 都**只匹配 `.swift` 副檔名** ❌

### 2.2 遺漏的常見 Objective-C Patterns

找到的 Objective-C 檔案範例：

**ViewControllers** (9 個遺漏):
```
WMFAppViewController.m
AboutViewController.m
WMFLanguagesViewController.m
WMFImageGalleryViewController.m
WMFSettingsViewController.m
WMFBarButtonItemPopoverMessageViewController.m
WMFReferencePopoverMessageViewController.m
NYTPhotoViewController.m
NYTPhotosViewController.m
```

**Controllers/Managers** (15 個遺漏):
```
WMFNotificationsController.m
WMFExploreFeedContentController.m
MWKLanguageLinkController.m
MWKTitleLanguageController.m
NYTPhotoTransitionController.m
NYTPhotoDismissalInteractionController.m
```

---

## 3. Objective-C 命名慣例研究

### 3.1 常見 Patterns 對應

| Pattern Type | Swift 命名 | Objective-C 命名 | 差異 |
|--------------|-----------|-----------------|------|
| **View Controller** | `*ViewController.swift` | `*ViewController.m/.h` | 相同後綴 ✅ |
| **Manager** | `*Manager.swift` | `*Manager.m/.h` | 相同後綴 ✅ |
| **Service** | `*Service.swift` | `*Service.m/.h` | 相同後綴 ✅ |
| **ViewModel** | `*ViewModel.swift` | `*ViewModel.m/.h` | 相同後綴 ✅ |
| **Controller** | `*Controller.swift` | `*Controller.m/.h` | 相同後綴 ✅ |
| **Coordinator** | `*Coordinator.swift` | `*Coordinator.m/.h` | 相同後綴 ✅ |
| **Delegate** | `*Delegate.swift` | `*Delegate.m/.h` | 相同後綴 ✅ |
| **DataSource** | `*DataSource.swift` | `*DataSource.m/.h` | 相同後綴 ✅ |

**結論**: Objective-C 和 Swift 的 pattern 命名慣例**幾乎完全相同** ✅
**只需要擴充副檔名即可**！

### 3.2 Objective-C 特殊 Patterns

**需要注意的差異**:

1. **Protocol (Swift) vs Protocol (Objective-C)**:
   - Swift: `*Protocol.swift`
   - Objective-C: `*Protocol.h` (只在 .h 檔案定義)

2. **Extension (Swift) vs Category (Objective-C)**:
   - Swift: `String+Extensions.swift`, `*Extension.swift`
   - Objective-C: `NSString+Utils.h/.m`, `*+Category.h/.m`

3. **Core Data**:
   - Swift: `*+CoreDataProperties.swift`, `*+CoreDataClass.swift`
   - Objective-C: `*+CoreDataProperties.m/.h`, `*+CoreDataClass.m/.h`

---

## 4. 解決方案設計

### 4.1 簡單方案：擴充副檔名 ✅

**原理**: 大部分 patterns 只需要加上 `.m` 和 `.h` 副檔名

**Before**:
```bash
"view controller"|"viewcontroller")
    echo "*ViewController.swift *VC.swift *Controller.swift"
    ;;
```

**After**:
```bash
"view controller"|"viewcontroller")
    echo "*ViewController.swift *ViewController.m *ViewController.h *VC.swift *VC.m *VC.h *Controller.swift *Controller.m *Controller.h"
    ;;
```

**優點**:
- ✅ 簡單直接
- ✅ 向後相容
- ✅ 涵蓋 95%+ 的 Objective-C patterns

**缺點**:
- ⚠️ Pattern 字串會變長
- ⚠️ 需要更新所有 29 個 patterns

### 4.2 進階方案：統一 Helper Function ✅

**原理**: 建立 helper function 自動擴充副檔名

```bash
# Helper function
ios_file_patterns() {
    local base_patterns="$1"
    local result=""
    for pattern in $base_patterns; do
        # 移除現有的 .swift 副檔名
        base="${pattern%.swift}"
        # 加上 .swift, .m, .h
        result="$result ${base}.swift ${base}.m ${base}.h"
    done
    echo "$result"
}

# 使用方式
"view controller"|"viewcontroller")
    ios_file_patterns "*ViewController *VC *Controller"
    ;;
```

**優點**:
- ✅ 代碼簡潔
- ✅ 易於維護
- ✅ 統一處理所有 patterns

**缺點**:
- ⚠️ 需要重構現有代碼

---

## 5. 建議方案

### 5.1 推薦：簡單方案（擴充副檔名）

**理由**:
1. **快速實作** - 只需更新 patterns 字串
2. **低風險** - 不改變架構
3. **向後相容** - 保持現有行為
4. **高效益** - 立即支援混合專案

### 5.2 實作範圍

**需要更新的 patterns**: **所有 29 個 iOS patterns**

**Tier 1 (14 個)**:
1. protocol → 加 `.m .h`
2. combine → 加 `.m .h`
3. async → 加 `.m .h`
4. repository → 加 `.m .h`
5. service → 加 `.m .h`
6. usecase → 加 `.m .h`
7. router → 加 `.m .h`
8. factory → 加 `.m .h`
9. viewmodel → 加 `.m .h`
10. view controller → 加 `.m .h`
11. swiftui view → **保持 `.swift` 只有**（SwiftUI 限定）
12. coordinator → 加 `.m .h`
13. core data → 已有 `.xcdatamodeld`，加 `*+CoreData*.m .h`
14. layout → 加 `.m .h`

**Tier 2 (15 個)**:
- 全部加 `.m .h`
- 特別注意 `extension` 需要支援 Category 語法 (`*+*.m *+*.h`)

---

## 6. 測試計劃

### 6.1 測試專案

- ✅ **wikipedia-ios** (18% Objective-C) - 主要測試專案
- ✅ **Signal-iOS** (3% Objective-C) - 驗證專案

### 6.2 測試案例

| Pattern | Swift 檔案 | Objective-C 檔案 | 預期結果 |
|---------|-----------|-----------------|---------|
| `view controller` | `*ViewController.swift` | `*ViewController.m/.h` | 同時找到 ✅ |
| `service` | `*Service.swift` | `*Service.m/.h` | 同時找到 ✅ |
| `manager` | `*Manager.swift` | `*Manager.m/.h` | 同時找到 ✅ |
| `extension` | `*Extension.swift`, `*+*.swift` | `*+*.m/.h` (Category) | 同時找到 ✅ |
| `core data` | `*+CoreData*.swift` | `*+CoreData*.m/.h` | 同時找到 ✅ |

### 6.3 成功指標

- ✅ wikipedia-ios: 從遺漏 18% → 0% 遺漏
- ✅ Signal-iOS: 從遺漏 3% → 0% 遺漏
- ✅ 所有 Objective-C patterns 能被找到
- ✅ Swift patterns 仍然正常運作（向後相容）
- ✅ 混合專案能完整分析

---

## 7. 實作優先級

### 高優先級（立即實作）

1. ✅ **view controller** - 最常見 pattern，遺漏 9 個檔案
2. ✅ **service / manager** - 遺漏 15+ 個檔案
3. ✅ **coordinator** - 導航核心
4. ✅ **extension** - 需支援 Category 語法

### 中優先級（後續實作）

5. ✅ **viewmodel** - 較少 Objective-C 使用
6. ✅ **repository** - 資料層
7. ✅ 其他 Tier 1 patterns

### 低優先級（可選）

8. ✅ Tier 2 patterns - 使用率較低

---

## 8. 風險評估

### 8.1 技術風險

| 風險 | 機率 | 影響 | 緩解措施 |
|------|------|------|---------|
| Pattern 字串過長 | 低 | 低 | 測試效能 |
| 找到過多無關檔案 | 低 | 低 | 維持現有過濾機制 |
| 向後相容問題 | 極低 | 高 | 只新增副檔名，不移除 |

### 8.2 維護風險

| 風險 | 機率 | 影響 | 緩解措施 |
|------|------|------|---------|
| 未來新增 pattern 忘記加 .m/.h | 中 | 中 | 文檔化 + 測試 |
| Objective-C 特殊語法遺漏 | 低 | 低 | 持續測試 |

---

## 9. 預期成果

### Before (當前)
```
wikipedia-ios 分析結果:
- 找到 Swift files: 559 ✅
- 遺漏 Objective-C files: 121 ❌
- 遺漏率: 18% ❌
```

### After (擴充後)
```
wikipedia-ios 分析結果:
- 找到 Swift files: 559 ✅
- 找到 Objective-C files: 121 ✅
- 遺漏率: 0% ✅
```

---

## 10. 結論

**問題嚴重性**: 🔴 **高** - 遺漏平均 10% 代碼

**解決方案**: ✅ **簡單擴充副檔名** - 快速、低風險、高效益

**建議行動**:
1. ⏰ **立即實作** - 高優先級 patterns (view controller, service, coordinator)
2. ⏰ **1 小時內完成** - 所有 29 個 patterns
3. ⏰ **測試驗證** - wikipedia-ios, Signal-iOS
4. ⏰ **文檔更新** - 記錄 Objective-C 支援

**預期改善**:
- ✅ 從遺漏 10-18% → 0% 遺漏
- ✅ 完整支援混合 Swift/Objective-C 專案
- ✅ 向後相容，零破壞性變更
