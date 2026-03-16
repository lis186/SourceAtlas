## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 命中次數 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_sync | 2 | PaymentsNetworkDispatcher.swift:96 |
| 2 | S | DispatchQueue_create | 1 | PaymentsNetworkDispatcher.swift:86 |
| 3 | S | DispatchSemaphore | 1 | NetworkClientProtocol.swift:191 |
| 4 | N | NotificationCenter_post | 1 | PaymentsNetworkDispatcher.swift:362 |
| 5 | D | shared_singleton | 1 | PaymentsNetworkDispatcher.swift:90 |
| 6 | D | if_conditional | 1 | PaymentsNetworkDispatcher.swift:134 |
| 7 | E | throws_decl | 7 | PaymentsNetworkDispatcher.swift:102 |
| 8 | E | do_catch | 3 | PaymentsNetworkDispatcher.swift:140 |
| 9 | E | Codable | 1 | PaymentsNetworkDispatcher.swift:119 |

共 9 個錨點命中。
