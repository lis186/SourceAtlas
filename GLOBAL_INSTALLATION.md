# SourceAtlas 全局安裝指南

讓 SourceAtlas 的 `/atlas-overview` 和 `/atlas-pattern` 命令在任何專案都可以使用！

---

## 快速開始

### 1. 安裝全局命令

在 SourceAtlas 專案根目錄執行：

```bash
./install-global.sh
```

這會將 SourceAtlas 命令安裝到 `~/.claude/commands/`，讓你可以在任何專案中使用。

### 2. 驗證安裝

```bash
./install-global.sh --check
```

你應該會看到：

```
✓ atlas-overview.md → [path] (symlink OK)
✓ atlas-pattern.md → [path] (symlink OK)
✓ scripts/atlas → [path] (symlink OK)
✓ All commands installed and working
```

### 3. 開始使用

現在你可以在 **任何專案** 中使用這些命令：

```bash
# 在任何專案目錄中
cd ~/projects/my-other-project

# 在 Claude Code 中執行
/atlas-overview
/atlas-pattern "api endpoint"
```

---

## 可用命令

### `/atlas-overview [directory]`

快速專案指紋分析（Stage 0）

- **掃描效率**: <5% 檔案
- **理解深度**: 70-80%
- **完成時間**: 10-15 分鐘
- **輸出格式**: YAML

**使用範例**:

```bash
/atlas-overview              # 分析當前目錄
/atlas-overview src/api      # 分析特定目錄
```

**適用場景**:
- 接手新的代碼庫
- 代碼審查和技術盡職調查
- 評估開源專案
- 學習新框架或模式

### `/atlas-pattern [pattern-type]`

從當前代碼庫學習設計模式

- **掃描效率**: 2-3 個範例檔案
- **完成時間**: 5-10 分鐘
- **輸出格式**: Markdown

**支援的 Pattern 類型**:

| Pattern | 使用範例 | 說明 |
|---------|---------|------|
| API Endpoint | `/atlas-pattern "api endpoint"` | RESTful API 實作模式 |
| Background Job | `/atlas-pattern "background job"` | 異步任務處理模式 |
| File Upload | `/atlas-pattern "file upload"` | 檔案上傳處理模式 |
| Database Query | `/atlas-pattern "database query"` | 資料庫查詢模式 |
| Authentication | `/atlas-pattern "auth"` | 認證和授權模式 |
| SwiftUI View | `/atlas-pattern "swiftui view"` | SwiftUI 視圖組件模式 |
| View Controller | `/atlas-pattern "view controller"` | UIKit 控制器模式 |
| Networking | `/atlas-pattern "networking"` | 網路請求模式 |

**適用場景**:
- 實作新功能前先學習現有模式
- 確保代碼一致性
- 新團隊成員快速上手
- 重構前理解現有架構

---

## 安裝選項

### 預設方式：符號連結（Symlink）

```bash
./install-global.sh
```

**優點**:
- ✅ 自動同步更新 - SourceAtlas 更新時，所有專案立即可用
- ✅ 節省磁碟空間
- ✅ 單一真實來源

**適合**:
- 經常使用 SourceAtlas 的開發者
- 希望始終使用最新版本
- 管理多個專案

### 複製方式（Copy）

```bash
INSTALL_METHOD=copy ./install-global.sh
```

**優點**:
- ✅ 獨立副本 - 不依賴 SourceAtlas 專案位置
- ✅ 版本固定 - 不會意外被更新
- ✅ 可以自訂修改

**適合**:
- 需要穩定版本
- SourceAtlas 專案可能移動或刪除
- 想要客製化命令

### 比較表

| 特性 | Symlink（預設） | Copy |
|------|----------------|------|
| 同步更新 | ✅ 自動 | ❌ 需手動重新安裝 |
| 磁碟空間 | ✅ 最小 | ⚠️ 複製檔案 |
| 依賴性 | ⚠️ 依賴源專案 | ✅ 完全獨立 |
| 客製化 | ❌ 會影響源專案 | ✅ 可自由修改 |

---

## 管理命令

### 檢查安裝狀態

```bash
./install-global.sh --check
```

顯示：
- 安裝位置
- 命令狀態（符號連結或複製）
- 是否有損壞的連結

### 更新命令

**Symlink 方式**（自動）:
```bash
# 更新 SourceAtlas 代碼庫
cd ~/dev/sourceatlas2
git pull

# 所有專案自動使用最新版本！
```

**Copy 方式**（手動）:
```bash
# 重新執行安裝腳本
./install-global.sh
```

### 解除安裝

```bash
./install-global.sh --remove
```

這會刪除：
- `~/.claude/commands/atlas-overview.md`
- `~/.claude/commands/atlas-pattern.md`
- `~/.claude/scripts/atlas/`

---

## 目錄結構

### 安裝後的全局配置

```
~/.claude/
├── commands/
│   ├── atlas-overview.md        # → sourceatlas2/.claude/commands/
│   ├── atlas-pattern.md         # → sourceatlas2/.claude/commands/
│   └── [其他你的全局命令]
│
└── scripts/
    └── atlas/                    # → sourceatlas2/scripts/atlas/
        ├── detect-project-enhanced.sh
        ├── scan-entropy.sh
        ├── find-patterns.sh
        └── benchmark.sh
```

### 與專案級命令共存

SourceAtlas 命令安裝在 **全局級別**，與專案特定命令不衝突：

```
你的專案/
├── .claude/
│   └── commands/
│       ├── deploy.md            # 專案特定命令
│       └── test.md              # 專案特定命令
│
└── [你的專案檔案]

# Claude Code 會同時看到：
# - 全局: /atlas-overview, /atlas-pattern
# - 專案: /deploy, /test
```

**重要**: 根據 Claude Code 文檔，**相同名稱的全局和專案命令不支援衝突**。確保你的專案命令不使用 `atlas-overview` 或 `atlas-pattern` 這些名稱。

---

## 常見問題

### Q: 我能在 CI/CD 中使用全局命令嗎？

A: 可以！在 CI 環境中：

```yaml
# .github/workflows/analyze.yml
- name: Install SourceAtlas
  run: |
    git clone https://github.com/your-org/sourceatlas2.git
    cd sourceatlas2
    ./install-global.sh

- name: Analyze project
  run: |
    # Claude Code 現在可以使用 /atlas-overview
```

### Q: 全局命令會影響性能嗎？

A: 不會。Claude Code 在啟動時載入命令列表，但實際執行只在你使用時。即使安裝 100+ 全局命令也不會影響性能。

### Q: 我可以客製化全局命令嗎？

A: 可以，但方式取決於安裝方法：

**Symlink 方式**:
- 直接修改 `sourceatlas2/.claude/commands/` 中的源文件
- 修改會影響所有使用該命令的專案

**Copy 方式**:
- 直接修改 `~/.claude/commands/atlas-*.md`
- 只影響你的全局安裝

### Q: 如果我移動或刪除 SourceAtlas 專案會怎樣？

A:

**Symlink 方式**: 命令會損壞（broken symlink）
```bash
# 檢測損壞的連結
./install-global.sh --check

# 修復方法 1: 重新克隆到相同位置
cd ~/dev/sourceatlas2  # 或你原本的位置

# 修復方法 2: 解除安裝後重新安裝
./install-global.sh --remove
cd /new/location/sourceatlas2
./install-global.sh
```

**Copy 方式**: 不受影響，完全獨立

### Q: 全局命令能訪問專案特定的配置嗎？

A: 能！命令在執行時使用 **當前專案的上下文**：

- 工作目錄 = 當前專案目錄
- 可以讀取專案的 `.claude/settings.json`
- 可以訪問專案的所有檔案

範例：
```bash
# 在專案 A 執行
cd ~/projects/projectA
/atlas-overview        # 分析 projectA

# 在專案 B 執行
cd ~/projects/projectB
/atlas-overview        # 分析 projectB
```

### Q: 我可以創建自己的全局命令嗎？

A: 當然可以！學習 SourceAtlas 的模式：

```bash
# 1. 創建你的命令檔案
cat > ~/.claude/commands/my-command.md << 'EOF'
---
description: My custom command
allowed-tools: Bash, Read
---

# My Command

[你的 prompt 內容...]
EOF

# 2. 測試
# 在任何專案中使用 /my-command
```

參考 SourceAtlas 的命令結構：
- `.claude/commands/atlas-overview.md`
- `.claude/commands/atlas-pattern.md`

---

## 卸載

如果你想完全移除 SourceAtlas 全局命令：

```bash
./install-global.sh --remove
```

這會清理：
- 所有 atlas-* 命令
- scripts/atlas 目錄
- 但保留其他全局命令

---

## 技術細節

### 安裝機制

安裝腳本執行以下操作：

1. **創建目錄結構**:
   ```bash
   mkdir -p ~/.claude/commands
   mkdir -p ~/.claude/scripts
   ```

2. **連結或複製命令**:
   ```bash
   # Symlink
   ln -s $SOURCE/.claude/commands/atlas-*.md ~/.claude/commands/

   # Copy
   cp $SOURCE/.claude/commands/atlas-*.md ~/.claude/commands/
   ```

3. **連結腳本**（總是 symlink，確保腳本更新）:
   ```bash
   ln -s $SOURCE/scripts/atlas ~/.claude/scripts/atlas
   ```

### 命令解析順序

根據 Claude Code 文檔，設定優先級為：

1. **企業管理策略**（最高，不可覆蓋）
2. **命令行參數**（臨時覆蓋）
3. **專案本地設定** (`.claude/settings.local.json`)
4. **專案共享設定** (`.claude/settings.json`)
5. **用戶全局設定** (`~/.claude/settings.json`)（最低）

命令則是簡單的合併：全局 + 專案級別（不允許同名）

### 路徑解析

命令中的相對路徑（如 `scripts/atlas/detect-project-enhanced.sh`）會相對於：
- **執行目錄**（當前專案）
- 因此我們需要 symlink scripts 到全局位置

---

## 進階用法

### 與 Dotfiles 整合

如果你使用 dotfiles 管理配置：

```bash
# 將 SourceAtlas 作為 submodule
cd ~/dotfiles
git submodule add https://github.com/your-org/sourceatlas2.git tools/sourceatlas

# 在 dotfiles 安裝腳本中
~/dotfiles/tools/sourceatlas/install-global.sh
```

### 團隊共享配置

在團隊內標準化 SourceAtlas 使用：

```bash
# 團隊 setup script
#!/bin/bash
# setup-dev-env.sh

echo "Installing SourceAtlas..."
if [ ! -d "$HOME/tools/sourceatlas2" ]; then
    git clone https://github.com/your-org/sourceatlas2.git ~/tools/sourceatlas2
fi

cd ~/tools/sourceatlas2
git pull
./install-global.sh

echo "✓ SourceAtlas installed globally"
echo "You can now use /atlas-overview and /atlas-pattern in any project"
```

---

## 相關資源

- **主要文檔**: [README.md](./README.md)
- **使用指南**: [USAGE_GUIDE.md](./USAGE_GUIDE.md)
- **Prompts 模板**: [PROMPTS.md](./PROMPTS.md)
- **產品需求**: [PRD.md](./PRD.md)

---

## 回饋和貢獻

如果你遇到問題或有改進建議：

1. 檢查 `./install-global.sh --check` 輸出
2. 查看 `dev-notes/` 中的實作記錄
3. 提交 issue 或 PR

---

**享受在任何專案中使用 SourceAtlas 吧！** 🚀
