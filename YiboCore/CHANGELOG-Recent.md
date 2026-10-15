# YiboCore Changelog / 近期更新

## 1.12.5 / API13 — 2026-10-16

- 发布 character-cleanup:2，持久记录动态缓存所有者，保留禁用期间待清理历史。
- Delete提供deletedAt／deletionID／replay上下文；旧两参数回调继续兼容。Builds1.5.0使用该能力处理延后回放与新观察保留。
- 仅发布该项通用清理能力；API13及现有业务数据归属保持该提交基线。契约见 Docs/API-v13-角色清理v2.md。


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
