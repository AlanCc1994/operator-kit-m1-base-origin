# Operator Kit · M1 R0 基础工程架构

## 项目状态
- 基础名称：`operator-kit-m1-base-r0`
- 定位：可独立验证的 **M1 配置与实例隔离子工程**，不是完整的 upstream operator-kit 2.0.0 镜像。
- 上游只读参考：私有库 `AlanCc1994/operator-kit`，固定 Git commit `78187984af240cec1a1c9568f5a14429701cc860`。
- 交付形式：此基础源码包 + 使用用户本地 Git 凭据的 **完整 2.0.0 组装脚本**。不将私有代码假装为已随包附带。
- M2~M9 尚未迁移/实现；需要完整已存在的功能请运行组装脚本。

## M1 目标与边界
共享 Kit 可只读；真实实例都在 Kit 外部：`OPERATOR_HOME`。配置、项目身份清单、项目钩子、日志、下载缓存、浏览器 Profile、凭据各自独立。`BOARD_LOCKDIR` 是有意保留的远程共享资源，不必位于实例下。

### 入口
- `bin/m1-init-instance.sh --home PATH`：只初始化，不验证真机。
- `bin/m1-verify-instance.sh --home PATH --stage filesystem`：离线文件与目录安全校验。
- `bin/m1-verify-instance.sh --home PATH --stage config`：离线参数、路径、作用域校验。
- `bin/m1-verify-instance.sh --home PATH --stage full`：未实现，返回 4。不虚报成功。

### 生命周期
- 初始化时保留现有 `operator.env` 与 `project/project.env`，不创建密码，不登录外部服务。
- `OPERATOR_ENV` 可以从实例内选择同名或后端专用配置，但不能跨实例指向别的配置。
- 配置文件是**可信 Bash 代码**；严禁 source 不可信交付包中的配置。下一版本可加入非可执行格式。
- 本阶段不改动 upstream `bin/_common.sh`、`run-round.sh`、浏览器和真机系统。M1 独立验证器与原 upstream `verify_install.sh` 不同；后续 Patch 统一入口。

### 目录树
```
/tools/operator-kit/                      # shared, potentially readonly
  m1/{paths,init,verify}.sh                # added by M1
  bin/m1-{init,verify}-instance.sh

/workspace/afc/operator/                   # instance A
  operator.env
  project/{project.env,hooks/,identity/}
  _ssh/askpass.sh.example
  state/ incoming/ chrome-cdp-profile/

/workspace/rnnoise/operator/               # instance B
  ...
```

## 已知范围和限制
1. 这份包单独运行时只包含 M1 与项目模板，**没有 M2~M9 的原代码**。
2. 完整 Kit 组装脚本要求用户本地已有对 GitHub 私有仓库的访问权限（或现有本地克隆）。
3. 实例内可执行 Bash 配置是信任边界；文件系统权限不能让不可信配置变安全。
4. 配置验证只确认实例结构和静态字段，未连接/检查真实浏览器、会话或开发板。
5. Firefox/AdsPower 的真实运行能力在后续 M2 进行验证。
6. 旧单实例入口依然由 upstream 的 `install.sh`、`verify_install.sh` 保持；M1 新入口显式要求外部实例或 `--legacy-in-kit`。

## 冻结验收
- 测试必须离线执行，不改真实工程。
- `tests/m1/run-tests.sh` 全部通过。
- 后续任务必须基于 `m1-base-r0` Git 标签开展，并使用 `git diff --binary` 或 `git format-patch` 提供增量交付。
