## Caller Interface Extract（Step 0.9）

外部模組引用 NYHTTPSClient 的片段（±5 行上下文）：

### NYLoginHelper.m (1 references)
```
9-#import "NYLoginHelper.h"
10-
11-// FIXME: UI dependency
12-#import "NYCookieManager.h"
13-#import "NYFacebookHelper.h"
14:#import "NYHTTPSClient.h"
15-#import "NYDataProvider+Login.h"
16-#import "NYDataProvider+MemberCenter.h"
17-#import "NYUserDefaultsHelper.h"
18-#import "NYGlobalData.h"
19-#import "NYUserDefault.h"
```

