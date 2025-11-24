# 新語言支援方法論

**基於**: iOS Patterns 擴展實戰經驗（2025-11-23）
**適用於**: SourceAtlas 新增任何程式語言支援
**狀態**: v1.0 - 從實戰提煉的可重複框架

---

## 執行摘要

本文檔提煉出一套 **6 階段系統化方法**，用於為 SourceAtlas 新增任何程式語言的 pattern 支援。此方法論經過 iOS 擴展實戰驗證（18 patterns, 7 專案, 92%+ 準確率），可直接應用於其他語言（如 Kotlin, Go, Rust, Flutter, React Native 等）。

### 六大階段

1. **研究階段**（Research Phase）- 1-2 天
2. **測試專案準備**（Test Projects Setup）- 0.5-1 天
3. **Pattern 分層規劃**（Pattern Tiering）- 0.5 天
4. **分階段實作**（Phased Implementation）- 1-3 週
5. **品質驗證**（Quality Assurance）- 持續進行
6. **文檔產出**（Documentation）- 每階段完成後

**總時程**: 2-4 週（視語言複雜度）

---

## 階段 1: 研究階段（Research Phase）

**目標**: 深入理解目標語言的生態系統、主流架構、命名慣例

**時間**: 1-2 天

### 1.1 語言生態系統分析

**必答問題清單**:

1. **語言特性**:
   - [ ] 主要範式（OOP, FP, Procedural, Hybrid）
   - [ ] 類型系統（靜態/動態, 強/弱）
   - [ ] 記憶體管理（GC, ARC, Manual）
   - [ ] 並發模型（Thread, async/await, Goroutine, Actor）

2. **生態系統成熟度**:
   - [ ] 社群活躍度（GitHub repos, StackOverflow 問題數）
   - [ ] 官方指南與最佳實踐文檔
   - [ ] 主流框架/函式庫
   - [ ] 版本穩定性

3. **命名慣例研究**:
   - [ ] 檔案命名規則（camelCase, snake_case, kebab-case）
   - [ ] 目錄結構慣例（src/, lib/, app/, domain/）
   - [ ] Pattern 命名後綴/前綴（*Service, *Repository, Mock*, *Impl）

**範例：iOS 研究成果**:
```yaml
language: Swift
paradigm: OOP + FP (Protocol-Oriented)
type_system: Static, Strong
memory: ARC (Automatic Reference Counting)
concurrency: async/await, Actor (Swift 5.5+), GCD

ecosystem_maturity:
  community: 高 (GitHub: 300K+ repos)
  official_docs: 優秀 (Apple Developer Documentation)
  frameworks: SwiftUI, UIKit, Combine, TCA

naming_conventions:
  files: PascalCase.swift
  suffixes:
    - Delegate, Protocol (UIKit)
    - ViewModel, Store (SwiftUI)
    - Repository, Service, UseCase (Clean Arch)
  prefixes: Mock*, Fake* (Testing)
```

### 1.2 主流架構/框架識別

**調查清單**:

1. **官方推薦架構**:
   - 官方文檔推薦的架構模式
   - 官方範例專案使用的 patterns

2. **社群主流架構**:
   - MVC, MVVM, MVP, Clean Architecture
   - 函式庫特定架構（Redux, TCA, Elm, etc.）
   - 微服務 patterns（如適用）

3. **Framework 特定 Patterns**:
   - 框架強制的 patterns（如 Rails Convention over Configuration）
   - 框架提供的抽象（React Hooks, Vue Composables, SwiftUI ViewModifiers）

**輸出格式**（建議用表格）:

| 架構 | 流行度 | 使用場景 | 關鍵 Patterns |
|------|--------|----------|---------------|
| MVVM | ⭐⭐⭐⭐⭐ | 所有規模 | ViewModel, DataBinding |
| Clean Architecture | ⭐⭐⭐⭐ | 中大型 | UseCase, Repository, Entity |
| TCA | ⭐⭐⭐ | SwiftUI 專案 | Reducer, Action, State, Effect |
| Redux | ⭐⭐⭐ | 複雜狀態管理 | Reducer, Middleware, Action |

**iOS 實戰發現**:
- SwiftUI 專案 ≠ UIKit patterns（不同檔案結構）
- TCA 使用 `*Domain.swift`，不是 `*Reducer.swift`
- Redux 架構才有 Middleware，Clean Architecture 沒有

### 1.3 語言版本與現代化趨勢

**重點分析**:

1. **版本演進**:
   - 主要版本變化（如 Swift 5.5 引入 async/await）
   - Breaking changes 導致的 pattern 變化
   - 新特性取代舊 patterns（如 @Observable 取代 ObservableObject）

2. **現代化指標**:
   - 哪些 patterns 代表現代代碼（2023+）
   - 哪些 patterns 代表遺留代碼（<2020）
   - 過渡期 patterns（仍在使用但逐漸淘汰）

**iOS 範例**:
```
現代化時間線:
├─ Legacy (2014-2019): UIKit + Objective-C
│  └─ Patterns: Delegate, MVC, NSObject
│
├─ Transitional (2019-2022): SwiftUI 早期 + Combine
│  └─ Patterns: ObservableObject, @Published, Combine
│
└─ Modern (2023+): SwiftUI + async/await + @Observable
   └─ Patterns: @Observable, async/await, Actor, TCA
```

### 1.4 研究產出物

**必須產生的文檔**:

1. **語言生態系統報告** (`{language}-ecosystem-analysis.md`)
   - 語言特性總結
   - 主流框架列表
   - 命名慣例整理
   - 現代化趨勢分析

2. **Patterns 候選清單** (`{language}-patterns-candidates.md`)
   - 識別的所有可能 patterns（20-50 個）
   - 初步分層（Tier 1-2-3）
   - 每個 pattern 的：
     - 重要性評級（⭐⭐⭐⭐⭐）
     - 預估流行度
     - 檔案/目錄命名模式
     - 預期測試專案

**範例結構**:
```markdown
## Pattern: Repository

**重要性**: ⭐⭐⭐⭐⭐ (Tier 1)
**流行度**: 80% 的 Clean Architecture 專案
**適用架構**: Clean Architecture, DDD

**檔案命名模式**:
- `*Repository.swift`
- `*DAO.swift`
- `*Store.swift`

**目錄模式**:
- `Data/Repositories/`
- `Infrastructure/Persistence/`

**預期測試專案**: clean-architecture-swiftui, iOS-Clean-Architecture-MVVM
```

---

## 階段 2: 測試專案準備（Test Projects Setup）

**目標**: 選擇並準備多樣化的測試專案

**時間**: 0.5-1 天

### 2.1 測試專案選擇標準

**必須滿足的 4 個維度**:

#### 維度 1: 規模多樣性

| 規模 | LOC 範圍 | 數量 | 目的 |
|------|----------|------|------|
| **TINY** | <1K | 1 | 驗證基礎 patterns |
| **SMALL** | 1K-5K | 2 | 驗證核心架構 |
| **MEDIUM** | 5K-50K | 2 | 驗證企業級 patterns |
| **LARGE** | 50K-200K | 1-2 | 驗證大型專案複雜性 |
| **VERY_LARGE** | >200K | 1 | 壓力測試（可選） |

**最少**: 6 個專案（涵蓋 SMALL → LARGE）

#### 維度 2: 架構多樣性

**必須包含**:
- [ ] 官方推薦架構（如 Apple 的 MVC/SwiftUI）
- [ ] 社群主流架構（MVVM, Clean Architecture）
- [ ] 特定框架架構（TCA, Redux, VIPER）
- [ ] 遺留代碼範例（如 Objective-C 混用）

**iOS 範例覆蓋**:
```
✅ SwiftUI 現代 (IceCubesApp, OnlineStoreTCA) - 3 專案
✅ UIKit 遺留 (wikipedia-ios, ios-mail) - 2 專案
✅ Clean Architecture (clean-arch-swiftui, iOS-MVVM) - 2 專案
✅ TCA (OnlineStoreTCA) - 1 專案
✅ Redux (firefox-ios) - 1 專案
```

#### 維度 3: 社群驗證

**選擇標準**:
- ⭐ GitHub Stars: >1,000 (最好 >3,000)
- 📅 最後更新: <6 個月
- 📝 文檔品質: 有 README + 架構說明
- 🏆 代表性: 社群認可的範例專案

**為什麼重要**:
- 高 star 專案 = 社群驗證的最佳實踐
- 避免個人玩具專案的怪異 patterns
- 確保檢測結果有普遍適用性

#### 維度 4: 現代化程度

**時間分佈**:
- 🔴 Legacy (<2020): 1 個（驗證向後兼容）
- 🟡 Transitional (2020-2022): 2 個（主流）
- 🟢 Modern (2023+): 3 個（驗證現代 patterns）

### 2.2 專案 Clone 與整理

**標準化流程**:

```bash
#!/bin/bash
# clone-test-projects.sh

LANG="swift"  # 或 kotlin, go, rust, etc.
TARGET_DIR="test_targets"

# 定義專案列表（從研究階段產出）
declare -A PROJECTS=(
    ["IceCubesApp"]="https://github.com/Dimillian/IceCubesApp"
    ["clean-arch-swiftui"]="https://github.com/nalexn/clean-architecture-swiftui"
    # ... 其他專案
)

# Clone 所有專案
for name in "${!PROJECTS[@]}"; do
    url="${PROJECTS[$name]}"
    echo "Cloning $name..."
    git clone --depth 1 "$url" "$TARGET_DIR/$name"

    # 記錄專案資訊
    cd "$TARGET_DIR/$name"
    echo "Project: $name" >> ../${LANG}_projects_info.txt
    echo "Stars: $(gh repo view --json stargazerCount -q .stargazerCount)" >> ../${LANG}_projects_info.txt
    echo "LOC: $(find . -name "*.$LANG" | xargs wc -l | tail -1)" >> ../${LANG}_projects_info.txt
    echo "---" >> ../${LANG}_projects_info.txt
    cd ../..
done

echo "✅ Cloned ${#PROJECTS[@]} test projects"
```

### 2.3 專案分析與分類

**為每個專案建立 Profile**:

```yaml
# test_targets/IceCubesApp/PROJECT_PROFILE.yaml
project_name: IceCubesApp
github_url: https://github.com/Dimillian/IceCubesApp
stars: 6700+
last_updated: 2025-11

scale:
  total_files: 390
  loc: 38350
  size_category: MEDIUM

tech_stack:
  language: Swift
  language_version: 5.9+
  frameworks: [SwiftUI, Combine, TCA-lite]

architecture:
  primary: MVVM + Clean Architecture
  patterns: [Repository, Router, Theme, ObservableObject]

modernization:
  level: MODERN
  year: 2023+
  indicators:
    - async/await usage
    - SwiftUI 100%
    - Has CLAUDE.md

test_suitability:
  patterns_to_test:
    - Router (API)
    - Theme/Style
    - ObservableObject
    - async/await
  expected_files:
    - Router: ~5 files
    - Theme: ~2 files
    - ObservableObject: ~10 files
```

---

## 階段 3: Pattern 分層規劃（Pattern Tiering）

**目標**: 將候選 patterns 分層，規劃實作優先級

**時間**: 0.5 天

### 3.1 Tier 定義標準

#### Tier 1 - 核心 Patterns ⭐⭐⭐⭐⭐

**必須滿足**（3 選 2）:
- ✅ 使用率 >60% 的專案使用
- ✅ 官方文檔推薦
- ✅ 架構核心組件（如 ViewModel in MVVM）

**特性**:
- 檢測準確率目標: >90%
- 必須在 Phase 1 實作
- 檔名檢測可靠

**iOS 範例**:
```
Tier 1 (10 個):
1. Protocol/Delegate ⭐⭐⭐⭐⭐ - UIKit 核心
2. Repository ⭐⭐⭐⭐⭐ - Clean Architecture 核心
3. Service Layer ⭐⭐⭐⭐⭐ - 企業級標準
4. ViewModel ⭐⭐⭐⭐⭐ - MVVM 核心
5. Router ⭐⭐⭐⭐⭐ - API + Navigation
...
```

#### Tier 2 - 補充 Patterns ⭐⭐⭐

**特性**:
- 使用率 30-60%
- 特定架構/框架必須
- 重要但非通用

**iOS 範例**:
```
Tier 2 (8 個):
11. ObservableObject ⭐⭐⭐ - SwiftUI 過渡期
12. Reducer (TCA) ⭐⭐⭐ - TCA 專用
13. Cache ⭐⭐⭐ - 效能優化
14. Middleware ⭐⭐⭐ - Redux 專用
...
```

#### Tier 3 - 進階 Patterns ⭐⭐（可選）

**特性**:
- 使用率 <30%
- 進階場景
- 框架深度整合

**潛在範例**:
```
Tier 3 (候選):
- CoreData Patterns (NSManagedObject, FetchRequest)
- SwiftUI Advanced (ViewModifier, PreferenceKey)
- Testing Patterns (XCTestCase variants)
- Coordinator (Advanced Navigation)
```

### 3.2 分層決策流程圖

```
Pattern 候選
    ↓
是否官方推薦? ────Yes──→ Tier 1
    ↓ No
使用率 >60%? ────Yes──→ Tier 1
    ↓ No
架構核心組件? ────Yes──→ Tier 1
    ↓ No
使用率 30-60%? ────Yes──→ Tier 2
    ↓ No
框架特定必須? ────Yes──→ Tier 2
    ↓ No
    ↓
  Tier 3 或丟棄
```

### 3.3 實作路線圖產出

**Phase 1 - Tier 1 實作**（2 週）:

**Week 1**: 最高優先級 5 個
- 選擇標準: 使用率最高 + 檔名檢測最可靠
- 測試專案: 每個 pattern 至少 2 個專案
- 交付: 實作 + 測試 + 報告

**Week 2**: 次優先級 5 個
- 剩餘 Tier 1 patterns
- 可能包含需內容分析的 patterns
- 交付: 實作 + 測試 + 報告

**Phase 2 - Tier 2 實作**（1 週）:
- 8-10 個補充 patterns
- 框架特定 patterns
- 交付: 實作 + 測試 + 總結報告

**Phase 3 - Tier 3（可選）**:
- 根據需求決定是否實作
- 進階場景支援

---

## 階段 4: 分階段實作（Phased Implementation）

**目標**: 系統化實作每個 pattern，持續測試與調整

**時間**: 1-3 週（視 pattern 數量）

### 4.1 單個 Pattern 實作流程（標準化）

**步驟 1: 修改 find-patterns.sh**

```bash
# 新增 case 到 find-patterns.sh

# 範例：Repository pattern
"repository"|"repo")
    echo "*Repository.swift *DAO.swift *Store.swift *DataSource.swift"
    ;;

# 對應的目錄 pattern
"repository"|"repo")
    echo "Repositories/ Data/Repositories/ DataLayer/"
    ;;
```

**步驟 2: 建立測試腳本**

```bash
#!/bin/bash
# test_{language}_pattern_{name}.sh

echo "=== Testing Repository Pattern ==="

# Test on project 1
echo "## Project: clean-architecture-swiftui"
bash scripts/atlas/find-patterns.sh "repository" test_targets/clean-architecture-swiftui 2>&1 | head -10

# Test on project 2
echo "## Project: iOS-Clean-Architecture-MVVM"
bash scripts/atlas/find-patterns.sh "repository" test_targets/iOS-Clean-Architecture-MVVM 2>&1 | head -10

# Count results
echo "Total files found: $(bash scripts/atlas/find-patterns.sh "repository" test_targets/ 2>&1 | wc -l)"
```

**步驟 3: 執行測試並分析**

```bash
# 執行測試
bash test_swift_pattern_repository.sh > results_repository.txt

# 手動檢查結果
# 1. 所有檔案都是 Repository 嗎？（檢查 false positives）
# 2. 有遺漏的 Repository 檔案嗎？（檢查 false negatives）
# 3. 準確率是否 >80%？
```

**步驟 4: 迭代改進**

**常見調整場景**:

1. **檔名模式不足** → 新增更多後綴
   ```bash
   # Before
   echo "*Repository.swift"

   # After (發現專案用 *Store)
   echo "*Repository.swift *Store.swift *DataStore.swift"
   ```

2. **發現新命名慣例** → 新增特定框架 pattern
   ```bash
   # iOS 實戰：發現 TCA 用 *Domain.swift
   "reducer"|"tca reducer")
       echo "*Reducer.swift *Domain.swift *Action.swift *State.swift"
       ;;
   ```

3. **False positives 過多** → 縮小範圍
   ```bash
   # Before (太廣泛)
   echo "*Service.swift"

   # After (排除常見非 Service 檔案)
   echo "*Service.swift" | grep -v "ViewModel" | grep -v "View"
   ```

**步驟 5: 記錄結果**

每個 pattern 記錄：
```yaml
pattern: Repository
status: ✅ Completed

implementation:
  file_patterns: ["*Repository.swift", "*DAO.swift", "*Store.swift"]
  directory_patterns: ["Repositories/", "Data/Repositories/"]

test_results:
  - project: clean-architecture-swiftui
    files_found: 3
    accuracy: 100%
    examples:
      - "Data/Repositories/MoviesRepository.swift"
      - "Data/Repositories/ImagesRepository.swift"

  - project: iOS-Clean-Architecture-MVVM
    files_found: 3
    accuracy: 100%
    examples:
      - "Data/Repositories/DefaultMoviesRepository.swift"

overall_accuracy: 100%
notes: "Clean Architecture 專案標準實作，命名一致"
```

### 4.2 批次實作流程（Week 1/2）

**每週節奏**:

**Day 1-2**: 實作 5 個 patterns
- 修改 find-patterns.sh
- 建立測試腳本
- 初步測試

**Day 3**: 分析與調整
- 檢查所有測試結果
- 識別問題（DIContainer, Domain.swift 等）
- 調整 patterns

**Day 4**: 重新測試
- 用調整後的 patterns 重新測試
- 確認準確率 >80%

**Day 5**: 建立報告
- 寫週報告（`{language}-tier1-week{N}-report.md`）
- 記錄發現與學習
- 準備下週工作

### 4.3 問題解決模式

**從 iOS 實戰學到的教訓**:

#### 問題 1: Pattern 返回 0 結果

**調查步驟**:
```bash
# 1. 手動搜尋確認專案確實有此 pattern
find test_targets/OnlineStoreTCA -name "*.swift" | xargs grep -l "Reducer"

# 2. 檢查實際檔名
find test_targets/OnlineStoreTCA -name "*Reducer*" -o -name "*Domain*"

# 3. 讀取幾個檔案確認內容
cat test_targets/OnlineStoreTCA/RootDomain.swift | head -20
```

**常見原因與解決**:
- ✅ **命名慣例不同** → 新增該慣例（如 *Domain.swift）
- ✅ **框架特定語法** → 補充框架 variant
- ✅ **目錄位置特殊** → 新增目錄 pattern

#### 問題 2: 架構專屬 Pattern 在其他架構返回 0

**範例**: Middleware 在 Clean Architecture 專案返回 0

**分析**:
```
Middleware 使用場景:
- Redux 架構: ✅ 使用 Middleware 處理 side effects
- Clean Architecture: ❌ 使用 Use Cases
- MVVM: ❌ 使用 ViewModels
```

**結論**: 這不是 bug，是架構差異
**處理**: 在報告標註 "架構特定 pattern"

#### 問題 3: 語言特性無法用檔名檢測

**範例**: async/await, Combine/Publisher

**解決方案**:
1. **保留 pattern 在腳本中** - 檢測專案檔案
2. **標註需內容分析** - 在 help 訊息註明
3. **提供補充 grep 指令** - 給 AI Stage 0-1 使用

```bash
# 在報告中提供
# async/await 內容檢測
grep -r "async func\|await " --include="*.swift" . | wc -l

# Combine 內容檢測
grep -r "@Published\|import Combine" --include="*.swift" . | wc -l
```

---

## 階段 5: 品質驗證（Quality Assurance）

**目標**: 確保實作品質，建立可信度

**時間**: 持續進行

### 5.1 準確率計算標準

**定義**:
```
準確率 = (真正例 True Positives) / (真正例 + 假正例 False Positives)

其中:
- 真正例 (TP): 檢測到的檔案確實是該 pattern
- 假正例 (FP): 檢測到的檔案不是該 pattern
- 假反例 (FN): 專案有該 pattern 但未檢測到
```

**評級標準**:
```
100%        : 完美 - 所有檔案都正確
90-99%      : 優秀 - 僅 1-2 個 FP
80-89%      : 良好 - 可接受的 FP 數量
70-79%      : 尚可 - 需要改進
<70%        : 不合格 - 必須調整
```

**iOS 實戰結果**:
- Tier 1 Week 1: 88.9% (良好)
- Tier 1 Week 2: 95.8% (優秀)
- Tier 2: 98%+ (優秀)

### 5.2 多專案交叉驗證

**最少驗證標準**:
- ✅ 每個 pattern 至少 2 個專案測試
- ✅ 至少 1 個 LARGE 專案包含在測試中
- ✅ 涵蓋不同架構（MVVM, Clean, etc.）

**驗證矩陣範例**（iOS）:

| Pattern | IceCubes | wikipedia | ios-mail | clean-arch | iOS-MVVM | 覆蓋率 |
|---------|----------|-----------|----------|------------|----------|--------|
| Repository | ❌ | ❌ | ✅ 6 | ✅ 3 | ✅ 3 | 3/5 ✅ |
| Service | ❌ | ✅ 10 | ✅ 10 | ❌ | ✅ | 3/5 ✅ |
| Router | ✅ 3 | ❌ | ✅ 5 | ✅ | ❌ | 3/5 ✅ |

**目標**: 每個 pattern 至少 2/5 專案有結果

### 5.3 False Positives 分析

**記錄所有 FP 案例**:

```yaml
pattern: UICollectionViewLayout
false_positives:
  - file: "CustomLayoutHelper.swift"
    reason: "包含 'Layout' 但不是 UICollectionViewLayout subclass"
    fix: "可接受 FP，因為 Helper 通常相關"

  - file: "LayoutConstants.swift"
    reason: "僅常數定義"
    fix: "考慮排除 *Constants.swift"

decision:
  accuracy: 75% (3/4 檔案正確)
  action: 保持現狀，在報告註明 FP 類型
```

### 5.4 品質檢查清單

**每個 Pattern 完成前必須**:

- [ ] 在至少 2 個專案測試
- [ ] 準確率 >80%
- [ ] 記錄所有 FP/FN 案例
- [ ] 提供實際檔案範例（至少 3 個）
- [ ] 如有架構限制，明確標註
- [ ] 如需內容分析，提供 grep 指令

**每個 Phase 完成前必須**:

- [ ] 所有 patterns 通過品質檢查
- [ ] 建立完整測試報告
- [ ] 統計整體準確率
- [ ] 記錄關鍵發現（如 DIContainer, Domain.swift）

---

## 階段 6: 文檔產出（Documentation）

**目標**: 完整記錄實作過程、發現、學習

**時間**: 每階段完成後

### 6.1 文檔架構（5 份報告）

#### 1. 研究報告（Research Report）
**檔名**: `{language}-patterns-expansion-research-report.md`

**必須包含**:
- 執行摘要
- 語言生態系統分析
- 缺少的 patterns 清單（分層）
- 測試專案選擇與理由
- 實作路線圖（Phase 1-2-3）

**目的**: 為什麼實作這些 patterns

#### 2-4. 實作報告（Implementation Reports）
**檔名**:
- `{language}-tier1-phase1-week1-report.md`
- `{language}-tier1-phase1-week2-report.md`
- `{language}-tier2-implementation-report.md`

**必須包含**:
- 本階段實作的 patterns 清單
- 每個 pattern 的：
  - 檔案/目錄模式
  - 測試結果（專案 × 檔案數）
  - 準確率
  - 範例檔案
  - 發現的問題與修正
- 統計數據（檔案數、準確率）
- 關鍵技術發現

**目的**: 怎麼做的，遇到什麼問題

#### 5. 總結報告（Complete Report）
**檔名**: `{language}-patterns-expansion-complete-report.md`

**必須包含**:
- 執行摘要（關鍵成果）
- 所有 patterns 概覽表格
- 分階段結果統計
- 測試專案覆蓋矩陣
- ⭐ 關鍵技術發現（最重要！）
- 代碼修改摘要
- 最終統計數據
- AI Stage 0-2 使用建議
- 已知限制與未來改進
- 下一步建議

**目的**: 學到什麼，如何使用

### 6.2 關鍵技術發現（Critical Section）

**這是最重要的部分**！記錄所有非預期的發現：

**範本**:
```markdown
## 關鍵技術發現 ⭐

### 發現 1: DIContainer 是現代 Factory Pattern

**問題**: Factory pattern 初始測試返回 0 結果

**調查**:
- 手動搜尋發現專案使用 `DIContainer` 而非 `Factory`
- Clean Architecture 社群趨勢轉向依賴注入容器

**證據**:
```swift
// AppDIContainer.swift
class AppDIContainer {
    func makeUserListViewController() -> UserListViewController {
        // ...
    }
}
```

**修正**: 新增 `*DIContainer.swift` 到 Factory pattern

**影響**:
- 立即檢測到 3 個檔案
- 證明現代 iOS 開發使用 DI Container 而非傳統 Factory
- 其他語言可能有類似趨勢（Kotlin Koin, Dart GetIt）

**教訓**: 命名慣例會隨時間演進，需參考最新專案
```

### 6.3 文檔品質標準

**每份報告必須**:

- ✅ 使用 Markdown 格式
- ✅ 有清晰的目錄結構
- ✅ 表格呈現統計數據
- ✅ 程式碼範例有語法高亮
- ✅ 所有論點有證據支持（檔案路徑、數據）
- ✅ 明確的結論與下一步

**避免**:

- ❌ 空泛的描述（"大部分正確" → 提供準確率數字）
- ❌ 無證據的斷言（"TCA 使用 Reducer" → 展示實際檔案）
- ❌ 遺漏關鍵發現（DIContainer, Domain.swift 這些必須記錄）

---

## 實戰檢查清單（Checklist）

### 開始前（Day 0）

**環境準備**:
- [ ] 熟悉目標語言基本語法
- [ ] 安裝目標語言開發工具（IDE, 編譯器）
- [ ] 準備 test_targets/ 目錄

**文檔準備**:
- [ ] 複製本方法論文檔
- [ ] 建立 `{language}/` 子目錄存放報告
- [ ] 準備報告模板

### 研究階段（Day 1-2）

- [ ] 完成語言生態系統分析
- [ ] 識別主流框架與架構
- [ ] 分析命名慣例
- [ ] 研究現代化趨勢
- [ ] 產出研究報告
- [ ] 建立 patterns 候選清單（20-50 個）

### 測試專案準備（Day 2-3）

- [ ] 選擇 6+ 個測試專案（涵蓋 4 個維度）
- [ ] Clone 所有專案到 test_targets/
- [ ] 為每個專案建立 PROJECT_PROFILE.yaml
- [ ] 驗證專案可編譯/運行（可選）

### Pattern 分層（Day 3-4）

- [ ] 將 patterns 分為 Tier 1-2-3
- [ ] Tier 1: 8-12 個核心 patterns
- [ ] Tier 2: 6-10 個補充 patterns
- [ ] 建立實作路線圖（Phase 1 Week 1/2, Phase 2）

### Phase 1 Week 1 實作（Day 5-9）

- [ ] 實作 5 個最高優先級 patterns
- [ ] 修改 find-patterns.sh（檔案 + 目錄 patterns）
- [ ] 建立測試腳本
- [ ] 在至少 2 個專案測試每個 pattern
- [ ] 記錄結果（準確率、範例、問題）
- [ ] 迭代改進（處理 FP/FN）
- [ ] 建立 Week 1 實作報告

### Phase 1 Week 2 實作（Day 10-14）

- [ ] 實作剩餘 5 個 Tier 1 patterns
- [ ] 同樣的測試與驗證流程
- [ ] 特別注意框架特定 patterns
- [ ] 建立 Week 2 實作報告

### Phase 2 Tier 2 實作（Day 15-19）

- [ ] 實作 6-10 個 Tier 2 patterns
- [ ] 測試與驗證
- [ ] 建立 Tier 2 實作報告

### 總結階段（Day 20-21）

- [ ] 統計所有數據（patterns 數量、準確率、檔案數）
- [ ] 整理所有關鍵技術發現
- [ ] 建立測試專案覆蓋矩陣
- [ ] 撰寫 AI Stage 0-2 使用建議
- [ ] 建立完整總結報告
- [ ] 更新 CLAUDE.md 和 PROMPTS.md

### 品質驗證（持續）

- [ ] 每個 pattern 準確率 >80%
- [ ] 每個 pattern 至少 2 個專案測試
- [ ] 所有 FP/FN 案例已記錄
- [ ] 關鍵發現已文檔化
- [ ] 代碼修改已提交

---

## 語言特定調整建議

不同語言可能需要調整方法論的某些部分：

### 靜態類型語言（Java, Kotlin, Swift, Rust）

**優勢**:
- ✅ 檔名慣例通常一致
- ✅ 架構 patterns 明確
- ✅ IDE 支援強，易於導航

**注意事項**:
- 介面/協定 patterns（Interface, Protocol, Trait）
- 泛型 patterns（Generic, Template）

### 動態類型語言（Python, JavaScript, Ruby）

**挑戰**:
- ⚠️ 檔名慣例較不一致
- ⚠️ Patterns 可能隱藏在檔案內部
- ⚠️ 需要更多內容分析

**調整**:
- 更依賴目錄結構
- 更多 grep-based 檢測
- 框架約定（Django, Rails, React）更重要

### 函數式語言（Haskell, Elixir, Scala）

**特殊性**:
- Monad, Functor patterns（函數式 patterns）
- Typeclass patterns
- ADT (Algebraic Data Types)

**調整**:
- Tier 1 包含函數式核心 patterns
- 注意範式差異（FP vs OOP）

### 新興語言（Dart, Go, Zig）

**機會**:
- 社群慣例尚在形成
- 可能成為標準參考

**風險**:
- 最佳實踐尚未穩定
- 測試專案選擇較困難

---

## 成功指標（KPIs）

### 量化指標

| 指標 | 目標 | iOS 實戰 | 說明 |
|------|------|----------|------|
| **新增 Patterns** | >15 | 18 ✅ | Tier 1 + Tier 2 總數 |
| **Pattern 增長率** | >80% | 112.5% ✅ | (新增 / 原有) × 100% |
| **測試專案數** | ≥6 | 7 ✅ | 涵蓋不同規模/架構 |
| **檔案檢測數** | >100 | 152+ ✅ | 所有 patterns 總和 |
| **整體準確率** | >80% | 92%+ ✅ | 加權平均準確率 |
| **專案覆蓋率** | 每個 pattern ≥2 專案 | 100% ✅ | 所有 patterns 達標 |
| **文檔產出** | 5 份報告 | 5 ✅ | 研究 + 3 實作 + 總結 |

### 質化指標

- ✅ **架構多樣性**: 涵蓋主流架構（MVVM, Clean, TCA, Redux）
- ✅ **現代化支援**: 支援語言最新特性（async/await, @Observable）
- ✅ **社群驗證**: 使用高 star 開源專案測試
- ✅ **可重複性**: 方法論可應用於其他語言
- ✅ **AI 友善**: 提供 Stage 0-2 使用建議

### 失敗指標（紅旗）

如果出現以下情況，需要重新評估：

- 🚩 整體準確率 <70%
- 🚩 超過 30% 的 patterns 無測試專案覆蓋
- 🚩 實作時間超過預估 50%+
- 🚩 發現大量無法用檔名檢測的 patterns
- 🚩 測試專案品質不佳（玩具專案、過時專案）

---

## 經驗傳承（Lessons Learned）

### 從 iOS 擴展學到的 Top 10 教訓

1. **命名慣例會演進**
   - Factory → DIContainer
   - Reducer → Domain.swift
   - 需參考最新專案

2. **架構決定 Patterns**
   - Redux 用 Middleware，Clean Architecture 用 Use Cases
   - 不要期望所有架構都有相同 patterns

3. **語言特性難用檔名檢測**
   - async/await, Combine 需內容分析
   - 提供補充 grep 指令

4. **測試專案選擇至關重要**
   - 高 star 專案 = 社群最佳實踐
   - 避免個人玩具專案

5. **分階段實作降低風險**
   - Week 1/2 分批實作
   - 早期發現問題，及時調整

6. **關鍵發現要詳細記錄**
   - DIContainer, Domain.swift 這些發現是最有價值的
   - 未來其他語言可能有類似模式

7. **準確率 >80% 是合理目標**
   - 100% 很難達到（總有邊緣案例）
   - 90%+ 是優秀水準

8. **多專案交叉驗證必須**
   - 單一專案可能有特殊慣例
   - 至少 2-3 個專案才能確認 pattern 普遍性

9. **文檔與實作同步進行**
   - 不要等全部完成才寫文檔
   - 每階段立即記錄，避免遺忘

10. **預留迭代時間**
    - 初版 patterns 很少完美
    - 預留 20-30% 時間用於調整

---

## 快速開始模板

### 新語言支援快速啟動（1 天）

```bash
#!/bin/bash
# quick-start-new-language.sh

LANG="$1"  # 例如: kotlin, go, rust

if [ -z "$LANG" ]; then
    echo "Usage: ./quick-start-new-language.sh <language>"
    exit 1
fi

echo "🚀 Quick Start: $LANG Pattern Support"

# 1. 建立工作目錄
mkdir -p "test_targets/${LANG}"
mkdir -p "../../${LANG}"

# 2. 複製模板
cp ../../new-language-support-methodology.md "../../${LANG}/methodology.md"
cp templates/research-report-template.md "../../${LANG}/${LANG}-research-report.md"

# 3. 建立 checklist
cat > "../../${LANG}/checklist.md" <<EOF
# ${LANG} Pattern Support Checklist

## Research Phase (Day 1-2)
- [ ] Ecosystem analysis
- [ ] Framework identification
- [ ] Naming conventions
- [ ] Modernization trends
- [ ] Research report completed

## Test Projects (Day 2-3)
- [ ] 6+ projects selected
- [ ] Projects cloned
- [ ] PROJECT_PROFILE.yaml for each

## Pattern Tiering (Day 3-4)
- [ ] Tier 1 defined (8-12 patterns)
- [ ] Tier 2 defined (6-10 patterns)
- [ ] Implementation roadmap

## Phase 1 Week 1 (Day 5-9)
- [ ] 5 patterns implemented
- [ ] Tested on 2+ projects each
- [ ] Week 1 report completed

## Phase 1 Week 2 (Day 10-14)
- [ ] 5 patterns implemented
- [ ] Week 2 report completed

## Phase 2 Tier 2 (Day 15-19)
- [ ] 6-10 patterns implemented
- [ ] Tier 2 report completed

## Summary (Day 20-21)
- [ ] Complete report
- [ ] Update CLAUDE.md
- [ ] Update PROMPTS.md
EOF

echo "✅ Created ${LANG} support structure"
echo ""
echo "Next steps:"
echo "1. Read ../../${LANG}/methodology.md"
echo "2. Fill in ../../${LANG}/${LANG}-research-report.md"
echo "3. Follow ../../${LANG}/checklist.md"
echo ""
echo "📚 Reference: iOS implementation in test_targets/ios-*-report.md"
```

---

## 結論

這套方法論經過 iOS patterns 擴展實戰驗證（18 patterns, 7 projects, 92%+ accuracy），可直接應用於其他語言。

**核心原則**:
1. ✅ **系統化** - 6 階段明確流程
2. ✅ **可重複** - 標準化步驟與檢查清單
3. ✅ **品質導向** - 準確率目標與多專案驗證
4. ✅ **文檔驅動** - 每階段產出報告
5. ✅ **迭代改進** - 發現問題立即調整

**預期成果**:
- 2-4 週完成 15-20 個 patterns
- 90%+ 整體準確率
- 完整文檔（5 份報告）
- 可複製的經驗

**下次應用**（建議優先級）:
1. **Kotlin** - Android 現代開發（類似 Swift → iOS）
2. **Go** - 微服務架構 patterns
3. **Dart/Flutter** - 跨平台 patterns
4. **Rust** - 系統級 patterns

---

**方法論版本**: v1.0
**最後更新**: 2025-11-23
**維護者**: SourceAtlas Team
**參考實作**: iOS Patterns Expansion (test_targets/ios-*-report.md)

🎯 **準備好開始下一個語言了嗎？執行 `./quick-start-new-language.sh <language>` 開始吧！**
