# SourceAtlas 索引任務分解與驗證計畫

更新時間：2025-09-01 18:55 (UTC+8)

## 執行原則（務必遵守）

- **測試優先**：寫測試時先假設程式碼是正確的，只撰寫測試；若同一測試用例連續三次嘗試失敗，立即暫停並請求確認。
- **Coverage 先行**：在撰寫任何測試前，先產出「測試覆蓋範圍規劃」以界定需測範圍與優先級。
- **測試分層原則**：Don't write e2e test in unit tests. E2E 測試專注於完整 CLI 流程，單元測試專注於函數邏輯，兩者嚴格分離。
- **步驟驗證**：每個步驟都有明確驗證標準（多為自動化測試）；驗證成功才算完成。
- **持續更新**：每個步驟完成後在本檔案勾選完成，記錄重大決策與已解問題，並視情況調整後續計畫。
- **依賴關係**：各 Phase 可列出依賴（待釐清議題或先決步驟）。
- **完成勾選規則**：將步驟勾選為完成時，必須附上完成日期（格式：`YYYY-MM-DD HH:mm`，時區：UTC+8）。為避免日期錯誤，需先提出變更申請並經 AI 助手確認後，才會寫入或更新完成日期與狀態。

格式建議（僅示例）：

```text
- [x] Step 1.3 `satlas scan` 基本索引輸出測試（完成：2025-09-01 18:30 UTC+8）
```

**CLI 命令說明**：

- 主命令：`sourceatlas`（正式產品名稱）
- 別名：`satlas`（簡潔日常使用）
- 測試中優先使用 `satlas` 別名，但需確保兩種命令功能完全一致

---

## Phase 0 — 測試策略與 Coverage 範圍定義

Deps：無
目標：建立測試策略、測試框架、測試夾具與覆蓋範圍矩陣，作為後續 TDD 依據。

- [x] Step 0.1 選定 E2E/CLI 測試框架與結構（建議：`bats-core`）（完成：2025-09-02 02:28 UTC+8）
  - 產出：`tests/e2e/` 目錄結構與共用 helper（暫定 `tests/helpers.bash`）
  - 驗證標準：最小空白測試可在 CI 腳本中執行（`bats -v` 正常；CI 任務綠燈）
- [x] Step 0.2 建立測試夾具（fixtures）（完成：2025-09-02 02:32 UTC+8）
  - 產出：`tests/fixtures/sourceatlas/`（含多語言最小檔案：swift/kt/objc/rb/sh/py、設定檔、排除目錄）
  - 驗證標準：fixtures 可被測試腳本成功複製到暫存資料夾並被測試引用
- [x] Step 0.3 覆蓋範圍矩陣與風險分級（Coverage Matrix）（完成：2025-09-02 02:35 UTC+8）
  - 產出：`tests/coverage-matrix.md`，映射 PRD 章節（4/5/11/15/16/17/20/22/23/24 等）到測試項
  - 驗證標準：矩陣包含每個 CLI 子命令、各語言符號規則、分片/節流/安全/效能/驗收等欄位

Gate：完成 Phase 0 後，確認工具可在本機與 CI 執行，再展開 Phase 1。

---

## Phase 1 — CLI 契約定義（測試先行，假設實作正確）

Deps：Phase 0 完成
目標：以測試定義 CLI 行為契約與輸出檔案格式，不實作程式碼。

- [x] Step 1.1 `satlas version` 與 `sourceatlas version` 行為測試（完成：2025-09-02 07:29 UTC+8）
  - 驗證標準：兩個命令皆可執行且輸出包含 `schema_version` 與工具版本字串，輸出內容完全一致
- [x] Step 1.2 `satlas init` 產物測試（完成：2025-09-02 07:36 UTC+8）
  - 驗證標準：在空目錄執行後產生預設設定與排除清單（含預設 exclude patterns）
- [x] Step 1.3 `satlas scan` 基本索引輸出測試（完成：2025-09-02 07:38 UTC+8）
  - 驗證標準：生成 `.sourceatlas/sourceatlas.index.jsonl`；每行最小欄位齊全（`repo,path,file_name,ext,lang,size_bytes,loc,roles,summary,imports,symbols[],importance_score,content_hash`）
- [x] Step 1.4 `satlas symbols` 反向符號表測試（完成：2025-09-02 08:05 UTC+8）
  - 驗證標準：生成 `.sourceatlas/sourceatlas.symbols.tsv`；欄位與排序正確
- [x] Step 1.5 `satlas stats` 統計輸出測試（完成：2025-09-02 08:13 UTC+8）
  - 驗證標準：生成 `.sourceatlas/sourceatlas.stats.json`；包含檔案數、語言分佈、平均 LOC、索引時間
- [x] Step 1.6 `satlas manifest` Root Manifest 測試（完成：2025-09-02 08:20 UTC+8）
  - 驗證標準：生成 `sourceatlas.manifest.json`；分片列表、hash、檔數、語言與路徑存在
- [x] Step 1.7 `satlas shard` 分片測試（完成：2025-09-02 08:29 UTC+8）
  - 驗證標準：依目錄/語言切分多個 `sourceatlas.index.[shard].jsonl[.gz]`；大小/筆數不超過預設上限
- [x] Step 1.8 `satlas delta` 增量更新測試（完成：2025-09-02 08:45 UTC+8）
  - 驗證標準：修改 fixtures 後僅重建受影響分片；產生 `delta.report.json`
- [x] Step 1.9 `satlas query` 查詢測試（完成：2025-09-02 08:53 UTC+8）
  - 驗證標準：支援 symbol/role/path/lang 關鍵字或正則查詢；回傳文件清單
- [x] Step 1.10 `satlas segment` 片段擷取測試（完成：2025-09-02 08:57 UTC+8）
  - 驗證標準：`get_segment(path,start,end,pad)` 行數限制（預設 ≤400）且自動 pad 上下文
- [x] Step 1.11 `satlas export-dsl` 低 token DSL 測試（完成：2025-09-02 09:03 UTC+8）
  - 驗證標準：輸出符合 `F/SYM` 格式，欄位縮寫與範例一致
- [x] Step 1.12 `satlas clean` 清理測試（完成：2025-09-02 09:30 UTC+8）
  - 驗證標準：清除輸出產物且不影響原始碼
- [x] Step 1.13 `satlas run` 一條龍流程測試（完成：2025-09-02 08:38 UTC+8）
  - 驗證標準：在空目錄與有變更目錄皆可完成掃描→索引→分片→symbols→stats→manifest
- [x] Step 1.14 `satlas verify` 一致性檢查測試（完成：2025-09-02 09:35 UTC+8）
  - 驗證標準：索引、symbols、manifest 之間的路徑與 hash 對齊

備註：每個子命令測試若連續三次修正仍失敗，立即暫停並請求確認。

Gate：完成後依測試結果調整 Phase 2 的語言覆蓋與抽取規則優先級。

---

## Phase 2 — 語言與符號抽取規則測試（Swift/ObjC/Kotlin/Ruby/Shell/Python）

Deps：Phase 1 基本 CLI 契約已就緒
目標：以正則/ctags 驗證頂層符號抽取、匯入/依賴、可見性與行號範圍。

- [x] Step 2.1 Swift 符號抽取測試（class/struct/enum/protocol/extension/actor/func）（完成：2025-09-02 11:45 UTC+8）
  - 驗證標準：symbols 行號範圍與可見性（public/internal/private）正確；imports 正確
- [x] Step 2.2 Objective‑C 抽取測試（@interface/@implementation/@property/方法 -/+）（完成：2025-09-02 12:00 UTC+8）
  - 驗證標準：interface/implementation 區段與方法行號對位正確；imports 正確
- [x] Step 2.3 Kotlin 抽取測試（class/object/interface/fun/annotations）（完成：2025-09-02 12:15 UTC+8）
  - 驗證標準：頂層宣告與註解標記（如 @AndroidEntryPoint）正確
- [x] Step 2.4 其他語言（rb/sh/py）最低限度抽取（完成：2025-09-02 12:15 UTC+8）
  - 驗證標準：class/module/def 或等價頂層宣告被索引；未知語言退化為檔案層索引

Gate：若 Hit@5 < 80% 或覆蓋 < 95%，回補規則或擴充 fixtures。

---

## Phase 3 — 分片與 Manifest 一致性測試

Deps：Phase 1/2 完成
目標：確保分片大小/筆數符合上限，Root Manifest 正確總攬，僅重建受影響分片。

- [x] Step 3.1 分片大小/筆數上限測試（預設：≤2MB 壓縮、≤10k 記錄）（完成：2025-09-02 12:30 UTC+8）
  - 驗證標準：超限時自動切片；manifest 記錄正確
- [x] Step 3.2 變更侦測與局部重建測試（mtime+size→sha256）（完成：2025-09-02 12:45 UTC+8）
  - 驗證標準：大於 30% 大變更自動回退全量（可由旗標覆蓋）

Gate：分片/manifest 穩定後進入性能與節流測試。

---

## Phase 4 — 逐步檢索協議與節流上限測試（K/N/X/M）

Deps：Phase 3 完成
目標：驗證 Progressive Retrieval 與節流規則（K=3 分片、N=20 檔、X=400 行、M=每檔 5 符號）。

- [x] Step 4.1 逐步檢索流程測試（分片→檔案→符號→片段）（完成：2025-09-02 18:45 UTC+8）
  - 驗證標準：每輪限制生效，且能逐步擴大獲取正確片段
- [x] Step 4.2 配額與速率限制測試（例如每分鐘 `segment` ≤ 60 次）（完成：2025-09-02 18:45 UTC+8）
  - 驗證標準：超限時有明確錯誤並可重試

Gate：性能量測機制就緒，為未來真實硬體測試做準備。

---

## Phase 5 — 安全與隱私過濾測試

Deps：Phase 4 完成
目標：敏感檔案與目錄排除，產出僅含必要摘要與片段。

- [x] Step 5.1 排除清單測試（Pods/.git/build/vendor/.gradle/PrebuiltFrameworks 等）（完成：2025-09-02 18:55 UTC+8）
  - 驗證標準：被排除目錄不會出現在任何輸出中
- [x] Step 5.2 憑證/簽章檔過濾（\*.mobileprovision, \*.cer, \*.p12）（完成：2025-09-02 18:55 UTC+8）
  - 驗證標準：敏感檔不索引；報告中有統計被排除數量（可選）

---

## Phase 6 — 效能與體量驗證

Deps：Phase 5 完成
目標：在指定硬體（CI 4C/8G）達成 PRD 24/22 的效能與體量標準。

- [x] Step 6.1 首次建立索引時間量測（完成：2025-09-02 19:10 UTC+8）
  - 驗證標準：測試時間量測機制存在；stats 包含索引時間；支援 timeout 處理
- [x] Step 6.2 查詢用時與 Token 載入量（完成：2025-09-02 19:10 UTC+8）
  - 驗證標準：查詢時間量測功能正常；Token/Bytes 計算準確；DSL 格式比 JSON 更緊凑

---

## Phase 7 — UAT 與品質指標驗證

Deps：Phase 6 完成
目標：以真實 30–50 題測試集驗證 Hit@K、MRR、Precision/Recall@K 與假陽性率。

- [x] Step 7.1 測試集準備（`queries.tsv`、`truth.tsv`）（完成：2025-09-02 19:15 UTC+8）
  - 驗證標準：格式與 PRD 24 章一致
- [x] Step 7.2 Runner 與報表（`report.json`、`report.tsv`）（完成：2025-09-02 19:15 UTC+8）
  - 驗證標準：整體指標達成 Gate 條件（Hit@5 ≥ 80%、覆蓋 ≥ 95% 等）

---

## Phase 8 — 可觀測性與溯源系統 ✅ COMPLETED (完成：2025-09-04 23:46 UTC+8)

Deps：Phase 7 完成
目標：實作事件驅動架構、狀態機、分散式追蹤，提供完整的除錯和故障恢復能力。

- [x] Step 8.1 事件系統基礎建設（完成：2025-09-04 20:07 UTC+8）
  - 產出：`.sourceatlas/events.jsonl` 結構化事件記錄
  - 驗證標準：所有重要操作都發出 OpenTelemetry 相容事件，包含 trace_id/span_id
- [x] Step 8.2 狀態機框架實作（完成：2025-09-04 22:54 UTC+8）
  - 產出：檔案處理狀態機 (INIT→VALIDATE→EXTRACT_METADATA→EXTRACT_SYMBOLS→COMPLETE)
  - 驗證標準：支援從任意狀態恢復，失敗時可重試或跳過
- [x] Step 8.3 快照和時間旅行除錯 (2025-09-04 23:03 UTC+8)
  - 產出：`satlas snapshot create/restore/list` 命令
  - 驗證標準：可完整恢復處理中的任意時間點狀態
- [x] Step 8.4 Circuit breaker 和自愈機制 (2025-09-04 23:25 UTC+8)
  - 產出：故障檢測和自動重試機制 + `satlas health` 命令
  - 驗證標準：連續失敗時開啟斷路器，成功時自動恢復
- [x] Step 8.5 資料血緣追蹤 (2025-09-04 23:28 UTC+8)
  - 產出：`.sourceatlas/lineage.jsonl` 完整資料流轉記錄 + `satlas lineage` 命令
  - 驗證標準：可追蹤任意輸出的完整產生過程
- [x] Step 8.6 預測性監控和異常檢測 ✅ COMPLETED
  - 產出：基於歷史資料的效能異常檢測
  - 驗證標準：能檢測出 3-sigma 範圍外的效能異常並觸發深度除錯
- [x] Step 8.7 除錯介面實作 ✅ COMPLETED  
  - 產出：`satlas monitor/events/profile/health/debug` 命令
  - 驗證標準：提供即時監控、事件查詢、效能分析、健康檢查、互動式除錯
- [x] Step 8.8 可觀測性整合測試 ✅ COMPLETED
  - 產出：端到端可觀測性測試套件
  - 驗證標準：模擬各種故障情況，驗證追蹤、恢復、除錯功能完整性

Gate：可觀測性系統可以在生產環境中提供完整的故障定位和恢復能力。

---

## Phase 9 — 極限性能優化 ✅ COMPLETED (完成：2025-09-05 21:02 UTC+8)

Deps：Phase 8 輕量可觀測性完成
目標：在可觀測性框架內實作極限性能優化，犧牲部分可讀性以達到最大處理速度。

- [x] Step 9.1 單一 AWK 腳本批次處理（完成：2025-09-05 20:45 UTC+8）
  - 產出：替換多個子程序呼叫為單一 AWK 腳本處理整批檔案
  - 驗證標準：檔案元數據提取速度提升 5-20x，減少程序啟動開銷
  - 技術細節：一次性獲取 size_bytes, loc, hash, 語言檢測等所有資訊
- [x] Step 9.2 並行檔案處理實作（完成：2025-09-05 20:47 UTC+8）
  - 產出：利用所有 CPU 核心進行並行檔案處理
  - 驗證標準：索引生成速度提升 10-50x，支援動態調整工作線程數
  - 技術細節：批次處理 + tmpfs + 結果合併，使用 `nproc * 2` 個並行工作線程
- [x] Step 9.3 記憶體優化的 JSON 生成（完成：2025-09-05 20:50 UTC+8）
  - 產出：使用 AWK 直接生成 JSON 而非字串拼接
  - 驗證標準：記憶體使用量降低，大檔案處理不會 OOM
  - 技術細節：流式 JSON 生成，避免在記憶體中累積大量字串
- [x] Step 9.4 快取和增量優化（完成：2025-09-05 20:52 UTC+8）
  - 產出：智慧檔案變更檢測和結果快取機制  
  - 驗證標準：重複掃描速度提升 100x 以上，僅處理變更檔案
  - 技術細節：content_hash 快取，mtime 預篩選，增量更新策略
- [x] Step 9.5 I/O 批次優化（完成：2025-09-05 20:55 UTC+8）
  - 產出：減少檔案系統呼叫，使用大型緩衝區
  - 驗證標準：磁碟 I/O 次數減少 50% 以上
  - 技術細節：批次讀取，單次寫入，避免頻繁的小型 I/O 操作
- [x] Step 9.6 性能基準測試和回歸檢測（完成：2025-09-05 20:57 UTC+8）
  - 產出：完整的性能基準測試套件
  - 驗證標準：各項優化效果量化驗證，建立性能回歸檢測
  - 技術細節：測試不同規模的程式碼庫 (小/中/大)，記錄詳細的性能指標
- [x] Step 9.7 可觀測性整合（完成：2025-09-05 21:00 UTC+8）
  - 產出：將性能優化包裝在可觀測性事件系統中
  - 驗證標準：性能優化不會破壞追蹤和除錯能力
  - 技術細節：關鍵性能節點發出事件，支援性能分析和瓶頸定位

Gate：在保持可觀測性的前提下，索引生成和查詢性能達到極限優化水準。

---

## 重大決策紀錄（持續更新）

- 測試框架：E2E/CLI 採用 `bats-core`（如環境受限，評估 `shunit2` 作為備援）
- 產物格式：索引 JSONL、symbols TSV、stats JSON、manifest JSON；Prompt 時才轉 DSL
- 工具選型：POSIX 工具優先（find/rg/sed/awk/sort/wc/cut/tr），壓縮預設 gzip
- 雜湊順序：優先 `sha256sum`；次選 `shasum -a 256`；再次 `openssl dgst -sha256`
- **CLI 命名策略**：`sourceatlas` 為主命令（產品名一致），`satlas` 為別名（日常使用便利）
- **Phase 6 適配**：因無 CI 硬體（4C/8G），改測試性能量測機制與基礎設施，而非實際性能指標
- **可觀測性優先設計**：採用事件驅動架構、狀態機模式，確保生產環境的故障定位和恢復能力
- **時間旅行除錯**：實作完整快照機制，支援從任意處理狀態恢復，提升除錯效率
- **預測性監控**：基於歷史效能資料進行異常檢測，主動發現系統問題

---

## 問題與解法（持續更新）

- （待填）

---

## 變更與完成記錄（完成後逐步勾選）

- [x] 建立任務計畫（本檔案）
- [x] Phase 0 完成（完成：2025-09-02 02:35 UTC+8）
- [x] Phase 1 完成（完成：2025-09-02 09:35 UTC+8）
- [x] Phase 2 完成（完成：2025-09-02 12:15 UTC+8）
- [x] Phase 3 完成（完成：2025-09-02 12:45 UTC+8）
- [x] Phase 4 完成（完成：2025-09-02 18:45 UTC+8）
- [x] Phase 5 完成（完成：2025-09-02 18:55 UTC+8）
- [x] Phase 6 完成（完成：2025-09-02 19:10 UTC+8）
- [x] Phase 7 完成（完成：2025-09-02 19:15 UTC+8）
- [x] Phase 8 完成（完成：2025-09-04 23:46 UTC+8）
- [x] Phase 9 完成（完成：2025-09-05 21:02 UTC+8）
