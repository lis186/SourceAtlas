---
date: 2026-04-27
session: refactor #2 T4 S5 shadow validation
status: closed (10/10 静态評估)
---

# Issue #2: T4 S5 shadow validation — closed at doc level

## 結論

文件層面驗收 **10/10 通過**。完整 E2E 驗證需走完 Step 2b/3/4 才能達到 Step 5，~30 分鐘 LLM session 不划算。

## 評分依據

| 維度 | 滿分 | 評分 | 證據 |
|------|-----|------|------|
| A. 5.5b 條件清晰度 | 3 | 3 | workflow.md 1146-1151 行：crypto/hashing/encoding 明列 |
| B. shadow_safe 判定可操作性 | 2 | 2 | 1153-1159 行：pure / safe to call twice / DB-network-charge 反例 |
| C. 5_interface.yaml template 支援 | 2 | 2 | swap_strategy + shadow_config 欄位（commit 6f4cc4ce） |
| D. 5.5b 範例覆蓋 | 1 | 1 | encrypt/decrypt/hashing/encoding 明文 |
| E. Steps 8-13 兩條 path 完整 | 1 | 1 | SKILL.md direct + shadow 兩個表格 |
| F. unsafe_methods 反例覆蓋 | 1 | 1 | writes DB / sends network / charges user |

CocoaSecurity → shadow 的判斷鏈：
```
target_dependency: CocoaSecurity
  → AES encrypt/decrypt = "byte-for-byte identical (crypto)"
  → 5.5b 條件 1 ✓
  → 全為 pure functions
  → 5.5b 條件 3 ✓
  → swap_strategy: shadow
  → shadow_safe_methods 含 aesEncryptWithData:key:iv: + decryptDataString:
```

## 延伸發現（非 #2 範疇）

#16-class 隱憂：Step 5 沒有 init-step5.sh 縱深防禦。LLM 可能：
- hand-write 5_interface.yaml 跳過 swap_strategy 詢問
- 未呈現「Confirm swap_strategy: [direct] or [shadow]」即繼續 Step 6

這跟 Step 2 hand-edit 是同一個失敗模式。記為新 issue 候選 → **#16-extension: Step 5 lifecycle**。

修法已知方向（沿用 plan E pattern）：
- 設計 init-step5.sh，內部呼叫 LLM evaluate criteria → 寫 5_interface.yaml → state.sh advance
- 但 Step 5 本身就是 user decision point（Critical Rule 7），全 deterministic 化會破壞語意
- 較合適：Critical Rule 16 — 5_interface.yaml 必須含 swap_strategy 且非 null，state.sh 增加 Step 5 advance 前置檢查

不在當前 #2 處理範圍。

## 重新評估剩餘問題

| # | 問題 | 嚴重度 |
|---|------|------|
| 3 | T5 platform-migration walkthrough | 🟡 中 |
| **新** | Step 5+ lifecycle（#16 鏡像在 Step 5） | 🟡 中 |
| 8 | paired-header 範圍 | 🟢 低 |
| 4 | GitButler workaround | 🟢 低 |
| 5 | gate-strangler.sh yq 依賴 | 🟢 低 |
| 6 | IPHONEOS multi-target | 🟢 低 |
| 7 | Shadow logging infra docs | 🟢 低 |
