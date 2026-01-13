# Impact Analysis Reference

Advanced features and behaviors reference.

---

## Cache Behavior

### Cache Check (Highest Priority)

**If `--force` is not in arguments**, check cache first:

1. Extract target name from `$ARGUMENTS` (remove `--force`)
2. Convert to filename: spaces → `-`, slashes → `-`, lowercase, remove `{}`, **truncate to 50 characters**
   - Example: `"User model"` → `user-model.md`
   - Example: `"api /api/users/{id}"` → `api-users-id.md`
3. Check cache:
   ```bash
   ls -la .sourceatlas/impact/{name}.md 2>/dev/null
   ```

4. **If cache exists**:
   - Calculate days since creation
   - Read cache content using Read tool
   - Output:
     ```
     📁 Loading from cache: .sourceatlas/impact/{name}.md (N days ago)
     💡 Use --force to reanalyze --force
     ```
   - **If over 30 days**, additionally display:
     ```
     ⚠️ Cache is over 30 days old, recommend reanalysis
     ```
   - Then output:
     ```
     ---
     [Cache content]
     ```
   - **End, do not execute subsequent analysis**

5. **If cache does not exist**: Continue with analysis below

**If arguments contain `--force`**: Skip cache check, run analysis directly

---

## Auto-Save (Default Behavior)

After analysis completes, automatically:

### Step 1: Parse target name

Extract target name from arguments (remove `--force`):
- `"User model"` → target name is `user-model`
- `"api /api/users/{id}"` → target name is `api-users-id`

Convert to filename:
- Spaces → `-`
- Slashes → `-`
- Remove `{`, `}`, special characters
- Lowercase
- Example: `"User model"` → `user-model.md`

### Step 2: Create directory

```bash
mkdir -p .sourceatlas/impact
```

### Step 3: Save output

After generating the complete analysis, save the **entire output** (from `🗺️ SourceAtlas: Impact` to the end) to `.sourceatlas/impact/{name}.md`

### Step 4: Confirm

Add at the very end:
```
💾 Saved to .sourceatlas/impact/{name}.md
```

---

## Handoffs (Recommended Next)

> Follows **Constitution Article VII: Handoffs Principles**

Add at the end of output:

```markdown
---

## Recommended Next

| # | Command | Purpose |
|---|------|------|
| 1 | `/sourceatlas:flow "[entry point]"` | Impact chain involves N-layer calls, need to trace complete flow |
| 2 | `/sourceatlas:history "[directory]"` | This area changes frequently, need to understand historical patterns |

💡 Enter number (e.g., `1`) or copy command to execute

───────────────────────────────
🗺️ v2.11.0 │ Constitution v1.1
```

### End Conditions vs Recommendations (choose one, mutually exclusive)

**⚠️ Important: The following two outputs are mutually exclusive, choose only one**

**Situation A - End (omit Recommended Next)**:
When any of the following conditions are met, **only output end message, do not output table**:
- Impact scope is small: <5 dependencies, no further analysis needed
- Findings too vague: Cannot provide with high confidence (>0.7) specific parameters
- Analysis depth sufficient: Already executed 4+ commands

Output:
```markdown
✅ **Impact analysis complete** - Can start modifications following the Migration Checklist
```

**Situation B - Recommend (output Recommended Next table)**:
When impact scope is large or there are clear risks, **only output table, do not output end message**.

### Recommendation Selection (applies to Situation B)

| Finding | Recommended Command | Parameter Source |
|------|---------|---------|
| Involves specific pattern | `/sourceatlas:pattern` | pattern name |
| Complex impact chain | `/sourceatlas:flow` | entry point file |
| Need to understand change history | `/sourceatlas:history` | related directory |
| Need broader context | `/sourceatlas:overview` | no parameters needed |

### Output Format

Use numbered table for quick selection.

### Quality Requirements

- **Specific parameters**: Use actual found file names or entry point
- **Quantity limit**: 1-2 recommendations, not required to fill all
- **Purpose column**: Reference specific findings (dependency count, risk level, issues)

---

## Best Practices

### For Accurate Analysis

1. **Use precise grep patterns**: Match import statements, not comments
2. **Follow the call chain**: From definition → usage → components
3. **Check test files separately**: Different directory structure
4. **Consider indirect dependencies**: Hooks/Services wrapping the target

### Language-Specific Search Patterns

**TypeScript/JavaScript**:
```bash
# Imports
grep -r "import { UserService } from\|import UserService from" --include="*.ts"

# Usage
grep -r "UserService\.\|new UserService(" --include="*.ts"
```

**Ruby**:
```bash
# Requires
grep -r "require.*user\|require_relative.*user" --include="*.rb"

# Usage
grep -r "User\.create\|User\.find\|User\.where" --include="*.rb"
```

**Go**:
```bash
# Imports
grep -r 'import.*".*user"' --include="*.go"

# Usage
grep -r "user\.\|User{" --include="*.go"
```

**Python**:
```bash
# Imports
grep -r "from.*user import\|import user" --include="*.py"

# Usage
grep -r "User(\|user\." --include="*.py"
```

---

## Deprecated Features

### --save flag

If `--save` is in arguments:
- Show: `⚠️ --save is deprecated, auto-save is now default`
- Remove `--save` from arguments
- Continue normal execution (still auto-saves)

---

## Tips for Complex Projects

### Large Codebases (>100 dependencies)

When facing too many results:
1. Sample top 20-30 most relevant
2. Group by category (controllers, services, components)
3. Provide statistical summary instead of full list
4. Warn about incomplete analysis

Example:
```
📊 **Impact Summary** (sampled from 156 total dependencies):
- Controllers: 23 files
- Services: 45 files
- Components: 88 files

⚠️ Showing top 20 high-priority dependencies. Run with specific filters for complete analysis.
```

### Monorepos

Specify scope to avoid false positives:
```bash
# Instead of searching entire repo
grep -r "UserService" .

# Search specific packages
grep -r "UserService" packages/backend/ packages/api/
```

### False Positive Reduction

Exclude common noise:
```bash
grep -r "UserService" . \
  | grep -v "node_modules" \
  | grep -v ".git" \
  | grep -v "coverage" \
  | grep -v "build" \
  | grep -v "dist"
```
