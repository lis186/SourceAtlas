---
description: Analyze dependency usage for library/framework/SDK upgrades
allowed-tools: Bash, Glob, Grep, Read, WebFetch
argument-hint: [library or SDK name, e.g., "react", "axios", "iOS 18", "Python 3.12"]
---

# SourceAtlas: Dependency Analysis

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.1
>
> Key principles enforced:
> - Article IV: 證據格式要求 (file:line references)
> - Article V: 輸出格式 (YAML)

## Context

**Arguments**: ${ARGUMENTS}

**Goal**: Analyze how a specific library, framework, or SDK is used in the codebase to facilitate upgrade planning.

---

## Your Task

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

### Phase 3: Find All Usage Points (3-5 minutes)

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

### Phase 5: Generate Analysis Report

---

## Output Format

Generate output in **YAML format**:

```yaml
dependency_analysis:
  target: "${ARGUMENTS}"
  type: "[library|sdk|framework|runtime]"
  analysis_time: "[ISO 8601 timestamp]"
  constitution_version: "1.1"

version_info:
  current: "[detected version or 'unknown']"
  source: "[package.json|Podfile|build.gradle|etc.]"
  # latest_stable: "[if easily detectable]"

usage_summary:
  total_imports: [number]
  unique_files: [number]
  unique_apis: [number]

api_usage:
  # Group by category when applicable
  hooks:  # or components, utilities, etc.
    - api: "[function/class name]"
      count: [number]
      files:
        - "[path/to/file.ts:line]"
        - "[path/to/file2.ts:line]"

  components:
    - api: "[component name]"
      count: [number]
      files:
        - "[path/to/file.tsx:line]"

  utilities:
    - api: "[utility name]"
      count: [number]
      files:
        - "[path/to/file.ts:line]"

  # For SDK analysis, group by deprecated status if known
  possibly_deprecated:
    - api: "[API name]"
      reason: "[why flagged - e.g., old naming convention, known deprecation]"
      count: [number]
      files:
        - "[path/to/file:line]"

files_using_dependency:
  - file: "[path/to/file]"
    import_count: [number]
    apis_used: ["api1", "api2"]

summary:
  key_findings:
    - "[finding 1 - e.g., Heavy usage of X API (45 occurrences)]"
    - "[finding 2 - e.g., Uses legacy API Y in 3 files]"
    - "[finding 3]"

  upgrade_considerations:
    - "[consideration 1]"
    - "[consideration 2]"

  estimated_scope: "[small|medium|large]"
  # small: <10 files, medium: 10-30 files, large: >30 files

## Next Steps

<!-- 根據發現動態建議 -->
建議對照官方文檔檢查以上 API 的相容性：
- [Library名稱] Migration Guide: [官方文檔URL如果已知]

如需進一步分析特定 API 的影響範圍：
`/atlas.impact "[specific API or file]"`
```

---

## Critical Rules

1. **Focus on USED APIs**: List what the project actually uses, not all available APIs
2. **Provide file:line references**: Every usage must have specific location (Constitution Article IV)
3. **No guessing breaking changes**: We only analyze usage, not predict compatibility
4. **Exclude dependencies**: Skip node_modules/, Pods/, .venv/, vendor/, build/
5. **Reasonable limits**: Cap at 50 usages per category to avoid overwhelming output
6. **Categorize meaningfully**: Group APIs by function (hooks, components, utilities)

---

## Tips for Efficient Analysis

- **Start with imports**: Import statements reveal the entry points
- **Sample when large**: If >100 usages, show top 20 with "and N more..."
- **Look for patterns**: Same API used similarly across files = lower risk
- **Flag outliers**: Unusual usage patterns may indicate higher upgrade risk
- **Note indirect usage**: Re-exports from internal modules count too

---

## Examples

### Example 1: React Library Analysis
```bash
/atlas.deps "react"
```

Output focuses on: hooks (useState, useEffect, etc.), components, ReactDOM APIs

### Example 2: iOS SDK Analysis
```bash
/atlas.deps "iOS 18"
```

Output focuses on: UIKit APIs, SwiftUI features, deprecated patterns

### Example 3: Python Library Analysis
```bash
/atlas.deps "pandas"
```

Output focuses on: DataFrame operations, I/O functions, deprecated methods

---

## Handoffs

根據分析結果，可能建議：

| 發現 | 建議命令 |
|------|---------|
| 高風險 API 集中在特定檔案 | `/atlas.impact "[file]"` |
| 需要學習新版本寫法 | `/atlas.pattern "[new pattern]"` |
| 想了解該模組的歷史變更 | `/atlas.history "[module]"` |
