# 大型 Codebase 效能考量 - 快速參考

> ⚠️ **狀態**: 待討論的優化方向，尚未實作

---

## 🎯 問題概述

大型或歷史悠久的 codebase 在使用 code-maat 時可能遇到：

### 執行時間
- **小型專案** (<10K commits): 通常 <1 分鐘
- **中型專案** (10K-50K commits): 可能 1-3 分鐘
- **大型專案** (50K-100K commits): 可能 3-6 分鐘
- **超大型專案** (>100K commits): 可能 >10 分鐘

### 檔案體積
- git log 輸出可能達到數百 MB 甚至 1 GB+
- code-maat 需要載入整個檔案到記憶體

### 記憶體
- JVM heap size 可能不足
- 大量檔案的 coupling 分析特別耗記憶體

---

## 💡 暫時解決方案（當前可用）

### 1. 限制時間範圍
```bash
# 只分析最近 6 個月
git log --since="6 months ago" --numstat \
    --pretty=format:'--%h--%ad--%an' > git.log

maat -l git.log -c git2 -a revisions
```

### 2. 限制分析範圍
```bash
# 只分析特定目錄
git log --all --numstat \
    --pretty=format:'--%h--%ad--%an' \
    -- src/ > git.log

maat -l git.log -c git2 -a coupling
```

### 3. 使用快取
```bash
# 避免重複產生 git log
CACHE_DIR="$HOME/.sourceatlas/cache"
CACHE_FILE="$CACHE_DIR/git.log"

if [ -f "$CACHE_FILE" ] && [ $(find "$CACHE_FILE" -mmin -60) ]; then
    # 使用 60 分鐘內的快取
    cp "$CACHE_FILE" git.log
else
    # 重新產生
    git log --all --numstat \
        --pretty=format:'--%h--%ad--%an' > git.log
    cp git.log "$CACHE_FILE"
fi
```

### 4. 增加 JVM 記憶體
```bash
# 如果遇到 OutOfMemoryError
java -Xmx4g -jar code-maat.jar -l git.log -c git2 -a coupling
```

---

## 🚀 未來優化方案（待討論）

詳細內容請參考主文檔的「大型 Codebase 的效能考量」章節。

### 方案 1: 分批處理
將分析拆分為多個時間範圍，可並行處理。

**適用場景**: 需要完整歷史但可以分段處理

### 方案 2: 多層快取
L1 記憶體快取 → L2 檔案快取 → L3 增量快取

**適用場景**: 頻繁執行分析的情況

### 方案 3: 增量更新
只分析新的 commits，合併到現有結果。

**適用場景**: 持續監控，定期更新

**挑戰**: coupling 需要重新計算

### 方案 4: 取樣分析
只分析部分歷史或部分 commits。

**適用場景**: 快速概覽，不需要精確數據

### 方案 5: 資料庫儲存
將分析結果存入 SQLite，支援增量更新。

**適用場景**: 需要快速查詢和更新的生產環境

---

## 📊 效能基準（待補充）

需要在真實專案上測試才能確定實際效能：

| 專案規模 | Commits | 檔案數 | 當前耗時 | 優化目標 |
|---------|---------|--------|---------|---------|
| 小型 | <10K | <500 | ? | <30秒 |
| 中型 | 10K-50K | 500-2K | ? | <2分鐘 |
| 大型 | 50K-100K | 2K-5K | ? | <5分鐘 |
| 超大型 | >100K | >5K | ? | <10分鐘 |

---

## 🤔 討論要點

在實作任何優化方案前，需要討論：

### 1. 快取失效策略
- 如何判斷快取是否過期？
- 檔案修改後如何觸發更新？
- 快取大小限制是多少？

### 2. 增量更新的準確性
- coupling 必須重新計算嗎？
- ownership 百分比如何增量更新？
- 可接受的誤差範圍是多少？

### 3. 使用者體驗
- 第一次執行慢（完整分析）可以接受嗎？
- 需要進度條嗎？
- 後台更新 vs 即時更新？

### 4. 資源限制
- JVM heap size 設定多少合理？
- 磁碟空間預算是多少？
- 可接受的分析時間上限？

### 5. 降級策略
- 超大專案是否自動切換到取樣模式？
- 提供「快速模式」vs「完整模式」？
- 如何通知使用者當前使用的模式？

---

## 📋 實作建議

### Phase 1 (當前)
- ✅ 實作基本快取（60分鐘）
- ✅ 並行處理多個分析
- ⏸️ 暫不處理大型專案優化
- 📝 收集使用者回饋

**原因**: 先確保基本功能穩定，再考慮優化

### Phase 2 (未來)
- 📊 收集真實專案的效能數據
- 📊 分析瓶頸（git log vs code-maat）
- 🎯 根據數據決定優化方向
- 💡 實作 ROI 最高的方案

**決策依據**: 
- 如果 80% 的使用者專案 <50K commits → 優先順序低
- 如果 50% 的使用者抱怨太慢 → 優先順序高

### Phase 3 (長期)
- 🚀 完整的增量更新系統
- 🗄️ 考慮資料庫支援
- ⚙️ 提供效能調優選項

---

## 🔍 如何提供回饋

如果你遇到效能問題，請提供以下資訊：

```bash
# 1. 專案規模
git rev-list --count HEAD
# 例如: 125043 commits

# 2. 檔案數量
git ls-files | wc -l
# 例如: 3456 files

# 3. git log 大小
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%an' > /tmp/git.log
ls -lh /tmp/git.log
# 例如: 234M

# 4. 實際執行時間
time maat -l /tmp/git.log -c git2 -a revisions
# 例如: real 3m24.567s

# 5. 記憶體使用
# 觀察執行時的記憶體用量
```

這些資訊將幫助我們：
- 了解真實的效能瓶頸
- 設計有效的優化方案
- 提供合理的效能預期

---

## 📚 參考資源

- **主文檔**: `SOURCEATLAS_CODEMAAT_INTEGRATION.md`
  - 第 10 章「部署與維護」→「效能優化」→「大型 Codebase 的效能考量」
- **格式速查表**: `CODE_MAAT_FORMAT_CHEATSHEET.md`
  - 包含快速解決方案
- **code-maat 專案**: https://github.com/adamtornhill/code-maat
  - 查看 Issues 中關於效能的討論

---

**重要提醒**：
- ⚠️ 以上優化方案都是「待討論」的方向
- ⚠️ 不要在未討論前自行實作複雜方案
- ⚠️ 當前應該專注於基本功能的穩定性
- ✅ 但可以收集效能數據作為未來決策依據
