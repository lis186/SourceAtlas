---
date: 2026-04-27
session: refactor T4 retest after init-state.sh fix
status: 1 win + 1 new issue
---

# T4 Retest: Critical Rule 14 win + Step 2 lifecycle leak

## TL;DR

- ✅ **#1 修法成功**：Critical Rule 14 + init-state.sh 擋住了原本的 CLAUDE.md override。Skill 第一個 tool call 就是 `bash init-state.sh ...`，沒有 pre-Step-1 dead code cleanup，沒有自由的 zone 分析。
- ⚠️ **新 issue #16**：Step 2+ 沒有對應的 deterministic 入口。LLM 在 init-state.sh 完成後，**直接 hand-edit state.yaml** 設 `current_step: 2` 和 `zone_id: "formatting"`，繞過 `/atlas.seam` 的 zone discovery。

## 觀察

在 nineyiappshop（work account）跑 fresh `/atlas.refactor NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYMemberHelper.m`：

**Step 1 行為（修法後）**：
```
⏺ Bash(bash /Users/justinlee/dev/sourceatlas2/plugin/commands/refactor/scripts/init-state.sh "." "...NYMemberHelper.m" 2>&1)
⎿  → Running pilot-run.sh...
   Step 1 — Select Target: produced
   ...
```

第一個 tool call 就是 init-state.sh。✅

**Step 2 行為（新發現）**：
init-state.sh 一完成，LLM 馬上發起 Edit tool call 改 state.yaml：

```diff
- updated: "2026-04-26T15:59:57Z"
- current_step: 1
- zone_id: null
+ updated: "2026-04-27T00:00:00Z"
+ current_step: 2
+ zone_id: "formatting"
```

`zone_id: "formatting"` 是 LLM 推論出來的。沒有：
- 跑 `/atlas.seam` 做 zone discovery
- 寫 `2a_zones.yaml` artifact
- 跑 Gate 2 contract verification dry-run
- 觸發 Step 2 session boundary

換句話說：**#1 的修法把 CLAUDE.md override 從 Step 1 推遲到 Step 2**。同樣的失敗模式（LLM 自由發揮、跳過 artifact lifecycle），只是發生在更後面。

## 為什麼這發生

Step 1 被加固成「單一 deterministic bash call」，LLM 沒有解讀空間。Step 2 在 workflow.md 裡仍然是文字描述：

```markdown
### Step 2a: Zone Discovery
Call /atlas.seam on the target ...
```

LLM 看到 `Call /atlas.seam` 是「自然語言指令」，就有判斷空間。在 work account session（沒有 SourceAtlas 自己的 CLAUDE.md），LLM 偏好用 Edit tool 直接改檔案，而非走 slash command 鏈。

## 修法方向（待設計）

### 方案 A：Step 2a 也包成 init-step2a.sh

新增 `scripts/init-step2a.sh` 內部呼叫 `/atlas.seam` 等價的邏輯：
- 跑 detect-zones.sh
- 解析輸出產生 zone 排名
- 自動選 first-slice zone
- 寫 `2a_zones.yaml` + 更新 state.yaml current_step/zone_id

優點：跟 Step 1 對稱，deterministic
缺點：要先有 `/atlas.seam` 的非互動版本；如果 /atlas.seam 是另一個 Skill，需要 inline 它的邏輯

### 方案 B：禁止 Edit tool 動 state.yaml

Critical Rule 15: state.yaml 只能由 init-state.sh / init-step2a.sh / init-stepN.sh 寫。LLM 不得用 Edit / Write 編輯 state.yaml。

優點：規則層面解
缺點：純文字提示，跟原本 #1 的問題同類，依賴 LLM 服從

### 方案 C：把 Step 2-7 全部 deterministic 化

每個 step 都有 init-stepN.sh。workflow.md 變成「步驟 N 的 Do = bash init-stepN.sh」。

優點：根本解
缺點：成本最大，需要把 atlas.audit / atlas.seam 的 inline 等價邏輯包進來

### 方案 D：hybrid — 規則 + 部分 deterministic

- 規則 (B) + Step 2a deterministic (A 的子集)
- Steps 3-7 維持 LLM-driven 但 Critical Rule 15 禁止 hand-edit state.yaml
- LLM 必須透過 update-state.sh 改 state（write-only API）

## T4 完整檢查點狀態

| 檢查點 | 狀態 |
|--------|------|
| Pilot: platform_migration_detected: false | ✅ |
| S1: mode_name: seam-injection | ✅ |
| S1: confirmed: true (auto) | ✅ |
| S1: 1_target.yaml + state.yaml 寫到磁碟 | ✅ |
| **NEW**: Step 1 是第一個 tool call（無 CLAUDE.md override） | ✅ |
| Step 2: 透過 /atlas.seam 走 zone discovery | ❌（hand-edit） |
| S5: swap_strategy → shadow | ❌ 未到達（被 #16 阻擋） |
| S5: shadow_safe_methods 含 aesEncryptWithData: | ❌ 未到達 |

## 重新評估剩餘問題優先序

| # | 問題 | 嚴重度 |
|---|------|------|
| 16 | Step 2+ lifecycle 未強制 deterministic（新） | 🔴 高 |
| 2 | T4 S5 shadow path 驗證 | 🟡 中（被 #16 阻擋） |
| 3 | T5 platform-migration walkthrough | 🟡 中 |
| 8 | paired-header 範圍 | 🟢 低 |
| 4 | GitButler workaround | 🟢 低 |
| 5 | gate-strangler.sh yq 依賴 | 🟢 低 |
| 6 | IPHONEOS multi-target | 🟢 低 |
| 7 | Shadow logging infra docs | 🟢 低 |

#16 是 #1 的鏡像，下一步該處理它。
