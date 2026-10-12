# YiboAutoOpen

**Dependencies:** No required Yibo addon. Optional — [YiboCore](https://www.curseforge.com/wow/addons/yibocore) (API v6+) for integrated settings and supported integration.

## The YiboCore framework

YiboCore is the shared account window, character directory, and settings framework for Yibo addons. It is optional here; this addon works on its own. Add [YiboCore](https://www.curseforge.com/wow/addons/yibocore) for supported settings or integration.

Open supported bags and reward containers one at a time, with an editable allowlist and automatic safety pauses. With cursor placement enabled, a Bind on Pickup confirmation from an allowlisted source appears under the cursor, ready for you to review and click.

## What makes it useful

An explicit allowlist, serialized queue, and per-item failure handling keep container opening predictable while preserving player confirmation. For enabled allowlist sources, the native Bind on Pickup dialog appears at the cursor position; YiboAutoOpen never clicks it or chooses for you. This addresses two common pain points: a failed container no longer stalls the queue, and the confirmation stays visible where the interaction began.

## Features

- Scan existing inventory on login and process allowlisted containers in sequence.
- Add or remove containers using item IDs, links, or names.
- Pause during combat, casting, looting, sensitive interfaces, or insufficient free bag space.
- Retry handling lets other items proceed when one container fails.
- Move the native Bind on Pickup confirmation dialog under the cursor for enabled, allowlisted sources; the player still clicks Confirm or Cancel.
- Optional YiboCore settings manage the confirmation-source allowlist and cursor-placement toggle. Sources include containers opened by YiboAutoOpen and game objects you explicitly add from the recent-object list.

For example, when a whitelisted source such as Imperial Silk or Pandaria's Dark Soil triggers a Bind on Pickup prompt, the game's confirmation dialog appears under the cursor. The source must be enabled in the allowlist; you still decide whether to confirm or cancel.

## Getting started

Works without YiboCore. Use `/yao status` to check the queue, `/yao add <item>` to add an item, and `/yao list` to review the allowlist. Install YiboCore for graphical settings.

## Requirements and data

Mists of Pandaria Classic; packaged for client 5.5.4. YiboCore is optional. Its integrated settings require API v6 or later.

When YiboAutoOpen triggers a Bind on Pickup dialog from an enabled, allowlisted source, it moves the native dialog under the cursor; you must click Confirm or Cancel yourself. Turning off cursor placement leaves the dialog at its native position. This addon does not change auto-loot settings or choose rewards. Containers that require manual opening, including Abyssal Clam on MoP Classic, are skipped.

## Feedback

Report issues in this project's CurseForge comments with the addon version, client version, and steps to reproduce.

---

# YiboAutoOpen · 自动开包

**依赖：** 无必需的 Yibo 插件。弱依赖 — [YiboCore](https://www.curseforge.com/wow/addons/yibocore)（API v6+），用于统一设置及适用联动。

## YiboCore 框架

YiboCore 为 Yibo 插件提供统一账号窗口、角色目录与设置工作台。本插件基础功能可独立运行；[安装 YiboCore](https://www.curseforge.com/wow/addons/yibocore) 可使用适用的设置或集成。

按允许目录逐个开启背包里的袋子与奖励容器，并在不适合开启时自动暂停。目录来源触发“拾取后绑定”确认时，会把游戏原生确认框移到鼠标下，方便你直接检查并点击。

## 特点与解决的问题

开包清单明确可控，单个坏物品不会堵住整个队列；启用的白名单来源触发绑定确认时，游戏原生确认框会出现在鼠标位置，仍由玩家亲自确认或取消。
解决的痛点：批量开包时无需寻找突然出现在屏幕其它位置的确认框，同时避免单个坏容器阻塞队列或插件替玩家确认绑定物品。

## 主要功能

- 登录时扫描已有物品，按队列开启允许目录中的容器。
- 按物品 ID、链接或名称添加和删除目录项。
- 战斗、施法、拾取、敏感界面或背包空位不足时暂停。
- 单个容器失败时先处理其它物品，按项重试与隔离。
- 对启用的确认框来源白名单，将游戏原生“拾取后绑定”确认框移到鼠标下；仍须玩家亲自点击“确定”或“取消”。
- 可选 YiboCore 设置可管理确认框来源白名单与跟随鼠标开关；来源包括 YAO 自动开启的目录容器，以及从“最近可添加对象”主动加入的游戏对象。

例如，帝王丝绸、潘达利亚的黑色泥土等白名单来源触发“拾取后绑定”提示时，游戏原生确认框会出现在鼠标下方。该来源必须已在白名单中启用；是否确定或取消仍由你决定。

## 开始使用

无需 Core 即可运行。`/yao status` 查看状态，`/yao add <物品>` 添加项目，`/yao list` 查看目录；安装 Core 后可使用图形设置。

## 运行需求与数据说明

熊猫人之谜经典版；当前发布包对应 5.5.4 客户端。YiboCore 为可选增强；统一设置需要 API v6 或更新版本。

启用跟随鼠标时，白名单来源触发的游戏原生绑定确认框会移到鼠标位置；关闭后保留游戏原生位置。玩家仍须亲自点击“确定”或“取消”。插件不修改自动拾取设置、不选择奖励。深渊蚌等在 MoP 客户端要求手动开启的物品会跳过。

## 问题反馈

请在本项目 CurseForge 评论中提供插件版本、客户端版本与复现步骤。
