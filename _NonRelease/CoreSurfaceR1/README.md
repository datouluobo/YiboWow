# Core R1-05／06 离线验证

日期：2026-10-27。仅离线工具，无游戏TOC，不部署。

- `Spec.lua`：真实Mists／Forever清单，合成原生物品／UI函数与帧；验证查询失败、异步生命周期、入口与共享窗口。
- `PlanSpec.ps1`：继承启动／身份计划，经统一构建器ValidateOnly验证两个目标及虚拟保留旧文件覆盖；增加物品／UI边界引用检查。
- `BlockedFixtureDiagnostics.lua`：在内存暴露历史任务来源夹具被吞掉的provider错误，不改业务实现、不跳过断言。
- `TestResults.json`：本轮实际命令、退出状态和原始输出；失败保留。
- `Results.json`：当前运行源摘要、版本和证据边界；不改写前阶段摘要。

详见[实施验收](../../YiboCore/Docs/R1-05-06-公共物品与UI原生边界实施验收.md)。没有玩家WTF或客户端操作；离线模拟不能替代原生UI和存档恢复验收。
