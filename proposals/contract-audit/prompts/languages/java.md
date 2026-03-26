# Language Plugin: Java
# Contract Audit 語言插件 -- Java / Spring / Android
# Version: 1.0

---

## 適用範圍

- 純 Java 模組（`.java`）
- Spring Boot / Spring Framework
- Android 應用（Activity, Fragment, Service）
- Jakarta EE / Java EE
- Reactive 框架（Project Reactor, RxJava）
- Mixed Java + Kotlin 模組中的 Java 部分

---

## 1. 通知/事件原語

### java.util.concurrent 佇列

```java
BlockingQueue<Event> queue = new LinkedBlockingQueue<>(100);

// 生產端
queue.put(event);           // 阻塞直到有空間
queue.offer(event, 1, TimeUnit.SECONDS); // 限時等待

// 消費端
Event e = queue.take();     // 阻塞直到有項目
Event e = queue.poll(1, TimeUnit.SECONDS); // 限時等待
```

稽核要點：
- `put` 和 `take` 是阻塞操作——在 async 或 UI thread 中使用會導致凍結
- `LinkedBlockingQueue` 無界建構（不傳 capacity）時記憶體無限增長
- `offer` 在佇列滿時回傳 `false`——不檢查回傳值會靜默丟棄事件
- `ConcurrentLinkedQueue` 是非阻塞但無界的——適合多生產者場景但沒有背壓

### Observer / Listener Pattern

```java
button.setOnClickListener(new View.OnClickListener() {
    @Override
    public void onClick(View v) {
        handleClick(v);
    }
});

// PropertyChangeSupport（JavaBeans）
support.addPropertyChangeListener("name", evt -> {
    System.out.println("Changed: " + evt.getNewValue());
});
```

稽核要點：
- `setOnClickListener` 是 replace 語義——覆蓋前一個 listener
- `addPropertyChangeListener` 是 add 語義——不移除會累積
- 匿名內部類別持有外部 class 的隱式 reference——Activity/Fragment 洩漏風險（同 Kotlin）
- `removePropertyChangeListener` 需要傳入同一個 listener 物件——lambda 每次建立新實例，無法移除

### CompletableFuture Callback

```java
CompletableFuture.supplyAsync(() -> fetchData())
    .thenApply(data -> transform(data))
    .thenAccept(result -> display(result))
    .exceptionally(ex -> {
        log.error("Failed", ex);
        return null;
    });
```

稽核要點：
- `thenApply` vs `thenApplyAsync`——前者在完成 future 的 thread 上執行，後者在 ForkJoinPool 上
- `exceptionally` 只處理例外——正常完成不觸發
- 沒有 `exceptionally` 或 `handle` 的鏈，例外會被靜默吞掉
- `CompletableFuture.allOf` 回傳 `CompletableFuture<Void>`——結果需要從原始 future 取

### Spring ApplicationEvent

```java
@Component
public class OrderService {
    @Autowired
    private ApplicationEventPublisher publisher;

    public void placeOrder(Order order) {
        // ...
        publisher.publishEvent(new OrderPlacedEvent(order));
    }
}

@Component
public class NotificationListener {
    @EventListener
    public void onOrderPlaced(OrderPlacedEvent event) {
        sendNotification(event.getOrder());
    }

    @TransactionalEventListener(phase = AFTER_COMMIT)
    public void afterOrderCommitted(OrderPlacedEvent event) {
        // 只在 transaction commit 後執行
    }
}
```

稽核要點：
- `@EventListener` 預設同步執行——listener 拋例外會影響 publisher
- `@Async @EventListener` 非同步執行——但例外不會傳播回 publisher
- `@TransactionalEventListener` 綁定 transaction 狀態——`AFTER_COMMIT` 表示只在 commit 後觸發
- 事件是廣播——所有 listener 都會收到，順序不保證（除非 `@Order`）

---

## 2. 同步原語

### synchronized

```java
public class Counter {
    private int count = 0;

    public synchronized void increment() {
        count++;
    }

    public void update() {
        synchronized (this) {
            count++;
        }
    }
}
```

稽核要點：
- `synchronized` 是可重入的——同一 thread 可以多次進入（不像 Go 的 Mutex）
- `synchronized(this)` 鎖定當前實例——外部程式碼也能 `synchronized(obj)` 鎖定同一物件
- `synchronized` 方法隱含地鎖定 `this`（instance method）或 `Class` 物件（static method）
- `synchronized` 不支援 timeout——永久等待，無法被中斷

### java.util.concurrent Locks

```java
ReentrantLock lock = new ReentrantLock();
lock.lock();
try {
    // critical section
} finally {
    lock.unlock();
}

// 可中斷的 lock
lock.lockInterruptibly();

// 限時 lock
if (lock.tryLock(1, TimeUnit.SECONDS)) {
    try { /* ... */ } finally { lock.unlock(); }
}
```

稽核要點：
- `ReentrantLock` 比 `synchronized` 更靈活——支援 tryLock、timeout、Condition
- `lock()` 和 `unlock()` 必須配對——忘記 `unlock`（尤其在例外路徑）會永久死鎖
- `ReadWriteLock` 允許多個讀取者——但寫入者需要等待所有讀取者（可能飢餓）
- `StampedLock`（Java 8+）提供樂觀讀取——效能更好但 API 更複雜

### volatile

```java
private volatile boolean running = true;

public void stop() {
    running = false; // 對其他 thread 立即可見
}

public void run() {
    while (running) {
        doWork();
    }
}
```

稽核要點：
- `volatile` 保證可見性——但不保證原子性（`volatile int count; count++` 不是原子的）
- `volatile` 建立 happens-before 關係——寫入 volatile 之前的所有操作對讀取 volatile 之後的操作可見
- Java Memory Model 中，非 volatile 變數的修改不保證跨 thread 可見

### Thread / ExecutorService

```java
ExecutorService executor = Executors.newFixedThreadPool(10);

Future<String> future = executor.submit(() -> {
    return fetchData();
});

String result = future.get(5, TimeUnit.SECONDS);

executor.shutdown();
executor.awaitTermination(30, TimeUnit.SECONDS);
```

稽核要點：
- `Executors.newCachedThreadPool()` 無限建立 thread——高併發下可能耗盡系統資源
- `future.get()` 阻塞當前 thread——在 Android UI thread 使用會導致 ANR
- `shutdown()` 不接受新任務但完成已提交的——`shutdownNow()` 嘗試中斷所有任務
- `ThreadPoolExecutor` 的拒絕策略（`AbortPolicy` 等）是合約——預設拋 `RejectedExecutionException`

### Virtual Threads (Java 21+)

```java
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    executor.submit(() -> handleRequest(request));
}

Thread.startVirtualThread(() -> {
    // 每個 virtual thread 是一個輕量級任務
    var result = blockingIO(); // 不會阻塞 OS thread
});
```

稽核要點：
- Virtual thread 在阻塞 I/O 時自動讓出 carrier thread——但 `synchronized` block 會 pin carrier thread
- `synchronized` 應替換為 `ReentrantLock`——避免 carrier thread pinning
- Virtual thread 不適合 CPU 密集型任務——沒有 preemption
- `ThreadLocal` 在 virtual thread 中代價高——每個 virtual thread 都有自己的副本

---

## 3. 生命週期模式

### try-with-resources (AutoCloseable)

```java
try (var conn = dataSource.getConnection();
     var stmt = conn.prepareStatement(sql);
     var rs = stmt.executeQuery()) {
    while (rs.next()) {
        process(rs);
    }
} // conn, stmt, rs 按反向順序自動 close
```

稽核要點：
- `AutoCloseable.close()` 在 `try` block 結束時自動呼叫——包括例外路徑
- close 順序是宣告的反向（LIFO）——同 Go 的 defer
- `close()` 中拋出的例外作為 suppressed exception 附加——不會覆蓋原始例外
- 不使用 try-with-resources 是 Java 最常見的資源洩漏來源

### Spring Bean Lifecycle

```java
@Component
public class CacheManager implements InitializingBean, DisposableBean {

    @PostConstruct
    public void init() {
        // Bean 初始化後呼叫
    }

    @Override
    public void afterPropertiesSet() {
        // 所有 property 設定完成後呼叫
    }

    @PreDestroy
    public void cleanup() {
        // ApplicationContext 關閉時呼叫
    }

    @Override
    public void destroy() {
        // 同 @PreDestroy，interface 方式
    }
}
```

稽核要點：
- 初始化順序：Constructor → `@Autowired` setter → `@PostConstruct` → `afterPropertiesSet`
- `@PreDestroy` 只在正常 shutdown 時呼叫——`kill -9` 不觸發
- `@Scope("prototype")` 的 Bean 不觸發 `@PreDestroy`——Spring 不管理 prototype Bean 的銷毀
- `@Lazy` 延遲初始化——首次使用時才建立，可能在非預期的時間點觸發副作用

### Android Activity Lifecycle

```
onCreate() → onStart() → onResume() → onPause() → onStop() → onDestroy()
```

稽核要點：
- `onCreate(Bundle)` 的 Bundle 可能為 null（首次啟動）或非 null（恢復）
- Configuration change（螢幕旋轉）觸發完整的 destroy-recreate 週期
- `onDestroy` 不保證被呼叫（系統直接殺死 process）
- `onSaveInstanceState` 的 Bundle 大小有限（~500KB）——超過會 `TransactionTooLargeException`
- Android 的生命週期合約與 Kotlin 完全相同——參見 kotlin.md §3

### Servlet Lifecycle (Jakarta EE)

```java
@WebServlet("/api/users")
public class UserServlet extends HttpServlet {

    @Override
    public void init(ServletConfig config) {
        // 一次性初始化
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) {
        // 每次 request 呼叫——多 thread 同時執行
    }

    @Override
    public void destroy() {
        // Container 關閉時呼叫
    }
}
```

稽核要點：
- Servlet 是 singleton——`doGet`/`doPost` 被多個 thread 同時呼叫
- Servlet 的 instance variable 是共享狀態——必須 thread-safe
- `init()` 只呼叫一次——`destroy()` 只呼叫一次
- `HttpSession` 有 timeout——過期後存取拋 `IllegalStateException`

### finalize() (已棄用)

```java
@Override
protected void finalize() throws Throwable {
    try {
        closeResource();
    } finally {
        super.finalize();
    }
}
```

稽核要點：
- `finalize()` 在 Java 9 中被棄用，Java 18 中被標記為 `forRemoval`
- GC 不保證何時（甚至是否）呼叫 `finalize()`——不能依賴它做資源釋放
- `finalize()` 中的例外會被靜默忽略
- 應改用 `AutoCloseable` + try-with-resources 或 `Cleaner`（Java 9+）

---

## 4. 驗證策略

**ast-grep: 完整支援。**

Java 是 ast-grep 的支援語言。所有合約應優先使用 ast-grep 規則驗證。

### ast-grep 規則撰寫指南

```yaml
id: s1-synchronized-in-virtual-thread
message: "S1: synchronized block may pin virtual thread carrier"
severity: warning
language: Java
rule:
  pattern: |
    synchronized ($LOCK) { $$$ }
```

**Pattern 注意事項：**
- Java 的 annotation 語法：`@Override`、`@Autowired` 是獨立的 AST 節點
- Generic type（`List<String>`）在 AST 中有獨立的 type argument 節點
- Lambda expression vs anonymous class 是不同的 AST 結構
- try-with-resources 有獨立的 resource specification AST 節點

### grep 作為補充

```bash
# 檢查 synchronized 使用
grep -n 'synchronized' "$file"

# 檢查 volatile 使用
grep -n 'volatile\s' "$file"

# 檢查 finalize 使用（已棄用）
grep -n 'void finalize' "$file"

# 檢查 Thread.sleep 在 synchronized 中（死鎖風險）
grep -n 'Thread\.sleep' "$file"

# 檢查 Executors.newCachedThreadPool（無界 thread pool）
grep -n 'newCachedThreadPool\|newFixedThreadPool' "$file"
```

---

## 5. Effect 防火牆

**強度：中。**

Java 提供多種不可變性機制，但不如 Rust 的編譯時保證嚴格。

### final 關鍵字

```java
final int x = 42;          // 不可重新賦值
final List<String> list = new ArrayList<>(); // reference 不可變，內容可變！
list.add("hello");         // 合法
```

- `final` 只保護 reference——不保護物件內容（同 JavaScript 的 `const`）
- `final` field 在建構子結束前必須初始化——是 JMM 的 safe publication 保證
- `final` 方法不可 override——`final` class 不可繼承

### Immutable Collections (Java 9+)

```java
List<String> immutable = List.of("a", "b", "c");
immutable.add("d"); // UnsupportedOperationException!

Map<String, Integer> map = Map.of("key", 1);
```

- `List.of` / `Map.of` / `Set.of` 建立真正不可變的集合
- `Collections.unmodifiableList` 是 view——原始集合修改仍會反映
- 不可變集合不允許 `null` 元素——`List.of(null)` 拋 `NullPointerException`

### Record (Java 16+)

```java
public record User(String name, int age) {
    // 自動生成 constructor, equals, hashCode, toString
    // 所有 field 隱含 final
}
```

- Record 的 field 都是 `final`——但 mutable field（如 `List`）的內容仍可修改
- Record 自動生成 `equals`/`hashCode`/`toString`——同 Kotlin 的 `data class`
- Record 不可繼承——是 implicitly `final`

### sealed class (Java 17+)

```java
public sealed interface Shape
    permits Circle, Rectangle, Triangle {
}

public record Circle(double radius) implements Shape {}
public record Rectangle(double w, double h) implements Shape {}
```

- `sealed` 限制子型別——`permits` 列出所有允許的實作
- pattern matching `switch`（Java 21+）可以窮舉 sealed type——類似 Kotlin 的 `sealed class`
- 新增子型別需要修改 `permits` 列表——編譯時強制

**稽核影響：**
- `final` + immutable collection 可以信任不可變性——但需要確認是 `List.of` 不是 `Collections.unmodifiableList`
- Record 的淺層不可變需要注意——mutable field 的內容仍可修改
- `sealed` 類型的 exhaustive switch 是編譯器強制的合約（Java 21+）

---

## 6. Seam 類型

### Object Seam（Interface / Abstract Class）

```java
public interface UserRepository {
    Optional<User> findById(String id);
    void save(User user);
}

@Repository
public class JpaUserRepository implements UserRepository {
    @PersistenceContext
    private EntityManager em;

    @Override
    public Optional<User> findById(String id) {
        return Optional.ofNullable(em.find(User.class, id));
    }
}
```

- Java interface 可以有 `default` method（Java 8+）——default method 是隱含合約
- Spring 的 `@Autowired` 根據 type 注入——多個實作需要 `@Qualifier` 區分
- `@Primary` 標記預設實作——是隱含的綁定合約

### Preprocessing Seam

```java
// Spring Profile
@Profile("production")
@Configuration
public class ProdConfig {
    @Bean
    public DataSource dataSource() { /* ... */ }
}

// System Property / Environment Variable
String env = System.getProperty("app.env", "dev");
if ("production".equals(env)) {
    enableProductionMode();
}
```

- `@Profile` 在啟動時決定——不同 profile 載入不同的 Bean 組合
- `System.getProperty` 和 `System.getenv` 是 runtime 的 Preprocessing Seam
- `@ConditionalOnProperty` / `@ConditionalOnClass` 是 Spring Boot 的條件組裝

### Link Seam

```java
// ServiceLoader (SPI)
ServiceLoader<Plugin> plugins = ServiceLoader.load(Plugin.class);
for (Plugin p : plugins) {
    p.initialize();
}

// Spring Component Scan
@ComponentScan("com.app")
// 自動發現並注入所有 @Component/@Service/@Repository

// Reflection
Class<?> clazz = Class.forName("com.app.DynamicHandler");
Object instance = clazz.getDeclaredConstructor().newInstance();
```

- `ServiceLoader` 從 `META-INF/services/` 載入實作——是 Java 標準的 plugin 機制
- Spring `@ComponentScan` 在啟動時掃描 classpath——掃描範圍是合約
- `Class.forName` 是 runtime 動態載入——class 不存在時拋 `ClassNotFoundException`
- Reflection 繞過存取控制——`setAccessible(true)` 可以存取 private field

---

## 7. Sprout/Wrap 策略

### Sprout Method

```java
// Before
public Receipt processOrder(Order order) {
    // 200 lines of mixed validation + processing
}

// After
public Receipt processOrder(Order order) {
    ValidatedOrder validated = validateOrder(order);
    return processValidated(validated);
}

// Sprouted — independently testable
private ValidatedOrder validateOrder(Order order) {
    Objects.requireNonNull(order, "Order must not be null");
    if (order.getItems().isEmpty()) {
        throw new IllegalArgumentException("Order must have items");
    }
    return new ValidatedOrder(order);
}
```

**Java 優勢：** `Objects.requireNonNull` 和 checked exception 讓前置條件檢查成為 API 合約的一部分。

### Wrap via Decorator

```java
public class LoggingRepository implements UserRepository {
    private final UserRepository delegate;
    private final Logger log;

    public LoggingRepository(UserRepository delegate) {
        this.delegate = delegate;
        this.log = LoggerFactory.getLogger(getClass());
    }

    @Override
    public Optional<User> findById(String id) {
        log.debug("findById({})", id);
        Optional<User> result = delegate.findById(id);
        log.debug("findById({}) -> {}", id, result);
        return result;
    }
}
```

**Java 優勢：** Interface-based Decorator 是 GoF 設計模式的經典實作——Spring 的 AOP 自動生成類似的 proxy。

### Wrap via AOP (Spring)

```java
@Aspect
@Component
public class LoggingAspect {

    @Around("execution(* com.app.service.*.*(..))")
    public Object logMethod(ProceedingJoinPoint joinPoint) throws Throwable {
        log.info("Entering {}", joinPoint.getSignature());
        Object result = joinPoint.proceed();
        log.info("Exiting {}", joinPoint.getSignature());
        return result;
    }
}
```

**Java 優勢：** AOP 是 Java 獨有的橫切關注點 Wrap 機制——不修改原始程式碼即可加入 logging、transaction、security。

### Wrap via Proxy (java.lang.reflect.Proxy)

```java
UserRepository proxy = (UserRepository) Proxy.newProxyInstance(
    UserRepository.class.getClassLoader(),
    new Class[]{UserRepository.class},
    (proxyObj, method, args) -> {
        log.info("Calling {}", method.getName());
        return method.invoke(realRepo, args);
    }
);
```

**Java 優勢：** Dynamic Proxy 可以在 runtime 為任意 interface 建立 Wrap——Spring AOP 的底層機制。

---

## 8. 常見隱含合約範例

### 8.1 equals / hashCode 一致性

```java
public class User {
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof User user)) return false;
        return Objects.equals(id, user.id);
    }

    // 忘記 override hashCode！
    // HashMap/HashSet 行為不正確
}
```

**重構風險：** 修改 `equals` 而不更新 `hashCode` 會破壞所有使用 `HashMap`/`HashSet` 的程式碼——物件可能在 `HashSet` 中「消失」。

### 8.2 Checked vs Unchecked Exception

```java
// Checked exception — caller 必須處理
public User getUser(String id) throws UserNotFoundException {
    // ...
}

// Unchecked exception — caller 不被強制處理
public User getUser(String id) {
    throw new IllegalArgumentException("Invalid id");
}
```

**重構風險：** 將 checked exception 改為 unchecked（或反向）改變了所有 caller 的錯誤處理合約——checked → unchecked 可能導致錯誤未處理；unchecked → checked 會導致編譯錯誤。

### 8.3 null 回傳合約

```java
// 回傳 null 表示「不存在」
public User findUser(String id) {
    return userMap.get(id); // 可能回傳 null
}

// 回傳 Optional 表示「可能不存在」
public Optional<User> findUser(String id) {
    return Optional.ofNullable(userMap.get(id));
}
```

**重構風險：** 將 nullable 回傳改為 `Optional` 破壞所有 caller 的 null check——`if (user != null)` 需要改為 `user.ifPresent()`。

### 8.4 Iterator ConcurrentModification

```java
List<String> list = new ArrayList<>(Arrays.asList("a", "b", "c"));
for (String s : list) {
    if (s.equals("b")) {
        list.remove(s); // ConcurrentModificationException!
    }
}
```

**重構風險：** 將 `CopyOnWriteArrayList`（thread-safe，允許 iteration 中修改）改為 `ArrayList` 會引入 `ConcurrentModificationException`。

### 8.5 Autoboxing / Unboxing

```java
Integer a = 127;
Integer b = 127;
a == b;  // true（IntegerCache 範圍 -128 到 127）

Integer c = 128;
Integer d = 128;
c == d;  // false!
```

**重構風險：** 將 `int` 改為 `Integer`（或反向）改變了 `==` 的語義——`Integer == Integer` 比較 reference，`int == int` 比較值。`Integer` 可以是 `null`——unboxing null 拋 `NullPointerException`。

### 8.6 Spring @Transactional 語義

```java
@Service
public class OrderService {
    @Transactional
    public void placeOrder(Order order) {
        save(order);
        sendNotification(order); // 如果失敗，order 也 rollback
    }

    // 同一 class 內呼叫——@Transactional 不生效！
    @Transactional(propagation = REQUIRES_NEW)
    public void sendNotification(Order order) {
        // 因為 Spring AOP 基於 proxy，self-invocation 繞過 proxy
    }
}
```

**重構風險：** `@Transactional` 只在透過 proxy 呼叫時生效——同一 class 內的方法呼叫不經過 proxy，`@Transactional` 被靜默忽略。

### 8.7 Stream 只能消費一次

```java
Stream<String> stream = list.stream().filter(s -> s.length() > 3);
stream.forEach(System.out::println);
stream.forEach(System.out::println); // IllegalStateException!
```

**重構風險：** 將 `List` 操作改為 `Stream` 後，重複使用 stream 會拋例外——Stream 是一次性的。

### 8.8 Serializable 合約

```java
public class User implements Serializable {
    private static final long serialVersionUID = 1L;
    private String name;
    private transient Connection conn; // 不序列化
}
```

**重構風險：** 新增/移除 field 會改變 serialization 格式——如果 `serialVersionUID` 不變，反序列化舊資料可能靜默丟失 field 或使用預設值。修改 `serialVersionUID` 會使所有舊序列化資料無法讀取。

---

## 9. Java-Kotlin 互操作合約

此節與 kotlin.md §9 互為鏡像——從 Java 端的視角描述互操作風險。

### Nullability 邊界

```java
// Java 方法（無 @Nullable/@NonNull annotation）
public String getName() { return name; }

// Kotlin 側看到 String!（platform type）
// val name: String = obj.name   -> 如果 Java 回傳 null，NPE
// val name: String? = obj.name  -> 安全
```

稽核要點：
- 為 Java API 加上 `@Nullable` / `@NonNull` annotation 是最高 ROI 的合約聲明——影響所有 Kotlin 消費者
- `@ParametersAreNonnullByDefault`（JSR-305）可以設定 package-level 預設
- Spring Framework 從 5.0 起全面使用 `@Nullable`——遵循此慣例

### Collection Mutability

```java
// Java 的 List<String> 在 Kotlin 側是 MutableList<String>!（platform type）
// Kotlin 可以 cast 為 List<String>（不可變）或 MutableList<String>（可變）
// 如果 Java 端期望 List 不被修改，但 Kotlin 端 cast 為 MutableList 並修改——行為未定義
```

### SAM Conversion

```java
// Java functional interface
@FunctionalInterface
public interface Callback<T> {
    void onResult(T result);
}

// Kotlin 側可以用 lambda
service.register { result -> handleResult(result) }
// 但每次呼叫都建立新實例——如果需要 remove，必須保留 reference
```
