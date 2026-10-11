# Core 公共能力迁移台账

首次审查：2026-10-07。最近更新：2026-10-10。

2026-10-10 主动添加实施：当前工作树 **Core 1.11.0 / API v12**，新增 business-item-actions:1；TaskHub 0.5.0 / schema4，九个来源已接入。CAP-008 记录实际范围；230项新目标检查、672项既有集成及相关回归通过，客户端待验收、未发布。以下较早版本说明保留历史。


2026-10-09 O1 更新：当前工作树为 **Core 1.10.0 / API v11**，已实现 business-providers:1 与 List，尚未发布。ContractsSpec 90 项、RuntimePerformanceSpec、CharacterNamesSpec 77 项、MailProviderSpec、VaultIntegrationSpec、InboxReleaseSpec 通过，Core TOC 45 文件 Lua 5.1 语法通过。AUD-009 已修复。业务插件本轮没有运行代码变化，Provider 接入数量仍为零，来源输出及游戏验收另在 O2 执行。下面 2026-10-08 的版本与发布依据保留为历史记录，不代表本次工作树已发布。

本台账记录 Core 公共能力的实现与业务接入进度，长期规则见 [AGENTS.md](../../AGENTS.md)。按能力独立记录，允许多个迁移过程同时进行；业务修改继续触及即迁移，集中追赶结合后续插件大幅更新，实施节奏见 [迁移节奏审查](../../Docs/Core业务插件-迁移节奏审查-2026-10-08.md)。

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

## 活动能力总表

| 编号 | 能力 | Core 状态 | 最低要求 / 发布依据 | 当前接入结果 | 下一触发点 |
| --- | --- | --- | --- | --- | --- |
| CAP-001 | 公共角色／联系人名称格式化 | 已提供 | Core 1.7.0 / API v8，`character-name-format:1`；用户截图显示 v1.7.0-api8 已 Approved | Core 自身显示已接入；Mail 部分接入，其他业务范围随功能修改迁移 | 游戏内核对及业务剩余显示调用 |
| CAP-002 | 基础输入控件 | 已提供 | API v7，`basic-input:1`；文档首批 Core 1.6.1 | Currency 有明确接入与验证记录；Mail 版本要求已修正、旧输入部分待迁移；Vault 部分接入 | 对应搜索／输入控件修改时迁移，并核对最低版本 |
| CAP-003 | 物品解析、选择与操作确认 | 已提供 | API v7，`item-resolver:1`；Core 1.7.1 / API v8 提供 `item-picker:2` 批量扩展 | Currency 保持单物品兼容；Mail 已接入所列范围；Crafting／Vault 部分接入展示加载，TaskHub 0.3.0 部分接入图标；AutoOpen 待评估 | 有真实批量录入需求时使用公开配置；业务校验与执行由业务插件负责 |
| CAP-004 | 账号页面、入口与设置工作台 | 已提供 | 账号页面／入口基线 API v5、`account-entry:1`；独立设置注册 API v6；API v11 新增 `account-character-admission:1`、`account-surface-budget:1`；`account-view:2` 首次提示另见 CAP-006 | TaskHub O4 接入角色准入通知、悬停及业务设置；仍有旧设置壳、版本和客户端验证待核对项 | 对应功能修改或经确认的集中迁移时处理所列缺口 |
| CAP-005 | 通用跨业务能力连接 | 已提供（Service 与 Provider） | Service 最低 API v9 / business-services:1；Provider 工作树 Core 1.10.0 / API v11 / business-providers:1，未发布；文档见 API-v11 | Mail／Vault／Currency 已有 Service；Todo／Mail 输出三个 action.todo，TaskHub 通用消费 | ContractsSpec 90 项、TaskHub 集成与展示 327 项及邮件回归通过；主页面外观已确认，新来源和 O4 客户端待验收 |
| CAP-006 | 页面首次打开提示 | 已提供 | Core 1.9.0 / API v10、account-view:2；v1.9.0-api10 上传中，包含 api9 | Core 概览及 Builds／Reputation／Todo 已写入 firstUseTip，业务检查 API v10 与能力；仅静态核对，记部分接入 | 与 api9 同批核对；自动化契约和低版本停止验证、游戏内一次性／预览／超时验收 |

### 当前插件最低版本与依赖基线

以下均于 2026-10-08 按工作树复核。数字表示初始化检查和 RegisterAddon 声明，不表示已接入该版本的全部能力；TOC 版本号没有随部分工作树修改提高，不能当作已发布接入版本。

| 插件技术名 | 最低 Core API | TOC Core 依赖 | 已检查的新能力 / 主要缺口 |
| --- | --- | --- | --- |
| YiboAltoBoss | 5（基础）／11（目标增强） | RequiredDeps | 2.6.0 的刷取目标要求 business-services:1 / business-providers:1；基础追踪保留 API5，版本不足提示升级并停止增强；既有独立设置壳见 AUD-005 |
| YiboAutoOpen | 6（可选设置） | OptionalDeps | 独立基础队列保留；本地输入与解析待评估 |
| YiboBeastPaths | 6（可选维护页） | OptionalDeps（各客户端 TOC） | Mists 维护适配；独立路线功能保留 |
| YiboBuilds | 10 | RequiredDeps | account-view:2；名称仍待迁移，首次提示验收待完成 |
| YiboCrafting | 8 | RequiredDeps | character-name-format:1、item-resolver:1；共享角色表头／FormatName 方法检查，搜索输入待迁移 |
| YiboCurrency | 9 | RequiredDeps | business-services:1；检查物品控件方法；仍有 OptionalDeps: YiboVault，见 AUD-007 |
| YiboLegendary | 5 | RequiredDeps | 页面内业务设置；名称待迁移 |
| YiboMail | 9；新增集成 11 | RequiredDeps | 1.2.6-api1 基础业务保留 business-services:1、character-name-format:1、item-picker:2；action.todo 新邮件查看提醒单独检查 API11 / business-providers:1，不足仅停止新集成并提示升级 |
| YiboMounts | 5（可选设置） | 未声明 | 使用 v6 RegisterSettingsPanel；方法存在检查已避免缺失调用，版本／加载顺序仍见 AUD-004 |
| YiboQuestBlocker | 5 | RequiredDeps | 页面内业务设置；名称与基础输入待迁移 |
| YiboReputation | 10 | RequiredDeps | account-view:2；搜索输入和首次提示验证待完成 |
| YiboTaskHub | 11 | RequiredDeps | 0.4.0 增加 Service 双向查询、basic-input:1 与 CreateBusinessTabs／CreateInput 检查；既有角色／高度／物品要求保留。672项自动化通过，客户端待验收 |
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
| YiboAltoBoss | 部分接入（目标增强范围） | 2026-10-10 2.6.0 的目标行动标题使用 Core FormatName，增强初始化检查 API11 / character-name-format:1；基础 API5 行动保留原显示逻辑，此版本兼容边界已记录 | 既有账号表头／角色行／设置与 Core.lua 的名字组合继续是迁移库存，本轮未改该显示逻辑；LockoutsPage 身份回退另待涉及时核对。源矩阵状态与目标联动自动化通过，客户端待验收 |
| YiboAutoOpen | 不适用 | [加载清单](../../YiboAutoOpen/YiboAutoOpen.toc) 与设置／队列代码未发现账号角色或联系人的名称显示需求 | 新增相应显示需求时重审；物品别名不属于角色短名 |
| YiboBeastPaths | 不适用 | [加载清单](../../YiboBeastPaths/YiboBeastPaths.toc) 及路线维护适配器以路线、宠物和坐标为显示对象 | 新增角色／联系人显示时重审；宠物名称不属于本能力 |
| YiboBuilds | 待迁移 | [AccountPage.lua](../../YiboBuilds/AccountPage.lua) 的 CharacterLabel 使用 Core 短名后本地追加服务器，角色行另用原名 | 预览标签、角色行与相应身份提示；装备装等等附加信息继续由业务组合 |
| YiboCrafting | 部分接入 | AccountPage 矩阵复用 CreateMatrixHeader／SetCharacterHeader；角色下拉与详情显示复用 Characters:FormatName。初始化与注册要求 API v8，检查 character-name-format:1、FormatName 及共享表头方法；CoreNameIntegration、正向缓存 Smoke、Core CharacterNamesSpec 77 项通过 | 本次角色显示调用已接入，游戏内短名、职业色、全服服务器行及完整身份悬停待验收；AUD-011 代码修复完成，显示验收未完成 |
| YiboCurrency | 待迁移 | [AccountPage.lua](../../YiboCurrency/AccountPage.lua) 的 DisplayName / DisplayIdentity 本地格式化；调用共享表头时显式传入原名 | 表头、角色行、物品与货币 tooltip 标签及宽度测量；保留总计／空状态特殊行 |
| YiboLegendary | 待迁移 | [UI.lua](../../YiboLegendary/UI.lua) 的 CharacterLabel 用于列表、tooltip、确认及行动项 | 上述调用统一声明显示策略；人工确认应提供可精确识别的真实完整身份 |
| YiboMail | 部分接入 | 当前工作树 TOC 1.2.0-api1：AccountPage 总览／预览、ViewModel、CacheUI 等复用 FormatName；初始化检查 API v9、名称能力与方法；InboxReleaseSpec 本轮通过，其他已登记测试为历史证据 | Recipients:Label 仍自行按当前服务器组合联系人名称；保留备注优先、转义及邮寄地址解析。游戏内显示待验收 |
| YiboMounts | 不适用 | [加载清单](../../YiboMounts/YiboMounts.toc) 与图鉴提示／Core 设置适配未发现角色或联系人身份显示 | 新增相应显示需求时重审；坐骑名称与来源格式继续归业务 |
| YiboQuestBlocker | 待迁移 | [AccountPage.lua](../../YiboQuestBlocker/AccountPage.lua) 的 ShortName 实际返回原名；CharacterIdentity 解析回退键，并显式覆盖共享表头名称 | 当前角色分组标题、表头和身份 tooltip；旧键解析用于身份迁移，不能用格式化结果替代 |
| YiboReputation | 待迁移 | [AccountMatrixView.lua](../../YiboReputation/AccountMatrixView.lua) 与 [MonitoredPreview.lua](../../YiboReputation/MonitoredPreview.lua) 已调用共享角色表头 | Core 1.7.0 表头内部已接入；后续核对业务侧遗漏标签、最低要求与游戏表现，再记录业务显式接入。公会名称与公会键不属于角色显示 |
| YiboTaskHub | 部分接入 | 2026-10-09 0.3.1 主表执行角色／跨角色受益者、悬停角色标题／摘要复用 CreateMatrixHeader／SetCharacterHeader；FormatName short／sameRealm 用于紧凑角色行，详情执行者和跨角色受益者 original／full。显式检查共享方法，359 项回归及 Core 名称 77 项通过 | 修复 0.3.0 普通文本缺少职业色／统一身份提示；紧凑任务行采用共享控件单行模式；游戏内职业色／跨服身份待验收 |
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
| YiboCrafting | 待迁移 | [AccountPage.lua](../../YiboCrafting/AccountPage.lua) 的搜索框本地创建；规则后 a4c7944 新增清空交互仍未收拢基础输入，见 AUD-012 | 历史已触及输入应补 CreateInput 与版本／验证；本轮只改物品回调，不重复计一次输入漏迁 |
| YiboCurrency | 已接入 | [Settings.lua](../../YiboCurrency/Settings.lua) 的自定义物品选择器间接使用公共输入；[CoreIntegration.lua](../../YiboCurrency/CoreIntegration.lua) 当前工作树要求 API v9、business-services:1 和所需控件方法 | 所列范围首批 Currency 0.9.1 / API v7；当前控件专项未重跑，v9 服务迁移见 CAP-005 |
| YiboLegendary | 不适用 | 当前业务页与业务设置未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboMail | 部分接入 | 当前工作树 TOC 1.2.0-api1：CacheUI、SendRulesSettings 使用公共输入；最低 API v9；InboxReleaseSpec 本轮通过，WorkspaceSpec／RuleSendUISpec 为历史证据 | MailUI、NativeUI、RecipientUI 本地输入仍保留，随对应修改或经确认的集中迁移处理；游戏内待核对 |
| YiboMounts | 不适用 | 图鉴及 Core 设置适配未发现本地 EditBox | 新增输入时使用公共控件；无接入版本 |
| YiboQuestBlocker | 待迁移 | [AccountPage.lua](../../YiboQuestBlocker/AccountPage.lua) 的等级表达式与手动任务录入本地创建 | 对应输入控件；任务 ID 校验仍归业务。未登记接入版本 |
| YiboReputation | 待迁移 | [AccountMatrixView.lua](../../YiboReputation/AccountMatrixView.lua) 的搜索框本地创建 | 搜索框及其状态；未登记接入版本 |
| YiboTaskHub | 部分接入（本轮范围） | 2026-10-10 0.4.0 TargetsPage 的搜索使用 CreateInput(clearable=true)，复用清空与 IME 处理；检查 API11 / basic-input:1 及方法；BossTargetsSpec 覆盖缺失能力停止和真实标签页操作 | 新增输入均已收拢，中文输入法与客户端布局待验收；无物品选择需求 |
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
| YiboCrafting | 部分接入 | AccountPage 产出名称通过 Core.ItemResolver 共享加载；本轮因名称接入将累计最低要求提高至 API v8，继续检查 item-resolver:1；Smoke 通过 | 仅展示加载接入，搜索输入未迁移；配方规则归业务，游戏内待验收 |
| YiboCurrency | 已接入 | Settings 的 CreateItemPicker、删除操作确认复用 Core；本轮最低 API 提高至 v9；CoreItemControlsSpec 通过 | 所列范围首批 Currency 0.9.1；游戏内待验收 |
| YiboLegendary | 不适用 | 人工目标确认不是物品身份选择 | 不为统一形式改造成物品确认器 |
| YiboMail | 已接入 | 工作树 1.2.0-api1：NativeUI 附件加载复用 ItemResolver；指定规则使用 item-picker:2 的 multiple／retainInput；分类排除与全局黑名单复用单物品模式；初始化本轮检查 API v9、business-services:1 和 item-picker:2；使用公开配置 | 接口见 API-v8-批量物品确认；CoreItemControlsSpec、RuleSendUISpec、RuleSendSpec 和 InboxReleaseSpec 通过。游戏内待验收；新批量需求按契约扩展 |
| YiboMounts | 不适用 | 当前图鉴读取坐骑／物品来源，未提供通用物品录入 | 展示与来源查询不自动替换成选择器 |
| YiboQuestBlocker | 不适用 | 手动输入任务 ID | 校验与操作归任务业务 |
| YiboReputation | 不适用 | 搜索声望目录，未发现通用物品身份录入 | 声望搜索不属于物品解析 |
| YiboTaskHub | 部分接入 | 2026-10-09 0.3.1 的 Presentation 为三展示面使用 ItemResolver:GetInfo／Request 加载 item.itemID 图标；显式检查 API11 / item-resolver:1 和方法；来源 icon 直接渲染，缺失时通用任务图标 | OverviewSpec 包含一次请求、加载完成、非法元数据与缺能力停止；共 359 项回归通过，游戏内图标与加载效果待验收；后续编辑器仍需重新评估控件 |
| YiboTodo | 不适用 | 当前配置选择活动／目标，未发现通用物品身份录入 | 活动 ID 与业务条件不属于物品解析 |
| YiboVault | 部分接入 | StoragePage 格子复用 ItemResolver 展示加载，最低 API v9；过滤输入仍仅接受物品 ID | 选择器需求按过滤功能评估；展示异步加载游戏内待验收 |

## CAP-004：账号页面、入口与设置接入基线

2026-10-09 0.3.0 收拢：AccountPage 新来源／状态下拉全部使用 UITheme:CreateDropdown；预览继续消费可用高度预算；HUD／登录列表入口使用 SetPageScope 与 ShowPage 回到全服第一页。新增 OverviewSpec 验证折叠／展开、筛选、行池按钮及入口重置；无新增 Core 接口。用户 0.2.1 截图证实上一轮修复生效，本轮 UI 仍待验收，见 [收拢记录](../../Docs/行动中心-概念图收拢与流程修正.md)。

2026-10-09 O4／O5 联合复核增加 [视图可用高度](API-v11-视图可用高度.md)：Core 1.10.0 / API v11 / account-surface-budget:1，主页面与悬停在测量前提供高度预算，原有页面行为兼容。TaskHub 0.2.1 显式检查并直接消费；SurfacesSpec 现为 95 项，含真实 Core 测量、压缩后尺寸与缺能力停止。用户 0.2.0 截图已定位问题，修复后仍待客户端验收；其余业务页未触及。

2026-10-09 O4 按真实需求补齐 [角色准入通知](API-v11-角色准入通知.md)：Core 1.10.0 / API v11 / account-character-admission:1，隐藏及默认页面等级筛选有效变化后发出隔离事件。TaskHub 为首个消费者；无改动和无效输入不通知，订阅可清理。SurfacesSpec 追加 86 项检查包含实际 AccountView 路径，游戏内尚未验收。

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
| YiboTaskHub | 部分接入 | 2026-10-10 0.4.0 新增 Core CreateBusinessTabs 标签页，目标配置在主页面，自动显示开关在既有工作台业务区；名称、范围、入口、只读预览、HUD 和高度能力继续复用，672项检查通过 | 旧截图不替代新编辑器、窄窗口、IME 和完整登录流程验收；实际契约见刷取目标记录 |
| YiboTodo | 部分接入 | [CoreIntegration.lua](../../YiboTodo/CoreIntegration.lua) 注册账号页、入口与业务设置；当前最低 API v10 / account-view:2 | 核对业务设置与通用字段配置职责、实际行为及低版本停止；首次提示见 CAP-006 |
| YiboVault | 部分接入 | [AccountPage.lua](../../YiboVault/AccountPage.lua) 注册账号页、入口与业务设置 | 核对存储页、账号入口及设置行为 |

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
| YiboAltoBoss | 部分接入（运行代码与自动化完成） | 2026-10-10 2.6.0 经 Core 提供 boss.target-catalog 与 action.todo / planned-targets，消费 task.boss-targets；奖励观察、精确副本／难度、旧目录稳定键及自动投影均由来源负责，136项联动检查通过 | 可选增强显式 API11 / business-services:1 / business-providers:1；基础 API5 兼容边界已记录；客户端映射、窗口、切号及重置待验收 |
| YiboAutoOpen | 待评估 | 无该新连接接入证据 | 真实协作出现时评估，独立开包功能不因此扩展 |
| YiboBeastPaths | 待评估 | 无该新连接接入证据 | 真实协作出现时评估 |
| YiboBuilds | 待评估 | 已盘点 [Snapshot](../../YiboBuilds/Snapshot.lua) 与内部提升页面，尚无目标契约接入 | 计划 targets 与需求下发，核实装备身份和完成证据；当前 UI 最低 API v10 不代表服务已接入，扩展版本待定 |
| YiboCrafting | 待评估 | 已盘点 [Store](../../YiboCrafting/Store.lua) 与 [Collector](../../YiboCrafting/Collector.lua)，只有正向缓存 | 计划 production 与制作证据，材料和产出覆盖待验证；原计划 v9 不构成扩展版本承诺，无接入版本 |
| YiboCurrency | 已接入（本轮范围） | VaultIntegration 经 Core 发现 vault.items；缺失/不兼容保留 Core 基础快照；VaultIntegrationSpec、CoreItemControlsSpec 通过 | 最低接口 API v9 / business-services:1，渠道包需 v1.9.0-api10；业务接入未发布、游戏内待验收；追赶须另核对 api10 |
| YiboLegendary | 待评估 | 无该新连接接入证据 | 真实待办／目标接入时评估 |
| YiboMail | 部分接入（Provider 代码与自动化完成） | 1.2.6-api1 保留 mail.items v1.0／Items API v1；action.todo / inbox-collection 当前输出每角色一条新邮件查看提醒，Mail 所有已处理标记与批次；MailSourceSpec 80 项及邮件／Vault 消费回归通过 | 基础 API9 / business-services:1；可选任务集成 API11 / business-providers:1；客户端待验收，需求附件关联／logistics／evidence 仍未公开，追赶须另核对 api10 |
| YiboMounts | 待评估 | 无该新连接接入证据 | 真实协作出现时评估 |
| YiboQuestBlocker | 待评估 | 无该新连接接入证据 | 不把阻止接任务当成任务数据能力；真实需求出现再评估 |
| YiboReputation | 待评估 | 无该新连接接入证据 | 真实待办／目标接入时评估 |
| YiboTaskHub | 部分接入（运行代码与自动化完成） | 2026-10-10 0.4.0 通用消费 Todo 全量／Mail／AltoBoss action.todo，并提供 task.boss-targets、消费 boss.target-catalog；计划由 Task 保存，逐角色双向复制通过 Service 协作，schema3 迁移；672项检查通过 | API11 / business-services:1 / business-providers:1；本轮仅实现刷取计划安排，通用跨角色制作／任务链未实现；客户端待验收，见 [运行契约](../../Docs/行动中心-AltoBoss-运行契约与验收.md) |
| YiboTodo | 部分接入（运行代码与自动化完成） | 2026-10-09 1.1.4 注册神纹布与诺米 action.todo，独立 epoch／revision／覆盖与合并通知，持久元数据分开；实际模型及 133 项集成、日常／冷却／动作／旧日常回归通过 | 新集成 API v11 / business-providers:1；基础 UI 保留 API v10。游戏内观察、交付／重置与中心一致性待验收；当前已扩展至全部适用监控项目，见下方 2026-10-09 全量接入复核 |
| YiboVault | 部分接入 | v1.1.1-api1 发布 Items 的 vault.items v1.0 与 MailProvider 的 mail.items 消费；16 项 Vault 测试通过，覆盖来源生命周期、失败后历史缓存与实际 Mail API 的 Tooltip 投影；2026-10-09 审查 | 最低接口 API v9 / business-services:1，正式 Core 包需 1.9.0；inventory／evidence 仍是计划，双插件游戏内联动待验收；追赶须另核对 api10 |

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
| YiboBuilds | 部分接入 | 1.4.2：CoreIntegration 的模型旋转／缩放提示；Bootstrap 与 CoreIntegration 要求 API v10 / account-view:2；EquipmentAugmentSpec 验证低版本和缺失能力停止、正常注册提示 | 2026-10-08；一次性显示、预览及计时游戏内待验证 |
| YiboCrafting | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboCurrency | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboLegendary | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboMail | 不适用（当前范围） | 页面无 firstUseTip | 安全提示继续常显；新增引导时评估 |
| YiboMounts | 不适用（当前范围） | 可选设置注册无 firstUseTip | 独立功能不因此提高 Core 门槛 |
| YiboQuestBlocker | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |
| YiboReputation | 部分接入 | CoreIntegration 的星标／设置监控提示；初始化要求 API v10 / account-view:2 | 工作树；低版本提示与停止、一次性显示、预览及计时待验证 |
| YiboTaskHub | 不适用（O4 范围） | 2026-10-09 主页面及只读展示没有低频操作引导，HUD 拖动／锁定说明在业务设置常显，未登记 firstUseTip | 后续编辑器存在真实引导需求时重新评估 |
| YiboTodo | 部分接入 | CoreIntegration 的设置开关／矩阵列提示；Namespace 与初始化要求 API v10 / account-view:2 | 工作树；低版本提示与停止、一次性显示、预览及计时待验证 |
| YiboVault | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估 |

## 后续方案观察项（尚无运行时能力）

| 方向 | 当前证据 | 对迁移节奏的影响 |
| --- | --- | --- |
| 中英文客户端适配 | [方案](../../Docs/Core系列中英文客户端适配方案与实施计划.md) 已确认待实施；当前 TOC 未加载公共语言服务 | Core 服务及检查工具可用后，业务插件按用户可见区域或经确认的逐插件收尾接入；目前不登记已接入或猜测 API／能力名称 |
| 内置 LDB 与信息条 | [方案](Core-内置LDB与信息条实施方案.md) 待实施；当前 TOC 仍仅 OptionalDeps LDB，Entry 仍为四态入口 | 方案明确保留 RegisterBusinessEntry、defaultMode 与 legacyIDs 兼容；主要由 Core 改造，不作为全插件追版本的前提 |
| 业务任务聚合 | CAP-005 的 Provider／List 已提供；Todo／Mail 三个 action.todo 与 TaskHub 四个展示面已有代码及自动化 | 按真实提供方／消费方继续扩展；两个业务所有者已接入，不等同于全部业务或跨角色安排已实现 |
| 网络通讯协议 | 本轮在业务运行 Lua 中未找到 SendAddonMessage／CHAT_MSG_ADDON／RegisterAddonMessagePrefix；本机 Core.Events／Contracts 不属于网络协议 | 需求、契约和实现版本尚未确定；不作为当前追赶完成条件 |

## 其他现有能力索引

2026-10-08 按 TOC 所加载源码的 Capabilities:Register 复核；以下显式记录能力版本，不能把能力版本与 Public API 版本混为一谈：

| 类别 | 已注册能力 | 后续处理 |
| --- | --- | --- |
| 运行与配置 | runtime:1、database:1、migrations:1、events:1、resources:1、fields:1、addon-catalog:1、addon-status:1 | 现有基础设施；发现具体重复实现或版本缺口时建迁移条目 |
| 角色与数据 | characters:1、character-cleanup:1、character-profile:1、data-domains:1、domain-store:1、level-filter:1 | 角色身份与清理已有公共接口；character-profile 是旧兼容层，新功能按现有指南读取 DataDomains。数据域内容仍须遵守业务所有权 |
| 账号 UI | account-view:2、account-entry:1、account-character-admission:1 | 角色准入通知见 API-v11-角色准入通知；接入基线见 CAP-004，首次提示见 CAP-006；注册存在不代表全部行为已验收 |
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
| AUD-012 | Crafting 规则后搜索框清空交互已触及但未迁移 | CAP-002 | [执行审查 F02](../../Docs/Core触及即迁移-执行审查-2026-10-08.md)：a4c7944 晚于规则提交，新增 AttachClearButton 仍保留本地输入。待修复；发生于 Core 1.8 之前，作为历史旁证单列，不混入本轮窗口计数 |

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


2026-10-09 CAP-005 / Todo 全量接入复核：YiboTodo 1.2.0 保持 API v11 / business-providers:1 门槛，基础 UI 继续最低 API v10。`profession-cooldown` 输出全部适用冷却组；`nomi` 保留；新增 `activities` 输出其余 `monitoringProjects`，账号布林顿去重并投影候选。Core 连接实现和 TaskHub 消费实现无需改动。TodoSourcesSpec 177 项、原 359 项以及全部 Todo 烟雾测试通过；低版本停止、三来源注销／重注册已验证。状态仍为“部分接入（运行代码与自动化完成，客户端待验收）”。CAP-001／002／003／004／006 本次无新接入变化；未触及调用继续保持原台账状态。范围与实际契约见 [全量接入记录](../../Docs/行动中心-Todo全量接入.md)。

## CAP-007：轻量角色身份投影

2026-10-10；Core 状态：已提供（1.10.0 工作树，未发布）；API v11 / character-identity:1。职责、选项、返回字段、缺失及默认兼容语义见 [API 文档](API-v11-轻量角色身份.md)。不复制 domains，无新业务存储。

| 插件 | 状态与已覆盖范围 | 剩余范围／验证 | 最近审查 |
| --- | --- | --- | --- |
| YiboAltoBoss | 已接入：目标进度、行动投影、目标配置范围；增强初始化检查能力 | 基础 API v5 旧页面未触及的完整读取保留；缺少新能力停止增强、基础可用。专项219项与BossTargets136项通过 | 2026-10-10 |
| YiboTaskHub | 已接入：全部角色身份、目录、受益者、目标校验、主视图／预览／提醒；检查能力 | 无本次范围遗漏；Overview50项及依赖回归、专项219项通过 | 2026-10-10 |
| YiboTodo | 已接入：Bootstrap 任务事件、DailyQuest 观察、Snapshot、行动投影；最低API v11并检查能力 | 未触及的专业／农场采集和旧页面完整读取为后续库存；九个smoke与TodoSources177项、专项219项通过 | 2026-10-10 |

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
| YiboAltoBoss | 部分接入：世界／节日及锁定对象、GoalTargets；增强最低API12 | 客户端；原刷取编辑与批量复制复用同库，普通无周期锁定本不适用 | 2026-10-10 |
| YiboAutoOpen | 本轮对象不适用：即时操作 | 后续真实持久目标出现时评估；未改变基础功能 | 2026-10-10 |
| YiboBeastPaths | 本轮对象不适用：路线说明 | 无角色驯服完成采集；后续收藏入口再评估 | 2026-10-10 |
| YiboBuilds | 部分接入：宝石／附魔实际候选、具体装备与孔位；增强最低API12 | 客户端GUID、安全点击；其它强化不注册占位目标 | 2026-10-10 |
| YiboCrafting | 部分接入：配方行及角色格；制造次数、持有；增强最低API12 | 客户端；产出件数／材料物流未交付，不伪造证据 | 2026-10-10 |
| YiboCurrency | 部分接入：原生货币／金币角色格与标题；增强最低API12 | 客户端；账号货币合计未接入，物品数量归Vault | 2026-10-10 |
| YiboLegendary | 部分接入：角色最终目标；增强最低API12 | 客户端；任意中间节点与整链未接入 | 2026-10-10 |
| YiboMail | 部分接入：角色明确查看邮件目标；增强最低API12 | 客户端；寄达／收取需求关联未接入 | 2026-10-10 |
| YiboMounts | 当前入口不适用：Tooltip来源说明 | 未来收藏管理入口与完成采集再评估 | 2026-10-10 |
| YiboQuestBlocker | 本轮对象不适用：屏蔽规则 | 规则不转目标；未来真实业务对象另评估 | 2026-10-10 |
| YiboReputation | 部分接入：角色声望单元格、来源等级；增强最低API12 | 客户端；未采集／友谊rank缺失未知 | 2026-10-10 |
| YiboTaskHub | 部分接入：action.demands v1、参数面板、手势消费与目标定位；整体最低API12 | 客户端；代码及自动化闭环完成 | 2026-10-10 |
| YiboTodo | 部分接入：角色项目精确目标，不依赖显示监控；增强最低API12 | 客户端周期／账号活动；基础旧版本分支属兼容例外 | 2026-10-10 |
| YiboVault | 部分接入：仓储物品格、阈值与固定账号范围；增强最低API12 | 客户端仓储完整性；公会／拍卖目标未接入 | 2026-10-10 |

验证证据：GoalsSpec62、GoalSources40、BossGoals15、GoalSurfaces12；相关原集成672、性能219、布局197、显隐46、Core连接90／名称77、Todo九个smoke及Crafting两个smoke通过；17TOC／255Lua语法通过。详见 [实施与验证](../../Docs/行动中心-主动添加实施与验证.md)。自动化帧夹具不代替客户端验收，因此业务状态记“部分接入”。新增实际对象或修改同类入口时复用本能力；暂无对象的插件不提前生成空Provider。

### 本轮直接相关公共能力核对

- CAP-001／007：新增参数角色下拉、来源校验、作用域与目标管理显示使用 Core.FormatName / identityOnly，不以短名关联业务。本轮新增调用已接入；其它旧范围保持原台账状态。
- CAP-002／003／004：目标编辑复用共享输入／下拉／按钮和统一账号壳；移除及复制复用 ItemConfirmation；仓储物品名称复用 ItemResolver；不建第二套窗口、入口或角色设置。本轮直接相关逻辑已接入，客户端待验收。
- CAP-005：新增 action.demands Service 与九个 action.targets Provider，制造→库存公开调用、Boss兼容配置投影都经Core；Task目标所有权唯一，来源查询不读Task内部实现。来源内部读取自身Catalog／SavedVariables不越权。
- CAP-006：本轮未修改首次提示机制，原接入状态保持；新增空态引导是必要产品说明。
- 兼容例外：九个来源仅主动添加增强要求API12，原有基础业务继续自身旧最低版本；低版本显式提示并停止增强，没有新交互本地回退。适用旧Core；当来源整体提升最低版本时收拢此分支。TaskHub整体最低API12。

CAP-007 本轮补充：Vault Items 对个人仓储的明确 characters 范围在 API11 / character-identity:1 可用时逐个 Get(identityOnly=true)，不枚举并复制全部角色领域；增强入口仍最低API12并检查身份能力。Items原API服务旧Core分支保留，属于基础库存查询的明确兼容例外，整体提高版本时收拢。本轮调用已收拢，客户端性能待采样。

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
