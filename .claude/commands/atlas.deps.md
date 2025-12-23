---
description: Analyze dependency usage for library/framework/SDK upgrades
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write, WebFetch, WebSearch, AskUserQuestion
argument-hint: [library or SDK name, e.g., "react", "axios", "iOS 18", "Python 3.12"] [--save] [--force]
---

# SourceAtlas: Dependency Analysis

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.1
>
> Key principles enforced:
> - Article IV: Evidence Format Requirements (file:line references)
> - Article V: Output Format (YAML)

## Context

**Arguments**: ${ARGUMENTS}

**Goal**: Analyze how a specific library, framework, or SDK is used in the codebase to facilitate upgrade planning.

---

## Cache Check (Highest Priority)

**If `--force` is NOT in arguments**, check cache first:

1. Extract dependency name from `$ARGUMENTS` (remove `--save`, `--force`)
2. Convert to filename: spaces→`-`, `→`→`to`, lowercase, remove special chars, **truncate to 50 chars**
   - Example: `"react"` → `react.md`
   - Example: `"iOS 16 → 17"` → `ios-16-to-17.md`
   - Example: `"Python 3.12"` → `python-3-12.md`
3. Check cache:
   ```bash
   ls -la .sourceatlas/deps/{name}.md 2>/dev/null
   ```

4. **If cache exists**:
   - Calculate days since creation
   - Read cache content with Read tool
   - Output:
     ```
     📁 Loaded from cache: .sourceatlas/deps/{name}.md (N days ago)
     💡 To re-analyze, add --force
     ```
   - **If older than 30 days**, also show:
     ```
     ⚠️ Cache is older than 30 days, recommend re-analysis
     ```
   - Then output:
     ```
     ---
     [Cache content]
     ```
   - **Stop here, do not proceed with analysis**

5. **If cache does not exist**: Continue with analysis below

**If `--force` is in arguments**: Skip cache check, proceed directly to analysis

---

## Your Task

### Phase 0: Rule Confirmation

**IMPORTANT**: Before starting inventory, confirm analysis rules. This ensures results meet user needs.

#### Step 0.1: Identify Upgrade Type

Based on `${ARGUMENTS}`:

| Input Pattern | Type | Rules to Confirm |
|---------------|------|------------------|
| `iOS 17`, `iOS 16 → 17` | **iOS Minimum Version Upgrade** | Removable #available, deprecated APIs, new API opportunities |
| `iOS SDK 26`, `Xcode 16` | **SDK/Compiler Upgrade** | Compilation warnings, Swift version changes, new syntax |
| `react 17 → 18`, `pandas 1.x → 2.x` | **Major Version Upgrade** | Breaking changes, deprecated APIs, new patterns |
| `react`, `pandas` (no version) | **Usage Inventory** | Simply list usage points, no upgrade analysis |

#### Step 0.2: Generate Rules Preview

Output the following YAML for user confirmation:

```yaml
upgrade_rules_preview:
  detected_upgrade_type: "[type from step 0.1]"
  from_version: "[detected current version]"
  to_version: "[target version from arguments]"

  planned_checks:
    # === For iOS Minimum Version Upgrade ===
    removable_availability_checks:
      description: "Version checks that can be removed after upgrade"
      patterns:
        - "#available(iOS [version below target]"
        - "@available(iOS [version below target]"
      action: "Scan and list removable code"

    deprecated_apis:
      description: "APIs deprecated in target version"
      known_items:
        # Fill based on target version
        - api: "[API name]"
          replacement: "[new API]"
          source: "[official docs URL]"
      action: "Scan usage points and flag"

    new_api_opportunities:
      description: "New APIs available after upgrade"
      known_items:
        - api: "[new API]"
          benefit: "[benefits]"
          requires: "[minimum version]"
      action: "Identify code that can be modernized"

    # === For Third-party Library Upgrade ===
    breaking_changes:
      description: "Known breaking changes"
      known_items:
        - change: "[change description]"
          affected_api: "[API name]"
          migration: "[migration approach]"
      source: "[Changelog/Migration Guide URL]"

    third_party_compatibility:
      description: "Compatibility of related third-party dependencies"
      items_to_check:
        - "[dependency 1]"
        - "[dependency 2]"

  questions_for_user:
    - "Are the above rules complete?"
    - "Are there any project-specific considerations to add?"
    - "Should I query the latest official documentation?"
```

#### Step 0.3: User Confirmation

Use `AskUserQuestion` tool to ask user:

```
questions:
  - header: "Rule Confirmation"
    question: "Are the above upgrade rules sufficient?"
    multiSelect: false
    options:
      - label: "Sufficient, start inventory"
        description: "Use the above rules for analysis"
      - label: "Help me check latest info"
        description: "Use WebSearch to query official Release Notes"
      - label: "I have additions"
        description: "I will provide additional rules or considerations"
```

#### Step 0.4: Supplement Rules (If Needed)

If user selects "Help me check latest info":
- Use `WebSearch` to query "[target] release notes migration guide"
- Use `WebFetch` to retrieve official documentation content
- Integrate newly discovered rules into `planned_checks`

If user selects "I have additions":
- Wait for user input
- Add supplemental content to `planned_checks.user_provided`

---

### Phase 1: Identify Target Type (30 seconds)

Determine what type of dependency is being analyzed:

| Input Pattern | Type | Analysis Approach |
|--------------|------|-------------------|
| `react`, `axios`, `lodash`, `pandas` | **Library** | Search imports/requires |
| `iOS 18`, `iOS SDK 18`, `UIKit` | **iOS SDK** | Search system framework APIs |
| `Android API 35`, `Android 15` | **Android SDK** | Search Android API usage |
| `Python 3.12`, `Node 20` | **Runtime** | Search language features |
| `SwiftUI`, `Combine`, `Foundation` | **Apple Framework** | Search framework APIs |

### Phase 2: Detect Current Version (1-2 minutes)

**For Libraries**:
```bash
# JavaScript/TypeScript
grep -E "\"${ARGUMENTS}\":" package.json 2>/dev/null
grep -E "\"${ARGUMENTS}\":" package-lock.json 2>/dev/null | head -5

# Python
grep -i "${ARGUMENTS}" requirements.txt pyproject.toml setup.py 2>/dev/null

# iOS (CocoaPods)
grep -i "${ARGUMENTS}" Podfile Podfile.lock 2>/dev/null

# iOS (SPM)
grep -i "${ARGUMENTS}" Package.swift Package.resolved 2>/dev/null

# Ruby
grep -i "${ARGUMENTS}" Gemfile Gemfile.lock 2>/dev/null
```

**For SDK/Runtime**:
```bash
# iOS SDK
grep -E "IPHONEOS_DEPLOYMENT_TARGET|sdk" *.xcodeproj/project.pbxproj 2>/dev/null | head -3

# Android SDK
grep -E "compileSdk|targetSdk|minSdk" build.gradle* 2>/dev/null

# Python version
cat .python-version pyproject.toml 2>/dev/null | grep -E "python|requires-python"

# Node version
cat .nvmrc .node-version package.json 2>/dev/null | grep -E "node|engines"
```

### Phase 2.5: ast-grep Enhanced Search (Optional, P1 Enhancement)

**When to use**: ast-grep provides more precise usage point search, excluding false positives in comments and strings.

**Use unified script** (`ast-grep-search.sh`):

```bash
# Set script path (global priority, local fallback)
AST_SCRIPT=""
if [ -f ~/.claude/scripts/atlas/ast-grep-search.sh ]; then
    AST_SCRIPT=~/.claude/scripts/atlas/ast-grep-search.sh
elif [ -f scripts/atlas/ast-grep-search.sh ]; then
    AST_SCRIPT=scripts/atlas/ast-grep-search.sh
fi

# React Hooks usage inventory
$AST_SCRIPT usage "useEffect" --path .
$AST_SCRIPT usage "useState" --path .

# Swift async/await inventory
$AST_SCRIPT async --lang swift --path .

# Kotlin suspend function inventory
$AST_SCRIPT pattern "suspend" --lang kotlin --path .

# Get match count
$AST_SCRIPT usage "useEffect" --count

# If ast-grep not installed, get grep fallback command
$AST_SCRIPT usage "useEffect" --fallback
```

**Value**: Based on integration testing, ast-grep achieves in dependency inventory:
- TypeScript useEffect: 44% false positive elimination
- Swift @available: 0% (grep already sufficiently precise)
- Kotlin @Composable: 0% (grep already sufficiently precise)

**Best Practices**:
- For dedicated syntax (@available, @Composable), grep is sufficient
- For common terms (useEffect, useState, ViewModel), prefer ast-grep
- Script automatically handles fallback logic

---

### Phase 3: Find All Usage Points (3-5 minutes)

**Execute scans based on Phase 0 confirmed rules**

**For iOS SDK Upgrade** (rule-based):
```bash
# Removable version checks
grep -rn "#available(iOS" --include="*.swift" . | grep -v Pods | grep -v .build

# Deprecated APIs (based on planned_checks.deprecated_apis)
# Dynamically generate search patterns

# New API adoption opportunities (based on planned_checks.new_api_opportunities)
# Search for old APIs that can be replaced
```

**For JavaScript/TypeScript Libraries**:
```bash
# Import statements
grep -rn "from ['\"]${ARGUMENTS}" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . | grep -v node_modules | head -50

# Require statements
grep -rn "require(['\"]${ARGUMENTS}" --include="*.js" --include="*.ts" . | grep -v node_modules | head -50

# Dynamic imports
grep -rn "import(['\"]${ARGUMENTS}" --include="*.ts" --include="*.tsx" . | grep -v node_modules | head -20
```

**For Python Libraries**:
```bash
# Import statements
grep -rn "^import ${ARGUMENTS}\|^from ${ARGUMENTS}" --include="*.py" . | grep -v __pycache__ | grep -v .venv | head -50
```

**For iOS/Swift (System Frameworks)**:
```bash
# Import statements
grep -rn "^import ${ARGUMENTS}\|import ${ARGUMENTS}$" --include="*.swift" . | grep -v Pods | grep -v .build | head -50

# Specific API usage (for common frameworks)
# UIKit
grep -rn "UIView\|UIViewController\|UITableView\|UICollectionView" --include="*.swift" . | grep -v Pods | head -30

# SwiftUI
grep -rn "@State\|@Binding\|@Observable\|@Environment" --include="*.swift" . | grep -v Pods | head -30
```

**For Android/Kotlin**:
```bash
# Import statements
grep -rn "^import.*${ARGUMENTS}" --include="*.kt" --include="*.java" . | grep -v build | head -50
```

### Phase 4: Categorize API Usage (2-3 minutes)

From the usage points found, extract and categorize:

1. **Count unique APIs** used from the library
2. **Group by category** (hooks, components, utilities, etc.)
3. **Note usage frequency** for each API
4. **Identify specific file:line** for each usage type
5. **Match against Phase 0 rules** to flag deprecated/removable items

### Phase 5: Generate Analysis Report

---

## Output Format

Generate output with **branded header**, then **YAML format**:

```markdown
🗺️ SourceAtlas: Dependencies
───────────────────────────────
📦 [target] │ [N] APIs found
```

Then YAML content:

```yaml
dependency_analysis:
  target: "${ARGUMENTS}"
  type: "[library|sdk|framework|runtime]"
  analysis_time: "[ISO 8601 timestamp]"
  constitution_version: "1.1"

version_info:
  current: "[detected version or 'unknown']"
  source: "[package.json|Podfile|build.gradle|etc.]"
  target: "[target version if upgrade]"

rules_applied:
  source: "[built-in|web_search|user_provided]"
  rule_count: [number]
  # Reference to Phase 0 confirmed rules

# ============================================
# SECTION 1: Removable/Modifiable Code (Required for Upgrade)
# ============================================
required_changes:
  removable_availability_checks:
    description: "Version checks that can be removed after upgrade"
    total: [number]
    items:
      - file: "[path:line]"
        code: "[#available(...)]"
        action: "Can be removed"

  deprecated_api_usages:
    description: "Code using deprecated APIs"
    total: [number]
    items:
      - file: "[path:line]"
        api: "[deprecated API]"
        replacement: "[new API]"
        migration_effort: "[low|medium|high]"

  breaking_change_impacts:
    description: "Code affected by breaking changes"
    total: [number]
    items:
      - file: "[path:line]"
        change: "[breaking change description]"
        action: "[required action]"

# ============================================
# SECTION 2: Modernization Opportunities (Optional for Upgrade)
# ============================================
modernization_opportunities:
  description: "New APIs/Patterns available after upgrade"
  items:
    - category: "[e.g., Observation Framework]"
      current_pattern: "[e.g., ObservableObject + @Published]"
      new_pattern: "[e.g., @Observable]"
      affected_files: [number]
      benefit: "[e.g., Reduce boilerplate code]"
      effort: "[low|medium|high]"
      files:
        - "[path:line]"

# ============================================
# SECTION 3: Complete Usage Point Inventory
# ============================================
usage_summary:
  total_imports: [number]
  unique_files: [number]
  unique_apis: [number]

api_usage:
  # Group by category
  hooks:
    - api: "[function name]"
      count: [number]
      files:
        - "[path:line]"

  components:
    - api: "[component name]"
      count: [number]
      status: "[ok|deprecated|needs_update]"
      files:
        - "[path:line]"

# ============================================
# SECTION 4: Third-party Dependencies
# ============================================
third_party_dependencies:
  config_file: "[Podfile|package.json|etc.]"
  items:
    - name: "[dependency]"
      current_version: "[version]"
      compatible: "[yes|needs_update|unknown]"
      note: "[any notes]"

# ============================================
# SECTION 5: Summary and Checklist
# ============================================
summary:
  key_findings:
    - "[finding 1]"
    - "[finding 2]"

  estimated_scope: "[small|medium|large]"

  migration_checklist:
    phase1_required:
      - "[ ] [required change 1]"
      - "[ ] [required change 2]"
    phase2_recommended:
      - "[ ] [modernization 1]"
      - "[ ] [modernization 2]"
    phase3_verification:
      - "[ ] Compile test"
      - "[ ] Run tests"

## Next Steps

Recommended to cross-reference with official documentation:
- [Official documentation URL]

───────────────────────────────
🗺️ v2.9.6 │ Constitution v1.1
```

For further analysis:
- `/atlas.impact "[specific API]"` - Assess impact scope of specific API
- `/atlas.pattern "[new pattern]"` - Learn new version patterns
```

---

## Critical Rules

1. **Phase 0 must be executed**: Unless user only wants "pure inventory", must confirm rules first
2. **Focus on USED APIs**: List what the project actually uses, not all available APIs
3. **Provide file:line references**: Every usage must have specific location (Constitution Article IV)
4. **No guessing breaking changes**: Only analyze usage points, use confirmed rules to flag
5. **Exclude dependencies**: Skip node_modules/, Pods/, .venv/, vendor/, build/
6. **Reasonable limits**: Cap at 50 usages per category to avoid overwhelming output
7. **Categorize meaningfully**: Group APIs by function (hooks, components, utilities)

---

## Built-in Rules Library

### iOS Version Upgrade Rules

#### iOS 16 → 17
```yaml
removable_checks:
  - "#available(iOS 16"
  - "#available(iOS 15"
  - "#available(iOS 14"
  - "#available(iOS 13"

deprecated_apis:
  - api: "onChange(of:) { newValue in }"
    replacement: "onChange(of:) { oldValue, newValue in }"
    reason: "iOS 17 new signature"
  - api: "@ObservedObject"
    replacement: "@Observable (macro)"
    reason: "Observation framework"
  - api: "presentationMode"
    replacement: "@Environment(\\.dismiss)"
    reason: "Simplified API"

new_features:
  - feature: "@Observable"
    min_version: "iOS 17.0"
  - feature: "Interactive Widgets"
    min_version: "iOS 17.0"
  - feature: "TipKit"
    min_version: "iOS 17.0"
  - feature: "SwiftData"
    min_version: "iOS 17.0"
```

#### iOS 17 → 18
```yaml
# To be supplemented after iOS 18 official release
```

### React Version Upgrade Rules

#### React 17 → 18
```yaml
breaking_changes:
  - api: "ReactDOM.render"
    replacement: "createRoot().render()"
    reason: "Concurrent rendering"
  - api: "ReactDOM.hydrate"
    replacement: "hydrateRoot()"
    reason: "Concurrent rendering"

new_features:
  - feature: "useId"
  - feature: "useDeferredValue"
  - feature: "useTransition"
  - feature: "Automatic batching"
```

### Python Version Upgrade Rules

#### Python 3.11 → 3.12
```yaml
new_features:
  - feature: "f-string improvements"
  - feature: "TypedDict improvements"
  - feature: "Per-interpreter GIL"
```

---

## Tips for Efficient Analysis

- **Start with imports**: Import statements reveal the entry points
- **Sample when large**: If >100 usages, show top 20 with "and N more..."
- **Look for patterns**: Same API used similarly across files = lower risk
- **Flag outliers**: Unusual usage patterns may indicate higher upgrade risk
- **Note indirect usage**: Re-exports from internal modules count too
- **Match against rules**: Use Phase 0 rules to categorize findings

---

## Examples

### Example 1: iOS Minimum Version Upgrade
```bash
/atlas.deps "iOS 16 → 17"
```

Phase 0 outputs rules preview → User confirms → Scan #available, deprecated APIs → Generate migration checklist

### Example 2: Library Major Upgrade
```bash
/atlas.deps "react 17 → 18"
```

Phase 0 queries React 18 migration guide → Confirm rules → Scan ReactDOM.render etc. → Generate report

### Example 3: Pure Usage Inventory
```bash
/atlas.deps "pandas"
```

Skip Phase 0 rule confirmation → Directly scan usage points → Output API usage statistics

---

## Handoffs

Based on analysis results, may suggest:

| Finding | Suggested Command |
|---------|-------------------|
| High-risk APIs concentrated in specific files | `/atlas.impact "[file]"` |
| Need to learn new version patterns | `/atlas.pattern "[new pattern]"` |
| Want to understand module's historical changes | `/atlas.history "[module]"` |

---

## Self-Verification Phase (REQUIRED)

> **Purpose**: Prevent hallucinated dependency names, incorrect version numbers, and fictional API changes from appearing in output.
> This phase runs AFTER output generation, BEFORE save.

### Step V1: Extract Verifiable Claims

After generating the dependency analysis output, extract all verifiable claims:

**Claim Types to Extract:**

| Type | Pattern | Verification Method |
|------|---------|---------------------|
| **Dependency Name** | Package names in inventory | Check package manifest |
| **Current Version** | "react@18.2.0" | `grep "react" package.json` |
| **File Path** | Usage location files | `test -f path` |
| **Usage Count** | "used in 45 files" | `grep -r "import" \| wc -l` |
| **Config File** | "package.json", "Podfile" | `test -f config_file` |

### Step V2: Parallel Verification Execution

Run **ALL** verification checks in parallel:

```bash
# Execute all verifications in a single parallel block

# 1. Verify dependency exists in manifest
if ! grep -q '"react"' package.json 2>/dev/null; then
    echo "❌ DEPENDENCY_NOT_FOUND: react in package.json"
fi

# 2. Verify version matches
claimed_version="18.2.0"
actual_version=$(grep -o '"react": "[^"]*"' package.json 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
if [ "$actual_version" != "$claimed_version" ]; then
    echo "⚠️ VERSION_MISMATCH: claimed $claimed_version, actual $actual_version"
fi

# 3. Verify usage file paths
for path in "src/components/App.tsx" "src/hooks/useAuth.ts"; do
    if [ ! -f "$path" ]; then
        echo "❌ FILE_NOT_FOUND: $path"
    fi
done

# 4. Verify package manifest exists
for manifest in "package.json" "Podfile" "build.gradle"; do
    if [ -f "$manifest" ]; then
        echo "✅ MANIFEST_FOUND: $manifest"
        break
    fi
done
```

### Step V3: Handle Verification Results

**If ALL checks pass:**
- Continue to output/save

**If ANY check fails:**
1. **DO NOT output the uncorrected analysis**
2. Fix each failed claim:
   - `DEPENDENCY_NOT_FOUND` → Remove from inventory or find correct manifest
   - `VERSION_MISMATCH` → Update with actual version from manifest
   - `FILE_NOT_FOUND` → Search for correct usage locations
3. Re-generate affected sections with corrected information
4. Re-run verification on corrected sections

### Step V4: Verification Summary (Append to Output)

Add to footer (before `🗺️ v2.9.6 │ Constitution v1.1`):

**If all verifications passed:**
```
✅ Verified: [N] dependencies, [M] versions, [K] usage files
```

**If corrections were made:**
```
🔧 Self-corrected: [list specific corrections made]
✅ Verified: [N] dependencies, [M] versions, [K] usage files
```

### Verification Checklist

Before finalizing output, confirm:
- [ ] All dependencies verified to exist in package manifest
- [ ] All version numbers match actual manifest entries
- [ ] Usage file paths verified to exist
- [ ] Breaking change examples verified in actual API docs (if claimed)
- [ ] Migration code snippets verified to be syntactically correct

---

## Save Mode (--save)

If `--save` is present in `$ARGUMENTS`:

### Step 1: Parse library/SDK name

Extract name from arguments (remove `--save`):
- `"react" --save` → name is `react`
- `"iOS 16 → 17" --save` → name is `ios-16-to-17`

Convert to filename:
- Spaces → `-`
- `→` → `to`
- Remove special characters
- Lowercase
- Example: `"Python 3.12"` → `python-3-12.md`

### Step 2: Create directory

```bash
mkdir -p .sourceatlas/deps
```

### Step 3: Save output

After generating the complete analysis, save the **entire YAML output** to `.sourceatlas/deps/{name}.md`

### Step 4: Confirm

Add at the very end:
```
💾 Saved to .sourceatlas/deps/{name}.md
```
