# Dependency Analysis Reference

Advanced features, caching behavior, and best practices.

---

## Cache Behavior

### When Cache is Used

```bash
# Default: Use cache if exists and fresh
/sourceatlas:deps "react"

# Check logic:
if [ -f ".sourceatlas/deps/${SANITIZED_TARGET}.md" ]; then
  age_days=$(calculate_age_in_days)
  if [ $age_days -eq 0 ]; then
    echo "📁 Loading from cache (today)"
  elif [ $age_days -eq 1 ]; then
    echo "📁 Loading from cache (1 day ago)"
  else
    echo "📁 Loading from cache ($age_days days ago)"
  fi
  # Output cached content
  exit 0
fi
```

### When Cache is Skipped

```bash
# Force flag: Always skip cache
/sourceatlas:deps "react" --force
# → Executes full analysis even if cache exists

# No cache: First time analysis
# → .sourceatlas/deps/ doesn't exist yet
```

### Cache File Naming

```bash
# Target sanitization rules:
"react 17 → 18"  → "react-17-18.md"
"iOS 16"         → "ios-16.md"
"lodash"         → "lodash.md"
"@types/node"    → "types-node.md"

# Pattern: lowercase, alphanumeric + hyphens only
sanitized=$(echo "$ARGUMENTS" | tr '[:upper:]' '[:lower:]' | \
            sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | \
            sed 's/^-//' | sed 's/-$//')
```

---

## Auto-Save Behavior

### File Structure

```
.sourceatlas/deps/
├── react-17-18.md           # Analysis for "react 17 → 18"
├── ios-16-17.md             # Analysis for "iOS 16 → 17"
├── lodash.md                # Analysis for "lodash"
└── pandas-1x-2x.md          # Analysis for "pandas 1.x → 2.x"
```

### Save Timing

Auto-save occurs **immediately after Step V4 verification**:

```yaml
# After verification passes
verification_summary:
  confidence_level: "high"

# Then auto-save
💾 Saved to .sourceatlas/deps/react-17-18.md
```

### What Gets Saved

Complete YAML output including:
- dependency_analysis header
- version_info
- rules_applied
- required_changes (all items)
- modernization_opportunities
- usage_inventory (by_category)
- migration_checklist
- risk_assessment
- verification_summary

**Format:** Full YAML as specified in [output-template.md](output-template.md)

---

## Handoffs: When to Suggest Next Commands

### After Usage Inventory (No Upgrade)

If user only asked for usage analysis without version upgrade:

```yaml
usage_inventory:
  total_files: 45
  total_usage_points: 123
```

**Suggest:**
```
✨ Next steps:
- /sourceatlas:impact "src/hooks/useAuth.ts" - See impact of changing this hook
- /sourceatlas:pattern "react hooks" - Learn project's hook patterns
```

### After Upgrade Analysis (Low Risk)

```yaml
risk_assessment:
  overall_risk: "🟢 low"
```

**Suggest:**
```
✨ Next steps:
- Update package.json and run tests
- /sourceatlas:impact - Check impact after upgrade
```

### After Upgrade Analysis (Medium/High Risk)

```yaml
risk_assessment:
  overall_risk: "🟡 medium"
```

**Suggest:**
```
⚠️ Recommended actions:
1. Review all deprecated API usages carefully
2. Create a feature branch for testing
3. /sourceatlas:impact "ComponentX" - Analyze high-risk components first
```

### If WebSearch/WebFetch Failed

```yaml
rules_applied:
  source: "built-in"  # Fallback to built-in rules
```

**Suggest:**
```
⚠️ Could not find official migration guide
Please manually review:
- ${LIBRARY} official changelog
- Breaking changes documentation
```

---

## Language-Specific Best Practices

### JavaScript/TypeScript (Node.js)

**Manifest Files:**
- `package.json` - Primary source
- `package-lock.json` - Actual installed versions
- `yarn.lock` or `pnpm-lock.yaml` - Alternative lock files

**Search Tips:**
```bash
# Include all JS/TS variants
--include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx"

# Exclude common directories
grep -v "node_modules\|dist\|build\|.next"

# Monorepo: Check workspace packages
grep -r "\"workspaces\"" package.json
```

**Common Upgrade Patterns:**
- Major versions (e.g., React 17 → 18) → Focus on breaking changes
- Minor versions (e.g., Next.js 13.4 → 13.5) → Focus on new features
- Patch versions → Usually safe, check security fixes

---

### Swift/iOS

**Manifest Files:**
- `Podfile` - CocoaPods dependencies
- `Package.swift` - Swift Package Manager
- `Cartfile` - Carthage dependencies
- Project settings (`.xcodeproj`) - iOS deployment target

**Search Tips:**
```bash
# Availability checks
grep -rn "#available(iOS" --include="*.swift" . | grep -v Pods

# Framework imports
grep -rn "^import UIKit\|^import SwiftUI" --include="*.swift" .

# Deprecated APIs
grep -rn "@available(*, deprecated" --include="*.swift" .
```

**iOS Version Upgrades:**
- iOS 15 → 17: Focus on removable `#available` checks
- iOS 17+: Consider new APIs like `@Observable`, `Observation`
- Check Swift version compatibility

---

### Android/Kotlin

**Manifest Files:**
- `build.gradle` or `build.gradle.kts` - Main config
- `settings.gradle` - Project structure
- `gradle.properties` - SDK versions

**Search Tips:**
```bash
# API level checks
grep -rn "Build.VERSION.SDK_INT" --include="*.kt" --include="*.java" .

# Dependency versions
grep "implementation\|api\|compileOnly" build.gradle
```

---

## WebSearch Strategy

### Query Templates

For major version upgrades:
```
"${LIBRARY} ${FROM_VERSION} to ${TO_VERSION} migration guide"
"${LIBRARY} ${TO_VERSION} breaking changes"
"${LIBRARY} changelog ${TO_VERSION}"
```

For iOS/Android SDK:
```
"iOS ${TO_VERSION} migration guide"
"Android API ${TO_VERSION} migration"
"What's new in iOS ${TO_VERSION}"
```

### Source Priority

1. **Official docs** (highest priority)
   - Library's official website
   - GitHub releases page
   - Official migration guides

2. **Semi-official** (high priority)
   - Framework maintainer blog posts
   - Official YouTube channels
   - Conference talks

3. **Community** (medium priority)
   - Dev.to, Medium articles by core contributors
   - Stack Overflow highly-voted questions
   - GitHub discussions

4. **Avoid** (low priority)
   - Random blogs without verification
   - Outdated tutorials
   - AI-generated content without sources

---

## Edge Cases

### Case 1: Dependency Not Found in Manifest

```yaml
version_info:
  current: "unknown"
  source: "not found in manifest files"
```

**Possible reasons:**
1. Transitive dependency (not directly listed)
2. Different package name
3. Bundled in framework

**Action:**
- Search for import/require statements
- Check lock files for transitive deps
- Ask user to clarify package name

---

### Case 2: Multiple Versions Detected

```bash
# package.json shows 17.0.2
# package-lock.json shows 17.0.1
```

**Action:**
```yaml
version_info:
  current: "17.0.1"  # Use lock file version
  source: "package-lock.json (installed)"
  note: "package.json specifies ^17.0.2"
```

---

### Case 3: Monorepo with Multiple Packages

```bash
# Root package.json: "react": "17.0.2"
# packages/app-a/package.json: "react": "16.8.0"
```

**Action:**
1. Clarify scope with user:
   ```
   ⚠️ Multiple versions detected:
   - Root: 17.0.2
   - packages/app-a: 16.8.0

   Analyzing root package by default.
   Use `/sourceatlas:deps "react" --scope=app-a` to analyze specific package.
   ```

2. Analyze specified scope only

---

### Case 4: No Upgrade Guide Found

```yaml
rules_applied:
  source: "built-in"
  rule_count: 0
```

**Action:**
1. Report usage statistics only
2. Skip breaking changes analysis
3. Recommend manual changelog review:

```
⚠️ Could not find migration guide for ${LIBRARY}

Provided usage inventory only. Please manually review:
- ${LIBRARY} official changelog
- GitHub releases: https://github.com/${ORG}/${REPO}/releases
```

---

## Performance Optimization

### For Large Codebases

```bash
# Limit grep results to prevent timeout
grep -r "pattern" --include="*.js" . | head -100

# Use --max-count for early exit
grep -r --max-count=50 "pattern" .

# Parallel search for multiple patterns
grep -r "pattern1" . & grep -r "pattern2" . & wait
```

### For Monorepos

```bash
# Skip non-source directories
grep -r "pattern" . \
  --exclude-dir="node_modules" \
  --exclude-dir="dist" \
  --exclude-dir="build" \
  --exclude-dir=".next" \
  --exclude-dir="coverage"
```

---

## Troubleshooting

### Issue: Version Detection Failed

**Symptom:** `current: "unknown"`

**Debug:**
```bash
# Check manifest file exists
ls -la package.json Podfile build.gradle

# Verify file format
cat package.json | python -m json.tool

# Search more broadly
grep -i "version" package.json
```

---

### Issue: No Usage Points Found

**Symptom:** `total_usage_points: 0`

**Debug:**
```bash
# Verify library name
echo "Searching for: ${LIBRARY}"

# Try broader pattern
grep -r "${LIBRARY}" . | head -20

# Check file extensions
find . -name "*.js" -o -name "*.ts" | head -10
```

---

### Issue: WebSearch Returns Irrelevant Results

**Symptom:** Migration guide for wrong version

**Action:**
1. Add version number to query: `"react 18.0.0 migration"` (not just "react 18")
2. Add "official" keyword: `"official react 18 migration guide"`
3. Use site-specific search: `"site:reactjs.org migration guide"`

---

## Constitutional Compliance

### Article I: Evidence-Based Analysis
- ✅ Every claim must reference actual files
- ✅ Version numbers from manifest files only
- ✅ Usage counts from verified grep results

### Article III: Verification Required
- ✅ Execute [verification-guide.md](verification-guide.md) before output
- ✅ Re-verify after corrections

### Article V: Transparency
- ✅ Show cache age: "Loading from cache (2 days ago)"
- ✅ Disclose upgrade guide source: "source: web_search"
- ✅ Note any limitations: "No official migration guide found"

### Article VII: User Empowerment
- ✅ Provide actionable migration checklist
- ✅ Estimate effort level
- ✅ Suggest next steps

---

## Related Commands

After dependency analysis, consider:

- **`/sourceatlas:impact "Component"`** - See change impact before upgrade
- **`/sourceatlas:pattern "api"`** - Learn how project uses the library
- **`/sourceatlas:history "src/lib/"`** - Check change frequency in affected areas
