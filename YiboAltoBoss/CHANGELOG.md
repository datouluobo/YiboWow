# YiboAltoBoss 更新日志 / Changelog

## 未发布 — 自定义目标接入行动中心（2026-10-11）

- 自定义 NPC 纳入公开首领目录，可从角色状态格加入任务目标；Ctrl＋左键安全消费添加操作，普通左键保留击杀标记。
- 完成与周期恢复复用 AltoBoss 的击杀记录及 24 小时有效期；新增、改名、删除即时失效目录缓存。删除来源不删除用户目标与历史。
- CustomBossGoalsSpec 25 项实际模块检查通过，客户端待复测。

## 未发布 — 任务链性能修复（2026-10-10）

- 2026-10-10 性能修复：不变奖励／节日观察不刷新；目标查询复用有时效的账号投影与配置缓存，角色存在／等级读取使用 Core character-identity:1。缺少能力仅停止目标增强。

详见 [性能修复记录](../Docs/任务链-性能异常修复-2026-10-10.md)。

## 未发布 — v2.6.0 刷取目标协作（2026-10-10）

- 经 Core 提供 boss.target-catalog 与 action.todo / planned-targets，消费 TaskHub 的逐角色目标；业务增强要求 API11，基础追踪保留 API5。
- 目录明确地图／Journal／encounter 身份，补双语与缩写搜索别名；旧副本完整采集后分配持久业务键，未验证目录限制保存。
- 修正副本锁定采集第4返回值被当作首领 ID 的问题；在精确副本与难度目录内解析首领，按完整采集数量核验。
- 新增周常奖励观察、精确难度及指定首领／整本进度、日周失效与节日日历状态；查询只读，源变化合并通知。
- 自动显示计划与手动展示取并集；主表与悬停使用同一目标进度，关闭开关／暂停仅撤下自动来源。136项联动检查通过，客户端待验收。

## 未发布 — 请求与刷新（2026-10-08）

- 副本信息响应不再回发 RequestRaidInfo；主动请求合并、有限超时，无关系统消息忽略。
- 锁定实质变化及首次成功扫描才通知；PersistDB 避免重复整库迁移。
- 节日排队延迟确认仅在状态变化时通知。


## v2.5.1

### 中文

- 修复节日 Boss 排队后再次点击行动按钮无法实际取消排队的问题。

### English

- Fixed the holiday Boss action button failing to leave the Dungeon Finder queue when clicked again.

## v2.5

### 中文

- 新增跨角色副本锁定页，支持按资料片浏览团队副本与五人副本的锁定状态。
- 可在设置中固定悬停预览副本，并查看角色副本锁定、首领击杀及副本进入统计。
- 增加普通五人副本每小时进入次数记录与可配置上限。
- Boss 与副本页面共用窗口标签，记住上次查看页面，并分别按页面内容计算尺寸。

### English

- Added a cross-character instance lockout page with raid and dungeon views grouped by expansion.
- Added configurable pinned instances for hover previews, with lockout, boss-kill, and run-history details.
- Added per-hour entry tracking and a configurable limit for normal five-player dungeons.
- Added shared Boss and instance tabs, persisted page selection, and page-specific window sizing.

## v2.4.1

### 中文

1. 修复节日 Boss 击杀记录与历史状态回填。
2. 修复职责选择、刷新和 Tooltip 显示。
3. 优化节日 Boss 状态与可排队按钮。
4. 修复点击加入或取消排队后按钮状态不会立即刷新的问题。

### English

1. Fixed holiday Boss kill records and historical status backfill.
2. Fixed role selection, refresh behavior, and tooltip display.
3. Improved holiday Boss status labels and the queue-ready button.
4. Fixed the queue button not refreshing immediately after joining or leaving.

## v2.4

### 中文

- 新增节日 Boss 目录；美酒节开放期间自动显示科林·烈酒，后续节日目标可按同一目录扩展。
- 节日 Boss 状态按服务器日追踪，支持每日任务、副本完成奖励和明确标注的人工标记。
- 行动格可直接排入或取消节日副本队列，并显示客户端返回的不可排原因；“位面 / 职责”格显示当前已选职责。
- 新增首领追踪业务设置“节日 Boss”，默认开启且可持久关闭。
- Todo 不再维护节日 Boss 专属目录、矩阵列和探针，保留通用特殊活动与暗月马戏团逻辑。

### English

- Added a seasonal-Boss catalog. Coren Direbrew appears automatically during Brewfest, and future holiday targets can use the same catalog.
- Seasonal completion is tracked per server day from daily quests, LFG completion rewards, and explicitly labeled manual marks.
- The Action field can join or leave the seasonal queue and reports client-provided eligibility failures; the “Phase / Role” field shows the selected LFG roles.
- Added a persistent, default-on “Holiday Boss” option in Boss Tracker settings.
- Todo no longer owns seasonal-Boss-specific catalog, matrix, or probe behavior while retaining its shared special-activity and Darkmoon Faire support.

## v2.3

### 中文

- 账号矩阵新增“角色为行 / 角色为列”方向切换，并由 Core 统一保存设置与刷新页面。
- 转置视图按 Boss、行动、位面和同一角色列切片计算宽度；切换后立即重排并在必要时分页。
- 角色列按当前可见角色名在四至六字间自适应；跨服查看时服务器名显示为第二行，且不会覆盖相邻列。

### English

- Added a Core-managed “characters as rows / characters as columns” matrix direction setting.
- The transposed view measures Boss, Action, Phase, and one consistent character-column slice together; it reflows immediately and paginates only when needed.
- Character columns now adapt to visible names from four to six CJK glyphs. In the all-realms scope, realm names appear on a second line without overlapping adjacent columns.

## v2.2.1

### 中文

- 首领追踪的 Broker 与小地图悬停预览现在由 YiboCore 统一处理自动关闭。
- 修复复杂 Boss 矩阵的滚动单元格可能让鼠标离开预览后仍被误判为停留在窗口内的问题。
- 右键业务入口可直接进入首领追踪设置页，避免偶发的空白设置内容。

### English

- Boss Tracker Broker and minimap previews now use YiboCore's unified automatic-close behavior.
- Fixed interactive Boss matrix cells being able to misreport the cursor as still inside a preview after it had visibly left.
- Right-clicking a business entry now opens Boss Tracker settings directly, avoiding occasional blank settings content.

## v2.2

### 中文

- 自定义目标支持直接添加当前选中的 NPC，并显示客户端本地化名称与 NPC ID。
- 按 ID 添加的自定义目标在首次选中对应 NPC 时自动补全名称，并刷新矩阵和设置页。
- 自定义目标的击杀标记保存 24 小时过期时间；当前角色、宠物或载具的战斗死亡证据会同步更新矩阵状态。

### English

- Custom targets can be added from the current NPC target and show the client-localized name with the NPC ID.
- ID-only custom targets fill in their name when first targeted, then refresh the matrix and settings view.
- Custom-target kill marks carry a 24-hour expiry; player, pet, and vehicle combat death evidence now updates the matrix status.

## v2.1.2

### 中文

- 缩窄角色列宽、减少分组间距。
- 切换 AltoBoss 设置页时确保面板正确显示。

### English

- Narrowed character columns and reduced group spacing.
- Ensured the AltoBoss settings panel displays correctly when switching pages.

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
