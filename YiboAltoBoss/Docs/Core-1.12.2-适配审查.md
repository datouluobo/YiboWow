# AltoBoss 2.6.1 对 Core 1.12.2 的适配审查

日期：2026-10-14。对象：当前工作区 AltoBoss 2.6.1、Core TOC 1.12.2 / API13，以及刚发布的同版本源码。此次为审查，没有修改运行代码、重新发布或将全部迁移记为完成。

## 结论

当前使用的公共接口与 Core API13 兼容；五人本功能及已覆盖的目标联动检查通过。完整公共能力迁移尚未完成，不能将“最低 API13”视为全能力接入证明。

## 已接入

| 范围 | 当前情况 |
|---|---|
| 基础初始化 | TOC RequiredDeps: YiboCore；CoreIntegration 检查 API13 / localization:1 / LockoutLocaleReady |
| 账号视图与入口 | AccountView 页面、角色范围、矩阵尺寸／分页、Entry.RegisterBusinessEntry 及统一工作台已复用 |
| 副本 TP 与历史设置 | 35 对 owner 语言资源；采用 UITheme pair/text/spacer，三个历史选项在工作台业务面板 |
| 主动添加 | GoalTargets 检查 API13 / business-item-actions:3；仅副本格启用 compactTooltip，Core 实现提供能力3 |
| DBM 补充 | 检查 events:1 / character-identity:1 与所需方法；经 Core Events 发布隔离事实，Core 不承接 DBM 业务 |
| 目标协作 | PlannedTargets 通过 Contracts、service/provider 与 Core 唯一角色标识协作；未发现直接读取其它业务 SavedVariables 的新协作 |

## 问题与剩余迁移

1. **Core 发布版本标识不一致，优先修复。** YiboCore.toc 为1.12.2，Bootstrap.lua:7 的 Core.VERSION 仍为1.12.1；GetVersion 与 About 页面会报告旧版本。能力3确实已注册，按API／能力检查的AltoBoss不会因此失效，但发布包和运行时版本显示不一致。应同步运行时版本并重新核对打包版本来源。
2. **角色名称格式化部分接入。** 目标行动部分调用 Characters:FormatName；LockoutsPage:218 直接取旧记录名称，Core.lua:2070 的 GetCharacterLabel 仍返回旧 displayName／键。Core短名与跨服显示规则不保证在所有视图一致，CAP-001应保持部分接入。
3. **公共输入未接入。** 工作台业务面板的 NPC／爆本上限等仍 CreateFrame(EditBox, InputBoxTemplate)，没有使用 Core.UITheme:CreateInput / basic-input:1。Core已提供适用能力，CAP-002仍待迁移。
4. **本地化仅部分完成。** 副本状态、TP、新历史设置已接入；注册字段、Boss页、其余设置和目录仍有中文硬编码，CoreIntegration 的插件名称也仍跟随 GetLocale。不能保证手动英语模式与英文客户端的全插件一致。
5. **旧独立设置窗口仍在源码。** 正常 Core 可用路径进入统一工作台，但 InitializeSettings 等还保留缺少Core时的旧窗口分支。与 RequiredDeps / API13 新基线不一致，CAP-004仍需收尾。
6. **能力台账有历史版本描述。** CAP-008等旧行仍提API12／基础API5，需要在实际迁移时统一当前状态与历史说明；追加记录不等于这些旧区域已经完成。

## 本次执行证据

- InstanceKillsSpec：无样本56项通过；带真实探针样本58项通过。包括独立采集、重复来源、DBM适配及部分语言与旧Core场景；不代表全部页面或真实客户端交互均已验收。
- BossGoalsSpec：19项通过。
- CustomBossGoalsSpec：25项通过（包含其前置BossGoals运行，计数不可简单相加为独立覆盖）。
- BossTargetsSpec：前置 ActionIntegrationSpec.lua:188 失败，错误为 Todo 配方提示返回资源key，未进入AltoBoss测试主体。
- ItemActionSettingsSpec：前置 GoalSourcesSpec.lua:154 provider-error 阻断，尚不能确认完整操作设置回归通过。

## 建议顺序

先修复Core版本标识；随后按CAP-001角色名称、CAP-002公共输入、CAP-004旧设置壳、CAP-009剩余界面语言逐项收尾。保留现有业务采集和数据所有权；每项迁移核对最低能力、缺失时提示与停止行为，并更新台账。实际DBM、计时启停、全局操作设置及中英文客户端仍待实机验收。

## 后续实施（2026-10-14）

上述问题已在工作树按Core API13收尾：版本标识、名称、输入、独立窗口和界面语言的适用代码已处理，客户端仍待验。以 [完整接入记录](Core-API13-完整接入.md) 为当前状态，本文件上文保留审查时结论。
