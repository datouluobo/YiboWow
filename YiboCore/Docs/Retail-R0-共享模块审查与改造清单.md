# Retail R0：共享模块全量审查与改造清单

R5当前状态（2026-10-27）：本页R0审查及改造编号保持历史快照，R0～R3适用实现已完成；R4 Retail／Mists声明的安装、覆盖和恢复范围通过，Forever实机保留待测。R5文档与台账收尾完成，不代表整个R4或发行门槛通过；当前范围、API／CAP与继续条件见[R5验收](R5-文档与台账收尾验收.md)。

日期：2026-10-27。状态：**R0 审查快照已完成。** 本文保留R0时点结论及原改造清单；后续R1-01～09已完成代码与离线验证，前阶段见[启动与预检记录](R1-01-02-启动与存档预检实施验收.md)，最新进度见下方链接。R0机器源码基线保持冻结。

后续更新：R1-03／04也已完成代码与两端离线验证，身份／数据域新边界与剩余实机范围见[本阶段验收](R1-03-04-角色身份与数据域实施验收.md)。下方逐文件表及待办描述为R0快照，最新R1-05／06已完成代码与专项、双目标离线回归，扩展旧夹具阻塞及新增实机见[本阶段验收](R1-05-06-公共物品与UI原生边界实施验收.md)；R1-07／08也已完成代码与389＋465项专项、双目标及消费者离线回归，见[最新目标元数据与契约验收](R1-07-08-目标元数据与通用契约实施验收.md)；R1-09文案与契约收尾现已完成，791项新专项及两端回归通过，见[最新收尾验收](R1-09-文案与契约文档收尾验收.md)。R1新增实机、最终包和扩展旧夹具阻塞仍待，Retail未接入。

R2-01／02后续更新：已完成Retail标准源／Mainline开发映射、最小身份与独立存档、三目标构建；正式服基础启动／页面实机及适用离线回归通过，见[当前验收](R2-01-02-Retail目标与构建实施验收.md)。下方R2待办仍为R0快照，R3及最终发行门槛未提前判定通过。

R3后续更新：12项既有公共能力足够，2463项三目标消费者专项及适用Mists／Forever回归通过，见[R3验收](R3-YBP离线兽栏公共契约实施验收.md)与[支持契约](API-v13-YBP离线兽栏公共支持契约.md)。没有生产运行改造或新能力，YBP业务未实施；本页R0清单和机器基线继续冻结，R4及发行门槛保持待验。

本记录落实[正式服适配方案](Retail-共享底座适配实施与验收方案.md)的 R0，配套[三目标能力矩阵](Retail-R0-三目标能力矩阵.md)与[机器源码基线](Retail-R0-源码基线.json)。审查范围是 Core 全部现存共享职责、实际清单与引用、目标采集器、未加载公共旧模块及相关构建入口。

## 1. 固定基线与方法

| 项目 | 本轮基线 |
| --- | --- |
| Mists | 1.12.9 / API13 / Interface50504 / schema11；`YiboCore_Mists.toc`；`YiboCoreDB` |
| Forever | 0.2.0 / API13 / Interface16001 / schema11；`YiboCore_Forever.toc`；`YiboCoreForeverDB` |
| Retail | 无 Core 源清单、目标入口、构建目标及目标存档声明；不能认定已有能力 |
| 默认入口 | `YiboCore.toc` → `Common/TocHint.lua`，无业务 SavedVariables |
| 扫描范围 | Core 排除 Docs／_NonRelease 的全部 Lua／TOC／XML：62 文件（59 Lua、3 TOC）；无 XML |
| 实际运行图 | Mists 51 Lua，Forever 49 Lua，并集53、交集47；含3个原样内嵌库 |
| 其余文件 | Hint1、退役Lua5、源TOC3；均逐项登记，不纳入有效业务运行图 |
| 哈希范围 | 上述62文件逐项 SHA256；构建配置／共享构建入口、库来源与许可证、媒体、所跑测试入口另附 SHA256 |
| 消费者 | 扫描14个其它 Yibo 插件的非测试业务Lua，检出能力字符串入口；结合公开方法及内部调用审查，不将字符串计数当接入证明 |

审查使用真实 TOC 逐行解析、全文件能力注册／原生调用／目标分支／加载指令扫描，结合注册、就绪、存档、采集、字段与消费者关键路径阅读。逐文件表覆盖全部62项；“保留”表示暂未发现必须修改其通用实现，仍须按实际共享 diff 回归，不表示三端已验收。当前不使用 Git 分支或提交身份代替源码字节基线，机器文件记录实际工作区内容。

## 2. 加载与引用图

1. 两个目标均按 `LibStub → CallbackHandler → LibDataBroker → Bootstrap` 启动；Forever 随后加载 `Forever/Target.lua`，Mists 没有对等显式 Target。
2. 随后为 Defaults／Capabilities／Locale／zhCN／enUS／Registry／SettingsRegistry／Events。Mists 在此加载 Calendar，Forever 不加载。
3. 共用 Contracts／DataDomains／Resources／ItemResolver／Fields／ArchiveFields／Commands／EntryConfig，再加载 Migrations／Database／Characters／CharacterCleanup／DomainStore。
4. Mists 注册 identity、professions、equipment、location、specialization；Forever 注册 identity、location 及自己的 professions。两端随后加载 CharacterArchive 字段、目录、AddonStatus、Profile、筛选与排序。
5. UI 顺序为 Theme／Input／确认／物品Picker／图标Picker／BusinessItemActions／AccountView，再五个内部页（Overview、CharacterArchive、SettingsWorkbench、Help、About），最后 Entry／EntryBar。内部页消费 AccountView._internal，顺序不能任意交换。
6. 所有 TOC 条目均为静态 Lua，存在性和重复引用已核对；运行 Lua 未检出 dofile／loadfile／LoadAddOn 等动态加载。当前没有 XML 或动态文件加载边，未来迁移后仍须重新检查。
7. 玩家包额外存在一条生成边：统一构建器将 `Data/PackagedAddonVersions.lua` 插入 `Runtime/AddonStatus.lua` 之前；该文件不在当前源码清单，是构建产物，不能当缺源文件或手工添加到运行源码。
8. Core 自有资源为 Media 图标；其它插件图标仅用于目录展示，目标过滤后才查询安装情况，未安装有 Core 图标回退，不是 Lua 依赖。原生 UI 模板／GameTooltip／StaticPopup／Minimap 属于客户端运行前提，另列验证。

机器基线的 `targets` 数组保留两端完整加载顺序；`files` 包含路径、行数、SHA256、所属目标及能力注册。拟迁移文件原路径残留必须保持不再被当前 TOC／间接引用执行，不运行磁盘清理。

## 3. 逐文件审查表

加载标记：MF=两端共用，M=Mists，F=Forever，H=默认Hint，T=源清单，—=未加载退役文件。具体改造编号见第5节。

| 文件（相对 YiboCore） | 加载／行数 | 职责与审查结论 |
| --- | --- | --- |
| [Bootstrap.lua](../Bootstrap.lua) | MF / 73 | 启动与原生事件：改造 R1-01：目标策略先于生命周期事件注册；只订阅目标所需事件，保留支持结果诊断。 |
| [Common/TocHint.lua](../Common/TocHint.lua) | H / 8 | 预启动诊断：保留最小双语提示；R2-01 仅更新真实 Interface 集合，不建立 Core／存档／事件。 |
| [Data/AddonCatalog.lua](../Data/AddonCatalog.lua) | MF / 149 | 目标目录元数据：改造 R1-07：消除无 target 默认 Mists 假设；登记 YBP 已有 Retail 路线支持，区分尚未接入的兽栏。 |
| [Data/CharacterCleanup.lua](../Data/CharacterCleanup.lua) | MF / 240 | 清理所有者与删除历史：改造 R1-07：EXPECTED_OWNERS 六业务固定名单需按目标元数据限定，并保留当前存档已知 owner 与待重放记录。 |
| [Data/Characters.lua](../Data/Characters.lua) | MF / 389 | 角色目录与名称显示：改造 R1-03：共享 GUID／短名／复制／排序契约；原生身份读取与 legacy 策略归目标边界。 |
| [Data/Database.lua](../Data/Database.lua) | MF / 125 | 存档与就绪协调：改造 R1-01／02：严格产品判定、异常结构预检、幂等初始化与成功后就绪；保留旧 Mists 无目标戳存档兼容。 |
| [Data/Domains/Economy.lua](../Data/Domains/Economy.lua) | — / 66 | 退役货币采集：不加载；开头 return；历史读取保留，不能恢复业务所有权。 |
| [Data/Domains/EconomyItems.lua](../Data/Domains/EconomyItems.lua) | — / 74 | 退役物品货币采集：不加载；开头 return；不迁入 Retail。 |
| [Data/Domains/Equipment.lua](../Data/Domains/Equipment.lua) | M / 20 | Mists 装等采集：迁移 R1-04 至 Mists/Equipment.lua，既有行为先保持；Retail 暂缓。 |
| [Data/Domains/Identity.lua](../Data/Domains/Identity.lua) | MF / 29 | 两端共用身份域定义与原生读取：拆分 R1-03／04：身份域投影共享，采集和缺数据语义落目标边界；核对种族／阵营多返回值。 |
| [Data/Domains/Location.lua](../Data/Domains/Location.lua) | MF / 18 | 两端位置采集：拆分 R1-03／04：共享状态／投影保留，原生位置读取落现有目标适配层；Retail 首期不采位置。 |
| [Data/Domains/Professions.lua](../Data/Domains/Professions.lua) | M / 74 | Mists 专业目录与采集：迁移 R1-04 至 Mists/Professions.lua，保留六槽与原生别名回退；不附加 Forever 专业能力承诺。 |
| [Data/Domains/Reputation.lua](../Data/Domains/Reputation.lua) | — / 123 | 退役声望源码：不在 TOC；不像货币文件有顶层 return，须防止误重引；Core 不恢复声望业务。 |
| [Data/Domains/Specialization.lua](../Data/Domains/Specialization.lua) | M / 17 | Mists 专精采集：迁移 R1-04 至 Mists/Specialization.lua；Retail 暂缓。 |
| [Data/DomainStore.lua](../Data/DomainStore.lua) | MF / 66 | 通用状态快照：保留复制／revision；R1-04 明确 nil 保留与空表替换语义，updatedAt 是变更时间，不能作为 YBP 采集时间。 |
| [Data/Fields/CharacterArchive.lua](../Data/Fields/CharacterArchive.lua) | MF / 45 | 档案字段与旧专业槽映射：拆分 R1-04：共享字段注册按实际域；SECONDARY_SLOTS 旧槽映射与目标字段集合归适配层。 |
| [Data/Migrations.lua](../Data/Migrations.lua) | MF / 179 | schema1～11 迁移：共享保留；R1-02 验证结构再迁移，保留旧设置／入口语义；不预定新 schema。 |
| [Data/Profile.lua](../Data/Profile.lua) | MF / 78 | 旧 v4 档案兼容门面：共享保留；R1-04 回归域投影／旧收集器通知，不把所有业务数据迁入 Core。 |
| [Data/Resources/Economy.lua](../Data/Resources/Economy.lua) | — / 13 | 退役金币资源定义：不加载；开头 return；历史 money 字段测试不能作为恢复该资源的理由。 |
| [Forever/Professions.lua](../Forever/Professions.lua) | F / 63 | Forever 专业采集：保留七槽、权威 skillLineID、双次读取及失败保留；回归 R1-04，不接入 Retail。 |
| [Forever/Target.lua](../Forever/Target.lua) | F / 13 | Forever 目标策略：R1-01／02 统一策略结构，保持版本0.2.0、GUID要求、禁导入及原存档身份；旧证据按字节复用。 |
| [Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua](../Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua) | MF / 202 | 内嵌回调库：原样保留；securecallfunction 与可重复库初始化列实际目标验证。 |
| [Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua](../Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua) | MF / 90 | 内嵌 Broker 库：原样保留；无业务 API；对象复用／不可可靠注销由 Core Entry 处理。 |
| [Libs/LibStub/LibStub.lua](../Libs/LibStub/LibStub.lua) | MF / 30 | 内嵌库注册：原样保留；全局库版本复用，保持三库加载顺序。 |
| [Locales/enUS.lua](../Locales/enUS.lua) | MF / 568 | Core 英文资源：R1-09 按改造增加稳定 key／完整插值；旧资源不重译或改动态名称。 |
| [Locales/zhCN.lua](../Locales/zhCN.lua) | MF / 568 | Core 中文资源：R1-09 与英文 key／格式一致；自动模式覆盖 zhCN／zhTW。 |
| [Mists/Calendar.lua](../Mists/Calendar.lua) | M / 77 | Mists 日历事实：目标边界已明确，保持原实现；Retail 不加载／不声明该能力。 |
| [Runtime/AddonStatus.lua](../Runtime/AddonStatus.lua) | MF / 73 | 插件安装／启用／连接状态：R1-06：现代与旧 C_AddOns getter／签名集中适配验证；连接不代替业务就绪。 |
| [Runtime/ArchiveFields.lua](../Runtime/ArchiveFields.lua) | MF / 96 | 跨业务档案字段 Provider：共享保留；GetFields／Read／副本／冲突及失效回归，无提供者时空集合。 |
| [Runtime/Capabilities.lua](../Runtime/Capabilities.lua) | MF / 40 | 能力注册与版本检查：共享保留；R1-08 按目标实际加载集合核对，不把 capability true 当初始化成功。 |
| [Runtime/Commands.lua](../Runtime/Commands.lua) | MF / 19 | /yco 玩家入口：共享保留；未就绪只提示，继续使用三字母命令，不新增别名。 |
| [Runtime/Contracts.lua](../Runtime/Contracts.lua) | MF / 155 | Service／Provider 契约连接：共享保留；owner、版本、冲突、晚注册／注销、参数与返回复制回归；不新建宠物契约。 |
| [Runtime/CurrencyCatalog.lua](../Runtime/CurrencyCatalog.lua) | — / 52 | 退役货币目录：不加载且开头 return；残留 currency-catalog:1 不计有效能力。 |
| [Runtime/DataDomains.lua](../Runtime/DataDomains.lua) | MF / 106 | 域注册与事件分发：改造 R1-04：正常返回 nil 被 data or {} 吞掉，须保留失败旧值；定义事件参与目标生命周期订阅。 |
| [Runtime/EntryConfig.lua](../Runtime/EntryConfig.lua) | MF / 54 | 三通道设置规范化：共享保留；迁移旧 mode、八组合及内置条总开关恢复回归。 |
| [Runtime/Events.lua](../Runtime/Events.lua) | MF / 67 | 内部公开事件：共享保留；同 owner／callback 去重与清理、Fire／FireIsolated 不同语义不混改。 |
| [Runtime/Fields.lua](../Runtime/Fields.lua) | MF / 57 | 静态与业务档案字段：共享保留；按已注册域合法性检查，返回隔离、动态 Provider 合并与冲突回归。 |
| [Runtime/ItemResolver.lua](../Runtime/ItemResolver.lua) | MF / 117 | 物品解析与异步请求：改造 R1-05：0～4 固定背包范围、getter/request/event 原生差异集中适配；保留取消／超时／显式重试。 |
| [Runtime/Locale.lua](../Runtime/Locale.lua) | MF / 135 | 语言会话与 owner 资源：共享保留；加载前可查资源、初始化后按设置生效；R1-09 回归重复初始化与绑定。 |
| [Runtime/Registry.lua](../Runtime/Registry.lua) | MF / 111 | 插件及资源 owner 注册：共享保留；依赖 API、同 owner 重入、冲突与释放语义；R1-01 检查 Core 自身注册结果。 |
| [Runtime/Resources.lua](../Runtime/Resources.lua) | MF / 31 | 中性资源定义：共享保留；不产生 currency／reputation／pet 值；无目标域不注册对应资源。 |
| [Runtime/SettingsRegistry.lua](../Runtime/SettingsRegistry.lua) | MF / 66 | 独立设置注册：共享保留；同 owner 重入／冲突／注销回归；没有独立 settings 能力名，不虚构检查。 |
| [UI/AccountPages/About.lua](../UI/AccountPages/About.lua) | MF / 291 | 关于页与目标目录展示：共享布局保留；R1-07 核对目标过滤、安装／连接状态与版本索引，不把路线可用表述为兽栏已接入。 |
| [UI/AccountPages/CharacterArchive.lua](../UI/AccountPages/CharacterArchive.lua) | MF / 310 | 角色档案页及投影：共享保留；R1-04 按实际域显示字段、空集合与历史字段设置兼容；不恢复缺失专业栏。 |
| [UI/AccountPages/Help.lua](../UI/AccountPages/Help.lua) | MF / 117 | 帮助页静态业务说明：改造 R1-07：OPERATIONS／USAGE_NOTES 无目标筛选，改为按明确目标元数据组织显示，保留已有说明。 |
| [UI/AccountPages/Overview.lua](../UI/AccountPages/Overview.lua) | MF / 118 | 业务摘要与行动聚合：共享保留；仅枚举已注册页、页面准入和同源摘要，无业务时正常空态。 |
| [UI/AccountPages/SettingsWorkbench.lua](../UI/AccountPages/SettingsWorkbench.lua) | MF / 933 | 统一设置工作台：共享保留并回归；技术名字母序、固定导航、字段／入口／角色集中管理；R1-07 清理影响说明按真实 owner。 |
| [UI/AccountView.lua](../UI/AccountView.lua) | MF / 1939 | 共享窗口与页面生命周期：R1-06／08 核对原生帧／secure 状态驱动；保持角色准入、跨服 all、预算与分页；重复页 ID 仍拒绝，调用方协调幂等。 |
| [UI/BusinessItemActions.lua](../UI/BusinessItemActions.lua) | MF / 338 | 通用行动项目连接／交互：共享机制保留；R1-06 合并 GetMouseFoci／GetMouseFocus 选择；无 action Provider 时增强不可用，原 UI 正常。 |
| [UI/Entry.lua](../UI/Entry.lua) | MF / 690 | Broker／小地图／预览／入口协调：改造 R1-06：ResolveAnchor 仅旧焦点入口，与项目操作重复；统一焦点查询，保留八组合／注销对象策略。 |
| [UI/EntryBar.lua](../UI/EntryBar.lua) | MF / 135 | 内置条布局与拖拽：共享保留；屏幕安全边界、分页、禁用选择保留与拖拽恢复回归，不新增默认入口。 |
| [UI/IconPicker.lua](../UI/IconPicker.lua) | MF / 106 | 公共图标选择：R1-06 将全局宏图标枚举／返回约定归原生边界，保留无数据重试和分页；不新增图标业务目录。 |
| [UI/Input.lua](../UI/Input.lua) | MF / 133 | 公共输入与 IME：共享保留；目标帧方法差异核验，组合输入／隐藏清焦点／Esc／多行配置回归。 |
| [UI/ItemConfirmation.lua](../UI/ItemConfirmation.lua) | MF / 37 | 公共确认请求：共享保留；原生 StaticPopup、取消、代次和隐藏清理回归；不增加业务窗口壳。 |
| [UI/ItemPicker.lua](../UI/ItemPicker.lua) | MF / 288 | 物品选择与输入／光标交互：共享保留；R1-05／06 通过适配边界处理光标／物品读取，保持代次失效与确认语义。 |
| [UI/Theme.lua](../UI/Theme.lua) | MF / 1027 | 公共样式、几何、控件与 Tooltip：共享保留；R1-06 核验字体、BackdropTemplate、Frame／GameTooltip 方法，保持布局／滚动预算；无视觉重设计。 |
| [Util/CharacterSort.lua](../Util/CharacterSort.lua) | MF / 173 | 角色排序纯逻辑：共享保留；同名跨服与 GUID 稳定兜底、置顶／自定义顺序与替换回归。 |
| [Util/Defaults.lua](../Util/Defaults.lua) | MF / 35 | 默认值与复制纯逻辑：共享保留；R1-02 在调用前验证存档结构，不能用默认值静默修复异常类型。 |
| [Util/LevelFilter.lua](../Util/LevelFilter.lua) | MF / 85 | 等级表达式纯逻辑：共享保留；合法／非法输入及三端语言错误文本回归，无固定客户端等级上限。 |
| [YiboCore.toc](../YiboCore.toc) | T / 5 | 默认 Hint 清单：R2-01 保持无 SavedVariables／运行链，仅列已实测 Interface；玩家包不含 Hint。 |
| [YiboCore_Forever.toc](../YiboCore_Forever.toc) | T / 64 | Forever 加载图：R1-01／04 与 R2-02 同步引用，保留存档／目标版本；只保留本端采集器。 |
| [YiboCore_Mists.toc](../YiboCore_Mists.toc) | T / 66 | Mists 加载图：R1-01／04 增加显式 Mists 入口并替换迁移引用；存档身份保持。 |

### 构建、库与资源补充

- `Tools/ReleaseProfiles.psd1`：Core 只登记 Mists／Forever；全局认识 Retail 目标不等于 Core 已配置。YBP 现有默认／Mainline／Mists 清单通过 LegacyBundles 显式映射，需与 Core 版本索引逻辑协同。
- `Tools/Release.Common.ps1:Get-YiboTocEntries`：只接受静态 Lua，检查越界、其它目标目录、重复条目与非发布内容。迁移必须同步清单，不需要引入 XML。
- `Get-YiboPackagedAddonVersions` 当前只检查 Addons 配置及 `_<Target>.toc`，Mists 才回退默认清单；因此后续新增 Core Retail 时，现有 YBP Mainline／默认映射不会自动进入 Retail 版本索引。R2-02 必须按既有明确映射补齐，不能重命名 YBP 来迎合索引。
- `Tools/Build-ReleasePackages.ps1`：注入版本索引、添加3份库说明／许可证、只收集 Media 顶层 TGA；全目标源码归档则包含公开源码／文档。R0 文档可进入源码归档，不会成为玩家包加载代码。
- `YiboCore/_NonRelease/Tools/Build-ReleasePackages.ps1`：转调统一构建器，默认 Mists；保留兼容入口，后续使用参数选择 Retail。
- 三库保持已有上游版本与声明。CallbackHandler 使用 `securecallfunction`；LDB 无可靠注销协议，Entry 保留同名对象并禁用交互的策略须回归。无上游升级需求，不在本轮修改第三方库。
- Media 的35个文件已固定摘要，未修改图标或资产；实际玩家包资源仍以构建器 TGA 规则及清单验证为准。宏图标Picker读取客户端原生目录，不是这些自有媒体文件。

## 4. 关键发现与证据

以下“确认缺口”是源码行为与本次适配要求之间的差距；“待目标核验”不等于断言某正式服 API 已被移除或返回错误。

| 编号 | 证据位置 | 结论与影响 | 类型 |
| --- | --- | --- | --- |
| F01 | Database.lua:62～70；Mists TOC无Target | 无 target 只明确拒绝 Camelot，剩余客户端默认使用 YiboCoreDB；Retail／其它产品没有严格拒绝条件。要让 Mists 显式识别产品并保护写库 | 确认缺口；R1-01／02 |
| F02 | Database.lua:101～121；Bootstrap.lua:48～52 | ADDON_LOADED 有就绪挡板，直接 Core:Initialize 没有；Database 已初始化仍重新注册并发 CORE_READY；且 initialized 在 Core 自身注册／角色刷新之前置 true | 确认缺口；R1-01 |
| F03 | Database.lua:72～96；Migrations.lua | 只检查部分顶层类型／目标戳／超前schema，缺少 characters.byID、settings等完整结构预检；Defaults 无法修复已有错误类型，迁移可在错误前部分修改存档 | 确认缺口；R1-02 |
| F04 | Bootstrap.lua:38～41；DataDomains.lua:Register | 原生事件列表固定含银行／装备／专业；已加载域不能自动形成订阅集合。仅用 pcall 记录失败不等于按目标提供能力 | 确认缺口；R1-01／04 |
| F05 | DataDomains.lua:91；DomainStore.lua:49 | Collect 正常返回 nil＋unavailable／error 时被 data or {} 转为空表，绕过 DomainStore 的 nil保留旧数据语义。抛错路径则传nil；两类失败不一致 | 确认缺口；R1-04 |
| F06 | Data/Domains/Identity、Location；Data/Fields/CharacterArchive.lua:3 | 原生采集与共享域投影混合；专业旧槽映射在共享字段中。身份的 and表达式多返回值、known／缺值语义须核对，先迁移保行为再按契约修正 | 目标边界缺口；R1-03／04 |
| F07 | ItemResolver.lua:16、48～52、97～106 | getter优先级、请求、事件、固定0～4背包枚举在共享模块；必须定义“搜索背包”在各目标的实际范围，不能未核验就标完整 | 确认固定假设；目标行为待验，R1-05 |
| F08 | Entry.lua:102～106；BusinessItemActions.lua:220～224 | 两处焦点读取策略不一致，一处只走 GetMouseFocus，一处兼容 GetMouseFoci；应集中适配。候选锚点回退仍存在，不直接判定整个悬停已坏 | 确认重复／差异；R1-06 |
| F09 | IconPicker.lua:14～23；AddonStatus.lua:6～27；ItemPicker.lua:214～223 | 原生图标枚举、现代／旧插件API签名、光标物品读取分散；统一查询／适配边界并验证返回值，失败不得伪装成功 | 待目标核验；R1-05／06 |
| F10 | CharacterCleanup.lua:6～14、30～36；Help.lua:8～31 | 清理期望owner、帮助业务说明固定，缺少目标适用性。清理不能机械只看当前已注册owner，否则丢失离线／禁用owner待重放记录 | 确认目标元数据缺口；R1-07 |
| F11 | AddonCatalog.lua:114～116、131～132 | YBP条目仅Mists，且无target时默认Mists；需要准确说明Retail现有路线与未来兽栏的不同状态 | 确认缺口；R1-07 |
| F12 | Release.Common.ps1:164～185；ReleaseProfiles.LegacyBundles | Retail版本索引不识别YBP明确登记的Mainline／默认映射；构建适配需补该边界而非改变业务加载方案 | 确认未来接入缺口；R2-02 |
| F13 | AccountView.lua:448、562；DataDomains.lua:43；CharacterCleanup.lua:123 | 页面／域／清理owner重复注册会拒绝，而Events、SettingsRegistry、Contracts有各自重入规则；不能通过让所有重复ID静默成功来统一 | 契约兼容要求；R1-08／R3 |
| F14 | AccountView.lua:1007～1025、1363～1446 | 已有secure combat状态驱动、跨服all与业务准入／预览上限。复用并测真实客户端，不为YBP另造窗口／角色库 | 保留并验证；R1-06／08／R3 |

## 5. 具体改造清单与执行顺序

下列为**R0时点的待实施清单**，保留原改造边界；当前R1-01～04已完成代码与离线验证，其余进度见文首。R2 Retail尚未开始，不把规划中的接口推定为已经存在。

| 编号／阶段 | 具体修改与文件边界 | 依赖／完成证据 |
| --- | --- | --- |
| R1-01 启动与目标策略 | Bootstrap保留Core对象／版本API；拟新增 Runtime/Lifecycle.lua 承担事件／启动，使 Mists/Target.lua、Forever/Target.lua 在生命周期前生效。Mists新增明确产品判断，Forever保持既有判断。Core:Initialize直接重复调用返回稳定结果，初始化失败不留成功就绪；检查Core自身注册结果；GUID晚到继续等待 | 最先实施；同步两TOC；错端先于写库、重复直接调用、失败／晚到、事件订阅模拟。已有版本与存档不变 |
| R1-02 存档预检与隔离 | Database／Defaults／Migrations先校验目标、存档结构和schema，再应用默认值和迁移；必要时在候选副本完成后提交，失败保留原数据。明确接受合法历史Mists无clientScope存档再写本端戳，不跨目标导入。冻结 schema11 行为基线，新schema仅在真实格式变化时决定 | 依赖01；异常嵌套、超前schema、迁移失败重试、旧角色／设置／清理历史、两端恢复与目标戳兼容 |
| R1-03 身份与原生边界 | Characters保留目录／名称／公开快照；拟新增 Runtime/Client.lua 作为内部稳定适配契约（当前不存在），由目标策略／适配实现提供实际读取。抽离身份／位置原生读取，真实GUID与legacy策略明确；identity域与投影可共享，Retail只提供首期需要的基础身份，不扩展位置／专业采集 | 依赖01／02；无GUID不建假角色、同名跨服、不按显示名关联、identityOnly复制隔离；不得更改历史身份或跨端导入 |
| R1-04 数据域与字段 | 先将 Professions／Equipment／Specialization 的Mists采集职责迁至 Mists/Professions.lua、Equipment.lua、Specialization.lua；Identity／Location拆成共享定义／投影和目标读取，避免复制全部共用实现。旧专业槽映射和字段集合按目标提供；没有域就不注册字段。修正Dispatch正常nil失败的保留语义，保留DomainStore显式{}空快照与revision契约 | 依赖01／03；同步TOC／测试／全部间接引用；旧原路径残留不可执行；Mists六槽、Forever七槽与权威flag、失败保留和真实空值分别回归 |
| R1-05 公共物品能力 | ItemResolver将物品getter、请求、事件、可搜索背包范围交给内部原生边界；共享解析／合并请求／取消／超时／重试保持。ItemPicker只消费稳定物品／光标查询。按实际客户端证据界定范围，不增加库存采集、银行或宠物采集业务 | 依赖03；两端旧调用兼容、冷缓存／取消／失败／重试、跨目标物品接口与背包范围；对应公开能力完整适配后才能声明 |
| R1-06 UI原生边界 | Client边界集中鼠标焦点、插件信息／启用、宏图标枚举、光标等实际差异；Entry和BusinessItemActions复用。Theme／AccountView仍共享，保留现有布局与secure机制，不创建三套窗口。原生模板／字体／Tooltip／StaticPopup方法以实机证据验证，稳定帧方法不逐个包装 | 依赖03／05；窄屏与安全边界、战斗进入退出、Broker实际宿主锚点、Popup取消、IME、图标重试、三通道八组合与注销 |
| R1-07 目标元数据 | AddonCatalog及帮助条目明确目标与现有功能范围；清理期望owner从明确元数据取目标集合，合并当前存档已知owner／删除历史，保持缺owner待重放。可登记YBP现有Retail路线，不宣称兽栏就绪，不修改业务插件注册或私有存档 | 依赖01／02；Mists既有目录／帮助保留，Forever过滤正确，Retail不显示无支持业务；禁用／晚注册owner重放与历史兼容 |
| R1-08 通用注册／窗口契约 | Registry／SettingsRegistry／Events／Contracts／Fields／ArchiveFields／EntryConfig／CharacterSort／Theme保留稳定实现，按三目标契约回归。明确每个注册接口重入／冲突／注销规则，调用方使用生命周期协调；不改重复页／域的现有错误语义。保留GetAllCached只读契约与性能，不无条件复制全量快照 | 贯穿01～07；R3合成消费者验证晚就绪、重复协调、冲突、注销、快照准入／同源预览、排序／范围／分页 |
| R1-09 文案与契约文档 | 为新增目标／异常／不可用提示补owner中英文稳定key；迁移与改动区同步语言服务；更新适用API、能力版本与CAP证据，不把未接入YBP写成已接入 | 随实际diff执行；语言静态报告审查及四种客户端／手动模式实机，新增路径不出现中文硬编码 |
| R2-01 Retail清单 | 新增 Retail/Target.lua、YiboCore_Retail.toc；在R1稳定原生边界上实现首期身份所需部分。拟用YiboCoreRetailDB；核对历史全局名后固定。真实build／Interface／产品常量／后缀选择先采证，默认Hint按实测值扩展 | 依赖R1；本轮R0不猜测Interface／版本／发布元数据，不把YBP旧Mainline的120007直接作为Core实测值 |
| R2-02 构建接入 | ReleaseProfiles增加Core Retail；两端迁移引用校验；Release.Common按既有LegacyBundles明确映射识别YBP Retail版本索引。源码包维持全目标集合，目标包只含所选默认TOC／必需文件／库声明／TGA，验证Data/PackagedAddonVersions生成边 | 依赖R2-01；三目标ValidateOnly与实际包检查、未登记文件过滤；版本索引仅表达源码版本，不证明业务就绪 |
| R3-01 消费者夹具与补验 | 根_NonRelease下新增合成消费者／必要探针，模拟YBP猎人且有兽栏快照的准入、跨服all、两分组时间／未知状态投影；只验证公共契约。更新实际受迁移影响的测试入口与夹具，单独处理下方旧失败 | 依赖R1／R2；不写真实宠物快照；R4真实YBP集成留业务阶段，Core本轮仍须完成自身客户端及安装证据 |

无需改动清单中的纯通用模块以制造diff；“完成适配”允许经完整审查和目标验证确认保持原实现。R1 内部原生边界不是新公开Service／Provider，不为尚无需求的目标方法创建空接口；共用相同原生实现可以复用，只有确实差异才落目标文件。

### 暂缓与保留项

- Retail 的专业、装备、专精、位置、日历采集及其它正式服专属业务暂缓；共享机制仍完整审查和适配，已支持目标实现保留。
- YBP业务采集、快照schema、页面与最低Core要求在DEV-002阶段实施；路线拥有判断及四色研究在DEV-005阶段。R0不修改现有YBP的OptionalDeps／加载例外。
- 五个退役文件保留，不删除、不重引；不会恢复货币／声望采集以满足旧夹具。
- 不预建其它业务插件的Retail适配、账号同步或服务目录；不改变第三方库、图标资产与玩家存档。

## 6. 实际离线基线与既有证据

本轮仅运行既有读取源码并使用内存合成数据的Lua检查，没有新增测试代码、运行构建器或写客户端存档。解释器为本机Lua5.1。结果原文与退出码保存在JSON的tests。

| 命令（仓库根） | 2026-10-27 实际结果 | 边界 |
| --- | --- | --- |
| `lua _NonRelease/CoreTocEntry-20261026/Verify.lua YiboCore` | 退出0，128项通过 | 两目标当前真实清单／Hint与模拟保护，不证明原生选择 |
| `lua _NonRelease/CoreForever/Smoke.lua` | 退出0，69项通过 | Mists／Forever模拟启动、目录、窗口与保存，不是Retail |
| `lua YiboCore/_NonRelease/Tests/ContractsSpec.lua` | 退出0，90项通过 | 公开Service／Provider契约 |
| `lua YiboCore/_NonRelease/Tests/CharacterNamesSpec.lua` | 退出0，77项通过 | 名称显示／排序／短名相关契约 |
| `lua YiboCore/_NonRelease/Tests/CharacterCleanupV2Spec.lua` | 退出0，43项通过 | 清理owner与延迟重放；夹具中重复加载源码不等于真实游戏TOC重载 |
| `lua YiboCore/_NonRelease/Tests/RuntimePerformanceSpec.lua` | 退出1，107行断言失败 | 位于AltoBoss原生事件模拟，timer／扫描断言；R0保留现状，未归因为Core新适配 |
| `lua _NonRelease/Localization/LocaleSpec.lua` | 退出1，56行nil索引 | 该行访问character.level字段；旧夹具启动／域加载依赖先失配，后面还假设退役money资源。不能把失败只归因于money或修改生产域迎合夹具 |

合计5组407项通过、2组失败。新R1／Retail代码尚不存在，上述不是新增适配通过。旧失败与已记录基线位置一致，实际根因与修复方案在涉及对应夹具时验证，不能静默计入通过或扩大为运行功能故障。

现有实机及发行证据见[多目标TOC记录](多目标TOC入口-实施与验收.md)和[Forever总台账](../../Docs/无限服适配与发布验收台账.md)。2026-10-26 X03／X04／X06只覆盖指定开发入口及恢复，最终包真实安装／覆盖与测试存档副本恢复仍有缺口；本次R0没有补写新的实机通过，也不改变Forever发布状态。

## 7. R0完成检查与下一阶段入口

| R0产出 | 状态／证据 |
| --- | --- |
| 全量模块与未加载旧模块 | 62路径逐项结论；53运行文件并集，无遗漏 |
| 源码及引用基线 | JSON逐文件SHA256、两端完整顺序、生成／资源边说明；所有静态条目存在且无重复 |
| 三目标能力矩阵 | 34项有效声明逐项列目标、版本、来源、消费者及Retail计划；退役currency-catalog单列 |
| 首期边界与具体改造 | R1-01～09、R2-01～02、R3-01列文件、依赖与完成证据；暂缓目标能力明确 |
| 当前测试与历史证据 | 407项离线通过、2组失败；实机旧范围与发行缺口分别引用 |
| 代码与部署 | 本次仅写审查／矩阵／基线及入口文档；运行源码和构建配置不变，未部署／未发布 |

收尾自动核对通过：62个源码／清单文件及49个附加文件的SHA256与R0基线一致，源码文件集合无增删；62条逐文件审查与34条有效能力矩阵无遗漏，146处本地文档链接存在。附加文件包含构建配置／入口、媒体、库说明及既有测试入口；此核对证明本轮未改这些文件，不代替后续运行验收。

R0已完成；R0收尾时的下一阶段为R1-01／02，当前执行进度见文首后续记录。Retail实际build、Interface、目标初始版本、最终YBP依赖能力以及原生API实测结果仍是后续实施输入，不妨碍该静态审查快照收口。

本次属于文档审查，不触发运行目录迁移或业务公共能力接入；CAP台账没有新的实现／调用进度，Forever台账无新适配或验收结论。后续按实际代码diff更新迁移单元、TOC／加载名、误目标保护、Core就绪／版本、单次初始化、存档身份、旧文件覆盖、构建引用及已验／待验范围。
