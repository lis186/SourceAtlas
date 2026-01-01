# atlas.flow v3.0 測試報告

**日期**: 2026-01-01
**版本**: v2.10.2
**類型**: Test Report

---

## 測試環境

| 項目 | 值 |
|------|---|
| 測試專案 1 | TTCA-iOS (Swift TCA) |
| 測試專案 2 | cal.com (TypeScript, Open Source) |
| 測試專案 3 | Express.js (JavaScript, Open Source) |
| 測試案例總數 | 15 |
| 通過率 | 100% |

---

## Tier 1 測試結果 (內建模式)

| TC | 模式 | 觸發詞 | 專案 | 結果 |
|----|------|--------|------|------|
| 01 | Standard Flow | (default) | TTCA-iOS | 5/5 ✅ |
| 02 | Reverse Tracing | "who calls" | TTCA-iOS | 5/5 ✅ |
| 03 | Error Path | "error" | TTCA-iOS | 5/5 ✅ |
| 04 | Data Flow | "data flow" | TTCA-iOS | 5/5 ✅ |
| 05 | Event Tracing | "event", "message" | TTCA-iOS | 5/5 ✅ |
| 16 | Permission Flow | "permission", "role" | cal.com | 5/5 ✅ |

**Tier 1 驗證**：✅ 全部正確識別，無需載入外部檔案

---

## Tier 2-3 測試結果 (外部載入模式)

| TC | 模式 | 觸發詞 | 專案 | 外部檔案載入 | 結果 |
|----|------|--------|------|--------------|------|
| 07 | State Machine | "state", "lifecycle" | TTCA-iOS | ✅ mode-04 | 5/5 ✅ |
| 08 | Log Discovery | "logging" | TTCA-iOS | ✅ mode-06 | 5/5 ✅ |
| 09 | Transaction | "transaction" | cal.com | ✅ mode-09 | 5/5 ✅ |
| 10 | Taint Analysis | "taint" | TTCA-iOS | ✅ mode-12 | 5/5 ✅ |
| 12 | Feature Toggle | "feature flag" | cal.com | ✅ mode-07 | 5/5 ✅ |
| 13 | Cache Flow | "cache" | cal.com | ✅ mode-11 | 5/5 ✅ |
| 14 | Dead Code | "dead code" | sourceatlas2 | ✅ mode-13 | 5/5 ✅ |
| 15 | Concurrency | "async" | TTCA-iOS | ✅ mode-14 | 5/5 ✅ |
| 17 | Flow Comparison | "compare", "vs" | Express.js | ✅ mode-05 | 5/5 ✅ |

**Tier 2-3 驗證**：✅ 全部正確偵測關鍵字並載入對應外部檔案

---

## Dispatch 機制驗證

### 測試矩陣

| 輸入關鍵字 | 預期 Tier | 實際結果 |
|-----------|-----------|----------|
| "order flow" | Tier 1 (Standard) | ✅ 正確 |
| "who calls X" | Tier 1 (Reverse) | ✅ 正確 |
| "error handling" | Tier 1 (Error Path) | ✅ 正確 |
| "data flow" | Tier 1 (Data Flow) | ✅ 正確 |
| "event message" | Tier 1 (Event) | ✅ 正確 |
| "state lifecycle" | Tier 2 → mode-04 | ✅ 正確 |
| "logging" | Tier 2 → mode-06 | ✅ 正確 |
| "transaction" | Tier 2 → mode-09 | ✅ 正確 |
| "taint analysis" | Tier 2 → mode-12 | ✅ 正確 |
| "feature flag" | Tier 3 → mode-07 | ✅ 正確 |
| "cache flow" | Tier 3 → mode-11 | ✅ 正確 |
| "dead code" | Tier 3 → mode-13 | ✅ 正確 |
| "async flow" | Tier 3 → mode-14 | ✅ 正確 |
| "permission flow" | Tier 1 (Permission) | ✅ 正確 |
| "compare X vs Y" | Tier 3 → mode-05 | ✅ 正確 |

---

## 關鍵修復

### 問題：Dispatch 表格未被執行

**症狀**：
- Claude 輸出整個 skill 內容而非執行指令
- 外部檔案未被載入

**解決方案**：
1. 將 STEP 0 移至文件最頂部
2. 將表格格式從描述式改為命令式：
   ```markdown
   # 修復前 (被當作文件輸出)
   | Keywords | Mode |
   |----------|------|
   | "dead code" | Mode 13 |

   # 修復後 (被當作指令執行)
   | If arguments contain... | Then execute this action |
   |------------------------|--------------------------|
   | "dead code" | `Read mode-13-dead-code.md` then follow |
   ```
3. 加入明確指令：「Load the file NOW... Do NOT continue reading this document」

---

## 效能指標

| 指標 | 優化前 | 優化後 |
|------|--------|--------|
| atlas.flow.md 行數 | 2,708 | 239 |
| 首次載入 tokens | ~4,000 | ~400 |
| 外部模式檔案 | 0 | 9 |
| 模式總數 | 5 | 14 |

---

## 總結

| 項目 | 結果 |
|------|------|
| Tier 1 模式 | 6/6 通過 |
| Tier 2-3 模式 | 9/9 通過 |
| Dispatch 正確率 | 100% |
| 外部檔案載入 | 100% |
| **整體評分** | **15/15 (100%)** |

---

## 補充測試 (2026-01-02)

| TC | 模式 | 專案 | 說明 |
|----|------|------|------|
| 16 | Permission Flow | cal.com | PBAC 系統，角色層級：OWNER > ADMIN > MEMBER |
| 17 | Flow Comparison | Express.js | v5.2.0 vs v5.2.1 安全補丁比較 (CVE-2024-51999) |

---

## 建議後續

1. ~~**Flow Comparison (mode-05)** - 未測試，需要兩個版本的程式碼~~ ✅ 已完成
2. ~~**Permission Flow (mode-10)** - Tier 1，需要有 RBAC 的專案測試~~ ✅ 已完成
3. **持續監控** - 確保新增模式時 dispatch 邏輯正確

---

🗺️ SourceAtlas v3.0 │ Test Report
