# Dependency Analysis Output Template

Complete YAML format specification for dependency upgrade analysis.

---

## Header Format

```markdown
🗺️ SourceAtlas: Dependencies
───────────────────────────────
📦 [target] │ [N] APIs found
```

---

## YAML Output Structure

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
# SECTION 3: Usage Inventory
# ============================================
usage_inventory:
  total_files: [number]
  total_usage_points: [number]

  by_category:
    hooks:  # For React
      - name: "useState"
        count: [number]
        files:
          - "[path:line]"

    components:  # For React/Vue
      - name: "Button"
        count: [number]
        files:
          - "[path:line]"

    utilities:
      - name: "formatDate"
        count: [number]
        files:
          - "[path:line]"

# ============================================
# SECTION 4: Migration Checklist
# ============================================
migration_checklist:
  estimated_effort: "[low|medium|high]"
  recommended_approach: "[description]"

  steps:
    - step: 1
      action: "[e.g., Update package.json]"
      command: "[e.g., npm install react@18]"

    - step: 2
      action: "[e.g., Remove [N] availability checks]"
      files_affected: [number]

    - step: 3
      action: "[e.g., Update [N] deprecated API usages]"
      files_affected: [number]

    - step: 4
      action: "[e.g., Test all affected areas]"
      areas: ["[area1]", "[area2]"]

# ============================================
# SECTION 5: Risk Assessment
# ============================================
risk_assessment:
  overall_risk: "[🟢 low|🟡 medium|🔴 high]"

  factors:
    breaking_changes: "[none|minor|major]"
    usage_breadth: "[isolated|moderate|widespread]"
    test_coverage: "[good|partial|poor]"
    migration_guide_quality: "[excellent|good|poor|missing]"

  recommendations:
    - "[Recommendation 1]"
    - "[Recommendation 2]"
```

---

## Example: React Upgrade

```yaml
dependency_analysis:
  target: "react 17 → 18"
  type: "library"
  analysis_time: "2026-01-13T15:30:00Z"
  constitution_version: "1.1"

version_info:
  current: "17.0.2"
  source: "package.json"
  target: "18.2.0"

rules_applied:
  source: "web_search"
  rule_count: 12

required_changes:
  deprecated_api_usages:
    description: "Code using deprecated APIs"
    total: 3
    items:
      - file: "src/components/Header.tsx:45"
        api: "ReactDOM.render()"
        replacement: "ReactDOM.createRoot()"
        migration_effort: "medium"

      - file: "src/App.tsx:12"
        api: "unstable_batchedUpdates"
        replacement: "Automatic batching (remove)"
        migration_effort: "low"

modernization_opportunities:
  items:
    - category: "Automatic Batching"
      current_pattern: "Manual batching with unstable_batchedUpdates"
      new_pattern: "Automatic batching (built-in)"
      affected_files: 8
      benefit: "Reduced boilerplate, better performance"
      effort: "low"
      files:
        - "src/hooks/useAuth.ts:34"
        - "src/utils/state.ts:67"

usage_inventory:
  total_files: 145
  total_usage_points: 487

  by_category:
    hooks:
      - name: "useState"
        count: 89
        files:
          - "src/components/UserProfile.tsx:23"
          - "src/hooks/useForm.ts:12"

    components:
      - name: "Suspense"
        count: 12
        files:
          - "src/App.tsx:45"

migration_checklist:
  estimated_effort: "medium"
  recommended_approach: "Incremental migration - update root first, then components"

  steps:
    - step: 1
      action: "Update package.json"
      command: "npm install react@18 react-dom@18"

    - step: 2
      action: "Update root rendering"
      files_affected: 1

    - step: 3
      action: "Remove 3 deprecated API usages"
      files_affected: 3

    - step: 4
      action: "Test all components for automatic batching"
      areas: ["forms", "auth", "data-fetching"]

risk_assessment:
  overall_risk: "🟡 medium"

  factors:
    breaking_changes: "minor"
    usage_breadth: "widespread"
    test_coverage: "good"
    migration_guide_quality: "excellent"

  recommendations:
    - "Update tests to use createRoot API"
    - "Review automatic batching behavior in forms"
    - "Consider adopting new Suspense features"
```

---

## Example: iOS Minimum Version Upgrade

```yaml
dependency_analysis:
  target: "iOS 15 → 17"
  type: "runtime"
  analysis_time: "2026-01-13T16:00:00Z"
  constitution_version: "1.1"

version_info:
  current: "iOS 15.0"
  source: "Project.swift"
  target: "iOS 17.0"

required_changes:
  removable_availability_checks:
    description: "Version checks that can be removed"
    total: 23
    items:
      - file: "Sources/UI/ProfileView.swift:45"
        code: "if #available(iOS 15.0, *)"
        action: "Can be removed - always true on iOS 17+"

      - file: "Sources/UI/SettingsView.swift:89"
        code: "if #available(iOS 16.0, *)"
        action: "Can be removed - always true on iOS 17+"

  deprecated_api_usages:
    total: 0
    items: []

modernization_opportunities:
  items:
    - category: "Observation Framework"
      current_pattern: "ObservableObject + @Published"
      new_pattern: "@Observable"
      affected_files: 34
      benefit: "Simpler syntax, better performance"
      effort: "medium"
      files:
        - "Sources/ViewModels/UserViewModel.swift:12"

migration_checklist:
  estimated_effort: "low"
  recommended_approach: "Remove availability checks, consider modernization"

  steps:
    - step: 1
      action: "Update minimum deployment target"
      command: "Update Project.swift: deploymentTarget: .iOS('17.0')"

    - step: 2
      action: "Remove 23 availability checks"
      files_affected: 15

    - step: 3
      action: "Test on iOS 17 simulator"
      areas: ["all"]

risk_assessment:
  overall_risk: "🟢 low"

  factors:
    breaking_changes: "none"
    usage_breadth: "moderate"
    test_coverage: "good"
    migration_guide_quality: "good"

  recommendations:
    - "Safe upgrade - mostly code cleanup"
    - "Consider adopting @Observable for new code"
```

---

## Field Descriptions

### dependency_analysis
- **target**: Original ${ARGUMENTS} from user
- **type**: library/sdk/framework/runtime
- **analysis_time**: ISO 8601 timestamp
- **constitution_version**: Current Constitution version

### version_info
- **current**: Detected from manifest file
- **source**: Which file provided version info
- **target**: Target version for upgrade

### required_changes
Changes that MUST be done for successful upgrade:
- **removable_availability_checks**: Version checks that are now redundant
- **deprecated_api_usages**: APIs that will be removed
- **breaking_change_impacts**: Behavior changes

### modernization_opportunities
Optional improvements using new features:
- **category**: Type of opportunity
- **current_pattern**: How it's done now
- **new_pattern**: Modern approach
- **benefit**: Why it's better
- **effort**: Migration complexity

### usage_inventory
Complete list of API usage:
- **by_category**: Grouped by type (hooks, components, utilities)
- Each entry includes count and file locations

### migration_checklist
Step-by-step upgrade guide:
- **estimated_effort**: Overall complexity
- **recommended_approach**: Strategy description
- **steps**: Ordered actions with commands

### risk_assessment
Risk evaluation:
- **overall_risk**: 🟢 low / 🟡 medium / 🔴 high
- **factors**: Contributing risk elements
- **recommendations**: Specific advice
