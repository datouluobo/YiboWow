# Core 公共能力迁移台账

首次审查：2026-10-07。最近更新：2026-10-07。

本台账记录 Core 公共能力的实现与业务接入进度，长期规则见 [AGENTS.md](../../AGENTS.md)。按能力独立记录，允许多个迁移过程同时进行；业务插件后续涉及对应功能时逐步接入。

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

首次审查时 Core 源码版本为 **1.6.3 / API v7**。本次 CAP-001 实施后，当前源码为 **1.7.1 / API v8**，依据 [Bootstrap.lua](../Bootstrap.lua) 与 [YiboCore.toc](../YiboCore.toc)，尚未上传发布渠道。首次审查仅静态核对；后续名称契约与旧调用回归的自动化验证见 CAP-001，游戏内仍未验收。

首次审查完整登记名称显示、基础输入和物品选择相关范围，并建立账号页面、入口、设置接入基线。其余已注册能力登记为现有接口索引，未进行逐调用验收；后续发现真实迁移需求时新增独立条目。

## 活动能力总表

| 编号 | 能力 | Core 状态 | 最低要求 / 发布依据 | 首次审查结果 | 下一触发点 |
| --- | --- | --- | --- | --- | --- |
| CAP-001 | 公共角色／联系人名称格式化 | 已提供 | Core 1.7.0 / API v8，`character-name-format:1`；尚未上传发布渠道 | Core 自身显示已接入；Mail 部分接入，其他业务范围随功能修改迁移 | 游戏内核对及业务剩余显示调用 |
| CAP-002 | 基础输入控件 | 已提供 | API v7，`basic-input:1`；文档首批 Core 1.6.1 | Currency 有明确接入与验证记录；Mail 版本要求已修正、旧输入部分待迁移；Vault 部分接入 | 对应搜索／输入控件修改时迁移，并核对最低版本 |
| CAP-003 | 物品解析、选择与操作确认 | 已提供 | API v7，`item-resolver:1`；Core 1.7.1 / API v8 提供 `item-picker:2` 批量扩展 | Currency 保持单物品兼容；Mail 已接入所列范围；AutoOpen、Vault 待评估 | 有真实批量录入需求时使用公开配置；业务校验与执行由业务插件负责 |
| CAP-004 | 账号页面、入口与设置工作台 | 已提供 | 账号页面／入口 API v5、`account-view:1`／`account-entry:1`；独立设置注册 API v6 | 已有广泛注册；存在旧设置壳、版本声明和验证待核对项 | 修改对应入口或设置功能时处理所列缺口 |

## CAP-001：公共名称格式化

### Core 当前状态与边界

- 已有 [Characters:GetDisplayName](../Data/Characters.lua)：`short` 读取以角色 ID 保存的短名，其余模式返回原始角色名。现有 `full` **不包含服务器**，必须保留该接口的兼容语义。
- 已提供 `Characters:FormatName(identity, options)`，能力声明为 `character-name-format:1`。`nameMode=original/short` 与 `realmMode=omit/sameRealm/full` 独立选择；同服参照服务器必须由调用方明确提供。正式契约见 [API v8 公共名称格式化](API-v8-公共名称格式化.md)。
- [共享角色表头](../UI/Theme.lua) 已接入新接口；保留业务传入名称／服务器的覆盖优先级、两段布局、旧 full 名称模式、真实身份悬停与状态提示，不要求旧业务插件改动调用或提高最低版本。
- 目录外联系人可直接提供 `{name, realm}` 格式化，不建立角色目录记录；短名只按明确提供的 Core 角色 ID 读取。联系人备注、职业色、WoW 文本转义、地址解析与业务操作仍归调用方。
- Core 内部已覆盖范围：[Theme](../UI/Theme.lua) 的表头、身份悬停与宽度测量；[角色档案字段](../Data/Fields/CharacterArchive.lua)；[角色档案删除确认](../UI/AccountPages/CharacterArchive.lua)；[设置工作台](../UI/AccountPages/SettingsWorkbench.lua) 的排序、短名管理身份标签。身份键、业务地址与短名存档结构未改动。
- 旧接口说明：[角色短名与统一服务器切换实施方案](Core-角色短名与统一服务器切换实施方案.md)。实施源码版本为 Core 1.7.0 / API v8（尚未上传发布渠道）。2026-10-07 验证通过：[CharacterNamesSpec](../_NonRelease/Tests/CharacterNamesSpec.lua) 75 项检查、Core TOC 的 44 个 Lua 5.1 文件语法检查、现有 Currency CoreItemControlsSpec 回归。游戏内 Core 档案／设置与旧业务主窗口／预览仍待核对。

### 业务插件接入表

以下 13 项最近审查日期均为 2026-10-07；接入版本与证据逐行记录。共享表头在 Core 内部已接入，业务仍须分别核对调用、最低要求与实际行为。

| 插件 | 状态 | 已有路径与证据 | 剩余范围 / 后续触发 |
| --- | --- | --- | --- |
| YiboAltoBoss | 待迁移 | [AccountPage.lua](../../YiboAltoBoss/AccountPage.lua) 本地组合名字与服务器；[Core.lua](../../YiboAltoBoss/Core.lua) 有 GetCachedCharacterLabel / GetCharacterLabel | 账号表头、角色行、行动项与设置标签；[LockoutsPage.lua](../../YiboAltoBoss/LockoutsPage.lua) 身份回退亦需核对。保留副本名称缩写业务逻辑，不能因同名 ShortName 函数误迁移 |
| YiboAutoOpen | 不适用 | [加载清单](../../YiboAutoOpen/YiboAutoOpen.toc) 与设置／队列代码未发现账号角色或联系人的名称显示需求 | 新增相应显示需求时重审；物品别名不属于角色短名 |
| YiboBeastPaths | 不适用 | [加载清单](../../YiboBeastPaths/YiboBeastPaths.toc) 及路线维护适配器以路线、宠物和坐标为显示对象 | 新增角色／联系人显示时重审；宠物名称不属于本能力 |
| YiboBuilds | 待迁移 | [AccountPage.lua](../../YiboBuilds/AccountPage.lua) 的 CharacterLabel 使用 Core 短名后本地追加服务器，角色行另用原名 | 预览标签、角色行与相应身份提示；装备装等等附加信息继续由业务组合 |
| YiboCrafting | 待迁移 | [AccountPage.lua](../../YiboCrafting/AccountPage.lua) 的 CharacterName 本地拼服务器，矩阵直接调用 Core 短名读取 | 矩阵、角色列表、角色下拉与 tooltip；核对不同布局是否应使用原名或短名 |
| YiboCurrency | 待迁移 | [AccountPage.lua](../../YiboCurrency/AccountPage.lua) 的 DisplayName / DisplayIdentity 本地格式化；调用共享表头时显式传入原名 | 表头、角色行、物品与货币 tooltip 标签及宽度测量；保留总计／空状态特殊行 |
| YiboLegendary | 待迁移 | [UI.lua](../../YiboLegendary/UI.lua) 的 CharacterLabel 用于列表、tooltip、确认及行动项 | 上述调用统一声明显示策略；人工确认应提供可精确识别的真实完整身份 |
| YiboMail | 部分接入 | 工作树 1.1.0-api1：AccountPage 总览／预览、ViewModel 业务标签及 CacheUI／NativeUI／规则命中显示复用 FormatName；初始化检查 API v8、名称能力与方法。WorkspaceSpec、NativeInboxSpec、RuleSendUISpec 和 InboxReleaseSpec 通过 | 通讯录／快捷标签的 Recipients:Label 仍待对应功能修改时迁移；保留联系人备注与邮寄地址解析。游戏内显示待验收 |
| YiboMounts | 不适用 | [加载清单](../../YiboMounts/YiboMounts.toc) 与图鉴提示／Core 设置适配未发现角色或联系人身份显示 | 新增相应显示需求时重审；坐骑名称与来源格式继续归业务 |
| YiboQuestBlocker | 待迁移 | [AccountPage.lua](../../YiboQuestBlocker/AccountPage.lua) 的 ShortName 实际返回原名；CharacterIdentity 解析回退键，并显式覆盖共享表头名称 | 当前角色分组标题、表头和身份 tooltip；旧键解析用于身份迁移，不能用格式化结果替代 |
| YiboReputation | 待迁移 | [AccountMatrixView.lua](../../YiboReputation/AccountMatrixView.lua) 与 [MonitoredPreview.lua](../../YiboReputation/MonitoredPreview.lua) 已调用共享角色表头 | Core 1.7.0 表头内部已接入；后续核对业务侧遗漏标签、最低要求与游戏表现，再记录业务显式接入。公会名称与公会键不属于角色显示 |
| YiboTodo | 待迁移 | [AccountPage.lua](../../YiboTodo/AccountPage.lua) 的 CharacterLabel 本地按 showRealm 组合身份 | 账号待办角色标签与相关身份提示；保留活动名称和业务状态文本 |
| YiboVault | 待迁移 | [Tooltip.lua](../../YiboVault/Tooltip.lua) 本地按当前服务器拼角色名称；[StoragePage.lua](../../YiboVault/StoragePage.lua) 所有者标签使用原名 | 库存 tooltip 与仓储角色标签；公会显示、容器名称和公会身份键继续由各自逻辑处理 |

### 首次审查注意事项

1. “所选单服范围内省略服务器”与“相对当前登录服务器省略服务器”是两种不同调用语义。Currency、Legendary 等按 `context.scope` 显示；Mail、Vault 部分显示相对当前角色服务器。新契约与迁移须明确参照范围，不能直接用一种替换另一种。
2. Mail 的 `Recipients:Normalize / Key`、收件地址、规则发件人匹配，Core 的旧键别名及稳定角色 ID，均承担身份或操作语义。迁移只替换显示调用，不能向这些数据写入短名或省略服务器后的显示文本。
3. Mail 的 CacheModel / HistoryModel 已把短名加入搜索文本；它们是检索输入，不是身份标签。后续显示迁移时检查检索一致性，不能机械替换成单一格式化字符串。
4. 共享表头收到 `options.name` 时会覆盖默认短名；QuestBlocker、Currency 当前存在此路径。完成 Core 实现后仍需逐业务核对，不能据共享表头调用将它们记为已接入。

## CAP-002：基础输入

接口与首批验证记录见 [API v7 物品选择与基础输入](API-v7-物品选择与基础输入.md)。Core 入口为 [Theme:CreateInput](../UI/Input.lua)。

以下条目最近审查日期均为 2026-10-07。除 Currency 的文档已有验证记录外，本轮均仅静态核对；没有重新运行历史验证。

| 插件 | 状态 | 已覆盖 / 证据 | 剩余范围与接入版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 待迁移 | [Settings.lua](../../YiboAltoBoss/Settings.lua) 有本地 EditBox | Core 托管业务面板的等级、NPC、副本录入；旧独立设置壳另见 CAP-004。未登记接入版本 |
| YiboAutoOpen | 待迁移 | [Settings.lua](../../YiboAutoOpen/Settings.lua) 中空位、物品、确认来源和别名输入均本地创建 | 仅 Core 托管设置范围接入；独立运行与 OptionalDeps 关系须在实施时确认。未登记接入版本 |
| YiboBeastPaths | 待迁移 | [CoreDebugView.lua](../../YiboBeastPaths/Maintenance/CoreDebugView.lua) 的 Core 维护页本地创建多行输入 | 评估公共输入对多行导出的适配；独立 DebugCalibrator 窗口不自动扩大迁移。未登记接入版本 |
| YiboBuilds | 不适用 | 当前账号页面与设置接入代码未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboCrafting | 待迁移 | [AccountPage.lua](../../YiboCrafting/AccountPage.lua) 的搜索框本地创建 | 搜索框输入／焦点／清空行为；未登记接入版本 |
| YiboCurrency | 已接入 | [Settings.lua](../../YiboCurrency/Settings.lua) 的自定义物品选择器间接使用公共输入；[CoreIntegration.lua](../../YiboCurrency/CoreIntegration.lua) 要求 API v7 和所需方法 | 所列范围首批 Currency 0.9.1；API 文档有控件验证记录，当前未重跑 |
| YiboLegendary | 不适用 | 当前业务页与业务设置未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboMail | 部分接入 | 工作树 1.1.0-api1：CacheUI、SendRulesSettings 使用公共输入；最低 API 提高到 v8；WorkspaceSpec、RuleSendUISpec 和 InboxReleaseSpec 通过 | MailUI、NativeUI、RecipientUI 尚未涉及的本地输入随对应修改迁移；已覆盖输入在游戏内仍待核对 |
| YiboMounts | 不适用 | 图鉴及 Core 设置适配未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboQuestBlocker | 待迁移 | [AccountPage.lua](../../YiboQuestBlocker/AccountPage.lua) 的等级表达式与手动任务录入本地创建 | 对应输入控件；任务 ID 校验仍归业务。未登记接入版本 |
| YiboReputation | 待迁移 | [AccountMatrixView.lua](../../YiboReputation/AccountMatrixView.lua) 的搜索框本地创建 | 搜索框及其状态；未登记接入版本 |
| YiboTodo | 不适用 | 当前待办设置与页面未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboVault | 部分接入 | [StoragePage.lua](../../YiboVault/StoragePage.lua) 的搜索框已使用公共输入 | [AccountPage.lua](../../YiboVault/AccountPage.lua) 的物品过滤输入仍本地创建；[Namespace.lua](../../YiboVault/Namespace.lua) 最低 API 为 6。工作树，未登记首次发布版本／运行验证 |

## CAP-003：物品解析、选择与操作确认

公共契约与验证依据同 [API v7 文档](API-v7-物品选择与基础输入.md)。业务保存、执行、物品准入与风险文案由消费方提供；不是所有物品展示或扫描都需要选择器。

以下条目最近审查日期均为 2026-10-07；未列入候选的插件亦已检查物品录入相关调用，状态只覆盖本次所述功能。

| 插件 | 状态 | 已覆盖 / 证据 | 剩余范围与接入版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 不适用 | 设置录入是 NPC／副本 ID | 不将这些 ID 当作物品；无接入版本 |
| YiboAutoOpen | 待评估 | [ItemResolver.lua](../../YiboAutoOpen/ItemResolver.lua) 本地解析物品 ID／链接／名字；TOC 将 Core 列为 OptionalDeps | Core 托管物品录入是候选；先确认独立运行约束与解析语义，再定范围，不能仅为迁移强制 Core 依赖 |
| YiboBeastPaths | 不适用 | 路线维护以坐标和路线数据为输入 | 无物品录入迁移项 |
| YiboBuilds | 不适用 | 当前构筑页面读取装备／配方数据，未发现可直接替换的物品输入选择器 | 业务动作与装备应用不自动纳入此项 |
| YiboCrafting | 不适用 | 当前制造页搜索已有业务目录，未发现通用物品身份录入控件 | 配方选择与制造逻辑仍归业务 |
| YiboCurrency | 已接入 | Settings 的 CreateItemPicker、删除操作确认复用 Core；初始化检查 API v7 与所需方法 | 所列范围首批 Currency 0.9.1，API 文档记录验证；本轮未重跑 |
| YiboLegendary | 不适用 | 人工目标确认不是物品身份选择 | 不为统一形式改造成物品确认器 |
| YiboMail | 已接入 | 工作树 1.1.0-api1：指定规则使用 item-picker:2 的 multiple／retainInput；分类排除与全局黑名单复用单物品模式；初始化检查 API v8 和能力 v2；使用公开配置 | 接口见 API-v8-批量物品确认；CoreItemControlsSpec、RuleSendUISpec、RuleSendSpec 和 InboxReleaseSpec 通过。游戏内待验收；新批量需求按契约扩展 |
| YiboMounts | 不适用 | 当前图鉴读取坐骑／物品来源，未提供通用物品录入 | 展示与来源查询不自动替换成选择器 |
| YiboQuestBlocker | 不适用 | 手动输入任务 ID | 校验与操作归任务业务 |
| YiboReputation | 不适用 | 搜索声望目录，未发现通用物品身份录入 | 声望搜索不属于物品解析 |
| YiboTodo | 不适用 | 当前配置选择活动／目标，未发现通用物品身份录入 | 活动 ID 与业务条件不属于物品解析 |
| YiboVault | 待评估 | [AccountPage.lua](../../YiboVault/AccountPage.lua) 的过滤输入仅接受物品 ID，并用 tonumber 校验 | 优先接入基础输入；是否需要解析器／选择器按过滤需求评估，不自动扩展为链接或名称录入 |

## CAP-004：账号页面、入口与设置接入基线

已有公开接口见 [API v5](API-v5-业务插件接入指南.md)、[API v6](API-v6-业务插件增量接入指南.md) 与 [统一协作计划](Core-0.3-统一协作与改造计划.md)。下表登记源码路径，**不是运行时验收表**；存在注册路径统一记为部分接入，待验证实际行为和遗留分支后才能关闭本条目。最近审查日期均为 2026-10-07；首次发布版本未逐一追溯。

| 插件 | 状态 | 已有接入与证据 | 剩余核对范围 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入 | [CoreIntegration.lua](../../YiboAltoBoss/CoreIntegration.lua) 注册页面、入口和业务设置 | [Settings.lua](../../YiboAltoBoss/Settings.lua) 仍保留 Core 缺失时的独立窗口分支；后续设置修改时收拢并核对升级提示 |
| YiboAutoOpen | 部分接入 | [CoreIntegration.lua](../../YiboAutoOpen/CoreIntegration.lua) 可选注册统一业务设置 | 验证 Core 可用／缺失时的设置路由；基础队列独立运行不自动纳入迁移 |
| YiboBeastPaths | 部分接入 | [CoreDebugAdapter.lua](../../YiboBeastPaths/Maintenance/CoreDebugAdapter.lua) 在 Mists 下可选注册维护页面与设置 | 核对客户端分支、晚接入与关闭行为；独立路线校准工具保留其既有范围 |
| YiboBuilds | 部分接入 | [CoreIntegration.lua](../../YiboBuilds/CoreIntegration.lua) 注册账号页与入口，业务设置只有描述元数据 | 验证页面／入口；当前无业务设置面板，不能虚记为已迁移面板 |
| YiboCrafting | 部分接入 | [AccountPage.lua](../../YiboCrafting/AccountPage.lua) 注册账号页与入口 | 验证页面／入口；当前未注册业务设置内容，没有第二套设置壳迁移项 |
| YiboCurrency | 部分接入 | [CoreIntegration.lua](../../YiboCurrency/CoreIntegration.lua) 注册页面、入口与业务设置 | 核对入口与设置现行契约的实际行为；CAP-003 所列物品控件验证不代替此范围验收 |
| YiboLegendary | 部分接入 | [UI.lua](../../YiboLegendary/UI.lua) 注册账号页、入口与业务设置 | 核对预览、完整页和设置行为 |
| YiboMail | 部分接入 | [AccountPage.lua](../../YiboMail/AccountPage.lua) 注册页面、入口与业务设置 | 当前工作树业务设置改造进行中；核对入口／账号快照与设置跳转，不能按旧文档直接认定完成 |
| YiboMounts | 部分接入 | [CoreIntegration.lua](../../YiboMounts/CoreIntegration.lua) 独立注册设置；[TOC](../../YiboMounts/YiboMounts.toc) 没有 Core 依赖声明 | RegisterSettingsPanel 属于 API v6，当前仅检查／声明 API v5；后续接入修改时明确其独立运行定位及 TOC 加载顺序。无账号入口需求 |
| YiboQuestBlocker | 部分接入 | [CoreIntegration.lua](../../YiboQuestBlocker/CoreIntegration.lua) 注册账号页、入口与业务设置 | 核对显示字段、预览与设置契约 |
| YiboReputation | 部分接入 | [CoreIntegration.lua](../../YiboReputation/CoreIntegration.lua) 注册账号页、入口与业务设置 | 核对矩阵／预览与设置契约；声望快照现有归属另需按业务边界评估，不以本次基线登记宣告迁移 |
| YiboTodo | 部分接入 | [CoreIntegration.lua](../../YiboTodo/CoreIntegration.lua) 注册账号页、入口与业务设置 | 核对业务设置与通用字段配置职责及实际行为 |
| YiboVault | 部分接入 | [AccountPage.lua](../../YiboVault/AccountPage.lua) 注册账号页、入口与业务设置 | 核对存储页、账号入口及设置行为 |

## 其他现有能力索引

本轮检查 [Capabilities](../Runtime/Capabilities.lua) 及其注册处，以下能力当前均登记版本 1：

| 类别 | 已注册能力 | 后续处理 |
| --- | --- | --- |
| 运行与配置 | runtime、database、migrations、events、resources、fields、addon-catalog、addon-status | 现有基础设施；发现具体重复实现或版本缺口时建迁移条目 |
| 角色与数据 | characters、character-cleanup、character-profile、data-domains、domain-store、level-filter | 角色身份与清理已有公共接口；character-profile 是旧兼容层，新功能按现有指南读取 DataDomains。数据域内容仍须遵守业务所有权 |
| 账号 UI | account-view、account-entry | 当前接入基线见 CAP-004；注册存在不代表预览、字段或设置行为已验收 |
| 输入与物品 | basic-input、item-resolver、item-picker、currency-catalog | 输入与物品迁移见 CAP-002／003；currency-catalog 后续有真实迁移需求时单列 |

Core 1.7.0 新增 `character-name-format:1`，接入进度见 CAP-001。接口索引不构成新建服务目录或迁入业务数据的授权。

## 首次审查待处理项

| 编号 | 事项 | 关联能力 | 处理触发 / 验证要求 |
| --- | --- | --- | --- |
| AUD-001 | 公共名称格式化：Core 阶段已完成，业务阶段待迁移 | CAP-001 | Core 接口、契约与兼容自动化验证已完成；游戏内核对及各业务插件接入继续随对应功能推进 |
| AUD-002 | Mail 输入／选择器最低要求已修正 | CAP-002／003 | 工作树 1.1.0-api1 检查 API v8、名称能力与 item-picker:2；InboxReleaseSpec 覆盖升级提示和停止行为，已关闭 |
| AUD-003 | Vault 搜索框调用 v7 输入，最低 API 仍为 6 | CAP-002 | 下一次搜索控件或初始化修改时提高要求；核对旧 Core 路径 |
| AUD-004 | Mounts 使用 v6 设置注册接口却仅检查 API v5 | CAP-004 | 下一次 Core 设置接入修改时修正，并明确独立运行／加载顺序 |
| AUD-005 | AltoBoss 仍保留独立设置壳回退 | CAP-004 | 后续涉及设置壳时收拢；如需旧版兼容例外，记录必要性、边界与移除条件 |
| AUD-006 | Mail 已通过公开配置保留确认输入 | CAP-003 | Core 1.7.1 提供 retainInput 与 multiple；CoreItemControlsSpec 与 RuleSendUISpec 验证生命周期，已关闭 |

## 更新记录

| 日期 | 更新范围 | 结果与证据 |
| --- | --- | --- |
| 2026-10-07 | 建立台账；首次静态审查 Core 与全部 13 个业务插件 | 登记 CAP-001～004、现有能力索引及 AUD-001～006；源码路径见各表；本轮仅文档更新，未修改运行代码或运行测试 |
| 2026-10-07 | CAP-001 Core 实施 | Core 1.7.0 / API v8 提供 FormatName 与 character-name-format:1，完成 Core 内部显示迁移；75 项名称／兼容检查、44 文件语法检查及 Currency 控件回归通过。业务状态保留，游戏内尚未验收 |
| 2026-10-07 | Mail 1.1.0 工作树接入；Core 1.7.1 批量控件扩展 | CAP-001 记录已覆盖与剩余名称调用；CAP-002 最低版本缺口关闭、旧输入保留待迁移；CAP-003 完成所列范围接入；AUD-002／006 关闭。相关自动化及 Core／Mail 66 文件语法检查通过；尚未发布，游戏内待验收 |
