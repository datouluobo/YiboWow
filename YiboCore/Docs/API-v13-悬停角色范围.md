# API v13：悬停角色范围

2026-10-13，Core 1.12.1 工作树新增 `account-preview-characters:1`，API 保持13，旧 `account-view:2` 不变。

## 需求与职责

Mail 账号有超过20个有效角色。单服务器预览可以显示仓库角色，全部服务器却在 Core 截取前20名时丢失该角色。用户要求尽可能完整显示，少量行不出现无意义滚动。

Core 负责角色准入、服务器范围、排序与截取策略、屏幕安全边界及入口定位；业务页面负责内容高度和滚动呈现，不复制 Core 筛选逻辑。数据仍归业务所有，不涉及 Service、Provider 或业务存档读取。

## 公开契约

`AccountView:RegisterPage(addonName, definition)` 的可选字段 `previewCharacterLimit`：

- 省略：保持既有前20名默认值。
- `false`：保留全部满足准入条件的有效角色。
- 正数：向下取整后至少1名，按 Core 排序截取。

既有 `BuildContext(page, options)` 的 `options.characterLimit` 优先于页面声明；省略时使用页面声明，再使用20名默认值。`false` 同样表示不限。仅作用于业务页悬停；Core 角色档案和主窗口行为保持原状。它不绕过账号隐藏、页面准入、等级过滤或服务器范围，不改变角色顺序，也不向玩家暴露无快照角色。

数量不限不代表尺寸不限。Core 仍按屏幕安全区域与入口可用高度钳取窗口；页面必须提供实际高度及受限空间下可到达全部行的滚动。旧 `GetHoverMetrics` 的尺寸为整个窗口，须包含 `Theme.Geometry.titleBar` 和两侧 `shellBorder`；`GetSurfaceMetrics` 则使用内容尺寸，由 Core 加壳。

消费新字段前检查 API13 和 `account-preview-characters:1`。缺失时提示升级并停止依赖操作，不静默回退成截断列表。

## 接入与验证

YiboMail 1.2.13 显式声明 `previewCharacterLimit = false`，Bootstrap 检查能力。单服务器名称经 Core FormatName，以选中服务器为参考；全账号仍复用原角色目录和排序。它是用户本次要求完整查看的范围例外，其余插件的默认20名预览保持原行为。

`YiboMail/_NonRelease/Tests/WorkspaceSpec.lua` 覆盖真实 Core BuildContext 的24角色跨服务器筛选、末位仓库角色、默认20名／显式7名兼容，中英文1／4／18／24行含提醒与无提醒的实际 Theme 滚动判断，以及缺失能力时停止初始化。其它业务插件未作新字段接入审查；后续触及同类完整账号预览时按需接入，不要求一次性迁移。实机中英文、入口位置／UI缩放仍待验收。
