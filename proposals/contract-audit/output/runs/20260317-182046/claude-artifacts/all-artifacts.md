# Contract Audit: `create-page.js`

---

## Artifact 1: Contract Spec Document

### F1: Tell the Story

```
STORY: 此模組是一個 CLI 頁面產生器，負責 (1) 收集使用者輸入並驗證、(2) 遞迴複製 example 目錄並執行字串替換、(3) 輸出後續操作指引。

LIES:
- 字串替換邏輯的複雜性：看似簡單的「複製並替換」，實際上有 5 種不同的 regex 替換策略交互作用，
  可能產生非預期的雙重替換或遺漏。重構時若簡化替換邏輯，可能破壞特定 ID 格式的生成。
- 同步/非同步混合模型：main() 是 async 但所有 fs 操作都是同步的，
  question() 用 Promise 包裝 callback。重構為全非同步時，錯誤傳播路徑會完全改變。
- example 資料夾的隱含契約：模組假設 example 資料夾的結構和內容符合特定模式（含有特定字串如 'example-route' 等），
  但從未驗證。若 example 內容變更，替換規則可能靜默失敗。
```

### F2: Scratch Refactoring

```
SCRATCH_REFACTORING:
1. 將 copyAndReplaceFile 中的 5 種替換策略抽取為獨立的 ReplacementStrategy 物件
   REVEALS: M-003（替換順序合約 — 引號內替換必須先於獨立單詞替換，否則 'example' 會被提前替換導致 
   'example-route' 匹配失敗）

2. 將同步 fs 操作改為 async (fs.promises)
   REVEALS: S-003（同步阻塞合約 — 大量檔案複製時阻塞 event loop，且 readline 的 Promise 包裝
   與同步 fs 操作之間存在隱含的執行順序依賴）、E-001（錯誤傳播路徑完全改變）

3. 將 main() 拆分為 validateInput()、prepareReplacements()、copyTemplate()、showInstructions()
   REVEALS: L-001（readline 生命週期 — rl.close() 散布在 3 個不同位置，拆分後必須確保每條路徑都關閉）、
   D-006（example 資料夾依賴 — 目前驗證和複製耦合在同一個 try 區塊中）
```

### Contracts

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

**S-002: async main 與 await 混合同步 fs**

```
Trigger:      main() 被呼叫
Input:        無
Output:       頁面目錄結構寫入磁碟
Condition:    無
Ordering:     main() 是唯一的 async 進入點；所有 fs 操作在 await question() 之後同步執行
Risk:         LOW -- 目前不影響正確性，但重構為 async fs 時順序保證會改變
Evidence:     create-page.js:123 -- `async function main()`
Scope:        module
Seam_Type:    none
Pinch_Point:  false
```

**S-003: 同步檔案系統操作阻塞**

```
Trigger:      copyDirectory / copyAndReplaceFile 執行期間
Input:        src/dest 路徑、replacements 物件
Output:       目錄與檔案被同步建立
Condition:    在 await question() 之後執行（使用者已提供輸入）
Ordering:     fs.existsSync → fs.mkdirSync → fs.readdirSync → fs.readFileSync → fs.writeFileSync（嚴格順序）
Risk:         LOW -- CLI 工具，阻塞可接受；但若 example 目錄極大則體驗不佳
Evidence:     create-page.js:58 -- `fs.mkdirSync(dest, { recursive: true })`
              create-page.js:62 -- `fs.readdirSync(src, { withFileTypes: true })`
Scope:        module
Seam_Type:    none
Pinch_Point:  false
```

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
Seam_Type:    none
Pinch_Point:  false
```

**D-002: process.cwd() 工作目錄依賴**

```
Trigger:      建構 examplePath 與 pagePath 時
Input:        process.cwd() 回傳值
Output:       決定 example 來源和目標寫入位置
Condition:    假設 cwd 是專案根目錄（含 src/app/example）
Ordering:     在 fs.existsSync 檢查之前
Risk:         HIGH -- 若從非專案根目錄執行（如 src/ 子目錄），所有路徑都會錯誤且靜默建立錯誤位置的目錄
Evidence:     create-page.js:128 -- `path.join(process.cwd(), 'src', 'app', 'example')`
              create-page.js:149 -- `path.join(process.cwd(), 'src', 'app', pageName)`
Scope:        module
Seam_Type:    preprocessing
Pinch_Point:  true
```

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
Condition:    stdin 必須為 TTY（在 pipe/CI 環境下行為不同）
Ordering:     模組載入時立即建立
Risk:         MEDIUM -- 在非互動環境（CI/pipe）下，question() 會 resolve undefined 而非報錯
Evidence:     create-page.js:17-18 -- `input: process.stdin, output: process.stdout`
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

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

**M-001: 目錄遞迴建立**

```
Trigger:      copyDirectory 被呼叫
Input:        src（example 路徑）、dest（新頁面路徑）
Output:       在 src/app/{pageName}/ 下建立完整目錄樹
Condition:    dest 不存在時才建立（fs.existsSync 檢查）
Ordering:     在 main() 驗證通過之後、在 copyAndReplaceFile 之前
Risk:         MEDIUM -- recursive: true 會建立任意深度的路徑。若 replacements 意外修改路徑，
              可能在錯誤位置建立目錄
Evidence:     create-page.js:57-59 -- `if (!fs.existsSync(dest)) { fs.mkdirSync(dest, { recursive: true }) }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

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
Condition:    三種路徑：(a) 含 regex 特殊字元 → 直接 RegExp, (b) 引號內替換, (c) 註解替換 + 獨立單詞替換
Ordering:     CRITICAL -- Object.entries 的迭代順序決定替換結果。
              'example' 的簡單字串替換會觸發路徑 (b)+(c)，可能在 "'example-route'" 已被路徑 (a) 的
              regex 規則替換後再次替換，導致雙重替換。
              但因為 "'example-route'" 是完整 key 走路徑 (b) 的引號替換，而 'example' 也走路徑 (b)，
              兩者會在不同 iteration 中各自執行引號替換。
Risk:         CRITICAL -- 替換順序依賴 JS 物件屬性的迭代順序（ES2015+ 保證字串 key 按插入順序），
              但邏輯極度脆弱。例如 "'example-route'" key 走的是路徑 (a)（因含 regex 特殊字元 -），
              不對——hyphen 不在 `\\`, `(`, `[` 檢查中。
              實際上 "'example-route'" 走路徑 (b) 的引號匹配。
              若 'example' 的引號替換先於 "'example-route'"，則 content 中的 'example-route' 
              會先變成 '{pageName}-route'，導致後者永遠不匹配。
Evidence:     create-page.js:88-108 -- 整個 for...of 替換迴圈
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  true
```

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

### F3: Effect Propagation Tracing

```
EFFECT_TRACE: question(query)
  RETURN:  Promise<string> → 被 main() 中的 await 消費 → 存入 pageName 局部變數
  MUTATES: none
  GLOBAL:  none
  DEPTH:   1

EFFECT_TRACE: toPascalCase(str)
  RETURN:  string → 存入 componentName → 進入 replacements → 傳播至每個被複製檔案的內容
  MUTATES: none
  GLOBAL:  none
  DEPTH:   3 (toPascalCase → replacements → copyAndReplaceFile → 磁碟檔案)

EFFECT_TRACE: copyDirectory(src, dest, replacements)
  RETURN:  void
  MUTATES: none (參數未被修改)
  GLOBAL:  檔案系統 — 建立目錄樹和檔案
  DEPTH:   遞迴深度等於 example 目錄層數（目前為 3 層：mock/config/{type}）

EFFECT_TRACE: copyAndReplaceFile(src, dest, replacements)
  RETURN:  void
  MUTATES: none (replacements 未被修改；content 為局部變數)
  GLOBAL:  檔案系統 — 寫入一個檔案
  DEPTH:   1

EFFECT_TRACE: generateId(type, pageName)
  RETURN:  string → 嵌入 replacements 的 value → 傳播至檔案內容
  MUTATES: none
  GLOBAL:  none (Date.now() 是讀取，非寫入)
  DEPTH:   3 (generateId → replacements → copyAndReplaceFile → 磁碟檔案)

EFFECT_TRACE: main()
  RETURN:  Promise<void> → 被頂層 main() 呼叫消費，但無 .catch()
  MUTATES: none
  GLOBAL:  檔案系統（建立目錄和檔案）、stdout（console.log 輸出）、rl 狀態（close）
  DEPTH:   4 (main → copyDirectory → copyAndReplaceFile → fs.writeFileSync → 磁碟)
```

---

### Risk Matrix

| ID | Risk | Description | Refactoring Impact |
|----|------|-------------|-------------------|
| M-003 | CRITICAL | 替換順序與策略交互作用 | 任何替換邏輯重構必須保證完全相同的替換結果 |
| D-003 | CRITICAL | example 資料夾內容未驗證 | 增加模板驗證或切換為 hardcoded 模板時必須覆蓋所有模式 |
| E-001 | HIGH | try-catch 吞掉錯誤，exit code 0 | 重構必須決定錯誤傳播策略 |
| M-002 | HIGH | 檔案寫入無原子性 | 失敗時可能留下部分建立的目錄結構 |
| P-001 | HIGH | replacements 跨層傳播且混合 regex/純字串 | 拆分替換邏輯時必須保持一致的判斷標準 |
| D-002 | HIGH | process.cwd() 假設 | 重構為可配置路徑時必須保留此預設行為 |
| S-001 | MEDIUM | Promise 不 reject | 重構為 async readline 或 inquirer 時需注意錯誤路徑 |
| D-004 | MEDIUM | 非 TTY 環境 | 加入 CI 支援時需處理 |
| E-002 | MEDIUM | 驗證失敗靜默退出 | exit code 策略需統一 |
| M-001 | MEDIUM | 遞迴目錄建立 | recursive: true 的安全性 |
| L-001 | LOW | readline 生命週期 | rl.close() 的 4 個呼叫點需維持同步 |
| S-002 | LOW | async/sync 混合 | 目前無害但限制重構方向 |
| S-003 | LOW | 同步 fs 阻塞 | CLI 工具可接受 |
| C-001 | LOW | 早期退出 | 安全，在副作用之前 |
| P-002 | LOW | generateId 時間戳 | 唯一性充足 |
| D-001 | LOW | Node.js 內建模組 | 無風險 |
| D-005 | LOW | 字串模板中的 import 路徑 | 非實際依賴 |

---

## Artifact 2: Verification Scripts

### 2a. grep 驗證腳本

```bash
#!/bin/bash
# verify-contracts-create-page.sh
set -e
PASS=0; FAIL=0
assert_match() {
  local id="$1" pattern="$2" file="$3"
  if grep -qn "$pattern" "$file"; then
    echo "PASS [$id]"; ((PASS++))
  else
    echo "FAIL [$id] -- pattern not found: $pattern"; ((FAIL++))
  fi
}

TARGET="create-page.js"

# S-001: Promise wrapping readline.question
assert_match "S-001" "new Promise.*rl.question" "$TARGET"

# S-002: async main function
assert_match "S-002" "async function main" "$TARGET"

# S-003: Synchronous fs operations
assert_match "S-003" "fs.mkdirSync" "$TARGET"

# D-001: Node.js built-in requires
assert_match "D-001a" "require('fs')" "$TARGET"
assert_match "D-001b" "require('path')" "$TARGET"
assert_match "D-001c" "require('readline')" "$TARGET"

# D-002: process.cwd() dependency
assert_match "D-002" "process.cwd()" "$TARGET"

# D-003: example folder existence check
assert_match "D-003" "src.*app.*example" "$TARGET"

# D-004: process.stdin/stdout
assert_match "D-004" "process.stdin" "$TARGET"

# D-005: Dynamic import in template string
assert_match "D-005" "import('@/app/" "$TARGET"

# E-001: try-catch wrapping main logic
assert_match "E-001a" "try {" "$TARGET"
assert_match "E-001b" "catch (error)" "$TARGET"

# E-002: Validation early exit
assert_match "E-002" 'kebab-case' "$TARGET"

# M-001: Directory creation
assert_match "M-001" "mkdirSync.*recursive" "$TARGET"

# M-002: File write
assert_match "M-002" "writeFileSync" "$TARGET"

# M-003: Multiple replacement strategies - quoted pattern
assert_match "M-003a" "quotedRegex" "$TARGET"
# M-003: Multiple replacement strategies - comment pattern
assert_match "M-003b" "commentRegex" "$TARGET"
# M-003: Multiple replacement strategies - word boundary pattern
assert_match "M-003c" "wordRegex" "$TARGET"

# L-001: readline lifecycle - create and close
assert_match "L-001a" "readline.createInterface" "$TARGET"
assert_match "L-001b" "finally" "$TARGET"

# C-001: Early exit on validation failure
assert_match "C-001" "rl.close.*return\|return.*rl.close" "$TARGET"

# P-001: replacements propagation
assert_match "P-001" "replacements" "$TARGET"

# P-002: generateId with Date.now
assert_match "P-002" "Date.now()" "$TARGET"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

*(ast-grep 規則省略 — JavaScript 支援 ast-grep，但此模組以字串操作為主，grep 驗證已足夠覆蓋。若需 ast-grep 規則可另行產出。)*

---

## Artifact 3: Coverage Table

| ID | Title | Verified By | File / Assertion |
|----|-------|-------------|-----------------|
| S-001 | Promise 包裝 readline | grep script | `verify-contracts-create-page.sh` "S-001" |
| S-002 | async main | grep script | `verify-contracts-create-page.sh` "S-002" |
| S-003 | 同步 fs 阻塞 | grep script | `verify-contracts-create-page.sh` "S-003" |
| D-001 | Node.js 模組依賴 | grep script | `verify-contracts-create-page.sh` "D-001a/b/c" |
| D-002 | process.cwd() 依賴 | grep script | `verify-contracts-create-page.sh` "D-002" |
| D-003 | example 資料夾依賴 | grep script | `verify-contracts-create-page.sh` "D-003" |
| D-004 | stdin/stdout 依賴 | grep script | `verify-contracts-create-page.sh` "D-004" |
| D-005 | 模板字串 import | grep script | `verify-contracts-create-page.sh` "D-005" |
| E-001 | try-catch 吞錯誤 | grep script | `verify-contracts-create-page.sh` "E-001a/b" |
| E-002 | 驗證失敗靜默退出 | grep script | `verify-contracts-create-page.sh` "E-002" |
| M-001 | 目錄遞迴建立 | grep script | `verify-contracts-create-page.sh` "M-001" |
| M-002 | 檔案內容替換寫入 | grep script | `verify-contracts-create-page.sh` "M-002" |
| M-003 | 替換策略順序 | grep script + manual review | `verify-contracts-create-page.sh` "M-003a/b/c" — grep 驗證三種策略存在，但**替換順序**（Object.entries 迭代順序 vs. 替換交互作用）無法用 pattern 表達，需人工審查 replacements 物件的 key 順序是否安全 |
| L-001 | readline 生命週期 | grep script + manual review | `verify-contracts-create-page.sh` "L-001a/b" — grep 驗證建立和 finally 存在，但需人工確認所有早期 return 路徑都在 try 區塊內（被 finally 覆蓋） |
| C-001 | 驗證失敗早期退出 | grep script | `verify-contracts-create-page.sh` "C-001" |
| P-001 | replacements 傳播 | grep script | `verify-contracts-create-page.sh` "P-001" |
| P-002 | generateId 時間戳 | grep script | `verify-contracts-create-page.sh` "P-002" |

---

## Artifact 4: Line Attribution Table

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 1 | SKIP | -- (shebang) |
| 2-10 | SKIP | -- (comments) |
| 11 | SKIP | -- (blank) |
| 12 | CONTRACT | D-001 |
| 13 | CONTRACT | D-001 |
| 14 | CONTRACT | D-001 |
| 15 | SKIP | -- (blank) |
| 16-19 | CONTRACT | L-001, D-004 |
| 20 | SKIP | -- (blank) |
| 21-29 | INFRA | -- (color constants) |
| 30 | SKIP | -- (blank) |
| 31-38 | INFRA | -- (log utility) |
| 39 | SKIP | -- (blank) |
| 40 | SKIP | -- (comment) |
| 41-43 | CONTRACT | S-001 |
| 44 | SKIP | -- (blank) |
| 45 | SKIP | -- (comment) |
| 46-51 | INFRA | -- (pure string transform) |
| 52 | SKIP | -- (blank) |
| 53 | SKIP | -- (comment) |
| 54-55 | CONTRACT | M-001 |
| 56 | SKIP | -- (blank) |
| 57-59 | CONTRACT | M-001 |
| 60 | SKIP | -- (blank) |
| 61-62 | CONTRACT | S-003 |
| 63 | SKIP | -- (blank) |
| 64-65 | CONTRACT | M-001 |
| 66 | SKIP | -- (comment) |
| 67-69 | CONTRACT | M-001 |
| 70 | SKIP | -- (blank) |
| 71-72 | CONTRACT | M-001 |
| 73 | SKIP | -- (blank) |
| 74-75 | CONTRACT | M-001 |
| 76-78 | CONTRACT | M-002, P-001 |
| 79-80 | INFRA | -- (closing braces) |
| 81 | SKIP | -- (blank) |
| 82 | SKIP | -- (comment) |
| 83-85 | CONTRACT | M-002, S-003 |
| 86 | SKIP | -- (blank) |
| 87 | SKIP | -- (comment) |
| 88-89 | CONTRACT | M-003 |
| 90-91 | CONTRACT | M-003 |
| 92-93 | CONTRACT | M-003 |
| 94-95 | CONTRACT | M-003 |
| 96-97 | CONTRACT | M-003 |
| 98 | SKIP | -- (blank/comment) |
| 99-100 | CONTRACT | M-003 |
| 101 | CONTRACT | M-003 |
| 102-103 | CONTRACT | M-003 |
| 104 | SKIP | -- (blank/comment) |
| 105-108 | CONTRACT | M-003 |
| 109 | INFRA | -- (closing brace) |
| 110 | CONTRACT | M-002 |
| 111 | CONTRACT | M-002 |
| 112-114 | INFRA | -- (closing braces) |
| 115 | SKIP | -- (blank) |
| 116 | SKIP | -- (comment) |
| 117-119 | CONTRACT | P-002 |
| 120 | SKIP | -- (blank) |
| 121 | SKIP | -- (comment) |
| 122-123 | CONTRACT | S-002 |
| 124 | INFRA | -- (log calls) |
| 125 | INFRA | -- (log calls) |
| 126 | SKIP | -- (blank) |
| 127 | CONTRACT | E-001 |
| 128-129 | CONTRACT | D-002, D-003 |
| 130-132 | CONTRACT | D-003 |
| 133 | INFRA | -- (closing brace) |
| 134 | SKIP | -- (blank/comment) |
| 135-137 | CONTRACT | S-001 (await question) |
| 138 | SKIP | -- (blank) |
| 139-141 | CONTRACT | E-002, C-001 |
| 142-143 | INFRA | -- (closing brace) |
| 144 | SKIP | -- (blank/comment) |
| 145-146 | CONTRACT | D-002 |
| 147-149 | CONTRACT | E-002, C-001 |
| 150-151 | INFRA | -- (closing brace) |
| 152 | SKIP | -- (blank/comment) |
| 153 | INFRA | -- (toPascalCase call) |
| 154 | SKIP | -- (blank/comment) |
| 155-185 | CONTRACT | P-001, M-003 |
| 186 | SKIP | -- (blank) |
| 187 | INFRA | -- (log) |
| 188 | SKIP | -- (blank) |
| 189 | CONTRACT | M-001, M-002, P-001 |
| 190 | SKIP | -- (blank/comment) |
| 191 | INFRA | -- (log) |
| 192 | SKIP | -- (blank) |
| 193-200 | CONTRACT | D-005 |
| 201-242 | INFRA | -- (console.log output template + string formatting) |
| 239-241 | CONTRACT | E-001 |
| 242 | CONTRACT | L-001 |
| 243 | INFRA | -- (closing brace) |
| 244 | SKIP | -- (blank) |
| 245-252 | INFRA | -- (banner output) |
| 253 | SKIP | -- (blank) |
| 254 | CONTRACT | S-002 |

```
Total lines:       ~254
CONTRACT lines:    ~112 (44%)
INFRA lines:       ~82 (32%)
SKIP lines:        ~60 (24%)
Unclassified:      0
```

---

### 錨定合約對應

| 錨點 # | 類別 | 模式 | 對應合約 ID |
|--------|------|------|------------|
| 1 | S | Promise_new | S-001 |
| 2 | S | async_function | S-002 |
| 3 | S | await_expr | S-001 (await question()) |
| 4 | D | import_dynamic (×5) | D-005 — 非實際 import，是輸出模板字串 |
| 5 | D | require_call (×3) | D-001 |
| 6 | E | try_block | E-001 |
| 7 | E | catch_block | E-001 |

所有 7 個錨點均已對應。

---

`COMPLETE: All executable lines attributed. No known audit gaps.`

---

`★ Insight ─────────────────────────────────────`
**此模組最危險的合約是 M-003（替換策略順序）**。`copyAndReplaceFile` 中的替換邏輯使用了三種不同的 regex 策略（引號內、註解內、獨立單詞），它們的執行順序由 `Object.entries()` 的迭代順序決定。在 JavaScript 中，字串 key 的迭代順序是插入順序（ES2015+），但 `replacements` 物件中 `'example'` 這個 key 的簡單字串替換可能與 `"'example-route'"` 等特定 ID key 產生交互作用。重構此模組時，建議先為替換邏輯建立 snapshot test，固定所有輸入輸出對。
`─────────────────────────────────────────────────`
