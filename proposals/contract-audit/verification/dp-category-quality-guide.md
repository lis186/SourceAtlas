# D/P 類別合約品質驗證指南 — TypeScript

本指南說明 D（Dependency）和 P（Propagation）類別合約在 TypeScript 專案中的典型表現形式，
以及對應的品質標準。供合約審計管線的人工審閱和自動化驗證參考。

---

## 1. D（Dependency）類別：TypeScript 典型表現

D 類別合約描述模組對外部資源或框架的依賴關係。
在 TypeScript 中，常見的 D 類別合約來源如下：

### 1.1 npm 第三方深層 import

直接引用第三方套件的內部路徑，形成對套件內部結構的隱含依賴。

```typescript
// 高風險：依賴 lodash 內部路徑，套件重構即破壞
import { cloneDeep } from 'lodash/internal/baseClone';

// 高風險：依賴 node_modules 內部模組
import { parse } from 'acorn/dist/acorn.mjs';

// 中風險：使用未文件化的子路徑匯出
import { unstable_batchedUpdates } from 'react-dom/client';
```

**合約範例**：`AuthService 依賴 jsonwebtoken 套件的 decode 函式，預期回傳值包含 exp 欄位（JWT 過期時間戳記）`

### 1.2 框架耦合

與特定框架的深層綁定，導致模組無法獨立於框架運作。

```typescript
// React Context 耦合
const auth = useContext(AuthContext);

// Angular 依賴注入
@Injectable({ providedIn: 'root' })
class AuthService {
  constructor(private http: HttpClient) {}
}

// Next.js 框架耦合
import { cookies } from 'next/headers';
```

**合約範例**：`AuthMiddleware 透過 React Context 取得目前使用者狀態，預期 AuthContext.Provider 存在於元件樹中`

### 1.3 環境變數依賴

模組行為取決於執行時期的環境變數設定。

```typescript
// 直接存取 process.env
const apiUrl = process.env.NEXT_PUBLIC_API_URL;
const secret = process.env.JWT_SECRET;

// Vite 環境變數
const mode = import.meta.env.VITE_APP_MODE;
```

**合約範例**：`TokenManager 在啟動時讀取 JWT_SECRET 環境變數，若不存在則拋出 ConfigurationError`

### 1.4 資料庫/API 客戶端直接使用

模組直接持有並操作資料庫連線或 HTTP 客戶端實例。

```typescript
// 直接使用 Prisma client
const user = await prisma.user.findUnique({ where: { id } });

// 直接使用 axios instance
const response = await axios.get('/api/users', { headers: authHeader });

// 直接使用 Redis client
await redis.set(`session:${userId}`, token, 'EX', 3600);
```

**合約範例**：`AuthService.validateToken() 呼叫 Redis 查詢 session 資料，預期 Redis 連線可用且 key 格式為 session:{userId}`

---

## 2. P（Propagation）類別：TypeScript 典型表現

P 類別合約描述效果（effect）在模組邊界間的傳播路徑。
在 TypeScript 中，常見的 P 類別合約來源如下：

### 2.1 Promise chain 的 error propagation

錯誤在 Promise 鏈中的傳播方式決定了呼叫者的行為。

```typescript
// 錯誤向上傳播：呼叫者必須處理 AuthError
async function login(credentials: Credentials): Promise<Token> {
  const response = await fetch('/api/login', { body: JSON.stringify(credentials) });
  if (!response.ok) throw new AuthError(response.status);  // 傳播給呼叫者
  return response.json();
}

// 錯誤被吞掉：呼叫者看不到失敗
async function refreshToken(): Promise<Token | null> {
  try {
    return await fetch('/api/refresh').then(r => r.json());
  } catch {
    return null;  // 錯誤被靜默處理
  }
}
```

**合約範例**：`login() 在 HTTP 401 時拋出 AuthError，呼叫者（LoginForm）必須 catch 並顯示錯誤訊息`

### 2.2 Redux/Zustand state mutation propagation

狀態變更從 action 發起，經由 reducer/store 傳播至所有訂閱者。

```typescript
// Zustand store：狀態變更傳播至所有 useAuthStore() 訂閱者
const useAuthStore = create<AuthState>((set) => ({
  user: null,
  login: async (creds) => {
    const user = await authService.login(creds);
    set({ user });  // 觸發所有訂閱元件重新渲染
  },
  logout: () => set({ user: null }),  // 傳播「登出」效果至全應用
}));

// Redux：dispatch 傳播路徑
dispatch(setUser(userData));  // -> reducer -> store -> 所有 useSelector 訂閱者
```

**合約範例**：`authStore.logout() 將 user 設為 null，傳播至 NavBar、ProfilePage、ProtectedRoute 等所有訂閱元件，觸發重新渲染和路由重導向`

### 2.3 React props drilling

資料和回呼函式透過多層元件 props 向下傳遞。

```typescript
// 層層傳遞 onAuthChange 回呼
function App() {
  return <Layout onAuthChange={handleAuth}>   {/* 第 1 層 */}
    <Sidebar onAuthChange={handleAuth}>         {/* 第 2 層 */}
      <UserMenu onAuthChange={handleAuth} />    {/* 第 3 層 */}
    </Sidebar>
  </Layout>;
}
```

**合約範例**：`onAuthChange 回呼從 App 經由 Layout、Sidebar 傳遞至 UserMenu，中間任何一層若未轉發則鏈斷裂`

### 2.4 EventEmitter 事件傳播鏈

事件從發射端傳播至所有監聽端，形成隱含的執行流。

```typescript
// 事件發射
class AuthService extends EventEmitter {
  async login(creds: Credentials) {
    const token = await this.fetchToken(creds);
    this.emit('auth:login', { userId: token.sub });      // 傳播至監聽者
    this.emit('auth:token-refresh', { token });           // 傳播至監聽者
  }

  async logout() {
    this.emit('auth:logout', { reason: 'user-initiated' }); // 傳播至監聽者
  }
}

// 多個監聽者形成傳播鏈
authService.on('auth:logout', () => cache.clear());
authService.on('auth:logout', () => analytics.track('logout'));
authService.on('auth:logout', () => router.push('/login'));
```

**合約範例**：`AuthService 發射 auth:logout 事件時，CacheManager、AnalyticsService、Router 三個監聽者依序執行，任一監聯者拋出例外將阻斷後續監聽者`

---

## 3. 品質標準

### 3.1 D 類別合約品質要求

每個 D 類別合約必須滿足以下條件：

| 項目 | 要求 | 說明 |
|------|------|------|
| seam_type 標記 | 必填 | 標記為 Object Seam、Preprocessing Seam 或 Link Seam 之一 |
| 依賴方向 | 必填 | 明確標示「A 依賴 B」的方向 |
| evidence | 必填 | 至少一筆 `file:line` 參照 |
| 替換策略 | 建議 | 標記可能的依賴替換方式（注入、包裝、模擬） |

**TypeScript 常見 Seam 類型對應**：

- **Object Seam**：透過 interface / abstract class 實現的依賴注入點。可在測試中替換為 mock 實作。
- **Preprocessing Seam**：TypeScript 的 `paths` 設定（tsconfig.json）或 bundler alias（webpack/vite resolve.alias）。可在建置時重導向 import 目標。
- **Link Seam**：ES module 的 re-export（barrel file `index.ts`）。修改 re-export 即可替換整個模組。

### 3.2 P 類別合約品質要求

每個 P 類別合約必須滿足以下條件：

| 項目 | 要求 | 說明 |
|------|------|------|
| effect 路徑 | 必填 | 至少追蹤一種：`return`（回傳值傳播）、`mutates`（狀態變更）、`global`（全域副作用） |
| 傳播終點 | 必填 | 標示效果最終影響的元件/模組 |
| evidence | 必填 | 至少一筆 `file:line` 參照 |
| 中斷條件 | 建議 | 標記可能導致傳播中斷的情況（try-catch 吞掉錯誤、條件判斷短路等） |

**Effect 路徑類型說明**：

- **return**：效果透過函式回傳值傳播。呼叫者根據回傳值決定後續行為。
- **mutates**：效果透過狀態變更傳播。Store 更新觸發訂閱者重新執行。
- **global**：效果透過全域副作用傳播。如 `window.location` 變更、`localStorage` 寫入、`document.cookie` 修改。

### 3.3 D/P 佔比基準

D/P 類別合約在總合約中的佔比反映模組的耦合程度：

| 指標 | 建議範圍 | 異常處置 |
|------|----------|----------|
| D/P 合約佔總合約比例 | 15% - 25% | 低於 15%：可能遺漏隱含依賴，建議重新檢視 import 和全域存取 |
| | | 高於 25%：模組耦合度偏高，重構時風險較大，建議優先處理 Pinch Point |
| D 類別中有 seam_type 標記的比例 | 100% | 未標記者視為品質不合格，退回重新分析 |
| P 類別中有 effect 路徑的比例 | 100% | 未標記者視為品質不合格，退回重新分析 |
| P 類別中有中斷條件標記的比例 | >= 50% | 低於 50% 時發出警告，可能存在未識別的 error swallowing |

---

## 4. 審閱檢查清單

人工審閱 D/P 合約時，依照以下順序檢查：

1. [ ] 所有第三方 import 是否已被 D 合約覆蓋（特別是深層路徑 import）
2. [ ] 環境變數存取（`process.env`、`import.meta.env`）是否已被 D 合約覆蓋
3. [ ] 框架特定的依賴注入（React Context、Angular DI）是否已被 D 合約覆蓋
4. [ ] Promise/async 的錯誤傳播路徑是否已被 P 合約覆蓋
5. [ ] 狀態管理的 mutation 傳播是否已被 P 合約覆蓋
6. [ ] EventEmitter/Subject 的事件傳播鏈是否已被 P 合約覆蓋
7. [ ] D/P 佔比是否在 15%-25% 範圍內
8. [ ] 每個 D 合約是否標記了 seam_type
9. [ ] 每個 P 合約是否追蹤了至少一種 effect 路徑
