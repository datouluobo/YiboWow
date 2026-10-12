# YiboAltoBoss

Boss Tracker (YiboAltoBoss) tracks world-boss progress, seasonal encounters, custom targets, raid and dungeon lockouts, and dungeon entry history across a MoP Classic account. The current source version is 2.6.0. Basic tracking uses the YiboCore account page and requires Core API v5 or later. The optional per-character goal integration requires the now-released Core 1.11.0 / API v12, `business-item-actions:1`, and a compatible YiboTaskHub installation. TaskHub is still an unpublished project, so goal integration is available only when that compatible build is installed; standalone Boss tracking remains available without it.

Optional YiboTaskHub integration supports per-character world-boss, seasonal-boss, and instance goals. AltoBoss provides the encounter catalog and progress; TaskHub owns the goal configuration and its account-page presentation. Goals can target a whole instance or selected encounters at an exact supported difficulty. Automatic display can be disabled while retaining manual views and kill history. World-boss progress uses reward observations; instance completion requires a complete encounter catalog and exact lockout data. Unknown or stale data remains unconfirmed. Older instances need a complete scan to establish a stable catalog; automatic cycle tracking for repeatedly run normal dungeons is not supported. The current goal integration requires the compatible, currently unpublished TaskHub build. See [runtime contract and acceptance](../Docs/行动中心-AltoBoss-运行契约与验收.md).

![YiboAltoBoss overview](Screenshots/Snipaste_2026-07-06_06-09-49.png)

## Features

- Account-wide overview for MoP Classic world boss progress
- Per-character tracking for Sha of Anger, Galleon, Nalak, Oondasta, the combined Four Celestials encounter, and Ordos
- The Four Celestials are a single weekly row; the recorded kill tooltip identifies the specific Celestial defeated
- Warbringer observation tracking by zone and realm
- Seasonal Boss tracking during confirmed holiday windows, starting with Brewfest Coren Direbrew
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

新增强最低 Core API v12 / business-item-actions:1，不足提示升级并停止增强；原基础业务保留既有最低版本，作为旧 Core 兼容例外，无新交互本地回退。整体提高最低版本时收拢此例外。

实际契约、自动化与客户端待验收范围见 [实施与验证](../Docs/行动中心-主动添加实施与验证.md)。
