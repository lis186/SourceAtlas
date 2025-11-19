# Stage 1: 假設驗證與模型更新

## 你的角色

你現在要驗證 Stage 0 建立的假設，並建立更精確的專案心智模型。

## 輸入

### Stage 0 的假設
```toon
{{STAGE0_HYPOTHESIS}}
```

### 驗證掃描的檔案
```
{{VALIDATION_FILES_CONTENT}}
```

## 任務

用貝氏更新（Bayesian Update）的方式，根據新證據調整你的假設。

### 分析框架

#### 1. 假設驗證

對於 Stage 0 的每個假設，檢查：

**證實的假設：**
```
假設：[原始假設]
證據：[哪些檔案內容支持這個假設]
信心度更新：[從 X% 提升到 Y%]
新發現：[這個假設帶來什麼新理解]
```

**證偽的假設：**
```
假設：[原始假設]
反證：[哪些檔案內容反駁這個假設]
修正：[新的假設是什麼]
原因：[為什麼原始假設錯了]
```

**無法驗證的假設：**
```
假設：[原始假設]
狀態：證據不足
需要：[還需要看什麼檔案才能驗證]
```

#### 2. 模式識別

分析掃描的檔案，識別：

**程式碼模式：**
- 重複出現的結構（components pattern, service pattern, etc.）
- 命名慣例的實際使用
- 依賴注入模式
- 錯誤處理模式

**架構模式：**
- 檔案之間的依賴關係
- 資料流向（client → server, UI → API → DB）
- 關注點分離（separation of concerns）

**開發慣例：**
- 測試策略（有沒有測試？什麼類型？）
- 文件風格（JSDoc, comments, README）
- 程式碼組織原則

#### 3. 核心概念提取

識別這個專案的核心抽象：

```toon
core_concepts:
  {{CONCEPT_NAME}}:
    what: {{簡短描述}}
    why: {{為什麼這個概念存在}}
    where: {{在哪些檔案中實作}}
    how: {{如何實作的}}
    examples: [{{具體範例}}]
```

例如：
- Authentication（認證機制）
- Data fetching（資料獲取策略）
- State management（狀態管理）
- Routing（路由機制）

#### 4. 關鍵檔案識別

根據實際掃描，重新評估哪些檔案最重要：

**評分標準：**
- **被依賴程度**：有多少檔案 import 這個檔案？
- **概念中心度**：是否定義核心抽象？
- **變更頻率**：是否經常被修改？（從 git 看）
- **複雜度**：是否包含重要的商業邏輯？

## 輸出格式

```toon
# project-model.toon

metadata:
  stage: validation
  analysis_time: {{ISO_TIMESTAMP}}
  validation_files_count: {{COUNT}}
  overall_confidence: {{0.0_TO_1.0}}

validation_results:
  confirmed_hypotheses:
    - hypothesis: {{ORIGINAL_HYPOTHESIS}}
      confidence_before: {{0.0_TO_1.0}}
      confidence_after: {{0.0_TO_1.0}}
      supporting_evidence:
        - file: {{FILE_PATH}}
          excerpt: {{RELEVANT_CODE}}
          why_confirms: {{EXPLANATION}}

  rejected_hypotheses:
    - hypothesis: {{ORIGINAL_HYPOTHESIS}}
      why_rejected: {{EXPLANATION}}
      counter_evidence:
        - file: {{FILE_PATH}}
          excerpt: {{RELEVANT_CODE}}
      revised_hypothesis: {{NEW_HYPOTHESIS}}

  uncertain_hypotheses:
    - hypothesis: {{ORIGINAL_HYPOTHESIS}}
      status: insufficient_evidence
      needed_files: [{{FILE_PATHS}}]
      expected_answer: {{WHAT_WE_EXPECT_TO_FIND}}

project_model:
  # 更新的專案理解

  architecture:
    verified_pattern: {{PATTERN}}
    layers:
      - name: {{LAYER_NAME}}
        purpose: {{PURPOSE}}
        key_files: [{{FILES}}]

    data_flow:
      - from: {{SOURCE}}
        to: {{DESTINATION}}
        mechanism: {{HOW}}
        example: {{FILE_PATH}}:{{LINE_NUMBER}}

  core_concepts:
    {{CONCEPT_NAME}}:
      definition: {{WHAT_IT_IS}}
      purpose: {{WHY_IT_EXISTS}}
      implementation:
        primary: {{FILE_PATH}}
        related: [{{FILE_PATHS}}]
      pattern: {{DESIGN_PATTERN_USED}}
      example_usage: |
        {{CODE_SNIPPET}}

  conventions:
    file_organization:
      pattern: {{DESCRIPTION}}
      example:
        - {{ACTUAL_FILE_PATH}}
        - {{ACTUAL_FILE_PATH}}

    naming:
      pattern: {{REGEX_OR_DESCRIPTION}}
      examples: [{{ACTUAL_NAMES}}]

    code_style:
      - pattern: {{PATTERN}}
        prevalence: {{HIGH|MEDIUM|LOW}}
        example: {{FILE}}:{{LINE}}

  dependencies_graph:
    # 核心依賴關係
    - file: {{FILE_PATH}}
      imports: [{{FILE_PATHS}}]
      imported_by: [{{FILE_PATHS}}]
      centrality_score: {{0.0_TO_1.0}}

key_files_ranking:
  # 重新排序的重要檔案清單
  - rank: 1
    path: {{FILE_PATH}}
    importance_score: {{0.0_TO_1.0}}
    reasons:
      - {{WHY_IMPORTANT}}
    role: {{ENTRY_POINT|CORE_LOGIC|CONFIG|PATTERN_EXAMPLE}}

patterns_detected:
  architectural:
    - pattern: {{PATTERN_NAME}}
      description: {{WHAT_IT_IS}}
      locations: [{{WHERE_USED}}]
      quality: {{GOOD|ACCEPTABLE|NEEDS_IMPROVEMENT}}

  code:
    - pattern: {{PATTERN_NAME}}
      example: {{FILE}}:{{LINE_RANGE}}
      frequency: {{HIGH|MEDIUM|LOW}}

code_health_indicators:
  positive_signals:
    - signal: {{WHAT_YOU_NOTICED}}
      implication: {{WHAT_THIS_MEANS}}

  concerns:
    - concern: {{WHAT_YOU_NOTICED}}
      severity: {{HIGH|MEDIUM|LOW}}
      recommendation: {{SUGGESTION}}

surprises:
  # 與假設不符的發現
  - finding: {{UNEXPECTED_DISCOVERY}}
    expected: {{WHAT_YOU_EXPECTED}}
    actual: {{WHAT_YOU_FOUND}}
    implication: {{WHAT_THIS_CHANGES}}

missing_pieces:
  # 還沒理解的部分
  - question: {{WHAT_WE_DONT_KNOW}}
    importance: {{HIGH|MEDIUM|LOW}}
    where_to_look: [{{FILE_PATHS_TO_CHECK}}]

next_steps:
  recommended_scans:
    - priority: {{HIGH|MEDIUM|LOW}}
      files: [{{FILE_PATHS}}]
      reason: {{WHY_SCAN_THESE}}
      expected_learning: {{WHAT_WILL_WE_LEARN}}
```

## 思考品質檢查

**好的驗證分析應該：**
✓ 明確指出哪些假設被證實、哪些被證偽
✓ 提供具體的程式碼證據（檔案路徑 + 行號）
✓ 識別出核心抽象和模式
✓ 給出更精確的重要檔案排序
✓ 承認不確定性（「這個還需要驗證」）

**避免：**
✗ 只是重複 Stage 0 的假設
✗ 沒有提供程式碼證據
✗ 模糊的結論（「程式碼看起來不錯」）
✗ 忽視反例和異常

## 貝氏思考範例

```
Stage 0 假設：使用 App Router
信心度：0.7（因為看到 next.config.js）

驗證證據：
✓ 找到 app/layout.tsx（符合 App Router）
✓ 找到 app/page.tsx（符合 App Router）
✓ 沒有 pages/ 目錄（支持假設）
✗ 但找到 app/api/route.ts（這是 App Router 的 API 路由）

更新信心度：0.95
新發現：完全使用 App Router，包含 API routes

進一步推論：
→ 可能使用 Server Components
→ 檢查是否有 'use client' directives
→ 確認：是的，在 components/ 中看到
→ 結論：混合 Server + Client Components 的架構
```

現在開始驗證！記住：**用證據說話，量化信心度，承認不確定性**。
