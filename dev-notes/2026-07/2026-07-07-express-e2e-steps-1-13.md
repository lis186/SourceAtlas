# Express E2E — Playbook Steps 1→13 全程實走（Group C 首測）

日期：2026-07-07 · 執行：Fable 5（handoff 指定下一棒；原規劃 Opus，實際由 Fable 執行）
目標專案：`~/dev/test_targets/express`（分支 `experiment/refactor-playbook-e2e`，絕不推 upstream）
Plugin：worktree `steps-8-13`（PR #130 未 merge）

## 結果

- **`13_delete_legacy: verified`** — 全程 `state.sh` / gate scripts 推進，零手改 state.yaml
- Target：`lib/response.js`（rank-candidates #1，score 2100 = 1050 lines × 2 commits）
- Seam：Module Seam @ `lib/express.js:21 require('./response')`（單行注入點，覆蓋全部 29 contracts）
- Step 8 真重寫 895 行 `lib/response-new.js`；swap 前用 require-cache seed 過 400 測試；swap 後 `npm test` 1258 綠；Step 13 刪 `lib/response.js` 獨立 commit
- express 分支 4 commits：artifacts(1-7) → new impl(8) → 單行 swap(9) → 刪 legacy(13)
- 審查管線首走：Step 2b `reviewers: {blind: agy, adversarial: codex}`（audit_mode: full）；Step 3 codex 陣亡 → `{blind: agy, adversarial: claude-subagent}`（Sonnet，緩解 #1 順帶實現）

## 傷痕清單（時序）

1. **detect-zones.sh 雙零 bug（JS 零 marker 路徑首踩）** — `grep -c ... || echo 0` 在零命中時輸出 `0\n0`（grep -c 自己印 0 且回傳 1），炸掉 `-eq 0` guard → line 334 unbound variable。同款病灶掃出 3 檔 9 處（refactor/seam 兩份 detect-zones + pilot-run）。諷刺：pilot-run.sh:206 有註解記載此 bug 並寫了 `_ccount()` 正確版，但同檔 143-145 行沒用它——修一處不掃全倉的教訓。全部改 `|| true`。
2. **init-step2a.sh 零 zone 直接 error** — workflow.md 宣稱 "handles small files (single zone)"，實際沒有 fallback。修：合成單一 whole-file zone。Group C 的 JS 檔沒有 `// MARK:` 是常態——這條路徑之前從未被走過。
3. **`agy -p` 不繼承 cwd** — 在自己的 scratch dir（`~/.gemini/antigravity-cli/scratch`）遊蕩直到 timeout。修法：`--add-dir "$PWD"`。gemini→agy 換血（PR #130）後首次實戰即暴露。
4. **三份 gate 腳本的 YAML `\"` 不反轉義** — gate-contracts / gate-seams / gate-step7 各自複製了 sed+eval 抽取邏輯，規則含引號時 eval 拿到字面 `\"`。Gate 2 首跑 21/29「失敗」全是 gate 自己的 bug（handoff gotcha「fact-check 失敗先懷疑 fact-checker」再次應驗）。三處都補 `sed 's/\\"/"/g'`；並學到規則寫法應避免引號（`grep -qE 'cookieParser..secret..'`）。
5. **state.sh 缺 audit_mode setter** — workflow 要求記錄 audit_mode 到 state，但 Rule 15 禁手改且 state.sh 無 API。加 `set-status --audit-mode full|subagent`。
6. **codex refresh token 中途陣亡** — Step 2b 正常，Step 3 空輸出 exit 1（`refresh_token_invalidated`）。fallback subagent 管線如設計運作；教訓：CLI 死活要逐次探測，reviewers: 逐 artifact 記錄。
7. **gate-step7.sh 重跑倒退狀態機** — SKILL.md Step 10 明文要求重跑 gate-step7 驗證 swap，但腳本 pass 時無條件 `current_step: 8`，把 10 拉回 8。修：僅 `current_step ≤ 7` 時推進。
8. **gate-postswap 通用字 legacy_class（Group C 結構性問題）** — `response` 匹配 `http.ServerResponse`、註解、一切。Step 8 gate 6 hits 全誤傷；Step 13 的全 repo zero-ref 檢查對 JS 通用字模組名不可滿足。修：dynamic languages 改查模組路徑引用 `require('./response')`。
9. **adapter 名推導把註解當宣告** — regex 未錨行首，把 6_adapter.js 註解 "No adapter **class exists**" 抓成 class 名 `exists`（grep -r 'exists' → 4 hits）。修：錨定行首 + Group C 無 adapter class 時改查 artifact 引用。
10. **audit `--zone` interop gap（未修，記錄）** — audit 讀 `.sourceatlas/seam/{module}.yaml`，refactor 2a 產 `2a_zones.yaml`。whole-file zone 繞過（不帶 --zone）；真 zone-scoped Group C 會撞牆。
11. **Group C 指南假設 jest** — express 用 mocha。require-cache seed（6_adapter.js 模式）是 mocha 版 module-seam mock；已寫入 SKILL.md Gotchas。
12. **gate-seams.sh parser 不停在 candidates 結束** — recommended_seam 欄位滲入最後一個 candidate 的標籤。無害（計數正確），未修。
13. **express 套件 flaky** — `req.fresh without response headers` 以 ~1/3 機率 socket parse error（供 3 跑 2 綠佐證）；與 swap 無關。另學：`npm test | tail` 吃掉 exit code——差點紅燈 commit，驗證要 `; echo $?` 分開。
14. **score threshold 對測試專案說 skip** — 2100 分被判 skip（低 churn）。handoff 明令全走 → 以任務授權 override，`--force` 重跑。

## 流程妥協（誠實揭露）

- **Session boundaries（Step 2 後、Step 5 後）被覆蓋** — handoff 明示單一 session 走完 1→13。Step 3 起僅讀 artifacts 不讀前段推理（盲掃/對抗審查本身即獨立 context），但「同 agent 寫同 agent 驗」的偏誤風險客觀存在。
- **Step 5 swap_strategy 使用者決策點自主判定**（direct；準則表 3/3 指向 direct）——依 handoff 授權，理由記錄於 5_interface.yaml。
- **Step 11 手動 smoke 從略** — express 無 UI，以 1258 全套件 + examples 隱含覆蓋替代。
- 主 session 為 Fable（handoff 原規劃 Opus 主導）；subagent 指派遵循建議（對抗審查用 Sonnet、機械驗證直接跑腳本無需 agent）。

## 對 Playbook 的量化回饋

- Steps 1-7 工具鏈在 Group C 的第一次接觸戰打出 9 個 bug 修復 + 2 個記錄性 gap——「沒有傷痕的 workflow 是設計出來的」獲得直接證據。
- Steps 8-13 表格本身（動作/Done 訊號）在 Group C 語義上成立，但 gate-postswap 的三個檢查全部需要 language-group 分派才能運作——已修。
- 審查管線（盲掃+對抗）實質有效：對抗審查砍掉 2 個偽 seam 候選（「extraction 不是現存 seam」）、加 2 個我漏掉的消費者路徑、3 條 FLAG 直接變成 Step 8 重寫的硬約束。
