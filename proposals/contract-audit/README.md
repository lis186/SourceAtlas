# atlas.audit — 行為合約審計命令

> 多 LLM 交叉驗證的行為合約提取系統，用於遺留代碼重構前的品質保證。

## 使用場景

### 解決什麼問題

遺留代碼重構最大的風險不是「看不懂」，而是「不知道哪些隱含行為是故意的」。人工代碼審查難以系統性地提取所有隱含合約（implicit contracts），導致重構後出現迴歸 bug。

### 誰會使用

- 需要將 ObjC 重寫為 Swift 的 iOS 團隊
- 需要將 Java 遷移到 Kotlin 的 Android 團隊
- 任何涉及核心模組語言遷移或架構重寫的開發者

### 為什麼需要

等同於 Michael Feathers《Working Effectively with Legacy Code》中的「特徵化測試」，但在行為合約層面而非單元測試層面。產出可機器驗證的斷言（grep + ast-grep），整合進 CI/CD 防止重構迴歸。

---

## 來源：已驗證的原型

原型位於 `/Users/justinlee/dev/nineyiappshop/audit/`，已對 `NYHTTPSClient.m`（769 行 ObjC）完成驗證：

- 產出 49 個合約（M/L/N/S/E/C 六類）
- Codex 對抗性評論 CONFIRM_RATIO = 69.4%（通過 ≤70% 門檻）
- 意外發現 4 個實際 bug（cancel 失效、AnyPromise 回傳錯誤值等）
- Phase B CI 檢查 100% 通過

---

## 理論基礎：Feathers《Working Effectively with Legacy Code》

本系統的設計並非憑空而來，而是與 Michael Feathers 提出的遺留代碼處理框架高度對映：

### 特徵化測試 vs 行為合約

Feathers 的「特徵化測試」（Characterization Test）是在**運行時**捕捉現有行為，確保重構前後一致。本系統的行為合約則是在**靜態分析層面**，由 LLM 提取隱含行為規範。兩者互補：

| 面向 | 特徵化測試 | 行為合約 |
|------|-----------|---------|
| 執行方式 | 運行時（需要環境） | 靜態（LLM + grep/ast-grep） |
| 產出物 | 測試案例 | 驗證規則（CI 可執行） |
| 覆蓋範圍 | 可觸發的路徑 | 所有可見的隱含行為 |
| 適用時機 | 有可運行環境 | 環境不可用或成本過高 |

### Seam（接縫）概念

Feathers 定義 Seam 為「可以在不修改代碼的情況下改變行為的位置」。本系統可由 LLM 自動識別三類 Seam：

- **Object Seam** — 可替換的物件注入點（依賴注入、Protocol/Interface）
- **Preprocessing Seam** — 編譯期可替換的行為（宏、條件編譯、build config）
- **Link Seam** — 連結期可替換的實現（動態連結庫、module alias）

Seam 識別直接影響合約的 scope 標記和依賴打破策略的選擇。

### Legacy Code Change Algorithm 五步法 vs Phase A/B

| Feathers 五步法 | 本系統對應 | 差距 |
|----------------|-----------|------|
| 1. 確認變更點 | Step 0 邊界發現 | ✅ 已覆蓋 |
| 2. 找到測試點 | Step 1-2 合約提取 | ✅ 用合約替代測試 |
| 3. 打破依賴 | ⚠️ 缺少 | ❌ 需新增依賴圖譜分析 |
| 4. 寫測試 | Phase B CI 規則 | ✅ 用 grep/ast-grep 替代 |
| 5. 修改並重構 | 超出範圍（使用者自行完成） | — |

第 3 步「打破依賴」是目前最大的差距，需要在管線中補充依賴圖譜分析。

### Sensing vs Separation

Feathers 區分兩種測試困難：

- **Sensing（感知）** — 無法觀察到代碼的效果（對應合約類別 M/N/E）
- **Separation（分離）** — 無法將代碼從依賴中隔離出來（對應新增類別 D）

現有合約分類法偏重 Sensing 面向，需要新增 Dependency 類別來補足 Separation 面向。

---

## 架構設計

### 兩階段設計

```
Phase A（一次性）— 三方 LLM 交叉驗證產生合約：
  Step 0: 邊界發現（rg 靜態掃描相關檔案）
  Step 1: Gemini 盲掃 → 獨立發現隱含行為
  Step 1.5: 依賴圖譜分析 → 識別 Seam、標記 scope 與依賴方向
  Step 2: Claude 結構化審計 → 合約 + 驗證腳本（含 D/P 類別）
  Step 3: Codex 對抗性評論 → CONFIRM/DISPUTE/ADD
  Step 4: Claude 合併 → 最終合約 + 驗證規則 + Pinch Point 識別

Phase B（每個 PR）— 確定性、無 LLM 的 CI 檢查：
  grep 斷言驗證合約存在
  ast-grep 規則驗證結構化合約
  任何失敗 → PR 阻止
```

### 合約分類法（語言無關）

| 類別 | 名稱 | 描述 |
|------|------|------|
| M | Mutation | 對請求或資料的副作用修改 |
| L | Lifecycle | 隱含狀態轉換 |
| N | Notification | 發布/訂閱耦合 |
| S | Synchronization | 阻塞、鎖定、排序保證 |
| E | Error Handling | 錯誤吞沒 vs 傳播 |
| C | Cancellation | 取消範圍與殘留狀態 |
| D | Dependency | 此行為依賴外部實體，遷移時需先分離（Separation 面向） |
| P | Propagation | effect 傳播路徑：回傳值鏈、參數修改、global state |

### 三層架構與耦合度

```
Layer 1: 管線架構（盲掃→結構化→對抗性→合併）  → 100% 通用
Layer 2: 合約分類法（M/L/N/S/E/C/D/P）          → 95% 通用
Layer 3: 語言特定實現（prompt 細節 + 驗證工具）   → 需要泛化
```

### Step 1.5 依賴圖譜分析（對應 Feathers 第 3 步「打破依賴」）

在盲掃之後、結構化審計之前，插入依賴分析：

1. **依賴方向圖** — 從 import/include 建立模組間的依賴方向圖
2. **Seam 識別** — LLM 標記每個依賴的 Seam 類型（Object/Preprocessing/Link）
3. **Pinch Point 識別** — 找出「多條依賴路徑收斂的節點」，這些節點的合約具有最高 ROI（一條 CI 規則保護多條路徑）
4. **合約元資料** — 每個合約標記：
   - `scope`: method / class / module
   - `seam_type`: object / preprocessing / link / none
   - `pinch_point`: boolean

```yaml
# 合約元資料範例
- id: M-003
  type: Mutation
  scope: method
  seam_type: object
  pinch_point: true
  description: "addHTTPHeaderField 會修改 shared request"
```

---

## 泛化方案

### 1. Prompt 拆分為骨架 + 語言插件

現有 `claude-contract-audit.md` 是 272 行單體，拆為：

```
prompts/
├── skeleton.md              # 通用：合約分類 + 輸出格式 + 品質門檻
├── languages/
│   ├── objc.md              # NSNotification, dispatch_semaphore, ...
│   ├── swift.md             # actor, async/await, Combine, ...
│   ├── typescript.md        # EventEmitter, Promise, AbortController, ...
│   ├── go.md                # channel, context, sync.Mutex, ...
│   ├── kotlin.md            # Flow, coroutine, LiveData, ...
│   └── python.md            # asyncio, threading, signal, ...
└── gemini-blind-scan.md     # 已通用，參數化 Section 4
```

每個語言插件提供：
- 該語言的通知/事件原語
- 該語言的同步原語
- 該語言的生命週期模式
- 驗證策略（ast-grep 或 grep fallback）
- 常見隱含合約範例
- 該語言的 effect 防火牆機制（如 Java `final`、Rust ownership、Python 無內建機制）
- 該語言可用的 Seam 類型 + 推薦的依賴打破技術
- Sprout/Wrap 安全變更策略的語言映射

```
語言 effect 防火牆對照：
  Java/Kotlin  — final, sealed, records（強）
  Swift        — let, value types, actor isolation（強）
  Rust         — ownership + borrow checker（最強）
  Go           — 無 class，但 interface implicit（中）
  TypeScript   — readonly, as const（弱，僅型別層）
  Python       — 無內建機制（最弱，需靠 convention）
  ObjC         — 無，所有 property 預設可變（最弱）⚠️ 無 ast-grep，需 grep fallback

Sprout/Wrap 策略映射：
  Sprout Method — 所有語言皆適用，新增方法不碰舊代碼
  Sprout Class  — Java/Swift/Kotlin/ObjC 適用
  Wrap Method   — 所有語言皆適用，包裝既有方法
  Wrap Class    — Java/Swift/Kotlin 適用（Decorator pattern）
```

### 2. 配置檔驅動管線

新增 `audit.config.yml` 取代硬編碼：

```yaml
module: NYHTTPSClient
language: objc
target_files:
  - NYCore/.../NYHTTPSClient.m
  - NYCore/.../NYHTTPSClient.h
refactoring_intent: "Replace with Swift async/await + interceptor chain"

boundary_discovery:
  observer_patterns: '"apiRequest"|"apiResponse"'
  sync_patterns: 'dispatch_semaphore_create|dispatch_barrier_sync'
  file_types: [objc, swift]

verification:
  primary: grep
  secondary: ast-grep
```

### 3. 語言感知驗證策略

```
ast-grep 完整支援：Swift, Go, TypeScript, JavaScript, Python, Rust, C, C++, Java, Kotlin
grep fallback：     Objective-C, Ruby, PHP, Shell
```

Phase B `run-ci.sh` 已有正確的抽象邊界（自動 SKIP 不支援的語言），不需修改。

### 4. Prompt 設計改進（來自 Feathers 方法論）

三個核心 prompt 增強指令，提升 LLM 合約提取品質：

#### Tell the Story

要求 LLM 用 ≤3 個核心概念描述系統，並列出為了簡化而省略的「謊言」：

```
指令：用 3 個概念向新人解釋這個模組的核心職責。
然後列出你的解釋中省略了哪些重要細節（這些就是隱含合約候選）。
```

這對應 Feathers 的「如果你能用簡單的話描述系統做什麼，那些你省略的部分就是潛在的隱含合約」。

#### Scratch Refactoring

要求 LLM 描述它**會做但不執行**的重構操作，藉此揭示隱藏合約：

```
指令：假設你要重構這段代碼，列出你會做的 5 個重構步驟。
對每個步驟，標記它可能破壞的隱含假設。
（注意：不要實際執行，只分析風險。）
```

Feathers 提出 Scratch Refactoring 是安全的探索手段——在心理上重構以理解代碼，而不實際改動。

#### Effect Propagation Tracing

追蹤每個 public 方法的三種 effect 路徑：

```
指令：對每個 public 方法，追蹤以下三種 effect：
1. 回傳值鏈 — 回傳值被誰消費？是否有隱含的格式/型別假設？
2. 參數修改 — 是否修改傳入的參數？呼叫者是否假設不可變？
3. Global state — 是否讀寫全域狀態？其他方法是否依賴該狀態的時序？
```

### 5. 驗證規則擴展（來自 Feathers 的代碼氣味）

新增 ast-grep/grep 規則，捕捉 Feathers 書中描述的典型遺留代碼問題：

| 規則 | 偵測目標 | ast-grep 語言 | ObjC grep fallback | 來源 |
|------|---------|-------------|-------------------|------|
| 巢狀深度 > 3 | Snarled method（糾結方法） | Swift, TS, Go, ... | `grep -c '^\s*{' \| awk '$1>3'` 近似 | Ch.22 |
| 方法行數 > 50 | Monster method（巨型方法） | （直接用 grep -c） | ✅ 通用 | Ch.22 |
| 子類別 override ≤ 2 方法 | Programming by difference | Swift, Java, Kotlin | `grep -c '@override\|-(void)\|-(id)'` 近似 | Ch.20 |
| 10+ 檔案 import 同一第三方深層 class | Missing wrapper（缺少包裝層） | （直接用 grep） | ✅ 通用 | Ch.15 |
| 公開可變欄位 | Effect propagation 風險 | Swift, TS, Java, ... | `grep '@property.*readwrite\|@property[^)]*)'` | Ch.11 |

這些規則可作為 Phase B CI 的補充檢查，標記高風險區域供人工複審。

#### Objective-C grep fallback 策略

Objective-C 不在 ast-grep 支援列表中，所有結構化規則需降級為 grep 近似：

```bash
# Snarled method — 統計大括號巢狀深度（近似，無法處理字串中的大括號）
awk '{for(i=1;i<=length($0);i++){c=substr($0,i,1);if(c=="{")d++;if(c=="}")d--};if(d>3)print NR": depth="d, $0}' "$file"

# Monster method — 統計 @implementation 內的方法行數
awk '/^[-+]\s*\(/{start=NR} /^\}/ && start{if(NR-start>50)print start"-"NR" ("NR-start" lines)";start=0}' "$file"

# Programming by difference — 找只 override 少量方法的子類別
grep -c '^\s*-\s*(' "$file"  # 配合 @interface ... : SuperClass 判斷

# 公開可變欄位 — 找 readwrite property（ObjC 預設即 readwrite）
grep '@property\s*(' "$file" | grep -v 'readonly'
```

**精確度限制**：grep fallback 存在誤報風險（如字串中的大括號、宏展開），建議搭配人工複審。對精確度要求高的場景，考慮使用 `clang -ast-dump` 作為進階替代方案。

---

## 與 SourceAtlas 整合

### 自動選擇語言插件

利用現有 `detect-project.sh` 自動辨識語言：

```bash
/atlas.audit NYHTTPSClient.m
→ detect-project.sh 辨識 ObjC → 載入 languages/objc.md
```

### 自動推薦審計目標

整合 `scan-entropy.sh` + `/atlas.history` hotspot：

```bash
/atlas.audit --recommend
→ 「200 個檔案中，這 5 個值得做合約審計」
→ 排序：高熵 × 高 git 變動頻率 × 高耦合度
```

### 輸出存儲

```
.sourceatlas/audit/{module}.yaml
```

---

## 適用場景

| 場景 | 適合度 | 原因 |
|------|--------|------|
| 核心模組語言遷移（ObjC→Swift, Java→Kotlin） | ★★★★★ | 隱含合約最多、風險最高 |
| 高風險模組（加密、支付、認證） | ★★★★★ | 錯誤代價最大 |
| API 層重構 | ★★★★☆ | 合約明確但數量多 |
| 一般性代碼清理 | ★★☆☆☆ | 成本效益比低 |
| 批量遺留代碼現代化（100+ 檔案） | ★☆☆☆☆ | 每檔 3 次 LLM 呼叫，成本過高 |

---

## 實作步驟

### P0 — 核心泛化

三條平行軌道，無交叉依賴：

#### 軌道 A — Prompt 體系（寫作密集）

```
A1 → A2（序列）
A1 → A3, A4（平行）
```

- [ ] **A1** 從 `claude-contract-audit.md` 提取通用骨架 `prompts/skeleton.md`
  - 合約分類法（M/L/N/S/E/C/D/P）
  - 輸出格式（Artifact 1-4）
  - 品質門檻（Quality Gates）
  - Known Pitfalls（通用部分）
  - 建立語言插件目錄 `prompts/languages/`
- [ ] **A2** 整合 Tell the Story / Scratch Refactoring / Effect Propagation 三個 prompt 增強指令到 skeleton.md（依賴 A1）
- [ ] **A3** 撰寫 `prompts/languages/objc.md`（依賴 A1，與 A4 平行）
  - 包含 effect 防火牆、Seam 類型、Sprout/Wrap 策略
- [ ] **A4** 撰寫 `prompts/languages/swift.md`（依賴 A1，與 A3 平行）
  - 包含 effect 防火牆、Seam 類型、Sprout/Wrap 策略

#### 軌道 B — 驗證規則（工程密集）

```
B1 → B2（序列）
B3 獨立
```

- [ ] **B1** 實作 Feathers 驗證規則（巢狀深度、方法行數、missing wrapper 等 5 條 ast-grep 版）
- [ ] **B2** 為 ObjC 實作所有 5 條規則的 grep fallback（含精確度標記）（依賴 B1）
- [ ] **B3** 評估 `clang -ast-dump` 作為 ObjC 進階替代方案的可行性（獨立）

#### 軌道 C — 管線整合（架構密集）

```
C1 → C2, C3（平行）
C4 獨立
```

- [ ] **C1** 定義 `audit.config.yml` schema
- [ ] **C2** 修改 `run-baseline.sh` 讀取 config 選擇語言插件（依賴 C1）
  - Step 0：從 config 讀取 `boundary_discovery.*`
  - Step 1.5：依賴圖譜分析 + Seam 識別
  - Step 2：組合 `skeleton.md` + `languages/{lang}.md`
- [ ] **C3** 保留 CLI 參數作為 fallback（依賴 C1，與 C2 平行）
- [ ] **C4** 在合約輸出中加入 scope / seam_type / pinch_point 元資料（獨立）

#### P0 合流點

最終 `run-baseline.sh` 需要組合 skeleton + 語言插件（A→C2），三條軌道在此合流驗證。

### P1 — 第二語言驗證

兩條平行軌道，在端到端驗證時合流：

#### 軌道 D — Prompt 泛化

```
D1, D2 平行
```

- [ ] **D1** 參數化 `gemini-blind-scan.md` Section 4（獨立）
  - 「NSNotification observers」→「event/notification observers」
  - 「dispatch_semaphore」→「synchronization primitives」
- [ ] **D2** 選擇驗證目標（TypeScript 或 Go）+ 撰寫第三語言插件（獨立）
  - 包含 effect 防火牆 + Seam 類型 + Sprout/Wrap 策略

#### 軌道 E — 配置與驗證

```
E1 → E2 → E3（序列）
```

- [ ] **E1** 建立該語言的 `audit.config.yml`（依賴 D2 完成語言選擇）
- [ ] **E2** 端到端驗證：Phase A 產出合約 → Phase B CI 通過（依賴 D1 + D2 + E1）
- [ ] **E3** 驗證 D/P 類別合約在新語言上的提取品質（依賴 E2）

#### P1 合流點

E2 端到端驗證是匯集點，需要 D1（泛化 prompt）+ D2（語言插件）+ E1（config）全部完成。

### P2 — SourceAtlas 整合

四項全部平行，無依賴：

- [ ] 整合 `detect-project.sh` 自動選擇語言插件
- [ ] 建立 `plugin/commands/audit/` 命令結構
  - SKILL.md, workflow.md, output-template.md, verification-guide.md
- [ ] 整合 scan-entropy.sh + git hotspot 實現 `--recommend`
- [ ] 輸出存到 `.sourceatlas/audit/{module}.yaml`

### P3 — 長期改進

三項全部平行，無依賴：

- [ ] 更多語言插件（Kotlin, Python, Rust, Java）— 每個語言彼此平行
- [ ] 建立 ast-grep 支援矩陣文件
- [ ] LLM 後端可替換（支援本地模型降低成本）

---

## 驗收標準

1. 同一管線對 **2 種以上語言** 產出合約，Phase B 通過
2. 新增語言只需寫一個 `prompts/languages/{lang}.md`（<100 行）+ 一個 `audit.config.yml`
3. 不修改 `run-baseline.sh` 或 `run-ci.sh` 即可支援新語言

---

## 已知風險

1. **成本** — 每個模組呼叫 3 個 LLM，適合高風險模組，不適合批量處理
2. **Prompt 工程** — 語言插件品質直接決定合約品質，需要該語言的領域知識
3. **合約驗證** — LLM 可能把 bug 當成合約，需要人工最終確認
4. **不能替代整合測試** — 合約驗證的是代碼結構，不是運行時行為

---

## 參考

- 原型實現：`/Users/justinlee/dev/nineyiappshop/audit/`
- SourceAtlas 插件結構：`/Users/justinlee/dev/sourceatlas2/plugin/commands/`
- 語言偵測：`/Users/justinlee/dev/sourceatlas2/scripts/atlas/detect-project.sh`
- 熵掃描：`/Users/justinlee/dev/sourceatlas2/scripts/atlas/scan-entropy.sh`
