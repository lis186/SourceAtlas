---
date: 2026-04-27
session: refactor plan E validation
status: passed
---

# Plan E Validation: Step 2 lifecycle 縱深防禦生效

## TL;DR

✅ 修法完全成功。在 nineyiappshop work account 跑 fresh `/atlas.refactor NYMemberHelper.m`：
- Step 1 走 `init-state.sh`（Critical Rule 14）
- Step 2a 走 `init-step2a.sh`（Critical Rule 15 + 對稱化）
- state.yaml 全程透過 `state.sh` 寫入，**沒有 LLM hand-edit**

state.yaml 最終狀態：
```yaml
current_step: 2
zone_id: "private"
1_target.status: verified         # auto-promoted by state.sh advance
2a_zones.status: produced
```

## 對照 #16 失敗模式

| 階段 | 修法前（4-26） | 修法後（4-27） |
|------|---------------|---------------|
| Step 1 入口 | init-state.sh ✅ | init-state.sh ✅ |
| Step 2a 入口 | LLM Edit state.yaml 設 zone_id ❌ | init-step2a.sh ✅ |
| zone_id 來源 | LLM 推論「formatting」 | 從 pilot report `recommended_zone` 自動帶入「private」 |
| current_step 變更 | LLM 直接 Edit | state.sh advance（檢查前置） |
| 1_target 升 verified | 沒發生 | state.sh advance 自動升 |
| 2a_zones artifact | 沒寫 | 寫了 |

## 三個元件分工

```
LLM 看到 SKILL.md Critical Rule 15
  → 不敢直接 Edit state.yaml
  → 跑 init-step2a.sh （workflow.md Step 2a 的 Do）
       └→ 內部跑 detect-zones.sh
       └→ 寫 2a_zones.yaml
       └→ 透過 state.sh set-status / set-zone / advance
              └→ awk 重寫 state.yaml（單一寫入點）
              └→ 前置條件檢查（1_target.status 必須 produced/verified）
```

縱深防禦：即使 LLM 想繞過 init-step2a.sh，state.sh 也會擋下無效轉換。

## #16 修法分數驗收

原本評估方案 E 的 9.5/10 是否成立？

| 維度 | 評分 | 實測驗證 |
|------|-----|---------|
| A. Deterministic | 3/3 | ✅ 實測 LLM 跑 init-step2a.sh 沒繞過 |
| B. CLAUDE.md 兼容 | 2/2 | ✅ work account 有 CLAUDE.md（含 Senior Dev Override），Step 2 不再被影響 |
| C. 改動成本 | 1.5/2 | ✅ 5 檔案，符合預估 |
| D. 既有 user 衝擊 | 1/1 | ✅ schema_version: "2.0" 已 cover |
| E. 可驗證性 | 1/1 | ✅ 4 個 deterministic 條件全可機器驗證（current_step / zone_id / 1_target.status / 2a_zones.status） |
| F. 文檔自洽 | 1/1 | ✅ workflow.md Step 2a + SKILL.md Rule 15 + mode-dispatch.yaml 不動 = 一致 |

**實測 9.5/10 成立。**

## 重新評估剩餘問題

| # | 問題 | 嚴重度 |
|---|------|------|
| 2 | T4 S5 shadow validation | 🟡 中（仍待，Step 2b 後 reach S5）|
| 3 | T5 platform-migration walkthrough | 🟡 中 |
| 8 | paired-header 範圍（Swift/Java/TS） | 🟢 低 |
| 4 | GitButler workaround | 🟢 低 |
| 5 | gate-strangler.sh yq 依賴 | 🟢 低 |
| 6 | IPHONEOS multi-target | 🟢 低 |
| 7 | Shadow logging infra docs | 🟢 低 |

新延伸 issue（待規劃）：
- Step 2b/3/4/5/6/7 沒有對應的 init-stepN.sh，但 state.sh 提供了縱深防禦。
  目前 LLM 在 Step 2b 會自由決定（讀 atlas.audit/SKILL.md），尚未觀察到 hand-edit state.yaml。
  視 Step 2b 後續行為決定是否需要進一步加固。

下一個高優先 = #2 T4 S5 shadow validation（需要走完 Step 2b/3/4 才能 reach S5）。
