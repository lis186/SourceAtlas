# Dependency Analysis Workflow

Complete step-by-step guide for dependency upgrade analysis.

---

## Phase 0: Rule Confirmation (1-2 minutes)

### Step 0.1: Identify Upgrade Type

Based on `${ARGUMENTS}`:

| Input Pattern | Type | Focus Areas |
|---------------|------|-------------|
| `iOS 17`, `iOS 16 → 17` | iOS Minimum Version Upgrade | Removable #available, deprecated APIs, new opportunities |
| `iOS SDK 26`, `Xcode 16` | SDK/Compiler Upgrade | Compilation warnings, Swift version, new syntax |
| `react 17 → 18`, `pandas 1.x → 2.x` | Major Version Upgrade | Breaking changes, deprecated APIs, new patterns |
| `react`, `pandas` (no version) | Usage Inventory | List usage points only |

### Step 0.2: Generate Rules Preview

Output YAML for user confirmation:
```yaml
upgrade_rules_preview:
  detected_upgrade_type: "[type]"
  from_version: "[current]"
  to_version: "[target]"

  planned_checks:
    removable_availability_checks:
      patterns: ["#available(iOS [version below target]"]
    deprecated_apis:
      source: "[built-in|web_search|migration_guide]"
```

### Step 0.3: Confirm with User

Use `AskUserQuestion` to confirm rules before proceeding.

---

## Phase 1: Detect Current Version (1 minute)

### For Node.js/npm

```bash
# package.json
grep '"${LIBRARY}"' package.json
```

### For iOS/CocoaPods

```bash
# Podfile or Podfile.lock
grep "${POD_NAME}" Podfile Podfile.lock
```

### For Android/Gradle

```bash
# build.gradle or build.gradle.kts
grep "${DEPENDENCY}" build.gradle build.gradle.kts
```

---

## Phase 2: Search for Upgrade Guide (2-3 minutes)

### Use WebSearch

```bash
# Search for official migration guide
WebSearch: "${LIBRARY} ${FROM_VERSION} to ${TO_VERSION} migration guide"
WebSearch: "${LIBRARY} breaking changes ${TO_VERSION}"
```

### Priority Order

1. Official migration guide
2. Official changelog
3. Community upgrade guides
4. GitHub release notes

---

## Phase 3: Find All Usage Points (3-5 minutes)

### For JavaScript/TypeScript

```bash
# Import statements
grep -rn "^import.*${LIBRARY}\|require.*${LIBRARY}" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . | grep -v node_modules | head -100

# Specific API usage
grep -rn "\.${API_NAME}\|${API_NAME}(" --include="*.ts" --include="*.tsx" . | grep -v node_modules | head -50
```

### For Swift/iOS

```bash
# Import statements
grep -rn "^import ${FRAMEWORK}" --include="*.swift" . | grep -v Pods | head -100

# Specific API usage (UIKit)
grep -rn "UIView\|UIViewController\|UITableView\|UICollectionView" --include="*.swift" . | grep -v Pods | head -30

# Availability checks
grep -rn "#available(iOS" --include="*.swift" . | grep -v Pods | head -50
```

### For Android/Kotlin

```bash
# Import statements
grep -rn "^import.*${LIBRARY}" --include="*.kt" --include="*.java" . | grep -v build | head -50
```

---

## Phase 4: Categorize API Usage (2-3 minutes)

From usage points found:

1. **Count unique APIs** used
2. **Group by category** (hooks, components, utilities, etc.)
3. **Note frequency** for each API
4. **Identify file:line** for each usage type
5. **Match against Phase 0 rules** to flag deprecated/removable items

---

## Phase 5: Generate Analysis Report

See [output-template.md](output-template.md) for complete format.

---

## Language-Specific Tips

### Swift/iOS

**Find removable availability checks:**
```bash
# iOS version checks below target
grep -rn "#available(iOS 14" --include="*.swift" . | grep -v Pods
grep -rn "#available(iOS 15" --include="*.swift" . | grep -v Pods
# If target is iOS 17, these can be removed
```

**Find deprecated APIs:**
```bash
# UIWebView (deprecated)
grep -rn "UIWebView" --include="*.swift" . | grep -v Pods

# @UIApplicationMain (use @main instead)
grep -rn "@UIApplicationMain" --include="*.swift" . | grep -v Pods
```

### React/JavaScript

**Find deprecated patterns:**
```bash
# Legacy lifecycle methods
grep -rn "componentWillMount\|componentWillReceiveProps" --include="*.js" --include="*.jsx" .

# String refs (deprecated)
grep -rn 'ref="' --include="*.js" --include="*.jsx" .
```

---

## Error Handling

**If upgrade guide not found:**
- Search broader terms
- Check library's official GitHub releases
- Ask user if they have migration guide URL

**If no usage found:**
- Verify dependency actually installed
- Check different file extensions
- Suggest dependency might be unused

**If breaking changes unclear:**
- Report usage statistics only
- Recommend manual review of changelog
- Provide comparison script for major APIs
