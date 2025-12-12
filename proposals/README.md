# proposals/ - 功能提案庫

SourceAtlas 未來功能的完整設計文檔。

## 📋 當前提案

### ⚫ 已完成（歸檔）

- **[code-maat Integration](./code-maat-integration/SOURCEATLAS_CODEMAAT_INTEGRATION.md)**
  - **實作為**: `/atlas.history` (v2.6.0)
  - **完成日期**: 2025-11-30
  - **成果**: 智慧時序分析（Hotspots、Coupling、Recent Contributors）
  - **文檔保留供參考**:
    - [完整提案](./code-maat-integration/SOURCEATLAS_CODEMAAT_INTEGRATION.md)
    - [快速參考](./code-maat-integration/CODE_MAAT_FORMAT_CHEATSHEET.md)
    - [效能考量](./code-maat-integration/PERFORMANCE_CONSIDERATIONS.md)

- **[/atlas.flow - 業務流程分析](./atlas-flow/README.md)**
  - **實作為**: `/atlas.flow` (v2.7.0)
  - **完成日期**: 2025-12-01
  - **成果**: 11 種分析模式、語言專屬入口點偵測、漸進式展開
  - **文檔保留供參考**

### 🟢 已批准待實作

- **[探索結果持久化](./persistence/README.md)** ⭐ NEW
  - **目標**: 讓分析結果可儲存、可事後補存、可清空
  - **功能**:
    - 所有命令支援 `--save`
    - `/atlas.save` 事後儲存上一次結果
    - `/atlas.clear` 清空 `.sourceatlas/`
  - **狀態**: 設計完成，待實作
  - **工作量**: 2.5-3 小時
  - **優先級**: P0

### 🟡 研究中

*（從 ideas/ 升級的提案會出現在這裡）*

### ⚪ 擱置

- **[YAML Pattern Configuration](./yaml-pattern-config/README.md)**
  - **目標**: 將 patterns 從 shell script 硬編碼改為 YAML 配置檔
  - **狀態**: 擱置（2025-11-30）
  - **原因**: 經多角色審查後決定暫不實作
    - PM 評估：無使用者需求，ROI 為負
    - 現有發現機制（`find-patterns.sh` 無參數）已足夠
    - 優先完善現有 commands 和多語言支援
  - **未來**: 待使用者明確需求時再評估

---

## 🔄 提案生命週期

```
ideas/*.md
  ↓ (1-4 週研究驗證)
  ↓ 確認價值和可行性
proposals/feature-name/
  ↓ (排入 roadmap)
  ↓ 開始實作
dev-notes/YYYY-MM/implementation.md
```

---

## ✅ 提案要求

每個提案必須包含：

1. **清晰的使用場景**
   - 解決什麼問題？
   - 誰會使用？
   - 為什麼需要？

2. **完整的技術設計**
   - 架構方案
   - 技術選型和理由
   - 實作範例

3. **可行性驗證**
   - 在真實場景測試
   - 技術風險評估
   - 替代方案比較

4. **實作計畫**
   - 具體步驟（不含時間估算）
   - 測試策略
   - 文檔要求

---

## 🚀 如何提交提案

### 從 ideas/ 升級

如果你在 `ideas/` 有想法已經成熟：

1. 確認符合提案要求
2. 創建 `proposals/feature-name/` 目錄
3. 撰寫完整文檔
4. 更新本 README（在「🔵 待評估」區段新增）
5. 開 Issue 討論

### 新提案

1. 先在 `ideas/` 做初步研究（1-4 週）
2. 驗證可行性
3. 按上述步驟升級到 proposals/

---

## 📊 提案狀態說明

| 狀態 | 說明 | 下一步 |
|------|------|--------|
| 🔵 待評估 | 設計完成，等待 review | 團隊討論、決策 |
| 🟢 已批准 | 已同意實作，待排程 | 排入 roadmap |
| 🟡 研究中 | 從 ideas/ 升級，持續完善 | 補充設計細節 |
| ⚪ 擱置 | 決定暫不實作，保留設計 | 待使用者需求再評估 |
| ⚫ 已歸檔 | 已實作或已放棄 | 移到 dev-notes/ 或刪除 |

---

## 🤝 參與方式

- **討論提案**: 在對應 Issue 留言
- **提供反饋**: PR 補充或修正
- **提出新想法**: 先到 `ideas/` 探索

---

## 📚 相關資源

- [ideas/](../ideas/) - 實驗性想法孵化區
- [dev-notes/](../dev-notes/) - 已完成功能的實作記錄
- [ROADMAP](../dev-notes/ROADMAP.md) - 開發路線圖
