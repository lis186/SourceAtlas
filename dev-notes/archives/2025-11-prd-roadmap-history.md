## 11. 實作路線圖

### v2.5.3 - Python Patterns ✅

**目標**：Python 生態系統完整支援

**狀態**：已完成 (2025-11-30)

**成果**：
- ✅ 26 個 Python patterns（12 Tier 1 + 14 Tier 2）
- ✅ 10 個專案測試（Django, FastAPI, Flask, Celery, Scrapy, Pydantic, SQLAlchemy, Starlette, httpx, cookiecutter-django）
- ✅ 框架覆蓋：Django, FastAPI, Flask, Celery, Scrapy, Pydantic, SQLAlchemy, Starlette

---

### v2.5.4 - TypeScript/React/Vue Patterns ✅

**目標**：前端生態系統完整支援（React、Vue、Next.js、Nuxt）

**狀態**：已完成 (2025-11-30)

**成果**：
- ✅ 50 個 TypeScript/React/Vue patterns（25 Tier 1 + 25 Tier 2）
- ✅ 7+ 個前端專案測試
- ✅ 框架覆蓋：React, Vue, Next.js, Nuxt, Zustand, Pinia, TanStack Query, Framer Motion

#### React Tier 1 Patterns（18 個）✅

| Pattern | 別名 | 用途 |
|---------|------|------|
| React Component | component | 組件定義 |
| React Hook | hook, hooks, custom hook | 自訂 Hook |
| State Management | store, state, zustand, redux | 狀態管理 |
| API Endpoint | api, endpoint, trpc | API 端點 |
| Authentication | auth, login | 身份驗證 |
| Form Handling | form, react hook form, zod | 表單處理 |
| Database Query | database, query, prisma | 資料庫查詢 |
| Networking | network, http client, fetch, axios | 網路請求 |
| Next.js Page | page | 頁面路由 |
| Next.js Layout | layout | 佈局組件 |
| React Query | tanstack query, data fetching, swr | 資料獲取 |
| React Context | context api | Context 狀態 |
| HOC | higher order component | 高階組件 |
| Error Boundary | boundary | 錯誤邊界 |
| Suspense | fallback | Suspense 組件 |
| Portal | modal, dialog | Portal/Modal |
| Ref | forward ref, imperative handle | Ref 處理 |
| Memo | memoization, performance | 效能優化 |

#### Vue Tier 1 Patterns（7 個）✅

| Pattern | 別名 | 用途 |
|---------|------|------|
| Vue Component | sfc, vue | SFC 組件 |
| Composable | composition, vue hook | Composition API |
| Pinia | pinia store, vue store | 狀態管理 |
| Vue Router | vue routes, router | 路由管理 |
| Directive | directives, vue directive | 指令 |
| Vue Plugin | plugin, plugins | 插件 |
| Provide/Inject | provide, inject | 依賴注入 |

#### Tier 2 補充 Patterns（25 個）✅

**React Tier 2（14 個）**：
- Next.js Middleware, Loading, Error
- Server Components, Server Actions
- Background Job, File Upload
- Test (Vitest/Jest), Theme/Styling
- Animation (Framer Motion)
- i18n, Validation (Zod/Yup), tRPC

**Vue Tier 2（11 個）**：
- Nuxt Page, Layout, Middleware, Plugin, Composable
- Vue Transition, Mixin, Filter
- Vue Test, i18n, Router Guard

#### 測試專案 ✅

| 專案 | 類型 | 特色 |
|------|------|------|
| Excalidraw | React | 畫布應用、豐富 Hooks |
| Mantine | React | UI 組件庫、完整 Hooks |
| Shadcn UI | React | 現代 UI 組件 |
| Bulletproof React | React | 最佳實踐範例 |
| Element Plus | Vue | 企業級 UI 組件 |
| VueUse | Vue | Utility Composables |
| Naive UI | Vue | 現代 UI 組件 |

#### 成功指標 ✅
- [x] React patterns 覆蓋率 >90%（常見專案）
- [x] Vue patterns 覆蓋率 >85%（常見專案）
- [x] 準確率 >90%（無大量誤報）
- [x] 7+ 專案驗證

---

### v2.6.0 - `/atlas.history` 時序分析 ✅ (已完成)

**目標**：Git 歷史時序分析，專為 Legacy Codebase 接手者設計

**狀態**：✅ 完成（2025-11-30）

**實作成果**：
- 核心腳本：`scripts/atlas/history.sh`
- 命令定義：`.claude/commands/atlas.history.md`
- 自動安裝：`scripts/install-codemaat.sh`
- 測試：6 personas × 多語言專案驗證

---

#### 設計決策記錄 (2025-11-30)

**背景**：通過模擬 9 位不同背景開發者的回饋，確定了以下設計方向。

**目標用戶**：**Legacy Codebase 接手者**（最高價值場景）
- 原始專家可能已離職
- 需要快速識別風險區域
- 需要知道「可以問誰」

**命名決策**：`/atlas.history`（3 票勝出）
- ✅ 直覺、跨平台通用
- ✅ 與現有命令風格一致（名詞）
- ✅ 誠實描述資料來源（git history）
- ❌ 避免 `/atlas.tempo`（太抽象）、`/atlas.risk`（過度承諾）

**命令設計**：單一命令，智慧輸出（零參數優先）

```bash
/atlas.history                    # 整個專案概覽（Top 10 hotspots）
/atlas.history auth               # 模組分析（自動偵測）
/atlas.history src/auth/login.ts  # 單一檔案詳細分析
```

**輸出自動調整**：

| 輸入 | 輸出內容 |
|------|---------|
| 無參數 | Top 10 hotspots + 專案健康度 |
| 模組名 | 模組熱點 + 耦合 + 最近貢獻者 |
| 檔案路徑 | 詳細歷史 + 耦合檔案 + 風險評估 |

**核心輸出（三個重點）**：

| 概念 | 用戶問題 | 政治敏感度 |
|------|---------|-----------|
| **Hotspots** | 「哪些檔案最危險？」 | ✅ 安全 |
| **Coupling** | 「改這個會影響什麼？」 | ✅ 安全 |
| **Recent Contributors** | 「這塊誰最熟？」 | ⚠️ 謹慎表達 |

**「可以問誰」的政治友善設計**：

```yaml
# ✅ 正確表達（強調時效性）
recent_contributors:
  - name: Alice
    last_active: 3 days ago
    context: "最近在處理支付邏輯重構"
suggestion: "建議先問 Alice，她最近有在改這塊"

# ❌ 避免（像績效報告）
ownership:
  Alice: 78% (主要負責人)
  風險: Alice 是瓶頸
```

**移除功能**：
- ❌ `/atlas.expert` 反向查詢（「Alice 負責什麼」）- 對 Legacy 接手者價值低

---

#### 與現有命令的關係

| 命令 | 資料來源 | 回答問題 | 使用時機 |
|------|---------|---------|---------|
| `/atlas.overview` | 檔案系統 | 「這是什麼專案？」 | Day 1 快速了解 |
| `/atlas.pattern` | 程式碼 | 「怎麼實作 X？」 | 學習設計模式 |
| `/atlas.impact` | AST 靜態分析 | 「改這個會壞什麼？」 | API 變更前 |
| `/atlas.history` ⭐ | Git 歷史 | 「這個危不危險？問誰？」 | 重構/接手時 |

**完整工作流程**：
```
overview → pattern → impact → history → 動手改
（結構）   （模式）  （靜態）  （歷史）
```

---

#### 日常工作流程驗證

基於 5 個場景的模擬測試：

| 場景 | `/atlas.history` 填補的缺口 |
|------|---------------------------|
| **Bug 修復** | 哪個檔案最常出 bug？誰能幫我？ |
| **新功能** | 這區穩定嗎？跟什麼耦合？ |
| **Code Review** | 這檔案風險多高？誰該 review？ |
| **Onboarding** | 哪裡是地雷區？問誰？ |
| **Refactoring** | **為什麼**變亂的？從哪開始？ |

---

#### 安裝方案

```bash
# 一鍵安裝 code-maat
./scripts/install-codemaat.sh

# 或手動
curl -sSL https://github.com/adamtornhill/code-maat/releases/download/v1.0.4/code-maat-1.0.4-standalone.jar \
  -o ~/.sourceatlas/bin/code-maat.jar
```

---

#### 實作路線圖

**Phase 1: 核心功能** ✅ 已完成 (2025-11-30)
- [x] `install-codemaat.sh` 安裝腳本（自動安裝 + 環境配置）
- [x] `/atlas.history` 命令實作
- [x] Hotspots 分析
- [x] Coupling 分析
- [x] Recent Contributors 分析
- [x] Shallow Clone 偵測 + 一鍵修復

**Phase 2: 完善** ✅ 已完成 (2025-11-30)
- [x] iOS 專案自動排除（Pods/, .pbxproj）
- [x] 風險評估算法
- [x] 測試與文檔（6 personas 多語言測試）

---

#### 未來候選功能

**SourceAtlas Monitor**（v2.7+）：
```yaml
持續追蹤:
  - 自動偵測變更
  - 趨勢分析
  - 健康度儀表板

技術債務量化:
  - 自動債務偵測
  - 重構建議
  - 優先級排序
```

**決策點**：根據 `/atlas.history` 的使用回饋決定是否建立完整 Monitor 系統

---

### v2.8.1 - 發現驅動 Handoffs ✅ (已完成)

**目標**：根據分析發現，動態建議下一步命令

**狀態**：✅ 已完成 (2025-12-06)

**設計原則**：

| 原則 | 說明 |
|------|------|
| **發現驅動** | 根據實際分析結果，而非靜態清單 |
| **限制數量** | 最多 1-2 個建議，避免選擇疲勞 |
| **具體參數** | 包含實際參數，如 `/atlas.pattern "repository"` |
| **理由說明** | 說明為什麼這個建議相關 |

**為什麼不用 spec-kit 的線性 handoffs？**

spec-kit 是**線性工作流**：
```
specify → clarify → plan → tasks → implement
```

SourceAtlas 是**探索式工具**：
```
         ┌─ pattern ─┐
overview ├─ flow ────┼─ (依情境)
         ├─ history ─┤
         └─ impact ──┘
```

**實作方案**：

在每個命令的輸出末尾，根據發現動態生成建議：

```markdown
## Recommended Next

| # | 命令 | 用途 |
|---|------|------|
| 1 | `/atlas.pattern "repository"` | 發現 Repository pattern 在 5 個服務中使用，學習慣例確保一致性 |
| 2 | `/atlas.history` | 專案規模 LARGE (15k LOC)，hotspot 分析可識別重構優先區 |

💡 輸入數字（如 `1`）或複製命令執行
```

**Handoffs 邏輯對照表**：

| 發現 | 建議命令 | 理由 |
|------|---------|------|
| API/Controller patterns | `/atlas.pattern "api endpoint"` | 學習 API 設計慣例 |
| 複雜架構（多層/微服務） | `/atlas.flow` | 追蹤關鍵流程 |
| 專案規模 >= LARGE | `/atlas.history` | 找出 hotspots |
| AI 協作等級 >= 3 | （無建議） | 可直接開發 |
| 測試覆蓋低 | `/atlas.pattern "test"` | 學習測試慣例 |

**成功指標**：
- [x] 建議準確率 >80%（用戶實際執行建議命令）✅ 95%+
- [x] 每個命令輸出最多 2 個建議 ✅
- [x] 建議包含具體參數和理由 ✅

**測試結果** (2025-12-06)：
- 9 個測試專案 × 3 種開發者類型 = 27 個測試場景
- Constitution v1.1 Article VII 定義 5 個 Sections
- 結束條件正確觸發率：100%
- Secondary 省略率：33%（符合預期）
- 參數品質：100% 具體
- 理由品質：100% 引用具體發現

---

