---
description: TDD 測試：默認存儲功能
---

# 測試：默認存儲

執行此測試來驗證默認存儲功能是否正常運作。

## 測試環境準備

1. 清除舊 cache:
```bash
rm -rf .sourceatlas/
```

2. 記錄測試開始時間:
```bash
date +%s > /tmp/test-start-time
```

---

## T1: overview 自動存儲

執行 `/atlas.overview` 命令（無 --save 參數）。

完成後驗證:
```bash
if [ -f .sourceatlas/overview.yaml ]; then
    echo "✅ T1 PASS: overview.yaml 已建立"
else
    echo "❌ T1 FAIL: overview.yaml 不存在"
fi
```

---

## T2: --force 覆蓋

記錄舊時間戳:
```bash
stat -f %m .sourceatlas/overview.yaml > /tmp/old-mtime
sleep 2
```

執行 `/atlas.overview --force` 命令。

驗證:
```bash
new_mtime=$(stat -f %m .sourceatlas/overview.yaml)
old_mtime=$(cat /tmp/old-mtime)
if [ "$new_mtime" -gt "$old_mtime" ]; then
    echo "✅ T2 PASS: 檔案已覆蓋"
else
    echo "❌ T2 FAIL: 檔案未更新"
fi
```

---

## T3: --save deprecation

執行 `/atlas.overview --save` 命令。

驗證輸出是否包含 deprecation 提示（人工確認）:
- 應看到類似: `⚠️ --save 已棄用，現在默認存儲`

---

## T4: pattern 自動存儲

執行 `/atlas.pattern "api"` 命令。

驗證:
```bash
if [ -f .sourceatlas/patterns/api.md ]; then
    echo "✅ T4 PASS: patterns/api.md 已建立"
else
    echo "❌ T4 FAIL: patterns/api.md 不存在"
fi
```

---

## T5: cache 載入

執行 `/atlas.overview` 命令（已有 cache）。

驗證輸出是否包含 "Loading cache"（人工確認）:
- 應看到類似: `📁 Loading cache: .sourceatlas/overview.yaml`

---

## 測試結果彙整

執行完所有測試後，輸出:
```bash
echo "=== 測試結果 ==="
echo "T1: $([ -f .sourceatlas/overview.yaml ] && echo 'PASS' || echo 'FAIL')"
echo "T4: $([ -f .sourceatlas/patterns/api.md ] && echo 'PASS' || echo 'FAIL')"
echo "T2, T3, T5: 請人工確認上述輸出"
```
