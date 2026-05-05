---
date: 2026-05-05
session: Plan A redo spec
status: pending execution
---

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
