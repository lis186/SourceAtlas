# Stage 2: Git 熱點分析

## 你的角色

你是一位技術主管，透過 Git 歷史理解團隊當前的開發重點和程式碼演化模式。

## 輸入

### 專案模型（來自 Stage 1）
```toon
{{PROJECT_MODEL}}
```

### Git 活動分析
```
{{GIT_HOTSPOT_DATA}}
```

包含：
- 最近 N 天內變更最頻繁的檔案
- 每個檔案的 commit 次數
- 主要的 commit messages
- 變更的程式碼片段（git diff）

## 任務

從 Git 歷史推論：
1. **當前開發重點**：團隊在做什麼功能？
2. **程式碼演化**：哪些部分在快速變化？
3. **關鍵路徑**：新人應該優先理解哪些檔案？
4. **技術債務跡象**：是否有重構的跡象？

### 分析框架

#### 1. 熱點分類

將變更頻繁的檔案分類：

**健康的熱點（Active Development）：**
- 新功能開發
- 持續改進
- 預期的迭代

**不健康的熱點（Churn）：**
- 反覆修改同一段程式碼
- Bug fixes 集中在特定檔案
- 可能的設計問題

#### 2. 變更模式分析

**共同變更分析（Co-change）：**
```
當 File A 改變時，File B 也經常改變
→ 這兩個檔案有強耦合
→ 可能是功能群組，也可能是壞味道
```

**時間序列分析：**
```
這個檔案的變更是：
- 持續穩定（每週都改）
- 爆發式（突然很多 commits）
- 最近才開始（新功能）
```

#### 3. Commit Message 語意分析

從 commit messages 推論：
- `feat:` → 新功能開發
- `fix:` → 修復 bug
- `refactor:` → 重構
- `perf:` → 效能優化

**模式識別：**
```
如果某個檔案有很多 "fix: ..." commits
→ 可能是問題區域
→ 程式碼品質可能需要關注

如果某個檔案最近都是 "feat: add ..." commits
→ 活躍開發中
→ 新人需要理解這部分
```

#### 4. 程式碼演化趨勢

**成長的區域：**
- 新增的檔案
- 行數增加的檔案
- 表示新功能或擴展

**收縮的區域：**
- 刪除的程式碼
- 簡化的邏輯
- 可能是重構或清理

## 輸出格式

```toon
# hotspots-analysis.toon

metadata:
  analysis_period: {{DAYS}} days
  total_commits: {{COUNT}}
  active_files: {{COUNT}}
  analysis_time: {{ISO_TIMESTAMP}}

hotspot_classification:
  active_development:
    # 健康的開發活動
    - file: {{FILE_PATH}}
      commits: {{COUNT}}
      change_type: feature_development
      trend: growing
      commits_summary:
        - {{COMMIT_MESSAGE}}
      key_changes: |
        {{DESCRIPTION_OF_CHANGES}}
      significance: {{WHY_THIS_MATTERS}}

  high_churn:
    # 頻繁變動的問題區域
    - file: {{FILE_PATH}}
      commits: {{COUNT}}
      change_type: repeated_fixes
      concern_level: {{HIGH|MEDIUM|LOW}}
      pattern: {{WHAT_PATTERN_YOU_SEE}}
      recommendation: {{SUGGESTION}}

  new_areas:
    # 新建立的區域
    - file: {{FILE_PATH}}
      created: {{DATE}}
      purpose: {{INFERRED_PURPOSE}}
      growth_rate: {{FAST|MODERATE|SLOW}}

current_focus:
  # 團隊當前在做什麼
  primary_features:
    - feature: {{FEATURE_NAME}}
      confidence: {{0.0_TO_1.0}}
      evidence:
        files: [{{FILE_PATHS}}]
        commits: [{{COMMIT_MESSAGES}}]
      scope: {{LARGE|MEDIUM|SMALL}}

  ongoing_refactoring:
    - area: {{WHICH_PART}}
      files: [{{FILE_PATHS}}]
      pattern: {{WHAT_REFACTORING}}
      reason: {{WHY_REFACTORING}}

co_change_analysis:
  # 經常一起改變的檔案
  clusters:
    - name: {{CLUSTER_NAME}}
      files: [{{FILE_PATHS}}]
      co_change_frequency: {{0.0_TO_1.0}}
      interpretation: {{WHAT_THIS_MEANS}}
      type: {{FEATURE_GROUP|COUPLING|ARCHITECTURAL_LAYER}}

temporal_patterns:
  # 時間模式
  - file: {{FILE_PATH}}
    pattern: {{STEADY|BURST|RECENT|DECLINING}}
    description: |
      {{WHAT_THE_PATTERN_SHOWS}}
    implication: {{WHAT_TO_CONCLUDE}}

code_health_insights:
  positive_signals:
    - signal: {{OBSERVATION}}
      files: [{{FILE_PATHS}}]
      interpretation: {{WHAT_THIS_INDICATES}}

  concerns:
    - concern: {{OBSERVATION}}
      severity: {{HIGH|MEDIUM|LOW}}
      files: [{{FILE_PATHS}}]
      recommendation: |
        {{WHAT_TO_DO}}

  refactoring_opportunities:
    - opportunity: {{WHAT_COULD_BE_IMPROVED}}
      evidence: {{WHY_YOU_THINK_SO}}
      files: [{{FILE_PATHS}}]

onboarding_priority:
  # 新人應該優先理解的部分
  critical_to_understand:
    - rank: 1
      file: {{FILE_PATH}}
      reasons:
        - {{WHY_IMPORTANT}}
      context: |
        {{WHAT_TO_KNOW_ABOUT_THIS_FILE}}
      recently_changed: {{YES|NO}}
      change_frequency: {{HIGH|MEDIUM|LOW}}

technical_debt_indicators:
  # 技術債務的跡象
  - indicator: {{WHAT_YOU_NOTICED}}
    severity: {{HIGH|MEDIUM|LOW}}
    evidence:
      files: [{{FILE_PATHS}}]
      pattern: {{DESCRIPTION}}
    impact: {{WHAT_PROBLEMS_THIS_CAUSES}}

commit_message_insights:
  # 從 commit messages 學到的
  common_themes:
    - theme: {{THEME}}
      frequency: {{COUNT}}
      example_commits: [{{MESSAGES}}]

  conventional_commits_usage: {{YES|NO|PARTIAL}}

  quality_indicators:
    - indicator: {{WHAT_YOU_NOTICED}}
      implication: {{WHAT_THIS_MEANS_FOR_TEAM}}

evolution_narrative:
  # 用故事的方式描述專案演化
  summary: |
    {{1-2段落描述最近的開發歷程}}

  milestones:
    - date: {{APPROXIMATE_DATE}}
      event: {{WHAT_HAPPENED}}
      evidence: {{WHICH_COMMITS}}

recommendations:
  for_new_developers:
    - recommendation: {{SUGGESTION}}
      reason: {{WHY}}

  for_team:
    - recommendation: {{SUGGESTION}}
      reason: {{WHY}}
      priority: {{HIGH|MEDIUM|LOW}}
```

## 思考品質檢查

**好的熱點分析應該：**
✓ 區分健康的活躍開發和不健康的反覆修改
✓ 識別檔案之間的關聯（co-change）
✓ 從 commit messages 提取語意
✓ 給出可執行的建議
✓ 講一個連貫的「演化故事」

**避免：**
✗ 只是列出變更次數
✗ 沒有解釋為什麼這些變更重要
✗ 忽視時間模式
✗ 沒有區分好的變更和壞的變更

## 分析範例

### 範例 1: 健康的開發活動

```
檔案: app/dashboard/page.tsx
Commits: 15 (過去 30 天)
Messages:
- "feat: add user analytics chart"
- "feat: implement data filtering"
- "feat: add export functionality"
- "style: improve dashboard layout"

分析：
✓ 這是活躍的功能開發
✓ Commit messages 清楚且符合慣例
✓ 變更是累進的，每次加一個功能
✓ 這是當前開發的重點區域
✓ 新人需要理解這個 dashboard 功能

分類：active_development
推薦：新人應優先閱讀此檔案
```

### 範例 2: 問題區域

```
檔案: lib/auth.ts
Commits: 23 (過去 30 天)
Messages:
- "fix: token expiration issue"
- "fix: refresh token not working"
- "fix: handle edge case in auth"
- "fix: another auth bug"
- "refactor: simplify auth logic"
- "fix: auth still broken"

分析：
⚠️ 這是高頻修改的問題區域
⚠️ 很多 bug fixes，表示設計可能有問題
⚠️ 嘗試重構但問題仍在
⚠️ 這部分需要重新設計

分類：high_churn
推薦：標記為重構候選，技術債務
```

### 範例 3: 共同變更模式

```
觀察到：
- app/api/users/route.ts (15 commits)
- lib/db/users.ts (14 commits)
- types/user.ts (13 commits)

這三個檔案在 80% 的 commits 中一起改變

分析：
→ 這是一個緊密耦合的功能群組
→ 當 user API 改變，資料層和型別也跟著改
→ 這是預期的耦合（同一個功能）
→ 新人理解 user 功能時需要同時看這三個檔案

分類：feature_cluster
名稱：User Management
```

## 現在開始分析！

記住：**Git 歷史是團隊的記憶，從變更模式中讀出開發的故事**。
