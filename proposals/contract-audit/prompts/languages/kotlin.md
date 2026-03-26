# Language Plugin: Kotlin
# Contract Audit 語言插件 -- Kotlin / Android / KMP
# Version: 1.0

---

## 適用範圍

- 純 Kotlin 模組（`.kt` / `.kts`）
- Android 應用（Activity, Fragment, ViewModel, Compose）
- Kotlin Multiplatform（KMP / KMM）
- 後端框架（Ktor, Spring Boot with Kotlin）
- Mixed Java + Kotlin 模組中的 Kotlin 部分

---

## 1. 通知/事件原語

### LiveData / MutableLiveData
```kotlin
class UserViewModel : ViewModel() {
    private val _user = MutableLiveData<User>()
    val user: LiveData<User> = _user

    fun loadUser(id: String) {
        viewModelScope.launch {
            _user.value = repository.getUser(id)
        }
    }
}

// 觀察端
viewModel.user.observe(viewLifecycleOwner) { user ->
    updateUI(user)
}
```

稽核要點：
- `MutableLiveData` 暴露為 `LiveData`（唯讀）是封裝合約——洩漏 `MutableLiveData` 破壞此合約
- `observe` 綁定 `LifecycleOwner`——Activity/Fragment 銷毀時自動取消
- `setValue` 只能在主執行緒呼叫，`postValue` 可在任何執行緒——但 `postValue` 會合併（coalesce）快速連續的更新
- LiveData 在 observer inactive 時暫停發送，reactivate 時只發最新值——中間值丟失是合約

### StateFlow / SharedFlow
```kotlin
private val _state = MutableStateFlow(UiState.Loading)
val state: StateFlow<UiState> = _state.asStateFlow()

private val _events = MutableSharedFlow<Event>()
val events: SharedFlow<Event> = _events.asSharedFlow()
```

稽核要點：
- `StateFlow` 永遠有值（conflated）——新 collector 立即收到最新值
- `SharedFlow` 預設不 replay——`replay = 0` 表示新 collector 不收到歷史值
- `MutableStateFlow.value` 使用 `equals` 去重——自訂 `equals` 實作是隱含合約
- `SharedFlow` 的 `emit` 是 suspend function——buffer 滿時會掛起（`BufferOverflow.SUSPEND`）
- `collectLatest` vs `collect`——`collectLatest` 在新值到來時取消前一個 block

### BroadcastChannel / Channel（已半棄用，但仍常見）
```kotlin
val channel = Channel<Event>(Channel.BUFFERED)

// 生產端
channel.send(event) // suspend if full

// 消費端
for (event in channel) {
    process(event)
}
```

稽核要點：
- Channel 是 hot stream——沒有 consumer 時 send 會掛起或丟棄（取決於 capacity）
- `Channel.CONFLATED` 只保留最新值——舊值被覆蓋是合約
- `Channel` 是單一消費者——多個 consumer 會競爭（fan-out），不是廣播
- `close()` 後 `send` 拋 `ClosedSendChannelException`

### Callback / Listener（Android）
```kotlin
button.setOnClickListener { view ->
    handleClick(view)
}

recyclerView.addOnScrollListener(object : RecyclerView.OnScrollListener() {
    override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
        // ...
    }
})
```

稽核要點：
- `setOnClickListener` 會覆蓋前一個 listener——是 replace 語義，不是 add
- `addOnScrollListener` 是 add 語義——不移除會累積
- 匿名 object 持有外部 class 的隱式 reference——Activity/Fragment 洩漏風險

---

## 2. 同步原語

### Coroutine / Structured Concurrency
```kotlin
viewModelScope.launch {
    val user = async { repository.getUser(id) }
    val orders = async { repository.getOrders(id) }
    updateUI(user.await(), orders.await())
}
```

稽核要點：
- `viewModelScope` 在 ViewModel `onCleared` 時取消所有子 coroutine——是生命週期合約
- `launch` vs `async`——`launch` 的例外會傳播到 parent，`async` 的例外延遲到 `await`
- `supervisorScope` / `SupervisorJob` 阻止子 coroutine 失敗傳播——這改變了錯誤處理合約
- `withContext(Dispatchers.IO)` 是執行緒切換合約——忘記切換可能阻塞主執行緒
- `coroutineScope` vs `supervisorScope`——前者任一子 coroutine 失敗全部取消，後者不會
- `CoroutineExceptionHandler` 只在 root coroutine 或 `supervisorScope` 的直接子 coroutine 生效——嵌套 coroutine 的例外向上傳播，不觸發 handler

### Dispatchers
```kotlin
withContext(Dispatchers.Main) { updateUI() }
withContext(Dispatchers.IO) { networkCall() }
withContext(Dispatchers.Default) { heavyComputation() }
```

稽核要點：
- `Dispatchers.Main` 在非 Android 環境（測試、KMP）可能未定義——需要 `Dispatchers.Main.immediate`
- `Dispatchers.IO` 預設 64 個執行緒——超過時新的 coroutine 排隊等待
- `Dispatchers.Unconfined` 在第一個 suspension point 後切換到 resume 的執行緒——行為不可預測

### Mutex
```kotlin
private val mutex = Mutex()

suspend fun safeIncrement() {
    mutex.withLock {
        counter++
    }
}
```

稽核要點：
- `Mutex` 是 coroutine-aware——不會阻塞執行緒，但同一 coroutine 重入會死鎖
- `Mutex.withLock` 使用 `try/finally` 確保釋放
- `Semaphore(permits)` 控制並行度——常用於限制 API 呼叫頻率

### @Synchronized / synchronized
```kotlin
@Synchronized
fun legacyThreadSafe() {
    // ...
}

synchronized(lock) {
    // critical section
}
```

稽核要點：
- `@Synchronized` 是 JVM intrinsic monitor——不適用於 coroutine
- 在 coroutine 中使用 `synchronized` 可能導致執行緒飢餓（thread starvation）
- Kotlin/Native 不支援 `synchronized`——KMP 需要替代方案（`kotlinx.atomicfu`）

---

## 3. 生命週期模式

### Activity Lifecycle
```
onCreate() -> onStart() -> onResume() -> onPause() -> onStop() -> onDestroy()
```

稽核要點：
- `onCreate(savedInstanceState)` 中的 Bundle 可能為 null（首次啟動）或非 null（恢復）
- `onSaveInstanceState` 只在系統殺死 Activity 前呼叫——主動 finish 不呼叫
- Configuration change（螢幕旋轉）觸發完整的 destroy-recreate 週期
- `onDestroy` 不保證被呼叫（系統直接殺死程序）

### Fragment Lifecycle
```
onAttach -> onCreate -> onCreateView -> onViewCreated -> onStart -> onResume
-> onPause -> onStop -> onDestroyView -> onDestroy -> onDetach
```

稽核要點：
- Fragment 的 view lifecycle 與 Fragment lifecycle 不同——`viewLifecycleOwner` vs `this`
- `onDestroyView` 後 view reference 變為 stale——繼續持有會洩漏
- `by viewModels()` 綁定 Fragment lifecycle，`by activityViewModels()` 綁定 Activity lifecycle

### Jetpack Compose Lifecycle
```kotlin
@Composable
fun UserScreen(userId: String) {
    val viewModel: UserViewModel = viewModel()

    LaunchedEffect(userId) {
        viewModel.loadUser(userId)
    }

    DisposableEffect(Unit) {
        onDispose { /* cleanup */ }
    }

    val lifecycle = LocalLifecycleOwner.current
    // ...
}
```

稽核要點：
- `LaunchedEffect(key)` 在 key 變更時取消並重新啟動——key 的 equals 實作是合約
- `remember(key) { }` 在 key 變更時重新計算——忘記加 key 導致 stale 值
- `DisposableEffect` 的 `onDispose` 在 Composable 離開 Composition 時呼叫
- `derivedStateOf { }` 只在依賴變更時重算——減少不必要的 recomposition
- Recomposition 可以跳過——不保證每次 state 變更都觸發
- `rememberUpdatedState` 在不重啟 effect 的情況下安全引用最新值——常用於 `LaunchedEffect(true)` 中的 callback，避免 stale closure
- `produceState(initialValue) { value = ... }` 將外部非 Compose 狀態（Flow、LiveData、RxJava）轉為 Compose State——內部啟動 coroutine，離開 Composition 時自動取消
- `SideEffect { }` 每次成功 recomposition 後同步執行（非 suspend）——用於將 Compose state 同步到非 Compose 系統（如 analytics、logging）
- `snapshotFlow { state.value }` 將 Compose State 轉為 Flow——只在 snapshot 內讀取的 state 變更時 emit

### ViewModel Lifecycle
```kotlin
class UserViewModel(
    private val savedStateHandle: SavedStateHandle
) : ViewModel() {

    init { loadData() }

    override fun onCleared() {
        // cleanup: cancel non-coroutine resources
    }
}
```

稽核要點：
- ViewModel 存活跨 configuration change——但不跨 process death
- `SavedStateHandle` 跨 process death 但限制 Bundle 大小
- `viewModelScope` 在 `onCleared` 時自動取消

---

## 4. 驗證策略

**ast-grep: 完整支援。**

Kotlin 是 ast-grep 的支援語言。所有合約應優先使用 ast-grep 規則驗證。

### ast-grep 規則撰寫指南

```yaml
id: n1-livedata-observe
message: "N1: LiveData observation -- lifecycle-aware contract must be present"
severity: error
language: Kotlin
rule:
  pattern: |
    $LIVEDATA.observe($OWNER) { $BODY }
```

**Pattern 注意事項：**
- Kotlin 的 trailing lambda 語法需要注意：`foo { }` vs `foo({ })`
- `data class` 的 `equals`/`hashCode` 自動生成——影響 `StateFlow` 去重
- `sealed class`/`sealed interface` 的 `when` exhaustiveness 是合約
- 使用 `kind: call_expression` + `has` 組合匹配複雜調用鏈

### grep 作為補充

```bash
# 檢查 MutableLiveData 是否被暴露為 LiveData
grep -n 'val.*MutableLiveData' "$file" | grep -v 'private'

# 檢查 viewModelScope 使用
grep -n 'viewModelScope\.\(launch\|async\)' "$file"

# 檢查 Dispatchers 切換
grep -n 'withContext\|Dispatchers\.' "$file"

# 檢查 suspend function 是否在非 coroutine context 中被呼叫
grep -n 'runBlocking' "$file"
```

### Mixed Java + Kotlin 模組

- Kotlin 部分：使用 ast-grep 規則
- Java 部分：使用 ast-grep（Java 亦支援）或 grep
- 跨語言合約重點：
  - Java 回傳的 platform type `T!` 在 Kotlin 側不強制 null check
  - `@Nullable` / `@NonNull` annotation 影響 Kotlin 側的 nullability 推斷
  - Kotlin `companion object` 的 `@JvmStatic` 影響 Java 側的呼叫方式

---

## 5. Effect 防火牆

**強度：強。**

Kotlin 提供多層不可變性機制：

### val 宣告
```kotlin
val value = 42  // 不可重新賦值
```
- `val` 只保證 reference 不可變——`val list = mutableListOf()` 仍可修改內容
- `val` + `List`（不可變介面）才是真正不可變

### Data Class
```kotlin
data class User(val name: String, val age: Int)
```
- `data class` 的所有屬性建議用 `val`——`var` 屬性使 `copy()` 語義混亂
- 自動生成的 `equals`/`hashCode`/`toString`/`copy` 是合約——修改屬性列表影響所有四個方法
- `copy()` 是淺拷貝——nested mutable object 仍共享 reference

### Sealed Class / Interface
```kotlin
sealed interface Result {
    data class Success(val data: Data) : Result
    data class Error(val exception: Throwable) : Result
    data object Loading : Result
}
```
- `when (result)` 必須窮舉——新增子類別會導致編譯錯誤
- 這使得 `sealed` 成為天然的合約表達機制

### Value Class (inline class)
```kotlin
@JvmInline
value class UserId(val value: String)
```
- 編譯時型別安全，runtime 零開銷
- 防止 primitive obsession（傳錯 String 參數）

**稽核影響：**
- `val` + immutable interface（`List`, `Map`, `Set`）可以信任不可變性
- `var` 或 mutable collection 需要追蹤所有修改點
- `data class` 的 `copy()` 語義需要特別注意淺拷貝風險
- `sealed` 類型的 exhaustive `when` 是編譯器強制的合約

---

## 6. Seam 類型

### Object Seam（Interface / Abstract Class）
```kotlin
interface UserRepository {
    suspend fun getUser(id: String): User?
    suspend fun saveUser(user: User)
}

class UserRepositoryImpl(
    private val api: ApiService,
    private val db: UserDao
) : UserRepository {
    // ...
}
```

- Kotlin interface 可以有預設實作——預設實作是隱含合約（同 Swift protocol extension）
- `by` 委託模式提供簡潔的 Decorator pattern：`class Logging(inner: Repo) : Repo by inner`
- 依賴注入框架（Hilt, Koin, Kodein）使用 interface binding——binding 設定是合約

### Preprocessing Seam
```kotlin
// BuildConfig（Android）
if (BuildConfig.DEBUG) {
    enableDebugMode()
}

// Kotlin Multiplatform expect/actual
expect fun platformLog(message: String)
actual fun platformLog(message: String) = Log.d("TAG", message)
```

- `BuildConfig` 在 compile time 決定——不同 build variant 產生不同行為
- KMP `expect/actual` 是跨平台的 Preprocessing Seam——每個 target 有獨立實作
- ProGuard/R8 規則可能移除「看似無用」的代碼——是 Link Seam 的延伸

### Link Seam
```kotlin
// 動態載入（ServiceLoader pattern）
val services = ServiceLoader.load(MyService::class.java)

// Dagger/Hilt Module
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    fun provideClient(): OkHttpClient = OkHttpClient.Builder().build()
}
```

- DI container 的 binding 是 Link Seam——runtime 替換實作
- `@InstallIn` 的 Component 決定 scope（Singleton, Activity, Fragment）——scope 是生命週期合約

---

## 7. Sprout/Wrap 策略

### Sprout Method
```kotlin
// Before
fun processOrder(order: Order): Receipt {
    // 200 lines of mixed validation + processing + notification
}

// After
fun processOrder(order: Order): Receipt {
    val validated = validateOrder(order)  // sprouted
    // remaining logic
}

// Sprouted -- independently testable
private fun validateOrder(order: Order): ValidatedOrder {
    require(order.items.isNotEmpty()) { "Order must have items" }
    require(order.total > 0) { "Total must be positive" }
    return ValidatedOrder(order)
}
```

**Kotlin 優勢：** `require` / `check` / `error` 提供語義化的前置條件檢查

### Sprout Class
```kotlin
class OrderValidator(
    private val rules: List<ValidationRule>
) {
    fun validate(order: Order): ValidationResult {
        val violations = rules.mapNotNull { it.check(order) }
        return if (violations.isEmpty()) Valid else Invalid(violations)
    }
}
```

**Kotlin 優勢：** `sealed class` 讓 `ValidationResult` 的消費者必須處理所有情況

### Wrap Method
```kotlin
suspend fun processOrder(order: Order): Receipt {
    logger.info("Processing order ${order.id}")
    return processOrderInternal(order).also {
        logger.info("Order ${order.id} completed: $it")
    }
}
```

**Kotlin 優勢：** `also`/`let`/`apply`/`run` scope function 讓 wrap 更簡潔

### Wrap Class (Decorator via delegation)
```kotlin
class LoggingRepository(
    private val inner: UserRepository
) : UserRepository by inner {
    override suspend fun getUser(id: String): User? {
        logger.debug("getUser($id)")
        return inner.getUser(id).also { logger.debug("getUser result: $it") }
    }
    // saveUser 自動委託給 inner
}
```

**Kotlin 優勢：** `by` 委託自動轉發未覆寫的方法——不需要手動實作每個 interface 方法

---

## 8. 常見隱含合約範例

### 8.1 Platform Type（Java 互操作）
```kotlin
// Java 方法回傳 String（沒有 @Nullable/@NonNull annotation）
// Kotlin 側看到的是 String!（platform type）
val name: String = javaObject.getName()  // 如果 Java 回傳 null -> NPE
val name: String? = javaObject.getName() // 安全，但改變了下游的使用方式
```

**重構風險：** Java→Kotlin 遷移時，所有 platform type 的 nullability 決定都是隱含合約。選擇 `String` vs `String?` 影響所有下游消費者。

### 8.2 Coroutine 取消不合作
```kotlin
suspend fun longRunning() {
    // 隱含合約：此函式不檢查 cancellation
    while (hasMoreWork()) {
        doWork()  // 如果 doWork() 不是 suspend function，cancel 無效
    }
}

// 正確版本
suspend fun longRunning() {
    while (hasMoreWork()) {
        ensureActive()  // 或 yield()
        doWork()
    }
}
```

### 8.3 data class equals 語義
```kotlin
data class CacheKey(
    val url: String,
    val headers: Map<String, String>,  // Map 的 equals 是深比較
    val timestamp: Long  // 包含 timestamp 導致每次都 cache miss
)
```

**重構風險：** 新增/移除 data class 屬性會自動改變 `equals`/`hashCode`，影響所有使用 `==`、`Set`、`Map` key 的地方。

### 8.4 Scope Function 副作用
```kotlin
// 隱含合約：apply 的回傳值是 receiver 本身
val request = Request.Builder()
    .url(url)
    .apply {
        if (authToken != null) {
            header("Authorization", "Bearer $authToken")
        }
    }
    .build()
```

### 8.5 Extension Function 遮蔽
```kotlin
// 隱含合約：extension function 優先於成員函式（在同一 scope 內）
// 但如果匯入不同 package 的同名 extension，行為會改變
fun String.isValid(): Boolean = this.isNotBlank() && this.length <= 100

// 另一個 package 中
fun String.isValid(): Boolean = this.matches(emailRegex)
```

**重構風險：** 移動檔案到不同 package 或改變 import 可能導致呼叫到不同的 extension function，不會產生編譯錯誤。

### 8.6 init block 順序
```kotlin
class Repository(url: String) {
    // 隱含合約：property initializer 和 init block 按宣告順序執行
    val client = HttpClient()  // 1st
    val baseUrl = url          // 2nd

    init {
        // 3rd -- 此時 client 和 baseUrl 都已初始化
        client.setBaseUrl(baseUrl)
    }

    val cache = Cache(client)  // 4th -- 此時 init block 已執行
}
```

### 8.7 Sealed class exhaustive when
```kotlin
// 隱含合約：所有 when 分支必須處理，新增子類別 = 編譯錯誤
fun render(state: UiState) = when (state) {
    is UiState.Loading -> showLoading()
    is UiState.Success -> showData(state.data)
    is UiState.Error -> showError(state.message)
    // 新增 UiState.Empty -> 所有 when 表達式都需要更新
}
```

### 8.8 Companion object 初始化
```kotlin
class ApiClient {
    companion object {
        // 隱含合約：companion object 在 class 首次載入時初始化（lazy by JVM）
        val instance = ApiClient()  // singleton pattern
        private val logger = LoggerFactory.getLogger(ApiClient::class.java)
    }
}
```

**重構風險：** companion object 中的副作用（網路呼叫、檔案 I/O）在 class 首次被 reference 時執行——不一定是預期的時間點。

---

## 9. Kotlin-Java 互操作合約

這是 Kotlin 最獨特的合約風險區域，Java→Kotlin 遷移時尤其重要。

### Nullability 邊界
```kotlin
// Java 端
public String getName() { return name; }  // 可能回傳 null

// Kotlin 端——三種處理方式，各有不同合約
val name1: String = obj.getName()   // NPE if null
val name2: String? = obj.getName()  // safe but changes downstream
val name3: String = obj.getName()!! // explicit NPE
```

### @JvmStatic / @JvmField / @JvmOverloads
```kotlin
class Config {
    companion object {
        @JvmStatic fun create(): Config = Config()    // Java: Config.create()
        @JvmField val DEFAULT = Config()               // Java: Config.DEFAULT
    }

    @JvmOverloads
    fun init(host: String, port: Int = 8080) { }      // Java: init("host") 或 init("host", 9090)
}
```

稽核要點：
- 移除 `@JvmStatic` 會改變 Java 側的呼叫語法——Java 無法存取 `Companion.create()`
- `@JvmOverloads` 生成多個 Java overload——移除會破壞 Java 側省略參數的呼叫
- `@JvmField` 繞過 getter/setter——Java 側直接 field access，移除後需要改為 getter 呼叫

### Collection 互操作
```kotlin
// Kotlin List<T> 在 JVM 上是 java.util.List（可變）
// Java 端可以 cast 並修改 Kotlin 的「不可變」List
val items: List<String> = listOf("a", "b")
// Java: ((java.util.List) items).add("c")  // 成功！但 Kotlin 端預期不可變
```
