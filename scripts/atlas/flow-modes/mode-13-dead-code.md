# Mode 13: Dead Code Detection

> Tier 3 | Trigger: "dead code", "unreachable", "unused", "never called", "orphan"

## Purpose

Identify code that is never executed, including unreachable statements, unused functions, and obsolete code paths.

## Detection Types

| Type | Description | Example |
|------|-------------|---------|
| **Unreachable Code** | Code after return/throw | `return x; console.log("never");` |
| **Unused Functions** | No callers in codebase | `function legacyCalc() { ... }` |
| **Unused Variables** | Declared but never read | `const temp = calc(); // never used` |
| **Unused Imports** | Imported but not referenced | `import { unused } from 'lib';` |
| **Unused Parameters** | Function params never used | `function f(a, b) { return a; }` |
| **Impossible Conditions** | Logic that can't be true | `if (x && !x) { ... }` |
| **Dead Branches** | Conditions always true/false | `if (true) { } else { /* dead */ }` |

## Analysis Steps

### Step 1: Find Unreachable Code

```bash
# After return/throw
grep -n "return\|throw" --include="*.ts" --include="*.js" src/ | head -20

# Check for code after these statements
```

### Step 2: Find Unused Functions

```bash
# List all function definitions
grep -rn "function \w\+\|const \w\+ = .*=>" --include="*.ts" src/

# For each function, search for callers
# grep -rn "functionName(" src/
```

### Step 3: Find Unused Exports

```bash
# List exports
grep -rn "export.*function\|export.*const\|export.*class" src/

# Check if imported elsewhere
```

### Step 4: Analyze with AST (if available)

For more accurate detection, use language-specific tools:
- TypeScript: `ts-prune`, `ts-unused-exports`
- JavaScript: `eslint --rule no-unused-vars`
- Python: `vulture`, `autoflake`

## Output Format

```
Dead Code Analysis: {Scope}
===========================

Summary:
├── Unreachable code: N locations
├── Unused functions: N functions
├── Unused variables: N variables
├── Unused imports: N imports
└── Total removable: ~N lines

───────────────────────────────────

## Unreachable Code (N)

1. After return statement
   📍 {file}:{line}
   ```{language}
   return result;
   console.log("Done");  // ← Unreachable
   this.cleanup();       // ← Unreachable
   ```
   💡 Safe to remove: lines {start}-{end}

2. After throw statement
   📍 {file}:{line}
   ```{language}
   throw new Error("Failed");
   return null;  // ← Unreachable
   ```

───────────────────────────────────

## Unused Functions (N)

1. {functionName}()
   📍 {file}:{line}
   ```{language}
   private legacyCalculate(): number { ... }
   ```
   🔍 Searched: 0 callers found
   ⚠️ Note: {May be called via reflection | Exported but unused | Test helper}
   💡 Confidence: {High | Medium | Low}

2. {functionName}()
   📍 {file}:{line}
   🔍 Searched: 0 callers found
   💡 Confidence: High

───────────────────────────────────

## Unused Variables (N)

1. {variableName}
   📍 {file}:{line}
   ```{language}
   const tempResult = calculate();  // Assigned but never read
   ```

───────────────────────────────────

## Unused Imports (N)

1. 📍 {file}:{line}
   ```{language}
   import { usedFunc, unusedFunc } from './utils';
   //                  ^^^^^^^^^^^ Never used
   ```

───────────────────────────────────

## Impossible Conditions (N)

1. 📍 {file}:{line}
   ```{language}
   if (status === 'active' && status === 'inactive') {
     // This block can never execute
   }
   ```

───────────────────────────────────

Removal Impact:
├── Lines removable: ~N
├── File size reduction: ~N%
├── Safe to remove: {list of high-confidence items}
└── Review needed: {list of medium/low confidence items}
```

## Confidence Levels

| Level | Criteria | Action |
|-------|----------|--------|
| **High** | No references found, not exported, not in interface | Safe to remove |
| **Medium** | Exported but no imports, or test-only usage | Review before removal |
| **Low** | May use reflection, dynamic calls, or external reference | Manual verification needed |

## False Positive Patterns

Be careful with:

1. **Reflection/Dynamic Calls**
   ```javascript
   const method = 'process';
   obj[method]();  // Calls obj.process() dynamically
   ```

2. **Framework Magic**
   ```typescript
   @Get('/users')  // Decorator-based routing
   getUsers() { }  // Called by framework, not directly
   ```

3. **Lifecycle Hooks**
   ```typescript
   ngOnInit() { }  // Called by Angular
   componentDidMount() { }  // Called by React
   ```

4. **Event Handlers**
   ```html
   <button onClick={handleClick}>  // handleClick called from template
   ```

5. **Exported APIs**
   ```typescript
   export function publicApi() { }  // May be used by external packages
   ```

## Language-Specific Detection

### TypeScript/JavaScript
```bash
# Unused exports
npx ts-prune

# Unused variables (ESLint)
npx eslint --rule 'no-unused-vars: error' src/

# Find functions
grep -rn "function \|const.*= (" src/ --include="*.ts"
```

### Python
```bash
# Vulture for dead code
vulture src/

# Find function definitions
grep -rn "^def \|^async def " src/ --include="*.py"
```

### Swift
```bash
# Find unused functions
grep -rn "func " --include="*.swift" Sources/

# Periphery tool
periphery scan
```

## Output Example

```
Dead Code Analysis: OrderService
================================

Summary:
├── Unreachable code: 2 locations
├── Unused functions: 3 functions
├── Unused variables: 5 variables
├── Unused imports: 2 imports
└── Total removable: ~85 lines (4.2% of file)

───────────────────────────────────

## Unreachable Code (2)

1. After return statement
   📍 src/services/order.ts:156-158
   ```typescript
   return order;
   console.log("Order created");  // ← Unreachable
   this.notifyAdmin();            // ← Unreachable
   ```
   💡 Safe to remove: 2 lines

2. After throw in catch block
   📍 src/services/order.ts:203-205
   ```typescript
   throw new OrderError(e.message);
   return null;  // ← Unreachable
   ```
   💡 Safe to remove: 1 line

───────────────────────────────────

## Unused Functions (3)

1. calculateLegacyDiscount()
   📍 src/services/order.ts:280
   🔍 Searched: 0 callers found
   💡 Confidence: High - private method, no references

2. formatOrderV1()
   📍 src/services/order.ts:312
   🔍 Searched: 0 callers found
   💡 Confidence: Medium - exported, may be used externally

3. debugOrder()
   📍 src/services/order.ts:350
   🔍 Searched: 0 callers (except tests)
   💡 Confidence: Low - test helper, review before removal

───────────────────────────────────

Removal Impact:
├── Lines removable: ~85
├── File size reduction: ~4.2%
├── Safe to remove: calculateLegacyDiscount (25 lines)
└── Review needed: formatOrderV1, debugOrder
```

## Trigger Keywords

Primary: `dead code`, `unreachable code`, `unused functions`
Secondary: `orphan code`, `never called`, `unused`, `remove dead code`, `code cleanup`
