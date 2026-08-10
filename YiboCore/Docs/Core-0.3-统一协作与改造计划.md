# YiboCore 0.3：统一协作约定与 Core 改造计划

> 本文是 Yibo 系列插件的长期协作约定，也是 **只改动 YiboCore** 的实施计划。
>
> 本轮不迁移、不修改任何业务插件；业务插件的数据、窗口、入口与 SavedVariables 均不在本计划的变更范围内。Core 完成并验证平台能力后，再由独立任务逐个接入业务插件。

## 1. 目标与非目标

### 目标

让多个 Yibo 业务插件围绕同一套账号浏览体验协作，同时保留各自领域的独立性：

1. 默认只有一个 YiboCore 入口，避免 Broker 和小地图入口泛滥。
2. 业务插件可声明、但不能自行管理独立快捷入口；入口由 Core 统一仲裁。
3. 同一业务在主窗口、Broker 和小地图中的角色范围、状态和行动完全一致。
4. Core 概览只帮助玩家找到下一件值得做的事，不演变为所有插件细节的拼盘。
5. 业务数据、业务规则、业务设置始终归业务插件所有。

### 非目标

- 不在本轮修改 `YiboAltoBoss`、`YiboQuestBlocker`、`YiboLegendary` 或 `YiboBeastPaths`。
- 不删除业务插件既有 Broker、小地图、独立窗口、Slash 命令或 SavedVariables。
- 不要求所有业务页面采用相同表格布局。
- 不让 Core 推导任务、Boss、路线、收藏或成就等业务结论。
- 不在 Core 中复制或缓存业务插件的原始数据。

## 2. 稳定边界

### 2.1 Core 的唯一职责

Core 是账号视图平台，拥有：

- 角色目录、角色范围、隐藏、排序和窗口偏好；
- 统一窗口壳、页面导航、概览、设置导航和静态滚动；
- 默认 Core Broker / 小地图入口；
- 已获用户启用的业务快捷入口的创建、定位、显隐和生命周期；
- 将业务页面的正式账号快照投影为悬停预览；
- 页面、入口及其全局标识符的注册和冲突检查。

Core 不拥有任何业务事实或解释逻辑。

### 2.2 业务插件的唯一职责

业务插件拥有：

- 自己的采集、业务快照、准入条件、规则与状态解释；
- 自己 SavedVariables 中的业务数据和 `settings.previewColumns`；
- 页面布局、行渲染、业务 Tooltip 和业务操作；
- 对 Core 概览提供有限数量、可点击跳转的行动项。

业务插件不得创建账号窗口壳、角色目录或自身的通用入口管理器；迁移后，即便出现独立快捷入口，也只能由 Core 创建和注销。

## 3. 入口与悬停协议

### 3.1 默认入口

只有 Core 默认拥有一个小地图入口，并在可用时拥有一个统一 LibDataBroker 数据源。

- 左键：打开账号总览。
- 右键：打开 Core 设置。
- 悬停：显示概览页面的账号预览；不只显示当前角色。

### 3.2 业务快捷入口

业务页面可注册 `entryId`、图标、标题和目标 `pageId`，但默认模式为 `none`。玩家可在该业务的 Core 设置内选择：

|模式|含义|
|-|-|
|`none`|不创建独立入口（默认）|
|`broker`|仅创建业务 Broker 快捷入口|
|`minimap`|仅创建业务小地图快捷入口|
|`both`|同时创建两种快捷入口|

Core 是所有这些入口的唯一实现者，负责点击、右键设置、位置持久化、显隐和刷新。每个 `entryId`、Broker 名称和小地图 Frame 名称必须在全局唯一；重复注册必须失败并给出明确诊断。

业务入口行为固定如下：

- 左键：打开统一框架中的目标业务页面；
- 右键：打开该业务在 Core 中的设置；
- 悬停：显示该业务正式账号页面的预览列投影。

### 3.3 悬停预览

悬停不是第二套文本摘要。Core 只承载与定位预览，业务页面必须复用主表的：

- 角色过滤与准入条件；
- 行渲染器、状态颜色、文字和图标含义；
- 任务、目标和行动判断。

预览只能按 `settings.previewColumns` 隐藏字段；不得改变状态计算，也不得包含无快照角色、调试信息、重复说明或装饰文本。预览字段应优先回答“哪个角色、现在能做什么、为什么”。

## 4. 主窗口协议

统一窗口包含三类页面：

1. **概览**：跨插件行动索引。每个插件只贡献少量高价值行动，点击后进入对应业务页面。
2. **角色档案**：Core 保存的中性角色事实，不包含业务结论。
3. **业务页面**：一个业务插件一个页面；可采用角色为行、角色为列或自定义布局。

概览的排序语义固定为：可立即行动、即将失效/错过、有阻塞、纯信息。Core 只排序和显示业务插件已给出的行动，不自行判断优先级。

为防止概览成为大杂烩，Core 应实施显示预算：单业务最多显示 3 条行动，概览总数最多显示 8 条；其余行动留在原业务页面中查看。

## 5. 注册契约

Core 0.3 将在不读取业务内部表结构的前提下，提供并校验以下契约。

```lua
YiboCore.AccountView:RegisterPage(addonName, {
    id = "yab-boss",             -- 全局唯一页面 ID
    title = "Boss 周常",
    order = 30,
    fields = { ... },
    previewEnabled = true,
    Create = function(parent, context) end,
    Refresh = function(instance, context) end,
    GetSummary = function(characters) end,
    GetActions = function(characters) end,
})

YiboCore.Entry:RegisterBusinessEntry(addonName, {
    id = "yab",                  -- 全局唯一入口 ID
    pageID = "yab-boss",
    text = "[Yibo] Boss 周常",
    icon = "...",
})
```

契约要求：

- `addonName` 必须已通过 `Core:RegisterAddon` 注册，且 API 版本兼容；
- `pageID` 只能绑定到同一 `addonName` 注册的页面；
- 入口不得抢占 Core 保留标识符（如 `YiboCore`）；
- `GetActions` 返回的行动必须带 `pageID` 或由 Core 可靠补齐目标页面；
- 行动包含稳定优先级、角色标识、简短标题和决策文本；
- 业务字段在页面内唯一，页面 ID、入口 ID 与实际 Broker 名称在全局唯一。

业务自己的 `GetPreviewFields` / `SetPreviewFieldVisible` 仍负责读取和保存 `settings.previewColumns`；Core 仅渲染和提供设置入口。

## 6. 仅 Core 的实施计划

### 阶段 A：冻结边界与兼容基线

- 将本文作为 0.3 设计基线，并在 README 中链接。
- 为现有 `RegisterPage`、`RegisterBusinessEntry` 写明兼容范围和弃用路径。
- 不修改现有注册 API 的调用方式，不要求业务插件立即升级。

验收：所有现有 Core 页面、默认入口和设置在未加载任何业务插件时保持可用。

### 阶段 B：建立中央注册与冲突诊断

改动仅限 `Runtime/Registry.lua`、`UI/AccountView.lua`、`UI/Entry.lua`：

- 将页面、入口、Broker 对象名和小地图 Frame 名称纳入统一登记；
- 校验页面归属、入口目标页面和保留名称；
- 遇到冲突不覆盖已有注册，返回具体原因并通过 `/yco status` 可诊断；
- 为页面卸载补齐关联入口的注销/隐藏路径。

验收：重复 `pageID`、`entryId`、错误 `pageID`、跨插件绑定均被拒绝，原有注册不受影响。

### 阶段 C：统一入口生命周期

改动仅限 `UI/Entry.lua` 与 Core 设置 UI：

- 将 Core 默认入口和业务快捷入口收敛为同一套入口状态机；
- 统一模式读取、位置存储、刷新、左键和右键行为；
- 将业务入口默认值固定为 `none`；
- 保留 LibDataBroker 无可靠注销协议的限制：关闭 Broker 后提示“重载界面后生效”，但小地图入口应即时隐藏。

验收：启用任一业务入口不会影响 Core 默认入口；模式切换不产生重复图标；位置按入口 ID 独立保存。

### 阶段 D：统一预览投影

改动仅限 `UI/AccountView.lua` 与 `UI/Entry.lua`：

- 明确 `ShowPreview(pageID)` 只接受已启用且支持预览的页面；
- 预览 context 与正式页面使用同一个 `GetVisibleCharacters()` 结果；
- 增加空预览、无合格角色、渲染失败的安全状态；
- 统一 Broker `OnEnter`、`OnTooltipShow`、小地图 `OnEnter` 的锚点与延迟关闭处理。

验收：同一业务的窗口与两类入口显示相同角色集合和业务状态；快速移入预览不会闪烁或错误关闭。

### 阶段 E：概览行动预算与跳转

改动仅限 `UI/AccountView.lua`：

- 标准化行动的默认字段和 `pageID` 补齐逻辑；
- 按优先级、插件排序和角色名排序；
- 执行“单业务 3 条、全局 8 条”的显示预算；
- 点击行动时可靠打开目标页，并在缺失/禁用目标页时安全降级。

验收：概览不显示超过预算的事项；行动点击始终落在正确页面；异常业务行动不会阻塞其它页面刷新。

### 阶段 F：设置与可观测性

改动仅限 `UI/AccountView.lua`、`Debug/Commands.lua`：

- 每个业务页面的设置统一显示页面开关、快捷入口模式、主表字段和预览字段；
- `/yco addons` 或 `/yco status` 输出页面、入口、模式、冲突和预览可用性；
- 记录业务回调失败的页面 ID、插件名和操作阶段，而不输出业务数据。

验收：玩家可在一个位置控制入口和字段；开发时可从 Core 命令定位注册冲突与回调故障。

### 阶段 G：Core 回归与发布门槛

只测试 Core 自身和模拟注册器，不修改真实子插件：

- 无业务页面、一个模拟页面、多个模拟页面；
- 页面/入口 ID 冲突与无效归属；
- Core Broker 存在与缺失；
- 小地图模式切换、拖拽位置、`/reload` 后持久化；
- 主窗口、业务预览、Broker 预览之间的角色范围一致性；
- 业务回调抛错时的页面隔离。

只有上述 Core 回归完成后，才单独立项迁移某一个业务插件。每次迁移只改一个插件及其与 Core 的接入代码，避免同时修改多个插件导致问题归因不清。

## 7. 变更边界清单

本计划实施时允许修改的路径：

```text
YiboCore/Runtime/Registry.lua
YiboCore/UI/AccountView.lua
YiboCore/UI/Entry.lua
YiboCore/Debug/Commands.lua
YiboCore/Docs/*
YiboCore/README.md
```

除非后续单独批准，以下路径不得在本计划内改动：

```text
YiboAltoBoss/**
YiboQuestBlocker/**
YiboLegendary/**
YiboBeastPaths/**
```

## 8. 业务插件后续接入清单（不属于本轮）

每个业务插件在自己的独立改造任务中完成：

1. 声明 `RequiredDeps: YiboCore`。
2. 保留自身业务 SavedVariables，注册页面与快照投影。
3. 将自身入口替换为由 Core 管理的可选快捷入口。
4. 将 Broker、小地图和主窗口悬停接到同一份业务行渲染逻辑。
5. 验证数据、行动和角色筛选在窗口与悬停中一致。

在未完成该插件自己的接入任务前，不应由 Core 为其编写特殊兼容代码。
