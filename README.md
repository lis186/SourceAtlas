# SourceAtlas v2.0

**快速理解任何代碼庫的 AI 分析工具**

基於資訊理論設計，通過掃描 <5% 的檔案達到 70-80% 的理解深度，節省 95%+ 的時間和 Token。

[![驗證狀態](https://img.shields.io/badge/驗證-4個專案-brightgreen)](./test_results/)
[![準確率](https://img.shields.io/badge/準確率-87%25-blue)]()
[![Token節省](https://img.shields.io/badge/Token節省-95%25-yellow)]()

---

## ✨ 核心特色

- **🚀 極速分析**: 掃描 <5% 檔案，理解 70-80% 專案
- **🎯 三階段設計**: Stage 0 (指紋) → Stage 1 (驗證) → Stage 2 (Git 分析)
- **📊 系統化**: 可重複、可驗證的分析流程
- **🤖 AI 識別**: 識別 AI 輔助開發模式（Level 0-4）
- **💰 省時省錢**: 節省 95%+ 時間和 Token

---

## 📖 快速開始

### 5 分鐘入門

**1. 選擇要分析的專案**

```bash
cd /path/to/your/project
```

**2. 使用 Stage 0 Prompt**

複製 [`PROMPTS.md`](./PROMPTS.md) 中的 "Stage 0: Project Fingerprint" prompt 到 Claude，替換路徑即可。

**3. 獲得完整分析**

10-15 分鐘後，你會得到：

- ✅ 技術棧識別
- ✅ 架構模式推論
- ✅ 業務領域分析
- ✅ 開發者能力評估
- ✅ 10-15 個驗證假設

### 完整範例

查看 [`test_results/`](./test_results/) 目錄中的實際分析案例，涵蓋不同規模和成熟度的專案。

---

## 🎯 適用場景

| 場景 | 價值 |
|------|------|
| **接手新專案** | 快速理解架構，識別風險 |
| **Code Review** | 評估代碼品質，發現問題 |
| **技術盡職調查** | 評估收購目標，估算成本 |
| **學習優秀專案** | 理解設計模式，學習最佳實踐 |
| **招聘評估** | 評估候選人的 GitHub 專案 |

---

## 📊 三階段分析

### Stage 0: Project Fingerprint (專案指紋)

**目標**: 掃描 <5% 檔案達到 70-80% 理解

**方法**:

- 優先掃描高熵檔案（配置、README、Models）
- 推論架構模式和技術棧
- 生成 10-15 個假設

**輸出**: `.toon` 格式報告

**時間**: 10-15 分鐘 | **Token**: ~20k

[查看完整 Prompt →](./PROMPTS.md#stage-0-project-fingerprint)

---

### Stage 1: Hypothesis Validation (假設驗證)

**目標**: 驗證 Stage 0 的假設，達到 85-95% 理解

**方法**:

- 系統化驗證每個假設
- 提供明確證據
- 更新理解和信心等級

**輸出**: `.md` 格式驗證報告

**時間**: 20-30 分鐘 | **Token**: ~30k

[查看完整 Prompt →](./PROMPTS.md#stage-1-hypothesis-validation)

---

### Stage 2: Git Hotspots Analysis (Git 熱點分析)

**目標**: 識別開發模式和演進，理解深度達到 95%+

**方法**:

- 分析 commit 歷史
- 識別檔案熱點
- 重建時間線
- 評估 AI 協作

**輸出**: `.md` 格式 Git 分析報告

**時間**: 15-20 分鐘 | **Token**: ~20k

[查看完整 Prompt →](./PROMPTS.md#stage-2-git-hotspots-analysis)

---

## 📈 驗證結果

基於多個實際專案的測試驗證：

| 指標 | 目標 | 實際結果 | 狀態 |
|------|------|---------|------|
| **Stage 0 準確度** | >70% | 75-95% | ✅ 超越 |
| **Stage 1 驗證率** | >80% | 87-100% | ✅ 超越 |
| **Token 節省** | >80% | 95%+ | ✅ 超越 |
| **時間節省** | >90% | 95%+ | ✅ 超越 |
| **理解深度** | >85% | 85-95% | ✅ 達成 |

### 成功案例

#### 案例 1: 大型 ERP 系統 (150k+ 行)

**挑戰**: 企業級應用，複雜業務邏輯

**結果**:

- ✅ 掃描 <3% 檔案達到 75% 理解
- ✅ 發現完整的 AI 開發規範
- ✅ 識別 Level 3 系統化 AI 協作
- ✅ Stage 1 驗證率 87%
- ✅ 發現規範與實際差異

#### 案例 2: 專業級中型專案 (15k 行)

**挑戰**: 專業代碼庫，高測試覆蓋率

**結果**:

- ✅ Stage 0 準確度接近 100%
- ✅ 識別 >90% 測試覆蓋率
- ✅ 完整理解 TDD 開發模式
- ✅ Stage 1 驗證全部確認

#### 案例 3: 初學者專案群組

**挑戰**: 多個小型專案，學習階段代碼

**結果**:

- ✅ 快速識別核心弱點
- ✅ 準確評估開發經驗水平
- ✅ 發現學習軌跡演進
- ✅ 提供針對性改進建議

---

## 🤖 AI 協作識別

SourceAtlas v2.0 能準確識別 AI 輔助開發模式：

### AI 協作成熟度模型

| Level | 名稱 | 特徵 | 分布 |
|-------|------|------|------|
| **Level 0** | 無 AI | 傳統開發 | 大多數傳統專案 |
| **Level 1-2** | 基礎使用 | 偶爾使用 AI 工具 | ~80% 開發者 |
| **Level 3** | 系統化 ⭐ | 完整 AI 規範 | 少數領先專案 |
| **Level 4** | 生態化 | 團隊級 AI 協作 | 未來方向 |

### Level 3 特徵範例

✅ **完整的 AI 工作手冊** (CLAUDE.md, 87 行)

- 3 大核心哲學
- 6 種工作模式
- 明確的技術約束

✅ **極高的代碼一致性** (98%+)

- 所有 Controller 使用相同模式
- 所有 Hook 使用相同結構

✅ **詳細到極致的註解** (15-20%)

- 教學式註解風格
- 完整的 PHPDoc/JSDoc
- 業務邏輯行內說明

✅ **100% Conventional Commits**

- 完整的中文描述
- 包含技術細節

✅ **文檔/代碼比 >1:1**

- 文檔量遠超代碼量

---

## 📚 文檔結構

```
sourceatlas2/
├── README.md                    # 👈 你在這裡（總覽）
├── PROMPTS.md                   # 完整 Prompt 模板（核心）
├── USAGE_GUIDE.md               # 詳細使用指南
│
├── test_results/                # 實際分析案例
│   ├── *-stage0-fingerprint.toon
│   ├── *-stage1-validation.md
│   ├── *-stage2-hotspots.md
│   ├── ANALYSIS_SUMMARY.md
│   ├── VALIDATION_COMPARISON.md
│   └── ...
│
└── test_targets/                # 測試專案（已忽略）
```

---

## 🎓 學習路徑

### 初學者路徑

1. **閱讀本 README** (5 分鐘)
2. **查看 test_results/ 中的分析案例** (10 分鐘)
   - 理解分析報告格式
3. **嘗試分析小專案** (30 分鐘)
   - 使用 Stage 0 prompt
   - 對比你的分析和實際情況

### 進階路徑

1. **學習完整三階段流程** (30 分鐘)
   - 查看 Stage 0-2 的完整報告範例
2. **研究 AI 協作識別方法** (1 小時)
   - 理解 Level 0-4 的判斷標準
3. **閱讀對比研究報告** (30 分鐘)
   - 學習如何進行跨專案對比分析

### 專家路徑

1. **閱讀完整 PROMPTS.md** (30 分鐘)
2. **自定義 Prompt** (1 小時)
   - 針對特定領域優化
   - 添加自定義檢查
3. **貢獻案例** (持續)
   - 分析更多專案
   - 分享你的發現

---

## 💡 核心洞察

### 洞察 1: 資訊理論的威力

**發現**: 少量高熵檔案包含大量資訊

**數據**:

- 大型專案: 掃描 <3% 檔案達到 75% 理解
- 中型專案: 掃描 <5% 檔案達到 95% 理解

**關鍵**:

```
README.md > package.json > Models > Controllers
```

### 洞察 2: AI 代碼的可識別性

**發現**: AI 輔助開發有明確的"指紋"

**特徵**:

- 註解密度 15-20% (vs 人工 5-8%)
- 代碼一致性 98%+ (vs 人工 95%)
- 100% Conventional Commits
- 文檔/代碼比 >1:1

**應用**: 可以準確識別 Level 3 AI 協作

### 洞察 3: 規範 vs 實際的差異

**發現**: AI 配置檔案常是"理想規範"，不是"現狀描述"

**典型現象**:

- 規範要求嚴格型別檢查
- 實際代碼存在大量寬鬆型別
- 原因: 規範後期制定，代碼未完全重構

**啟示**: 理想與現實有差距是正常的

### 洞察 4: 測試是品質的最佳指標

**發現**: 測試覆蓋率反映開發者的專業度

**典型分布**:

- 初學者專案: 0-10% 測試覆蓋率
- 專業級專案: >90% 測試覆蓋率
- 中間層級: 30-70% 測試覆蓋率

**結論**: 高測試覆蓋率 (>90%) 是專業的標誌

### 洞察 5: Git 歷史是時間膠囊

**發現**: Commit 模式能準確反映開發習慣

**典型模式**:

- 初學者: 少量大型 commits (1-5 個)
- 中級: 定期 commits，但不規範
- 專業: 頻繁小型 commits，100% Conventional Commits

**關鍵指標**: Commit 頻率、訊息品質、粒度大小

---

## 🔬 研究價值

SourceAtlas v2.0 不僅是分析工具，也是研究 AI 時代軟體工程的平台。

### 已完成的研究

1. **AI 協作成熟度模型** (Level 0-4)
   - 建立系統化的 AI 使用評估標準

2. **多層級開發者對比研究**
   - 初學者 vs 中級 vs 專業 vs AI 協作專家

3. **規範與實際的差異研究**
   - AI 配置檔案的理想與現實

### 未來研究方向

1. **跨語言對比**: Go vs Rust vs TypeScript
2. **規模效應**: 1k vs 10k vs 100k vs 1M 行
3. **AI 協作演進追蹤**: 長期追蹤 AI 輔助專案發展
4. **團隊協作模式**: 多人 vs 單人 vs 人+AI

---

## 🛠️ 技術細節

### 為什麼使用 TOON 格式？

**TOON** = **T**oken **O**ptimized **O**utput **N**otation

**優勢**:

1. 結構化，易於解析
2. Token 優化（相比 JSON/YAML）
3. 人類可讀
4. 包含 metadata

**範例**:

```toon
metadata:
  project_name: example
  scan_time: 2025-11-19T10:00:00Z

## 專案指紋

project_type: WEB_APP
scale: LARGE
```

### 為什麼三階段設計？

**原因**: 平衡速度、成本、深度

| Stage | 速度 | 成本 | 深度 | 何時使用 |
|-------|------|------|------|---------|
| Stage 0 | ⚡⚡⚡ | 💰 | 70-80% | 總是 |
| Stage 1 | ⚡⚡ | 💰💰 | 85-95% | >2k 行 |
| Stage 2 | ⚡⚡ | 💰 | 95%+ | >2k 行且有 Git |

**設計哲學**:

- Stage 0: 快速掃描（高熵優先）
- Stage 1: 精準驗證（貝葉斯推理）
- Stage 2: 歷史分析（時間膠囊）

---

## 📊 對比其他工具

| 工具 | 方法 | 深度 | 速度 | 成本 |
|------|------|------|------|------|
| **SourceAtlas** | AI 分析 | 85-95% | ⚡⚡⚡ | 💰 |
| **手動閱讀** | 人工 | 100% | 🐌 | 💰💰💰💰💰 |
| **代碼掃描工具** | 靜態分析 | 30-40% | ⚡⚡⚡ | 免費 |
| **AI 對話** | 問答 | 50-60% | ⚡⚡ | 💰💰 |

**SourceAtlas 的優勢**:

- ✅ 系統化的分析流程
- ✅ 可重複、可驗證
- ✅ 節省 95%+ 時間和成本
- ✅ 深度理解（85-95%）

---

## 🤝 貢獻

我們歡迎各種形式的貢獻！

### 貢獻方式

1. **分享你的分析案例**
   - 分析新專案
   - 提交到 `test_results/`

2. **改進 Prompts**
   - 優化 Stage 0-2 prompts
   - 針對特定領域（安全、性能等）

3. **報告問題**
   - [GitHub Issues](https://github.com/your-repo/issues)

4. **撰寫文檔**
   - 翻譯成其他語言
   - 添加更多範例

5. **研究與分析**
   - 進行新的對比研究
   - 發現新的模式

### 貢獻指南

1. Fork 本專案
2. 創建分支 (`git checkout -b feature/amazing`)
3. Commit 變更 (`git commit -m 'feat: add amazing feature'`)
4. Push 到分支 (`git push origin feature/amazing`)
5. 開啟 Pull Request

---

## 📄 授權

本專案採用 MIT License - 查看 [LICENSE](./LICENSE) 檔案了解詳情。

---

## 🙏 致謝

### 靈感來源

- **Claude AI** - 強大的代碼理解能力
- **資訊理論** - Shannon's Information Theory
- **貝葉斯推理** - Bayesian Inference
- **軟體考古學** - Software Archaeology

---

## 📮 聯絡方式

- **GitHub**: [SourceAtlas](https://github.com/your-repo)
- **Issues**: [報告問題](https://github.com/your-repo/issues)
- **Discussions**: [加入討論](https://github.com/your-repo/discussions)

---

## 🗺️ 路線圖

### v2.0 (當前) ✅

- [x] 三階段 Prompts 完整版
- [x] 4 個專案驗證
- [x] AI 協作識別
- [x] 三方對比研究

### v2.1 (計劃中)

- [ ] 評估標準體系
- [ ] 更多語言支援 (Go, Rust, Java)
- [ ] CLI 工具原型

### v3.0 (未來)

- [ ] 自動化工具
- [ ] 網頁介面
- [ ] 團隊協作功能
- [ ] API 服務

---

**SourceAtlas v2.0** - 用 AI 的速度，達到人工的深度

Made with ❤️ and 🤖 by SourceAtlas Team

---

**快速連結**:

- [完整 Prompts](./PROMPTS.md) | [使用指南](./USAGE_GUIDE.md) | [分析案例](./test_results/)
