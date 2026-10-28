# R2-01／02：Retail目标与构建实施验收

日期：2026-10-27。状态：**Retail目标、存档保护与构建接入完成，适用离线回归通过，正式服源码启动和各页面已获用户确认；未发布。** 最终安装包实机覆盖、完整退出恢复、扩展旧夹具及R3后续消费者验证继续待验。

依据[R0清单](Retail-R0-共享模块审查与改造清单.md) R2-01／02、[总体方案](Retail-共享底座适配实施与验收方案.md)及[标识规范2.1](../../Docs/多版本目标与发行标识规范.md#21-多目标-toc-与运行入口规则2026-10-26)。本轮开始校验R1-09运行源摘要无差异，前阶段机器记录不改写。当前源码／工具摘要、三目标能力版本及命令结果在[Results](../../_NonRelease/CoreRetailR2/Results.json)、[TestResults](../../_NonRelease/CoreRetailR2/TestResults.json)。

## 实机前置证据与清单选择

先检查本机.build.info和Wow.exe文件版本，均为12.1.5.70575；随后由用户在正式服执行原生GetBuildInfo／产品常量查询，得到：`12.1.5 70575 Oct 22 2026 120105 1 1 zhCN`。因此采用Interface120105，不沿用YBP旧120007。磁盘版本不代替运行证据，见[Preflight](../../_NonRelease/CoreRetailR2/Preflight.json)。

七个独立无SavedVariables探针位于根_NonRelease并以同名Junction部署。用户完整重启后的自动／手动两次报告一致，各入口runs=1；进程更替也已观察。结果见[加载证据](../../_NonRelease/CoreRetailR2/Loading-Evidence.json)：

| 清单集合 | 实际选择 | API／消费者 |
| --- | --- | --- |
| 只有默认目标清单 | 默认目标，执行一次 | ready=true、init=1、consumer=1 |
| Hint默认＋_Retail | 默认Hint | loaded=true，但ready=false、init=0、consumer=0 |
| Hint默认＋_Mainline | _Mainline | ready=true、init=1、consumer=1 |
| Hint默认＋Retail／Mainline／Mists／Forever | _Mainline | 执行一次，其它产品入口未执行 |
| Hint默认＋Mists／Forever | 默认Hint | 已加载不等于业务就绪，消费者停止 |

本build识别_Mainline，不识别_Retail。保留标准`YiboCore_Retail.toc`为构建源清单，增加**字节相同**的`YiboCore_Mainline.toc`为开发实际加载名；配置明确DevelopmentToc，统一构建器拒绝别名与源内容不一致。没有复制Lua实现或增加第四产品目标。单目标玩家包仍只输出`YiboCore/YiboCore.toc`，不带Hint、Mainline别名或其它目标TOC。源码默认Hint增加已实测的120105声明，仍不声明SavedVariables或创建Core API。

## Retail职责、身份和存档

- 版本0.1.0／API13／schema11，独立SavedVariables为YiboCoreRetailDB，安装目录及技术名仍是YiboCore。仓库运行源中未发现该全局名的历史实现；部署前只检查Core存档文件是否存在，结果为0，没有读取或改写玩家WTF内容。既有其它插件联接保持原状。
- Retail/Target在写库、迁移与Core注册之前校验实际WOW_PROJECT_MAINLINE常量存在且项目ID匹配。Interface不是产品身份替代。错端、错scope、异常／超前schema停止并保留原数据；新目标拒绝非空但无clientScope的旧表，nil／空表可创建，合法Retail戳可恢复。不导入或复制Mists／Forever全局。
- requireGUID=true、legacyImports=false，不以名称／短服务器名生成替代角色ID。GUID晚到时基础设施可就绪，目录保持待观察；稍后原生事件补采，读不到时保留旧快照。Core目录不限定猎人，业务快照准入仍由YBP负责。
- Retail/Client绑定GUID、姓名、服务器、职业、等级和时间；复用共享校验和最小身份投影选项。仅注册identity域、角色身份／等级两个静态字段，目标策略在等级事件先刷新目录再投影。Mists／Forever未选择该选项，原身份／位置／专业／装备行为保持。
- 不注册Retail位置、专业、装备、专精或日历采集；不调用种族／公会等非本期目录必需读取，不以空表或零值假装提供这些能力。Retail/Fields明确适用集合；公共域、字段、动态Provider、范围、排序、入口与设置基础设施继续共享。
- Retail/Surface仅绑定原生查询与随身候选范围，复用公共实现；现代C_Item优先，秘密值／失败沿用R1边界。探针已证明GUID／姓名／服务器可读及现代Addon／Item／MouseFoci接口存在，但接口存在不代表所有操作实机验收。
- Retail元数据只有YBP既有独立路线，无兽栏能力／清理owner；其它业务不因安装或源目录存在而出现在Retail目录。宠物采集、两组快照时间、离线查看与“已拥有”仍由YBP后续版本实现。

| 目标 | 版本／Interface／存档 | 加载项／能力数 |
| --- | --- | --- |
| Mists | 1.12.9／50504／YiboCoreDB | 62／33 |
| Forever | 0.2.0／16001／YiboCoreForeverDB | 59／33 |
| Retail | 0.1.0／120105／YiboCoreRetailDB | 56／32 |

API和既有能力版本保持，三目标能力并集仍34项。Retail未声明profession-profile或calendar-day-query；不存在隐含的宠物能力。Core.Client仍为内部边界，业务通过公开契约检查就绪和所需最低能力。

## Core本体实机证据

源码以新Junction联接到正式服AddOns/YiboCore；未替换已有Core代码目录。用户按要求完整重启，`/yrt core`返回：

```text
[YiboRetailCore] loaded=true ready=true version=0.1.0 api=13 target=Retail project=1 schema=11 ownStore=true
[YiboRetailCore] characters=1 class=DRUID level=66 identity=known fields=2 repeatOK=true sameStore=true repeatedReady=0
```

用户同时确认“yco可以正常打开core窗口且各页面都正常”。这覆盖当前正式服源码的启动、独立内存存档归属、德鲁伊目录／身份、两字段、重复初始化以及中文各页基本显示；证明Core没有错误地把目录限制为猎人。当前加载字节摘要保存在[Core实机证据](../../_NonRelease/CoreRetailR2/Core-Client-Evidence.json)。不外推为英文／手动语言、战斗、边界布局、Broker宿主、落盘恢复或最终包安装通过。此前日志中的第三方UI错误提示单独保留，不归因于当时尚未安装的Core。

## 构建与离线回归

ReleaseProfiles增加Retail，明确SourceToc、DevelopmentToc、目标版本文件、Interface、Lua5.1及开发验证状态。retail／12.1.5作为发行元数据记录；平台数字版本ID与当前平台可上传范围仍须发布前查询，本轮不上传。

版本索引通过LegacyBundles显式目标／TOC映射读取YBP三个既有清单，核对声明Interface与版本一致性；Retail索引包含工作区YBP1.8，未将旧Interface120007解释成当前兼容。未声明的Forever不回退默认TOC；索引只表示源版本，不证明业务就绪。源码归档目标集合为forever-mists-retail，版本采用Bootstrap1.12.9，包含标准源清单及开发别名；玩家包只含本目标依赖、库声明、媒体与生成版本索引。

| 验证 | 已得结果 |
| --- | --- |
| Retail专项 | 115项通过：两份一致清单、中文／英文模拟、三产品错装、scope／无戳／超前／坏档、独立存档、GUID晚到／丢失、等级刷新、最小字段、页面与幂等 |
| 版本索引／三目标计划 | 11／213项通过；Mists／Forever既有计划148＋154＋16＋36项继续通过 |
| R1语言／元数据／通用契约／原生边界 | 791／389／465／192项通过 |
| 启动／身份域／TOC入口 | 334／133／149项通过 |
| 双目标Smoke／ForeverBatch／CraftingForever | 70／268／92项通过 |
| 既有Contracts／名称／清理 | 90／77／59项通过 |
| Currency控件／API13／CoreSpec；Reputation迁移 | 控件套件通过；1102／23／88项通过 |
| Goals／GoalSurfaces／BossGoals | 94／30／19项通过 |
| Lua5.1／语言静态 | 5个TOC共74文件通过；563个Core key，缺英文／格式错／重复均0；原6个AutoOpen未知key及27个Core候选不变 |

本地ZIP检查独立记在[Package-Checks](../../_NonRelease/CoreRetailR2/Package-Checks.json)：该记录保存实际产物摘要、文件集合／目标过滤／生成索引及解包后默认TOC回放结果，以实际状态判定，不用ValidateOnly代替。Retail包和三目标源码归档的本地生成不构成发布，也不构成客户端从ZIP干净安装或覆盖通过。Mists已有同名旧安装包不覆盖，本轮两旧目标采用当前源码、构建计划及消费者回归；新字节的最终包安装仍按R4验收。

扩展旧夹具仍有5组失败及1条诊断非零退出：Mail WorkspaceSpec:349阻断EntryBar／Layout；GoalSourcesSpec:156的Vault夹具缺少T方法阻断动作设置；AltoBoss定时器在RuntimePerformance:109失败；LocaleSpec:57旧字段nil。位置与R1一致，原始输出保留，不跳断言或宣称整体通过。历史TaskChain问题本轮未重跑。

## 收尾与待验

- 适用插件YiboCore；三个目标清单和实际加载名已明确登记。Mainline为Retail开发别名，玩家默认名与SavedVariables技术身份稳定；旧TOC／Lua残留不能新增执行边。三目标图及虚拟保留旧文件引用验证通过，真实覆盖仍待。
- 产品身份校验、Core提交后就绪、最低API／能力检查、单次初始化与存档预检继续有效。新增共享改动仅是显式选项和目标策略消费，既有消费者运行调用与最低Core要求未改。
- CAP-001／003／004／005／007／009／010相关公共设施已有Retail实现，证据按本页范围登记；业务接入与Core实现分开。YBP路线不被改造成Core强依赖，离线兽栏及后续“已拥有”没有被登记为已完成。
- R3真实消费者／两分组时间与未知状态、YBP业务、实际英文／手动模式、战斗／宿主／IME／边界UI、测试存档副本完整退出恢复、最终包干净／保留文件覆盖及发行检查继续待完成；不能通知可发布。
- 当前为本地main改动，未提交、未推送、未发布。独立探针及源码联接保留供复验；没有删除文件或在Lua运行时清理磁盘。
