# code-maat 輸出格式速查表

快速參考 code-maat 各種分析的 CSV 輸出格式。

---

## 🎯 核心分析類型

### 1. revisions - 變更頻率

```bash
maat -l git.log -c git2 -a revisions
```

**輸出格式**：
```csv
entity,n-revs
src/payment_service.rb,245
src/auth_controller.rb,156
src/user_model.rb,89
```

| 欄位 | 說明 | 範例 |
|------|------|------|
| entity | 檔案路徑 | src/payment_service.rb |
| n-revs | 修訂次數 | 245 |

---

### 2. churn - 程式碼變動量

```bash
maat -l git.log -c git2 -a churn
```

**輸出格式**：
```csv
entity,added,deleted,commits
src/payment_service.rb,3450,890,245
src/auth_controller.rb,2100,450,156
src/user_model.rb,1200,320,89
```

| 欄位 | 說明 | 範例 |
|------|------|------|
| entity | 檔案路徑 | src/payment_service.rb |
| added | 新增的程式碼行數 | 3450 |
| deleted | 刪除的程式碼行數 | 890 |
| commits | 提交次數 | 245 |

---

### 3. coupling - 耦合度

```bash
maat -l git.log -c git2 -a coupling
```

**輸出格式**：
```csv
entity,coupled,degree,average-revs
payment_service.rb,payment_controller.rb,92,245
payment_service.rb,stripe_integration.rb,78,245
user_model.rb,user_controller.rb,85,89
```

| 欄位 | 說明 | 範例 | 備註 |
|------|------|------|------|
| entity | 主要檔案 | payment_service.rb | |
| coupled | 耦合的檔案 | payment_controller.rb | |
| degree | 耦合程度 | 92 | 百分比，0-100 |
| average-revs | 平均修訂次數 | 245 | |

**耦合度解讀**：
- 90-100: 極強耦合（幾乎總是一起改）
- 70-89: 強耦合（常一起改）
- 50-69: 中度耦合（有時一起改）
- <50: 弱耦合（偶爾一起改）

---

### 4. authors / hotspot-authors - 作者分析

```bash
maat -l git.log -c git2 -a authors
# 或
maat -l git.log -c git2 -a hotspot-authors
```

**輸出格式**：
```csv
entity,n-authors,n-revs
payment_service.rb,8,245
auth_controller.rb,5,156
user_model.rb,4,89
```

| 欄位 | 說明 | 範例 |
|------|------|------|
| entity | 檔案路徑 | payment_service.rb |
| n-authors | 貢獻者人數 | 8 |
| n-revs | 修訂次數 | 245 |

**作者數解讀**：
- 8+: 協作複雜，可能需要更好的文檔
- 5-7: 正常協作範圍
- 2-4: 小團隊維護
- 1: 單一維護者（知識風險）

---

### 5. main-dev - 主要開發者

```bash
maat -l git.log -c git2 -a main-dev
```

**輸出格式**：
```csv
entity,main-dev,added,total-added,ownership
payment_service.rb,Alice,1850,2380,0.78
payment_controller.rb,Bob,890,1200,0.74
user_model.rb,Charlie,650,1100,0.59
```

| 欄位 | 說明 | 範例 | 備註 |
|------|------|------|------|
| entity | 檔案路徑 | payment_service.rb | |
| main-dev | 主要開發者名稱 | Alice | |
| added | 該開發者新增的行數 | 1850 | |
| total-added | 總新增行數 | 2380 | |
| ownership | 所有權百分比 | 0.78 | 0-1 的小數 |

**所有權解讀**：
- 0.8-1.0: 主導者（78%+ 的程式碼）
- 0.6-0.79: 主要貢獻者
- 0.4-0.59: 重要貢獻者
- <0.4: 次要貢獻者

---

### 6. entity-ownership - 所有權分布

```bash
maat -l git.log -c git2 -a entity-ownership
```

**輸出格式**：
```csv
entity,author,added,deleted
payment_service.rb,Alice,1850,230
payment_service.rb,Bob,356,89
payment_service.rb,Charlie,174,41
payment_controller.rb,Bob,890,120
```

| 欄位 | 說明 | 範例 |
|------|------|------|
| entity | 檔案路徑 | payment_service.rb |
| author | 作者名稱 | Alice |
| added | 該作者新增的行數 | 1850 |
| deleted | 該作者刪除的行數 | 230 |

**用途**：
- 了解每個檔案的貢獻者分布
- 識別知識集中風險
- 規劃 code review 分配

---

### 7. soc - 變更集中度

```bash
maat -l git.log -c git2 -a soc
```

**輸出格式**：
```csv
entity,soc
payment_service.rb,456
auth_controller.rb,342
user_model.rb,218
```

| 欄位 | 說明 | 範例 | 備註 |
|------|------|------|------|
| entity | 檔案路徑 | payment_service.rb | |
| soc | Sum of Coupling | 456 | 數字越高，越常跟其他檔案一起改 |

**SOC 解讀**：
- 高 SOC: 核心檔案，改動影響大
- 低 SOC: 獨立檔案，改動影響小

---

## 🔧 參數選項

### 常用參數

```bash
-l, --log <file>           # Git log 檔案
-c, --version-control <vcs> # 版本控制系統（使用 git2）
-a, --analysis <type>      # 分析類型
-n, --min-revs <num>       # 最小變更次數（預設5）
-i, --min-coupling <num>   # 最小耦合度（預設30）
-r, --rows <num>           # 限制輸出行數
-o, --output <file>        # 輸出檔案
```

### 範例

```bash
# 只顯示變更10次以上的檔案
maat -l git.log -c git2 -a revisions -n 10

# 只顯示耦合度50以上的關係
maat -l git.log -c git2 -a coupling -i 50

# 只顯示前20個結果
maat -l git.log -c git2 -a authors -r 20

# 輸出到指定檔案
maat -l git.log -c git2 -a revisions -o output.csv
```

---

## 📊 解析 CSV 的 awk 技巧

### 讀取特定欄位

```bash
# 讀取第2行第2欄（跳過標題）
awk -F, 'NR==2 {print $2}' revisions.csv

# 讀取所有檔案名稱（跳過標題）
awk -F, 'NR>1 {print $1}' revisions.csv

# 篩選特定條件（耦合度>80）
awk -F, 'NR>1 && $3>80 {print $1, $2, $3}' coupling.csv
```

### 格式化輸出

```bash
# 轉換為 YAML 格式
awk -F, 'NR>1 {print "  - file: " $1 "\n    revisions: " $2}' revisions.csv

# 計算總和
awk -F, 'NR>1 {sum+=$2} END {print sum}' revisions.csv

# 找出最大值
awk -F, 'NR>1 {if($2>max) max=$2} END {print max}' revisions.csv
```

---

## 🚀 完整工作流範例

```bash
#!/bin/bash
# 完整的 code-maat 分析流程

FILE="src/payment_service.rb"

# Step 1: 產生 git log
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%an' \
    --no-renames \
    -- "$FILE" > /tmp/file.log

# 全專案 log（用於 coupling）
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%an' \
    --no-renames > /tmp/full.log

# Step 2: 執行分析
maat -l /tmp/file.log -c git2 -a revisions > /tmp/revisions.csv
maat -l /tmp/file.log -c git2 -a churn > /tmp/churn.csv
maat -l /tmp/file.log -c git2 -a authors > /tmp/authors.csv
maat -l /tmp/file.log -c git2 -a main-dev > /tmp/main-dev.csv
maat -l /tmp/full.log -c git2 -a coupling | grep "$FILE" > /tmp/coupling.csv

# Step 3: 解析結果
echo "File: $FILE"
echo "Revisions: $(awk -F, 'NR==2 {print $2}' /tmp/revisions.csv)"
echo "Authors: $(awk -F, 'NR==2 {print $2}' /tmp/authors.csv)"
echo "Main Dev: $(awk -F, 'NR==2 {print $2}' /tmp/main-dev.csv)"
echo "Churn: +$(awk -F, 'NR==2 {print $2}' /tmp/churn.csv) -$(awk -F, 'NR==2 {print $3}' /tmp/churn.csv)"

# Step 4: 清理
rm /tmp/*.csv /tmp/*.log
```

---

## 📝 注意事項

### CSV 格式

- ✅ 第一行是標題（欄位名稱）
- ✅ 欄位間用逗號分隔
- ✅ 沒有引號（除非值包含逗號）
- ✅ 數字不含千位分隔符

### 常見陷阱

1. **忘記跳過標題行**
   ```bash
   # ❌ 錯誤：會讀到標題
   awk -F, '{print $1}' data.csv
   
   # ✅ 正確：跳過第一行
   awk -F, 'NR>1 {print $1}' data.csv
   ```

2. **欄位索引錯誤**
   ```bash
   # ❌ 錯誤：欄位從1開始，不是0
   awk -F, '{print $0}' data.csv  # $0 是整行
   
   # ✅ 正確：第一欄是 $1
   awk -F, '{print $1}' data.csv
   ```

3. **coupling 需要完整 log**
   ```bash
   # ❌ 錯誤：用特定檔案的 log
   git log -- file.rb > git.log
   maat -l git.log -c git2 -a coupling  # 結果不完整
   
   # ✅ 正確：用完整專案的 log
   git log --all > git.log
   maat -l git.log -c git2 -a coupling
   ```

4. **大型專案效能問題**
   ```bash
   # ⚠️ 大型專案可能很慢
   # 10萬+ commits: 可能需要 3-6 分鐘
   # git log 可能達到 1 GB+
   
   # 💡 暫時解決方案：限制時間範圍
   git log --since="6 months ago" > git.log
   
   # 💡 或只分析特定目錄
   git log -- src/ > git.log
   
   # 📋 完整的優化方案（分批、快取、增量更新）
   # 請參考主文檔的「大型 Codebase 的效能考量」章節
   ```

---

## 🔗 相關資源

- code-maat GitHub: https://github.com/adamtornhill/code-maat
- 書籍: "Your Code as a Crime Scene" by Adam Tornhill
- 書籍: "Software Design X-Rays" by Adam Tornhill
- SourceAtlas 主文檔: SOURCEATLAS_CODEMAAT_INTEGRATION.md

---

**快速提示**：
- 用 `head` 快速查看 CSV: `head -5 revisions.csv`
- 用 `wc -l` 計算行數: `wc -l revisions.csv`
- 用 `sort` 排序: `sort -t, -k2 -n revisions.csv`
