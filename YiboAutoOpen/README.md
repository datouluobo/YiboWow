# YiboAutoOpen 1.2.3

Safely opens containers from an explicit account-wide allowlist, one at a time. By default, the addon scans items already in your bags after login.

YiboCore is optional and is not required to run the addon. Without Core, automatic opening and all four `/yao` commands work independently. The commands let you add, remove, and review catalog items and inspect runtime status. The shared settings workbench requires YiboCore API v13 with `localization:1`; a compatible Core can manage the automatic-opening toggle, login scan, free-space threshold, chat notifications, catalog, and confirmation-dialog position.

### Using YiboAutoOpen without YiboCore

Automatic opening is enabled by default and existing bag items are scanned at login. The default minimum is 5 free general bag slots; chat notifications show issues only; eligible Bind on Pickup dialogs follow the cursor. Without the Core settings page, these runtime options cannot be changed with `/yao`; install YiboCore API v13 with `localization:1` to adjust them. You can still fully manage the allowlist and inspect status with these commands:

- `/yao add <item link, ID, or name>` — add an item to the allowlist. Names must resolve uniquely; use an item link or ID if a name is ambiguous. Matching items in your bags enter the opening queue.
- `/yao del <item link, ID, or name>` — remove an item from the allowlist. This does not remove the item from your bags.
- `/yao list [page]` — list catalog items, up to 20 per page. For example, `/yao list 2` shows the next page. Items marked “manual only” are restricted by the game and will not be opened automatically.
- `/yao status` — show whether the queue is running or paused and why, the next eligible catalog item, items isolated for this login, and pending confirmation details.

For example, enter `/yao add 12345` or provide an item link to add it. In the Core settings workbench, you can also drag an item from your bags into the catalog. Use `/yao del 12345` to remove it and `/yao list` to review the catalog. If nothing opens, use `/yao status` to see whether combat, a sensitive interface, low free space, or the absence of an eligible item is holding the queue.

With YiboCore installed, confirmation-dialog positioning applies only to allowlisted sources: containers opened by YiboAutoOpen and game objects you explicitly add from the recent-object list. When cursor placement is disabled, the dialog stays in its native game position.

### Failure isolation and recovery

- Automatic timeout or failure isolation (`retry-backoff`) clears when its backoff expires or a world-recovery event occurs.
- World recovery and the settings-page “Refresh / Retry” action rebuild pause markers from currently visible sensitive interfaces. A genuinely open sensitive interface continues to pause the queue.
- A failed item moves to the end of the candidate queue so other distinct items get a chance first. Each item has its own retry count; automatic failure isolation begins only after all candidates reach their retry limits.
- Combat, casting, player-state checks, and incomplete bag data are temporary safety pauses, not session isolation.
- If you cancel a Bind on Pickup prompt, that item is skipped for the rest of the login session. Only a manual retry or removing and re-adding the item clears this choice.
- New-item events clear automatic-failure isolation but do not override a player's cancellation.

YiboAutoOpen does not change Auto Loot, click confirmation dialogs, or choose rewards. When opening an item triggers a Bind on Pickup prompt, the native dialog may move under the cursor, but you must click Confirm or Cancel yourself. Abyssal Clam (52340) is manual-only on MoP Classic and is skipped. The queue pauses during combat, death, vehicles, casting, loot windows, sensitive interfaces, or insufficient general bag space. Other candidate items continue to receive their turn before individual failed items are retried and isolated. See [queue and recovery rules](../Docs/YiboAutoOpen-队列与失败恢复规则.md) for details.

For example, when a whitelisted source such as Imperial Silk triggers a Bind on Pickup prompt, the native confirmation dialog appears under the cursor. The source must be enabled, and you decide whether to confirm or cancel.

### Action Hub integration (2026-10-10)

Not applicable: the immediate opening queue has no separate persistent goal, so its action button is not converted into a to-do. See the [implementation and verification record](../Docs/行动中心-主动添加实施与验证.md) for the contract, automation, and remaining client acceptance scope.

### Icon assets (2026-10-14)

The current icon uses `Media/YiboAutoOpenIcon`: the default TGA is 64 px and the addon-list TGA is 128 px. PNG sizes are 16, 24, 32, 64, 128, 512, and 1024 px; the transparent raster master is 312 px. See the [series asset record](../Docs/Design/Yibo系列Logo-20261014/README.md) for versioning, scaling, and verification.

![YiboAutoOpen icon](Media/YiboAutoOpenIcon-128.png)

---

# YiboAutoOpen 1.2.3

安全地逐个开启账号目录中的容器。目录是明确的允许列表，不依赖客户端并不稳定的“可拾取”标记；默认会在登录时扫描已有物品。

YiboCore 是可选增强，不是运行依赖。未安装 Core 时，自动开包和下方四个 `/yao` 命令仍可独立使用；物品目录可通过命令添加、删除和查看。统一设置工作台要求 YiboCore API v13 与 `localization:1`；兼容版本可管理自动开包开关、登录扫描、空位阈值、聊天提示、目录和确认框位置。

### 未安装 YiboCore 时

插件默认启用自动开包，并在登录时扫描已有背包物品。默认至少保留 5 个通用背包空位，聊天仅提示问题；符合条件的拾取后绑定确认框默认跟随鼠标。没有 Core 设置页时，这些运行选项不能通过 `/yao` 修改；如需调整，请安装 YiboCore API v13 且提供 `localization:1` 的版本。命令仍可完整管理自动开包目录并查看运行状态：

- `/yao add <物品链接、ID 或名称>`：把物品加入允许自动开启的目录。名称必须能唯一匹配；有重名时请使用物品链接或 ID。加入后，背包中该物品会进入自动开启队列。
- `/yao del <物品链接、ID 或名称>`：从目录移除物品，不会删除背包中的物品。
- `/yao list [页码]`：按页查看目录，每页最多 20 项；输入 `/yao list 2` 等可查看后续页。标记“仅手动开启”的物品受游戏限制，不会被自动开启。
- `/yao status`：查看暂停或运行原因、下一个可开启的目录物品、临时隔离项目和待处理的确认框信息。

例如，输入 `/yao add 12345` 或把物品链接作为参数添加；也可以在兼容的 Core 设置工作台中拖放背包物品加入目录。输入 `/yao del 12345` 移除，输入 `/yao list` 核对目录。若暂时没有物品开启，可用 `/yao status` 查看是否因战斗、敏感界面、空位不足或当前没有合适物品而暂停。

安装符合要求的 Core 后，确认框位置设置只作用于白名单来源：YAO 自己打开的目录箱子，以及通过“最近可添加对象”主动加入的游戏对象。关闭该选项后，确认框保留游戏原生位置。

命令：

- `/yao add <物品链接、ID 或名称>`
- `/yao del <物品链接、ID 或名称>`
- `/yao list [页码]`
- `/yao status`

失败隔离清除规则：

- 自动开启超时或失败造成的 `retry-backoff` 隔离，退避计时结束或世界恢复事件到来时自动清除。
- 世界恢复和设置页“刷新/重新尝试”会根据游戏当前可见的敏感界面重建暂停标记，修复副本切换或界面关闭事件遗漏导致的陈旧暂停；真实打开的敏感界面仍会暂停。
- 失败物品会移到候选队列末尾；只要还有其它不同物品待开，就先处理其它物品。每个物品独立计数，队列候选均达到重试上限后才逐项进入自动失败隔离。
- 读条、战斗、施法、玩家状态和背包数据未完成只属于临时安全状态，不会升级为会话隔离。
- 玩家主动取消“拾取后绑定”确认造成的 `bind-cancelled` 隔离，会保留到本次登录结束；只有设置页“重新尝试”、删除后重新加入目录等明确人工操作可以清除。
- 新物品事件只清除自动失败隔离，不会覆盖玩家主动取消的决定。

插件不会改变游戏的自动拾取设置、不会点击确认框，也不会选择奖励。YAO 自动开启物品而触发“拾取后绑定”确认时，会把该游戏原生确认框临时移到触发时的鼠标位置，仍须由玩家亲自点“确定”或“取消”；取消后该物品仅在本次登录跳过。深渊蚌（52340）在 MoP 客户端只能手动开启，YAO 会跳过它。战斗、死亡、载具、施法、拾取窗口、敏感界面或通用背包空位不足时会暂停。队列中其它不同物品先各自获得处理机会；候选耗尽后，对单项有界重试并隔离失败项，不会让一个坏物品堵住整个队列。完整规则见 `Docs/YiboAutoOpen-队列与失败恢复规则.md`。

例如，帝王丝绸等白名单来源触发“拾取后绑定”提示时，游戏原生确认框会出现在鼠标下方；该来源必须已启用，是否确定或取消仍由你决定。


## 行动中心主动添加（2026-10-10 工作树）

本轮审查为不适用：即时开箱队列没有独立持久目标，不把执行按钮转换为待办。

实际契约、自动化与客户端待验收范围见 [实施与验证](../Docs/行动中心-主动添加实施与验证.md)。

## 图标资源（2026-10-14）

当前图标为 `Media/YiboAutoOpenIcon`：默认TGA为64px，插件列表使用128px TGA；PNG提供16/24/32/64/128/512/1024px，母版为312px透明位图。版本、统一缩放和验证范围见[系列资源记录](../Docs/Design/Yibo系列Logo-20261014/README.md)。

![YiboAutoOpen 图标](Media/YiboAutoOpenIcon-128.png)
