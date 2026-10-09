# Core 公共能力迁移台账

首次审查：2026-10-07。最近更新：2026-10-08。

本台账记录 Core 公共能力的实现与业务接入进度，长期规则见 [AGENTS.md](../../AGENTS.md)。按能力独立记录，允许多个迁移过程同时进行；当前仍按触及对应功能时逐步接入。逐插件集中追赶的审查建议见 [迁移节奏审查](../../Docs/Core业务插件-迁移节奏审查-2026-10-08.md)，该建议尚未替代项目规则。

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

首次审查时 Core 源码版本为 **1.6.3 / API v7**。2026-10-08 本轮复核时，当前工作树为 **1.9.0 / API v10**，依据 [Bootstrap.lua](../Bootstrap.lua) 与 [YiboCore.toc](../YiboCore.toc)；当前 HEAD 为 **1.7.1 / API v8**。1.8.0 / v9 与 1.9.0 / v10 均未提交、未发布，游戏内待验收。Git 提交和源码版本不能作为渠道发布证据；本轮没有查询发布渠道。

本轮覆盖 14 个业务目录（13 个现有业务插件及 YiboTaskHub 项目基础），静态复核加载清单、最低版本、能力注册及接入调用。重新运行 RuntimePerformanceSpec、InboxReleaseSpec、MailProviderSpec、VaultIntegrationSpec 均通过；CharacterNamesSpec 在“API v10 应拒绝”的过期断言处失败，见 AUD-009。历史通过记录保留，但不能据此宣称当前工作树名称回归全部通过。首次提示本轮仅静态核对。

首次审查完整登记名称显示、基础输入和物品选择相关范围，并建立账号页面、入口、设置接入基线。其余已注册能力登记为现有接口索引，未进行逐调用验收；后续发现真实迁移需求时新增独立条目。

## 活动能力总表

| 编号 | 能力 | Core 状态 | 最低要求 / 发布依据 | 当前接入结果 | 下一触发点 |
| --- | --- | --- | --- | --- | --- |
| CAP-001 | 公共角色／联系人名称格式化 | 已提供 | Core 1.7.0 / API v8，`character-name-format:1`；尚未上传发布渠道 | Core 自身显示已接入；Mail 部分接入，其他业务范围随功能修改迁移 | 游戏内核对及业务剩余显示调用 |
| CAP-002 | 基础输入控件 | 已提供 | API v7，`basic-input:1`；文档首批 Core 1.6.1 | Currency 有明确接入与验证记录；Mail 版本要求已修正、旧输入部分待迁移；Vault 部分接入 | 对应搜索／输入控件修改时迁移，并核对最低版本 |
| CAP-003 | 物品解析、选择与操作确认 | 已提供 | API v7，`item-resolver:1`；Core 1.7.1 / API v8 提供 `item-picker:2` 批量扩展 | Currency 保持单物品兼容；Mail 已接入所列范围；Crafting／Vault 部分接入展示加载，AutoOpen 待评估 | 有真实批量录入需求时使用公开配置；业务校验与执行由业务插件负责 |
| CAP-004 | 账号页面、入口与设置工作台 | 已提供 | 账号页面／入口基线 API v5、`account-entry:1`；独立设置注册 API v6；当前 `account-view:2` 的首次提示增量另见 CAP-006 | 已有广泛注册；仍有旧设置壳、版本声明和验证待核对项 | 对应功能修改或经确认的集中迁移时处理所列缺口 |
| CAP-005 | 通用跨业务能力连接 | 已提供（最小 Service）；完整 Provider 待扩展 | 工作树 Core 1.8.0 / API v9、`business-services:1`；未发布。`business-contracts:1` 仍是草案 | Mail 提供 mail.items，Vault 消费 mail.items 并提供 vault.items，Currency 消费 vault.items；本轮相关测试通过 | 服务链游戏内验收；行动中心真实聚合需求出现后扩展 Provider／List |
| CAP-006 | 页面首次打开提示 | 已提供 | 工作树 Core 1.9.0 / API v10、`account-view:2`；未发布 | Core 概览及 Builds／Reputation／Todo 已写入 firstUseTip，业务检查 API v10 与能力；仅静态核对，记部分接入 | 自动化契约和低版本停止验证、游戏内一次性／预览／超时验收 |

### 当前插件最低版本与依赖基线

以下均于 2026-10-08 按工作树复核。数字表示初始化检查和 RegisterAddon 声明，不表示已接入该版本的全部能力；TOC 版本号没有随部分工作树修改提高，不能当作已发布接入版本。

| 插件技术名 | 最低 Core API | TOC Core 依赖 | 已检查的新能力 / 主要缺口 |
| --- | --- | --- | --- |
| YiboAltoBoss | 5 | RequiredDeps | 页面内业务设置；独立设置壳遗留见 AUD-005 |
| YiboAutoOpen | 6（可选设置） | OptionalDeps | 独立基础队列保留；本地输入与解析待评估 |
| YiboBeastPaths | 6（可选维护页） | OptionalDeps（各客户端 TOC） | Mists 维护适配；独立路线功能保留 |
| YiboBuilds | 10 | RequiredDeps | account-view:2；名称仍待迁移，首次提示验收待完成 |
| YiboCrafting | 7 | RequiredDeps | item-resolver:1；名称和搜索输入待迁移 |
| YiboCurrency | 9 | RequiredDeps | business-services:1；检查物品控件方法；仍有 OptionalDeps: YiboVault，见 AUD-007 |
| YiboLegendary | 5 | RequiredDeps | 页面内业务设置；名称待迁移 |
| YiboMail | 9 | RequiredDeps | business-services:1、character-name-format:1、item-picker:2 与 FormatName 方法 |
| YiboMounts | 5（可选设置） | 未声明 | 使用 v6 RegisterSettingsPanel；方法存在检查已避免缺失调用，版本／加载顺序仍见 AUD-004 |
| YiboQuestBlocker | 5 | RequiredDeps | 页面内业务设置；名称与基础输入待迁移 |
| YiboReputation | 10 | RequiredDeps | account-view:2；搜索输入和首次提示验证待完成 |
| YiboTaskHub | 未声明 / 未检查 | RequiredDeps | 仅 TOC 与命名空间，尚无 RegisterAddon／页面／服务 |
| YiboTodo | 10 | RequiredDeps | account-view:2；名称与首次提示验证待完成 |
| YiboVault | 9 | RequiredDeps | business-services:1；搜索输入部分接入，名称与另一过滤输入待迁移 |

源码依据：各插件 Bootstrap、Namespace 或 CoreIntegration，及各自根目录 TOC。强依赖插件仍须按实际所需 API／能力检查，不能统一把最低版本改成 10；业务提供方缺失与 Core 版本不足是两种不同的失败路径。

## CAP-001：公共名称格式化

### Core 当前状态与边界

- 已有 [Characters:GetDisplayName](../Data/Characters.lua)：`short` 读取以角色 ID 保存的短名，其余模式返回原始角色名。现有 `full` **不包含服务器**，必须保留该接口的兼容语义。
- 已提供 `Characters:FormatName(identity, options)`，能力声明为 `character-name-format:1`。`nameMode=original/short` 与 `realmMode=omit/sameRealm/full` 独立选择；同服参照服务器必须由调用方明确提供。正式契约见 [API v8 公共名称格式化](API-v8-公共名称格式化.md)。
- [共享角色表头](../UI/Theme.lua) 已接入新接口；保留业务传入名称／服务器的覆盖优先级、两段布局、旧 full 名称模式、真实身份悬停与状态提示，不要求旧业务插件改动调用或提高最低版本。
- 目录外联系人可直接提供 `{name, realm}` 格式化，不建立角色目录记录；短名只按明确提供的 Core 角色 ID 读取。联系人备注、职业色、WoW 文本转义、地址解析与业务操作仍归调用方。
- Core 内部已覆盖范围：[Theme](../UI/Theme.lua) 的表头、身份悬停与宽度测量；[角色档案字段](../Data/Fields/CharacterArchive.lua)；[角色档案删除确认](../UI/AccountPages/CharacterArchive.lua)；[设置工作台](../UI/AccountPages/SettingsWorkbench.lua) 的排序、短名管理身份标签。身份键、业务地址与短名存档结构未改动。
- 旧接口说明：[角色短名与统一服务器切换实施方案](Core-角色短名与统一服务器切换实施方案.md)。实施源码版本为 Core 1.7.0 / API v8（尚未上传发布渠道）。2026-10-07 验证通过：[CharacterNamesSpec](../_NonRelease/Tests/CharacterNamesSpec.lua) 75 项检查、Core TOC 的 44 个 Lua 5.1 文件语法检查、现有 Currency CoreItemControlsSpec 回归。游戏内 Core 档案／设置与旧业务主窗口／预览仍待核对。

### 业务插件接入表

首次登记为 2026-10-07；以下 14 项于 2026-10-08 静态复核。共享表头在 Core 内部已接入，业务仍须分别核对调用、最低要求与实际行为。名称测试的历史通过不代替本轮验证，见 AUD-009。

| 插件 | 状态 | 已有路径与证据 | 剩余范围 / 后续触发 |
| --- | --- | --- | --- |
| YiboAltoBoss | 待迁移 | [AccountPage.lua](../../YiboAltoBoss/AccountPage.lua) 本地组合名字与服务器；[Core.lua](../../YiboAltoBoss/Core.lua) 有 GetCachedCharacterLabel / GetCharacterLabel | 账号表头、角色行、行动项与设置标签；[LockoutsPage.lua](../../YiboAltoBoss/LockoutsPage.lua) 身份回退亦需核对。保留副本名称缩写业务逻辑，不能因同名 ShortName 函数误迁移 |
| YiboAutoOpen | 不适用 | [加载清单](../../YiboAutoOpen/YiboAutoOpen.toc) 与设置／队列代码未发现账号角色或联系人的名称显示需求 | 新增相应显示需求时重审；物品别名不属于角色短名 |
| YiboBeastPaths | 不适用 | [加载清单](../../YiboBeastPaths/YiboBeastPaths.toc) 及路线维护适配器以路线、宠物和坐标为显示对象 | 新增角色／联系人显示时重审；宠物名称不属于本能力 |
| YiboBuilds | 待迁移 | [AccountPage.lua](../../YiboBuilds/AccountPage.lua) 的 CharacterLabel 使用 Core 短名后本地追加服务器，角色行另用原名 | 预览标签、角色行与相应身份提示；装备装等等附加信息继续由业务组合 |
| YiboCrafting | 待迁移 | [AccountPage.lua](../../YiboCrafting/AccountPage.lua) 的 CharacterName 本地拼服务器，矩阵直接调用 Core 短名读取 | 矩阵、角色列表、角色下拉与 tooltip；核对不同布局是否应使用原名或短名 |
| YiboCurrency | 待迁移 | [AccountPage.lua](../../YiboCurrency/AccountPage.lua) 的 DisplayName / DisplayIdentity 本地格式化；调用共享表头时显式传入原名 | 表头、角色行、物品与货币 tooltip 标签及宽度测量；保留总计／空状态特殊行 |
| YiboLegendary | 待迁移 | [UI.lua](../../YiboLegendary/UI.lua) 的 CharacterLabel 用于列表、tooltip、确认及行动项 | 上述调用统一声明显示策略；人工确认应提供可精确识别的真实完整身份 |
| YiboMail | 部分接入 | 当前工作树 TOC 1.2.0-api1：AccountPage 总览／预览、ViewModel、CacheUI 等复用 FormatName；初始化检查 API v9、名称能力与方法；InboxReleaseSpec 本轮通过，其他已登记测试为历史证据 | Recipients:Label 仍自行按当前服务器组合联系人名称；保留备注优先、转义及邮寄地址解析。游戏内显示待验收 |
| YiboMounts | 不适用 | [加载清单](../../YiboMounts/YiboMounts.toc) 与图鉴提示／Core 设置适配未发现角色或联系人身份显示 | 新增相应显示需求时重审；坐骑名称与来源格式继续归业务 |
| YiboQuestBlocker | 待迁移 | [AccountPage.lua](../../YiboQuestBlocker/AccountPage.lua) 的 ShortName 实际返回原名；CharacterIdentity 解析回退键，并显式覆盖共享表头名称 | 当前角色分组标题、表头和身份 tooltip；旧键解析用于身份迁移，不能用格式化结果替代 |
| YiboReputation | 待迁移 | [AccountMatrixView.lua](../../YiboReputation/AccountMatrixView.lua) 与 [MonitoredPreview.lua](../../YiboReputation/MonitoredPreview.lua) 已调用共享角色表头 | Core 1.7.0 表头内部已接入；后续核对业务侧遗漏标签、最低要求与游戏表现，再记录业务显式接入。公会名称与公会键不属于角色显示 |
| YiboTaskHub | 待评估 | 2026-10-08 新建 [项目基础](../../YiboTaskHub/README.md)，仅有命名空间 | 角色显示随中心页面实现时接入；尚无显示调用或接入版本 |
| YiboTodo | 待迁移 | [AccountPage.lua](../../YiboTodo/AccountPage.lua) 的 CharacterLabel 本地按 showRealm 组合身份 | 账号待办角色标签与相关身份提示；保留活动名称和业务状态文本 |
| YiboVault | 待迁移 | [Tooltip.lua](../../YiboVault/Tooltip.lua) 本地按当前服务器拼角色名称；[StoragePage.lua](../../YiboVault/StoragePage.lua) 所有者标签使用原名 | 库存 tooltip 与仓储角色标签；公会显示、容器名称和公会身份键继续由各自逻辑处理 |

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
| YiboAltoBoss | 待迁移 | [Settings.lua](../../YiboAltoBoss/Settings.lua) 有本地 EditBox | Core 托管业务面板的等级、NPC、副本录入；旧独立设置壳另见 CAP-004。未登记接入版本 |
| YiboAutoOpen | 待迁移 | [Settings.lua](../../YiboAutoOpen/Settings.lua) 中空位、物品、确认来源和别名输入均本地创建 | 仅 Core 托管设置范围接入；独立运行与 OptionalDeps 关系须在实施时确认。未登记接入版本 |
| YiboBeastPaths | 待迁移 | [CoreDebugView.lua](../../YiboBeastPaths/Maintenance/CoreDebugView.lua) 的 Core 维护页本地创建多行输入 | 评估公共输入对多行导出的适配；独立 DebugCalibrator 窗口不自动扩大迁移。未登记接入版本 |
| YiboBuilds | 不适用 | 当前账号页面与设置接入代码未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboCrafting | 待迁移 | [AccountPage.lua](../../YiboCrafting/AccountPage.lua) 的搜索框本地创建 | 搜索框输入／焦点／清空行为；未登记接入版本 |
| YiboCurrency | 已接入 | [Settings.lua](../../YiboCurrency/Settings.lua) 的自定义物品选择器间接使用公共输入；[CoreIntegration.lua](../../YiboCurrency/CoreIntegration.lua) 当前工作树要求 API v9、business-services:1 和所需控件方法 | 所列范围首批 Currency 0.9.1 / API v7；当前控件专项未重跑，v9 服务迁移见 CAP-005 |
| YiboLegendary | 不适用 | 当前业务页与业务设置未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboMail | 部分接入 | 当前工作树 TOC 1.2.0-api1：CacheUI、SendRulesSettings 使用公共输入；最低 API v9；InboxReleaseSpec 本轮通过，WorkspaceSpec／RuleSendUISpec 为历史证据 | MailUI、NativeUI、RecipientUI 本地输入仍保留，随对应修改或经确认的集中迁移处理；游戏内待核对 |
| YiboMounts | 不适用 | 图鉴及 Core 设置适配未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboQuestBlocker | 待迁移 | [AccountPage.lua](../../YiboQuestBlocker/AccountPage.lua) 的等级表达式与手动任务录入本地创建 | 对应输入控件；任务 ID 校验仍归业务。未登记接入版本 |
| YiboReputation | 待迁移 | [AccountMatrixView.lua](../../YiboReputation/AccountMatrixView.lua) 的搜索框本地创建 | 搜索框及其状态；未登记接入版本 |
| YiboTaskHub | 待评估 | 2026-10-08 新建项目基础，尚无编辑控件 | 中心编辑器实现时复用公共输入；尚无接入版本 |
| YiboTodo | 不适用 | 当前待办设置与页面未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboVault | 部分接入 | [StoragePage.lua](../../YiboVault/StoragePage.lua) 的搜索框已使用公共输入 | [AccountPage.lua](../../YiboVault/AccountPage.lua) 的物品过滤输入仍本地创建；[Namespace.lua](../../YiboVault/Namespace.lua) 本轮最低 API 提高至 9。工作树，未登记首次发布版本／运行验证 |

## CAP-003：物品解析、选择与操作确认

公共契约与验证依据同 [API v7 文档](API-v7-物品选择与基础输入.md)。业务保存、执行、物品准入与风险文案由消费方提供；不是所有物品展示或扫描都需要选择器。

初次审查为 2026-10-07；以下条目于 2026-10-08 静态复核。状态只覆盖所述功能；Smoke／控件专项等此前通过记录为历史证据，本轮重跑范围见审查边界。

| 插件 | 状态 | 已覆盖 / 证据 | 剩余范围与接入版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 不适用 | 设置录入是 NPC／副本 ID | 不将这些 ID 当作物品；无接入版本 |
| YiboAutoOpen | 待评估 | [ItemResolver.lua](../../YiboAutoOpen/ItemResolver.lua) 本地解析物品 ID／链接／名字；TOC 将 Core 列为 OptionalDeps | Core 托管物品录入是候选；先确认独立运行约束与解析语义，再定范围，不能仅为迁移强制 Core 依赖 |
| YiboBeastPaths | 不适用 | 路线维护以坐标和路线数据为输入 | 无物品录入迁移项 |
| YiboBuilds | 不适用 | 当前构筑页面读取装备／配方数据，未发现可直接替换的物品输入选择器 | 业务动作与装备应用不自动纳入此项 |
| YiboCrafting | 部分接入 | AccountPage 产出名称通过 Core.ItemResolver 共享加载；初始化检查 API v7 / item-resolver:1；Smoke 通过 | 仅展示加载接入，搜索输入未迁移；配方规则归业务，游戏内待验收 |
| YiboCurrency | 已接入 | Settings 的 CreateItemPicker、删除操作确认复用 Core；本轮最低 API 提高至 v9；CoreItemControlsSpec 通过 | 所列范围首批 Currency 0.9.1；游戏内待验收 |
| YiboLegendary | 不适用 | 人工目标确认不是物品身份选择 | 不为统一形式改造成物品确认器 |
| YiboMail | 已接入 | 工作树 1.2.0-api1：NativeUI 附件加载复用 ItemResolver；指定规则使用 item-picker:2 的 multiple／retainInput；分类排除与全局黑名单复用单物品模式；初始化本轮检查 API v9、business-services:1 和 item-picker:2；使用公开配置 | 接口见 API-v8-批量物品确认；CoreItemControlsSpec、RuleSendUISpec、RuleSendSpec 和 InboxReleaseSpec 通过。游戏内待验收；新批量需求按契约扩展 |
| YiboMounts | 不适用 | 当前图鉴读取坐骑／物品来源，未提供通用物品录入 | 展示与来源查询不自动替换成选择器 |
| YiboQuestBlocker | 不适用 | 手动输入任务 ID | 校验与操作归任务业务 |
| YiboReputation | 不适用 | 搜索声望目录，未发现通用物品身份录入 | 声望搜索不属于物品解析 |
| YiboTaskHub | 待评估 | 2026-10-08 新建项目基础，尚无物品录入或确认调用 | 按中心编辑和校正的真实需求接入；尚无接入版本 |
| YiboTodo | 不适用 | 当前配置选择活动／目标，未发现通用物品身份录入 | 活动 ID 与业务条件不属于物品解析 |
| YiboVault | 部分接入 | StoragePage 格子复用 ItemResolver 展示加载，最低 API v9；过滤输入仍仅接受物品 ID | 选择器需求按过滤功能评估；展示异步加载游戏内待验收 |

## CAP-004：账号页面、入口与设置接入基线

已有公开接口见 [API v5](API-v5-业务插件接入指南.md)、[API v6](API-v6-业务插件增量接入指南.md) 与 [统一协作计划](Core-0.3-统一协作与改造计划.md)。下表登记源码路径，**不是运行时验收表**；存在注册路径统一记为部分接入，待验证实际行为和遗留分支后才能关闭本条目。2026-10-08 已静态复核；首次发布版本未逐一追溯。首次提示增量独立记录于 CAP-006。

| 插件 | 状态 | 已有接入与证据 | 剩余核对范围 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入 | [CoreIntegration.lua](../../YiboAltoBoss/CoreIntegration.lua) 注册页面、入口和业务设置 | [Settings.lua](../../YiboAltoBoss/Settings.lua) 仍保留 Core 缺失时的独立窗口分支；后续设置修改时收拢并核对升级提示 |
| YiboAutoOpen | 部分接入 | [CoreIntegration.lua](../../YiboAutoOpen/CoreIntegration.lua) 可选注册统一业务设置 | 验证 Core 可用／缺失时的设置路由；基础队列独立运行不自动纳入迁移 |
| YiboBeastPaths | 部分接入 | [CoreDebugAdapter.lua](../../YiboBeastPaths/Maintenance/CoreDebugAdapter.lua) 在 Mists 下可选注册维护页面与设置 | 核对客户端分支、晚接入与关闭行为；独立路线校准工具保留其既有范围 |
| YiboBuilds | 部分接入 | [CoreIntegration.lua](../../YiboBuilds/CoreIntegration.lua) 注册账号页与入口，业务设置只有描述元数据；当前最低 API v10 / account-view:2 | 验证页面／入口及低版本停止；当前无业务设置面板，不能虚记为已迁移面板；首次提示见 CAP-006 |
| YiboCrafting | 部分接入 | [AccountPage.lua](../../YiboCrafting/AccountPage.lua) 注册账号页与入口 | 验证页面／入口；当前未注册业务设置内容，没有第二套设置壳迁移项 |
| YiboCurrency | 部分接入 | [CoreIntegration.lua](../../YiboCurrency/CoreIntegration.lua) 注册页面、入口与业务设置 | 核对入口与设置现行契约的实际行为；CAP-003 所列物品控件验证不代替此范围验收 |
| YiboLegendary | 部分接入 | [UI.lua](../../YiboLegendary/UI.lua) 注册账号页、入口与业务设置 | 核对预览、完整页和设置行为 |
| YiboMail | 部分接入 | [AccountPage.lua](../../YiboMail/AccountPage.lua) 注册页面、入口与业务设置 | 当前工作树业务设置改造进行中；核对入口／账号快照与设置跳转，不能按旧文档直接认定完成 |
| YiboMounts | 部分接入 | [CoreIntegration.lua](../../YiboMounts/CoreIntegration.lua) 独立注册设置；[TOC](../../YiboMounts/YiboMounts.toc) 没有 Core 依赖声明 | RegisterSettingsPanel 属于 API v6，当前仅检查／声明 API v5；后续接入修改时明确其独立运行定位及 TOC 加载顺序。无账号入口需求 |
| YiboQuestBlocker | 部分接入 | [CoreIntegration.lua](../../YiboQuestBlocker/CoreIntegration.lua) 注册账号页、入口与业务设置 | 核对显示字段、预览与设置契约 |
| YiboReputation | 部分接入 | [CoreIntegration.lua](../../YiboReputation/CoreIntegration.lua) 注册账号页、入口与业务设置；当前最低 API v10 / account-view:2 | 核对矩阵／预览、设置及低版本停止；首次提示见 CAP-006。声望快照现有归属另需按业务边界评估，不以本次基线登记宣告迁移 |
| YiboTaskHub | 待评估 | 2026-10-08 新建 [TOC](../../YiboTaskHub/YiboTaskHub.toc)，已声明 Core 强依赖 | 页面、入口和设置尚未注册；随中心实现接入 |
| YiboTodo | 部分接入 | [CoreIntegration.lua](../../YiboTodo/CoreIntegration.lua) 注册账号页、入口与业务设置；当前最低 API v10 / account-view:2 | 核对业务设置与通用字段配置职责、实际行为及低版本停止；首次提示见 CAP-006 |
| YiboVault | 部分接入 | [AccountPage.lua](../../YiboVault/AccountPage.lua) 注册账号页、入口与业务设置 | 核对存储页、账号入口及设置行为 |

## CAP-005：通用跨业务能力连接

### Core 状态与边界

- 初次设计时状态为待实现。2026-10-08 初次静态核对 [Registry](../Runtime/Registry.lua)、[Events](../Runtime/Events.lua)、[Capabilities](../Runtime/Capabilities.lua) 与 [Bootstrap](../Bootstrap.lua)：当时 Core 1.7.1 / API v8 没有跨业务 Service／Provider 调用接口。
- 真实需求为独立行动中心的需求下发、业务待办和角色工作流聚合；Core 只提供连接与生命周期，不接管中心、库存、配方或邮件数据。
- 当前契约：[API v9](API-v9-业务服务与刷新.md)。工作树 Core 1.8.0 起已提供 `Core.Contracts` 的最小 Service 注册、发现、隔离调用和注销，能力为 `business-services:1`；当前 1.9.0 / API v10 保留该能力。本轮 RuntimePerformanceSpec、MailProviderSpec、VaultIntegrationSpec、InboxReleaseSpec 通过；尚未发布，游戏内待验收。
- 扩展草案：[行动中心最小能力契约 v1](../../Docs/行动中心-最小能力契约-v1.md) §2 的完整 Provider／List 与 `business-contracts:1` 仍待实现。草案所写 API v9 是原计划，不是当前可用能力或未来扩展版本承诺；不得仅凭 API >= 9 调用未实现的 Provider。
- 实施范围为真实需要的最小连接、输入输出隔离、冲突、版本、晚注册、注销与通用事件；旧业务调用在涉及范围内逐步接入，既有 Core UI API 行为保持兼容。

### 业务接入台账

以下记录最近审查日期为 2026-10-08。Mail／Vault／Currency 的既有库存协作已接入最小 Service，最低 API v9；行动中心的新能力仍待实施。其余业务在此能力下保持待评估。

| 插件技术名 | 接入状态 | 已覆盖及证据 | 剩余范围与版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 待评估 | 无该新连接接入证据 | 真实待办接入时评估，不推定适用或不适用 |
| YiboAutoOpen | 待评估 | 无该新连接接入证据 | 真实协作出现时评估，独立开包功能不因此扩展 |
| YiboBeastPaths | 待评估 | 无该新连接接入证据 | 真实协作出现时评估 |
| YiboBuilds | 待评估 | 已盘点 [Snapshot](../../YiboBuilds/Snapshot.lua) 与内部提升页面，尚无目标契约接入 | 计划 targets 与需求下发，核实装备身份和完成证据；当前 UI 最低 API v10 不代表服务已接入，扩展版本待定 |
| YiboCrafting | 待评估 | 已盘点 [Store](../../YiboCrafting/Store.lua) 与 [Collector](../../YiboCrafting/Collector.lua)，只有正向缓存 | 计划 production 与制作证据，材料和产出覆盖待验证；原计划 v9 不构成扩展版本承诺，无接入版本 |
| YiboCurrency | 已接入（本轮范围） | VaultIntegration 经 Core 发现 vault.items；缺失/不兼容保留 Core 基础快照；VaultIntegrationSpec、CoreItemControlsSpec 通过 | 最低 Core 1.8.0 / API v9、business-services:1；游戏内待验收，尚未发布 |
| YiboLegendary | 待评估 | 无该新连接接入证据 | 真实待办／目标接入时评估 |
| YiboMail | 部分接入 | Items 注册 mail.items v1.0，保留旧 API v1；InboxReleaseSpec、MailProviderSpec 验证升级停止与注册查询 | 最低 Core 1.8.0 / API v9、business-services:1；logistics／evidence 仍为行动中心计划，游戏内待验收、未发布 |
| YiboMounts | 待评估 | 无该新连接接入证据 | 真实协作出现时评估 |
| YiboQuestBlocker | 待评估 | 无该新连接接入证据 | 不把阻止接任务当成任务数据能力；真实需求出现再评估 |
| YiboReputation | 待评估 | 无该新连接接入证据 | 真实待办／目标接入时评估 |
| YiboTaskHub | 待评估 | [项目基础](../../YiboTaskHub/README.md) 已建立，尚无连接或需求能力注册 | 计划 demands 与业务聚合；原计划 v9 不构成扩展版本承诺，无接入版本或运行验证 |
| YiboTodo | 待评估 | 无该新连接接入证据 | 内部 Provider 不等于跨业务契约；真实待办接入时评估 |
| YiboVault | 部分接入 | v1.1.1-api1 发布 Items 的 vault.items v1.0 与 MailProvider 的 mail.items 消费；16 项 Vault 测试通过，覆盖来源生命周期、失败后历史缓存与实际 Mail API 的 Tooltip 投影；2026-10-09 审查 | 最低接口 API v9 / business-services:1，正式 Core 包需 1.9.0；inventory／evidence 仍是计划，双插件游戏内联动待验收；追赶须另核对 api10 |

行动中心技术名已确定为 YiboTaskHub；2026-10-08 已建立项目目录、TOC 和命名空间并联接到 MoP Classic 客户端。各活动能力先登记为待评估；当前项目基础不代表 Core 连接、任务能力或 UI 已接入。

## CAP-006：页面首次打开提示

### Core 状态与边界

- 工作树 Core 1.9.0 / API v10 已提供，注册能力为 `account-view:2`；契约见 [API v10](API-v10-首次打开界面提示.md)。这不改变 v5 页面注册基础接口的最低要求。
- [AccountView](../UI/AccountView.lua) 读取页面定义 `firstUseTip`；[Theme](../UI/Theme.lua) 提供 ShowFirstUseTooltip；[Database](../Data/Database.lua) 默认保存 firstUseHints。只在主视图成功显示后记录，以 pageID 区分，6 秒自动关闭；预览不触发。Core 概览已使用。
- 业务插件提供提示文案，Core 不解释业务、复制业务缓存或替代必需的状态／风险说明。本轮静态确认调用与版本检查；没有首次提示专项自动化或游戏内验收证据。

### 业务接入表

最近审查：2026-10-08。`不适用` 仅表示当前未注册首次提示，无须为了追赶版本给每页强加提示；后续真实需要时重审。

| 插件技术名 | 状态 | 已覆盖 / 证据 | 剩余范围与版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboAutoOpen | 不适用（当前范围） | 可选设置注册无 firstUseTip | 独立功能不因此提高 Core 门槛 |
| YiboBeastPaths | 不适用（当前范围） | 可选维护注册无 firstUseTip | 独立功能不因此提高 Core 门槛 |
| YiboBuilds | 部分接入 | 1.4.2：CoreIntegration 的模型旋转／缩放提示；Bootstrap 与 CoreIntegration 要求 API v10 / account-view:2；EquipmentAugmentSpec 验证低版本和缺失能力停止、正常注册提示 | 2026-10-08；一次性显示、预览及计时游戏内待验证 |
| YiboCrafting | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboCurrency | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboLegendary | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboMail | 不适用（当前范围） | 页面无 firstUseTip | 安全提示继续常显；新增引导时评估 |
| YiboMounts | 不适用（当前范围） | 可选设置注册无 firstUseTip | 独立功能不因此提高 Core 门槛 |
| YiboQuestBlocker | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboReputation | 部分接入 | CoreIntegration 的星标／设置监控提示；初始化要求 API v10 / account-view:2 | 工作树；低版本提示与停止、一次性显示、预览及计时待验证 |
| YiboTaskHub | 待评估 | 仅项目基础，尚无页面 | 页面实现时确定需求 |
| YiboTodo | 部分接入 | CoreIntegration 的设置开关／矩阵列提示；Namespace 与初始化要求 API v10 / account-view:2 | 工作树；低版本提示与停止、一次性显示、预览及计时待验证 |
| YiboVault | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |

## 后续方案观察项（尚无运行时能力）

| 方向 | 当前证据 | 对迁移节奏的影响 |
| --- | --- | --- |
| 中英文客户端适配 | [方案](../../Docs/Core系列中英文客户端适配方案与实施计划.md) 已确认待实施；当前 TOC 未加载公共语言服务 | Core 服务及检查工具可用后，业务插件按用户可见区域或经确认的逐插件收尾接入；目前不登记已接入或猜测 API／能力名称 |
| 内置 LDB 与信息条 | [方案](Core-内置LDB与信息条实施方案.md) 待实施；当前 TOC 仍仅 OptionalDeps LDB，Entry 仍为四态入口 | 方案明确保留 RegisterBusinessEntry、defaultMode 与 legacyIDs 兼容；主要由 Core 改造，不作为全插件追版本的前提 |
| 完整跨业务聚合 | CAP-005 的 Provider／List 尚为草案 | 按真实提供方／消费方链路实施，不等同于每个插件都必须注册服务 |
| 网络通讯协议 | 本轮在业务运行 Lua 中未找到 SendAddonMessage／CHAT_MSG_ADDON／RegisterAddonMessagePrefix；本机 Core.Events／Contracts 不属于网络协议 | 需求、契约和实现版本尚未确定；不作为当前追赶完成条件 |

## 其他现有能力索引

2026-10-08 按 TOC 所加载源码的 Capabilities:Register 复核；以下显式记录能力版本，不能把能力版本与 Public API 版本混为一谈：

| 类别 | 已注册能力 | 后续处理 |
| --- | --- | --- |
| 运行与配置 | runtime:1、database:1、migrations:1、events:1、resources:1、fields:1、addon-catalog:1、addon-status:1 | 现有基础设施；发现具体重复实现或版本缺口时建迁移条目 |
| 角色与数据 | characters:1、character-cleanup:1、character-profile:1、data-domains:1、domain-store:1、level-filter:1 | 角色身份与清理已有公共接口；character-profile 是旧兼容层，新功能按现有指南读取 DataDomains。数据域内容仍须遵守业务所有权 |
| 账号 UI | account-view:2、account-entry:1 | 接入基线见 CAP-004，首次提示见 CAP-006；注册存在不代表全部行为已验收 |
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
| AUD-009 | 名称测试把当前 API v10 当未来版本拒绝 | CAP-001 | 本轮 CharacterNamesSpec:26 失败；后续修改测试时按当前 API_VERSION + 1 检查未知版本，并显式覆盖 v10 接受／旧版兼容；未修改测试，保持待处理 |
| AUD-010 | 首次提示只有静态证据 | CAP-006 | 补契约与低版本停止验证，并在游戏内核对一次性、预览不触发、计时及帮助页；保持部分接入 |

## 更新记录

| 日期 | 更新范围 | 结果与证据 |
| --- | --- | --- |
| 2026-10-07 | 建立台账；首次静态审查 Core 与全部 13 个业务插件 | 登记 CAP-001～004、现有能力索引及 AUD-001～006；源码路径见各表；本轮仅文档更新，未修改运行代码或运行测试 |
| 2026-10-07 | CAP-001 Core 实施 | Core 1.7.0 / API v8 提供 FormatName 与 character-name-format:1，完成 Core 内部显示迁移；75 项名称／兼容检查、44 文件语法检查及 Currency 控件回归通过。业务状态保留，游戏内尚未验收 |
| 2026-10-07 | Mail 1.1.0 工作树接入；Core 1.7.1 批量控件扩展 | CAP-001 记录已覆盖与剩余名称调用；CAP-002 最低版本缺口关闭、旧输入保留待迁移；CAP-003 完成所列范围接入；AUD-002／006 关闭。相关自动化及 Core／Mail 66 文件语法检查通过；尚未发布，游戏内待验收 |
| 2026-10-08 | CAP-005 通用跨业务连接契约设计 | 新增待实现条目，计划 API v9 / business-contracts:1，登记首批业务现状与后续范围；未新增连接运行时、未接入业务或执行测试 |
| 2026-10-08 | 新建 YiboTaskHub 项目基础 | CAP-001～005 登记新插件为待评估；TOC、Namespace 和客户端目录联接已建立，尚无公共能力接入 |
| 2026-10-08 | 刷新扫描修复与最小 Service 实施 | CAP-003 记录 Mail／Vault／Crafting 展示加载；CAP-005 记录 Core business-services:1 与 Mail／Vault／Currency；接口与测试见 API-v9 文档。未发布、游戏内待验收 |
| 2026-10-08 | 台账复核与迁移节奏审查 | 修正当前工作树 1.9.0 / API v10、CAP-005 总表及能力版本；新增插件最低版本表、CAP-006 和规划观察项；更新 API 总览，登记 AUD-007～010。4 个相关测试通过，名称测试因过期版本断言失败；仅改文档，未修改 AGENTS 或运行／测试代码 |
