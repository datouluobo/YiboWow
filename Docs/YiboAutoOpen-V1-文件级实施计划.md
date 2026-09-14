# YiboAutoOpen V1 文件级实施计划

> 状态：已完成需求访谈，待实施
> 目标客户端：魔兽世界熊猫人之谜经典版（Interface `50504`）
> 首版版本：`YiboAutoOpen 1.0.0`
> Core 集成：可选；独立安装时自动开包与目录命令完整可用
> 基线来源：`F:\Download\wa.txt`（SHA-256：`2CDD4AD691C0B9176D9DA1FDD0B783F6E1F3287003EAA585D57ED590733A22F6`）

## 1. 目标与边界

YiboAutoOpen 用独立插件替代现有“自动开包”WeakAura。首版只处理明确加入账号目录、且背包 API 标记为 `hasLoot` 的容器物品。插件扫描玩家普通背包，将目标物品排入单步状态机，在满足安全条件时逐个调用背包使用接口。

首版必须做到：

- 默认目录覆盖旧 WA 的 40 个项目，并修复已确认的数据错误。
- 登录后默认扫描已有物品；以后在背包变化或脱战时继续处理。
- 战斗、敏感界面、死亡、载具、施法、拾取窗口和背包空间不足时暂停。
- 一次只使用一个容器，等待背包或拾取结果后再推进。
- 同一物品连续失败两次后，本次登录隔离该物品 ID，不阻塞其它目录项。
- 独立安装时提供 `/yao add`、`/yao del`、`/yao list`。
- 同时安装兼容 YiboCore 时，在 Core 统一设置工作台中提供图形设置页。

首版不做：

- 正式服或其它经典客户端兼容。
- 自动识别所有可开启物品。
- 接管或修改游戏自动拾取设置。
- 自动点击确认框、奖励选择框或其它受保护交互。
- 账号角色矩阵、主账号业务页、Broker、小地图入口或悬停预览。
- 独立设置窗口、长期开包历史、统计报表或调试控制台。
- WeakAuras 内部 API 检测；发布说明只提示玩家停用旧 WA。

## 2. 已验证的现状与前置改造

当前 YiboCore Public API 为 v5。业务设置由 `AccountView:RegisterPage(...).settings` 间接注册，设置导航也只枚举账号业务页。因此，YiboAutoOpen 若要“只进入统一设置工作台、不创建账号页”，必须先给 Core 增加 settings-only 注册能力。

实施时不得注册空账号页作为占位，也不得让 YiboAutoOpen 直接修改 Core 私有 `_pages` 表。

计划将 YiboCore Public API 从 v5 升至 v6，同时保留全部 v5 API：

- 新增 `Core:RegisterSettingsPanel(addonName, definition)`。
- 新增 `Core:UnregisterSettingsPanel(id, addonName)`。
- 新增 `Core:GetRegisteredSettingsPanels()`。
- 设置面板与账号页使用统一的技术名字母序导航。
- settings-only 项目只出现在设置导航，不出现在账号主窗口、“显示与入口”、Broker 或小地图逻辑中。
- 现有通过 `page.settings` 注册的业务插件保持原行为，不要求同步迁移。

## 3. 最终目录结构

```text
YiboAutoOpen/
├── YiboAutoOpen.toc
├── Bootstrap.lua
├── Defaults.lua
├── Database.lua
├── Catalog.lua
├── ItemResolver.lua
├── BagAdapter.lua
├── Safety.lua
├── Queue.lua
├── Commands.lua
├── Settings.lua
├── CoreIntegration.lua
├── Media/
│   └── YiboAutoOpenIcon-v1.tga
├── README.md
├── CHANGELOG.md
├── CURSEFORGE_DESCRIPTION.md
├── TEST_CHECKLIST.md
└── _NonRelease/
    ├── Tests/
    │   ├── TestRunner.lua
    │   ├── CatalogSpec.lua
    │   ├── ItemResolverSpec.lua
    │   ├── QueueSpec.lua
    │   └── MigrationSpec.lua
    └── Tools/
        └── Build-ReleasePackages.ps1

YiboCore/
├── YiboCore.toc                         # 加载新注册模块；同步版本
├── Bootstrap.lua                        # Public API v5 → v6；同步版本
├── Runtime/
│   └── SettingsRegistry.lua             # 新增 settings-only 注册表
├── UI/
│   └── AccountView.lua                  # 设置导航与宿主渲染接入注册表
├── README.md                             # 记录 API v6
└── CHANGELOG.md                          # 记录兼容性与新接口

Docs/
└── YiboAutoOpen-V1-文件级实施计划.md
```

## 4. 文件级实施内容

### 4.1 `YiboAutoOpen/YiboAutoOpen.toc`

职责：声明客户端、元数据、软依赖、SavedVariables 和确定的加载顺序。

建议内容：

```toc
## Interface: 50504
## Title: |cff20e070[Yibo]|r YiboAutoOpen - 自动开包
## Notes: 安全地自动开启账号目录中的容器物品。
## Author: YiboSoft
## Version: 1.0.0
## IconTexture: Interface\AddOns\YiboAutoOpen\Media\YiboAutoOpenIcon-v1
## SavedVariables: YiboAutoOpenDB
## OptionalDeps: YiboCore
## LoadOnDemand: 0

Bootstrap.lua
Defaults.lua
Database.lua
Catalog.lua
ItemResolver.lua
BagAdapter.lua
Safety.lua
Queue.lua
Commands.lua
Settings.lua
CoreIntegration.lua
```

约束：

- 不声明 `RequiredDeps: YiboCore`。
- 不声明 `Group: YiboCore`，避免被表现为 Core 的强依赖下级。
- Title 必须使用统一的青绿色 `[Yibo]` 前缀。
- TOC 版本必须与 `Bootstrap.lua`、README、CHANGELOG 和打包文件名一致。

### 4.2 `YiboAutoOpen/Bootstrap.lua`

职责：创建唯一全局命名空间与运行态，不承载业务算法。

公开/内部结构：

```lua
local ADDON_NAME = ...
local Addon = _G.YiboAutoOpen or {}
_G.YiboAutoOpen = Addon

Addon.NAME = "YiboAutoOpen"
Addon.VERSION = "1.0.0"
Addon.runtime = {
    initialized = false,
    queueState = "IDLE",
    generation = 0,
    pending = nil,
    quarantined = {},
    warned = {},
    sensitiveFrames = {},
}
```

提供：

- `Addon:Print(message, level)`：统一 `[Yibo] 自动开包` 前缀与提示等级。
- `Addon:NotifyIssue(key, message)`：按登录会话去重或节流。
- `Addon:Initialize()`：仅由 `ADDON_LOADED` 调用一次。
- `Addon:Refresh(reason)`：供命令、设置和事件入口请求重新扫描。

不得把队列、隔离、超时 token 等运行态写入 SavedVariables。

### 4.3 `YiboAutoOpen/Defaults.lua`

职责：保存数据库默认值、允许范围和通知枚举。

```lua
Addon.DEFAULTS = {
    schemaVersion = 1,
    catalogVersion = 1,
    enabled = true,
    scanExistingOnLogin = true,
    minFreeSlots = 5,
    notificationMode = "issues", -- silent | issues | verbose
}

Addon.LIMITS = {
    minFreeSlots = { min = 1, max = 20 },
    listPageSize = 20,
    maxRetries = 2,
    operationTimeout = 2.0,
}
```

低风险实现参数 `operationTimeout` 可在实机测试后调整，但不暴露为首版设置。

### 4.4 `YiboAutoOpen/Database.lua`

职责：初始化、校验和迁移 `YiboAutoOpenDB`。

目标 Schema：

```lua
YiboAutoOpenDB = {
    schemaVersion = 1,
    catalogVersion = 1,
    enabled = true,
    scanExistingOnLogin = true,
    minFreeSlots = 5,
    notificationMode = "issues",
    catalog = {
        order = { 39883, 44751, ... },
        entries = {
            [39883] = true,
            [44751] = true,
        },
    },
}
```

实现函数：

- `Initialize()`：首次安装复制默认目录，不能让 SavedVariables 直接引用只读默认表。
- `Normalize()`：修复非法类型、重复顺序项、缺失索引、越界空位和未知通知模式。
- `MigrateSchema()`：数据库结构迁移。
- `MigrateCatalog()`：按目录版本只加入“本版本新增 ID”；不得全量合并默认目录。
- `AddItem(itemID)`：重复添加返回 `already_exists`，不改变原顺序。
- `RemoveItem(itemID)`：从 `entries` 和 `order` 同时删除。
- `GetOrderedItems()`：返回副本，调用方不得修改数据库内部数组。

目录升级规则：

- 每个目录版本必须显式声明 `fromVersion → toVersion → addedIDs`。
- 玩家删除的旧默认 ID 不得由未来版本恢复。
- 新增默认 ID 追加到目录末尾。
- 迁移必须幂等；重复执行结果不变。

### 4.5 `YiboAutoOpen/Catalog.lua`

职责：保存 V1 默认目录和目录迁移定义，不包含扫描或 UI 逻辑。

按旧 WA 原始顺序写入以下 40 个启用 ID：

| 顺序 | ID | WA 注释名称 | 处理 |
|---:|---:|---|---|
| 1 | 39883 | 裂开的卵 | 保留 |
| 2 | 44751 | 海德尼尔礼品 | 保留 |
| 3 | 45724 | 冠军的钱包 | 保留 |
| 4 | 199210 | 诺森德冒险补给品 | 保留 |
| 5 | 200239 | 诺森德冒险补给品 | 保留 |
| 6 | 200238 | 诺森德冒险补给品 | 保留 |
| 7 | 45328 | 浮肿的鳗鱼 | 保留 |
| 8 | 46007 | 钓鱼宝藏 | 保留 |
| 9 | 44113 | 小香料袋 | 保留 |
| 10 | 52676 | 魔网守护者的珍宝 | 保留 |
| 11 | 44663 | 被遗弃的冒险者背包 | 保留 |
| 12 | 54535 | 桶型宝箱 | 保留 |
| 13 | 37586 | 一把糖果 | 保留 |
| 14 | 54516 | 塞满战利品的南瓜 | 由旧 WA 的 `false` 改为启用 |
| 15 | 20393 | 糖果包 | 保留 |
| 16 | 34077 | 稀烂的南瓜 | 保留 |
| 17 | 45072 | 鲜艳的彩蛋 | 保留 |
| 18 | 34863 | 钓鱼宝藏 | 保留 |
| 19 | 35348 | 钓鱼宝藏 | 保留 |
| 20 | 33857 | 一箱肉 | 保留 |
| 21 | 33844 | 一桶鱼 | 保留 |
| 22 | 25419 | 没有标记的宝石袋 | 保留 |
| 23 | 25423 | 贵重宝石袋 | 保留 |
| 24 | 35512 | 一包雪花 | 保留 |
| 25 | 54536 | 结冰的袋子 | 保留 |
| 26 | 52340 | 深渊蚌 | 修正旧 WA 的 `5234000` |
| 27 | 72201 | 肥肠 | 保留 |
| 28 | 90735 | 诺米的点心 | 保留 |
| 29 | 86623 | 布林顿4000礼包 | 保留 |
| 30 | 87391 | 被劫的财宝 | 保留 |
| 31 | 92960 | 蚕茧 | 保留 |
| 32 | 95601 | 一堆亮晶晶的垃圾 | 保留 |
| 33 | 95602 | 风化宝箱 | 保留 |
| 34 | 90839 | 一箱染煞金币 | 保留 |
| 35 | 90840 | 掠夺者的闪光金币袋 | 保留 |
| 36 | 98133 | 大宝箱 | 保留 |
| 37 | 93724 | 暗月游戏奖品 | 保留 |
| 38 | 95469 | 神龙之心 | 保留 |
| 39 | 104272 | 天神宝箱 | 保留 |
| 40 | 104273 | 焦黑的祭品箱 | 保留 |

代码只把 ID 作为真实键。注释名称用于维护说明；运行时名称与链接必须从客户端 API 获取，避免本地化名称写死。

### 4.6 `YiboAutoOpen/ItemResolver.lua`

职责：把命令或设置输入解析成唯一物品 ID。

解析顺序：

1. 从完整物品链接提取 `item:<ID>`。
2. 纯数字字符串解析为 ID，并拒绝小于 1、非整数或超出 Lua 安全整数范围的值。
3. 对物品名依次检查：
   - 玩家 0–4 号背包中已缓存物品的精确名称；
   - 当前账号目录中可由 `GetItemInfo(itemID)` 取得的精确名称；
   - `GetItemInfo(rawName)` 的客户端缓存查询结果。
4. 找不到时返回 `not_found`，提示使用物品链接或 ID。
5. 同名匹配到多个不同 ID 时返回 `ambiguous`，列出候选 ID，不修改目录。

名称比较使用去除首尾空白后的客户端本地化文本；不做模糊匹配、拼音匹配或外部数据库查询。

### 4.7 `YiboAutoOpen/BagAdapter.lua`

职责：隔离熊猫人之谜经典版背包 API 差异，让队列和测试不直接依赖全局函数。

封装：

- `GetNumSlots(bag)`
- `GetItemInfo(bag, slot)`，统一返回 `{ itemID, link, locked, hasLoot, count }`
- `UseItem(bag, slot)`
- `GetFreeSlots(bag)`，统一返回 `freeSlots, bagFamily`
- `GetTotalItemCount(itemID)`
- `FindNextEligible(entries, quarantined)`
- `GetGenericFreeSlots()`

扫描顺序保持旧 WA 行为：背包 `4 → 0`，格子从末位向前。每次成功或背包变化后重新定位，不长期保存可能失效的 bag/slot。

通用空位计算：

- 0 号主背包始终计入。
- 1–4 号背包只有 `bagFamily == 0` 时计入。
- 专业材料包等受限背包空位不计入阈值。

容器资格：

- `itemID` 存在于账号目录；
- `hasLoot == true`；
- `locked ~= true`；
- 物品不在本次登录隔离表；
- 若有物品冷却，必须已结束。

### 4.8 `YiboAutoOpen/Safety.lua`

职责：集中判断队列是否可以推进，并返回稳定原因码。

`CanRun()` 必须依次检查：

- 账号总开关为启用。
- 已完成首次初始化与登录扫描门槛。
- `InCombatLockdown()` 为假。
- 玩家未死亡或处于灵魂状态。
- 玩家不在载具中。
- 玩家没有正在施法或引导。
- `LootFrame` 未打开。
- 敏感界面均未打开。
- 通用背包空位不少于 `minFreeSlots`。

敏感界面至少覆盖：

- 商人；
- 银行；
- 邮箱；
- 玩家交易；
- 拍卖行；
- 公会银行；
- 虚空仓库。

使用事件维护显式布尔状态，不只依赖 Frame 名称是否存在。原因码示例：

```text
DISABLED
IN_COMBAT
PLAYER_UNAVAILABLE
CASTING
LOOT_OPEN
SENSITIVE_UI
INSUFFICIENT_SPACE
```

空位不足提示按原因去重：持续不足期间只提示一次；恢复到安全值后清除去重状态，未来再次不足可以重新提示。

### 4.9 `YiboAutoOpen/Queue.lua`

职责：实现事件驱动的单步处理状态机。

状态：

```text
IDLE
SCAN_PENDING
READY
USING
WAITING_RESULT
PAUSED
```

核心流转：

```text
登录/背包变化/脱战/敏感界面关闭/设置变化
  → 请求扫描（同一帧合并）
  → Safety.CanRun
  → 查找下一个目录容器
  → 记录 itemID 与使用前总数量
  → UseItem
  → WAITING_RESULT
  → BAG_UPDATE_DELAYED 或 LOOT_OPENED 或超时
  → 比较物品总数量/格子内容
  → 成功：清零该项目连续失败计数并重新扫描
  → 失败：最多重试两次；仍失败则会话隔离并扫描其它项目
```

实现要求：

- `RequestScan(reason)` 只递增 generation 或设置 pending 标记，避免事件风暴重复创建计时器。
- `ProcessNext()` 每次最多调用一次 `UseItem`。
- 使用 `C_Timer.After` 时捕获 generation；旧回调发现 token 过期必须直接退出。
- 成功判断以目标 ID 的背包总数量下降为主；堆叠数量减少 1 也算成功。
- `LOOT_OPENED` 时立刻进入暂停，不调用 `LootSlot`；`LOOT_CLOSED` 后重新扫描。
- 总开关关闭或目录删除时，增加 generation 并清空 pending，使旧超时回调失效。
- 删除当前正在等待的 itemID 时取消后续重试。
- 每次成功后重新扫描当前位置，直到所有合格数量处理完毕。
- 不在 `OnUpdate` 中做全背包轮询。

事件至少注册：

```text
ADDON_LOADED
PLAYER_LOGIN
BAG_UPDATE_DELAYED
PLAYER_REGEN_ENABLED
PLAYER_DEAD
PLAYER_ALIVE
PLAYER_UNGHOST
LOOT_OPENED
LOOT_CLOSED
MERCHANT_SHOW / MERCHANT_CLOSED
BANKFRAME_OPENED / BANKFRAME_CLOSED
MAIL_SHOW / MAIL_CLOSED
TRADE_SHOW / TRADE_CLOSED
AUCTION_HOUSE_SHOW / AUCTION_HOUSE_CLOSED
GUILDBANKFRAME_OPENED / GUILDBANKFRAME_CLOSED
VOID_STORAGE_OPEN / VOID_STORAGE_CLOSE
UNIT_SPELLCAST_START / STOP / SUCCEEDED / FAILED / INTERRUPTED
```

实际实现前需在 5.5.4 客户端验证事件名；不存在的非必需事件应由兼容表过滤，而不是导致加载失败。

### 4.10 `YiboAutoOpen/Commands.lua`

职责：唯一 Slash 命令 `/yao` 及其三个正式子命令。

注册：

```lua
SLASH_YIBOAUTOOPEN1 = "/yao"
SlashCmdList.YIBOAUTOOPEN = function(message) ... end
```

不得注册 `/yiboautoopen`、旧命令别名或第二个 Slash 名称。

行为：

- `/yao add <目标>`
  - 使用 ItemResolver 解析链接、ID 或名称。
  - 已存在时提示但不重排。
  - 新增后立即请求扫描。
  - 输出“已加入目录并进入自动开启队列”或对应等待原因。
- `/yao del <目标>`
  - 从目录和当前 pending 中移除。
  - 不要求聊天二次确认。
  - 不清除其它项目，也不重建默认目录。
- `/yao list [页码]`
  - 默认页码 1，每页 20 项。
  - 按目录加入顺序输出序号、可用的物品链接和 ID。
  - 未缓存名称时显示 `物品 #<ID>`，异步缓存成功后不主动重复刷屏。
  - 页码小于 1、非整数或大于总页数时给出有效范围。
  - 有下一页时末尾输出：`更多项目：输入 /yao list N 查看第 N 页`。
- 空命令、未知子命令或缺少参数：只打印三行正式用法，不创建隐藏别名。

目录修改与查询的命令反馈始终输出，不受通知模式影响。

### 4.11 `YiboAutoOpen/Settings.lua`

职责：只创建可嵌入 Core 的业务设置内容，不创建窗口壳、标题栏、导航、关闭按钮、滚动条或窗口位置存档。

导出：

```lua
Addon.Settings:CreatePanel(parent, host)
Addon.Settings:Refresh()
Addon.Settings:Release()
```

页面结构：

1. `业务设置`
   - “启用自动开包”账号级持久复选框。
   - “登录时扫描已有包裹”复选框。
   - “最低通用背包空位”数值输入，范围 `1–20`，默认 `5`。
   - “聊天提示”下拉：静默 / 仅问题 / 详细。
2. `当前状态`
   - 当前队列状态与暂停原因文本。
   - 本次登录隔离项目数量。
   - 有隔离项目时显示“重新尝试”按钮；清空会话隔离并请求扫描。
3. `开包目录`
   - 顶部输入框接受链接、ID 或名称，右侧“添加”按钮。
   - 紧凑表格列：图标与名称、物品 ID、删除。
   - 每页 20 条，保持加入顺序。
   - 上一页、`当前页 / 总页数`、下一页。
   - 空目录状态明确提示可粘贴物品链接或输入 ID，不显示装饰卡片。

交互要求：

- 同一语义组中的标签、说明和控件一起换行，不出现横向滚动。
- 删除按钮使用危险语义颜色，并通过 Core 统一确认框确认单项 ID 和物品名。
- 添加失败保留输入内容并就地显示原因；成功后清空输入并刷新当前页。
- 数值输入在回车或失焦时校验；非法值恢复上一个有效值。
- 提示档位改变后立即生效。
- 关闭总开关立即清空运行队列；重新启用立即请求扫描。
- 颜色不独自承载状态，状态文字必须同时存在。

### 4.12 `YiboAutoOpen/CoreIntegration.lua`

职责：软依赖检测、API v6 注册和一次性降级提示。

流程：

1. 若 `_G.YiboCore` 不存在，静默保持独立模式。
2. 若 Core 存在但 `CheckAPIVersion(6)` 失败：
   - 当前登录最多提示一次“Core 版本不兼容，已继续使用命令模式”；
   - 不停止扫描、命令或数据库功能。
3. 若 API v6 可用：
   - `Core:RegisterAddon("YiboAutoOpen", { version = Addon.VERSION, requiredAPI = 6 })`。
   - `Core:RegisterSettingsPanel("YiboAutoOpen", definition)`。
4. 注册失败时仅提示一次并降级，不污染数据库。

设置定义建议：

```lua
{
    id = "YiboAutoOpen",
    title = "自动开包",
    description = "管理自动开启目录、安全阈值与运行状态。",
    icon = "Interface\\AddOns\\YiboAutoOpen\\Media\\YiboAutoOpenIcon-v1",
    CreateSettingsPanel = function(parent, host)
        return Addon.Settings:CreatePanel(parent, host)
    end,
}
```

不得调用 `AccountView:RegisterPage` 或 `Entry:RegisterBusinessEntry`。

### 4.13 `YiboAutoOpen/Media/YiboAutoOpenIcon-v1.tga`

职责：TOC 与 Core 设置导航使用的插件图标。

资源要求：

- 主体建议使用“开启的包裹/宝箱”轮廓，与自动开包业务直接对应。
- 外围透明必须延伸到画布边缘。
- 不得带实色方底、渐变画布或烘焙棋盘格。
- 不得复制 WA 作者素材或其它插件图标。
- 实机验证小尺寸下仍可辨识。

### 4.14 文档文件

`README.md`：

- 独立安装和可选 Core 增强的关系。
- 三条命令及链接、ID、名称示例。
- 默认会扫描已有包裹，安装前应停用旧 WA。
- 自动拾取由游戏设置负责。
- 安全暂停与会话隔离说明。

`CHANGELOG.md`：

- 记录 1.0.0 的默认目录来源、`52340` 修正、`54516` 启用和 Core API v6 可选集成。

`CURSEFORGE_DESCRIPTION.md`：

- 明确 YiboCore 不是必需依赖，也不包含在下载包中。
- 独立功能和 Core 图形设置增强分别描述。
- 不声称会自动识别未知容器。

`TEST_CHECKLIST.md`：

- 使用第 7 节的静态与实机矩阵。

### 4.15 `_NonRelease/Tools/Build-ReleasePackages.ps1`

职责：生成双渠道安装包。

- 输出至仓库根 `Builds/`。
- 先在临时目录生成完整 zip，再归档旧包并写入新包。
- 生成：
  - `YiboAutoOpen-v1.0.0-curseforge.zip`
  - `YiboAutoOpen-v1.0.0-github.zip`
- 两个包均保留顶层 `YiboAutoOpen/`。
- CurseForge 包只含运行文件和必要元数据。
- GitHub 包可额外包含 README、CHANGELOG、描述和测试清单。
- 两个包均排除 `_NonRelease/`、本地测试输出、临时文件和源码 WA 导出串。

## 5. YiboCore API v6 文件级改造

### 5.1 `YiboCore/Runtime/SettingsRegistry.lua`（新增）

职责：管理不依附账号页的业务设置面板。

接口：

```lua
Core:RegisterSettingsPanel(addonName, definition)
Core:UnregisterSettingsPanel(id, addonName)
Core:GetRegisteredSettingsPanels()
```

验证规则：

- `addonName` 必须已通过 `Core:RegisterAddon` 注册。
- `definition.id`、`title`、`CreateSettingsPanel` 必填且类型正确。
- `description`、`icon` 可选。
- `id` 在 settings-only 注册表中唯一。
- 通过 `Core:ClaimResource("settings", id, addonName)` 防止跨插件冲突。
- 同一 owner 重复注册同一 ID 返回既有对象或明确幂等结果；不同 owner 冲突必须失败。
- `GetAll` 按插件技术名排序，而不是注册顺序或显示名排序。

### 5.2 `YiboCore/UI/AccountView.lua`

改造点：

- `RefreshNavigation()` 在三个 Core 常规设置项之后合并两类业务设置来源：
  - 现有非 internal 账号页的 `page.settings`；
  - `Core:GetRegisteredSettingsPanels()` 返回的 settings-only 项。
- 合并后按插件技术名排序；已知顺序保持：
  - `YiboAltoBoss`
  - `YiboAutoOpen`
  - `YiboLegendary`
  - `YiboQuestBlocker`
- settings-only 目标 ID 使用独立命名空间，例如 `addon-settings:YiboAutoOpen`，不得与页面 ID 混用。
- `SelectSettingsTarget()` 同时验证 Core 内建目标、账号页目标和 settings-only 目标。
- `RefreshSettings()` 通过统一解析函数获得 `{ title, description, CreateSettingsPanel }`，复用现有 `AddonPanel` 宿主。
- 从 settings-only 页面点击“返回”时返回账号概览，而不是尝试打开不存在的业务页。
- “显示与入口”继续只枚举账号业务页，绝不能出现 YiboAutoOpen。
- 插件设置创建失败时沿用现有错误边界，只使该面板显示错误，不破坏整个设置工作台。
- 宿主 context 保留现有帮助器；如设置实现需要输入框或下拉，应在 v6 中补充通用 `createInput` / `createDropdown` 帮助器，避免插件复制 Core 窗口控件样式。

### 5.3 `YiboCore/YiboCore.toc` 与 `YiboCore/Bootstrap.lua`

- 在 `Runtime/Registry.lua` 后、`UI/AccountView.lua` 前加载 `Runtime/SettingsRegistry.lua`。
- `Core.API_VERSION` 从 `5` 升到 `6`。
- Core 版本从当前 `1.3` 升为下一正式版本，TOC 与 Lua 常量同步；实施时若仓库已出现更新版本，则按实际版本递增，不回退。
- 现有 requiredAPI 1–5 插件继续兼容。

### 5.4 `YiboCore/README.md` 与 `YiboCore/CHANGELOG.md`

- 文档化 settings-only 注册接口、定义字段、排序方式和生命周期。
- 明确该接口不会创建账号页或入口。
- 记录 API v6 对 v5 的向后兼容性。

## 6. 实施顺序

### 阶段 1：Core 前置能力

1. 新增 `SettingsRegistry.lua`。
2. 更新 TOC 加载顺序和 API 版本。
3. 重构设置导航与目标解析。
4. 确认现有三个业务插件的设置页无回归。
5. 用一个临时内存 definition 验证 settings-only 项只出现在设置导航；临时验证代码不得进入发布文件。

### 阶段 2：独立插件数据层

1. 创建 TOC、Bootstrap、Defaults。
2. 建立默认目录和数据库迁移。
3. 完成 ItemResolver 与 BagAdapter。
4. 验证 40 个 ID 顺序、去重和已确认修正。

### 阶段 3：安全状态机

1. 实现 Safety 原因码。
2. 实现 Queue 单步状态机和超时 generation。
3. 接入背包、战斗、拾取与敏感界面事件。
4. 完成两次重试与会话隔离。
5. 验证删除、停用和旧超时不会继续使用物品。

### 阶段 4：命令与 Core 设置

1. 注册唯一 `/yao`。
2. 完成三种输入解析和三条子命令。
3. 完成 20 条分页与下一页提示。
4. 实现 Core 嵌入设置页。
5. 完成 Core 缺失、过旧和注册失败的降级。

### 阶段 5：资源、文档与发布

1. 制作透明图标并验证小尺寸显示。
2. 编写 README、CHANGELOG、CurseForge 描述和测试清单。
3. 运行静态检查、离线测试和游戏内冒烟。
4. 构建 CurseForge/GitHub 双包并检查内容清单。

## 7. 测试与验收矩阵

### 7.1 静态检查

- `rg -n "SLASH_" .` 确认 `/yao` 唯一，且只注册一个三字母 Slash 命令。
- `powershell -ExecutionPolicy Bypass -File .\Tools\Test-LuaSyntax.ps1 -Addon YiboAutoOpen` 通过 Lua 5.1 语法检查。
- YiboCore 与 YiboAutoOpen TOC 中所有 Lua、图标路径存在。
- TOC Title 为统一 `|cff20e070[Yibo]|r` 前缀。
- YiboAutoOpen 不包含 `RequiredDeps: YiboCore`、`Group: YiboCore` 或业务入口注册。
- `git diff --check` 无空白错误。

### 7.2 离线逻辑测试

`CatalogSpec.lua`：

- V1 恰好 40 个唯一 ID。
- 第 14 项为 `54516` 且启用。
- 第 26 项为 `52340`，不存在 `5234000`。
- 删除后 order/entries 一致；重复添加不重排。

`MigrationSpec.lua`：

- 首次安装复制默认目录。
- Schema 与目录迁移可重复执行。
- 玩家删除的旧 ID 不被后续版本恢复。
- 新版本 addedIDs 只追加一次。

`ItemResolverSpec.lua`：

- 正确解析链接、纯数字和已缓存名称。
- 空白、负数、小数、未知名称被拒绝。
- 同名多 ID 返回歧义，不修改目录。

`QueueSpec.lua`：

- 同一帧多个 BAG_UPDATE 只推进一次。
- 每次最多调用一次 UseItem。
- 数量下降判定成功并继续下一项。
- 超时失败两次后按 ID 会话隔离。
- 旧 generation 回调不能推进新队列。
- 战斗、敏感界面、拾取窗口和空位不足均暂停。
- 关闭总开关、删除当前 ID 会取消待处理动作。

### 7.3 游戏内独立模式

- 仅启用 YiboAutoOpen，不启用 YiboCore，登录无 Lua 错误。
- 首次安装默认扫描已有合格容器。
- `/yao add` 分别接受物品链接、ID 和可缓存名称。
- `/yao del` 删除后立即停止后续处理。
- `/yao list` 每页 20 条；V1 有两页，第一页末尾正确提示 `/yao list 2`。
- 战斗中获得容器不打开，脱战后恢复。
- 商人、银行、邮箱、交易、拍卖行、公会银行或虚空仓库打开时不使用物品。
- 通用空位低于 5 时暂停；专业包空位不计入。
- `hasLoot == false` 的目录物品不被使用。
- 自动拾取关闭时，拾取窗口出现后队列暂停；玩家关闭后继续。
- 同一物品堆叠和分散在多个格子时最终全部处理。
- 连续失败项目被隔离后，其它目录容器继续处理。

### 7.4 游戏内 Core 增强模式

- YiboCore API v6 加载时，设置左侧导航按技术名字母序出现“自动开包”。
- YiboAutoOpen 不出现在账号主导航、“显示与入口”、Broker 或小地图列表。
- Core 页面可以切换总开关、登录扫描、空位阈值和提示档位。
- 目录表格每页 20 条，保持加入顺序。
- 图形添加、删除与 `/yao` 操作读取同一份数据库。
- 会话隔离项可通过“重新尝试”清空并重新扫描。
- 设置内容超高时只使用 Core 右侧内容区纵向滚动；无横向滚动和裁切。
- YiboCore API v5 或注册失败时，只提示一次并继续独立模式。

### 7.5 Core 回归

- YiboAltoBoss、YiboLegendary、YiboQuestBlocker 原设置页仍可进入并正确渲染。
- Core 常规设置固定保持“窗口 / 角色与排序 / 显示与入口”的顺序。
- 账号主页面顺序和页面启用设置不受 settings-only 注册影响。
- 插件设置创建错误被局部捕获，Core 设置工作台仍可切换。
- `/reload` 后设置目标、业务页和现有插件功能正常。

### 7.6 发布包

- CurseForge 与 GitHub zip 均保留顶层 `YiboAutoOpen/`。
- 发布包不含 `_NonRelease/`、`wa.txt`、测试输出或临时文件。
- YiboCore 不打入 YiboAutoOpen 包。
- 两个包解压后通过 TOC 引用检查。

## 8. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| `hasLoot` 在部分特殊礼包上为假 | 合法目录物品不会自动打开 | V1 坚持安全优先；实机记录具体 ID 后再设计显式例外机制 |
| 背包事件在高延迟下乱序或重复 | 重复使用、误判失败 | 单步状态机、总数量比对、generation token、超时后重扫 |
| 商人窗口导致背包使用变成出售 | 严重误操作 | 敏感界面硬暂停；商人状态必须优先于扫描 |
| 名称缓存不完整或同名 | 加错目录 | 链接/ID 优先；歧义拒绝；内部永远只存 ID |
| Core settings-only API 改造回归 | 现有设置页异常 | API v6 向后兼容；合并导航但保留 page.settings 路径；执行三插件回归矩阵 |
| 独立模式无法调整运行设置 | 用户需要暂停或改阈值 | 产品已确认：独立模式保持三个命令；通过插件管理器禁用，Core 模式提供完整设置 |
| 首装时旧 WA 仍启用 | 两套逻辑同时调用物品 | README、发布说明和首次版本说明明确要求先停用旧 WA |

## 9. 完成定义

以下条件全部满足才算 V1 完成：

- 计划中的运行文件、Core API v6 前置改造、文档、图标和构建脚本均已落地。
- 40 项默认目录顺序与本计划一致。
- 独立模式、Core 增强模式、Core 不兼容降级三条路径均通过测试。
- Lua 5.1 语法、TOC 引用、Slash 唯一性、离线逻辑测试和 `git diff --check` 全部通过。
- 用户在熊猫人之谜经典版实机完成至少一次：登录扫描、战斗延后、敏感界面暂停、连续多包处理、空位不足恢复和 Core 设置操作。
- 双渠道包内容检查通过，且未包含 WA 原始导出串或其它非发布资料。
