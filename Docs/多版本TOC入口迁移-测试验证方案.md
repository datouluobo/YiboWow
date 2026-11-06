# 多版本 TOC 入口迁移测试验证方案

2026-11-02 当前收尾：Retail `_Mainline` 清单选择规则及本方案覆盖的 TOC 探针入口选择、默认提示、目标缺失、失败停止和保留旧文件覆盖场景已有验收记录；探针源码已从活动目录移至 `_NonRelease/_ManualDelete-2026-11-02/CompletedTocProbes/`，本文件的测试结论与截图引用保留。用户判断不需要再为 Forever 重复验证共用的 WoW TOC 加载机制，因为 Retail 与 Mists 实测结果一致，且此前已有 Forever 探针场景证据。最终玩家包验收是另一范围：Retail 与 Mists 的干净安装、覆盖和恢复已通过；Forever 最终包安装／覆盖／存档恢复未实测，不记为通过，见 `_NonRelease/CoreFinalR4/README.md`。下文按日期记录历史步骤，较早的“待测”状态以之后反馈和收尾记录为准。

2026-10-26 用户补充“两客户端都测试了，正常”：登记MoP与Forever本轮用户实机反馈正常，复用已验范围，不安排重复操作。反馈未单列安装载荷路径／哈希、旧包升级起点及是否使用测试存档副本，因此不据此补写这些未明确的证据，也不扩大为整插件可发布。TOC与运行入口规则已归纳到[标识规范2.1节](多版本目标与发行标识规范.md#21-多目标-toc-与运行入口规则2026-10-26)。

2026-10-26 第3项离线部分：Core Mists1.12.9／Forever0.2.0（API13）两个单目标待验收包及全目标源码归档已生成；1,084项归档／覆盖加载图与676项实际解包运行模拟通过。未部署客户端、未发布，现有源码联接不变。最终包真实客户端覆盖与测试存档副本恢复仍待验，保持发行阻断；不重复已验开发候选启动／reload或旧TOC探针。详见[最终包检查记录](../_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/README.md)。

2026-10-26 当前进展：用户选择的第1项已落地，正式 Core 三 TOC 源码及双目标构建配置接入完成。Mists1.12.9／Forever0.2.0／API13、存档名与 schema 保持原状；53个既有运行Lua及两个目标清单、Hint与已验候选字节一致，复用X03／X04／X06证据，不重复实机。离线构建与验证明细见[源码接入记录](../YiboCore/Docs/多目标TOC入口-实施与验收.md)。两端客户端仍使用独立候选普通目录，原源码联接备份保留；Vault、旧TOC探针及WTF未改。正式目标包与发布检查尚未执行；无限业务及其它探针继续暂停。下方历史阶段描述按原日期理解。

日期：2026-10-20。状态：**方案已记录，全部测试待执行**。本文件不构成客户端行为或发布兼容性已通过的证据。

## 1. 目的与范围

验证从只有默认 `YiboCore.toc` 的旧版，迁移到客户端原生多 TOC 时，如何通过同路径覆盖消除旧默认入口的影响，并保证源码直接联接与安装包使用均有正确的加载入口。

本轮先使用独立探针验证机制，不修改正式 Core、业务插件或玩家存档。覆盖 MoP 与 Forever 两端；新增第三个客户端时按同一方案补充验证。

需要取得实机证据的问题：

1. 两端认可哪些目标 TOC 后缀，目标清单与默认清单的选择优先级是什么？
2. 默认 TOC 为零字节、只有元数据或最小提示入口时，插件列表、可加载状态和执行结果分别是什么？
3. 默认入口被选中后，是否还会执行其他目标 TOC？目标代码执行失败时是否重新选择清单？
4. 保留旧文件的覆盖更新能否阻止旧实现执行？
5. 默认空入口或提示入口是否仍被判为已加载，依赖它的消费插件如何安全停止？

开发与发布约束分别见[多版本开发规则](多版本开发规则.md)及[覆盖更新与升级验收](../发布包约定.md#覆盖更新与升级验收)。

## 2. 环境与探针

执行前核对[无限服适配与发布验收台账](无限服适配与发布验收台账.md)。记录两端本次实际客户端构建、Interface、产品标识、语言、插件启用状态与是否允许加载过期插件；不能只沿用历史记录。正常加载验收不得依赖“加载过期插件”；如需诊断须单列该配置及结果。

按项目非发布探针约定准备独立目录，目录名与默认 TOC 文件名一致：

| 路径 | 职责 |
| --- | --- |
| `_NonRelease/YiboTocProbe/` | 被测插件，准备默认、目标和旧版入口场景 |
| `_NonRelease/YiboTocObserver/` | 独立观察器，不依赖探针；空探针无法执行代码时仍可报告状态 |
| `_NonRelease/YiboTocConsumer/` | 测试消费插件，声明依赖探针，验证依赖满足与公共 API 就绪的差别 |

需要运行时，按同名目录联接到指定测试客户端 `Interface/AddOns/`。记录联接目标，避免对正式插件目录或其它客户端执行覆盖。各场景使用明确的清单文件集合，切换后核对目录实况，防止上一场景残留目标 TOC 污染结果。实际删除或移动探针源文件仍按项目删除策略执行。

探针不依赖或创建真实 `YiboCore` 对象，不声明真实插件的 SavedVariables，不读取、导入或修改玩家业务存档。提示及测试控件按适用的项目语言约定实现。需要 Slash 命令时，实施前全工作区搜索注册情况并选择未占用的三字母命令；本文不预留命令。

## 3. 观察方式

每份非空 TOC 使用不同的 `X-Probe-Entry` 元数据。入口 Lua 分别记录 `default`、`mists`、`forever`、`legacy` 的执行标记和次数；正式模拟业务入口另外提供探针自身的 API 就绪标记。每次完整启动计数从零开始。

观察器按客户端实际可用 API 读取探针元数据、可加载状态与原因、已加载状态，在登录完成后输出入口执行次数、就绪标记及错误证据。错误证据须保留首条 Lua 错误；不能仅以聊天区没有报错作为通过依据。

TOC 文件名没有直接可用的查询接口时，用唯一元数据与执行标记交叉判断，并记录推断依据。零字节清单没有自定义元数据，须结合“仅存在默认 TOC”的对照场景、目录实况及客户端状态判定；不能把元数据为空直接判为未发现插件。

**修改 TOC、增删候选清单或切换覆盖场景后，完整退出游戏再启动。仅 `/reload` 不计为清单重新发现和选择的验证。**

## 4. A 组：清单识别与优先级

两端分别执行。候选后缀逐个测试；仓库内部目标名 `Forever` 不自动等于客户端识别的后缀。尚未确认的文件名只作为候选，不写入正式兼容结论。

| 编号 | 场景 | 观察与通过标准 | 状态 |
| --- | --- | --- | --- |
| A1 | 只有正常默认 TOC | 默认入口执行一次，观察器能识别插件及元数据，建立基线 | 待执行 |
| A2 | 默认 TOC 加一个候选目标 TOC | 逐个记录后缀是否认可；确认目标与默认谁被选择，不提前要求候选成功 | 待执行 |
| A3 | 默认 TOC 加两端各自已确认的目标 TOC | 每端正确目标入口执行一次，默认与另一目标入口均执行零次 | 待执行 |
| A4 | 默认 TOC 加仅适用于另一客户端的目标 TOC | 记录是否回退默认；另一目标实现不得执行 | 待执行 |

A3 不通过时，先处理命名或选择规则，不进入正式入口迁移。若多个候选后缀均被识别，补测共存优先级，确定唯一正式命名及历史入口处理方式。

## 5. B 组：空默认 TOC 与提示入口

分别准备：零字节默认 TOC；保留合法元数据但不列 Lua/XML 的默认 TOC；合法元数据加最小提示 Lua 的默认 TOC。后两种使用当前两端适用的 Interface 声明，提示入口不提供业务 API、不初始化业务数据库。

| 编号 | 默认 TOC 内容 | 正确目标 TOC 存在 | 正确目标 TOC 不存在 | 状态 |
| --- | --- | --- | --- | --- |
| B1 | 零字节 | 记录是否仍正确选择目标 | 记录列表显示、可加载原因、已加载状态和错误，不预设零字节被视作无效或禁用 | 待执行 |
| B2 | 只有合法元数据 | 正确目标执行一次，其他入口零次 | 确认是否加载为空插件；业务执行零次 | 待执行 |
| B3 | 最小提示入口 | 正确目标执行一次，提示零次 | 提示执行一次，全部业务入口零次，无非预期 Lua 错误 | 待执行 |

B3 缺少正确目标清单时，可保留另一客户端清单作对照，确认默认提示执行后是否还会加载它。出现跨目标执行应阻断当前方案。

### B4：执行失败是否重新选择清单

保留已确认有效的目标 TOC，让其入口在留下标记后故意抛出明确的测试错误；默认入口保留独立标记。记录目标、默认及其他目标执行次数、原始错误和已加载状态。故意制造的错误单独登记，不作为非预期错误。

本用例用于观察失败后的真实行为，与“没有找到目标 TOC”分开记录。无论是否出现回退，正式方案都不得依赖代码报错来完成目标路由。

## 6. C 组：保留旧文件的覆盖更新

在独立测试安装目录中准备可复现的旧版和新版文件集合，记录版本标识与文件清单；探针联接不能指向正式源码后再被当作解压覆盖目标。

1. 安装模拟旧版：只有默认 TOC，引用 `Legacy.lua`。完整启动，确认旧入口执行一次。
2. 完整退出后覆盖新版：新版同路径默认 TOC、已确认的目标 TOC及目标实现。
3. 保留旧 `Legacy.lua` 和其他历史文件，不先清空目录；记录覆盖前后清单及默认 TOC 内容摘要。
4. 两端分别完整启动，核对正确目标、默认及旧入口的执行次数。
5. 在独立场景中模拟漏装正确目标 TOC，再验证默认空入口或提示入口的真实行为。
6. 对通过选择的方案补测：完整退出再启动及 `/reload` 后，入口仍无重复注册或混用。

通过标准：默认 TOC 已被新内容替换；正常场景正确目标入口一次、其他入口零次；旧文件虽然存在但没有执行；缺目标清单时不运行旧业务或另一目标业务；提示方案有准确提示。各次启动和重载分别计算次数，不能把跨会话累计误判为重复执行。

如历史版本曾分发其它客户端认可的 TOC 名称，须增加对应残留场景并记录其选择优先级；仅验证旧默认 TOC不足以覆盖这些升级路径。

## 7. D 组：依赖与 API 就绪

消费插件通过 `RequiredDeps` 依赖探针，业务初始化前检查探针自身 API 和就绪状态；不调用真实 Core。按实际依赖机制实现，并在日志中区分“文件已加载”和“业务已初始化”。

| 编号 | 探针最终入口 | 观察与通过标准 | 状态 |
| --- | --- | --- | --- |
| D1 | 正常目标入口 | 就绪后消费方初始化一次 | 待执行 |
| D2 | 元数据空入口 | 记录原生依赖是否满足、消费方是否被加载；消费业务保持停止且提示明确 | 待执行 |
| D3 | 提示入口 | 同 D2；不把探针已加载误判为 API 可用 | 待执行 |
| D4 | B4 的故意失败入口 | 记录原生依赖结果；消费方不得在缺失／未就绪 API 上继续业务操作 | 待执行 |

若需要展示仅检查原生依赖的风险，使用受控诊断记录，避免为取证修改正式业务插件。

## 8. 结果与证据表

每个用例两端分别填写，组合场景增加行，不用单个截图外推整组通过。

| 用例／变体 | 客户端构建／Interface | 场景文件清单／摘要 | 元数据／选中入口依据 | 执行次数／就绪 | 列表／可加载／已加载 | 错误／截图／报告 | 结论／日期 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 待填写 | 待填写 | 待填写 | 待填写 | 待填写 | 待填写 | 待填写 | 待执行 |

### MoP 当前截图记录（2026-10-20）

| 用例／变体 | 客户端构建／Interface | 场景文件清单／摘要 | 元数据／选中入口依据 | 执行次数／就绪 | 列表／可加载／已加载 | 错误／截图／报告 | 结论／日期 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MoP 多候选启动观察 | 客户端构建待补；当前候选 TOC 声明 Interface 50504 | 截图显示探针、观察器、消费方已启用；精确 TOC 文件清单待现场核对 | 插件列表标题显示 Mists candidate；观察器返回 `info=YiboTocProbe` | `default=0,mists=1,forever=0,legacy=0,error=0`；`apiReady=true`、`apiEntry=mists`、`init=1` | `loaded=true`；“加载过期插件”勾选 | 用户提供的插件列表与 `/ytp` 输出截图；本截图未显示错误记录 | Mists 候选本次被选择；完整 A 组待执行。因过期插件开关已勾选，正常加载验收待在关闭该选项后复核；Consumer 初始化输出待单独取证。 |

本记录只反映截图中的一次 MoP 会话，不代表构建信息已核实，也不外推为其他候选、空入口、覆盖更新或无限服通过。下一步先记录客户端构建并关闭“加载过期插件”，重启后用 `/ytp` 复核本场景；再按 A1 单默认清单建立基线。测试清单每次切换都须完整退出客户端。

### MoP 过期插件选项复核（2026-10-20）

用户补充的插件列表截图显示“加载过期插件”未勾选；同组提示框显示 RS 检测到该选项未开启并提示重载后生效。随附 `/ytp` 截图仍为 `mists=1`、`apiReady=true`、`init=1`，但无法确认它是在选项应用前还是应用后取得，因此不作为关闭选项后的有效重启证据。结论：设置已改为关闭，生效状态待完整退出客户端后重新启动复核。下一步完整退出并重启 MoP，再输入 `/ytp`；保存新输出和插件列表截图后，才记录为普通加载条件下的结果。

用户随后提供了新的 MoP `/ytp` 输出：`loaded=true`、`mists=1`、其它入口均为 0、`apiReady=true`、`apiEntry=mists`、`init=1`。按前述重启要求，将其记录为关闭“加载过期插件”后的再次启动结果；截图中的插件列表已显示该选项未勾选。当前证据确认 Mists 候选在本次启动被选择且探针 API 就绪；客户端构建、准确 TOC 共存清单和 Consumer 输出仍待补齐，因此不据此判定 A 组或 D1 全部完成。

用户随后按 A1 暂时移出三个目标候选 TOC，并提供 MoP 输出：`loaded=true`、`default=1`，`mists=0`、`forever=0`、`legacy=0`、`error=0`，`apiReady=nil`、`apiEntry=none`、`init=0`。日志进一步显示消费方输出 `loaded-without-ready-api; business-stopped`，说明探针被原生依赖判定为已加载时，消费方仍根据 API 未就绪停止业务初始化。客户端日志识别为 MoP Classic 5.6.4、Build 70469；Interface 50504。记录为 **A1 默认入口基线行为通过**，并记录 API 未就绪停止行为已验证；该清单实际执行了 `Probe.lua`，不等同于 D2 的纯元数据空入口场景。测试结束后须将三个候选 TOC 放回原目录，再进入下一场景。

### MoP A2：仅默认与 Mists 候选（2026-10-20）

用户按单候选场景提供启动日志：`loaded=true`、`default=0`、`mists=1`，其余 `forever=0`、`legacy=0`、`error=0`，`apiReady=true`、`apiEntry=mists`、`init=1`；消费方输出 `initialized`。依据本轮执行步骤，清单集合为默认 TOC 与 Mists 候选。记录为 **A2 Mists 变体通过**：MoP 选择目标候选，默认及未参与的目标入口未执行，消费方在 API 就绪后初始化一次。测试构建沿用本轮日志识别的 MoP Classic 5.6.4、Build 70469、Interface 50504。A2 的其它候选及 A3 共存优先级仍待测试。

### MoP A4：默认与另一客户端 Forever 候选（2026-10-20）

用户首次提供的入口计数为 `loaded=true`、`default=1`、`forever=0`、`mists=0`、`legacy=0`、`error=0`、`apiReady=nil`；消费方输出 `loaded-without-ready-api; business-stopped`。插件列表截图显示条目标题为 `YiboTocProbe (default...)`，且“加载过期插件”勾选。对工作区探针目录的核对确认当时仅有 `YiboTocProbe.toc` 与 `YiboTocProbe_Forever.toc`；后者声明 Interface 16001，属于另一客户端候选。用户随后说明完整退出、关闭“加载过期插件”并重新测试；新日志仍为 `default=1`、`forever=0`、其它入口均为 0、`apiReady=nil`，消费方安全停止。按复测步骤，文件集合仍为默认 TOC 与 Forever 候选。记录为 **A4 通过（MoP Classic 5.6.4、Build 70469、Interface 50504；过期插件关闭）**：MoP 执行默认入口，没有执行另一客户端实现。此结果不区分 Forever 后缀未识别与 Interface 不兼容过滤；两个原因都不会让 MoP 执行 Forever 入口。

### MoP A3：默认与两端目标 TOC 共存（2026-10-21）

用户按 A3 步骤提供 MoP 启动日志，场景集合为默认、Mists 与 Forever TOC，Legacy 候选移出；日志为 `loaded=true`、`default=0`、`mists=1`、`forever=0`、`legacy=0`、`error=0`、`apiReady=true`、`apiEntry=mists`、`init=1`，消费方输出 `initialized`。记录为 **A3 通过**：MoP 选择 Mists 目标入口一次，默认入口及另一客户端 Forever 入口均未执行，消费方初始化一次。客户端为 MoP Classic 5.6.4、Build 70469、Interface 50504；按步骤关闭“加载过期插件”并完整重启。

### MoP B1：零字节默认 TOC，目标 TOC 存在（2026-10-21）

在收到新日志后核对探针源目录文件清单：`YiboTocProbe.toc` 为 0 字节，`YiboTocProbe_Mists.toc` 为 115 字节，其它目标 TOC 当前不在目录中。启动日志为 `loaded=true`、`default=0`、`mists=1`、其它入口均为 0、`apiReady=true`、`apiEntry=mists`、`init=1`，消费方输出 `initialized`。记录为 **B1（正确目标存在）通过**：零字节默认文件存在时，MoP 仍选择 Mists 目标入口，目标 API 与依赖消费方正常就绪。客户端为 MoP Classic 5.6.4、Build 70469、Interface 50504。正确目标缺失的 B1 变体仍待执行。

### MoP B1：零字节默认 TOC，目标 TOC 缺失（2026-10-21）

用户在角色选择界面报告插件列表看不到探针。探针源目录核对为仅 `YiboTocProbe.toc` 存在且为 0 字节，没有任何目标 TOC。随后 Observer 输出 `info=YiboTocProbe loaded=false`，所有入口计数为 0，API 未就绪；聊天记录没有 Consumer 初始化输出，用户补充确认 Consumer 未加载。记录为 **B1（正确目标缺失）通过：零字节默认清单未执行任何入口，依赖消费方未加载**。客户端通过 AddOnInfo API 可查到插件名，但运行时未加载；玩家报告插件列表中看不到探针，说明列表可见性与 API 枚举结果不同。未观察到探针相关 Lua 错误。客户端为 MoP Classic 5.6.4、Build 70469、Interface 50504。

### MoP B2：仅元数据默认 TOC，目标 TOC 存在（2026-10-21）

按本轮场景核对，当前清单集合只有 `YiboTocProbe.toc`（元数据模板，119 字节）与 `YiboTocProbe_Mists.toc`；默认清单不加载 Lua/XML。用户提供的启动日志为 `loaded=true`、`default=0`、`mists=1`、其余入口均为 0、`apiReady=true`、`apiEntry=mists`、`init=1`，Consumer 输出 `initialized`。记录为 **B2（正确目标存在）通过**：元数据默认入口与 Mists 目标共存时，Mists 入口被选择并就绪，消费方初始化一次。客户端为 MoP Classic 5.6.4、Build 70469、Interface 50504。正确目标缺失变体仍待执行。

用户随后移出 Mists 候选，核对当前仅有 `YiboTocProbe.toc` 元数据入口（119 字节）。启动日志为 `loaded=true`、所有入口次数为 0、`apiReady=nil`、`apiEntry=none`、`init=0`；Consumer 输出 `loaded-without-ready-api; business-stopped`。记录为 **B2（正确目标缺失）通过**：元数据清单使插件被原生状态视为已加载，`RequiredDeps` 消费方随之加载，但依赖 API 未就绪时停止业务初始化。该结果同时验证 **D2（MoP）通过**。客户端为 MoP Classic 5.6.4、Build 70469、Interface 50504。

### MoP B3：提示默认入口，目标 TOC 缺失（2026-10-21）

用户提供日志显示提示入口输出 `Target TOC was not selected; this is a hint-only default entry.` 一次；Observer 显示 `info=YiboTocProbe loaded=true`、所有业务入口计数为 0、`apiReady=nil`；Consumer 输出 `loaded-without-ready-api; business-stopped`。当前探针目录核对为仅默认 TOC 存在。记录为 **B3（目标缺失）通过**：提示入口执行一次，不提供业务 API，消费方安全停止。日志片段未显示探针 Lua 错误。之后已将提示文本改为按客户端语言显示中/英文，供后续场景使用；该文案调整不改变本轮已观察的入口和依赖行为。客户端为 MoP Classic 5.6.4、Build 70469、Interface 50504。

### MoP B3：提示默认入口，目标 TOC 存在（2026-10-22）

当前清单核对为默认提示 TOC（`YiboTocProbe.toc`）与 Mists 目标 TOC；Forever、Legacy 不在探针目录。用户提供的 MoP Classic 5.6.4 启动日志显示 Build 70531、Interface 50504，入口计数为 `default=0`、`mists=1`、`forever=0`、`legacy=0`、`error=0`，`apiReady=true`、`apiEntry=mists`、`init=1`；Consumer 输出 `initialized`，未出现默认提示文本。记录为 **B3（目标存在）通过**：目标入口执行一次，提示默认入口未执行，消费方就绪后初始化。此证据适用 Build 70531，不与 Build 70469 的前一变体合并。

### MoP B4：目标入口故意失败（2026-10-22）

用户在 Mists 候选 TOC 中把入口标记改为 `error` 后提供启动日志：Build 70531、Interface 50504；`loaded=true`、`error=1`，`default=0`、`mists=0`、`forever=0`、`legacy=0`，API 未就绪；Consumer 输出 `loaded-without-ready-api; business-stopped`。聊天中出现 BugSack 错误捕获提示。记录为 **B4 行为已验证**：故意失败目标入口执行后，客户端未执行默认提示入口回退，Consumer 未在缺少 API 时继续业务初始化。探针代码预期错误为 `YiboTocProbe intentional entry failure`；当前日志未包含完整错误堆栈，BugSack 错误 ID/展开内容待留档。

### MoP C：保留旧文件的覆盖更新模拟（2026-10-22）

游戏退出后，先将默认 `YiboTocProbe.toc` 临时切换为旧版清单（`X-Probe-Entry: legacy`，加载 `Legacy.lua`），并将 Mists 候选移出插件根目录；随后模拟同路径覆盖新版：默认清单恢复为 Hint 入口，Mists 清单恢复为 `X-Probe-Entry: mists`，旧 `Legacy.lua` 保留在根目录。旧版清单快照保存在 `Scenarios/LegacyOld.toc.template`，故意失败候选另存为非 `.toc` 文件，未参与加载。MOP AddOns 路径经 Junction 指向探针源目录，覆盖后的 TOC 已从该路径核对。

用户随后提供 MoP Classic 5.6.4、Build 70531、Interface 50504 的实机启动日志：Consumer 输出 `initialized`；Observer 为 `loaded=true`、`default=0`、`mists=1`、`forever=0`、`legacy=0`、`error=0`、`apiReady=true`、`apiEntry=mists`、`init=1`。记录为 **C 覆盖后状态通过**：保留的旧版 `Legacy.lua` 未执行，新版 Mists 入口只执行一次且 Consumer 正常初始化。该次只实际运行覆盖后的状态；旧版 `legacy=1` 阶段未启动游戏，故旧版基线的运行证据仍待执行。

### MoP C：更新前旧版基线（待实机，2026-10-22）

为补齐 C-1，已将 `Scenarios/LegacyOld.toc.template` 复制为默认 `YiboTocProbe.toc`，并把新版 Mists 候选移出插件根目录；当前根目录仅有默认 TOC，`Legacy.lua` 保留且由它加载。下一次完整启动预期 `legacy=1`、其它入口均为 0、API 未就绪，Consumer 输出 `loaded-without-ready-api; business-stopped`。此项尚未运行，收到实机日志后再判定。

用户随后提供 MoP Classic 5.6.4、Build 70531、Interface 50504 的启动日志：`loaded=true`、`default=0`、`mists=0`、`forever=0`、`legacy=1`、`error=0`、`apiReady=nil`、`apiEntry=none`、`init=0`；Consumer 输出 `loaded-without-ready-api; business-stopped`。记录为 **C-1 更新前旧版基线通过**：旧版默认清单确实执行 `Legacy.lua` 一次，未初始化新版 API，消费方在 API 缺失时停止。

随后已恢复覆盖后清单集合：Hint 默认 TOC 与 Mists 候选 TOC 均位于插件根目录；旧版 `Legacy.lua` 仍保留。**C-2 覆盖后状态复测待实机**，下一次完整启动预期 `mists=1`、`legacy=0`、`apiReady=true`、`init=1`，Consumer 输出 `initialized`。

用户随后提供新版覆盖状态的实机日志：MoP Classic 5.6.4、Build 70531、Interface 50504；Consumer 输出 `initialized`，Observer 为 `default=0`、`mists=1`、`forever=0`、`legacy=0`、`error=0`、`apiReady=true`、`apiEntry=mists`、`init=1`。记录为 **C-2 覆盖后状态通过**：目标入口执行一次，旧版残留未执行，消费方初始化一次。下一项按 C-6 执行 `/reload` 后复核同样状态，并确认没有重复注册；此项待实机。

用户随后执行 `/reload` 并提供完整启动后日志：Consumer 输出一次 `initialized`，Observer 再次显示 `mists=1`、`legacy=0`、`apiReady=true`、`apiEntry=mists`、`init=1`。记录为 **C-6 重载复核通过**：重载后入口和消费方仍各初始化一次，未见旧实现执行或重复初始化。

为执行 C-5，已将 Mists TOC 移出插件根目录至 `Scenarios/C5_MistsMissing.toc.disabled`；默认 Hint TOC 和旧版 `Legacy.lua` 保留。**目标缺失变体待实机**：完整退出后重新启动，预期 Hint 默认入口提示一次、`legacy=0`、API 未就绪，Consumer 安全停止。完成后恢复 Mists TOC 再继续其它覆盖场景。

用户随后提供 MoP Build 70531 启动日志：Hint 提示输出一次，Observer 为 `default=0`、`mists=0`、`forever=0`、`legacy=0`、`error=0`、`apiReady=nil`、`apiEntry=none`、`init=0`；Consumer 输出 `loaded-without-ready-api; business-stopped`。记录为 **C-5 缺目标覆盖场景通过**：目标清单缺失时执行提示默认入口，旧版实现未回退运行，消费方安全停止。

MoP C 组已记录的更新前、覆盖后、重载及缺目标场景完成。下一项切换到 Forever 客户端 A2：当前插件根目录只放默认 Hint TOC 与 `YiboTocProbe_Forever.toc`（Interface 16001），Mists 候选已移出根目录；Forever AddOns 路径 Junction 指向此探针目录。**Forever A2 待实机**，需在 Forever 测试客户端完整启动验证候选识别和入口执行。

首次进入 Forever 测试时用户报告 `/ytp` 不可用。核对确认 Observer 与 Consumer 虽已通过 Junction 安装，但两者 TOC 原先声明 MoP Interface 50504，而 Forever 测试插件使用 Interface 16001；辅助插件因此可能被客户端按过期插件处理，无法注册命令。已分别将 Observer 与 Consumer 的 Interface 临时改为 16001，并在 `Scenarios/` 保存原始 MoP TOC 模板。Forever A2 仍待实机；启动前确认插件列表中 Observer、Consumer 已勾选，正常测试保持“加载过期插件”关闭。

结论使用“通过、失败、待执行、待确认、不适用”；不适用写明理由。记录本次完整退出启动、插件启用和过期加载开关的证据。离线解析或模拟结果单列，不能替代客户端清单选择。

## 9. 决策与后续接入

两端 A 组确认原生目标选择后，再依据 B、C、D 组选择默认入口形式。优先比较元数据空入口与最小提示入口；零字节文件只在实测行为明确且满足诊断与依赖要求时评估采用。

探针通过只证明对应客户端构建与场景的入口机制。正式 Core 接入仍须：

- 由新版同路径 `YiboCore.toc` 覆盖历史默认入口，并携带客户端实际认可的目标清单；源码与安装包各自验证。
- 核对发布规则对目标清单和兼容默认入口的约束，明确该入口仅用于历史覆盖及安全回退，不能靠报错转交另一 TOC。
- 使用真实历史 Core 包和测试存档副本完成覆盖升级；验证目标 API、业务插件就绪检查、设置恢复、重载及完整退出恢复。
- 在插件验收记录及无限服发布台账登记已验构建、升级起点、剩余项；存在未解决阻断时保持待验或不可发布。

实施前只依据本方案准备探针；本文不授权删除正式源码、玩家数据或历史安装包，也不表示已决定迁移正式入口。

### Forever A2反馈（2026-10-23）

用户截图确认Consumer initialized；Observer loaded=true，forever=1，default/mists/legacy/error均0，apiReady=true、apiEntry=forever、init=1，两次查询一致。结合已核对的Hint默认与Forever候选集合，本次候选入口选择与API就绪行为通过，兼作B3目标存在及D1行为证据。本次build、插件列表／过期加载开关及完整错误记录未在截图显示，环境证据仍待补，不沿用历史build推定。证据：`F:/Temp/User/codex-clipboard-cf66166b-9b4a-44a3-b160-f9bb4da1a457.png`。下一项A1须先退出两端客户端再准备；当前未改动场景。

### Forever A1场景准备（2026-10-23）

用户确认退出且进程核对未见Wow后，已保留A2清单至Scenarios非加载扩展名，根目录只保留Interface16001、X-Probe-Entry default、加载Probe.lua的默认TOC。Forever联接读取一致；预期default=1、其余入口0、API未就绪且Consumer安全停止。实机待反馈，详情见合并清单T02。

### Forever A1实机反馈（2026-10-23）

用户截图：Consumer loaded-without-ready-api; business-stopped；Observer两次查询均loaded=true、default=1，其余入口0，apiReady=nil、apiEntry=none、init=0。结合已核对的仅默认TOC场景，A1默认入口基线与API未就绪安全停止行为通过。本次build、插件列表／过期开关与完整错误面板未在截图显示，环境证据待补。证据：`F:/Temp/User/codex-clipboard-eb7ea3c5-6cb2-4106-a399-240330822516.png`。下一项A3共存，待退出后准备。

### Forever A3准备（2026-10-23）

两端退出且进程检查未见Wow后，保留A1默认基线（Interface16001、entry default），恢复Mists50504及Forever16001候选；三份均加载Probe.lua。A1默认已备份，Forever实际联接读取集合与内容核对一致。预期只执行Forever一次且Consumer初始化一次；实机待反馈。详见合并清单T03。

### Forever A3实机反馈（2026-10-23）

用户截图确认Consumer initialized；Observer两次查询均loaded=true、forever=1、default/mists/legacy/error均0，apiReady=true、apiEntry=forever、init=1。结合默认、Mists、Forever三份TOC共存的现场文件核对，A3入口选择与就绪行为通过。截图未显示本次build、插件列表／过期开关与完整错误面板，环境证据待补。证据：`F:/Temp/User/codex-clipboard-9df420b0-3ead-41bc-98e9-979abacd7494.png`。下一项A4默认＋Mists候选，待退出后准备。

### Forever A4准备（2026-10-23）

用户确认退出且进程检查未见Wow后，将Forever候选保留至Scenarios/ForeverA3_CandidateBeforeA4.toc.disabled；根目录仅默认16001/default与Mists50504/mists，均加载Probe.lua。客户端联接读取一致。预期默认入口执行一次、Mists入口不执行、API未就绪且Consumer安全停止。此场景不区分后缀未识别与Interface过滤原因。实机待反馈；详见合并清单T03/A4。

### Forever A4实机反馈（2026-10-23）

用户截图：Consumer loaded-without-ready-api; business-stopped；Observer两次查询均loaded=true、default=1、mists/forever/legacy/error均0，apiReady=nil、apiEntry=none、init=0。结合默认与Mists候选共存文件核对，A4默认回退、Mists未执行及消费方安全停止行为通过。无法据此区分后缀未识别与Interface过滤原因；本次build、插件列表／过期开关及完整错误面板未在截图显示，环境证据待补。证据：`F:/Temp/User/codex-clipboard-6d0bd4f0-4253-48e5-a294-4c577483a773.png`。下一项B1目标存在，待退出后准备。

### Forever B1目标存在准备（2026-10-23）

用户确认退出且进程检查未见Wow后，备份A4默认并将Mists候选移至Scenarios非加载扩展名；根目录仅默认TOC（实际0字节）与Forever候选（Interface16001、entry forever、加载Probe.lua）。Forever联接读取集合、内容与0字节核对一致；Observer/Consumer仍16001。预期只执行Forever一次并正常就绪，实机待反馈；详见合并清单T04。

### Forever B1目标存在实机反馈（2026-10-23）

用户截图确认Consumer initialized；Observer两次查询均loaded=true、forever=1、default/mists/legacy/error均0，apiReady=true、apiEntry=forever、init=1。结合默认TOC精确0字节与Forever候选的文件核对，B1目标存在入口选择与就绪行为通过。本次build、插件列表／过期开关及完整错误面板未在截图显示，环境证据待补。证据：`F:/Temp/User/codex-clipboard-34ecaddf-1d27-4578-9be8-7bcf3451f300.png`。下一项B1目标缺失待退出后准备，列表、加载及依赖行为按实际观察记录。

### Forever B1目标缺失准备（2026-10-23）

用户再次确认退出且复查未见Wow后，将Forever候选保留到Scenarios/ForeverB1_PresentCandidateBeforeMissing.toc.disabled；根目录与客户端实际联接视图均仅含精确0字节默认TOC，辅助插件仍Interface16001。须观察插件列表、加载状态及Consumer是否加载；不预设原生依赖结果，所有入口应不执行且API未就绪。未改业务目录或存档，实机待反馈；见合并清单T04。

### Forever B1目标缺失实机反馈（2026-10-23）

2026-10-23 T04/B1目标缺失反馈：用户插件列表截图显示“加载过期插件”未勾选，YiboTocProbe条目可见且标“不兼容”；Yibo TOC Consumer显示“依赖功能不兼容”，Observer正常启用。运行截图Observer两次查询均info=YiboTocProbe、loaded=false，default/mists/forever/legacy/error均0，apiReady=nil、apiEntry=none、init=0；所示日志无Consumer初始化输出。结合已核对根目录仅精确0字节默认TOC，确认本场景探针未加载、未执行业务且原生依赖阻止Consumer正常加载，未发现初始化行为；不将勾选框等同于成功加载。Forever列表可见性与MoP此前“列表看不到”反馈分别记录，不互相外推。本次build和完整错误面板未提供，不推定已补齐；过期加载关闭的直接证据适用于本次场景，不追溯先前场景。证据：`F:/Temp/User/codex-clipboard-2cbf1d9e-4c3a-43f5-96b5-4a8cf590b646.png`、`F:/Temp/User/codex-clipboard-23027b07-dbab-40c1-89fa-b10a1124691c.png`、`F:/Temp/User/codex-clipboard-f0ced860-4165-410d-a848-b5582741d28b.png`。B1两个变体行为完成，下一项T05/B2目标存在：仅元数据默认TOC＋Forever候选，待退出后准备。

### Forever B2目标存在准备（2026-10-23）

用户确认退出且进程检查未见Wow后，备份B1零字节默认为Scenarios/ForeverB1_ZeroDefaultBeforeB2.toc.template。根目录仅元数据默认（Interface16001、entry metadata、无Lua/XML）与Forever候选（Interface16001、entry forever）；客户端联接读取集合与内容一致，辅助TOC仍16001。预期Forever执行一次、API就绪且Consumer初始化；实机待反馈，见合并清单T05。

### Forever B2目标存在实机反馈（2026-10-23）

2026-10-23 T05/B2目标存在反馈：用户截图显示Consumer initialized；Observer两次查询均loaded=true，forever=1，default/mists/legacy/error均0，apiReady=true、apiEntry=forever、init=1。结合已核对仅元数据默认16001（无Lua/XML引用）与Forever候选集合，B2目标存在入口选择与就绪行为通过。重复Observer查询未增加初始化次数；本次build、插件列表／过期开关及完整错误面板未在截图提供，环境证据待补。证据：`F:/Temp/User/codex-clipboard-18321a46-37e9-49ef-b2f1-d64f0a5b1a40.png`。下一项T05/B2目标缺失，兼验D2，待退出后准备；不提前推定原生依赖与加载结果。

### Forever B2目标缺失准备（2026-10-23）

退出与进程核对完成后，将Forever候选保留到Scenarios/ForeverB2_PresentCandidateBeforeMissing.toc.disabled，根目录仅元数据默认（Interface16001、entry metadata，无Lua/XML）。客户端实际联接读取一致，辅助TOC仍16001。待实测原生依赖是否满足及Consumer安全停止，兼验D2；所有入口应0且API未就绪、init=0。业务目录与存档未改，详见合并清单T05。

### Forever B2目标缺失与D2实机反馈（2026-10-23）

2026-10-23 T05/B2目标缺失兼D2反馈：用户截图显示Consumer loaded-without-ready-api; business-stopped；Observer两次查询均loaded=true，default/mists/forever/legacy/error均0，apiReady=nil、apiEntry=none、init=0。结合仅元数据默认TOC、无Lua/XML与无目标候选的已核对集合，确认原生依赖允许Consumer加载，但消费方依据API未就绪安全停止，B2目标缺失与D2行为通过。截图未提供本次build、插件列表／过期开关及完整错误面板，环境证据待补。证据：`F:/Temp/User/codex-clipboard-2d7537bf-ca0e-4423-b8f4-091208c983d5.png`。B2两变体行为完成；T06/B3目标存在复用T01/A2的Hint默认＋Forever候选证据，不重复执行；下一项B3目标缺失兼D3，待退出后准备。

### Forever B3目标缺失准备（2026-10-23）

确认无Wow进程后，备份B2元数据默认并切换为Interface16001、entry hint的默认TOC，仅引用Scenarios/Hint.lua；根目录无目标候选，客户端实际读取核对一致。提示脚本只打印文本，不递增业务入口计数或提供API。预期提示一次、loaded=true、全部业务入口0、API未就绪且Consumer安全停止，兼验D3；实机待反馈，详见合并清单T06。

### Forever B3目标缺失与D3实机反馈（2026-10-23）

2026-10-23 T06/B3目标缺失兼D3反馈：用户截图显示“[YiboTocProbe] 未选择客户端目标 TOC；这是仅提示的默认入口。”一次，Consumer loaded-without-ready-api; business-stopped。Observer两次查询均loaded=true，default/mists/forever/legacy/error均0，apiReady=nil、apiEntry=none、init=0。结合仅Hint默认、无目标候选的文件核对，B3目标缺失提示及D3安全停止行为通过。截图所示重复Observer查询未触发重复提示或初始化；本次build、插件列表／过期开关及完整错误面板未提供，环境证据待补。证据：`F:/Temp/User/codex-clipboard-bdacbdad-65f0-4255-8616-6e1ea1599902.png`。B3目标存在沿用T01/A2同场景证据，不重复执行；下一项T07/B4兼D4：故意失败目标入口，待退出后准备，需保留预期错误完整堆栈并观察是否回退默认。

### Forever B4与D4准备（2026-10-23）

确认无Wow进程后备份B3 Hint默认并保持其内容，新增Forever候选（Interface16001、entry error、加载Probe.lua），通过既有error分支留下计数后抛出YiboTocProbe intentional entry failure。客户端实际读取集合与内容核对一致。待观察error=1、API未就绪、Consumer安全停止及是否执行默认提示；须保留完整预期错误堆栈。实机待反馈，见合并清单T07。

### Forever B4与D4部分反馈（2026-10-23）

2026-10-23 T07/B4兼D4部分反馈：用户截图显示Consumer loaded-without-ready-api; business-stopped；Observer两次查询均loaded=true、error=1、default/mists/forever/legacy均0、apiReady=nil、apiEntry=none、init=0。所示启动日志无Hint默认提示，结合既有失败候选与Hint默认场景，失败入口执行一次、未见默认提示回退、Consumer安全停止的行为已确认。Hint脚本不递增default计数，因此是否回退不能单凭default=0判断；当前依据为截图启动日志中未出现提示。截图未包含YiboTocProbe intentional entry failure原始错误或完整堆栈，故T07保持部分完成，先补错误内容及用户对提示是否出现的确认，不重复运行已验证场景。本次build、插件列表／过期开关及完整错误面板证据仍待补。证据：`F:/Temp/User/codex-clipboard-bc2563fa-6818-446a-8364-559ce86df122.png`。尚未切换下一场景。

### Forever B4与D4原始错误补证（2026-10-23）

2026-10-23 T07/B4兼D4补充错误证据：用户开启内置Lua错误显示并reload后提供原始错误：Message: Interface/AddOns/YiboTocProbe/Probe.lua:21: YiboTocProbe intentional entry failure；Time: Fri Oct 23 11:36:40 2026；Count: 1；Stack与Locals为空。错误与既有Probe.lua第21行故意抛出内容一致；保留客户端实际空堆栈，不将其记为未提供错误，也不要求为补堆栈重复测试。结合此前截图error=1、其余业务入口0、API未就绪及Consumer安全停止，故意失败与D4行为验证通过。此前截图启动日志未见默认Hint提示，用户尚未单独明确确认是否出现过，故“未回退默认”结论限于已展示日志，提示确认待补。本次build等环境证据缺口仍保留。下一项T08/C旧版基线待准备；进入切换前需退出两端客户端并核对独立安装目录，不能直接向源码Junction解压覆盖。

原始错误记录：
```text
Message: Interface/AddOns/YiboTocProbe/Probe.lua:21: YiboTocProbe intentional entry failure
Time: Fri Oct 23 11:36:40 2026
Count: 1
Stack:

Locals:
```

### Forever B4默认回退观察收尾（2026-10-23）

2026-10-23 T07/B4默认回退补证：用户反馈“应该没有出现”并补充重载后的启动截图。截图显示Consumer loaded-without-ready-api; business-stopped，Observer loaded=true、error=1、default/mists/forever/legacy均0、apiReady=nil、apiEntry=none、init=0，所示启动段无默认Hint提示。结合前次启动截图、原始故意错误及本次用户反馈，记录为本次已展示启动／重载场景未观察到回退默认提示入口，B4与D4本批行为验证通过；不将用户的措辞扩大为对未展示日志的绝对断言。Hint不递增default，结论依据为提示输出观察而非default计数。证据：`F:/Temp/User/codex-clipboard-34868658-10fb-4e49-a57b-78f5aa3e4bc6.png`。T07行为收尾，后续环境核对缺口继续保留。下一项T08/C-1独立测试安装的旧版基线，须先退出两端客户端再准备，不自动恢复Vault联接，不向共享源码联接解压覆盖。

### Forever C-1独立旧版安装准备（2026-10-23）

2026-10-23 T08/C-1准备：确认无Wow进程后，Forever AddOns/YiboTocProbe原Junction精确保留到客户端根目录_YiboTocOverlayTest/20261023-C1/OriginalYiboTocProbe，仍指向仓库_NonRelease/YiboTocProbe；原位建立独立普通目录，仅YiboTocProbe.toc（16001、version0.0.1、entry legacy、加载Legacy.lua）与Legacy.lua。Manifest-C1.json记录路径与SHA256。仓库探针当前B4文件保持原状，MoP探针联接及Forever Observer/Consumer联接未改，Vault与业务插件及WTF未操作。预期legacy=1，其余入口0，API未就绪、init=0、Consumer安全停止。旧版基线待实机；后续覆盖直接作用于该独立普通目录并保留Legacy.lua，不以源码联接模拟覆盖。恢复时须先退出客户端，将测试普通目录保留在本测试根目录，再把OriginalYiboTocProbe移回同名AddOns路径，不删除测试证据或还原WTF。

### Forever C-1旧版基线实机反馈（2026-10-23）

2026-10-23 T08/C-1实机反馈：用户截图显示Consumer loaded-without-ready-api; business-stopped；Observer两次查询均loaded=true、legacy=1、default/mists/forever/error均0、apiReady=nil、apiEntry=none、init=0。结合Forever独立普通目录中旧版默认TOC加载Legacy.lua的安装清单，旧版运行基线行为通过。证据：`F:/Temp/User/codex-clipboard-2b17936f-99a5-489c-b832-0cdba5c39b71.png`。本次build、插件列表／过期开关及完整错误面板未在截图提供，环境证据缺口保留。下一项C-2：客户端退出后同路径覆盖新版Hint默认与正常Forever候选，保留旧Legacy.lua，核对Forever一次、legacy零次与Consumer就绪；尚未执行覆盖。

### Forever C-2保留旧文件覆盖准备（2026-10-23）

2026-10-23 T08/C-2准备：确认无Wow进程、Forever YiboTocProbe为独立普通目录，且C-1两文件哈希与Manifest-C1一致后，原文件备份至客户端_YiboTocOverlayTest/20261023-C1/C1-OldFilesBeforeC2。在原位覆盖新版Hint默认16001并加入正常Forever16001候选、Probe.lua及Scenarios/Hint.lua；旧Legacy.lua原路径原内容保留，SHA256未变。目录精确5文件，两份TOC引用检查通过，均不引用Legacy.lua；Manifest-C2.json保存覆盖后清单及哈希。仓库B4场景、两端业务插件、Vault独立目录、原联接与WTF未改。预期forever=1，default/mists/legacy/error均0，API就绪、init=1、Consumer initialized，默认Hint提示不出现；实机待反馈。

### Forever C-2覆盖后实机反馈（2026-10-23）

2026-10-23 T08/C-2实机反馈：用户截图显示Consumer initialized；Observer两次查询均loaded=true、forever=1、default/mists/legacy/error均0、apiReady=true、apiEntry=forever、init=1，所示启动段未见默认Hint提示。结合C-1旧版基线及Manifest-C2独立目录覆盖清单、原路径Legacy.lua哈希未变，C-2保留旧文件覆盖后的目标入口选择、旧入口不执行与消费方初始化行为通过。证据：`F:/Temp/User/codex-clipboard-4547765a-09c8-43fd-b4d0-7d74d6ed536e.png`。本次build、插件列表／过期开关及完整错误面板未在截图提供，环境证据缺口保留。下一项C-6在当前安装执行reload，核对入口与Consumer仍各初始化一次、legacy=0；不改文件、不要求退出。

### Forever C-6重载实机反馈（2026-10-23）

2026-10-23 T08/C-6实机反馈：用户按reload与/ytp步骤提供截图，Consumer initialized出现一次；Observer两次查询均loaded=true、forever=1、default/mists/legacy/error均0、apiReady=true、apiEntry=forever、init=1。独立保留旧文件覆盖安装在重载后仍只执行当前目标一次、旧Legacy未执行，C-6重载行为通过。证据：`F:/Temp/User/codex-clipboard-8061aa5b-89ce-434f-8a1a-19239e19a3fe.png`。本次build、插件列表／过期开关及完整错误面板未提供，环境证据缺口保留。下一项C-5缺目标覆盖变体：退出后精确保留独立安装中的Forever TOC到测试目录，保留新版Hint默认与旧Legacy.lua，观察提示、安全停止和旧入口不执行。C-6完整退出再启动复核另须完成，不能用reload替代。

### Forever C-5缺目标覆盖准备（2026-10-23）

2026-10-23 T08/C-5准备：确认无Wow进程、Forever YiboTocProbe仍为独立普通目录，且所有现存文件哈希与Manifest-C2一致后，将Forever TOC精确保留至客户端_YiboTocOverlayTest/20261023-C1/C5-ForeverCandidate.toc.disabled。安装根目录仅新版Hint默认TOC（16001）；旧Legacy.lua及其余Lua原路径原内容保留，Legacy哈希未变。Manifest-C5.json记录安装清单与移出候选哈希。预期Hint提示一次、所有业务入口0、API未就绪、init=0、Consumer安全停止，不运行Legacy。业务插件、Vault、仓库源码联接及WTF未改。实机待反馈；随后须退出恢复正常Forever候选，再完整启动复核正常覆盖安装。

### Forever C-5实机反馈（2026-10-23）

2026-10-23 T08/C-5实机反馈：用户截图显示Hint默认提示一次、Consumer loaded-without-ready-api; business-stopped；Observer两次查询均loaded=true，default/mists/forever/legacy/error均0，apiReady=nil、apiEntry=none、init=0。结合独立覆盖安装缺目标TOC、旧Legacy.lua保留且哈希未变的Manifest-C5清单，确认缺目标时执行新版提示、旧实现不回退运行、消费方安全停止，C-5行为通过。证据：`F:/Temp/User/codex-clipboard-b3721a73-192c-474a-8f32-5d7eab8a704f.png`。本次build、插件列表／过期开关及完整错误面板未提供，环境证据缺口保留。下一项退出后恢复正常Forever候选，再完整启动复核覆盖目录正常目标加载；本次未改动文件。

### Forever C-6完整启动准备（2026-10-23）

2026-10-23 T08/C-6完整启动准备：确认无Wow进程及独立普通目录后，核对当前安装与Manifest-C5一致，复制保留的C5-ForeverCandidate.toc.disabled恢复为安装根目录YiboTocProbe_Forever.toc，保留原取证副本。恢复后全部5文件哈希与Manifest-C2一致，Legacy.lua仍保留，两个TOC均不引用它；Manifest-C6-Restart.json保存当前清单。预期完整启动后forever=1、其余入口0、API就绪、init=1、Consumer initialized、无默认Hint提示。源码联接仍在AddOns外保留，Vault与业务插件及WTF未改；本次完整启动实机待反馈。

### Forever C-6完整启动实机反馈（2026-10-24）

2026-10-24 T08/C-6完整启动反馈：用户按恢复正常候选后完整启动步骤提供截图，Consumer initialized出现一次；Observer两次查询均loaded=true、forever=1、default/mists/legacy/error均0、apiReady=true、apiEntry=forever、init=1，所示启动段无Hint提示。结合恢复后5文件哈希与Manifest-C2一致的核对，独立保留旧文件覆盖安装完整重启仍仅当前目标执行一次，旧Legacy不执行、消费方初始化一次，C组本批已列行为用例完成。证据：`F:/Temp/User/codex-clipboard-df0f0669-1dd9-4780-8f14-5ac3a994d765.png`。当前客户端build／Interface／项目／语言、过期加载设置与非预期错误情况须在T09收尾核对；新取得环境信息仅证明当前会话，不追溯推定10月23日全部场景build一致。探针通过不代表真实Core入口迁移或插件发行验收完成。下一步T09环境记录，不重复已测场景；当前探针仍为Forever独立普通目录，源码联接在AddOns外保留，Vault独立目录不恢复。

### T09环境报告补证（2026-10-24）

2026-10-24 T09环境补证：用户通过/yfp scan、/yfp report提供YiboForeverProbe0.1.1报告（sample77、session39、previousSampleID74）。GetBuildInfo返回1.60.1、70450、Oct 15 2026、Interface16001；GetLocale=zhCN；WOW_PROJECT_ID=18且WOW_PROJECT_CAMELOT=18，ActiveGameMode=1。仅登记该样本实际返回，不将先前70374基线或本报告推定为全部历史TOC场景的构建。原始附件位于C:/Users/Administrator/.codex/attachments/85fabbfc-5e1c-4cec-ab05-d60fbb5f4f65/已粘贴的文本.txt；含角色标识，不复制完整报告入仓库。本报告不包含checkAddonVersion，当前过期加载关闭及除B4以外是否有Lua错误仍待用户确认。/run出现运行确认且用户反馈确认后无输出，已改用既有探针取证，无需更改运行代码。下一步B01先核对Core0.2.0页面，现有TOC探针独立覆盖目录与Vault部署保持不变。正式Core入口迁移和发行包仍另验。

2026-10-24环境补充反馈：用户明确确认当前“加载过期插件”关闭，除B4故意错误外本轮无其它Lua错误。结合样本77构建70450／16001／project18／zhCN登记当前环境，不将其追溯为全部历史场景构建一致。


## 2026-10-26暂停与范围调整（以本节为准）

用户要求：“无限和mop分开、toc设置的测试还差几项，到这里要先停一下，无限探针测试另外再测”。已暂停本轮引导，不继续要求天赋截图／新采样，不自动创建会话、发送其它会话消息或安排提醒。之后恢复本会话时，先处理MoP／Forever分离和TOC收尾；无限业务／探针测试另行恢复，不自动沿合并清单B03继续。

已验：TOC探针本轮MoP／Forever已有入口选择、空／元数据／提示默认、失败入口安全停止及旧文件覆盖等证据；Forever C组旧版、覆盖后、重载、缺目标、恢复正常候选完整重启行为均已记录。不得重复已验同版本同场景，也不把探针通过算作真实Core或业务包通过。

分离与TOC收尾仍须核对的工作组（不是已确定的单条实机用例数量）：
1. 汇总两端证据，确定正式目标TOC与默认入口方案，审查历史环境／构建和MoP B4原始错误等证据缺口；当前环境信息不追溯冒充历史已核对。
2. 正式Core／受影响插件的实际TOC、XML与间接加载链落地及复核，验证目标身份、错误目标写库前停止、依赖API就绪；探针验证不代替正式入口接入。
3. 实际独立包及真实旧版本保留文件覆盖、源码联接加载来源、初始化／事件单次注册、原角色／设置／存档、reload与完整退出恢复。Vault两端已列MoP用例通过，Forever仅初始页面等局部证据，剩余相关范围及错误保留／入口边界继续待验；不重做已有证据，公会银行仍待条件。
4. 测试部署状态收尾与包边界：两端Vault独立普通目录、Forever TOC探针独立目录及AddOns外原联接均继续保留；恢复联接或切换辅助TOC时须先核对两端已退出，再精确执行与登记，暂停本身不授权自动恢复。最终干净／覆盖安装和渠道共管检查按声明范围另验。

另测保留：Crafting0.1.2修复与已验专业对照／关闭快照证据保留；未学、变化和保存恢复继续待验。B03天赋已有结构首样本，原生树截图与自然变化待对照；坐骑、副本、容器、真实冷却等未完成项继续待条件／待测。暂停不改变任何插件可发布数量，不操作运行文件、客户端或WTF。


## 2026-10-26恢复范围与下一步（覆盖前述暂停状态）

用户明确“好，先测这些”，授权恢复双端分离与TOC收尾，无限业务／探针采样继续暂停，不继续B03天赋截图。先只读核对：两端Core仍为仓库Junction，根目录仅YiboCore.toc（50504、1.12.9、YiboCoreDB）和YiboCore_Forever.toc（16001、0.2.0、YiboCoreForeverDB），尚无Mists目标TOC，正式默认入口还未改为Hint。不能将此前独立探针验证写成正式Core入口迁移已完成。

已发现其它工作更新，避免重复：客户端源码联接文档记录2026-10-25 MoP Vault1.2.4-api1保留旧文件覆盖与干净代码安装及reload／完整退出均已获用户反馈通过；实际MoP Vault独立普通目录为1.2.4-api1，Forever Vault独立目录仍0.6.0-api1。两端Vault与Forever TOC探针原源码联接仍保留在AddOns外，不自动恢复。两端Core默认及Forever TOC均可从实际客户端联接读取。

下一项X01：正式Core当前MoP1.12.9启动基线。用户切到MoP客户端、关闭加载过期插件，/yco检查实际版本、原角色／设置及首条Lua错误；先不重做Vault功能或更换运行文件。此项基线用于后续实际入口接入前后对照，不等于正式迁移验收。X01之后再按实际方案准备双目标入口与独立包／覆盖验证，已有证据去重复用，缺失场景单列。此次未修改运行代码、TOC、客户端目录或存档；当前两端游戏均运行，切换部署前须再核对退出。

### X01正式Core MoP启动基线（2026-10-26）

2026-10-26 X01正式Core MoP启动基线反馈：用户截图显示YiboCore v1.12.9概览，现有业务导航及账号摘要可见（角色构筑13名快照、货币14角色、账号待办14名快照等），排序按钮显示自定义，用户明确“无错误”。登记MoP当前版本启动、既有摘要可见与本步无Lua错误通过；不据概览推定每条业务数据、全部角色档案、全部设置及持久化已逐项对照。证据：`F:/Temp/User/codex-clipboard-beafb2b4-498c-4696-b1a3-7df5fe889943.png`。

下一项X02正式Core当前双端选择对照：切换当前无限服客户端/yco，核对同一源码联接下实际选择Forever0.2.0、仅显示无限角色／目标业务范围、没有MoP角色混入以及Lua错误。该项是本批正式入口接入前与MoP1.12.9共享源码基线对照，不恢复B03或其它业务／探针取证；不重做已验TOC探针场景。运行代码、TOC与部署均未修改，正式Hint默认与Mists入口迁移尚未实施。

### X02正式Core双端基线对照（2026-10-26）

2026-10-26 X02正式Core Forever选择／页面数据对照：用户两张截图显示YiboCore v0.2.0概览与角色档案，档案仅一名当前角色天堂-CAMWOW CN1 Real...、等级13、专业33／86；未见此前MoP概览所见多角色数据。结合两端相同仓库Core联接、默认MoP1.12.9与Forever0.2.0实际TOC核对，登记本次双端目标版本选择与可见角色目录隔离对照通过。截图不是对全部SavedVariables字段隔离的审计，不能推定写库前误装阻止、全部设置／业务数据或持久化已验；用户本次未单独补“无Lua错误”，不扩大此前MoP无错误反馈到Forever本步。已知关于项与角色档案表头越界继续独立待修，不借本次TOC测试处理。

证据：`F:/Temp/User/codex-clipboard-231fbbbe-1fa4-4727-989c-8df94441b7c2.png`（概览）、`F:/Temp/User/codex-clipboard-8b7d0504-5827-4ab1-9da9-20362152f19f.png`（档案）。

下一项X03：为正式Core准备最小双目标入口候选（Hint默认＋Mists目标＋既有Forever目标），先在独立测试副本核对实际入口与旧包覆盖；须完整退出两客户端后备份当前代码／存档并核对部署。保留当前真实源码与安装来源，不先全仓切换，也不恢复Vault联接；最低Core能力与业务初始化就绪检查按实际调用核对。当前尚未创建或部署该候选，文件与WTF未改。业务／非TOC探针仍暂停。

### X03独立正式Core候选准备（2026-10-26）

2026-10-26 X03正式Core三TOC独立候选已部署，待首次实机：用户确认两端退出并补充不要重复已验测试；进程复查无Wow/WowClassic后才部署。候选位于_NonRelease/CoreTocEntry-20261026/Candidate/YiboCore，共92文件；原53个运行Lua逐文件与仓库哈希一致，MoP原默认清单改名YiboCore_Mists.toc，Forever清单沿用，二者增加X-Yibo-Target元数据。默认YiboCore.toc仅引用Common/TocHint.lua，不声明SavedVariables，不创建Core/API、不注册事件；Interface声明50504,16001，两端通用值仍须实机选择核对。Hint为Core尚不可用时的最小预启动诊断，以稳定ASCII键及中英文表输出，不能调用尚未加载的Core:Text，此例外仅限默认TOC提示，不建立并行运行语言服务。目标版本仍MoP1.12.9与Forever0.2.0，存档仍YiboCoreDB／YiboCoreForeverDB，schema未改。

离线仅验证本次新候选：Verify.lua128项通过，覆盖目标清单实际加载、每Lua一次、重复ADDON_LOADED不重复初始化、两端DB隔离、误用对端清单初始化前拒绝和四客户端语言Hint安全行为；不重复全部业务套件，亦不将离线选择等同客户端原生选择。多Interface格式参考打包器一手说明https://github.com/BigWigsMods/packager#multiple-interface-values；正式发行目标包及真实旧包覆盖验收未执行，此候选是开发双目标副本，不作为单目标玩家包。

客户端两端原Core均已由Junction换成独立普通目录；原Junction精确保留于各自客户端_YiboCoreTocTest/20261026-X03/OriginalYiboCore，仍指向仓库YiboCore。切换前备份两端现有Yibo系列存档及bak（MoP85、Forever22，共107份）到各自SavedVariablesBackup，部署前后原WTF哈希一致；继续使用原客户端WTF路径，不称为隔离WTF测试。每端92文件与候选哈希一致，原联接、备份与清单记录在客户端Manifest.json，仓库部署摘要Deployment.json。Vault普通目录与其它插件未改；TOC旧独立探针及其原联接保持原状。

下一步只补新加载链的首次客户端选择：X03A先启动MoP/yco，看1.12.9正常打开、无默认Hint、无新增Lua错误；X03B再核对Forever0.2.0。X01/X02旧加载链基线、已验探针A—D与Vault安装测试全部复用，不重跑。原设置／角色已有证据按范围复用，正式入口误装或缺文件等尚未覆盖边界单列，不扩大业务测试。

恢复与后续：两端Core独立目录不跟随仓库后续修改自动更新。需要回到源码联接时必须先退出两端，逐端把当前Core测试普通目录移入本测试备份根保留，再将OriginalYiboCore移回原AddOns路径；不删除证据、不自动还原WTF。本次不是持久化迁移仓库正式Core加载链；核心源目录默认TOC及所有运行文件未改。公共能力无新增／接入变化，目标职责只为已有清单路由与预启动Hint，正式迁移和发行检查仍按后续范围落地，当前无发布操作。

### X03A正式Core独立候选MoP首次加载（2026-10-26）

2026-10-26 X03A独立Core三TOC候选MoP首次反馈：用户截图显示Core1.12.9角色档案正常打开，多名原有角色、专业／等级等档案行可见，自定义排序按钮保留。结合已部署候选（默认仅Hint、不创建Core；Mists1.12.9、Forever0.2.0）和完整启动要求，登记Mists目标入口首次加载及既有档案／排序可见通过；不重跑原探针A—D或业务回归。截图所示日志未见Core默认Hint，但未展示完整启动日志；用户本次未单独声明无错误，截图BugSack“所有已保存的错误已经被清除”不作为无新增Lua错误证明。不得据此宣告全部设置／全库持久化或入口单次注册实机全部通过。证据：`F:/Temp/User/codex-clipboard-22508926-470a-436a-82ec-72ce92bcf0a9.png`。下一项X03B只启动Forever候选/yco，预期0.2.0、无MoP角色混入、无Hint或新增Lua错误；无需更换文件、恢复联接或再验证业务内容。两端Core仍为独立候选普通目录，Vault不变。

### X03B正式Core独立候选Forever首次加载（2026-10-26）

2026-10-26 X03B独立正式Core三TOC候选Forever首次反馈：用户截图显示YiboCore0.2.0角色档案，当前角色天堂、等级13、专业33／86，未见X03A MoP的多角色档案混入；所示启动日志未见Core Hint。图中YiboTocObserver/Consumer输出仍属于另一个独立TOC探针，不用作Core候选的初始化次数证据。结合候选实际文件清单，登记Forever目标入口首次加载及可见角色隔离通过，两端X03A/B首次入口选择完成；不以截图无弹窗直接判所有Lua错误审计或完整注册／保存恢复已通过。证据：`F:/Temp/User/codex-clipboard-c544a30e-f7fd-4399-8f17-09ece5951326.png`。

下一项X04为本次正式Core候选一次reload后的重复入口／窗口及原有角色设置保留检查；用户要求不重复已验测试，因此仅观察候选新加载链，旧探针reload、业务功能与Vault测试均不再安排。先在当前Forever执行reload后/yco，若有新Lua错误则留首条；之后按实际必要范围核对MoP，已通过的首次完整启动证据直接复用。尚未进行正式玩家包或真实旧包覆盖发布验收；源码默认入口仍未永久迁移，当前客户端为独立候选。业务／其它探针继续暂停。

### X04A正式Core候选Forever重载（2026-10-26）

2026-10-26 X04A正式Core候选Forever重载反馈：用户截图显示重载后Core0.2.0角色档案仍可见，当前角色天堂、等级13、专业33／86保留；用户明确补充“RL，没问题”。按指定检查范围登记本候选Forever reload后版本、角色保留及无重复窗口／入口、新增Lua错误反馈通过；不以另一个YiboTocObserver的init=1作为Core本体初始化计数。证据：`F:/Temp/User/codex-clipboard-3c7c0ffd-3531-4e66-a2d9-06c2d4750f7f.png`及用户文字确认。下一项X04B仅MoP正式Core新候选一次reload/yco，核对1.12.9、原角色／自定义排序保留和无重复／错误；不重复首次启动、原TOC探针或业务功能测试。当前两端独立候选部署和Vault均未变，业务／其它探针继续暂停。

### X04B重载与X05旧包覆盖加载图（2026-10-26）

2026-10-26 X04B正式Core候选MoP重载反馈：用户按reload/yco核对步骤回复“通过”，按指定范围登记MoP1.12.9、原角色／自定义排序保留，无重复入口／窗口或新增Lua错误。至此X03两端候选首次入口选择与X04两端候选reload检查通过；不重做已验探针／业务用例。

X05离线真实旧包覆盖核对：分别解压现存Core MoP1.12.9-api13与1.12.7-api13 CurseForge ZIP到_NonRelease/CoreTocEntry-20261026/OverlayReplay/独立目录，再同路径覆盖当前92文件候选，不清理旧文件。两个旧包分别65／64文件，均残留5文件，原哈希不变；覆盖后精确三TOC集合，三个清单引用全部指向候选同字节运行文件且无重复Lua引用／间接XML。各候选文件和加载图与已通过X03/X04实机候选相同，旧残留不参与加载。详细归档SHA256、残留清单和加载图见OverlayReplay-Report.json。此为离线结构证据，不将其记作真实旧存档副本客户端覆盖或渠道更新工具验收，也不为相同加载图安排重复手动启动。正式目标独立包尚未制作。

下一项X06只补本次新三TOC候选运行后完整退出再启动的角色／原设置恢复，两端合并一次完成；与X03候选首次启动前基线、旧探针重启及X04 reload区分。原设置不要求人为变更，恢复已有角色与自定义排序即可。无需重跑数据采集、入口切换或其它业务。当前客户端代码／联接／WTF无新增修改，仍保留独立候选和原联接备份。源码正式入口永久迁移及部署恢复另列，不因候选已验自动修改。

### X06及本轮候选入口验证收尾（2026-10-26）

2026-10-26 X06正式Core候选双端完整退出恢复：用户按正常退出两个客户端、分别重启/yco的指定步骤回复“均通过”。按明确检查范围登记MoP1.12.9、Forever0.2.0、原角色与排序保留、无新增错误反馈通过。复用既有截图与X03/X04证据，不重复安排启动／重载／业务操作。

本轮独立三TOC候选入口验证收尾：X01/X02原源码双端基线；X03候选两端首次选择与可见目录隔离；X04两端reload；X06两端完整退出恢复均通过。X05真实旧MoP1.12.9／1.12.7包保留文件覆盖后的加载图与已验候选完全一致，属于离线结构通过；不冒称真实旧存档副本客户端覆盖、单目标发行包或CF工具验收通过。旧TOC机制探针A—D结果继续复用，本轮不再安排这些场景。

后续落地工作而非本轮重复测试：仓库YiboCore.toc仍是原MoP加载链，实际候选改动仅在_NonRelease/CoreTocEntry-20261026；正式源入口迁移／构建引用／发布配置尚未提交到运行源码，不宣告已完成正式迁移或可发布。两端Core当前仍为独立普通候选目录，原Junction在各自_YiboCoreTocTest/20261026-X03/OriginalYiboCore保留；两端Vault及Forever旧TOC探针部署不变。只有正式源入口与构建接入后，才安排适用的未覆盖边界及最终包检查，文件／加载图未变化且同版本证据可复用时不重复要求实机。源码落地及联接恢复仍须核对客户端退出后精确执行，当前未修改运行文件或还原存档。

无限业务／非TOC探针仍按用户要求暂停，天赋报告等已采证据保留，不继续采样。当前Core布局问题仍独立待修，不把本轮入口通过扩大为全部UI／业务验收完成。
