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

2026-10-28 内部性能优化：Core 自有原生 DataDomains 采集使用身份投影，第三方注册的 Collect 仍收到完整隔离角色上下文；Get／GetCurrent／GetAll 的默认完整副本和 GetAllCached 的既有契约保持。没有新增公开能力或版本要求。见[修复与验证](../../Docs/性能修复-第二轮-2026-10-28.md)。

当前Mists／Forever共享底座采用API13，character-identity:1契约继续兼容；当前工作树已提供下述能力2。原生读取经Core内部Client绑定；业务继续使用本页公开投影，不绑定Client或用本地化显示名关联数据。另有GetAllCached只读共享快照，不能按GetAll的可修改副本使用；暂不可读与legacy边界见[共享底座契约](API-v13-R1共享底座兼容与失败契约.md)。新字节实机恢复仍待，原历史版本说明不代表当前渠道状态。

2026-10-29 character-identity:2（API13）：身份投影新增既有角色目录的 faction，未知时仍为 nil，不读取业务域。Mail 收件人需检查能力2，直接消费身份投影，取消为阵营而加载完整 GetAllCached。能力1消费者与默认完整查询契约不变。


## 只读身份目录缓存（2026-10-29）

Core API13 新增独立能力 `character-identity-cache:1`。检查后可用 `Core.Characters:GetAllCached({identityOnly=true})`：字段与能力2的身份投影相同，返回共享只读目录，同一代重复调用复用数组与身份表；不得修改。需要可修改副本时继续 GetAll(identityOnly)。默认 GetAllCached() 的完整只读契约不变。

2026-10-29 Core内部设置读取优化：设置页上下文、短名与排序列表及重建顺序只读身份；业务页面默认完整上下文保持。GetShortNameDuplicates先按身份筛选，仅对真实重复组构造完整隔离副本，返回字段及组内顺序保持；不会因没有重复短名而复制所有业务域。公开API／能力版本与业务接入状态不变，详见[设置身份读取记录](../../Docs/Core-设置身份读取性能-2026-10-29.md)。

目录刷新／导入／删除及现有 InvalidateAllCache（包括域更新）会先清掉身份缓存；新查询重建，消费者可用返回数组身份变化作自身派生缓存失效依据，不依赖事件广播顺序。缓存仅含身份，不存业务域，未就绪和空目录返回行为同 GetAll。Core 阶段验证后由 Mail 在途目录首先接入，Mists 消费方检查能力1，缺少则提示升级、在写库前停止；其它插件不强制改动。
