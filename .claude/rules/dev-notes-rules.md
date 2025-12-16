# dev-notes/ 管理規則

**dev-notes/** 資料夾記錄完整開發歷史、關鍵決策和方法論。**所有 AI 和開發者必須遵守以下規則**。

## 檔案分類決策樹

創建或整理 dev-notes 檔案時，**嚴格按照此決策樹**：

### Step 1: 是否為「持續參考」？

回答以下 3 個問題，**全部為 YES** 才是持續參考：

1. 這個檔案會被**頻繁更新**嗎？（每週至少 1 次）
2. 這個檔案是**索引/導航**性質嗎？（指向其他檔案）
3. 這個檔案提供**長期有效的方法論/原則**嗎？

**如果 3 個都是 YES** → 使用**大寫檔名** (UPPER_CASE.md)
- **限制：最多 5 個大寫檔案**
- 當前已有：README.md, HISTORY.md, KEY_LEARNINGS.md, ROADMAP.md, METHODOLOGY.md
- **絕不創建新的大寫檔案**（除非明確討論並批准）

**否則** → 使用**日期前綴** (YYYY-MM-DD-topic-type.md)

### Step 2: 確定檔案名稱

**格式**: `YYYY-MM-DD-topic-type.md`

- **YYYY-MM-DD**: 使用**完成日期**（不是開始日期）
- **topic**: 主題，使用連字號分隔（如 `objective-c-support`）
- **type**: 類型後綴
  - `implementation`: 實作記錄
  - `analysis`: 分析報告
  - `decision`: 決策記錄
  - `test`: 測試報告
  - `experiment`: 實驗嘗試

**範例**:
```
2025-11-23-objective-c-support-implementation.md
2025-11-20-toon-vs-yaml-decision.md
2025-11-22-atlas-pattern-implementation.md
```

### Step 3: 確定存放位置

```bash
# 決策邏輯
if 檔案完成日期屬於當前月或上個月:
    放在 dev-notes/YYYY-MM/
elif 檔案是「決策分析」類型:
    放在 dev-notes/archives/decisions/
elif 檔案是「方法論深度分析」:
    放在 dev-notes/archives/lessons/
else:
    放在 dev-notes/YYYY-MM/ (對應月份)
```

### Step 4: 檢查是否需要合併

**合併條件**（滿足任一即合併）：
1. 同一天（YYYY-MM-DD）+ 同一主題 → 合併為一個檔案
2. 同一主題的多個測試結果 → 合併為一個完整報告
3. 計劃 + 實作 + 報告 → 合併為完整記錄

## 更新大寫檔案的規則

### 更新 HISTORY.md

每完成一個重大功能/決策，**立即追加**一條記錄：

```markdown
### Week N (MM/DD-MM/DD): 主題
- **功能名稱** (MM/DD): 簡短描述（1 行）→ [詳細](連結)
```

### 更新 KEY_LEARNINGS.md

每發現重要學習，追加到相應章節：

```markdown
### N. 學習標題
**發現**: 1 句話
**證據**: 1 句話
**應用**: 1 句話
→ [完整分析](連結)
```

### 更新 ROADMAP.md

- 每週更新「Immediate Actions」
- 每月更新「Phase Progress」

### 更新月度 README

每月最後一天，更新 `YYYY-MM/README.md`：

```markdown
## 本月重點
（2-3 句話總結）

## 主要成果
（列出 3-5 個重點，每個 2-3 行 + 連結）

## 關鍵學習
（提煉 2-3 個核心學習）
```

## 執行原則（AI 必須遵守）

1. **絕不創建新的大寫檔案**（除非明確討論並批准）
2. **所有新內容使用日期前綴**
3. **完成後立即更新 HISTORY.md**
4. **同主題內容必須合併**
5. **每月最後一天檢查並更新月度 README**
6. **3 個月前的內容考慮移到 archives/**

## 驗證工具

創建或整理檔案後，執行檢查：

```bash
# 驗證結構
dev-notes/scripts/validate.sh

# 檢查項目：
# - 檔名符合規範（大寫或日期前綴）
# - 大寫檔案不超過 5 個
# - 日期檔案有對應的月度資料夾
# - 月度 README.md 存在且完整
# - HISTORY.md 有最新記錄
```

## 資訊分層原則

本資料夾遵循 SourceAtlas 的資訊理論原則：

- **Layer 0** (README.md): 10 秒快速理解
- **Layer 1** (5 個核心檔案): 5 分鐘掌握全貌
- **Layer 2** (月度資料夾): 30 分鐘理解細節
- **Layer 3** (archives/): 深度挖掘

**完整規範**: 見 [dev-notes/README.md](./dev-notes/README.md)
