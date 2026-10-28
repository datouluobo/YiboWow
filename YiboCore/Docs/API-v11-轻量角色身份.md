# API v11：轻量角色身份

2026-10-10 工作树新增能力 `character-identity:1`，Core 1.10.0 / API v11，尚未发布。

高频任务观察只需要角色身份、等级或是否存在。原 `Characters:Get` / `GetAll` 会深复制完整角色记录（含 domains）；业务循环调用时会复制背包等无关大数据。身份投影属于 Core 的通用设施，业务状态与时效继续由来源插件判断。

检查 `Core:CheckAPIVersion(11)` 和 `Core:HasCapability("character-identity", 1)` 后使用：

```lua
Core.Characters:Get(characterID, { identityOnly = true })
Core.Characters:GetCurrent({ identityOnly = true })
Core.Characters:GetAll({ identityOnly = true })
```

返回新建的身份表：`id / name / realm / class / level / lastSeenAt / seenOrder`，不含 domains，不访问或复制业务领域数据。缺失角色仍返回 nil；无角色返回空列表；排序保持 seenOrder、id 顺序。返回值可修改，不影响数据库。名字显示继续使用 FormatName，不能用显示名作为身份键。

不传 options 的既有调用保持完整记录深复制语义；GetAllCached 也保持既有只读快照约定。身份投影即时读取，没有第二套持久化存储或失效缓存。

TaskHub 全部角色目录与身份读取、Todo 任务观察／主快照／行动投影、AltoBoss 目标投影与配置范围已接入。TaskHub / Todo 初始化检查新能力，缺少时提示升级并停止；AltoBoss 只停止目标增强，基础 API v5 跟踪继续工作。未触及的旧业务查询后续修改时按实际需求迁移，不改全局 Get 的默认含义。

验证：`_NonRelease/TaskChainPerformance/PerformanceSpec.lua` 使用真实 Core Characters，包含 10,000 条无关物品数据的角色；400 次身份读取未调用 Defaults.Copy，默认完整读取保持数据完整与复制隔离。还覆盖消费者缺少能力时的停止行为。

## R1兼容性复核（2026-10-27）

当前Mists／Forever共享底座采用API13，character-identity:1保持。原生读取经Core内部Client绑定；业务继续使用本页公开投影，不绑定Client或用本地化显示名关联数据。另有GetAllCached只读共享快照，不能按GetAll的可修改副本使用；暂不可读与legacy边界见[共享底座契约](API-v13-R1共享底座兼容与失败契约.md)。新字节实机恢复仍待，原历史版本说明不代表当前渠道状态。
