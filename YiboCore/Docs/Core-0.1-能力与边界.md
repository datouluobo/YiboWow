# YiboCore 0.1：能力与边界（已由 0.2 取代）

> 此文档保留为 0.1 历史基线。当前实现和接入规范请使用 [Core 0.2 能力与边界](Core-0.2-能力与边界.md)。

本文描述当前已实现的 `YiboCore 0.1.0`，是后续新插件的接入基线。

## 定位

YiboCore 是 Yibo WoW 新插件的共享运行时与账号基础数据 Addon。

它提供稳定的角色身份、版本契约和少量无业务含义的通用工具；它不是一个把所有 Yibo 插件功能合并在一起的大型插件。

新插件从第一天开始采用强依赖：

```toc
## Dependencies: YiboCore
## SavedVariables: YiboNewAddonDB
```

## 当前能力

|能力|说明|主要 API|
|-|-|-|
|API 契约|声明并检查 Core API 版本。当前为 API v1。|`YiboCore:CheckAPIVersion(1)`|
|插件注册|记录已接入插件的名称、版本与所需 API。|`YiboCore:RegisterAddon(name, metadata)`|
|能力查询|查询某项 Core 能力及其版本。|`YiboCore:HasCapability(name, version)`|
|Core 数据库|维护带 Schema 版本和迁移历史的 `YiboCoreDB`。|Core 内部管理|
|角色身份|以角色 GUID 为优先 ID，记录角色基础资料。|`YiboCore.Characters:GetCurrent()`|
|角色查询|读取当前角色、指定角色或全部已记录角色。|`GetCurrent()`、`Get(id)`、`GetAll()`|
|旧键兼容|识别和导入旧插件的角色键，供未来迁移使用。|`ResolveLegacyKey()`、`ImportLegacyCharacter()`|
|等级表达式|解析和匹配等级过滤规则。|`YiboCore.LevelFilter:Compile(expr)`|
|默认值工具|递归填充默认值，避免共享 table 引用。|`YiboCore.Defaults:Apply(target, defaults)`|
|事件机制|Core 内部事件分发，当前用于生命周期和角色更新。|`YiboCore.Events:Register(...)`|
|调试命令|检查运行状态、角色与注册插件。|`/yibocore`、`/yc`|

当前已声明的能力名：

```text
runtime
events
migrations
database
characters
level-filter
```

## 角色模型

新插件不得自行以 `角色名-服务器` 或 `服务器-角色名` 作为永久业务键。

应使用：

```lua
local character = YiboCore.Characters:GetCurrent()
local characterID = character.id
```

当前角色记录包含：

```lua
{
    id = "Player-...", -- 角色 GUID；不可自行解析
    name = "角色名",
    realm = "服务器",
    class = "MAGE",
    level = 90,
    lastSeenAt = 0,
    seenOrder = 1,
}
```

`id` 必须被视为不透明标识。插件可以保存和比较它，但不能依赖其文本结构。

## 数据边界

### YiboCoreDB 管理

- Core 自己的 Schema 版本与迁移历史
- 角色基础身份与别名映射
- 角色首次出现顺序
- Core 自己的调试设置

### 每个插件自己的 SavedVariables 管理

- 功能业务数据
- 功能缓存
- 插件窗口状态和配置
- 插件专属过滤条件
- 插件专属小地图/Broker 配置

推荐结构：

```lua
YiboNewAddonDB = {
    settings = {},
    byCharacter = {
        [characterID] = {
            -- 新插件自己的业务数据
        },
    },
}
```

新插件不得直接写入 `YiboCoreDB`，也不得依赖其内部 table 结构。角色数据必须通过 `YiboCore.Characters` API 读取。

## 新插件最小接入模板

```lua
local Core = _G.YiboCore

local compatible = Core and Core:CheckAPIVersion(1)
if not compatible then
    return
end

Core:RegisterAddon("YiboNewAddon", {
    version = "0.1.0",
    requiredAPI = 1,
})

local currentCharacter = Core.Characters:GetCurrent()
local characterID = currentCharacter.id

YiboNewAddonDB = YiboNewAddonDB or {}
YiboNewAddonDB.byCharacter = YiboNewAddonDB.byCharacter or {}
YiboNewAddonDB.byCharacter[characterID] = YiboNewAddonDB.byCharacter[characterID] or {}
```

## 等级表达式

```lua
local filter, badToken = YiboCore.LevelFilter:Compile(">=85,90")
if not filter then
    print("无效规则: " .. badToken)
    return
end

if filter:Matches(currentCharacter.level) then
    -- 角色符合规则
end
```

支持：

```text
90
1-20
>=85
<=3,89,90
```

空字符串或 `0` 表示不过滤。

## 明确不属于 0.1 的范围

- Broker、LibDataBroker、LibDBIcon、小地图入口
- 通用设置界面、UI 控件库、主题系统
- Tooltip 工具
- 本地化框架
- 插件级 Profile / 数据库管理框架
- Retail/Mists 等跨客户端通用适配层
- 坐骑、任务、Boss、路线、收藏等任何业务数据
- 旧插件的主动接入或数据迁移

这些能力只有在至少两个新插件出现同一项真实需求后，才考虑扩展到 Core。

## 兼容性与迁移原则

- 新插件一律使用 `## Dependencies: YiboCore`。
- 当前不要求任何旧插件接入 Core。
- `ImportLegacyCharacter` 仅为未来迁移保留，不应被新插件调用。
- Core 的 API 变更应通过 `API_VERSION` 和能力版本表达，不应让消费者读取 Core 内部数据库。

## 调试命令

|命令|用途|
|-|-|
|`/yibocore status`|显示版本、API 版本和能力摘要|
|`/yibocore characters`|显示已登记角色|
|`/yibocore addons`|显示已注册插件|

`/yc` 是 `/yibocore` 的短命令。
