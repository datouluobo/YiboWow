# Vault 无限服当前角色最小适配

日期：2026-10-19。状态：**无限服背包／装备页面、采集及按钮显示已获实机确认，保存恢复及MoP待实机验收**。

后续确认：用户截图与文字已确认按钮显示及页签高亮正确。银行阶段现为0.2.0-api1，独立见[角色银行最小适配](Forever-当前角色银行最小适配.md)；下文保留0.1阶段的实施与验证边界。

| 目标 | 源清单 | 版本 | 存档表 | 本轮范围 |
| --- | --- | --- | --- | --- |
| Mists | YiboVault.toc，Interface50504 | 1.2.3-api1 | YiboVaultDB | 保留现有完整来源、账号查询与仓储页 |
| Forever | YiboVault_Forever.toc，Interface16001 | 0.1.0-api1 | YiboVaultForeverDB | 当前角色背包与装备的只读采集、保存及Core页面 |

两份清单复用 Namespace、Store、Items 与物品记录构造；Forever 通过自己的目标配置、采集、初始化和页面文件落实本轮范围。共享 Collector 中银行等旧方法仅作为未调用的定义存在；银行、公会银行、拍卖、邮件、目标操作和全局物品悬停模块未在无限清单加载，也不注册其事件或来源能力。

## Core 与数据所有权

- 最低 Core API13，开发客户端配套 Core Forever 0.1.0 起的相应能力：`localization:1`、`business-services:1`、`character-name-format:1`、`basic-input:1`、`item-resolver:1`、`character-identity:1`、`account-entry:2`、`account-surface-budget:2`、`account-character-admission:1`，并检查所调用的方法。Core缺失、版本或能力不足时明确提示升级，停止无限服数据库及业务初始化。
- Vault 是物品记录与存档的唯一所有者。角色 ID、名称格式化、页面壳、滚动、字段与预览选择、入口和清理生命周期复用 Core 公开接口；不访问其私有状态或存档，不把物品数据放进 Core。
- 升级提示通过Core语言服务输出；Core语言服务本身缺失时，启动前诊断使用固定英文升级提示。这是无法调用语言服务时的最小例外，不提供并行的业务翻译实现。
- 角色使用 Core 当前 GUID。当前角色无公开身份时，查询返回 `current-character-unavailable`；不创建名字／服务器回退键。规则集范围继续未知，当前目标不提供账号、服务器或其它角色查询。
- 无限服只读写 `YiboVaultForeverDB`，不导入或复制 `YiboVaultDB`。存档戳为 `target=Forever, projectID=18, scope=current-character, rulesetState=unknown`。schema、目标戳或顶层数据类型不兼容时保留原数据并停止。原生文件名仍是无限客户端 `WTF/Account/<账号>/SavedVariables/YiboVault.lua`，文件中表名为 `YiboVaultForeverDB`。
- 保存既有角色快照只供归档与Core清理；当前阶段的服务与页面只准入当前角色。每次重载将已有采集覆盖标记为过期，保留旧记录及原采样时间，成功重采后恢复正常状态。

## 采集边界与失败语义

背包覆盖 `0..4`，仅当客户端原生 `Enum.BagIndex.ReagentBag=5` 存在时纳入5；不把经典服的银行编号套到无限服。使用 `C_Container.GetContainerNumSlots/GetContainerItemInfo`，返回表的 ID、数量、链接须可读；可用时核对空格数与实见占用格数。装备读取当前玩家 `1..19` 槽的 ID 与可用链接。

进入世界时不立即写空快照，先将旧覆盖置过期，安排3秒后读取；背包／装备变化事件合并触发重采，不使用周期轮询。首次自动读取若整类来源完全无对象、又尚未收到该来源就绪通知，则维持未知。手动采样须已进入世界且跨过最初3秒，用户应在画面加载后执行；离开世界会取消待执行采样。

一次来源读取先暂存所有候选，验证通过后才替换对应位置。读取失败或空格／物品数量不一致时保留旧记录，标记错误与过期；不把失败当空背包。收到对应原生变化事件或用户在加载后手动确认，再完成成功空扫描时，才可清除已移走物品并产生 `known-empty`。成功表示本次声明范围的API读取完成，不外推银行、离线角色、其它规则集或全部账号库存。

物品仍采用 `itemID/itemKey/variantKey/identityQuality/quantity/characterID/location/observedAt/clockSource` 等既有记录结构。链接不完整时使用 `item-id-only`，不伪造完整变体。展示名称与加载中的物品数据交给 Core ItemResolver；不以显示名称关联库存。

原生调用形状参考[暴雪容器API源码文档镜像](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)；该来源属于其它当前分支，实际无限构建的全槽位、材料包和变化行为继续以本机实测为准。

## 通过 Core 发现的查询契约

沿用服务 `vault.items`，提供方 `YiboVault`、providerID `YiboVault:inventory`、版本 `{major=1,minor=1}`。消费方按 Core.Contracts 注册与发现契约，不读取 Vault 全局实现或 SavedVariables。

| 方法／能力 | Forever 行为 |
| --- | --- |
| Query(request) | scope省略表示当前角色；显式scope仅接受包含当前GUID的characters列表。account／realm／其它角色返回 `nil,scope-not-supported` |
| sources | 仅 `bags`、`equipment`；其它来源返回 `nil,invalid-sources` |
| HasCapability | 仅声明 items.query:1、items.state:1、items.events:1、source.bags:1、source.equipment:1 |
| GetPersonalCounts | 未声明该能力，方法返回 `nil,unsupported-capability`；不返回虚假的银行零值 |
| 快照与状态 | Query沿用API1值快照、records、coverage与revision；来源状态以coverage.locations为准。无快照、错误或过期不可单凭totals=0解释为“没有物品” |
| 变更通知 | 复用VAULT_ITEMS_CHANGED和Core.Contracts:NotifyChanged；同一批事件合并采集，相同结果不无故提高revision；调用方订阅用Core.Events并按既有契约清理 |

来源就绪、失败、过期和恢复均保留既有覆盖结构；错误时旧记录通过 `includeStale=true` 可见，通过 `includeStale=false` 排除。返回表保持副本，不给消费者内部数据库引用。服务仅在Core就绪、Vault完成注册后可发现；初始化可重复调用，成功后不重复注册页面、入口或监听。

## 页面与入口

无限页面ID沿用 `vault-items`，由Core托管，提供背包／装备两页签、物品／位置／数量字段和手动刷新。首次尚无有效快照的角色不进入预览准入；完整成功的空快照与等待、过期、错误分别显示。主窗口和悬停预览使用同一查询、准入、状态文字与配色，预览只隐藏刷新按钮，并按插件 `settings.previewColumns` 投影字段。

字段选择、角色隐藏、入口三通道、滚动与窗口位置均由Core处理；独立入口默认三通道关闭。默认仍从Core入口打开业务页。页签选择保存在Vault设置中。当前没有额外业务设置或可独立管理的缓存动作，不创建第二套设置窗口。

共享 AddonCatalog 已为Vault声明Forever目标，并在该客户端使用“当前角色背包与装备”描述；MoP仍使用原账号物品说明。所有新增玩家文本使用稳定ASCII key的中英文资源。

## 离线证据

```powershell
lua _NonRelease/VaultForever/Smoke.lua
lua _NonRelease/CoreForever/Smoke.lua
.\Tools\Test-LuaSyntax.ps1 -Addon YiboCore,YiboVault
.\Tools\Build-ReleasePackages.ps1 -Addon YiboVault -Target Mists -ValidateOnly
```

- 新集成316项检查通过，加载真实Core与Vault两端清单，模拟登录初期无数据、材料包、全袋／装备、变化合并、数量与换装、失败保留、恢复、空快照、服务隔离、主视图／预览一致、重载恢复及版本／目标／schema失败。包含真实MoP清单的启动、来源能力、采集、账号查询与原仓储页面。
- Core69项回归通过；73个TOC加载Lua文件通过Lua5.1语法检查；Mists 1.2.3-api1/Interface50504构建ValidateOnly通过，未生成或发布新包。
- Vault现有16个独立Spec中5个通过、11个失败。改动前对照同样5通过／11失败，缺项集中在旧夹具的T语言方法与GetAllCached接口。对照明细位于[LegacyTestComparison.json](../../_NonRelease/VaultForever/LegacyTestComparison.json)，不把失败计为通过。
- 工作区本地化候选报告已生成并查看：本次新增文本无缺英文或格式参数不一致，无新增未知key；其余插件既有6个未知key保留原状。模拟和词法检查不代替中英文客户端验收。

## 客户端验收

1. 完整退出无限客户端再进入，仅启用Core与Vault，可保留独立探针。确认Vault为 **0.1.0-api1**，Core为 **0.1.0**，原生加载选择正确。
2. 进入世界等待画面加载完成后运行 `/yva scan`、`/yva open`。核对背包页中的实际物品、数量与位置，再切装备页逐项对照人物装备；本阶段不用银行、邮件或其它角色作为数据来源。
3. 手动正常游戏操作移动／拆分一组物品、替换一件装备，确认页面自动刷新。检查已移走的记录消失，新物品和数量正确；不需要探针代替游戏操作。
4. `/reload` 后再次打开页面，核对保存与重采；再退出角色重登验证。确认原生YiboVault.lua文件中的表名为YiboVaultForeverDB。若想验证真正空位置，用已确认的正常移动操作对照，不能用登录初期空结果代替。
5. 如启用独立入口，核对悬停是同一来源页的列投影；Core“显示与入口”的主表和悬停字段选择分别生效。
6. MoP保留原启用集合，核对 **1.2.3-api1**、原数据、背包／装备及原仓储页；原有银行、拍卖、邮件等范围和窗口继续按已有流程工作。

2026-10-19 用户三张截图确认：无限服加载Vault0.1.0-api1，当前角色背包与装备均显示真实物品名称、位置、数量及“快照已采集”，两页签可切换，Core托管业务设置页可打开。截图未提供物品逐项核对、变化自动更新、重载保存恢复或MoP实测证据，不将这些项目计为完成。

截图还暴露背包／装备／刷新按钮全部显示“28”：调用Core `UITheme:CreateButton(parent,width,label,kind)` 时错误插入高度参数。本次修正三个调用，高度单独设置，并使选中页签使用Core已有selected状态。新增四项真实Theme标签与选中状态检查，双端集成共320项通过；修复后的原生文字与布局待用户重载确认。设置页暂无业务专属设置符合本阶段范围，通用字段与入口仍在Core“显示与入口”。

具体库存、材料包枚举、保存落盘和完整WoW原生布局不可据模拟推定已通过。请保留首条错误及两页截图，按实际现象继续修复。
