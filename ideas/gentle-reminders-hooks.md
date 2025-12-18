# Gentle Reminders Hooks（溫和提醒機制）

> **來源**: [Claude Code is a Beast – Tips from 6 Months of Hardcore Use](https://dev.to/diet-code103/claude-code-is-a-beast-tips-from-6-months-of-hardcore-use-572n)
> **建立日期**: 2025-12-16
> **成熟度**: 30%

## 問題

Claude 完成任務後，可能遺漏：
- 錯誤處理
- 測試覆蓋
- 文檔更新
- 模式一致性

## 核心概念：非阻塞式提醒

作者的 Error Handling Reminder Hook：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 ERROR HANDLING SELF-CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  Backend Changes Detected
   2 file(s) edited

   ❓ Did you add Sentry.captureException() in catch blocks?
   ❓ Are Prisma operations wrapped in error handling?

   💡 Backend Best Practice:
      - All errors should be captured to Sentry
      - Controllers should extend BaseController
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 關鍵特性

1. **非阻塞** - 只是提醒，不強制停止
2. **上下文感知** - 根據編輯的檔案類型顯示相關提醒
3. **自我評估** - Claude 自己判斷是否需要採取行動
4. **模式檢測** - 識別高風險程式碼模式

## 與 SourceAtlas 的關係

### 現有機制

SourceAtlas 的 **Handoffs 原則**（Constitution Article VII）已有類似概念：

> "發現驅動的動態下一步建議"

但 Handoffs 是在**分析結束時**提供建議，而 Gentle Reminders 是在**每次回應後**提醒。

### 應用場景

#### 場景 1：分析完成後的自我檢查

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 SOURCEATLAS ANALYSIS SELF-CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ /atlas.overview 完成

   ❓ 假設是否都有證據支持？
   ❓ 信心分數是否合理？
   ❓ 是否遺漏重要目錄？

   💡 建議下一步：
      - 驗證高影響假設
      - 執行 /atlas.pattern 深入分析
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 場景 2：程式碼修改後的提醒

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 CODE CHANGE SELF-CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  Swift 檔案修改偵測
   3 file(s) edited in iOS project

   ❓ 是否遵循 Repository Pattern？
   ❓ 是否有對應的單元測試？
   ❓ 是否更新了相關文檔？

   💡 參考：
      - .sourceatlas/patterns/repository.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 實作構想

### Hook 設計

```javascript
// hooks/sourceatlas-gentle-reminder.js
module.exports = {
  event: 'Stop',
  handler: async (context) => {
    const editedFiles = context.editedFiles || [];
    const reminders = [];

    // 檢測 SourceAtlas 分析
    if (context.lastCommand?.startsWith('/atlas.')) {
      reminders.push({
        type: 'analysis',
        message: '是否所有假設都有證據支持？'
      });
    }

    // 檢測程式碼修改
    if (editedFiles.some(f => f.endsWith('.swift'))) {
      reminders.push({
        type: 'ios',
        message: '是否遵循專案的 iOS patterns？'
      });
    }

    if (reminders.length > 0) {
      return formatReminder(reminders);
    }
  }
};
```

### 與 Handoffs 整合

可以將 Gentle Reminders 視為 **Micro-Handoffs**：

| Handoffs | Gentle Reminders |
|----------|------------------|
| 分析結束時 | 每次回應後 |
| 建議下一個命令 | 自我檢查清單 |
| 基於發現 | 基於動作 |
| 明確方向 | 品質提醒 |

## 疑問

- [ ] 頻繁提醒是否會造成干擾？
- [ ] 如何避免 token 成本過高？
- [ ] 是否需要使用者可配置的開關？
- [ ] 與現有 Handoffs 如何協調？

## 潛在風險

原文警告：

> "File modifications trigger `<system-reminder>` notifications that can consume significant context tokens."

需要評估：
1. 提醒訊息的 token 成本
2. 是否每次都需要顯示
3. 是否可以合併多個提醒

## 替代方案

### 方案 A：Hook 實作
- 每次回應後自動顯示
- 需要開發 Hook
- Token 成本考量

### 方案 B：擴展 Handoffs
- 在現有 Handoffs 中加入自我檢查項目
- 不需要新機制
- 但只在分析結束時觸發

### 方案 C：CLAUDE.md 規則
- 在 CLAUDE.md 中寫明自我檢查規則
- 依賴 Claude 自覺遵守
- 零開發成本但不可靠

## 下一步

1. 評估 token 成本
2. 決定是否值得實作
3. 如果實作，先從 Handoffs 擴展開始

## 更新日誌

- 2025-12-16: 初次記錄，來自 Reddit 文章分析
