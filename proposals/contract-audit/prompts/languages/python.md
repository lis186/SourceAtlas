# Language Plugin: Python
# Contract Audit 語言插件 -- Python / asyncio / Common Frameworks
# Version: 1.0

---

## 適用範圍

- 純 Python 模組（`.py`）
- Web 框架（Django, Flask, FastAPI, Starlette）
- 非同步框架（asyncio, Trio, AnyIO）
- CLI 工具（Click, Typer, argparse）
- 資料處理（pandas, SQLAlchemy）
- C Extension 混合模組中的 Python 部分

---

## 1. 通知/事件原語

### Signal (標準庫)

```python
import signal

def handler(signum, frame):
    print(f"Received signal {signum}")
    cleanup()

signal.signal(signal.SIGINT, handler)
signal.signal(signal.SIGTERM, handler)
```

稽核要點：
- `signal.signal` 替換前一個 handler——是 replace 語義，不是 add
- signal handler 只能在主執行緒中設定——子執行緒呼叫會拋 `ValueError`
- handler 中只能呼叫 async-signal-safe 函式——在 handler 中取得鎖可能死鎖
- `signal.alarm` 在 Windows 上不可用

### Callback / Observer

```python
class EventEmitter:
    def __init__(self):
        self._listeners = defaultdict(list)

    def on(self, event: str, callback: Callable):
        self._listeners[event].append(callback)

    def emit(self, event: str, *args, **kwargs):
        for cb in self._listeners[event]:
            cb(*args, **kwargs)
```

稽核要點：
- Python 沒有內建的 EventEmitter——各框架自行實作，API 不統一
- callback 持有外部物件的 reference——如果 callback 未移除，物件無法被 GC
- `weakref.WeakMethod` 可避免 callback 造成的 reference cycle
- `functools.partial` 包裝的 callback 比對困難——移除時需要保留原始 reference

### Queue (threading / multiprocessing)

```python
from queue import Queue, Empty
import asyncio

# threading Queue
q = Queue(maxsize=100)
q.put(item)           # 阻塞直到有空間
item = q.get()         # 阻塞直到有項目
q.task_done()          # 配合 q.join() 使用

# asyncio Queue
aq = asyncio.Queue(maxsize=100)
await aq.put(item)
item = await aq.get()
```

稽核要點：
- `queue.Queue` 是 thread-safe——但不能在 asyncio 中使用（會阻塞 event loop）
- `asyncio.Queue` 只能在同一 event loop 中使用——跨 thread 需要 `loop.call_soon_threadsafe`
- `q.get(timeout=N)` 超時拋 `Empty`——不檢查會導致未處理例外
- `q.task_done()` 和 `q.join()` 必須配對——不呼叫 `task_done` 會導致 `join` 永久阻塞

### asyncio Event / Condition

```python
event = asyncio.Event()

# 等待端
await event.wait()

# 通知端
event.set()
event.clear()  # 重置
```

稽核要點：
- `Event.set()` 喚醒所有 waiter——是廣播語義
- `Event.clear()` 後新的 `wait()` 會再次阻塞——但已被喚醒的 coroutine 不受影響
- `Condition` 需要在 `async with` 中使用——忘記 acquire 鎖會拋 `RuntimeError`

---

## 2. 同步原語

### GIL (Global Interpreter Lock)

稽核要點：
- CPython 的 GIL 保證同一時間只有一個 thread 執行 Python bytecode——這是隱含合約
- GIL 不保護跨多個 bytecode 操作的原子性——`list.append` 是原子的，但 `counter += 1` 不是
- I/O 操作（network, file）會釋放 GIL——I/O 密集型任務仍受益於多執行緒
- C extension 可以手動釋放 GIL（`Py_BEGIN_ALLOW_THREADS`）——此時 Python 物件存取不安全
- Python 3.13+ 有實驗性的 free-threaded 模式——移除 GIL 後所有隱含的 thread-safety 假設都失效

### threading

```python
import threading

lock = threading.Lock()
with lock:
    # critical section
    pass

rlock = threading.RLock()  # 可重入鎖

t = threading.Thread(target=worker, args=(data,), daemon=True)
t.start()
t.join(timeout=5)
```

稽核要點：
- `Lock` 不可重入——同一 thread 重複 acquire 會死鎖
- `RLock` 可重入——但 release 次數必須等於 acquire 次數
- `daemon=True` 的 thread 在主程式退出時被強制終止——不執行 cleanup
- `t.join(timeout)` 超時後 thread 仍在執行——Python 無法強制終止 thread
- `threading.local()` 提供 thread-local storage——但在 asyncio 中不可用（多個 coroutine 共享同一 thread）

### asyncio

```python
import asyncio

async def main():
    task1 = asyncio.create_task(fetch_user())
    task2 = asyncio.create_task(fetch_orders())
    user, orders = await asyncio.gather(task1, task2)

asyncio.run(main())
```

稽核要點：
- `asyncio.run()` 建立新 event loop——不能在已有 event loop 的 context 中呼叫（如 Jupyter notebook）
- `create_task` 必須在 running event loop 中呼叫——在 loop 外呼叫會拋 `RuntimeError`
- `gather` 預設 `return_exceptions=False`——任一 task 失敗會取消其他所有 task
- `gather` 的 `return_exceptions=True`——例外作為 result 回傳，不會中斷其他 task
- 未 await 的 `create_task` 結果——task 的例外會被靜默丟棄（只有一條 warning log）
- `asyncio.to_thread` 將同步函式放到 thread pool——但 GIL 仍然存在
- `asyncio.wait_for(coro, timeout)` 超時時取消 coroutine——被取消的 coroutine 收到 `CancelledError`

### multiprocessing

```python
from multiprocessing import Process, Pool, Manager

def worker(shared_dict, key, value):
    shared_dict[key] = value

manager = Manager()
d = manager.dict()
p = Process(target=worker, args=(d, "key", "value"))
p.start()
p.join()
```

稽核要點：
- 跨 process 的物件必須 pickle-able——lambda、closure、某些 C extension 物件無法序列化
- `Manager` 提供跨 process 的共享狀態——但效能遠低於 thread-safe 資料結構
- `Pool.map` 中 worker 的例外會在 `get()` 時重新拋出——但 traceback 會丟失
- `daemon=True` 的子 process 在父 process 結束時被強制終止

---

## 3. 生命週期模式

### Context Manager

```python
class DatabaseConnection:
    def __enter__(self):
        self.conn = create_connection()
        return self.conn

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.conn.close()
        return False  # 不吞掉例外

# 使用
with DatabaseConnection() as conn:
    conn.execute("SELECT 1")
```

稽核要點：
- `__exit__` 回傳 `True` 會吞掉例外——這是非常隱蔽的合約
- `__exit__` 在例外發生時也會被呼叫——確保資源釋放
- `contextlib.contextmanager` 用 generator 實作——`yield` 之後的程式碼就是 cleanup
- `contextlib.asynccontextmanager` 用於 async context manager
- 巢狀 context manager 的 `__exit__` 按 LIFO 順序執行

### `__del__` 與 Finalizer

```python
class Resource:
    def __del__(self):
        self.cleanup()  # 不保證被呼叫！
```

稽核要點：
- `__del__` 不保證在物件不可達時立即呼叫——依賴 GC 策略
- `__del__` 中拋出的例外會被靜默忽略（只印 stderr warning）
- Reference cycle 中的物件，`__del__` 可能永遠不被呼叫
- 應使用 context manager 或 `weakref.finalize` 替代 `__del__`

### atexit

```python
import atexit

def cleanup():
    close_connections()
    flush_logs()

atexit.register(cleanup)
```

稽核要點：
- `atexit` handler 在正常退出時執行——`os._exit()` 或信號殺死不會觸發
- handler 按 LIFO 順序執行
- handler 中的例外會被印出但不會阻止其他 handler 執行

### Flask / Django Request Lifecycle

```python
# Flask
@app.before_request
def before():
    g.start_time = time.time()

@app.after_request
def after(response):
    duration = time.time() - g.start_time
    return response

@app.teardown_request
def teardown(exception):
    db.session.remove()

# Django Middleware
class TimingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        start = time.time()
        response = self.get_response(request)
        # after response
        return response
```

稽核要點：
- Flask `g` 是 request-scoped——每個 request 獨立，但同一 request 中所有函式共享
- `teardown_request` 即使在例外時也會執行——類似 `finally`
- Django middleware 順序影響行為——request 階段正向、response 階段反向
- `MIDDLEWARE` 設定中的順序是合約——例如 `AuthMiddleware` 必須在 `SessionMiddleware` 之後

### FastAPI / Starlette Lifespan

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app):
    # startup
    db = await create_db_pool()
    yield {"db": db}
    # shutdown
    await db.close()

app = FastAPI(lifespan=lifespan)
```

稽核要點：
- `yield` 之前是 startup，之後是 shutdown——這是 context manager 的合約
- lifespan state 透過 `request.state` 傳遞——是隱含依賴

---

## 4. 驗證策略

**ast-grep: 完整支援。**

Python 是 ast-grep 的支援語言。所有合約應優先使用 ast-grep 規則驗證。

### ast-grep 規則撰寫指南

```yaml
id: s1-asyncio-run-nested
message: "S1: asyncio.run() called inside running event loop"
severity: error
language: Python
rule:
  pattern: |
    asyncio.run($CORO)
```

**Pattern 注意事項：**
- Python 的 decorator 語法：`@decorator` 是獨立的 AST 節點
- `with` statement 的 pattern matching 需要注意 `as` clause
- `async def` vs `def` 是不同的 AST 節點類型
- f-string 內的表達式在 AST 中獨立存在

### grep 作為補充

```bash
# 檢查 GIL 相關的 thread-safety 假設
grep -n 'threading\.Thread\|threading\.Lock' "$file"

# 檢查 asyncio 使用
grep -n 'asyncio\.run\|create_task\|await ' "$file"

# 檢查 __del__ 使用（通常應避免）
grep -n 'def __del__' "$file"

# 檢查 bare except
grep -n 'except:' "$file"
```

---

## 5. Effect 防火牆

**強度：弱。**

Python 缺乏語言級不可變性保證，但提供慣例和工具。

### tuple / frozenset

```python
point = (1, 2)          # immutable
colors = frozenset({"red", "blue"})  # immutable set
```

- `tuple` 本身不可變，但包含的 mutable 物件仍可修改：`t = ([1, 2],); t[0].append(3)`
- `frozenset` 是真正不可變的——可以作為 dict key 或 set 成員

### dataclass(frozen=True)

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Point:
    x: float
    y: float
```

- `frozen=True` 使 instance attribute 不可重新賦值——但 mutable attribute（如 `list`）的內容仍可修改
- `frozen=True` 自動生成 `__hash__`——使 dataclass 可作為 dict key

### NamedTuple

```python
from typing import NamedTuple

class Point(NamedTuple):
    x: float
    y: float
```

- `NamedTuple` 繼承 `tuple`——不可變
- 可以用 `._replace()` 建立新實例——不修改原始物件

### Property / Descriptor

```python
class User:
    def __init__(self, name: str):
        self._name = name

    @property
    def name(self) -> str:
        return self._name
```

- `_name` 前綴是慣例——不是強制，外部仍可存取
- `__name` 前綴觸發 name mangling——增加存取難度但不是真正的 private
- `@property` 沒有 setter 時，賦值會拋 `AttributeError`

**稽核影響：**
- Python 的不可變性依賴慣例而非編譯器——`_` 前綴只是約定
- `frozen=True` 和 `NamedTuple` 是最接近真正不可變的機制
- 任何物件都能被 `object.__setattr__` 繞過——不可變性在 Python 中不是絕對的

---

## 6. Seam 類型

### Object Seam（ABC / Protocol）

```python
from abc import ABC, abstractmethod
from typing import Protocol

# ABC 方式（顯式繼承）
class Repository(ABC):
    @abstractmethod
    def get(self, id: str) -> dict:
        ...

# Protocol 方式（結構化子型別，類似 Go interface）
class Loggable(Protocol):
    def log(self, message: str) -> None:
        ...
```

- `ABC` 是名義子型別——必須顯式繼承
- `Protocol` 是結構化子型別（Python 3.8+）——滿足方法簽名即可，不需繼承
- `@abstractmethod` 未實作時 instantiation 會拋 `TypeError`
- `Protocol` 的 `runtime_checkable` 裝飾器允許 `isinstance` 檢查——但只檢查方法是否存在，不檢查簽名

### Preprocessing Seam

```python
# 條件匯入
try:
    import ujson as json
except ImportError:
    import json

# 環境變數
import os
DEBUG = os.environ.get("DEBUG", "false").lower() == "true"
if DEBUG:
    enable_debug_logging()

# __name__ guard
if __name__ == "__main__":
    main()
```

- 條件匯入是 Python 最常見的 Preprocessing Seam——`try/except ImportError` 模式
- 環境變數在 module import 時讀取——後續變更不影響已讀取的值
- `__name__ == "__main__"` 區分 script 執行和 import——是 Python 的基本合約

### Link Seam

```python
import importlib

# 動態載入
module = importlib.import_module("plugins.auth")
handler = getattr(module, "AuthHandler")

# Entry points (setuptools)
from importlib.metadata import entry_points
eps = entry_points(group="myapp.plugins")

# Monkey patching
import unittest.mock
with unittest.mock.patch("mymodule.external_api", return_value=mock_data):
    result = my_function()
```

- `importlib.import_module` 是動態 Link Seam——import 路徑可以是變數
- `entry_points` 是 plugin 發現機制——package 在 `setup.cfg`/`pyproject.toml` 中註冊
- `mock.patch` 在測試中替換模組屬性——是暫時性的 Link Seam
- `setattr(module, "func", replacement)` 是永久性的 monkey patch——影響所有使用該 module 的程式碼

---

## 7. Sprout/Wrap 策略

### Sprout Function

```python
# Before
def process_order(order: dict) -> dict:
    # 200 lines of mixed validation + processing
    pass

# After
def process_order(order: dict) -> dict:
    validated = validate_order(order)
    return _process_validated(validated)

# Sprouted — independently testable
def validate_order(order: dict) -> dict:
    if not order.get("items"):
        raise ValueError("Order must have items")
    if order.get("total", 0) <= 0:
        raise ValueError(f"Invalid total: {order['total']}")
    return order
```

**Python 優勢：** duck typing 讓 sprout function 不需要嚴格的型別宣告——但 type hints 大幅提升可讀性。

### Wrap via Decorator

```python
import functools
import time

def timing(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        print(f"{func.__name__} took {time.time() - start:.3f}s")
        return result
    return wrapper

@timing
def slow_function():
    time.sleep(1)
```

**Python 優勢：** Decorator 是 Python 最自然的 Wrap 機制——`@` 語法讓 wrapping 幾乎零摩擦。`functools.wraps` 保留原始函式的 metadata。

### Wrap via Context Manager

```python
from contextlib import contextmanager

@contextmanager
def transaction(conn):
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
```

**Python 優勢：** `contextlib.contextmanager` 用 generator 實作 Wrap——`yield` 前是 setup，`yield` 後是 teardown。

### Wrap via Middleware (ASGI / WSGI)

```python
class LoggingMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        start = time.time()
        await self.app(scope, receive, send)
        duration = time.time() - start
        logger.info(f"{scope['path']} took {duration:.3f}s")

app = LoggingMiddleware(app)
```

**Python 優勢：** ASGI/WSGI middleware 是洋蔥模型——每層只負責一個 concern。

---

## 8. 常見隱含合約範例

### 8.1 Mutable Default Argument

```python
def append_to(item, target=[]):  # 危險！
    target.append(item)
    return target

append_to(1)  # [1]
append_to(2)  # [1, 2] — 不是 [2]！
```

**重構風險：** 將 `None` 改為 mutable default（或反向）會改變所有 caller 的行為——default argument 在函式定義時求值一次，不是每次呼叫。

### 8.2 Late Binding Closure

```python
functions = [lambda: i for i in range(5)]
[f() for f in functions]  # [4, 4, 4, 4, 4] — 不是 [0, 1, 2, 3, 4]！

# 修正
functions = [lambda i=i: i for i in range(5)]
```

**重構風險：** 迴圈中建立的 closure 共享同一個迴圈變數——所有 closure 引用最終值。

### 8.3 `is` vs `==`

```python
a = 256
b = 256
a is b  # True（CPython 快取 -5 到 256 的整數）

a = 257
b = 257
a is b  # False（超出快取範圍）
```

**重構風險：** 將 `==` 改為 `is` 或反向，在小整數和 interned 字串上可能不會被測試發現，但在生產環境中失敗。

### 8.4 Exception Chaining

```python
try:
    fetch_data()
except ConnectionError as e:
    raise ValueError("bad data") from e   # 保留 chain
    raise ValueError("bad data")          # 隱式 chain (__context__)
    raise ValueError("bad data") from None # 切斷 chain
```

**重構風險：** `from e` vs 不加 vs `from None` 改變了 traceback 的呈現和 `__cause__` / `__context__` 屬性——影響上游的錯誤處理邏輯。

### 8.5 `__slots__`

```python
class Point:
    __slots__ = ('x', 'y')

    def __init__(self, x, y):
        self.x = x
        self.y = y

p = Point(1, 2)
p.z = 3  # AttributeError!
```

**重構風險：** 移除 `__slots__` 允許動態添加任意屬性——可能破壞依賴「屬性集合固定」的程式碼。新增 `__slots__` 可能破壞使用 `__dict__` 的序列化邏輯。

### 8.6 Generator 只能迭代一次

```python
gen = (x * 2 for x in range(5))
list(gen)  # [0, 2, 4, 6, 8]
list(gen)  # [] — 已耗盡！
```

**重構風險：** 將 `list` 改為 generator expression（節省記憶體）可能導致第二次迭代得到空結果。

### 8.7 `import` 副作用

```python
# module_a.py
print("module_a loaded")  # import 時執行
registry = {}

def register(name):
    def decorator(cls):
        registry[name] = cls
        return cls
    return decorator
```

**重構風險：** 調整 import 順序或延遲 import 可能改變 registry 的填充時機——如果其他模組在 import 時讀取 registry，可能得到不完整的結果。

### 8.8 `__eq__` 與 `__hash__` 的一致性

```python
class User:
    def __eq__(self, other):
        return self.id == other.id
    # 忘記定義 __hash__！

users = {User(1), User(2)}  # TypeError: unhashable type
```

**重構風險：** 定義 `__eq__` 會自動使 `__hash__` 變為 `None`——物件無法放入 `set` 或作為 `dict` key。

---

## 9. C Extension 互操作合約

```python
# ctypes
from ctypes import cdll, c_char_p
lib = cdll.LoadLibrary("libfoo.so")
lib.greet.restype = c_char_p
result = lib.greet(b"hello")  # 必須手動管理記憶體

# Cython / pybind11 / CFFI
# 自動處理大部分記憶體管理，但仍有陷阱
```

稽核要點：
- `ctypes` 不做型別檢查——傳錯型別會導致 segfault，不是 Python exception
- C extension 中 `Py_INCREF` / `Py_DECREF` 必須配對——錯誤會導致 memory leak 或 use-after-free
- GIL 在 C extension 中可以手動釋放——釋放期間不能存取 Python 物件
- `numpy` array 可以透過 buffer protocol 零拷貝共享——但修改 shared buffer 影響所有 view
