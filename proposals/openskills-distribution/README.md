# Proposal: openskills 跨平台分發

**Status**: ✅ 已完成
**Version**: 1.2
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

## 已完成的變更

### Phase 1: 格式轉換（已完成）

8 個 commands 轉換為 SKILL.md 目錄格式：

```
plugin/commands/
├── overview/SKILL.md     (555 lines)
├── pattern/SKILL.md      (604 lines)
├── flow/SKILL.md         (249 lines)
├── history/SKILL.md      (631 lines)
├── impact/SKILL.md       (912 lines)
├── deps/SKILL.md         (737 lines)
├── list/SKILL.md         (103 lines)
└── clear/SKILL.md        (108 lines)
```

每個轉換的改動：
1. ✅ 建立 `{name}/` 目錄
2. ✅ 加入 `name:` 欄位到 YAML frontmatter
3. ✅ 更新相對路徑（Constitution 引用）
4. ✅ 驗證 Claude Code `/sourceatlas:{name}` 命令正常

### Phase 2: 分發設置（已完成）

1. ✅ 驗證 `openskills install ./commands -y` 成功安裝 8 個 skills
2. ✅ 驗證 `openskills read overview` 正確輸出 prompt
3. ✅ 更新 plugin/README.md 新增 OpenSkills 安裝方法

---

## 驗證清單

### POC 階段（已完成）

- [x] SKILL.md 格式相容性測試
- [x] openskills list/read/sync 測試
- [x] Gemini CLI 測試
- [x] Claude Code 測試

### 實作階段（已完成）

- [x] 轉換 8 個 commands 為 SKILL.md 格式（2026-01-10）
- [x] 驗證 Claude Code `/sourceatlas:*` 命令仍正常
- [x] openskills install/list/read 驗證通過
- [x] 更新 plugin/README.md 安裝文檔

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

- [x] 8 個命令轉換為 SKILL.md 格式
- [x] Claude Code 使用者無感知變化（`/sourceatlas:overview` 正常運作）
- [x] openskills 使用者可成功安裝和使用
- [x] plugin/README.md 更新安裝說明
- [x] 新增 OpenSkills 安裝方法（Method 2）

---

## 相關資源

- [openskills GitHub](https://github.com/numman-ali/openskills)
- [openskills 分析](../../test_targets/openskills/) - Stage 0 overview 已完成
- [Anthropic Skills 規範](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
