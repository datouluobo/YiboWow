# 暗月周期修复 — 2026-10-18

状态：代码与自动化验证已完成，客户端待验收。

## 问题与行为

用户报告本月再次开放的暗月马戏团在 00:00 至 07:00 仍保留上次完成状态；截图完成证据为 10-09。旧周期键为 `YYYY-MM-1/2`，以月内第一个周日加四天划分，因此同月后续开放复用了同一个键，周四的切换还提前到了 00:00。

现以每轮周日 00:00、周四 07:00 的服务器时间戳生成 `darkmoon:<timestamp>`。活动是否开放仍由现有日历判定负责，周期键不推断活动已经开放。周日凌晨的新交付不会在 07:00 再清除；跨月不额外重置。旧键记录只在 completedAt（缺失时使用 observedAt）落入当前周期且不晚于当前时间时保留完成投影，历史数据不删除，新交付写入新键。

主视图、入口预览、精确目标与行动中心继续复用 Todo 的来源状态。Snapshot 现在纳入特殊活动的 nextChangeAt，在周四 07:00 自动失效并经现有 NotifyChanged 通知消费方。

## 验证

- 新增 `YiboTodo/Tests/DarkmoonCycleSmoke.lua`：修改前复现同月重开失败；修复后覆盖 10-09 → 10-18 的离线与当前角色、00:00、02:18、周日 07:00、周一、周四 06:59:59 / 07:00、周六关闭、跨月、有效旧记录保留、未来证据排除、服务器与本机日期不一致、账号快照自动刷新及精确目标／行动中心周期一致性。
- `YiboTaskHub/_NonRelease/Tests/TodoSourcesSpec.lua`：177 项通过。
- `Tools/Test-LuaSyntax.ps1 -Addon YiboTodo`：TOC 引用的 33 个 Lua 文件通过；新测试文件另经 Lua 5.1 语法检查。
- Todo 共十个 Smoke 中八个直接通过；`LegacyDailyProjectionSmoke.lua` 缺少 Core.Locale，`MonitoringSettingsSmoke.lua` 缺少 Core，均在 Settings.lua 的既有本地化调用处失败。使用 HEAD 版 Snapshot 运行前者仍在同一处失败；后者不加载本次修改的运行文件。本次未扩大修改这两个旧测试。
- 追加尝试 `TodoStateSyncSpec.lua`，在复用的 `GoalSourcesSpec.lua:154`（Vault 目标添加）报 provider-error；用 HEAD 版 Snapshot 与 SpecialActivity 替换加载后仍在同一处失败，未进入 Todo 状态同步检查。本次精确暗月目标与行动中心状态一致性另由新增专项覆盖。

## Core 公共能力复核

本次 diff 未新增或迁移 Core API 调用、玩家可见资源文案、注册信息、身份读取或跨业务插件绑定；继续通过原有 Snapshot、NotifyChanged 与 Provider 契约输出。业务重置归 Todo 所有，最低 Core API13 与能力检查不变。迁移台账无需更新。

## 客户端验收

1. 更新代码并 `/reload`，确认本轮有专业资格的角色恢复可做，上轮 10-09 的完成记录不再生效；对比主窗口、入口悬停和行动中心。
2. 凌晨交付一项并重载，确认其保持本轮已完成；周日 07:00 不再次清除。
3. 周四 07:00 前保留完成状态，跨界后保持在线也应自动恢复可做；确认主窗口与行动中心一致。

未替代客户端实测，未打包或发布。
