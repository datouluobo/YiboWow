# 主动添加目标集成检查

2026-10-26追加 `lua _NonRelease/TaskGoalIntegration/RaidProgressSpec.lua [zhCN|enUS] [auto|zh|en]`，四种语言组合各40项；覆盖现场成功事件、手动确认／取消／撤销、周期失效、来源生命周期及实际Hub确认UI。当前BossGoalEditorSpec为468项。离线通过及客户端待验范围见[SW取证与确认](../../Docs/行动中心-SW锁定取证与本周期确认.md)。

追加 `lua _NonRelease/TaskGoalIntegration/BossSearchIdentitySpec.lua [zhCN|enUS] [auto|zh|en]`，四种语言组合各33项，覆盖搜索焦点/输入法生命周期与TBC难度身份跨入口去重；前置BossGoalEditorSpec更新为458项。见[搜索与副本身份记录](../../Docs/行动中心-搜索焦点与副本身份一致性.md)。

2026-10-25 追加 `lua _NonRelease/TaskGoalIntegration/BossGoalEditorSpec.lua [zhCN|enUS] [auto|zh|en]`，四组语言组合各456项（包括新增资源配对），覆盖21个旧团本首次目录、SW六首领/基尔加丹、局部旧目录、手册ID适配、Hub内部选择保存、来源生命周期及覆盖残留；先运行BossGoalsSpec的19项夹具。实机待复测，见[实施记录](../../Docs/行动中心-副本首领范围修复-20261025.md)。

追加 `lua _NonRelease/TaskGoalIntegration/ClickActionsSpec.lua`，45 项安全图标契约检查；它先运行 GoalSourcesSpec 作为真实模块夹具，汇总计数不重复计算夹具。

在仓库根目录用 Lua5.1 运行 `GoalsSpec.lua`、`GoalSourcesSpec.lua`、`BossGoalsSpec.lua`、`GoalSurfacesSpec.lua` 及下列追加脚本（均以本目录完整相对路径传入 lua）。共356项（夹具重复执行不重复计数）。脚本独立进程运行，使用实际模块与受控游戏输入／Frame。无需安装为 AddOn，不创建游戏目录联接。

范围、来源边界与客户端待验收项见 [实施记录](../../Docs/行动中心-主动添加实施与验证.md)。

追加 `lua _NonRelease/TaskGoalIntegration/ItemActionSettingsSpec.lua`（30项）验证互斥方式、标记、战斗限制及旧设置迁移；`lua _NonRelease/TaskGoalIntegration/TodoStateSyncSpec.lua`（36项）验证专业观察通知、缓存失效、每日预计准备、图标描述一致及成功制作后滞后零冷却。两者复用 GoalSourcesSpec 夹具。

裁缝回归追加：TodoStateSync 验证 learned/craftable 已知但 cooldownKnown=false 时沿用来源准备状态；当前角色两种布在悬停分别显示，未知时亦不折叠。历史汇总计数以上述独立脚本本次输出为准。

追加 `lua _NonRelease/TaskGoalIntegration/EventGoalsSpec.lua`（17项），覆盖暗月午夜关闭、完成行保留边界、目标保留及下次恢复；复用 GoalSourcesSpec 的检查不重复计数。

追加 `lua _NonRelease/TaskGoalIntegration/CustomBossGoalsSpec.lua`（25项），加载实际 AltoBoss Core，覆盖自定义 NPC 目录变更、添加／取消、原有击杀操作、角色隔离、来源有效期到期恢复、单次完成及删除后保留目标；复用 BossGoalsSpec 的检查不重复计数。
