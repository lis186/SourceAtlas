Contract: Filesystem Write
Category: M
Trigger:  Calling `copyDirectory` or `copyAndReplaceFile`.
Effect:   Creates new directories and files on the filesystem based on the 'example' template.
Evidence: create-page.js:101 -- `fs.mkdirSync(dest, { recursive: true })`
Evidence: create-page.js:151 -- `fs.writeFileSync(dest, content, 'utf-8')`

Contract: User Input Block
Category: S
Trigger:  Awaiting the `question` function.
Effect:   Pauses script execution until the user provides input via the command line.
Evidence: create-page.js:203 -- `const pageName = await question('📝 請輸入頁面名稱 (kebab-case, 例如: my-new-page): ')`

Contract: Readline Interface Lifecycle
Category: L
Trigger:  Script startup and shutdown.
Effect:   An instance of `readline.Interface` is created at the start and is guaranteed to be closed via a `finally` block before the script exits, releasing its handle on stdin/stdout.
Evidence: create-page.js:19 -- `const rl = readline.createInterface({...})`
Evidence: create-page.js:275 -- `rl.close()`

Contract: Input Validation Error
Category: E
Trigger:  Providing a page name that is empty or not in kebab-case format.
Effect:   The script logs an error message and terminates immediately. No files are created.
Evidence: create-page.js:206 -- `log.error('頁面名稱格式不正確，請使用 kebab-case (例如: my-new-page)')`

Contract: Pre-existence Error
Category: E
Trigger:  Entering a page name that corresponds to an existing directory.
Effect:   The script logs an error and terminates, preventing overwrites.
Evidence: create-page.js:213 -- `log.error(\`頁面 "${pageName}" 已經存在！\`)`

Contract: Template Dependency
Category: D
Trigger:  Running the script.
Effect:   The script implicitly depends on the existence and structure of the `src/app/example` directory. If not found, it errors out.
Evidence: create-page.js:195 -- `if (!fs.existsSync(examplePath)) { ... }`

Contract: Node Module Dependency
Category: D
Trigger:  Script execution (`require` statements at the top).
Effect:   The script requires the 'fs', 'path', and 'readline' built-in Node.js modules to be available in the environment.
Evidence: create-page.js:13 -- `const fs = require('fs')`

Contract: User Progress Notification
Category: N
Trigger:  Various stages of script execution (start, file creation, success, error).
Effect:   Messages are printed to standard output to inform the user of the script's progress and next steps.
Evidence: create-page.js:38 -- `log.success: (msg) => console.log(\`...\`)`

Contract: Content Propagation and Transformation
Category: P
Trigger:  The `copyAndReplaceFile` function being called.
Effect:   Content read from a source file is transformed by replacing placeholder strings (`example`, `Example`, etc.) and then propagated to a new destination file on the filesystem.
Evidence: create-page.js:128 -- `let content = fs.readFileSync(src, 'utf-8')`
Evidence: create-page.js:151 -- `fs.writeFileSync(dest, content, 'utf-8')`

Contract: Non-deterministic ID Generation
Category: D
Trigger:  The `generateId` function call.
Effect:   Relies on the system clock (`Date.now()`) to produce a unique ID, making the output non-deterministic across different runs at different times.
Evidence: create-page.js:155 -- `return \`${type}-${pageName}-${Date.now()}\``

TOTAL CONTRACTS FOUND: 10
CATEGORY BREAKDOWN: M=[1] L=[1] N=[1] S=[1] E=[2] C=[0] D=[3] P=[1]

EXTERNAL_DEPENDENCY: src/app/example/ -- The script's primary function is to copy this directory.
EXTERNAL_DEPENDENCY: src/lib/config-registry.ts -- The script output explicitly instructs the user to modify the `PAGE_REGISTRY` array within this file for the new page to be recognized.
EXTERNAL_DEPENDENCY: package.json -- The script output suggests running `npm run dev`, implying a "dev" script is defined here.
EXTERNAL_DEPENDENCY: (Web Server Configuration) -- The output suggests the development server will run at `http://localhost:3003/`, implying an external configuration for this port.
