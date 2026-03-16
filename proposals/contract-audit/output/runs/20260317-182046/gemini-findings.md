Contract: Filesystem Mutation
Category: M
Trigger:  Running the script and providing a valid page name.
Effect:   Creates a new directory and files by copying and modifying the contents of the `src/app/example` directory.
Evidence: [cli.js:145] -- `copyDirectory(examplePath, pagePath, replacements)`

Contract: User Input Block
Category: S
Trigger:  The script calls the `question` function.
Effect:   The script's execution is paused, waiting for the user to provide input via stdin. This is a form of synchronous blocking in an otherwise async-capable environment.
Evidence: [cli.js:231] -- `const pageName = await question('📝 請輸入頁面名稱 (kebab-case, 例如: my-new-page): ')`

Contract: Template Directory Dependency
Category: D
Trigger:  The script starts execution.
Effect:   The script requires the existence of a specific directory (`src/app/example`) to function. If not found, the script will terminate with an error.
Evidence: [cli.js:225] -- `if (!fs.existsSync(examplePath)) { log.error('找不到 example 資料夾，請確認專案結構'); ... }`

Contract: Idempotency Failure
Category: L
Trigger:  Running the script with a page name that already exists.
Effect:   The script will refuse to run, preventing overwrites. It is not idempotent and does not offer a "force" option.
Evidence: [cli.js:240] -- `if (fs.existsSync(pagePath)) { log.error(`頁面 "${pageName}" 已經存在！`); ... }`

Contract: Input Validation
Category: E
Trigger:  Providing a page name that does not conform to the expected `kebab-case` format.
Effect:   The script terminates with a format error message instead of proceeding with a potentially problematic name.
Evidence: [cli.js:235] -- `if (!pageName || !/^[a-z0-9-]+$/.test(pageName)) { log.error('頁面名稱格式不正確，請使用 kebab-case (例如: my-new-page)'); ... }`

Contract: Uniqueness Propagation via Time
Category: P
Trigger:  The `generateId` function is called during content replacement.
Effect:   The current timestamp (`Date.now()`) is embedded into the content of the newly created files to ensure IDs are unique. This propagates a time-dependent value into the filesystem.
Evidence: [cli.js:215] -- `return `${type}-${pageName}-${Date.now()}``

Contract: Skipped File
Category: M
Trigger:  The `copyDirectory` function encounters a file named `README.md` in the source template.
Effect:   The file is explicitly skipped and not copied to the destination, altering the output from a pure 1:1 copy.
Evidence: [cli.js:159] -- `if (entry.name === 'README.md') { log.info(`跳過: ${entry.name}`); continue; }`

Contract: Cleanup on Exit
Category: C
Trigger:  The `main` function completes, either successfully or due to an error.
Effect:   The `readline` interface is explicitly closed, releasing its handle on stdin/stdout. This ensures the Node.js process can exit cleanly.
Evidence: [cli.js:332] -- `} finally { rl.close() }`

Contract: User-Directed Manual Dependency
Category: D
Trigger:  The script successfully completes its filesystem operations.
Effect:   The script outputs instructions for the user to manually edit `src/lib/config-registry.ts` and add a new entry. The application's correctness is dependent on this manual step being performed.
Evidence: [cli.js:296] -- `1. 手動添加到 config-registry.ts`

Contract: User Notification
Category: N
Trigger:  Various stages of the script's execution (start, success, error, file creation).
Effect:   Messages are printed to the console to inform the human operator of the script's status and next steps.
Evidence: [cli.js:101] -- `log.success(`建立檔案: ${path.relative(process.cwd(), dest)}`)`

TOTAL CONTRACTS FOUND: 10
CATEGORY BREAKDOWN: M=2 L=1 N=1 S=1 E=1 C=1 D=2 P=1

EXTERNAL_DEPENDENCY: src/app/example/ -- [source for template files]
EXTERNAL_DEPENDENCY: src/lib/config-registry.ts -- [target for manual configuration update, contains PAGE_REGISTRY]
EXTERNAL_DEPENDENCY: npm -- [runtime environment, script is invoked via `npm run create-page`]
