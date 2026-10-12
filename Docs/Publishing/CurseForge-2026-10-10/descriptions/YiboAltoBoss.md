# YiboAltoBoss — Boss, Lockout & Goal Tracker

**Dependencies:** Required — [YiboCore](https://www.curseforge.com/wow/addons/yibocore) (API v5 for core tracking; API v12 for optional goal actions). Optional — YiboTaskHub (no public CurseForge project page yet) for per-character goals.

## The YiboCore framework

YiboCore provides the shared account window, character directory, and settings workspace for Yibo addons. YiboAltoBoss requires [YiboCore](https://www.curseforge.com/wow/addons/yibocore) for its account page, character scope, and shared entry.

See which character still needs a weekly boss, has a seasonal encounter available, or can enter an instance without logging through your roster.

## What makes it useful

World-boss checks, seasonal encounters, encounter-level lockouts, custom NPC goals, and instance history share one character-by-character view. This addresses a common pain point: players can choose which character to log into without opening every character to check weekly progress and lockouts again.

## Features

- Track Sha of Anger, Galleon, Nalak, Oondasta, the Four Celestials, and Ordos across characters.
- Browse raid and dungeon lockouts by expansion, with encounter details and configurable pinned instances.
- Track seasonal bosses during supported event windows, including Coren Direbrew during Brewfest.
- Record Warbringer observations, custom NPC targets, and normal five-player dungeon entry history.
- Use YiboCore's account page, character directory, shared settings, and optional entry hover preview.

## Optional YiboTaskHub integration

The current 2.6.0 source can provide per-character world-boss, seasonal-boss, and instance goals to a compatible YiboTaskHub version. Goals can target an entire instance or selected encounters at a supported difficulty. TaskHub owns goal configuration and presentation; AltoBoss supplies its encounter catalog and progress. This integration requires YiboCore 1.11.0 / API v12 and `business-item-actions:1`. YiboTaskHub does not yet have a public CurseForge release; the goal integration becomes available when a compatible TaskHub build is released. Boss tracking works without TaskHub.

World-boss progress uses reward observations; instance completion requires a complete encounter catalog and exact lockout data. Unknown or stale observations remain unconfirmed. Older instances need a complete scan before they can provide a stable goal catalog. Automatic cycle tracking for repeatedly run normal dungeons is not supported.

## Getting started

Use `/yab` to open the Boss or Instances page. Visit each character to collect available game data, then choose the bosses and instances you want to follow.

## Requirements and data

Mists of Pandaria Classic; packaged for client 5.5.4. Requires [YiboCore](https://www.curseforge.com/wow/addons/yibocore), API v5 or later, for basic tracking. The optional YiboTaskHub goal integration requires Core API v12 and a compatible TaskHub release.

Boss and respawn observations are records, not guaranteed spawn timers. The Four Celestials share one weekly row; the kill tooltip identifies the Celestial recorded. Seasonal content appears only during its supported event window.

## Feedback

Report issues in this project's CurseForge comments with the addon version, client version, and steps to reproduce.

---

# YiboAltoBoss · 首领与副本追踪

**依赖：** 强依赖 — [YiboCore](https://www.curseforge.com/wow/addons/yibocore)（基础追踪需 API v5；可选目标行动需 API v12）。弱依赖 — YiboTaskHub（尚无公开 CurseForge 项目页），用于逐角色目标。



## YiboCore 框架

YiboCore 为 Yibo 插件提供统一账号窗口、角色目录和设置工作台。YiboAltoBoss 需要[安装并启用 YiboCore](https://www.curseforge.com/wow/addons/yibocore)，用于账号页、角色范围和统一入口。

查看哪个角色还没完成周常首领、哪些节日首领可打、哪些副本仍有可用次数，不必逐个角色登录核对。

## 特点与解决的问题

世界首领周常、节日遭遇、首领级锁定、自定义 NPC 目标和副本进入记录集中在同一张角色视图中。
解决的痛点：玩家无需逐个打开角色检查周常和锁定，就能判断下一步登录哪个角色。

## 主要功能

- 跨角色追踪怒之煞、炮舰、纳拉克、乌达斯塔、四天神和斡耳朵斯。
- 按资料片浏览团队与五人副本锁定、首领详情，并固定常看的副本。
- 在支持的节日开放期追踪节日首领，包括美酒节的科林·烈酒。
- 记录战争使者观察、自定义 NPC 目标及普通五人副本进入历史。
- 使用 YiboCore 账号页、角色目录、统一设置和可选入口悬停预览。

## 可选 YiboTaskHub 联动

当前 2.6.0 源码可向兼容版本的 YiboTaskHub 提供逐角色世界首领、节日首领与副本目标。目标可指定整本副本或特定难度下的首领；TaskHub 管理目标设置和展示，AltoBoss 提供首领目录与进度。此联动需要 YiboCore 1.11.0 / API v12 和 `business-item-actions:1`。YiboTaskHub 目前尚无公开 CurseForge 版本；发布兼容版本后即可使用该联动。基础首领追踪无需安装 TaskHub。

世界首领进度依据奖励观测；副本目标需要完整首领目录和精确锁定数据。未知或过期观测保持待确认。旧副本须完整扫描后才能建立稳定的目标目录；普通五人副本暂不支持自动周期判断。

## 开始使用

使用 `/yab` 打开首领或副本页面。登录各角色采集可用数据，再选择要关注的首领和副本。

## 运行需求与数据说明

熊猫人之谜经典版；当前安装包对应 5.5.4 客户端。基础追踪需要 [YiboCore](https://www.curseforge.com/wow/addons/yibocore) API v5 或更新版本。可选的 YiboTaskHub 目标联动需要 Core API v12 和兼容版本的 TaskHub。

首领和刷新观测是历史记录，不保证预测实际刷新时间。四天神合并为一个周常条目，击杀提示会显示已记录的具体首领；节日内容仅在适用活动期间出现。

## 问题反馈

请在本项目 CurseForge 评论中提供插件版本、客户端版本与复现步骤。
