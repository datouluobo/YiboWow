# YiboAutoOpen — Safe Container Opening

YiboAutoOpen safely opens container items that **you explicitly add to its catalog**. It uses a clear allowlist instead of relying on inconsistent client-side "openable" flags, so catalogued items such as Nomi's Treats can be handled consistently.

## Features

- Opens catalogued containers one at a time.
- Scans existing bags after login by default.
- Lets you add items by link, item ID, name, or drag-and-drop in the settings panel.
- Provides a paged catalog with item-name refresh and per-session retry reset.
- Moves a failed item to the end of the queue so other catalog items still get a chance to open.
- Rechecks sensitive UI state after instance/world transitions and manual refresh, avoiding stale pauses when a close event was missed.
- Supports optional YiboCore integration for the unified settings workbench.
- Works without YiboCore through slash commands.

## Safety First

YiboAutoOpen pauses instead of taking risky actions while you are in combat, dead, in a vehicle, casting, viewing loot, using sensitive interfaces such as merchants or banks, or below the configured generic-bag free-space threshold.

It does not change Auto Loot, click confirmation dialogs, choose rewards, or discover and open unknown containers. Failed items are retried independently and isolated without blocking other catalog items. Combat, loading, active sensitive interfaces, and low free space remain safety pauses.

## Commands

- `/yao add <item link, ID, or name>` — add an item to the allowlist. Names must resolve uniquely; use a link or ID if a name is ambiguous. Matching items in your bags enter the opening queue.
- `/yao del <item link, ID, or name>` — remove an item from the allowlist without removing it from your bags.
- `/yao list [page]` — review the catalog, up to 20 items per page. Use `/yao list 2` to view page 2. Items marked manual-only cannot be opened automatically due to game restrictions.
- `/yao status` — see whether the queue is running or paused and why, the next eligible item, items isolated for this login, and pending confirmation details.

For example, use `/yao add 12345` or `/yao add <item link>` to add an item, `/yao list` to review the allowlist, and `/yao del 12345` to remove it. If nothing opens, `/yao status` shows whether combat, a sensitive interface, low free space, or no eligible item is holding the queue. In the Core settings workbench, you can also drag an item from your bags into the catalog.

For example, when a whitelisted source such as Imperial Silk or Pandaria's Dark Soil triggers a Bind on Pickup prompt, the game's confirmation dialog appears under the cursor. The source must be enabled in the allowlist; you still decide whether to confirm or cancel.

## Optional YiboCore Integration

YiboCore is optional and is not included in this download. Without it, automatic opening and all four `/yao` commands work independently. Automatic opening is enabled by default, existing bags are scanned at login, at least 5 general bag slots are kept free, chat shows issues only, and eligible Bind on Pickup dialogs follow the cursor. These runtime options cannot be changed in game without Core. Install YiboCore API v13 with `localization:1` to manage them in the shared settings workbench, along with the catalog and confirmation-source allowlist.

---

# Yibo 自动开包 — 安全开启容器

Yibo 自动开包只会开启**你主动加入目录**的容器物品。它使用明确的允许列表，而不依赖客户端不稳定的“可开启”标记，因此目录中的诺米的点心等物品也能按同一规则处理。

## 功能

- 逐个开启目录中的容器物品。
- 默认在登录后扫描背包中已有的目录物品。
- 支持通过物品链接、ID、名称，或设置页拖放背包物品加入目录。
- 目录提供分页、物品名称刷新，以及手动清除本次登录隔离。
- 失败物品移至队尾，其它目录物品继续处理；副本/世界切换和手动刷新会重新核验敏感界面状态。
- 可选接入 YiboCore 的统一设置工作台。
- 未安装 YiboCore 时仍可通过 Slash 命令完整使用。

## 安全机制

战斗、死亡、载具、施法、拾取窗口、商店/银行等敏感界面，或通用背包空位低于设定阈值时，插件会暂停，不会冒险操作。

插件不会修改自动拾取设置、点击确认框、选择奖励，也不会猜测或开启未加入目录的未知容器。失败按物品独立重试和隔离，不会阻塞其它目录物品；战斗、读条、实际打开的敏感界面和空位不足仍会触发安全暂停。

## 命令

- `/yao add <物品链接、ID 或名称>`：加入允许目录。名称必须能唯一匹配；有重名时请使用链接或 ID。背包中的对应物品会进入自动开启队列。
- `/yao del <物品链接、ID 或名称>`：从允许目录移除，不会删除背包中的物品。
- `/yao list [页码]`：查看目录，每页最多 20 项；输入 `/yao list 2` 查看第 2 页。标记为“仅手动开启”的物品受游戏限制，不会自动开启。
- `/yao status`：查看队列是否运行或暂停及其原因、下一个可开启物品、本次登录隔离项目和待处理的确认框信息。

例如，输入 `/yao add 12345` 或 `/yao add <物品链接>` 添加，输入 `/yao list` 查看目录，输入 `/yao del 12345` 移除。没有物品开启时，用 `/yao status` 检查是否因战斗、敏感界面、空位不足或没有可处理物品而暂停。也可以在 Core 设置工作台把背包物品拖到目录中。

例如，帝王丝绸、潘达利亚的黑色泥土等白名单来源触发“拾取后绑定”提示时，游戏原生确认框会出现在鼠标下方。该来源必须已在白名单中启用；是否确定或取消仍由你决定。

## 可选接入 YiboCore

YiboCore 不是必需依赖，也不包含在本下载包中。未安装 Core 时，自动开包和四条 `/yao` 命令均可独立运行。自动开包默认启用，登录时扫描已有背包物品，至少保留 5 个通用背包空位，聊天仅提示问题，符合条件的“拾取后绑定”确认框默认跟随鼠标。没有 Core 时无法在游戏内修改这些运行选项；安装 YiboCore API v13 且提供 `localization:1` 的版本后，可在统一设置工作台管理这些选项、目录和确认框来源白名单。
