# YiboCore

Yibo WoW 插件的共享运行时、角色档案与账号视图框架。

当前版本 `1.1` 提供：

- API 版本与插件注册
- 能力查询与 Core 内部事件
- `YiboCoreDB` 的 Schema 版本和迁移
- 统一角色身份、旧角色键别名与导入接口
- 通用角色档案：阵营、种族、公会、金钱、已知货币、地点、装等、专精、专业与数据可用性
- 统一账号视图、角色目录、页面/字段可见性设置
- 统一角色排序：最近登录、名称、等级、自定义顺序、当前角色置顶与页面级覆盖
- 统一单角色缓存删除：当前角色保护、跨插件角色级清理、延迟重试与旧缓存防复活
- 页面级业务角色准入与持久化范围状态 context
- Core 统一的小地图与可选 LibDataBroker 入口
- 等级表达式解析
- 窗口命令：`/yco`、`/yco settings`

Core 不保存任务、Boss、收藏等业务状态，也不接管业务插件的 SavedVariables；插件只向账号视图注册自己的页面、字段、摘要和交互。

当前能力、数据归属、接入规范与多插件协作约定见：[Core 0.3 统一协作与改造计划](Docs/Core-0.3-统一协作与改造计划.md)。统一角色排序见：[统一角色排序实施计划](Docs/Core-统一角色排序实施计划.md)；缓存角色删除见：[缓存角色删除实施计划](Docs/Core-缓存角色删除实施计划.md)。历史更新记录见：[CHANGELOG.md](CHANGELOG.md)。

## Public API

```lua
local compatible = YiboCore:CheckAPIVersion(5)
local character = YiboCore.Characters:GetCurrent()
local allCharacters = YiboCore.Characters:GetAll()
local economy = YiboCore.DataDomains:Get(character.id, "economy")
YiboCore.AccountView:RegisterPage("YiboNewAddon", pageDefinition)
```

业务插件接入 API v5、领域读取和刷新协议见：[API v5 业务插件接入指南](Docs/API-v5-业务插件接入指南.md)。`Profile:Get()` 与 `CHARACTER_PROFILE_UPDATED` 仅为 0.6.x 的旧插件兼容层；新功能应读取 `DataDomains`，并在确有 Core 中性数据依赖时订阅 `DATA_DOMAIN_UPDATED`。

依赖 Core 的业务插件必须在 `.toc` 中声明 `## RequiredDeps: YiboCore`，并保留自身的业务 SavedVariables。Core 不接管业务数据；插件只注册页面、摘要和交互。

业务页面必须保持 `context.characters` 的输入顺序，不得在页面刷新阶段再次排列角色。Core 会依次应用隐藏、页面范围、业务准入和有效排序；悬停预览再从同一结果中截取前 20 名角色。

角色缓存只能在 Core 角色档案中逐个手动删除，当前登录角色不可删除。业务插件通过 `Core.CharacterCleanup:RegisterOwner` 清理自己的角色级快照，并必须保留账号共享数据。系统永久不提供批量删除、按时间自动清理、游戏角色存在性判断、转服角色合并或撤销删除。

## 发布打包

运行 `_NonRelease/Tools/Build-ReleasePackages.ps1` 会在仓库根目录 `Builds/` 生成两份带顶级 `YiboCore/` 目录的 zip：`*-curseforge.zip` 只包含 TOC、其加载的运行时代码与 `.tga` 纹理；`*-github.zip` 保留文档、截图和其它公开资源，但排除构建输出。`Builds/` 是 YiboWow 全仓库统一的安装包目录。
