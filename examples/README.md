# examples/ - 外部參考專案

用於學習和研究的第三方專案。

## ⚠️ 重要說明

**此目錄內容不追蹤到 git**（除了本 README）

- 所有 clone 的專案都在 `.gitignore` 中
- 用於手動探索和學習，不用於自動化測試
- 想要的專案可以自行 clone 到這裡

---

## 🎯 用途

### 1. 研究不同架構模式
- 學習 MVC、MVVM、Clean Architecture 等實際應用
- 對比不同規模專案的組織方式

### 2. 驗證 SourceAtlas 分析方法
- 在真實專案上測試分析準確度
- 發現邊緣案例和改進點

### 3. 學習最佳實踐
- 觀察成熟專案的代碼品質
- 研究 AI 協作模式

---

## 📚 推薦範例

### Web 應用

**Rails Monolith** - 傳統 MVC 架構
```bash
cd examples
git clone https://github.com/discourse/discourse
```

**React SPA** - 現代前端
```bash
git clone https://github.com/vercel/next.js
```

### 移動應用

**iOS (SwiftUI)**
```bash
git clone https://github.com/pointfreeco/isowords
```

**Android (Kotlin)**
```bash
git clone https://github.com/android/architecture-samples
```

### 微服務

**Node.js Microservices**
```bash
git clone https://github.com/GoogleCloudPlatform/microservices-demo
```

---

## 🔍 與其他目錄的區別

| 目錄 | 用途 | 特性 | Git 追蹤 |
|------|------|------|---------|
| `examples/` | 手動探索學習 | 大型、完整專案 | ❌ 否 |
| `test_targets/` | 自動化驗證 | 精選、代表性專案 | ❌ 否 |
| `test_results/` | 分析輸出 | SourceAtlas 產生的報告 | ❌ 否 |

---

## 📝 如何使用

### 1. Clone 專案到這裡

```bash
cd <project-root>/examples
git clone <repository-url>
```

### 2. 執行 SourceAtlas 分析

```bash
cd <project-name>
/atlas.overview
```

### 3. 研究輸出並學習

比較 SourceAtlas 的分析與實際代碼結構

### 4. 記錄學習

在 `ideas/` 記錄發現，或在 `dev-notes/` 記錄方法論改進

---

## 🧹 清理建議

這些專案可能很大（幾百 MB），定期清理不需要的：

```bash
# 列出所有 clone 的專案大小
du -sh examples/*

# 刪除不需要的
rm -rf examples/old-project
```

---

## 💡 提示

- **不要直接修改** clone 的專案
- **善用分支** 如果想實驗：`git checkout -b experiment`
- **定期更新** 專案以獲取最新代碼：`git pull`
- **記錄發現** 在 ideas/ 或 dev-notes/ 中

---

## 🤝 貢獻

發現好的參考專案？歡迎更新此 README！

1. 在上方「推薦範例」區段新增
2. 說明為什麼值得學習
3. 提供 clone 命令
