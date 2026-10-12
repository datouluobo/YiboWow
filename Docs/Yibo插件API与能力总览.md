# Yibo 插件 API 与能力总览

> 文档状态：2026-10-12 工作树。Core **1.12.0 / API v13** 新增 [语言服务](../YiboCore/Docs/API-v13-语言服务.md) / localization:1，Core 公共界面已接入；TaskHub **0.6.0 / schema4** 的静态界面已接入 Core 中英文资源，客户端待验收。保留的 API v12 已提供 business-item-actions:1；九个来源的 action.targets v1 与 Task 的 action.demands v1 已接入。230项新目标检查及672项既有集成回归通过。TaskHub 尚未发布，详见 [实施与验证](行动中心-主动添加实施与验证.md)。
>
> 本文区分“当前已实现”和“方案规划中”。详细接口以版本契约为准，接入范围、最低版本、验证缺口和迁移状态以 [Core 公共能力迁移台账](../YiboCore/Docs/Core-公共能力迁移台账.md) 为准。内部 Lua 模块不自动构成公共 API。

O5 当前语义：每角色一条新邮件查看提醒，用户查看但未取走附件视为已处理；升级前库存建立基线。其它任务所需附件留待真实需求关联，当前没有该契约。详见 [新邮件与角色显示复核](行动中心-新邮件语义与角色显示复核.md)。

## 1. 插件与职责

| 插件 | 当前能力 / 负责的数据 | Core 集成与主要接口 | 对外 API 状态 |
|---|---|---|---|
| **YiboCore** | 角色目录、角色身份与基础事实、账号视图、统一入口、设置、缓存清理、Service／Provider 连接 | 工作树 Public API v13，保留 v9～v12，未发布；新增 localization:1 | business-providers:1／List 与 account-character-admission:1 已实现并验证；Todo／TaskHub 已接入 |
| **YiboAltoBoss** | 2.6.0 副本锁定、首领追踪、Task 刷取目录／精确进度与自动展示 | 基础 API5；可选 API11，经 Core 提供 boss.target-catalog、action.todo / planned-targets，消费 task.boss-targets | action.targets v1 已提供精确Boss目标；原目录／配置兼容接口保留，增强API12，客户端待验收 |
| **YiboAutoOpen** | 玩家配置的物品 ID 目录、背包扫描与受限自动开包队列 | 可选接入 Core API v6 设置页；Core 不可用时使用命令模式 | 未提供库存历史/跨角色库存 API；其 ID 目录仅供自身开包逻辑使用 |
| **YiboBeastPaths** | 狩猎路线、路线渲染与地图/小地图导航；支持 Mists 与 Mainline 客户端 | 普通路线功能独立运行；Core v6 下可选注册维护/调试界面 | 路线资源和模块是插件内部实现；未声明通用路线消费者 API |
| **YiboBuilds** | 角色天赋/专精构筑、装备与附魔/宝石/插槽效果快照和账号对比 | Core 账号页面、入口、设置、角色清理 | action.targets v1 宝石／附魔目标与实际应用评估；增强API12，客户端GUID待验收 |
| **YiboCurrency** | 账号货币、货币上限/周常进度、可监控物品数量和角色对比 | Core 账号页面、入口、统一设置；向 Core 货币目录登记定义 | action.targets v1 指定角色原生货币／金币阈值；增强API12，客户端待验收 |
| **YiboLegendary（传说之路）** | 角色阶段进度、任务/声望/货币等证据快照、账号路线对比、手动证据校正 | Core 页面、入口、悬停预览、统一设置、角色缓存清理；读取 Core 中性领域事实 | action.targets v1 最终获得目标，真实／明确人工证据；增强API12，客户端待验收 |
| **YiboMounts** | 坐骑来源 Tooltip、收藏状态显示与诊断信息 | 当前 TOC 未声明 YiboCore 依赖；Core 可用时可选注册设置面板 | 未声明稳定消费者 API |
| **YiboQuestBlocker** | 阻止或筛选任务接受流程，提供任务/规则配置及诊断 | Core 页面、入口、设置、角色缓存清理；另含兼容入口组件 | 阻止任务接受是副作用型能力，不能当作通用任务数据 API；未声明稳定消费者 API |
| **YiboReputation（声望之路）** | 角色声望事实的账号矩阵、声望目录/过滤、最多 10 项快速监控和预览 | Core 收集并保存 `reputation` 领域；插件注册页面/入口并消费 `DATA_DOMAIN_UPDATED` | action.targets v1 标准／友谊等级阈值，业务解释归插件；增强API12，客户端待验收 |
| **YiboTodo** | 账号待办与活动状态、日常/周常/专业冷却/特殊活动观察、业务动作 | Core 页面、入口、设置、角色清理；新任务输出另查 API v11 / business-providers:1 | action.targets v1 精确项目；action.todo旧来源契约保持，增强API12，客户端待验收 |
| **YiboMail** | 邮件快照、到期/收件状态、新邮件查看确认、可解析的成功发件在途附件、规则寄送和联系人辅助 | 工作树 1.2.7-api1，基础 API9 / mail.items v1.1；任务集成单独要求 API11 / business-providers:1 | mail.items v1.1 新增可选 GetTransfers；已扫描的匹配收件会结束在途投影；任务契约不变，客户端待验收 |
| **YiboTaskHub** | 0.5.0 账号任务／悬停／HUD／提醒及逐角色刷取计划、双向复制 | API11，经 Core 通用枚举 action.todo；提供 task.boss-targets，消费 boss.target-catalog；标签页、输入、设置与身份使用共享能力 | 0.5.0 / schema4：action.demands v1、目标管理与按目标评估；整体API12，客户端待验收 |
| **YiboVault** | 背包/装备/银行/公会银行/AH/邮箱附件与在途邮件投影、搜索与物品 Tooltip | 当前 TOC 1.2.1-api1；工作树最低 Core API v13；消费 `mail.items` v1.1 并注册 `vault.items` v1.1 | 在途数量单独提供，不计入角色已持有量；action.targets v1 角色／固定账号范围库存阈值，客户端待验收 |

> 插件功能以仓库当前主线 `.toc` 和运行时代码为准；`dist/`、`Builds/` 等历史/打包副本不作为当前 API 来源。

## 2. YiboCore Public API v11（保留 v9／v10）

Core 是共享运行时与通用角色事实层，不是所有业务数据的集中数据库。业务插件仍保存自己的业务快照和设置。

### 2.1 注册、能力与生命周期

- `YiboCore:CheckAPIVersion(version)`：检查最低 Public API 版本。
- `YiboCore:RegisterAddon(name, metadata)` / `GetRegisteredAddons()`：登记和查询插件。
- `YiboCore.Capabilities`、`HasCapability(name, minimumVersion)`、`GetCapabilityVersion(name)`：可选能力协商。
- `YiboCore.Events:Register(eventName, owner, callback)` / `Unregister(...)`：订阅 Core 生命周期和数据变化事件。
- `YiboCore:ClaimResource(...)`：声明唯一资源 ID，避免注册冲突。
- `YiboCore.Contracts:Register/Resolve/Call/NotifyChanged/Unregister`：API v9 / `business-services:1` 的单 Service 连接继续兼容；API v11 / `business-providers:1` 新增 kind=provider 和 `List`，按稳定来源枚举、过滤版本，复用隔离调用与通知。草案 business-contracts:1 不作为运行时能力检查。

### 2.2 角色和中性事实

- `YiboCore.Characters:GetCurrent()`、`GetAll()`：当前角色和 Core 角色目录。
- `Characters:FormatName(identity, options)`：API v8 / `character-name-format:1` 的原名、短名与服务器显示格式化；只返回显示文本，不能作为身份键或邮寄地址。旧 GetDisplayName 的兼容语义保留。
- `YiboCore.DataDomains:Get(characterID, domainID)` / `GetState(...)`：读取 Core 管理的领域快照及状态。
- 当前领域由 Core 自己采集和拥有，包括身份、经济、经济物品、装备、地点、专业、声望和专精等。`known`、`stale`、`unavailable`、`not-yet-scanned`、`error` 等状态不可互相当作零值。
- `DATA_DOMAIN_UPDATED`：领域变化通知，payload 按 `domainID` 过滤。业务插件不能直接修改领域快照。
- `YiboCore.CurrencyCatalog:RegisterCurrency/RegisterItem`：登记货币和相关物品的目录定义；目录登记不等于跨角色业务库存查询 API。

### 2.3 账号视图、入口、设置和清理

- `YiboCore.AccountView:RegisterPage(addonName, definition)`：注册业务页面；Core 管理统一窗口、角色范围、页面可见性和预览壳。`NotifyPageChanged(pageID)` 通知刷新，`Toggle(pageID)` 打开对应页面。
- `YiboCore.Entry:RegisterBusinessEntry(addonName, definition)`：注册 Core 管理的 Broker/小地图入口，关联对应账号页面。
- `YiboCore:RegisterSettingsPanel(addonName, definition)`：注册统一设置工作台的业务设置区。
- `YiboCore.CharacterCleanup:RegisterOwner(addonName, definition)`：注册删除角色缓存时清理插件角色级数据的回调。
- `YiboCore.LevelFilter:Validate(expression)`：校验 Core 统一的角色等级筛选表达式。
- API v11 / `account-character-admission:1`：角色隐藏及默认页面等级筛选有效变化后发出 `ACCOUNT_VIEW_CHARACTERS_CHANGED`；HUD 等独立展示订阅后重建准入，见 [契约](../YiboCore/Docs/API-v11-角色准入通知.md)。
- API v11 / `account-surface-budget:1`：页面尺寸测量前提供内容可用高度，扣除窗口壳、安全边界与悬停入口空间；TaskHub 0.2.1 已接入，见 [契约](../YiboCore/Docs/API-v11-视图可用高度.md)。联合复核累计 283 项检查通过，Mail 1.2.4-api1 同步修复重扫恢复通知；修复后的客户端待验收，见 [记录](行动中心-O4-O5-联合验收与修复.md)。
- `YiboCore.UITheme`：账号矩阵、表格、滚动区域和预览等共享 UI 原语；遵循 API 接入指南，不复制 Core 的窗口/入口实现。
- API v7 提供 `basic-input:1`、`item-resolver:1` 与物品选择；Core 1.7.1 / API v8 的 `item-picker:2` 扩展批量确认与保留输入，业务校验／执行仍归业务插件。
- API v9 的 `NotifyPageChanged(pageID)` 合并下一帧同页面通知，执行时复核可见性；`RefreshPage` 保留即时调用路径。
- API v10 / `account-view:2` 的可选页面字段 `firstUseTip` 提供首次打开提示；Core 概览、Builds、Reputation、Todo 已写入。后三者最低 API v10，游戏内与低版本停止专项验证待完成。

- API v12 / business-item-actions:1：全局手势、项目绑定、可见添加菜单及解绑，见 [契约](../YiboCore/Docs/API-v12-业务项目主动添加.md)。来源原基础版本保留的兼容例外见实施记录。

### 2.4 版本兼容

当前工作树声明 API_VERSION = 12，版本 1.11.0，未发布。新 Provider 接入检查 API v11 / business-providers:1；已有 Service 仍可声明 API v9 / business-services:1，首次提示检查 API v10 / account-view:2。业务按实际需要检查版本，Core 连接实现与业务接入分别记录。此前渠道 v1.9.0-api10 合并 api9／api10，追赶仍同批核对适用项；名称测试过期断言已在 O1 修复，其他客户端验证缺口见台账。

参考：[API v5](../YiboCore/Docs/API-v5-业务插件接入指南.md)、[API v6](../YiboCore/Docs/API-v6-业务插件增量接入指南.md)、[API v7](../YiboCore/Docs/API-v7-物品选择与基础输入.md)、[API v8 名称](../YiboCore/Docs/API-v8-公共名称格式化.md)、[API v8 批量物品](../YiboCore/Docs/API-v8-批量物品确认.md)、[API v9](../YiboCore/Docs/API-v9-业务服务与刷新.md)、[API v10](../YiboCore/Docs/API-v10-首次打开界面提示.md)、[API v11 Provider](../YiboCore/Docs/API-v11-跨业务Provider.md)。

## 3. 跨插件数据消费原则

1. **数据由业务所有者保存。** 谁采集、定义业务语义，谁持有 SavedVariables 和迁移策略。
2. **消费者经 Core 发现并调用公开业务契约。** 不直接绑定提供者全局对象、加载其 Lua 或访问 SavedVariables；查询返回副本／投影，操作由业务所有者校验执行。
3. **Core 管中性事实与共用机制。** Core 负责通用角色事实、账号 UI、生命周期和连接，不接管库存／邮件等业务数据；物品来源聚合与业务查询仍由 Vault 解释。
4. **领域协议匹配领域。** Mail→Vault 当前使用 `mail.items`，Currency→Vault 使用 `vault.items`。Reputation／Todo 后续需要库存时按实际契约经 Core 接入；不能推定当前已经提供其所有所需方法。
5. **状态与缺失必须可区分。** 未加载、未采集、不可用、陈旧、错误、已知空结果不可混为一谈；缓存数据不能被描述成实时完整状态。
6. **可选消费者不应成为硬依赖。** Vault 无 Mail 时使用自有精简邮箱附件快照；未扫描的邮箱保持未扫描状态。Mail 上线后按角色选择收件箱来源，并可额外提供不计入持有量的在途发件投影，具体状态由协议契约定义。
7. **公开 API 需有契约。** 稳定 ID、参数、结果 schema、版本/能力、状态语义、变更通知和兼容承诺都应有文档。插件当前导出的全局命名空间或内部 Lua 模块并不自动构成兼容承诺。

## 4. 当前工作树的物品数据链

```text
YiboMail（邮件采集与邮件 SavedVariables）
       └─ mail.items v1.1（Core.Contracts，收件快照 + 可选在途投影）─┐
                                        ↓
YiboVault（来源适配、各容器缓存与查询 API）
       ├─ vault.items v1.1（Core.Contracts）→ YiboCurrency
       └─ Reputation / Todo / TaskHub 等后续真实需求再接入
```

Core 为这些插件提供角色范围、页面、入口、设置和服务连接，不复制邮件或库存快照。Vault 经 Core 发现 Mail 的邮件来源，Mail 缺失／注销／主版本不兼容时保留独立基础扫描；提供方已注册但未就绪时等待采集，不开启第二轮扫描或当作空邮箱。当前状态语义与迁移验证见 [API v9](../YiboCore/Docs/API-v9-业务服务与刷新.md)，此前阶段安排见 [联合实施计划](YiboCore-Vault-Mail-实施计划.md)。

### 4.1 Vault 物品查询 API v1

Vault 的 `Items:Query`、`GetSourceState`、`GetStorageSummary`、`GetPersonalCounts`、能力检查、revision 和事件已有运行时；调用范围、参数错误、覆盖状态及事件提交顺序见 [YiboVault / YiboMail Public API v1 契约](YiboVault-Mail-API-v1-契约.md)。返回数据为副本；空结果只表示当前查询缓存无匹配记录，不能推断所有角色和容器都已采集。YiboCurrency 的物品代币矩阵按来源选用 Vault 已扫描的个人背包、银行和装备数量或 Core 有依据的旧值，不重复累计；邮件、拍卖和公会共享库存只作为来源明细。

### 4.2 已实现与待实现边界

- Mail、Vault 均有正式 TOC 和运行时；工作树服务接入尚未发布。RuntimePerformanceSpec、InboxReleaseSpec、MailProviderSpec、VaultIntegrationSpec 本轮重新运行通过；游戏内验收待完成。
- Core 提供通用 Service 与 API v11 Provider／List，不新建库存业务目录；Mail 来源接口与 Vault 适配已实现。action.todo 首项神纹布输出及 TaskHub 主页已通过 O2 自动化，客户端待验收；目标／需求协议待后续真实场景接入。
- YiboReputation 目前的“监控”是声望 ID 快速监控，不是按 itemID 监控物品；如后续需要显示账号各角色库存，应消费 Vault API，而非重复扫描背包或把库存写入 Core。
- Core API13 工作树已提供 localization:1，以及 account-entry:2 / builtin-entry-bar:1；内置 LDB 与三通道信息条代码、自动化完成，客户端待验收，未发布。入口契约见 YiboCore/Docs/API-v13-入口三通道与内置条.md；网络通讯协议仍属规划。

## 5. 维护本总览

新增插件或公共 API 时，更新本文件对应表格，并明确标注：

- 已实现、可调用的稳定公共 API；
- 插件内部接口（无跨版本兼容承诺）；
- 仅在产品方案/路线图中规划的能力；
- 数据归属、状态语义和依赖关系。

不要从函数名推断 API 稳定性，也不要把产品目标写成已发布能力。
