# Core R2：正式服预检与接入证据

2026-10-27。当前状态：运行build／Interface与默认／后缀选择已核验；Core Retail目标／构建已接入，用户确认源码启动和各页正常，未发布。

已核验：本机正式服`12.1.5.70575`；用户原生命令输出为`12.1.5 70575 Oct 22 2026 120105 1 1 zhCN`。Interface为120105，产品标识及MAINLINE常量均为1。磁盘／运行证据与探针源码摘要见`Preflight.json`，不把YBP旧Interface120007作为Core值。

## 一次启动的加载对照

七个独立目录位于仓库根`_NonRelease/`，以同名Junction联接到正式服`Interface/AddOns/`，见`Client-Probe-Links.json`。不访问Core、业务SavedVariables或玩家WTF。

| 探针 | 清单集合 | 记录内容 |
| --- | --- | --- |
| YiboRetailTocDefault | 默认目标入口 | 确认单目标包默认清单可执行且初始化一次 |
| YiboRetailTocRetail | Hint默认＋Retail | 实测_Retail是否识别 |
| YiboRetailTocMainline | Hint默认＋Mainline | 实测_Mainline是否识别 |
| YiboRetailTocBoth | Hint默认＋Retail／Mainline／Mists／Forever | 实测同存优先级与其它产品排除 |
| YiboRetailTocMissing | Hint默认＋Mists／Forever | 实测无正式服候选时只进入Hint且不就绪 |
| YiboRetailTocConsumer | RequiredDeps指向以上五个 | 区分已加载／依赖满足和业务就绪，各场景独立gate |
| YiboRetailTocObserver | 默认诊断入口 | 登录及三字母`/yrt`报告实际build、所选源清单、运行／初始化次数和原生身份读取可用性 |

新增TOC后完整退出并重启，确认七个探针启用，登录后输入`/yrt`。只看到插件列表或执行reload不能证明新TOC选择。实际结果为Mainline生效、Retail后缀不识别、缺目标Hint停止；原始结果在Loading-Evidence.json。进入游戏前已有的第三方插件错误与本次探针证据分别记录。

`Prepare-Probes.ps1 -Interface 120105`已执行；现有目录再次执行会停止，避免覆盖。`ProbeTemplates/`仅为生成模板，不直接部署；所有源清单及Lua摘要在Preflight中固定。没有运行时删文件、故意Lua错误或业务数据写入。

## 不依赖后缀结果的构建准备

`Tools/Release.Common.ps1`通过LegacyBundles显式目标／TOC映射取得YBP版本索引，核对既有声明的Interface及全部TOC版本一致性。Retail查询不依赖尚未登记的Core Interface，也不按TOC文件名猜测；它记录源版本，不证明YBP可在当前客户端运行。未声明Forever的包不会回退其默认TOC。

`VersionIndexSpec.ps1`的11项验证、Mists／Forever统一构建及既有70项双端、268项联合、334项启动回归输出保存在`Index-Checks.json`。这是接入前的独立构建索引历史结果，不能代替后续Core／包验收。

当前Core-Client-Evidence.json记录Core本体实机及加载字节，Core-Client-Link.json记录新Core联接与旧存档存在性检查（0个）。RunChecks.py／TestResults.json／Results.json为三目标回归、能力和摘要；Package-Checks.json为实际本地ZIP与解包回放结果。/yrt core用于Core就绪／归属／重复调用诊断，/yco仍是正式窗口入口。最终包客户端覆盖、完整退出恢复与R3后续仍待；没有发布。

本地包已完成83项ZIP检查和12项实际解包默认TOC回放；AliasSpec另以隔离夹具确认构建器拒绝开发清单漂移。现有正式服YBP联接仍指向E:/Program/YiboBeastPaths，该目标目录不存在；本轮没有改动该既有联接，不将Core测试当作YBP已加载／集成。
