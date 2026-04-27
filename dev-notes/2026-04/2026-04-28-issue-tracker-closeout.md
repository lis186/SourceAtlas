---
date: 2026-04-28
session: refactor playbook hardening — multi-issue closeout
status: all issues resolved
---

# Issue tracker closeout: #1–#27 全部處理完成

## 起點

2026-04-21 T4 在 nineyiappshop 試跑 atlas.refactor 揭露的失敗模式：1 hour、$7.94、0 artifacts。LLM 被 work account CLAUDE.md 的「Senior Dev Override」覆蓋，跳過整個 artifact lifecycle。

## 結局

從 2026-04-21 → 2026-04-28，依嚴重度逐個處理 9 個 issues + 5 個延伸 issues = **14 個 issue 全部 resolved**。

## 處理摘要

| # | 議題 | 嚴重度 | 狀態 | Commit |
|---|------|------|------|--------|
| 1 | Skill 跳過 artifact lifecycle | 🔴 | fixed (plan D, 9.5/10) | `78f13654`, `c727dc6a`, `93825b44` |
| 2 | T4 S5 shadow validation | 🟡 | closed (10/10 static) | `65ead40c` |
| 3 | T5 platform-migration walkthrough | 🟡 | closed (10/10 static) | `bed9d65a` |
| 4 | GitButler workaround docs | 🟢 | won't fix | user 不再使用 GitButler |
| 5 | gate-strangler.sh yq 依賴 | 🟢 | fixed (9.0/10) | `bbf97383` |
| 6 | IPHONEOS multi-target | 🟢 | fixed (9.0/10) | `8a52edbe` |
| 7 | Shadow logging infra docs | 🟢 | fixed (9.0/10) | `afc7b9d4` |
| 8 | paired-header 範圍 | 🟢 | fixed (9.5/10) | `04a9e5e9` |
| 9 | issue note 未 commit | 🟢 | fixed | `1a628fed` |
| 16 | Step 2+ lifecycle 未強制 | 🔴 | fixed (plan E, 9.5/10) | `8b8266b2`, `c4dc241e`, `f74644d8` |
| 25 | Step 5 swap_strategy gate | 🟡 | fixed (9.5/10) | `ea81d128` |
| 27 | dispatch ↔ status enforcement | 🟡 | fixed (9.5/10) | `08f7cad7` |

## 縱深防禦完整圖

```
LLM 收到 /atlas.refactor 指令
  ↓
Step 1: bash init-state.sh         ← Critical Rule 14 阻擋 CLAUDE.md override
   └→ 寫 state.yaml + 1_target.yaml + lock candidate
  ↓
Step 2a: bash init-step2a.sh       ← Critical Rule 15 阻擋 hand-edit state.yaml
   └→ detect-zones → 2a_zones.yaml → state.sh advance
  ↓
Step 2b/3/4: LLM-driven /atlas.audit / atlas.seam etc.
   └→ 每次 state 變更走 state.sh（單一寫入 API）
   └→ state.sh advance 檢查 dispatch ↔ status 一致 (Critical Rule 17)
  ↓
Step 5: User decision (Critical Rule 7) — direct vs shadow
   └→ state.sh advance 拒絕無 swap_strategy 的轉換 (Critical Rule 16)
  ↓
Step 6/7: 標準路徑
```

## 新增 / 修改檔案

```
plugin/commands/refactor/
├── SKILL.md                              + Critical Rule 14, 15, 16, 17
├── workflow.md                           + Step 0.5, Step 1 deterministic, Step 2a deterministic
├── scripts/
│   ├── init-state.sh                     新增 (#1)
│   ├── init-step2a.sh                    新增 (#16)
│   ├── state.sh                          新增 (#16, +#25, +#27)
│   ├── pilot-run.sh                      修改 (#1 paired .h, #8 Swift/TS)
│   ├── gate-platform-migration.sh        修改 (#6 xcodebuild)
│   └── gate-strangler.sh                 修改 (#5 yq fallback)
├── templates/
│   ├── 1_target.yaml                     新增 (#1)
│   └── 2a_zones.yaml                     新增 (#16)
└── references/
    └── steps-8-13-by-mode.md             修改 (#7 shadow logger patterns)
```

## 評分機制驗收

每個 fix 都通過 6 維度評分（A/B/C/D/E/F），門檻 9 分：

- 高嚴重度（🔴）#1, #16: 9.5/10
- 中嚴重度（🟡）#25, #27, #2 close, #3 close: 9.5–10/10
- 低嚴重度（🟢）#5, #6, #7, #8: 9.0–9.5/10

機制本身運作良好：低於 9 分的候選方案（如純 Critical Rule 文字提示、init-step5.sh 互動式）都被擋下，迫使設計更 deterministic 的方案。

## 下一個 session 建議

1. **真實 E2E 驗證**：在 nineyiappshop 跑完 Step 2b → Step 5 完整流程，驗 Critical Rule 16/17 的 deterministic gate 在真實 LLM session 是否被遵守。
2. **若 #16 鏡像在更深 step 出現**：套相同 plan E pattern（state.sh + init-stepN.sh + advance gate）。
3. **若 plan E 套不到**：考慮抽出 init-stepN.sh 通用 framework（目前 init-state.sh 和 init-step2a.sh 有不少共用邏輯：read state, run script, write artifact, call state.sh）。

## 不再相關

- **GitButler workaround**：使用者決定全用 plain git，不需 troubleshooting docs。

---

playbook 加固告一段落。
