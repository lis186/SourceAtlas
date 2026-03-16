# 端到端驗證清單 — TypeScript（AuthService）

本文件為合約審計管線在 TypeScript 專案上的端到端驗證清單。
由於管線需要 LLM CLI 工具（gemini/codex/claude），此文件以檢查清單形式記錄各步驟的預期行為與驗收標準。

---

## 1. 前置條件檢查

### 1.1 CLI 工具安裝

- [ ] `ast-grep` 已安裝且版本 >= 0.20（`sg --version`）
- [ ] `rg`（ripgrep）已安裝（`rg --version`）
- [ ] LLM CLI 工具至少一項可用：`gemini`、`codex`、`claude`
- [ ] `yq` 或 `jq` 已安裝（用於解析 YAML/JSON 輸出）

### 1.2 配置檔案

- [ ] `audit.config.yml` 存在且可被 schema 驗證通過
- [ ] `language` 欄位值為 `typescript`
- [ ] `target_files` 中列出的所有 `.ts` 檔案皆存在於專案中
- [ ] `refactoring_intent` 非空字串
- [ ] `.d.ts` 處理規則明確：`target_files` 中由使用者明確指定的 `.d.ts` 檔案應被納入分析範圍，不受邊界發現（Step 0）排除規則影響。邊界發現的 `.d.ts` 排除僅適用於自動掃描發現的非目標宣告檔

### 1.3 語言插件

- [ ] `prompts/languages/typescript.md` 存在
- [ ] 插件內容涵蓋 TypeScript 特有的合約模式（interface、type guard、generic constraint）

---

## 2. 管線步驟：預期輸入/輸出

### Step 0：邊界發現（Boundary Discovery）

- **輸入**：`audit.config.yml` 中的 `boundary_discovery` 設定
- **處理**：使用 `rg` 搜尋 `observer_patterns` 和 `sync_patterns`，限定 `file_types: [ts, js]`
- **輸出**：相關檔案清單（最多 `max_files` 個），格式為純文字路徑列表
- **驗收標準**：
  - [ ] 搜尋範圍正確排除 `node_modules`、`dist`、`.d.ts`（非目標宣告檔）、`build/`、`coverage/`、`.next/`、`.nuxt/`、`__tests__/`、`jest.config.*`
  - [ ] 輸出檔案數量 <= `max_files`（預設 5）
  - [ ] 每個輸出檔案都至少匹配一個 pattern

### Step 1：合約提取（Contract Extraction）

- **輸入**：`target_files` + Step 0 發現的邊界檔案 + `refactoring_intent`
- **處理**：LLM 分析原始碼，提取行為合約候選
- **輸出**：YAML 格式合約清單，每筆含 `id`、`type`（M/L/N/S/E/C/D/P）、`description`、`evidence`
- **驗收標準**：
  - [ ] 至少產出 10 個合約候選
  - [ ] 每個合約至少有一筆 `evidence`（含 `file:line` 參照）
  - [ ] 涵蓋至少 3 種合約類型

### Step 1.5：依賴分析（Dependency Analysis）

- **輸入**：`target_files` + `dependency_analysis.import_patterns`
- **處理**：使用 `rg` 掃描 import 語句，建立依賴方向圖
- **輸出**：依賴圖（節點 + 邊）、Seam 標記、Pinch Point 標記
- **驗收標準**：
  - [ ] `import_patterns` 正確匹配 ES module `import { x } from 'y'`、`require()` 和 dynamic `import()`
  - [ ] `seam_detection: true` 時，每個依賴節點標記 Seam 類型
  - [ ] 入邊數 >= `pinch_point_threshold`（3）的節點被標記為 Pinch Point

### Step 2：合約分類（Contract Classification）

- **輸入**：Step 1 產出的合約候選
- **處理**：LLM 為每筆合約指定正式分類與信心度
- **輸出**：分類後的合約清單，含 `confidence`（0.0-1.0）
- **驗收標準**：
  - [ ] 所有合約皆有分類
  - [ ] 無「未分類」項目殘留

### Step 3：交叉驗證（Cross-Validation）

- **輸入**：分類後的合約清單
- **處理**：第二個 LLM 獨立驗證，標記 CONFIRM / DISPUTE / ADD
- **輸出**：驗證結果，含 CONFIRM_RATIO
- **驗收標準**：
  - [ ] CONFIRM_RATIO <= 70%（若高於此值，表示第一輪可能遺漏重要合約或驗證流於形式）
  - [ ] 每個 DISPUTE 和 ADD 項目含理由說明
  - [ ] ADD 項目被回饋至合約清單

### Step 4：Claude 合併（Contract Merge）

- **輸入**：Step 1-2 的合約清單 + Step 3 的交叉驗證結果（CONFIRM / DISPUTE / ADD）
- **處理**：Claude 機械性地合併 Auditor 與 Adversary 的結果，產出最終合約
- **輸出**：最終合約文件 + 驗證規則 + Pinch Point 標記
- **驗收標準**：
  - [ ] 合約去重完成——無重複 ID 或語義重複的合約
  - [ ] 所有 DISPUTE 項目已被移除，或保留者附有明確理由（`[DISPUTED -- evidence inconclusive]`）
  - [ ] 每個合約的 `pinch_point` 欄位已標記完成（`true` 或 `false`）
  - [ ] 所有合約 ID 格式符合 `{Category}-{NNN}`（例如 `M-001`、`D-002`），匹配正規表示式 `^[MLNSECDP]-[0-9]{3}$`

---

## 3. Phase B CI 規則驗證

### 3.1 ast-grep 規則

- [ ] 能夠為 TypeScript 合約產生 ast-grep 規則（`.sgconfig.yml` + `.yaml` 規則檔）
- [ ] 規則可在 `.ts` 檔案上成功執行（`sg scan --rule rule.yaml target.ts`）
- [ ] 規則涵蓋以下 TypeScript 結構：
  - interface 宣告與 implements
  - type assertion / type guard
  - async function 簽名
  - decorator（如適用）
  - generic type constraint
  - useEffect cleanup（驗證 `useEffect` 中的 cleanup return 函式存在，參照語言插件 `l1-useeffect-cleanup` 範例）
  - EventEmitter pattern（驗證 `emit` / `on` / `removeListener` 的配對使用，參照語言插件 `n1-event-emitter-emit` 範例）

### 3.2 grep 回退規則

- [ ] 對於 ast-grep 無法表達的模式，有對應的 grep 規則
- [ ] grep 規則正確處理 TypeScript 的多行語法（如多行 import）

---

## 4. 回歸檢查

確認新增 TypeScript 支援後，既有語言配置不受影響。

### 4.1 Objective-C 回歸

- [ ] `audit.config.example-objc.yml` 仍可通過 schema 驗證
- [ ] ObjC 的 `boundary_discovery.observer_patterns` 在 ObjC 檔案上正常匹配
- [ ] ObjC 的 `verification.secondary: clang-ast-dump` 設定不受 TypeScript 變更影響

### 4.2 Swift 回歸

- [ ] `audit.config.example-swift.yml` 仍可通過 schema 驗證
- [ ] Swift 的 `boundary_discovery.observer_patterns` 在 Swift 檔案上正常匹配
- [ ] Swift 的 `verification.primary: ast-grep` 設定不受影響

### 4.3 Schema 相容性

- [ ] schema 中 `language.enum` 已包含 `typescript`（已確認存在）
- [ ] schema 中 `file_types.enum` 已包含 `ts` 和 `js`（已確認存在）
- [ ] 新增的 TypeScript 範例配置未引入 schema 中未定義的欄位
