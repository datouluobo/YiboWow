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
| 小地图图标 | 支持内置小地图按钮与 LibDBIcon，左键开关窗口，悬停临时展开主窗口 |
| 斜杠命令 | `/yqb` 开关窗口 |
| 数据持久化 | 所有角色共享同一个 SavedVariables 文件 |

### 1.3 技术栈

- 语言: Lua 5.1 (WoW 内嵌)
- 框架: WoW Frame API (CreateFrame, BackdropTemplate)
- 依赖库: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0
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
    -- 已知角色列表（每次登录自动注册/更新等级）
    knownChars = {
        ["莫格莱尼-天堂暴风"] = { level = 90, class = "PALADIN" },
        ["莫格莱尼-伊利丹怒风"] = { level = 85, class = "DRUID" },
    },

    -- 全局屏蔽列表（所有角色共享）
    globalBlocked = { [12345] = true },
    globalCache   = { [12345] = "熊猫人火锅" },

    -- 各角色个人屏蔽
    perChar = {
        ["莫格莱尼-天堂暴风"] = {
            blocked      = { [67890] = true },
            cache        = { [67890] = "雷神岛巡逻" },
            minimapPos   = 210,
            windowShown  = true,
            _foldedBlocked = false,
            _foldedCurrent = false,
        },
    },

    -- 过滤器偏好（每个角色独立）
    filters = {
        showDaily     = true,
        showNormal    = true,
        hideComplete  = true,
        levelMin      = 0,
        levelOp       = "至",   -- 至 / 以上 / 以下 / 等于
        levelMax      = 90,
        sortBy        = "order", -- name / level / order / count
    },

    -- Broker / LibDBIcon 使用的小地图配置（账号级）
    minimap = {
        hide = false,
        minimapPos = 210,
    },
}
```

### 2.4 拦截逻辑

```
AcceptQuest() 被调用
  ↓
GetQuestID() 在 globalBlocked 中？ → 是 → DeclineQuest(), return
  ↓ 否
GetQuestID() 在 perChar[当前角色].blocked 中？ → 是 → DeclineQuest(), return
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
