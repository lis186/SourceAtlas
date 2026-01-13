# Impact Analysis Workflow

Complete step-by-step guide for executing static dependency analysis.

## Step 1: Parse Target and Detect Type (1 minute)

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

## Step 2: Project Context Detection (1 minute)

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

## Step 2.5: ast-grep Enhanced Search (Optional, P1 Enhancement)

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

## Step 3: Execute Impact Analysis (3-5 minutes)

### For API Impact (Type: API)

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

### For Model Impact (Type: MODEL)

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

### For General Component (Type: COMPONENT)

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

## Step 4: Test Impact Analysis (1-2 minutes)

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

## Step 5: Language-Specific Deep Analysis (1-2 minutes, optional)

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

## Step 6: Risk Assessment (1 minute)

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
