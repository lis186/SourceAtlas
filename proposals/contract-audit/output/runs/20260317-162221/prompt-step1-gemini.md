# Blind Contract Scout
# 盲掃合約發現者 -- 語言無關版本
# 此 prompt 由 Gemini 執行，獨立於主稽核者（Auditor）運作，不參考任何既有合約清單。

## ROLE

You are performing a blind behavioral contract discovery on one or more source files.
You have NO prior list of contract IDs. You are NOT trying to confirm anyone else's work.
Your only goal is to find every place this code makes an implicit promise to its callers.

The target code may be written in any language (`javascript`). Adapt your analysis accordingly.

## WHAT TO LOOK FOR

Scan for all eight categories of behavioral contracts:

| Category | What to look for |
|----------|-----------------|
| **M** -- Mutation | Side effects that modify data before it leaves the module |
| **L** -- Lifecycle | Implicit state transitions triggered by the module |
| **N** -- Notification | Any pub/sub coupling: events, notifications, signals, message buses |
| **S** -- Synchronization | Blocking, locks, ordering guarantees, thread assumptions |
| **E** -- Error Handling | Swallowed errors, silent fallbacks, special error codes |
| **C** -- Cancellation | What can be cancelled, scope, residual state after cancellation |
| **D** -- Dependency | Implicit reliance on external components, singletons, init order |
| **P** -- Propagation | How effects cross module boundaries: return value chains, parameter mutation, global state changes |

For each behavioral contract you find, record:
- What triggers it (call site, method entry, condition)
- What it does (mutation, state change, event dispatch, lock, error handling, etc.)
- Exact filename and line number
- One-sentence description

## OUTPUT FORMAT

For each contract:

```
Contract: [short title]
Category: [M | L | N | S | E | C | D | P]
Trigger:  [what causes it]
Effect:   [what observable change it makes]
Evidence: [filename:line -- exact code fragment]
```

After listing all contracts, add a summary line:
```
TOTAL CONTRACTS FOUND: [N]
CATEGORY BREAKDOWN: M=[n] L=[n] N=[n] S=[n] E=[n] C=[n] D=[n] P=[n]
```

## Section 4: Boundary Discovery

After listing all contracts, investigate what lies OUTSIDE the provided files.
For each of the following, list files you suspect exist based on the code you see:

1. **Event/Notification Observers**: This code dispatches events or notifications. What classes or modules likely observe them?
   Search for: any observer registration, event listener setup, or subscription calls referencing the same event names.

2. **External Synchronization**: This code uses synchronization primitives (locks, semaphores, actors, mutexes, async barriers). Are there other classes with similar patterns?

3. **Downstream Lifecycle**: This code calls cleanup, teardown, or shutdown helpers. What classes implement them?

4. **Singleton / Global State**: This code reads or writes shared global state. What other modules depend on the same state?

5. **Propagation Endpoints**: This code returns values or mutates parameters that cross module boundaries. What are the likely consumers?

For each finding, output:
```
EXTERNAL_DEPENDENCY: [suspected filename or class/module name] -- [reason / what event or call triggers it]
```

If you cannot find evidence, output:
```
EXTERNAL_DEPENDENCY: (none found)
```

## INSTRUCTIONS

- Read every line of the provided source file(s). Do not skip sections.
- If you are unsure whether something is a contract, include it and mark it "(uncertain)".
- Do NOT use contract IDs from any other document. Assign no IDs.
- Do NOT produce verification scripts or ast-grep rules. Discovery only.
- Adapt your analysis to `javascript` idioms -- for example, use language-appropriate terminology for events, notifications, lifecycle hooks, and synchronization primitives.


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
