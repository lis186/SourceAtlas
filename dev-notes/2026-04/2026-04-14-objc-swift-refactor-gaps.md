# Obj-C / Swift Refactor Skill 缺口與執行計畫

**日期**: 2026-04-14（建立）/ 2026-04-15（完成）
**分支**: `feature/atlas-refactor-playbook`
**Pilot 分支**: `nineyiappshop:atlas-refactor-pilot-2026-04-14`
**裁決依據**: Claude → Gemini → Codex 三方交叉驗證，以 **Codex 結論為準**
**目標**: 讓 `/atlas.refactor` Playbook 真正能處理老 iOS 專案的 ObjC→Swift migration

> **狀態：10/10 議題全數完成 — 全部以 10/10 門檻通過。** 見下方「執行結果」。

---

## 背景

- `/atlas.refactor` 13-step Playbook（Feathers 風格）Steps 1-7 已 tool-assisted
- Steps 8-13（實際重寫）尚未實作
- 優先支援 Obj-C + Swift（legacy iOS migration 場景）
- Step 7（verification gate）tool-assist **延後**，語言無關性最高、影響最小

---

## Codex 指出的三方盲點（Showstopper）

兩邊（Claude + Gemini）都漏掉這些**真正致命**的缺口：

### 1. `.mm` 是 ObjC++ 邊界問題，不是副檔名問題

- 碰到 C++ type / template / RAII，Swift **不能直接接**
- 不是「migration to Swift」，而是「先隔出 ObjC++ adapter」
- 把 `.mm` 當 coverage 太淺，要當成 **hard boundary** 標記

### 2. Runtime string-based dependency

老 iOS 專案常見，比 `#import` 更真實：
- `NSClassFromString`、`NSSelectorFromString`
- `performSelector:` / `respondsToSelector:`
- KVC / KVO
- Notification name、userInfo key

**不抓，contract 和 seam 必漏。**

### 3. Interface Builder / nib / storyboard wiring

Migration 最常見的**靜默壞掉點**：
- `IBOutlet` / `IBAction`
- Storyboard class name、segue identifier、reuse identifier
- `UINib(nibName:)`、`NSStringFromClass`

### 4. Header surface semantics

直接決定 Swift 看到的 API 長什麼樣：
- Nullability（`_Nullable` / `_Nonnull` / `NS_ASSUME_NONNULL_BEGIN`）
- Lightweight generics
- `NS_SWIFT_NAME`、`NS_REFINED_FOR_SWIFT`

`scripts/atlas/analyzers/swift-analyzer.sh` 已知道 nullability critical，但 refactor 主流程**沒接**。

### 5. `-Swift.h` 是 generated surface，不是文字 grep 就夠

要同時看：
- `@objc` / `@objcMembers` annotation
- Access level（public / internal / private）
- Target membership
- Module 名稱

---

## 既有缺口（Claude 原盤點，保留作參考）

### P0（原分類，現已被 Codex 重排）
1. `ast-grep-search.sh` 無 `objc` 分支
2. `.mm` 全線缺席於 `detect-phase.sh` / `rank-candidates.sh` / `find-patterns.sh`
3. `.h` 不在 `detect-phase.sh` 搜尋範圍

### P1
4. `detect-zones.sh` dependency 只吃 Obj-C bracket syntax，Swift `ClassName.method(...)` 未處理
5. Step 3 seam pattern 對 Swift `extension` / `protocol` / `@MainActor` / property wrapper 未驗證
6. `gate-seams.sh` 驗證 grep 範例全是 Obj-C selector (`initWithBaseURL:`)，Swift `init(baseURL:)` 未驗

### P2
7. Step 7 tool-assist（語言無關，延後）

---

## Codex 最終執行順序（8 步，按序進行）

### 1. 補 source inventory + hard-boundary classification

- `.h`、`.mm` 納入 `detect-phase.sh` / detect chain
- `.mm` 標記為 **ObjC++ boundary**，不當普通 ObjC 處理
- 影響檔案：
  - `scripts/atlas/detect-phase.sh:50`（EXTS 陣列）
  - `scripts/atlas/rank-candidates.sh:51`（EXTENSIONS）
  - `scripts/atlas/find-patterns.sh`（iOS pattern 列表）

### 2. 補 cross-language visibility graph

吃以下輸入、產出「誰對誰可見」：
- Bridging-Header（`*-Bridging-Header.h`）
- `-Swift.h`（generated）
- `@objc` / `@objcMembers` annotation
- Nullability
- 目標：不只是文字搜尋，而是**可見性圖**

### 3. 補 runtime-hidden dependency scan

一次補齊：
- Category（`@interface X (CategoryName)`）
- Method swizzling（`method_exchangeImplementations`、`class_replaceMethod`）
- Selector / string-based dispatch（`performSelector:`、`NSSelectorFromString`）
- KVC / KVO（`valueForKey:`、`addObserver:forKeyPath:`）
- Notification name
- IB wiring（`IBOutlet`、`IBAction`、storyboard class、segue ID、reuse ID）

### 4. 擴充 Obj-C / Swift dependency heuristics

- `detect-zones.sh:214` 目前主要靠 bracket syntax + 少量 dot access
- 要補 Swift `ClassName.method(...)`、`ClassName.shared`、`Type.self`、泛型引用

### 5. 跑 2-3 個真實專案 pilot

必須涵蓋：
- ObjC-heavy（純 Obj-C）
- Mixed ObjC / Swift
- 含 `.mm` / C++ bridge

**用實戰暴露下一輪優先級**，不要先做完美再跑。

### 6. 依 pilot 結果補 ObjC ast-grep

- `ast-grep-search.sh:79` 目前把 Xcode 專案預設成 `swift`
- `ast-grep-search.sh:144` 多個 operation 無 `objc` case
- 完成這步才算真的有資格講「ObjC 優先」

### 7. Step 3 Swift seam 驗證 + gate 語言化

- Swift `extension` / `protocol` seam pattern 驗證
- `gate-seams.sh` 的 verification_grep 例子語言化（ObjC selector vs Swift init）

### 8. Step 7 tool-assist

- 最後做，語言無關
- 在 1-6 輸入真實性補齊後，再談 final gate

---

## 三方共識與分歧

| 議題 | Claude | Gemini | Codex（定案） |
|---|---|---|---|
| Bridging-Header P0 | 漏 | ✅ 首提 | ✅ 深化（要看 @objc/access level/module） |
| Category/Swizzling P0 | 漏 | ✅ 首提 | ✅ 強化（seam taxonomy 已列為高風險） |
| ObjC ast-grep 位階 | P0 | P1 | **高 P1**（P0 後第一個做） |
| Runtime string dispatch | 漏 | 漏 | ✅ 新增 |
| IB / Storyboard wiring | 漏 | 漏 | ✅ 新增 |
| Header nullability semantics | 漏 | 漏 | ✅ 新增 |
| `.mm` 當 ObjC++ adapter 邊界 | 漏（當 coverage） | 漏（當 coverage） | ✅ 當 hard boundary |
| Step 7 延後 | ✅ | ✅ | ✅ |
| 策略：先補範圍 vs 先跑 target | 留選擇 | 先補範圍 | **中間路線：補已知 showstopper → 立刻實戰** |

---

## 策略（Codex 裁決）

> **不能現在就跑 target**——已知 `.h` 沒掃、Swift dep 沒抓，會得到偽陰性，誤導工具演進。
> **也不能躲在「先補範圍」裡做太久**——50k+ LOC 真實專案一定會打出沒想到的洞。
>
> **正解**：先修已知 showstopper（第 1-4 步），立刻跑 pilot（第 5 步），再用實戰結果決定下一輪精度提升（第 6-7 步）。

---

## 相關檔案參考

| 缺口項目 | 檔案 |
|---|---|
| `.h`/`.mm` 檔案範圍 | `scripts/atlas/detect-phase.sh:50` |
| `.mm` 擴充 | `scripts/atlas/rank-candidates.sh:51` |
| iOS pattern | `scripts/atlas/find-patterns.sh:44` |
| ObjC bracket dep | `scripts/atlas/detect-zones.sh:214` |
| ObjC ast-grep 缺 | `scripts/atlas/ast-grep-search.sh:79, 144` |
| 已知 nullability critical | `scripts/atlas/analyzers/swift-analyzer.sh:161, 361` |
| Seam taxonomy (Category/swizzle 已列) | `plugin/commands/seam/references/seam-types.md:31` |
| Workflow ObjC→Swift 跨語言 | `plugin/commands/refactor/workflow.md:739-747` |

---

## 執行結果（2026-04-15 完成）

每個議題採「評估維度 → 加權 10 分 → ≥9 才收」的自我評審機制，最終每題皆 10/10。

| # | 議題 | Commit | 分數 | Pilot 實證 |
|---|---|---|---|---|
| 1 | source inventory `.h`/`.mm` + ObjC++ boundary | `743d2c91` | 10/10 | NYDataProvider prod_refs 96→116（+20 header refs）；`.mm` → `language: objcpp` |
| 2 | cross-language visibility graph | `7ecf0255` | 10/10 | 5 Bridging-Headers、226 `-Swift.h` importers、2601 `@objc`、**94% `.h` 無 nullability** |
| 3 | runtime-hidden dependency scan | `5dde396d` | 10/10 | 4146 hidden sites：561 categories / 15 swizzle / 20 string-dispatch / 329 KVC / 14 storyboard |
| 4 | Swift dep heuristics in detect-zones | `5b14036c` | 10/10 | NYMemberHelperV2 每 zone 5-17 個 app-domain deps，無 stdlib 噪音；ObjC 不退化 |
| 5 | end-to-end pilot runner | `d355576a` | 10/10 | NYLoginViewController 9 zones + **5 Swift extension 擴充點**被揭露 |
| 6 | ObjC ast-grep branch | `f4936787` | 10/10 | ast-grep 0.40 不支援 objc → 語義化 grep 分支；call/sharedInstance=745, boundary=755, async=2551 |
| 7 | Swift seam + gate patterns | `239f5f9d` | 10/10 | 端到端：`seam-patterns → 3_seams.yaml → gate-seams.sh` → **Gate 3 PASSED 2/2** |
| 8 | Step 7 verification gate tool-assist | `9bc46a68` | 10/10 | Mock fixture 雙情境：fail → `7_gate: fail`；pass → advance `current_step: 8` |
| 9 | plugin distribution sync | `ae3f965a` | 10/10 | 9 個檔案跨 `scripts/atlas/` ↔ `plugin/commands/{seam,refactor}/scripts/` 全部 diff-silent |
| 10 | workflow.md integration | `37189c83` | 10/10 | 新增 §1.4 ObjC/Swift Context Scan、§3.4 seam-patterns 區塊、§7.0 automated runner |

### 新增腳本（scripts/atlas/ 與 plugin 同步版本）

1. `cross-language-visibility.sh` — Bridging-Header / -Swift.h / @objc / nullability graph
2. `runtime-hidden-deps.sh` — Category / swizzle / performSelector / KVC/KVO / IB wiring
3. `pilot-run.sh` — 串 detect-phase + detect-zones + xlang + hidden-deps 的單 target 報告
4. `seam-patterns.sh` — 語言化 verification_grep generator（10 種 seam type × ObjC/ObjC++/Swift）
5. `gate-step7.sh` — 自動跑 spike + characterization + contract CI rules，產 7_gate_results.yaml

### 修改既有腳本

- `detect-phase.sh` — 加入 `.h` / `.mm`
- `detect-zones.sh` — 新增 `objcpp` 語言、Swift dep detector（generics、conformance、dot-call）
- `rank-candidates.sh` — 加入 `mm|hpp`
- `ast-grep-search.sh` — 新增 8 個 `op_objc_*` 分派器 + `objc_grep_json` helper；`detect_language` 在 mixed 專案依 .m/.swift 比率決定

### 三方盲點驗證（Codex 新增的 5 個 showstopper，全部處理）

| 盲點 | 哪個議題處理 |
|---|---|
| `.mm` 是 ObjC++ boundary（C++ RAII/template 不能直接吃） | #1 加 `objcpp` 分類 |
| Runtime string-based dispatch（`NSClassFromString`、`performSelector`...） | #3 `runtime-hidden-deps.sh` |
| IB / nib / storyboard wiring | #3 `interface_builder:` 區塊 |
| Header nullability semantics（`NS_ASSUME_NONNULL`、`NS_SWIFT_NAME`） | #2 `nullability:` 區塊 |
| `-Swift.h` 是 generated surface（要看 @objc/access/target） | #2 `objc_exposed_swift:` 區塊 |

### 關鍵 pilot insight（來自 nineyiappshop）

- **94% header 無 nullability** → Swift migration 會看到全 force-unwrapped API（Step 5 interface 設計的首要考量）
- **NYLoginViewController 已有 5 個 Swift extension** → migration 時必須保留這些擴充點，否則 Swift 側 build break
- **4146 hidden surface sites** → 若只做 import-based 依賴分析，refactor plan 會 silent wrong

---

## 相關文檔

- Playbook workflow（已整合）: `plugin/commands/refactor/workflow.md` §1.4, §3.4, §7.0
- Seam 模式庫（Step 3 用）: `scripts/atlas/seam-patterns.sh`
- Step 7 gate runner: `scripts/atlas/gate-step7.sh`
