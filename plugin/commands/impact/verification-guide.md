# Impact Analysis Verification Guide

Prevent hallucinated file paths, incorrect dependency counts, and fictional impact assessments.

**When to Run**: After output generation, BEFORE save

---

## Step V1: Extract Verifiable Claims

After generating the impact analysis output, extract all verifiable claims:

### Claim Types to Extract

| Type | Pattern | Verification Method |
|------|---------|---------------------|
| **File Path** | Impacted files, dependencies | `test -f path` |
| **Dependency Count** | "12 direct dependencies" | Count actual imports/usages |
| **Import Statement** | `import X from Y` | `grep -q "import.*X" file` |
| **Function/Class Name** | `UserService`, `handleLogin` | `grep -q "name" file` |
| **Line Number** | `:45`, `:120` | `sed -n 'Np' file` |

---

## Step V2: Parallel Verification Execution

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

---

## Step V3: Handle Verification Results

### If ALL checks pass

- Continue to output/save

### If ANY check fails

1. **DO NOT output the uncorrected analysis**
2. Fix each failed claim:
   - `TARGET_NOT_FOUND` → Search for correct target file path
   - `IMPACTED_FILE_NOT_FOUND` → Remove from impact list or find correct path
   - `DEP_COUNT_MISMATCH` → Update with actual dependency count
   - `IMPORT_NOT_FOUND` → Remove invalid dependency relationship
   - `LINE_NOT_FOUND` → Re-read file and find correct line
3. Re-generate affected sections with corrected information
4. Re-run verification on corrected sections

---

## Step V4: Verification Summary

Add to footer (before `🗺️ v2.11.0 │ Constitution v1.1`):

### If all verifications passed

```
✅ Verified: [N] file paths, [M] dependencies, [K] import relationships
```

### If corrections were made

```
🔧 Self-corrected: [list specific corrections made]
✅ Verified: [N] file paths, [M] dependencies, [K] import relationships
```

---

## Verification Checklist

Before finalizing output, confirm:

- [ ] Target file verified to exist
- [ ] All impacted file paths verified to exist
- [ ] Dependency count verified against actual grep results
- [ ] Import relationships verified via grep
- [ ] Line number references verified (content is relevant)

---

## Common Verification Errors

### Error: TARGET_NOT_FOUND

**Cause**: Target file path doesn't exist

**Fix**:
```bash
# Find the correct path
find . -name "*UserService*" -type f | grep -v node_modules | grep -v test
# Update output with correct path
```

### Error: DEP_COUNT_MISMATCH

**Cause**: Claimed count doesn't match actual grep results

**Fix**:
```bash
# Recount dependencies
actual_count=$(grep -rl "UserService" src/ | wc -l | tr -d ' ')
# Update output with actual count
```

### Error: IMPORT_NOT_FOUND

**Cause**: Claimed import statement doesn't exist in file

**Fix**:
```bash
# Verify import exists
grep "import.*UserService" src/api/auth.ts
# If not found, remove this dependency from report
```

### Error: LINE_NOT_FOUND

**Cause**: Referenced line number doesn't exist or file is shorter

**Fix**:
```bash
# Check actual file length
wc -l src/services/UserService.ts
# Re-read file and find correct line
# Update line number in output
```

---

## Verification Examples

### Example 1: Verify dependency count

```bash
# Claim: "12 direct dependencies on UserService"
claimed=12
actual=$(grep -rl "import.*UserService\|from.*UserService" src/ | wc -l | tr -d ' ')

if [ "$actual" != "$claimed" ]; then
    echo "⚠️ Count mismatch: claimed $claimed, actual $actual"
    # Update output with actual count
fi
```

### Example 2: Verify file paths

```bash
# Claim: Impact analysis lists 5 files
files=(
    "src/api/users.ts"
    "src/components/UserBadge.tsx"
    "src/hooks/useUser.ts"
    "src/services/UserService.ts"
    "src/types/user.d.ts"
)

for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ File not found: $file"
    fi
done
```

### Example 3: Verify import relationships

```bash
# Claim: "UserBadge.tsx imports useUser hook"
if ! grep -q "import.*useUser\|from.*useUser" "src/components/UserBadge.tsx"; then
    echo "❌ Import not found: useUser in UserBadge.tsx"
    # Remove this claim from output
fi
```

---

## Quality Assurance

### High Confidence Required

Only include claims with >90% confidence:
- File paths you've actually Read
- Counts from actual grep results
- Import statements you've verified

### Exclude Low Confidence

Remove claims based on:
- Assumptions without verification
- Estimated counts (use "~")
- Speculative dependencies
