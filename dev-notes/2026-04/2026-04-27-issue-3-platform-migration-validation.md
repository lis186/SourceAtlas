---
date: 2026-04-27
session: refactor #3 T5 platform-migration validation
status: closed (10/10 静态評估)
---

# Issue #3: T5 platform-migration walkthrough — closed at doc level

## 結論

文件層面驗收 **10/10 通過**。完整 E2E 驗證需 LLM 走過 platform-migration 自動偵測 → S2 strangler plan generation → S3 skip → S4 spike → S5 → S6+ wiring，~30 分鐘 LLM session 不划算。

## 評分依據

| 維度 | 滿分 | 評分 | 證據 |
|------|-----|------|------|
| A. mode confirmation 提示 | 2 | 2 | init-state.sh:155-159 對非 seam-injection auto 設 `confirmed=false`；summary 印「Mode requires user confirmation」 |
| B. mode-dispatch.yaml 完整性 | 3 | 3 | 8 step × 4 mode；platform-migration S3=skip、S2=replaced 完全符合 T5 預期 |
| C. 2b-alt strangler plan | 2 | 2 | workflow.md §2b-alt（line 451+）+ S_strangler_plan.yaml 產出邏輯 |
| D. gate-platform-migration.sh | 1 | 1 | legacy_removed / target_implemented / no_double_dispatch 三項實裝 |
| E. platform-slot-map.yaml | 1 | 1 | UIKit scenes 對映齊全 + iOS 12 fallback note |
| F. Steps 8-13 platform-migration 表格 | 1 | 1 | references/steps-8-13-by-mode.md 含 platform-migration + platform-strangler 完整表 |

## T5 預期 vs 實裝對應

| T5 預期 | 實裝 |
|---------|------|
| S1 mode 確認提示 | ✅ init-state.sh 自動偵測 `platform_id: ios_uikit_scenes` → `confirmed: false` → user 看到 prompt |
| S3 被 skip | ✅ mode-dispatch.yaml `S3_seams.platform-migration.dispatch: skip` |
| S2 後產出 S_strangler_plan.yaml | ✅ workflow.md §2b-alt 產出邏輯；platform-slot-map.yaml 自動填 to_slot |

## 延伸發現（非 #3 範疇）

#16/#25-class 鏡像在 dispatch enforcement：

- LLM 看到 mode-dispatch.yaml 說 S3 = skip，理論上應 `state.sh set-status --step 3_seams --status skipped --skip-reason "..."` → 然後 advance。
- 但 state.sh advance 沒檢查「dispatch=skip 的 step 應該是 skipped status，不是 produced/verified」。
- LLM 可能照樣跑 Step 3（atlas.seam）然後標 produced，dispatch 規則被繞過。

修法方向（候選 #27）：
- state.sh advance 在推進前讀 mode-dispatch.yaml，比對 prev_step 的 dispatch 與實際 status：
  - dispatch=skip 但 status≠skipped → 拒絕並提示應 mark skipped
  - dispatch=replaced 但無 replacement_script 紀錄 → 拒絕

不在 #3 範圍。記為 #27 候選。

## 重新評估剩餘問題

| # | 問題 | 嚴重度 |
|---|------|------|
| **27 (新)** | dispatch enforcement 在 state.sh advance | 🟡 中 |
| 8 | paired-header 範圍 | 🟢 低 |
| 5 | gate-strangler.sh yq 依賴 | 🟢 低 |
| 6 | IPHONEOS multi-target | 🟢 低 |
| 4 | GitButler workaround | 🟢 低 |
| 7 | Shadow logging infra docs | 🟢 低 |
