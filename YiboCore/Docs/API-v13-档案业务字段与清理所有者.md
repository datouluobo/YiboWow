# API13：档案业务字段与清理所有者

2026-10-15；Core1.12.4工作树 / API13。能力：`character-archive-providers:1`、`character-cleanup:2`。Currency0.9.1工作树已接入代码，真实客户端待验收。

版本安排：按用户要求，TOC与运行时版本保持Currency0.9.1、Core1.12.4，当前为未发布工作树。实机测试通过后再更新正式版本、提交、推送及打包；不能仅按相同版本号判断兼容，必须同时满足新增能力版本与停采集检查。

## 档案业务字段 Provider v1.0

Core通过既有 `Contracts:List("character-archive.fields",{major=1,minMinor=0})` 枚举提供者，通过 `Contracts:Call("YiboCore",descriptor,method,request)` 查询。Core不依赖插件技术名，不读取其数据库；业务所有者负责数量、状态、时效、语言标签与数据保存。

Provider注册形状：

```lua
{
  name = "character-archive.fields", kind = "provider",
  providerID = "Owner:fields", version = { major = 1, minor = 0 },
  methods = { GetFields = function(request) ... end, Read = function(request) ... end },
}
```

`GetFields({})` 返回连续数组，字段为 `{id,title,order,width?,align?,formatKind,defaultVisible?,defaultPreviewVisible?}`。id非空稳定字符串、title会话语言字符串、order有限数值；formatKind首版仅支持本次所需的 `money`（铜币输入、金单位显示）。宽度限制32～400，未知元数据不带入UI；不允许函数、重复ID、数组空洞或非数组属性。默认两个显示开关均关闭。

`Read({characterIDs={...},fieldIDs={...}})` 返回：

```lua
{
  sourceID = "Owner:fields", revision = 1, generatedAt = 1000,
  characters = { [coreCharacterID] = { fields = {
    [fieldID] = { value = 0, state = "known", observedAt = 999 },
  } } },
}
```

字段值为非负有限数值；known可显示确认零；stale显示历史值并加`~`；unknown/unavailable、缺失、错误或不合规值显示`?`，不回退Core旧业务数据。sourceID必须与描述符providerID一致。observedAt由来源负责解释，Core不把generatedAt当采集时间。Currency的金币单位为铜币，状态与Currency主表一致。

Core `Fields:GetByConsumer("character-archive")` 合并静态与业务字段，保持既有静态调用兼容；`Fields:FormatValue(character,field,batch?)` 复用一次批量读模型。完整档案与悬停绘制按提供者批量读取，逐格绘制不重复查询；查询只读取缓存，不执行业务采集。

冲突规则：业务字段之间同ID全部隔离；与Core静态字段冲突时保留静态字段、隔离业务字段，输出一次双语错误。提供者缺失、禁用、主版本不兼容或异常时，基础档案仍可用；晚注册／注销／变更通过原有BUSINESS_CONTRACT_*事实通知合并刷新。业务返回副本，Core也不把内部适配对象传给业务消费者。

实际消费者为Core角色档案，实际提供者为Currency `YiboCurrency:archive-currency`，首个字段保留原ID `character.money`。原Core静态金币字段已撤下；显示选择不改ID，无需重新选择。其它业务按真实需求加入本契约，不预建服务目录。

## CharacterCleanup v2

`RegisterOwner(addonName,{Inspect,Delete})` 原签名不变，仍要求所有者已注册。新增通用持久化 `YiboCoreDB.characterDataOwners[addonName]=true`；关闭插件后，Core仍能在影响说明和pending清理中包含该所有者。保存技术ID，不保存本地化标签或回调函数；Core不增加具体业务名称分支。

Delete回调新增第三个可选参数：`{deletedAt,deletionID,replay}`。直接删除replay=false；启动后的RetryPending回放replay=true。旧回调忽略额外参数，仍兼容能力1。业务必须按自己的数据所有权删除，Inspect提供会话语言影响摘要；Core不触碰业务SavedVariables。

历史记录软上限仍为100；所有已知所有者确认且无失败后，才允许按原策略裁剪。任何待处理的动态所有者都会阻止对应清理记录被裁掉。`IsLegacyImportBlocked`、当前角色禁止删除与原别名语义保留。

Currency在回放时保留墓碑之后、时间有效的本地重采快照，清理更旧的另一类快照；直接删除不被未来时间戳绕过。它自行保存导入阻止标记、按Core别名处理旧ID，不把同名新GUID当作已删除的旧角色。所有业务实现仍需自行检查适用的版本和方法。

## 验证

`_NonRelease/CurrencyMigration/CoreSpec.lua` 23项涵盖字段批量、副本、缺失、冲突、静态兼容、晚注册、注销、所有者持久化、冷启动及软上限留存。MigrationSpec55项、RetentionSpec29项覆盖实际Currency接入；声望迁移既有126项通过，说明该已验证旧消费者继续兼容。其它所有者仅静态发现，不推定已完成客户端或能力2特性验收。

## R1兼容性复核（2026-10-27）

API13、character-archive-providers:1与character-cleanup:2保持。目标期望owner与存档、历史owner合并，新历史可选requiredOwners而旧历史兼容；跨目标已知owner不丢弃，pending仍须重放确认。档案字段聚合、冲突与注销按原契约；页面注销后的实例和预览由Core清理。当前验证范围见[共享底座契约](API-v13-R1共享底座兼容与失败契约.md)及[R1-09验收](R1-09-文案与契约文档收尾验收.md)，不据此增加业务接入或已发布声明。
