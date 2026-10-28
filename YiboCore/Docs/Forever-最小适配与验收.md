# Core 无限服最小适配

日期：2026-10-19。状态：**代码与离线回归完成，待两个客户端实机验收**。

| 目标 | 源码加载清单 | 运行版本 / API | 账号 SavedVariables |
| --- | --- | --- | --- |
| Mists | `YiboCore.toc`，Interface 50504 | 1.12.7 / 13 | `YiboCoreDB` |
| Forever | `YiboCore_Forever.toc`，Interface 16001 | 0.1.0 / 13 | `YiboCoreForeverDB` |

两份清单位于同一源码目录，复用窗口、角色目录与存档实现。客户端目录联接保持原样。Forever 清单的原生选择与优先级须在本机 build 70374 完整重启后的插件列表及运行版本中确认；离线直接加载该清单不能替代这一步。多清单原则参考 [BigWigs Packager 文档](https://github.com/BigWigsMods/packager/blob/master/README.md#multiple-toc-files)，本仓库的目标与发行标识仍遵循[标识规范](../../Docs/多版本目标与发行标识规范.md)。

## 已实现的最小范围

`Forever/Target.lua` 是当前目标策略的唯一来源，以已采到的具名常量 `WOW_PROJECT_CAMELOT` 与 `WOW_PROJECT_ID` 相等为前提，配置版本、存档名与 GUID 策略。共享代码只消费策略；未知常量、产品不匹配或在无限客户端强行加载默认 MoP 清单时，初始化在写库前停止，并显示中英文资源提示。

- 启动：原有生命周期保留。移除的客户端事件通过逐项保护注册记录在 Core 私有诊断状态，不中断其余加载；不是把采集错误吞掉后当作成功。
- 角色目录：无限服仅使用 `UnitGUID("player")`；GUID 尚未就绪时不创建临时角色，下一次原生生命周期事件继续尝试。名字和服务器仅用于显示，不创建名称别名，不按名称合并不同 GUID，也不导入旧角色记录。
- 保存：无限服只读写 `YiboCoreForeverDB`，不读取、复制或迁移 `YiboCoreDB`。目标存档包含 `clientScope={target="Forever",projectID=18,rulesetState="unknown"}`。产品戳不匹配、存档结构异常或 schema 超前时保留原数据，停止初始化。存档仍由 WoW 原生加载与落盘；实际文件为无限客户端 `WTF/Account/<账号>/SavedVariables/YiboCore.lua`，文件名跟随插件名，表名为 `YiboCoreForeverDB`。
- 基础档案：无限清单只加载身份与位置域；字段目录只注册已加载域的字段。装备等级、专业、专精未进入本轮采集，不填零或空业务结论；MoP 原有域和字段继续加载。
- 窗口：复用账号总览、角色档案、统一设置、帮助／关于、Broker／小地图和关闭行为，命令仍是 `/yco` 与 `/yco settings`。未启动时命令给出提示，不打开依赖存档的窗口。

此处角色目录是独立 GUID 的本地观察记录，不建立无限规则集、双名或共享库存契约。`Standard=1` 不用作规则集键；跨角色业务共享与范围判定须有实际业务来源后单独设计。业务插件本轮保持禁用，不提高其 Core 最低版本，不宣称其已接入无限目标。

## 公共接口与发行边界

沿用 API 13，已用的 `characters:1`、`character-identity:1`、`character-name-format:1`、`database:1`、`account-view:2`、`localization:1` 等契约版本保持不变。未新增公共服务或能力版本。Forever 的角色目录要求真实 GUID，旧角色导入明确返回 `nil, localizedError`；缺失的目标域可由 `DataDomains:GetDefinitions()` 发现，不得推定所有 MoP 域都存在。

CAP-004／CAP-007／CAP-009 等现有台账仅增加 Core 新目标的验证边界；没有业务插件的调用迁移。源清单与目标策略已实现，不代表全部公共能力在无限客户端已验收。

Mists 默认清单、版本和发布构建配置沿用当前工作树；Forever 暂不登记可发布 CF 构建，不猜测平台版本 ID，也不新增上传或发行产物。用户首次实机加载通过后，再按本次实现与真实平台元数据补对应发布配置。

## 离线验证证据

```powershell
lua _NonRelease/CoreForever/Smoke.lua
.\Tools\Test-LuaSyntax.ps1 -Addon YiboCore
.\Tools\Build-ReleasePackages.ps1 -Addon YiboCore -Target Mists -ValidateOnly
```

CoreForever Smoke 使用两份真实清单与全部窗口模块，在模拟 WoW 环境验证 69 项：启动、GUID 缺失与晚到、不同 GUID 同名不合并、默认清单错客户端保护、存档隔离与异常／超前保护、角色快照不暴露内部引用、总览／角色档案／设置／关闭、下一会话身份与短名／语言／排序恢复。它覆盖共用与目标实现的联动，不证明原生 TOC 选择、WoW 渲染、保护执行或真实落盘。

已通过：Lua 5.1 的 51 个 TOC 加载源文件检查；Mists 1.12.7/API13/50504 构建 ValidateOnly；CharacterNamesSpec 77 项、CharacterCleanupV2Spec 43 项、ContractsSpec 90 项、Currency CoreSpec 23 项；已有 LocaleLayoutSpec 213 项及其工作台／窗口夹具；Core 新旧语言资源检查。

两个扩大回归的现有阻断保持原样：

- `RuntimePerformanceSpec.lua:107` 在 AltoBoss 测试段失败。
- `_NonRelease/Localization/LocaleSpec.lua:56` 仍查找已无定义的 `money` 资源，发生 nil 索引。

通过 `_NonRelease/CoreForever/BaselineRunner.lua` 在内存中恢复本轮七个修改文件的原始 HEAD 版本、保留其余当前工作区，两个测试均在同一位置失败。对照没有改写工作树；这些结果不能计为通过，也不扩大本次 Core 适配去修复其它模块或旧夹具。

## 实机验收步骤

1. 完整退出两个客户端后重开。无限服只启用 `YiboCore`，需要报告时可同时保留 `YiboForeverProbe`。先看插件列表是否允许正常加载；不要用“加载过期插件”掩盖清单选择错误。
2. 无限服进入世界后等加载完成，输入 `/yco`。确认窗口可开关、Core 版本为 **0.1.0**，总览、角色档案和设置能切换；角色名称、服务器、职业、等级与当前角色一致。专业／装备业务字段本轮不作为验收项。
3. 在 `角色与排序` 给当前角色设置一个短名、选择排序；在常规设置改一次语言。拖动窗口后关闭，执行 `/reload` 再打开，核对短名、排序、语言和位置。再退出角色重登复测，记录实际采用的登录方式。
4. 确认无限客户端 `SavedVariables/YiboCore.lua` 内为 `YiboCoreForeverDB`；如需分析，可提供该文件，避免覆盖或复制 MoP 文件。
5. MoP 保持原启用集合，输入 `/yco` 与 `/yco settings`。确认 Core 显示 **1.12.7**、已有角色与设置仍在，原业务页与入口能打开；重载后复查。
6. 反馈两端窗口截图及遇到的首条 Lua 错误。若无限服仍为“不兼容”、显示 MoP 版本、没有角色或重载后设置丢失，保留现状，按失败点核对清单、身份或存档；不能把离线回归记为实机完成。

| 客户端 | 清单选择 | 启动／角色 | 窗口 | 原生保存恢复 | 本轮状态 |
| --- | --- | --- | --- | --- | --- |
| Forever 1.60.1.70374 | 截图确认选择0.1.0 | 已启动；角色目录数据待核对 | 总览／设置／关于已见截图；目录筛选改动待重载核对 | 待确认 | 继续实机验收 |
| Mists 5.5.4 | 默认清单保持，待复核 | 离线回归通过，待实测 | 离线回归通过，待实测 | 离线回归通过，待实测 | 本次共享改动待客户端回归 |

## 2026-10-19 关于页客户端适用性

用户截图已确认无限服加载 Core 0.1.0，总览、设置和关于页可打开。关于页过去展示所有目录插件，即使本机只有其它客户端的清单也标记为已安装／已启用，不能表达当前目标可用性。

共享 AddonCatalog 现要求每个插件通过 `supportedTargets` 明确声明已适配目标，并在查询安装信息、读取图标与创建卡片前按当前目标过滤。13项业务目录保留Mists支持；Vault本轮新增Forever目标声明，描述限定为当前角色背包与装备，其余业务条目在Forever隐藏。安装、启用或连接状态都不用于推断目标兼容。后续业务适配完成时同步更新其目录目标声明。目录在分组内按插件技术名排序，未安装但适用于当前目标的插件仍可作为发现项显示。

关于页直接复用共享目录，空分组隐藏标题和分隔线；没有业务条目时采用紧凑高度。没有额外加载业务插件或改写其启用状态。扩展的双端真实清单模拟共69项，包含Forever仅Vault及目标描述、MoP13项列表、分组可见性和排序。截图不能证明角色短名／排序或保存恢复已通过；对应验收项继续待确认。Vault的采集与保存另见[最小适配记录](../../YiboVault/Docs/Forever-当前角色物品最小适配.md)。

## 2026-10-20 专业档案增量

当前Forever版本升至0.2.0／API13，增加profession-profile:1及目标professions v1采集器：处理原生七个专业返回位，按skillLineID保存身份和技能等级，为Crafting0.1.0提供公开专业档案。Core拥有专业档案，配方由Crafting拥有；错误／未就绪保留旧档案并返回非known状态。详见[契约](Forever-专业档案契约.md)。此前0.1.0窗口与启动实机证据保留，0.2.0新增档案和字段变化全部待实机。MoP仍1.12.7，旧副专业槽位兼容不变。
