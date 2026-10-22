# YiboCore Changelog / 近期更新

## 1.12.8 — 日历查询保护（2026-10-22）

- API13新增 `calendar-day-query:1`，提供服务器当天日历快照与异常多年月份基准校正；无效日期、读取失败及部分数据保持未知。
- Todo1.2.4和AltoBoss2.8.3配套接入；活动规则与完成存档继续由业务插件管理。
- 离线回归通过；2021年异常来源仍待复现观察，完整结束边界及安装包客户端验收保留待验。包在本地生成，渠道发布另行记录。

English: Adds calendar-day-query:1 on API13 to validate realm dates and repair stale multi-year calendar anchors. Used by Todo 1.2.4 and AltoBoss 2.8.3. The original source of the stale anchor remains under observation.

## 1.12.7 — 业务入口设置路由（2026-10-18）

- 业务 Broker、小地图及内置信息条入口右键直接打开对应业务页面的设置项；Core 入口继续打开“显示与入口”。
- 公共 API 保持 13，未增加业务插件依赖。

## 1.12.6 — 统一矩阵预算（2026-10-16）

- 提供 `account-surface-budget:2`：按最终窗口高度统一计算滚动槽与可用列宽，完整自然宽度优先，达到屏幕安全边界后才分页；兼容既有 v1 页面。
- 主窗口与入口悬停共用尺寸声明、宽度精度和分页基础设施；六个业务插件已接入。
- 相关离线回归通过；用户已确认本轮实机检查无问题。当前仅更新工作树版本，尚未提交或打包发布。

## 1.12.5 / API13 — 2026-10-16

- 发布 character-cleanup:2，持久记录动态缓存所有者，保留禁用期间待清理历史。
- Delete提供deletedAt／deletionID／replay上下文；旧两参数回调继续兼容。Builds1.5.0使用该能力处理延后回放与新观察保留。
- 仅发布该项通用清理能力；API13及现有业务数据归属保持该提交基线。契约见 Docs/API-v13-角色清理v2.md。


## 未发布 — 货币数据归属迁移（2026-10-15）

- 停止货币采集、CurrencyCatalog及静态金币字段；旧economy／economy-items与profile投影冻结保留，Currency0.9.1工作树接管新采集和存储。
- 新增character-archive-providers:1，档案经通用Provider批量读取业务字段，缺失／冲突／异常隔离，静态字段兼容。
- character-cleanup:2持久化动态所有者，禁用期间pending记录不被软上限裁掉；Delete第三参数区分直接删除与旧墓碑回放，旧消费者兼容。
- 配套版本与离线／客户端验证边界见Currency货币数据归属迁移记录；未清理玩家旧数据，客户端待验收。


## 1.12.2 · API13 · 2026-10-14

- 新增兼容的 business-item-actions:3：Bind.compactTooltip 按全局操作模式提供简短双语提示，默认保留既有提示。AltoBoss 2.6.1 副本格已接入。
- Added opt-in compact target-action hints; existing consumers keep their default behavior.
- 静态语法与语言检查通过；本次未运行自动化测试，客户端交互及英文验收待完成。

## 1.12.0 · API v13 · 2026-10-12

### 中文

- 共用单选／多选下拉互斥展开；内部子菜单保留父菜单，关闭父菜单或隐藏控件时同步关闭子菜单。
- 新增中英文界面，支持跟随客户端、中文或 English，重载后生效。
- 内置 LDB 与信息条，小地图、外部 Broker、内置信息条可独立开关。
- 信息条支持外框、背景颜色、透明度、图标大小与间距设置，以及拖拽调序。
- 优化设置导航和控件布局，精简说明；业务插件每行显示，角色筛选使用统一输入框样式。
- 统一帮助页与关于页高度；安装包名称标注 API 版本，旧包自动归档。
- 包含 `business-item-actions:2`，改进项目添加按钮的悬停交互与位置。

语言切换控制 Core 与已适配插件的界面；游戏动态名称跟随客户端。真实英文客户端及部分实机验收仍待完成。

### English

- Shared single-select and multi-select dropdowns now close other open menus. Nested menus retain their parent and close when the parent menu or source control is hidden.
- Added Chinese and English UI options: follow the client, Chinese, or English. Changes take effect after reloading.
- Bundled LDB and added a built-in bar, with separate toggles for minimap, external Broker, and built-in bar entries.
- Added bar border, background color, opacity, icon size and spacing settings, plus drag-and-drop reordering.
- Refined settings navigation and control layouts, shortened descriptions, and standardized plugin rows and character filter inputs.
- Matched Help and About window heights. Package names now include the API version, and previous packages are archived automatically.
- Included `business-item-actions:2`, improving hover behavior and placement of item action buttons.

Language selection applies to Core and adapted plugins. Dynamic game names follow the client language. Testing on a real English client and some in-game checks remain pending.

## 1.11.0 · API v12 · 2026-10-11

### 中文

- 新增统一项目添加菜单与可配置手势，供业务插件接入目标添加操作。
- 添加按钮悬停显示，已加入项目使用金色角标；支持再次使用手势取消目标。
- 已加入状态改用游戏纹理，修复部分字体下勾选符号显示为方块的问题。

### English

- Added a shared item action menu and configurable gestures for plugins that support adding goals.
- Action buttons appear on hover, while added items show a gold corner marker. Repeating the gesture removes the corresponding goal.
- Replaced the added-state checkmark with a game texture to fix missing glyphs with some fonts.

## 1.10.0 · API v11 · 2026-10-09–10

本节记录开发阶段增量，不代表独立渠道发布。

This section covers development changes, not a separate channel release.

### 中文

- 新增多来源能力注册与发现，支持业务插件按公开契约聚合数据。
- 新增角色筛选变化通知，让关联视图及时更新。
- 改进页面与悬停的可用高度计算。
- 新增轻量角色身份查询，减少高频查询复制完整角色数据的开销。

### English

- Added provider registration and discovery so plugins can aggregate data through public contracts.
- Added character admission change notifications to keep related views updated.
- Improved available-height calculation for pages and hover previews.
- Added lightweight character identity queries to reduce full-data copying during frequent lookups.

## 1.9.0 · API v10 · 2026-10-08

包含 1.8.0 / API v9 的更新；1.8.0 未独立发布。

Includes the 1.8.0 / API v9 changes; 1.8.0 was not released separately.

### 中文

- 新增页面首次打开提示，将较长说明集中到帮助页。
- 新增业务服务注册、版本发现与隔离调用能力。
- 合并同帧页面刷新，减少重复更新。
- 优化物品信息加载，同一物品共享请求，仅在有请求时轮询。

### English

- Added first-open page hints and moved longer explanations to Help.
- Added business service registration, version discovery, and isolated calls.
- Coalesced page refreshes within the same frame to reduce repeated updates.
- Improved item loading by sharing requests for the same item and polling only while requests are pending.

完整历史 / Full history: [CHANGELOG.md](CHANGELOG.md).
