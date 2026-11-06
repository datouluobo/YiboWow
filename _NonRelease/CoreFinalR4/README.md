# Core R4 最终包验收动态记录

2026-10-27。状态：**Retail、Mists本轮安装／覆盖／存档恢复范围通过，原联接均已恢复；Mists原始存档恢复并核对完成。Forever测试服已关闭、正式服尚未开放，实机验收等待服务器可用；R4未整体完成，未发布。**

2026-11-02 用户判断无需为 Forever 单独重复验证共用的 WoW TOC 加载机制，依据为 Retail 与 Mists 实测结果相同及此前 Forever 探针场景证据。该判断仅处理 TOC 机制测试；Forever 最终包干净安装、覆盖和存档恢复没有实机证据，仍未标记通过或可发布。

范围：Retail0.1.0／Mists1.12.9／Forever0.2.0，API13／schema11。规则与步骤见[R4方案](../../YiboCore/Docs/R4-最终包安装覆盖与存档恢复验收.md)。现有三端均为源码Junction，不能直接解压覆盖；原联接及原始存档会完整保留。

| 目标 | 干净最终包 | 保留旧文件覆盖 | reload／完整退出恢复 | 原环境恢复 |
| --- | --- | --- | --- | --- |
| Retail | 首次登录及中文各页通过 | R2→R4覆盖后加载／设置保留通过；该包对额外旧文件残留0 | 干净包reload／完整退出恢复通过 | 已恢复原联接及2份原始存档，测试结果完整保留 |
| Mists | 首次登录及/yco正常，31名角色可读 | 1.12.9／1.12.7两旧包覆盖实机通过，各3个旧文件保留 | 干净包reload／完整退出恢复通过 | 已恢复原联接及4份原始存档，3个测试目录及测试存档保留 |
| Forever | 待服务器开放 | 待验（既有0.2.0开发验收包仅作历史起点） | 待验 | 无R4部署；原测试客户端Core路径当前不存在，开放后重新核对路径／build |

## 本轮冻结包与离线证据

产物位于仓库Builds/CoreR4-20261027-3a578f2a，包含三个目标玩家ZIP及一份三目标源码ZIP，既有Builds包未覆盖、未归档或删除。源与配置摘要为 `a638f694e5bd92c252a969dd3dc0cb0809bc8e4806ce562babfb74569b2906ae`，实际ZIP路径／SHA256见[包记录](Package-Builds.json)与[检查结果](Package-Checks.json)。

- 1724项实际ZIP／默认TOC／目标过滤／逐文件哈希／保留旧文件覆盖检查通过；7个实际解包场景各34项运行与探针标记合成恢复检查通过，共238项。
- 干净包：Retail／Mists／Forever。覆盖：Mists1.12.9、Mists1.12.7、Retail R2本地验收包、Forever既有0.2.0开发验收包。每个旧包SHA和未被新包覆盖的残留文件均记录在Package-Checks，残留字节完整保留。
- 每个玩家包只含YiboCore.toc，生成版本索引实际加载；误目标停止写库；API13／schema11与三套存档身份保持。R4没有修改Core生产运行字节。
- [本轮回归](Regression.json)：30条命令24条通过，原5组失败及1条独立诊断非零退出，无新增失败。Mists／Forever启动、身份、公共契约、语言、清理、联合及消费者适用回归通过；完整输出见[TestResults](TestResults.json)。原失败仍为Mail WorkspaceSpec:349（两组）、GoalSourcesSpec:156／Vault缺T、RuntimePerformance:109、LocaleSpec:57。
- 三份构建本地化报告已审查，563key，缺英文／未知／格式错均0；27个Core硬编码候选保持原分类（26原生专业别名及双语Hint）。工作区另有6个既有AutoOpen未知key，不归入Core包通过范围。
- 全工作区SLASH注册已搜索，`/yra`、`/yrm`、`/yrf`未被占用；记录在[命令盘点](Slash-Inventory.txt)。三个目标单独探针分别位于根目录_NonRelease/YiboCoreRetailR4、YiboCoreMistsR4、YiboCoreForeverR4，TOC与目录同名，不进玩家包。

## Retail 当前步骤

无WoW进程时执行 `Manage-Client.ps1 -Mode Install -Target Retail -Case Clean-Retail`，当前AddOns/YiboCore为普通测试目录；原Junction与2份原始存档完整备份，并按字节核对后将备份复制为活动工作副本。部署位置、原联接目标、原始／备份文件SHA、实际安装文件摘要见[部署记录](Deployment-Retail.json)。未切换Mists／Forever。

用户已反馈首次登录：12.1.5.70575／Interface120105／project1／zhCN；Core0.1.0／API13／schema11，ready=true、ownStore=true、index=true／indexCount=1、repeatOK=true、repeatedReady=0；characters=1、currentIdentity=true、marker=unset、sort=recent/desc/false。用户确认`/yco`各页面正常。登记为本次实际干净包基础登录／页面通过，不外推为覆盖、存档恢复或其它语言通过，见[实机证据](Retail-Client-Evidence.json)。

用户已完成`/yra mark`→`/RL`→`/yra`：重载前后marker=true、sort=level/asc/true，ready／ownStore／index／幂等及角色数量保持，用户确认`/yco`正常。登记reload恢复通过，见[实机证据](Retail-Client-Evidence.json)。用户随后确认完整退出；等待原进程10048结束后，已核实无WoW进程，捕获4份Core／探针测试存档及bak，2份原始备份SHA均不变，见[落盘检查](Savepoint-Retail-Clean-FullExit.json)。当前引导重新启动后`/yra`和`/yco`，完整退出恢复仍须本次新进程读到marker=true后判定，不能仅以落盘文件存在作为通过。其后退出切换Overlay-Retail-R2目录，保留旧文件核验。原始存档备份不被探针修改，标记仅通过Core公开排序接口改变当前工作副本。

## 维护脚本与返回路径

### 当前收尾与继续条件

用户明确“无限测试服已关、无限正式服还没开，现在无法测试无限”。Forever实机保持待验，不安装本轮探针、不建立Deployment-Forever；读取旧测试服Core路径时该路径已不存在，R4没有创建／移动／恢复该路径。开放后先核验新客户端根目录、实际build／Interface／产品身份及目标清单选择，确认冻结验收包仍适用，再从干净安装开始；不能直接将旧测试服身份和包兼容声明外推到新正式客户端。

用户退出Mists后捕获最终6份测试存档，4份原始备份SHA不变。Restore保留干净、1.12.9覆盖、1.12.7覆盖共3个测试代码目录及测试存档；原源码Junction恢复，4份活动原始存档逐项与备份SHA一致，R4探针联接从AddOns移回保留目录。详见[最终保存点](Savepoint-Mists-Overlay1127-FinalExit.json)、[恢复核验](Restoration-Verification.json)与[Mists实机证据](Mists-Client-Evidence.json)。

同次复核Retail：原联接正确、原始备份及2个保留测试目录哈希正确；当前活动存档已不同于上次恢复点。上次恢复有[零差异证据](Handoff-Retail-Mists.json)，本次仅登记后续写入，保留当前数据，没有再次用旧备份覆盖。它不改写历史恢复通过，也不宣称本次活动Retail存档仍等于最初备份。

R4当前只完成Retail／Mists声明的安装、覆盖、恢复范围；Forever实机、既有扩展回归失败及未验语言／UI／发行边界仍按各自记录保留。未通知整插件“测试通过，待发布检查”或“可发布”；没有提交、推送、发布，也没有删除原始／测试文件。当前无需用户继续实机操作。

### Mists首次登录反馈

1.12.7覆盖实机结果：用户在指定案例重开后报告5.5.4.70579／Interface50504／project19／zhCN，Core1.12.9／API13／schema11就绪，ownStore=true、index=true／14项、repeatOK=true、repeatedReady=0，31名角色且当前身份可读，marker=true／recent/asc/true保留，YCO正常。结合79文件／3旧文件保留的安装核验，登记迁移前1.12.7→R4覆盖场景通过，见[Mists实机证据](Mists-Client-Evidence.json)。Mists本轮安装／恢复及两旧包覆盖范围已通过，原环境尚未恢复；下一步正常退出，保存最终测试存档，恢复原源码联接和4份原始存档，再准备Forever。尚未提前登记Forever实机或整个R4完成。

1.12.7覆盖部署补记：用户退出并授权切换，核实无WoW进程，捕获6份Before-Overlay-1127测试存档，4份原始备份SHA不变。Switch到独立Overlay-Mists-1.12.7案例，完整保留此前1.12.9覆盖目录；安装79文件逐项匹配，3个旧文件保留且字节不变，活动存档未改，见[安装核验](Installation-Mists-Overlay-Mists-1.12.7.json)。当前等待重开同一角色/yrm和/yco，预期31名角色、marker=true及recent/asc/true；尚未登记1.12.7覆盖实机通过。

1.12.9覆盖实机结果：用户重开后报告5.5.4.70579／Interface50504／zhCN，Core1.12.9／API13／schema11，ready／ownStore／14项包索引／repeatOK正常、重复就绪0，31名角色且当前身份可读；marker=true、recent/asc/true保持，/yco正常。结合安装时3个旧文件保留和当前加载字节核验，登记本次1.12.9→R4覆盖场景实际加载、基本页面与设置保留通过，见[Mists实机证据](Mists-Client-Evidence.json)。下一步正常完整退出，再切换独立的Overlay-Mists-1.12.7案例；尚未切换或验收1.12.7。

1.12.9覆盖部署补记：用户退出后，原WowClassic进程34692结束，核实无WoW进程。捕获6份Before-Overlay-1129测试存档，4份原始备份SHA不变，再Switch到Overlay-Mists-1.12.9，完整保留Clean-Mists目录。79个实际文件逐项匹配冻结案例，3个旧文件保留且哈希不变，只有默认YiboCore.toc，活动测试存档未修改；见[安装核验](Installation-Mists-Overlay-Mists-1.12.9.json)。当前引导重开同一角色后/yrm和/yco，预期marker=true、recent/asc/true、31名角色；尚未登记该覆盖实机通过。

完整退出恢复结果：用户重开Mists后未重复mark，报告5.5.4.70579／Interface50504／zhCN，Core1.12.9／API13／schema11就绪，独立存档／14项生成索引／幂等正常，角色31名且当前身份可读，marker=true、recent/asc/true保持，/yco正常。结合退出与落盘保存点，登记干净包完整退出恢复通过，见[Mists实机证据](Mists-Client-Evidence.json)。下一步正常退出并保持关闭，再切换Overlay-Mists-1.12.9；当前未切换旧包覆盖场景，不能将恢复结果外推为覆盖通过。

完整退出落盘补记：用户确认退出后等待原WowClassic进程36024结束，核实无WoW进程，捕获6份Core／探针测试存档及bak，4份原始备份SHA均与部署时一致。原始存档内容未执行，活动文件未改写，见[落盘保存点](Savepoint-Mists-Clean-FullExit.json)。下一步重开同一角色，仅/yrm读取已有标记，不再次mark；预期marker=true、recent/asc/true及/yco正常。完整退出恢复仍待本次新进程读回结果，落盘文件存在本身不算恢复通过。

后续reload结果：用户按mark→reload→报告操作，marker=true、sort=recent/asc/true，角色31名及当前身份可读，ready／ownStore／14项包索引／重复就绪0正常，/yco正常。登记干净包reload恢复通过，详见[Mists实机证据](Mists-Client-Evidence.json)。下一步正常完整退出并保持关闭，核对测试存档落盘与4份原始备份，再引导重开；完整退出恢复仍待。

用户报告实际5.5.4.70579／Interface50504／project19／zhCN；Core1.12.9／API13／schema11，ready=true、ownStore=true、index=true／14项、repeatOK=true、repeatedReady=0，characters=31、currentIdentity=true、marker=unset、sort=custom/desc/false，/yco正常。本次干净包登录、目录读取、基本页面及幂等检查通过，见[Mists实机证据](Mists-Client-Evidence.json)。下一步/yrm mark→/reload→/yrm，等待标记恢复结果，不提前登记完整退出或两旧包覆盖通过。当前实测build以70579为准，不沿用历史客户端build。

### Retail恢复与Mists接续

用户确认退出并授权恢复／接续后，等待Wow进程4024结束，再次核实无WoW进程。已捕获Retail覆盖场景最终4份测试存档，原始2份备份未变，见[结束保存点](Savepoint-Retail-Overlay-FinalExit.json)。Restore保留2个测试代码目录和测试存档，移回原源码Junction，并恢复2份原始存档，逐文件SHA匹配；R4探针联接移至保留目录，AddOns中不再参与加载。

随后Install Clean-Mists：Mists原Core源码联接完整保留，4份现有Core存档／bak备份并核对，活动文件为字节一致的工作副本。实际玩家包逐文件匹配冻结案例，只有默认YiboCore.toc；部署依据见[Deployment-Mists](Deployment-Mists.json)，两端恢复／安装核验见[Handoff](Handoff-Retail-Mists.json)。未改其它业务插件或Forever。

当前引导完整启动Mists，启用YiboCore与YiboCoreMistsR4，登录后`/yrm`报告及`/yco`各页／原角色设置观察。首次登录通过后再标记与reload、完整退出恢复，之后分别核验1.12.9／1.12.7旧包覆盖，最后恢复Mists原环境。Mists任何实机结果均未预填通过。

Retail覆盖实机结果：用户在切换后重开正式服，报告12.1.5.70575／Interface120105／zhCN，Core0.1.0／API13／schema11就绪，ownStore=true、index=true／1项、repeatOK=true、repeatedReady=0、角色1名且当前身份可读；marker=true／level/asc/true保持，用户确认YCO正常。登记本次R2→R4包覆盖后的默认加载、生成索引、幂等、设置保留和基本页面通过；该包对无额外残留，不能外推为其它历史TOC或非零旧路径残留通过。见[实机证据](Retail-Client-Evidence.json)。下一步正常退出，保存覆盖场景结束存档，恢复原Junction与原始存档；尚未恢复，不预填整个R4完成。

Retail覆盖目录部署补记：用户确认已退出并授权切换，原进程35552结束后核实无WoW进程。已保存4份测试存档的Before-Overlay保存点，2份原始备份SHA不变，执行Switch到Overlay-Retail-R2，完整保留此前Clean-Retail目录。安装后70个文件逐项匹配冻结案例，只有默认YiboCore.toc，活动测试存档字节未变；见[切换核验](Retail-Overlay-Switch.json)。R2旧包与新包文件集合相同，额外残留文件数为0，不把该案例记作非零旧路径残留证据；Mists代表旧包的实际残留另行验收。当前等待重新登录后/yra报告marker=true、level/asc/true及/yco正常，尚未登记覆盖实机通过。

Retail干净包完整退出恢复补记：用户在重开后未重复mark，报告marker=true、sort=level/asc/true，ready／ownStore／index及单次初始化状态正常，角色1名且当前身份可读，/yco正常。结合上一阶段无进程与落盘保存点，登记干净包完整退出恢复通过，详见[实机证据](Retail-Client-Evidence.json)。下一步要求正常退出并保持关闭，之后执行Switch到Overlay-Retail-R2；当前尚未切换覆盖目录，也未登记覆盖通过。

- [Prepare.ps1](Prepare.ps1)：统一构建并生成三个独立单目标探针；已执行一次，存在Package-Builds时拒绝重复构建。
- [CheckPackages.py](CheckPackages.py)、[PackageSpec.lua](PackageSpec.lua)：新隔离目录验证实际包与覆盖，合成环境不等于客户端恢复。部署后复验应保留既有报告，不改实际安装案例的冻结依据。
- [RunRegression.py](RunRegression.py)：本阶段日志独立保存，未改写R1／R2／R3历史报告。
- [Manage-Client.ps1](Manage-Client.ps1)：Install／Switch／Restore；每步检查WoW已退出、精确目标、普通目录／联接状态、原始备份及案例哈希。所有移动先校验路径位于明确客户端根；没有删除操作。

后续Switch只换同目标测试代码目录，保留当前存档工作副本以验证设置持续性。Restore先保留测试代码与Core／探针存档，再恢复原联接及原始存档并核对原始SHA；当前尚未执行Restore。恢复点记录在对应Deployment JSON，不能把尚未恢复写为已恢复。

本记录随步骤更新。离线回归、实际ZIP检查、部署／备份摘要与用户实机反馈分别保存，不将合成恢复或旧源码启动证据改写为实际包恢复通过。当前本地main，无提交、推送或发布。客户端剩余项和未验UI范围保持进行中。

## 2026-11-03 正式客户端安装与旧目录清理预检

2026-11-03 用户确认无限正式客户端已可安装，路径为 `C:\Program Files (x86)\World of Warcraft\_forever_`；本机读取 Wow.exe 文件版本为1.60.1.70753、flavor为wowf，AddOns当前为空。旧 `_cn_beta_` 已卸载，仅余测试备份及程序残留；四个Yibo测试目录的182份普通文件已归档并逐项SHA256校验，目录联接仅登记目标、不跟随归档，见 `_NonRelease/ClientArchives/ForeverBeta-20261103/Manifest.json`。尚未删除旧目录、部署插件或验证正式客户端运行身份。用户指出Retail／Mists已验覆盖与恢复可复用共享框架证据；后续仅补Forever正式客户端的实际差异边界，不重复已验通用场景，也不将复用证据记为Forever最终包实测通过。历史服务器不可用状态由本条更新；正式服运行及发布状态仍待。

2026-11-03 按用户授权，将YiboBuilds、YiboCore、YiboCrafting、YiboCurrency、YiboMail、YiboReputation、YiboVault七个已有Forever目标实现的源码目录，以同名Junction联接至正式客户端 `_forever_/Interface/AddOns/`；逐项核对联接目标及Forever清单存在，记录见 `_NonRelease/ClientArchives/ForeverBeta-20261103/Forever-Links.json`。未修改加载链、版本或SavedVariables，未启动游戏，不将联接完成计为正式客户端验收通过。用户已确认删除整个旧 `_cn_beta_` 并保留归档及联接目标，但删除命令被自动审批以blocked by policy拒绝，旧目录仍保留；归档SHA256核对一致。只读复查发现旧探针Junction仍存在，但其目标 `_NonRelease/YiboTocProbe` 当前不存在，为悬空联接；本次删除命令未执行，未删除任何仓库源码。

2026-11-03 用户已手动删除旧 `_cn_beta_`，本机确认该路径不存在；既有归档保留。按用户修复探针联接要求，已将 `YiboAltoBossForeverProbe`（/yaf）、`YiboBuildsForeverProbe`（/ybf）、`YiboProgressForeverProbe`（/ypg）、`YiboCoreForeverR4`（/yrf）四个现存探针以同名Junction部署至 `_forever_/Interface/AddOns/`，源为仓库 `_NonRelease/` 对应目录。逐项核对联接目标、TOC和引用文件；记录见 `_NonRelease/ClientArchives/ForeverBeta-20261103/Forever-Probe-Links.json`。未改运行代码、Slash、清单或存档，未恢复历史故障场景YiboTocProbe（源目录当前不存在），未将联接检查计作实机通过。

2026-11-05 用户报告/yrf无效；本机查明正式客户端AddOns/YiboCoreForeverR4目录缺失，仓库源码仍在，已恢复同名Junction并逐项核对TOC/Target.lua/Probe.lua与源文件SHA一致。使用真实Core清单与探针的离线环境确认命令注册、报告执行通过（GetBuildInfo为明确模拟值），未改运行代码、存档或Core联接；需要完整退出并重启正式客户端、确认启用探针后再复测。当前Core仍为源码Junction，报告index=false/0时仅说明未切换候选玩家包，不单凭此判定Core故障。不得登记本次实机通过。

## 2026-11-05 正式客户端源码诊断反馈

2026-11-05 用户截图确认/yrf已恢复有效：无限正式客户端1.60.1.70790／Interface16001／project18／zhCN，Core Forever0.2.0／API13／schema11，ready=true、ownStore=true、repeatOK=true、repeatedReady=0；角色1名、currentIdentity=true，marker=unset、recent/desc/false。当前源码Junction的index=false/indexCount=0符合部署状态，不作为运行失败或玩家包索引已验。登记G1源码诊断路径部分通过；页面、候选玩家包实际加载、语言/UI与当前保存恢复仍待，不据此判定可发布。截图及逐字段证据已保存在 `_NonRelease/CoreFirstRelease-20261104/ClientEvidence/20261105-Forever-70790-Source-yrf.*`。
