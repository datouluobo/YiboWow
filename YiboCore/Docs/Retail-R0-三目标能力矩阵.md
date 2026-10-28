# Retail R0：三目标能力矩阵

日期：2026-10-27。状态：**R0静态声明审查已冻结；R2当前实现与验收见下方更新。**

R5当前验收索引：R3的API13／12项最小公共契约不变；Retail32项、Mists33项、Forever33项为冻结实现声明，不能当作全部实机通过。Retail／Mists本轮指定包的干净安装、声明覆盖、reload／完整退出恢复与返回原环境已验；Forever实机保留待测。R5文档已收尾，整体未判定可发布，见[R5验收](R5-文档与台账收尾验收.md)。本页R0表格、机器基线与历史进度不改写。

后续进度：R1-01／02的Mists／Forever启动与存档保护代码、离线回归已完成，见[实施验收](R1-01-02-启动与存档预检实施验收.md)；显式能力集合与版本未变，Retail仍未提供。下文源码基线和声明统计保持R0时点。

R1-03／04更新：身份／位置读取改用内部Client、Mists采集器及目标字段配置已迁移，失败保留旧快照；[实施与新路径](R1-03-04-角色身份与数据域实施验收.md)已有代码和离线证据，显式能力仍两端各33项、并集34项，Retail未接入。下表注册路径以R0历史快照展示，最新加载路径以本阶段记录与Results为准。

R1-05／06更新：公共物品、光标／焦点、插件状态、宏图标和Popup／战斗原生查询已经目标surface绑定；192项专项及双目标离线回归、统一构建通过，扩展旧夹具与新增实机仍待，见[实施验收](R1-05-06-公共物品与UI原生边界实施验收.md)。能力版本和Retail未接入状态保持。

R1-07／08更新：目标目录／帮助与期望清理owner已按目标策略生成，历史owner与pending重放保留；注册契约、只读角色缓存与窗口同源预览已复核，修复页面注销重建和活动预览收尾。389＋465项专项及两端回归通过，旧夹具／新增实机待验；见[最新验收](R1-07-08-目标元数据与通用契约实施验收.md)。Retail仍未接入，YBP仅补记已有路线产品元数据。

R1-09更新：文案与[当前兼容／失败契约](API-v13-R1共享底座兼容与失败契约.md)收尾完成，新增6个双语资源；791项语言／失败专项及双目标回归通过，见[最新验收](R1-09-文案与契约文档收尾验收.md)。能力版本、加载图和业务接入不变，新增客户端与最终包仍待；下表继续保留R0历史声明路径。

R2当前更新：Retail0.1.0／API13／schema11／Interface120105已接入，标准Retail源清单与实测Mainline开发别名一致；仅identity目录域和身份／等级两字段，32项公共能力，未提供专业／日历／位置等采集。Mists／Forever各33项及能力版本保持，并集34项。基础Retail源码实机与三目标离线／构建证据见[当前验收](R2-01-02-Retail目标与构建实施验收.md)；下表继续保留R0历史路径与当时未实现状态，不能当作当前能力判定。

范围依据[实施方案](Retail-共享底座适配实施与验收方案.md)；逐文件结论、证据及改造编号见[R0 审查与改造清单](Retail-R0-共享模块审查与改造清单.md)，机器基线见[源码基线](Retail-R0-源码基线.json)。

R3当前更新：既有12项能力已完成面向离线兽栏的三目标合成消费者验证，2463项通过，无能力／API／运行字节变化。最低要求及方法固定到[公共支持契约](API-v13-YBP离线兽栏公共支持契约.md)，验证与待验见[R3验收](R3-YBP离线兽栏公共契约实施验收.md)。YBP真实接入状态保持待实施，下表仍为R0冻结矩阵。

## 1. 读法与统计

- “声明 vN”指该目标真实 TOC 加载文件含对应能力注册，不代表全部路径已经实机通过。必要初始化成功且 Core 就绪后，消费者才可使用。
- Retail 当前没有 Core 目标清单：下表每一项当前均为**未提供**；Retail 列表示本轮后续实施结论，不是完成状态。
- 两端各声明 33 项：32 项共用，Mists 独有 `calendar-day-query:1`，Forever 独有 `profession-profile:1`；有效声明并集为 34 项。
- “共享适配”要求适配并验证通用机制，即使 YBP 首期未直接使用；其中物品、光标、图标、插件状态等原生边界单独完成适配。不会因此增加 Retail 专业、装备、日历或宠物采集器。
- YBP 列“必需候选”是支持链路的审查基线；最终消费要求按实际功能固定，不能把传递依赖全部机械变成业务插件的能力检查列表。
- 消费者列来自非测试业务 Lua 的能力字符串命中，是定位入口，非完整调用图或接入完成证明；未命中仍可能存在直接公开方法调用。完整命中文件保存在 JSON 的 consumerEvidence；内部调用在逐文件审查中补充。

## 2. 显式能力全量矩阵

| 能力／版本 | 职责与注册文件 | Mists 当前 | Forever 当前 | Retail 本轮结论（当前均未实现） | YBP 首期关系 | 业务源码命中 |
| --- | --- | --- | --- | --- | --- | --- |
| `account-character-admission:1` | 角色准入通知；[源码](../UI/AccountView.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | YiboBuilds、YiboCrafting、YiboCurrency、YiboMail、YiboReputation、YiboTaskHub、YiboVault |
| `account-dynamic-fields:1` | 动态字段；[源码](../UI/AccountView.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboCurrency |
| `account-entry:2` | 托管入口；[源码](../UI/Entry.lua) | 声明 v2 | 声明 v2 | 共享适配后提供，待验证 | 必需候选 | YiboAltoBoss、YiboBuilds、YiboCrafting、YiboCurrency、YiboLegendary、YiboMail、YiboQuestBlocker、YiboReputation、YiboTaskHub、YiboTodo、YiboVault |
| `account-preview-characters:1` | 悬停角色限制；[源码](../UI/AccountView.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | YiboBuilds、YiboCrafting、YiboCurrency、YiboMail、YiboReputation |
| `account-preview-field-groups:1` | 预览字段分组；[源码](../UI/AccountPages/SettingsWorkbench.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboAltoBoss、YiboCurrency |
| `account-surface-budget:2` | 表面尺寸预算；[源码](../UI/AccountView.lua) | 声明 v2 | 声明 v2 | 共享适配后提供，待验证 | 必需候选 | YiboAltoBoss、YiboBeastPaths、YiboBuilds、YiboCrafting、YiboCurrency、YiboLegendary、YiboMail、YiboQuestBlocker、YiboReputation、YiboTaskHub、YiboVault |
| `account-view:2` | 账号窗口与业务页；[源码](../UI/AccountView.lua) | 声明 v2 | 声明 v2 | 共享适配后提供，待验证 | 必需候选 | YiboAltoBoss、YiboBeastPaths、YiboBuilds、YiboCrafting、YiboCurrency、YiboLegendary、YiboMail、YiboQuestBlocker、YiboReputation、YiboTaskHub、YiboTodo |
| `addon-catalog:1` | 目标插件目录；[源码](../Data/AddonCatalog.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | 未检出显式检查；Core 内部使用／公共接口 |
| `addon-status:1` | 安装／启用／连接状态；[源码](../Runtime/AddonStatus.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | 未检出显式检查；Core 内部使用／公共接口 |
| `basic-input:1` | 公共输入；[源码](../UI/Input.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboAltoBoss、YiboBeastPaths、YiboCrafting、YiboCurrency、YiboMail、YiboQuestBlocker、YiboReputation、YiboTaskHub、YiboVault |
| `builtin-entry-bar:3` | 内置信息条；[源码](../UI/Entry.lua) | 声明 v3 | 声明 v3 | 共享适配后提供，待验证 | 必需候选 | YiboTaskHub |
| `business-item-actions:3` | 业务项目主动添加；[源码](../UI/BusinessItemActions.lua) | 声明 v3 | 声明 v3 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboAltoBoss、YiboBuilds、YiboCrafting、YiboCurrency、YiboLegendary、YiboMail、YiboReputation、YiboTaskHub、YiboTodo、YiboVault |
| `business-providers:1` | Provider 聚合；[源码](../Runtime/Contracts.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboAltoBoss、YiboBuilds、YiboCrafting、YiboCurrency、YiboMail、YiboReputation、YiboTaskHub、YiboTodo |
| `business-services:1` | Service 连接；[源码](../Runtime/Contracts.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboAltoBoss、YiboCrafting、YiboCurrency、YiboMail、YiboTaskHub、YiboVault |
| `calendar-day-query:1` | 当天日历原始事实；[源码](../Mists/Calendar.lua) | 声明 v1 | 未声明 | 目标专属暂缓；不声明 | 首期不需要 | YiboAltoBoss、YiboTodo |
| `character-archive-providers:1` | 公开档案字段 Provider；[源码](../Runtime/ArchiveFields.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboCurrency |
| `character-cleanup:2` | 清理所有者 v2；[源码](../Data/CharacterCleanup.lua) | 声明 v2 | 声明 v2 | 共享适配后提供，待验证 | 必需候选 | YiboAltoBoss、YiboBuilds、YiboCrafting、YiboCurrency、YiboMail、YiboReputation |
| `character-identity:1` | 轻量角色身份；[源码](../Data/Characters.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | YiboAltoBoss、YiboBuilds、YiboCrafting、YiboCurrency、YiboMail、YiboReputation、YiboTaskHub、YiboTodo、YiboVault |
| `character-name-format:1` | 名称显示；[源码](../Data/Characters.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | YiboAltoBoss、YiboBuilds、YiboCrafting、YiboCurrency、YiboLegendary、YiboMail、YiboQuestBlocker、YiboReputation、YiboTaskHub、YiboTodo、YiboVault |
| `character-profile:1` | 旧档案兼容门面；[源码](../Data/Profile.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | 未检出显式检查；Core 内部使用／公共接口 |
| `characters:1` | 角色目录；[源码](../Data/Characters.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | YiboAltoBoss、YiboBuilds、YiboCrafting、YiboCurrency、YiboMail、YiboQuestBlocker、YiboVault |
| `data-domains:1` | 域注册／分发；[源码](../Runtime/DataDomains.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboCrafting、YiboCurrency、YiboReputation |
| `database:1` | 目标存档；[源码](../Data/Database.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | 未检出显式检查；Core 内部使用／公共接口 |
| `domain-store:1` | 域快照保存；[源码](../Data/DomainStore.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | 未检出显式检查；Core 内部使用／公共接口 |
| `events:1` | 公开事件；[源码](../Runtime/Events.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | YiboAltoBoss、YiboCrafting、YiboCurrency、YiboReputation |
| `fields:1` | 域字段；[源码](../Runtime/Fields.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboCrafting |
| `item-picker:2` | 物品选择器；[源码](../UI/ItemPicker.lua) | 声明 v2 | 声明 v2 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboCurrency、YiboMail |
| `item-resolver:1` | 物品解析／异步加载；[源码](../Runtime/ItemResolver.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboBuilds、YiboCrafting、YiboCurrency、YiboMail、YiboTaskHub、YiboVault |
| `level-filter:1` | 等级表达式；[源码](../Util/LevelFilter.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | YiboAltoBoss |
| `localization:1` | owner 语言资源；[源码](../Runtime/Locale.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | YiboAltoBoss、YiboAutoOpen、YiboBeastPaths、YiboBuilds、YiboCrafting、YiboCurrency、YiboLegendary、YiboMail、YiboMounts、YiboQuestBlocker、YiboReputation、YiboTaskHub、YiboTodo、YiboVault |
| `migrations:1` | schema 迁移；[源码](../Data/Migrations.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | 未检出显式检查；Core 内部使用／公共接口 |
| `profession-profile:1` | 权威专业档案；[源码](../Forever/Professions.lua) | 未声明 | 声明 v1 | 目标专属暂缓；不声明 | 首期不需要 | YiboCrafting |
| `resources:1` | 中性资源定义；[源码](../Runtime/Resources.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 通用底座；按实际调用选用 | 未检出显式检查；Core 内部使用／公共接口 |
| `runtime:1` | 运行时与 API 检查；[源码](../Runtime/Capabilities.lua) | 声明 v1 | 声明 v1 | 共享适配后提供，待验证 | 必需候选 | 未检出显式检查；Core 内部使用／公共接口 |

`Runtime/CurrencyCatalog.lua` 虽残留 `currency-catalog:1` 文本，但文件开头直接返回且不在两端 TOC，**不计为第 35 项有效能力**；本轮不恢复该业务目录。

## 3. 无独立能力名的公共接口与原生边界

| 接口／机制 | 当前实现及目标 | Retail／共享处理 | 验证 |
| --- | --- | --- | --- |
| `Core:RegisterAddon`、Registry 资源所有权 | Runtime/Registry.lua，两端共用；没有 registry 能力名 | 保持 API 检查、同 owner 资源复用与冲突规则；Core 自身就绪发布加幂等保护 | R1-01；同名冲突、晚就绪、直接重复初始化 |
| `Core:RegisterSettingsPanel/UnregisterSettingsPanel` | Runtime/SettingsRegistry.lua，两端共用；无 settings 能力名 | 保持同 owner 重入及注销，消费者检查实际方法 | R1-08；设置单独注册、晚注册、关闭重开 |
| `Core.EntryConfig` | schema11 通道规范化，两端共用；无独立能力名 | 保留历史入口迁移与三通道八组合 | R1-08；旧设置恢复 |
| `Core.UITheme`、ItemConfirmation、IconPicker | 公共控件，不各自声明能力；basic-input 在 Input.lua 声明 | 样式／布局共用；图标原生枚举归目标边界，确认取消及焦点清理保留 | R1-06；三端 UI 与实际图标来源 |
| `Core.CharacterSort`、Defaults | 稳定纯逻辑；无独立能力名 | 共用保留，不创建每目标副本 | 排序、ID 替换、复制与迁移回归 |
| `Core:Initialize/IsInitialized/CheckAPIVersion`、CORE_READY | Bootstrap／Database 配合；API13 | 版本、能力声明、就绪分别判断；不新建空服务注册层 | R1-01／02；必要初始化失败不得广播成功 |
| `Core.PackagedAddonVersions` | 构建器生成并在 AddonStatus 前注入，源码无该 Lua | 三目标按已登记清单生成；Retail 必须识别 YBP 现有 Mainline／默认清单的明确配置映射 | R2-02；不按文件名或安装状态推定接入 |

同一公开接口存在并不意味着本次需要新增能力名；若改变语义或契约，先评估 API／能力版本并更新契约文档。

## 4. 数据域与目标功能矩阵

域注册与能力注册分别统计。`profession-profile:1` 的非对称声明不能用“补一行能力注册”消除：Mists 现有专业投影没有 Forever 的 `skillLineIDsAuthoritative` 与双次稳定读取承诺，应保留既有契约并单独回归。

| 域／功能 | Mists 当前 | Forever 当前 | Retail 本轮 | 所有权／处理 |
| --- | --- | --- | --- | --- |
| 角色基本目录（GUID／名称／服务器／职业／等级） | Characters；允许既有 legacy 身份迁移 | Characters；要求真实 GUID，禁 legacy 导入 | 首期必需；真实 GUID、无跨目标导入 | Core；R1-03 |
| identity v1 | Data/Domains/Identity.lua | 同文件 | 基础身份需求保留；原生采集边界抽离后按证据加载 | Core；种族／阵营多返回值与未知状态须核对 |
| location v1 | Data/Domains/Location.lua | 同文件 | 首期非必要，不加载位置采集；共享分发与状态机制仍适配 | Core；迁到既有目标适配层，不因此新增 Retail 位置能力 |
| professions v1 | Data/Domains/Professions.lua；无 profession-profile 标记 | Forever/Professions.lua；声明 profession-profile:1 | 暂缓，不注册域与字段 | Core 已有专业档案，不复制到 Retail |
| equipment v1（装等） | Data/Domains/Equipment.lua | 未加载 | 暂缓 | Mists 采集职责迁入目标目录 |
| specialization v1 | Data/Domains/Specialization.lua | 未加载 | 暂缓 | Mists 采集职责迁入目标目录 |
| 当天日历事实 | Mists/Calendar.lua | 未提供 | 暂缓 | 保持 Mists；Core 不解释活动业务周期 |
| economy／economy-items、声望域及货币目录 | 已退役，不在 TOC | 已退役，不在 TOC | 不恢复 | 货币／声望事实属于对应业务插件；历史 Core 快照保持可读 |
| 宠物随身／兽栏采集与快照 | Core 不拥有 | Core 不拥有 | Core 不新增 | 后续由 YBP 实施；R3 只用非发布合成消费者 |
| 路线“已拥有”与四色识别 | Core 不拥有 | Core 不拥有 | Core 不新增 | YBP DEV-005 |

Retail 的 identity 原生读取属于首期身份支持边界；位置、专业、装备、专精、日历未实现时，不能用空表／零值补出可用业务字段。跨服务器目录与猎人准入由公共目录和业务回调解决，不需要这些额外采集器。

## 5. 验证与接入状态

本轮执行的既有离线基线为 5 组共 407 项通过，另 2 组失败；具体命令、退出码与失败原因见 R0 审查记录。它们只覆盖原 Mists／Forever 清单及指定公共契约，不证明上述 32 项共用能力所有路径实机通过，更不证明 Retail 可用。

现有 YBP 的 account-view／surface-budget／basic-input／localization 命中来自 Mists 可选维护功能；不能据此将 YBP 离线兽栏记为已接入。Core 实现状态与业务接入状态在后续按 CAP 台账分别更新。
