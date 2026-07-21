# VERIFICATION.md — SourceAtlas 改動驗證流程

> **一句話**:「測試全綠」只證明沒變差,不證明更好。要主張「更好」,拿出一個**能分辨新舊的檢查**。
>
> 本文件規範「**改動驗證**」(change verification):當你修改 SourceAtlas 的任何資產時,如何證明改動真的更好。
> 它與各 command 內的 `verification-guide.md` **分工不同**:後者是**執行期自查**(agent 產出分析後、存檔前防幻覺),本文件是**開發期驗證**(prompt/腳本被修改後、合併前防退化)。兩者互補,不可互相取代。

---

## 0. 快速決策表:我改了什麼,走哪條 SOP?

| 你改的檔案 | 性質 | SOP | 最低驗證要求 |
|---|---|---|---|
| `scripts/atlas/*.sh` 修 bug | 行為修正 | [A1](#a1) | bats 差異檢查(舊紅新綠) |
| `scripts/atlas/*.sh` 重構 | 行為不變 | [A2](#a2) | bats 綠燈不變 + shellcheck 數字不升 |
| `scripts/atlas/*.sh` 效能 | 行為不變 | [A3](#a3) | hyperfine before/after 中位數 |
| `plugin/commands/**` 或 `plugin/skills/**` 的 `.md` 修行為 | prompt 行為修正 | [B1](#b1) | 捕捉失敗案例 → 舊 prompt 必敗、新 prompt 必過 |
| 同上,但只搬移/精簡內容(progressive disclosure) | prompt 重構 | [B2](#b2) | 評測指標不降 + context 成本下降 |
| `output-template.md` 改輸出格式 | 契約變更 | [B3](#b3) | schema 檢查更新 + 下游消費者確認 |
| README / USAGE_GUIDE / TESTING.md | 文件 | [C](#c) | 指令逐條可執行 + 冷啟動走查 |
| `plugin.json` / `marketplace.json` / 版本號 | manifest | [D](#d) | check-versions + 安裝煙霧測試 |

---

## 1. 可信度階梯在本專案的落地

```
最強  ┌─ 差異檢查    腳本:bats 測試舊碼 FAIL、新碼 PASS
      │              prompt:捕捉的失敗案例,舊 prompt ≥4/5 次失敗、新 prompt ≥4/5 次通過
      ├─ 客觀指標    fact-check 通過率、schema 符合率、Hit@k、token/時間成本、shellcheck 警告數
      ├─ 獨立第二意見 盲測 A/B LLM 裁判(不知何者為新)、他人 code review
最弱  └─ 自己跑全綠  必要但永不充分
```

**SourceAtlas 的特殊性**:skills 是 Markdown prompt,不是傳統程式碼。prompt 沒辦法對「文字」做差異檢查——你要對「**行為**」做。做法:固定輸入(同一目標 repo、同一 commit、同一參數),對舊/新 prompt 各跑 n 次,比較**輸出的可驗證性質**。prompt 的「先寫紅燈」翻譯成:**先把現在的失敗行為捕捉成一個 eval case,親眼看它失敗,再去改 prompt**。

---

## 2. SOP A:shell 腳本(`scripts/atlas/*.sh`)

這是最接近傳統程式碼的部分,直接套用標準做法。

<a name="a1"></a>
### A1. 修 bug / 改行為

```
1. 重現:寫一個 bats 測試斷言正確行為 → 跑 → 必須看到它「紅」
2. 修改腳本
3. 跑同一測試 → 綠
4. 跑該腳本的全部既有 bats → 全綠(無附帶損傷)
```

```bash
# tests/bats/ast-grep-search.bats
@test "SEARCH_LANG 不覆蓋系統 locale" {
  run env LANG=zh_TW.UTF-8 scripts/atlas/ast-grep-search.sh --lang swift --fallback "foo"
  [ "$status" -eq 0 ]
  # 斷言「結果」:輸出不受 locale 影響,而非斷言內部變數名
}
```

原則:**斷言結果,不斷言實作**——測輸出格式與退出碼,不要 grep 腳本原始碼裡有沒有某行。

<a name="a2"></a>
### A2. 純重構(行為不變)

- 既有 bats + golden 測試**一個都不能改、全部保持綠**。若你發現需要寫一個「舊碼會 fail」的測試才能證明重構有價值——那它就不是重構,回到 A1。
- 客觀結構指標(至少一項往好的方向動,其餘不惡化):
  ```bash
  shellcheck scripts/atlas/*.sh | wc -l    # 警告數:不升
  wc -l scripts/atlas/foo.sh               # 行數(輔助參考,非目標)
  ```

<a name="a3"></a>
### A3. 效能優化

```bash
# 固定條件:同機器、同目標 repo(pin 到 commit)、清除快取
hyperfine --warmup 2 --min-runs 10 \
  'git -C tests/fixtures/mixed-objc-swift stash -u >/dev/null 2>&1; OLD/ast-grep-search.sh --lang objc "viewDidLoad"' \
  'NEW/ast-grep-search.sh --lang objc "viewDidLoad"'
```

- 報告**中位數**與範圍,不是單次、不是體感。
- 行為不變是前提:先過 A2 的綠燈檢查,再量效能。
- macOS 沒有 `timeout` 指令;需要逾時控制用 `gtimeout`(coreutils)或 deadline 迴圈。

---

## 3. SOP B:prompt 資產(`plugin/commands/**`、`plugin/skills/**`)

<a name="b1"></a>
### B1. 修 prompt 行為(例:overview 會幻覺出不存在的檔案路徑)

**步驟 1:捕捉失敗案例(這就是你的紅燈)**

在改 prompt 之前,先把失敗行為固定成 eval case:

```yaml
# tests/evals/cases/overview-hallucinated-path.yaml
id: overview-hallucinated-path
command: "/sourceatlas:overview"
args: ". --force"
target: express          # tests/evals/targets.lock 中 pin 住 commit SHA
captured: 2026-07-21
bug: "scanned_files 出現不存在的 src/index.js"
runs: 5
assertions:
  - type: fact-check     # 機械驗證輸出中所有可驗證聲明
    min_pass_rate: 1.0
  - type: schema         # 輸出符合 output-template.md 結構
old_must_fail: ">=4/5"   # 舊 prompt 至少 4/5 次觸發此 bug(證明可重現)
new_must_pass: "5/5"
```

**步驟 2:先跑舊 prompt,親眼看它紅。** 跑不紅代表 bug 不可重現——先解決重現問題,不要盲改。

**步驟 3:改 prompt。**

**步驟 4:跑新 prompt 5 次,全過;舊案例庫(`tests/evals/cases/`)全部重跑,不能有退化。**

執行方式(headless):

```bash
# tests/evals/run-eval.sh 核心邏輯
rm -rf "$TARGET/.sourceatlas"          # 關鍵:清快取,否則第 2 輪起量到的是「讀快取」不是「分析」
claude -p "/sourceatlas:overview . --force" \
  --model "$(yq '.model' plugin/commands/overview/SKILL.md)" \
  --cwd "$TARGET" > "$RUN_DIR/output-$i.txt"
tests/evals/fact-check.sh "$TARGET/.sourceatlas/overview.yaml"
```

**非決定性的處理**:LLM 輸出有隨機性,所以用「n 次中 k 次」而非單次;閾值建議 `old_must_fail ≥4/5`、`new_must_pass 5/5`(允許舊行為偶爾僥倖,不允許新行為偶爾失敗)。n=5 是成本與信心的折衷,重大改動可升到 n=10。

<a name="b2"></a>
### B2. prompt 重構(搬移內容、精簡 token,行為應不變)

反模式警告:如果你能寫出一個「舊 prompt 會 fail」的 eval——那行為就被改了,這不是重構。

- **行為指標持平**:既有 eval cases 全跑,通過率不降;盲測 A/B 裁判結論應為「無明顯差異」。
- **客觀結構指標改善**(這才是重構的證據):
  ```bash
  wc -w plugin/commands/overview/SKILL.md   # 主檔載入字數 ↓(progressive disclosure 的意義)
  # 或:eval 執行的 token 成本 / 工具呼叫次數 ↓
  ```

<a name="b3"></a>
### B3. 改 `output-template.md`(輸出契約變更)

- 同步更新 `tests/evals/schema/` 對應的結構檢查(yq 斷言必要欄位存在)。
- grep 下游消費者:其他 command 是否讀取 `.sourceatlas/*.yaml` 的舊欄位(例:impact 讀 overview 的快取)。契約變更必須列出受影響清單。

### B4. 新增 command / skill

- 至少 2 個 eval case(一個 golden path、一個「不該發生的事」)再合併。
- 「不該發生的事」範例:`/sourceatlas:reset` 只能刪 `.sourceatlas/`,eval 斷言目標 repo 其他檔案的 mtime/內容不變;overview 無 `--force` 時第二次執行必須讀快取而非重新分析。

---

## 4. SOP C:文件改動(README、USAGE_GUIDE、TESTING.md)

<a name="c"></a>
**正確性可驗,有效性靠對照。**

1. **正確性(必做)**:文件裡每一條可執行指令,逐條實際執行一次。安裝章節在乾淨環境跑(新 shell、無既有 marketplace);`markdown-link-check` 掃連結與錨點。改了指令名(如 /atlas.clear → /atlas.reset)要 grep 全 repo 確認無殘留舊名——這正是 v2.13.1 修過的那類問題。
2. **有效性(重大改寫時)**:冷啟動走查——用「從未看過本專案」的視角(或乾淨 context 的 `claude -p`)只憑文件完成安裝與第一次使用,記錄卡住的每一點。文件改動的「復發檢查」:如果這次改寫是為了回應某個使用者疑問,把該疑問記進 PR;下次同類疑問再出現,就是文件無效的證據。
3. **反模式**:「寫了就會更好」。沒跑過的安裝步驟不算驗證過。

---

## 5. SOP D:plugin manifest 與版本(plugin.json、marketplace.json、版本號)

<a name="d"></a>

1. `jq empty` 驗 JSON 語法;`tests/tools/check-versions.sh` 斷言所有版本字串一致(約 18 處,見 CI 節)。
2. **安裝煙霧測試**(manifest 有任何變動時必做):走 `plugin/TESTING.md` 的流程——本地 marketplace add → install → `/help` 看得到 `/sourceatlas:*` 指令。manifest 錯誤的失敗模式是「安裝不起來」,只有真的裝一次才會暴露。
3. 版本 bump 需同步 `plugin/CHANGELOG.md` 條目;check-versions 應同時斷言 CHANGELOG 最新條目的版號等於 plugin.json 版號。

---

## 6. 客觀指標定義(prompt 輸出的可量化項)

| 指標 | 定義 | 工具 | 為什麼可信 |
|---|---|---|---|
| **fact-check 通過率** | 輸出中可驗證聲明(檔案路徑、行號、數量、branch 名)通過機械驗證的比例 | `tests/evals/fact-check.sh`:解析 YAML → `test -f`、`git branch --show-current`、`wc -l` 對照 | 完全機械、零主觀。這是本專案**最強的客觀指標**,因為所有 command 的輸出都充滿可驗證聲明 |
| **schema 符合率** | 輸出含 output-template 規定的必要欄位 | `yq` 斷言 | 機械 |
| **Hit@k** | 對已知答案的 fixture 提問,正確檔案是否出現在前 k 個結果(適用 pattern / impact / deps) | fixture repo + 預先人工標定的答案檔 | 答案先於實作存在(golden acceptance) |
| **成本** | wall time、工具呼叫次數、輸出 token | 執行紀錄 | 機械 |

`fact-check.sh` 的實作方向:重用各 command `verification-guide.md` 已定義的「聲明類型 → 驗證方法」對照表(它們已經寫好了 V1/V2 步驟),把它從「agent 執行期自查指引」抽成「可獨立執行的腳本」。一份邏輯,兩處使用。

---

## 7. 獨立第二意見的落地

1. **盲測 A/B LLM 裁判**(prompt 質性維度用):
   - 裁判看到的是「輸出 A / 輸出 B」,**不知道**哪個來自新 prompt;每對比較做**位置對調**各跑一次,抵銷順序偏差。
   - 裁判用固定 rubric(`tests/evals/rubrics/*.md`),輸出結構化判決(`A better / B better / tie` + 理由),不接受自由心證。
   - 裁判必須是**沒看過你推理過程**的乾淨 context:`claude -p --model sonnet` 新開 session。
2. **批判採納**:裁判說 tie 就是 tie,不要重跑到它說你贏為止。預先寫下判準,事後不移動球門。
3. 人工 code review 仍是 scripts 類改動的第二意見管道(PR template 已存在)。

---

## 8. 目錄佈局與工具鏈

```
tests/
  bats/                  # scripts/atlas 單元測試(bats-core)
  fixtures/              # 迷你合成 repo(mixed-objc-swift、ts-express-like…)——golden 測試用
  golden/                # 確定性腳本的預期輸出(diff 比對)
  evals/
    cases/               # 捕捉的失敗案例(格式見 B1)——只增不刪,這是回歸資產
    rubrics/             # 裁判評分準則
    schema/              # 各 command 輸出的 yq 結構斷言
    targets.lock         # E2E 目標 repo 的 pin(名稱 → URL + commit SHA)
    run-eval.sh          # 執行器:清快取 → claude -p × n → 收集 → fact-check → 判定
    fact-check.sh        # 機械驗證輸出聲明
  tools/
    check-versions.sh    # 版本一致性(見 SOP D)
    lint-frontmatter.sh  # SKILL.md frontmatter 完整性(name/description/model/allowed-tools)
```

工具選擇:**bats-core**(腳本測試)、**shellcheck**(靜態)、**hyperfine**(效能)、**yq/jq**(輸出解析)、**claude -p**(headless 評測與裁判)、**git worktree**(fallback 舊碼重跑)。E2E 目標沿用 `~/dev/test_targets/`(express、cal.com、WordPress-iOS),但 eval 一律以 `targets.lock` 的 SHA checkout,不追 HEAD——目標 repo 更新會讓新舊比較失去同條件基礎。

---

## 9. CI/CD 三層整合

| 層 | 觸發 | 內容 | 成本 |
|---|---|---|---|
| **Tier 1:每個 PR 必跑** | push / PR | shellcheck、bats、golden diff、`lint-frontmatter.sh`、`check-versions.sh`、JSON/YAML 語法、markdown 連結檢查 | 秒級、零 API 費用、決定性 |
| **Tier 2:prompt 評測** | PR 帶 `run-evals` label,或 `plugin/**` 路徑變更時提示要求 | `run-eval.sh` 跑受影響 command 的全部 cases(n=3)+ 該 PR 新增的失敗案例(n=5),結果貼回 PR comment(fact-check 率、通過數、裁判判決) | 分鐘級、需 `ANTHROPIC_API_KEY` secret,label 門檻控費 |
| **Tier 3:release** | tag / release branch | TESTING.md 安裝煙霧測試(marketplace add → install → /help 可見)、全 eval suite(n=5)、CHANGELOG 與版本號齊備檢查 | 手動+自動混合 |

**`check-versions.sh` 特別說明**:版本號散落在 `plugin.json`、`marketplace.json`、README ×2、USAGE_GUIDE ×2、CHANGELOG 等約 18 處,本專案歷史上發生過版本不同步需要事後補救(v2.13.1 的 "sync all version references" 提交)。這個檢查是「測不該發生的事」的直接案例:抽取所有版本字串 → 斷言全部相等。

GitHub Actions 骨架(`.github/workflows/verify.yml`):

```yaml
on: [pull_request]
jobs:
  tier1:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: shellcheck scripts/atlas/**/*.sh
      - run: bats tests/bats/
      - run: tests/tools/check-versions.sh && tests/tools/lint-frontmatter.sh
  tier2:
    if: contains(github.event.pull_request.labels.*.name, 'run-evals')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: tests/evals/run-eval.sh --changed-only --runs 3
        env: { ANTHROPIC_API_KEY: '${{ secrets.ANTHROPIC_API_KEY }}' }
```

---

## 10. 誠實標示驗證邊界(PR description 必填段)

每個 PR 的描述必須包含:

```markdown
## 驗證
- 方式:<差異檢查 / 客觀指標 / 第二意見 / 全綠>(可複選,標明各自結果)
- 證據:<bats 檔名與紅→綠紀錄 / eval case id 與 n 次通過率 / hyperfine 中位數>
- 邊界:<沒驗到什麼。例:「eval 只在 express + WordPress-iOS 上跑,Kotlin 專案未驗」「n=3,非統計顯著」>
```

沒有「邊界」段的 PR 視同驗證不完整。「在我機器上跑過一次沒問題」屬於階梯最底層,必須如實寫出,不得包裝成「已驗證」。

---

## 11. Fallback:已經 shipped 才想起來要補證明

用拋棄式 worktree 把「現在的檢查」帶回「舊 commit」上跑,確認它紅:

```bash
git worktree add /tmp/verify-old <舊commit>
cp -r tests/bats/new-test.bats /tmp/verify-old/tests/bats/   # 或 tests/evals/cases/xxx.yaml
cd /tmp/verify-old && bats tests/bats/new-test.bats           # 期望:FAIL
cd - && git worktree remove --force /tmp/verify-old
```

prompt 改動同理:對舊 commit 的 SKILL.md 跑同一 eval case,確認 `old_must_fail` 成立。補證明的結果寫回 PR comment,標明是事後補驗。

---

## 12. 導入順序建議(現況:repo 沒有任何自動化測試)

1. **第一步(最高投報)**:`fact-check.sh` + 2-3 個捕捉自真實失敗的 eval cases——這直接把本專案最大的風險(輸出幻覺)變成可量測的回歸資產。
2. 第二步:Tier 1 CI(shellcheck + check-versions + lint-frontmatter,一天內可完成,零 API 成本)。
3. 第三步:為 `scripts/atlas/` 補 bats + fixtures(從 ast-grep-search.sh 開始,它最常被改)。
4. 第四步:Tier 2 label-gated evals。
5. 原則:**規則寫完不是終點**——每次真實事故後,回頭把事故捕捉成 case 加入 `tests/evals/cases/`,文件與案例庫同步長大。

---

*本文件依據〈如何確認一個改動「真的更好」〉驗證原則撰寫;各 command 的執行期自查見 `plugin/commands/*/verification-guide.md`,本地安裝測試見 `plugin/TESTING.md`。*
