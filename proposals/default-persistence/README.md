# Proposal: 默認存儲

**Status**: ⚫ 已完成
**Version**: 2.0 (簡化版)
**Author**: Claude & Justin
**Created**: 2026-01-02
**Based on**: [persistence proposal](../persistence/README.md) (v2.9.1)

---

## 一句話總結

**移除 `--save`，改為默認存儲。**

---

## 背景

來自 MCP vs Skills 社群討論的洞見：

> Skills 的核心優勢是「硬碟暫存」- 結果存硬碟，不佔用 context

目前 SourceAtlas 的 `--save` 是 opt-in，違反這個理念。

---

## 變更

| 現況 | 改後 |
|-----|------|
| `/atlas.overview` 不存 | `/atlas.overview` 自動存 |
| `/atlas.overview --save` 存 | 移除 `--save` |
| 無 | `/atlas.overview --force` 跳過 cache |

就這樣。

---

## 需修改的檔案

6 個 command prompts：

```
plugin/commands/
├── overview.md
├── pattern.md
├── flow.md
├── history.md
├── impact.md
└── deps.md
```

每個檔案的改動：
1. 移除 `argument-hint` 中的 `[--save]`
2. 將 `## Save Mode (--save)` 改為 `## 自動存儲（默認行為）`
3. 移除條件判斷，直接存

---

## 不做的事

| 功能 | 原因 |
|------|------|
| git status 檢查 | 沒人抱怨過 |
| metadata 記錄 | `/atlas.list` 已有時間戳 |
| manifest.json | 過度工程化 |
| dependencies.yaml | prompt 裡寫就好 |
| 自動錯誤降級 | LLM 會自己處理 |

等用戶反饋再說。

---

## 驗收標準

- [x] 6 個命令默認存儲
- [x] `--save` 參數顯示棄用警告
- [x] `--force` 維持不變
- [x] 文檔更新 (CLAUDE.md, USAGE_GUIDE.md)

---

## 相關資源

- [MCP vs Skills 分析](../../ideas/mcp-vs-skills-analysis.md)
- [persistence proposal](../persistence/README.md)
