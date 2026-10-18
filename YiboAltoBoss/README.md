# YiboAltoBoss

当前源码版本：**2.8.0**（2026-10-18）。新增四类节日副本首领支持、排队时间提示，并修复重复副本列和排队状态同步。自动化检查通过；本次新增功能的实机验收状态见 Docs/四类节日副本首领核查与验收.md 和 Docs/节日排队状态同步修复.md。 请配套使用 **YiboCore 1.12.6 / API13**，启动时检查 `account-surface-budget:2` 及实际方法。

Boss Tracker (YiboAltoBoss) tracks world-boss progress, seasonal encounters, custom targets, raid and dungeon lockouts, and dungeon entry history across a MoP Classic account. The current source version is 2.8.0. Basic tracking uses the YiboCore account page and requires Core 1.12.6 / API v13 and the documented UI and localization capabilities. The optional per-character goal integration requires Core 1.12.2 / API v13, `business-item-actions:3`, and a compatible YiboTaskHub installation. TaskHub is still an unpublished project, so goal integration is available only when that compatible build is installed; base Boss tracking remains available without TaskHub; YiboCore is always required.

Optional YiboTaskHub integration supports per-character world-boss, seasonal-boss, and instance goals. AltoBoss provides the encounter catalog and progress; TaskHub owns the goal configuration and its account-page presentation. Goals can target a whole instance or selected encounters at an exact supported difficulty. Automatic display can be disabled while retaining manual views and kill history. World-boss progress uses reward observations; instance completion requires a complete encounter catalog and exact lockout data. Unknown or stale data remains unconfirmed. Older instances need a complete scan to establish a stable catalog; automatic cycle tracking for repeatedly run normal dungeons is not supported. The current goal integration requires the compatible, currently unpublished TaskHub build. See [runtime contract and acceptance](../Docs/行动中心-AltoBoss-运行契约与验收.md).

![YiboAltoBoss overview](Screenshots/Snipaste_2026-07-06_06-09-49.png)

## Features

- Account-wide overview for MoP Classic world boss progress
- Per-character tracking for Sha of Anger, Galleon, Nalak, Oondasta, the combined Four Celestials encounter, and Ordos
- The Four Celestials are a single weekly row; the recorded kill tooltip identifies the specific Celestial defeated
- Warbringer observation tracking by zone and realm
- Seasonal dungeon Boss tracking for Love is in the Air (Crown Chemical Co.), Midsummer (Ahune), Brewfest (Coren Direbrew), and Hallow's End (Headless Horseman), using the client's calendar
- Cross-character raid and dungeon lockout overview grouped by expansion
- Configurable pinned instances for hover previews, with lockout and encounter details
- Normal five-player dungeon entry tracking with a configurable hourly limit
- Direct seasonal Dungeon Finder queue and cancellation actions using the current selected roles
- Unified YiboCore entry and account-view navigation
- Configurable overview and settings panels

## Why it is useful

YiboAltoBoss combines weekly world-boss checks, seasonal encounters, custom NPC goals, and raid or dungeon lockouts in one character-by-character view. A player can see which character is worth logging into without opening each character to check again. Instance details, pinned hover previews, and entry history keep the decision close to the relevant encounter.

YiboCore is required for the shared account page and character directory. Optional YiboTaskHub integration adds per-character objectives and projected progress; the two addons keep their data ownership separate. The base Boss tracker does not depend on TaskHub.

## 功能说明

YiboAltoBoss 把世界首领周常、节日首领、自定义 NPC 目标、团队与五人副本锁定及副本进入记录放在同一账号视图中。玩家可以直接判断哪个角色值得登录，不必逐个角色打开游戏核对；锁定详情、固定副本悬停预览和进入记录帮助玩家就地决定下一步。

账号页和角色目录依赖 YiboCore；可选 YiboTaskHub 联动增加逐角色目标与进度展示，两个插件仍各自管理自己的数据。基础首领追踪不依赖 TaskHub。

## Core integration (2.0)

- `YiboAltoBossDB` remains the owner of all Boss, phase, respawn-sample, custom-target, and display data.
- Known AltoBoss characters are imported into YiboCore's shared character directory without changing their legacy Boss data keys.
- YiboCore owns the default minimap/Broker entry and exposes AltoBoss in its settings navigation.
- The formal Boss grid and its hover preview use one AltoBoss renderer inside the Core account view. Page scope, character hiding, sorting, preview limits, and optional entry lifecycle are managed by Core.

## Release Package

GitHub Releases and packaged builds exclude unused source artwork under `Media/Source/`.

## P5 tracking

Timeless Isle kills are recorded immediately from combat-log events. On login, the addon also restores completed current-week kills from Blizzard's server-side weekly lockout flags, so a kill remains recoverable after reloads or on another computer. The Four Celestials do not create phase or action records because they rotate at one location without a respawn wait.

If a character killed a Celestial before the addon was installed, run `/yab celestial` to manually correct that character's current-week Four Celestials record. This command does not read quests or infer historical kills.


## 行动中心主动添加（2026-10-10 工作树）

从世界／节日及副本锁定对象添加；精确难度／首领判断，原刷取编辑、复制与自动展示引用同一Task目标库。

基础账号页最低 Core API v13 / localization:1；主动添加要求 Core 1.12.2 / business-item-actions:3。版本或能力不足时提示升级并停止依赖功能。

实际契约、自动化与客户端待验收范围见 [实施与验证](../Docs/行动中心-主动添加实施与验证.md)。


## 五人本击杀历史（工作树）

单体 Boss 的死亡战斗日志按副本地图与 NPC ID 目录补记，和原生完成事件去重；普通本无锁定快照时也可悬停副本格查看次数、难度与最近击杀。成功重置不清除历史，随后重打可再计数。多目标与剧情类遭遇以明确完成信号为准，覆盖边界与客户端验收见 [五人本 Boss 记录](Docs/FivePlayerBossRecording.md)。

Five-player dungeon history also records verified single-boss deaths from the combat log, filters trash by map/NPC identity, and merges duplicate native completion events. Hover an unlocked instance cell to view kill history. Successful resets allow another run without removing historical totals. See [recording rules and verification](Docs/FivePlayerBossRecording.md).

五人本现在可选接收 DBM 完成通知补齐复杂遭遇；DBM 不可用时保留独立基础记录。三种来源按本轮副本统一去重。团本沿用既有原生记录路径。DBM 集成默认自动发现，无额外入口或业务依赖。

Optional DBM completion callbacks supplement complex five-player encounters. Native completion and verified single-boss death tracking remain independent; all dungeon sources share per-run deduplication. Raid recording keeps its existing native path.

2.6.1：普通本显示本轮进度，历史 TP 字段默认隐藏，可在统一业务设置开启；离本30分钟进度待刷新，校对仅在有未过期进度时运行。中文实机已确认采集及进度展示；DBM、时效启停和英文客户端仍待验收。

## Core API13 迁入收尾（2.7.0，2026-10-15）

设置、角色名称／排序、输入、确认和小地图入口统一使用 Core；已清理独立设置窗口与旧入口／窗口分支。界面使用 Core 统一账号语言，动态游戏名和历史原文保留。能力基线、数据边界及实机待验项见 [完整接入记录](Docs/Core-API13-完整接入.md)。

Settings, character display, inputs, confirmations and minimap entries use Core APIs. Core API13 and the documented capabilities are required; optional TaskHub/DBM integrations retain their own checks. Client acceptance is pending.

本次源码还要求 Core `account-preview-field-groups:1`：固定副本选择位于「显示与入口 → YiboAltoBoss → 预览字段」，旧选择自动沿用。请同步安装 Core 1.12.3 / API13；此前2.6.1发布包未包含这次迁入。

2026-10-16 未发布工作树：首领主表两方向与锁定矩阵已接入Core统一滚动预算，要求API13／`account-surface-budget:2`及`AccountView:GetScrollSurfaceWidth`。Core决定滚动槽、自然窗口宽度和必要分页；版本／方法不足时提示升级并停止初始化。代码和离线回归通过，实机待验；本轮未更新版本或发布。见[统一接入与验收](../YiboCore/Docs/矩阵预算统一接入-实施与验收.md)。
