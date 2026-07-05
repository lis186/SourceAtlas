# QA 計畫：skill-slim 改版驗證

**受測物**：分支 `feature/skill-slim`（commit `b11ac4b3`）— plugin 從五檔架構收斂為單檔 SKILL.md（15,896 → 4,249 行），wrapper skills 移除、script 路徑改用 `${CLAUDE_PLUGIN_ROOT}`。

**驗證方式**：三個測試角色各開一個新 Claude Code session，平行執行各自的測試案例，透過 `/agmsg` 回報給 `qa-lead`（team：`satlas-qa`）。

## 改版引入的風險（測試就是針對這些）

| # | 風險 | 對應案例 |
|---|------|---------|
| R1 | 刪除 wrapper skills 後，自然語言問題不再觸發對的 command | A1–A5 |
| R2 | 刪除 V1–V4 驗證儀式後，輸出出現幻覺路徑 | C4（核心） |
| R3 | `${CLAUDE_PLUGIN_ROOT}` script 路徑在真實安裝下解析失敗 | B3、B8、B9 |
| R4 | 濃縮後遺漏行為：快取、handoffs、輸出 schema | B1–B7 |
| R5 | flow 內聯化的 9 個模式品質不足（原本就是死路，現在是新寫的） | C1 |
| R6 | refactor/seam 保守修改仍動到了狀態機行為 | B8、B9 |

---

## 每個測試 session 的共同準備（bootstrap）

1. 開新終端，`cd` 到測試標的專案（預設：`~/dev/sourcealtas`，SourceAtlas CLI repo，中型 shell 專案、有 CLAUDE.md），啟動 `claude`。
2. 安裝受測 plugin：
   ```
   /plugin marketplace add ~/dev/sourceatlas2-skill-slim
   /plugin install sourceatlas@sourceatlas-dev
   ```
   若正式版 `sourceatlas@lis186-SourceAtlas` 已啟用，先 `/plugin disable sourceatlas@lis186-SourceAtlas`（測完再啟回來）。用 `/plugin list` 確認只有 dev 版啟用。
3. 加入訊息團隊：執行 `/agmsg`，依提示 join team `satlas-qa`，agent 名稱用自己的角色名（下方角色卡），delivery mode 選 `1`（monitor）。
4. 讀本文件（`~/dev/sourceatlas2-skill-slim/QA-SKILL-SLIM.md`），只執行自己角色的案例。
5. 測試開始前先清狀態：`rm -rf .sourceatlas`（僅限測試標的專案內）。

## 回報協定

- 每完成一個案例即回報一則：
  `/agmsg send qa-lead "REPORT <角色> <案例ID> PASS|FAIL|BLOCKED — <一行證據，FAIL 需含實際輸出片段或檔案路徑>"`
- 全部完成後送總結：
  `/agmsg send qa-lead "DONE <角色> — <n> pass / <n> fail / <n> blocked"`
- 卡住超過兩次重試：標 BLOCKED 並繼續下一案例，不要空轉。

---

## 角色卡

### 角色 A：`naive-user`（新手視角 — 驗證自動觸發與可讀性）

心態：你從未看過 SourceAtlas。**全程不准輸入任何 `/sourceatlas:*` 指令**，只用自然語言提問。每個案例判定兩件事：(1) Claude 是否自動選用正確的 command，(2) 輸出對新手是否可讀（有品牌標頭、YAML 結構、下一步建議表）。

| ID | 提問（照抄） | 期望觸發 | 通過準則 |
|----|-------------|---------|---------|
| A1 | 「我剛加入這個專案，幫我了解一下整體架構和技術棧」 | `overview` | 自動執行 overview；輸出含 `🗺️ SourceAtlas: Overview` 標頭與 YAML；存檔至 `.sourceatlas/overview.yaml` |
| A2 | 「這個專案是怎麼定義新的 CLI 子指令的？給我可以照抄的範例」 | `pattern` | 自動執行 pattern；給出 file:line 佐證的範例 |
| A3 | 「如果我改 lib/core.sh 會影響哪些地方？安全嗎？」 | `impact` | 自動執行 impact；有風險分級（🟢/🟡/🔴）與依賴計數 |
| A4 | 「satlas scan 執行時內部流程是怎麼跑的？」 | `flow` | 自動執行 flow；有步驟化的執行路徑 |
| A5 | 「這個 repo 誰改最多？有沒有只有一個人懂的區域？」 | `history` | 自動執行 history；有 hotspot / bus-factor 資訊 |
| A6 | 綜合評分：以新手身分評 1–5 分：輸出可讀性、下一步建議是否具體可執行 | — | 主觀評分 + 一句理由，寫進 DONE 訊息 |

判定注意：若 Claude 用原生能力直接回答而沒觸發 command，記 FAIL 並附上它實際做了什麼——這正是 R1 要抓的回歸。

### 角色 B：`power-user`（功能對等 — 驗證指令行為、快取、script 佈線）

心態：熟練使用者，明確下指令、驗檔案系統副作用。每案例都要 `ls`/`cat` 驗證宣稱的存檔真的存在。

| ID | 步驟 | 通過準則 |
|----|------|---------|
| B1 | `/sourceatlas:overview` → 再跑一次（不加 flag）→ 再跑 `--force` | 第一次產生分析並存 `.sourceatlas/overview.yaml`；第二次顯示 `📁 Loading cache`（含天數）且**不重新分析**；`--force` 重新分析 |
| B2 | `/sourceatlas:overview lib` | 存檔名為 `.sourceatlas/overview-lib.yaml`（子目錄命名規則） |
| B3 | `/sourceatlas:pattern "error handling"` | **確認 `find-patterns.sh` 真的被執行**（觀察工具呼叫，路徑應含 plugin cache 而非 `~/.claude/scripts`）；結果存 `.sourceatlas/patterns/` |
| B4 | `/sourceatlas:impact "bin/sourceatlas"` | 直接/間接依賴分類計數一致（總和=去重總數）；引用的檔案路徑全部真實存在 |
| B5 | `/sourceatlas:history` | 若無 code-maat：出現安裝詢問（AskUserQuestion），拒絕後改走 pure-git fallback 且有結果 |
| B6 | `/sourceatlas:deps`（讓它自己盤點，或指定 shell 相關升級） | 版本資訊來自實際 manifest/lock，不猜測；規則來源有揭露 |
| B7 | `/sourceatlas:list` → `/sourceatlas:reset patterns` → `/sourceatlas:list` | list 正確列出 B1–B6 產物；reset 後 patterns 消失、其他保留 |
| B8 | `/sourceatlas:seam lib/core.sh` | `detect-zones.sh` 從 plugin bundle 執行成功；產出 zone 報告 |
| B9 | `/sourceatlas:refactor lib/core.sh --zones-only` | scripts 解析成功、狀態檔建立；`--zones-only` 只做 zone 偵測不進後續步驟 |

### 角色 C：`adversary`（破壞性測試 — 驗證幻覺與邊界）

心態：想辦法讓它出錯。**C4 是本次改版最重要的回歸測試**。

| ID | 步驟 | 通過準則 |
|----|------|---------|
| C1 | 用自然語言觸發 flow 舊死路模式，各跑一個：「幫我做 taint 分析追蹤未信任輸入」「找出 dead code」「分析 feature toggle 的流向」 | 三個都**不能**卡死或說找不到參考檔（舊版會撞 `flow-modes/mode-*.md` 死路）；各自產出合理分析 |
| C2 | `/sourceatlas:impact "lib/does-not-exist.sh"` | 優雅處理：模糊比對建議或明說找不到；**不得虛構依賴清單** |
| C3 | `/sourceatlas:pattern "a"`（過度籠統） | 要求使用者收斂 pattern 名稱，而非硬吐 50+ 檔案 |
| C4 | **幻覺稽核**：跑 `/sourceatlas:overview --force` 和 `/sourceatlas:pattern "config"`，然後把存檔 YAML/MD 裡**每一個** file path 和 file:line 逐一 `test -f` / `sed -n` 驗證 | 虛構路徑數 = 0 → PASS；1–2 個 → FAIL（附清單）；≥3 → FAIL 並在訊息標 `CRITICAL` |
| C5 | `/sourceatlas:audit lib/core.sh`（在沒裝 gemini/codex CLI 的前提下） | 進入降級模式：prompt 檔存到 `.sourceatlas/audit/prompts/`，不 crash、誠實說明少了哪些驗證 |
| C6 | 檢查安裝後的 plugin 快取目錄（`/plugin list` 找到路徑）：`grep -rn '~/.claude/scripts\|ANALYSIS_CONSTITUTION' <cache>/commands/`、`find <cache> -type l` | 兩者皆空 |

---

## qa-lead 收尾（本 session 或新 session 以 qa-lead 身分）

1. 收齊三個 `DONE` 後，彙整成矩陣：案例 × PASS/FAIL/BLOCKED。
2. 判定標準：
   - **可合併**：R1–R6 對應案例全 PASS，或 FAIL 僅屬既有行為（改版前也會失敗）。
   - **需修**：C4 出現任何幻覺路徑、R3 任一 script 解析失敗、A1/A2 觸發失敗 → 回 worktree 修正後重測該角色。
3. 產出報告存 `~/dev/sourceatlas2-skill-slim/QA-REPORT.md`。
