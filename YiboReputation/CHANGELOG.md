# YiboReputation 更新日志

## v1.5.1

- 修复声望之路监控列表的上移、下移和移除操作不会立即刷新的问题。
- 操作监控列表时仅刷新该列表区域，不再重建整个设置工作台。

## v1.3

- 统一普通声望与好友型声望的六阶颜色语义；好友型数据仍保持数值直显，完整关系名称仅在文字提示中显示。
- 修复满级好友度在旧客户端缺少普通声望等级时被误显示为未同步；吱吱等阡陌客 NPC 会保留有效好友度快照。
- 纳特·帕格保留游戏原生的“同伴”第二级名称，并与半山 NPC 的“熟人”按同一等级和颜色处理。
- 修复“纳特·帕格”这类好友型声望在旧客户端未被识别的问题；好友等级查询使用好友度 API 返回的 friendship ID。
- 旧版 Core 声望快照不会再被误作当前好友度数据：未重扫的角色显示“需重扫”，在该角色下次登录后自动以好友度 API 刷新。

# YiboReputation v1.2.1

- 保留“阡陌客”这类同时是原生标题行和真实声望的主声望；账号矩阵会显示其数值、星标和可展开的 NPC 好友度子项。
- 移除“熊猫人之谜 → 熊猫人阵营”的冗余分类层。

# YiboReputation v1.2.0

## 中文更新日志

### 优化与修复

- 优化并修复账号声望总览及悬停预览界面。
- 修复主窗口与悬停预览之间的 UI 状态残留问题。
- 修复悬停预览偶尔短暂显示滚动条的问题。
- 修复多个声望等级颜色显示不正确的问题，恢复按等级区分颜色。
- 修复阡陌客 NPC 好友度读取错误，正确显示“陌生人、熟人、哥们、朋友、好友、挚友”等等级。
- 修复好友度 API 返回值解析错误导致的声望数值和等级异常。

## English Changelog

### Improvements & Fixes

- Improved and fixed the account reputation overview and hover preview UI.
- Fixed stale UI state leaking between the main window and hover preview.
- Fixed a scrollbar briefly appearing in the hover preview after opening the main window.
- Fixed incorrect reputation level colors and restored distinct colors for each standing.
- Fixed Tillers NPC friendship data so levels such as Stranger, Acquaintance, Buddy, Friend, Good Friend, and Best Friend are displayed correctly.
- Fixed incorrect parsing of the friendship reputation API, which caused inaccurate reputation values and levels.
