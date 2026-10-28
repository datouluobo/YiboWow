# API13：角色清理 v2

Core1.12.5 / API13 / character-cleanup:2，2026-10-16发布。Builds1.5.0是本次配套消费者。

Core负责通用缓存所有者登记、影响说明与删除历史；各业务拥有自己的数据库并执行删除，Core不读取业务SavedVariables。

2026-10-27 R1-07补充：期望owner由当前目标元数据提供，并合并当前注册、存档已知owner和删除历史中的owner；不因禁用或当前目录过滤丢失待重放范围。新历史可选`requiredOwners`保存当次集合，旧历史缺字段仍兼容，schema／API／能力版本保持。详情及新增字节待验范围见[目标元数据与通用契约验收](R1-07-08-目标元数据与通用契约实施验收.md)。

RegisterOwner(addonName,{Inspect,Delete})原签名保持；登记成功后持久保存所有者技术ID，插件禁用后仍计入影响说明与pending清理。所有已知所有者确认且无失败后，历史才按100条软上限裁剪。重复所有者登记返回错误，不静默覆盖。

Delete(character,aliases,context)返回true表示完成；nil/false与错误信息表示失败并保留待处理记录。aliases沿用Core的别名ID→true集合。第三参数新增：

- deletedAt：服务器删除时间。
- deletionID：稳定删除记录ID。
- replay：直接删除为false，RetryPending回放为true。

第三参数可忽略，已有两参数回调继续兼容v1。所有者按自己的快照时间和业务语义决定是否保留墓碑之后的有效新观察；直接删除必须按用户操作清理。返回影响摘要须使用会话语言。所有者不因回放次序而依赖其他业务。

最低接口检查：CheckAPIVersion(13)、HasCapability("character-cleanup",2)、CharacterCleanup:RegisterOwner。版本不足时提示升级并停止依赖初始化。

Builds1.5.0接入Inspect／Delete，清理角色ID及别名，延后回放保留有效新观察并移除过期装备。其他既有消费者继续使用其原能力要求，触及生命周期时评估接入。CharacterCleanupV2Spec验证实际Core模块的持久所有者、禁用／冷启动、pending软上限、回放上下文及旧回调兼容；Builds Core13Spec验证业务新旧快照保留边界。用户已确认Builds本次Core适配正常。
