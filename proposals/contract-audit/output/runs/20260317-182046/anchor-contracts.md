## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | Promise_new | 1 | create-page.js:43 |
| 2 | S | async_function | 1 | create-page.js:123 |
| 3 | S | await_expr | 1 | create-page.js:137 |
| 4 | D | import_dynamic | 5 | create-page.js:194 |
| 5 | D | require_call | 3 | create-page.js:12 |
| 6 | E | try_block | 1 | create-page.js:127 |
| 7 | E | catch_block | 1 | create-page.js:239 |

共 7 個錨點命中。
