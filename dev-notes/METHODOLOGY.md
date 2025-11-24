# SourceAtlas Development Methodology

**Purpose**: 核心開發方法論與最佳實踐
**Last Updated**: 2025-11-23

---

## 1. 核心原則

### 1.1 資訊理論優先

**原則**: 高熵檔案包含不成比例的大量資訊

**應用**:
- README + package.json/build.gradle 提供 70%+ 專案理解
- 掃描 <5% 檔案達到 70-80% 理解
- 結構 > 實作細節

**驗證**: 5/5 專案測試成功（v1.0）

### 1.2 規模感知設計

**分類**:
- **TINY**: <500 LOC
- **SMALL**: 500-2K LOC
- **MEDIUM**: 2K-10K LOC
- **LARGE**: 10K-50K LOC
- **VERY_LARGE**: >50K LOC

**策略**: 不同規模使用不同掃描策略，避免一刀切

### 1.3 標準優於自訂

**決策範例**: YAML vs TOON
- 選擇 YAML（標準格式）
- 雖然 +14% tokens，但換取生態系統支援
- 長期維護成本更低

### 1.4 漸進式資訊揭露

**分層設計**:
- Layer 0: 10 秒快速理解
- Layer 1: 5 分鐘掌握全貌
- Layer 2: 30 分鐘深入細節
- Layer 3: 無限深入研究

---

## 2. Pattern Detection 方法論

### 2.1 設計哲學

**理念**: 腳本收集數據，AI 做深度解釋
- 腳本：快速（<5s）、可靠、80%+ 準確
- AI：理解語義、提供洞察

### 2.2 匹配策略

**檔案名稱 > 內容分析**:
- 檔名匹配：+10 分（基礎分）
- 目錄名稱：+8 分
- 不做內容分析（太慢）
- 不檢查最近修改（太慢）

**Trade-off**:
- ✅ 極快速度（<5s on LARGE projects）
- ✅ 簡單可靠
- ⚠️ 可能遺漏非標準命名檔案

### 2.3 跨語言支援

**關鍵發現**: 跨語言 pattern 命名慣例高度相似

**範例**:
- Swift: `*ViewController.swift`
- Objective-C: `*ViewController.m/.h`
- Kotlin: `*ViewModel.kt`
- Java: `*ViewModel.java`
- TypeScript: `*ViewModel.ts`

**策略**: 同一 pattern 支援多個副檔名

### 2.4 混合專案處理

**問題**: Swift/ObjC 混合專案會遺漏 3-55% 代碼

**解決方案**:
1. 擴充所有 patterns 支援 .m/.h
2. 支援 Category 語法（`*+*.m`）
3. 測試不同混合比例（3%, 18%, 55%）

**驗證**: 從遺漏 55% → 0% 遺漏

---

## 3. 新語言支援流程

**標準流程**（來自 archives/lessons/new-language-support-methodology.md）:

### Step 1: 研究現有專案
- 分析 3+ 真實專案
- 識別常見命名慣例
- 記錄檔案結構模式

### Step 2: 定義 Pattern 分層
- **Tier 1**: >70% 使用率（核心 patterns）
- **Tier 2**: 30-70% 使用率（補充 patterns）

### Step 3: 實作與測試
- 更新 `find-patterns.sh`
- 測試 3+ 專案
- 驗證準確率 >80%

### Step 4: 文檔化
- 更新 CLAUDE.md
- 記錄決策與學習
- 提供範例

---

## 4. Multi-Agent 開發策略

**核心原則**（來自 archives/lessons/multi-agent-development-lessons.md）:

### 4.1 Agent 選擇

**Plan Agent**: 適合開放式探索
- 不確定目標位置
- 需要多次搜尋
- 複雜決策

**Direct Execution**: 適合明確任務
- 已知檔案位置
- 標準化操作
- 快速執行

### 4.2 平行 vs 序列

**平行執行**: 獨立任務
```bash
# 同時測試多個專案
test_project_A & test_project_B & test_project_C
```

**序列執行**: 依賴任務
```bash
# 必須先 A 再 B
implement_feature && run_tests && commit
```

---

## 5. 測試策略

### 5.1 測試專案選擇

**標準**:
- 涵蓋不同規模（SMALL, MEDIUM, LARGE）
- 涵蓋不同架構（MVC, MVVM, Clean Architecture）
- 真實專案 > 教學範例

**iOS 範例**:
- wikipedia-ios (18% ObjC, LARGE)
- Signal-iOS (3% ObjC, VERY_LARGE)
- nineyiappshop (55% ObjC, MEDIUM) - 極端案例

### 5.2 驗證指標

**Pattern Detection**:
- 準確率 >80%（找到的都是對的）
- 召回率 >70%（該找的有找到）
- 速度 <5s（LARGE projects）

**覆蓋率**:
- 混合專案遺漏率 <5%
- 核心 patterns 100% 支援

---

## 6. 文檔管理

### 6.1 分層原則

見 README.md 的資訊分層設計。

### 6.2 命名規範

**持續參考** (5 個上限):
- UPPER_CASE.md
- 經常更新、經常引用

**歷史記錄**:
- `YYYY-MM-DD-topic-type.md`
- 一次性、有時效性

### 6.3 更新流程

**每日/每週**: 原始筆記
**完成後**: 整理成完整報告
**每月**: 更新核心索引

---

## 7. 決策框架

### 7.1 技術選擇

**評估標準**:
1. 標準 vs 自訂（優先標準）
2. 生態系統支援
3. 長期維護成本
4. 效能 trade-off

**範例**: YAML vs TOON 決策
→ [完整分析](./archives/decisions/2025-11-20-toon-vs-yaml.md)

### 7.2 優先級

**P0** (立即): 核心功能、嚴重 bug
**P1** (本週): 重要功能、優化
**P2** (未來): Nice-to-have、實驗

---

## 8. 持續改進

### 8.1 學習記錄

每個重大功能完成後：
1. 提煉 2-3 個核心學習
2. 更新 KEY_LEARNINGS.md
3. 更新 METHODOLOGY.md（如needed）

### 8.2 回顧機制

**每週**: 檢查 ROADMAP 進度
**每月**: 更新月度 README
**每季**: 歸檔舊內容（>3 months）

---

**參考文檔**:
- [新語言支援](./archives/lessons/new-language-support-methodology.md)
- [Multi-Agent 開發](./archives/lessons/multi-agent-development-lessons.md)
- [決策記錄](./archives/decisions/)
