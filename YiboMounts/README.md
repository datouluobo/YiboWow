# YiboMounts

2026-10-30：[性能修复](../Docs/其它插件-性能修复-2026-10-30.md)将收藏查询与索引归入 `Mists/CollectionState.lua`，保留实时收藏/阵营核实。当前版本只支持 Mists，误目标在写库前停止；独立来源提示与设置存档保持，新加载字节实机待验。

> 文档状态更新（2026-10-16）：现有功能已由用户确认实机验收收口。当前源码版本与发行证据见[状态总览](../Docs/仓库当前状态总览.md)，后续任务见[延期清单](../Docs/后续开发任务清单.md)。下文旧版本的开发／待验收描述按其原日期理解；当前版本渠道状态没有明确证据时保留待核对。

YiboMounts is a lightweight World of Warcraft addon that provides compact mount acquisition information through in-game tooltips. Chinese and English bilingual.

## Current Scope

YiboMounts displays mount source information in the following locations:

- The player's buff auras
- The target's buff auras
- The tooltip of a mouseover unit
- Tooltips in the Mount Journal
- Mount or mount-spell links in chat

Mount source details may include dungeons, bosses, vendors, factions, achievements, quests, events, difficulty requirements, reputation requirements, prices, class restrictions, and faction restrictions.

YiboMounts optionally integrates with YiboCore API 13 for account language and the shared settings workbench. Its source tooltips remain usable without YiboCore.

---

# YiboMounts

YiboMounts 是一款轻量级《魔兽世界》插件，通过游戏内 Tooltip 提供紧凑的坐骑获取来源信息。中英双语。

## 当前功能范围

YiboMounts 会在以下位置显示坐骑来源信息：

- 玩家的 Buff 光环
- 目标的 Buff 光环
- 鼠标指向单位的 Tooltip
- 坐骑面板（Mount Journal）中的 Tooltip
- 聊天框中的坐骑或坐骑法术链接

坐骑来源信息可能包括副本、首领、商人、阵营、成就、任务、活动，以及难度、声望、价格、职业和阵营等限制条件。

YiboMounts 可选接入 YiboCore API 13，使用账号语言与统一设置工作台；未安装 Core 时来源 Tooltip 仍可独立使用。


## 行动中心主动添加（2026-10-10 工作树）

当前入口审查为不适用：提供Tooltip来源说明，没有业务收藏管理目标控件；未来新增收藏入口及采集后再接入。

实际契约、自动化与客户端待验收范围见 [实施与验证](../Docs/行动中心-主动添加实施与验证.md)。

## 图标资源（2026-10-14）

当前图标为 `Media/YiboMountsIcon`：默认TGA为64px，插件列表使用128px TGA；PNG提供16/24/32/64/128/512/1024px，母版为312px透明位图。版本、统一缩放和验证范围见[系列资源记录](../Docs/Design/Yibo系列Logo-20261014/README.md)。

![YiboMounts 图标](Media/YiboMountsIcon-128.png)
