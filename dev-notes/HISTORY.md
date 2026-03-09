# SourceAtlas 開發歷史

> 快速索引：本檔案提供**時間線視角**，每個事件 2-3 行 + 詳細連結

---

## 2026-03（當前月份）

### Week 1 (03/09): Rename /atlas.clear → /atlas.reset

**🐛 指令衝突修正 - /atlas.reset** (03/09):
- **問題**: `/atlas.clear` 與 Claude Code 內建 `/clear`（清除對話歷史）命名衝突
- **解法**: 全面改名為 `/atlas.reset`，修正 13 個檔案
- **影響**: plugin/commands, .claude/commands, README, USAGE_GUIDE 全部同步
→ [實作筆記](./2026-03/2026-03-09-atlas-reset-rename.md)

---

## 2026-01

### Week 2 (01/14): Progressive Disclosure Architecture ⭐⭐⭐⭐⭐

**🎯 SKILL.md 大重構 - PDA 實作完成** (01/14):
- **核心變更**: 5 個 commands 全面重構，符合 Claude Code 官方最佳實踐
- **Token 節省**: 3,440 → 1,496 行 (-57%)，~37,500 → ~11,343 tokens (-70%)
- **檔案結構**: SKILL.md (概覽) + 4 支持檔案 (workflow.md, output-template.md, verification-guide.md, reference.md)
- **品質指標**: 100% 連結完整性，100% 格式規範，5/5 測試通過
→ [驗證報告](./2026-01-14-skill-pda-validation.md)

**重構成果詳情**:
- **impact**: 912 → 195 行 (-79%)
- **deps**: 738 → 294 行 (-60%)
- **history**: 631 → 325 行 (-48%)
- **pattern**: 604 → 363 行 (-40%)
- **overview**: 555 → 319 行 (-43%)
- **支持檔案**: 20 個新建，7,992 行（按需載入）
→ [驗證報告](./2026-01-14-skill-pda-validation.md)

**Progressive Disclosure 優勢**:
- **可讀性**: 2/5 → 5/5 (+3)
- **導航性**: 2/5 → 5/5 (+3)
- **維護性**: 2/5 → 5/5 (+3)
- **學習曲線**: 3/5 → 4/5 (+1)

**OpenSkills 跨平台考量** (01/14):
- **影響評估**: PDA 可能影響 Cursor/Gemini/Aider/Windsurf 用戶（如 AI agent 無法訪問支援檔案）
- **風險緩解**: SKILL.md 保留 80%+ 核心邏輯，添加用戶測試建議
- **處理方案**: CHANGELOG + README 添加注意事項，監控用戶反饋
→ [詳細分析](./2026-01/2026-01-14-pda-refactoring.md#openskills-跨平台考量)

---

### Week 1 (01/03): Default Persistence ⭐⭐⭐⭐

**🎯 v2.12.0 - Default Persistence** (01/03):
- **核心變更**: 移除 `--save`，所有命令默認自動存儲到 `.sourceatlas/`
- **影響範圍**: 6 個命令 (overview, pattern, flow, history, impact, deps)
- **棄用警告**: `--save` 仍可用但顯示 `⚠️ --save is deprecated, auto-save is now default`
- **靈感來源**: MCP vs Skills 社群討論 - Skills 的核心優勢是「硬碟暫存」
→ [Proposal](../proposals/default-persistence/README.md)

---

### Week 1 (01/01): Context 優化與分層架構 ⭐⭐⭐⭐⭐

**🎯 Context 大幅優化** (01/01):
- **Memory 精簡**: CLAUDE.md 從 12.9k → 839 tokens (93% 減少)
- **atlas.flow 分層**: 2,708 → 239 行 (91% 減少)，Tier 1-3 按需載入
- **新建 Skills**: `multi-approach.md`, `dev-notes-guide.md`, `pre-release.md`
→ [詳細記錄](./2026-01/2026-01-01-context-optimization-refactor.md)

**Dead Code 清理** (01/01):
- **刪除 5 個腳本**: benchmark.sh, compare-formats.sh, detect-project.sh (舊), history.sh, validate-constitution.sh
- **重新命名**: detect-project-enhanced.sh → detect-project.sh
- **新增 3 個模式**: Taint Analysis (12), Dead Code (13), Concurrency (14)
→ [詳細記錄](./2026-01/2026-01-01-context-optimization-refactor.md)

**atlas.flow v3.0 測試完成** (01/01-01/02):
- **測試專案**: TTCA-iOS (Swift), cal.com (TypeScript), Express.js (JavaScript)
- **通過率**: 15/15 (100%)
- **Dispatch 驗證**: Tier 1-3 全部正確
- **補充測試** (01/02): Permission Flow (cal.com PBAC), Flow Comparison (Express.js v5.2.0 vs v5.2.1)
→ [測試報告](./2026-01/2026-01-01-atlas-flow-test-results.md)

---

## 2025-12

### Week 3 (12/21): Benchmark + Scale Detection Fix ⭐⭐⭐⭐⭐

**🎯 SourceAtlas Benchmark 完成** (12/21):
- **測試專案**: Firefox iOS, Thunderbird Android, Cal.com, Prefect, Discourse
- **原始準確率**: 93.3% (56/60)，Scale 偵測僅 60%
- **問題診斷**: 門檻過於保守 (>150 files = VERY_LARGE)
- **修正後準確率**: Scale 100% (5/5)，預期整體 ~98%
→ [Benchmark 報告](../test_targets/test_results/benchmark-2025-12-21.md)

**Scale Detection v2.0** (12/21):
- **修正 1**: Swift 優先偵測（>50 Swift files → iOS，避免被 fastlane Gemfile 誤判）
- **修正 2**: 統計所有程式碼檔案（跨語言一致性）
- **修正 3**: 門檻調整（LARGE: 2K-10K, VERY_LARGE: >10K）
- **移除 LOC**: 跨語言不一致，改用純檔案數
→ [方法論文件](./2025-12/2025-12-21-scale-detection-methodology.md)

### Week 3 (12/20): Go + Rust + Ruby + AST Operations ⭐⭐⭐⭐⭐

**🎉 v2.9.6 發布** (12/20):
- **Tuist 支援**：新增 `Project.swift` 和 `Tuist/` 目錄偵測
- **新語法支援**：Swift 6、Python 3.12、Rust 2024
- **Bug Fixes**：Glob pattern、Swift ast-grep patterns、Rust macro
- **QA 測試**：30 個測試案例，100% 通過
- 11 個檔案更新（scripts + commands + docs）

**op_definition / op_import 實作完成** (12/20):
- 新增 2 個 AST 操作到 `ast-grep-search.sh`（8 個操作總計）
- `op_definition`: 精確定位函數/類別/結構體定義（7 語言支援）
- `op_import`: 提取 import 語句 + 可選模組過濾（7 語言支援）
- **關鍵發現**: AST 精確度 > grep 文字匹配（grep 有 False Positives）
- 驗證方法論學習：Ground Truth 本身需要驗證
→ [驗證報告](./2025-12/2025-12-20-ast-grep-definition-import-validation.md)

**Ruby op_definition UX 增強** (12/20):
- 新增 `category` 欄位：primary / library / concern / nested（基於 Rails 慣例）
- 新增 `--primary` 參數：只返回主要定義
- **關鍵修正**：Ruby class reopening 是合法語法，ast-grep 精確度 = 100%
- 原始框架錯誤：誤將 6 個結果當成 False Positives（實際是 UX 問題）
→ [驗證報告](./2025-12/2025-12-20-ast-grep-definition-import-validation.md)

**語言偵測增強** (12/20):
- **Glob 修復**：`[[ -d ]]` 中 glob 不展開，改用 `ls -d`
- **Tuist 支援**：新增 `Project.swift` 和 `Tuist/` 目錄偵測
- Swift 偵測現支援：SPM (`Package.swift`)、Xcode (`.xcodeproj/.xcworkspace`)、Tuist
- 測試通過：Swiftfin（有 Gemfile）正確偵測為 swift

**Swift ast-grep Pattern 修復** (12/20):
- **op_definition**：`class/struct/enum $name` 需要完整語法（`{ $$$ }` + 繼承）
- **op_type**：`$VAR: $type` 無效，改用 `var/let $NAME: $type`
- 移除無法解析的 `-> $type` pattern（CLI 參數衝突）
- 測試通過：definition、type、call、async、import 全部正常

**Swift 6 語法支援** (12/20):
- **op_definition**：新增 `consuming func` / `borrowing func` patterns
- **op_import**：新增 `public/internal/private import` patterns
- Noncopyable (`~Copyable`) 和 Typed Throws (`throws(Error)`) 自動相容
- 測試通過：Swift 6 新語法全部正確匹配

**多語言新版本語法支援** (12/20):
- **Python 3.12**：`class Name[T]:` generic class patterns
- **Rust 2024**：`async || {}` / `async move || {}` async closures
- **Go 1.22**：`for i := range N` 自動相容
- **Kotlin 2.1**：guard conditions 待 ast-grep 支援
- **Ruby 3.4**：`it` block parameter 自動相容

**Rust op_call Macro 支援** (12/20):
- **修復**：`println!`, `format!`, `vec!` 等巨集呼叫需要 `!` 語法
- 新增 pattern：`$func_name!($$$)` 匹配 Rust 巨集
- 測試通過：tokio 專案 println! 找到 65 個結果

**完整 QA 測試** (12/20):
- 30 個測試案例，100% 通過
- 覆蓋：語言偵測、8 個 AST 操作、新語法、JSON 格式、Edge Cases
- 測試腳本：`/tmp/ast-grep-full-test-v3.sh`

**Ruby/Rails 語言支援完成** (12/20):
- 26 個模式（model, controller, job, mailer, concern, spec 等）
- 測試專案：ruby-spree（~2000 個 Ruby 檔案）
→ 詳見 CLAUDE.md Multi-Language Pattern Support

**Go 語言支援完成** (12/20):
- 26 個模式（handler, service, middleware, transport, endpoint 等）
- 4 個測試專案：gin, go-kit, cobra, kratos
- 測試檔案：708 個 Go 檔案
→ 詳見 CLAUDE.md Multi-Language Pattern Support

**Rust 語言支援完成** (12/20):
- 28 個模式（lib, main, mod, error, config, handler, service, middleware, runtime 等）
- 4 個測試專案：actix-web, axum, ripgrep, tokio
- 測試檔案：1459 個 Rust 檔案
- **多語言支援總計**：7 語言、221 patterns
→ 詳見 CLAUDE.md Multi-Language Pattern Support

### Week 3 (12/19): Branded Output v2.9.5 + AI Collaboration Detection v2.9.4 ⭐⭐⭐⭐

**品牌識別輸出格式** (12/19):
- 統一 6 個分析命令的 Header/Footer 格式
- Header: `🗺️ SourceAtlas: [Command Name]` + 分隔線 + emoji + 目標 + 關鍵指標
- 命令專屬 Emoji: 🔭 overview, 🧩 pattern, 📜 history, 💥 impact, 🔀 flow, 📦 deps
- Footer: `🗺️ v2.9.5 │ Constitution v1.1`
- 設計決策: 30 字元分隔線（避免窄終端換行）、`│` 分隔符（美觀）
- 實作時間: ~1.5 小時，6 個命令檔案
→ [設計探索](../ideas/claude-code-plugins-learnings.md)

**AI 協作偵測增強** (12/19):
- 支援 12+ AI 開發工具偵測（原本僅 Claude Code + Cursor）
- Tier 1 高信心度：Claude Code, Cursor, Windsurf, GitHub Copilot, Cline/Roo, Aider, Continue.dev, JetBrains AI, AGENTS.md, Sourcegraph Cody, Replit, Ruler
- Tier 2 間接指標：註解密度 >15%, 程式碼一致性 >98%, Conventional Commits, 文件比例
- Level 0-4 定義更新：更精確的分級標準
- 輸出格式增強：新增 `tools_detected` 區塊
- **新增腳本**: `scripts/atlas/detect-ai-tools.sh` (~250 行)
- **測試驗證**: 5 個 GitHub 專案測試，100% 準確率
→ [實作記錄](./2025-12/2025-12-19-ai-collaboration-detection-enhancement.md)

### Week 3 (12/18): Progressive Disclosure for /atlas.pattern ⭐⭐⭐

**Progressive Disclosure 實作完成** (12/18):
- 智慧輸出模式：≤5 檔案直接分析，>5 檔案顯示選擇介面
- 新增參數：`--brief`（僅列清單）、`--full`（強制完整分析）
- 多方案驗證：5 個方案比較，選擇 Parameter-Based（加權分數 4.15/5）
- 測試通過：4/4 測試案例（model, router, config, unknown）
- GitButler 保留備選方案：`pd-v2-minimal`, `pd-v2-script`, `pd-v2-hybrid`, `pd-v2-config`
→ [實作報告](./2025-12/2025-12-18-progressive-disclosure-implementation.md)

### Week 2 (12/14): v2.9.2 Release - ast-grep Integration ⭐⭐⭐⭐

**ast-grep 整合完成** (12/14):
- 統一腳本架構：`scripts/atlas/ast-grep-search.sh`（~570 行）
- 6 種操作：`call`, `type`, `pattern`, `usage`, `async`, `boundary`
- 4 個命令整合：`/atlas.flow`, `/atlas.impact`, `/atlas.deps`, `/atlas.pattern`
- 多語言支援：Swift, TypeScript/TSX, Kotlin, Python
- Graceful degradation：`--fallback` 選項提供 grep 替代命令
- QA 測試：61 個測試案例，100% 通過率，Grade A (9.5/10)
- 誤判消除率：14-93%（依 pattern 類型）
→ [評估報告](./2025-12/2025-12-14-ast-grep-integration-evaluation.md)
→ [QA 驗證報告](./2025-12/2025-12-14-ast-grep-qa-validation-report.md)

**關鍵改進**:
| Pattern 類型 | Grep 準確率 | ast-grep 準確率 | 誤判消除 |
|--------------|------------|-----------------|----------|
| Swift async | 58% | 94% | 88% |
| TypeScript hook | 55% | 91% | 93% |
| Kotlin suspend | 60% | 93% | 51% |
| Kotlin data class | 85% | 100% | 15% |

**Plugin 同步** (12/14):
- 更新 4 個命令檔案到 plugin/commands/
- 版本更新：2.7.0 → 2.9.2
- CHANGELOG 新增 ast-grep 整合記錄

### Week 2 (12/12): v2.9.0 Release - Dependency Analysis ⭐⭐⭐⭐⭐

**Model 效能優化完成** (12/12):
- 各命令指定最適 Model，平衡速度與品質
- `/atlas.init`: Haiku（簡單文字注入）
- `/atlas.overview`, `pattern`, `history`, `impact`, `deps`: Sonnet（中等複雜度分析）
- `/atlas.flow`: Opus（複雜多層邏輯流追蹤）
- E2E 測試 100% 通過（7/7 命令）
- 預期效益：Haiku 成本 -70%、Sonnet 成本 -40%、品質維持高標準

**/atlas.deps 完整測試完成** (12/12):
- 4 個場景並行測試：iOS 16→17, Android API 35, Kotlin 純粹盤點, Flask 升級
- **整體準確率**: 100% (42/42 樣本驗證)
- **Phase 0 規則確認**: 100% 有效（Built-in rules + WebSearch 動態生成）
- **模式識別**: 100% 準確（正確區分升級 vs 盤點模式）
- **Constitution v1.1**: 100% 合規 (24/24 checks)
- **Production Ready**: ✅ 批准上線
→ [測試報告](./2025-12/2025-12-12-atlas-deps-testing-report.md)

**測試結果總覽**:
| 場景 | 規模 | 準確率 | Phase 0 | 評分 |
|------|------|--------|---------|------|
| iOS 16→17 (iOS App A) | 2,108 files | 100% (12/12) | ✅ Built-in | A+ (9.8/10) |
| Android API 35 (Android App B) | 303 files, 30 modules | 100% (15/15) | ✅ Built-in | A+ (10/10) |
| Kotlin coroutines 盤點 | 578 files, 1,509 imports | 100% | ✅ 正確跳過 | A+ (9.8/10) |
| Flask 升級 (Python App C) | 7 files | 100% (12/12) | ✅ WebSearch | A (9.8/10) |

**關鍵成功**:
- ✅ Phase 0 機制顯著提升穩定度（相比 /atlas.flow +5-10% 準確率）
- ✅ Multi-module Android 處理完美 (30/30 modules)
- ✅ 缺少依賴檔案 Robust 處理 (README.md + git history 推論)
- ✅ Edge case 偵測優秀 (Django+Flask 混用、unused imports)

### Week 2 (12/08): /atlas.deps 實作完成

**/atlas.deps 命令實作** (12/08):
- 新增 Phase 0 規則確認機制（升級規則預覽 + 使用者確認）
- Built-in rules: iOS 16→17, React 17→18, Python 3.11→3.12
- WebSearch/WebFetch 整合：動態查詢最新 migration guides
- 5 個輸出 sections：required_changes, modernization_opportunities, usage_summary, third_party_dependencies, summary
- 支援「純粹盤點」vs「升級」模式自動識別
→ [命令規格](./.claude/commands/atlas.deps.md)

### Week 1 (12/06): v2.8.1 Release - Handoffs 完成 ⭐⭐⭐⭐⭐

**Constitution v1.1 + Handoffs 原則完成** (12/06):
- 新增 Article VII: Handoffs 原則（5 個 Sections）
  - Section 7.1: 發現驅動
  - Section 7.2: 結束條件（4 種條件）
  - Section 7.3: 建議數量（Primary 必須，Secondary 可選）
  - Section 7.4: 參數品質（具體、非泛泛）
  - Section 7.5: 理由品質（引用具體發現）
- 更新所有 5 個 atlas 命令模板，引用 Constitution Article VII
- 測試：9 個專案 × 3 種開發者 = 27 個場景，95%+ 成熟度
→ 相關檔案：`ANALYSIS_CONSTITUTION.md`, `.claude/commands/atlas.*.md`

**測試結果**:
| 指標 | 結果 |
|------|------|
| 結束條件觸發率 | 100% |
| Secondary 省略率 | 33% (符合預期) |
| 參數品質 | 100% 具體 |
| 理由品質 | 100% 引用具體發現 |

### Week 1 (12/05): v2.8.0 Release - Constitution v1.0 ⭐⭐⭐⭐⭐

**Constitution v1.0 實作完成** (12/05):
- 學習 spec-kit 的 Constitution 模式，建立 SourceAtlas 分析憲法
- 7 個 Articles：資訊理論、排除原則、假設原則、證據原則、輸出原則、規模感知、修訂原則
- 驗證腳本：`validate-constitution.sh`（自動化合規檢查）
- 專案偵測增強：Monorepo 支援（lerna, pnpm, nx, turborepo, npm workspaces）
- 測試：18 個舊格式 TOON + 1 個新格式 YAML，品質改進 +3900% file:line 引用
→ [測試報告](./2025-12/2025-12-05-constitution-testing-report.md)
→ [品質比較](./2025-12/2025-12-05-constitution-quality-comparison-report.md)
→ [前後對比](./2025-12/2025-12-05-constitution-before-after-comparison.md)

**關鍵改進**:
| 指標 | Before | After | 改進 |
|------|--------|-------|------|
| file:line 引用 | 0.3 個 | 12 個 | +3900% |
| 驗證成本 | 手動審查 | 自動 1 秒 | -95% |
| 輸出行數 | 361 行 | 133 行 | -63% |
| 專案偵測成功率 | 83% | 100% | +17% |

### Week 1 (12/01): v2.7.0 Release - Flow 分析完成 ⭐⭐⭐⭐⭐

**`/atlas.flow` P0-A 準確性改善** (12/01):
- 語言專屬入口點偵測：Swift/iOS, TypeScript/React, Kotlin/Android, Python
- 增強邊界識別：6 → 10 類型（新增 AUTH, PAY, FILE, PUSH）
- 信心評分算法：區分高/低可信度識別結果
- 多 Agent 並行研究：5 個研究 Agent 同時進行
→ [實作記錄](./2025-12/2025-12-01-atlas-flow-p0a-implementation.md)

---

## 2025-11

### Week 5 (11/25-12/01): v2.6.0 Release - 時序分析完成 ⭐⭐⭐⭐⭐

**`/atlas.history` 命令完成** (11/30):
- 實作 Git 歷史時序分析命令（Hotspots, Coupling, Contributors）
- 整合 code-maat（自動安裝 + 環境配置）
- 智慧處理：Shallow Clone 偵測 + 一鍵修復
- 6 personas 多語言測試（iOS, Python, React, Android, Vue, Signal-iOS）
- 修復：SIGPIPE 導致的 "No data available" 誤報
- 核心輸出：變動熱點、隱藏依賴、知識分佈、Bus Factor 風險
→ 檔案：`scripts/atlas/history.sh`, `.claude/commands/atlas.history.md`

**`install-codemaat.sh` 安裝腳本** (11/30):
- **安裝前先詢問**：使用 AskUserQuestion 工具取得用戶許可，不會未經同意自動安裝
- 一鍵安裝 code-maat v1.0.4 到 `~/.sourceatlas/bin/`
- 自動檢測 Java 版本（需 8+）
- 自動配置環境變數（CODEMAAT_JAR）到 shell config
- 支援 `--check`（檢查狀態）、`--remove`（解除安裝）
- 支援 curl 或 wget 下載
→ 檔案：`scripts/install-codemaat.sh`

**TypeScript/React/Vue Patterns 擴展完成** (11/30):
- 完成 50 個 patterns（25 Tier 1 + 25 Tier 2），pattern 總數達 141
- **React Tier 1 (18)**: component, hook, context, hoc, error boundary, suspense, portal, lazy, ref, zustand, tanstack query, redux, framer motion, form hook, jest test, storybook, i18n, theme
- **Vue Tier 1 (7)**: sfc, composable, pinia, directive, plugin, provide inject, nuxt
- **React Tier 2 (14)**: middleware, server component, client component, route, loader, action, api route, server action, layout, page, recoil, jotai, swr, msw mock
- **Vue Tier 2 (11)**: router guard, transition, teleport, slot component, watcher, lifecycle, emit, prop, ref template, slot, test util
- 測試專案：Excalidraw, Mantine, Shadcn UI, Bulletproof React, Element Plus, VueUse, Naive UI
- 修復：Vue directive pattern（`v*.ts` 過於廣泛 → `*Directive.ts v-*.ts`）
- 修復：移除路徑型 patterns（`find -name` 不支援 `composables/*.ts`）

**Kotlin/Android Patterns 實作完成** (11/30):
- 完成 6 階段方法論驗證，8 個測試專案（5,237+ 檔案）
- 測試專案：8 個匿名 Android 專案（涵蓋 Clean Architecture, Circuit/MVI, MVVM, 生產級應用等）
- **31 個 patterns** 實作完成（12 Tier 1 + 19 Tier 2），95%+ 準確率
- 關鍵發現：Circuit library 使用 Presenter/Component 模式；生產級 App 需要 Factory/Provider/Contract 等更多 patterns
- 新增核心 patterns：`*Presenter.kt`, `*Component.kt`, `*UiState.kt`, `*Intent.kt`, `*Effect.kt`
- 新增生產級 patterns：`*Factory.kt`, `*Provider.kt`, `*Contract.kt`, `*Config.kt`, `*Validator.kt`, `*Parser.kt`, `*Formatter.kt`, `*Loader.kt`, `*Listener.kt`
→ [研究報告](./2025-11/2025-11-30-kotlin-android-research-report.md)
→ [實作報告](./2025-11/2025-11-30-kotlin-patterns-implementation-report.md)

**v2.5.3 Release Preparation** (11/30):
- Comprehensive testing of all 4 commands (90% pass rate)
- Plugin sync: Updated plugin/ to match .claude/commands/ (4 commands)
- PROMPTS.md update: Added v2.5 Commands section
- Version unification: All docs updated to v2.5.3
- Version renaming: v3.0 → v2.6 for future planning
- Script enhancement: detect-project-enhanced.sh now supports Android/iOS
→ [完整測試報告](./2025-11/2025-11-30-v252-comprehensive-testing.md)

**`/atlas.init` 命令完成 + 隱性觸發驗證** (11/30):
- 實作專案初始化命令，注入自動觸發規則到 CLAUDE.md
- 參考 [spec-kit](https://github.com/github/spec-kit) 設計模式
- 10 專案 × 3 開發者類型 並行測試，100% 準確率
- 命令重命名：`atlas-*` → `atlas.*`（dot-separated format）
- 核心命令數：3 → 4（init, overview, pattern, impact）
→ [完整實作記錄](./2025-11/2025-11-30-atlas-init-implementation.md)

**資深開發者查詢模式研究** (11/29):
- Signal/Android 專案深度分析
- 484 行 Android Architect 評估文檔
- 資深開發者查詢索引建立（266 行）
- 確認 `/atlas-find` 取消決策的正確性
→ [研究文檔](./2025-11/atlas-find-research/)

**重大決策：取消 `/atlas.find` 命令** (11/25):
- 執行 8 個開發者角色模擬（9 專案，80+ 查詢）
- 發現 70%+ 需求已被現有命令涵蓋
- 決策：聚焦完善 3 個核心命令，避免功能重疊
- Phase 3 轉向多語言擴展 + 測試 + 發布準備
→ [完整決策記錄](./2025-11/2025-11-25-atlas-find-cancellation-decision.md)

**Swift Analyzer 整合** (11/25):
- 開發 Swift/ObjC Deep Analyzer (7 sections, 482 lines)
- 語言分析覆蓋率：70% → 90%+ (+20%)
- 整合到 `/atlas.impact` 命令（自動觸發）
- 8 個 subagent 多使用者測試驗證
- 關鍵功能：Nullability (6% 覆蓋), @objc exposure (1,135 classes), Memory (112 unowned)
→ [完整實作記錄](./2025-11/2025-11-25-swift-analyzer-integration-implementation.md)

**測試與驗證完成** (11/25):
- 5 個真實場景測試：SwiftUI, Clean Arch, Swift/ObjC interop, Enterprise, API 變更
- 100% 測試成功率，92%+ 準確率
- 關鍵發現：Swift/ObjC nullability 風險檢測、API 變更跨團隊協調價值
- **重大決策**：移除自動時間估算（只提供客觀事實，由團隊自行判斷）
→ [完整測試報告](./2025-11/2025-11-25-atlas-impact-testing.md)

**命令實作** (11/25):
- 創建 `.claude/commands/atlas.impact.md`（557 行）
- 自適應類型檢測：API/MODEL/COMPONENT
- 完整 call chain 追蹤、breaking changes 識別
- Migration checklist 生成
→ [命令實作](../.claude/commands/atlas.impact.md)

### Week 4 (11/20-11/24): Patterns 系統全面優化 + 架構簡化

**命令架構簡化** (11/24):
- 版本號統一：產品版本 vs 文檔版本（清晰語意）
- 移除 `/atlas` 命令（避免與 `/atlas.overview` 混淆）
- code-maat 提案簡化：3→2 命令（移除 coupling 重複）
→ [完整決策](./2025-11/2025-11-24-atlas-command-simplification-decision.md)

**iOS Patterns 整合** (11/23):
- 34→29 patterns（-15%），消除 Architecture section 重複
- 合併 5 個重複 patterns（router/api-endpoint, service/networking等）
- 100% 向後相容，100% 測試通過
→ [完整報告](./2025-11/2025-11-23-ios-patterns.md)

**Objective-C 支援** (11/23):
- 擴充所有 29 iOS patterns 支援 .m/.h 檔案
- Category 語法支援（`*+*.m`）
- 測試 3 個混合專案：大型商業 App (55%), wikipedia-ios (18%), Signal-iOS (3%)
- 從遺漏 55% → 0% 遺漏
→ [完整報告](./2025-11/2025-11-23-objective-c-support.md)

**TypeScript Patterns 擴充** (11/23):
- 13→22 patterns (+69%)
- 新增 Next.js, React 專屬 patterns
- 完整測試驗證
→ [完整報告](./2025-11/2025-11-23-typescript-patterns.md)

**Patterns 系統審計** (11/23):
- 全面審計 3 語言 patterns
- 發現並修復重複和不一致
→ [審計報告](./2025-11/2025-11-23-patterns-audit.md)

### Week 3 (11/15-11/19): Atlas Pattern Command

**實作完成** (11/22):
- 完成 `/atlas.pattern` command
- 實作 `find-patterns.sh` 腳本（ultra-fast 版本）
- 多專案驗證：Swiftfin, Telegram, WordPress
→ [完整報告](./2025-11/2025-11-22-atlas-pattern.md)

### Week 3 (11/15-11/22): v1.0 完成與規劃

**v1.0 方法論驗證完成** (11/22):
- 5 專案驗證成功
- 資訊理論原則確立：<5% 掃描達 70-80% 理解
- 規模感知算法實作
- YAML 格式確定
- v1.0 → v2.5 規劃會議完成
→ [v1.0 實作日誌](./2025-11/2025-11-22-v1-implementation.md)

### Week 2 (11/08-11/14): 格式決策

**TOON vs YAML 決策** (11/20):
- 決定採用 YAML（標準 > 優化）
- Trade-off: +14% tokens 換取生態系統支援
→ [完整分析](./archives/decisions/2025-11-20-toon-vs-yaml.md)

---

## 🔑 關鍵里程碑

| 日期 | 事件 | 影響 | 連結 |
|------|------|------|------|
| 2025-12-06 | **Constitution v1.1 + Handoffs** | 發現驅動動態建議，95%+ 成熟度 | - |
| 2025-12-05 | **Constitution v1.0** | 品質框架，+3900% 證據精確度 | [詳細](./2025-12/2025-12-05-constitution-quality-comparison-report.md) |
| 2025-11-30 | TypeScript/React/Vue Patterns | 50 patterns, 141 total | - |
| 2025-11-30 | Kotlin/Android Patterns | 31 patterns, 8 專案驗證 | [詳細](./2025-11/2025-11-30-kotlin-patterns-implementation-report.md) |
| 2025-11-24 | 命令架構簡化 | 版本號統一、移除 `/atlas` | [詳細](./2025-11/2025-11-24-atlas-command-simplification-decision.md) |
| 2025-11-23 | Objective-C 支援 | 完整混合專案支援 | [詳細](./2025-11/2025-11-23-objective-c-support.md) |
| 2025-11-23 | iOS Patterns 整合 | 消除重複，架構優化 | [詳細](./2025-11/2025-11-23-ios-patterns.md) |
| 2025-11-22 | Atlas Pattern 實作 | v2.5 核心功能 | [詳細](./2025-11/2025-11-22-atlas-pattern.md) |
| 2025-11-22 | v1.0 完成 | 方法論驗證 | [詳細](./2025-11/2025-11-22-v1-implementation.md) |
| 2025-11-20 | TOON vs YAML 決策 | 格式標準確立 | [詳細](./archives/decisions/2025-11-20-toon-vs-yaml.md) |

---

## 統計總覽

### Patterns 總數（截至 2025-12-03, v2.7.0）
- **iOS/Swift**: 34 patterns（27 支援 Objective-C）
- **TypeScript/React/Vue**: 50 patterns（25 Tier 1 + 25 Tier 2）
- **Android/Kotlin**: 31 patterns（12 Tier 1 + 19 Tier 2）
- **Python**: 26 patterns（12 Tier 1 + 14 Tier 2）
- **總計**: 141 patterns ⭐

### Commands 總數（v2.7.0）
- `/atlas.init` - 專案初始化
- `/atlas.overview` - 專案指紋
- `/atlas.pattern` - 模式學習
- `/atlas.impact` - 影響分析
- `/atlas.history` - 時序分析
- `/atlas.flow` - 流程追蹤
- **總計**: 6 commands ⭐

### 測試專案
- **iOS**: 匿名 iOS 專案（包含混合 Swift/ObjC 專案）
- **TypeScript/React**: 匿名前端專案（包含 UI 組件庫、畫布應用、最佳實踐範例等，7 專案）
- **Vue**: 匿名 Vue 專案（包含企業級 UI 組件、Utility Composables 等）
- **Android**: 8 個匿名 Android 專案（包含 Clean Architecture, Circuit/MVI, MVVM, 生產級應用等）
- **Python**: 匿名 Python 專案（包含 Django, FastAPI, Flask 等框架，10 專案）

---

**最後更新**: 2025-12-19 (v2.9.5)
