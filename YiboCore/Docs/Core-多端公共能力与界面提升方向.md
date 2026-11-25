# YiboCore 多端公共能力与界面提升方向

2026-11-21 · 规划审查 · 适用范围为熊猫人之谜（Mists）、无限服（Forever）和正式服（Retail）。

三端源码清单均加载 Core 的角色目录、账号页、主题、统一设置和物品解析。优先把业务插件已经重复实现、且职责稳定的界面组件收归 Core。原生接口差异由各目标适配，业务插件继续拥有各自的数据、内容和判断规则。本文的优先级基于源码、加载清单及仓库验收记录。拟议能力的客户端验收均待实施。 [Mists 清单](../YiboCore_Mists.toc) · [Forever 清单](../YiboCore_Forever.toc) · [Retail 清单](../YiboCore_Mainline.toc) · [公共能力迁移台账](Core-公共能力迁移台账.md)

## 优先收归的前端组件

### 1. 长列表的可见行与控件复用

- **现有能力**。Core 已提供滚动框、窗口尺寸预算和矩阵列分页。Crafting 和 Reputation 在各自的 Forever 页面计算可见行，Crafting 的 MoP 页面及 BeastPaths 的 MoP／Retail 兽栏也有对应实现。 [Core 滚动框](../UI/Theme.lua) · [Crafting MoP 列表](../../YiboCrafting/AccountPage.lua) · [Crafting Forever 列表](../../YiboCrafting/Forever/AccountPage.lua) · [Reputation Forever 列表](../../YiboReputation/Forever/AccountPage.lua) · [BeastPaths 兽栏渲染](../../YiboBeastPaths/Common/OfflinePetRenderer.lua)
- **要补的缺口**。让 Core 管理定高列表的可见范围、行控件复用和内容变更后的滚动范围。首批可用 Crafting 与 Reputation 对照行为，BeastPaths 提供 Retail 实际消费场景。列定义、排序、筛选、选择后的业务操作和不规则布局留在各页面。Legacy 的挑战矩阵和 Transmog 的收藏清单是后续消费者。
- **验收重点**。三端使用各自已有页面核对从空列表到长列表、筛选后越界滚动、换页重开和行控件换绑。矩阵的表头、数据和分页使用同一角色切片。滚动经过复用行时，悬停、选中和点击都指向当前数据。对比改动前后的创建行数和实际滚动表现。

### 2. 业务页的物品展示单元

- **现有能力**。三端 Core 已提供物品解析、异步加载和选择器。Vault、Builds 和 Mail 现有页面分别处理物品图标、品质边框、链接悬停及未加载状态。 [物品解析](../Runtime/ItemResolver.lua) · [物品选择器](../UI/ItemPicker.lua) · [Vault 物品展示](../../YiboVault/Forever/AccountPage.lua) · [Builds 装备展示](../../YiboBuilds/Forever/AccountPage.lua) · [Mail 物品提示](../../YiboMail/CacheUI.lua)
- **要补的缺口**。新增一个可嵌入业务页的物品展示单元，统一图标、品质边框、未加载占位和原生 Tooltip。先从 Vault 与 Builds 的同类显示收归，业务页面继续控制数量、库存、装备差异和收藏角标。MoP 与 Forever 有现成消费者，Retail 可以用 Core 物品选择器或独立验证载体对照通用组件。
- **验收重点**。核对普通及低品质物品、相同物品 ID 的不同链接、物品资料晚到、行快速换绑和鼠标移出。保留完整物品链接，确认异步回调和 Tooltip 都对应当前物品。Retail 的组件验证按实际消费或验证载体记录。

## 优先新增的公共能力

### 3. 依赖检查与业务就绪状态

- **现有能力**。Core 已提供初始化就绪、API 版本、能力版本和业务注册。Crafting、Currency、Builds 与 Mail 有各自的前置检查。「关于」页目前依据注册记录判断是否连接。 [插件状态](../Runtime/AddonStatus.lua) · [业务注册](../Runtime/Registry.lua) · [Crafting 启动检查](../../YiboCrafting/Forever/Bootstrap.lua) · [Mail 生命周期](../../YiboMail/Common/Lifecycle.lua)
- **要补的缺口**。为业务插件提供统一的依赖检查结果和最少的就绪状态，现有「关于」页可据此解释缺少哪项能力、版本不足或注册后初始化失败。插件负责目标身份校验、业务注册顺序和失败处理。升级提示应能明确指出目标、能力和最低版本。先选两个真实消费者验证，按目标逐步接入。
- **验收重点**。验证旧 Core、能力不足、晚就绪、重复调用、登记后失败和恢复成功。旧版消费者的连接展示保持兼容。三端都应能表达自身实际状态。客户端连 Core 都未成功加载时，以原生插件依赖提示为入口。

## 等消费者明确后再评估

| 候选 | 现有依据与可补缺口 | 验收重点 |
| --- | --- | --- |
| **原生物品 Tooltip 协调** | Vault 的 MoP／Forever 共享代码已有现代回调和旧式钩子路径。Legacy 和 Transmog 有追加提示的产品需求。出现第二个实际提供者后，可评估把物品识别、回调分发和追加行顺序从业务插件收归 Core。仓储、传承与收藏内容各自生成。 [Vault Tooltip](../../YiboVault/Tooltip.lua) | 两个提供者同时启用、重复刷新和换物品时，行内容、顺序与清理正确。按目标实际存在的钩子分别验证，区分原生物品 Tooltip 与 Core 入口悬停。 |
| **当前场景与规则集身份** | MoP 和 Forever 已加载位置域，Retail 当前清单未加载该域。AltoBoss、Todo 和 BeastPaths 有各自的副本或地图读取。若 Legacy、Transmog 或其他插件需要相同的场景事实，可提供稳定的地图、实例类型或已取证的规则集身份。场景偏好、地图关联和账号共享规则由业务插件解释。 [位置域](../Data/Domains/Location.lua) · [Forever 目标](../Forever/Target.lua) · [AltoBoss 副本读取](../../YiboAltoBoss/Mists/RaidEvents.lua) · [Todo 地图读取](../../YiboTodo/Providers/FarmOperationObservation.lua) | 对照世界、五人本、战场、过图及信息未就绪。地图 ID 与副本 ID 分别验证。规则集范围按本端真实样本确认，读不到时明确保留未知。 |
| **原生日常与周常重置时间** | AltoBoss 已读取日常或周常原生重置信息，Todo 也处理自己的任务和专业周期。出现多个需要同一原生重置事实的消费者后，可以提供小型目标适配。节日、专业冷却和具体任务的重置语义继续由业务所有者负责。 [AltoBoss 重置查询](../../YiboAltoBoss/Mists/PlannedTargets.lua) · [Todo 周期规则](../../YiboTodo/Model/Schedule.lua) | 核对服务器时间、重置前后、原生数据缺失和跨天登录。只有经目标客户端验证的原生周期才声明可用。 |

## 多端接入与取舍

- 首批建议先验证可见行复用，其次是物品展示单元。同时为有实际支持成本的插件整理依赖诊断需求。共享界面能力可覆盖三端，业务插件接入和实机通过按实际目标分别登记。
- 新增公开契约时明确能力版本、失败行为和首批消费者。利用现有 `AccountView`、`UITheme`、`ItemResolver`、Service／Provider、语言和角色清理接口，按真实需求扩展对应能力。 [三目标共享底座兼容契约](API-v13-R1共享底座兼容与失败契约.md) · [档案字段与清理所有者](API-v13-档案业务字段与清理所有者.md)
- 实施时先核对受影响的三端 TOC 和构建结果，再按实际消费者进行离线回归及客户端验证。业务存档由各插件继续拥有，覆盖更新和旧设置恢复按目标验证。 [多版本目标与发行标识规范](../../Docs/多版本目标与发行标识规范.md)
