# Pattern Learning Workflow

Complete step-by-step guide for learning design patterns from the codebase.

---

## Overview

This workflow helps you understand how the current codebase implements specific patterns by:
1. Finding 2-3 best example files (high-entropy priority)
2. Analyzing implementation details
3. Extracting conventions and best practices
4. Providing actionable implementation guidance

**Time Budget**: 5-10 minutes total

---

## Step 0: Parse Output Mode (10 seconds)

### Detect Output Mode Parameter

Parse `$ARGUMENTS` for mode flags:

```bash
# Check for --brief
if echo "$ARGUMENTS" | grep -q "\-\-brief"; then
    OUTPUT_MODE="brief"
# Check for --full
elif echo "$ARGUMENTS" | grep -q "\-\-full"; then
    OUTPUT_MODE="full"
else
    OUTPUT_MODE="smart"  # Default
fi
```

### Mode Behaviors

| Mode | Behavior | Use Case |
|------|----------|----------|
| **--brief** | List files only, no analysis | Quick file browser |
| **--full** | Analyze all found files | Deep learning session |
| **smart** (default) | ≤5 files → full; >5 → show selection UI | Balanced approach |

---

## Step 1: Execute Pattern Detection (1-2 minutes)

### Use find-patterns.sh Script

**Priority: Try script first** (tested, optimized, fast):

```bash
# Locate script (global → local fallback)
SCRIPT_PATH=""
if [ -f ~/.claude/scripts/atlas/find-patterns.sh ]; then
    SCRIPT_PATH=~/.claude/scripts/atlas/find-patterns.sh
elif [ -f scripts/atlas/find-patterns.sh ]; then
    SCRIPT_PATH=scripts/atlas/find-patterns.sh
fi

# Execute if found
if [ -n "$SCRIPT_PATH" ]; then
    bash "$SCRIPT_PATH" "$ARGUMENTS"
else
    echo "⚠️ find-patterns.sh not found, falling back to manual search"
fi
```

### Script Output Format

```
src/api/controllers/user_controller.ts ⭐⭐⭐
src/api/controllers/order_controller.ts ⭐⭐⭐
src/api/controllers/payment_controller.ts ⭐⭐
...
```

**Ranking criteria:**
- ⭐⭐⭐ Exact filename match + relevant directory
- ⭐⭐ Filename match OR relevant directory
- ⭐ Partial match

### Supported Predefined Patterns

The script recognizes these patterns:

**Backend patterns:**
- api endpoint / api / endpoint
- background job / job / queue
- file upload / upload / file storage
- database query / database / query
- authentication / auth / login
- middleware
- service object
- repository

**Frontend patterns:**
- react component / component
- custom hook / hook
- swiftui view / view
- view controller / viewcontroller

**Infrastructure:**
- networking / network
- caching / cache

### Fallback: Manual Search

If script returns "Unknown pattern" or not found:

```bash
# Extract keywords from pattern
# Example: "video learning progress" → keywords: video, learning, progress

# Search by filename
find . -type f \( -name "*video*" -o -name "*learning*" -o -name "*progress*" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    -not -path "*/Pods/*" \
    2>/dev/null | head -20

# Search by content
grep -rl "video.*progress\|learning.*video" --include="*.ts" --include="*.swift" --include="*.py" . | \
    grep -v node_modules | head -20
```

---

## Step 1.5: ast-grep Enhanced Search (Optional)

### When to Use

For **Type B patterns** (content-based, not filename-based):

| Pattern Type | Examples | Tool |
|--------------|----------|------|
| **Type A**: Filename is pattern | ViewModel, Service, Repository | grep/find sufficient |
| **Type B**: Requires content analysis | async/await, suspend functions, decorators | ast-grep better |

### Use ast-grep-search.sh Script

```bash
# Locate script
AST_SCRIPT=""
if [ -f ~/.claude/scripts/atlas/ast-grep-search.sh ]; then
    AST_SCRIPT=~/.claude/scripts/atlas/ast-grep-search.sh
elif [ -f scripts/atlas/ast-grep-search.sh ]; then
    AST_SCRIPT=scripts/atlas/ast-grep-search.sh
fi

# Examples for different languages

# Swift async functions
$AST_SCRIPT pattern "async" --lang swift --path .

# Kotlin suspend functions
$AST_SCRIPT pattern "suspend" --lang kotlin --path .

# TypeScript custom hooks (use* prefix)
$AST_SCRIPT pattern "hook" --lang tsx --path .

# Go goroutines
$AST_SCRIPT pattern "goroutine" --lang go --path .
```

### Performance Data

Based on integration tests:

| Pattern | False Positive Reduction |
|---------|-------------------------|
| TypeScript custom hooks | 93% |
| Kotlin suspend functions | 51% |
| Kotlin data classes | 15% |
| Swift async functions | 14% |

### Graceful Degradation

```bash
# If ast-grep not installed, get fallback command
$AST_SCRIPT pattern "async" --fallback
# Returns: grep equivalent command to use
```

---

## Step 2: Apply Output Mode Logic (30 seconds)

### Count Files Found

```bash
FILE_COUNT=$(wc -l < /tmp/pattern-results.txt | tr -d ' ')
```

### Smart Mode Decision

```python
if FILE_COUNT == 0:
    → Output "No matching files found"
    → Suggest alternative patterns
    → END

elif FILE_COUNT <= 5:
    → Proceed to Step 3 (full analysis)

else:  # FILE_COUNT > 5
    → Show selection interface
    → Wait for user input
```

### Selection Interface

```markdown
Found {FILE_COUNT} related files, please select files to analyze:

| # | File Path | Relevance |
|---|-----------|-----------|
| 1 | src/api/controllers/user_controller.ts | ⭐⭐⭐ |
| 2 | src/api/controllers/order_controller.ts | ⭐⭐⭐ |
| 3 | src/api/controllers/payment_controller.ts | ⭐⭐ |
...

**Options:**
- Enter numbers separated by commas (e.g., `1,2,3`)
- Enter "all" to analyze all files
- Enter "top3" to analyze top 3 only
```

### Brief Mode (--brief)

If `--brief` flag detected:

```markdown
Found {FILE_COUNT} files matching pattern:

1. src/api/controllers/user_controller.ts ⭐⭐⭐
2. src/api/controllers/order_controller.ts ⭐⭐⭐
...

Use `/sourceatlas:pattern "{pattern}" --full` to analyze all files
Or specify file numbers: `/sourceatlas:pattern "{pattern}" 1,2,3`
```

Then **END** (no further analysis).

### Full Mode (--full)

If `--full` flag detected:
- Bypass selection interface
- Proceed to analyze ALL found files
- Warn if >10 files: "Analyzing {N} files, this may take longer..."

---

## Step 3: Analyze Selected Files (3-5 minutes)

### High-Entropy File Priority

Read files in relevance order (top-ranked first):

**What to prioritize:**
- ✅ Main implementation files (controllers, services, handlers)
- ✅ Complete examples (100-500 lines ideal)
- ✅ Well-structured, production code
- ❌ NOT: Helper utilities, trivial code, generated files

### Reading Strategy

For each selected file:

```bash
# Read file
cat "path/to/file.ts"

# Focus on:
# 1. Class/function structure
# 2. Imports/dependencies
# 3. Main execution flow
# 4. Error handling patterns
# 5. Configuration patterns
```

### Analysis Focus Areas

**1. Overall Structure**
- How is code organized? (classes, functions, modules)
- What's the typical file length?
- How are concerns separated?

**2. Standard Flow**
- What's the typical execution path?
- How do components interact?
- What's the lifecycle?

**3. Naming Conventions**
- Variable naming: camelCase, snake_case, PascalCase?
- File naming: UserService.ts vs user_service.py?
- Directory structure patterns?

**4. Dependencies**
- What libraries/frameworks are imported?
- How are dependencies injected?
- Configuration management approach?

**5. Error Handling**
- Try/catch patterns?
- Error types/classes used?
- Error propagation strategy?

**6. Testing Patterns**
- Where are tests located?
- Testing framework used?
- Coverage approach?

---

## Step 4: Extract the Pattern (2 minutes)

### Pattern Summary (2-3 sentences)

Answer:
- How does THIS codebase handle this pattern?
- What makes it unique to this project?
- What's the high-level approach?

Example:
```
This codebase implements API endpoints using Express.js controllers
with a 3-layer architecture: Controller → Service → Repository.
All endpoints follow RESTful conventions and use middleware for
auth, validation, and error handling.
```

### Standard Flow (Numbered Steps)

Document the typical execution path:

```
1. Request hits route → routes/users.ts
2. Middleware stack executes (auth, validation)
3. Controller method called → controllers/UserController.ts
4. Service layer handles business logic → services/UserService.ts
5. Repository accesses database → repositories/UserRepository.ts
6. Response formatted and returned
```

### Key Conventions (Bullet Points)

List concrete, observable conventions:

```
- All controllers extend BaseController class
- Service objects placed in app/services/ directory
- Use constructor injection for dependencies
- Error responses follow RFC 7807 format (Problem Details)
- File naming: PascalCase for classes, camelCase for functions
```

### Testing Pattern

Describe how this pattern is tested:

```
**Test Location:** tests/integration/api/

**Testing Approach:**
- Supertest for API integration tests
- Jest for unit testing controllers
- Mocks for service layer using jest.mock()
- Test database setup/teardown in beforeEach/afterEach

**Example test:** tests/integration/api/users.test.ts
```

### Common Pitfalls

Identify from code observations:

```
1. Don't call services directly from routes - use controllers
2. Don't put business logic in controllers - use services
3. Don't forget to sanitize user input - use validators
```

---

## Step 5: Find Related Tests (1 minute, optional)

### Locate Test Files

```bash
# Find test directories
find . \( -path "*/test/*" -o -path "*/tests/*" -o -path "*/spec/*" \
         -o -path "*/__tests__/*" \) -type d \
    -not -path "*/node_modules/*" \
    2>/dev/null | head -10

# Find test files by extension
find . \( -name "*.test.*" -o -name "*.spec.*" \) -type f \
    -not -path "*/node_modules/*" \
    2>/dev/null | head -20
```

### Search for Pattern-Related Tests

```bash
# Example: Search for "UserController" tests
grep -rn "UserController\|user.*controller" \
    --include="*.test.*" --include="*.spec.*" \
    tests/ 2>/dev/null | head -10
```

---

## Step 6: Generate Implementation Guide (1 minute)

### Create Step-by-Step Guide

Based on analysis, provide concrete steps:

```
## Step-by-Step Implementation Guide

To implement a new API endpoint following this codebase's pattern:

1. **Create route definition**
   - File: src/routes/[resource].ts
   - Add route: router.get('/api/resource', controller.method)

2. **Create controller**
   - File: src/controllers/[Resource]Controller.ts
   - Extend BaseController
   - Implement method with request validation

3. **Create service**
   - File: src/services/[Resource]Service.ts
   - Implement business logic
   - Use dependency injection for repositories

4. **Create repository** (if database access needed)
   - File: src/repositories/[Resource]Repository.ts
   - Use ORM (e.g., Sequelize)

5. **Add tests**
   - File: tests/integration/api/[resource].test.ts
   - Test happy path and error cases
```

---

## Error Handling

### Issue: Pattern Not Recognized by Script

**Symptom:** Script returns "Unknown pattern"

**Action:**
1. Inform user about unsupported pattern
2. Suggest similar supported patterns
3. Fall back to manual search using keywords
4. Still provide analysis based on findings

---

### Issue: No Files Found

**Symptom:** 0 results from search

**Action:**
```
⚠️ No files found matching pattern: "{pattern}"

Possible reasons:
- Pattern doesn't exist in this codebase
- Using different naming conventions
- Pattern is in language we didn't search

Suggestions:
- Try related patterns: [list similar patterns]
- Check documentation or ask team members
- Use different keywords: [suggest alternatives]
```

---

### Issue: Pattern Too Generic

**Symptom:** >50 files found, too broad

**Action:**
```
⚠️ Found {N} files for pattern "{pattern}" - too generic

Please specify a more specific pattern:
- Instead of "service", try "payment service" or "email service"
- Instead of "component", try "react component" or "button component"
- Instead of "controller", try "api controller" or "admin controller"
```

---

### Issue: Files Are Test Files

**Symptom:** Top results are all test files

**Action:**
- Filter out test files from ranking
- Look for production implementation files
- Note: "Found mostly test files, looking for production code..."

```bash
# Exclude test files from search
grep -v "\.test\." results.txt | grep -v "\.spec\." | grep -v "/test/" | grep -v "/tests/"
```

---

## Output Generation Tips

### Best Examples Section

```markdown
### 1. src/api/controllers/UserController.ts:45

**Purpose**: Demonstrates RESTful endpoint with auth middleware

**Key Code**:
```typescript
@Get('/api/users/:id')
@UseGuards(AuthGuard)
async getUser(@Param('id') id: string): Promise<User> {
  return await this.userService.findById(id);
}
```

**Key Points**:
- Uses decorator-based routing
- Auth guard applied via @UseGuards
- Async/await for service calls
- TypeScript types for request/response
```

### Key Conventions Section

Be specific and observable:

```markdown
## Key Conventions

- **All controllers extend BaseController** - provides common methods (found in: src/common/BaseController.ts)
- **Service objects use constructor injection** - e.g., constructor(private userRepo: UserRepository)
- **Error responses follow RFC 7807** - {type, title, status, detail, instance}
- **File structure**: controllers/ → services/ → repositories/
```

---

## Performance Optimization

### For Large Codebases

```bash
# Limit search depth
find . -maxdepth 5 -name "*controller*" ...

# Limit results
... | head -20

# Exclude large directories early
find . -path "*/vendor" -prune -o -path "*/dist" -prune -o ...
```

### For Monorepos

```bash
# Search specific package only
find packages/api -name "*controller*" ...

# Or multiple related packages
find packages/{api,core} -name "*controller*" ...
```

---

## Integration with Other Commands

After pattern analysis, suggest:
- **Complex flow found** → `/sourceatlas:flow "[entry point]"`
- **Pattern used widely** → `/sourceatlas:impact "[core file]"`
- **Related pattern mentioned** → `/sourceatlas:pattern "[related pattern]"`
