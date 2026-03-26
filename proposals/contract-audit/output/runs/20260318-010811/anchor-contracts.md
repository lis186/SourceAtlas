## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

**載入的框架 patterns**：swiftui

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | actor_decl | 1 | LibWhisper.swift:11 |
| 2 | S | @MainActor | 5 | WhisperState.swift:19 |
| 3 | S | DispatchQueue_main | 3 | WhisperState.swift:57 |
| 4 | S | dispatch_async | 1 | WhisperState.swift:57 |
| 5 | S | Task_unstructured | 8 | WhisperState.swift:45 |
| 6 | N | NotificationCenter_post | 5 | WhisperState.swift:166 |
| 7 | N | NotificationCenter_addObserver | 5 | WhisperPrompt.swift:61 |
| 8 | N | NotificationCenter_removeObserver | 2 | WhisperState.swift:496 |
| 9 | L | deinit | 3 | WhisperState.swift:495 |
| 10 | D | shared_singleton | 11 | WhisperState.swift:125 |
| 11 | D | canImport | 1 | LibWhisper.swift:2 |
| 12 | D | if_conditional | 2 | LibWhisper.swift:2 |
| 13 | E | throws_decl | 2 | LibWhisper.swift:117 |
| 14 | E | do_catch | 5 | WhisperState.swift:142 |
| 15 | C | Task_cancel | 3 | WhisperState.swift:170 |
| 16 | C | checkCancellation | 5 | WhisperState.swift:374 |

共 16 個錨點命中。
