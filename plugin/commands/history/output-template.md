# History Analysis Output Template

Complete Markdown format specification for temporal analysis reports.

---

## Header Format

```markdown
🗺️ SourceAtlas: History
───────────────────────────────
📜 [repo name] │ [N] months

**Analysis Period**: [start date] → [end date]
**Commits Analyzed**: [count]
**Files Analyzed**: [count]
```

---

## Section 1: Hotspots (Top 10)

Files changed most frequently - likely complex or frequently enhanced.

```markdown
## 1. Hotspots (Top 10)

Files changed most frequently - likely complex or frequently enhanced:

| Rank | File | Changes | LOC | Complexity Score |
|------|------|---------|-----|------------------|
| 1 | src/core/processor.ts | 45 | 892 | 40,140 |
| 2 | src/api/handlers.ts | 38 | 456 | 17,328 |
| 3 | config/settings.json | 32 | 123 | 3,936 |
| 4 | src/models/user.ts | 28 | 345 | 9,660 |
| 5 | src/utils/helpers.ts | 25 | 234 | 5,850 |
| 6 | src/middleware/auth.ts | 23 | 189 | 4,347 |
| 7 | tests/integration.spec.ts | 21 | 567 | 11,907 |
| 8 | src/routes/index.ts | 19 | 156 | 2,964 |
| 9 | src/services/payment.ts | 18 | 423 | 7,614 |
| 10 | package.json | 17 | 78 | 1,326 |

**Insights**:
- **Hotspot #1**: `processor.ts` has been modified in 45 commits
  - Complexity score of 40,140 indicates significant technical debt
  - Consider refactoring into smaller modules (Strategy pattern)
  - Review recent changes for code duplication

- **Hotspot #2**: `handlers.ts` frequently updated (38 commits)
  - API endpoint additions/modifications
  - Ensure adequate test coverage for new endpoints

- **Configuration hotspot**: `settings.json` (32 commits)
  - Normal for configuration files
  - Consider environment-specific configs to reduce churn

- **Test file in hotspots**: `integration.spec.ts` (21 commits)
  - Good sign - tests updated with production code
  - Complexity score indicates comprehensive test suite
```

---

## Section 2: Temporal Coupling (Significant Pairs)

Files that frequently change together - may indicate hidden dependencies.

```markdown
## 2. Temporal Coupling (Significant Pairs)

Files that frequently change together - may indicate hidden dependencies:

| File A | File B | Coupling | Co-changes |
|--------|--------|----------|------------|
| src/user/model.ts | src/user/service.ts | 0.85 | 23 |
| src/api/auth.ts | src/middleware/jwt.ts | 0.72 | 18 |
| src/routes/user.ts | src/controllers/user.ts | 0.68 | 15 |
| src/core/processor.ts | src/core/validator.ts | 0.63 | 12 |
| src/models/order.ts | src/services/payment.ts | 0.58 | 10 |
| config/database.json | src/db/connection.ts | 0.55 | 9 |

**Insights**:

### Expected Coupling ✅
- **user/model.ts ↔ user/service.ts** (0.85, 23 co-changes)
  - Same domain, expected coupling
  - Model changes naturally require service updates

- **auth.ts ↔ jwt.ts** (0.72, 18 co-changes)
  - Authentication flow dependencies
  - Normal for security-related code

- **routes ↔ controllers** (0.68, 15 co-changes)
  - MVC pattern, expected behavior

### Suspicious Coupling ⚠️
- **order.ts ↔ payment.ts** (0.58, 10 co-changes)
  - Cross-module coupling (orders → payments)
  - **Review**: Consider event-driven decoupling
  - May indicate missing abstraction layer

### Recommendations
1. **High coupling (>0.8)**: Consider merging files if always changed together
2. **Cross-module coupling**: Review for architectural improvements
3. **Config ↔ Code coupling**: Normal, ensure version control best practices
```

---

## Section 3: Recent Contributors (Knowledge Map)

Who has recent knowledge of each area.

```markdown
## 3. Recent Contributors (Knowledge Map)

Who has recent knowledge of each area:

### src/api/
| Contributor | Recent Commits | Last Active |
|-------------|----------------|-------------|
| Alice | 12 | 2025-11-28 |
| Bob | 8 | 2025-11-25 |
| Charlie | 3 | 2025-11-15 |

**Coverage**: 3 contributors, good knowledge distribution

---

### src/core/
| Contributor | Recent Commits | Last Active |
|-------------|----------------|-------------|
| Charlie | 15 | 2025-11-29 |
| Alice | 3 | 2025-11-20 |

**Coverage**: 2 contributors, Charlie is primary maintainer

---

### src/legacy/
| Contributor | Recent Commits | Last Active |
|-------------|----------------|-------------|
| David | 2 | 2025-05-10 |

**⚠️ Bus Factor Risk**: Only 1 contributor in last 6 months, no recent activity

---

### src/payments/
| Contributor | Recent Commits | Last Active |
|-------------|----------------|-------------|
| Eve | 5 | 2025-08-15 |

**⚠️ Knowledge Gap**: Primary contributor last active 3 months ago

---

### Bus Factor Risks

| Area | Risk Level | Contributors | Last Activity | Recommendation |
|------|------------|--------------|---------------|----------------|
| src/legacy/* | 🔴 HIGH | 1 | 6 months ago | Document immediately, pair programming |
| src/payments/ | 🟡 MEDIUM | 1 | 3 months ago | Knowledge transfer, cross-training |
| src/core/ | 🟢 LOW | 2 | Recent | Maintain current distribution |
```

---

## Section 4: Risk Summary

Aggregate risk assessment across all dimensions.

```markdown
## 4. Risk Summary

| Risk Type | Count | Top Files | Severity |
|-----------|-------|-----------|----------|
| Bus Factor | 3 | legacy/*, payments/gateway.ts, utils/deprecated.ts | 🔴 HIGH |
| High Complexity | 2 | core/processor.ts, api/handlers.ts | 🟡 MEDIUM |
| Suspicious Coupling | 1 | orders/model.ts ↔ payments/service.ts | 🟡 MEDIUM |
| Testing Gap | 1 | core/processor.ts (no corresponding test changes) | 🟡 MEDIUM |

---

### Priority Actions

1. **URGENT - Document Legacy Code** 🔴
   - `src/legacy/*` - Single contributor, 6 months inactive
   - Action: Schedule knowledge transfer session this week
   - Pair junior dev with Charlie to review legacy patterns

2. **HIGH - Add Tests for Hotspots** 🟡
   - `core/processor.ts` - 45 changes but no test file activity
   - Action: Add unit tests, aim for 80% coverage
   - Review recent changes for edge cases

3. **MEDIUM - Review Cross-Module Coupling** 🟡
   - `orders/model.ts ↔ payments/service.ts` coupling (0.58)
   - Action: Investigate if event-driven architecture is appropriate
   - Consider introducing domain events for decoupling

4. **MEDIUM - Knowledge Transfer for Payments** 🟡
   - Primary contributor Eve last active 3 months ago
   - Action: Cross-train another developer on payment flows
   - Document critical payment integration logic

---

### Risk Metrics

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Files with single contributor | 8 | <5 | ⚠️ Above threshold |
| Average contributors per module | 2.3 | >2 | ✅ Acceptable |
| Hotspots without tests | 1 | 0 | ⚠️ Needs attention |
| Suspicious couplings | 1 | <2 | ✅ Acceptable |
```

---

## Section 5: Recommendations

Actionable recommendations based on temporal patterns.

```markdown
## 5. Recommendations

Based on temporal analysis:

### 1. Refactoring Candidates

**processor.ts** (Hotspot #1)
- **Problem**: 45 changes in 12 months, complexity score 40,140
- **Indicator**: High change frequency suggests unstable design
- **Recommendation**:
  - Extract into Strategy or Plugin pattern
  - Separate concerns: validation, transformation, persistence
  - Target: Reduce file LOC from 892 → <500 per module

**handlers.ts** (Hotspot #2)
- **Problem**: 38 changes, grows with each new API endpoint
- **Recommendation**:
  - Consider breaking into feature-specific handler modules
  - Use route grouping by domain (users/, orders/, payments/)

---

### 2. Knowledge Sharing

**Schedule Knowledge Transfer Sessions**:
- `src/legacy/*` - Pair David (if available) with 2 developers
- `src/payments/` - Document Eve's integration patterns
- `src/core/` - Charlie to share processor.ts refactoring plan

**Cross-Training Matrix**:
| Module | Primary | Backup | Learning |
|--------|---------|--------|----------|
| api/ | Alice | Bob | Charlie |
| core/ | Charlie | Alice | Bob |
| payments/ | Eve | (needed) | (assign) |
| legacy/ | David | (needed) | (assign) |

---

### 3. Architecture Review

**Investigate Cross-Module Coupling**:
- **orders ↔ payments** (0.58 coupling)
  - Current: Direct service calls
  - Consider: Event-driven architecture
  - Benefit: Reduce coupling, improve scalability
  - Trade-off: Increased complexity, eventual consistency

**Review Testing Strategy**:
- Hotspots should have proportional test activity
- `processor.ts`: 45 production changes, 0 test file changes
- Action: Implement test coverage before next refactor

---

### 4. Process Improvements

**Commit Practices**:
- Large, infrequent commits may hide coupling patterns
- Consider: Smaller, atomic commits with clear messages
- Benefit: Better coupling detection, easier rollback

**Code Review Focus**:
- Flag changes to identified hotspots (processor.ts, handlers.ts)
- Extra scrutiny for cross-module coupling
- Require tests for hotspot modifications
```

---

## Section 6: Recommended Next

Dynamic suggestions based on findings.

```markdown
## Recommended Next

Based on analysis findings, dynamically suggest 1-2 most relevant follow-up commands:

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:impact "src/core/processor.ts"` | processor.ts changed 45 times, need to understand dependencies |
| 2 | `/sourceatlas:pattern "strategy pattern"` | Hotspot involves complex processing, need to understand implementation conventions |

💡 Enter a number (e.g., `1`) or copy the command to execute
```

**Rules**:
- Only show if there are clear findings (hotspots, coupling, risks)
- Use actual discovered file names, not placeholders
- Limit to 1-2 most actionable recommendations
- Reference specific metrics in Purpose (change count, coupling degree)

---

## Footer Format

```markdown
───────────────────────────────
🗺️ v2.12.0 │ Constitution v1.1

💾 Saved to .sourceatlas/history.md
```

---

## Example: Complete Output

```markdown
🗺️ SourceAtlas: History
───────────────────────────────
📜 sourceatlas2 │ 12 months

**Analysis Period**: 2024-11-30 → 2025-11-30
**Commits Analyzed**: 487
**Files Analyzed**: 234

---

## 1. Hotspots (Top 10)

[... full hotspots table ...]

**Insights**:
[... specific insights ...]

---

## 2. Temporal Coupling (Significant Pairs)

[... full coupling table ...]

**Insights**:
[... expected vs suspicious ...]

---

## 3. Recent Contributors (Knowledge Map)

[... knowledge map by area ...]

**Bus Factor Risks**:
[... specific risks ...]

---

## 4. Risk Summary

[... risk aggregation ...]

**Priority Actions**:
[... numbered action items ...]

---

## 5. Recommendations

[... detailed recommendations ...]

---

## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:impact "src/core/processor.ts"` | processor.ts changed 45 times, need to understand dependencies |

💡 Enter a number (e.g., `1`) or copy the command to execute

───────────────────────────────
🗺️ v2.12.0 │ Constitution v1.1

✅ Verified: 10 hotspot files, 5 contributors, commit counts

💾 Saved to .sourceatlas/history.md
```

---

## Field Descriptions

### Hotspots Table

- **Rank**: 1-10, sorted by revision count descending
- **File**: Relative path from repository root
- **Changes**: Number of commits touching this file
- **LOC**: Current lines of code (use `wc -l`)
- **Complexity Score**: LOC × Changes (higher = more risk)

### Coupling Table

- **File A, File B**: The coupled file pair
- **Coupling**: Degree 0.0-1.0 (percentage they change together)
- **Co-changes**: Number of commits where both files changed

### Contributors Table

- **Contributor**: Git author name (use `git shortlog`)
- **Recent Commits**: Commits in analysis period
- **Last Active**: Date of most recent commit (YYYY-MM-DD)

### Risk Summary

- **Risk Type**: Bus Factor / High Complexity / Suspicious Coupling / Testing Gap
- **Count**: Number of instances
- **Top Files**: Most critical examples
- **Severity**: 🔴 HIGH / 🟡 MEDIUM / 🟢 LOW
