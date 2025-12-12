---
description: Analyze dependency usage for library/framework/SDK upgrades
allowed-tools: Bash, Glob, Grep, Read, WebFetch, WebSearch, AskUserQuestion
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

### Phase 0: 規則確認 (Rule Confirmation) ⭐ NEW

**IMPORTANT**: 在開始盤點前，先確認分析規則。這確保分析結果符合使用者需求。

#### Step 0.1: 識別升級類型

根據 `${ARGUMENTS}` 判斷：

| 輸入模式 | 類型 | 需確認的規則 |
|---------|------|-------------|
| `iOS 17`, `iOS 16 → 17` | **iOS 最低版本升級** | 可移除的 #available、deprecated APIs、新 API 機會 |
| `iOS SDK 26`, `Xcode 16` | **SDK/編譯器升級** | 編譯警告、Swift 版本變化、新語法 |
| `react 17 → 18`, `pandas 1.x → 2.x` | **Major 版本升級** | Breaking changes、deprecated APIs、新 patterns |
| `react`, `pandas` (無版本) | **使用點盤點** | 純粹列出使用點，不做升級分析 |

#### Step 0.2: 生成規則預覽

輸出以下 YAML 讓使用者確認：

```yaml
upgrade_rules_preview:
  detected_upgrade_type: "[type from step 0.1]"
  from_version: "[detected current version]"
  to_version: "[target version from arguments]"

  planned_checks:
    # === 對於 iOS 最低版本升級 ===
    removable_availability_checks:
      description: "升級後可移除的版本檢查"
      patterns:
        - "#available(iOS [版本低於目標]"
        - "@available(iOS [版本低於目標]"
      action: "掃描並列出可移除的程式碼"

    deprecated_apis:
      description: "在目標版本中 deprecated 的 API"
      known_items:
        # 根據目標版本填入已知項目
        - api: "[API 名稱]"
          replacement: "[新 API]"
          source: "[官方文檔 URL]"
      action: "掃描使用點並標記"

    new_api_opportunities:
      description: "升級後可採用的新 API"
      known_items:
        - api: "[新 API]"
          benefit: "[好處]"
          requires: "[最低版本]"
      action: "識別可現代化的程式碼"

    # === 對於第三方 Library 升級 ===
    breaking_changes:
      description: "已知的 Breaking Changes"
      known_items:
        - change: "[變更描述]"
          affected_api: "[API 名稱]"
          migration: "[遷移方式]"
      source: "[Changelog/Migration Guide URL]"

    third_party_compatibility:
      description: "相關第三方依賴的相容性"
      items_to_check:
        - "[dependency 1]"
        - "[dependency 2]"

  questions_for_user:
    - "以上規則是否完整？"
    - "是否有專案特定的注意事項需要加入？"
    - "需要我查詢最新的官方文檔嗎？"
```

#### Step 0.3: 使用者確認

使用 `AskUserQuestion` 工具詢問使用者：

```
questions:
  - header: "規則確認"
    question: "以上升級規則是否足夠？"
    multiSelect: false
    options:
      - label: "足夠，開始盤點"
        description: "使用以上規則進行分析"
      - label: "幫我查最新資訊"
        description: "使用 WebSearch 查詢官方 Release Notes"
      - label: "我有補充"
        description: "我會提供額外的規則或注意事項"
```

#### Step 0.4: 補充規則（如需要）

如果使用者選擇「幫我查最新資訊」：
- 使用 `WebSearch` 查詢 "[target] release notes migration guide"
- 使用 `WebFetch` 取得官方文檔內容
- 整合新發現的規則到 `planned_checks`

如果使用者選擇「我有補充」：
- 等待使用者輸入
- 將補充內容加入 `planned_checks.user_provided`

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

### Phase 3: Find All Usage Points (3-5 minutes)

**根據 Phase 0 確認的規則執行掃描**

**For iOS SDK Upgrade** (基於規則):
```bash
# 可移除的版本檢查
grep -rn "#available(iOS" --include="*.swift" . | grep -v Pods | grep -v .build

# Deprecated APIs (根據 planned_checks.deprecated_apis)
# 動態生成搜尋模式

# 新 API 採用機會 (根據 planned_checks.new_api_opportunities)
# 搜尋可被替換的舊 API
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
  target: "[target version if upgrade]"

rules_applied:
  source: "[built-in|web_search|user_provided]"
  rule_count: [number]
  # Reference to Phase 0 confirmed rules

# ============================================
# SECTION 1: 可移除/需修改的程式碼 (升級必做)
# ============================================
required_changes:
  removable_availability_checks:
    description: "升級後可移除的版本檢查"
    total: [number]
    items:
      - file: "[path:line]"
        code: "[#available(...)]"
        action: "可移除"

  deprecated_api_usages:
    description: "使用了 deprecated API 的程式碼"
    total: [number]
    items:
      - file: "[path:line]"
        api: "[deprecated API]"
        replacement: "[new API]"
        migration_effort: "[low|medium|high]"

  breaking_change_impacts:
    description: "受 breaking changes 影響的程式碼"
    total: [number]
    items:
      - file: "[path:line]"
        change: "[breaking change description]"
        action: "[required action]"

# ============================================
# SECTION 2: 現代化機會 (升級可選)
# ============================================
modernization_opportunities:
  description: "升級後可採用的新 API/Pattern"
  items:
    - category: "[e.g., Observation Framework]"
      current_pattern: "[e.g., ObservableObject + @Published]"
      new_pattern: "[e.g., @Observable]"
      affected_files: [number]
      benefit: "[e.g., 減少樣板程式碼]"
      effort: "[low|medium|high]"
      files:
        - "[path:line]"

# ============================================
# SECTION 3: 完整使用點盤點
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
# SECTION 4: 第三方依賴
# ============================================
third_party_dependencies:
  config_file: "[Podfile|package.json|etc.]"
  items:
    - name: "[dependency]"
      current_version: "[version]"
      compatible: "[yes|needs_update|unknown]"
      note: "[any notes]"

# ============================================
# SECTION 5: 總結與檢查清單
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
      - "[ ] 編譯測試"
      - "[ ] 執行測試"

## Next Steps

建議對照官方文檔：
- [官方文檔 URL]

如需進一步分析：
- `/atlas.impact "[specific API]"` - 評估特定 API 影響範圍
- `/atlas.pattern "[new pattern]"` - 學習新版本寫法
```

---

## Critical Rules

1. **Phase 0 必須執行**: 除非使用者只要「純粹盤點」，否則必須先確認規則
2. **Focus on USED APIs**: List what the project actually uses, not all available APIs
3. **Provide file:line references**: Every usage must have specific location (Constitution Article IV)
4. **No guessing breaking changes**: 只分析使用點，使用已確認的規則來標記
5. **Exclude dependencies**: Skip node_modules/, Pods/, .venv/, vendor/, build/
6. **Reasonable limits**: Cap at 50 usages per category to avoid overwhelming output
7. **Categorize meaningfully**: Group APIs by function (hooks, components, utilities)

---

## 內建規則庫 (Built-in Rules)

### iOS 版本升級規則

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
    reason: "iOS 17 新簽名"
  - api: "@ObservedObject"
    replacement: "@Observable (macro)"
    reason: "Observation framework"
  - api: "presentationMode"
    replacement: "@Environment(\\.dismiss)"
    reason: "簡化 API"

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
# 待 iOS 18 正式發布後補充
```

### React 版本升級規則

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

### Python 版本升級規則

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

Phase 0 輸出規則預覽 → 使用者確認 → 掃描 #available, deprecated APIs → 生成 migration checklist

### Example 2: Library Major Upgrade
```bash
/atlas.deps "react 17 → 18"
```

Phase 0 查詢 React 18 migration guide → 確認規則 → 掃描 ReactDOM.render 等 → 生成報告

### Example 3: Pure Usage Inventory
```bash
/atlas.deps "pandas"
```

跳過 Phase 0 規則確認 → 直接掃描使用點 → 輸出 API 使用統計

---

## Handoffs

根據分析結果，可能建議：

| 發現 | 建議命令 |
|------|---------|
| 高風險 API 集中在特定檔案 | `/atlas.impact "[file]"` |
| 需要學習新版本寫法 | `/atlas.pattern "[new pattern]"` |
| 想了解該模組的歷史變更 | `/atlas.history "[module]"` |
