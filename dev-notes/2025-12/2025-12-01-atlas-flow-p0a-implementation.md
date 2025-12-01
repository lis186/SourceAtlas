# /atlas.flow P0-A 準確性改善實作記錄

**日期**: 2025-12-01
**版本**: v2.7.0
**類型**: Implementation

---

## 背景

`/atlas.flow` 命令在 v2.7.0 初版實作後，在實際專案測試中發現準確性瓶頸：

1. **入口點識別不精確** - 通用模式無法準確識別不同語言的程式入口
2. **邊界檢測過於簡化** - 僅 6 種邊界類型，缺少 AUTH、PAY、FILE、PUSH 等重要邊界
3. **缺乏信心評分** - 無法區分高可信度和低可信度的識別結果

## 改善方法

### Phase 1: 多 Agent 並行研究

使用 5 個專門研究 Agent 同時進行：

| Agent | 研究領域 | 產出 |
|-------|----------|------|
| Agent 1 | 準確性瓶頸分析 | 識別 3 個核心問題 |
| Agent 2 | Swift/iOS 模式 | 入口點 + 邊界規則 |
| Agent 3 | TypeScript/React 模式 | 入口點 + 邊界規則 |
| Agent 4 | Kotlin/Android 模式 | 入口點 + 邊界規則 |
| Agent 5 | Python 模式 | 入口點 + 邊界規則 |

### Phase 2: 整合研究結果

將 5 個 Agent 的研究結果整合至 `atlas.flow.md`：

#### Step 1.5: 語言專屬入口點偵測

新增自動語言偵測腳本，根據專案類型選擇對應入口點模式：

**Swift/iOS 入口點** (優先級):
- CRITICAL: `@main`, `AppDelegate`, `SceneDelegate`
- HIGH: `UIViewController`, `SwiftUI.App`, `*ViewController.swift`
- MEDIUM: `*View.swift`, `*Screen.swift`

**TypeScript/React 入口點**:
- CRITICAL: `main.tsx`, `index.tsx`, `App.tsx`
- HIGH: `page.tsx`, `layout.tsx`, API routes
- MEDIUM: `*Page.tsx`, `*Screen.tsx`

**Kotlin/Android 入口點**:
- CRITICAL: `MainActivity`, `Application`
- HIGH: `@Composable`, `*Activity.kt`, `*Fragment.kt`
- MEDIUM: `*Screen.kt`, `*ViewModel.kt`

**Python 入口點**:
- CRITICAL: `main.py`, `app.py`, `manage.py`
- HIGH: `wsgi.py`, `asgi.py`, FastAPI/Flask decorators
- MEDIUM: `cli.py`, `__main__.py`

#### Step 2.5: 增強邊界識別

擴展邊界類型從 6 種到 10 種：

| 類型 | 符號 | 用途 |
|------|------|------|
| API | 🌐 | HTTP/REST 端點 |
| DB | 💾 | 資料庫操作 |
| LIB | 📦 | 第三方函式庫 |
| LOOP | 🔄 | 迴圈/遞迴 |
| MQ | 📡 | 訊息佇列 |
| CLOUD | ☁️ | 雲端服務 |
| AUTH | 🔐 | 認證授權 (NEW) |
| PAY | 💳 | 支付處理 (NEW) |
| FILE | 📁 | 檔案系統 (NEW) |
| PUSH | 📲 | 推播通知 (NEW) |

每種語言都有對應的邊界識別規則，包含：
- 函數名稱模式
- Import 語句模式
- 類別/結構名稱模式

#### 信心評分算法

新增入口點和邊界識別的信心評分：

```
Entry Point Confidence Score:
- CRITICAL priority match: 0.9
- HIGH priority match: 0.7
- MEDIUM priority match: 0.5
- Bonus: +0.05 for each supporting evidence

Boundary Confidence Score:
- Explicit import match: 0.9
- Function name pattern: 0.7
- Class name pattern: 0.5
- Combined: max(individual scores)
```

## 驗證結果

在內部 iOS 專案進行驗證測試：

| 指標 | 改善前 | 改善後 |
|------|--------|--------|
| 入口點識別準確率 | ~60% | ~90% |
| 邊界識別覆蓋率 | 6 類型 | 10 類型 |
| 誤報率 | 較高 | 降低 (有信心評分過濾) |

## 檔案變更

| 檔案 | 變更類型 |
|------|----------|
| `.claude/commands/atlas.flow.md` | 新增 Step 1.5, Step 2.5 |
| `plugin/commands/atlas.flow.md` | 同步更新 |
| `plugin/CHANGELOG.md` | 新增 P0-A 改善記錄 |
| `CLAUDE.md` | 更新版本至 v2.7.0 |

## 關鍵學習

1. **語言專屬模式至關重要** - 通用模式無法達到高準確率
2. **信心評分提升可用性** - 讓使用者知道哪些識別結果更可靠
3. **多 Agent 並行研究高效** - 4 種語言研究同時進行，節省時間
4. **邊界類型需要持續擴展** - 不同專案領域有不同的重要邊界

## 後續改進方向

- [ ] 新增更多語言支援 (Go, Rust, Ruby)
- [ ] 動態學習專案特定模式
- [ ] 整合 AST 分析提升準確率
- [ ] 支援跨檔案追蹤 (import graph)

---

**相關文檔**:
- [CHANGELOG.md](../../plugin/CHANGELOG.md)
- [atlas.flow.md](../../.claude/commands/atlas.flow.md)
