# Core R5：文档与验收台账收尾

日期：2026-10-27。**R5文档与台账收尾完成。Retail／Mists仅本次明确的安装、覆盖和存档恢复范围实机通过；Forever保留待测。R4未整体完成，整体未判定可发布，未发布。** R5本身不增加功能，不改变API／能力版本或构建配置，不生成新包；期间按用户追加授权独立完成误删文件恢复与正式服YBP联接修复，存档未改动。

## 证据范围与工作区状态

本页以[R4冻结包及动态记录](../_NonRelease/CoreFinalR4/README.md)、[阶段状态](../_NonRelease/CoreFinalR4/Stage-Status.json)、两端用户报告和离线结果为依据。它不把旧版本验收、离线模拟或目录中存在文件替代客户端证据。

R5启动时发现15个插件目标目录被清空。用户说明刚卸载无限测试服并授权恢复；两端联接指向同一仓库，现象符合卸载沿联接影响源码，但没有卸载器内部日志，不断言具体删除实现。已从仍可读取的Git工作树对象补回未提交目标与测试文件，Core公开源码从R4冻结源码包恢复并验证完整输入摘要；15插件语法与适用回归复验通过，原5组失败及1条诊断保留，无新增失败。正式服YBP既有悬空联接已完整保留并改接恢复后的仓库；没有读写玩家SavedVariables。恢复过程、来源及限制见[恢复记录](../_NonRelease/Recovery-20261027/README.md)。R4历史机器证据及冻结ZIP保持原样，源码恢复不生成新的实机通过结论。

## 目标与已验边界

| 项目 | Retail | Mists | Forever |
| --- | --- | --- | --- |
| 验收包版本 | 0.1.0／API13／schema11 | 1.12.9／API13／schema11 | 0.2.0／API13／schema11，离线冻结快照 |
| 客户端证据 | 12.1.5.70575／Interface120105／project1／zhCN | 5.5.4.70579／Interface50504／project19／zhCN | 本轮无R4实机；旧测试服记录不外推新正式服 |
| 最终包干净安装 | 用户确认就绪、独立存档、生成索引、幂等及/yco基本页面 | 同左；31名角色与当前身份可读 | 待测 |
| 旧包覆盖 | R2开发验收包→R4，70文件；该包对额外残留0，覆盖后设置／标记保留 | 旧1.12.9及迁移前1.12.7→R4，两案例各79文件、3个旧文件原样保留；覆盖后加载与设置保留 | 既有0.2.0开发验收包覆盖仅离线通过，实机待测 |
| reload恢复 | marker=true、level/asc/true，角色1名，/yco正常 | marker=true、recent/asc/true，角色31名，/yco正常 | 待测 |
| 完整退出恢复 | 无进程、落盘保存点及重开读回标记，用户确认/yco正常 | 同左，31名角色与排序标记保留 | 待测 |
| 结束环境恢复 | 原源码Junction及2份原始存档曾逐项核对；后续活动存档有新写入，本轮保留现值 | 原源码Junction及4份原始存档恢复，SHA一致；3个测试目录及测试存档保留 | 无R4部署；原测试客户端Core路径当前不存在 |

原始证据：[Retail实机](../_NonRelease/CoreFinalR4/Retail-Client-Evidence.json)、[Mists实机](../_NonRelease/CoreFinalR4/Mists-Client-Evidence.json)、[恢复核验](../_NonRelease/CoreFinalR4/Restoration-Verification.json)。Retail后续写入已明确区分恢复当时与后续审计结果，没有再次用旧备份覆盖现有数据。

本次“通过”不扩大到英文／手动语言客户端、战斗、Broker宿主、IME、全部边界布局、所有历史包起点或第三方更新工具。R1～R3未闭环项继续按原记录保留，不能将/yco正常解释为全部UI完成。

## API、能力矩阵与所有权收尾基线

R3固定API13及12项既有能力：runtime:1、events:1、characters:1、character-identity:1、character-name-format:1、character-cleanup:2、account-view:2、account-character-admission:1、account-surface-budget:2、account-entry:2、builtin-entry-bar:3、localization:1。消费方还需校验实际使用的方法；“已加载”、Interface匹配或版本字符串不代替Core就绪与能力门槛。

R3冻结源码声明Mists33项、Forever33项、Retail32项，并集34项；Retail仅提供最小角色identity域及身份／等级字段，不宣称提供专业、日历、装备、位置或宠物采集。三目标合成消费者2463项通过，证明本阶段公共契约，不是YBP真实业务集成，也不增加YBP的Forever支持集合。

| 稳定台账编号 | Core已提供／已验公共支持 | YBP实际接入状态 |
| --- | --- | --- |
| CAP-001 | 统一短名／服务器显示，显示文本不作身份键 | 既有路线范围不适用；离线兽栏待接入 |
| CAP-004 | 页面准入、跨服范围、排序、窗口／预览同源、预算、页面托管设置、三通道入口及生命周期 | 既有维护页范围保留；离线兽栏页面／入口／设置待接入 |
| CAP-007 | GUID与轻量身份副本；Core目录不限定猎人 | 离线兽栏跨角色查询待接入 |
| CAP-009 | owner中英文资源与统一会话语言 | 既有维护区域范围保留；真实兽栏状态／时间／依赖提示待接入 |
| CAP-010 | 单次owner、影响未知、失败pending与带时间上下文的延后清理 | 实际YBP尚未登记兽栏清理owner |

Core不读取YBP内部对象／SavedVariables，不保存宠物快照、不判定拥有。YBP拥有采集、schema、快照、准入与时效：随身／兽栏分别记录成功采集时间和状态，失败保留历史，不当作空栏；无成功兽栏快照的角色不展示，跨服同名按GUID分离。普通预览沿用默认最多20名，同源投影不产生第二权威存档。当前只是公共支持冻结，不提高现有YBP最低依赖、不将独立路线变为Core强依赖。

DEV-002仍为下一版YBP离线查看，真实Retail／Mists宠物API采证、扫描完整性、跨组移动、提交／迁移、依赖提示、晚加载、页面控件及业务存档恢复待实施。DEV-005仍为再下一版路线“已拥有”；缺失／陈旧／部分证据保留未知，不由Core推定未拥有。

## 加载与构建收尾基线

- 冻结清单：Mists用YiboCore_Mists.toc，Forever用YiboCore_Forever.toc，Retail标准源YiboCore_Retail.toc与开发加载名YiboCore_Mainline.toc字节相同。Retail12.1.5.70575已实测_Mainline可识别、_Retail不被选用。
- 源码默认YiboCore.toc只作Hint；每个目标玩家包仅默认YiboCore.toc及本目标文件，均实际加载生成版本索引。不能向源码Junction解压，源码归档不能当玩家旧包升级起点。
- 产品身份和存档预检在业务写库前执行，误目标／异常／超前存档保护离线验证通过；当前两端实际正常路径及重复初始化不重发就绪已验。真实YBP仍须自行校验目标、Core就绪、最低API及能力。
- 稳定SavedVariables分别为YiboCoreDB、YiboCoreForeverDB、YiboCoreRetailDB；此次未跨目标导入或重置。纯文档收尾不触发运行代码迁移。
- R4实际ZIP／保留旧文件检查1724项、7个解包场景238项通过；三目标构建已按当时输入校验。冻结源码及配置摘要为 `a638f694e5bd92c252a969dd3dc0cb0809bc8e4806ce562babfb74569b2906ae`，产物位于Builds/CoreR4-20261027-3a578f2a，详见[包清单](../_NonRelease/CoreFinalR4/Package-Builds.json)及[实际包检查](../_NonRelease/CoreFinalR4/Package-Checks.json)。本轮不重打包，文档更新不改写旧ZIP摘要或实机证据。

## Forever待验及继续条件

用户确认无限测试服已关闭、正式服尚未开放。Forever本次没有部署测试包／探针，没有R4客户端证据。待客户端可用后按顺序继续：

1. 重新确认客户端根目录、原联接与WTF身份，核验实际build、Interface、产品ID和TOC选择；评估0.2.0冻结载荷是否仍适用，不以旧测试服目录或旧加载行为外推。
2. 无游戏进程时备份原始代码／存档，建立独立普通测试目录与存档工作副本。
3. 实际单目标包干净安装，核对就绪、最低API／能力、独立存档、生成索引、幂等、既有角色与页面。
4. 标记→reload→读取，再完整退出／校验落盘→重开读取，分别登记恢复证据。
5. 对明确声明且适用的开发载荷升级起点做保留旧文件覆盖，记录残留路径／加载来源；新正式服若需适配先改造并重新验证，不套用旧包通过结论。
6. 保留测试结果并恢复原环境，核对原始存档与联接。完成后再决定相关未验项及发行检查，不自动判定可发布。

## 发布门槛与未完成项

R4本轮30条回归命令24条通过；原5组失败加1条独立诊断仍为非零退出，无新增失败。EntryBar／Layout均止于Mail WorkspaceSpec:349，ItemActionSettings止于GoalSourcesSpec:156（诊断为Vault夹具缺T），RuntimePerformance:109定时器断言，LocaleSpec:57旧字段nil；不跳过断言，不记录整体测试全绿。见[回归记录](../_NonRelease/CoreFinalR4/Regression.json)。

Forever实机、未验语言／UI范围、上述旧夹具问题、平台版本ID、渠道及适用更新工具／覆盖发行检查均保留。用户已明确不发布：不通知整体“测试通过，待发布检查”或“可发布”，不创建发行、不上传、不提交或推送。原已发布版本的历史状态不被本轮文档改写。

R5文档收尾与R4实机闭环分别记录。已同步Core方案、README、API13支持契约、R0能力矩阵／改造清单当前索引、CAP台账、目标与构建说明、根目录总览／任务／Forever台账及YBP版本任务。历史R0～R4测试结果和基线不改写。范围、方法与版本以冻结证据为准，后续代码或客户端变化须重新确定受影响验证。
