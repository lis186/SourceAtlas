# Proposal: openskills 跨平台分發

**Status**: 🟢 已驗證（POC 通過）
**Version**: 1.1
**Author**: Claude & Justin
**Created**: 2026-01-10

---

## 一句話總結

**透過 openskills 將 SourceAtlas 分發給非 Claude Code 使用者（Cursor, Gemini CLI, Aider 等）。**

---

## 背景

### 問題

SourceAtlas 目前僅支援 Claude Code：
- 綁定 `.claude/commands/` 目錄結構
- 使用 Claude Code 專用 `Skill` tool 呼叫
- 其他 AI agents（Cursor, Windsurf, Gemini CLI, Aider）無法使用

### 機會

[openskills](https://github.com/numman-ali/openskills) 是一個通用 skills 載入器：
- 實作 Anthropic SKILL.md 規範
- 支援所有 AI coding agents
- 透過 `openskills read <name>` CLI 呼叫
- 已有 npm 套件（1.3.0）

### 價值

| 對 SourceAtlas | 對生態系 |
|----------------|----------|
| 擴大使用者群 | 高品質分析 skills |
| 不需為每個 agent 重寫整合 | 展示 SKILL.md 格式價值 |
| 增加專案曝光度 | 跨 agent 協作範例 |

---

## 變更

### 策略 B：統一格式（推薦）

將現有 `.claude/commands/` 轉換為 SKILL.md 格式，讓 Claude Code 和 openskills 都能使用。

| 現況 | 改後 |
|------|------|
| `.claude/commands/atlas.overview.md` | `.claude/commands/atlas.overview/SKILL.md` |
| 單檔案，自訂格式 | 目錄 + SKILL.md，標準格式 |
| 只有 Claude Code 可用 | Claude Code + 所有 agents 可用 |

### SKILL.md 格式範例

```yaml
---
name: atlas.overview
description: Get project overview - scan <5% of files to achieve 70-80% understanding
---

# SourceAtlas: Project Overview (Stage 0 Fingerprint)

[現有 prompt 內容...]
```

---

## POC 驗證結果（2026-01-10）

### 測試環境

```
poc/
├── AGENTS.md                         # openskills sync 生成
├── .claude/skills/
│   └── atlas-overview/
│       └── SKILL.md                  # 統一格式 POC
└── openskills-test/
    └── atlas-overview/
        └── SKILL.md                  # 原始測試檔
```

### 測試結果

| 平台 | 測試項目 | 結果 |
|------|----------|------|
| **openskills** | `openskills list` | ✅ 正確識別 skill |
| **openskills** | `openskills read atlas-overview` | ✅ 完整輸出 prompt |
| **openskills** | `openskills sync` | ✅ 正確生成 AGENTS.md |
| **Gemini CLI** | 讀取 AGENTS.md + 呼叫 skill | ✅ 正常運作 |
| **Claude Code** | 識別 `.claude/skills/` 中的 skill | ✅ 正常運作 |

### 關鍵發現

1. **額外 YAML 欄位相容**
   - SKILL.md 可同時包含 `name`, `description`（openskills 必要）和 `model`, `allowed-tools`, `argument-hint`（Claude Code 專用）
   - 兩個系統都能正確解析，互不干擾

2. **統一格式可行**
   ```yaml
   ---
   name: atlas-overview
   description: Get project overview...
   model: sonnet                    # Claude Code 專用，openskills 忽略
   allowed-tools: Bash, Glob...     # Claude Code 專用，openskills 忽略
   argument-hint: "[path]"          # Claude Code 專用，openskills 忽略
   ---
   ```

3. **分發流程驗證**
   ```bash
   # 使用者安裝
   openskills install lis186/sourceatlas-skills
   openskills sync

   # 任何 agent 都可使用
   openskills read atlas-overview
   ```

### POC 結論

**策略 B（統一格式）可行**，風險已排除：
- ✅ Claude Code 支援目錄格式 SKILL.md
- ✅ 額外 frontmatter 欄位不影響解析
- ✅ openskills 能正確讀取和分發

---

## 需修改的檔案

### Phase 1: 格式轉換

6 個 commands 轉換為 SKILL.md 格式：

```
plugin/commands/
├── atlas.overview.md    →  atlas.overview/SKILL.md
├── atlas.pattern.md     →  atlas.pattern/SKILL.md
├── atlas.flow.md        →  atlas.flow/SKILL.md
├── atlas.history.md     →  atlas.history/SKILL.md
├── atlas.impact.md      →  atlas.impact/SKILL.md
└── atlas.deps.md        →  atlas.deps/SKILL.md
```

每個轉換的改動：
1. 建立目錄
2. 加入 YAML frontmatter（name, description）
3. 保留原有 prompt 內容
4. 驗證 Claude Code 仍可正常使用

### Phase 2: 分發設置

1. 在 GitHub 發布 skills repo（或使用現有 sourceatlas2）
2. 撰寫 openskills 安裝說明
3. 更新 USAGE_GUIDE.md

---

## 驗證清單

### POC 階段（已完成）

- [x] SKILL.md 格式相容性測試
- [x] openskills list/read/sync 測試
- [x] Gemini CLI 測試
- [x] Claude Code 測試

### 實作階段（待執行）

- [ ] 轉換 6 個 commands 為 SKILL.md 格式
- [ ] 驗證 Claude Code `/atlas.*` 命令仍正常
- [ ] 建立 GitHub skills repo 或分支
- [ ] 撰寫安裝文檔

---

## 不做的事

| 功能 | 原因 |
|------|------|
| 維護兩份 prompts | 增加維護負擔，策略 B 已解決 |
| 建立獨立 skills repo | 先驗證可行性，成功後再考慮 |
| 修改 openskills 原始碼 | 不需要，現有功能已足夠 |
| 支援舊版 Claude Code | SKILL.md 格式已被支援 |

---

## 風險評估

| 風險 | 機率 | 影響 | 狀態 |
|------|------|------|------|
| Claude Code 不支援目錄格式 | ~~低~~ | ~~高~~ | ✅ POC 已排除 |
| YAML frontmatter 影響 prompt 品質 | ~~低~~ | ~~中~~ | ✅ POC 已排除 |
| openskills 格式不相容 | ~~低~~ | ~~中~~ | ✅ POC 已排除 |

**所有技術風險已透過 POC 驗證排除。**

---

## 驗收標準

- [ ] 6 個命令轉換為 SKILL.md 格式
- [ ] Claude Code 使用者無感知變化
- [ ] openskills 使用者可成功安裝和使用
- [ ] USAGE_GUIDE.md 更新安裝說明
- [ ] README 增加「支援平台」區段

---

## 相關資源

- [openskills GitHub](https://github.com/numman-ali/openskills)
- [openskills 分析](../../test_targets/openskills/) - Stage 0 overview 已完成
- [Anthropic Skills 規範](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
