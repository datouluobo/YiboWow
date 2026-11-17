# Forever 当前角色声望最小适配

## 2026-11-12 后续目录与快照重构规则

Mists、Forever 后续遵循[货币与声望：API 发现目录与角色快照规则](../../Docs/货币与声望-API发现目录与角色快照规则.md)。各角色已发现阵营按稳定 ID 合并为本目标账号目录，角色声望快照独立保存；有已验证的按 ID 详情接口时主动补查已知阵营。列表缺项不能当作中立或进度零；特殊声望类型、阈值和范围仍由本插件按各端证据解释，关注顺序与原设置保留。两目标平级并尽量共用实现。当前仅规则确认，API 补证、代码重构和迁移验收尚未完成；此前版本证据不外推为本方案通过。

## 2026-11-11 Reputation Forever 0.1.8 关注阵营矩阵

悬停使用关注阵营行、角色列和 Core 服务器范围、列分页。按账号关注顺序展示，使用已验证的等级与当前进度，详细信息进入格子提示。缺失观察显示问号。主表按账号关注清单管理，继续读取当前角色；旧存档各角色关注取并集并按阵营 ID 初始化一次，后续按玩家操作顺序保存。

职责限 Forever 视图和关注设置。复用 CAP-004 托管页、范围和分页，CAP-007 角色 GUID、CAP-009 语言。API13 与能力版本沿用，新增公开分页方法和 Core:Text 就绪检查。源码 `YiboReputation_Forever.toc`、包内唯一 `YiboReputation.toc`（16001）、`YiboReputationForeverDB` schema1、技术名与目录沿用。TOC 只更新版本，错目标保护、就绪检查、单次初始化和加载引用保持，旧文件留存无新增执行路径。

Forever 模拟 138 项、MoP 悬停回归、Mists 构建预检和 Forever 候选构建通过，包内 17 项已核对。候选见 `_NonRelease/ForeverBatch/AccountHoverCandidate-20261111`。客户端布局、两角色切换、保留文件覆盖和退出恢复待实机。

## 2026-11-10 Reputation Forever 0.1.7 关注悬停

对齐 MoP 的关注预览。主表提供关注管理和「仅看关注」，所选排序直接决定顺序。入口悬停只投影当前角色已关注的阵营，忽略主表搜索、等级和排序。空关注提示「尚未关注阵营」。使用同一快照、进度格式和 Core 入口生命周期。

Forever 模拟 135 项、MoP 悬停回归、Mists 构建预检及 Forever 构建通过。候选包 17 项并核对本机源码联接。源码 `YiboReputation_Forever.toc`、唯一包内 `YiboReputation.toc`（16001）、`YiboReputationForeverDB` schema1、技术名及目录沿用。只更新清单版本，引用、错目标保护、API13 与能力要求、Core 就绪及一次初始化守卫保持。保留旧文件不增加执行路径。新预览与覆盖／退出恢复待实机。

## 2026-11-10 Reputation Forever 0.1.6 声望列表滚动

列表保留所有匹配阵营，只为视口及少量缓冲行建立控件。滚动复用已有投影和控件，筛选回到列表顶部，窗口变宽或变高时重排可见行。复用控件后，提示和关注动作都对应当前阵营。已打开的提示随同一行数据更新，隐藏进度字段时同步隐藏背景及进度条。

134 项 Forever 模拟通过。243 条记录、三行视口的夹具只分配五个行控件，覆盖重用、提示清理、关注动作、宽高调整与筛选。Mists 构建预检与 Forever 候选包核对通过。候选包位于 `_NonRelease/ReputationForever/VisibleRowsCandidate-20261110`，实际窗口滚动、提示和覆盖／退出恢复待实机。

职责范围为 Forever 视图，复用 Core API13 的托管页面及滚动控件，能力及方法门槛保持。目标校验、Core 就绪、一次初始化、`YiboReputationForeverDB` schema1、技术名及目录沿用。源码 `YiboReputation_Forever.toc` 和包内 `YiboReputation.toc`（16001）仅更新版本，引用顺序和旧文件覆盖边界保持。

## 2026-11-10 Reputation Forever 0.1.5 阵营排序

主窗口可按名称、等级、本级进度比例或本次净变化排序。关注阵营继续优先，同值按阵营 ID 排序，无法确认的值排在所在组末尾。排序和搜索／等级／关注筛选组合使用，切换时返回列表顶部。入口悬停沿用同一数据与原顺序。

127 项 Forever 模拟覆盖排序、关注优先、正负与未知、组合搜索及悬停隔离。Mists 构建预检和 Forever 候选包核对通过。候选包位于 `_NonRelease/ReputationForever/FactionSortCandidate-20261110`。实际布局、排序交互和候选包恢复待实机。

本次职责为 Forever 托管页面的派生排序。复用 Core API13 下拉、输入及双语资源，无新能力门槛。客户端校验、Core 就绪、一次初始化守卫、角色清理与 `YiboReputationForeverDB` schema1 沿用。源清单 `YiboReputation_Forever.toc`、包内 `YiboReputation.toc`（16001）仅更新版本，技术名、安装目录、加载引用及旧文件覆盖边界保持。

## 2026-11-10 Reputation Forever 0.1.4 会话净变化

声望之路默认显示「本次净变化」。以每个阵营本次首次有效的普通声望读数为起点，按原生累计值显示正数、负数或零。无法验证的阈值、未观察和采集失败显示横线。阈值不再有效时丢弃该阵营的比较基准，原生范围标记变化时重新起算。退出或重载不恢复会话基准。Core「显示与入口」可选入悬停，预设保留旧悬停字段。

118 项 Forever 模拟覆盖旧存档、成功首读、正负变化、普通等级跨界、范围变化、读取失败、默认悬停和选择字段。Mists 构建预检及 Forever 候选包 `_NonRelease/ReputationForever/SessionCandidate-20261110` 核对通过。游戏内布局与自然声望变化待实机，已有普通声望采集证据沿用。

本次职责为 Forever 声望已观察数据的派生计算及同源界面。源清单 `YiboReputation_Forever.toc`、包内 `YiboReputation.toc`（16001）及引用顺序沿用，旧文件覆盖的加载图无新增引用。实际目标写库保护、Core API13／能力检查、一次初始化及角色清理沿用。`YiboReputationForeverDB` schema1 及安装目录不变。玩家包覆盖及当前版本实际恢复待实机。

2026-11-10 **0.1.3** 在主窗口加入插件自己的关注阵营列表。关注按当前角色和阵营 ID 保存，关注项优先排序，可叠加名称／ID 与声望等级筛选。入口悬停继续使用原字段与排序，关注操作不调用游戏追踪接口。清理角色时随对应快照删除。

可选关注数据沿用 `YiboReputationForeverDB` schema1，既有记录可读。Core API13、目标身份与能力检查、一次初始化保护、源清单 `YiboReputation_Forever.toc`、候选包唯一默认 `YiboReputation.toc`（16001）、加载顺序和技术名均保持。108 项 Forever 模拟覆盖置顶、叠加筛选、无关注、保存恢复及悬停。Mists 构建预检通过，Forever 候选包 `_NonRelease/ReputationForever/WatchCandidate-20261110` 17 项及本机源码联接核对通过。实际布局、覆盖和恢复待实机。

2026-11-09 **0.1.2** 主窗口新增阵营名称／ID 搜索和声望等级筛选。使用同一当前角色快照，组合条件取交集，显示匹配数。未经验证的等级保留「待确认」，悬停使用同一快照的原预览列。复用 Core 输入、下拉与 owner 双语资源，新增 `basic-input:1` 与控件方法检查，最低 API13。当前目标及依赖检查先于写库，沿用单次初始化守卫。

源码为 `YiboReputation_Forever.toc`，候选包为唯一默认 `YiboReputation.toc`，Interface16001，依赖 Core。此次只改 TOC 版本，运行引用及顺序保持，无 XML 或新增间接引用。安装目录和 `YiboReputationForeverDB` 及 schema 保持，Mists 的清单与存档保持。99 项模拟通过，含旧档恢复、错误客户端停写、Core 能力不足和预览。Mists 构建预检及 Forever 构建和解包核对通过，候选包含 17 项、7 个与源码一致的运行 Lua。0.1.1 保留文件覆盖、0.1.2 干净安装和新布局待实机，入口测试并入[合并清单](../../Docs/无限服-仓储搜索与收件筛选-2026-11-09.md)。

## 0.1.1 及之前记录

日期：2026-10-20。当前Forever版本0.1.1。状态：**等级名称、当前级进度及颜色条已获用户实机确认；已采集到增长后的声望值，其它项目按下文保留待验**。

2026-10-20用户明确“确认”，附图 `codex-clipboard-6c79cfa4-c424-405f-ba7a-493a4d505651.png` 显示0.1.1：中立黄色条、友善绿色条；暴风城友善100／6000、肯瑞托友善0／6000、诺莫瑞根流亡者中立2000／3000。等级名称、当前级进度、零进度与颜色条的本次中文主窗口展示通过。夜爪德鲁伊由前图0／3000变为100／3000，高阶会由1855／6000变为1905／6000，均标为本次已观察，确认增长后的值已被采集并展示；截图不能区分自动事件、手动刷新或重进世界触发。自动刷新路径、悬停、完整语言模式、存档独立恢复及MoP实机回归仍待验证。

按[已确认顺序](../../Docs/Yibo系列-无限服适用性与适配顺序-2026-10-19.md)接续Currency金币最小版。本轮仅观察当前角色可读声望，不把已有MoP验收外推到Forever。

## 版本与范围

| 目标 | 清单／版本 | 存档 |
| --- | --- | --- |
| Mists | YiboReputation.toc，Interface50504，1.7.2 | YiboReputationDB，原模块集合 |
| Forever | YiboReputation_Forever.toc，Interface16001，0.1.1 | YiboReputationForeverDB，schema1 |

Forever复用现有owner中英文资源，加载独立的Namespace／Store／Scanner／AccountPage／Bootstrap。声望的采集、保存与有效性属于Reputation；Core仅提供身份、名称、窗口、字段、入口、语言和缓存清理。没有跨业务消费方需求，不新增服务、目标Provider或共享数据层。

保存factionID、API原文名称、reaction、currentStanding与当前等级上下界、isAccountWide标记和观察时间。0.1.1对符合普通声望区间的记录，复用owner中英文等级资源显示中立、友善等名称，进度为 `value−minimum / maximum−minimum`，以对应等级颜色绘制进度条；最高普通等级显示已满。不改写存档中的原始事实。特殊声望结构尚未核实的记录显示待确认；不套用普通等级或进度。账号标记与业务共享结论分开，不汇总跨角色或推断规则集范围。

显示样例：暴风城友善100／6000、肯瑞托友善0／6000、诺莫瑞根流亡者中立2000／3000、高阶会友善1855／6000。0进度保留空条和数字；隐藏进度字段同时隐藏条和文字。主窗口、行提示与Core悬停使用同一业务显示函数；颜色优先读取客户端FACTION_BAR_COLORS，保留文字表达。采集、独立存档、范围及MoP实现不变。

不加载MoP固定声望目录、Nomi、友谊业务、历史Core声望导入、原矩阵及目标模块。Mists原实现保持；共享启动处仅增加Forever误用默认清单时的写库与初始化保护。

## 来源、覆盖和失败行为

参考[Forever生成的ReputationInfo API源码](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ReputationInfoDocumentation.lua)，于2026-10-20核对C_Reputation.GetNumFactions／GetFactionDataByIndex／GetFactionDataByID及FactionData字段。源码镜像与既有探针中的接口存在性均不能替代本机70374返回值实测。

- 进入世界且Core当前GUID有效后读取。PLAYER_ENTERING_WORLD／UPDATE_FACTION／FACTION_STANDING_CHANGED触发，BAG_UPDATE_DELAYED用于迟到身份恢复；原生事件按需合并，注册失败只记录目标不支持事件，不令启动中断。
- 只枚举当前原生可见列表，再按稳定factionID刷新**本插件此前已观察过**的项目；不使用列表索引、显示名或MoP目录作为身份。普通分组跳过，isHeaderWithRep的真实声望保留。不展开／折叠原生分组，不改监控、战争、排序或旧版显示选择。
- 覆盖永远是部分观察。折叠分组下首次未见的声望不会凭空发现；玩家正常展开后刷新可增加项目。已知项目若ByID返回nil或该方法缺失，保留旧记录并标为上次快照，不补成零、不宣称已删除。
- 用pcall及secret检查保护API和字段；验证计数、稳定ID、名称、整数字段及范围标记。两次完整采样的数量和按ID记录一致、当前GUID未变才原子提交。读取异常、缺行、缺字段、重复ID、错ID、数量变化或值变化时整批失败，保留前值。
- 可用声望中的真实0和负值允许保存；全列表空或只有分组不证明“没有声望”，保持待观察。API缺失显示不可用，已存值不会被覆盖为空。
- 每条事实保留自己的observedAt；本次可读项目为“本次已观察”，未重读项目为“上次快照”。窗口整体显示部分覆盖，而非“所有声望已完整采集”。离开世界／重载后旧记录全部先stale，重新采样后按项目恢复。

## 独立保存、Core与UI

独立库声明 `clientScope={target="Forever", projectID=18, scope="current-character", rulesetState="unknown"}`，characters以Core GUID为键，各factions以factionID为键。Get返回副本，只准入当前GUID；其它角色记录可保留但不显示或合计。schema超前、异客户端／范围或非法存档结构在写库前拒绝；不导入或改写Mists库。原生SavedVariables文件仍为目标客户端WTF中的YiboReputation.lua，表名YiboReputationForeverDB。

最低Core API13，检查localization:1、character-name-format:1、character-identity:1、characters:1、character-cleanup:2、account-view:2、account-entry:2、account-preview-characters:1、account-character-admission:1、account-surface-budget:2及实际方法。不足时提示升级并停止建库；Locale设施缺失时仅启动诊断用英文。可重复初始化并处理Core晚就绪。

本次接入CAP-001／004／007／009／010。没有输入、物品解析／选择或跨业务查询，CAP-002／003／005在本目标无调用，不加空接口。Mists最低要求保留。角色缓存清理使用Core v2注册；取消本角色未执行扫描，删除回放按每条观察时间保留删除之后的新事实，清理另一角色不打断当前采集。没有自动删除玩家缓存。

Core页面 `reputation` 与悬停共用同一行快照、角色准入、字段与状态；字段显隐、入口与窗口位置由Core管理。只在主窗口提供刷新。默认独立入口小地图／Broker／内置条全部关闭，不另建设置壳。关于页加入目标与当前角色描述，按技术名排序。

沿用 `/yrp`：打开页面；`/yrp scan`手动刷新并输出状态；`/yrp status`输出状态。注册前已全工作区搜索SLASH，只有本插件和历史副本使用该命令，没有新别名。新增玩家文字使用稳定ASCII key与owner资源，服从Core会话语言；API名称保留原文。

## 离线验证

0.1.1显示复核：目标模拟增至**91项通过**，补充实机样例的等级名称／当前级进度、负声望区间、最高等级、未知结构、条比例／零填充、字段显隐及主窗／悬停一致性。MoP原88项、Retention额外39、Hover回归保持通过；目标两清单24文件语法通过。下列70项为0.1.0阶段历史基线。

- `_NonRelease/ReputationForever/Smoke.lua` **70项通过**：真实目标清单、独立存档、未知／正值／负值／零、部分覆盖、折叠与ByID、无范围标记、带声望分组、原子失败保留、secret／NaN／非法计数／重复及错ID、变化事件、迟到GUID、保存恢复、角色准入、Core主窗／预览、删除与回放、缺API／Core能力／Locale、Core晚就绪、幂等、错目标／强制默认清单及四种语言组合。
- MoP既有声望迁移／采集／目标／身份／清理／初始化88项通过，Retention额外39项通过，Hover交互与错误状态检查通过。
- Core69、Currency60、Mail69、Vault2874保持通过；Core／Reputation四清单共74个Lua文件语法通过。Reputation Mists1.7.2／Interface50504构建ValidateOnly通过；未生成、发布或启用Forever发行包。
- 本地化报告已生成并查看：Core544资源缺英文／格式差异均0，Reputation硬编码候选0；原工作区6个未知key属于AutoOpen。中英文模拟不代替客户端语言验收。
- 两客户端的Reputation现有目录联接均指向源码，新增Forever TOC哈希一致；客户端路径继续由Tools/ClientPaths.psd1管理。

## 待实机清单

2026-10-20用户截图 `codex-clipboard-70781e72-363d-42ef-8402-9f4c8f62919f.png` 确认YiboReputation v0.1.0启动、当前角色与中文主窗口，展示8项声望：铁炉堡2000（0／3000）、诺莫瑞根流亡者2000（0／3000）、达纳苏斯500（0／3000）、暴风城3100（3000／9000）、塞纳里奥议会2100（0／3000）、肯瑞托3000（3000／9000）、夜爪德鲁伊0（0／3000）、高阶会4855（3000／9000）。所有行均标为“本次已观察”和“角色标记”，页面保留部分覆盖说明。据此确认正值及零值项目的实机采集展示；范围标记仅说明API返回的标记，不作为共享语义证据。

同日补充四张对照图（`3a54ae66-9745-45d0-a926-b25e26f9ebf2`、`8ee9b878-ae07-4066-a6e8-b5a7cd6df750`、`d3336a26-f3e6-4b84-84b4-61047161e9a0`、`a8a9db40-3d70-4eee-8313-070ca2507a7a`，均为codex-clipboard PNG）：原生暴风城友善100／6000对应插件3100（3000／9000），肯瑞托友善0／6000对应3000（3000／9000），诺莫瑞根流亡者中立2000／3000对应2000（0／3000）；高阶会原生1855／6000对应4855（3000／9000）。这些项目的等级区间及进度换算一致，原生列表可见阵营与插件8项名称相符。

用户明确说明最后一张为RL后：主窗口正常，8项记录及数值与RL前一致，均显示“本次已观察”。据此记录重载后启动、重新采集与展示流程通过；由于截图已完成重采，不能单独证明重采之前的存档恢复或完整退出后的落盘恢复。

仍待实机：其它项目的原生精确数值及范围标记对照；展开原生分组发现更多项目；获得声望后的自动／手动变化刷新；未重采历史快照恢复、完整退出／重登落盘；英文／手动语言模式、字段显隐、悬停及MoP原功能回归。当前截图未发生数值增长，不计为变化刷新通过，也不确认全声望覆盖。

银行、邮件附件、拍卖行、公会银行等原待测项目保持原状态。本轮只更新文档，未修改运行代码、自动操作游戏、提交或推送。

## 2026-10-24集中实机初始页面

2026-10-24 B01/Reputation页面反馈：用户截图显示YiboReputation v0.1.1、当前角色天堂-CAMWOW CN1 Realm 2 PvE，8行均标“角色标记／本次已观察”。可见铁炉堡中立2000/3000、诺莫瑞根流亡者中立2000/3000、达纳苏斯中立500/3000、暴风城友善100/6000、塞纳里奥议会中立2100/3000、肯瑞托友善0/6000、夜爪德鲁伊中立100/3000、高阶会友善2415/6000；中立黄色、友善绿色进度与零进度可见。登记当前普通声望8行及等级／进度展示，不据此前任务增长聊天和事后页面推定自动事件刷新通过，也不代替当前原生逐项数值对照。范围提示明确不代表全声望、账号标记不代表共享已验证。证据：`F:/Temp/User/codex-clipboard-b7cb0501-daba-4005-8225-664856187a8d.png`。原生对照与自然变化刷新并入B07；下一步B01物品总览，先不打开银行等原生来源。
