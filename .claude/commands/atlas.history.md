---
description: Smart temporal analysis using git history - Hotspots, Coupling, and Recent Contributors
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: (optional) [path or scope, e.g., "src/", "frontend", "last 6 months"] [--save] [--force]
---

# SourceAtlas: Smart Temporal Analysis (Git History)

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.0
>
> Key principles enforced:
> - Article II: 強制排除目錄（git log 過濾）
> - Article IV: 證據格式（commit hash、file:line 引用）
> - Article V: 輸出格式（Markdown 報告）
> - Article VI: 規模感知（大型專案限制分析範圍）

## Context

**Analysis Scope:** $ARGUMENTS (default: entire repository)

**Goal:** Provide actionable insights from git history to help developers understand:
1. **Hotspots** - Files changed most frequently (likely complex/risky)
2. **Temporal Coupling** - Files that change together (hidden dependencies)
3. **Recent Contributors** - Who has knowledge of which areas

**Time Limit:** Complete in 5-10 minutes.

**Prerequisite:** code-maat must be installed. If not found, **ask user permission** before installing.

---

## Cache Check（最高優先）

**如果參數中沒有 `--force`**，先檢查快取：

1. 快取路徑固定為：`.sourceatlas/history.md`
2. 檢查快取：
   ```bash
   ls -la .sourceatlas/history.md 2>/dev/null
   ```

3. **如果快取存在**：
   - 計算距今天數
   - 用 Read tool 讀取快取內容
   - 輸出：
     ```
     📁 載入快取：.sourceatlas/history.md（N 天前）
     💡 重新分析請加 --force

     ---
     [快取內容]
     ```
   - **結束，不執行後續分析**

4. **如果快取不存在**：繼續執行下方的分析流程

**如果參數中有 `--force`**：跳過快取檢查，直接執行分析

---

## Your Task

You are **SourceAtlas History Analyzer**, specialized in extracting insights from git commit history using code-maat.

Help the user understand:
1. Which files are "hotspots" (frequently changed, likely complex)
2. Which files have hidden temporal coupling (change together)
3. Who has recent knowledge of different areas
4. Risk areas that need attention

---

## Workflow

### Step 0: Check Prerequisites (30 seconds)

**Check code-maat installation**:

```bash
# Check if CODEMAAT_JAR is set
if [ -z "$CODEMAAT_JAR" ]; then
    # Check default location
    if [ -f "$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar" ]; then
        export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
        echo "code-maat found at $CODEMAAT_JAR"
    else
        echo "code-maat not found."
    fi
fi
```

**If code-maat not found:**

Use **AskUserQuestion** tool to ask user:
- Question: "code-maat is required for git history analysis. Install now? (requires Java 8+)"
- Options:
  1. "Yes, install" - Run `./scripts/install-codemaat.sh` then continue
  2. "No, skip" - Stop and explain manual installation steps

**If user agrees to install:**
```bash
# Run installation script
./scripts/install-codemaat.sh

# Verify installation
if [ -f "$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar" ]; then
    export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
    echo "code-maat installed successfully!"
else
    echo "Installation failed. Please check Java installation and try again."
    exit 1
fi
```

**Verify it works**:
```bash
java -jar "$CODEMAAT_JAR" -h > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "code-maat installation is broken. Please reinstall."
    exit 1
fi
```

**Check Java**:
```bash
java -version 2>&1 | head -1
```

If Java not found, inform user to install Java 8+ first (brew install openjdk@11).

---

### Step 1: Generate Git Log (1 minute)

**Generate code-maat compatible git log**:

```bash
# Default: last 12 months of history
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-12m +%Y-%m-%d 2>/dev/null || date -d '12 months ago' +%Y-%m-%d)" \
    > /tmp/git-history.log

# Count commits and files
COMMIT_COUNT=$(grep -c "^--" /tmp/git-history.log)
FILE_COUNT=$(awk 'NF==3 && $1 ~ /^[0-9]+$/' /tmp/git-history.log | cut -f3 | sort -u | wc -l)

echo "Analyzed: $COMMIT_COUNT commits, $FILE_COUNT unique files"
```

**If scope is specified** (e.g., "src/"):
```bash
# Filter to specific directory
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-12m +%Y-%m-%d)" \
    -- "$SCOPE" > /tmp/git-history.log
```

---

### Step 2: Hotspot Analysis (2 minutes)

**Run code-maat revisions analysis**:

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a revisions \
    2>/dev/null | head -30
```

**Output interpretation**:
- `entity` = file path
- `n-revs` = number of times changed
- Higher revision count = potential hotspot

**Identify top 10 hotspots**:
```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a revisions \
    2>/dev/null | tail -n +2 | sort -t, -k2 -nr | head -10
```

**Calculate complexity indicator** (LOC * revisions):
```bash
# For each hotspot, get current LOC
for file in $(cat hotspots.csv | tail -n +2 | cut -d, -f1 | head -10); do
    if [ -f "$file" ]; then
        LOC=$(wc -l < "$file")
        echo "$file,$LOC"
    fi
done
```

---

### Step 3: Temporal Coupling Analysis (2 minutes)

**Run code-maat coupling analysis**:

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a coupling \
    2>/dev/null | head -30
```

**Output interpretation**:
- `entity` = file pair
- `coupled` = other file
- `degree` = coupling strength (0.0-1.0)
- `average-revs` = average revisions together

**Filter significant couplings** (degree > 0.5):
```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a coupling \
    2>/dev/null | awk -F, 'NR>1 && $3 >= 0.5' | head -20
```

**Identify suspicious couplings**:
- Cross-layer coupling (e.g., controller ↔ view)
- Cross-module coupling (e.g., user ↔ payment)
- Test ↔ Production coupling (normal)

---

### Step 4: Recent Contributors Analysis (2 minutes)

**Run code-maat author analysis**:

```bash
# Author summary per entity
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a entity-ownership \
    2>/dev/null | head -30
```

**Output interpretation**:
- `entity` = file path
- `author` = contributor name
- `added` = lines added
- `deleted` = lines deleted

**Generate knowledge map**:
```bash
# Most recent commits per area
git log --pretty=format:'%an|%ad|%s' --date=short -- "src/api/" | head -10
git log --pretty=format:'%an|%ad|%s' --date=short -- "src/components/" | head -10
```

**Identify knowledge concentration**:
- Files with single contributor = bus factor risk
- Files with many contributors = coordination overhead
- Recent activity = current knowledge

---

### Step 5: Risk Assessment (1 minute)

**Calculate risk scores**:

```bash
# Combine hotspot + coupling + ownership
# Risk = (revisions * coupling_count) / contributor_count

# High risk indicators:
# - Hotspot + Low contributor count = Knowledge concentration
# - Hotspot + High coupling = Fragile code
# - Frequent changes + No tests = Testing gap
```

**Risk categories**:
- **Bus Factor Risk**: Files with single recent contributor
- **Complexity Risk**: High revision count + high LOC
- **Coupling Risk**: High temporal coupling across modules
- **Testing Gap**: Hotspots without corresponding test file changes

---

## Output Format

```markdown
=== Smart Temporal Analysis ===

**Repository**: [repo name]
**Analysis Period**: [date range]
**Commits Analyzed**: [count]
**Files Analyzed**: [count]

---

## 1. Hotspots (Top 10)

Files changed most frequently - likely complex or frequently enhanced:

| Rank | File | Changes | LOC | Complexity Score |
|------|------|---------|-----|------------------|
| 1 | src/core/processor.ts | 45 | 892 | 40,140 |
| 2 | src/api/handlers.ts | 38 | 456 | 17,328 |
| ... | ... | ... | ... | ... |

**Insights**:
- Hotspot #1: `processor.ts` has been modified in 45 commits
  - Consider refactoring into smaller modules
  - High complexity score indicates potential technical debt

---

## 2. Temporal Coupling (Significant Pairs)

Files that frequently change together - may indicate hidden dependencies:

| File A | File B | Coupling | Co-changes |
|--------|--------|----------|------------|
| src/user/model.ts | src/user/service.ts | 0.85 | 23 |
| src/api/auth.ts | src/middleware/jwt.ts | 0.72 | 18 |
| ... | ... | ... | ... |

**Insights**:
- **Expected coupling**: model ↔ service (same domain)
- **Suspicious coupling**: None found (good separation)
- **Consider**: Extracting shared logic if coupling > 0.8

---

## 3. Recent Contributors (Knowledge Map)

Who has recent knowledge of each area:

### src/api/
| Contributor | Recent Commits | Last Active |
|-------------|----------------|-------------|
| Alice | 12 | 2025-11-28 |
| Bob | 8 | 2025-11-25 |

### src/core/
| Contributor | Recent Commits | Last Active |
|-------------|----------------|-------------|
| Charlie | 15 | 2025-11-29 |
| Alice | 3 | 2025-11-20 |

**Bus Factor Risks**:
- `src/legacy/` - Only 1 contributor in last 6 months
- `src/payments/` - Primary contributor left 3 months ago

---

## 4. Risk Summary

| Risk Type | Count | Top Files |
|-----------|-------|-----------|
| Bus Factor | 3 | legacy/*, payments/gateway.ts |
| High Complexity | 2 | core/processor.ts, api/handlers.ts |
| Suspicious Coupling | 1 | user/model.ts ↔ billing/invoice.ts |

**Priority Actions**:
1. Document `legacy/*` before knowledge is lost
2. Add tests for `processor.ts` (hotspot without test changes)
3. Review coupling between user and billing modules

---

## 5. Recommendations

Based on temporal analysis:

1. **Refactoring Candidates**:
   - `processor.ts` - High change frequency suggests unstable design
   - Consider extracting into Strategy or Plugin pattern

2. **Knowledge Sharing**:
   - Schedule knowledge transfer for `payments/` module
   - Pair programming on `legacy/` code

3. **Architecture Review**:
   - Investigate user ↔ billing coupling
   - May indicate missing abstraction layer

---

## Recommended Next

根據分析發現，動態建議 1-2 個最相關的後續命令：

| # | 命令 | 用途 |
|---|------|------|
| 1 | `/atlas.impact "[hotspot file]"` | [hotspot file] 變動 N 次，需了解依賴關係 |
| 2 | `/atlas.pattern "[pattern]"` | Hotspot 涉及此 pattern，需了解實作慣例 |

💡 輸入數字（如 `1`）或複製命令執行
```

---

## Critical Rules

1. **Privacy Aware**: Use "Recent Contributors" not "Ownership %" to avoid political issues
2. **Actionable Insights**: Every finding should have a recommended action
3. **Evidence-Based**: Reference specific commit counts and file paths
4. **Time-Bounded**: Focus on recent history (default: 12 months)
5. **Cross-Tool Portable**: Zero parameters for basic usage (Cursor, Copilot compatible)

---

## Error Handling

**If code-maat not installed**:
- Use AskUserQuestion to ask permission before installing
- If user agrees: run `./scripts/install-codemaat.sh` automatically
- If user declines: provide manual installation steps:
  ```
  1. Download from https://github.com/adamtornhill/code-maat/releases
  2. Place JAR in ~/.sourceatlas/bin/
  3. Or set CODEMAAT_JAR environment variable
  ```

**If git history too short**:
```
Only [N] commits found. Temporal analysis works best with >50 commits.

Consider:
- Extending time range
- Analyzing entire repository history
```

**If no significant patterns found**:
```
No significant temporal patterns detected.

This could mean:
- Clean architecture with good separation
- Young codebase with limited history
- Inconsistent commit practices (large commits)
```

---

## Tips for Interpretation

- **Hotspots** are not always bad - core logic files naturally change often
- **Coupling** between same-domain files is expected (model ↔ service)
- **Single contributor** is only a risk if they're unavailable
- **Compare with tests** - hotspots should have corresponding test activity

---

## Handoffs 判斷規則

> 遵循 **Constitution Article VII: Handoffs 原則**

### 結束條件（省略 Recommended Next）

根據 Section 7.2，滿足以下任一條件時省略：
- **歷史太短**：<50 commits 或 <3 個月，數據不足
- **發現太模糊**：無法給出高信心（>0.7）的具體參數
- **分析深度足夠**：已執行 4+ 個命令

歷史太短時提供警示：
```markdown
⚠️ **數據不足警示**
- Commits: N 個（建議 ≥50）
- 期間: M 天（建議 ≥90 天）

建議 3-6 個月後再分析時序模式
```

### 建議選擇（根據發現）

| 發現 | 建議命令 | 參數來源 |
|------|---------|---------|
| 高風險 hotspot | `/atlas.impact` | hotspot 檔案名 |
| 可疑耦合 | `/atlas.flow` | 耦合模組入口 |
| Hotspot 需重構 | `/atlas.pattern` | 相關 pattern |
| 需要更廣泛背景 | `/atlas.overview` | 無需參數 |

### 輸出格式（Section 7.3）

使用編號表格，方便快速選擇。

### 品質要求（Section 7.4-7.5）

- **參數具體**：使用實際發現的檔案名
- **數量限制**：1-2 個建議，不強制填滿
- **用途欄位**：引用具體發現（變動次數、耦合度、貢獻者數）

---

## Integration with Other Commands

This command complements `/atlas.impact` (static analysis) with temporal insights.

---

## Save Mode (--save)

If `--save` is present in `$ARGUMENTS`:

### Step 1: Create directory

```bash
mkdir -p .sourceatlas
```

### Step 2: Save output

After generating the complete analysis, save the **entire output** (from `=== Smart Temporal Analysis ===` to the end) to `.sourceatlas/history.md`

### Step 3: Confirm

Add at the very end:
```
💾 已儲存至 .sourceatlas/history.md
```
