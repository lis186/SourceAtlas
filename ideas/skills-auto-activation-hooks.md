# Skills Auto-Activation Hooks

> **來源**: [Claude Code is a Beast – Tips from 6 Months of Hardcore Use](https://dev.to/diet-code103/claude-code-is-a-beast-tips-from-6-months-of-hardcore-use-572n)
> **建立日期**: 2025-12-16
> **成熟度**: 30%

## 問題

SourceAtlas 的 `/atlas.init` 將自動觸發規則注入 CLAUDE.md，但這是**被動式**的——依賴 Claude 自己去讀取和遵循。

原文作者遇到相同問題：
> "Claude just wouldn't use them. I'd literally use the exact keywords from the skill descriptions. Nothing."

## 核心洞察

作者使用 **Hooks 系統** 強制 Claude 在每個 prompt 前檢查並載入相關 Skills：

### 1. UserPromptSubmit Hook（prompt 前執行）

- 分析 prompt 的關鍵字和意圖模式
- 檢查哪些 skills 可能相關
- **主動注入** 格式化提醒到 Claude 的 context

```
🎯 SKILL ACTIVATION CHECK - Use project-catalog-developer skill
```

### 2. Stop Event Hook（回應後執行）

- 分析哪些檔案被編輯
- 檢查高風險模式（try-catch、資料庫操作、async）
- 顯示溫和的自我檢查提醒

### 3. skill-rules.json 配置

```json
{
  "backend-dev-guidelines": {
    "type": "domain",
    "enforcement": "suggest",
    "priority": "high",
    "promptTriggers": {
      "keywords": ["backend", "controller", "service", "API", "endpoint"],
      "intentPatterns": [
        "(create|add).*?(route|endpoint|controller)",
        "(how to|best practice).*?(backend|API)"
      ]
    },
    "fileTriggers": {
      "pathPatterns": ["backend/src/**/*.ts"],
      "contentPatterns": ["router\\.", "export.*Controller"]
    }
  }
}
```

## SourceAtlas 應用構想

### 方案 A：為 SourceAtlas 開發專屬 Hook

```javascript
// hooks/sourceatlas-auto-activate.js
module.exports = {
  event: 'UserPromptSubmit',
  handler: async (prompt) => {
    // 檢測關鍵字
    const keywords = ['專案', 'codebase', '架構', '分析', 'pattern', 'flow'];
    const hasKeyword = keywords.some(k => prompt.includes(k));

    // 檢查 .sourceatlas/ 是否存在
    const hasCache = fs.existsSync('.sourceatlas/');

    if (hasKeyword && hasCache) {
      return {
        inject: `🎯 SOURCEATLAS CONTEXT AVAILABLE
檢測到專案層級問題，建議先讀取 .sourceatlas/ 快取：
- overview.yaml: 專案全貌
- patterns/: 設計模式
- flows/: 流程分析`
      };
    }
  }
};
```

### 方案 B：擴展現有 /atlas.init

在 `/atlas.init` 注入的規則中，加入更強制的觸發條件：

```markdown
## SourceAtlas 自動觸發（MANDATORY）

當使用者問題包含以下關鍵字時，**必須**先執行：
1. 「專案」「codebase」「架構」→ 讀取 `.sourceatlas/overview.yaml`
2. 「pattern」「模式」→ 讀取 `.sourceatlas/patterns/`
3. 「流程」「flow」→ 讀取 `.sourceatlas/flows/`

**執行順序**：
1. 檢查 `.sourceatlas/` 是否存在
2. 如存在，載入相關快取
3. 基於快取回答問題
4. 如快取不存在或過期，建議執行相應 `/atlas.*` 命令
```

## 疑問

- [ ] Claude Code 的 Hooks API 是否穩定？
- [ ] Hook 執行會增加多少延遲？
- [ ] 是否有 token 成本考量？（system-reminder 問題）
- [ ] 如何處理 Hook 與現有 CLAUDE.md 規則的衝突？

## 潛在風險

原文提到的警告：

> "After publishing, a reader shared detailed data showing that file modifications trigger `<system-reminder>` notifications that can consume significant context tokens. In their case, Prettier formatting led to 160k tokens consumed in just 3 rounds."

需要評估 Hook 注入的 token 成本。

## 下一步

1. 研究 Claude Code Hooks API 文檔
2. 建立最小可行 Hook 原型
3. 測量 token 消耗
4. 評估是否升級到 proposals/

## 更新日誌

- 2025-12-16: 初次記錄，來自 Reddit 文章分析
