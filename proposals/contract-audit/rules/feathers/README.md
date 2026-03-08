# Feathers 驗證規則

基於 Michael Feathers《Working Effectively with Legacy Code》的 5 條結構性驗證規則。
用於偵測 Legacy Code 中常見的設計問題，作為重構優先順序的參考依據。

## 規則總覽

| # | 規則名稱 | Feathers 章節 | 偵測目標 | ast-grep | grep |
|---|---------|--------------|---------|----------|------|
| 1 | Snarled Method | Ch.22 | 巢狀深度 > 3 | rule.yaml | objc-fallback/snarled-method.sh |
| 2 | Monster Method | Ch.22 | 方法行數 > 50 | rule.sh (通用) | objc-fallback/monster-method.sh |
| 3 | Programming by Difference | Ch.20 | 子類別 override <= 2 方法 | rule.yaml | objc-fallback/programming-by-difference.sh |
| 4 | Missing Wrapper | Ch.15 | 10+ 檔案 import 同一深層 class | rule.sh (通用) | objc-fallback/missing-wrapper.sh |
| 5 | Mutable Public Field | Ch.11 | 公開可變欄位 | rule.yaml | objc-fallback/mutable-public-field.sh |

## 各規則說明

### 1. Snarled Method (Ch.22)

**偵測目標**: 巢狀 if/for/while/switch 超過 3 層的方法。

**為什麼重要**: 過深的巢狀結構暗示方法承擔過多責任，每層巢狀都增加理解的認知負擔。
Feathers 建議透過 Extract Method 拆解，讓每個方法只做一件事。

**ast-grep 版本** (`snarled-method/rule.yaml`): 使用模式匹配偵測 4 層巢狀的具體結構。
僅支援 Swift。受限於 ast-grep 無法動態計算深度，只能匹配固定的巢狀模式。

**grep 版本** (`objc-fallback/snarled-method.sh`): 透過大括號計數追蹤巢狀深度。
支援 ObjC .m 檔案。

### 2. Monster Method (Ch.22)

**偵測目標**: 行數超過 50 行的方法。

**為什麼重要**: 過長的方法難以理解、測試和修改。Feathers 建議將閾值設在 50 行，
超過此長度的方法幾乎一定可以拆分。

**通用版本** (`monster-method/rule.sh`): 支援 Swift、ObjC、Java、C#。
透過方法宣告偵測和大括號追蹤計算方法長度。閾值可自訂。

**ObjC 版本** (`objc-fallback/monster-method.sh`): 專為 ObjC .m 檔最佳化。

### 3. Programming by Difference (Ch.20)

**偵測目標**: 子類別僅 override 1-2 個方法。

**為什麼重要**: 當子類別只是為了覆寫少數方法而存在，通常表示應該使用組合（Composition）
或策略模式（Strategy Pattern）。這種模式會導致繼承階層膨脹且難以理解。

**ast-grep 版本** (`programming-by-difference/rule.yaml`): 偵測 Swift 類別中僅有
單一 override 方法的情況。排除常見的 UIKit lifecycle override（viewDidLoad 等）。

**grep 版本** (`objc-fallback/programming-by-difference.sh`): 從 .h 找繼承宣告，
再到 .m 計算方法數量。

### 4. Missing Wrapper (Ch.15)

**偵測目標**: 10 個以上檔案 import 同一第三方深層 class。

**為什麼重要**: 當大量檔案直接依賴同一個第三方 API，代表缺少封裝層。
一旦第三方 API 變更，所有直接依賴都需要修改。Feathers 建議建立 Wrapper/Facade。

**通用版本** (`missing-wrapper/rule.sh`): 支援 Swift、ObjC、Java、Kotlin。
統計各 import 語句在專案中的出現次數。

**ObjC 版本** (`objc-fallback/missing-wrapper.sh`): 專為 ObjC #import 格式最佳化，
自動排除系統 framework（UIKit, Foundation 等）。

### 5. Mutable Public Field (Ch.11)

**偵測目標**: 公開的可變（非 readonly）屬性。

**為什麼重要**: 公開可變欄位讓任何外部程式碼都能修改物件狀態，造成 Effect Propagation。
變更的影響範圍無限擴大，測試覆蓋也變得困難。

**ast-grep 版本** (`mutable-public-field/rule.yaml`): 偵測 Swift 的 `public var`
和 `open var` 宣告。

**grep 版本** (`objc-fallback/mutable-public-field.sh`): 在 .h 檔中找非 readonly 的
@property 宣告。排除 delegate 和 IBOutlet。

## ast-grep vs grep 精確度對照

| 規則 | ast-grep 精確度 | grep 精確度 | 說明 |
|------|----------------|------------|------|
| Snarled Method | LOW | MEDIUM | ast-grep 只能匹配固定模式，grep 可動態計算深度 |
| Monster Method | N/A (用 shell) | HIGH | 行數計算本身就是精確的 |
| Programming by Difference | LOW | MEDIUM | ast-grep 只能偵測單一 override，grep 可計數 |
| Missing Wrapper | N/A (用 shell) | HIGH | import 計數本身就是精確的 |
| Mutable Public Field | HIGH | MEDIUM | ast-grep 理解語法結構；grep 靠文字比對 |

**結論**: 這 5 條規則中，只有 Mutable Public Field 適合用 ast-grep 做主要偵測工具。
其他規則需要計數或深度追蹤，grep/shell 腳本反而更精確。

## clang -ast-dump 可行性評估

### 概述

`clang -ast-dump` 能輸出完整的 AST（Abstract Syntax Tree），理論上可以提供最精確的
結構分析。以下評估其在這 5 條規則中的適用性。

### 是否需要完整編譯環境

**需要。** 這是最大的障礙。

- ObjC 程式碼需要正確的 header search paths（`-I`）、framework search paths（`-F`）
- 使用 CocoaPods 的專案需要 Pods/ 目錄中所有 headers
- 系統 SDK 路徑需要透過 `xcrun --show-sdk-path` 取得
- PCH（precompiled header）可能需要額外處理
- 實務上需要執行類似以下命令：
  ```
  clang -Xclang -ast-dump -fsyntax-only \
    -isysroot $(xcrun --show-sdk-path) \
    -I./Pods/Headers/Public \
    -F$(xcrun --show-sdk-path)/System/Library/Frameworks \
    NYHTTPSClient.m
  ```
- 缺少任何一個 header 都會導致 parse 失敗或不完整的 AST

### 輸出格式是否可靠 parse

**可靠但冗長。**

- 輸出是縮排式的純文字 AST，格式穩定（跨 clang 版本變動小）
- 可使用 `-ast-dump=json` 輸出 JSON 格式（clang 11+），更容易 parse
- 單一 .m 檔的 AST dump 可能超過數萬行
- 需要自行撰寫 parser 或使用 jq 處理 JSON 格式

### 與 grep fallback 的精確度差異

| 規則 | grep 精確度 | clang AST 精確度 | 差異說明 |
|------|-----------|-----------------|---------|
| Snarled Method | MEDIUM | VERY HIGH | AST 能精確計算巢狀深度，不受字串/註解干擾 |
| Monster Method | HIGH | HIGH | 差異不大，行數計算兩者都準確 |
| Programming by Difference | MEDIUM | VERY HIGH | AST 能精確識別 override 方法 |
| Missing Wrapper | HIGH | HIGH | import 分析兩者差不多 |
| Mutable Public Field | MEDIUM | VERY HIGH | AST 能區分 readonly/readwrite、IBOutlet 等 |

### 建議：什麼情況下值得使用

**值得使用的情境：**

1. 專案已有完整的編譯環境設定（能 `xcodebuild` 成功）
2. 需要精確分析巢狀深度（Snarled Method），且 grep 的誤報率不可接受
3. 需要精確識別 override 方法（Programming by Difference）
4. 單次深度審計，不需要在 CI 中反覆執行

**不值得使用的情境：**

1. CI 環境中沒有完整的 iOS 編譯工具鏈
2. 分析對象是跨語言專案（clang 只處理 C/ObjC/C++）
3. 需要快速掃描（clang AST dump 比 grep 慢 10-100 倍）
4. 專案使用大量巨集或模板，導致 AST 膨脹

**最終建議：** 對於 CI 整合場景，使用 grep fallback 作為主要工具。
在需要深度審計時，可以針對特定檔案使用 `clang -ast-dump=json` 做精確分析。
Snarled Method 和 Programming by Difference 這兩條規則從 clang AST 獲益最大。

## 使用方式

### ast-grep 規則

```bash
# 掃描 Swift 程式碼
sg scan --rule rules/feathers/snarled-method/rule.yaml ./Sources/
sg scan --rule rules/feathers/mutable-public-field/rule.yaml ./Sources/
sg scan --rule rules/feathers/programming-by-difference/rule.yaml ./Sources/
```

### Shell 腳本（通用）

```bash
# Monster Method（閾值 50 行）
bash rules/feathers/monster-method/rule.sh ./Sources 50

# Missing Wrapper（閾值 10 個檔案）
bash rules/feathers/missing-wrapper/rule.sh ./Sources 10
```

### ObjC Fallback

```bash
# 所有 ObjC fallback 腳本
bash rules/feathers/objc-fallback/snarled-method.sh ./NYCore 3
bash rules/feathers/objc-fallback/monster-method.sh ./NYCore 50
bash rules/feathers/objc-fallback/programming-by-difference.sh ./NYCore 2
bash rules/feathers/objc-fallback/missing-wrapper.sh ./NYCore 10
bash rules/feathers/objc-fallback/mutable-public-field.sh ./NYCore
```

## 與現有 Phase B 規則的關係

Phase B 規則（`audit/phase-b/rules/`）專注於特定檔案的合約驗證（NYHTTPSClient 的行為契約）。
Feathers 規則則是通用的結構品質偵測，適用於任何 Legacy Code 專案。

兩者可以互補：
- Phase B 規則確保關鍵行為不被破壞（合約層）
- Feathers 規則標記需要重構的區域（品質層）
