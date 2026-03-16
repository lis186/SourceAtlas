## Artifact 4（續）: Line Attribution Table — NYHTTPSClient.m（行 246–769）

| Lines | Label | Contract(s) / Note |
|-------|-------|--------------------|
| 247-256 | CONTRACT | **M-017** (AnyPromise postPath 2-param): PMKManifold wraps `responseObject`; delegates to syncPostPath → S-001 semaphore path |
| 258-266 | CONTRACT | **B3** (AnyPromise postPath 4-param): `resolve(PMKManifold(responseType, ...))` — resolves enum instead of `responseObject`. **Bug confirmed.** |
| 268-273 | INFRA | Convenience wrapper: postPath 4-param → postPath 6-param with default JSON/JSON types |
| 275-282 | INFRA | postPath 6-param → delegates to `addOperationWithRequestType` 8-param (no requestTimeout) |
| 284-299 | INFRA | postPath 7-param (with requestTimeout) → delegates to `addOperationWithRequestType` 9-param |
| 301-355 | CONTRACT | **E-001** (Encrypted POST — registerAPP): AES-CBC encrypt → HMAC-SHA512 sign → conditional sync/async dispatch. **C-001** (AES key derivation), **C-002** (HMAC signing). Hardcoded `kSalt`, `kHMAC_SHA512`. |
| 357-410 | CONTRACT | **E-002** (Encrypted response — MemberCard): POST → AES-CBC decrypt response → HMAC-SHA512 verify signature → JSON deserialize. **C-001** (AES key), **C-003** (HMAC verify), **C-004** (response decryption). |
| 412-441 | CONTRACT | **E-003** (eCoupon signed GET): HMAC-SHA512 signs `eCouponGiftId` → POST→GET方法轉換（comment: "應Alan要求將post改為get"）. **C-002** (HMAC signing). |
| 443-463 | CONTRACT | **B2** (cancelAllHTTPOperations): `.path` vs `.absoluteString` 比對永遠不匹配。`operationQueue.operations` 對 `NSURLSession` 為空陣列。**Bug confirmed — 雙重失效。** |
| 465-475 | CONTRACT | **M-016** (timestamp): GMT+8 硬編碼偏移 `+28800`，用於加密簽章。非標準時區處理。 |
| 477-487 | CONTRACT | **D-003** (logMismatchShopID): shopId 不一致時透過 `self.logger` 記錄。Error code `91400` 為自定義。 |
| 489 | SKIP | -- (#pragma mark) |
| 491-512 | CONTRACT | **M-012** (requestSerializer factory): 3 種類型切換 + 全域 30 秒 timeout。**M-018** (NYJSONRequestSerializer for FixedFloat)。 |
| 514-528 | CONTRACT | **M-013** (responseSerializer factory): 2 種類型切換。**B1 的根源** — 此回傳值被設定到 `self.responseSerializer`（行 597），造成 race condition。 |
| 530-547 | INFRA | addOperationWithRequestType 8-param（無 requestTimeout）→ 轉發到 9-param，`isSynchrounousRequest:NO`, `requestTimeout:nil` |
| 549-567 | INFRA | addOperationWithRequestType 8-param（有 requestTimeout）→ 轉發到 9-param，`isSynchrounousRequest:NO` |
| 569-654 | CONTRACT | **核心執行路徑** — 9-param `addOperationWithRequestType:...`:  |
| | | • **M-014** (appVer 注入, 行 579-587) |
| | | • **M-001** (requestWithType 呼叫, 行 589) — 觸發所有 request mutation |
| | | • **M-015** (requestTimeout override, 行 590-592) |
| | | • **M-010** (HTTPShouldHandleCookies=YES, 行 593) |
| | | • **M-011** (ny-idempotency-key UUID, 行 594) |
| | | • **M-008** (n1-shop-id header, 行 595) |
| | | • **B1** (self.responseSerializer 共享可變狀態, 行 597) |
| | | • **D-001** (test env SSL bypass, 行 599-602) |
| | | • **S-001** (semaphore create, 行 604-607) |
| | | • **N-001** (notifyResponse, 行 611) |
| | | • **D-002** (shopId mismatch check, 行 612-623) |
| | | • **L-001** (auto-logout detection, 行 632-635) — `logoutWithURL` + `NYLoginHelper.logoutAndLoginAgain` |
| | | • **D-004** (ignoreAuthExpireLogoutEnabled debug flag, 行 634) |
| | | • **N-002** (notifyRequest, 行 646) |
| | | • **S-001** (semaphore wait FOREVER, 行 649-651) |
| 656-675 | CONTRACT | **M-014** (shouldAppendAppVer): 5 個 domain 排除規則（facebook, CDN, tracking, cms, cpdl）。regex pattern matching。 |
| 677-695 | CONTRACT | **L-001** (logoutWithURL): `logoutAPICheckList` pattern match + `ReturnCode` 比對。Break-on-first-match 語意。 |
| 697 | SKIP | -- (#pragma mark) |
| 699-730 | CONTRACT | **D-005** (recordApiInfo): 條件式 API logging 到 CSV 檔（`_logLevel == APIInfo`）。File I/O 無 thread safety。 |
| 732-743 | INFRA | logFilePath + initLogFile — 靜態輔助方法 |
| 745-750 | CONTRACT | **N-002** (notifyRequestWithTask): post `@"apiRequest"` notification，nil guard。 |
| 752-767 | CONTRACT | **N-001** (notifyResponseWithTask): post `@"apiResponse"` notification，conditional `responseObject` inclusion。 |
| 769 | SKIP | -- (@end) |

---

### Summary Statistics

| Category | Count |
|----------|-------|
| **Total lines** | 769 |
| **CONTRACT** | ~580 lines (75.4%) |
| **INFRA** | ~140 lines (18.2%) |
| **SKIP** | ~49 lines (6.4%) |
| **Unclassified** | 0 |

### Anchor Point Reconciliation

| # | Anchor | Contract(s) | Status |
|---|--------|-------------|--------|
| 1 | `dispatch_once` singleton | S-003 | ✅ |
| 2 | `dispatch_semaphore_create` | S-001 | ✅ |
| 3 | `dispatch_semaphore_wait` | S-001 | ✅ |
| 4 | `dispatch_async` | N/A in NYHTTPSClient.m (present in NYDataProvider.m → S-009) | ✅ mapped elsewhere |
| 5 | `@synchronized` | N/A in NYHTTPSClient.m | ✅ N/A |
| 6 | `NSNotificationCenter postNotificationName` | N-001, N-002 | ✅ |
| 7 | `NSNotificationCenter addObserver` | N/A in NYHTTPSClient.m (observers in other files) | ✅ mapped elsewhere |
| 8 | `setValue:forHTTPHeaderField:` | M-003 (Authorization), M-008 (n1-shop-id), M-011 (ny-idempotency-key) | ✅ |
| 9 | `self.responseSerializer =` | B1 | ✅ |
| 10 | `logoutWithURL:` | L-001 | ✅ |
| 11 | `forceUpdateUAuth` | M-009 | ✅ |
| 12 | `aesKey()` / `kSalt` / `kHMAC_SHA512` | C-001, C-002, E-001, E-002, E-003 | ✅ |
| 13 | `PMKManifold` | M-017, B3 | ✅ |
| 14 | `cancelAllHTTPOperations` | B2 | ✅ |
| 15 | `#ifdef` / feature flag | D-004 (ignoreAuthExpireLogoutEnabled) — runtime flag, not compile-time | ✅ |
| 16 | `category_interface` | NYDataProvider+Login, +MemberCenter, etc. — pass-through wrappers | ✅ mapped elsewhere |
| 17 | `AFHTTPSessionManager` subclass | P-001 (NYHTTPSClient inherits), P-005 (NYTrackingClient orphan override) | ✅ |
| 18 | `operationQueue.operations` | B2 (always empty for NSURLSession-based manager) | ✅ |
| 19 | `NYHTTPSClientLogger protocol` | D-007 | ✅ |

**19/19 anchors reconciled.**

---

### Completeness Declaration

```
COMPLETE — All 19 anchor points reconciled. 
All 4 artifacts produced:
  1. Contract Spec (50 contracts, 8 categories, F1/F2/F3 + Risk Matrix) ✅
  2. Verification Script (grep-based, ObjC plugin) ✅  
  3. Coverage Table ✅
  4. Line Attribution Table (NYHTTPSClient.m, 769 lines, 0 unclassified) ✅

Known bugs: B1 (responseSerializer race), B2 (cancel never matches), 
            B3 (AnyPromise wrong resolve), B4 (Timer on GCD queue)
Critical finding: P-005 (NYTrackingClient orphan override)
```

---

`★ Insight ─────────────────────────────────────`
**行 569-654 是整個 network layer 的「pinch point」** — 所有 API 請求最終都流經這個 9-param method。它同時承載了 request mutation（M-001~M-015）、同步語意（S-001）、通知（N-001/N-002）、auto-logout（L-001）、和已確認的 race condition（B1）。未來 T5 Protocol 設計的 Interceptor chain 必須能完整替代這個 method 的所有行為合約，才能安全遷移。
`─────────────────────────────────────────────────`
