# 2026-03-09: Rename /atlas.clear → /atlas.reset

## 問題背景

`/atlas.clear` 與 Claude Code 內建指令 `/clear` 命名衝突。
`/clear` 是 Claude Code 用於清除對話歷史的內建指令，導致用戶混淆。

## 解決方案

將所有 `/atlas.clear` 改名為 `/atlas.reset`。

## 修改的檔案（13 個）

| 檔案 | 變更 |
|------|------|
| `.claude/commands/atlas.list.md` | 更新指令參照 |
| `.claude/commands/atlas.clear.md` → `atlas.reset.md` | 重新命名 |
| `CLAUDE.md` | 更新指令表 |
| `README.md` | 更新文件 |
| `README.zh-TW.md` | 更新文件 |
| `USAGE_GUIDE.md` | 更新指令參照 |
| `USAGE_GUIDE.zh-TW.md` | 更新指令參照 |
| `plugin/commands/list/SKILL.md` | 更新指令參照 |
| `plugin/commands/clear/SKILL.md` → `reset/SKILL.md` | 重新命名 |
| `proposals/README.md` | 更新文件 |
| `proposals/atlas-list-expiry/README.md` | 更新文件 |
| `proposals/atlas-refresh/README.md` | 更新文件 |
| `proposals/persistence/README.md` | 更新文件 |

## 版本

v2.13.0 → v2.13.1 (PATCH)
