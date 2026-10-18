# Core 公共能力迁移台账

## 当前基线

2026-10-15 YiboReputation 数据归属改造已按[迁移方案](../../YiboReputation/Docs/声望数据归属迁移方案.md)实施：Core 1.12.4 停止声望采集，Reputation 1.7.1 接管采集、目录与新存储，旧快照通过公开接口一次性导入且冻结保留。87 项专项与独立悬停检查通过，真实客户端存档尚未迁移／验收；详见[实施记录](../../YiboReputation/Docs/声望数据归属迁移-实施与验收记录.md)。

> 最近更新：2026-10-16。首次审查：2026-10-07。
>
> **当前工作树：Core 1.12.6 / API 13。** Crafting 集中接入基线为 Core 1.12.0 / Crafting 1.2.0；当前适用调用、版本检查及离线检查已完成，游戏内双语、入口与性能验收待完成。各能力与插件状态仍按各自验证边界记录。详见 [Crafting 完整接入清单](../../YiboCrafting/Docs/Core-API13-完整接入.md)。YiboReputation 1.7.1 API13 接入与数据归属迁移代码已完成，客户端待验收。
>
> 近期历史基线：2026-10-10 主动添加实施使用 Core 1.11.0 / API 12，TaskHub 0.5.0 / schema 4 接入九个来源；230 项目标检查、672 项既有集成及相关回归通过，客户端待验收，未发布。2026-10-09 O1 实施使用 Core 1.10.0 / API 11，提供 `business-providers:1` 与 List；ContractsSpec 90 项、RuntimePerformanceSpec、CharacterNamesSpec 77 项、MailProviderSpec、VaultIntegrationSpec、InboxReleaseSpec 及 Core TOC 45 个 Lua 5.1 文件语法检查通过。两项均为历史工作树记录，不代表当前发布状态。

## 目录

- [当前实施节奏](#当前实施节奏2026-10-08-已确认)
- [维护与状态](#维护与状态)
- [首次审查依据与边界](#首次审查依据与边界)
- [API 版本演进与追赶要求](#api9-与-api10-合并发布及业务追赶要求)
- [活动能力总表](#活动能力总表)
- [插件最低版本与依赖基线](#当前插件最低版本与依赖基线)
- [CAP-001：公共名称格式化](#cap-001公共名称格式化)
- [CAP-002：基础输入](#cap-002基础输入)
- [CAP-003：物品解析、选择与操作确认](#cap-003物品解析选择与操作确认)
- [CAP-004：账号页面、入口与设置](#cap-004账号页面入口与设置接入基线)
- [CAP-005：跨业务能力连接](#cap-005通用跨业务能力连接)
- [CAP-006：首次打开提示](#cap-006页面首次打开提示)
- [CAP-007：轻量角色身份投影](#cap-007轻量角色身份投影)
- [CAP-008：业务项目主动添加](#cap-008业务项目主动添加)
- [CAP-009：语言服务与账号语言偏好](#cap-009公共语言服务与账号语言偏好)
- [CAP-010：角色缓存所有者与延后清理](#cap-010角色缓存所有者与延后清理)
- [后续方向与实现状态](#后续方向与实现状态)
- [其他现有能力索引](#其他现有能力索引)
- [首次审查待处理项](#首次审查待处理项)
- [更新记录](#更新记录)

## 当前实施节奏（2026-10-08 已确认）

- 保留触及即迁移；每次后续业务修改收尾时按实际 diff 检查，持续记录正确接入与遗漏。未触及的旧实现保留为迁移库存。
- 用户计划在无限服开服后对所有插件进行大幅更新，集中追赶随各插件对应更新一起执行；开服日期和具体客户端差异尚未确定，不据此登记迁移已完成。
- 大幅更新开始时固定当时已实现且满足验证要求的 Core 能力基线，补齐该插件全部适用项。基线须涵盖 api9／api10 合并增量，若当时 Core 又有新能力，也一并审查适用范围、最低版本及验证要求；接口明细继续按 CAP 条目登记。
- Core 负责通用操作实现，业务负责接入与业务回调。搜索清空已由 Core AttachClearButton 和 CreateInput(clearable=true) 提供；Crafting 搜索框的剩余项是标准输入接入，见 AUD-012。

## 维护与状态

- 使用稳定编号 `CAP-001` 等标识迁移事项；编号不代表运行时注册名称。
- Core 状态：`待实现`、`已提供`、`待扩展`。另列发布版本与验证情况；源码存在不等于已发布或已验收。
- 插件状态：`待评估`（尚未确定适用范围）、`待迁移`（已确认存在相关调用）、`部分接入`（已有接入但仍有剩余调用、版本要求或验证缺口）、`已接入`（所列范围完成接入、最低版本检查与必要验证）、`不适用`（已审查，所列范围没有该能力需求）。
- 每个状态仅适用于该能力条目明确列出的范围。使用旧接口或间接使用 Core 控件，不等于已接入新契约。
- Core 新增或发布能力、业务接入、发现遗漏、契约变化或新增插件时更新相关条目。新插件须在各活动能力下登记；未经审查先记为待评估。无变化时无需定期更新。
- 表格按插件技术名排序。后续更新须记录接入版本、已覆盖与剩余范围、验证证据、最近审查日期；未发布改动标注“工作树”，不猜测发布版本。
- 台账保存进度与证据，接口参数、返回值与兼容语义以对应 API 文档为准。每项能力的完成条件是 Core 已提供，所有适用插件已接入，且已知缺口已关闭。

## 首次审查依据与边界

审查仓库根目录的 `YiboCore` 与 13 个业务插件：以 `.toc` 加载清单、初始化检查、运行时代码和相关 API 文档为依据，排除第三方 Libs、探针、构建输出与测试辅助实现。分支为 `main`，工作树包含尚未提交的其他改动，以下结论是本次读取的本地源码快照，不代表远端或已发布安装包状态。

首次审查时 Core 源码版本为 **1.6.3 / API v7**。2026-10-08 后续发布记录：当前源码与 HEAD 均为 **1.9.0 / API v10**，提交 `1ef9ccf`；依据 [Bootstrap.lua](../Bootstrap.lua)、[YiboCore.toc](../YiboCore.toc) 及用户提供的发布页截图，渠道从 **v1.7.0-api8** 直接提交 **v1.9.0-api10**，未单独发布 **v1.8.0-api9**。截图中 api8 已 Approved，api10 为 Uploading；记录为已发起发布，尚无审核完成证据。业务插件工作树接入与游戏内验收仍分别记录，不能由 Core 发包推定完成。

本轮覆盖 14 个业务目录（13 个现有业务插件及 YiboTaskHub 项目基础），静态复核加载清单、最低版本、能力注册及接入调用。重新运行 RuntimePerformanceSpec、InboxReleaseSpec、MailProviderSpec、VaultIntegrationSpec 均通过；CharacterNamesSpec 在“API v10 应拒绝”的过期断言处失败，见 AUD-009。历史通过记录保留，但不能据此宣称当前工作树名称回归全部通过。首次提示本轮仅静态核对。

首次审查完整登记名称显示、基础输入和物品选择相关范围，并建立账号页面、入口、设置接入基线。其余已注册能力登记为现有接口索引，未进行逐调用验收；后续发现真实迁移需求时新增独立条目。

## api9 与 api10 合并发布及业务追赶要求

2026-10-08 用户确认：跳过 v1.8.0-api9 独立发布，api9 的实现随 v1.9.0-api10 一起发布。1.8.0 是实现阶段版本；使用 api9 能力的用户应升级到渠道包 **v1.9.0-api10 或更新版本**。运行时仍按实际所需 API／能力版本检查，不因合并发包把只需 API v9 的插件一律改成 requiredAPI=10。

**其它业务插件后续追赶 Core 时，必须把 api9 与 api10 纳入同一次接入审查和验收，补齐两代中全部适用项；不能只完成 api10 首次提示或提高版本声明，就将 api9 记为已完成。** 已有接入也需核对剩余范围；不适用项记录理由，不添加无需求功能。更早 API 的遗留项继续按各 CAP 条目记录。

| 代际 / 台账 | 同批核对与补齐范围 | 完成证据 |
| --- | --- | --- |
| api9／api11 / CAP-005 | 真实跨业务调用经 Core.Contracts；Service 与 Provider／List 均已实现，业务接入分别登记 | Service 查 API v9 / business-services:1，Provider 查 API v11 / business-providers:1；验证缺失、晚注册、注销、不兼容及业务时效 |
| api9 / CAP-004 | 已有 NotifyPageChanged 调用复用 Core 的合并刷新；核对可见性、切页、悬停及需要即时反馈的交互 | Core 内部刷新改进可直接继承，但需验收业务页面行为；不要求无需求插件新增刷新机制 |
| api9 / CAP-003 | 对本次涉及的物品展示加载复用已提供的 ItemResolver；核对异步回调、过期取消和错误／超时 | 公共解析接口仍为 API v7 / item-resolver:1；api9 是内部调度改进，不单独抬高该调用的门槛 |
| api10 / CAP-006 | 有首次引导需求的页面接入 firstUseTip；没有该需求时登记不适用；必需状态与安全提示保留常显 | 使用者检查 API v10 / account-view:2；验证一次性、预览不触发、成功记录、计时及低版本提示／停止 |

追赶记录须分别列出 api9 与 api10 的已覆盖、剩余、不适用和验证证据。Mail／Vault／Currency 的 api9 工作树接入，以及 Builds／Reputation／Todo 的 api10 工作树接入，均不代表整个插件已完成这次合并批次。

## API 11–13 版本演进补充

上方关于 API 10 的批准／上传状态是 2026-10-08 的历史发布记录，不是当前源码上限。之后的实现与接入按当时工作树版本记录；以下是从 API 10 补齐到当前 Core 1.12.0 / API 13 的能力基线。API 11–13 当前均按工作树实现记录，不能据此推断渠道包已发布。

| Core 基线 | 新增或扩展的公开能力 | 迁移台账与当前边界 |
|---|---|---|
| Core 1.10.0 / API 11 | `business-providers:1`（Provider/List）；`account-surface-budget:1`；`account-character-admission:1`；`character-identity:1` | CAP-004、CAP-005、CAP-007 分别登记。Provider、准入／高度预算及身份能力按真实消费者接入；没有对应需求的插件保持不适用或待评估。 |
| Core 1.11.0 / API 12 | `business-item-actions:1`，为业务页面提供 Core 管理的主动添加与目标操作入口 | CAP-008 登记提供方与消费方。Core 1.12.0 将其向后兼容扩展为 `business-item-actions:2`，已有 v1 调用仍有效。 |
| Core 1.12.0 / API 13 | `localization:1`；`account-entry:2`；`builtin-entry-bar:3`。并把 `business-item-actions` 升至 v2；统一下拉互斥等控件行为沿用既有接口 | CAP-004、CAP-008、CAP-009 登记。语言接入最低 API13；新入口消费者按具体所需能力检查版本。Core 运行代码及客户端仍为工作树／待验收状态。 |

YiboMounts 1.0.0 已按 API13 接入 `localization:1` 和 API v6 独立设置注册；Core 保持可选，增强功能要求 API13，独立来源 Tooltip 保持可用。细节与剩余验收见 [YiboMounts API13 接入说明](../../YiboMounts/Docs/Core-API13-接入说明.md)。

## 活动能力总表

| 编号 | 能力 | Core 状态 | 最低要求 / 发布依据 | 当前接入结果 | 下一触发点 |
| --- | --- | --- | --- | --- | --- |
| CAP-001 | 公共角色／联系人名称格式化 | 已提供 | Core 1.7.0 / API v8，`character-name-format:1`；用户截图显示 v1.7.0-api8 已 Approved | Core 自身显示已接入；Mail 部分接入，其他业务范围随功能修改迁移 | 游戏内核对及业务剩余显示调用 |
| CAP-002 | 基础输入控件 | 已提供 | API v7，`basic-input:1`；文档首批 Core 1.6.1 | Currency 有明确接入与验证记录；Mail 版本要求已修正、旧输入部分待迁移；Vault 部分接入 | 对应搜索／输入控件修改时迁移，并核对最低版本 |
| CAP-003 | 物品解析、选择与操作确认 | 已提供 | API v7，`item-resolver:1`；Core 1.7.1 / API v8 提供 `item-picker:2` 批量扩展 | Currency 保持单物品兼容；Mail 已接入所列范围；Crafting／Vault 部分接入展示加载，TaskHub 0.3.0 部分接入图标；AutoOpen 待评估 | 有真实批量录入需求时使用公开配置；业务校验与执行由业务插件负责 |
| CAP-004 | 账号页面、入口与设置工作台 | 已提供 | 账号页面／入口基线 API v5；API13 提供 `account-entry:2` / `builtin-entry-bar:3`（客户端待验收）；独立设置注册 API v6；API v11 新增 `account-character-admission:1`、`account-surface-budget:1`；`account-view:2` 首次提示另见 CAP-006 | TaskHub O4 接入角色准入通知、悬停及业务设置；仍有旧设置壳、版本和客户端验证待核对项 | 对应功能修改或经确认的集中迁移时处理所列缺口 |
| CAP-005 | 通用跨业务能力连接 | 已提供（Service 与 Provider） | Service 最低 API v9 / business-services:1；Provider 工作树 Core 1.10.0 / API v11 / business-providers:1，未发布；文档见 API-v11 | Mail／Vault／Currency 已有 Service；Todo／Mail 输出三个 action.todo，TaskHub 通用消费 | ContractsSpec 90 项、TaskHub 集成与展示 327 项及邮件回归通过；主页面外观已确认，新来源和 O4 客户端待验收 |
| CAP-006 | 页面首次打开提示 | 已提供 | Core 1.9.0 / API v10、account-view:2；v1.9.0-api10 上传中，包含 api9 | Core 概览及 Builds／Reputation／Todo 已写入 firstUseTip，业务检查 API v10 与能力；仅静态核对，记部分接入 | 与 api9 同批核对；自动化契约和低版本停止验证、游戏内一次性／预览／超时验收 |

| CAP-010 | 角色缓存所有者与延后清理 | 已提供（工作树） | Core1.12.4工作树 / API13 / `character-cleanup:2`，v1调用兼容；[契约](API-v13-档案业务字段与清理所有者.md) | Currency显式检查2，离线通过、客户端待验；Reputation既有消费者126项通过；其它所有者待评估v2特性 | 禁用／重新启用后清理与真实存档验收 |

### 当前插件最低版本与依赖基线

以下均于 2026-10-08 按工作树复核。数字表示初始化检查和 RegisterAddon 声明，不表示已接入该版本的全部能力；TOC 版本号没有随部分工作树修改提高，不能当作已发布接入版本。

| 插件技术名 | 最低 Core API | TOC Core 依赖 | 已检查的新能力 / 主要缺口 |
| --- | --- | --- | --- |
| YiboAltoBoss | 13（基础与增强） | RequiredDeps | 工作树副本状态／悬停使用 localization:1；五人本 DBM 可选桥接使用 events:1，目标增强继续要求 business-services:1 / business-providers:1；旧设置库存见 AUD-005 ；2026-10-16本轮矩阵接入另检查account-surface-budget:2及实际方法 |
| YiboAutoOpen | 13 + `localization:1`（可选设置） | OptionalDeps | Core 缺失或版本不足时独立基础队列保留；本地输入与解析待评估 |
| YiboBeastPaths | 13（可选维护页；1.7.0 工作树） | OptionalDeps（各客户端 TOC） | 固定 Core 1.12.1 基线；检查 localization:1、basic-input:1、account-view:2、account-surface-budget:1；独立路线功能保留 / 2026-10-13 |
| YiboBuilds | 13 | RequiredDeps | Core1.12.5；localization:1、character-name-format:1、character-identity:1、account-view:2、account-entry:2、character-cleanup:2、business-providers:1、business-item-actions:1；客户端待验 |
| YiboCrafting | 8 | RequiredDeps | character-name-format:1、item-resolver:1；共享角色表头／FormatName 方法检查，搜索输入待迁移 |
| YiboCurrency | 13 | RequiredDeps | 0.9.1工作树：Core1.12.4工作树、account-dynamic-fields:1、character-archive-providers:1、character-cleanup:2及实际接入能力；Vault仅经契约发现，无TOC业务依赖 |
| YiboLegendary | 13 | RequiredDeps | 工作树 2.2.0 检查 `localization:1`、`character-name-format:1`、`account-view:2`、`account-entry:2` 与所需方法；路线静态文案仍有大量未迁移项 ；2026-10-16本轮矩阵接入另检查account-surface-budget:2及实际方法 |
| YiboMail | 13；action.todo 提醒 11 | RequiredDeps | 1.2.9-api1 基础业务要求 localization:1、business-services:1、character-name-format:1、basic-input:1、item-resolver:1、item-picker:2、character-identity:1、characters:1、character-cleanup:1、account-view:2、account-character-admission:1、account-surface-budget:1、account-entry:2；邮件目标操作要求 business-item-actions:1；action.todo 新邮件提醒单独要求 business-providers:1，不足仅停止对应可选功能 |
| YiboMounts | 13（可选 Core 设置／语言增强） | OptionalDeps | 1.0.0：Core v6 设置面板与 API13 localization:1；Core 缺失或不兼容时来源 Tooltip 独立运行，见 Core-API13-接入说明 |
| YiboQuestBlocker | 13；localization:1、character-name-format:1、basic-input:1、account-view:2、account-entry:2 | RequiredDeps | 工作树 3.1.0；版本不足时提示升级并停止初始化 ；2026-10-16本轮矩阵接入另检查account-surface-budget:2及实际方法 |
| YiboReputation | 13（工作树 1.7.1；最低 Core1.12.4） | RequiredDeps | localization:1、account-view:2、account-surface-budget:2、data-domains:1、events:1、basic-input:1、character-name-format:1、character-identity:1、character-cleanup:1；迁移检查 GetDefinitions 与停采集状态；目标增强另检查 API12 / business-item-actions:1、business-providers:1、character-identity:1 |
| YiboTaskHub | 11 | RequiredDeps | 0.4.0 增加 Service 双向查询、basic-input:1 与 CreateBusinessTabs／CreateInput 检查；既有角色／高度／物品要求保留。672项自动化通过，客户端待验收 |
| YiboTodo | 10 | RequiredDeps | account-view:2；名称与首次提示验证待完成 |
| YiboVault | 13（1.12.0 工作树） | RequiredDeps | localization:1、business-services:1、character-name-format:1、basic-input:1、item-resolver:1、character-identity:1、account-entry:2；初始化逐项检查版本与所需方法 |

源码依据：各插件 Bootstrap、Namespace 或 CoreIntegration，及各自根目录 TOC。强依赖插件仍须按实际所需 API／能力检查，不能统一把最低版本改成 10；业务提供方缺失与 Core 版本不足是两种不同的失败路径。

## CAP-001：公共名称格式化

### Core 当前状态与边界

- 已有 [Characters:GetDisplayName](../Data/Characters.lua)：`short` 读取以角色 ID 保存的短名，其余模式返回原始角色名。现有 `full` **不包含服务器**，必须保留该接口的兼容语义。
- 已提供 `Characters:FormatName(identity, options)`，能力声明为 `character-name-format:1`。
ameMode=original/short` 与 `realmMode=omit/sameRealm/full` 独立选择；同服参照服务器必须由调用方明确提供。正式契约见 [API v8 公共名称格式化](API-v8-公共名称格式化.md)。
- [共享角色表头](../UI/Theme.lua) 已接入新接口；保留业务传入名称／服务器的覆盖优先级、两段布局、旧 full 名称模式、真实身份悬停与状态提示，不要求旧业务插件改动调用或提高最低版本。
- 目录外联系人可直接提供 `{name, realm}` 格式化，不建立角色目录记录；短名只按明确提供的 Core 角色 ID 读取。联系人备注、职业色、WoW 文本转义、地址解析与业务操作仍归调用方。
- Core 内部已覆盖范围：[Theme](../UI/Theme.lua) 的表头、身份悬停与宽度测量；[角色档案字段](../Data/Fields/CharacterArchive.lua)；[角色档案删除确认](../UI/AccountPages/CharacterArchive.lua)；[设置工作台](../UI/AccountPages/SettingsWorkbench.lua) 的排序、短名管理身份标签。身份键、业务地址与短名存档结构未改动。
- 旧接口说明：[角色短名与统一服务器切换实施方案](Core-角色短名与统一服务器切换实施方案.md)。实施源码版本为 Core 1.7.0 / API v8（尚未上传发布渠道）。2026-10-07 验证通过：[CharacterNamesSpec](../_NonRelease/Tests/CharacterNamesSpec.lua) 75 项检查、Core TOC 的 44 个 Lua 5.1 文件语法检查、现有 Currency CoreItemControlsSpec 回归。游戏内 Core 档案／设置与旧业务主窗口／预览仍待核对。

### 业务插件接入表

首次登记为 2026-10-07；以下 14 项于 2026-10-08 静态复核。共享表头在 Core 内部已接入，业务仍须分别核对调用、最低要求与实际行为。名称测试的历史通过不代替本轮验证，见 AUD-009。

| 插件 | 状态 | 已有路径与证据 | 剩余范围 / 后续触发 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（适用代码完成，客户端待验收） | Core API13 / character-name-format:1；主矩阵、转置及副本角色行／测量／行动统一 Core FormatName，经唯一ID与轻量身份读取 | 历史原生文本保留；短名及跨服实机待验，见 AltoBoss/Docs/Core-API13-完整接入.md / 2026-10-14 |
| YiboAutoOpen | 不适用 | [加载清单](../../YiboAutoOpen/YiboAutoOpen.toc) 与设置／队列代码未发现账号角色或联系人的名称显示需求 | 新增相应显示需求时重审；物品别名不属于角色短名 |
| YiboBeastPaths | 不适用 | [加载清单](../../YiboBeastPaths/YiboBeastPaths.toc) 及路线维护适配器以路线、宠物和坐标为显示对象 | 新增角色／联系人显示时重审；宠物名称不属于本能力 |
| YiboBuilds | 部分接入（代码／离线通过，客户端待验） | 主表角色行与预览CharacterLabel统一调用FormatName；短名／所有服务器策略复用Core | Core13Spec（1057项）验证单服／全服与短名策略；最低API13 / character-name-format:1；2026-10-15 |
| YiboCrafting | 部分接入（代码完成／客户端待验收） | 1.2.0 / API13；FormatName、共享角色表头、真实身份悬停全部接入，最低能力检查 | CoreNameIntegration／CoreAdaptation；中英文、短名、职业色及全服显示待客户端 / 2026-10-12 |
| YiboCurrency | 部分接入（适用代码完成／客户端待验收） | 0.9.1工作树 / API13，检查 character-name-format:1；主矩阵共享表头及货币／库存提示角色标签使用Core格式化，不再本地拼接名称 | API13Spec四组各52项、CharacterNames77项通过；短名／全服／完整身份实机待验 / 2026-10-15 |
| YiboLegendary | 部分接入（API13 代码完成／客户端待验收） | 工作树 2.2.0 检查 API13 / `character-name-format:1` 与 FormatName；角色行、行动标题按账号范围格式化，人工确认使用 original/full 身份 | 悬停、列表与完整身份客户端核对待做；名称历史状态不可由自动化或共享表头推定 |
| YiboMail | 部分接入 | 当前工作树 TOC 1.2.0-api1：AccountPage 总览／预览、ViewModel、CacheUI 等复用 FormatName；初始化检查 API v9、名称能力与方法；InboxReleaseSpec 本轮通过，其他已登记测试为历史证据 | Recipients:Label 仍自行按当前服务器组合联系人名称；保留备注优先、转义及邮寄地址解析。游戏内显示待验收 |
| YiboMounts | 不适用 | [加载清单](../../YiboMounts/YiboMounts.toc) 与图鉴提示／Core 设置适配未发现角色或联系人身份显示 | 新增相应显示需求时重审；坐骑名称与来源格式继续归业务 |
| YiboQuestBlocker | 部分接入（代码完成／客户端待验收） | 工作树 3.1.0：共享表头不再覆盖 Core 格式化；当前角色分组通过 `Characters:FormatName` 使用短名 | 角色短名、同服／跨服表头、职业色和身份 Tooltip 需实机核对；身份 ID 与旧键迁移逻辑保持不变 / 2026-10-12 |
| YiboReputation | 部分接入（API13 代码完成，客户端待验收） | 1.7.1 检查 API13 / `character-name-format:1`；主矩阵、监控预览复用 Core 共享角色表头；遗留当前角色预览显式使用 `FormatName` | 角色短名、同服／跨服提示及职业色待客户端核对；公会名称与公会键仍属公会身份，不作为角色格式化范围 / 2026-10-15 |
| YiboTaskHub | 部分接入 | 2026-10-09 0.3.1 主表执行角色／跨角色受益者、悬停角色标题／摘要复用 CreateMatrixHeader／SetCharacterHeader；FormatName short／sameRealm 用于紧凑角色行，详情执行者和跨角色受益者 original／full。显式检查共享方法，359 项回归及 Core 名称 77 项通过 | 修复 0.3.0 普通文本缺少职业色／统一身份提示；紧凑任务行采用共享控件单行模式；游戏内职业色／跨服身份待验收 |
| YiboTodo | 部分接入 | 工作树 1.3.0 检查 API13 / `character-name-format:1`，角色标签使用 `Characters:FormatName` | 本轮涉及标签已迁移；其他可能属于身份提示的用户文本与客户端显示待审查 / 2026-10-12 |
| YiboVault | 部分接入（代码完成／客户端待验收） | [Tooltip.lua](../../YiboVault/Tooltip.lua) 与 [StoragePage.lua](../../YiboVault/StoragePage.lua) 角色显示使用 `Characters:FormatName`；最低 API13 / `character-name-format:1` | 公会显示、容器名称和公会身份键仍由各自逻辑处理；角色显示待客户端核对 / 2026-10-12 |

### 首次审查注意事项

1. “所选单服范围内省略服务器”与“相对当前登录服务器省略服务器”是两种不同调用语义。Currency、Legendary 等按 `context.scope` 显示；Mail、Vault 部分显示相对当前角色服务器。新契约与迁移须明确参照范围，不能直接用一种替换另一种。
2. Mail 的 `Recipients:Normalize / Key`、收件地址、规则发件人匹配，Core 的旧键别名及稳定角色 ID，均承担身份或操作语义。迁移只替换显示调用，不能向这些数据写入短名或省略服务器后的显示文本。
3. Mail 的 CacheModel / HistoryModel 已把短名加入搜索文本；它们是检索输入，不是身份标签。后续显示迁移时检查检索一致性，不能机械替换成单一格式化字符串。
4. 共享表头收到 `options.name` 时会覆盖默认短名；QuestBlocker、Currency 当前存在此路径。完成 Core 实现后仍需逐业务核对，不能据共享表头调用将它们记为已接入。

## CAP-002：基础输入

接口与首批验证记录见 [API v7 物品选择与基础输入](API-v7-物品选择与基础输入.md)。Core 入口为 [Theme:CreateInput](../UI/Input.lua)。

首次登记为 2026-10-07；以下条目于 2026-10-08 静态复核。输入控件专项历史验证本轮未重跑；最低版本按上方基线更新。

| 插件 | 状态 | 已覆盖 / 证据 | 剩余范围与接入版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（适用代码完成，客户端待验收） | API13 / basic-input:1 / level-filter:1；NPC与小时上限使用 CreateInput，等级表达式委托Core，旧重复过滤面板及解析已清理 | 中文输入法、失焦／提交及英文布局待验 / 2026-10-14 |
| YiboAutoOpen | 待迁移 | [Settings.lua](../../YiboAutoOpen/Settings.lua) 中空位、物品、确认来源和别名输入均本地创建 | 仅 Core 托管设置范围接入；独立运行与 OptionalDeps 关系须在实施时确认。未登记接入版本 |
| YiboBeastPaths | 部分接入（适用调用代码完成／客户端待验收） | 1.7.0 Core 维护页多行导出迁移 CreateInput，最低 API13 / basic-input:1；不限长度、换行、IME／焦点生命周期；旧独立 DebugCalibrator 布局不由 Core 页面构建 | Core13IntegrationSpec 与双语 CoreDebugViewSmoke 通过，长文本复制与 IME 待客户端，见 [接入说明](../../YiboBeastPaths/Docs/Core-API13-接入说明.md) / 2026-10-13 |
| YiboBuilds | 不适用 | 当前账号页面与设置接入代码未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboCrafting | 部分接入（代码完成／客户端待验收） | 1.2.0 搜索使用 CreateInput 的 OnChanged／OnSubmit／OnFocus 与共享清空，保留 Core IME／隐藏生命周期；API13 / basic-input:1 | 真实 Input 模块与 IME 合成回归通过，AUD-012 代码关闭；实际输入待客户端 / 2026-10-12 |
| YiboCurrency | 已接入（所列范围） | 0.9.1工作树 / API13；自定义选择器复用公共输入，检查basic-input:1及实际方法 | 中文／英文CoreItemControlsSpec通过；游戏内输入与布局待验 / 2026-10-15 |
| YiboLegendary | 不适用 | 当前业务页与业务设置未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboMail | 部分接入 | 当前工作树 TOC 1.2.0-api1：CacheUI、SendRulesSettings 使用公共输入；最低 API v9；InboxReleaseSpec 本轮通过，WorkspaceSpec／RuleSendUISpec 为历史证据 | MailUI、NativeUI、RecipientUI 本地输入仍保留，随对应修改或经确认的集中迁移处理；游戏内待核对 |
| YiboMounts | 不适用 | 图鉴及 Core 设置适配未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboQuestBlocker | 部分接入（代码完成／客户端待验收） | 工作树 3.1.0：等级表达式与数字任务 ID 使用 Core `CreateInput`；检查 `basic-input:1` | 任务 ID 校验和等级表达式规则仍归业务；IME 输入法、回车提交与焦点生命周期待客户端核对 / API13 / 2026-10-12 |
| YiboReputation | 部分接入（API13 代码完成，客户端待验收） | 1.7.1 矩阵搜索使用 `Theme:CreateInput`，检查 `basic-input:1`；保留输入值、清空按钮并复用 IME 处理 | 中文输入法合成、清空／焦点及英文布局待客户端核对 / 2026-10-15 |
| YiboTaskHub | 部分接入（本轮范围） | 2026-10-10 0.4.0 TargetsPage 的搜索使用 CreateInput(clearable=true)，复用清空与 IME 处理；检查 API11 / basic-input:1 及方法；BossTargetsSpec 覆盖缺失能力停止和真实标签页操作 | 新增输入均已收拢，中文输入法与客户端布局待验收；无物品选择需求 |
| YiboTodo | 不适用 | 当前待办设置与页面未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboVault | 部分接入（适用输入已收拢） | [StoragePage.lua](../../YiboVault/StoragePage.lua) 搜索与 [AccountPage.lua](../../YiboVault/AccountPage.lua) 物品过滤均使用 Core `CreateInput`；初始化检查 API13 / `basic-input:1` 和方法 | IME、输入交互及设置布局待客户端验收 / 2026-10-12 |

## CAP-003：物品解析、选择与操作确认

公共契约与验证依据同 [API v7 文档](API-v7-物品选择与基础输入.md)。业务保存、执行、物品准入与风险文案由消费方提供；不是所有物品展示或扫描都需要选择器。

初次审查为 2026-10-07；以下条目于 2026-10-08 静态复核。状态只覆盖所述功能；Smoke／控件专项等此前通过记录为历史证据，本轮重跑范围见审查边界。

| 插件 | 状态 | 已覆盖 / 证据 | 剩余范围与接入版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（确认代码完成，客户端待验收） | API13 Core.ItemConfirmation；目标移除位于数据区末尾，复核目标并在隐藏时取消 | NPC非物品，物品解析／选择不适用；确认／取消／切页待验 / 2026-10-14 |
| YiboAutoOpen | 待评估 | [ItemResolver.lua](../../YiboAutoOpen/ItemResolver.lua) 本地解析物品 ID／链接／名字；TOC 将 Core 列为 OptionalDeps | Core 托管物品录入是候选；先确认独立运行约束与解析语义，再定范围，不能仅为迁移强制 Core 依赖 |
| YiboBeastPaths | 不适用 | 路线维护以坐标和路线数据为输入 | 无物品录入迁移项 |
| YiboBuilds | 不适用 | 当前构筑页面读取装备／配方数据，未发现可直接替换的物品输入选择器 | 业务动作与装备应用不自动纳入此项 |
| YiboCrafting | 部分接入（适用展示代码完成） | 1.2.0 / API13 / item-resolver:1；资料经 GetInfo，搜索只读已缓存项，事件去重；无物品编辑／批量确认／图标选择需求 | SearchPerformance／Smoke 通过；Tooltip 与实际搜索性能待客户端 / 2026-10-12 |
| YiboCurrency | 已接入（所列范围） | 0.9.1工作树 / API13；Settings复用CreateItemPicker、ItemResolver与ItemConfirmation，删除位于数据区末尾 | 中英文CoreItemControlsSpec通过；游戏内待验 / 2026-10-15 |
| YiboLegendary | 不适用 | 人工目标确认不是物品身份选择 | 不为统一形式改造成物品确认器 |
| YiboMail | 已接入 | 工作树 1.2.0-api1：NativeUI 附件加载复用 ItemResolver；指定规则使用 item-picker:2 的 multiple／retainInput；分类排除与全局黑名单复用单物品模式；初始化本轮检查 API v9、business-services:1 和 item-picker:2；使用公开配置 | 接口见 API-v8-批量物品确认；CoreItemControlsSpec、RuleSendUISpec、RuleSendSpec 和 InboxReleaseSpec 通过。游戏内待验收；新批量需求按契约扩展 |
| YiboMounts | 不适用 | 当前图鉴读取坐骑／物品来源，未提供通用物品录入 | 展示与来源查询不自动替换成选择器 |
| YiboQuestBlocker | 不适用 | 手动输入任务 ID | 校验与操作归任务业务 |
| YiboReputation | 不适用 | 搜索声望目录，未发现通用物品身份录入 | 声望搜索不属于物品解析 |
| YiboTaskHub | 部分接入 | 2026-10-09 0.3.1 的 Presentation 为三展示面使用 ItemResolver:GetInfo／Request 加载 item.itemID 图标；显式检查 API11 / item-resolver:1 和方法；来源 icon 直接渲染，缺失时通用任务图标 | OverviewSpec 包含一次请求、加载完成、非法元数据与缺能力停止；共 359 项回归通过，游戏内图标与加载效果待验收；后续编辑器仍需重新评估控件 |
| YiboTodo | 不适用 | 当前配置选择活动／目标，未发现通用物品身份录入 | 活动 ID 与业务条件不属于物品解析 |
| YiboVault | 部分接入（展示代码完成） | StoragePage 格子复用 `item-resolver:1` 加载展示；初始化检查 API13、能力与输入所需方法 | 输入按物品 ID 过滤是既定业务行为，无选择器迁移项；异步展示待客户端验收 / 2026-10-12 |

## CAP-004：账号页面、入口与设置接入基线

2026-10-18：Core 升至 1.12.7 / API 13，修正 `HandleEntryClick` 的业务入口右键路由，Core 入口仍打开“显示与入口”，业务 Broker／小地图／内置信息条直接打开对应业务页面设置；左键行为不变，无新增业务插件依赖。契约见 [三通道入口与内置条](API-v13-入口三通道与内置条.md)。

2026-10-13：Core 1.12.1 / API13 工作树新增 `account-preview-characters:1`，公开页面字段 `previewCharacterLimit`，默认20名兼容、false保留全部准入角色。契约见 [悬停角色范围](API-v13-悬停角色范围.md)。消费者按技术名：YiboMail 1.2.13 已接入代码，显式检查能力；WorkspaceSpec 验证24角色跨服务器、末位仓库角色、旧默认与显式数量，中英文1／4／18／24行含提醒／无提醒完整尺寸与受限滚动、缺失能力停止。客户端仍待验收，记部分接入；其它业务插件新字段待评估，默认行为保持。CAP-001 本轮服务器名称继续复用 FormatName，以选中范围为参考；CAP-002 原生输入未改、CAP-003 附件解析未改、CAP-005 队列通知未改、CAP-006 无新增引导、CAP-007 既有 identityOnly 保持、CAP-008 既有目标绑定保持，无新增本地公共能力实现。

2026-10-11：Core 工作树 API13 新增 [三通道入口与内置条契约](API-v13-入口三通道与内置条.md)，起始提供 account-entry:2 / builtin-entry-bar:2、schema11；后续 `builtin-entry-bar` 已向后兼容升至 v3，见 2026-10-12 更新。旧 RegisterBusinessEntry/defaultMode/legacyIDs 兼容，不提高未改业务插件最低版本。Core 的小地图／Broker／内置条及设置已统一接入，1156项入口／布局专项与相关回归通过；真实业务客户端验收待完成，各插件下表状态不因此变更。没有新增业务本地实现，后续主动消费新 API 时检查 API13 及所需能力。最近审查 2026-10-12；证据见实施记录。

2026-10-09 0.3.0 收拢：AccountPage 新来源／状态下拉全部使用 UITheme:CreateDropdown；预览继续消费可用高度预算；HUD／登录列表入口使用 SetPageScope 与 ShowPage 回到全服第一页。新增 OverviewSpec 验证折叠／展开、筛选、行池按钮及入口重置；无新增 Core 接口。用户 0.2.1 截图证实上一轮修复生效，本轮 UI 仍待验收，见 [收拢记录](../../Docs/行动中心-概念图收拢与流程修正.md)。

2026-10-09 O4／O5 联合复核增加 [视图可用高度](API-v11-视图可用高度.md)：Core 1.10.0 / API v11 / account-surface-budget:1，主页面与悬停在测量前提供高度预算，原有页面行为兼容。TaskHub 0.2.1 显式检查并直接消费；SurfacesSpec 现为 95 项，含真实 Core 测量、压缩后尺寸与缺能力停止。用户 0.2.0 截图已定位问题，修复后仍待客户端验收；其余业务页未触及。

2026-10-09 O4 按真实需求补齐 [角色准入通知](API-v11-角色准入通知.md)：Core 1.10.0 / API v11 / account-character-admission:1，隐藏及默认页面等级筛选有效变化后发出隔离事件。TaskHub 为首个消费者；无改动和无效输入不通知，订阅可清理。SurfacesSpec 追加 86 项检查包含实际 AccountView 路径，游戏内尚未验收。

已有公开接口见 [API v5](API-v5-业务插件接入指南.md)、[API v6](API-v6-业务插件增量接入指南.md) 与 [统一协作计划](Core-0.3-统一协作与改造计划.md)。下表登记源码路径，**不是运行时验收表**；存在注册路径统一记为部分接入，待验证实际行为和遗留分支后才能关闭本条目。2026-10-08 已静态复核；首次发布版本未逐一追溯。首次提示增量独立记录于 CAP-006。

| 插件 | 状态 | 已有接入与证据 | 剩余核对范围 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（适用代码完成，客户端待验收） | API13 / account-view:2 / account-entry:2；仅Core设置／账号页／入口；固定副本选择接入account-preview-field-groups:1；独立设置壳、旧窗口及小地图接口已移除 | 旧SavedVariables字段保留而不读取；双语布局及入口组合待验 / 2026-10-14 |
| YiboAutoOpen | 部分接入 | [CoreIntegration.lua](../../YiboAutoOpen/CoreIntegration.lua) 检查 API13、`localization:1` 与设置 UI 后可选注册统一业务设置；基础队列独立运行 | 2026-10-16：针对 Core 1.12.6 / API13 更新可选设置门槛与升级提示；设置面板内现有中文文案尚未迁移，Core 缺失／不足时队列仍独立运行 |
| YiboBeastPaths | 部分接入（适用调用代码完成／客户端待验收） | Mists 可选维护页与统一业务设置最低 API13，检查 account-view:2 / account-surface-budget:1，使用公开可用高度；无账号入口，不需 account-entry／builtin-entry-bar | 494项集成检查含 Core 缺失／旧版／缺能力、晚就绪、重复注册、关闭重开和失败回滚；双语 UI smoke 通过；实际交互待客户端 / 2026-10-13 |
| YiboBuilds | 部分接入（代码／离线通过，客户端待验） | API13统一页面与三通道入口；设置元数据双语，预览字段副本及ID校验；没有独立业务设置面板 | Core13Spec验证能力不足停止与重复注册；最低API13 / account-view:2 / account-entry:2；2026-10-15 |
| YiboCrafting | 部分接入（代码完成／客户端待验收） | 1.2.0 / API13；统一账号页、共享矩阵视觉／滚动／分页、嵌入设置、三通道注册和同快照预览；按业务快照准入和高度预算投影 | CoreAdaptation 通过；实际入口／字段／安全边界待客户端 / 2026-10-12 |
| YiboCurrency | 部分接入（适用代码完成／客户端待验收） | 0.9.1工作树 / Core1.12.4工作树 / API13，检查account-dynamic-fields:1、account-entry:2、account-preview-field-groups:1及表面／准入能力；自有目录动态字段注册、档案金币Provider、previewColumns、同源矩阵及可选悬停转置、统一工作台、三通道默认关闭 | 旧选择保留、动态增删、主表／悬停一致性：API13Spec四组各52项及EntryBar1133项通过；真实客户端待验 / 2026-10-15 |
| YiboLegendary | 部分接入（API13 代码完成／客户端待验收） | 工作树 2.2.0 检查 `account-view:2`、`account-entry:2`，注册本地化页面与 Core 业务设置，三入口默认关闭 | 核对悬停角色范围、完整矩阵、设置与三入口开关；本轮最低版本升至 API13 |
| YiboMail | 部分接入 | [AccountPage.lua](../../YiboMail/AccountPage.lua) 注册页面、入口与业务设置 | 当前工作树业务设置改造进行中；核对入口／账号快照与设置跳转，不能按旧文档直接认定完成 |
| YiboMounts | 部分接入（可选设置增强） | 1.0.0 检查 Core API13、初始化状态与 `localization:1`，注册 Locale 资源和 v6 设置面板；TOC 使用 `OptionalDeps: YiboCore` 保证加载顺序，未转为硬依赖 | Core 缺失／低版本时保留独立来源 Tooltip，停用收藏状态与 Core 设置；游戏内注册、设置保存和 Core 缺失／旧版路径待验收 / 2026-10-12 |
| YiboQuestBlocker | 部分接入（API13 代码完成／客户端待验收） | 工作树 3.1.0 检查 API13、`account-view:2` 与 `account-entry:2`；页面注册预览字段；Broker、小地图、内置信息条入口首次均关闭；业务设置仍交给 Core 工作台托管 | 核对账号页与悬停快照／准入／筛选一致性、字段可见性、三入口独立开关／右键设置路由、设置保存与安全高度；未消费的 `account-surface-budget:1` 不列为依赖 / 2026-10-12 |
| YiboReputation | 部分接入（API13 代码完成，客户端待验收） | 1.7.1 检查 `account-view:2`、`account-surface-budget:1` 与页面所需方法；保留 Core 统一页面、入口、设置、悬停预览和 20 角色默认范围 | 英文入口／布局与页面尺寸待客户端验收；声望由 Reputation 自有 Store 提供；旧 Core 只用于导入，角色删除接入 CharacterCleanup，87 项专项通过 / 2026-10-15 |
| YiboTaskHub | 部分接入 | 0.5.0 检查 API13 / account-entry:2、builtin-entry-bar:1，RegisterBusinessEntry 通过 defaultChannels 明确三个入口默认关闭；保留 Core 对用户选择的统一管理 | ActionIntegrationSpec 检查最低 API 与默认值；客户端验证三个通道切换、悬停与页面跳转待做；旧截图不替代新编辑器、窄窗口、IME 和完整登录流程验收 |
| YiboTodo | 部分接入 | 工作树 1.3.0 整体最低 API13；检查 `account-view:2`、`character-identity:1`、`character-name-format:1`、`account-entry:2`、`localization:1`；入口显式默认关闭三个通道 | Core 注册、设置与低版本停止待验证；首次提示独立见 CAP-006；中英文与三个入口通道待客户端验收 / 2026-10-12 |
| YiboVault | 部分接入（适用接口代码完成） | [AccountPage.lua](../../YiboVault/AccountPage.lua) 注册账号页、Core 业务设置及 `account-entry:2` 三通道入口；默认通道均关闭，最低 API13 | 账号页、入口通道与统一设置工作台行为待客户端验收；固定仓储页面由 Core 统一页面容器处理，不消费动态高度预算 / 2026-10-12 |

### CAP-004 增量：统一滚动表面预算（2026-10-16）

Core1.12.6 / API13未发布工作树提供account-surface-budget:2，[契约](API-v13-滚动表面预算.md)。Core按最终主窗口／入口悬停高度统一决定槽宽、向上取整及自然宽度优先，业务声明scrollContentHeight／scrollFixedHeight并通过GetScrollSurfaceWidth读取最终可用宽度。业务不再手工加减滚动槽；v1兼容。公共预算与账号页面本轮完成验证，不等于所有业务已迁移。

| 插件／区域（技术名排序） | 本轮状态／剩余范围 | 证据与触发点 |
| --- | --- | --- |
| YiboAltoBoss账号矩阵／锁定矩阵 | 已接入（2.7.1工作树；本轮范围离线通过，用户实机确认）；要求预算2及实际方法，主表两方向声明，锁定矩阵使用Core滚动容器 | MatrixBudget四组各100项、InstanceKills56；用户已确认本轮实机检查无问题；2026-10-16 |
| YiboCrafting账号／悬停矩阵 | 已接入（1.2.1工作树；本轮范围离线通过，用户实机确认）；预算2、分组／筛选计划与快照复用、显式悬停声明；专业多面板详情不套单矩阵预算 | MatrixBudget四组各100项，CoreAdaptation／CoreNameIntegration／Smoke／SearchPerformance／采集与目标回归；2026-10-16 |
| YiboCurrency主表／两种悬停 | 已接入（0.9.2工作树；本轮范围离线通过，用户实机确认）；显式要求预算2，取消本地槽宽计算 | 四组API13各52、Core预算10项及完整迁移回归；2026-10-16 |
| YiboLegendary目标列预览 | 已接入（2.2.3工作树；本轮范围离线通过，用户实机确认）；实际为角色行／目标列，预算2、图例固定高度、完整目标宽度及Core目标切片；升级检查已补 | MatrixBudget四组各100项含实际预览渲染、窄屏切片、字段隐藏与缺方法拒绝；2026-10-16 |
| YiboQuestBlocker主表／悬停 | 已接入（3.1.1工作树；本轮范围离线通过，用户实机确认）；要求预算2，完整角色范围任务分组与空态高度、Core宽度及悬停声明；隐藏角色字段无空页 | MatrixBudget四组各100项含实际主表／悬停、分组与分页一致及旧预算拒绝；2026-10-16 |
| YiboReputation主矩阵 | 已接入（1.7.2工作树；本轮范围离线通过，用户实机确认）；显式要求预算2，取消本地rows>20补槽，完整范围行发现后再切角色列 | 88+39迁移／清理、HoverSpec；用户已确认本轮实机检查无问题；2026-10-16 |
| YiboReputation监控预览 | 本次滚动槽不适用：独立布局声明verticalOverflow=none，没有纵向ScrollFrame | 保留既有分页和悬停检查，不预留空槽 |

Mail缓存／规则／原生界面的滚动槽调用属于独立内嵌列表，不是账号窗口自然宽度，不能直接套用窗口预算；后续触及这些独立容器时再评估适用的Core布局工具。Mail／Vault／Todo／TaskHub等页面本轮仅发现固定／行向或压缩布局，未做新预算的逐回调验收，保持待评估，不登记已接入。Core档案为字段列投影，不在本次角色列分页迁移范围。

CoreScrollBudget10、EntryBar1133、Contracts90、CharacterNames77与84文件语法及三owner语言检查通过。TaskHub旧SurfacesSpec前置Todo语言夹具失败，记录在契约中，不宣称整体通过。此次无运行时版本更新、提交、推送或打包。业务数据归属没有变化。

2026-10-16验收与版本补记：用户反馈“已实机看过没问题”，以上六插件本轮矩阵预算范围记为已接入；不扩展为其它功能或全部语言组合均已验收。配套工作树版本为Core1.12.6、AltoBoss2.7.1、Crafting1.2.1、Currency0.9.2、Legendary2.2.3、QuestBlocker3.1.1、Reputation1.7.2；API13及预算能力2不变，尚未提交、推送或打包发布。

## CAP-005：通用跨业务能力连接

2026-10-09 0.3.0 收拢：action.todo v1.0 增加可选 icon 显示元数据，Mail 1.2.5-api1 从自己附件快照提供纹理；中心验证并通用渲染，不按提供方技术名分支。MailSourceSpec 56 项、OverviewSpec 43 项，连同原集成与展示共 327 项。折叠只改变投影，保留所有原始身份、数量与业务引用。

2026-10-09 联合复核：Mail 1.2.4-api1 对 Schedule 的快照失效和同内容成功扫描的恢复发布已有 Items 事实，再由既有 action.todo Provider 合并通知。查询仍只读，不改变契约版本；TASK 通用消费，无来源分支。MailSourceSpec 55 项，连同展示及原集成共 283 项通过；邮件运行／启动／原生界面／API 回归通过。原始缺陷截图与修复后待验收项见 [联合记录](../../Docs/行动中心-O4-O5-联合验收与修复.md)。

### Core 状态与边界

- 初次设计时状态为待实现。2026-10-08 初次静态核对 [Registry](../Runtime/Registry.lua)、[Events](../Runtime/Events.lua)、[Capabilities](../Runtime/Capabilities.lua) 与 [Bootstrap](../Bootstrap.lua)：当时 Core 1.7.1 / API v8 没有跨业务 Service／Provider 调用接口。
- 真实需求为独立行动中心的需求下发、业务待办和角色工作流聚合；Core 只提供连接与生命周期，不接管中心、库存、配方或邮件数据。
- 当前契约：[API v9](API-v9-业务服务与刷新.md)。实现阶段 Core 1.8.0 起提供 Core.Contracts 的最小 Service 注册、发现、隔离调用和注销，能力为 business-services:1；未独立发布 api9，随 v1.9.0-api10 发起发布。本轮已登记 RuntimePerformanceSpec、MailProviderSpec、VaultIntegrationSpec、InboxReleaseSpec 通过；业务接入仍在工作树，游戏内待验收。
- 2026-10-09 工作树已提供 [API v11](API-v11-跨业务Provider.md) / `business-providers:1`；O2 已接入 Todo 首项 action.todo 输出与 TaskHub 消费，ContractsSpec 90 项、集成 70 项与相关回归通过。未发布、客户端待验收，草案 business-contracts:1 不作为实际能力检查。
- 实施范围为真实需要的最小连接、输入输出隔离、冲突、版本、晚注册、注销与通用事件；旧业务调用在涉及范围内逐步接入，既有 Core UI API 行为保持兼容。

### 业务接入台账

以下既有业务接入范围审查日期为 2026-10-08；2026-10-09 更新 Core Provider 实现和 Todo／TaskHub 下一步范围。Mail／Vault／Currency 的既有库存协作已接入最小 Service，最低 API v9，新回归通过不代表新增 Provider 已接入；其余业务状态不因 Core 扩展改变。

| 插件技术名 | 接入状态 | 已覆盖及证据 | 剩余范围与版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（运行代码与自动化完成） | 2026-10-10 2.6.0 经 Core 提供 boss.target-catalog 与 action.todo / planned-targets，消费 task.boss-targets；奖励观察、精确副本／难度、旧目录稳定键及自动投影均由来源负责，136项联动检查通过 | 基础 API13 / localization:1；目标能力继续要求 business-services:1 / business-providers:1，五人本 DBM 可选桥接复用 events:1 与 character-identity:1；客户端映射、窗口、切号及重置待验收 |
| YiboAutoOpen | 待评估 | 无该新连接接入证据 | 真实协作出现时评估，独立开包功能不因此扩展 |
| YiboBeastPaths | 不适用（当前范围） | 路线工具无跨业务查询、聚合或操作；Core 就绪通知复用公开 CORE_READY | 1.7.0 源码审查无业务对象／SavedVariables 读取；真实协作出现时重审 / 2026-10-13 |
| YiboBuilds | 部分接入（代码／离线通过，客户端待验） | action.targets Provider为构筑所有者提供具体装备强化目标，Core负责发现与操作绑定 | 既有实际应用判断保持；双语标题与错误；最低API13 / business-providers:1 / business-item-actions:1；安全点击待客户端验收；2026-10-15 |
| YiboCrafting | 部分接入（当前连接代码完成） | 1.2.0 / API13；action.targets v1.2 注册／发现／公开库存调用，生命周期通知；制造规则与基线归来源，无业务私有访问 | GoalSourcesSpec72／GoalTargets 通过，尊重公开库存 validUntil；可选来源客户端待验收，配方只读 Service 是后续产品功能 / 2026-10-12 |
| YiboCurrency | 已接入（本轮连接范围，客户端待验） | 0.9.1工作树 / API13 / business-services:1、business-providers:1、character-archive-providers:1；vault.items经Resolve／Call，TOC无业务依赖，缺失／注销／不兼容／错误回退确认来源，返回覆盖校验 | VaultIntegrationSpec原样通过（已补身份夹具及生命周期回归）；货币权威迁移代码完成，实机待验；整角色Vault单一来源或自有随身快照，无旧Core运行读 / 2026-10-15 |
| YiboLegendary | 待评估 | 无该新连接接入证据 | 真实待办／目标接入时评估 |
| YiboMail | 部分接入（Provider代码与自动化完成／客户端待验收） | 1.2.11-api1：既有mail.items v1.1 GetTransfers按全账号签名／时间证据索引匹配，纯状态复用缓存且公共revision保持最新；自动查看多封信合并通知。邮件与新邮件查看状态仍由Mail所有，Vault仅经Core Service消费 | 基础API13 / business-services:1；TransfersPerformanceSpec 20角色／3411历史约0.04秒（旧约0.73秒），100封确认1次通知；MailProviderSpec真实服务集成与缺失／不兼容／晚注册通过。客户端仍待复验；logistics／evidence仍未公开 / 2026-10-12 |
| YiboMounts | 不适用 | 1.0.0 全面接入复核：Tooltip 图鉴只读取自身坐骑目录与 Core 账号级设置，无跨业务查询、提供或聚合需求 | 出现真实跨业务需求时按 Service／Provider 契约评估 / 2026-10-12 |
| YiboQuestBlocker | 待评估 | 无该新连接接入证据 | 不把阻止接任务当成任务数据能力；真实需求出现再评估 |
| YiboReputation | 部分接入（目标 Provider 已接入，客户端待验） | 1.7.1 通过 Core.Contracts 注册 action.targets v1.1；Normalize／Evaluate 读取插件自有声望快照，未知友谊等级不回退普通 standingID；迁移专项覆盖已知／未知／采集错误目标判断 | 目标增强 API12 / business-providers:1、business-item-actions:1；总体最低 Core1.12.4 / API13；可选消费者与客户端继续验收 / 2026-10-15 |
| YiboTaskHub | 部分接入（运行代码与自动化完成） | 2026-10-10 0.4.0 通用消费 Todo 全量／Mail／AltoBoss action.todo，并提供 task.boss-targets、消费 boss.target-catalog；计划由 Task 保存，逐角色双向复制通过 Service 协作，schema3 迁移；672项检查通过 | API11 / business-services:1 / business-providers:1；本轮仅实现刷取计划安排，通用跨角色制作／任务链未实现；客户端待验收，见 [运行契约](../../Docs/行动中心-AltoBoss-运行契约与验收.md) |
| YiboTodo | 部分接入（运行代码与自动化完成） | 2026-10-09 1.1.4 注册神纹布与诺米 action.todo，独立 epoch／revision／覆盖与合并通知，持久元数据分开；实际模型及 133 项集成、日常／冷却／动作／旧日常回归通过 | 新集成 API v11 / business-providers:1；基础 UI 保留 API v10。游戏内观察、交付／重置与中心一致性待验收；当前已扩展至全部适用监控项目，见下方 2026-10-09 全量接入复核 |
| YiboVault | 部分接入 | 1.2.1-api1 工作树消费 Mail `mail.items` v1.1 可选转移投影；Query、邮件仓储格与 Tooltip 单独显示在途，且不计入持有小计；vault.items 提升 v1.1 并保持 v1.0 消费兼容；本次未运行自动化 | 插件整体最低 Core API13；Service 仍只需 `business-services:1`。Mail 缺失／v1.0 时保留本地扫描基础行为；客户端联动待验收 / 2026-10-12 |

行动中心技术名为 YiboTaskHub；2026-10-08 建立项目基础与客户端联接，2026-10-09 O2 已完成首项 Provider 消费及 Core 主页／入口，客户端待验收。其他业务能力仍按真实接入分别登记，不能推定全仓库迁移完成。

2026-10-09 O3 增加 Todo 的诺米 Provider；本次实际 diff 触及来源输出／注册／通知和中心状态文本。CAP-005 复用已有公开连接与版本门槛；中心既有主题／名称调用无改动，CAP-001／004 的客户端验证状态不变。没有新增通用输入、物品解析或首次提示调用，CAP-002／003／006 本次不适用。

## CAP-006：页面首次打开提示

### Core 状态与边界

- Core 1.9.0 / API v10 已提供，注册能力为 account-view:2；契约见 [API v10](API-v10-首次打开界面提示.md)。渠道包 v1.9.0-api10 包含 api9，截图为上传中；这不改变 v5 页面注册基础接口的最低要求。
- [AccountView](../UI/AccountView.lua) 读取页面定义 `firstUseTip`；[Theme](../UI/Theme.lua) 提供 ShowFirstUseTooltip；[Database](../Data/Database.lua) 默认保存 firstUseHints。只在主视图成功显示后记录，以 pageID 区分，6 秒自动关闭；预览不触发。Core 概览已使用。
- 业务插件提供提示文案，Core 不解释业务、复制业务缓存或替代必需的状态／风险说明。本轮静态确认调用与版本检查；没有首次提示专项自动化或游戏内验收证据。

### 业务接入表

最近审查：2026-10-08。`不适用` 仅表示当前未注册首次提示，无须为了追赶版本给每页强加提示；后续真实需要时重审。

| 插件技术名 | 状态 | 已覆盖 / 证据 | 剩余范围与版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboAutoOpen | 不适用（当前范围） | 可选设置注册无 firstUseTip | 独立功能不因此提高 Core 门槛 |
| YiboBeastPaths | 不适用（当前范围） | 可选维护注册无 firstUseTip | 独立功能不因此提高 Core 门槛 |
| YiboBuilds | 部分接入 | CoreIntegration模型旋转／缩放提示已双语；统一API13 / account-view:2启动检查 | Core13Spec正常注册及缺失能力停止通过；一次性显示、预览与计时游戏内待验；2026-10-15 |
| YiboCrafting | 不适用（已审查） | 1.2.0 状态、搜索和添加提示常显；没有依赖一次性提示的隐藏操作 | 新增首次引导需求再评估 / 2026-10-12 |
| YiboCurrency | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboLegendary | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboMail | 不适用（当前范围） | 页面无 firstUseTip | 安全提示继续常显；新增引导时评估 |
| YiboMounts | 不适用（当前范围） | 可选设置注册无 firstUseTip | 独立功能不因此提高 Core 门槛 |
| YiboQuestBlocker | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboReputation | 部分接入（API13 代码完成，客户端待验收） | 1.7.1 提示文案经 Core Locale 注册中英文；整体初始化检查 API13 与 `account-view:2` | 静态资源已检查；低版本升级提示、一次性显示、预览不触发及计时待客户端验收 / 2026-10-15 |
| YiboTaskHub | 不适用（O4 范围） | 2026-10-09 主页面及只读展示没有低频操作引导，HUD 拖动／锁定说明在业务设置常显，未登记 firstUseTip | 后续编辑器存在真实引导需求时重新评估 |
| YiboTodo | 部分接入 | CoreIntegration 使用 firstUseTip；整体最低 Core API13 并检查 `account-view:2` | 工作树；低版本提示与停止、一次性显示、预览及计时待验证 |
| YiboVault | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |

## 后续方向与实现状态

| 方向 | 当前证据 | 对迁移节奏的影响 |
| --- | --- | --- |
| 中英文客户端适配 | 已实现 localization:1 / API13，见 CAP-009 与语言服务文档；客户端待验收 | Core 已提供不代表业务已接入；按触及区域迁移并登记最低版本和验证证据 |
| 内置 LDB 与信息条 | 2026-10-11 工作树已内置三库，提供 account-entry:2 / builtin-entry-bar:2；三通道和总开关实现，1156项专项通过，客户端待验收 | 方案明确保留 RegisterBusinessEntry、defaultMode 与 legacyIDs 兼容；主要由 Core 改造，不作为全插件追版本的前提 |
| 业务任务聚合 | CAP-005 的 Provider／List 已提供；Todo／Mail 三个 action.todo 与 TaskHub 四个展示面已有代码及自动化 | 按真实提供方／消费方继续扩展；两个业务所有者已接入，不等同于全部业务或跨角色安排已实现 |
| 网络通讯协议 | 本轮在业务运行 Lua 中未找到 SendAddonMessage／CHAT_MSG_ADDON／RegisterAddonMessagePrefix；本机 Core.Events／Contracts 不属于网络协议 | 需求、契约和实现版本尚未确定；不作为当前追赶完成条件 |

## 其他现有能力索引

2026-10-08 按 TOC 所加载源码的 Capabilities:Register 复核；以下显式记录能力版本，不能把能力版本与 Public API 版本混为一谈：

| 类别 | 已注册能力 | 后续处理 |
| --- | --- | --- |
| 运行与配置 | runtime:1、database:1、migrations:1、events:1、resources:1、fields:1、addon-catalog:1、addon-status:1 | 现有基础设施；发现具体重复实现或版本缺口时建迁移条目 |
| 角色与数据 | characters:1、character-cleanup:1、character-profile:1、data-domains:1、domain-store:1、level-filter:1 | 角色身份与清理已有公共接口；character-profile 是旧兼容层，新功能按现有指南读取 DataDomains。数据域内容仍须遵守业务所有权 |
| 账号 UI | account-view:2、account-entry:2、builtin-entry-bar:3、account-character-admission:1 | 角色准入通知见 API-v11-角色准入通知；接入基线见 CAP-004，首次提示见 CAP-006；注册存在不代表全部行为已验收 |
| 输入与物品 | basic-input:1、item-resolver:1、item-picker:2、currency-catalog:1 | 迁移见 CAP-002／003；currency-catalog 后续有真实迁移需求时单列 |
| 名称与连接 | character-name-format:1、business-services:1 | 见 CAP-001／005；business-contracts 尚未注册 |

Core 1.7.0 新增 `character-name-format:1`，接入进度见 CAP-001。接口索引不构成新建服务目录或迁入业务数据的授权。

## 首次审查待处理项

| 编号 | 事项 | 关联能力 | 处理触发 / 验证要求 |
| --- | --- | --- | --- |
| AUD-001 | 公共名称格式化：Core 阶段已完成，业务阶段待迁移 | CAP-001 | Core 接口、契约与兼容自动化验证已完成；游戏内核对及各业务插件接入继续随对应功能推进 |
| AUD-002 | Mail 输入／选择器最低要求已修正 | CAP-002／003 | 工作树 1.1.0-api1 检查 API v8、名称能力与 item-picker:2；InboxReleaseSpec 覆盖升级提示和停止行为，已关闭 |
| AUD-003 | Vault 最低 API 缺口关闭 | CAP-002 | 本轮初始化要求 API v9 / business-services:1，低版本停止并提示升级；搜索框原公共调用保留 |
| AUD-004 | Mounts 使用 v6 设置注册接口却仅检查 API v5 | CAP-004 | 下一次 Core 设置接入修改时修正，并明确独立运行／加载顺序 |
| AUD-005 | AltoBoss 仍保留独立设置壳回退 | CAP-004 | 后续涉及设置壳时收拢；如需旧版兼容例外，记录必要性、边界与移除条件 |
| AUD-006 | Mail 已通过公开配置保留确认输入 | CAP-003 | Core 1.7.1 提供 retainInput 与 multiple；CoreItemControlsSpec 与 RuleSendUISpec 验证生命周期，已关闭 |
| AUD-007 | Currency 服务发现已接入，但 TOC 仍有 OptionalDeps: YiboVault | CAP-005 | 下一次服务链／依赖接入修改时核实并收拢加载顺序依赖，验证 Vault 缺失、晚注册、注销与不兼容；本轮只登记，不改 TOC |
| AUD-008 | API 总览过期，与 Core 发现边界冲突 | CAP-005 | 本轮更新总览至工作树 v10，修正 Mail 阶段及“直接调用业务提供方”的旧指引；已关闭，仅文档修正 |
| AUD-009 | 名称测试把当前 API v10 当未来版本拒绝 | CAP-001 | 2026-10-09 已关闭：接受 v10／当前版本、拒绝 API_VERSION+1；CharacterNamesSpec 77 项通过，旧版兼容覆盖保留 |
| AUD-010 | 首次提示只有静态证据 | CAP-006 | 补契约与低版本停止验证，并在游戏内核对一次性、预览不触发、计时及帮助页；保持部分接入 |
| AUD-011 | Crafting 角色显示接入代码已修复，客户端待验收 | CAP-001 | 2026-10-09 将列头交给 Core 共享表头，角色下拉／详情改用 FormatName，检查 API v8／character-name-format:1 和所需方法。CoreNameIntegration 验证不兼容升级提示、初始化停止／幂等及表头复用；Smoke 与 Core 名称 77 项通过。游戏内显示待验收，工作树未提交 |
| AUD-012 | Crafting 标准搜索输入代码已修复，客户端待验收 | CAP-002 | 2026-10-12 1.2.0 改为 CreateInput 回调并保留共享 IME／提交／清空生命周期，整体 API13 / basic-input:1；CoreAdaptation 与原回归通过，实际客户端待验收 |

## 更新记录

| 日期 | 更新范围 | 结果与证据 |
| --- | --- | --- |
| 2026-10-10 | TaskHub 0.4.0／AltoBoss 2.6.0 刷取目标 | CAP-002 更新 Task 共享输入；CAP-004 更新共享业务标签页与工作台；CAP-005 登记两个 Service／一个 Provider 和最低版本边界。目标136项、原536项通过；CAP-001 新增 Task 角色选择及 AltoBoss 目标行动标题复用 FormatName；AltoBoss API5 基础行动保留原显示逻辑，版本兼容边界已记录；CAP-003 原物品显示未改；CAP-006 必要说明常显，无新首次提示。运行与自动化完成，客户端待验收，未发布 |
| 2026-10-09 | TASK 角色显示与新邮件语义复核 | TaskHub 0.3.1 的名称格式化已接入，补齐共享角色控件与 GetDataRowColor，显式检查所需方法；CAP-001／004 更新。Mail 1.2.6-api1 改为每角色一条新邮件提醒，已看未取由来源确认，CAP-005 更新。CAP-003 原调用保留并回归；本轮无输入／选择器及首次引导，CAP-002／006 不适用。359 项、Core 名称 77 项、邮件／Vault 回归通过；未提交／发布，客户端待验收 |
| 2026-10-09 | O5 邮件待收取跨业务来源 | Mail 1.2.4-api1 新增 action.todo，TaskHub 无运行改动；46 项新增／265 项累计与邮件启动／运行／API 回归通过。实际 diff 仅新增 Provider 注册、通知和业务投影，CAP-005 版本门槛与失败清理已接入；CAP-001／002／003／004／006 无新接入变化，旧迁移库存保持。未提交／发布，客户端待验收 |
| 2026-10-09 | O4 展示与提醒及角色准入通知 | Core 先补 account-character-admission:1，TaskHub 0.2.0 再接入；实际 diff 收拢名称／详情、预览字段、业务设置与角色准入。219 项集成及展示、Core 连接 90 项／名称 77 项／性能、待办日常回归与 88 个加载 Lua 语法通过。用户确认 0.1.1 主页面外观；O4 客户端待验收，未提交／发布 |
| 2026-10-07 | 建立台账；首次静态审查 Core 与全部 13 个业务插件 | 登记 CAP-001～004、现有能力索引及 AUD-001～006；源码路径见各表；本轮仅文档更新，未修改运行代码或运行测试 |
| 2026-10-07 | CAP-001 Core 实施 | Core 1.7.0 / API v8 提供 FormatName 与 character-name-format:1，完成 Core 内部显示迁移；75 项名称／兼容检查、44 文件语法检查及 Currency 控件回归通过。业务状态保留，游戏内尚未验收 |
| 2026-10-07 | Mail 1.1.0 工作树接入；Core 1.7.1 批量控件扩展 | CAP-001 记录已覆盖与剩余名称调用；CAP-002 最低版本缺口关闭、旧输入保留待迁移；CAP-003 完成所列范围接入；AUD-002／006 关闭。相关自动化及 Core／Mail 66 文件语法检查通过；尚未发布，游戏内待验收 |
| 2026-10-08 | CAP-005 通用跨业务连接契约设计 | 新增待实现条目，计划 API v9 / business-contracts:1，登记首批业务现状与后续范围；未新增连接运行时、未接入业务或执行测试 |
| 2026-10-08 | 新建 YiboTaskHub 项目基础 | CAP-001～005 登记新插件为待评估；TOC、Namespace 和客户端目录联接已建立，尚无公共能力接入 |
| 2026-10-08 | 刷新扫描修复与最小 Service 实施 | CAP-003 记录 Mail／Vault／Crafting 展示加载；CAP-005 记录 Core business-services:1 与 Mail／Vault／Currency；接口与测试见 API-v9 文档。未发布、游戏内待验收 |
| 2026-10-08 | 台账复核与迁移节奏审查 | 修正当前工作树 1.9.0 / API v10、CAP-005 总表及能力版本；新增插件最低版本表、CAP-006 和规划观察项；更新 API 总览，登记 AUD-007～010。4 个相关测试通过，名称测试因过期版本断言失败；仅改文档，未修改 AGENTS 或运行／测试代码 |
| 2026-10-08 | api9／api10 合并发布与追赶记录 | 用户确认跳过 v1.8.0-api9，随 v1.9.0-api10 发布；HEAD 已为 1ef9ccf，截图 api10 上传中。新增同批追赶要求与分代验收清单，修正 Core 当前发布依据；业务接入／验证状态不因 Core 发包自动完成 |
| 2026-10-08 | 触及即迁移执行审查 | 对规则生效时点、Core 合并提交及 38 个业务运行 Lua diff 逐项核对；列 10 个正确迁移实例、1 个当前调用层漏迁、1 个较早已提交历史漏迁。未触及旧实现不计违规；新增 AUD-011／012，仅改审查与台账文档 |
| 2026-10-08 | 确认迁移节奏与持续观察 | 用户确认保留触及即迁移，集中追赶随无限服开服后的各插件大幅更新执行；AGENTS 增加收尾 diff 核对，台账记录实际接入与遗漏。明确搜索清空已在 Core，业务搜索框需接入标准输入；未改运行代码 |
| 2026-10-09 | O1 Provider 与真实任务映射 | CAP-005 登记 Core 1.10.0 / API v11 / business-providers:1 与自动化回归；Todo／TaskHub 记待迁移、无运行接入；AUD-009 关闭。未发布、客户端待验收 |
| 2026-10-09 | O2 首项输出与两个角色列表 | Todo 1.1.3／TaskHub 0.1.0 接入 action.todo；70 项集成及待办／Core 回归、36 文件语法通过。按本轮实际修改审查 CAP-001～006，更新名称、页面／入口与 Provider 接入；客户端待验收，未提交／发布 |
| 2026-10-09 | O3 诺米第二来源 | Todo 1.1.4／TaskHub 0.1.1，两个真实 Provider 同属 Todo；133 项集成及待办日常／冷却／动作／旧日常、Core 连接／性能回归通过。复用 Core API v11，更新 CAP-005；其余本次相关能力无新接入变化，客户端待验收，未提交／发布 |
| 2026-10-09 | Crafting 专业与角色联动筛选 | 专业归属沿用 Core.DataDomains，自然宽度与分页复用 AccountView 公开接口；专业筛选、状态范围与 Core 原范围保留的针对性验证、Lua 5.1 语法通过。此次相关角色显示遗漏已在下一项补齐，AUD-011 更新为代码已修复、客户端待验收。输入控件及业务服务等未触及的旧范围继续按原状态登记 |
| 2026-10-09 | Crafting 角色表头及名称 API v8 接入 | 矩阵使用 Core 共享表头，角色下拉／详情使用 FormatName；初始化与注册要求 API v8，检查名称能力和方法，失败时提示升级并停止初始化。CoreNameIntegration、Crafting Smoke、Core 名称 77 项及四个相关文件语法通过；CAP-001 部分接入、AUD-011 代码已修复，游戏显示待验收 |


2026-10-09 CAP-005 / Todo 全量接入复核：YiboTodo 1.2.0 保持 API v11 / business-providers:1 门槛，基础 UI 继续最低 API v10。`profession-cooldown` 输出全部适用冷却组；
omi` 保留；新增 `activities` 输出其余 `monitoringProjects`，账号布林顿去重并投影候选。Core 连接实现和 TaskHub 消费实现无需改动。TodoSourcesSpec 177 项、原 359 项以及全部 Todo 烟雾测试通过；低版本停止、三来源注销／重注册已验证。状态仍为“部分接入（运行代码与自动化完成，客户端待验收）”。CAP-001／002／003／004／006 本次无新接入变化；未触及调用继续保持原台账状态。范围与实际契约见 [全量接入记录](../../Docs/行动中心-Todo全量接入.md)。

2026-10-12 CAP-005 Mail／Vault批量取件：Mail 1.2.12合并同轮扫描与收取归档通知、队列中间状态只更新原生进度；Vault 1.2.2经Core Contracts消费可选transfersUnchanged提示，仅状态变化刷新当前角色，缺失提示／实际数据／混合批次保持全账号刷新。最低API13／business-services:1不变，无来源私有访问；MailRuntimeSpec 30封90附件库存与归档一致、180次通知、1次队列完整刷新；MailProviderSpec含状态范围、混合失效、在途核实与缺失／不兼容／晚注册通过，客户端待验收。Core公共接口没有变化，CAP-007身份调用继续沿用既有接入，无新增能力迁移。

## CAP-007：轻量角色身份投影

2026-10-10；Core 状态：已提供（1.10.0 工作树，未发布）；API v11 / character-identity:1。职责、选项、返回字段、缺失及默认兼容语义见 [API 文档](API-v11-轻量角色身份.md)。不复制 domains，无新业务存储。

| 插件 | 状态与已覆盖范围 | 剩余范围／验证 | 最近审查 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（适用代码完成，客户端待验收） | API13 / character-identity:1；身份读取统一 identityOnly，公开角色引用经Core唯一ID，旧数据存储键不变 | 多角色／改名／缺失身份实机待验 / 2026-10-14 |
| YiboBeastPaths | 不适用：显示宠物／路线／坐标，不读取角色身份目录 | 1.7.0 Core 集中接入审查；新增跨角色功能时重审 | 2026-10-13 |
| YiboCrafting | 部分接入（适用代码完成） | 1.2.0 目标角色目录／存在性使用 identityOnly；领域快照单独 DataDomains:Get，检查 character-identity:1 / API13 | GoalTargets／来源集成通过，客户端待验收 / 2026-10-12 |
| YiboCurrency | 部分接入（适用代码完成） | 0.9.1工作树 / API13，目标角色校验使用Get(identityOnly=true)，检查character-identity:1与实际方法；API13Spec四组各52项通过，客户端待验 | 2026-10-15 |
| YiboMail | 部分接入（高频身份路径代码完成／客户端待验收） | 1.2.11-api1 收件箱／账号视图、名称、状态、扫描、队列、行动投影及新建历史占位使用 identityOnly；联系人与寄送经公开只读目录补阵营；既有最低 API13 并检查 character-identity:1。未触及的设置页／诊断低频完整读取保留 | 真实 Core 10,000物品对照，100轮邮箱身份／名称／状态／联系人约180KB、0领域复制；相关7个Spec通过，另2个既有夹具失败已用HEAD复核。详见 `../../Docs/Mail-内存与首次打开性能修复.md` / 2026-10-12 |
| YiboMounts | 不适用 | 本轮审查的 Tooltip、坐骑目录与独立设置不读取 Core 角色身份目录或领域快照 | 新增账号角色级坐骑页面时重审 / 2026-10-12 |
| YiboTaskHub | 已接入：全部角色身份、目录、受益者、目标校验、主视图／预览／提醒；检查能力 | 无本次范围遗漏；Overview50项及依赖回归、专项219项通过 | 2026-10-10 |
| YiboTodo | 已接入：Bootstrap 任务事件、DailyQuest 观察、Snapshot、行动投影；最低API v11并检查能力 | 未触及的专业／农场采集和旧页面完整读取为后续库存；九个smoke与TodoSources177项、专项219项通过 | 2026-10-10 |
| YiboVault | 部分接入（代码完成／客户端待验收） | Tooltip 与仓储页使用 FormatName；业务目标显式范围使用 `identityOnly` 身份查询；初始化检查 API13 / `character-identity:1` | 仅覆盖本插件实际角色标签与身份查询；显示、范围与目标交互待客户端验收 / 2026-10-12 |

其它插件尚未审查本能力，不推定已接入或不适用。未来触及只需身份、存在性或等级的查询时迁移；需要完整领域快照的既有查询保持默认形式。

CAP-005 本轮复核：TaskHub 仅按稳定 Provider 标识与范围缓存、精准失效；AltoBoss 目标配置仍经 Core Service，缓存随 registrationRef／变化事实失效，投影仍由来源生成。无跨业务对象或 SavedVariables 读取。CAP-001／CAP-004 已接入的名称、统一准入和窗口刷新继续复用，本轮未新增UI壳或业务来源分支。测试与客户端复测边界见 [性能记录](../../Docs/任务链-性能异常修复-2026-10-10.md)。

2026-10-10 悬停／显隐设置复核：CAP-004 的 YiboTaskHub 本次业务设置继续复用统一工作台与共享控件，以 ShowSettings("sorting") 和 ShowSettings("todo") 跳转既有入口，不重复保存角色准入／来源监控。CAP-005 的 Todo 三个来源新增可选 displayGroups／task.displayGroup 展示元数据，TaskHub 经既有 Core Provider 获取完整冷却／活动目录，不直读来源业务对象或数据；缺少目录仅支持来源级显示开关。CAP-001／002／003／007 本次涉及调用保持现有接入与最低版本声明，无新增本地回退。46项显隐专项、既有集成回归和219项性能回归通过；客户端待验收。详情见 [显隐设置与契约](../../Docs/行动中心-显隐设置与悬停规则.md)。


## CAP-008：业务项目主动添加

2026-10-11 设置入口复核：共享添加方式与目标标记仍由 Core 的窗口页统一渲染保存；TaskHub 业务设置新增“添加方式与目标标记”直达按钮，通过既有 AccountView:ShowSettings("core") 导航，不重复设置控件或数据。宽窄布局相应预留按钮高度，沿用 API12 最低版本要求。

2026-10-11 触及审查：Core 增加 business-item-actions:2，统一鼠标焦点追踪和可选旁侧按钮位置；版本 1 调用兼容。Crafting 1.0.7 目标增强检查 API12 / 能力2，名称、产物、已学矩阵格均复用公共绑定，无业务本地按钮。TaskHub GoalEditor 消费 action.targets v1.2 可选执行范围元数据，维持原提供者兼容，无来源名分支。共享角色身份与专业归属来自 Characters / DataDomains，持有判断经 Contracts 调用 Vault；Core 不承担制造判断。GoalSourcesSpec 60 项、GoalsSpec 94 项及 Crafting 四项、BossTargetsSpec136 和 Lua语法检查通过；悬停视觉、跨角色共享任务及实际完成仍待游戏验收，接入记为部分完成。未触及能力维持原状态。

2026-10-10 客户端反馈复核：Core 菜单改为悬停显示与延迟 Lookup，九个业务绑定继续复用同一公共能力，无本地重复按钮。Task 添加导航经 CAP-005 的 action.targets v1.1 GetEntry 发现九个来源；v1.0 评估保持兼容。Task 角色显示偏好、分页及源状态继续复用 CAP-001／002／004／007 的名称、共享控件、账号壳与轻量身份，不建立第二套角色数据或设置窗口。AltoBoss 补 action.targets 变化通知，Task 目标投影不复制历史并仅清过期缓存。230项目标专项及相关回归通过；客户端视觉、战斗安全和性能采样待复测。详见 [反馈记录](../../Docs/行动中心-客户端反馈修复与发布前检查-2026-10-10.md)。

Core 状态：已提供，工作树 1.11.0 / API v12 / business-item-actions:1，未发布。职责、方法、失败行为与版本要求以 [API v12](API-v12-业务项目主动添加.md) 为准。目标写入与业务评估经 CAP-005 的既有 Contracts；Core 不保存用户目标或业务数据。

| 插件技术名 | 接入状态／已覆盖 | 剩余范围与验证 | 最近审查 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（适用代码完成，客户端待验收） | API13 / business-item-actions:3；世界／节日／副本及自定义目标通过公开主动添加，副本启用Core精简TP | 手势／菜单／缺参数待实机；不保留本地按钮回退 / 2026-10-14 |
| YiboAutoOpen | 本轮对象不适用：即时操作 | 后续真实持久目标出现时评估；未改变基础功能 | 2026-10-10 |
| YiboBeastPaths | 本轮对象不适用：路线说明 | 无角色驯服完成采集；后续收藏入口再评估 | 2026-10-10 |
| YiboBuilds | 部分接入：宝石／附魔实际候选、具体装备与孔位；统一最低API13 / business-item-actions:1 | 原低版本基础功能兼容分支已收拢；客户端GUID／安全点击待验 | 2026-10-15 |
| YiboCrafting | 部分接入（代码完成／客户端待验收） | 1.2.0 / API13 / business-item-actions:2；配方名称、产物及已学角色格均走 Core，无本地按钮 | 默认参数／多产物配置／键鼠回归通过；真实交互待客户端 / 2026-10-12 |
| YiboCurrency | 部分接入：原生货币／金币角色格与标题 | 0.9.1工作树整体API13；目标增强检查business-item-actions:1／business-providers:1／character-identity:1与实际方法。API13Spec覆盖开启及stale未知；物品目标归Vault，账号合计不在范围；客户端待验 | 2026-10-15 |
| YiboLegendary | 部分接入：角色最终目标；增强最低API12 | 客户端；任意中间节点与整链未接入 | 2026-10-10 |
| YiboMail | 部分接入：角色明确查看邮件目标；增强最低API12 | 客户端；寄达／收取需求关联未接入 | 2026-10-10 |
| YiboMounts | 当前入口不适用：Tooltip 来源说明 | 未来收藏管理入口与完成采集再评估 | 2026-10-12 |
| YiboQuestBlocker | 本轮对象不适用：屏蔽规则 | 规则不转目标；未来真实业务对象另评估 | 2026-10-10 |
| YiboReputation | 部分接入：角色声望单元格、来源等级；增强最低API12 | 1.7.1 使用 Reputation 自有 Store；87项专项覆盖正常与未知／错误快照，不将缺失好友度等级解释为普通standing；客户端与消费者联动待验 | 2026-10-15 |
| YiboTaskHub | 部分接入：action.demands v1、参数面板、手势消费与目标定位；整体最低API12 | 客户端；代码及自动化闭环完成 | 2026-10-10 |
| YiboTodo | 部分接入：角色项目精确目标，不依赖显示监控；增强最低API12 | 客户端周期／账号活动；基础旧版本分支属兼容例外 | 2026-10-10 |
| YiboVault | 部分接入：仓储物品格、阈值与固定账号范围；整体最低API13，增强检查兼容的 `business-item-actions:1` 与角色身份能力 | 客户端仓储完整性；公会／拍卖目标未接入；Core v2 扩展保持对 v1 调用兼容 / 2026-10-12 |

验证证据：GoalsSpec62、GoalSources40、BossGoals15、GoalSurfaces12；相关原集成672、性能219、布局197、显隐46、Core连接90／名称77、Todo九个smoke及Crafting两个smoke通过；17TOC／255Lua语法通过。详见 [实施与验证](../../Docs/行动中心-主动添加实施与验证.md)。自动化帧夹具不代替客户端验收，因此业务状态记“部分接入”。新增实际对象或修改同类入口时复用本能力；暂无对象的插件不提前生成空Provider。

### 本轮直接相关公共能力核对

- CAP-001／007：新增参数角色下拉、来源校验、作用域与目标管理显示使用 Core.FormatName / identityOnly，不以短名关联业务。本轮新增调用已接入；其它旧范围保持原台账状态。
- CAP-002／003／004：目标编辑复用共享输入／下拉／按钮和统一账号壳；移除及复制复用 ItemConfirmation；仓储物品名称复用 ItemResolver；不建第二套窗口、入口或角色设置。本轮直接相关逻辑已接入，客户端待验收。
- CAP-005：新增 action.demands Service 与九个 action.targets Provider，制造→库存公开调用、Boss兼容配置投影都经Core；Task目标所有权唯一，来源查询不读Task内部实现。来源内部读取自身Catalog／SavedVariables不越权。
- CAP-006：本轮未修改首次提示机制，原接入状态保持；新增空态引导是必要产品说明。
- 兼容例外：九个来源仅主动添加增强要求API12，原有基础业务继续自身旧最低版本；低版本显式提示并停止增强，没有新交互本地回退。适用旧Core；当来源整体提升最低版本时收拢此分支。TaskHub整体最低API12。

CAP-007 历史记录：Vault Items 对个人仓储的明确 characters 范围逐个 Get(identityOnly=true)，不枚举并复制全部角色领域。此前 Items 查询兼容旧 Core；2026-10-12 Vault 整体最低版本升至 API13，旧 Core 身份回退已收拢；目标增强仍单独检查角色身份能力。本轮代码完成，客户端范围与目标行为待验收。

2026-10-10 CAP-008 追加审查：九类来源已有绑定直接复用 Core 常驻已加入折角与保持窗口的手势；无业务本地实现新增。CAP-005 的 action.demands v1.1 新增 LookupItems，按帧批量、按库 revision 索引；旧 minor0 保留添加，仅不显示可选标记。GoalsSpec 87 项覆盖角色、状态、移除、复用、注销、查询合并和中键不导航；客户端悬停与图标位置待复测。

2026-10-10 CAP-008 农场与切换手势复核：Todo 补齐农场目录校验，继续使用既有 Snapshot／ActionActivities，不新增业务判断到 Core；Core 统一 Handle 使用精确 Lookup 与 revision 校验 Update 实现再次手势取消。无新增公共能力，action.demands v1.1 的 Lookup 增加 revision 元数据。GoalsSpec89、GoalSourcesSpec46 通过，覆盖农场观察、重置、角色隔离与三次手势添加／取消／再添加；客户端待验收。

2026-10-10 CAP-005／008 图标执行接入：Todo action.targets v1.2 公开 GetClickAction／AfterClick，Task 以 Core Contracts 发现，不访问 Todo 全局实现或 SavedVariables；Todo 图标和提供方共享 Actions:Describe。Task 主表／悬停使用同一安全绑定，继续复用 Core UI 提示与战斗窗口生命周期；其它来源未迁移执行能力，不预建空接口。ClickActionsSpec26 与既有目标、布局、性能及 Todo 操作回归通过，客户端待验收。契约见 ../../Docs/行动中心-目标图标执行契约-v1.2.md。

2026-10-10 CAP-005 图标执行客户端反馈：Task 安全按钮改为锚定行 Frame＋工作列数值偏移，消除锚定 FontString 导致的刷新中断；Core 契约与 Todo 提供方无变化。ClickActionsSpec26、Layout197 与256文件语法检查通过，重载后客户端待复测。

2026-10-10 CAP-008 图标反馈：Core 统一添加按钮使用原生勾选纹理，消除中文字体缺字方块；Todo ActionNomi 经既有目标投影提供 item／icon，Task 继续通过公开来源消费，保留 ItemResolver 并补已可用纹理显示。无新增能力或跨业务私有访问。GoalsSpec90、ClickActionsSpec29、Layout197、TodoSources177 与语法检查通过，客户端待复测。

2026-10-10 CAP-005／008 连续点击与图标布局：Task 统一使用带边框的工作图标及同位安全按钮；当前角色目标逐项显示，完成行仅在当前打开的 UI 中保留到关闭。Todo Evaluate 可选提供 display.item／icon，未知专业只保留显示元数据，不推定执行或完成。继续复用 Core Contracts、ItemResolver 与 UITheme，未新增 Core 业务分支或来源私有访问。ClickActionsSpec45、Layout197、Performance219、256文件语法检查通过；客户端待复测。

CAP-008 设置与状态同步追加审查：Core 统一设置提供右上角按钮／中键／Ctrl＋左键互斥选择，以及金色折角／青绿圆点；旧自定义手势迁移保留。Todo、Builds 的安全属性由来源回调负责，Currency、Crafting、Mail、Legendary、Reputation 的普通入口声明安全消费 Ctrl＋左键；全部复用既有 API12 / business-item-actions:1，未增加本地按钮实现。CAP-005 的 Todo 精确查询与账号快照复用同一专业图标／动作元数据；每日预计状态由来源解释为准备，Task 不重算重置。ItemActionSettings30、TodoStateSync23 与既有专项及回归通过，客户端战斗与视觉仍待复测。

2026-10-11 CAP-005 同步复核：Todo 继续通过既有 action.targets／action.todo 输出，已学习可制作但无数值冷却的配方投影准备，保留 profession 置信度；Task 不读取来源 SavedVariables。Task 悬停分组保留既有 current/others 段标识，当前未知目标与主表同样逐项展示。无新增 Core 接口或本地回退；TodoStateSync36、ClickActions45、Layout197 及只读已保存观察回放通过，客户端仍待复测。

2026-10-11 CAP-005 活动关闭同步复核：Todo 通过既有 action.targets 任务的 active/not-applicable 状态表达暗月未开放，Task 复用 Snapshot 筛选并让完成行保留逻辑尊重明确不适用状态；无新增 Core 能力或来源内部访问。EventGoals17 验证午夜缓存到期、当前与其它角色、悬停、完成行移出、目标历史保留及下期恢复。

2026-10-11 CAP-005／008 AltoBoss 自定义目标复核：来源公开目录与进度纳入 custom NPC，Task 继续经 Core Contracts 消费，击杀和有效期仍归 AltoBoss。目录增删改经既有 NotifyChanged 失效；角色状态格复用 API12 / business-item-actions:1，并声明普通按钮安全消费 Ctrl＋左键。无新增 Core 接口、业务分支或跨插件内部访问；CustomBossGoalsSpec25 验证实际来源增删改、添加取消、角色隔离及有效期恢复，客户端仍待复测。


## CAP-009：公共语言服务与账号语言偏好

2026-10-18 YiboAltoBoss 已排队时间Tooltip：CAP-009新增 `QUEUE.ELAPSED_WAIT` 一对中英文资源；CAP-004复用现有行动Tooltip，和预估时间相邻显示，同次系统查询计算已排队时长。API13与接口要求不变，无本地语言或计时回退。HolidayBossSpec261、语法及语言检查通过，客户端待确认。详见[排队状态同步修复](../../YiboAltoBoss/Docs/节日排队状态同步修复.md)。

2026-10-18 YiboAltoBoss 排队预估Tooltip：CAP-009新增两对 owner 资源，CAP-004继续使用现有 Tooltip 显示／定位／关闭及行动单元格；API13要求不变，没有新增Core接口或本地语言回退。HolidayBossSpec252含中英文实际Tooltip渲染、最新估算与异常数据检查，BossGoals19及语法／语言检查通过；实机显示待验。详见[排队状态同步修复](../../YiboAltoBoss/Docs/节日排队状态同步修复.md)。

2026-10-18 YiboAltoBoss 节日队列同步复核：实时状态与事件刷新复用 CAP-004 账号视图和 CAP-009 既有 owner 提示，API13要求不变，无新增Core契约或本地语言回退。HolidayBossSpec240、BossGoals19、InstanceKills56与语法检查通过，实际队列与系统图标状态仍待客户端核对。详见[同步修复](../../YiboAltoBoss/Docs/节日排队状态同步修复.md)。

2026-10-18 YiboAltoBoss 四类节日副本核查：新增埃霍恩与皇冠药剂公司两对 owner 资源，四类日历／副本输入别名分别审查；仍要求 API13 / localization:1，无 Core 契约变化。复用 CAP-004 统一视图与 CAP-005／008 目标目录。HolidayBossSpec225（四类首领共12组语言场景）、既有 Boss 目标／副本回归、语法与语言静态检查通过；新增节日的排队和奖励仍待实机验证，既往范围的验收结论不扩大。详见[核查与验收](../../YiboAltoBoss/Docs/四类节日副本首领核查与验收.md)。

2026-10-18 YiboAltoBoss 万圣节续接入：新增无头骑士显示名复用 API13 / localization:1 owner 资源，中英文各一项；节日目标继续经既有 CAP-005／008 契约枚举，无 Core 接口变化。HolidayBossSpec24、BossGoals19、CustomBossGoals25（含前置 BossGoals）、InstanceKills56、LockoutProjection16 与 Lua 语法通过；语言报告缺英文／格式差异为0，6个未知 key 位于未涉及的 AutoOpen。节日输入名称别名属识别数据。日历、排队、奖励及中英文客户端待验，不扩大此前实机验收结论。详见[接入与验收](../../YiboAltoBoss/Docs/万圣节首领接入与验收.md)。

2026-10-13 Mail 1.2.13 截图修复：寄信发送／取消按钮和保留期确认直接使用 Mail owner 的 Core.Locale 资源，不再让客户端 CANCEL／ACCEPT 覆盖手动英文；中英文到期数值统一 d／h、估算保留~。NativeInboxSpec 验证中文原生标签在 Core 英文及中文的悬停／启禁刷新，WorkspaceSpec 验证两种语言的范围与高度。基础最低 Core 1.12.1 / API13，新增范围能力见 CAP-004；语言能力仍 localization:1。未修改游戏动态名称、历史快照或用户文本，客户端语言／布局验收仍待完成。

Core 状态：**已提供（1.12.0 / API v13 工作树，未发布）**。能力 `localization:1`，最低 API13。契约见 [API v13 语言服务](API-v13-语言服务.md)；Core 当前 532 对资源已接入，175 项语言验证、206 项语言模拟布局及1133项入口专项与相关回归通过，真实客户端待验收。Core 保留旧 API，不推动无关业务整体提版本。

职责：Core 提供账号模式与会话语言、资源注册/查询/格式化/中文回退/缺失报告；业务拥有翻译目录与业务数据。正常业务注册早于自身页面文件、晚于 Core 就绪；保存语言偏好只在下次重载或登录生效。临时预览只在非发布探针，不保存。

| 插件（技术名排序） | 接入状态 | 已覆盖 / 剩余范围与版本要求 | 验证证据 / 最近审查 |
|---|---|---|---|
| YiboAltoBoss | 部分接入（适用代码完成，客户端待验收） | API13 / localization:1；311对owner资源覆盖正式UI、设置、状态／错误、静态回退目录与目标／命令反馈，无独立语言开关 | 原生API名、历史、自定义文本与输入别名保留；中英文及手动语言模式待验 / 2026-10-14 |
| YiboAutoOpen | 部分接入 | `Locale.lua` 为 Core 升级提示注册中英文资源；设置面板控件、状态、确认框与目录文字仍为中文硬编码，需按设置页区域继续迁移；最低 Core API13 + `localization:1` | 2026-10-16：Core 1.12.6 / API13 兼容门槛更新；无中英文客户端验收 |
| YiboBeastPaths | 部分接入（Core 维护区域代码完成／客户端待验收） | 1.7.0 可选维护增强最低 API13 / localization:1；维护页、统一设置、共享错误、地图按钮／悬停和命令提示注册 zh/en 资源，使用 Core 会话语言。独立地图模式解析同份资源的客户端语言，必要性／范围／移除条件见接入文档；路线资料、诊断与旧独立布局保留范围另列 | 真实 Core Locale 494项检查、双语维护页 smoke 与26文件语法通过；静态报告254候选，缺英文／未知键／格式差异0，检查器不识别 ns.Text 引用；游戏中英文／手动语言模式待验收 / 2026-10-13 |
| YiboBuilds | 部分接入（主要区域代码完成，客户端待验） | 页面／字段／设置元数据／悬停／状态与确认／目标／命令／专业标签接入owner资源；历史占位在展示时翻译，原生API／DB2名称和识别别名保持 | Core13Spec双语资源与格式、旧快照无改写；词法报告55候选已分类，布局与真实客户端待验；最低API13 + localization:1；2026-10-15 |
| YiboCrafting | 部分接入（适用区域代码完成） | 1.2.0 整体 API13 / localization:1；页面、设置、入口、Tooltip、状态／错误、目标和稳定分类 ID 均迁移，动态名称／历史来源原文保留 | CoreAdaptation 双语资源／页面与静态报告通过；真实中文／enUS／手动语言模式待客户端 / 2026-10-12 |
| YiboCurrency | 部分接入（适用代码与离线检查完成／客户端待验收） | 0.9.1工作树 / API13 / localization:1；页面、设置、悬停、状态、目录、目标、诊断与数字单位均使用owner中英文资源；原生名称和自定义历史文本保留 | YiboCurrency-Migration-Report.md：0硬编码、缺英文、未知key及格式差异；四种语言组合各52项通过；真实客户端待验 / 2026-10-15 |
| YiboLegendary | 部分接入（适用区域未完成） | 工作树 2.2.0 / API13 注册自有 zh/en 资源，并迁移 Core 页面元数据、设置说明、摘要、部分状态、错误、清理提示与人工确认；Catalog、Data、Model 生成的路线／进度静态文本仍未迁移 | `_NonRelease/Localization/Legendary-API13-Report.md`：305 个硬编码候选、90 个 Core Locale 引用；缺英文、未知 key、格式差异均为 0。Bootstrap/UI 与 Catalog 路线目录、Data 行动文案部分迁移；Data 定义与 Model 快照状态仍有大量静态文案待迁移。继续迁移后再做中英文与手动语言客户端验收 / 2026-10-13 |
| YiboMail | 部分接入（适用区域代码与布局模拟完成） | 工作树 1.2.9-api1，最低 Core 1.12.0 / API13；Mail 静态玩家文案、账号入口、邮件状态／错误、目标与目录使用 Mail 自有 zh/en 稳定 ASCII key 并由 Core.Locale 按账号会话语言解析；动态游戏名称、历史快照及存档值保持原文。可选 action.todo 继续单独要求 API11 / business-providers:1；邮件目标操作检查 business-item-actions:1 | `YiboMail-API13-Report.md`：0 硬编码候选、0 缺失英文、0 未知 key、0 格式参数差异；WorkspaceSpec／NativeInboxSpec／RuleSendUISpec 英文尺寸回归通过，详见 `Docs/Mail-英文布局与历史页性能修复.md`；客户端中文／enUS、手动语言模式和登录验收待完成 / 2026-10-12 |
| YiboMounts | 部分接入（Core 增强） | 1.0.0 注册 `YiboMounts` zh/en 资源；Core 可用时设置面板、收藏状态 Tooltip 和固定文案使用账号会话语言。双语源目录保留其数据字段，独立模式保留本地 Locale 兼容文本以满足 Core 可选契约；Core 增强最低 API13 + `localization:1` | 静态检查到注册／查询路径；中文／英文会话、手动语言、设置保存、Core 缺失／旧版验收待完成 / 2026-10-12 |
| YiboQuestBlocker | 部分接入（适用区域代码完成／客户端待验收） | 工作树 3.1.0 整体要求 API13 与 `localization:1`；页面、入口、设置、状态、错误和命令前缀使用 QuestBlocker 自有 zh/en 资源与 Core Locale | Workspace-Report：0 硬编码候选、0 未知 key、0 缺失英文、0 格式差异；动态任务名及旧存档迁移 token 保持原文；中文／enUS／手动语言模式和实际入口交互待客户端 / 2026-10-12 |
| YiboReputation | 部分接入（适用区域代码完成，客户端待验收） | 1.7.1 / API13 注册 owner zh/en 资源并使用 Core Locale；覆盖页面／入口／首次提示、矩阵、设置、预览、状态／错误、目标和稳定资料片／分类目录；动态声望名称及历史快照保留原文 | `_NonRelease/Localization/Reputation-Migration-Report.md`：0 缺失英文、未知 key、格式差异；人工分类的原生游戏名称匹配 token 与低版本启动错误回退保留。中文／enUS、手动语言、IME 和入口客户端验收待完成；新增迁移／采集失败／诊断／缓存影响中英文资源；数据归属迁移代码与离线验证已完成，真实客户端待验 / 2026-10-15 |
| YiboTaskHub | 部分接入（静态文案已迁移） | 工作树 0.6.0：最低 YiboCore 1.12.0 / API13、localization:1、account-entry:2、builtin-entry-bar:1；TOC 注册 zh/en 资源，页面、入口、错误、摘要、HUD、设置、状态、目标编辑与 Boss 目录静态文案均通过 `Addon:T` 调用 Core Locale。动态来源名称仍由来源插件提供；搜索归一化用标点不属于显示文案 | 6 个 TaskHub 独立 Spec 均通过；静态报告 `_NonRelease/Localization/TaskHub-API13-Report.md`：0 未处理候选、0 缺失英文／未知 key／参数差异；中英文客户端布局及登录验收待完成 / 2026-10-12 |
| YiboTodo | 部分接入（适用区域代码未完成） | 工作树 1.3.0，最低 API13；`Locale.lua` 注册 zh/en，并接入页面注册元数据、统一升级／初始化错误、摘要、空页面、设置标题和命令帮助。业务数据和游戏动态名称保留来源原值 | `_NonRelease/Localization/Todo-API13-Report.md`：0 未知 key、0 参数差异；仍有 275 个硬编码候选待人工分类和迁移；真实中英文／手动语言模式与登录验收待完成 / 2026-10-12 |
| YiboVault | 部分接入（适用区域代码完成） | 工作树要求 YiboCore 1.12.0 / API13 与 `localization:1`；TOC 注册 zh/en 资源，页面、设置、入口、Tooltip、状态／错误与固定目录文本经 Core Locale。动态游戏名称、历史快照与玩家自定义文本保持原文 | `Vault-Core13-Report.md`：0 硬编码候选、缺失英文、未知 key、格式差异；中英文客户端、手动语言模式与登录验收待完成 / 2026-10-12 |

证据：[实施与验收记录](../../Docs/Core系列中英文客户端适配-实施与验收记录.md)，`_NonRelease/Localization/{Core-Report,Workspace-Report}.md`。字符串数不是加权区域覆盖度。后续新增/修改区域触发接入；达到单插件收尾条件时固定能力基线并集中验证。Core 间接给旧业务页面提供英文壳，不等于该业务已接入语言服务。

本轮仅修改 Core 运行代码及直接关联测试夹具；业务源代码没有因语言服务新增而迁移，CAP-001～008 状态保持。模拟布局中的 Fixture 是测试数据，不登记为插件接入。

2026-10-11 CAP-009：本轮 Core 入口／设置新增18对资源（总497对），继续 Core:Text 与统一会话语言，未涉及业务源码语言迁移；严格静态检查零缺失／未知／参数差异／硬编码，客户端待验收。

2026-10-11 CAP-009 文档同步：正式三模式设置承担插件显示语言覆盖，接口为 Core.Locale:GetLanguage() → zh/en，GetLocale() 保持客户端值；无需另建覆盖开关。zhCN 手动英文用于日常开发，真实 enUS 的原生名称、字体和业务场景验收仍待完成。探针仅作 Core 快速预览，未迁移业务状态保持。此次仅补齐文档，沿用既有验证证据，未新增运行验证。

2026-10-11 CAP-004／CAP-009 设置迭代：Core 新增 builtin-entry-bar:2 的外框、背景配色、透明度与稳定 ID 调序；设置三个固定页签、业务入口按高度分页。新增22对资源，当前519对；1156项入口专项、40项语言布局、175项语言契约通过，严格静态检查零缺失／未知／参数差异／硬编码。业务源码与接入范围未变；客户端验收待完成。

2026-10-12 CAP-004／CAP-009：Core 通用和信息条成为独立设置页，入口列表合并仅注册设置的插件，使用显式分页与总数；统一控件高度、行距和紧凑宽度。当前526对资源，1116项入口专项、58项语言布局通过；能力仍 API13 / account-entry:2 / builtin-entry-bar:2，业务源码与接入状态未变，客户端修正版待验收。

2026-10-12 本轮调整：点击 Core 常规设置直接显示语言与悬停，信息条与窗口等导航缩进为下一级。显示与入口完整展示注册的业务页面与独立设置，每个插件30高单行、38行距、共享表头，字段下拉仅显示数量；列表纵向滚动。builtin-entry-bar:3 增加图标拖拽调序，取消拖拽不改顺序，拖拽松开不触发打开页面；条与调序下拉统一使用去作者前缀的页面名称。Core 公共能力变化仅涉及 CAP-004／CAP-009，业务源码与接入范围未变。1133项入口专项、58项语言布局与532对资源严格检查通过；客户端交互仍待验收。

2026-10-12 文案与高度调整：Core 子页面统一导航按钮和文字锚点，信息条与其它子项对齐；设置隐藏重复页说明，入口表移除重复提示、注册数量与底部提示，保留字段表头、操作控件及必要风险确认。语言、重载、信息条拖拽与仅设置状态同步精简中英文。帮助页复用关于页高度规则，并优先读取关于页保存高度，覆盖旧帮助小窗口高度。1133项入口专项、61项布局（含子项对齐、帮助／关于默认及保存高度一致）、175项语言契约通过；532对资源严格静态检查无异常，客户端待验收。能力版本与业务接入范围未变。

2026-10-12 TaskHub 文案迁移：主总览、目标管理／编辑、Boss 目录、设置、悬停、HUD 与状态共 307 处静态资源调用使用 Core.Locale；英语列表分隔符已本地化。全量发布 Lua 静态检查 0 未处理候选、0 缺失英文／未知 key／格式参数差异；TaskHub 六个 Spec（683 项）与发布 Lua 语法检查通过。截图中业务来源动态名称仍由来源插件提供；英语客户端布局和完整登录验收待完成。CAP-009 接入状态仍为部分接入（自动化完成、客户端验收待完成）。

2026-10-12 Crafting 截图反馈修正（CAP-002／CAP-009）：已知专业显示按稳定 ID 优先使用 owner 双语资源，覆盖选择、列表、矩阵分组和详情，修复中文原生快照覆盖手动英文的遗漏。Core Theme 统一管理单选／多选下拉互斥与嵌套菜单关闭；Crafting 继续使用共用控件，无本地并行实现。公共接口与最低 API13 要求不变。CoreAdaptation、LocaleLayoutSpec 213项及运行文件语法检查通过；语言报告缺英文／未知 key／参数差异为0。原生配方／角色名称与历史数据保留，游戏菜单交互与专业显示待复验，状态仍为部分接入。

2026-10-12 YiboMail 1.2.8-api1 Core 1.12.0 / API13 适配：基础能力门槛增加 localization:1 与实际调用能力检查；Mail 玩家可见静态文本迁移到自有 zh/en 资源与稳定 ASCII key，目标操作检查 business-item-actions:1，action.todo 仍独立检查 API11 / business-providers:1。`YiboMail-API13-Report.md` 显示 0 硬编码候选、0 缺失英文／未知 key／格式参数差异；原生分类标记仅作内部识别。完整尺寸与中英文客户端、手动语言模式及登录验收待完成，故状态为部分接入。

2026-10-12 角色设置布局：信息条移至角色与排序、显示与入口之间；去掉三个导航资源文字内的前导空格，缩进统一由导航锚点控制。默认排序改下拉，操作按钮按文案宽度，业务等级过滤按宽度两至三列；角色档案过滤控件恢复分栏，等级输入固定120宽。Core 等级与短名输入改为既有 Theme:CreateInput（CAP-002 / basic-input:1），保留校验、回车保存、失焦保存和取消。仅 Core 消费实现接入变化，业务插件状态不变，无公共能力升版。206项布局覆盖中英文620／1200宽度、12业务过滤、共享输入与表达式保存、导航顺序与缩进；1133项入口专项通过。532对资源严格检查无异常，游戏内布局待验收。

2026-10-12 Vault Core 1.12.0 / API13 最新工作树复核：Vault 整体最低版本为 API13，启动时检查 `localization:1`、`business-services:1`、`character-name-format:1`、`basic-input:1`、`item-resolver:1`、`character-identity:1`、`account-entry:2` 及实际调用方法；能力不满足时提示并停止初始化。页面过滤输入迁移到 Core `CreateInput`，角色标签迁移到 `FormatName`，物品显示继续使用 ItemResolver；入口显式声明三个默认关闭通道；固定仓储页不需要 `account-surface-budget:1`。Core 最新 `business-item-actions:2` 向后兼容 v1，Vault 库存目标增强只调用并检查 v1；`builtin-entry-bar:3` 的拖拽排序由 Core 内部使用，Vault 未调用，不需依赖 v3。目标增强不满足 API13、`business-item-actions:1`、身份方法和 Core Contracts/绑定方法时单独停用。`vault.items` / `mail.items` 数据所有权和 Service 契约不变，Core 无需新增业务分支。语言静态报告为 0 硬编码候选、0 缺失英文、0 未知 key、0 格式差异；尚未做中英文游戏客户端与入口交互验收。

2026-10-12 YiboTodo 1.3.0 API13 适配：整体最低 Core API 升至13，启动检查 localization:1、account-view:2、character-identity:1、character-name-format:1、account-entry:2；目标操作仍独立检查 API12 / business-item-actions:1，Todo 来源仍检查 API11 / business-providers:1。角色名调用 FormatName，页面注册与部分基础 UI／帮助文本注册中英文资源；业务入口三通道默认关闭。语言检查报告显示 0 未知 key、0 格式参数差异，但有275个硬编码候选仍待人工分类／迁移，故 CAP-009 记部分接入。未进行客户端验收。

2026-10-12 YiboTodo 本地化续迁：完成账号矩阵状态与 Tooltip、农场／诺米状态、行动中心 Todo/Nomi 的动态状态原因、目标范围错误、共享清理说明、矩阵列标题和列表分隔符资源化。静态报告从415降至275个硬编码候选，语言资源引用由21增至152；未知 key、缺失英文和格式参数差异均为0。剩余候选主要在业务目录文本、探针／诊断与农场／日历的客户端原文匹配关键词；后者是输入匹配规则，不应翻译替换；客户端验证仍待完成。
2026-10-12 YiboTodo 目录名称渐进本地化：新增按稳定法术／物品／任务 ID 查询当前客户端显示名的辅助方法；成功时用于单配方冷却组、已记录任务、纳特鱼类与精确农场法术名称，API 缺失、数据未载入或返回空值时沿用原目录中文标签。任务投影按 questID 重新解析显示名，避免已保存的名称阻碍切换语言。中文农场关键词与暗月日历关键词识别保持原样，英文识别尚未验证，不计为完成；静态报告 275 项中按用户要求排除探针 57 项，本轮关注范围为 218 项，仍需按游戏实体名称、自定义目录文案及输入匹配规则逐类迁移。中文客户端行为以原标签和原匹配条件回退，英文客户端及目标 Classic API 实机验证待完成 / 2026-10-12

2026-10-12 Mail 英文截图修复（CAP-004／CAP-009）：账号／邮箱／规则控件复用 Theme 文字测量与既有共享控件，完整组换行；字段关联改用插件内部稳定 groupID，显示标题继续本地化。历史隐藏行停止逐条读取角色目录，角色名称仍经公开接口格式化。API13 门槛不变，无新公共能力。三个 UI Spec 与26个运行Lua语法检查通过，3411条历史模拟布局约0.02秒；游戏内待复验。CAP-002：账号搜索与规则输入继续公共输入，原生寄信控件保留原对象；NativeUI／RecipientUI／MailUI 的旧自建输入剩余范围仍待迁移，不据本轮尺寸修复升级为全部接入。

2026-10-12 Mail 1.2.9-api1 版本整理：合并 API13 适配与英文布局／历史性能修复，生成双渠道安装包；客户端验收状态仍保持待完成。

2026-10-13 YiboTodo 列头英文文案：CAP-009 接入范围内将职业列标题改为 `Cooldowns`，珠宝列标题改为 `JC`（Jewelcrafting 的常用缩写）；中文资源保持不变。职业列继续按图标内容宽度计算，珠宝列沿用当前语言标题测量，因此英语标题变短后列宽随之缩小。最低 Core API 与调用范围不变；游戏内英文／中文显示待验收。

2026-10-13 YiboTodo 设置页目录文案（CAP-009）：监控组标题和设置内静态目录项现在按稳定 group/item ID 查询 zh/en 资源，覆盖职业冷却、农场、诺米、日常分类、纳特、暗月与布林顿项目；业务设置页不再直接显示目录中的中文标签。角色动态采集名称仍遵循当前游戏 API 原文。Core API 与能力依赖不变；中英文客户端及手动语言模式待验收。

2026-10-13 YiboLegendary 2.2.0 API13 适配：基础初始化要求 `localization:1`、`character-name-format:1`、`account-view:2`、`account-entry:2` 与实际使用方法；注册中英文 Core Locale 资源，页面元数据、部分状态、设置、错误与人工确认已接入；角色显示与人工确认身份使用 Core `FormatName`；业务入口默认关闭三个通道。目标主动添加仍独立检查 API12 / `business-item-actions:1`。静态报告复核为305个硬编码候选、90个Locale引用，缺英文／未知key／格式参数差异为0；Catalog目录目标部分经稳定ID本地化，任务行动文案经Core.Locale解析。任务叙述、专有名词、路线说明及Model目标进度／任务诊断保留中文原文；英文范围限定为菜单、矩阵表头、按钮、控件和通用状态／错误提示，硬编码报告候选多为该业务文案且不作为此范围的未完成项；客户端待验收，故CAP-001／004／009均记部分接入。

2026-10-13 YiboLegendary 本地化续接（CAP-009）：Catalog扩展标签改为显式稳定键映射，消除动态 key 未知项；Data 任务行动与表格行动拆分为独立资源键，接入 Core.Locale。报告更新为305个硬编码候选、90个Locale引用，缺英文、未知key与格式参数差异均为0。任务定义和 Model 快照仍待迁移，客户端验收未完成。

2026-10-13 YiboLegendary 英文适配范围澄清（CAP-009）：任务步骤、专有名词、路线说明与目标进度缺少可靠原版英文来源，保留中文原文；英文适配聚焦菜单、矩阵表头、按钮、控件及通用状态／错误提示。静态词法候选数仍报告，但业务叙述候选不作为该范围的完成门槛。


2026-10-14 CAP-005：AltoBoss 五人本可选 DBM 适配器通过既有 Core events:1 发布 YIBOALTOBOSS_DUNGEON_COMPLETED v1 隔离事实；回调注册／注销、晚加载、版本化负载、Core 唯一角色ID／地图／难度／本轮校验与去重均由业务侧负责。无 DBM 依赖或 Core 业务分支，团本原生路径保持。最低 API13，接口与失效细节见 YiboAltoBoss/Docs/FivePlayerBossRecording.md；自动化通过，真实客户端待验收。

2026-10-14 YiboAltoBoss 普通五人本主表进度（CAP-009）：本轮完成集合投影到现有副本格及入口预览；新增 LOCKOUT.KILL_COUNT / LOCKOUT.CURRENT_RUN 双语资源，继续使用 owner Core.Locale:Get、API13 / localization:1。复用现有 Core 账号视图与入口，不新增公共能力。玩家截图已确认监狱三个 Boss 的历史采集；本次展示改动未运行自动化测试，中文／英文客户端及手动语言模式、击杀后显示和重置后恢复待客户端验收。

2026-10-14 CAP-008／CAP-009 AltoBoss 副本 TP：Core 提供 business-item-actions:3 / API13 的通用 Bind.compactTooltip 选项，保持既有调用默认行为与必要参数补充流程；契约见 API-v12-业务项目主动添加.md。AltoBoss 目标增强已检查能力3，副本格启用简短提示，缺能力提示升级并停止增强；基础采集／展示继续。副本 TP 使用既有 UITheme 双列／间隔／文本行，历史次数、最近时间、进入次数开关纳入统一业务设置；新增 TP.* owner 双语资源，历史默认关闭。CAP-001／CAP-004 继续复用现有账号视图、入口及工作台，不新增窗口或缓存权威。静态语法与语言检查通过，本次未运行自动化测试，客户端及交互验收待完成；按部分接入记录。其他插件与 AltoBoss Boss 格未启用简短提示，不推定其已接入能力3。

2026-10-14 CAP-009 AltoBoss 普通本显示时效：新增 TP.STALE／TP.STALE_HINT 中英文 owner 资源，离本 30 分钟后显示待刷新；业务时效和轮次事实仍由 AltoBoss 所有，复用现有 Core Locale／账号页刷新，公共契约与最低 API13 不变。Lua 语法与语言静态报告通过，本次未运行自动化测试，客户端计时／返回／重置及语言验收待完成。

2026-10-14 AltoBoss 2.6.1 对 Core1.12.2 审查：当前API13、localization:1、events:1／character-identity:1与business-item-actions:3调用兼容；InstanceKills带样本58项、BossGoals19项、CustomBossGoals25项通过。CAP-001角色名称、CAP-002公共输入、CAP-004旧独立设置分支与CAP-009其余界面语言仍未完成，保留部分接入／待迁移状态。发现Core TOC1.12.2与Bootstrap.VERSION1.12.1不一致，尚未修改运行代码。两组完整回归受前置测试阻断，详见 [审查报告](../../YiboAltoBoss/Docs/Core-1.12.2-适配审查.md)。

2026-10-14 AltoBoss API13 迁入收尾：按Core1.12.2既有能力补齐适用运行代码，删除独立设置壳、局部输入／名称／旧入口及窗口分支；统一工作台的数据区复用公共确认，历史不清除。Core Bootstrap版本与TOC对齐；CAP-004补齐既有预览字段group元数据传递并声明account-preview-field-groups:1，见[契约](API-v13-预览字段分组.md)。AltoBoss固定副本选择迁入Core显示与入口，旧选择导入previewColumns，客户端待验。适用代码与验证边界逐项见 [完整记录](../../YiboAltoBoss/Docs/Core-API13-完整接入.md)；保留客户端待验，台账不将其记为全部验收完成。

2026-10-15 CAP-004／CAP-009 AltoBoss设置页续改：公共能力调用无新增／遗漏，继续复用Core统一工作台、按钮／输入、BindTooltip与owner语言。业务规则前置，两个增长列表使用独立分页与窄宽度单列，破坏性操作保留数据区末尾及Core确认。新增5对资源（现316对），静态语法及语言报告通过；未运行测试，实际中文／英文客户端布局验收待完成。Core运行代码本轮无改动。

2026-10-15 CAP-004／CAP-009 发布记录：AltoBoss2.7.0与Core1.12.3 / API13同步发布，预览字段分组最低Core1.12.3 / account-preview-field-groups:1。保留本轮静态验证证据与客户端待验状态。

2026-10-15 YiboCurrency 0.9.1 对 Core1.12.3 / API13 只读运行代码审查：基础仍检查API9／business-services:1，目标增强独立检查API12／business-item-actions:1；CAP-001名称与CAP-009语言仍待迁移，CAP-004显示／悬停字段与排序仍保存在业务设置，待统一注册接入。CAP-002／003控件专项本轮通过；CAP-005 VaultIntegrationSpec原样因角色接口mock落后失败，仅内存补齐GetAllCached／Get后诊断通过，运行代码查询故障未据此成立。发现Core economy／economy-items仍采集并权威保存货币与代币，以及Core／Vault混合来源、未确认银行仍标known、容器兼容路径丢失carried问题；未改运行代码或删除历史数据。完整范围、证据与迁移顺序见[Currency适配与数据归属审查](../../YiboCurrency/Docs/Core-1.12.3-适配与货币数据归属审查.md)。上述状态未升级为全部接入或客户端验收完成。

2026-10-15 Reputation 1.7.1／Core1.12.4 声望归属迁移：CAP-004 接入 character-cleanup:1、角色身份事件与现有统一页面；CAP-005／008 action.targets 改读本地权威快照；CAP-009 补迁移、失败、诊断及缓存影响资源。Core 运行时停用声望域，旧域仅公开只读导入；未新增连接机制或业务 Service。87 项迁移专项、独立悬停、71 文件语法及语言检查通过；既有综合性能脚本被 AltoBoss 第107行断言阻断，未声称整体通过。真实客户端、旧数据最终清理及发布待完成，详见[实施记录](../../YiboReputation/Docs/声望数据归属迁移-实施与验收记录.md)。

2026-10-15 Reputation 数据迁移二次复查：CAP-004／005／008 公共调用边界不变，补充历史保留、重复导入、ID 重映射及 CharacterCleanup 验证。修复空失败占位阻断导入、标记存在而快照缺失不恢复、重复 ID 事件传播旧阻断，以及本地快照已就绪后 status 失败计数未收敛；原有87项加新增39项共126项通过。覆盖冷启动阻断持久化、Core完整旧来源不变、当前角色删除拒绝、owner失败重试、延后删除只执行一次与其它角色隔离。真实客户端验收仍待完成；详见[实施记录的二次复查](../../YiboReputation/Docs/声望数据归属迁移-实施与验收记录.md)。

2026-10-15 交付版本：Core1.12.4 / API13、Reputation1.7.1；提交推送并打包，保留126项迁移回归及客户端待验状态。

2026-10-15 Currency0.10.0收尾：Core1.12.4工作树按真实动态目录需求新增account-dynamic-fields:1，契约见[动态账号字段](API-v13-动态账号字段.md)。CAP-001～005／007～009按上表更新；CAP-006保持不适用。Core和Currency容器计数、确认来源完整度及中英文控件／版本停止回归已完成；RuntimePerformanceSpec在既有AltoBoss第107行阻断，HEAD AccountView诊断同样失败，未宣称整体通过。客户端尚未验收；[接入记录](../../YiboCurrency/Docs/Core-API13-实施与验收.md)与[数据归属方案](../../YiboCurrency/Docs/货币数据归属迁移方案.md)区分已完成代码和待确认迁移。无玩家存档迁移或清理。

## CAP-010：角色缓存所有者与延后清理

Core1.12.5 / API13发布character-cleanup:2：持久登记动态所有者，禁用后保持pending，不按软上限丢弃待处理记录；Delete新增时间与回放上下文，兼容旧回调。最低接口及失败行为见[清理v2契约](API-v13-角色清理v2.md)。

| 插件 | 状态与覆盖／剩余 | 验证／日期 |
| --- | --- | --- |
| YiboBuilds | 1.5.0已接入；Inspect双语，角色ID与别名清理，延后回放保留有效新观察并清理过期装备；用户确认本次Core适配正常 | Core13Spec1057项及CharacterCleanupV2Spec43项；2026-10-16 |
| YiboCurrency | 部分接入（代码与离线完成／客户端待验）；0.9.1工作树显式检查能力2，注册Inspect／Delete，阻止旧数据复活、旧墓碑保留有效新观察；偏好／目录及其它所有者不受影响 | CoreSpec23项、Retention共107项；2026-10-15 |
| YiboReputation | 既有v1调用兼容已验证；没有改成依赖v2，也不推定v2特性客户端验收完成 | Retention126项；2026-10-15 |

AltoBoss、Crafting、Legendary、Mail、QuestBlocker、Todo、Vault仅静态发现既有登记，本轮未改调用；v2特性均待评估，触及相关生命周期时迁移。

2026-10-15 Currency货币归属实施：Core1.12.4工作树停止货币域和目录采集，旧数据冻结；Currency0.9.1工作树接管原生余额与最小随身观察，通过公开副本导入，不自动清理历史。CAP-004／005新增通用档案字段Provider，`character-archive-providers:1`；CAP-010补动态所有者留存。CoreSpec23、迁移55、额外保留29（共107）、TOC额外15、容器额外10、双语API13四组各37、Vault／控件、EntryBar1133、声望126及语法／语言检查通过。真实客户端验收与发版待用户测试后处理，详见[实施与验收记录](../../YiboCurrency/Docs/货币数据归属迁移-实施与验收记录.md)。历史AltoBoss性能阻断已由用户反馈实测无问题，不作为本次交付阻断；未宣称旧综合脚本整体通过。

2026-10-15 Currency截图反馈：CAP-004接入现有autoFitWidth、FitRepeatedColumnWidth与GetColumnPageByWidth，主窗口优先完整角色列，悬停可在业务设置独立转置；实际方法检查齐全，未变更Core能力接口。CAP-009新增业务设置／转置开关中英文资源；四组API13各47项、设置控件及完整迁移回归通过，客户端待复测。版本保持原值，未提交、推送或打包。

2026-10-16 Currency自定义物品设置反馈：CAP-004在现有Core托管业务设置内恢复已保存目录列表，复用公共按钮、文本、Tooltip、ItemPicker与确认流程，不新增通用字段选择或本地设置窗口；CAP-003确认边界保持，CAP-009新增5对列表／空状态／分页资源。中英文控件及完整迁移回归通过；客户端待复测。Core公开契约没有变化，未改运行时版本或提交发布。

2026-10-16 Currency单项提示／分页复核：CAP-004继续复用Core矩阵、完整自然宽度、分页和Tooltip基础，补齐自然尺寸的滚动槽预算与向上取整，修复13角色末列被挤至第二页；单项提示共享Projection，不另查第二份库存或排全角色副本。CAP-009复用既有owner资源，无新硬编码。四组API13各51项及完整迁移回归通过，客户端待复测；无Core公共能力契约变化。

2026-10-16 台账剩余矩阵统一接入：AltoBoss、Crafting、Legendary、QuestBlocker均要求account-surface-budget:2及实际GetScrollSurfaceWidth；取消子帧瞬时宽度和插件自算槽宽路径，主表／悬停声明滚动内容尺寸。新增MatrixBudget四组各100项实际业务渲染／Core预算回归，七插件128文件语法及相关回归通过。CAP-004上表由待迁移更新为代码及离线完成、客户端待验；CAP-009同步复用Legendary预览资源及升级提示。详细范围与实机清单见[统一接入记录](矩阵预算统一接入-实施与验收.md)。本轮无版本、提交推送或打包。

2026-10-16：Builds1.5.0与Core1.12.5配套。用户确认Core适配正常，重载后一张附魔卷轴只显示对应的一个附魔；候选修复属于Builds业务，不新增Core契约。详见[接入与验收记录](../../YiboBuilds/Docs/Core-API13-接入说明.md)。
