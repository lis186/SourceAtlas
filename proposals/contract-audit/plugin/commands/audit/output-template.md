# Audit Output Template

Complete YAML format specification for behavioral contract audit output.

---

## Header Format

```markdown
SourceAtlas: Audit
-------------------------------
[module_name] | [language] | [total_contracts] contracts
```

**Example:**
```markdown
SourceAtlas: Audit
-------------------------------
NYHTTPSClient | objc | 49 contracts
```

---

## YAML Structure

Complete YAML output conforming to `contract-output.schema.yaml` 的擴展格式。
擴展欄位包括：`metadata.pipeline_config`、`feathers_analysis`（完整結構）、
`summary.by_category`、`summary.by_severity`、`summary.line_attribution`、
`summary.completeness`、`ci_rules`。

```yaml
# -- metadata（嵌套結構，與 output-template.yaml 一致）--
metadata:
  module: "[module name]"
  language: "[objc|swift|typescript|go|kotlin|python|rust|java]"
  timestamp: "[ISO 8601 timestamp]"
  version: "1.0"
  pipeline_config:
    run_id: "[YYYYMMDD-HHMMSS]"
    refactoring_intent: "[brief description of planned refactoring]"
    source_files:
      - "[path/to/file1]"
      - "[path/to/file2]"
    agents_used:
      - "auditor"
      - "blind_scout"
      - "adversary"
      - "applier"

# -- feathers_analysis（Feathers Legacy Code 分析）--
feathers_analysis:
  story: "[3-concept description]"
  lies:
    - omission: "[omission 1]"
      risk: "[why this omission is dangerous during refactoring]"
    - omission: "[omission 2]"
      risk: "[risk description]"
  scratch_refactoring:
    - operation: "[operation description]"
      reveals:
        - "[Contract ID or NEW]"
  effect_traces:
    - method: "[method signature]"
      return: "[return value chain or void]"
      mutates: "[mutated parameters or none]"
      global: "[global state changes or none]"
      depth: "[propagation depth]"

# -- contracts（合約清單）--
contracts:
  - id: "[M|L|N|S|E|C|D|P]-[NNN]"
    type: "[M|L|N|S|E|C|D|P]"
    description: "[human-readable description]"
    evidence:
      - file: "[path/to/file]"
        line: "[line or line-range]"
        snippet: "[code snippet]"
    severity: "[critical|high|medium|low]"
    scope: "[method|class|module]"
    seam_type: "[object|preprocessing|link|none]"
    pinch_point: [true|false]
    verification:
      grep_pattern: "[grep assertion pattern]"
      ast_grep_rule: "[rule filename]"
    adversary_status: "[CONFIRM|DISPUTE|ADD]"
    notes: "[optional notes]"

# -- summary（統計摘要）--
summary:
  total_contracts: [count]
  by_category:
    M: 0
    L: 0
    N: 0
    S: 0
    E: 0
    C: 0
    D: 0
    P: 0
  by_severity:
    critical: 0
    high: 0
    medium: 0
    low: 0
  confirm_ratio: 0.0
  pinch_points_count: 0
  line_attribution:
    total_lines: 0
    contract_lines: 0
    infra_lines: 0
    skip_lines: 0
    unclassified: 0
  completeness: "[COMPLETE|INCOMPLETE]"
  completeness_note: ""

# -- ci_rules（Phase B CI 驗證規則）--
ci_rules:
  grep_scripts:
    - ".sourceatlas/audit/rules/[module]/verify-contracts-[module].sh"
  ast_grep_rules:
    - ".sourceatlas/audit/rules/[module]/[id]-[slug].yml"
```

---

## Section Specifications

### Section 1: metadata（嵌套結構）

**Required Fields:**

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| metadata.module | string | "NYHTTPSClient" | Module name (without extension) |
| metadata.language | enum | "objc" | One of: objc, swift, typescript, go, kotlin, python, rust, java |
| metadata.timestamp | string | "2026-03-08T14:30:21+08:00" | ISO 8601 format |
| metadata.version | string | "1.0" | Schema version, always "1.0" |
| metadata.pipeline_config.run_id | string | "20260308-143021" | Format: YYYYMMDD-HHMMSS |
| metadata.pipeline_config.refactoring_intent | string | "Replace with Swift async/await" | Brief description |
| metadata.pipeline_config.source_files | array | ["path/to/file"] | Source files analyzed |
| metadata.pipeline_config.agents_used | array | ["auditor", ...] | Agent roles involved |

**Example:**
```yaml
metadata:
  module: "NYHTTPSClient"
  language: "objc"
  timestamp: "2026-03-08T14:30:21+08:00"
  version: "1.0"
  pipeline_config:
    run_id: "20260308-143021"
    refactoring_intent: "Replace with Swift async/await + interceptor chain"
    source_files:
      - "NYCore/Classes/Network/NYHTTPSClient.m"
      - "NYCore/Classes/Network/NYHTTPSClient.h"
    agents_used:
      - "auditor"
      - "blind_scout"
      - "adversary"
      - "applier"
```

### Section 2: feathers_analysis

Feathers Legacy Code 分析結果（F1、F2、F3）。此段落為合約清單提供上下文背景。

**Fields:**

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| story | string | "Request interceptor..." | F1 Tell the Story output |
| lies | array of {omission, risk} | see below | Omissions dangerous during refactoring |
| scratch_refactoring | array of {operation, reveals} | see below | F2 Scratch Refactoring operations |
| effect_traces | array of {method, return, mutates, global, depth} | see below | F3 Effect Propagation Tracing |

**Example:**
```yaml
feathers_analysis:
  story: "Request interceptor responsible for (1) injecting auth headers, (2) managing idempotency, (3) controlling retry logic"
  lies:
    - omission: "Thread safety: the shared request object is mutated without locks"
      risk: "Refactoring to async/await may introduce race conditions"
    - omission: "Error handling: 3 error paths silently fall through"
      risk: "New error handling may surface unexpected nil values"
  scratch_refactoring:
    - operation: "Refactor addHTTPHeaderField to immutable request builder"
      reveals:
        - "M-001"
        - "NEW"
  effect_traces:
    - method: "- (void)addHTTPHeaderField:(NSString *)field value:(NSString *)value"
      return: "void"
      mutates: "self.request (NSMutableURLRequest)"
      global: "none"
      depth: "1"
```

### Section 3: adversary_summary

Summary of the adversarial review results.

**Fields:**

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| agent | string | "codex" | Agent used for adversarial review |
| confirm_count | integer | 34 | Contracts confirmed |
| dispute_count | integer | 10 | Contracts disputed |
| add_count | integer | 5 | Contracts added by adversary |
| confirm_ratio | string | "69.4%" | Must be <=70% |

**Example:**
```yaml
adversary_summary:
  agent: "codex"
  confirm_count: 34
  dispute_count: 10
  add_count: 5
  confirm_ratio: "69.4%"
```

### Section 4: dependency_analysis

Summary of dependency graph analysis from Step 1.5.

**Example:**
```yaml
dependency_analysis:
  total_dependencies: 8
  seams:
    object: 3
    preprocessing: 1
    link: 0
    none: 4
  pinch_points_identified: 2
```

### Section 5: contracts

Contract list. Each contract must conform to the contract schema.

**Contract Structure:**

```yaml
- id: "M-001"
  type: "M"
  description: >
    addHTTPHeaderField modifies the shared NSMutableURLRequest.
    All subsequent requests inherit this modification.
    Migration must preserve header accumulation semantics.
  evidence:
    - file: "NYCore/Classes/Network/NYHTTPSClient.m"
      line: "42"
      snippet: "[self.request addValue:value forHTTPHeaderField:field];"
    - file: "NYCore/Classes/Network/NYHTTPSClient.m"
      line: "38-40"
  severity: high
  scope: class
  seam_type: object
  pinch_point: false
  verification:
    grep_pattern: "addValue.*forHTTPHeaderField"
  adversary_status: CONFIRM
```

**Contract ID Format:**

Must match `^[MLNSECDP]-[0-9]{3}$`:

| Prefix | Category | Typical Count |
|--------|----------|---------------|
| M | Mutation | 5-15 |
| L | Lifecycle | 3-10 |
| N | Notification | 2-8 |
| S | Synchronization | 2-6 |
| E | Error Handling | 3-10 |
| C | Cancellation | 1-5 |
| D | Dependency | 3-10 |
| P | Propagation | 3-8 |

**Severity Levels:**

| Level | Meaning | CI Action |
|-------|---------|-----------|
| critical | Violation causes data loss, security breach, or crash | Block PR |
| high | Violation causes functional regression | Block PR |
| medium | Violation may cause edge-case issues | Warn |
| low | Violation affects code quality, not function | Info |

**Adversary Status:**

| Status | Meaning |
|--------|---------|
| CONFIRM | Contract validated by adversarial review |
| DISPUTE | Contract challenged (see notes for reason) |
| ADD | Contract discovered during adversarial review |

### Section 6: summary

統計摘要，提供合約分析的整體視圖。

**Fields:**

| Field | Type | Notes |
|-------|------|-------|
| total_contracts | integer | 合約總數 |
| by_category | object | 按類別統計 (M/L/N/S/E/C/D/P) |
| by_severity | object | 按嚴重程度統計 (critical/high/medium/low) |
| confirm_ratio | float | CONFIRM 比率（不得超過 0.70） |
| pinch_points_count | integer | Pinch Point 合約數量 |
| line_attribution | object | 行歸因統計（total_lines, contract_lines, infra_lines, skip_lines, unclassified） |
| completeness | string | COMPLETE 或 INCOMPLETE |
| completeness_note | string | INCOMPLETE 時的說明 |

**Example:**
```yaml
summary:
  total_contracts: 49
  by_category:
    M: 12
    L: 8
    N: 5
    S: 4
    E: 6
    C: 3
    D: 7
    P: 4
  by_severity:
    critical: 5
    high: 18
    medium: 16
    low: 10
  confirm_ratio: 0.65
  pinch_points_count: 3
  line_attribution:
    total_lines: 487
    contract_lines: 312
    infra_lines: 140
    skip_lines: 35
    unclassified: 0
  completeness: "COMPLETE"
  completeness_note: ""
```

### Section 7: ci_rules

Phase B CI 驗證規則的路徑列表。

**Example:**
```yaml
ci_rules:
  grep_scripts:
    - ".sourceatlas/audit/rules/NYHTTPSClient/verify-contracts-NYHTTPSClient.sh"
  ast_grep_rules:
    - ".sourceatlas/audit/rules/NYHTTPSClient/M-001-shared-request-mutation.yml"
```

---

## Complete Example

```markdown
SourceAtlas: Audit
-------------------------------
NYHTTPSClient | objc | 49 contracts
```

```yaml
metadata:
  module: "NYHTTPSClient"
  language: "objc"
  timestamp: "2026-03-08T14:30:21+08:00"
  version: "1.0"
  pipeline_config:
    run_id: "20260308-143021"
    refactoring_intent: "Replace with Swift async/await + interceptor chain"
    source_files:
      - "NYCore/Classes/Network/NYHTTPSClient.m"
      - "NYCore/Classes/Network/NYHTTPSClient.h"
    agents_used:
      - "auditor"
      - "blind_scout"
      - "adversary"
      - "applier"

feathers_analysis:
  story: "NYHTTPSClient is a request interceptor responsible for (1) injecting auth headers, (2) managing request lifecycle with semaphore-based synchronization, (3) routing through CDN with automatic failover"
  lies:
    - omission: "Thread safety: shared NSMutableURLRequest is mutated without locks across concurrent requests"
      risk: "Refactoring to async/await may introduce race conditions if lock semantics are not preserved"
    - omission: "Error handling: 3 error paths silently fall through to success callback"
      risk: "New error handling may surface unexpected nil values at call sites"
  scratch_refactoring:
    - operation: "Refactor addHTTPHeaderField to immutable request builder"
      reveals:
        - "M-001"
        - "NEW"
    - operation: "Replace getCDNDomainSynchronously with async version"
      reveals:
        - "D-001"
        - "S-001"
  effect_traces:
    - method: "- (void)addHTTPHeaderField:(NSString *)field value:(NSString *)value"
      return: "void"
      mutates: "self.request (NSMutableURLRequest)"
      global: "none"
      depth: "1"

contracts:
  - id: "M-001"
    type: "M"
    description: >
      addHTTPHeaderField modifies the shared NSMutableURLRequest.
      All subsequent requests inherit this modification.
      Migration must preserve header accumulation semantics.
    evidence:
      - file: "NYCore/Classes/Network/NYHTTPSClient.m"
        line: "42"
        snippet: "[self.request addValue:value forHTTPHeaderField:field];"
    severity: high
    scope: class
    seam_type: object
    pinch_point: false
    verification:
      grep_pattern: "addValue.*forHTTPHeaderField"
    adversary_status: CONFIRM

  - id: "D-001"
    type: "D"
    description: >
      NYHTTPSClient hard-depends on NYCDNManager.getCDNDomainSynchronously.
      This synchronous call blocks the current thread.
      Migration requires abstracting CDN query interface via Protocol.
    evidence:
      - file: "NYCore/Classes/Network/NYHTTPSClient.m"
        line: "156"
        snippet: 'NSString *cdn = [[NYCDNManager shared] getCDNDomainSynchronously];'
    severity: critical
    scope: module
    seam_type: object
    pinch_point: true
    verification:
      grep_pattern: "getCDNDomainSynchronously"
    adversary_status: CONFIRM
    notes: "Pinch Point: 5 modules access CDN domain through this method"

  - id: "P-001"
    type: "P"
    description: >
      requestWithURL: return value is assumed non-nil by callers,
      but returns nil when URL is invalid.
      All 8 call sites lack nil checks.
    evidence:
      - file: "NYCore/Classes/Network/NYHTTPSClient.m"
        line: "78"
      - file: "NYCore/Classes/Network/NYHTTPSClient.m"
        line: "92"
    severity: high
    scope: module
    seam_type: none
    pinch_point: false
    verification:
      grep_pattern: "requestWithURL:"
    adversary_status: ADD
    notes: "Discovered by Codex adversarial review"

summary:
  total_contracts: 49
  by_category:
    M: 12
    L: 8
    N: 5
    S: 4
    E: 6
    C: 3
    D: 7
    P: 4
  by_severity:
    critical: 5
    high: 18
    medium: 16
    low: 10
  confirm_ratio: 0.65
  pinch_points_count: 3
  line_attribution:
    total_lines: 487
    contract_lines: 312
    infra_lines: 140
    skip_lines: 35
    unclassified: 0
  completeness: "COMPLETE"
  completeness_note: ""

ci_rules:
  grep_scripts:
    - ".sourceatlas/audit/rules/NYHTTPSClient/verify-contracts-NYHTTPSClient.sh"
  ast_grep_rules:
    - ".sourceatlas/audit/rules/NYHTTPSClient/M-001-shared-request-mutation.yml"
    - ".sourceatlas/audit/rules/NYHTTPSClient/D-001-cdn-sync-dependency.yml"
```

```markdown
Verified: 49 contracts, 3 pinch points, line attribution complete

-------------------------------
SourceAtlas Audit v1.0
```

---

## Recommended Next Section

**Decision Logic:** Choose ONE of these outputs, NOT both.

### Case A: End Condition (No Table)

When contracts are straightforward:
- Total contracts < 5
- No CRITICAL or HIGH severity contracts found

**Output:**
```markdown
Analysis complete -- Module has minimal implicit contracts, safe to refactor directly
```

### Case B: Suggestions (Table Output)

When additional analysis would improve refactoring safety:

**Format:**
```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:audit "RelatedModule.swift"` | Found 5 D-type contracts referencing this module |
| 2 | `/sourceatlas:flow "NYHTTPSClient.m"` | Trace request lifecycle through 3-layer architecture |

Enter a number (e.g., `1`) or copy the command to execute
```

---

## Footer Format

```markdown
-------------------------------
SourceAtlas Audit v1.0
```
