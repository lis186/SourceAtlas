# atlas.audit Decision Spec

> 基於 README.md 提案 + 三方交叉審查（Claude / Gemini / Codex）的 scope 收斂文件。
>
> 決策日期：2026-03-16

---

## 1. 交付定義

### v1.0 Scope

| 面向 | 決策 | 理由 |
|------|------|------|
| 語言支援 | ObjC, Swift, TypeScript, JavaScript | ObjC 已驗證；Swift 補完 iOS 遷移場景；TS/JS 覆蓋前後端 |
| 框架 patterns | 拆分為 `lang-framework.patterns` | 避免噪音 anchors（例如 React 專案不該觸發 Angular patterns） |
| 整合方式 | pipeline 腳本 + `/atlas.audit` skill 命令 | 可獨立執行，也可透過 Claude Code skill 協調 |
| LLM 後端 | 維持 Gemini + Claude + Codex 三方 | v1.0 不做可替換後端 |
| 執行模式 | CLI 模式（三 LLM 齊備）或 Agent 模式（無 LLM 需求） | 不做部分降級（見 §8） |

### v1.0 不做

- Kotlin, Python, Rust, Java, Go 語言插件（P3）
- LLM 後端可替換（P3）
- 部分 LLM 降級策略（僅有 1-2 個 LLM 時的降級執行）（P3）
- 互動式合約審查 UI（P3+）
- 合約演進追蹤 / resolved 狀態（P3+）
- IDE 整合（P3+）

---

## 2. 已驗證 vs 待驗證

| 語言 | patterns 檔 | prompt 插件 | 端到端 run | 狀態 |
|------|:-----------:|:-----------:|:----------:|:----:|
| ObjC | ✅ 68 行 | ✅ | ✅ 多次（NYHTTPSClient.m） | 🟢 生產就緒 |
| Swift | ✅ | ✅ | ❌ | 🟡 需驗證 |
| TypeScript | ✅ 76 行 | ✅ | ❌ | 🟡 需驗證 |
| JavaScript | ❌ 需新建 | ❌ 需新建 | ❌ | 🔴 需開發 |

### 驗收門檻

每個語言必須通過：
1. 在一個 **真實檔案**（非範例）上跑完整管線（Step 0 → Step 4）
2. 產出 ≥10 個合約
3. Phase B CI grep 驗證 100% 通過
4. Codex 對抗性評論 CONFIRM_RATIO ≤ 70%

---

## 3. 框架 patterns 拆分方案

### 目錄結構

```
patterns/
├── objc.patterns              # ObjC（無框架拆分需求）
├── swift.patterns             # Swift 通用（Foundation/UIKit）
├── swift-combine.patterns     # Swift + Combine
├── swift-swiftui.patterns     # Swift + SwiftUI 生命週期
├── typescript.patterns        # TypeScript 通用（Node.js 核心）
├── typescript-react.patterns  # TypeScript + React
├── typescript-angular.patterns # TypeScript + Angular
├── typescript-rxjs.patterns   # TypeScript + RxJS
├── javascript.patterns        # JavaScript 通用
├── javascript-express.patterns # JavaScript + Express
├── javascript-node.patterns   # JavaScript + Node.js（stream, cluster, child_process）
└── README.md
```

### 載入邏輯

1. 永遠載入 `{lang}.patterns`（通用 patterns）
2. 如果 `audit.config.yml` 指定 `frameworks:`，追加載入對應的 `{lang}-{framework}.patterns`
3. 如果未指定 `frameworks:`，自動偵測（掃描 import/require 判斷使用了哪些框架）

```yaml
# audit.config.yml 範例
module: AuthService
language: typescript
frameworks: [react]        # 只載入 typescript.patterns + typescript-react.patterns
target_files:
  - src/services/AuthService.ts
```

### 自動偵測規則

| 框架 | 偵測條件 |
|------|---------|
| React | `import.*from ['"]react['"]` 或 `require\(['"]react['"]\)` |
| Angular | `@Component\|@Injectable\|@NgModule` |
| RxJS | `import.*from ['"]rxjs['"]` |
| Combine | `import Combine` |
| SwiftUI | `import SwiftUI` |
| Express | `require\(['"]express['"]\)\|from ['"]express['"]` |

---

## 4. /atlas.audit Skill 整合

### 命令介面

```bash
/atlas.audit <target>              # 審計指定檔案/模組
/atlas.audit --recommend           # 自動推薦審計目標（熵 × 變動 × 耦合）
/atlas.audit --config path.yml     # 使用指定配置檔
/atlas.audit --language swift      # 強制指定語言（覆蓋自動偵測）
/atlas.audit --frameworks react    # 強制指定框架
/atlas.audit --agent               # Agent 模式（輸出 prompt，不直接呼叫 LLM CLI）
```

### Skill 檔案位置

```
plugin/commands/audit/
├── SKILL.md                # Skill 定義（觸發條件、參數）
├── workflow.md             # 工作流程定義
├── output-template.md      # 合約輸出模板
└── verification-guide.md   # 驗證指南
```

### 輸出存儲

```
.sourceatlas/audit/
├── {module}.yaml           # 合約 YAML
├── {module}.log            # 管線執行記錄
└── archive/                # 歷次 run 備份（時間戳）
```

---

## 5. 三方審查的開放問題處置

| # | 問題 | 來源 | 決策 |
|---|------|------|------|
| 1 | P2 交付物（SKILL.md 等）位置不明 | Codex | v1.0 重新建立在 `plugin/commands/audit/`，不沿用不可追溯的舊產出 |
| 2 | TypeScript 無端到端驗證 | Gemini + Codex | v1.0 驗收標準要求每語言至少一次真實 run |
| 3 | LLM 輸出解析脆弱（CONFIRM/DISPUTE/ADD） | Codex | v1.0 加入 fuzzy match + retry 1 次，失敗則標記 UNCERTAIN 供人工複審 |
| 4 | 成本過高（50 模組 ~$25-77） | Codex | README 已正確標記批量場景為 ★☆☆☆☆，v1.0 不解決，文件明確說明 |
| 5 | JavaScript patterns 缺失 | 新增需求 | v1.0 新建 javascript.patterns + javascript-node.patterns |
| 6 | 框架 patterns 噪音 | Claude + Gemini | 採用拆分方案 + 自動偵測（見 §3） |

---

## 6. 實作順序

### Phase 1 — 補齊缺口（阻塞驗收的項目）

- [ ] **1.1** 建立 `patterns/javascript.patterns`（通用 JS patterns）
- [ ] **1.2** 建立 `patterns/javascript-node.patterns`（Node.js 特定）
- [ ] **1.3** 從現有 `typescript.patterns` 拆出 `typescript-react.patterns`、`typescript-angular.patterns`、`typescript-rxjs.patterns`
- [ ] **1.4** 從現有 `swift.patterns` 拆出 `swift-combine.patterns`、`swift-swiftui.patterns`
- [ ] **1.5** `run-baseline.sh` Step 0.7 支援多 patterns 檔載入（通用 + 框架）
- [ ] **1.6** `run-baseline.sh` LLM 輸出解析加入 fuzzy match + retry
- [ ] **1.7** `run-baseline.sh` 加入 preflight 環境檢查（工具可用性 + 檔案存在性）

### Phase 2 — 端到端驗證

- [ ] **2.1** Swift 真實檔案端到端 run（選擇待定）
- [ ] **2.2** TypeScript 真實檔案端到端 run（選擇待定）
- [ ] **2.3** JavaScript 真實檔案端到端 run（選擇待定）

### Phase 3 — Skill 整合

- [ ] **3.1** 建立 `plugin/commands/audit/SKILL.md`
- [ ] **3.2** 建立 workflow.md + output-template.md + verification-guide.md
- [ ] **3.3** 整合 `--recommend` 功能（scan-entropy + git hotspot）
- [ ] **3.4** 輸出存儲到 `.sourceatlas/audit/`

### 依賴關係

```
Phase 1 ──→ Phase 2 ──→ Phase 3
 (1.1-1.6)   (2.1-2.3)   (3.1-3.4)
```

Phase 1 內部各項可平行。Phase 2 各語言可平行。Phase 3 依賴 Phase 2 驗證通過。

---

## 7. 風險登記

| 風險 | 影響 | 緩解 |
|------|------|------|
| JavaScript patterns 品質不如 ObjC（缺乏實戰迭代） | 合約品質低 | 先在小檔案驗證，迭代 patterns |
| 框架自動偵測誤判 | 載入錯誤 patterns | config 中 `frameworks:` 可手動覆蓋 |
| Swift/TS 端到端驗證不通過 | 延遲交付 | ObjC 已證明管線可行，語言插件品質是可修復問題 |
| Skill 整合與現有 plugin 結構衝突 | 需重構 | Phase 3 前先審查 plugin/ 結構 |
| 使用者缺少部分 LLM CLI | 無法執行 CLI 模式 | Preflight 檢查 + 明確錯誤訊息引導安裝或改用 Agent 模式 |

---

## 8. 環境需求與 Preflight 檢查

### v1.0 執行模式

| 模式 | 條件 | 說明 |
|------|------|------|
| **CLI 模式**（預設） | gemini + claude + codex + rg 全部可用 | 完整三方交叉驗證管線 |
| **Agent 模式**（`--agent`） | 僅需 rg | 只執行靜態分析（Step 0-0.9），輸出 prompt 檔供外部 LLM 協調 |

**v1.0 不提供部分降級**（例如「有 Claude 但沒 Gemini」的自動跳步）。原因：三方交叉驗證是核心品質保證機制，部分跳步會產出品質不明確的合約，不如明確告知使用者。降級策略列入 P3。

### Preflight 檢查邏輯

`run-baseline.sh` 啟動時（在讀取 config 之後、Step 0 之前）執行：

```bash
# Agent 模式只需 rg
if [ "$AGENT_MODE" = "true" ]; then
  REQUIRED_TOOLS="rg"
else
  REQUIRED_TOOLS="rg gemini claude codex"
fi

MISSING=""
for tool in $REQUIRED_TOOLS; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    MISSING="$MISSING $tool"
  fi
done

if [ -n "$MISSING" ]; then
  echo "ERROR: 缺少必要工具:$MISSING" >&2
  echo "" >&2
  echo "安裝指引：" >&2
  for tool in $MISSING; do
    case "$tool" in
      rg)      echo "  rg:      brew install ripgrep" >&2 ;;
      gemini)  echo "  gemini:  npm install -g @google/gemini-cli         (需要 Google AI API key)" >&2 ;;
      claude)  echo "  claude:  npm install -g @anthropic-ai/claude-code  (需要 Anthropic API key)" >&2 ;;
      codex)   echo "  codex:   npm i -g @openai/codex                    (需要 OPENAI_API_KEY)" >&2 ;;
    esac
  done
  echo "" >&2
  echo "或使用 --agent 模式（僅需 rg，不呼叫 LLM CLI）：" >&2
  echo "  bash run-baseline.sh --agent [其他參數]" >&2
  exit 1
fi
```

### 檢查內容

| 檢查項 | CLI 模式 | Agent 模式 |
|--------|:--------:|:----------:|
| `rg` 可執行 | ✅ 必要 | ✅ 必要 |
| `gemini` 可執行 | ✅ 必要 | ⬜ 不需要 |
| `claude` 可執行 | ✅ 必要 | ⬜ 不需要 |
| `codex` 可執行 | ✅ 必要 | ⬜ 不需要 |
| target_files 存在 | ✅ 必要 | ✅ 必要 |
| patterns 檔存在 | ✅ 必要 | ✅ 必要 |
| language 已指定或可偵測 | ✅ 必要 | ✅ 必要 |

### 實作步驟

在 §6 Phase 1 追加：

- [ ] **1.7** `run-baseline.sh` 加入 preflight 環境檢查（工具可用性 + 檔案存在性）
