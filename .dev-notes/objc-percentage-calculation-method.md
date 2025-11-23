# Objective-C 比例計算方式說明

**日期**: 2025-11-23

---

## 計算方式

我之前使用的是**檔案數比例**，計算公式：

```
ObjC 比例 = .m 檔案數 / (Swift 檔案數 + .m 檔案數) × 100%
```

### 為什麼用檔案數而非行數？

1. **快速計算** - 不需要讀取所有檔案內容
2. **代表性** - 檔案數反映了代碼模組化程度
3. **Pattern 匹配** - `find-patterns.sh` 本質上就是找檔案，不是算行數

---

## 三個測試專案的詳細數據

### 1. nineyiappshop (NYCore only)

**檔案數**:
- Swift 檔案: 147
- Objective-C .m 檔案: 179
- **檔案數比例**: 179 / (147 + 179) = **54.9% ≈ 55%**

**計算**:
```bash
$ find test_targets/nineyiappshop/NYCore -name "*.swift" | wc -l
147

$ find test_targets/nineyiappshop/NYCore -name "*.m" | wc -l
179

ObjC 比例 = 179 / 326 = 54.9% ≈ 55%
```

---

### 2. wikipedia-ios (Wikipedia/Code only)

**檔案數**:
- Swift 檔案: 559
- Objective-C .m 檔案: 121
- **檔案數比例**: 121 / (559 + 121) = **17.8% ≈ 18%**

**計算**:
```bash
$ find test_targets/wikipedia-ios/Wikipedia/Code -name "*.swift" | wc -l
559

$ find test_targets/wikipedia-ios/Wikipedia/Code -name "*.m" | wc -l
121

ObjC 比例 = 121 / 680 = 17.8% ≈ 18%
```

---

### 3. Signal-iOS (整個專案)

**檔案數**:
- Swift 檔案: 2514
- Objective-C .m 檔案: 73
- **檔案數比例**: 73 / (2514 + 73) = **2.8% ≈ 3%**

**計算**:
```bash
$ find test_targets/Signal-iOS -name "*.swift" | wc -l
2514

$ find test_targets/Signal-iOS -name "*.m" | wc -l
73

ObjC 比例 = 73 / 2587 = 2.8% ≈ 3%
```

---

## 為什麼只計算 .m 不計算 .h？

### Objective-C 檔案特性

- **.m 檔案** - 實作檔案（implementation），包含實際代碼
- **.h 檔案** - 標頭檔案（header），主要是宣告

### 計算邏輯

如果同時計算 .h 檔案：
- 每個 .m 檔案通常都有對應的 .h 檔案
- .h 檔案行數通常只有 .m 的 10-20%
- **會造成 ObjC 比例虛增約 1.5-2 倍**

**範例**:
```
nineyiappshop:
- .m 檔案: 179
- .h 檔案: 5,662 (但大部分是系統/第三方庫的 header)

如果計算 .h:
- ObjC 檔案數 = 179 + 5,662 = 5,841
- 虛增比例 = 5,841 / (147 + 5,841) = 97.5% ❌ (不合理)
```

**結論**: 只計算 .m 檔案更準確反映實際的 Objective-C 代碼量。

---

## 檔案數 vs 行數 (LOC)

### 檔案數的優缺點

**優點** ✅:
- 快速計算
- 反映代碼模組化
- 與 `find-patterns.sh` 的設計一致

**缺點** ⚠️:
- 不考慮檔案大小
- 一個 5000 行的檔案 = 一個 50 行的檔案

### 行數 (Lines of Code) 的優缺點

**優點** ✅:
- 更準確反映代碼量
- 考慮檔案大小差異

**缺點** ⚠️:
- 計算耗時（需讀取所有檔案）
- 包含空行、註解
- 不一定反映複雜度

---

## 實際影響分析

### 對 Pattern 匹配的影響

無論用檔案數還是行數，**Pattern 匹配的目標都是找到檔案**：

```bash
# Pattern 匹配找的是檔案，不是行數
$ ./scripts/atlas/find-patterns.sh "view controller" project/
*ViewController.swift  ← 找到這個檔案
*ViewController.m      ← 也要找到這個檔案
```

**關鍵點**:
- 遺漏 1 個 10,000 行的 .m 檔案 = 遺漏 ❌
- 遺漏 1 個 50 行的 .m 檔案 = 遺漏 ❌
- **檔案數比例** 更直接反映「會遺漏多少檔案」

---

## 統一的計算方式

### 推薦方式（已使用）

**檔案數比例**:
```
ObjC 比例 = .m 檔案數 / (Swift 檔案數 + .m 檔案數) × 100%
```

**理由**:
1. ✅ 與 Pattern 匹配目標一致（找檔案）
2. ✅ 快速計算
3. ✅ 清晰易懂
4. ✅ 直接反映「遺漏檔案數比例」

### 替代方式（未使用）

**行數比例** (LOC):
```
ObjC 比例 = .m 檔案總行數 / (Swift 總行數 + .m 總行數) × 100%
```

**何時使用**:
- 評估代碼重構工作量
- 計算遷移成本
- 代碼審查時間估算

**不適合 Pattern 匹配場景** ❌

---

## 總結

### 我使用的計算方式

✅ **檔案數比例** = .m 檔案數 / (Swift + .m 檔案數)

### 為什麼這樣計算

1. **與 Pattern 匹配一致** - 找檔案不是算行數
2. **快速簡單** - 不需讀取檔案內容
3. **直接反映遺漏** - 遺漏 55% 檔案數 = 遺漏 55% 的模組

### 三個測試專案總結

| 專案 | Swift 檔案 | ObjC .m 檔案 | **檔案數比例** | 分類 |
|------|-----------|-------------|--------------|------|
| nineyiappshop | 147 | 179 | **55%** | 重度混合 🔴 |
| wikipedia-ios | 559 | 121 | **18%** | 中度混合 🟡 |
| Signal-iOS | 2514 | 73 | **3%** | 輕度混合 🟢 |

**遺漏影響**: 當前 iOS patterns 會遺漏這些比例的檔案 ❌
