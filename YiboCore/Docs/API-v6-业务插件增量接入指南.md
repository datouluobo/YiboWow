# YiboCore API v6 业务插件增量接入指南

> 适用版本：YiboCore `1.x`，Public API v6。
>
> 本文只说明 v6 相对 [API v5 业务插件接入指南](API-v5-业务插件接入指南.md) 的增量。页面、入口、矩阵、事件和数据领域的 v5 约束继续有效。

> 2026-10-08 协作边界说明：新增或本次修改涉及的跨业务集成按仓库 AGENTS.md 通过 Core 注册与发现协作。Core 1.8.0 / API v9 工作树已提供 [最小 Service](API-v9-业务服务与刷新.md)，Mail／Vault／Currency 本轮接入。行动中心 [最小能力契约 v1](../../Docs/行动中心-最小能力契约-v1.md) 中的完整 Provider 等机制仍为草案；本文已有 UI 接口仍有效。

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
- 业务 API 版本不能用 `Core.API_VERSION` 代替；Core 的通用连接只负责注册、发现、调用边界与生命周期，不解释或持久化业务查询结果。
- 新增跨业务调用通过 Core 注册与发现的公开契约协作，缺失或不兼容时只影响对应增强；消费者不得直接绑定提供者全局实现对象。现有旧接口在本次涉及范围内渐进接入，具体最低版本见相关契约。

## 4. Vault / Mail 接入结论

现有 v6 已能支撑 YiboVault 与 YiboMail：

- `Characters` 提供稳定 characterID 与角色目录；
- `AccountView` 提供同一页面/悬停范围和排序后的角色列表；
- `Entry` 负责入口生命周期；
- `RegisterSettingsPanel` 负责业务设置；
- `CharacterCleanup` 负责角色级缓存删除；
- `Events` 是通用事实变化通知机制；业务事件须明确来源、负载和清理方式。行动中心的通用连接生命周期通知按新契约实施，不能假定 v6 已存在专门业务连接接口。

上述为 v6 阶段的 UI 接入范围，未增加业务连接 Capability。后续出现真实通用缺口时按仓库约定单独设计向后兼容增量；行动中心的连接草案不改变这些既有 UI 方法签名。

## 5. 多布局页面的字段与通用控件

2026-10-05 的向后兼容 UI 增量用于同一业务页面的多个标签或查看方式：

- 字段可提供 `group = "收件箱"`，Core“显示与入口”的主表字段菜单按组显示；未提供分组的页面继续使用原布局。
- 字段设置 `preview = false` 可排除悬停字段选项；预览回调仍须为全部字段提供明确布尔投影，避免其它布局的字段通过主表默认值进入预览。
- `defaultVisible = false` 同时适用于字段对象和 `context:GetFieldVisible("field-id")` 字符串查询；已有显隐配置优先。
- `Core.UITheme:CreateBusinessTabs(parent, definitions, onSelect)` 接收 `{id, title, width}` 定义列表，返回 `SetActive(id)` 与按 ID 索引的 `buttons`；业务插件拥有标签状态，Core 提供视觉与控件。
- `Core.UITheme:CreateDropdown(...)` 增加可选 `SetMenuPageSize(size)`，只对显式启用的菜单分页；`nil` 恢复完整菜单。关闭控件会关闭其弹出菜单，屏幕下缘空间不足时向上展开。

这些控件不保存业务浏览状态，不增加业务依赖，也不改变现有 API 版本。

## 6. 游戏图标选择器

2026-10-06 向后兼容增量：`Core:ShowIconPicker(config)` 打开由 Core 管理的单例选择窗口，返回 picker。config 可提供 `icon`（当前游戏纹理）、`autoTexture`、`autoCoords`（自动预览）与 `onConfirm(icon)`；icon=nil 表示自动图标。确认前仅修改窗口草稿，取消或 `Core:HideIconPicker()` 不触发回调。调用方拥有业务保存和过期编辑校验，Core 不保存角色或业务状态。`Core:IsBuiltinIcon(icon)` 检查本客户端枚举集合。

仅枚举游戏宏/物品图标，图标列表按需生成。没有可用枚举数据时提示，并允许确认自动图标。消费方按方法是否存在判断支持；缺失时提示同步更新 Core。新增 TOC 文件需要客户端完整重启。
