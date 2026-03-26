# Final Contract Spec
# Generated: 2026-03-17
# Auditor artifacts: proposals/contract-audit/output/runs/20260317-182046/prompt-step1-gemini.md
# Adversary review: proposals/contract-audit/output/runs/20260317-182046/codex-review.md
# DEGRADED: no

---

## Synchronization Contracts

---

**S-001: Promise 包裝 readline.question**

```
Trigger:      呼叫 question() 函數
Input:        query 字串
Output:       resolve 使用者輸入的字串
Condition:    rl 介面必須已建立且未關閉
Ordering:     在 main() 的 await 點之前建立
Risk:         MEDIUM -- Promise 永遠不會 reject；若 stdin 關閉（如 pipe EOF），resolve 得到 undefined 而非錯誤
Evidence:     create-page.js:43 -- `return new Promise((resolve) => rl.question(query, resolve))`
Scope:        method
Seam_Type:    object
Pinch_Point:  true
```

**S-002: async main 與混合同步 fs**

```
Trigger:      main() 被呼叫
Input:        無
Output:       頁面目錄結構寫入磁碟
Condition:    無
Ordering:     main() 是唯一的 async 進入點；部分同步 fs 操作（如 existsSync 檢查 examplePath）在 await question() 之前執行，其餘在 await 之後同步執行
Risk:         LOW -- 目前不影響正確性，但重構為 async fs 時順序保證會改變
Evidence:     create-page.js:123 -- `async function main()`
              create-page.js:128 -- `if (!fs.existsSync(examplePath))` (在 await 之前)
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

> [DISPUTED -- Auditor 原稱「所有 fs 操作都在 await question() 之後」，Adversary 指出 examplePath 的 existsSync 檢查在 await 之前。已修正 Ordering 與 Scope（module → method）。]

**S-003: 同步檔案系統操作阻塞**

```
Trigger:      copyDirectory / copyAndReplaceFile 執行期間
Input:        src/dest 路徑、replacements 物件
Output:       目錄與檔案被同步建立
Condition:    在 await question() 之後執行（使用者已提供輸入）
Ordering:     整體遵循 fs.existsSync → fs.mkdirSync → fs.readdirSync → fs.readFileSync → fs.writeFileSync 順序，但因目錄/檔案分支與遞迴，實際執行路徑非單一線性序列
Risk:         LOW -- CLI 工具，阻塞可接受；但若 example 目錄極大則體驗不佳
Evidence:     create-page.js:58 -- `fs.mkdirSync(dest, { recursive: true })`
              create-page.js:62 -- `fs.readdirSync(src, { withFileTypes: true })`
Scope:        module
Seam_Type:    none
Pinch_Point:  false
```

> [DISPUTED -- Adversary 指出「嚴格固定順序」表述過度，因遞迴與分支影響實際路徑。已修正 Ordering 描述。]

---

## Dependency Contracts

---

**D-001: Node.js 內建模組依賴**

```
Trigger:      模組載入時
Input:        無
Output:       fs, path, readline 模組可用
Condition:    Node.js 環境
Ordering:     在任何其他程式碼之前
Risk:         LOW -- 內建模組，無版本風險
Evidence:     create-page.js:12-14 -- `const fs = require('fs')` / `const path = require('path')` / `const readline = require('readline')`
Scope:        module
Seam_Type:    link
Pinch_Point:  false
```

> [META_ISSUE 已修正 -- Adversary 指出 `require(...)` 屬於連結/載入接縫，Seam_Type 由 none 修正為 link。]

**D-002: process.cwd() 工作目錄依賴**

```
Trigger:      建構 examplePath 與 pagePath 時
Input:        process.cwd() 回傳值
Output:       決定 example 來源和目標寫入位置
Condition:    假設 cwd 是專案根目錄（含 src/app/example）
Ordering:     在 fs.existsSync 檢查之前
Risk:         MEDIUM -- 若從非專案根目錄執行，examplePath 不存在時會被 existsSync 檢查攔截並提前退出（非靜默錯誤），但錯誤訊息未明確指出 cwd 問題
Evidence:     create-page.js:128 -- `path.join(process.cwd(), 'src', 'app', 'example')`
              create-page.js:149 -- `path.join(process.cwd(), 'src', 'app', pageName)`
Scope:        module
Seam_Type:    preprocessing
Pinch_Point:  true
```

> [DISPUTED -- Adversary 指出若 cwd 錯誤，existsSync 檢查會提前退出而非靜默建立錯誤目錄。已修正 Risk 由 HIGH 降為 MEDIUM 並更新描述。]

**D-003: example 資料夾存在性與內容依賴**

```
Trigger:      main() 開始時的存在性檢查
Input:        src/app/example 目錄
Output:       作為模板的完整目錄結構與檔案內容
Condition:    目錄必須存在且包含預期的字串模式（'example-route' 等）
Ordering:     existsSync 檢查在複製之前
Risk:         CRITICAL -- 只檢查目錄存在，不驗證內容結構。若 example 中的 ID 格式改變，
              replacements 中的 regex 會靜默不匹配，產出含有 "example" 字串的頁面
Evidence:     create-page.js:128-132 -- `if (!fs.existsSync(examplePath))`
Scope:        module
Seam_Type:    preprocessing
Pinch_Point:  true
```

**D-004: process.stdin/stdout 依賴**

```
Trigger:      readline.createInterface 建立時
Input:        process.stdin, process.stdout
Output:       互動式終端機介面
Condition:    程式碼未檢查 stdin.isTTY；在非 TTY 環境（CI/pipe）下不會報錯但行為不同
Ordering:     模組載入時立即建立
Risk:         MEDIUM -- 在非互動環境（CI/pipe）下，question() 會 resolve undefined 而非報錯
Evidence:     create-page.js:17-18 -- `input: process.stdin, output: process.stdout`
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

> [DISPUTED -- Adversary 指出「stdin 必須為 TTY」未被程式碼強制，無 isTTY 檢查。已修正 Condition 描述。]

**D-005: 字串模板中的動態 import 路徑（非實際依賴）**

```
Trigger:      main() 輸出註冊碼模板時
Input:        pageName 變數
Output:       console.log 輸出的字串（含 import() 語法）
Condition:    頁面建立成功後
Ordering:     在 copyDirectory 完成之後
Risk:         LOW -- 這些是輸出給使用者的程式碼模板字串，非實際 import。但若路徑慣例改變，模板會過時。
Evidence:     create-page.js:194-200 -- `route: () => import('@/app/${pageName}/mock/config/route/route')`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**D-006: 手動 Registry 更新依賴**

```
Trigger:      頁面建立成功後
Input:        pageName, componentName
Output:       console.log 輸出指引使用者手動編輯 config-registry.ts
Condition:    copyDirectory 成功完成
Ordering:     在所有檔案寫入完成之後
Risk:         MEDIUM -- 系統正確性依賴使用者手動編輯 config-registry.ts；若使用者忽略此步驟，新頁面無法被路由系統發現
Evidence:     create-page.js:302 -- `${colors.yellow}1. 手動添加到 config-registry.ts${colors.reset}`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

> [ADD -- Adversary 新增，具有效 filename:line 證據。]

---

## Error Handling Contracts

---

**E-001: try-catch 包裝整個 main 邏輯**

```
Trigger:      main() 內任何例外拋出
Input:        任何 Error 物件
Output:       log.error 輸出錯誤訊息 + console.error 完整堆疊
Condition:    無
Ordering:     catch 在 finally (rl.close) 之前
Risk:         HIGH -- catch 吞掉所有錯誤，process.exitCode 未設定。
              呼叫者（如 npm script）收到 exit code 0，即使操作失敗（部分檔案已寫入但未完成）
Evidence:     create-page.js:127 -- `try {`
              create-page.js:239-241 -- `catch (error) { log.error(...); console.error(error) }`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

**E-002: 驗證失敗的靜默退出**

```
Trigger:      pageName 格式不正確或頁面已存在
Input:        使用者輸入的 pageName
Output:       log.error + rl.close + return（無 process.exit、無 throw）
Condition:    !pageName || !/^[a-z0-9-]+$/.test(pageName) 或 fs.existsSync(pagePath)
Ordering:     在任何檔案操作之前
Risk:         MEDIUM -- 與 E-001 相同，exit code 為 0。在腳本組合中無法偵測失敗。
Evidence:     create-page.js:138-141 -- `if (!pageName || ...) { log.error(...); rl.close(); return }`
              create-page.js:146-149 -- `if (fs.existsSync(pagePath)) { log.error(...); rl.close(); return }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

## Mutation Contracts

---

**M-001: 目錄遞迴建立**

```
Trigger:      copyDirectory 被呼叫
Input:        src（example 路徑）、dest（新頁面路徑）
Output:       在 src/app/{pageName}/ 下建立完整目錄樹
Condition:    dest 不存在時才建立（fs.existsSync 檢查）
Ordering:     在 main() 驗證通過之後、在 copyAndReplaceFile 之前
Risk:         LOW -- recursive: true 會建立任意深度的路徑，但路徑由 entry.name 組成（非 replacements 影響），風險有限
Evidence:     create-page.js:57-59 -- `if (!fs.existsSync(dest)) { fs.mkdirSync(dest, { recursive: true }) }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

> [DISPUTED -- Adversary 指出路徑由 entry.name 組成，replacements 僅用於內容替換，不影響路徑。已修正 Risk 由 MEDIUM 降為 LOW 並更新描述。]

**M-002: 檔案內容替換與寫入**

```
Trigger:      copyAndReplaceFile 被呼叫（對 example 中的每個非目錄、非 README 項目）
Input:        src 檔案內容（UTF-8）、replacements 物件
Output:       替換後的內容寫入 dest 路徑
Condition:    entry 非目錄且非 README.md
Ordering:     在目錄建立之後
Risk:         HIGH -- 見 M-003
Evidence:     create-page.js:84-85 -- `let content = fs.readFileSync(src, 'utf-8')`
              create-page.js:110 -- `fs.writeFileSync(dest, content, 'utf-8')`
Scope:        method
Seam_Type:    object
Pinch_Point:  true
```

**M-003: 多重替換策略的順序與交互作用**

```
Trigger:      copyAndReplaceFile 中的 for...of 迴圈
Input:        replacements 物件的每個 key-value 對
Output:       content 字串被逐步替換
Condition:    三種路徑：(a) 含 regex 特殊字元 → 直接 RegExp, (b) 引號內替換 (`'${search}'`), (c) 註解替換 + 獨立單詞替換 (`\\b${search}\\b`)
Ordering:     Object.entries 的迭代順序決定替換結果（ES2015+ 字串 key 按插入順序）
Risk:         HIGH -- 替換順序依賴 JS 物件屬性的迭代順序，邏輯較脆弱。
              但引號內替換（quotedRegex）精確匹配 `'search'` 格式，不會意外命中含 hyphen 的複合詞
              （如 `'example-route'` 不會被 `'example'` 的 quotedRegex 命中）。
              wordRegex 的 `\\b` 邊界同樣不會匹配 hyphen 連接的子詞。
              主要風險在於新增替換 key 時若未理解三種策略的分流邏輯，可能產生非預期結果。
Evidence:     create-page.js:88-108 -- 整個 for...of 替換迴圈
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  true
```

> [DISPUTED -- Adversary 指出 `quotedRegex` 精確匹配 `'search'`（帶引號），`wordRegex` 的 `\b` 不會命中 hyphen 連接的複合詞，故 Auditor 描述的「'example' 先替換導致 'example-route' 永不匹配」的具體場景不成立。已修正 Risk 由 CRITICAL 降為 HIGH 並重寫風險描述。]

**M-004: README.md 跳過**

```
Trigger:      copyDirectory 遍歷到 README.md 檔案
Input:        entry.name === 'README.md'
Output:       該檔案被刻意跳過，不進行複製
Condition:    檔案名稱完全匹配 'README.md'
Ordering:     在 isDirectory 檢查之後、copyAndReplaceFile 之前
Risk:         LOW -- 刻意行為，但若 example 中新增小寫 readme.md 則不會被攔截
Evidence:     create-page.js:151 -- `if (entry.name === 'README.md') {`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

> [ADD -- Adversary 新增，具有效 filename:line 證據。]

---

## Lifecycle Contracts

---

**L-001: readline 介面生命週期**

```
Trigger:      模組載入（建立）；main() 結束或錯誤（關閉）
Input:        process.stdin / process.stdout
Output:       rl.close() 釋放 stdin
Condition:    finally 區塊確保關閉，但早期 return 路徑（L138, L147）各自也呼叫 rl.close()
Ordering:     建立（L16）→ 使用（L43 question）→ 關閉（L131/L141/L148/L242）
Risk:         LOW -- finally 保證關閉，早期 return 的重複 rl.close() 不會拋錯（idempotent）。
              但若重構移除 finally，三個早期退出點中任一遺漏都會導致 process 掛起。
Evidence:     create-page.js:16-19 -- `const rl = readline.createInterface(...)`
              create-page.js:131,141,148 -- `rl.close(); return`
              create-page.js:242 -- `finally { rl.close() }`
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

---

## Cancellation Contracts

---

**C-001: 驗證失敗的早期退出**

```
Trigger:      pageName 無效或頁面已存在
Input:        使用者輸入
Output:       rl.close() + return（不拋出錯誤）
Condition:    驗證條件失敗
Ordering:     在任何 fs 寫入操作之前
Risk:         LOW -- 安全地在副作用之前退出
Evidence:     create-page.js:138-141, 146-149
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**C-002: finally 區塊統一清理**

```
Trigger:      main() 結束（成功或失敗）
Input:        無
Output:       rl.close() 在 finally 統一釋放 I/O handle，避免程序懸掛
Condition:    無論成功、失敗或早期退出均執行
Ordering:     在 try/catch 之後，作為最終清理步驟
Risk:         LOW -- finally 保證執行，與 L-001 的早期退出 rl.close() 共同確保資源釋放
Evidence:     create-page.js:242 -- `finally { rl.close() }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

> [ADD -- Adversary 新增，具有效 filename:line 證據。]

---

## Propagation Contracts

---

**P-001: replacements 物件的傳播**

```
Trigger:      main() 建構 replacements → copyDirectory → copyAndReplaceFile
Input:        pageName, componentName, generateId() 結果
Output:       每個檔案的內容替換
Condition:    無
Ordering:     replacements 建構後不再修改（但內部含 regex 字串）
Risk:         HIGH -- replacements 物件跨越 3 層函數傳播，內部混合了純字串 key 和含 regex 語法的 key，
              但接收端（copyAndReplaceFile）的判斷邏輯（是否含 regex 特殊字元）與實際 key 的設計意圖不完全對齊
Evidence:     create-page.js:154-185 -- replacements 建構
              create-page.js:55 -- copyDirectory(examplePath, pagePath, replacements)
              create-page.js:78 -- copyAndReplaceFile(srcPath, destPath, replacements)
Scope:        module
Seam_Type:    preprocessing
Pinch_Point:  true
```

**P-002: generateId 的時間戳傳播**

```
Trigger:      replacements 建構期間多次呼叫 generateId
Input:        type 字串、pageName、Date.now()
Output:       格式為 `{type}-{pageName}-{timestamp}` 的字串
Condition:    無
Ordering:     同一次 main() 執行中多次呼叫，每次 Date.now() 可能不同
Risk:         LOW -- 同一批次的 ID 可能有 1-2ms 差異，但不影響唯一性
Evidence:     create-page.js:117-119 -- `return \`${type}-${pageName}-${Date.now()}\``
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

## Notification Contracts

---

**N-001: Console 通知通道**

```
Trigger:      建檔、錯誤、進度各階段
Input:        操作結果狀態
Output:       透過 log.success / log.error / log.info / console.log 向操作者發送狀態通知
Condition:    各操作階段完成或失敗時
Ordering:     穿插於整個 main() 流程中
Risk:         LOW -- 純輸出行為，無副作用；但若 stdout 被重導向，通知會靜默丟失
Evidence:     create-page.js:200 -- `log.success(\`建立檔案: ...\`)`
Scope:        module
Seam_Type:    none
Pinch_Point:  false
```

> [ADD -- Adversary 新增，具有效 filename:line 證據。]

---

## Skipped ADD

**[EXTERNAL] npm Runtime Invocation**: 跳過 -- 證據為 `[inferred from EXTERNAL_DEPENDENCY hint]`，非有效 filename:line，不符合 ADD 收錄標準。

---

## Risk Matrix

| ID | Risk | Description | Pinch Point |
|----|------|-------------|-------------|
| D-003 | CRITICAL | example 資料夾內容未驗證 | true |
| M-003 | HIGH | 替換策略順序與交互作用（降自 CRITICAL） | true |
| E-001 | HIGH | try-catch 吞掉錯誤，exit code 0 | true |
| M-002 | HIGH | 檔案寫入無原子性 | true |
| P-001 | HIGH | replacements 跨層傳播且混合 regex/純字串 | true |
| D-002 | MEDIUM | process.cwd() 假設（降自 HIGH） | true |
| S-001 | MEDIUM | Promise 不 reject | true |
| D-004 | MEDIUM | 非 TTY 環境無防護 | true |
| D-006 | MEDIUM | 手動 registry 更新依賴 | false |
| E-002 | MEDIUM | 驗證失敗靜默退出 | false |
| M-001 | LOW | 遞迴目錄建立（降自 MEDIUM） | false |
| M-004 | LOW | README.md 跳過 | false |
| L-001 | LOW | readline 生命週期 | true |
| S-002 | LOW | async/sync 混合 | false |
| S-003 | LOW | 同步 fs 阻塞 | false |
| C-001 | LOW | 早期退出 | false |
| C-002 | LOW | finally 統一清理 | false |
| N-001 | LOW | Console 通知通道 | false |
| P-002 | LOW | generateId 時間戳 | false |
| D-001 | LOW | Node.js 內建模組 | false |
| D-005 | LOW | 字串模板中的 import 路徑 | false |

---

## Merge Changelog

| Entry | Action | Detail |
|-------|--------|--------|
| S-001 | CONFIRM | 原樣保留 |
| S-002 | DISPUTE → 修正 | Ordering 修正（await 前有 fs 檢查）；Scope: module → method |
| S-003 | DISPUTE → 修正 | Ordering 修正（非嚴格固定序列） |
| D-001 | CONFIRM + META_ISSUE | Seam_Type: none → link |
| D-002 | DISPUTE → 修正 | Risk: HIGH → MEDIUM（existsSync 會攔截） |
| D-003 | CONFIRM | 原樣保留 |
| D-004 | DISPUTE → 修正 | Condition 修正（無 isTTY 檢查） |
| D-005 | CONFIRM | 原樣保留 |
| D-006 | ADD | 手動 Registry 更新依賴 |
| E-001 | CONFIRM | 原樣保留 |
| E-002 | CONFIRM | 原樣保留 |
| M-001 | DISPUTE → 修正 | Risk: MEDIUM → LOW（路徑不受 replacements 影響） |
| M-002 | CONFIRM | 原樣保留 |
| M-003 | DISPUTE → 修正 | Risk: CRITICAL → HIGH（quotedRegex 精確匹配不會產生描述的雙重替換） |
| M-004 | ADD | README.md 跳過 |
| L-001 | CONFIRM | 原樣保留 |
| C-001 | CONFIRM | 原樣保留 |
| C-002 | ADD | finally 統一清理 |
| P-001 | CONFIRM | 原樣保留 |
| P-002 | CONFIRM | 原樣保留 |
| N-001 | ADD | Console 通知通道 |
| npm Runtime | ADD → SKIP | 證據不足（inferred，非 filename:line） |
