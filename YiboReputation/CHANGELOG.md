# YiboReputation 更新日志

## 1.7.2 — 统一矩阵预算（2026-10-16）

- 主矩阵接入 Core 统一滚动预算，移除按行数补槽的本地逻辑；按完整角色范围测量后使用 Core 切片。
- 最低配套 Core 1.12.6 / API13，并检查 `account-surface-budget:2` 及实际预算方法。
- 相关离线回归通过；用户已确认本轮实机检查无问题。当前仅更新工作树版本，尚未提交或打包发布。

## 1.7.1 — 声望数据归属迁移（2026-10-15）

- 声望目录、普通声望和好友度采集移入本插件，权威快照保存于 YiboReputationDB；主矩阵、监控预览和 action.targets 使用同一来源。
- 首次逐角色导入 Core 旧快照并保留时间和原始版本；重复导入不覆盖新采集，旧 Core 来源冻结保留。旧版本或无法解释的数据需重扫。
- 采集事件合并、失败保留旧负载并标记状态；接入角色 ID 变更和统一缓存删除，处理未加载期间的延后删除。
- 最低 Core 1.12.4 / API13；旧 Core 采集器存在时提示升级并停止初始化。新增 /yrp status、scan、migrate 诊断子命令。
- 迁移专项与独立悬停检查通过；真实客户端导入、双语及切号验收待完成。详见 Docs/声望数据归属迁移-实施与验收记录.md。
- 二次复查补齐空失败占位与缺失快照恢复、重复 ID 转换幂等，以及本地快照已就绪后的导入失败计数；原有 87 项加新增 39 项保留／重试／删除回归通过。

## 未发布 — YiboCore API 13 适配（2026-10-15）

- 最低 Core 要求提高至 API 13；显式检查语言、账号页、高度预算、声望数据域、事件、基础输入与角色名称能力。缺少能力时停止页面初始化并提示升级。
- 声望矩阵搜索改用 Core 标准输入；页面首次提示、矩阵状态、设置、目录和目标文本接入 Core Locale 中英文资源。
- 声望矩阵继续使用 Core 共享角色表头和名称格式化；声望目标单独检查 API 12 的操作、Provider 和角色身份能力。
- 声望快照数据所有权与迁移留待下一阶段；本轮不修改 Core 声望采集或存储。
- 静态语言检查通过；自动化与游戏内双语、入口和输入交互验收待完成。

## 未发布 — 声望目标（2026-10-10）

- 可从声望行添加指定角色的声望或已知友谊等级目标；状态依据声望所有者的角色快照。
- 缺少新鲜声望记录或等级无法识别时保持待确认，不推断为零级或未完成。需要 Core API v12 / `business-item-actions:1` 及兼容 TaskHub；客户端待验收。

## 未发布 — 监测预览（2026-10-08）

- 一次渲染共享每角色声望快照；静止悬停不再逐帧复制域或重建 Tooltip，跨列／重新渲染仍更新。
- 将监控列表说明改为首次打开提示，并提高最低 YiboCore API 要求至 v10。


## v1.5.2

- 修复当前阵营无法通过客户端 API 查询时，声望监控列表显示“未知声望 + ID”的问题；为蛮锤氏族和火金派熊猫人补充本地化名称回退。

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
