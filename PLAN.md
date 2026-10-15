# M1 开发计划（冻结在 R0）

## 本轮完成
- M1-T00-A：外部实例路径解析；默认 fail-closed，兼容显式 legacy。
- M1-T00-B：幂等、离线实例初始化；生成独立配置、钩子、身份清单目录。
- M1-T00-C：`filesystem` 与 `config` 两级自检；`full` 未实现时返回 4。
- M1-T00-D：只读 Kit、双实例、凭据权限、越界链接等回归测试。
- M1-T00-E：固定 private upstream commit 的完整 Kit 本地组装脚本。

## 下一轮 TODO（均需 Patch）
1. M1-T01：消除 upstream `install.sh` 和 `verify_install.sh` 与 M1 新入口的行为差异。
2. M1-T02：统一 config resolver，供 upstream `_common.sh`、独立验证器使用。
3. M1-T03：对齐浏览器后端 capability/参数约定（与 M2 边界）。
4. M1-T04：配置文件更安全的格式/解析策略，避免不可信 shell source。
5. M1-T05：多实例并发端口、浏览器 profile 和板锁配置冲突检测。

## 非目标
- 本基础版不实现 M2~M9，不自动连接浏览器、不向用户真机发送 SSH、不修改 GitHub 私有仓库。
