# M1 以后增量 Patch 交互协议

**基线冻结**：首次交付的 M1 R0 为唯一初始接受基线。不要覆盖式投递新版源码包。

每轮 Patch 必需记录：
1. `ROUND_ID` / `BASE_COMMIT` / `BASE_TREE` / `EXPECTED_POST_TREE`。
2. `SCOPE`：精确文件白名单；M1 时禁止更改 M2~M9 代码。
3. `PLAN` / `TODO` / 设计变更理由。
4. `PREIMAGE` SHA 校验及 `git apply --check` 结果。
5. 增量 `.patch`、该文件 SHA256、测试结果、PASS/FAIL 判据。
6. 应用后源码树标识、回退方式及是否 ACCEPT。

使用过程：
```
git status --porcelain                # 必须为空
git rev-parse HEAD
git rev-parse HEAD^{tree}
git apply --check M1-Txx.patch
git apply M1-Txx.patch
bash tests/m1/run-tests.sh
git diff --check
```

**验收规则**：未通过测试、缺少 SHA、上轮未接受、或存在非白名单更改时不得推进下一轮。

**注意**：M1 独立基础包和使用组装脚本生成的完整 Operator Kit 的 Git Commit 不一样。
应先选择一个作为后续持续开发的权威基线；推荐完整组装版本（含真实 upstream 的 M2~M9）。
