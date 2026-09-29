# Yibo 插件 API 与能力总览

> 文档状态：仓库现状盘点（2026-09-28）。
>
> 本文区分“当前已实现”和“方案规划中”。Lua 模块中的内部函数不自动视为稳定公共 API；除特别标明外，其它插件目前没有承诺给第三方调用的版本化接口。

## 1. 插件与职责

| 插件 | 当前能力 / 负责的数据 | Core 集成与主要接口 | 对外 API 状态 |
|---|---|---|---|
| **YiboCore** | 角色目录、角色身份与基础事实、账号视图、统一入口、设置工作台、缓存清理和插件注册 | Public API v6；详见下文 | Yibo 系列公共运行时 API |
| **YiboAltoBoss** | 副本锁定、首领击杀/重生追踪、历史样本与账号统计 | Core 账号页面、锁定页面、入口、角色缓存清理 | 业务快照仍由插件持有；无已承诺的稳定消费者 API |
| **YiboAutoOpen** | 玩家配置的物品 ID 目录、背包扫描与受限自动开包队列 | 可选接入 Core API v6 设置页；Core 不可用时使用命令模式 | 未提供库存历史/跨角色库存 API；其 ID 目录仅供自身开包逻辑使用 |
| **YiboBeastPaths** | 狩猎路线、路线渲染与地图/小地图导航；支持 Mists 与 Mainline 客户端 | 普通路线功能独立运行；Core v6 下可选注册维护/调试界面 | 路线资源和模块是插件内部实现；未声明通用路线消费者 API |
| **YiboBuilds** | 角色天赋/专精构筑、装备与附魔/宝石/插槽效果快照和账号对比 | Core 账号页面、入口、设置、角色清理 | 构筑快照由插件维护；无已承诺的稳定消费者 API |
| **YiboCurrency** | 账号货币、货币上限/周常进度、可监控物品数量和角色对比 | Core 账号页面、入口、统一设置；向 Core 货币目录登记定义 | 目前无供其它插件读取的完整历史货币/物品 API；Core 的 CurrencyCatalog 是展示/定义目录，不是业务快照存储 |
| **YiboLegendary（传说之路）** | 角色阶段进度、任务/声望/货币等证据快照、账号路线对比、手动证据校正 | Core 页面、入口、悬停预览、统一设置、角色缓存清理；读取 Core 中性领域事实 | 路线与快照归插件 SavedVariables；无已承诺的稳定消费者 API |
| **YiboMounts** | 坐骑来源 Tooltip、收藏状态显示与诊断信息 | 当前 TOC 未声明 YiboCore 依赖；Core 可用时可选注册设置面板 | 未声明稳定消费者 API |
| **YiboQuestBlocker** | 阻止或筛选任务接受流程，提供任务/规则配置及诊断 | Core 页面、入口、设置、角色缓存清理；另含兼容入口组件 | 阻止任务接受是副作用型能力，不能当作通用任务数据 API；未声明稳定消费者 API |
| **YiboReputation（声望之路）** | 角色声望事实的账号矩阵、声望目录/过滤、最多 10 项快速监控和预览 | Core 收集并保存 `reputation` 领域；插件注册页面/入口并消费 `DATA_DOMAIN_UPDATED` | 声望事实来自 Core；监控列表和显示偏好归插件设置；目前没有物品库存监控 API |
| **YiboTodo** | 账号待办与活动状态、日常/周常/专业冷却/特殊活动观察、业务动作 | Core 页面、入口、设置、角色清理；读取 Core 角色/领域并按业务事件更新自身快照 | 内部 Provider Registry 只服务 YiboTodo 内部；不是跨插件公共 API |
| **YiboMail（阶段 0）** | 邮件快照、到期/收件状态、邮件物品来源和收发辅助 | 使用现有 Core 页面/入口/设置；直接提供只读邮件物品来源 API 供 Vault 等消费者使用 | Public API v1 契约已形成冻结候选；尚无可调用运行时 |
| **YiboVault 1.0.0** | 背包/装备/银行/公会银行/AH/邮箱附件缓存、搜索与物品 Tooltip | 依赖 Core API v6；独立采集可见邮箱附件 | `Items` API v1 提供查询、容量摘要和个人库存批量计数；YiboCurrency 可选调用 |

> 插件功能以仓库当前主线 `.toc` 和运行时代码为准；`dist/`、`Builds/` 等历史/打包副本不作为当前 API 来源。

## 2. YiboCore Public API v6

Core 是共享运行时与通用角色事实层，不是所有业务数据的集中数据库。业务插件仍保存自己的业务快照和设置。

### 2.1 注册、能力与生命周期

- `YiboCore:CheckAPIVersion(version)`：检查最低 Public API 版本。
- `YiboCore:RegisterAddon(name, metadata)` / `GetRegisteredAddons()`：登记和查询插件。
- `YiboCore.Capabilities`、`HasCapability(name, minimumVersion)`、`GetCapabilityVersion(name)`：可选能力协商。
- `YiboCore.Events:Register(eventName, owner, callback)` / `Unregister(...)`：订阅 Core 生命周期和数据变化事件。
- `YiboCore:ClaimResource(...)`：声明唯一资源 ID，避免注册冲突。

### 2.2 角色和中性事实

- `YiboCore.Characters:GetCurrent()`、`GetAll()`：当前角色和 Core 角色目录。
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
- `YiboCore.UITheme`：账号矩阵、表格、滚动区域和预览等共享 UI 原语；遵循 API 接入指南，不复制 Core 的窗口/入口实现。

### 2.4 版本兼容

当前 Core 声明 `API_VERSION = 6`。API v6 对 v5 保持兼容；新能力应通过可选方法或 Capability 增加，不改变既有注册接口含义。子插件应按实际依赖设置 `requiredAPI`，不要仅根据 Core 显示版本号猜能力。

参考：[YiboCore README](../YiboCore/README.md)、[API v5 业务插件接入指南](../YiboCore/Docs/API-v5-业务插件接入指南.md)。

## 3. 跨插件数据消费原则

1. **数据由业务所有者保存。** 谁采集、定义业务语义，谁持有 SavedVariables 和迁移策略。
2. **消费者直接调用提供者的稳定只读接口。** 查询结果返回副本/投影；不得修改提供者数据或依赖其私有 DB 结构。
3. **Core 管中性事实与共用机制。** Core 负责通用角色事实、账号 UI 和插件生命周期。物品来源发现、聚合与查询属于 Vault；其它业务查询也不要求经过 Core。
4. **领域协议匹配领域。** Mail→Vault 需要物品来源协议；声望之路读取物品库存时应消费 Vault 的物品查询 API。Todo 等其它消费者也可直接使用相应业务提供者接口。
5. **状态与缺失必须可区分。** 未加载、未采集、不可用、陈旧、错误、已知空结果不可混为一谈；缓存数据不能被描述成实时完整状态。
6. **可选消费者不应成为硬依赖。** Vault 无 Mail 时使用自有精简邮箱附件快照；未扫描的邮箱保持未扫描状态。Mail 上线后按角色择一来源，具体状态由协议契约定义。
7. **公开 API 需有契约。** 稳定 ID、参数、结果 schema、版本/能力、状态语义、变更通知和兼容承诺都应有文档。插件当前导出的全局命名空间或内部 Lua 模块并不自动构成兼容承诺。

## 4. 规划中的物品数据链

```text
YiboMail（邮件采集与邮件 SavedVariables）
       └─ 公开只读的 mail 物品来源 API ─┐
                                        ↓
YiboVault（来源适配、各容器缓存与查询 API）
       ├─ 提供物品 ID/身份、数量、角色、容器、来源、状态与 revision
       └─ YiboReputation / YiboTodo / 其它消费者按需查询
```

Core 为这两个插件提供角色范围、页面、入口和设置能力，不复制邮件或库存快照。Vault 通过 Mail 的公开接口可选地接入邮件来源；消费者不能读取 YiboMailDB 或 YiboVaultDB 私有结构。开发顺序与阶段门见 [Core、Vault、Mail 联合实施计划](YiboCore-Vault-Mail-实施计划.md)。

### 4.1 Vault 物品查询 API v1

Vault 的 `Items:Query`、`GetSourceState`、`GetStorageSummary`、`GetPersonalCounts`、能力检查、revision 和事件已有运行时；调用范围、参数错误、覆盖状态及事件提交顺序见 [YiboVault / YiboMail Public API v1 契约](YiboVault-Mail-API-v1-契约.md)。返回数据为副本；空结果只表示当前查询缓存无匹配记录，不能推断所有角色和容器都已采集。YiboCurrency 的物品代币矩阵按来源选用 Vault 已扫描的个人背包、银行和装备数量或 Core 有依据的旧值，不重复累计；邮件、拍卖和公会共享库存只作为来源明细。

### 4.2 规划状态

- `YiboMail` 仍是阶段 0 项目，尚无正式 TOC 或可加载运行时代码；Vault 已有正式 TOC、独立采集和查询运行时。
- Core 不新增物品来源注册表；Mail 来源接口与 Vault 的 Mail 适配器仍待实现。
- YiboReputation 目前的“监控”是声望 ID 快速监控，不是按 itemID 监控物品；如后续需要显示账号各角色库存，应消费 Vault API，而非重复扫描背包或把库存写入 Core。

## 5. 维护本总览

新增插件或公共 API 时，更新本文件对应表格，并明确标注：

- 已实现、可调用的稳定公共 API；
- 插件内部接口（无跨版本兼容承诺）；
- 仅在产品方案/路线图中规划的能力；
- 数据归属、状态语义和依赖关系。

不要从函数名推断 API 稳定性，也不要把产品目标写成已发布能力。
