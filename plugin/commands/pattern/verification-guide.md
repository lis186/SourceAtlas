# Pattern Learning Self-Verification Guide

Complete verification checklist to ensure pattern analysis accuracy.

---

## When to Verify

Execute after completing your pattern analysis, before outputting final results.

---

## Verification Steps

### Step V1: Extract Verifiable Claims

Parse your analysis output to identify all **quantifiable claims**:

```yaml
verifiable_claims:
  - "path/to/file.ts:45 contains pattern"
  - "Found 12 files matching pattern"
  - "Controllers placed in app/controllers/ directory"
  - "Code snippet from UserController.ts"
```

**Extract these for verification:**
- File paths (with line numbers)
- Directory paths
- Code snippets (must match actual file content)
- File counts ("12 files found")
- Pattern-specific claims (naming conventions, structure)

---

### Step V2: Parallel Verification Execution

Run verification commands in **parallel** for speed:

#### V2.1: Verify File Paths

```bash
# Check all file paths in "Best Examples" section
for path in "src/api/controllers/UserController.ts" "src/services/UserService.ts"; do
    if [ ! -f "$path" ]; then
        echo "❌ FILE_NOT_FOUND: $path"
    fi
done
```

**Check:**
- ✅ All referenced file paths exist
- ⚠️ If file not found → Search for similar path or remove example

#### V2.2: Verify Line Numbers

```bash
# Verify line number references
file="src/api/controllers/UserController.ts"
claimed_line=45

# Check if line exists
total_lines=$(wc -l < "$file" 2>/dev/null)
if [ $claimed_line -gt $total_lines ]; then
    echo "⚠️ LINE_OUT_OF_RANGE: $file:$claimed_line (file has $total_lines lines)"
fi

# Spot-check content at that line
sed -n "${claimed_line}p" "$file"
```

**Check:**
- ✅ Line numbers are within file bounds
- ✅ Content at line number matches description
- ⚠️ If line mismatch → Re-read file and find correct line

#### V2.3: Verify Code Snippets

```bash
# Verify code snippet exists in file
snippet_key_line="async getUser"
file="src/api/controllers/UserController.ts"

if ! grep -q "$snippet_key_line" "$file" 2>/dev/null; then
    echo "❌ CODE_NOT_FOUND: '$snippet_key_line' in $file"
fi
```

**Check:**
- ✅ Key lines from code snippets exist in claimed files
- ✅ Code syntax is valid (no typos in snippet)
- ⚠️ If code not found → Re-read file and extract correct snippet

#### V2.4: Verify Directory Paths

```bash
# Verify directory paths in "Key Conventions"
for dir in "app/controllers" "app/services" "app/repositories"; do
    if [ ! -d "$dir" ]; then
        echo "❌ DIR_NOT_FOUND: $dir"
    fi
done
```

**Check:**
- ✅ All mentioned directories exist
- ⚠️ If directory not found → Search for similar path or correct claim

#### V2.5: Verify File Counts

```bash
# Verify "Found N files" claim
claimed_count=12
actual_count=$(find . -path "*/*Controller.ts" -type f 2>/dev/null | wc -l | tr -d ' ')

if [ "$actual_count" != "$claimed_count" ]; then
    echo "⚠️ COUNT_MISMATCH: claimed $claimed_count, actual $actual_count"
fi
```

**Check:**
- ✅ File count matches actual search results (±2 tolerance)
- ⚠️ If significant difference → Update count

---

### Step V3: Handle Verification Results

Based on verification outcomes:

#### If All Checks Pass ✅

```yaml
verification_status:
  verified: true
  checks_passed: 5
  confidence: high
```

Proceed to output.

#### If Minor Issues Found ⚠️ (1-2 checks failed)

**Examples:**
- Line number off by 1-2 lines
- File count slightly different (±2)
- Directory path has different name

**Action:**
1. Correct the specific claims
2. Re-verify those claims
3. Add note to output:

```yaml
verification_notes:
  - "Line numbers adjusted after verification"
  - "File count corrected to 14 (was 12)"
```

#### If Major Issues Found ❌ (3+ checks failed)

**Examples:**
- Multiple file paths don't exist
- Code snippets not found in claimed files
- Directory structure completely different

**Action:**
1. **STOP** - Do not output current analysis
2. Re-execute Step 1-4 from [workflow.md](workflow.md)
3. Use better search patterns
4. Verify each file before including in examples

---

### Step V4: Verification Summary

Add to final output (before footer):

```yaml
verification_summary:
  timestamp: "[ISO 8601]"
  checks_performed:
    - "File paths: ✅"
    - "Line numbers: ✅"
    - "Code snippets: ✅"
    - "Directories: ✅"
    - "File counts: ✅"

  confidence_level: "high"  # high|medium|low
  notes:
    - "[Any corrections made]"
```

**Confidence Level Criteria:**

| Level | Criteria |
|-------|----------|
| **High** | All 5 checks passed, no corrections |
| **Medium** | 4/5 checks passed, minor corrections |
| **Low** | <4 checks passed, major corrections |

---

## Verification Examples

### Example 1: File Path Verification

**Claim:** "src/api/controllers/UserController.ts:45"

**Verification:**
```bash
test -f "src/api/controllers/UserController.ts"
# Exit code: 0 (exists)
```

**Result:** ✅ File exists

**Action:** No correction needed

---

### Example 2: Line Number Verification

**Claim:** "UserController.ts:45 - async getUser method"

**Verification:**
```bash
sed -n '45p' src/api/controllers/UserController.ts
# Output: async getUser(@Param('id') id: string): Promise<User> {
```

**Result:** ✅ Line matches description

**Action:** No correction needed

---

### Example 3: Code Snippet Verification

**Claim:** Code snippet shows `@UseGuards(AuthGuard)`

**Verification:**
```bash
grep -n "@UseGuards(AuthGuard)" src/api/controllers/UserController.ts
# Output: 46:  @UseGuards(AuthGuard)
```

**Result:** ⚠️ Line number slightly off (46 vs 45)

**Action:**
- Update reference to line 46
- Or expand snippet to show lines 45-46
- Note: "Line number adjusted"

---

### Example 4: Non-existent File

**Claim:** "src/api/controllers/AdminController.ts example"

**Verification:**
```bash
test -f "src/api/controllers/AdminController.ts"
# Exit code: 1 (not found)

# Search for similar
find . -name "*Admin*Controller*" 2>/dev/null
# Output: src/admin/controllers/AdminController.ts
```

**Result:** ❌ File path incorrect

**Action:**
- Update path to correct location
- Or remove example if file doesn't exist
- Note: "File path corrected"

---

### Example 5: Directory Structure Claim

**Claim:** "Controllers placed in app/controllers/"

**Verification:**
```bash
test -d "app/controllers"
# Exit code: 1 (not found)

# Search for controllers directory
find . -type d -name "controllers" 2>/dev/null | head -5
# Output:
# ./src/api/controllers
# ./packages/backend/controllers
```

**Result:** ❌ Directory path incorrect

**Action:**
- Update claim: "Controllers placed in src/api/controllers/"
- Note: "Directory path corrected"

---

## Error Recovery

### If Verification Script Fails

```bash
# If file not found
# → Use find to search
find . -name "UserController*" 2>/dev/null

# If grep fails
# → File might be binary or very large
file "$filepath"

# If wc fails
# → File might not exist
test -f "$filepath" || echo "File missing"
```

### If Code Snippet Doesn't Match

**Likely causes:**
1. Line number off by a few lines
2. Code was recently refactored
3. Wrong file referenced

**Action:**
1. Re-read the entire file
2. Search for key functions/patterns
3. Extract fresh snippet with correct line numbers

---

### If Many Files Don't Exist

**Likely causes:**
1. Analyzing wrong directory
2. Patterns were from different project
3. Files were moved/deleted

**Action:**
1. Verify current directory: `pwd`
2. Check git status: `git status`
3. Re-run pattern search from Step 1
4. Only include files that currently exist

---

## Best Practices

1. **Always verify file paths** - Files may be moved/renamed
2. **Sample at least 3 code snippets** - Ensures they're from actual code
3. **Check line numbers** - Code changes, line numbers shift
4. **Verify directory structure** - Projects reorganize over time
5. **Note all corrections** - Transparency builds trust

---

## Verification Checklist

Before finalizing output, confirm:

- [ ] All file paths in "Best Examples" verified to exist
- [ ] All line number references checked (within file bounds)
- [ ] All code snippets verified against actual files
- [ ] All directory paths in "Key Conventions" verified
- [ ] File counts verified (±2 tolerance acceptable)
- [ ] No placeholder values like "[file]" or "[path]" in output

---

## Handoff to Next Steps

After verification:
- ✅ If confidence HIGH → Proceed to output
- ⚠️ If confidence MEDIUM → Include verification notes, warn user
- ❌ If confidence LOW → Re-execute entire analysis

See [reference.md#handoffs](reference.md#handoffs) for when to suggest next commands.
