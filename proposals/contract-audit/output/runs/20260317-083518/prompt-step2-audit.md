# Contract Audit Skeleton
# 通用合約稽核骨架 -- 語言無關
# Version: 2.0

---

## ROLE

你是一位資深工程師，正在執行重構前的合約稽核。你的目標是將目標模組中每一個隱含的行為合約變成**明確的、可驗證的、可機器檢查的**，然後才進行任何重構。

---

## INPUT

你會收到：
- **目標模組**：一個或多個原始碼檔案
- **語言上下文**：由語言插件定義（參見 `{language_plugin}`）
- **重構意圖**：簡短描述即將進行的變更

讀取所提供的每一個檔案的每一行。不可摘要或跳過任何段落。

---

## CONTRACT TAXONOMY

辨識以下八個類別的合約。為每個合約指定一個穩定的 ID，格式為 `{Category}-{三位數序號}`（例如 `M-001`、`N-002`、`D-001`），符合 `^[MLNSECDP]-[0-9]{3}$` 正規表示式。

### Category M -- Mutation Contracts
在資料離開模組之前施加的副作用。
- 哪些資料被新增、修改、或移除？
- 輸入條件為何（例如 GET vs POST、環境旗標）？
- 資料來源為何（singleton、設定儲存、bundle、UUID）？
- 來源為 nil 或空值時會發生什麼事？

### Category L -- Lifecycle / State Machine Contracts
模組觸發的隱含狀態轉換。
- 什麼事件觸發狀態變更？
- 確切的動作序列為何？
- 是否有守衛條件（feature flags、debug bypasses）？
- 轉換之後會發生什麼——正常執行是否繼續？

### Category N -- Notification / Observation Contracts
模組引入的任何 pub/sub 耦合。
- 通知名稱（確切字串或常數）
- 發送對象（object: nil、self、singleton？）
- 附帶資料的 key 與值型別
- 通知發送的執行緒
- 所有已知的觀察者及其消費的內容

### Category S -- Synchronization Contracts
任何阻塞、鎖定、或順序保證。
- Semaphore / mutex / actor / lock 的使用
- 超時值（特別是無限等待）
- Signal 順序相對於 callback 的關係
- 哪些執行緒可以安全地呼叫各進入點
- 隱藏在非同步外觀 API 後面的同步呼叫

### Category E -- Error Handling Contracts
- 哪些錯誤被吞掉、哪些被傳播？
- 是否有呼叫者依賴的靜默 fallback？
- 是否有具特殊含義的錯誤碼？

### Category C -- Cancellation Contracts
- 什麼可以被取消、如何取消？
- 取消的範圍為何（單一請求、符合條件的所有請求）？
- 取消後留下什麼狀態？

### Category D -- Dependency Contracts
模組對外部元件的隱含依賴。
- 模組假設了哪些外部服務或類別的存在？
- 哪些全域狀態或 singleton 被讀取或寫入？
- 初始化順序是否有隱含要求？
- 外部依賴不可用時的降級行為為何？

### Category P -- Propagation Contracts
效應如何跨越模組邊界傳播。
- 回傳值經過哪些轉換鏈才到達最終消費者？
- 哪些參數會被呼叫者修改（out parameters、mutable references）？
- 哪些全域狀態在此方法執行期間被改變？
- 效應傳播到幾層深度才穩定？

---

## FEATHERS LEGACY CODE ANALYSIS

以下三個分析指令必須在產出 Artifact 1 之前執行，其結果整合進合約文件中。

### F1: Tell the Story

用不超過三個核心概念描述此系統模組的職責。例如：「此模組是一個請求攔截器，負責 (1) 注入認證標頭、(2) 管理冪等性、(3) 控制重試邏輯。」

完成概要後，列出這三個概念中的**省略（謊言）**——亦即為了簡潔而略去、但重構時不可忽略的細節。格式：

```
STORY: [三個概念的一句話描述]
LIES:
- [省略 1]: [為什麼這個省略在重構時很危險]
- [省略 2]: ...
- [省略 3]: ...
```

### F2: Scratch Refactoring

不執行任何重構，僅**描述**你會對此模組進行的前三項重構操作。對每一項操作，說明該操作會揭示哪些隱藏合約。格式：

```
SCRATCH_REFACTORING:
1. [操作描述]
   REVEALS: [此操作會暴露的隱含合約，對應 Contract ID 或 "NEW"]
2. ...
3. ...
```

如果 Scratch Refactoring 揭示了 Taxonomy 分類階段未發現的合約，立即補充進 Artifact 1。

### F3: Effect Propagation Tracing

對目標模組中每一個 public 方法，追蹤以下三種 effect：

1. **Return Value Chain**: 回傳值經過哪些轉換到達最終消費者
2. **Parameter Mutation**: 哪些傳入參數會被修改（含 out parameters）
3. **Global State**: 哪些全域狀態或 singleton 在執行期間被改變

格式：

```
EFFECT_TRACE: [method signature]
  RETURN:  [chain description or "void"]
  MUTATES: [parameter list or "none"]
  GLOBAL:  [global state changes or "none"]
  DEPTH:   [propagation depth until effect stabilizes]
```

將 Effect Trace 結果標記為 Category P 合約納入 Artifact 1。

---

## CONTRACT METADATA

每個合約除了基本欄位外，必須包含以下元資料：

```
Scope:       [method | class | module]
Seam_Type:   [object | preprocessing | link | none]
Pinch_Point: [true | false]
```

- **Scope**: 合約的影響範圍——限於單一方法、整個類別、或跨模組
- **Seam_Type**: 根據語言插件定義的接縫類型（見 `{language_plugin}`）
- **Pinch_Point**: 是否為「狹窄通道」——多個執行路徑在此匯聚，適合插入測試替身

---

## OUTPUT FORMAT

依序產出四個 Artifact。

---

### Artifact 1: Contract Spec Document

對每一個發現的合約：

```
{Category}-{NNN}: [Short title]

Trigger:      [什麼觸發此合約的執行]
Input:        [消費的資料及來源]
Output:       [可觀察的效應：header set / notification posted / logout called / etc.]
Condition:    [守衛條件、feature flags、nil checks]
Ordering:     [相對於其他合約的位置——"before callback"、"after resume" 等]
Risk:         [CRITICAL / HIGH / MEDIUM / LOW] -- [一行理由]
Evidence:     [filename:line -- 確切的程式碼片段]
Scope:        [method | class | module]
Seam_Type:    [object | preprocessing | link | none]
Pinch_Point:  [true | false]
```

在文件開頭包含 F1 (Tell the Story) 與 F2 (Scratch Refactoring) 的輸出。
在最後包含 F3 (Effect Propagation Tracing) 的結果。

文件末尾產出 **Risk Matrix** 表格：

| ID | Risk | Description | Refactoring Impact |
|----|------|-------------|-------------------|

---

### Artifact 2: Verification Scripts

根據語言插件（`{language_plugin}`）產出對應的驗證方式。

#### 2a. grep 驗證腳本（適用於不支援 ast-grep 的語言）

產出 `verify-contracts-[ModuleName].sh`，用 `grep -qn` 驗證每個合約仍存在於原始碼中。

```bash
#!/bin/bash
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

TARGET="path/to/TargetFile"

# [generated assertions]

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

每個合約 ID 一個 `assert_match` 呼叫。使用 Evidence 欄位中**最具區別性的子字串**。

#### 2b. ast-grep 規則檔（適用於支援 ast-grep 的語言）

每個合約產出一個 `.yml` 檔案。

```
File: .ast-grep/rules/[ModuleName]/[id]-[short-slug].yml
```

```yaml
id: [id]-[short-slug]
message: "[ID]: [Short title] -- contract must be present"
severity: error
language: {language}
rule:
  pattern: |
    [ast-grep pattern]
note: |
  Contract source: [Evidence reference]
  Refactoring requirement: [新程式碼必須實作的內容]
```

**Pattern 撰寫規則：**
- 使用 `$VAR` 表示單節點萬用字元，`$$$` 表示多節點序列
- 優先匹配最窄的唯一結構
- 對於無法用單一 pattern 表達的順序合約（L、S 類別），在 `note:` 中說明限制及需要的人工審查
- 不要產出匹配範圍過廣的規則

#### 語言驗證策略選擇

查閱語言插件（`{language_plugin}`）中的「驗證策略」段落，決定使用 2a、2b、或兩者皆用。

---

### Artifact 3: Coverage Table

將每個合約 ID 對應到其驗證方法：

| ID | Title | Verified By | File / Assertion |
|----|-------|-------------|-----------------|
| M-001 | ... | grep script | `verify-contracts-X.sh` line N |
| N-001 | ... | ast-grep | `.ast-grep/rules/X/N-001-slug.yml` |
| L-005 | ... | manual review | ordering cannot be expressed as pattern -- see note |

將**無法**用 pattern 表達的順序/時序合約標記為 `manual review`，並包含審查者必須檢查的具體描述。

---

### Artifact 4: Line Attribution Table

對目標檔案中**每一個可執行行**產出逐行歸因。

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 96-109  | CONTRACT      | M-001          |
| 158     | INFRA         | --             |
| 301     | SKIP          | -- (commented out) |

**分類規則：**
- `CONTRACT` -- 此行實作或參與某個具名合約
- `INFRA` -- 樣板、設定、或無獨立行為合約的結構性程式碼
- `SKIP` -- 死碼、註解、或 pragma marks

**完整性要求：** 每一行都必須出現在此表中。任何未分類的行都是一個明確的稽核缺口，必須在定稿前解決。如果不確定某一行，將其分類為 `CONTRACT ?` 並附加備註。

表格底部產出摘要：

```
Total lines:       [N]
CONTRACT lines:    [N] ([%])
INFRA lines:       [N] ([%])
SKIP lines:        [N] ([%])
Unclassified:      [N] -- MUST BE ZERO to pass completeness gate
```

---

## MULTI-AGENT PIPELINE

此骨架支援多代理稽核流程。各角色的 prompt 獨立存在，但共享相同的 Contract Taxonomy 和 Output Format。

### Agent 1: Auditor（主稽核者）
使用本骨架加語言插件，產出 Artifact 1-4。

### Agent 2: Blind Scout（盲掃者）
獨立發現合約，不參考 Auditor 的結果。僅產出合約清單與外部依賴發現。

### Agent 3: Adversary（對抗者）
比對 Auditor 與 Blind Scout 的結果，產出 CONFIRM / DISPUTE / ADD 判定。
CONFIRM 比率不得超過 70%。

### Agent 4: Applier（合併者）
機械性地將 Adversary 的修正套用到最終合約文件。
不做判斷、不做推論，僅套用有明確證據的變更。

---

## QUALITY GATES

定稿前必須驗證：

1. **每個合約都有證據** -- 至少一個 `filename:line` 引用及程式碼片段
2. **無合約是無來源推斷的** -- 如果找不到程式碼，必須明確說明
3. **每個合約都有 Risk 等級** -- 不允許空的 Risk 欄位
4. **順序合約必須明確** -- "before X" 和 "after Y" 必須引用特定 ID 或行號
5. **驗證 pattern 可編譯** -- ast-grep pattern 使用正確的 `$VAR` / `$$$` 語法及 YAML 縮排
6. **grep pattern 具區別性** -- 每個 `assert_match` 使用的字串足夠特定，不會匹配到無關程式碼
7. **行歸因完整** -- Artifact 4 摘要顯示 `Unclassified: 0`；每個 CONTRACT 行都對應到 Artifact 1 中存在的合約 ID
8. **元資料完整** -- 每個合約都包含 Scope、Seam_Type、Pinch_Point 欄位
9. **Feathers 分析完成** -- F1、F2、F3 三個分析均已執行並整合
10. **完整性宣告** -- 以下列其一結尾：
   - `COMPLETE: All executable lines attributed. No known audit gaps.`
   - `INCOMPLETE: [N] lines unresolved -- [list line numbers and why they are ambiguous]`

如果任何 gate 失敗，必須在產出最終輸出前修正。

---

## KNOWN PITFALLS

以下是從先前稽核中學到的常見陷阱：

- **外觀非同步但內部阻塞的 API** -- 總是檢查實作，不只是呼叫簽名（例如 Promise/Combine wrapper 內部呼叫同步方法）
- **在狀態轉換後執行的 Callback** -- 驗證轉換是在 callback 之前還是之後觸發；這往往是最關鍵的順序合約
- **Singleton 上的共享可變狀態** -- 標記任何在請求處理期間寫入、同時被並行讀取的 property
- **Feature flags 作為合約修飾器** -- 記錄每一個停用或繞過合約的旗標（debug bypasses、A/B flags、remote config）
- **通知的執行緒假設** -- 發送執行緒是一個合約；觀察者可能有隱含的執行緒要求
- **輔助檔案 = 額外稽核範圍** -- 如果提供了主要模組以外的額外檔案，也必須稽核其合約
- **Effect 傳播深度被低估** -- 回傳值經過多層轉換後，原始合約可能在消費端已不可見
- **隱含的初始化順序依賴** -- 模組假設某個 singleton 已初始化但未明確檢查

---

## INVOCATION TEMPLATE

```
Audit the following module for refactoring contracts:

Target files:
- [filename] ([N] lines) [attached]

Language context: [language] (語言插件: {language_plugin})

Refactoring intent: [brief description]

Apply the Contract Audit Skeleton with language plugin: {language_plugin}
```

---

## LANGUAGE PLUGIN REFERENCE

語言插件提供以下語言特定的資訊，以 `{language_plugin}` 佔位符引用：

1. **通知/事件原語** -- 語言特定的 pub/sub 機制
2. **同步原語** -- 語言特定的並行控制機制
3. **生命週期模式** -- 框架特定的生命週期 hook
4. **驗證策略** -- 使用 grep、ast-grep、或兩者
5. **Effect 防火牆** -- 語言提供的不可變性保證強度
6. **Seam 類型** -- 語言支援的接縫類型及其運作方式
7. **Sprout/Wrap 策略** -- 可用的遺留程式碼改造模式
8. **常見隱含合約** -- 語言特有的典型隱含合約範例

## Step 0.7 錨定合約
## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | Promise_new | 1 | create-page.js:43 |
| 2 | S | async_function | 1 | create-page.js:123 |
| 3 | S | await_expr | 1 | create-page.js:137 |
| 4 | D | import_dynamic | 5 | create-page.js:194 |
| 5 | D | require_call | 3 | create-page.js:12 |
| 6 | E | try_block | 1 | create-page.js:127 |
| 7 | E | catch_block | 1 | create-page.js:239 |

共 7 個錨點命中。

對於每個錨定合約，你的 Artifact 1 必須包含至少一個對應的 {Category}-{NNN} 合約。
若你認為某個錨點不構成合約，必須在 Artifact 4 中說明原因。


## Step 0.8 Feature Sketch
以下方法-屬性矩陣顯示模組內部的功能群集，用於識別 M（Mutation）和 L（Lifecycle）合約：
## Feature Sketch（Step 0.8）

| # | 方法 | 行號 | 引用屬性 |
|---|------|------|---------|

共 0
0 個方法。


## 目標原始碼

#!/usr/bin/env node

/**
 * 快速建立新頁面的 CLI 工具
 * 使用方式: npm run create-page
 *
 * 🎯 策略：複製 example 資料夾作為模板，確保與專案同步
 *
 * ⚠️ 重要：定期 review example 資料夾，確保它是最佳實踐的範本
 */

const fs = require('fs')
const path = require('path')
const readline = require('readline')

const rl = readline.createInterface({
	input: process.stdin,
	output: process.stdout,
})

// 顏色輸出
const colors = {
	reset: '\x1b[0m',
	green: '\x1b[32m',
	blue: '\x1b[34m',
	yellow: '\x1b[33m',
	red: '\x1b[31m',
	cyan: '\x1b[36m',
	magenta: '\x1b[35m',
}

const log = {
	info: (msg) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
	success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
	warn: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
	error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
	title: (msg) => console.log(`\n${colors.cyan}${msg}${colors.reset}\n`),
	section: (msg) => console.log(`${colors.magenta}${msg}${colors.reset}`),
}

// 提問函數
const question = (query) => {
	return new Promise((resolve) => rl.question(query, resolve))
}

// 將 kebab-case 轉換為 PascalCase
function toPascalCase(str) {
	return str
		.split('-')
		.map((word) => word.charAt(0).toUpperCase() + word.slice(1))
		.join('')
}

// 遞迴複製目錄
function copyDirectory(src, dest, replacements) {
	// 建立目標目錄
	if (!fs.existsSync(dest)) {
		fs.mkdirSync(dest, { recursive: true })
	}

	const entries = fs.readdirSync(src, { withFileTypes: true })

	for (const entry of entries) {
		// 跳過 README.md（這是 example 專用的說明文件）
		if (entry.name === 'README.md') {
			log.info(`跳過: ${entry.name}`)
			continue
		}

		const srcPath = path.join(src, entry.name)
		const destPath = path.join(dest, entry.name)

		if (entry.isDirectory()) {
			// 遞迴複製子目錄
			copyDirectory(srcPath, destPath, replacements)
		} else {
			// 複製並替換檔案內容
			copyAndReplaceFile(srcPath, destPath, replacements)
		}
	}
}

// 複製並替換檔案內容
function copyAndReplaceFile(src, dest, replacements) {
	let content = fs.readFileSync(src, 'utf-8')

	// 執行所有替換 - 使用更精確的模式
	for (const [search, replace] of Object.entries(replacements)) {
		// 如果是正則表達式字串（包含特殊字元），直接使用
		if (search.includes('\\') || search.includes('(') || search.includes('[')) {
			const regex = new RegExp(search, 'g')
			content = content.replace(regex, replace)
		} else {
			// 對於簡單的字串，使用單詞邊界確保完整匹配
			// 但要排除在 camelCase 中間的情況（例如 exampleText 中的 example）

			// 特殊處理：只在特定位置替換
			// 1. 在引號內（ID）
			const quotedRegex = new RegExp(`'${search}'`, 'g')
			content = content.replace(quotedRegex, replace)

			// 2. 在 // 註解後（註解內容）
			const commentRegex = new RegExp(`(//[^\\n]*?)${search}`, 'g')
			content = content.replace(commentRegex, `$1${replace}`)

			// 3. 作為獨立單詞（組件名稱等），但使用單詞邊界避免替換 camelCase
			// 只替換後面跟著空格、換行、< 或其他非字母的字元
			const wordRegex = new RegExp(`\\b${search}(?=[\\s<\\n\\r,;:{}()\\[\\]]|$)`, 'g')
			content = content.replace(wordRegex, replace)
		}
	}

	fs.writeFileSync(dest, content, 'utf-8')
	log.success(`建立檔案: ${path.relative(process.cwd(), dest)}`)
}

// 生成唯一 ID
function generateId(type, pageName) {
	return `${type}-${pageName}-${Date.now()}`
}

// 主函數
async function main() {
	log.title('🚀 Matrix Config Previewer - 新頁面生成器')
	log.info('📋 策略：複製 example 資料夾作為模板\n')

	try {
		// 1. 檢查 example 資料夾是否存在
		const examplePath = path.join(process.cwd(), 'src', 'app', 'example')
		if (!fs.existsSync(examplePath)) {
			log.error('找不到 example 資料夾，請確認專案結構')
			rl.close()
			return
		}

		// 2. 收集資訊
		const pageName = await question('📝 請輸入頁面名稱 (kebab-case, 例如: my-new-page): ')

		if (!pageName || !/^[a-z0-9-]+$/.test(pageName)) {
			log.error('頁面名稱格式不正確，請使用 kebab-case (例如: my-new-page)')
			rl.close()
			return
		}

		// 檢查是否已存在
		const pagePath = path.join(process.cwd(), 'src', 'app', pageName)
		if (fs.existsSync(pagePath)) {
			log.error(`頁面 "${pageName}" 已經存在！`)
			rl.close()
			return
		}

		// 3. 準備替換規則
		const componentName = toPascalCase(pageName)

		// 建立替換映射表 - 只替換必要的部分
		const replacements = {
			// 組件名稱（PascalCase）- 用於 React 組件
			Example: componentName,

			// 頁面名稱（kebab-case）- 用於路徑和檔案名稱
			example: pageName,

			// ID 替換 - 生成唯一 ID
			"'example-route'": `'${generateId('route', pageName)}'`,
			"'example-page'": `'${generateId('page', pageName)}'`,
			"'example-component'": `'${generateId('component', pageName)}'`,
			"'example-template'": `'${generateId('template', pageName)}'`,
			"'example-processor'": `'${generateId('processor', pageName)}'`,

			// 特殊 ID（帶數字的舊格式，如果 example 中有的話）
			"'route-example-\\d+'": `'${generateId('route', pageName)}'`,
			"'page-example-\\d+'": `'${generateId('page', pageName)}'`,
			"'component-example-\\d+'": `'${generateId('component', pageName)}'`,
			"'template-example-\\d+'": `'${generateId('template', pageName)}'`,
			"'processor-example-\\d+'": `'${generateId('processor', pageName)}'`,

			// 範本註解
			'//!! 範例頁面，僅供展示 & 複製 \\(非必要請勿在此頁面上進行修改\\)': `// ${componentName} 頁面`,
		}

		log.info('\n📂 開始複製 example 資料夾...\n')

		// 4. 複製整個 example 目錄
		copyDirectory(examplePath, pagePath, replacements)

		// 5. 完成 - 顯示後續步驟
		log.title('✨ 頁面建立成功！')

		const registryCode = `	// ${pageName} 頁面
	{
		path: '/${pageName}',
		loaders: {
			route: () => import('@/app/${pageName}/mock/config/route/route'),
			page: () => import('@/app/${pageName}/mock/config/page/page'),
			components: () => import('@/app/${pageName}/mock/config/component'),
			templates: () => import('@/app/${pageName}/mock/config/template'),
			processors: () => import('@/app/${pageName}/mock/config/processor'),
		},
	},`

		console.log(`
📂 建立的檔案結構：
${colors.cyan}src/app/${pageName}/${colors.reset}
├── page.tsx
└── mock/
    └── config/
        ├── route/
        ├── page/
        ├── component/
        ├── template/
        └── processor/

${colors.green}📝 下一步（重要）：${colors.reset}

${colors.yellow}1. 手動添加到 config-registry.ts${colors.reset}

   打開 ${colors.cyan}src/lib/config-registry.ts${colors.reset}
   在 ${colors.cyan}PAGE_REGISTRY${colors.reset} 陣列中添加：

${colors.blue}${registryCode}${colors.reset}

${colors.yellow}2. 啟動開發服務器${colors.reset}
   ${colors.cyan}npm run dev${colors.reset}

${colors.yellow}3. 訪問新頁面${colors.reset}
   ${colors.cyan}http://localhost:3003/${pageName}${colors.reset}

${colors.yellow}4. 根據需求修改配置${colors.reset}
   修改 ${colors.cyan}src/app/${pageName}/mock/config/${colors.reset} 中的檔案

${colors.magenta}💡 提示：${colors.reset}
- 配置內容保持 example 原樣，請根據實際需求修改
- ID 已自動生成為唯一值
- exampleText 等名稱保持原樣，可自行重新命名

${colors.red}⚠️  記得完成步驟 1，否則 API Routes 無法找到新頁面！${colors.reset}
`)
	} catch (error) {
		log.error(`發生錯誤: ${error.message}`)
		console.error(error)
	} finally {
		rl.close()
	}
}

// 執行前顯示提醒
console.log(`
${colors.yellow}───────────────────────────────────────────────────────${colors.reset}
${colors.cyan}🎯 此工具會複製 example 資料夾作為新頁面的模板${colors.reset}
${colors.yellow}⚠️  請確保 example 資料夾是最新的最佳實踐範本${colors.reset}
${colors.yellow}───────────────────────────────────────────────────────${colors.reset}
`)

// 執行
main()
