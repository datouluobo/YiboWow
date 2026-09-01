# YiboCore API v5 业务插件接入指南

适用版本：YiboCore `1.x`，Public API v5。

## 1. 接入边界

Core 负责角色目录、账号窗口、入口生命周期，以及身份、经济、声望、专业、装备、地点和专精等中性角色事实。业务插件继续拥有任务、Boss、收藏、路线等业务规则与所有业务 SavedVariables。

业务页面继续通过 `AccountView:RegisterPage()` 注册，独立入口继续通过 `Entry:RegisterBusinessEntry()` 注册；这两个 API 的签名未变。不要因为升级 v5 而搬迁业务数据库，也不要向 `YiboCoreDB` 写入业务快照。

## 2. 最小注册方式

矩阵页面的表头、角色列头、行明暗交替与当前角色提示必须复用
`Core.UITheme` 的 `CreateMatrixHeader`、`SetMatrixHeader`、
`SetCharacterHeader`、`GetDataRowColor` 和 `CreateCurrentCharacterOutline`。
全服务器范围下，`SetCharacterHeader` 会按统一契约显示“角色名 / -服务器”双行列头；
单服务器范围保持单行。业务插件不得自行复制这些视觉状态。

```lua
local compatible = Core:CheckAPIVersion(5)
if not compatible then
    return nil, "需要 YiboCore API v5。"
end

local addon, err = Core:RegisterAddon("YiboExample", {
    version = "1.0",
    requiredAPI = 5,
})
```

`.toc` 必须继续声明 `## RequiredDeps: YiboCore`。正式 Slash 命令仍须是全工作区唯一的三个英文字母；不要为旧命令保留别名。

## 3. 读取 Core 中性事实

新代码按领域读取快照，而不是读取或修改 `YiboCoreDB`：

```lua
local snapshot = Core.DataDomains:Get(characterID, "economy")
local state = Core.DataDomains:GetState(characterID, "economy")
local money = snapshot and snapshot.data and snapshot.data.money
```

领域快照包含 `data`、`state`、`updatedAt`、`revision` 与 `schemaVersion`。`known` 表示本次采集成功；`not-yet-scanned`、`unavailable`、`stale` 和 `error` 都不是可当作零值使用的数据。插件必须保留自己的业务数据源，不得注册或写入 Core 已有领域。

## 4. 刷新协议

业务事实仍由业务插件的 WoW 事件采集并调用 `AccountView:NotifyPageChanged(pageID)`。仅当页面实际展示或依赖 Core 中性事实时，才订阅 `DATA_DOMAIN_UPDATED`：

```lua
Core.Events:Register("DATA_DOMAIN_UPDATED", addon, function(_, payload)
    if payload.domainID ~= "reputation" then return end
    Core.AccountView:NotifyPageChanged("example-page")
end)
```

`payload` 提供 `characterID`、`domainID`、`revision`、`changedKeys`、`reason`、`updatedAt` 和 `state`。监听器必须按 `domainID` 过滤，不能把任意领域变化当作业务快照更新，也不能在回调中再次采集或写入同一领域。

## 5. 兼容期与禁止项

### 发布兼容承诺

Public API v5 在整个 `1.x` 兼容期内只增不删：较新的 Core 必须继续满足声明 `requiredAPI = 5` 的旧子插件；新增能力必须先以可选方法或 Capability 暴露，不能改变既有注册、页面或入口调用的含义。只有需要移除或改变既有 v5 语义时才升级 API 主版本。

较新的子插件若开始依赖新的 API，必须把 `.toc` 的依赖保持为 `YiboCore`，并把 `requiredAPI` 提升到实际所需版本；旧 Core 会在初始化时给出“需要 API vN”的明确错误并停止注册，而不是半初始化。子插件不得仅根据 Core 的显示版本号猜测功能是否存在；可选能力使用 `Core.Capabilities` 或方法存在性检查后再调用。

`Profile:Get()`、`Profile:RegisterCollector()` 与 `CHARACTER_PROFILE_UPDATED` 在整个 `0.6.x` 仅用于旧插件兼容。所有新功能使用 `DataDomains` 和 `DATA_DOMAIN_UPDATED`。现有业务页不依赖 Core 中性事实时无需为了“使用新事件”而订阅它。

不得直接修改领域快照、直接触碰 `character.domains`，或从业务插件创建窗口壳、Broker、小地图拖拽和入口设置。窗口、悬停预览与入口由 Core 管理；业务插件只提供其数据、页面内容和业务设置。
