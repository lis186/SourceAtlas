---
description: Analyze the impact scope of code changes using static dependency analysis
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: [target, e.g., "User model", "api /api/users/{id}", "authentication"] [--force]
---

# SourceAtlas: Impact Analysis (Static Dependencies)

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.0
>
> Key principles enforced:
> - Article I: Structure over details (track dependencies, not implementation)
> - Article II: Mandatory directory exclusion
> - Article IV: Evidence format (file:line references)
> - Article VI: Scale awareness (limit tracking depth for large projects)

## Context

**Analysis Target:** $ARGUMENTS

**Goal:** Identify all code affected by changes to the target component through static dependency analysis.

**Time Limit:** Complete in 5-10 minutes.

---

## Cache Check (Highest Priority)

**If `--force` is not in arguments**, check cache first: 

1. Extract target name from `$ARGUMENTS` (remove `--force`)
2. Convert to filename: spaces → `-`, slashes → `-`, lowercase, remove `{}`, **truncate to 50 characters**
   - Example: `"User model"` → `user-model.md`
   - Example: `"api /api/users/{id}"` → `api-users-id.md`
3. Check cache: 
   ```bash
   ls -la .sourceatlas/impact/{name}.md 2>/dev/null
   ```

4. **If cache exists**: 
   - Calculate days since creation
   - Read cache content using Read tool
   - Output: 
     ```
     📁 Loading from cache: .sourceatlas/impact/{name}.md (N days ago)
     💡 Use --force to reanalyze --force
     ```
   - **If over 30 days**, additionally display: 
     ```
     ⚠️ Cache is over 30 days old, recommend reanalysis
     ```
   - Then output: 
     ```
     ---
     [Cache content]
     ```
   - **End, do not execute subsequent analysis**

5. **If cache does not exist**: Continue with analysis below

**If arguments contain `--force`**: Skip cache check, run analysis directly

---

## Your Task

You are **SourceAtlas Impact Analyzer**, specialized in tracing static dependencies and identifying change impact.

Help the user understand:
1. What code directly depends on the target
2. What code indirectly depends on it (call chains)
3. Which tests need updating
4. Migration checklist and risk assessment

---

## Workflow

### Step 1: Parse Target and Detect Type (1 minute)

Analyze `$ARGUMENTS` to determine the analysis type:

**Type Detection**:

```bash
# If contains "api" or starts with "/" -> API Impact
if [[ "$ARGUMENTS" =~ api|^/ ]]; then
    TYPE="API"
    # Extract API path, e.g., "/api/users/{id}"
fi

# If contains "model" or common model names
if [[ "$ARGUMENTS" =~ model|Model|entity|Entity ]]; then
    TYPE="MODEL"
fi

# Otherwise -> General Component
TYPE="COMPONENT"
```

**Detected Type determines analysis strategy:**
- **API**: Backend → Frontend call chain
- **MODEL**: Database layer → Business logic → Controllers
- **COMPONENT**: General dependency search

---

### Step 2: Project Context Detection (1 minute)

Understand the project structure:

```bash
# Detect project type (Swift BEFORE Ruby to avoid Gemfile misdetection)
if [ -f "Package.swift" ] || [ -f "Project.swift" ] || [ -d "Tuist" ] || \
   ls *.xcodeproj >/dev/null 2>&1 || ls *.xcworkspace >/dev/null 2>&1; then
    PROJECT_TYPE="iOS/Swift"
    NEEDS_SWIFT_ANALYSIS=true
elif [ -f "package.json" ]; then
    PROJECT_TYPE="Node.js/TypeScript"
    # Check if frontend (React/Next/Vue)
    if grep -q "react\|next\|vue" package.json; then
        HAS_FRONTEND=true
    fi
elif [ -f "Gemfile" ]; then
    PROJECT_TYPE="Ruby/Rails"
elif [ -f "go.mod" ]; then
    PROJECT_TYPE="Go"
fi
```

**Key Directories to Scan**:
- Backend: `src/`, `app/`, `lib/`, `api/`
- Frontend: `components/`, `pages/`, `app/`, `hooks/`, `utils/`
- Tests: `__tests__/`, `spec/`, `test/`, `*.test.*`, `*.spec.*`
- Types: `types/`, `*.d.ts`, `interfaces/`
- iOS: `Sources/`, `**/Classes/`, `*.xcodeproj/`, `Tests/`

---

### Step 2.5: ast-grep Enhanced Search (Optional, P1 Enhancement)

**When to use**: ast-grep provides more precise dependency search, excluding false positives in comments and strings.

**Use unified script** (`ast-grep-search.sh`):

```bash
# Set script path (global first, local fallback)
AST_SCRIPT=""
if [ -f ~/.claude/scripts/atlas/ast-grep-search.sh ]; then
    AST_SCRIPT=~/.claude/scripts/atlas/ast-grep-search.sh
elif [ -f scripts/atlas/ast-grep-search.sh ]; then
    AST_SCRIPT=scripts/atlas/ast-grep-search.sh
fi

# Type reference search (MODEL/COMPONENT)
$AST_SCRIPT type "UserDto" --path .
$AST_SCRIPT type "ViewModel" --path .

# Function call tracking (API)
$AST_SCRIPT call "fetchUser" --path .

# If ast-grep is not installed, get grep fallback command
$AST_SCRIPT type "UserDto" --fallback
```

**Value**: According to integration tests, ast-grep achieves in dependency analysis: 
- Swift UserDto dependencies: 93% false positive elimination
- TypeScript useState: 15% false positive elimination
- Kotlin ViewModel: 92% false positive elimination

**Graceful Degradation**: Script automatically handles ast-grep unavailability, using `--fallback` to get equivalent grep command.

---

### Step 3: Execute Impact Analysis (3-5 minutes)

#### For API Impact (Type: API)

**Phase 1: Backend Definition**

```bash
# Find API endpoint definition
# Look for: route definitions, controllers, handlers
grep -r "$API_PATH" --include="*.ts" --include="*.js" --include="*.rb" --include="*.go" \
  app/ src/ routes/ api/ controllers/ 2>/dev/null | head -20
```

**Phase 2: Type Definitions**

```bash
# Find response type definitions (critical for API changes)
grep -r "Response\|ResponseType" --include="*.ts" --include="*.d.ts" \
  types/ src/types/ 2>/dev/null | head -10
```

**Phase 3: Frontend Usage**

```bash
# Find API calls in frontend
grep -r "$API_PATH\|fetch.*users\|axios.*users" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  src/ components/ app/ pages/ hooks/ 2>/dev/null | head -30
```

**Phase 4: Hook/Service Layer**

```bash
# Find custom hooks or services wrapping the API
grep -r "useUser\|userService\|UserAPI" \
  --include="*.ts" --include="*.tsx" \
  hooks/ services/ lib/ 2>/dev/null | head -20
```

**Phase 5: Component Usage**

For each Hook/Service found, find which components use it:

```bash
# Example: Find all imports of useUser
grep -r "import.*useUser\|from.*useUser" \
  --include="*.tsx" --include="*.ts" \
  components/ app/ pages/ 2>/dev/null
```

#### For Model Impact (Type: MODEL)

**Phase 1: Model Definition**

```bash
# Find the model file
find . -name "*User*.rb" -o -name "*user*.py" -o -name "*User*.ts" \
  2>/dev/null | grep -v node_modules | grep -v test
```

**Phase 2: Direct Dependencies**

```bash
# Who imports/requires this model?
MODEL_FILE="app/models/user.rb"
grep -r "require.*user\|import.*User\|from.*user" \
  --include="*.rb" --include="*.py" --include="*.ts" \
  app/ src/ lib/ 2>/dev/null | head -30
```

**Phase 3: Associations**

Read the model file and identify associations:
- `belongs_to`, `has_many`, `has_one` (Rails)
- Foreign keys and references
- Validation rules

**Phase 4: Business Logic Usage**

```bash
# Find controllers/services using the model
grep -r "User\.create\|User\.find\|User\.where\|new User" \
  --include="*.rb" --include="*.ts" \
  controllers/ services/ app/ 2>/dev/null | head -30
```

#### For General Component (Type: COMPONENT)

**Phase 1: Locate Component**

```bash
# Find files matching the component name
COMPONENT_NAME="authentication"
find . -iname "*${COMPONENT_NAME}*" -type f \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  2>/dev/null | head -20
```

**Phase 2: Find Imports/References**

```bash
# Search for imports
grep -r "import.*${COMPONENT_NAME}\|require.*${COMPONENT_NAME}\|from.*${COMPONENT_NAME}" \
  --include="*.ts" --include="*.js" --include="*.rb" \
  . 2>/dev/null | grep -v node_modules | head -30
```

**Phase 3: Find Usage**

```bash
# Search for function calls
grep -r "${COMPONENT_NAME}\.\|${COMPONENT_NAME}(" \
  --include="*.ts" --include="*.js" \
  . 2>/dev/null | grep -v node_modules | head -30
```

**Phase 4: Mutually Exclusive Categorization** ⚠️ REQUIRED

```bash
# IMPORTANT: Categories MUST be mutually exclusive to avoid double-counting
# Save all dependent files first
grep -rl "${COMPONENT_NAME}" --include="*.swift" . 2>/dev/null | grep -v Test | grep -v Mock | sort -u > /tmp/all_deps.txt

# Count total (this is the authoritative number)
TOTAL=$(wc -l < /tmp/all_deps.txt)

# Categorize with exclusion chain (order matters!)
# 1. Core module files (highest priority)
CORE=$(grep "${COMPONENT_NAME}" /tmp/all_deps.txt | wc -l)

# 2. Coordinators (exclude core)
COORDINATORS=$(grep -v "${COMPONENT_NAME}" /tmp/all_deps.txt | grep 'Coordinator' | wc -l)

# 3. Frontend (exclude core and coordinators)
FRONTEND=$(grep -v "${COMPONENT_NAME}" /tmp/all_deps.txt | grep -v 'Coordinator' | grep 'Frontend' | wc -l)

# 4. Others (everything else)
OTHERS=$(grep -v "${COMPONENT_NAME}" /tmp/all_deps.txt | grep -v 'Coordinator' | grep -v 'Frontend' | wc -l)

# VERIFY: Sum must equal total
echo "Verification: $CORE + $COORDINATORS + $FRONTEND + $OTHERS = $TOTAL"
```

**Phase 5: Exact API Usage Counts** ⚠️ REQUIRED

```bash
# NEVER estimate - always run actual grep counts
# For each key API/property, count exact occurrences

# Example for Swift:
echo "selectedTab: $(grep -rn '\.selectedTab' --include='*.swift' . | grep -v Test | wc -l)"
echo "addDelegate: $(grep -rn 'addDelegate' --include='*.swift' . | grep -v Test | wc -l)"

# Report actual numbers, NOT estimates like "~30"
```

---

### Step 4: Test Impact Analysis (1-2 minutes)

**Find Related Tests**:

```bash
# Find test files by name pattern
find . -name "*user*test*" -o -name "*user*spec*" \
  2>/dev/null | grep -v node_modules

# Find tests importing the target
grep -r "import.*User\|require.*user" \
  --include="*.test.*" --include="*.spec.*" \
  __tests__/ spec/ test/ 2>/dev/null | head -20
```

**Analyze Test Coverage**:
- Are there tests for the target component?
- Are there integration tests?
- Are there E2E tests covering the flow?

---

### Step 5: Language-Specific Deep Analysis (1-2 minutes, optional)

**When to Run**: If `NEEDS_SWIFT_ANALYSIS=true` AND target file is `.swift`, `.m`, or `.h`

Execute the Swift/Objective-C deep analyzer for additional insights:

```bash
# Check if this is an iOS project with Swift/ObjC target
if [[ "$TARGET_FILE" =~ \.(swift|m|h)$ ]] && [[ "$PROJECT_TYPE" == "iOS/Swift" ]]; then
    echo "Running Swift/Objective-C deep analysis..."

    # Execute analyzer (located at scripts/atlas/analyzers/swift-analyzer.sh)
    SWIFT_ANALYSIS_OUTPUT=$(./scripts/atlas/analyzers/swift-analyzer.sh "$TARGET_FILE" "$PROJECT_ROOT" 2>&1)

    # Parse key findings from the output
    # - Nullability coverage percentage
    # - @objc exposure count
    # - Memory management warnings
    # - UI framework architecture
fi
```

**What This Provides**:
- Nullability annotation coverage (CRITICAL for Swift interop)
- @objc exposure detection (breaking change risks)
- Memory management warnings (unowned, retain cycles)
- Bridging header circular dependency checks
- SwiftUI vs UIKit architecture detection

**Integration**: Include key findings in the final report's "Language-Specific Risks" section

---

### Step 6: Risk Assessment (1 minute)

Evaluate impact level based on findings:

**Risk Factors**:
- Number of direct dependents (>10 = HIGH)
- Presence in critical path (auth, payment = HIGH)
- Test coverage (<50% = HIGH risk)
- Type of change (breaking change = HIGH)

**Risk Levels**:
- 🟢 **LOW**: 1-5 dependents, well-tested, non-critical
- 🟡 **MEDIUM**: 5-15 dependents, partial tests, business logic
- 🔴 **HIGH**: >15 dependents OR critical path OR breaking change

---

## Output Format

### For API Impact

```markdown
🗺️ SourceAtlas: Impact
───────────────────────────────
💥 $API_PATH │ [total dependents] dependents

📊 **Impact Summary**:
- Backend files: [count]
- Frontend files: [count]
- Test files: [count]
- **Risk Level**: 🔴/🟡/🟢 [reason]

---

## 1. Backend Layer

### API Definition
- File: [path:line]
- Handler: [function name]
- Request/Response types: [types]

### Response Structure
```[language]
// Current structure from types
interface UserResponse {
  id: string
  role: string  // ⚠️ If changing this
  ...
}
```

---

## 2. Frontend Layer

### API Client/Service
- File: [path:line]
- Wrapper function: [function name]

### Custom Hooks (React)
- `useUser` ([path:line])
  - Used by [count] components
  - Components: [list]

### Direct API Calls
- [component:line] - [usage description]

---

## 3. Component Impact

**High Priority** (Directly affected):
1. [Component A] ([path:line])
   - Usage: [how it uses the API/field]
   - Impact: [what breaks]

2. [Component B] ([path:line])
   - Usage: [description]

**Medium Priority** (Indirectly affected):
3. [Component C] - Uses Hook that wraps API

---

## 4. Field Usage Analysis

**Field: `role`** (⚠️ Changing from string → array)
- Total occurrences: [count]
- Locations:
  1. [file:line] - `if (user.role === 'admin')`
  2. [file:line] - `user.role.toUpperCase()`

**Breaking Change Assessment**:
- All usages assume string type
- Migration required: Yes
- Backward compatibility: Possible with adapter

---

## 5. Test Impact

**Test Files to Update**:
- `user.test.ts` - Mock data structure
- `useUser.test.ts` - Hook logic
- `UserBadge.test.tsx` - Component rendering
- `e2e/user-profile.spec.ts` - E2E scenarios

**Test Coverage Gaps**:
- ⚠️ No tests for [Component X]
- ⚠️ Missing integration tests for [Flow Y]

---

## 6. Migration Checklist

- [ ] Update API response type definition
- [ ] Update [N] API call sites
- [ ] Update [N] components using the field
- [ ] Add backward compatibility layer (if needed)
- [ ] Update [N] test files
- [ ] Test all affected pages manually
- [ ] Update API documentation

**Risk Level**: 🔴 HIGH | 🟡 MEDIUM | 🟢 LOW

💡 **Note**: Time estimation depends on team velocity and complexity. Discuss with your team based on the checklist above.

---

## 7. Language-Specific Deep Analysis

**⚠️ Swift/Objective-C Interop Risks** (iOS Projects Only)

### Critical Issues 🔴

**Nullability Coverage**: [X]% ([N] files missing NS_ASSUME_NONNULL)
- **Impact**: Runtime crashes due to force unwrapping operator (!)
- **Auto-fix**: Run provided sed script to add annotations
- **Priority**: CRITICAL - Fix before making changes

### Medium Risks 🟡

**@objc Exposure**: [N] classes + [M] @objcMembers
- Classes exposing members to Objective-C
- **Risk**: Renaming/removing will break ObjC callers
- **Target file impact**: [Is/Is not] in interop boundary

**Memory Management**: [N] unowned references detected
- **Risk**: Crashes if referenced object is deallocated
- **Recommendation**: Review and convert to `weak` where appropriate

### Architecture Info ℹ️

**UI Framework**: [SwiftUI|UIKit|Hybrid]
- SwiftUI files: [N]
- UIKit files: [M]
- Integration points: [N] UIViewRepresentable, [M] UIHostingController

**Bridging Headers**: [N] found
- Largest imports: [N] headers
- Circular dependencies: [None|Detected]

💡 **Full Swift Analysis**: Run `/sourceatlas:impact [target].m` to see complete 7-section analysis

---

## 8. Recommendations

1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]
```

### For Model Impact

```markdown
🗺️ SourceAtlas: Impact
───────────────────────────────
💥 $MODEL_NAME │ [total dependents] dependents

📊 **Impact Summary**:
- Controllers: [count]
- Services: [count]
- Associated models: [count]
- Test files: [count]
- **Risk Level**: 🔴/🟡/🟢 [reason]

---

## 1. Model Definition
- File: [path]
- Table: [table_name]
- Key fields: [list]

### Associations
- `belongs_to :organization`
- `has_many :orders`
- `has_one :profile`

### Validations
- `validates :email, presence: true, uniqueness: true`
- [other validations]

---

## 2. Direct Dependencies

### Controllers ([count])
1. `UsersController#create` ([path:line])
   - Creates new User instances
   - Validation-dependent

2. `Admin::UsersController#update` ([path:line])
   - Updates User attributes

### Services ([count])
1. `UserImportService` ([path:line])
   - Bulk creates Users
   - ⚠️ No validation error handling

---

## 3. Cascade Impact

### Associated Models
1. **Order model** ([path:line])
   - `belongs_to :user, validates: true`
   - **Impact**: Will fail if User validation fails

2. **Notification model** ([path:line])
   - Assumes `user.email` is always valid
   - **Risk**: May send to invalid emails

---

## 4. Test Coverage

**Existing Tests**:
- `users_controller_spec.rb` - Basic CRUD
- `user_spec.rb` - Model validations

**Coverage Gaps**:
- ⚠️ UserImportService has no validation failure tests
- ⚠️ Order-User association not tested with invalid user

---

## 5. Migration Checklist

- [ ] Review validation rules for edge cases
- [ ] Add tests for validation failures
- [ ] Update controllers to handle new validation errors
- [ ] Check associated models for assumptions
- [ ] Add integration tests for cascade effects
- [ ] Update API documentation

**Risk Level**: 🔴 HIGH | 🟡 MEDIUM | 🟢 LOW

💡 **Note**: Time estimation depends on team velocity and complexity. Discuss with your team based on the checklist above.

---

## 6. Language-Specific Deep Analysis

*(Same format as API Impact - include if iOS/Swift project)*

```

---

## Critical Rules

1. **Static Analysis Only**: Analyze code structure, not runtime behavior
2. **Evidence-Based**: Every claim must reference file:line
3. **Prioritize Impact**: Show high-priority dependencies first
4. **Practical Output**: Focus on actionable migration steps
5. **Risk Assessment**: Always provide risk level and reasoning
6. **Test First**: Identify test gaps before changes
7. **Time Limit**: Complete analysis in 5-10 minutes

---

## Error Handling

**If target not found**:
- Search with fuzzy matching
- Suggest similar components
- Ask user to clarify

**If too many results** (>100):
- Sample top 20-30 most relevant
- Group by category (controllers, services, etc.)
- Warn about incomplete analysis

**If no dependencies found**:
- Verify target exists
- Check if it's a leaf component (no dependents)
- Suggest dead code possibility

---

## Tips for Accurate Analysis

- **Use precise grep patterns**: Match import statements, not comments
- **Follow the call chain**: From definition → usage → components
- **Check test files separately**: Different directory structure
- **Consider indirect dependencies**: Hooks/Services wrapping the target
- **Language-specific patterns**:
  - TypeScript: `import { X } from`, `X.method()`, type definitions
  - Ruby: `require`, `include`, `Class.method`
  - Go: `import`, package usage
  - Python: `from X import`, `import X`

---

## Recommended Next (Handoffs)

> Follows **Constitution Article VII: Handoffs Principles**

Add at the end of output: 

```markdown
---

## Recommended Next

| # | Command | Purpose |
|---|------|------|
| 1 | `/sourceatlas:flow "[entry point]"` | Impact chain involves N-layer calls, need to trace complete flow |
| 2 | `/sourceatlas:history "[directory]"` | This area changes frequently, need to understand historical patterns |

💡 Enter number (e.g., `1`) or copy command to execute

───────────────────────────────
🗺️ v2.11.0 │ Constitution v1.1
```

### End Conditions vs Recommendations (choose one, mutually exclusive)

**⚠️ Important: The following two outputs are mutually exclusive, choose only one**

**Situation A - End (omit Recommended Next)**: 
When any of the following conditions are met, **only output end message, do not output table**: 
- Impact scope is small: <5 dependencies, no further analysis needed
- Findings too vague: Cannot provide with high confidence (>0.7) specific parameters
- Analysis depth sufficient: Already executed 4+ commands

Output: 
```markdown
✅ **Impact analysis complete** - Can start modifications following the Migration Checklist
```

**Situation B - Recommend (output Recommended Next table)**: 
When impact scope is large or there are clear risks, **only output table, do not output end message**.

### Recommendation Selection (applies to Situation B)

| Finding | Recommended Command | Parameter Source |
|------|---------|---------|
| Involves specific pattern | `/sourceatlas:pattern` | pattern name |
| Complex impact chain | `/sourceatlas:flow` | entry point file |
| Need to understand change history | `/sourceatlas:history` | related directory |
| Need broader context | `/sourceatlas:overview` | no parameters needed |

### Output Format (Section 7.3)

Use numbered table for quick selection.

### Quality Requirements (Section 7.4-7.5)

- **Specific parameters**: Use actual found file names or entry point
- **Quantity limit**: 1-2 recommendations, not required to fill all
- **Purpose column**: Reference specific findings (dependency count, risk level, issues)

---

## Self-Verification Phase (REQUIRED)

> **Purpose**: Prevent hallucinated file paths, incorrect dependency counts, and fictional impact assessments from appearing in output.
> This phase runs AFTER output generation, BEFORE save.

### Step V1: Extract Verifiable Claims

After generating the impact analysis output, extract all verifiable claims:

**Claim Types to Extract:**

| Type | Pattern | Verification Method |
|------|---------|---------------------|
| **File Path** | Impacted files, dependencies | `test -f path` |
| **Dependency Count** | "12 direct dependencies" | Count actual imports/usages |
| **Import Statement** | `import X from Y` | `grep -q "import.*X" file` |
| **Function/Class Name** | `UserService`, `handleLogin` | `grep -q "name" file` |
| **Line Number** | `:45`, `:120` | `sed -n 'Np' file` |

### Step V2: Parallel Verification Execution

Run **ALL** verification checks in parallel:

```bash
# Execute all verifications in a single parallel block

# 1. Verify target file exists
target_file="src/services/UserService.ts"
if [ ! -f "$target_file" ]; then
    echo "❌ TARGET_NOT_FOUND: $target_file"
fi

# 2. Verify impacted files exist
for path in "src/api/auth.ts" "src/components/Login.tsx"; do
    if [ ! -f "$path" ]; then
        echo "❌ IMPACTED_FILE_NOT_FOUND: $path"
    fi
done

# 3. Verify dependency count
claimed_deps=12
actual_deps=$(grep -l "UserService" src/**/*.ts 2>/dev/null | wc -l | tr -d ' ')
if [ "$actual_deps" != "$claimed_deps" ]; then
    echo "⚠️ DEP_COUNT_MISMATCH: claimed $claimed_deps, actual $actual_deps"
fi

# 4. Verify import relationships
if ! grep -q "import.*UserService" "src/api/auth.ts" 2>/dev/null; then
    echo "❌ IMPORT_NOT_FOUND: UserService in src/api/auth.ts"
fi

# 5. Verify line number references
claimed_line=45
file_path="src/services/UserService.ts"
if [ -f "$file_path" ]; then
    line_content=$(sed -n "${claimed_line}p" "$file_path")
    if [ -z "$line_content" ]; then
        echo "❌ LINE_NOT_FOUND: line $claimed_line in $file_path"
    fi
fi
```

### Step V3: Handle Verification Results

**If ALL checks pass:**
- Continue to output/save

**If ANY check fails:**
1. **DO NOT output the uncorrected analysis**
2. Fix each failed claim:
   - `TARGET_NOT_FOUND` → Search for correct target file path
   - `IMPACTED_FILE_NOT_FOUND` → Remove from impact list or find correct path
   - `DEP_COUNT_MISMATCH` → Update with actual dependency count
   - `IMPORT_NOT_FOUND` → Remove invalid dependency relationship
   - `LINE_NOT_FOUND` → Re-read file and find correct line
3. Re-generate affected sections with corrected information
4. Re-run verification on corrected sections

### Step V4: Verification Summary (Append to Output)

Add to footer (before `🗺️ v2.11.0 │ Constitution v1.1`):

**If all verifications passed:**
```
✅ Verified: [N] file paths, [M] dependencies, [K] import relationships
```

**If corrections were made:**
```
🔧 Self-corrected: [list specific corrections made]
✅ Verified: [N] file paths, [M] dependencies, [K] import relationships
```

### Verification Checklist

Before finalizing output, confirm:
- [ ] Target file verified to exist
- [ ] All impacted file paths verified to exist
- [ ] Dependency count verified against actual grep results
- [ ] Import relationships verified via grep
- [ ] Line number references verified (content is relevant)

---

## 自動存儲（默認行為）

分析完成後，自動執行：

### Step 1: Parse target name

Extract target name from arguments (remove `--force`):
- `"User model"` → target name is `user-model`
- `"api /api/users/{id}"` → target name is `api-users-id`

Convert to filename:
- Spaces → `-`
- Slashes → `-`
- Remove `{`, `}`, special characters
- Lowercase
- Example: `"User model"` → `user-model.md`

### Step 2: Create directory

```bash
mkdir -p .sourceatlas/impact
```

### Step 3: Save output

After generating the complete analysis, save the **entire output** (from `🗺️ SourceAtlas: Impact` to the end) to `.sourceatlas/impact/{name}.md`

### Step 4: Confirm

Add at the very end:
```
💾 已儲存至 .sourceatlas/impact/{name}.md
```

---

## Deprecated: --save 參數

If `--save` is in arguments:
- 顯示: `⚠️ --save 已棄用，現在默認存儲`
- 從 arguments 中移除 `--save`
- 繼續正常執行（仍會自動存儲）
