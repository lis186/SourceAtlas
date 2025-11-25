# SourceAtlas 全局安裝指南

**一次安裝，在任何專案使用 3 個 SourceAtlas 命令**

v2.5 | 更新時間: 2025-11-25

---

## 系統需求

在開始前，請確認系統符合以下需求：

| 需求 | 最低版本 | 檢查方式 |
|------|---------|---------|
| **Claude Code** | 0.3+ | 在 Claude Code 執行 `/help` |
| **Git** | 2.0+ | `git --version` |
| **Bash** | 3.2+ | `bash --version` |
| **作業系統** | macOS 11+ / Ubuntu 20.04+ | `uname -a` |

**快速驗證**：

```bash
# 一鍵檢查所有依賴
echo "Claude Code: 需手動檢查（執行 /help）"
echo "Git: $(git --version 2>&1 | head -1)"
echo "Bash: $(bash --version 2>&1 | head -1)"
echo "OS: $(uname -s) $(uname -r)"
```

⚠️ **不符合需求？** 見[疑難排解](#疑難排解)章節

---

## 快速開始

### 1. 安裝

在 SourceAtlas 專案根目錄執行：

```bash
./install-global.sh
```

這會將 3 個命令安裝到 `~/.claude/commands/`。

### 2. 驗證安裝

```bash
./install-global.sh --check
```

你應該會看到：

```
✓ atlas-overview.md → [path] (symlink OK)
✓ atlas-pattern.md → [path] (symlink OK)
✓ atlas-impact.md → [path] (symlink OK)
✓ scripts/atlas → [path] (symlink OK)
✓ All commands installed and working
```

### 3. 開始使用

現在你可以在 **任何專案** 中使用：

```bash
cd ~/projects/any-project

# 在 Claude Code 中執行
/atlas-overview
/atlas-pattern "api endpoint"
/atlas-impact "src/api/users.ts"
```

---

## 可用命令

### `/atlas-overview`

快速理解專案全貌

- **時間**: 10-15 分鐘
- **得到**: 技術棧、架構模式、代碼品質、專案規模

### `/atlas-pattern [pattern]`

學習設計模式

- **時間**: 0.1-30 秒
- **得到**: 最佳範例檔案 + 實作指南
- **支援**: 71 個 patterns (iOS/TypeScript/Android)

### `/atlas-impact [target]`

分析代碼變更影響

- **時間**: 1-2 分鐘
- **得到**: 依賴追蹤、Breaking Changes、Migration Checklist
- **iOS 特別**: Swift/ObjC interop 風險分析

---

## 安裝選項

### 預設：符號連結（Symlink）

```bash
./install-global.sh
```

**優點**:
- ✅ 自動同步更新
- ✅ 節省磁碟空間
- ✅ 單一真實來源

**適合**: 經常使用、希望自動更新

### 複製方式（Copy）

```bash
INSTALL_METHOD=copy ./install-global.sh
```

**優點**:
- ✅ 獨立副本
- ✅ 版本固定
- ✅ 可以自訂修改

**適合**: 需要穩定版本、想要客製化

---

## 管理命令

### 檢查安裝狀態

```bash
./install-global.sh --check
```

### 更新命令

**Symlink 方式**（自動）:
```bash
cd ~/dev/sourceatlas2
git pull
# 所有專案自動使用最新版本
```

**Copy 方式**（手動）:
```bash
cd ~/dev/sourceatlas2
git pull
./install-global.sh
```

### 解除安裝

```bash
./install-global.sh --remove
```

這會刪除：
- `~/.claude/commands/atlas-overview.md`
- `~/.claude/commands/atlas-pattern.md`
- `~/.claude/commands/atlas-impact.md`
- `~/.claude/scripts/atlas/`

---

## 目錄結構

### 安裝後的全局配置

```
~/.claude/
├── commands/
│   ├── atlas-overview.md        # → sourceatlas2/.claude/commands/
│   ├── atlas-pattern.md         # → sourceatlas2/.claude/commands/
│   ├── atlas-impact.md          # → sourceatlas2/.claude/commands/
│   └── [你的其他全局命令]
│
└── scripts/
    └── atlas/                    # → sourceatlas2/scripts/atlas/
```

### 與專案級命令共存

全局命令與專案特定命令不衝突：

```
你的專案/
├── .claude/
│   └── commands/
│       ├── deploy.md            # 專案特定命令
│       └── test.md              # 專案特定命令

# Claude Code 會同時看到：
# - 全局: /atlas-overview, /atlas-pattern, /atlas-impact
# - 專案: /deploy, /test
```

**注意**: 確保專案命令不使用 `atlas-*` 名稱，避免衝突。

---

## 常見問題

### Q: 全局命令會影響性能嗎？

A: 不會。Claude Code 只在你使用時才執行命令。

### Q: 我可以客製化全局命令嗎？

A: 可以！

**Symlink 方式**: 修改 `sourceatlas2/.claude/commands/` 源文件（影響所有專案）

**Copy 方式**: 修改 `~/.claude/commands/atlas-*.md`（只影響本地）

### Q: 如果我移動或刪除 SourceAtlas 專案會怎樣？

**Symlink 方式**: 命令會損壞
```bash
# 修復：重新克隆到相同位置或解除安裝後重裝
./install-global.sh --remove
cd /new/location/sourceatlas2
./install-global.sh
```

**Copy 方式**: 不受影響

### Q: 我可以創建自己的全局命令嗎？

A: 可以！參考 SourceAtlas 命令結構：

```bash
# 創建你的命令
cat > ~/.claude/commands/my-command.md << 'EOF'
---
description: My custom command
---

# My Command Prompt
[你的 prompt 內容...]
EOF

# 在任何專案使用
/my-command
```

---

## 疑難排解

### 問題：命令不可用

**症狀**: 執行 `/atlas-overview` 時 Claude Code 找不到命令

**解決方式**:
```bash
# 1. 檢查安裝
./install-global.sh --check

# 2. 重新安裝
./install-global.sh --remove
./install-global.sh
```

### 問題：Symlink 損壞

**症狀**: `--check` 顯示 broken symlink

**解決方式**:
```bash
# 確認 SourceAtlas 專案存在
ls ~/dev/sourceatlas2

# 如果不存在，重新克隆
git clone https://github.com/lis186/SourceAtlas2.git ~/dev/sourceatlas2

# 重新安裝
cd ~/dev/sourceatlas2
./install-global.sh
```

---

## 更多資源

- **主要文檔**: [README.md](./README.md)
- **使用指南**: [USAGE_GUIDE.md](./USAGE_GUIDE.md)
- **回報問題**: [GitHub Issues](https://github.com/lis186/SourceAtlas2/issues)

---

**享受在任何專案中使用 SourceAtlas！** 🚀
