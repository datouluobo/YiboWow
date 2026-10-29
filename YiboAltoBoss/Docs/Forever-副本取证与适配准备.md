# AltoBoss Forever 副本取证与适配准备

日期：2026-10-23。依据：[适配顺序](../../Docs/Yibo系列-无限服适用性与适配顺序-2026-10-19.md)、[无限服台账](../../Docs/无限服适配与发布验收台账.md)、[多版本开发规则](../../Docs/多版本开发规则.md)。用户本轮安排为先完成可做的适配工作，再集中实机测试。

## 本轮结论

**取证工具代码完成、离线通过，正式 Forever 业务仍待真实样本。** 新增独立非发布探针 `YiboAltoBossForeverProbe 0.1.0`；可在集中测试的一次正常副本过程中取得进入、首领事件、原生锁定、保存恢复证据。它不构成 AltoBoss Forever 版本、目标包或正式兼容声明。现有 MoP 2.8.3 运行文件、加载链与 SavedVariables 没有因本轮准备而改变。

现有 `_NonRelease/YiboForeverProbe/Samples/2026-10-18-build70374-baseline.json` 和 `2026-10-19-build70374-followup.json` 只证实 `GetNumSavedInstances`、`GetSavedInstanceInfo`、`C_RaidLocks.IsEncounterComplete` 函数存在。相应[首轮审查](../../_NonRelease/YiboForeverProbe/Samples/2026-10-18-build70374-首轮审查.md)明确锁定尚未进入业务验证；[复测审查](../../_NonRelease/YiboForeverProbe/Samples/2026-10-19-build70374-复测审查.md)仍把锁定和重置列为后续。没有正向副本锁定、首领变化、真实重置、不同角色／规则集样本，不能据接口名或 MoP 数据建立正式业务。

## 已完成的具体准备

- `_NonRelease/YiboAltoBossForeverProbe/` 的目录、TOC 同名，Interface 使用已审查的 `16001`。运行时在建库前复核项目 18 和 `WOW_PROJECT_CAMELOT`，误装目标停止。
- `/yaf start` 后只读采样：原始 `GetInstanceInfo`、原生缓存锁定、候选首领返回及白名单事件。原始状态区分缺失、nil、false、零、错误、受限与截断，不产生完成判断。
- 记录 24 份快照、120 条事件、会话与样本关联、真实时间源及淘汰计数；事件合并采样并在停止／转场／退出时取消未执行采样。报告可一次复制保留的整段过程。
- 明确每次最多 64 条锁定、每条 64 个首领、合计 512 个首领读取；候选参数位置在报告标注待核实。没有 API 位置正向证据前不把该读取模型写成已验证契约。
- 已写出 B0—B6 集中测试顺序、原生对照、`/reload` 与完整退出恢复条件；后续自然重置与不同角色／规则集另验。

完整步骤与数据边界见[探针说明](../../_NonRelease/YiboAltoBossForeverProbe/README.md)。客户端联接状态由本轮集中测试安排记录，不因源码存在推定已安装或已加载。

## 样本到位后的最小实现边界

| 证据 | 可决定的最小范围 | 未满足时的处理 |
| --- | --- | --- |
| 进入／退出副本的地图、类型、难度候选值与玩家观察一致；重载身份稳定 | 当前角色实际进入记录；未知字段保留未知 | 保留原始探针证据，暂不生成正式副本身份 |
| 原生列表有真实锁定，首领前后行变化与实际击杀一致 | 仅已证明原生锁定来源的只读快照；由 AltoBoss 拥有与解释 | 不把事件、空表、锁定 ID 存在直接当作完成 |
| `ENCOUNTER_END`／`BOSS_KILL` 的本服返回及重复触发行为有对照 | 为已证实副本增量记录首领事实，并定义去重键 | 不导入 MoP encounter/NPC 目录或套用旧完成规则 |
| 自然重置前后、手动重置／难度变化有真实对照 | 已确认范围的过期与刷新规则 | 只展示采样时间和观察结果，不硬编码日周周期 |
| 第二角色／规则集对照足以证明各字段归属 | 按证据扩大离线／多角色视图 | 保持当前角色范围，不合并账号权威记录 |

正式实现时首批只消费已验证的数据源；原生动态名称保持 API 原文。一个副本样本只授权相应范围；目录增量按本服地图／首领稳定 ID 和来源事实记录。

## 后续迁移单元与 Core 审查

本轮运行代码只新增独立探针，没有触及正式 AltoBoss 公共能力调用；因此不迁移未修改的旧 MoP 职责，不调整其最低 Core 要求，不更新为已接入 Forever。非发布探针自有保存、报告窗口和中英文诊断资源，不创建业务页面、账号入口或跨插件服务；CAP-001 至 CAP-011 对本次探针无业务接入变化。

进入正式业务实施时以当时已实现且验证满足需求的 Core 能力重新固定基线。目前已检查 `CoreRequirements.lua` 与[API13 接入记录](Core-API13-完整接入.md)：正式 AltoBoss 使用 API13、语言／角色／输入／统一页面／入口／清理／等级过滤等公开能力；当前 MoP 日历功能另依赖 `calendar-day-query:1`。Forever 首批不能机械要求尚未使用的 MoP 日历、节日队列或目标功能。

需要按完整职责切分的旧实现已定位：

| 职责单元 | 当前入口／规则 | 后续目标归属 |
| --- | --- | --- |
| 原生副本与锁定采集 | `InstanceLockouts.lua` 的 `GetInstanceInfo`／`GetSavedInstanceInfo`／事件处理 | 已支持 MoP 规则收拢到 `Mists/`；Forever 只放目标实测 API 与事件；稳定快照接口按需放 `Common/` |
| 运行／首领完成与重置 | `DungeonRuns.lua` 的普通难度、30 分钟展示过期、GUID 拆解，以及副本锁定到期；`InstanceLockouts.lua` 击杀信号 | 这些规则不能推定跨目标稳定。分别保留 MoP 行为与建立本服已证明规则 |
| 静态副本／首领与节日 | `DungeonBossCatalog.lua`、`TargetCatalog.lua`、`HolidayBoss.lua` 及 `Mists/Calendar.lua` | MoP 目录归 MoP；本服目录由真实样本增量建立，节日不属于首批默认范围 |
| 页面、入口、设置与快照 | `LockoutsPage.lua`／`AccountPage.lua`／`CoreIntegration.lua`／`Settings.lua` | 可复用的布局与投影需先明确输入契约；窗口、入口、语言、角色身份继续消费 Core |

正式迁移还须同步 TOC／间接加载、构建、独立 Forever SavedVariables、旧包覆盖保留旧文件测试；共享变更回归 MoP，分别记录离线与实机。现在不预建空目标服务、业务数据库或占位页面。

## 本轮验证与状态

2026-10-23 执行：

```powershell
lua _NonRelease/YiboAltoBossForeverProbe/Tests/Smoke.lua
.\Tools\Test-LuaSyntax.ps1 -ProjectRoot .\_NonRelease -Addon YiboAltoBossForeverProbe
```

结果：**143 项检查、2 个 TOC Lua 文件语法通过**。模拟覆盖原始结果、数量与历史上限、事件合并、停止与跨加载生命周期、schema／目标保护、中英文 key 与参数。正式插件只增加本文档，未修改其运行代码；这不触发 MoP 运行迁移或声称原插件重新验收。

| 状态 | 结果 |
| --- | --- |
| 取证工具代码完成 | 是，0.1.0 |
| 取证工具离线通过 | 是，143 项及 2 文件语法 |
| 客户端探针通过 | 待集中测试 |
| AltoBoss Forever 业务代码完成 | 否，等待首批真实业务证据 |
| AltoBoss Forever 可发布／已发布 | 否，未建立正式目标包与发布范围 |
