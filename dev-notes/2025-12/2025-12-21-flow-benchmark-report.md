# /atlas.flow Benchmark Report

**Date**: 2025-12-21
**Version**: v2.9.6

## Summary

| Metric | Result |
|--------|--------|
| **Entry Point Detection** | 100% (5/5 projects) |
| **Call Chain Depth** | 4-5 levels per project |
| **Boundary Identification** | 100% (4-5 types per project) |
| **Languages Tested** | Swift, Ruby, Python, TypeScript, Kotlin |

## Test Results by Project

| Project | Language | Flow Target | Entry Point | Depth | Boundaries |
|---------|----------|-------------|-------------|-------|------------|
| Firefox iOS | Swift | TabManager | :380 | 5 | 5 types |
| Discourse | Ruby | user login | :329 | 5 | 5 types |
| Prefect | Python | flow run | :1406 | 5 | 4 types |
| Cal.com | TypeScript | booking | :16 | 5 | 4 types |
| Thunderbird | Kotlin | message | :93 | 4 | 4 types |

## Detailed Analysis

### Firefox iOS - TabManager

**Entry Point**: `TabManagement/TabManagerImplementation.swift:380`

**Call Chain** (5 levels):
1. `addTab()` - 新增分頁入口
2. `Tab.init()` - 創建 Tab 物件
3. `configureTab()` - 配置分頁
4. `delegates.didAddTab()` - 通知觀察者
5. `commitChanges()` → `tabDataStore.save()` - 持久化

**Boundaries Identified**:
- TabDataStore - DB persistence
- TabSessionStore - Session storage
- WKWebView - WebKit framework
- TabManagerDelegate - Delegate pattern
- Redux store.dispatch - State management

### Discourse - user login

**Entry Point**: `app/controllers/session_controller.rb:329`

**Call Chain** (5 levels):
1. `SessionController#create` - 登入入口
2. `User.find_by_username_or_email()` - 查找使用者
3. `user.confirm_password?()` - 驗證密碼
4. `authenticate_second_factor()` - 2FA 驗證
5. `login()` → `log_on_user()` - 執行登入

**Boundaries Identified**:
- User model - DB query
- confirm_password? - bcrypt verification
- authenticate_second_factor - TOTP/WebAuthn
- log_on_user - Cookie/Session
- render_serialized - JSON response

### Prefect - flow run

**Entry Point**: `src/prefect/flow_engine.py:1406`

**Call Chain** (5 levels):
1. `run_flow_sync()` - Flow 執行入口
2. `FlowRunEngine.__init__()` - 創建 Engine
3. `engine.start()` - 初始化 + Server 註冊
4. `engine.run_context()` - 執行上下文
5. `engine.call_flow_fn()` - 執行用戶函數

**Boundaries Identified**:
- SyncPrefectClient - Prefect Server API
- propose_state_sync - State machine
- call_hooks - Event hooks
- wait_for - Dependency waiting

### Cal.com - booking

**Entry Point**: `platform/atoms/hooks/bookings/useCreateBooking.ts:16`

**Call Chain** (5 levels):
1. `useCreateBooking()` - React Hook 入口
2. `http.post("/bookings")` - API 請求
3. `createBooking()` - 建立預約
4. `buildNewBookingData()` - 建構資料
5. `saveBooking()` → `prisma.$transaction()` - 儲存

**Boundaries Identified**:
- http.post - Platform API
- prisma.$transaction - Prisma ORM
- prisma.findUnique - DB query
- useMutation - TanStack Query

### Thunderbird - message

**Entry Point**: `designsystem/organism/message/MessageItem.kt:93`

**Call Chain** (4 levels):
1. `MessageItem()` - Composable 入口
2. `MessageItemUi` - UI 狀態模型
3. `leading()/sender()/subject()` - 子組件
4. `action()` - Star 按鈕

**Boundaries Identified**:
- @Composable - Jetpack Compose
- MessageItemUi - UI State
- MainTheme - Material3
- onClick/onLongClick - Event callbacks

## Validation Criteria

| Criteria | Method | Pass Standard |
|----------|--------|---------------|
| Entry Point Correct | Check if correct file found | Related file found |
| Call Chain Complete | Verify trace depth | ≥3 levels |
| file:line Format | Check output format | 100% compliance |
| Boundary ID | Check boundary markers | Has API/DB etc. |

## Conclusion

`/atlas.flow` achieves 100% validation accuracy across 5 projects in 5 different languages for all key metrics.
