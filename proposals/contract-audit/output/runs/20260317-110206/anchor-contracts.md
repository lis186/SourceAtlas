## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

**載入的框架 patterns**：combine

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_sync | 2 | PaymentsNetworkDispatcher.swift:96 |
| 2 | S | DispatchQueue_create | 1 | PaymentsNetworkDispatcher.swift:86 |
| 3 | N | NotificationCenter_post | 1 | PaymentsNetworkDispatcher.swift:362 |
| 4 | D | shared_singleton | 1 | PaymentsNetworkDispatcher.swift:90 |
| 5 | D | if_conditional | 1 | PaymentsNetworkDispatcher.swift:134 |
| 6 | E | throws_decl | 4 | PaymentsNetworkDispatcher.swift:102 |
| 7 | E | do_catch | 3 | PaymentsNetworkDispatcher.swift:140 |
| 8 | E | Codable | 1 | PaymentsNetworkDispatcher.swift:119 |
| 9 | N | combine_sink | 25 ⚠️ pervasive | PaymentsNetworkManager.swift:40 |
| 10 | N | combine_store | 25 ⚠️ pervasive | PaymentsNetworkManager.swift:49 |

共 10 個錨點命中。
