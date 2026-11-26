# YiboQuestBlocker 设计文档

> 魔兽世界怀旧服·熊猫人之谜 (5.5.4) 任务屏蔽管理器
>
> 作者：天堂暴风

---

## 1. 概述

### 1.1 目标

在其它插件已启用自动接受任务的情况下，强制自动过滤不接受指定的任务。

### 1.2 核心功能

| 功能 | 说明 |
|------|------|
| 任务拦截 | 包裹 `AcceptQuest` / `ConfirmAcceptQuest`，在接取前检查是否在屏蔽列表中 |
| 双层屏蔽 | 全局屏蔽（所有角色生效） + 个人屏蔽（仅当前角色） |
| 网格UI | 纵列任务、横列角色（含全局列），勾选框点击即屏蔽 |
| 手动添加 | 输入任务ID + 选择作用域（全局/当前角色） |
| 自动放弃 | 添加屏蔽时自动放弃当前任务日志中的该任务 |
| 任务列表 | 从任务日志读取，支持过滤器（日常/普通/隐藏已完成） |
| 等级过滤 | 按角色等级过滤哪些角色列显示（默认 0~90 级全部显示） |
| 角色排序 | 按名称/等级/登录顺序/屏蔽数排序角色列 |
| 统一入口 | 由 YiboCore 提供可选 Broker / 小地图入口，悬停显示同一账号视图预览 |
| 斜杠命令 | `/yqb` 打开 YiboCore 的“任务屏蔽”账号页 |
| 数据持久化 | 所有角色共享同一个 SavedVariables 文件 |

### 1.3 技术栈

- 语言: Lua 5.1 (WoW 内嵌)
- 框架: WoW Frame API (CreateFrame, BackdropTemplate)
- 核心依赖: YiboCore（API v5）
- 存储: SavedVariables (账号级共享)

---

## 2. 存储设计

### 2.1 文件路径

由于国服 5.5.4 客户端自动将 `## SavedVariables` 存到账号级目录：

```
WTF\Account\<账号名>\SavedVariables\YiboQuestBlockerDB.lua
```

不需要符号链接或额外的 `## SavedVariablesAccountWide` 指令。

### 2.2 TOC 声明

```
## Interface: 50504
## SavedVariables: YiboQuestBlockerDB
```

### 2.3 数据结构

```lua
YiboQuestBlockerDB = {
    schemaVersion = 2,

    -- 全局屏蔽列表（所有角色共享）
    globalBlocked = { [12345] = true },
    globalCache   = { [12345] = "熊猫人火锅" },

    -- 各角色个人屏蔽；键为 YiboCore characterID。
    -- 角色名、服务器、职业、等级与账号顺序均不在本插件重复保存。
    characterData = {
        ["Player-4512-005A28AA"] = {
            blocked      = { [67890] = true },
            cache        = { [67890] = "雷神岛巡逻" },
            _foldedBlocked = false,
            _foldedCurrent = false,
        },
    },

    -- 账号级过滤器偏好
    filters = {
        showDaily     = true,
        showNormal    = true,
        hideComplete  = true,
        reportChat    = true,
        autoAbandon   = false,
        levelExpr     = "",
    },

    settings = {
        previewColumns = {
            global = true,
            characters = true,
        },
    },
}
```

### 2.4 拦截逻辑

```
AcceptQuest() 被调用
  ↓
GetQuestID() 在 globalBlocked 中？ → 是 → DeclineQuest(), return
  ↓ 否
GetQuestID() 在 characterData[Core 当前角色 ID].blocked 中？ → 是 → DeclineQuest(), return
  ↓ 否
放行 → 调用原始 AcceptQuest()
```

优先级: 全局屏蔽 > 个人屏蔽

---

## 3. 文件结构

```
E:\Program\YiboQuestBlocker\
├── Libs\                          # 内嵌第三方库
│   ├── LibStub\
│   ├── CallbackHandler-1.0\
│   ├── LibDataBroker-1.1\
│   └── LibDBIcon-1.0\
├── Media\                         # 图标资源
├── YiboQuestBlocker.toc           # 插件元数据
├── YiboQuestBlocker_Core.lua      # 数据层 + 拦截逻辑
└── YiboQuestBlocker_UI.lua        # 界面层 + 主窗口 / Broker / 小地图图标
```

### 3.1 Core.lua 职责

- 数据初始化（角色注册、默认值）
- `AcceptQuest` / `ConfirmAcceptQuest` 包裹
- 事件监听（QUEST_DETAIL, QUEST_ACCEPT_CONFIRM, PLAYER_LEVEL_UP）
- 工具函数（获取任务名称、判断屏蔽状态、过滤角色等）
- 数据操作接口（添加/移除屏蔽、放弃任务、统计）

### 3.2 UI.lua 职责

- 主窗口（标题栏、关闭按钮、拖拽调整大小）
- 过滤器行（日常/普通/隐藏已完成 + 等级范围 + 角色排序）
- 列头（任务名 + 全局 + 各角色列）
- 滚动区域（屏蔽组 + 当前任务组，可折叠）
- 行生成（任务名 + 勾选框）
- 底部栏（手动添加ID + 作用域单选 + 添加按钮 + 状态文字）
- 刷新机制（延迟一帧避免多次刷新）
- 窗口显示/隐藏切换
- 小地图图标（Broker / 内置 fallback、拖拽定位、点击切换、悬停临时展开）
- 斜杠命令 `/yqb`

---

## 4. UI 布局

### 4.1 窗口结构

```
┌─────────────────────────────────────────────────┐
│ [YiboQuestBlocker]                       [X]    │  ← 标题栏（可拖拽移动）
├─────────────────────────────────────────────────┤
│ ☑日常  ☑普通  ☑隐藏已完成                         │  ← 过滤器第1行
│ 等级:[0] [▼至▼] [90]  排序:[▼名称▼]              │  ← 过滤器第2行
├─────────────────────────────────────────────────┤
│ 任务          │ 全局│天堂暴风│伊利丹怒风│...      │  ← 列头
├─────────────────────────────────────────────────┤
│ ▼ 屏蔽组  (N 个)                                 │  ← 分组1（可折叠）
│ [31234] 熊猫人│  ☑ │  ☑   │   □    │           │  ← 行
│ [31235] 雷神岛│  □ │  □   │   ☑   │           │
├─────────────────────────────────────────────────┤
│ ▼ 当前任务列表 (天堂暴风) - N 个                   │  ← 分组2（可折叠）
│ [32658] 产品订单│  □ │  □   │   □   │           │
│ [32659] 其他任务│  □ │  □   │   □   │           │
│                                                 │
│                                          ↗ 滚动  │
├─────────────────────────────────────────────────┤
│ [______] [●当前角色 ○全局] [+添加]               │  ← 手动添加
│ 全局: 2 | 当前角色: 3 | 总计: 5                  │  ← 状态栏
└─────────────────────────────────────────────────┘
                                                      ↘ 右下角拖拽调整大小
```

### 4.2 尺寸

| 元素 | 尺寸 |
|------|------|
| 列宽-任务名 | 200px |
| 列宽-勾选框 | 36px/列 |
| 行高 | 22px |
| 分组标题高 | 22px |
| 列头高 | 24px |
| 窗口默认 | 480×480 |
| 窗口最小 | 无硬性限制（右下角拖拽） |

### 4.3 交互细节

| 操作 | 行为 |
|------|------|
| 当前任务行点击☐→☑ | 加入屏蔽 + `AbandonQuest()` + 该行从列表消失 |
| 屏蔽组行取消☑→☐ | 从对应屏蔽列表移除 |
| 点击行空白区 | 聊天框显示 `任务名 (ID: 12345)` |
| 分组标题点击 | 折叠/展开该组 |
| 窗口标题栏拖拽 | 移动窗口 |
| 窗口右下角拖拽 | 调整窗口大小 |
| 小地图图标拖拽 | 沿小地图边缘自由定位 |
| 小地图图标左键 | 切换窗口显示/隐藏 |
| 小地图图标悬停 | 临时在图标下方展开主窗口；移出图标和窗口后自动收回 |

---

## 5. 开发过程中遇到的问题

### 5.1 `## SavedVariablesAccountWide` 不被识别

- 在 Interface: 50400 下测试，文件未生成
- 改为 Interface: 50504 后账号级生效
- 最终结果: 标准 `## SavedVariables` 在 50504 下自然存到账号级

### 5.2 任务列表不显示

- 原因: `GetCurrentQuestList()` 中使用 `break` 退出循环，遇到第一个已完成/被过滤/分组的任务就停止扫描
- 修复: 改用 `skip` 标志模式（Lua 无 `continue`）
- 同时修复了未捕获 `isHeader` 返回值的问题

### 5.3 `SetBackdrop` 调用 nil

- 原因: 国服客户端中 Frame 对象没有内置 `SetBackdrop` 方法，需要 `BackdropTemplate` 混合
- 修复: 所有使用 `SetBackdrop` 的 `CreateFrame` 调用加上 `"BackdropTemplate"` 参数

### 5.4 `OnDoubleClick` / `OnClick` 不支持

- 原因: MoP Classic 框架不支持 Frame 的 `OnDoubleClick` 和 `OnClick` 脚本
- 修复: 改用 `OnMouseUp`（Frame 支持的标准鼠标事件）

### 5.5 `SetMinResize` 不支持

- 原因: 该函数在 5.5.4 客户端中不存在
- 修复: 移除调用，仅保留 `SetResizable(true)`

### 5.6 贴图纹理路径

- 原使用 `Interface\DialogFrame\UI-DialogBox-Background` 和 `Interface\Tooltips\UI-Tooltip-Border`
- 部分纹理在国服客户端中路径不同或不存在
- 改用 `Interface\Tooltips\UI-Tooltip-Background`（主窗口）和 `Interface\Buttons\WHITE8x8`（行/分组标题）

### 5.7 `strsub` 等便捷函数

- WoW 早期版本没有 `strsub`、`strmatch` 等全局便捷函数
- 修复: 使用标准 `string.sub`、`string.match` 替代

---

## 6. 当前已知问题

- `SetResizable` 拖拽右下角调整大小后，滚动区域的列头与行勾选框对齐可能出现偏差（窗口内容需要刷新）
- 无图形化设置面板（所有配置通过 `/yqb` 窗口完成）
- 过滤器偏好没有保存到角色级（当前存在 `filters` 中，所有角色共用）
- 放弃任务时的确认弹窗依赖 `StaticPopup_OnClick` 自动点击，可能在某些特殊任务确认弹窗上失效

---

## 7. 未来可能的改进

| 功能 | 说明 |
|------|------|
| 任务搜索 | 在手动添加区域加一个搜索框，按任务名搜索 wowhead 或本地缓存 |
| 预设屏蔽列表 | 预置常见的"不要接"任务（如某些会卡住的任务线） |
| 导出/导入 | 屏蔽列表导出为文本，在角色间/账号间同步 |
| 任务分类标签 | 在网格中按任务类型着色（日常=黄色，副本=蓝色等） |
| Lua 错误提示开关 | 内置错误捕获，避免静默失败 |

---

## 8. 部署方式

```
# 复制文件到项目目录
xcopy /E /I <源目录> E:\Program\YiboQuestBlocker\

# 建立硬链接到游戏插件目录（管理员 PowerShell）
cmd /c mklink /J "C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\YiboQuestBlocker" "E:\Program\YiboQuestBlocker"
```

## 9. 无限服适用性分析（2026-11-26）

本轮完成仓库与客户端源码核对。基线为 YiboQuestBlocker Mists `3.2.0`、YiboCore Forever 工作树 `0.4.0`／API14，以及公开的 Forever `1.60.1.71091` 客户端 UI 源码镜像。YiboQuestBlocker 尚无 Forever 目标或实机操作证据。建议首版保留按任务 ID 管理规则，增加无需自动接取插件就能使用的接取提示和防误弃提示。 [客户端源码版本](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/version.txt)

| Mists 功能 | Forever 适用性 |
| --- | --- |
| 现有安装包 | 当前 TOC 和构建配置只面向 Mists，启动检查也要求实际 Mists 身份，Forever 无法直接运行现有业务。 |
| 全局／角色屏蔽、手输 ID、暂停、聊天提示、Core 矩阵和入口 | 规则与界面可复用。角色身份使用 Core 的 GUID，显示完整双名，范围与排序由 Core 提供。任务规则独立保存。 |
| 从当前日志勾选、任务标题缓存、隐藏已完成、日常／普通筛选 | 用原生 `C_QuestLog` 读取日志、任务 ID、标题和完成状态。仍在日志里的目标已完成任务要与已交付任务区分。频率标签只采用实际有证据的值，未知保持未知。 |
| 四风谷订单、MoP 特例 ID、Questie 分类兜底 | 四风谷例外和 MoP 静态 ID 无适用场景。首版分类采用原生字段。MoP 的 Questie 分类数据及第三方兼容结论需要分别重新验证。 |
| 接取前拒绝、多任务 NPC 跳过、队伍分享 | 原生 NPC 列表仍以 quest ID 调用 `C_GossipInfo.SelectAvailableQuest`；详情包含普通接取、PvP 确认及 `AcknowledgeAutoAcceptQuest` 分支；组队分享确认事件也提供 quest ID。全局函数存在只说明有入口。需逐条验证执行顺序、鼠标和手柄原生操作、同 NPC 交任务与其它对话选项，再按实测范围声明支持。`!Pig`、NDui、Questie、Leatrix Plus 的 MoP 状态不沿用。 |
| 手动批量放弃、接取后自动放弃队列 | 原生按 quest ID 设置当前任务并区分普通和带物品的确认弹窗。首版建议标出命中项，玩家在原生界面逐条确认。批量与后台自动放弃需独立评估。 |

[原生任务日志 API](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) · [原生 NPC 列表](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua#L39-L58) · [接取按钮](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua#L600-L614) · [分享事件](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestOfferDocumentation.lua#L59-L69) · [放弃确认](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua#L1368-L1381) · [Questie 手柄交互历史问题](https://github.com/Questie/Questie/issues/7925)

### 建议新增功能

1. **接取前加入规则。** 在账号页列出当前 NPC 提供的任务，并在单任务详情出现时记录本次任务 ID 与标题。玩家无需先接进日志，也不用查 ID，就能按账号或角色添加规则。任务详情和 NPC 列表先提供只读提示，玩家照常通过原生界面接取。对话关闭后清除当前候选任务。 [NPC 对话 API](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GossipInfoDocumentation.lua#L22-L38)
2. **无限关键任务提醒。** 优先验证少量角色解锁与副本开门任务，例如泽风岛离岛阶段、奥妮克希亚龙火护符链，以及瓦塔拉克公爵地下城饰品任务线。另可验证传承挑战涉及的特定 PvP 赛季旅程任务。加入屏蔽前显示已核实的后果，已被列入规则时保持可见。未来如启用自动处理，保护项优先，允许玩家为当前角色保留特例。资料按 Forever 任务 ID 验证，并区分阵营、职业及实际适用内容。传承点数和任务线进度由对应系统负责。 [无限上线概览](https://wow.blizzard.cn/news/24315820/index.html) · [团队副本开门](https://wow.blizzard.cn/news/24303009/) · [传承挑战](https://wow.blizzard.cn/news/24307383/)
3. **按实际样本补重复任务标签。** 艾泽拉斯贸易局／杜隆塔尔补给后勤部的专业活动可作为取样入口。先确认具体条目是否为日志任务、是否会反复出现和是否实际误接，再考虑显示分类或提供按角色选择的规则模板。首版规则由玩家逐条添加，避免把低等级、可重复或新区域任务整体视作可忽略。 [无限新专业活动](https://wow.blizzard.cn/news/24307383/)

无限原生已提供任务追踪、任务类型与地图提示。通用地图标点、任务攻略和进度管理优先使用对应客户端或插件功能。 [暴雪新手指南](https://worldofwarcraft.blizzard.com/en-us/news/24315280/einsteigerleitfaden-f%C3%BCr-neue-spieler-willkommen-bei-world-of-warcraft) · [测试版本说明](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-november-2/2360696/1)

### 实施与验收建议

- 先对照原生界面采集一个普通任务、一个同 NPC 多候选且可交任务、一个物品起始或自动入日志任务、一个队伍分享任务、一个已完成待提交任务及一个带物品的放弃确认。记录实际构建号、任务 ID、原生分类、事件载荷和次序、日志是否实际变化。若验证自动化，先选择一个玩家实际使用的 Forever 自动接取插件，分别覆盖开启和关闭、鼠标及原生手柄。没有样本的路径继续待验。
- 建议首版默认仅提示，保留暂停。先验证原生接取、交付、对话和放弃确认都可正常执行，规则修改与切换角色、重载和完整退出后可恢复。若实际存在频繁误接，再单独验证能否拦截明确支持的接取路径，以及同一 NPC 后续任务是否继续可选。后台自动放弃须另有实际需求与操作证据。
- 进入代码实施时按多目标规则拆分 `Mists`／`Forever` 任务日志、交互事件和目标分类，规则、矩阵和设置共享。采用 `YiboQuestBlocker_Mists.toc`／`YiboQuestBlocker_Forever.toc`，各玩家单目标包输出 `YiboQuestBlocker.toc`。用实际产品身份与就绪 Core 的 API14 和所需能力检查挡在写库之前，保留 Mists `YiboQuestBlockerDB`，Forever 建议独立 `YiboQuestBlockerForeverDB`。实施后回归 Mists 和 Forever 构建与实际加载、单次注册、干净安装和保留旧文件覆盖。 [多目标 TOC 与运行入口规范](../Docs/多版本目标与发行标识规范.md#21-多目标-toc-与运行入口规则2026-10-26)

本轮只更新分析与台账。加载链、构建配置、Core 能力接入及 SavedVariables 迁移均属于后续实施，尚无离线运行或客户端验收结果。

## 10. 多目标目录拆分方案（2026-11-26）

现有 `YiboQuestBlocker_Core.lua` 同时迁移存档、管理规则、读取任务并执行拒绝和放弃。按职责拆分时，共享层持有规则、设置和页面，目标层解释游戏数据并拥有游戏操作。当前 `AddBlock`／`RemoveBlock` 还会同步自动放弃队列，应先从规则写入中拆出 MoP 的通知和处理；改动远端角色规则时，仍只允许当前角色的有效规则驱动 MoP 队列。

| 目录与建议文件 | 现有来源及迁移职责 |
| --- | --- |
| `Common/Bootstrap.lua`、`Common/TocHint.lua` | 启动和全局注册从 `Locale.lua`、`YiboQuestBlocker_Core.lua`、`CoreIntegration.lua` 收口至一个生命周期。提示 TOC 单独加载 `TocHint.lua`。晚到 Core 复用已存在的 `CORE_READY`，重复通知不重注册。 |
| `Common/Store.lua`、`Common/Rules.lua` | 保存当前目标的 `globalBlocked`、`globalCache`、`characterData`、过滤、分组、播报和预览列。规则按 quest ID 与 Core 角色 ID 增删、合并显示及查询命中来源；当前角色 ID 变更处理使用 Core 事件。处理模式的保存和校验共用，允许值和默认值由目标给出。 |
| `Common/QuestView.lua` | 将已归一化的日志条目和规则合成屏蔽组、当前任务组及计数。主表、悬停和测量共用投影，任务名称保留客户端原文；显示读取使用已有数据，名称回填由日志或候选任务采集路径完成。角色等级表达式调用已有 `Core.LevelFilter`，任务分类和过滤继续归 YQB。 |
| `Common/AccountPage.lua`、`Common/Settings.lua`、`Common/CoreIntegration.lua`、`Common/Locale.lua` | 共用矩阵、输入、设置工作台、账号页、缓存清理、入口和 `/yqb`。注册版本、页面范围、默认等级、模式说明及可用按钮取自目标策略。保留工作树现有 `filters.reportChat` 及双语标签。没有适配状态或放弃操作的目标省略相应控件与占位。 |
| `Mists/Target.lua`、`Mists/Migrations.lua` | 声明实际 Mists 身份、`YiboQuestBlockerDB`、50504 与 MoP 配置。保留 v1 `knownChars`／`perChar`、旧角色键顺序推断、`levelOp` 及 `directReject` 等兼容语义，同时保留现有服务器范围、等级默认 `90` 和模式 `direct`／`abandon`／`paused`。旧迁移只作用于 MoP 存档。 |
| `Mists/QuestLog.lua`、`Mists/QuestHandling.lua` | `QuestLog` 包装旧 `GetQuestLog*`，保留 MoP 日常／普通、四风谷订单例外及本目标 Questie 分类行为。`QuestHandling` 负责 `AcceptQuest`／`ConfirmAcceptQuest`／任务选择包装、交互批次去重、第三方兼容状态、延迟自动放弃、手动批量放弃及其原生确认。相关事件留在本目标，初次移植按既有行为回归。 |
| `Forever/Target.lua`、`Forever/QuestLog.lua` | 声明 `WOW_PROJECT_CAMELOT`、16001 和独立 `YiboQuestBlockerForeverDB`，通过 Core GUID 和双名渲染。建议等级默认留空，账号页不声明 MoP 的 `realms` 范围；头部和排序仍由 Core 管理。日志用 `C_QuestLog`，按实测归一化任务状态和频率，未知单列语义，折叠分组不应造成漏项。首版模式为仅提示／暂停。 |
| `Forever/QuestOffers.lua`、`Forever/ProtectedQuests.lua` | 前者只读观察 NPC 候选和单任务详情，保留当前交互可添加的 quest ID、名称、已设规则及提醒；离开对话或切换角色时清空，现有任务与可交任务不当作新候选。后者只维护已核实的无限关键 quest ID 与双语提醒理由，细分阵营和职业等实际适用条件。名录有样本后再建立。首版的放弃提示使用日志中已命中项，由玩家在原生界面确认。 |

目录和文件名是实施建议。目标专用说明可随目标文件注册双语资源，只有内容形成独立职责时才单列文件。第一个代码阶段不建立空的 Forever 操作模块，也不改 Core 的业务模型。

### 共享边界和现有行为

- 日志适配层只提供业务用得到的 `questID`、`title`、日志内是否可交、任务频率及必要的任务等级。适配层消化原生索引、分组行和客户端枚举。NPC 候选保留为会话数据，按 ID 在共用规则层查命中状态。完成待交、已经交付与未知分别处理。
- 数据层一次完成规则变更，之后按目标需要通知。如果修改的是账号规则或当前角色规则，MoP 按变更后的有效范围复核队列，包含移除角色规则后仍命中全局规则的情况。无限首版同一动作只刷新候选、日志命中和规则显示。角色例外若正式纳入功能，共享层负责匹配优先级，Forever 目录负责内置保护名录及适用条件。
- 角色等级筛选只影响矩阵显示，由 Core `level-filter:1` 校验匹配。当前 MoP 默认 `90` 分散在存档初始化与页面注册，注册时会把空值改回 `90`。第一步迁移先明确保持 MoP 基线语义；Forever 使用自身默认值，空表达式表示不过滤。迁移后验证合法输入、非法拒绝、已存表达式与重载恢复。
- 保留 Core API14 作为当前基线。既有 `localization:1`、`character-identity:1`、`character-name-format:1`、`basic-input:1`、`pixel-line:1`、`account-view:2`、`account-entry:2`、`account-surface-budget:2` 按实际调用校验。复用等级解析时增加 `level-filter:1`。角色缓存清理继续走 Core 已有 owner 注册，按实际采用的公开契约校验。任务数据留在 YQB，Core 只持有公共角色和界面能力。 [Core 接入指南](../YiboCore/Docs/API-v5-业务插件接入指南.md) · [等级表达式实现](../YiboCore/Util/LevelFilter.lua)

### 开发顺序和加载验证

1. **先迁 MoP。** 目标 TOC 加载目标声明、共享模块、MoP 任务适配，再从共享入口初始化。先核对实际产品和 Core 就绪／能力，当前角色 ID 可用后才写业务库。回放 v1 规则和缓存恢复、当前角色 ID 变化、模式切换、当前／其他角色规则变更、接取与放弃路径、一次初始化、页面／悬停一致和旧包覆盖。复用现有 `QuestBlockerSpec`、`MatrixBudget`、语言和发布回放夹具。
2. **接 Forever 只读任务与提示。** 以实机样本验证日志、当前 NPC、单任务、分享、提交和关闭的字段与时序。验证共用规则、独立存档、双名、页面／悬停准入、仅提示和暂停的差异。关键任务提示按证据逐条补充。自动拒绝和后台放弃分别在有需求和证据后评估。
3. **验实际分发。** 源码默认 `YiboQuestBlocker.toc` 只执行提示，业务分别从 `YiboQuestBlocker_Mists.toc`／`YiboQuestBlocker_Forever.toc` 加载。两个玩家包都输出 `YiboQuestBlocker.toc`，且只携带其目标适用文件。保持技术名、目录和 MoP 存档变量，Forever 另起独立版本。更新统一构建器的目标、版本与最低 Core 检查来源，同步修正测试硬编码路径及本地化工具的旧迁移 token 路径，核对 MoP 整合包读取新目标清单。验证干净安装、含旧根 Lua 和旧资源的 MoP 覆盖、误目标无业务写库、待就绪恢复、重载及完整退出后的存档恢复。历史发行包清单作为覆盖对照。

本轮仅确认职责与现有依赖，未改运行代码、构建配置或存档，尚无双目标构建及实机验收结果。

## 11. 双目标实现与验收（2026-11-26）

| 目标 | 源码清单 | 玩家包加载名 | 存档 |
| --- | --- | --- | --- |
| Mists 3.2.1 | `YiboQuestBlocker_Mists.toc`（50504） | `YiboQuestBlocker.toc` | `YiboQuestBlockerDB`，保留 schema 3 和旧规则迁移 |
| Forever 0.1.0 | `YiboQuestBlocker_Forever.toc`（16001） | `YiboQuestBlocker.toc` | `YiboQuestBlockerForeverDB`，schema 1 |

- 源码默认 TOC 只显示缺目标提示。目标在 `ADDON_LOADED` 后等待实际客户端、Core 就绪与角色 ID，校验 API14 和所需能力后再绑定业务库。等待使用 Core 的就绪与角色更新事件，成功后注销等待回调。页面、清理所有者、入口及游戏交互按目标启动一次。
- 规则增删、账号页、设置、预览、存档结构、语言及通知进 `Common/`。MoP 的旧身份和设置迁移、Questie 分类、拦截及放弃进 `Mists/`。Forever 的 `C_QuestLog`、NPC 候选、分享事件、仅提示模式及关键任务提醒进 `Forever/`。等级校验调用 `Core.LevelFilter` 并声明 `level-filter:1`。动态标题保留客户端原文。
- MoP 初次拆分以 3.2.0 核对构建及覆盖，39 次启动、234 项通过后才接 Forever。最终 3.2.1 通过统一构建，分别在空目录与 3.1.3、3.2.0 玩家包解压目录覆盖回放，保留旧根 Lua，共 39 次启动、234 项通过。另用源码回放 v1 规则和名称缓存、缺少能力或误装时的保护、接取命中与未命中、其它角色规则不进当前队列、暂停和有效全局／角色规则。构建与覆盖以实际 ZIP 为输入，覆盖回放包含已有设置和规则、序列化重启及低版本 Core。
- Forever 0.1.0 通过统一构建及以 Core Forever 0.4.0 配套包为输入的 41 项回放。验证中英文启动、独立存档、混合日志与候选、任务频率、折叠标记、分享、任务详情关闭、暂停、关键任务保存前确认、误装和重载规则恢复。原生频率使用客户端枚举，未知频率在单独筛日常或普通时不混入该类。原生接口只枚举可见日志行时，当前组标记有折叠分组，玩家可展开原生列表。内置提醒已录入联盟龙火护符任务 `6502`。其它任务链、角色例外及反复误接规则模板待实际样本。 [Forever 频率枚举](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua#L1417-L1428) · [原生日志折叠处理](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua#L150-L183) · [龙火护符任务记录](https://questcorehq.com/wowdb/forever/quest/6502/drakefire-amulet) · [开门要求](https://wow.blizzard.cn/news/24303009/)
- 本地化专项报告为 0 硬编码候选、0 未知键、0 缺英文和 0 格式参数差异。矩阵预算专项 99 项通过，启动资源 18 项通过。旧根 Lua 从现行源码清单移出，更新测试加载引用和迁移文本检查路径。候选包尚未上传。

Forever 国服 `1.60.1.71037` 使用现有 Core 与 YQB 源码联接，完整启动后 `/yqb` 打开 0.1.0 页面。用西部荒野任务 `92742` 验证角色规则、日志命中标记及原任务仍在日志，`/reload` 后页面恢复规则。测试规则已经撤回，退出至角色列表后从同一存档核实已清除。泽风岛找到「成年礼」任务 NPC，尚未取得接取详情及候选事件实机样本。

按用户要求，剩余本轮工作使用离线验证。两个目标的最终安装字节、自然候选与分享、混合 NPC、手柄交互、完整退出重进以及保留旧文件实机覆盖保留为后续发行验收项。自动处理范围以实际证据决定。

### 11.1 无限 0.1.0 玩家实机清单

2026-11-26 用户反馈 MoP 端已测试且无问题，按用户反馈登记本轮 MoP 客户端通过。以下清单只针对 Forever 0.1.0 候选，配套 Forever Core API14。两个目标继续暂缓发布。

- [ ] **接取前候选。** 和提供任务的 NPC 对话，保持原生窗口打开，执行 `/yqb`。单任务直接进入详情、多任务停在 NPC 列表各测一次。「当前可接任务」应显示正确的任务名和 ID。若同一 NPC 同时有可接与可交任务，候选组只列可接项。任选普通任务勾选「当前角色」或「全局」规则，检查规则立即出现且游戏日志尚未接入该任务。关闭对话、重新打开同一 NPC，再换一个 NPC，核对候选不残留、不串人。
- [ ] **普通任务接取与提示。** 开启聊天播报，重新打开已设规则的普通任务，查看是否提示命中。愿意接取该任务时用原生按钮接取，检查它从候选组消失、已设规则保留并标记「任务日志中」，任务正常留在原生日志。完成待交任务仍能原生提交。
- [ ] **队伍分享。** 请队友分享一个当前角色可接且尚未接的普通任务。保持分享确认框打开，执行 `/yqb`，应显示正确任务名和 ID。分别测试拒绝和接受，最好先拒绝再请队友重新分享。拒绝后候选应清掉。接受后候选应消失，任务应出现在原生日志。若先添加了规则，接受后也应保留规则和日志标记。
- [ ] **关键任务确认。** 在 `/yqb` 底部手输 `6502`，点「当前角色」或「全局」。保存前应出现龙火护符与奥妮克希亚开门的提示。先取消并核对无新增规则，再重新添加并确认，核对规则只落在选择的范围，最后撤回测试规则。手输 ID 可测试弹窗，有自然任务样本时可同时核对候选行说明。
- [ ] **模式、界面和恢复。** 对照「仅提示」和「暂停」。暂停应隐藏当前候选并停止播报，已设规则仍可编辑。关闭聊天播报后，候选与规则标记仍应显示。任选一条临时全局规则和一条角色规则，完整退出再进游戏并切换角色，核对持久化和作用范围。折叠和展开原生日志分组，核对 YQB 的折叠标记。若使用 Core 悬停入口和原生手柄，核对同一候选显示及原生操作。可切中英文或 Core 手动语言检查提示和弹窗。

记录客户端构建、任务名或 ID、通过／失败／缺样本。失败时保留操作前后的候选组和原生窗口截图，注明是否启用了自动接交或替换任务对话的插件。

### 11.2 无限 0.1.1 自动放弃候选

2026-11-26 用户反馈：无限 0.1.0 已保存「测试水井」`92742` 当前角色规则，开启自动接交后仍能接到，聊天显示收到井水采样工具包。截图确认 `6502` 已显示保存前的龙火护符警告，取消与确认后的结果分别待验。0.1.0 提供「仅提示／暂停」，本次新增处理模式「自动放弃已接任务」。

- 选择该模式后，自动接取和手动接取走同一条 `QUEST_ACCEPTED` 路径。新增有效规则及切换到该模式也检查已接任务。处理在 NPC 对话结束后执行，按任务 ID 复核规则、日志和可放弃状态。交付取消待处理项，保留规则，避免把交付报成放弃。普通任务确认离开日志后才显示「已放弃」。
- 带任务物品调用客户端原生放弃确认，玩家决定是否继续。关键任务及客户端拒绝处理的任务保留，状态提示转到原生日志处理。升级维持既有模式与规则，需主动选择新模式。首次复验用 `92742` 保持自动接交开启，确认在原生提示前任务仍在日志。另用无任务物品的普通任务核对对话结束后自动移除。
- `YiboQuestBlocker_Forever.toc` 继续使用 Interface 16001，玩家包加载默认 `YiboQuestBlocker.toc`，沿用 `YiboQuestBlockerForeverDB` schema 1。新增执行模块只加载于 Forever，写库前目标检查、Core 就绪／API14 能力检查及单次初始化沿用现有入口。MoP 仅共享模式标签和状态呈现的可选接口，无 Forever 运行模块。离线候选验收及用户实机复测分开记录。 [原生放弃流程](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua#L1367-L1380)
- 统一构建器生成 Forever 0.1.1 候选，并通过 Mists 3.2.1 预检。Forever 干净包和保留 0.1.0 文件的覆盖目录分别通过 55 项离线回放，涵盖对话结束、带物品原生确认、不可放弃、自动交付、暂停和旧规则／模式保留。MoP 源码行为回放通过。YQB 本地化静态检查未发现硬编码候选、未知键或格式差异。用户实机复测待进行，候选包暂缓发布。

### 11.3 无限 0.1.2 自动拒绝候选

- 「自动拒绝」复用 `Common/Rules.lua` 的账号／角色有效规则。Forever 拦截接取详情、已识别任务 ID 的分享确认、NPC Gossip 任务 ID 与 Quest Greeting 原生列表索引。普通候选保持原顺序并排在命中项前；整个候选集的数量保持一致，兼容已缓存计数的自动接取插件。Quest Greeting 名称、信息及选择共用一份索引映射。可交任务与交付入口沿用原生路径。已记录的关键任务保留正常接取。
- 自动拒绝为独立可选模式。已有模式和规则随 `YiboQuestBlockerForeverDB` schema 1 保留。离开拒绝模式还原本插件所替换的 API，已显示的原生序号映射在关对话前有效。由服务器或缓存接口先完成接取的路径不纳入接取前拒绝结论；已入日志的任务由独立的自动放弃模式处理。
- 源码 `YiboQuestBlocker_Forever.toc`（16001）新增 Forever 拒绝模块，玩家包唯一加载名仍为 `YiboQuestBlocker.toc`。维持业务写库前的目标身份和 Core API14／能力校验，随单次初始化按模式安装。MoP 目标清单不加载 Forever 拒绝模块。双语模式及状态消息复用 Core Locale，能力门槛不变。
- 离线以「测试水井」`92742` 为同 NPC 候选首项，回放 Gossip 选择和 Quest Greeting 的索引选择。查验只有名单命中任务被拦截，其余候选排序稳定，自动接取可继续，已接任务可正常自动交付。另核对单任务接取、分享 ID、切换模式、任务名称和索引一致。用户自行实机复测，暂缓发布。 [原生 Gossip 调用](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua#L39-L58) · [原生 Quest Greeting](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua#L368-L389)
- 统一构建生成 0.1.2 候选。干净安装及在 0.1.1 玩家包上保留旧文件覆盖的目录分别通过 82 项回放，含旧规则、旧模式、误目标防写库和一次注册。MoP 3.2.1 构建预检及旧规则行为回放通过，YQB 双语静态检查通过。本次按用户要求没有自动上机，也未发布。

### 11.4 双目标共用任务处理开关

- MoP 3.2.2 与 Forever 0.1.3 的主表和设置工作台共用 `Common/Settings.lua` 的复选框定义与绑定，主表由 `Common/AccountPage.lua` 排版。两个自动动作可独立使用，暂停保留勾选和规则。主表和设置页按可用宽度换行。
- Common 持久化 `autoReject`、`autoAbandon` 和 `paused`。MoP 旧拒绝模式迁移为两项都开，保留接取前拦截及接取后放弃兜底。Forever 旧拒绝模式仅打开自动拒绝。旧放弃模式仅打开自动放弃，旧仅提示模式两项关闭。旧暂停保留暂停状态，因旧格式没有记录暂停前的选择，首次解除暂停恢复该目标默认选择。
- 自动动作继续各自通过 Mists／Forever 适配执行。两端既有目标清单、玩家包默认加载名、SavedVariables 身份、业务写库前保护、Core API14 能力校验与单次初始化沿用现有入口。新增选项与外框复用 Core 工具和双语资源。按用户既有要求离线验证，暂缓发布。
- 两端统一构建通过。MoP 干净安装及覆盖 3.2.0、3.2.1 共 234 项离线回放通过。Forever 干净安装与 0.1.2 覆盖分别通过 98 项，覆盖两处 Core 界面、实际点击、两个开关同时执行、暂停及重登恢复。矩阵预算 99 项和 YQB 本地化检查通过。实机待用户核对。
- 2026-11-26 用户在 Forever 0.1.3 确认触发自动放弃。截图显示「测试水井」（92742）进入原生确认，弹窗列出将摧毁的「井水采样工具包」，任务屏蔽页显示等待原生放弃确认。截图记录至弹窗出现，未记录确认后的任务日志及物品状态。
- 2026-11-26 修订 Forever 0.1.3。用户复测确认原生任务面板手动放弃会弹确认。按用户要求，Forever 自动放弃对带任务物品的任务也直接调用 `C_QuestLog.AbandonQuest()`，仍按任务日志确认结果，并保留关键任务保护和客户端拒绝处理提示。规则和开关沿用 Common。共用本地化资源移除旧状态文案，继续使用原有 Core 语言能力。
- 修订版统一构建通过，干净包与覆盖此前 0.1.3 候选各通过 98 项离线回放，模拟「测试水井」直接放弃、工具包随任务移除、恢复原选中任务、保留同一 NPC 的其它任务接交及关键任务保护。MoP 源码回归、构建预检和 YQB 本地化检查通过。未涉及运行入口或存档结构。
- 2026-11-26 用户复测 Forever 0.1.3 修订版，「测试水井」（92742）直接放弃，井水采样工具包随任务移除，未弹出确认框。该用例实机通过，暂缓发布。
- 2026-11-26 用户确认无限端分组可正常折叠且图标可见。按反馈，Forever 0.1.3 与 MoP 3.2.2 的共用账号页将角色任务分组标题简化为角色名，沿用 Core 角色显示名与折叠控件，删除多余的中英文标题资源。双目标离线回归、统一构建校验及本地化检查通过，简化后的显示待实机核对。
- 2026-11-26 Forever 0.1.3 与 MoP 3.2.2 共用悬停标题栏的暂停／恢复按钮。按钮复用游戏秒表的暂停与播放贴图，通过 Core API14／`account-view:2` 的 `context:SetTitleBarControl` 放置。点击写入既有 `paused` 设置，与主表和设置工作台共用状态，保留两项自动操作的选择。双目标统一构建通过，配套 Core Forever 0.3.0／MoP 1.13.0 的包回放共 110 项通过。实机图标显示和鼠标交互待验，暂缓发布。
- 2026-11-26 用户在 Forever 0.1.3 确认悬停暂停／恢复按钮工作正常。根据截图，双端共用按钮改为只显示原贴图中央符号，使用 Core 强调色和现有按钮边框。双目标构建及 110 项包回放通过，调整后的外观待实机核对。现有标题栏接口、能力门槛和加载链沿用。
- 2026-11-26 用户在 Forever 0.1.3 实测修订后的按钮，确认颜色和风格统一，暂停及恢复均正常。该用例实机通过。
- 双端候选升为 Forever 0.2.0／MoP 3.3.0。源码清单为 `YiboQuestBlocker_Forever.toc`／`YiboQuestBlocker_Mists.toc`，单目标安装包均加载 `YiboQuestBlocker.toc`。沿用业务写库前的目标身份保护、Core 就绪及 API14／能力检查、单次初始化和 `YiboQuestBlockerForeverDB`／`YiboQuestBlockerDB` 存档。旧文件覆盖由新清单选择当前加载路径。实机证据以受测版本和用例为准，发布暂缓。

## 12. 4.x 开发方案（2026-11-26）

本节记录后续开发方向。第 9 至 11 节保留无限 0.1.0 和 MoP 3.2.1 的设计与验收历史。4.x 是方案名称，各目标发行版本按实际发布范围确定。

### 12.1 NPC 对话快速添加

1. 本阶段只新增一个入口。在任务 NPC 的可见对话面板右上角放置 `YQB` 按钮，避开关闭键和原生操作。当前有可接、已接或可交任务，或者有该 NPC 的可信任务记录时显示。客户端无法可靠区分任务 NPC 时，允许在通用 NPC 对话上显示。展开后无数据时显示「暂无已知任务」。
2. 点击按钮展开或收起 YQB 自绘任务清单。每行显示任务名、任务 ID 和状态，右侧为「本角色」「全局」两列复选框。任务 ID 在窄布局可放入悬停提示，两列各表示对应范围是否存有规则。玩家勾选或取消勾选即保存或移除该范围的规则，沿用现有关键任务确认。单任务直接打开详情时，清单仅显示当前任务。
3. 按钮跟随可见面板外框，任务清单不依赖原生行、纹理、字体或索引。外框移动、缩放或重排时重新定位。整套替换对话的插件，只在能可靠识别可见外框时复用同一个按钮。所有显示行和后续操作用任务 ID 关联，任务来源以 NPC ID 判定。
4. YQB 已展开时，自动接取或交付关闭原生面板后，可以保留本次 NPC 清单并更新任务状态。切换到另一 NPC 或角色时清除旧交互上下文。如果原生面板在玩家点到按钮前就关闭，可使用原自动化插件支持的临时跳过方式重新对话，或在下次与该 NPC 交互时查看仍可用的记录。本阶段的兜底沿用同一 NPC 按钮。

### 12.2 状态、可选目录与存档

| 状态 | 数据来源与显示规则 |
| --- | --- |
| 当前可接 | 优先使用本次 NPC 对话的可接任务。单任务详情按实际任务 ID 收集。 |
| 已接／可交 | 使用原生活动任务和角色任务日志。目标已完成且还在日志的任务显示为「可交」。 |
| 本周期已交 | 只显示已经确认交付、已知属于该 NPC 且能确认周期的日常任务。自动交付与手动交付使用同一状态。按客户端实际重置周期清理。 |
| 未来可接 | 用户同时启用兼容的外部任务目录且数据就绪时，在同一清单的折叠组展示。优先接入 Questie／QuestieDB 的公开读取接口。DungeonsForever 作为副本任务补充候选，先核实其公开契约和覆盖范围。能确认前置时显示「需完成前置」，仅能确认目录归属时显示「目录收录 · 当前未提供」。 |

YQB 的玩家包不内置通用任务数据库。按当前 NPC ID 和客户端目标按需查询外部目录，原生可接状态优先，目录只提供任务归属和已知前置等静态事实。无数据源、接口未就绪或版本不兼容时，基础清单照常工作。数据源适配按实际可用的公开字段验证，避免读取其他插件的 SavedVariables 或把目录复制进 YQB。 [QuestieDB 公共 API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md) · [DungeonsForever 项目页](https://www.curseforge.com/wow/addons/dungeonsforever)

YQB 实际遇到的 NPC 与任务关系先放在当前会话的有限缓存。两个客户端沿用各自的 SavedVariables，继续保存真实的账号和角色屏蔽规则。若以后需要跨重载显示「本周期已交」，只评估保存角色 ID、任务 ID、NPC ID 与重置周期的最小索引，设定容量上限并在周期结束时清理。 [无限原生对话 API](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GossipInfoDocumentation.lua#L22-L38) · [无限交付事件](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua#L1325-L1335)

### 12.3 自动放弃与自动接交插件

- **MoP 与无限采用相同的产品语义。** 勾选让任务对当前角色生效时，若任务已在当前角色日志中，就安排自动放弃。以后被其他插件自动接到已经屏蔽的任务，按同一流程处理。取消一个范围后若另一个范围仍命中，继续以实际有效规则为准。
- 自动接交插件可照常运行。等待本次 NPC 交互结束，再按任务 ID 复核屏蔽规则、任务是否仍在日志及客户端是否允许放弃。任务若已交付，保留规则供下次使用。任务确已从日志移除且结果可确认时，才显示「已屏蔽并放弃」。客户端要求确认或无法放弃时，保留规则并显示实际状态。普通可放弃任务无需逐条弹出额外确认。
- 控制项放在现有 Core 设置工作台，建议名称为「自动放弃已屏蔽任务」。关闭时，新增屏蔽继续保存规则。MoP 沿用既有处理行为，无限在验证正常放弃、带任务物品直接放弃及自动接交后，再评估将该能力默认开启。无限自动接取前拦截可按独立场景评估。 [MoP 规则变更处理](Mists/QuestHandling.lua#L590) · [无限原生放弃检查](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua#L42-L55)

### 12.4 交付顺序与验收

1. **NPC 按钮和行操作。** 先完成共享清单、任务 ID、可接／已接／可交及双范围规则。两端分别核对普通对话、单任务直达、多任务混合、重复开关、皮肤移动或缩放、替换对话面板及窄屏布局。已展开清单应能处理对话快速关闭和任务状态变化。
2. **自动放弃。** MoP 回归原有处理。无限验证手动接取、第三方自动接取、第三方先交付、任务不可放弃、带任务物品直接放弃、开关关闭及规则改变后的实际结果。目标执行逻辑留在各客户端目录，现有主页面和新入口沿用同一套规则。
3. **补充任务状态与目录。** 在同一清单按证据逐步加入本周期已交日常和未来可接。分别验证外部数据源存在、缺失、禁用和版本不兼容，以及原生状态与目录冲突。以现有 3.2.1／0.1.0 为覆盖起点，回归原有规则、两个独立存档、Core 能力门槛、本地化及统一构建。

NPC 自动对话属于更远期的产品方向。届时再评估第一项、唯一项或指定项等选择方式，以及是否需要扩展插件定位和更换名称。
