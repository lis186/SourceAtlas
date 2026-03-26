## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

**載入的框架 patterns**：swiftui

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | @MainActor | 3 | WhisperState.swift:19 |
| 2 | S | DispatchQueue_main | 3 | WhisperState.swift:57 |
| 3 | S | dispatch_async | 1 | WhisperState.swift:57 |
| 4 | S | Task_unstructured | 5 | WhisperState.swift:45 |
| 5 | N | NotificationCenter_post | 2 | WhisperState.swift:166 |
| 6 | N | NotificationCenter_removeObserver | 1 | WhisperState.swift:496 |
| 7 | L | deinit | 1 | WhisperState.swift:495 |
| 8 | D | shared_singleton | 6 | WhisperState.swift:125 |
| 9 | E | do_catch | 5 | WhisperState.swift:142 |
| 10 | C | Task_cancel | 2 | WhisperState.swift:170 |
| 11 | C | checkCancellation | 5 | WhisperState.swift:374 |

共 11 個錨點命中。
