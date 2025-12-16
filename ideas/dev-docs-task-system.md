# Dev Docs 任務文檔系統

> **來源**: [Claude Code is a Beast – Tips from 6 Months of Hardcore Use](https://dev.to/diet-code103/claude-code-is-a-beast-tips-from-6-months-of-hardcore-use-572n)
> **建立日期**: 2025-12-16
> **成熟度**: 40%

## 問題

> "Claude is like an extremely confident junior dev with extreme amnesia, losing track of what they're doing easily."

在處理大型任務時，Claude 容易：
- 偏離原始計畫
- 忘記之前的決策
- 在 context 壓縮後失去方向

## 核心解法：三文件系統

作者的 Dev Docs 系統：

```
~/git/project/dev/active/[task-name]/
├── [task-name]-plan.md      # 被接受的計劃
├── [task-name]-context.md   # 關鍵文件、決策
└── [task-name]-tasks.md     # 任務清單
```

### 流程

1. **開始大型任務時**：
   ```bash
   mkdir -p ~/git/project/dev/active/[task-name]/
   ```

2. **建立三個文件**：
   - `plan.md` - 被接受的實作計劃
   - `context.md` - 關鍵檔案路徑、決策記錄
   - `tasks.md` - 可勾選的任務清單

3. **持續更新**：
   - 完成任務立即標記
   - 記錄重要決策到 context
   - Context 不足前執行 `/update-dev-docs`

4. **繼續任務時**：
   - 檢查 `/dev/active/` 是否有進行中的任務
   - 讀取三個文件再開始
   - 更新 "Last Updated" 時間戳

## 與 SourceAtlas 的關係

### 現有機制

SourceAtlas 已有 `.sourceatlas/` 持久化：

```
.sourceatlas/
├── overview.yaml     # 專案全貌
├── patterns/         # 設計模式
├── flows/            # 流程分析
├── impact/           # 影響分析
├── deps/             # 依賴分析
└── history.md        # Git 歷史
```

### 差異

| Dev Docs System | SourceAtlas |
|-----------------|-------------|
| 任務導向 | 分析導向 |
| 短期（單一功能） | 長期（專案生命週期） |
| 追蹤實作進度 | 追蹤專案理解 |
| Plan → Context → Tasks | Overview → Patterns → Flows |

### 互補可能性

兩個系統可以**互補**：

1. **SourceAtlas** 提供專案背景理解
2. **Dev Docs** 追蹤特定任務進度

## 構想：/atlas.task 命令

```bash
# 開始新任務
/atlas.task start "implement-user-auth"

# 產出
.sourceatlas/tasks/implement-user-auth/
├── plan.md           # 從 planning mode 產生
├── context.md        # 相關檔案、決策
├── tasks.md          # 任務清單
└── session-log.md    # 會話記錄（可選）
```

### 命令設計

```markdown
/atlas.task [action] [task-name]

Actions:
- start   開始新任務，建立三文件
- status  顯示進行中的任務
- update  更新 context 和 tasks
- finish  標記任務完成，歸檔
- list    列出所有任務
```

### 與現有命令整合

```
/atlas.overview → 專案背景
    ↓
/atlas.task start "feature-x" → 任務規劃
    ↓
/atlas.pattern "相關模式" → 參考實作
    ↓
/atlas.task update → 記錄進度
    ↓
/atlas.task finish → 歸檔
```

## 疑問

- [ ] 是否需要獨立命令？或整合到現有流程？
- [ ] 任務文件應該放在 `.sourceatlas/tasks/` 還是專案根目錄？
- [ ] 如何處理跨多個 session 的長期任務？
- [ ] 是否需要自動從 planning mode 提取計畫？
- [ ] 與 TodoWrite 工具的關係？

## 替代方案

### 方案 A：獨立 /atlas.task 命令
- 優點：功能完整、語義清晰
- 缺點：增加命令數量、學習成本

### 方案 B：擴展 /atlas.init
- 在 CLAUDE.md 注入任務管理規則
- 不新增命令，依賴使用者習慣
- 優點：簡單、不增加複雜度
- 缺點：不夠結構化

### 方案 C：文檔指南
- 只提供最佳實踐文檔
- 使用者自行建立目錄結構
- 優點：零開發成本
- 缺點：一致性差

## 下一步

1. 評估使用場景頻率
2. 決定是否值得開發
3. 如果值得，設計詳細規格

## 更新日誌

- 2025-12-16: 初次記錄，來自 Reddit 文章分析
