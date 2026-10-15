# YiboCore

当前工作树版本：**1.12.6**。统一矩阵预算已通过离线回归，用户于2026-10-16确认实机检查无问题；尚未打包发布。 公共API仍为13，提供 `account-surface-budget:2`。

1.12.5 / API13发布 `character-cleanup:2`，用于动态所有者留存与带时间上下文的延后清理；与Builds1.5.0配套，旧消费者保持兼容。见[清理v2契约](Docs/API-v13-角色清理v2.md)。

1.12.4工作树 / API13工作树已停止货币业务采集，Currency0.9.1工作树通过公开接口导入旧快照并接管新存储。旧Core货币记录冻结保留，不自动清理；需配套升级，见[货币迁移记录](../YiboCurrency/Docs/货币数据归属迁移-实施与验收记录.md)。Core新增[通用档案字段与清理所有者能力](Docs/API-v13-档案业务字段与清理所有者.md)，不直接读取业务存档。

1.12.4 / API13 工作树已将声望采集和新快照存储交给 YiboReputation 1.7.1。旧 Core 声望快照冻结保留，通过现有公开读取接口供一次性导入；请配套升级 Reputation，旧版只会显示冻结数据。实施与待验收范围见 [声望迁移记录](../YiboReputation/Docs/声望数据归属迁移-实施与验收记录.md)。
当前工作树 **1.12.1 / API13** 增加可声明的悬停角色范围，旧页面默认仍为前20名；Mail 1.2.13 按需保留全部有效角色。见 [悬停角色范围契约](Docs/API-v13-悬停角色范围.md)。

工作树新增 **1.12.0 / API v13 / localization:1**：YiboCore 已支持中英文界面适配与语言切换。Core 常规设置 → 通用 → 插件语言，可选择跟随客户端、中文或 English；选择后重载界面生效，缺失英文资源会回退中文。该支持覆盖 Core 自身界面；业务插件正按区域渐进接入，尚未迁移的文字可能仍为中文。当前工作树尚未发布，客户端验收状态见 [实施记录](../Docs/Core系列中英文客户端适配-实施与验收记录.md)；语言服务契约见 [API v13 语言服务](Docs/API-v13-语言服务.md)。

## Public overview / 对外说明

**English.** YiboCore is the shared account window, character directory, and settings framework for Yibo WoW addons. It keeps identity, realm scope, sorting, settings, and entry lifecycle consistent across registered pages. Each business addon owns its own collected data and rules; Core supplies the shared framework and versioned capability contracts. YiboCore's interface supports Chinese and English, with an account-wide language setting for following the client language or choosing Chinese or English; changes take effect after a UI reload. Business addons are migrating their own text progressively, so untranslated addon content may remain in Chinese.

**中文。** YiboCore 为 Yibo 系列提供统一账号窗口、角色目录与设置工作台，统一管理角色身份、服务器范围、排序、设置和入口生命周期。业务数据与规则仍归对应插件所有；Core 提供共享框架及带版本声明的能力契约。YiboCore 界面支持中文和英文，可在账号级语言设置中选择跟随客户端、中文或 English，重载界面后生效。业务插件的自有文本正逐步适配，尚未迁移的内容可能仍显示中文。

### Business addons / 业务插件

以下插件在 TOC 中声明依赖 YiboCore：

- [YiboAltoBoss](https://www.curseforge.com/wow/addons/yiboaltoboss) — Boss and instance-lockout tracking；首领与副本锁定。
- [YiboBuilds](https://www.curseforge.com/wow/addons/yibobuilds) — Character builds；角色构筑。
- [YiboCrafting](https://www.curseforge.com/wow/addons/yibocrafting) — Recipe records；专业配方记录。
- [YiboCurrency](https://www.curseforge.com/wow/addons/yibocurrency) — Account currencies；账号货币。
- [YiboLegendary](https://www.curseforge.com/wow/addons/yibolegendary) — Legendary progress；传说装备进度。
- [YiboMail](https://www.curseforge.com/wow/addons/yibomail) — Mailbox tools；邮件管理。
- [YiboQuestBlocker](https://www.curseforge.com/wow/addons/yiboquestblocker) — Quest blocklists；任务屏蔽。
- [YiboReputation](https://www.curseforge.com/wow/addons/yiboreputation) — Reputation tracking；声望追踪。
- [YiboTodo](https://www.curseforge.com/wow/addons/yibotodo) — Account to-do tracking；账号待办。
- [YiboVault](https://www.curseforge.com/wow/addons/yibovault) — Item inventory search；物品库存搜索。

以下插件的基础功能独立运行，YiboCore 提供可选增强：

- [YiboAutoOpen](https://www.curseforge.com/wow/addons/yiboautoopen) — Container opening；容器自动开启。
- [YiboBeastPaths](https://www.curseforge.com/wow/addons/yibobeastpaths) — Hidden hunter-pet map routes；隐藏猎人宠物路线。
- [YiboMounts](https://www.curseforge.com/wow/addons/yibomounts) — Mount-source tooltips；坐骑来源提示。

[YiboCurrency](https://www.curseforge.com/wow/addons/yibocurrency) 可选使用 [YiboVault](https://www.curseforge.com/wow/addons/yibovault) 库存数据；YiboVault 可选使用 [YiboMail](https://www.curseforge.com/wow/addons/yibomail) 的邮件快照。TaskHub 当前在仓库工作树中，尚无公开 CF 页面，发布后再加入公开插件列表。

Core 的特点是让多个业务插件共用账号与角色管理，同时保留各自的数据所有权。玩家少切换分散的界面；插件作者无需重复实现角色目录、排序、设置与入口。Core 不追踪具体业务进度，跨插件集成按公开能力契约和版本协商启用。

下一步 CF 首页稿见：[双语说明草稿](../Docs/Publishing/CurseForge-2026-10-10/descriptions/YiboCore.md)。标题、摘要、分类和依赖建议见[集中整理索引](../Docs/Publishing/CurseForge-2026-10-10/README.md)。

Yibo WoW 插件的共享运行时、角色档案与账号视图框架。

当前已发布版本为 **1.11.0 / API v12**，提供 [业务项目主动添加](Docs/API-v12-业务项目主动添加.md) / business-item-actions:1；保留 API v11 能力，并提供 `business-providers:1`、多来源注册与 `Contracts:List`，契约见 [API v11 跨业务 Provider](Docs/API-v11-跨业务Provider.md)。O4 按真实展示需求补齐 [角色准入通知](Docs/API-v11-角色准入通知.md) / `account-character-admission:1`。Todo 1.1.4 两项来源与 TaskHub 0.3.1 四个展示面已接入；Mail 1.2.6-api1 输出新邮件查看提醒。359 项集成与展示及既有 Service 回归通过，详见[复核记录](../Docs/行动中心-新邮件语义与角色显示复核.md)。

2026-10-10 新增 [轻量角色身份](Docs/API-v11-轻量角色身份.md) / character-identity:1，TaskHub、Todo 与 AltoBoss 目标链路已接入，避免高频完整角色深复制。详见 [性能修复记录](../Docs/任务链-性能异常修复-2026-10-10.md)。

渠道包 v1.9.0-api10 合并 api9 与 api10，未独立发布 v1.8.0-api9。业务插件后续追赶须同批核对并补齐两代适用项，接入与验证分别登记于 [公共能力迁移台账](Docs/Core-公共能力迁移台账.md)；最低 API／能力检查仍按实际使用范围声明。

O5 在原 API v11 Provider 契约下接入 Mail 邮件待收取，共三个来源、两个业务所有者。O4／O5 联合复核新增 [视图可用高度](Docs/API-v11-视图可用高度.md) / account-surface-budget:1，由 TaskHub 0.2.1 接入；Mail 1.2.4-api1 修复同内容重扫后的恢复通知，283 项集成／展示检查通过，见 [联合记录](../Docs/行动中心-O4-O5-联合验收与修复.md)。用户 0.2.0 截图已复核，修复后的客户端待验收。

此前渠道版本 `1.9.0`（API v10）的能力基础包括：

- API 版本与插件注册
- 能力查询与 Core 内部事件
- 最小业务 Service 注册、发现、版本化调用和隔离通知（business-services:1）
- `YiboCoreDB` 的 Schema 版本和迁移
- 统一角色身份、旧角色键别名与导入接口
- 公共角色／联系人名称格式化：原名／短名、同服省略服务器与完整名称
- 通用角色档案：阵营、种族、公会、金钱、已知货币、地点、装等、专精、专业与数据可用性
- 统一账号视图、角色目录、页面/字段可见性设置
- 统一角色排序：最近登录、名称、等级、自定义顺序、当前角色置顶与页面级覆盖
- 统一单角色缓存删除：当前角色保护、跨插件角色级清理、延迟重试与旧缓存防复活
- 页面级业务角色准入与持久化范围状态 context
- Core 统一管理小地图、外部 Broker 和内置条三处入口；LDB 内置，信息条默认关闭，三处可独立选择
- 等级表达式解析
- 窗口命令：`/yco`、`/yco settings`

Core 不保存任务、Boss、收藏等业务状态，也不接管业务插件的 SavedVariables；插件只向账号视图注册自己的页面、字段、摘要和交互。

当前能力、数据归属、接入规范与多插件协作约定见：[Core 0.3 统一协作与改造计划](Docs/Core-0.3-统一协作与改造计划.md)。[跨插件账号行动项与角色匹配方案（待实现）](Docs/Core-跨插件账号行动项与角色匹配方案.md)是后续规划，当前 Core 尚未提供此能力。统一角色排序见：[统一角色排序实施计划](Docs/Core-统一角色排序实施计划.md)；缓存角色删除见：[缓存角色删除实施计划](Docs/Core-缓存角色删除实施计划.md)。历史更新记录见：[CHANGELOG.md](CHANGELOG.md)。

## Public API

公共能力的 Core 实现状态、业务插件接入进度与待迁移范围见：[公共能力迁移台账](Docs/Core-公共能力迁移台账.md)。

```lua
local compatible = YiboCore:CheckAPIVersion(6)
local character = YiboCore.Characters:GetCurrent()
local allCharacters = YiboCore.Characters:GetAll()
-- Core1.12.4工作树: legacy import only; live balances belong to Currency.
local economy = YiboCore.DataDomains:Get(character.id, "economy")
YiboCore.AccountView:RegisterPage("YiboNewAddon", pageDefinition)
YiboCore:RegisterSettingsPanel("YiboNewAddon", {
  id = "YiboNewAddon", title = "新插件设置", CreateSettingsPanel = function(parent, host) end,
})
```

API v6 保持 API v5 向后兼容。`RegisterSettingsPanel` 只向统一设置工作台注册面板，并按插件技术名排序；它不会创建账号页、显示与入口配置、Broker 或小地图入口。v6 的增量接入、同一范围构造及公共业务 API 边界见：[API v6 业务插件增量接入指南](Docs/API-v6-业务插件增量接入指南.md)。`Profile:Get()` 与 `CHARACTER_PROFILE_UPDATED` 仅为 0.6.x 的旧插件兼容层；新功能应读取 `DataDomains`，并在确有 Core 中性数据依赖时订阅 `DATA_DOMAIN_UPDATED`。

依赖 Core 的业务插件必须在 `.toc` 中声明 `## RequiredDeps: YiboCore`，并保留自身的业务 SavedVariables。Core 不接管业务数据；插件只注册页面、摘要和交互。

业务页面必须保持 `context.characters` 的输入顺序，不得在页面刷新阶段再次排列角色。Core 会依次应用隐藏、页面范围、业务准入和有效排序；悬停预览再从同一结果中截取前 20 名角色。

角色缓存只能在 Core 角色档案中逐个手动删除，当前登录角色不可删除。业务插件通过 `Core.CharacterCleanup:RegisterOwner` 清理自己的角色级快照，并必须保留账号共享数据。系统永久不提供批量删除、按时间自动清理、游戏角色存在性判断、转服角色合并或撤销删除。

## 发布打包

运行仓库根目录 `Tools/Build-ReleasePackages.ps1 -Addon YiboCore -Target Mists`，或原 `_NonRelease/Tools/Build-ReleasePackages.ps1` 兼容入口，会在仓库根目录 `Builds/` 生成带顶级 `YiboCore/` 目录的 CF 目标安装包与一份全目标 GitHub 源码归档。CF 包保留目标 TOC、运行时代码、生成的目标插件版本索引、`.tga` 纹理与第三方通知；GitHub 归档保留公开源码、文档和资源，排除非发布与构建输出。当前仅配置 Mists；其它目标请求明确停止。

CF 包名按目标、插件版本、公开 API 排列，例如 `YiboCore-mists-v1.12.1-api13-curseforge.zip`；GitHub 包为 `YiboCore-src.<源码及配置摘要>-github.zip`。包内 `YiboReleaseManifest.json` 记录源码标识、版本、目标与验证状态。`-Channel CurseForge` 或 `-Channel GitHub` 可单独构建渠道，`-ValidateOnly` 只校验并返回计划。旧包按对应产物流移入 `Builds/Archive/YiboCore/`，保留其它目标和渠道的最新包。本地化报告仍保存在 `_NonRelease/Localization/Build/`，不随包分发；实际构建生成报告，ValidateOnly 不生成。正式命名与当前支持边界见 [目标与发行标识规范](../Docs/多版本目标与发行标识规范.md)。

公共 API v7 新增基础输入、物品解析与选择器，保持 v5/v6 兼容。见 [API v7 物品选择与基础输入](Docs/API-v7-物品选择与基础输入.md)。配套版本为 Core 1.6.1＋Currency 0.9.1。

公共 API v8 新增 `Characters:FormatName(identity, options)` 和 `character-name-format:1`，保持旧 API 与业务表头调用兼容。接入与验证见 [API v8 公共名称格式化](Docs/API-v8-公共名称格式化.md)。

公共 API v9 新增最小 `business-services:1`，并改进页面刷新合并与物品解析器请求调度。契约见 [API v9 业务服务与刷新](Docs/API-v9-业务服务与刷新.md)。API v10 新增页面首次打开泡泡提示，见 [API v10 首次打开界面提示](Docs/API-v10-首次打开界面提示.md)。

内置信息条设置位于 Core 常规设置 → 信息条。“显示与入口”选择各入口；“信息条”开启总开关、调整外框、背景配色与透明度，并选择按钮前移／后移或恢复默认；也可直接拖动条上图标调序。按钮名称采用页面名称并移除作者前缀。关闭后保留选择、外观和顺序。解锁后通过左侧把手拖动。外部 Broker 停用后图标可能需在外部条隐藏或重载。工作树接口见 [API13 入口三通道与内置条](Docs/API-v13-入口三通道与内置条.md)，客户端验收状态见 [实施记录](Docs/Core-内置LDB与信息条-实施与验收记录.md)。

点击 Core 常规设置：语言和通用悬停选项。显示与入口管理页面、入口和字段；信息条作为左侧独立页面管理外观、位置及排序；插件列表按技术名排序，每插件一行，完整展开并按需纵向滚动，仅有业务设置的插件也会列出并说明适用范围。

## 图标资源（2026-10-14）

当前图标为 `Media/YiboCoreIcon`：默认TGA为64px，插件列表使用128px TGA；PNG提供16/24/32/64/128/512/1024px，母版为312px透明位图。版本、统一缩放和验证范围见[系列资源记录](../Docs/Design/Yibo系列Logo-20261014/README.md)。

![YiboCore 图标](Media/YiboCoreIcon-128.png)

## 1.12.2 / API13（2026-10-14）

提供 business-item-actions:3 的可选 compactTooltip，兼容既有绑定；用于 AltoBoss 2.6.1 的精简副本提示。部署 AltoBoss 目标操作增强时请同时更新 Core。静态检查通过，真实客户端交互与英文验收待完成。

## 工作树：动态账号字段（2026-10-15）

Core1.12.4 / API13新增 `account-dynamic-fields:1`。业务可通过只读 `GetFieldDefinitions` 回调提供运行时变化的显示与悬停选项，Core统一读取、校验并保存主表选择；静态字段注册保持兼容。Currency0.10.0用于自定义代币目录，离线验证通过、客户端待验，见[公开契约](Docs/API-v13-动态账号字段.md)。
