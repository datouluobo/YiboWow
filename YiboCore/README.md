# YiboCore

Yibo WoW 插件的共享运行时、角色档案与账号视图框架。

当前版本 `0.2.0` 提供：

- API 版本与插件注册
- 能力查询与 Core 内部事件
- `YiboCoreDB` 的 Schema 版本和迁移
- 统一角色身份、旧角色键别名与导入接口
- 通用角色档案：阵营、种族、公会、金钱、已知货币、地点、装等、专精、专业与数据可用性
- 统一账号视图、角色目录、页面/字段可见性设置
- Core 统一的小地图与可选 LibDataBroker 入口
- 等级表达式解析
- 调试与窗口命令：`/yco`、`/yco status`、`/yco characters`、`/yco addons`

Core 不保存任务、Boss、收藏等业务状态，也不接管业务插件的 SavedVariables；插件只向账号视图注册自己的页面、字段、摘要和交互。

完整的当前能力、数据归属、接入规范与非目标范围见：[Core 0.2 能力与边界](Docs/Core-0.2-能力与边界.md)。

多插件入口、悬停预览、主窗口分层及仅改 Core 的 0.3 演进计划见：[Core 0.3 统一协作与改造计划](Docs/Core-0.3-统一协作与改造计划.md)。

## Public API

```lua
local compatible = YiboCore:CheckAPIVersion(2)
local character = YiboCore.Characters:GetCurrent()
local allCharacters = YiboCore.Characters:GetAll()
local profile = YiboCore.Profile:Get(character.id)
YiboCore.AccountView:RegisterPage("YiboNewAddon", pageDefinition)
```

旧插件迁移时必须先使用 `OptionalDeps: YiboCore`，并保留自身 SavedVariables 与回退路径。
