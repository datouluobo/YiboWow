# YiboAltoBoss 更新日志 / Changelog

## v2.1.1

### 中文

- 恢复账号页的“行动”和“位面”信息列及其真实数据、刷新预测和位置悬停详情。
- 修复账号页切换布局后窗口右侧、底部出现多余留白的问题。
- 修正页面自然尺寸计算，使窗口尺寸与 Boss 行、角色列的实际内容一致。

### English

- Restored the account page's Action and Phase columns with live data, respawn predictions, and location hover details.
- Fixed excessive right and bottom whitespace after switching the account page layout.
- Corrected natural-size metrics so the window matches the actual boss rows and character columns.

## v2.0

> 依赖：需要安装并启用 **YiboCore API v5**。<br>
> Requirement: Requires **YiboCore API v5** to be installed and enabled.

### 中文

- 接入 YiboCore 单角色缓存删除契约，只清理目标角色的 `knownChars` 与 Boss 角色快照。
- 角色缓存删除入口统一收口到 Core 角色档案；停用 AltoBoss 原有批量清理入口。
- 账号共享位面、刷新历史、目标和显示设置不会随角色删除。
- 已升级为 YiboCore API v5；继续使用统一账号视图、角色目录、设置和可选入口生命周期，Boss 业务数据仍保留在本插件。
- 保持 `YiboAltoBossDB` 对 Boss、位面、刷新样本、自定义目标和显示配置的所有权。
- 正式页面与入口悬停预览复用同一 Boss 行渲染和角色准入逻辑。
- 完善四天神击杀记录的战斗日志记录、周锁定恢复与手动修正命令。

### English

- Integrated YiboCore's single-character cache deletion contract. Only the selected character's `knownChars` and boss snapshots are removed.
- Consolidated character-cache deletion under Core's character directory and retired AltoBoss's former bulk-cleanup entry point.
- Shared account data, including phase observations, respawn history, custom targets, and display settings, is preserved when a character is deleted.
- Upgraded to YiboCore API v5 while retaining the unified account view, character directory, settings, and optional-entry lifecycle; boss data remains owned by this addon.
- Kept `YiboAltoBossDB` as the owner of boss, phase, respawn-sample, custom-target, and display data.
- The main page and entry hover preview now reuse the same boss-row renderer and character eligibility rules.
- Improved Four Celestials kill tracking with combat-log recording, weekly-lock recovery, and manual correction commands.
