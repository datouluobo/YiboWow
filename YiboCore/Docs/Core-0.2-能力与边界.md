# YiboCore 0.2：角色档案与账号视图

`YiboCore 0.2.0` 是 Yibo 系列插件的共享运行时、通用角色档案和统一账号视图框架。当前 API 为 v2。

## 定位

Core 让多个插件围绕同一批角色、同一窗口和同一套展示偏好工作；它不解释任何业务状态。

```toc
## RequiredDeps: YiboCore
## SavedVariables: YiboNewAddonDB
```

## Core 保存的数据

`YiboCoreDB` 保存角色身份和跨业务复用的事实快照：角色 GUID、名称、服务器、职业、种族、阵营、等级、公会、金钱、已知货币、地点、装等、专精、专业、各类信息的采集时间及 `known / unavailable / not-yet-scanned` 可用性状态。

未知或当前客户端不可读取的值不得以 `0` 替代。Core 会在登录、进入世界以及相关角色事件发生后增量刷新；窗口打开不会触发全量扫描。

任务、Boss、坐骑、路线、收藏、成就及其解释逻辑仍由对应插件保存在自身 SavedVariables 中。

## 账号视图与入口

Core 创建唯一的默认小地图入口，并在存在 `LibDataBroker-1.1` 时额外注册一个统一 Broker 数据源。两者左键均打开账号窗口，右键打开 Core 设置。窗口位置、大小、小地图入口位置、角色排序与显示范围均保存于 Core。业务插件不得再创建自己的 Broker、小地图入口、账号窗口壳或展示偏好数据库。

窗口提供概览、角色档案、业务页面导航、角色隐藏、页面显示/隐藏、字段显示/隐藏及窗口位置持久化。进入设置后，左侧导航会切换为设置目录：通用设置与每个已注册业务插件各占一个项目；右侧仅显示当前项目的配置。设置项过多时使用静态滚动，不应挤出窗口。

Broker 由第三方显示插件消费，`LibDataBroker-1.1` 没有通用注销协议。Core 的 Broker 开关决定下次重载时是否注册 Core 与业务 Broker 数据源；已注册的数据源会保留至重载界面。

## 页面注册

```lua
YiboCore.AccountView:RegisterPage("YiboNewAddon", {
    id = "new-addon",
    title = "业务页面",
    order = 30,
    defaultEnabled = true,
    settings = {
        title = "业务页面",
        description = "面向玩家的简短说明。",
        openLabel = "打开详细设置",
        OpenAddonSettings = function()
            -- 仅在存在插件专属配置窗口时提供；业务设置仍由插件自己保存。
        end,
    },
    fields = {
        { id = "status", title = "状态", defaultVisible = true },
    },
    Create = function(parent, context)
        -- 在 parent 中创建一次本插件的布局
    end,
    Refresh = function(instance, context)
        -- context.characters 是已过滤的角色；context.fields 是可见字段
    end,
    GetSummary = function(characters)
        return "可行动角色 2"
    end,
    GetActions = function(characters)
        return {
            { priority = 2, title = "法师-服务器", text = "可接取下一任务" },
        }
    end,
})
```

`Create` 与 `Refresh` 的布局、状态文案、Tooltip 和点击动作属于业务插件；窗口壳、角色范围和显示偏好属于 Core。插件不应写入 `YiboCoreDB`，也不得依赖其内部 table 结构。

`settings` 为可选元数据。Core 自动呈现页面开关、独立入口模式、主表字段和预览字段；只有业务专属设置才应通过 `OpenAddonSettings` 交回插件处理。预览列可继续由插件的 `GetPreviewFields` / `SetPreviewFieldVisible` 保存，Core 只负责统一展示。

页面字段 ID 必须唯一。Core 会隔离页面创建和刷新错误并在窗口内显示失败信息；业务插件可调用 `YiboCore.AccountView:NotifyPageChanged(pageID)` 请求刷新，卸载时调用 `UnregisterPage(pageID)`。

## 公共 API

```lua
YiboCore:CheckAPIVersion(2)
YiboCore.Characters:GetCurrent()
YiboCore.Characters:GetAll()
YiboCore.Profile:Get(characterID)
YiboCore.Profile:RegisterCollector(name, callback, events)
YiboCore.AccountView:RegisterPage(addonName, definition)
YiboCore.AccountView:Toggle("page-id")
```

当前能力名：`runtime`、`events`、`migrations`、`database`、`characters`、`character-profile`、`account-view`、`account-entry`、`level-filter`。

## 命令

|命令|用途|
|-|-|
|`/yco`|打开或关闭账号总览|
|`/yco settings`|打开账号视图设置|
|`/yco status`|显示版本与运行状态|
|`/yco characters`|输出已记录角色|
|`/yco addons`|输出已注册插件|

`/yco` 是 Core 唯一正式 Slash 命令。
