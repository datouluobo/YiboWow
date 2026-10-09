# YiboVault

当前版本：`1.1.1-api1`。`1.1.1` 为插件版本，`api1` 为对外 `Items` API 版本。需要 YiboCore API v9 和 `business-services:1`，正式渠道包使用 Core 1.9.0 或更新版本；YiboCurrency 是可选调用方。通过 Core 发现 `mail.items`，提供方兼容时只消费邮件快照；缺失或不兼容时独立采集。Vault 通过 `vault.items` 提供只读库存查询，见 [API v9](../YiboCore/Docs/API-v9-业务服务与刷新.md)。

正式版变化见 [更新日志](CHANGELOG.md)。

安装 YiboMail 时，Vault 通过 Core 的 `mail.items` v1 服务按角色优先使用 Mail 邮箱快照。Mail 关闭、历史状态或刷新失败但仍有成功快照时，继续使用该快照；成功空邮箱覆盖旧数量。Mail 从未采集该角色、公开接口不可用或不兼容时，使用 Vault 自有缓存。两份来源不会相加；主窗口、仓储页、查询 API 与 tooltip 共用同一投影。兼容 Mail 服务已注册时，Vault 不启动第二套邮箱扫描；服务缺失或注销后恢复独立采集。YiboMail 是可选增强，未安装时 Vault 邮箱采集照常工作。TOC 变化后需完整退出并重新进入游戏。

联动回归：`lua YiboVault/_NonRelease/Tests/MailProviderSpec.lua`。测试使用实际 Mail API、Vault 查询与来源适配器，覆盖按角色回退、空邮箱、状态变化、事件顺序和订阅生命周期。

> 当前状态：背包/装备、Core 账号查询页、个人银行及公会银行已完成首轮客户端检查；AH 正式采集和当前角色明细已通过客户端检查。角色仓储页与容量展示已获用户确认；物品 Tooltip 的 Vault 区块已通过截图核对。Vault 已接入可选 YiboMail.Items v1 邮件来源，联动回归测试通过，客户端联动仍待验收。YiboCurrency 已作为可选公共 API 调用方。

> 仓储视图实施进度：容量快照、只读汇总接口、Core 页面角色浏览与物品 Tooltip 已按 [概念图](Media/YiboVault-Storage-Tooltip-Concept.png) 实现并通过本地 Lua 校验；仓储页与容量展示已获用户确认，Tooltip 的基本显示与数量汇总已获客户端截图验证。新版 Tooltip 行布局与服务器范围设置已通过本地检查，尚待客户端复核。

`0.2.0-test.13-api1` 将 Public API 版本加入插件显示版本与发布包文件名；功能版本和 `Addon.API_VERSION` 仍分别维护。`0.2.0-test.12` 新增 `items.personal-counts` v1 能力与 `GetPersonalCounts` 批量计数接口。个人背包、个人银行按来源独立返回数量与扫描状态；运行时索引跨帧建立，物品代币悬停无需遍历完整物品记录。接口形状及待就绪事件见 [Public API v1 契约](../Docs/YiboVault-Mail-API-v1-契约.md)。

`0.2.0-test.14-api1` 扩展 `GetPersonalCounts`，按扫描状态返回个人装备来源的物品数量，供货币余额合并已装备代币；API 仍为 v1，既有调用方可忽略新增字段。

运行 `_NonRelease/Tools/Build-ReleasePackages.ps1` 在仓库根目录 `Builds/` 生成 `YiboVault-v<功能版本>-api<API版本>.zip` 与同名前缀的 `-github.zip`。脚本会校验 TOC、Lua 常量和包名一致；普通包只含游戏加载文件及 TGA 图标，GitHub 包含公开文档与设计资源。

YiboVault 是 Yibo 系列的账号物品缓存与查询服务。首轮实现顺序、职责边界及验收门见：

- [联合实施计划](../Docs/YiboCore-Vault-Mail-实施计划.md)
- [产品边界与开发路线图](../Docs/YiboVault-产品边界与开发路线图.md)
- [Public API v1 契约](../Docs/YiboVault-Mail-API-v1-契约.md)
- [阶段 0 客户端验证记录](_NonRelease/Docs/Stage0-客户端验证记录.md)
- [阶段 0 契约烟雾测试](_NonRelease/Tests/Stage0ContractSpec.lua)
- [阶段 0 非发布客户端探针（按需诊断）](../_NonRelease/YiboStage0Probe/README.md)
- [Core API v6 增量接入指南](../YiboCore/Docs/API-v6-业务插件增量接入指南.md)
- [阶段 1 客户端首轮验证记录](_NonRelease/Docs/Stage1-客户端首轮验证.md)
- [仓储视图与物品悬停规则](Docs/仓储视图与物品悬停规则.md)

正式 Slash 命令已完成全工作区占用检查并冻结为 `/yva`。

## 阶段 1 已实现范围

- `YiboVaultDB` 保存按角色、来源位置分区的背包、装备、个人银行与 AH 快照，以及按公会/页签分区的公会银行快照；不写入 `YiboCoreDB`。
- 登录/进入世界时初始化全量采集；背包在 `BAG_UPDATE_DELAYED` 后按脏 bag 更新；装备在装备变化事件后完整重扫 `1..19` 槽。
- `YiboVault.Items` 提供 API v1 能力检查、范围查询、来源状态、revision 和变更事件；个人银行与 AH 能力仅在对应窗口打开并成功扫描后产生已知快照。
- 查询调用规则已冻结：省略范围只查当前角色；账号和服务器范围排除 Core 隐藏角色；显式角色 ID 可查隐藏角色。覆盖状态统一放在持有者的 `locations` 中；非法参数返回 `nil, errorCode`，不伪装成空库存。详细结构见 API 契约。
- `/yva scan` 重扫当前角色背包与装备，`/yva status` 仅在当前缓存有扫描错误时显示错误。正常扫描不在聊天窗口发送通告。Broker 与插件列表统一使用 `Media/YiboVaultIcon-v2.tga`，由游戏界面按实际控件尺寸缩放显示；完整 PNG 尺寸组与可编辑 SVG 母版也保存在 `Media/`。
- Core 负责设置工作台壳、账号页面和角色缓存清理；Vault 使用单一仓储页，顶部按物品名称或 ID 搜索，左侧持有者列表与右侧物品格同步筛选。左栏每个公会只显示一行；角色固定显示五个来源标签，公会固定显示八个页签，未扫描标签置灰且不可点击。
- 角色按背包、邮件、个人银行、拍卖、装备浏览；公会共享库存按公会页签单独列出。Vault 保存并提供已扫描容量、空位及可识别的包名称/大小组成摘要，Core 继续负责统一页面壳与角色范围。
- 原生物品 Tooltip 追加 Vault 的缓存合计、角色来源图标与公会页签分布。所有角色与公会均保留成功保存过的数量：登录、重载、关闭窗口或刷新失败不隐藏历史快照；只有没有可用快照的来源以 `~` 表示未知，部分邮箱的数量保留并以 `+` 标识下限。主窗口仍展示快照状态，历史来源标为“上次缓存”。悬停复用只读物品查询，服务器范围可在 Vault 业务设置中选为当前或所有服务器，角色准入与排序沿用 Core。
- `/yva open` 打开统一账号视图中的物品总览页；Core 管理的 Broker/小地图入口也指向同一页面。

## 仓储容量接口

`YiboVault.Items:HasCapability("storage.summary", 1)` 已开放。`Items:GetStorageSummary(scope)` 是公共只读接口，`scope` 与 `Items:Query` 相同；完整字段与调用规则见 [API v1 契约](../Docs/YiboVault-Mail-API-v1-契约.md)。结果包含 `characters` 与去重后的 `guilds`；返回有完整扫描记录的角色与公会，也保留可验证的旧版公会页签作为陈旧快照。每个区域有已记录的 `locations`，以及可读取时的 `totalSlots`、`freeSlots`、`completeCapacity`。单位置 `capacity` 可包含 `bagName`、`bagType`。无法可靠读取的容量字段保持 `nil`，不从物品数量推算空槽；`completeCapacity=false` 表示容量数字只覆盖有数据的部分位置。

同内容、同容量、同状态重复扫描不会递增修订；空位、页签名称或覆盖状态变化会在快照提交后递增修订并发出 `VAULT_ITEMS_CHANGED`。

## 拍卖行采集

- 打开 AH 后自动调用本人上架查询；任意页签均可触发，不要求切到“取消”。
- 仅在 `OWNED_AUCTIONS_UPDATED` 响应后提交整份本人上架快照；关闭期间的空返回不会覆盖已有数据。
- 使用 `GetNumOwnedAuctions` 与逐条 `GetOwnedAuctionInfo` 读取本人上架；首次扫描完成后，拍卖行打开期间的后续更新事件仍会刷新快照。逐条记录缺失或读取期间数量变化时保留已有快照。
- 仓储页的全局搜索包含 AH 上架物品；角色可在“拍卖上架”储存区查看命中记录，AH 仍由查询 API 与实体库存分开统计。
- 客户端扫描、重复打开和当前角色明细验证见[阶段 1 客户端首轮验证记录](_NonRelease/Docs/Stage1-客户端首轮验证.md)中的“AH 正式接入客户端初测”。
