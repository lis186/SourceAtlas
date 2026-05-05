---
date: 2026-05-05
session: issue #28 — Critical Rule 14 prior-artifact fix
status: resolved (9.5/10)
---

# Issue #28 — CR14：prior artifacts without state.yaml 場景修法

## 問題

`/atlas.refactor` 對有 prior artifacts（pilot report、test files）但無 `state.yaml` 的 module 執行時，
Skill 推斷「Step 1 已完成」，跳過 `init-state.sh`，自己 hand-write 不相容 schema 的 state.yaml，
直接跳到 Step 3。（2026-04-28 Plan A smoke run，$1.52，0 valid artifacts）

## 根本原因

`workflow.md` State Management 段的偽代碼：

```bash
if [ ! -f "$STATE_FILE" ]; then
    mkdir -p "$STATE_DIR"
    # Copy from templates/state.yaml and fill in values  ← 授權 LLM 自己寫
fi
```

LLM 照做了。Critical Rule 14 的文字層強制對抗不了程式碼層的指示。

## 修法（三層，9.5/10）

### Layer 1 — workflow.md State Management 代碼層修正

把偽代碼替換為明確的 UNMANAGED STATE 說明 + 直接設 `CURRENT_STEP=1`：

```bash
# state.yaml absent → UNMANAGED STATE. Prior artifacts on disk without state.yaml
# do NOT indicate Step 1 was completed.
# DO NOT create or write state.yaml here. Step 1 (init-state.sh) is the sole creator.
if [ ! -f "$STATE_FILE" ]; then
    CURRENT_STEP=1
else
    CURRENT_STEP=$(grep '^current_step:' "$STATE_FILE" | awk '{print $2}')
fi
```

也補了 Schema Version Check 的 guard 說明（僅 state.yaml 存在時才執行）。

### Layer 2 — init-state.sh prior-artifact reuse

當 `pilot-{module}.md` 已存在且未加 `--force` 時，skip `pilot-run.sh` 直接重用報告。
消除 LLM「init-state.sh 是浪費（重新跑 pilot）」的理由：

```bash
if [[ -f "$pilot_report" && "$FORCE" -ne 1 ]]; then
    echo "→ Reusing existing pilot report: $pilot_report" >&2
else
    echo "→ Running pilot-run.sh..." >&2
    bash "$SCRIPT_DIR/pilot-run.sh" "$PROJECT_ROOT" "$TARGET" >&2 || true
fi
```

### Layer 3 — Critical Rule 14 語意強化

在 CR14 末尾加：

> Prior artifacts on disk (pilot-{module}.md, test files, commit references, etc.)
> WITHOUT a `state.yaml` are **UNMANAGED STATE** — they do not prove Step 1 was
> completed via init-state.sh. Call `init-state.sh` regardless; when a pilot report
> already exists and `--force` is not set, the script reuses it automatically
> without re-running analysis.

## 修改檔案

| 檔案 | 修改 |
|------|------|
| `plugin/commands/refactor/workflow.md` | State Management 偽代碼 → 明確 UNMANAGED STATE + CURRENT_STEP=1；Schema Version Check 加 guard 說明 |
| `plugin/commands/refactor/scripts/init-state.sh` | pilot-run.sh 呼叫加 reuse guard |
| `plugin/commands/refactor/SKILL.md` | Critical Rule 14 末尾加 unmanaged state 定義 |

## 評分

- Layer 1（代碼層）：解決根本原因，分數最重
- Layer 2（script 層）：消除 LLM 跳過的「理由」
- Layer 3（文字層）：補強語意，配合前兩層

綜合：**9.5/10**（剩餘 0.5 是對抗 LLM 完全無視 workflow.md 的極端情形，無法在此層解決）

## 下一步

重做 Plan A — 以乾淨無 artifact 的 module 做 E2E smoke，驗證 Step 1–7 lifecycle 完整。
