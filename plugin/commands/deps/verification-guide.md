# Dependency Analysis Self-Verification Guide

Complete verification checklist to ensure dependency analysis accuracy.

---

## When to Verify

Execute after completing your dependency analysis, before outputting final results.

---

## Verification Steps

### Step V1: Extract Verifiable Claims

Parse your analysis output to identify all **quantifiable claims**:

```yaml
verifiable_claims:
  - "Found [N] usage points"
  - "Current version: [X.Y.Z]"
  - "Detected in [file]"
  - "[M] deprecated API usages"
  - "[K] removable availability checks"
  - "[P] new APIs available"
```

**Extract these for verification:**
- Version numbers (current/target)
- File counts
- API usage counts
- Manifest file locations
- Breaking change counts

---

### Step V2: Parallel Verification Execution

Run verification commands in **parallel** for speed:

#### V2.1: Verify Version Detection

```bash
# For Node.js/npm
grep '"${LIBRARY}"' package.json | head -5

# For iOS/CocoaPods
grep "platform :ios" Podfile | head -5

# For Android/Gradle
grep "compileSdk\|minSdk\|targetSdk" build.gradle build.gradle.kts | head -5
```

**Check:**
- ✅ Version numbers match manifest files
- ✅ Source file (package.json/Podfile) exists
- ⚠️ If mismatch → update analysis

#### V2.2: Verify API Usage Counts

```bash
# Count import/require statements
grep -r "import.*${LIBRARY}\|require.*${LIBRARY}" \
  --include="*.js" --include="*.ts" --include="*.tsx" \
  . | grep -v node_modules | wc -l

# Count specific API usage
grep -r "\.${API_NAME}\|${API_NAME}(" \
  --include="*.js" --include="*.ts" \
  . | grep -v node_modules | wc -l
```

**Check:**
- ✅ Usage count matches analysis (±5% tolerance)
- ⚠️ If significant difference → re-search with better patterns

#### V2.3: Verify File Paths

Sample 3-5 file paths from your analysis:

```bash
# Check files exist
for file in "${FILE_PATHS[@]}"; do
  if [ ! -f "$file" ]; then
    echo "⚠️ Not found: $file"
  fi
done

# Verify line numbers
grep -n "${PATTERN}" "${FILE_PATH}" | head -3
```

**Check:**
- ✅ All sampled file paths exist
- ✅ Line numbers are accurate (±2 lines)
- ⚠️ If file not found → remove from analysis

#### V2.4: Verify Upgrade Guide Source

If you used WebSearch/WebFetch:

```bash
# Verify URL accessibility (if applicable)
# Check migration guide quality indicators
```

**Check:**
- ✅ URLs are official sources (not third-party blogs)
- ✅ Migration guide matches target version
- ⚠️ If quality low → note in risk_assessment

---

### Step V3: Handle Verification Results

Based on verification outcomes:

#### If All Checks Pass ✅

```yaml
verification_status:
  verified: true
  checks_passed: 4
  confidence: high
```

Proceed to output.

#### If Minor Issues Found ⚠️ (1-2 checks failed)

**Examples:**
- File path off by 1-2 lines
- Usage count difference <10%
- Version detection from wrong source

**Action:**
1. Correct the specific claims
2. Re-verify those claims
3. Add note to output:

```yaml
verification_notes:
  - "Line numbers adjusted after verification"
  - "Usage count corrected to [N] (was [M])"
```

#### If Major Issues Found ❌ (3+ checks failed)

**Examples:**
- Claimed files don't exist
- Usage count off by >50%
- Version numbers completely wrong
- Upgrade guide for wrong version

**Action:**
1. **STOP** - Do not output current analysis
2. Re-execute Phase 1-5 from [workflow.md](workflow.md)
3. Use better search patterns
4. Verify each step before proceeding

---

### Step V4: Verification Summary

Add to final output:

```yaml
verification_summary:
  timestamp: "[ISO 8601]"
  checks_performed:
    - "Version detection: ✅"
    - "API usage counts: ✅"
    - "File path accuracy: ✅"
    - "Upgrade guide quality: ✅"

  confidence_level: "high"  # high|medium|low
  notes:
    - "[Any corrections made]"
```

**Confidence Level Criteria:**

| Level | Criteria |
|-------|----------|
| **High** | All 4 checks passed, official sources, recent data |
| **Medium** | 3/4 checks passed, or no official migration guide |
| **Low** | <3 checks passed, or upgrade guide missing |

---

## Verification Examples

### Example 1: React Upgrade

**Claim:** "Found 89 useState usages"

**Verification:**
```bash
grep -r "useState" --include="*.ts" --include="*.tsx" . | \
  grep -v node_modules | grep -v ".test." | wc -l
# Output: 87
```

**Result:** ⚠️ Minor difference (89 → 87)

**Action:**
- Update analysis: `useState: 87 usages`
- Note: "Count verified and adjusted"

---

### Example 2: iOS Version Upgrade

**Claim:** "23 removable availability checks"

**Verification:**
```bash
grep -rn "#available(iOS 1[0-6]" --include="*.swift" . | \
  grep -v Pods | wc -l
# Output: 23
```

**Result:** ✅ Exact match

**Action:** Proceed with confidence

---

### Example 3: Version Detection

**Claim:** "Current version: 17.0.2"

**Verification:**
```bash
grep '"react"' package.json
# Output: "react": "17.0.1"
```

**Result:** ❌ Version mismatch

**Action:**
- Correct to 17.0.1
- Re-check if this affects breaking changes analysis
- Verify package-lock.json for actual installed version

---

## Error Recovery

### If Verification Script Fails

```bash
# If grep returns no results
# → Pattern might be too specific, broaden search

# If file not found
# → Use find command to locate similar files

# If command times out
# → Add --max-count or | head -N to limit results
```

### If Count Discrepancy Large (>20%)

**Likely causes:**
1. Search pattern too narrow/broad
2. Wrong file extensions
3. Forgot to exclude test files
4. Manifest file outdated

**Action:**
1. Review search pattern from [workflow.md#phase-3](workflow.md#phase-3)
2. Check file extensions match project
3. Verify .gitignore patterns
4. Use Glob to list files first, then grep

---

## Best Practices

1. **Always verify version numbers** - Most critical for upgrade analysis
2. **Sample at least 3 file paths** - Ensures grep patterns worked
3. **Check official sources first** - Community guides are secondary
4. **Note all corrections** - Transparency builds trust
5. **Re-verify after corrections** - Don't assume fix is correct

---

## Handoff to Next Steps

After verification:
- ✅ If confidence HIGH → Proceed to output
- ⚠️ If confidence MEDIUM → Warn user about limitations
- ❌ If confidence LOW → Re-execute analysis or ask user for help

See [reference.md#handoffs](reference.md#handoffs) for when to suggest next commands.
