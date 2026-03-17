## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | Promise_all | 1 | DatabaseManager.ts:238 |
| 2 | S | async_function | 3 | examples.ts:9 |
| 3 | E | try_block | 9 | EventHistory.ts:53 |
| 4 | E | throw_new | 1 | DatabaseManager.ts:60 |

共 4 個錨點命中。
