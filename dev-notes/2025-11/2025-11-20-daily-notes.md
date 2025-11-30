# Dev Notes - 2025-11-20

## 📋 今日討論主題

**核心問題**：SourceAtlas 應該是獨立 CLI 工具，還是 Claude Code Skill？

---

## 🎯 背景回顧

### 當前狀態
- ✅ 完成 v2.0 文檔（PROMPTS.md, USAGE_GUIDE.md, README.md）
- ✅ 完成 4 個專案的驗證（準確度 75-95%）
- ✅ 證明三階段分析方法的有效性
- ✅ 發現 AI 協作模式識別（Level 0-4）

### PRD 原始願景
- **產品形態**：獨立 CLI 工具 `satlas`
- **定位**：為 AI 助理（Claude/GPT）提供優化的專案上下文
- **核心技術**：TOON 格式、索引系統、漸進式載入
- **開發週期**：8 週
- **實作**：Shell (POSIX)，零依賴

### README 當前狀態
- **產品形態**：手動 Prompt 方法論
- **使用方式**：複製 PROMPTS.md → 貼到 Claude → 獲得分析報告
- **定位**：快速理解代碼庫的研究工具
- **狀態**：研究驗證階段完成

---

## 💡 關鍵洞察 #1：CLI vs Skill

### Justin 的提問
> "我認為 Claude Code 內的 Claude Skill 搭配幾個 script 或是 plugin 可能更適合這個用途，你覺得呢？"

### 我的分析：完全同意

#### 優勢對比

| 維度 | 獨立 CLI 工具 | Claude Code Skill |
|------|-------------|-------------------|
| **開發時間** | 8 週 | 1-2 週 |
| **整合方式** | 外部工具 → 匯出 → 貼給 AI | AI 原生執行 |
| **使用流程** | `satlas index` → 複製輸出 → 對話 | `/atlas` → 直接對話 |
| **維護成本** | 高（索引、解析、多語言） | 低（輕量 scripts + AI 能力） |
| **上下文管理** | 需要實作 | Claude Code 內建 |
| **檔案操作** | 需要實作 scanner | 已有 Glob, Grep, Read |
| **符號提取** | 需要實作解析器 | AI 理解能力 |
| **靈活性** | 預定義索引 | AI 動態探索 |

#### 重複造輪子分析

PRD 要實作的功能：
- ❌ 檔案掃描 → Claude Code 已有 Glob, Bash
- ❌ 內容搜尋 → Claude Code 已有 Grep
- ❌ 檔案讀取 → Claude Code 已有 Read
- ❌ 符號提取 → AI 自己就能理解代碼
- ❌ 上下文管理 → Claude Code 內建

實際需要的：
- ✅ **分析方法論**（三階段 Prompts）
- ✅ **啟發式規則**（高熵檔案優先）
- ✅ **TOON 格式規範**（Token 優化）
- ✅ **模式識別邏輯**（AI 協作、架構模式）

---

## 💡 關鍵洞察 #2：使用場景分析

### Justin 的提問
> "我們還沒討論這套類似索引的功能，在使用者實際開發軟體時將被如何運用？可能的場景有哪些？"

### 五個真實場景分析

#### 場景 1：接手遺留系統（Bug 修復）
**情境**：新人修 Bug "特定角色無法看到訂單列表"

**傳統方式**：
- 搜尋 "orders" → 50 個檔案
- 猜測、試錯、問人
- 花費 2 小時定位問題

**理想的 SourceAtlas**：
```
/atlas find "order list authorization"

AI 回應：
訂單列表授權鏈路：
  OrdersController#index → OrderPolicy#index? → role check

可能問題：
  - OrderPolicy 2天前被修改
  - Commit: "fix: update role check logic"

建議檢查：order_policy.rb:18 角色判斷邏輯
```

**關鍵問題**：
- 需要預先索引嗎？還是即時搜尋？
- 如何知道「授權鏈路」關聯性？

---

#### 場景 2：新功能開發（學習現有模式）
**情境**：PM 要加「匯出發票 PDF」功能

**理想的 SourceAtlas**：
```
/atlas patterns "file generation"

AI 回應：
此專案的檔案生成模式（範例：訂單 PDF）：
  1. Controller 接收請求
  2. 入隊 GeneratePdfJob
  3. Service 用 Prawn gem 生成
  4. 上傳 S3
  5. 發送郵件通知

跟隨此模式新增發票 PDF：
  [具體步驟與範例檔案]
```

**關鍵問題**：
- 如何識別「模式」而非單純檔案？
- 需要人工定義模式？還是 AI 自動識別？

---

#### 場景 3A：Debug 連鎖問題（Model 變更影響）
**情境**：改了 User model 驗證規則，3 個功能都壞了

**理想的 SourceAtlas**：
```
/atlas impact "User model validation"

AI 回應：
直接影響（4 處）：
  - RegistrationController
  - Admin::UsersController
  - Api::V1::ProfileController
  - UserImportService

連鎖影響（3 處）：
  - Order model (belongs_to :user)
  - Notification service
  - Analytics job

測試覆蓋缺口：
  ⚠️ UserImportService 沒有驗證失敗測試
```

**關鍵問題**：
- 如何追蹤「連鎖影響」？
- 需要靜態分析？還是基於 git 歷史？

---

#### 場景 3B：API 改動影響分析 ⭐（新增！）

### Justin 的補充
> "影響分析還有一種情況是要盤點某些 API 改動可能影響哪些頁面或功能"

**情境**：
```
後端 API 端點變更，需要盤點哪些前端頁面會受影響

例如：GET /api/users/{id} 的 response 格式改變
- 'role' 欄位從字串改為陣列 'roles'
- 新增 'profile' 巢狀物件
```

**理想的 SourceAtlas**：
```
/atlas impact api "/api/users/{id}"

AI 回應：
=== API Impact Analysis ===

📍 調用鏈路：
  API → Hook → Component

📊 欄位使用分析：
'role' 欄位（⚠️ 改為 'roles'）：
  - 使用次數：8 處
  - 假設類型為字串：✅ 是
  - 影響評估：🔴 破壞性變更

📋 遷移檢查清單：
  [ ] 更新 API 類型定義
  [ ] 更新 8 處 role → roles
  [ ] 改用 user.roles.includes('admin')
  [ ] 更新 5 個測試檔案

預估工作量：2-3 小時
風險等級：🔴 高
```

**價值**：
- 提前發現所有影響點
- 給出明確修改清單
- 評估工作量和風險
- 減少前後端協作摩擦

**為什麼重要**：
1. **高頻場景**：前後端分離專案中 API 變更非常頻繁
2. **高風險**：遺漏修改會導致 runtime 錯誤
3. **跨團隊協作**：減少溝通成本
4. **展示價值**：傳統 grep 難以做好的場景

---

#### 場景 4：Code Review（理解變更意圖）
**情境**：Review PR 新增 PaymentRefundService

**理想的 SourceAtlas**：
```
/atlas review PR#123

AI 回應：
架構符合度：✅ 良好
  - 遵循現有 Service Object 模式
  - 錯誤處理一致

潛在問題：
  ⚠️ 缺少冪等性處理
  ⚠️ Webhook 需要更新支援 refund events
```

---

#### 場景 5：技術債務管理（專案健康度）
**情境**：Tech Lead 需要報告技術債務

**理想的 SourceAtlas**：
```
/atlas health

AI 回應：
🔴 高風險區域：
  1. PaymentService
     - 450 lines, 8 dependencies
     - 被 12 個檔案依賴
     - 6 個月內修改 23 次
     - 測試覆蓋 78%（支付邏輯應 >95%）
     → 建議：拆分 + 補測試
```

---

## 🎯 核心發現：兩種不同的需求

### Type A: 即時探索（Ad-hoc Query）

**特點**：
- 不需要預先索引
- 即時搜尋和推理
- 問題驅動
- **Claude Code 已能做 80%**

**適用場景**：
- ✅ 場景 1: 找 Bug 位置
- ✅ 場景 2: 學習現有模式
- ✅ 場景 3B: API 影響分析 ⭐
- ✅ 場景 4: Code Review

**解決方案**：
- Claude Code Skill + 簡單 scripts
- AI 即時理解和推理
- 不需要複雜索引系統

---

### Type B: 持續追蹤（Continuous Analysis）

**特點**：
- 需要歷史資料
- 需要趨勢分析
- 需要跨時間對比
- 需要量化指標

**適用場景**：
- ✅ 場景 3A: Model 變更影響
- ✅ 場景 5: 技術債務管理
- ✅ 專案演進追蹤

**解決方案**：
- 需要持續索引
- 需要儲存歷史資料
- 可能需要獨立 CLI 工具

---

## 💡 新的產品定位建議

### 1. SourceAtlas Skill（立即開發，1-2週）

**定位**：開發者的 AI 搭檔

**技術架構**：
```
.claude/skills/atlas.md        # Skill 定義（核心）
scripts/
  ├── atlas-stage0.sh          # 快速指紋掃描
  ├── atlas-stage1.sh          # 假設驗證助手
  ├── atlas-stage2.sh          # Git 分析
  └── utils/
      ├── detect-project-type.sh
      └── scan-high-entropy.sh
```

**命令設計**：
```bash
/atlas                    # 啟動專案分析（Stage 0）
/atlas find "功能名稱"      # 快速定位
/atlas explain 檔案路徑     # 深入理解
/atlas pattern "模式名稱"   # 學習模式
/atlas impact api "..."   # API 影響分析 ⭐
```

**核心價值**：
- 保留三階段分析方法論
- 保留 TOON 格式
- 保留高熵檔案優先策略
- 不需要複雜的索引系統

---

### 2. SourceAtlas Monitor（未來，3-6個月）

**定位**：專案健康度儀表板

**使用場景**：
- 技術債務追蹤
- 影響範圍分析
- 專案演進趨勢
- 團隊報告

---

## 📝 今日完成的工作

### 1. 更新 PRD.md (v2.0 → v2.5)

**重大變更**：
- ❌ 移除：獨立 CLI 工具設計
- ✅ 新增：Claude Code Skill + Scripts 架構
- ✅ 新增：5 個詳細使用場景
- ✅ 新增：場景 3B API 影響分析 ⭐
- ✅ 保留：v2.0 核心方法論

**新增內容**：
1. 產品定位演進圖（v2.0 → v2.5 → v3.0）
2. 為什麼選擇 Skill 架構
3. 五個真實使用場景（含 API 影響分析）
4. 場景分類（即時探索 vs 持續追蹤）
5. 產品架構對比（CLI vs Skill）
6. Scripts 設計原則
7. 實作路線圖
8. 設計決策記錄

**檔案大小**：從 1153 行 → 1082 行（簡化了複雜的索引設計）

---

### 2. 創建詳細的 API 影響分析文檔

**檔案**：`dev-notes/2025-11-20-api-impact-analysis.md`

**內容**：
- API 改動場景的詳細描述
- 具體案例（User API, Orders API）
- 使用 SourceAtlas 的理想流程
- v2.5 vs v3.0 的實作方案
- 關鍵洞察和技術分析
- 實作優先級建議

---

## 🤔 待確認問題

### 給 Justin 的問題

1. **你最常遇到的是哪類場景？**
   - 即時探索（找 Bug、學模式、API 影響）？
   - 持續追蹤（技術債務、影響分析）？

2. **你現在用 Claude Code 開發時，最痛的點是什麼？**
   - 找不到功能在哪？
   - 不知道該學哪個範例？
   - 不確定改了會影響什麼？
   - API 改動影響難以評估？⭐
   - 其他？

3. **你期望的使用頻率？**
   - 每天多次（接手新專案、Debug、API 影響）？
   - 每週一次（Code Review、重構規劃）？
   - 每月一次（技術債務報告）？

4. **API 影響分析的實際需求？**
   - 主要是前端專案（React, Next.js）？
   - 還是前後端都有？
   - 是否有 TypeScript 類型定義？
   - 使用什麼 API client（fetch, axios, 其他）？

---

## 📝 下一步行動（待決定）

### 方案 A：立即開發 Skill
1. 設計 `.claude/skills/atlas.md`
2. 實作基礎 scripts（專案偵測、高熵掃描）
3. 整合 PROMPTS.md 的三階段邏輯
4. 重點實作 `/atlas find` 和 `/atlas impact api`
5. 在實際專案測試（優先測試 API 影響分析）

### 方案 B：先做使用者研究
1. 觀察 Justin 實際開發流程
2. 記錄真實痛點和需求
3. 特別關注 API 改動場景
4. 設計最小可用功能
5. 快速原型驗證

### 方案 C：重新調整優先級
1. 將 API 影響分析列為 v2.5 核心功能
2. 優先實作 `/atlas impact api`
3. 其他功能（health, review）留待 v2.6
4. 專注於最高價值場景

---

## 🎯 核心共識

1. **Claude Code Skill 優於獨立 CLI**（至少對即時探索場景）
2. **需要先確認真實使用場景**，再決定功能範圍
3. **API 影響分析是高價值場景** ⭐
   - 高頻率：前後端分離專案常見
   - 高風險：遺漏修改會導致 runtime 錯誤
   - 難解決：傳統工具不易做好
   - 展示價值：AI 理解的優勢
4. **保留核心價值**：
   - ✅ 三階段分析方法論
   - ✅ TOON 格式規範
   - ✅ 高熵檔案優先策略
   - ✅ AI 協作模式識別
5. **可能需要兩個產品**：
   - SourceAtlas Skill（即時探索）← 優先
   - SourceAtlas Monitor（持續追蹤）← 未來

---

## 📚 相關文件

- `PRD.md` - 已更新為 v2.5（Skill 架構）
- `README.md` - 當前手動 Prompt 方法
- `PROMPTS.md` - 三階段分析 Prompts
- `USAGE_GUIDE.md` - 使用指南
- `dev-notes/2025-11-20-api-impact-analysis.md` - API 影響分析詳細文檔

---

## 💭 個人思考

從今天的討論中最大的收穫：

1. **從實際場景倒推設計**
   - PRD 的 CLI 工具在理論上完整，但實際上開發者需要的是融入工作流程的工具
   - API 影響分析是 Justin 主動提出的真實需求，這正是我們應該優先解決的

2. **AI 的優勢在於理解，而非索引**
   - 傳統工具：建立索引 → 查詢索引 → 返回結果
   - AI 工具：動態探索 → 理解意圖 → 推理關聯 → 提供洞察

3. **最好的工具是無形的工具**
   - 不需要學習新命令
   - 不需要切換工具
   - 融入現有工作流程（Claude Code）
   - 自然語言互動

4. **場景驅動 > 功能驅動**
   - 不是「我們有什麼功能」
   - 而是「開發者遇到什麼問題」
   - API 影響分析就是典型例子

SourceAtlas 的真正價值不是「索引系統」，而是：
1. **分析方法論**（如何快速理解專案）
2. **啟發式規則**（掃描哪些檔案最有價值）
3. **模式識別**（如何識別設計模式和 AI 協作）
4. **影響分析**（如何評估變更的影響範圍）⭐

這些可以用更輕量的方式實現（Skill + Scripts），而不需要 8 週開發一個獨立工具。
