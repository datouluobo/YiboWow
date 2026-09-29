# YiboCore API v6 业务插件增量接入指南

> 适用版本：YiboCore `1.x`，Public API v6。
>
> 本文只说明 v6 相对 [API v5 业务插件接入指南](API-v5-业务插件接入指南.md) 的增量。页面、入口、矩阵、事件和数据领域的 v5 约束继续有效。

## 1. v6 新增的稳定接入点

v6 新增独立设置面板注册：

```lua
Core:RegisterSettingsPanel("YiboExample", {
    id = "YiboExample",
    title = "示例设置",
    description = "只放业务设置与数据/缓存操作。",
    CreateSettingsPanel = function(parent, host)
        -- 创建业务控件；窗口壳、导航、滚动与关闭操作由 Core 管理。
    end,
})
```

`RegisterSettingsPanel` 与 v5 的 `AccountView:RegisterPage`、`Entry:RegisterBusinessEntry` 是并列接口，不会替代或隐式创建后两者：

| 需求 | 接口 |
|---|---|
| 账号业务页面、字段和悬停投影 | `AccountView:RegisterPage` |
| Core 管理的 Broker/小地图入口 | `Entry:RegisterBusinessEntry` |
| 统一设置工作台中的业务设置区 | `Core:RegisterSettingsPanel` |
| 删除单角色缓存时清理业务快照 | `CharacterCleanup:RegisterOwner` |

设置面板按插件技术名字母序排列。业务设置页不得重复角色排序、页面/入口显示、主表字段或悬停字段；这些由 Core 的通用页面保存和渲染。

## 2. 同一范围与角色顺序

业务页面的 `Create` / `Refresh` 会收到 Core 构造的 context。插件必须以 `context.characters` 作为唯一的页面角色切片：

```lua
local function BuildScope(context)
    local ids = {}
    for index, character in ipairs(context.characters or {}) do
        ids[index] = character.id
    end
    return { mode = "characters", characterIDs = ids }
end
```

Core 已在构造 context 时依次应用：账号隐藏规则、业务角色准入、等级过滤、服务器范围、统一角色排序，以及悬停时最多 20 名角色的投影。业务插件不得再次排序或从 `Characters:GetAll()` 重建另一份范围。

- `context.scope` 是页面当前范围 ID，例如 `realm:<realm>` 或 `all`。
- `context.scopeDefinition` 是可选范围定义。
- `context.characters` 才是过滤和排序后的最终角色列表；跨插件查询应从它构造显式 characterIDs。
- 主页面与悬停调用同一个业务查询函数，只传不同的 context，不维护第二套摘要数据。

后台任务没有页面 context 时，必须显式构造范围，不能读取其它页面的 `GetPageScope()` 来猜用户意图。

## 3. 公共接口与 Core 接入点的边界

- Core 注册回调只用于 UI 与生命周期接入，不自动成为其它业务插件的数据 API。
- 业务插件若向其它插件提供数据，必须拥有独立版本、能力、状态、只读结果和事件契约。
- 业务 API 版本不能用 `Core.API_VERSION` 代替；Core 也不代理或持久化业务查询结果。
- 可选业务提供者缺失时，消费者自行通过全局命名空间和业务 capability 降级，不向 Core 注册业务专用来源协议。

## 4. Vault / Mail 接入结论

现有 v6 已能支撑 YiboVault 与 YiboMail：

- `Characters` 提供稳定 characterID 与角色目录；
- `AccountView` 提供同一页面/悬停范围和排序后的角色列表；
- `Entry` 负责入口生命周期；
- `RegisterSettingsPanel` 负责业务设置；
- `CharacterCleanup` 负责角色级缓存删除；
- `Events` 可用于 Core 中性事实变化，但不承载 Vault/Mail 的业务变更事件。

因此本轮不增加 Core Capability。若后续出现可由三个以上业务域复用、且无法由现有通用注册接口表达的缺口，再单独提出向后兼容增量。
