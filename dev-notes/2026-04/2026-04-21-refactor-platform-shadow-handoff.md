---
date: 2026-04-21
session: refactor-platform-shadow
status: handoff — test pending
---

# Handoff: atlas.refactor — Platform Migration + Shadow Mode

## 本次做了什麼

針對 Issue「Playbook doesn't map to platform-prescribed migrations」設計並實作了完整解法。

### 新增功能

| 功能 | 實作位置 | 說明 |
|------|---------|------|
| Migration mode 分類學 | `references/mode-dispatch.yaml` | 二維分類 (interface_origin × granularity)，4 種 mode，每 step 有 applies/skip/replaced dispatch |
| Platform 偵測 | `scripts/pilot-run.sh` + `references/platform-signatures.yaml` | Grep-only 偵測 UIApplicationDelegate 等平台協定，輸出 `Platform Migration Signals` 區段 |
| Candidate mode 確認 | `workflow.md` §1.5 | 非 seam-injection 自動偵測時，需使用者顯式確認才繼續 |
| Schema v2 回退 | `templates/state.yaml` + `workflow.md` | 舊 state（無 schema_version）視為 seam-injection，不自動升版 |
| Strangler Plan artifact | `workflow.md` §2b-alt + `scripts/gate-strangler.sh` | `S_strangler_plan.yaml`：zone × from_slot × to_slot × verification |
| Platform slot map | `references/platform-slot-map.yaml` | AppDelegate → SceneDelegate 方法對映，含 iOS version 注意事項 |
| Platform gate | `scripts/gate-platform-migration.sh` + `references/platform-dispatch-rules.yaml` | 三項檢查：legacy_removed / target_implemented / no_double_dispatch（含版本 condition）|
| Steps 8–13 mode 變體 | `references/steps-8-13-by-mode.md` + `SKILL.md` | 四種 mode 各有完整的 Start/Do/Done 表格 |
| **Shadow Mode** | `templates/5_interface.yaml` + `workflow.md` §5.5b / §6.0 + `SKILL.md` | S5 新增 swap_strategy 決策；S6 產出 ShadowAdapter + logger protocol；S9 拆為 9a/9b/9c |

### 新增/修改的檔案

```
plugin/commands/refactor/
├── SKILL.md                              修改（--mode 旗標、Steps 8-13 shadow 表、Critical Rules 11-13）
├── workflow.md                           修改（--mode parse、schema v2、dispatch、1.5 mode、2b-alt、5.5b、6.0）
├── templates/
│   ├── state.yaml                        修改（schema_version、migration_mode、skip_reason 欄位）
│   └── 5_interface.yaml                  修改（swap_strategy、shadow_config 欄位）
├── scripts/
│   ├── pilot-run.sh                      修改（Platform Migration Signals 區段）
│   ├── gate-strangler.sh                 新增
│   └── gate-platform-migration.sh        新增
└── references/
    ├── mode-dispatch.yaml                新增
    ├── platform-signatures.yaml          新增
    ├── platform-slot-map.yaml            新增
    ├── platform-dispatch-rules.yaml      新增
    └── steps-8-13-by-mode.md            新增
```

---

## 下一步：驗證測試

測試專案：`/Users/justinlee/dev/nineyiappshop`

### T1 — 偵測負例（腳本層，應立即跑）

```bash
cd /Users/justinlee/dev/nineyiappshop
bash /Users/justinlee/dev/sourceatlas2/plugin/commands/refactor/scripts/pilot-run.sh \
  . NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYKeychainHelper.m
```

**預期**：`platform_migration_detected: false`、`recommended_mode: seam-injection`

### T2 — 偵測正例（腳本層，應立即跑）

```bash
bash /Users/justinlee/dev/sourceatlas2/plugin/commands/refactor/scripts/pilot-run.sh \
  . NineyiAppShop/AppDelegate.m
```

**預期**：`platform_migration_detected: true`、`platform_id: ios_uikit_scenes`、`recommended_mode: platform-migration`

### T3 — Schema v2 回退

```bash
mkdir -p /tmp/test-refactor-compat/NYHTTPSClient
cat > /tmp/test-refactor-compat/NYHTTPSClient/state.yaml <<'EOF'
module: "nyhttpsclient"
file: "NYHTTPSClient.m"
language: "objc"
current_step: 3
EOF
grep 'schema_version' /tmp/test-refactor-compat/NYHTTPSClient/state.yaml \
  || echo "✅ v1 state confirmed"
```

### T4 — 完整流程 + Shadow mode（Playbook 層）

```bash
cd /Users/justinlee/dev/nineyiappshop
/atlas.refactor NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYMemberHelper.m
```

**逐步檢查點**：
- Pilot：`platform_migration_detected: false`
- S1：`mode_name: seam-injection`，`confirmed: true`（auto，不問使用者）
- S5：出現 swap_strategy 問題，CocoaSecurity → 建議 `shadow`
- S5：`shadow_safe_methods` 包含 `aesEncryptWithData:key:iv:`

### T5 — Platform mode 走一步（可選）

```bash
/atlas.refactor NineyiAppShop/AppDelegate.m
```

**預期**：S1 出現 mode 確認提示；S3 被 skip（dispatch = skip）；S2 後產出 `S_strangler_plan.yaml` draft

---

## 已知 limitation

- `gate-strangler.sh` 的 verification grep 需 yq；若無 yq 會 exit 1
- `gate-platform-migration.sh` 讀 IPHONEOS_DEPLOYMENT_TARGET 靠 grep pbxproj；multi-target 專案可能讀到最低版本
- Shadow mode 的 match rate 監控在 playbook 外（需使用者自行接 logging infra）
