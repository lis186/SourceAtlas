# SourceAtlas 索引 PRD（針對 AI Agent 快速定位程式碼）

## TL;DR

- 以輕量索引（JSONL/TSV/DSL）先鎖定正確檔案與符號，再按需拉取小片段（path:start-end）。
- 先做 Index + Symbols 驗證（Hit@K/時間/Token/覆蓋率），過門檻再視需要依 Gate 僅加 Shard/DSL/Embedding。
- 工具選型走輕量：Universal Ctags + ripgrep + `sourceatlas.sh`（POSIX、零或近零相依）。

## Arc42 導覽（對應章節）

- [1. 背景與目標](#1-背景與目標)
- [2. 範圍（Scope）](#2-範圍scope)
- [3. 產出物](#3-產出物)
- [4. 主索引 JSONL Schema（每行一筆）](#4-主索引-jsonl-schema每行一筆)
- [5. 反向符號表（TSV）](#5-反向符號表tsv)
- [6. 擷取與分析規則（實作概述）](#6-擷取與分析規則實作概述)
- [7. 效能與體量考量](#7-效能與體量考量)
- [8. 安全與隱私](#8-安全與隱私)
- [9. 驗收標準（UAT）](#9-驗收標準uat)
- [10. 目錄與檔名規劃](#10-目錄與檔名規劃)
- [11. 執行流程（實作建議）](#11-執行流程實作建議)
- [12. 後續擴充（非本版必做）](#12-後續擴充非本版必做)
- [13. JSONL 範例（精簡）](#13-jsonl-範例精簡)
- [14. 成功指標](#14-成功指標)
- [15. 分片化設計與 Root Manifest](#15-分片化設計與-root-manifest)
- [16. 片段服務 API（On-demand Segment）](#16-片段服務-apion-demand-segment)
- [17. 逐步檢索協議（Progressive Retrieval）](#17-逐步檢索協議progressive-retrieval)
- [18. 嵌入檢索（可選強化）](#18-嵌入檢索可選強化)
- [19. 低 Token DSL 與壓縮策略](#19-低-token-dsl-與壓縮策略)
- [20. 節流與配額規則](#20-節流與配額規則)
- [21. 跨 Repo 命名與路徑慣例](#21-跨-repo-命名與路徑慣例)
- [22. 規格常數（預設值，可環境變數覆蓋）](#22-規格常數預設值可環境變數覆蓋)
- [23. CLI 需求（零或近零相依）](#23-cli-需求零或近零相依)
- [24. 驗證方法（先測再優化）](#24-驗證方法先測再優化)
- [25. 工具選型（輕量優先）](#25-工具選型輕量優先)
- [26. 使用情境（context window 受限）](#26-使用情境context-window-受限)
- [26.1 語言無關化（Language-agnostic）設計](#261-語言無關化language-agnostic設計)
- [27. 架構決策（ADR 摘要）](#27-架構決策adr-摘要)
- [28. 風險與技術債](#28-風險與技術債)
- [29. 詞彙表](#29-詞彙表)
- [30. 增量索引（Delta）](#30-增量索引delta)
- [31. 任務管理規則（完成勾選與日期確認）](#31-任務管理規則完成勾選與日期確認)
- [32. 目錄結構與寫入約束（CLI 與測試）](#32-目錄結構與寫入約束cli-與測試)

## 導覽

- 目標/範圍（arc42 1/2）→ 1. 背景與目標、2. 範圍（Scope）
- 解決策略（arc42 4）→ 15–21（分片/片段/逐步檢索/DSL/節流/跨 repo）、25（工具選型）
- 建構體觀點（arc42 5）→ 3（產出物）、10（目錄與檔名規劃）、23（CLI 需求）
- 執行觀點（arc42 6）→ 16（片段服務 API）、17（逐步檢索協議）
- 部署觀點（arc42 7）→ 23（CLI 本地執行與輸出目錄）
- 橫切概念（arc42 8）→ 8（安全與隱私）、20（節流與配額）、22（規格常數）
- 品質需求/場景（arc42 10/11）→ 24（驗證方法：指標/流程/決策閘）
- 架構決策（arc42 9）→ 27（ADR 摘要）
- 風險與技術債（arc42 12）→ 28（風險與技術債）
- 詞彙表（arc42 Glossary）→ 29（詞彙表）

## 1. 背景與目標

- 目標：這是一個 CLI 工具，可以針對特定的 codebase 建立完整檔案層級的 Snapshot 索引，讓 AI agent（主要讀取模型：Claude 4 Sonnet）只需讀取此索引檔，即可快速定位目標功能/實作所在檔案與大致位置（行號範圍）。
- 需求重點：
  - 不追求可讀性與排版美觀，偏機器可解析、可 grep、可 programmatic consume。
  - 索引需包含：檔名、完整路徑、該檔案的重要職責/功能、語言類型、主要符號（類別/結構/介面/函式等）與行號範圍、匯入/依賴、可能的角色（如 ViewModel、Repository、Service、Controller…）。
  - 後續在問答時，AI 僅靠此索引即可先縮小檔案集合，再決定讀哪些原始碼。

## 2. 範圍（Scope）

- 預設包含的目標 codebase 根目錄：
  - 指定的 codebase 根目錄（可配置）
  - 可選擴充：多個 repo/目錄（若需跨 repo 索引，統一格式即可）
- 主要納入副檔名（可擴充）：
  - iOS：`.swift`, `.h`, `.m`
  - Android/Kotlin：`.kt`
  - 腳本/工具：`.rb`, `.sh`, `.py`
  - 設定/描述：`.gradle`, `.kts`, `.json`, `.yml`, `.yaml`, `.plist`
- 排除目錄（預設）：
  - `**/build/**`, `**/.gradle/**`, `**/.git/**`, `**/Pods/**`, `**/PrebuiltFrameworks/**`, `**/vendor/**`, `**/.idea/**`, `**/.DS_Store`
  - 憑證/簽章/Provision：`**/*.mobileprovision`, `**/*.cer`, `**/*.p12`

## 3. 產出物

- 主索引檔（單檔，供 LLM 載入）：
  - 路徑：`.sourceatlas/sourceatlas.index.jsonl`
  - 格式：JSON Lines（每行一個檔案的索引物件）。
- 反向符號表（選配，供關鍵字 → 檔案定位）：
  - 路徑：`.sourceatlas/sourceatlas.symbols.tsv`
  - 格式：TSV；欄位：`symbol\tkind\trepo\tpath\tline_start\tline_end`。
- 統計摘要（選配）：
  - 路徑：`.sourceatlas/sourceatlas.stats.json`
  - 內容：檔案數量、語言分佈、平均 LOC、索引時間等。

## 4. 主索引 JSONL Schema（每行一筆）

```json
{
  "repo": "SourceAtlas",                       
  "path": "ios-module/Sources/App/AppDelegate.swift",
  "file_name": "AppDelegate.swift",
  "ext": ".swift",
  "lang": "swift",
  "size_bytes": 1234,
  "loc": 85,
  "roles": ["AppLifecycle", "DI-EntryPoint"],  
  "summary": "負責 iOS app 啟動流程與生命週期掛鉤，註冊 DI 容器。<=200 chars",
  "imports": ["UIKit", "Combine", "ProjectCore"],
  "symbols": [
    {
      "name": "AppDelegate",
      "kind": "class",                       
      "visibility": "internal|public|private",
      "line_start": 12,
      "line_end": 80,
      "signature_excerpt": "class AppDelegate: UIResponder, UIApplicationDelegate { ... }"
    },
    {
      "name": "application(_:didFinishLaunchingWithOptions:)",
      "kind": "func",
      "visibility": "internal",
      "line_start": 25,
      "line_end": 45,
      "signature_excerpt": "func application(_ application: UIApplication, didFinishLaunchingWithOptions ... ) -> Bool"
    }
  ],
  "entry_points": ["@main", "UIApplicationMain", "SharedModule-Init"],
  "exported_symbols": ["AppDelegate"],           
  "dependencies": ["CoreModule", "ExternalLibrary"],
  "test_file": {
    "path": "ios-module/Tests/AppDelegateTests.swift",
    "exists": true
  },
  "platforms": ["iOS"],                         
  "build_targets": ["ios-module"],                  
  "importance_score": 0.82,                      
  "tags": ["bootstrap", "lifecycle"],
  "last_modified_utc": "2025-09-01T03:11:22Z",  
  "content_hash": "sha256:..."                  
}
```

欄位說明（重點）：

- `roles`：以檔名/路徑/符號啟發式推論（如包含 `ViewModel`, `Repository`, `Service`, `UseCase`, `ViewController`, `Reducer`, `Activity`, `Fragment`, `Composable` 等）。
- `symbols`：僅紀錄「頂層/對定位有幫助」的符號與行號範圍，不需全文。
- `entry_points`：各平台常見進入點（Swift `@main`, AppDelegate, SceneDelegate；Android `Application`, `Activity`）。
- `importance_score`：0~1 啟發式分數（如含進入點、跨模組依賴、檔名關鍵字者較高）。

## 5. 反向符號表（TSV）

- 欄位：`symbol\tkind\trepo\tpath\tline_start\tline_end`
- 作用：根據類別名/函式名快速反查檔案位置，利於 LLM 先鎖定候選檔案。

## 6. 擷取與分析規則（實作概述）

- 檔案走訪：
  - 遵守排除清單，並以多執行緒/多處理程序掃描。
  - 對每個檔案計算 `size_bytes`, `loc`, `content_hash`（例如 SHA-256）。
- 語言偵測：
  - 依副檔名決定 `lang`，基本無需 AST。
- 符號抽取（正則為主，速度優先）：
  - Swift：`class|struct|enum|protocol|extension|actor|func` 頂層宣告與可見性、行號範圍。
  - Objective-C：`@interface`, `@implementation`, `-\s*\(|\+\s*\(` 方法宣告、`@property`。
  - Kotlin：`class|object|interface|fun` 頂層宣告、`@AndroidEntryPoint` 等註解。
  - 其他語言：挑選對定位有幫助的頂層宣告（如 Ruby `class|module|def`）。
- 匯入/依賴：
  - Swift：`import X`，Kotlin：`import x.y.Z`，ObjC：`#import`/`@import`，Ruby：`require`/`require_relative`。
- 角色推論（啟發式，不需百分百正確）：
  - 依檔名/路徑關鍵字與符號型態（如含 `ViewModel` 類別 → `ViewModel`）。
- 重要度計分：
  - 含進入點、位於核心模組、被多處引用（可選）者加分；測試/樣本則略降。
- 錯誤處理：
  - 無法解析的檔案以最小資訊落檔（最差情況也要有 `repo`, `path`, `file_name`, `ext`）。

## 7. 效能與體量考量

- 以並行掃描 + 輕量正則解析為主；避免全專案 AST。
- 單一索引檔允許很大（LLM 讀取時可分段載入）。
- 輸出排序：`repo`、`path` 字典序，確保 deterministic。

## 8. 安全與隱私

- 排除憑證、簽章、私密金鑰/Provision 等。
- 只寫入「必要摘要」，不落原始碼內容（僅 `signature_excerpt` 的少量片段）。

## 9. 驗收標準（UAT）

- 基本覆蓋：≥ 95% 可讀檔案都有索引行。
- 查詢任務（人工抽樣 10 類）：
  - 例如：「iOS App 進入點在哪？」→ 能回傳 `AppDelegate.swift`/`@main` 相關檔。
  - 「Android 初始化 DI 在哪？」→ 能回傳 `Application`/`Hilt` 標註檔案。
  - 「Network Repository 的實作在哪？」→ 能回傳 `Repository`、`Service` 類型檔案清單。
- 回傳檔案同時提供頂層符號與行號範圍，方便二次跳轉。

## 10. 目錄與檔名規劃

- 產出位置固定：`.sourceatlas/`
  - `sourceatlas.index.jsonl`
  - `sourceatlas.symbols.tsv`（選配）
  - `sourceatlas.stats.json`（選配）

### 目錄結構規劃（SourceAtlas 工具）

#### SourceAtlas 工具本身的目錄結構

作為獨立工具的 SourceAtlas 專案結構：

```text
sourceatlas/                 # SourceAtlas 工具專案根目錄
  bin/
    sourceatlas              # CLI 主執行檔
    satlas                   # CLI 別名（symlink 或 wrapper）
  lib/
    core.sh                  # 核心函式庫
    parsers/                 # 語言解析器
      swift.sh
      kotlin.sh  
      objc.sh
      python.sh
      ruby.sh
  configs/
    lang/                    # 語言規則設定
      swift.conf
      kotlin.conf
      objc.conf
  tests/
    e2e/                     # E2E 測試
    fixtures/                # 測試夾具
    helpers.bash             # 測試 helper
  docs/                      # 文件
  README.md
  LICENSE
```

#### 目標 Codebase 中的使用

當 SourceAtlas 工具被應用到任意 codebase 時：

```text
${TARGET_CODEBASE}/          # 目標 codebase 根目錄
  src/                       # 原有程式碼
  docs/                      # 原有文件
  .sourceatlas/              # SourceAtlas 產出目錄（由工具建立）
    sourceatlas.index.jsonl
    sourceatlas.symbols.tsv
    sourceatlas.stats.json
    sourceatlas.manifest.json
  .gitignore                 # 應加入 .sourceatlas/
```

#### 安裝與使用模式

1. **系統安裝模式**：
   - `brew install sourceatlas` 或類似包管理器安裝
   - 工具安裝到 `/usr/local/bin/sourceatlas`
   - 在任意目錄執行 `satlas run`

2. **獨立執行檔模式**：
   - 下載單一執行檔到任意位置
   - `./sourceatlas run --root /path/to/target-codebase`
   - 或使用別名：`./satlas run --root /path/to/target-codebase`

3. **開發模式**：
   - Clone SourceAtlas repo
   - 直接執行 `./bin/sourceatlas run --root /path/to/target-codebase`
   - 或使用別名：`./bin/satlas run --root /path/to/target-codebase`

## 11. 執行流程（實作建議）

1. 走訪指定的 codebase 根目錄（可配置），依排除規則過濾。
2. 依語言以正則抽取：匯入、頂層符號（含可見性、行號範圍）、可能進入點。
3. 套用角色/重要度啟發式。
4. 寫入 JSONL 一行一檔，另行產出反向符號表與統計摘要（如開啟）。
5. 基本校驗：檔案數、語言分佈、隨機抽樣 30 檔人工檢核。

## 12. 後續擴充（非本版必做）

- 交叉引用（who-calls-who）與 `referenced_by` 索引。
- Xcode 專案/Gradle 模組關聯解析，補齊 `build_targets`。
- Git 資訊（僅查詢指令）補強 `last_modified_utc`、作者等。

## 13. JSONL 範例（精簡）

```json
{"repo":"SourceAtlas","path":"ios-module/Sources/App/AppDelegate.swift","file_name":"AppDelegate.swift","ext":".swift","lang":"swift","size_bytes":1234,"loc":85,"roles":["AppLifecycle"],"summary":"iOS 啟動與生命週期掛鉤","imports":["UIKit"],"symbols":[{"name":"AppDelegate","kind":"class","visibility":"internal","line_start":12,"line_end":80}],"entry_points":["UIApplicationMain"],"exported_symbols":["AppDelegate"],"dependencies":["CoreModule"],"platforms":["iOS"],"build_targets":["ios-module"],"importance_score":0.82,"tags":["bootstrap"],"last_modified_utc":"2025-09-01T03:11:22Z","content_hash":"sha256:..."}
```

## 14. 成功指標

- Q&A 檔案定位平均時間顯著下降（以內部測試任務量化）。
- 首次建立索引可於合理時間內完成（以專案體量與硬體計算）。
- 產出檔可被 LLM 持續重用（除非檔案改動需重建）。

## 15. 分片化設計與 Root Manifest

- 目的：避免單檔超過 context window，支援精準載入。
- Root Manifest（`sourceatlas.manifest.json`）範例：

```json
{
  "version": 1,
  "generated_at": "2025-09-01T03:20:00Z",
  "repo": "SourceAtlas",
  "shards": [
    { "id": "ios-module-core", "path": "sourceatlas.index.ios-module-core.jsonl.zst", "files": 1240, "lang": ["swift"], "hash": "sha256:..." },
    { "id": "android-core", "path": "sourceatlas.index.android-core.jsonl.zst", "files": 980,  "lang": ["kotlin"], "hash": "sha256:..." },
    { "id": "scripts",    "path": "sourceatlas.index.scripts.jsonl.zst",    "files": 60,   "lang": ["rb","sh","py"], "hash": "sha256:..." }
  ],
  "shard_rules": {
    "by_dir": [
      { "prefix": "ios-module/", "shard": "ios-module-core" },
      { "prefix": "android-module/", "shard": "android-core" },
      { "prefix": "ci-", "shard": "scripts" }
    ]
  }
}
```

- 生成規則：依 Module/Directory 分片；每片使用 `jsonl + zstd` 壓縮；Manifest 記錄 hash、檔數、語言、路徑。

## 16. 片段服務 API（On-demand Segment）

- 介面（本地工具或簡易服務）：
  - `get_file_index(path) -> { symbols:[...], loc:number }`
  - `get_segment(path, start, end, pad=10) -> { path, start, end, text }`
- 原則：僅傳回必要行段並自動附加 `pad` 行上下文，限制單次最大行數（如 400 行）。

## 17. 逐步檢索協議（Progressive Retrieval）

1. 問題 → 讀 Root Manifest → 選最可能分片（K shards）。
2. 掃 `symbols.tsv/roles.tsv` → 得到檔案候選（K files）。
3. 讀檔內 `symbols` → 鎖定符號/行段（M symbols）。
4. `get_segment` 抓取小片段；不足再逐步擴大範圍。
5. 每輪限制：最多分片 K、最多檔案 N、最多段落行數 X。

## 18. 嵌入檢索（可選強化）

- 本地向量庫：`SQLite + VSS` 或 `Faiss`，欄位：`repo, path, content_hash, lang, summary_embedding, symbol_embedding`。
- 檢索流程：先向量召回前 K 檔/符號，再回源抓行段；持續與傳統關鍵字檢索並用。
- 增量更新：以 `content_hash` 判斷是否需重建嵌入。

## 19. 低 Token DSL 與壓縮策略

- 供 LLM 輸入的精簡格式（替代 JSON），例如：

```text
FILE path=ios-module/Sources/App/AppDelegate.swift lang=swift roles=AppLifecycle;DI-EntryPoint loc=85
SYM name=AppDelegate kind=class vis=internal s=12 e=80
SYM name=application(_:didFinishLaunchingWithOptions:) kind=func vis=internal s=25 e=45
```

- 索引儲存仍用 JSONL；僅在 Prompt 時轉換為 DSL，降低 token。

## 20. 節流與配額規則

- 每輪最多載入：分片 K=3、檔案 N=20、每段最大行數 X=400。
- 強制引用：所有片段以 `path:start-end` 註明，利於快取與重播。
- 快取策略：最近使用的分片與片段本機快取，命中後不再重取。

## 21. 跨 Repo 命名與路徑慣例

- 統一 URI：`repo://${PROJECT_ROOT}/ios-module/...`、`repo://${OTHER_PROJECT}/${MODULE_NAME}/...`。
- Manifest 層維護多 repo 清單與各自分片位置；Agent 先讀全域 manifest 再選 repo。

## 22. 規格常數（預設值，可環境變數覆蓋）

- 分片與容量
  - 單片最大大小：2 MB（壓縮後，`zstd -3`）
  - 單片最大記錄數：10,000 筆
  - 微檔案聚合門檻：< 20 LOC 併入群組
  - 檔案最小欄位集合：`repo,path,file_name,ext,lang,size_bytes,loc,roles,summary,imports,symbols[],importance_score,content_hash`

- 逐步檢索上限（每輪）
  - 分片 K = 3
  - 檔案 N = 20
  - 片段行數 X = 400（`get_segment` 會自動 `pad=10`）
  - 符號數 M 每檔上限 = 5（重要度排序）

- 欄位精簡與裁剪
  - `summary` 最長 120 chars（超出截斷）
  - `imports` Top-5、`roles` Top-3、`tags` Top-5
  - 省略 `line_end` 時允許延後查詢補齊
  - 浮點欄位以整數 ×1000 儲存（如 `importance_score`）

- 格式與壓縮
  - 主索引：`sourceatlas.index.*.jsonl.zst`（分片）
  - 倒排表：`sourceatlas.symbols.tsv.zst`、`roles.tsv.zst`
  - 統計：`sourceatlas.stats.json`
  - Root Manifest：`sourceatlas.manifest.json`

- ID 與雜湊
  - `content_hash`: `sha256(file_bytes)`
  - `file_id`: `sha1(repo + ":" + path)`
  - `symbol_id`: `sha1(file_id + ":" + canonical_signature)`
  - `schema_version`: 1

- LLM 專用 DSL（鍵縮寫）
  - `F`=File, `SYM`=Symbol, `p`=path, `l`=lang, `r`=roles, `loc`=lines, `k`=kind, `v`=vis, `s`=start, `e`=end
  - 範例：

```text
F p=ios-module/Sources/App/AppDelegate.swift l=sw r=AppLifecycle;DI loc=85
SYM name=AppDelegate k=class v=int s=12 e=80
```

- 嵌入與節流
  - 向量維度=256、精度=int8（量化）
  - 檢索 Top-K：K=50（第一階段），回源再縮至 K=10 取段
  - 每分鐘最大 `get_segment` 次數：60（本地可放寬）

- 版本與驗收
  - 覆蓋率：≥ 95% 可讀檔案有索引
  - 問答回憶率：抽測 10 類問題，命中正確檔案 ≥ 90%
  - 生成時長：在 CI 節點 4C/8G 下 ≤ 10 分鐘（中型專案體量）

## 23. CLI 需求（零或近零相依）

- 核心命令
  - `init`：產生預設設定與排除清單
  - `run`：掃描→索引→分片→symbols→stats→manifest 一條龍
  - `scan`：輸出主索引 JSONL
  - `shard`：依目錄/語言切分片並產生 Root Manifest
  - `symbols`：生成/更新 `sourceatlas.symbols.tsv`
  - `stats`：輸出 `sourceatlas.stats.json`
  - `manifest`：產生/更新 `sourceatlas.manifest.json`
  - `delta`：增量更新（依 mtime/hash）
  - `query`：關鍵字/正則搜尋（symbol/role/path/lang）
  - `segment`：輸出 `path:start-end` 行段（支援 `pad`）
  - `export-dsl`：將候選輸出為低 token DSL
  - `verify`：一致性與完整性檢查
  - `clean`：清理輸出
  - `version`：顯示版本與 schema

- 主要旗標（跨命令）
  - `--root`、`--out`、`--include`、`--exclude`、`--langs`
  - `--shard-max-bytes`、`--shard-max-records`、`--limits`
  - `--compress/--no-compress`、`--threads`、`--quiet/--verbose`、`--dry-run`

- 無外部相依設計
  - 僅使用 POSIX 工具：`find`、`grep`、`sed`、`awk`、`sort`、`wc`、`cut`、`tr`
  - hash：優先 `sha256sum`，其次 `shasum -a 256`，再次 `openssl dgst -sha256`
  - 壓縮：預設 `gzip`；缺少時退回純文本
  - 併行：`xargs -P`

- 輸出與格式
  - `sourceatlas.index.[shard].jsonl[.gz]`
  - `sourceatlas.symbols.tsv[.gz]`
  - `sourceatlas.stats.json`
  - `sourceatlas.manifest.json`
  - `export-dsl`：單行 DSL

- 符號抽取（正則）
  - Swift：`class|struct|enum|protocol|extension|actor|func`
  - ObjC：`@interface`、`@implementation`、`-`/`+` 方法、`@property`
  - Kotlin：`class|object|interface|fun`
  - 其他：`class|module|def`（rb/sh/py）

- 增量與上限
  - 依 `content_hash`/mtime 重建變更檔
  - 使用第 22 章的上限常數（K/N/X/M、大小/筆數）

- 操作體驗
  - `satlas run --root . --out sourceatlas-output/`
  - `--dry-run` 提供將寫檔與大小估算
  - 失敗可重試：以 manifest 為準，續寫不破壞

## 24. 驗證方法（先測再優化）

- 指標
  - Hit@K（K=1/3/5）、MRR、Precision@K、Recall@K
  - Median/95p 查詢時間（提問→候選檔案）
  - Token/Bytes 載入量（估 4 chars/Token）
  - 覆蓋率（索引含有的可讀檔案比例）
  - 假陽性率（誤導候選比例）

- 測試集
  - 30–50 條真實問題（跨 iOS/Android/共用/腳本/設定）
  - 每題 ground truth：檔案路徑正則、可選符號名/行段

- 階梯式驗證
  - 階段 0 Baseline：無索引（IDE/grep）
  - 階段 1 Index：僅 `sourceatlas.index.jsonl`（roles/summary/imports/path 檢索）
  - 階段 2 Symbols：加入 `symbols.tsv`（符號/行段檢索）
  - 階段 3 Shard/DSL：僅在效能或 Token 超標時啟用
  - 階段 4 Embedding：僅在語意召回不足時啟用

- 決策閘（升級條件）
  - Gate A 覆蓋 < 95%：先修掃描規則
  - Gate B Hit@5 < 80%：強化 roles/summary；仍不行→加 symbols.tsv
  - Gate C Median > 3s 或 Token > 8k：啟用分片與 DSL
  - Gate D 語意召回差：啟用嵌入檢索
  - Gate E 假陽性 > 20%：調整排序與過濾

- 量測流程
  1. 準備 `queries.tsv` 與 `truth.tsv`（25–50 題）
  2. 跑 baseline（人工/grep）收時間與命中
  3. 生成階段 1 索引，跑 runner 計 Hit@K、MRR、時間、Token
  4. 若未達標依 Gate 升級下一階段並重測
  5. 固化最小可行組合，記錄結果與設定

- Runner 檔案格式
  - `queries.tsv` 欄位：`id\tquestion\ttags`
  - `truth.tsv` 欄位：`id\tpath_regex\tsymbol_regex?\tline_start?\tline_end?`
  - 輸出報表：`report.json`（整體指標）與 `report.tsv`（逐題結果）

## 25. 工具選型（輕量優先）

- 選擇：Universal Ctags + ripgrep + `satlas.sh` 薄殼（POSIX）
  - 理由：
    - 跨語言符號支援（Kotlin/Swift/ObjC/Java/TS/JS/Python）
    - 低相依、可在 macOS/Linux 直接執行
    - 易於輸出 JSONL/TSV 與我們的 DSL，符合 PRD 指標與驗證流程
  - 使用方式（概念）：
    - `ctags -R --fields=+n --languages=Swift,Kotlin,Java,JavaScript,TypeScript,Python,ObjectiveC -f tags` 產生符號索引
    - `rg --json`/`rg -n` 抽取 imports/roles/路徑特徵
    - `satlas.sh scan|symbols|stats|manifest` 組裝為 JSONL/TSV/JSON
  - 風險/限制：
    - 語意層級有限（非 AST/LSIF）；不足時再升級（見第 24 章 Gate D）
    - 需維護部分正則與角色啟發式

## 26. 使用情境（context window 受限）

- 功能已存在避免重做：以 `roles/symbols` 找既有實作位置
- 變更傳播：介面/協議、資料模型、匯入/依賴變動的受影響檔案
- 重構影響面：以 `symbols.tsv` 與 `imports` 快速列出影響清單
- 平台升版/Deprecation：定位危險 API 與替代實作檔案
- 特徵旗標/死碼清理：條件分支與可移除碼位點
- 設定與權限：plist/Gradle 改動對應的程式碼使用點
- 日誌/可觀測性一致化：全專案 Logger/Tracer 使用點
- 本地化資源：i18n key 與對應使用點
- 資產/主題：字型/色票/圖片引用
- CI/CD 腳本：路徑依賴與產物引用
- 安全/合規：Auth/支付等敏感流程入口與保護點
- 崩潰對位：符號→檔案→行段快速定位
- 跨 repo 影響：核心模組變更對 ${PROJECT_ROOT}/${OTHER_PROJECT} 的影響面

### 26.1 語言無關化（Language-agnostic）設計

- 語言偵測：以副檔名為主（可覆蓋 `--langs`），未知語言走基本檔案屬性索引
- 符號抽取：優先 ctags；若不支援語言則僅輸出檔案層（roles/summary/imports 可能為空）
- 通用欄位：`repo,path,file_name,ext,lang,size_bytes,loc,roles,summary,imports,symbols[]` 適用所有語言
- 可插拔規則：roles/imports/符號正則以語言設定檔覆蓋（`configs/lang/*.conf`），不需改程式
- 保守退化：遇到解析錯誤時仍產生最小索引物件，避免因單一語言阻斷整體生成
- 測試集覆蓋：queries 按語言標籤（swift/kt/py/js/ts/java/objc/other）做分層指標

## 27. 架構決策（ADR 摘要）

- ADR-001：採用 Universal Ctags + ripgrep + `satlas.sh` 薄殼
  - 決策：以低相依 CLI 為主，先滿足 Index+Symbols 的最小可行需求
  - 理由：快速落地、跨語言、易維護；可與驗證門檻（Gate）配合逐步升級
  - 取捨：語意不足（非 AST/LSIF）先不解；必要時依第 24 章 Gate D 再導入嵌入/更重工具

- ADR-002：索引格式選擇 JSONL/TSV 與簡潔 DSL
  - 決策：儲存用 JSONL/TSV，LLM 輸入用 DSL 降 token
  - 理由：機器友好、易 diff、易分片；Prompt 時節省 token

- ADR-003：逐步檢索流程與節流上限（K/N/X/M）
  - 決策：強制每輪上限，先檔→符號→片段，漸進擴大
  - 理由：控制 context 使用量與延遲，提升可靠度

- ADR-004：先不做 AST/語意圖譜
  - 決策：以正則抽取頂層符號，先驗證 Hit@K 與用時
  - 理由：避免早期過度設計，結果驅動的擴充

## 28. 風險與技術債

- 語意召回不足：複雜語意查詢可能 miss；以 Gate D 控制是否導入嵌入檢索
- 正則維護成本：多語言規則需維護；以驗證指標驅動調整與覆蓋率檢查
- 大型專案 I/O 時間：以分片與增量（delta）降低全量重建成本
- LLM 載入超標：以 DSL 與逐步檢索限制一次載入；必要再分片更細
- 多 repo 同步：以全域 manifest 與 URI 命名管理；需制定更新流程
- 操作溯源困難：複雜處理流程中問題定位困難；需建立完整可觀測性系統
- 故障恢復能力：批次處理中斷後難以恢復；需要狀態機和檢查點機制

## 29. 詞彙表

- JSONL：一行一物件的 JSON 格式，適合大型流式處理
- TSV：Tab 分隔值的純文字表格格式
- DSL（此專案）：供 LLM 使用的低 token 單行表示（F/SYM 等鍵）
- Shard（分片）：將索引按目錄/語言等規則切成多檔，便於載入與更新
- Root Manifest：分片的目錄檔，含版本、hash、大小、語言與路徑
- Symbols：頂層可導覽的宣告（class/struct/func 等），附行號範圍
- Roles：依檔名/路徑/符號啟發式推論的檔案角色（ViewModel/Repository…）
- Entry Points：程式入口（@main、AppDelegate、Application/Activity 等）
- Segment：以 `path:start-end` 指定的原始碼片段（可含 pad）
- K/N/X/M：逐步檢索上限（分片/檔案/行數/符號數）
- Hit@K、MRR：常用檢索品質指標

## 30. 增量索引（Delta）

- 變更偵測
  - 先以 mtime + size 篩選候選，再計算 `sha256(file_bytes)` 與索引內 `content_hash` 比對
  - 可選：若存在 Git，支援 `git diff --name-only <base>` 作為候選清單

- 分片局部重建
  - Root manifest 記錄每片檔名/檔數/hash/語言；僅重建包含 changed/added/removed 檔案的分片
  - 分片大小：遵循第 22 章上限（≤ 2MB 壓縮或 ≤ 10k 記錄）以利局部更新

- JSONL/TSV 輸出策略
  - 以檔路徑排序整片重寫，確保 deterministic 與簡化合併
  - `symbols.tsv` 可採多分片輸出（依目錄或語言），僅重建受影響分段

- CLI 行為（delta）
  - `satlas delta --root . --out ...`：
    - 掃描候選 → 驗證 hash → 列出 changed/added/removed
    - 重建相應分片與對應的 symbols/roles 段
    - 更新 `sourceatlas.stats.json` 與 `sourceatlas.manifest.json`
    - 產出 `delta.report.json`（變更數、重建片、耗時）
  - `satlas run` 預設先嘗試 delta；加 `--full` 才執行全量

- 安全網與回退
  - 若變更比例 > 30% 或跨越過多分片，建議自動回退全量（旗標可覆蓋）
  - 任何錯誤支援以 manifest 回滾到前一版本

## 31. 任務管理規則（完成勾選與日期確認）

- 規則：任何任務或步驟在勾選為完成時，必須同時附上完成日期時間。
  - 日期格式：`YYYY-MM-DD HH:mm`，時區一律使用 UTC+8。
  - 變更流程：因日期可能填寫或推斷錯誤，變更完成日期或完成狀態前，需先提出變更申請並由負責人（你）明確確認後，才可正式寫入。
  - 實務建議：在 `task.md` 的「變更與完成記錄」區塊維持一致格式，利於追蹤與審計。

範例（示意）：

```text
- [x] Phase 1 完成（完成：2025-09-02 10:15 UTC+8）
- [x] Step 1.3 `saltas scan` 基本索引輸出測試（完成：2025-09-01 18:30 UTC+8）
```

## 32. 可觀測性與溯源設計

### 32.1 設計原則

- **可觀測性優先**：每個操作都可追蹤、可審計、可重現
- **事件驅動架構**：所有重要操作發出結構化事件
- **狀態機模式**：文件處理採用明確狀態轉換，支援恢復
- **故障自愈**：Circuit breaker 模式，自動重試和降級
- **時間旅行**：完整快照和狀態恢復能力

### 32.2 事件記錄系統

```text
.sourceatlas/
  events.jsonl          # 結構化事件流 (OpenTelemetry 相容)
  audit.log            # 人類可讀的操作日誌
  state.db             # 狀態機當前狀態
  snapshots/           # 處理快照目錄
    snapshot_YYYYMMDD_HHMMSS_PID/
      environment.txt
      shell_variables.txt  
      *.jsonl           # 檔案狀態快照
  lineage.jsonl        # 資料血緣追蹤
  metrics_history.jsonl # 效能歷史資料
```

### 32.3 事件架構

每個事件包含：
- `timestamp`: ISO8601 時間戳
- `trace_id`: 分散式追蹤 ID (UUID)
- `span_id`: 當前操作 ID
- `parent_span_id`: 父操作 ID
- `type`: 事件類型 (file_processing_started, operation_failed, etc.)
- `data`: 事件具體資料 (JSON)
- `metadata`: 環境資訊 (host, user, pwd)

### 32.4 狀態機設計

文件處理狀態：
- `INIT` → `VALIDATE` → `EXTRACT_METADATA` → `EXTRACT_SYMBOLS` → `GENERATE_SUMMARY` → `COMPLETE`
- 每個狀態轉換都記錄事件
- 失敗狀態支援重試或跳過
- 支援從任意狀態恢復處理

### 32.5 除錯介面

- **即時監控**：`satlas monitor` 顯示當前處理狀態
- **事件查詢**：`satlas events --trace-id UUID` 查看完整調用鏈
- **快照管理**：`satlas snapshot create/restore/list`
- **效能分析**：`satlas profile` 顯示瓶頸分析
- **健康檢查**：`satlas health` 檢查系統狀態

### 32.6 預測性監控

- 基於歷史資料建立效能基線
- 3-sigma 規則檢測異常 (處理時間、記憶體使用)
- 自動觸發深度除錯當檢測到異常
- 效能回歸警報和自動降級

## 33. 開發與部署約束（獨立工具架構）

### SourceAtlas 工具專案的開發約束

開發 SourceAtlas 工具本身時的檔案組織原則：

- **工具專案根目錄結構**：
  - `bin/satlas`：CLI 主執行檔
  - `lib/**`：核心函式庫與語言解析器
  - `configs/**`：語言規則與設定檔
  - `tests/**`：測試程式碼與夾具
  - `docs/**`：文件

- **開發時寫入約束**：

```text
SourceAtlas 工具專案允許寫入：
- bin/**
- lib/**
- configs/**
- tests/**
- docs/**
- README.md, LICENSE, Makefile

不允許：
- 在目標 codebase 中建立工具原始碼
```

### 目標 Codebase 使用約束

當 SourceAtlas 被應用到目標 codebase 時：

- **僅允許建立輸出目錄**：
  - `.sourceatlas/`：索引與報表輸出（應加入目標專案的 `.gitignore`）

- **不修改目標 codebase**：
  - 工具不得在目標 codebase 中建立配置檔
  - 工具不得修改目標 codebase 的任何原有檔案
  - 僅讀取目標 codebase 內容進行索引

### 配置與自訂

- **系統級配置**：`~/.config/sourceatlas/config.toml`（可選）
- **專案級配置**：`.sourceatlas/config.toml`（可選，工具自動產生）
- **命令列參數優先**：所有配置都可被命令列參數覆蓋
