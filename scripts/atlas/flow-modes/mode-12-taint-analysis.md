# Mode 12: Taint Analysis (Security Flow)

> Tier 2 | Trigger: "taint", "untrusted", "user input", "injection", "sanitize", "xss", "sql injection"

## Purpose

Trace how untrusted data flows from external sources to sensitive operations, identifying potential security vulnerabilities.

## Concepts

| Term | Definition | Examples |
|------|------------|----------|
| **Source** | Where untrusted data enters | `req.body`, `req.query`, `process.argv`, API response |
| **Sink** | Sensitive operations | SQL query, shell command, `innerHTML`, file write |
| **Sanitizer** | Validation/escape functions | Input validation, parameterized queries, HTML escape |
| **Tainted** | Data that hasn't been sanitized | Any source data before sanitization |

## Analysis Steps

### Step 1: Identify Sources

Search for common input sources:

```bash
# Web frameworks
grep -rn "req\.body\|req\.query\|req\.params" --include="*.ts" --include="*.js" src/
grep -rn "request\.form\|request\.args\|request\.json" --include="*.py" src/

# User input
grep -rn "stdin\|readline\|prompt\|argv" src/
```

### Step 2: Identify Sinks

Search for sensitive operations:

```bash
# SQL
grep -rn "\.query(\|\.execute(\|\.raw(" src/

# Command execution
grep -rn "child_process\|subprocess\|os\.system" src/

# File operations
grep -rn "writeFile\|open.*'w'\|fwrite" src/

# Dangerous JS
grep -rn "innerHTML\|eval(\|document\.write" src/
```

### Step 3: Trace Flow

For each source, trace the data path:
1. Where does the input go first?
2. Is it validated/sanitized?
3. Does it reach any sink?

## Output Format

```
Taint Flow Analysis: [Description]
==================================

[SOURCE] {variable/parameter}
   📍 {file}:{line}
   ⚠️ Type: {User Input | API Response | File Read | Environment}
         │
         ▼
1. {Function/Method}
   📍 {file}:{line}
   {🔒 Sanitized: {method} | 🔍 No validation}
         │
         ▼
2. {Function/Method}
   📍 {file}:{line}
   {Description of transformation}
         │
         ▼
[SINK] {sensitive operation}
   📍 {file}:{line}
   {🚨 VULNERABLE | ✅ SAFE}

───────────────────────────────────
Risk Assessment
├── Vulnerability Type: {SQL Injection | XSS | Command Injection | Path Traversal}
├── Severity: {Critical | High | Medium | Low}
├── Exploitability: {Easy | Moderate | Difficult}
└── Recommendation: {specific fix}
───────────────────────────────────
```

## Common Vulnerability Patterns

### SQL Injection
```
Source: req.body.username
   ↓ (no sanitization)
Sink: db.query(`SELECT * FROM users WHERE name = '${username}'`)
🚨 Fix: Use parameterized queries
```

### XSS (Cross-Site Scripting)
```
Source: req.query.search
   ↓ (no escape)
Sink: res.send(`<div>${search}</div>`)
🚨 Fix: HTML escape user input
```

### Command Injection
```
Source: req.body.filename
   ↓ (no validation)
Sink: runCommand(`convert ${filename} output.pdf`)
🚨 Fix: Whitelist allowed characters, use execFile with array args
```

### Path Traversal
```
Source: req.params.file
   ↓ (no path validation)
Sink: fs.readFile(`./uploads/${file}`)
🚨 Fix: Validate path doesn't contain ../
```

## Risk Severity Matrix

| Sink Type | No Sanitizer | Weak Sanitizer | Strong Sanitizer |
|-----------|--------------|----------------|------------------|
| SQL Query | 🔴 Critical | 🟠 High | 🟢 Low |
| Shell Command | 🔴 Critical | 🔴 Critical | 🟡 Medium |
| innerHTML | 🟠 High | 🟡 Medium | 🟢 Low |
| File Write | 🟠 High | 🟡 Medium | 🟢 Low |
| File Read | 🟡 Medium | 🟢 Low | 🟢 Low |

## Language-Specific Patterns

### Node.js/TypeScript
```javascript
// Sources
req.body, req.query, req.params, req.headers
process.argv, process.env

// Sinks
db.query(), pool.execute()
child_process.spawn(), child_process.execFile()
fs.writeFile(), fs.readFile()
element.innerHTML

// Sanitizers
validator.escape(), sqlstring.escape()
parameterized queries (?), prepared statements
```

### Python
```python
# Sources
request.form, request.args, request.json
sys.argv, os.environ, input()

# Sinks
cursor.execute(), engine.execute()
subprocess.run(), os.popen()
open().write()

# Sanitizers
bleach.clean(), html.escape()
parameterized queries (%s), SQLAlchemy ORM
```

### Swift/iOS
```swift
// Sources
URLComponents.queryItems, UserDefaults
UITextField.text, UIPasteboard

// Sinks
FileManager.createFile()
Process().launch()
WKWebView.loadHTMLString()

// Sanitizers
Input validation, URL encoding
```

## Output Example

```
Taint Flow Analysis: Login Form Input
=====================================

[SOURCE] req.body.username
   📍 src/controllers/auth.ts:25
   ⚠️ Type: User Input (form field)
         │
         ▼
1. AuthController.login()
   📍 src/controllers/auth.ts:30
   🔍 No validation - passes directly
         │
         ▼
2. UserService.findByUsername(username)
   📍 src/services/user.ts:45
   🔍 No transformation
         │
         ▼
[SINK] db.query(`SELECT * FROM users WHERE username = '${username}'`)
   📍 src/services/user.ts:48
   🚨 VULNERABLE - SQL Injection

───────────────────────────────────
Risk Assessment
├── Vulnerability Type: SQL Injection
├── Severity: Critical
├── Exploitability: Easy (standard SQLi payloads work)
└── Recommendation:
    1. Use parameterized query:
       db.query('SELECT * FROM users WHERE username = ?', [username])
    2. Add input validation at controller level
───────────────────────────────────

Additional Sources Found (2):
├── req.body.password → Same sink (Critical)
└── req.body.rememberMe → Cookie setting (Low)
```

## Trigger Keywords

Primary: `taint`, `untrusted input`, `user input flow`
Secondary: `injection`, `xss`, `sql injection`, `command injection`, `sanitize`, `validate input`
