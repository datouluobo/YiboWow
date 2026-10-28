# Core R3 非发布消费者验证

2026-10-27。生产Core运行字节与R2完全一致；独立测试owner为CoreR3Consumer，不执行YBP业务代码，不采集宠物，不创建业务SavedVariables，不联接客户端。

- [Consumer.lua](Consumer.lua)：既有Core能力与方法门槛、页面／设置／入口／清理生命周期。两组值仅为内存样本，不能用作正式业务实现。
- [Spec.lua](Spec.lua)：真实三目标清单 × 五种语言组合，以及缺失owner的合成冷启动回放，2463项。
- [PlanSpec.ps1](PlanSpec.ps1)：统一三目标ValidateOnly、加载图／版本／别名与夹具排除，26项；计划输出[Build-Plans.json](Build-Plans.json)。
- [RunChecks.py](RunChecks.py)：复跑适用旧目标／消费者回归，保护R2生产字节和历史记录；34条命令中28条通过，原5组失败及1条诊断非零退出，无新失败。
- [TestResults.json](TestResults.json)：当前命令与完整输出；[Results.json](Results.json)：生产哈希、能力版本、范围和失败清单。

复现：在仓库根目录运行 `python _NonRelease/CoreConsumerR3/RunChecks.py`。不生成或移动ZIP。已有失败原样保留，详见[验收](../../YiboCore/Docs/R3-YBP离线兽栏公共契约实施验收.md)；真实客户端／最终包／WTF恢复和YBP业务集成仍待。

R3未新增原生加载行为，因此没有客户端探针TOC，也没有要求重复已验R2基础启动。新增文档后的源码归档摘要与R2旧ZIP不同，旧ZIP继续作为当时证据保留；本阶段不重新声明其为当前源码包。
