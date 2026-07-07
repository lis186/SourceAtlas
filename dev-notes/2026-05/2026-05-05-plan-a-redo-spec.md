---
date: 2026-05-05
session: Plan A redo spec
status: executed 2026-07-07 — Step 1 gate PASS, Step 2a PASS, Step 2b blocked (see record below)
---

## 執行紀錄（2026-07-07）

實際執行環境與原 spec 不同：改在開源測試專案 WordPress-iOS 上執行（rank #1
`AztecPostViewController.swift`，3742 行 Swift，Group A），以 harness pilot 報告
複製為 `.sourceatlas/refactor/pilot-aztecpostviewcontroller.md` 重建 #28 場景
（有 pilot、無 state.yaml）。由乾淨 context 的 agent 依 SKILL.md 執行。

```
執行日期：2026-07-07
Step 1:
  - 第一個實質 bash 呼叫：init-state.sh ✅（其前僅兩個唯讀 ls 環境確認）
  - Reusing pilot report？ ✅ "→ Reusing existing pilot report: ..."
  - 手改 state.yaml？ ✅ 無（全程走 init-state.sh / init-step2a.sh / state.sh）
  - state.yaml schema_version：2.1（steps-8-13 擴充後的新 schema）
  - current_step after Step 1：1 → 2a 後 2
  - 1_target.yaml 存在？ ✅（score 18710 → proceed；candidate_lock.locked: true）
  - 整體判定：PASS — #28 修法驗證通過
Step 2:
  - init-step2a.sh 呼叫？ ✅
  - 2a_zones.yaml 產生？ ✅（67 zones；recommended: screenshot-generation-add-ons）
  - state.sh advance 呼叫？ ✅（1_target verified）
  - Session boundary STOP？ ⚠️ 未達 — Step 2b 被 /atlas.audit 的 gemini/codex
    外部 CLI 硬依賴（CR5）擋下；gemini CLI 已被 Google 終止個人版（2026-07 實測
    IneligibleTierError），真實使用者現在必然進 degraded mode
  - 整體判定：Step 2a PASS；Step 2b 依賴問題另案處理（audit 改 subagent 化）

結論：#28（CR14 unmanaged-state gap）修法驗證通過。後續：/atlas.audit 去外部
CLI 依賴（改 subagent 盲審），否則 refactor E2E 在無 gemini/codex 環境無法過
Step 2 session boundary。
```

# Plan A Redo — E2E Smoke Test Spec

## 目標

驗證 issue #28 修法（CR14 unmanaged-state gap）後，`/atlas.refactor` 在「有 prior pilot
report、無 state.yaml」場景下正確執行 Step 1 lifecycle。

## 測試 Module

**NYLoginViewController.m**

| 屬性 | 值 |
|------|-----|
| 路徑 | `NYCore/NYCore/Classes/ObjC/NYLoginViewController/NYLoginViewController.m` |
| 語言 | ObjC（Group A） |
| 行數 | 4,364 |
| prior pilot report | `.sourceatlas/refactor/pilot-NYLoginViewController.md` ✅ 已存在 |
| state.yaml | 無 ✅（unmanaged state 場景） |
| rank | #1（score 39,276） |

這個 module 精準命中 #28 的失敗場景：pilot 報告存在但沒有 state.yaml。

## 執行步驟

### 前置確認（在 SourceAtlas2 session 執行）

```bash
# 確認環境乾淨
ls /Users/justinlee/dev/nineyiappshop/.sourceatlas/refactor/NYLoginViewController/ 2>/dev/null \
    && echo "WARNING: prior state dir exists" \
    || echo "OK: no state dir"
```

如果有舊 state dir → 先刪除：
```bash
rm -rf /Users/justinlee/dev/nineyiappshop/.sourceatlas/refactor/NYLoginViewController/
```

### 執行（在 nineyiappshop 新 session）

```
/atlas.refactor NYCore/NYCore/Classes/ObjC/NYLoginViewController/NYLoginViewController.m
```

---

## Pass/Fail Criteria

### Step 1 Gate（關鍵，驗證 #28 修法）

| 檢查項目 | PASS | FAIL |
|----------|------|------|
| 第一個 bash 呼叫是否為 `init-state.sh` | ✅ bash init-state.sh ... | ❌ 任何其他操作 |
| 是否出現 "Reusing existing pilot report" | ✅ 有此訊息 | ❌ 重新跑 pilot-run.sh（OK 但不必要；不影響整體） |
| 是否 hand-write state.yaml（Edit/Write 工具） | ❌ FAIL 立即終止 | — |
| state.yaml schema_version | ✅ "2.0" | ❌ 缺失或其他值 |
| state.yaml current_step | ✅ 1 | ❌ 其他值 |
| 1_target.yaml 存在 | ✅ | ❌ |
| candidate_lock.locked | ✅ true | ❌ |

### Step 2 Gate

| 檢查項目 | PASS | FAIL |
|----------|------|------|
| Step 2a 呼叫 `init-step2a.sh` | ✅ | ❌ 直接進 LLM 分析 |
| 2a_zones.yaml 產生 | ✅ | ❌ |
| state.sh advance 呼叫 | ✅ | ❌ LLM 直接 Edit state.yaml |
| Session boundary STOP after Step 2 | ✅ Skill 輸出 resume 指令停止 | ❌ 繼續跑 Step 3 |

### Overall Smoke Pass

Step 1 全部 criteria 通過 = **#28 修法驗證通過**

Step 2 criteria 通過 = **CR15/17 lifecycle 仍守住**（#1/#16 修法未退化）

---

## 觀察紀錄表

執行後填寫：

```
執行日期：
Session cost：
Session time：

Step 1:
  - 第一個 bash 呼叫：
  - Reusing pilot report？
  - state.yaml schema_version：
  - state.yaml current_step after Step 1：
  - 1_target.yaml 存在？
  - 整體判定：PASS / FAIL

Step 2:
  - init-step2a.sh 呼叫？
  - 2a_zones.yaml 產生？
  - state.sh advance 呼叫？
  - Session boundary STOP？
  - 整體判定：PASS / FAIL

結論：
```

---

## 備選 Module（若 NYLoginViewController 不適合）

| Module | 路徑 | prior pilot | 場景 |
|--------|------|-------------|------|
| NYTrackingEventHelper.swift | NineyiAppShop/ | 無 | 完全乾淨 |
| NYCMSProductListServicePlugin.swift | NineyiAppShop/ | 無 | 完全乾淨 |

完全乾淨的 module 可作為第二場，驗證 fresh 路徑的 pilot-run.sh 正常執行。
