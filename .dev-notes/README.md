# SourceAtlas Development Notes

這個資料夾記錄 SourceAtlas 的**完整開發歷史**、**關鍵決策**和**方法論**。

## 快速導航

- 📜 **[HISTORY.md](./HISTORY.md)** - 按時間線查看專案演進
- 🗺️ **[ROADMAP.md](./ROADMAP.md)** - 未來規劃與下一步
- 💡 **[KEY_LEARNINGS.md](./KEY_LEARNINGS.md)** - 核心學習與發現
- 📐 **[METHODOLOGY.md](./METHODOLOGY.md)** - 開發方法論

## 最近更新

- **2025-11-23**: iOS Patterns 整合 + Objective-C 支援完成
- **2025-11-22**: Atlas Pattern Command 實作完成
- **2025-11-20**: TOON vs YAML 格式決策

## 檔案組織

### 核心索引（持續參考）
- **大寫檔案** (UPPER_CASE.md): 持續更新的核心索引和方法論
- 限制 5 個：README, HISTORY, KEY_LEARNINGS, ROADMAP, METHODOLOGY

### 歷史記錄（按時間分類）
- **按月資料夾** (YYYY-MM/): 該月的詳細實作記錄
  - 每月有 README.md 摘要
  - 檔案格式：`YYYY-MM-DD-topic-type.md`

- **archives/**: 歷史存檔與深度分析
  - `decisions/`: 重大決策記錄
  - `lessons/`: 方法論深度分析
  - `experiments/`: 實驗性嘗試

### 工具與模板
- **scripts/**: 驗證和分類工具
- **templates/**: 標準文檔模板

## 資訊分層

本資料夾遵循 SourceAtlas 的資訊理論原則，提供漸進式資訊揭露：

- **Layer 0** (本檔案): 10 秒快速理解
- **Layer 1** (5 個核心檔案): 5 分鐘掌握全貌
- **Layer 2** (月度資料夾): 30 分鐘理解細節
- **Layer 3** (archives/): 深度挖掘

## 更新規則

**AI 和開發者必須遵守**：

1. ⛔ **絕不創建新的大寫檔案**（已達 5 個上限）
2. ✅ **所有新內容使用日期前綴**（YYYY-MM-DD-topic.md）
3. ✅ **完成後立即更新 HISTORY.md**
4. ✅ **同主題內容必須合併**
5. ✅ **每月更新月度 README**

詳細規則請參考：`***REMOVED***/CLAUDE.md` 中的「.dev-notes/ 管理規則」章節

---

**元級示範 (Meta-demonstration)**: 這個資料夾本身就是 SourceAtlas 資訊理論的最佳實踐範例。
