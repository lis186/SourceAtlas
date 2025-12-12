# SourceAtlas 開發歷史

> 快速索引：本檔案提供**時間線視角**，每個事件 2-3 行 + 詳細連結

---

## 2025-12（當前月份）

### Week 2 (12/12): v2.9.0 Release - Dependency Analysis ⭐⭐⭐⭐⭐

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

**最後更新**: 2025-12-06 (v2.8.1)
