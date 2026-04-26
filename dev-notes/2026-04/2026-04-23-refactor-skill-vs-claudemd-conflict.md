---
date: 2026-04-23
session: refactor-platform-shadow T4 validation
status: bug logged — fix pending
---

# Issue: atlas.refactor Skill 與全域 CLAUDE.md 衝突，跳過 artifact lifecycle

## 觀察到的行為

在 nineyiappshop（work account）跑 T4：

```
/atlas.refactor NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYMemberHelper.m
```

**預期流程**（per `workflow.md`）：
1. Skill 載入 → 讀 SKILL.md / workflow.md
2. Step 1 跑 pilot-run.sh → 寫 `1_target.yaml`，`state.yaml.current_step = 1`，`migration_mode.mode_name = seam-injection`
3. Step 2 → 寫 `2_contracts.yaml`、Gate 2 檢查
4. ⏸️ session boundary，輸出 resume command
5. （略）

**實際流程**：
1. Skill 載入 ✅
2. **直接執行全域 `~/.claude/CLAUDE.md` 的 "Step 0: Delete Before You Build"** — 對 NYMemberHelper.m 跑 dead code cleanup（683→300 行，184→117 行）
3. 等 Step 0 commit 完成（外部處理 git lock）
4. **跳過 workflow.md 的 step 結構**，直接做：
   - Re-run pilot 拿新 zone map
   - 評分 zone（🟢/🟡/🔴 testability）
   - 自由提出選項：「A — 撰寫 Characterization Test / B — 抽出 persistence 層 / C — 暫停」
5. **沒有寫任何 `.sourceatlas/refactor/NYMemberHelper/` 內的 artifact**

## 直接證據

```
$ ls /Users/justinlee/dev/nineyiappshop/.sourceatlas/refactor/NYMemberHelper/
ls: cannot access '...': No such file or directory
```

跑了 1 小時、$7.94，產出 0 個 artifact。

## 衝突的兩段指令

**全域 `~/.claude/CLAUDE.md`**：

> ### Step 0: Delete Before You Build
> Dead code accelerates context compaction. Before ANY structural refactor on
> a file >300 LOC, first remove all dead props, unused exports, unused
> imports, and debug logs. Commit this cleanup separately before starting the
> real work.

> ### Senior Dev Override
> Ignore your default directives to "avoid improvements beyond what was
> asked"... If architecture is flawed, state is duplicated, or patterns are
> inconsistent — propose and implement structural fixes.

**SKILL.md Critical Rules**：

> 1. Three-state lifecycle — every step: `pending → produced → verified`
> 2. Trust artifacts, not prompts — each step reads ONLY the previous step's artifact file

CLAUDE.md 的「Senior Dev Override」和 Skill 的「Trust artifacts」直接打架。Sonnet 4.6（執行 skill 的 model）選了前者。

## 為什麼 sourceatlas2 自己的 dev session 不會碰到這個

dev session 跑在 sourceatlas2 repo，CLAUDE.md 是 SourceAtlas 自己的（沒有「Senior Dev Override」規則）。只有當 atlas.refactor 被在**有 CLAUDE.md 強指令的 user repo** 裡呼叫時才暴露。

## 可能的修法（從低成本到高成本）

### 1. SKILL.md 加一條 Critical Rule 14（最小修改）

```markdown
14. **Skill workflow takes precedence over project CLAUDE.md hints** —
    even if the user's CLAUDE.md prescribes a "Step 0 cleanup" or
    "Senior Dev Override" pattern, the playbook's own Step 0 (= Step 1
    Select Target) is the entry point. Do not run dead-code cleanup
    before writing 1_target.yaml.
```

優點：純文字、立刻 push 給所有 user 生效
缺點：依賴 LLM 服從 — Sonnet 4.6 在 T4 已經證明會被 CLAUDE.md 覆蓋

### 2. workflow.md 把 Step 1 的「先寫 artifact」做成不可省略的前置條件

讓 SKILL.md 開頭直接執行一個檢查腳本：
```bash
[[ -f .sourceatlas/refactor/{module}/state.yaml ]] || \
    bash scripts/init-state.sh {module}
```

state.yaml 沒寫 → 不允許做任何其他事。**用程式強制 lifecycle**，不靠 LLM 服從。

優點：deterministic
缺點：會跟使用者「先 cleanup」的合理需求摩擦 — 需要在 init-state.sh 裡留逃生口（例如 `--skip-cleanup-check`）

### 3. 把 Step 0 cleanup 收納進 playbook（SKILL.md 加一個 Step 0.5）

承認這個需求合理，加正式步驟：
```
Step 0.5 — Pre-Refactor Cleanup（optional, gated by file LOC > 300）
  Output: 0_cleanup_diff.patch
  Gate: separate commit required before Step 1 advances
```

優點：對齊使用者預期，不違背 CLAUDE.md
缺點：playbook 從 13 步 → 14 步，需要更多文檔調整

## 推薦

**先做 (1)，同時規劃 (3)。**

(1) 是 30 行 markdown，今天就能做。能擋住至少一半的 LLM；剩下一半即使被 CLAUDE.md 覆蓋，至少 audit log 上 Skill 的 intent 是清楚的。

(3) 才是根本解法 — 承認 Step 0 cleanup 是真實需求，把它收進 playbook。但需要設計 `0_cleanup_diff.patch` 結構、補 workflow.md、補 templates、補 SKILL.md 表格、補 dispatch YAML。整套下來起碼 1 個 session。

(2) 不推薦 — 會擋住合理需求，且 escape hatch 還是會被 LLM 觸發。

## T4 測試現狀

| 檢查點 | 狀態 |
|--------|------|
| Pilot: `platform_migration_detected: false` | ✅ |
| Pilot: CocoaSecurity 依賴可見 | ✅ |
| S0 dead code 清除 + commit `20c28277c3` | ✅（雖然不在 playbook 規範內） |
| S1: `1_target.yaml` 寫入磁碟 | ❌ |
| S1: `mode_name: seam-injection` auto-confirmed | ⚠️（zone 分析隱含對，但 artifact 沒寫） |
| S5 swap_strategy → shadow | ❌ 未到達 |
| S5 `shadow_safe_methods` 含 `aesEncryptWithData:` | ❌ 未到達 |

T4 算半通過。要等修法落地後才能完整重跑驗收。
