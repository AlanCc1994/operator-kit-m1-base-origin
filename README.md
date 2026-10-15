# Operator Kit · M1 基础工程 R0

实现 M1：Kit 外部多实例初始化、路径隔离、幂等、离线配置校验。**后续只用增量 Patch。**

## 核心能力
- 所有实例文件放在 `OPERATOR_HOME`，Kit 可保持只读。
- `OPERATOR_HOME` 与 `KIT_ROOT` 有边界检查；禁止实例路径落入 Kit 子目录。
- 配置、项目身份清单和 Hook 都位于实例目录。
- 不覆盖已存在的配置、凭据和实例文件。
- 配置验证分层：`filesystem` / `config`；`full` 明确未实现。
- 有可重复运行的离线测试。无需浏览器、GitHub、开发板。

## 直接体验 M1
```bash
bash tests/m1/run-tests.sh
bin/m1-init-instance.sh --home /tmp/operator-afc-test
bin/m1-verify-instance.sh --home /tmp/operator-afc-test --stage filesystem
# 编辑 /tmp/operator-afc-test/operator.env 中占位符
bin/m1-verify-instance.sh --home /tmp/operator-afc-test --stage config
```

## 合成完整的现有 Operator Kit 2.0.0 + M1
若需继续使用完整的浏览器、交付、真机模块，请在**你的本地环境**执行：
```bash
# 不会覆盖原私有仓库或现有本地工作树
scripts/assemble-full-kit.sh \
  --source /path/to/your/cloned/operator-kit \
  --out /path/to/workspace/operator-kit-m1-full
```
或者省略 `--source`，自动从 `AlanCc1994/operator-kit` 克隆（需要你自己的 GitHub 凭据）。

组装脚本严格固定 upstream commit `78187984af240cec1a1c9568f5a14429701cc860`，
只加入 `m1/`、`bin/m1-*`、`tests/m1/`、相关文档，并修正一个 `project.env.example` 默认路径。
不会覆盖原有 `install.sh`、`verify_install.sh`、`bin/_common.sh`、浏览器、真机和交付代码。
生成完整 Git 工程并建立 `m1-base-r0` 标签和新提交，可直接作为后续 Patch 的父版本。

## 文件介绍
- `m1/paths.sh`：唯一实例目录和配置路径解析器。
- `m1/init.sh`：外部实例初始化，不接触网络和真机。
- `m1/verify.sh`：离线验证。
- `bin/m1-*.sh`：M1 公开命令入口。
- `tests/m1/run-tests.sh`：实例隔离、边界、幂等、只读 Kit 测试。
- `docs/M1_ARCHITECTURE.md`：架构与边界。
- `docs/PATCH_PROTOCOL.md`：后续 Patch 契约。
- `scripts/assemble-full-kit.sh`：复用原有私有仓库的完整工程组装入口。

## 说明
此压缩包本身是**可运行的 M1 完整子工程**，不声称内含整个私有仓库。
完整原工程须通过组装脚本本地获取后合成。这样可以保留上游 2.0.0 全部真实代码，避免伪造或丢失源码。
