# YiboLegendary 2.0.1

## 中文

### 传说目标目录

- 传说之路现以账号级“角色 × 传说目标”矩阵展示进度；完整页面、Broker 和小地图悬停共用同一份角色快照。
- 正式支持三条路线：MoP 传说披风、雷霆之怒，逐风者的祝福之剑，以及索利达尔，群星之怒。
- 新增索利达尔追踪：自动识别背包或装备中的物品；历史获得可由玩家手动确认，且会明确标注为“玩家确认”。
- 目录新增萨弗拉斯、黑色其拉作战坦克、埃提耶什、埃辛诺斯战刃、瓦兰奈尔、影之哀伤、巨龙之怒和龙父之牙等后续目标占位；其中绝版目标归入单独的“绝版”目录。尚未接入采集器的目标不会生成角色进度。

### 体验与可靠性

- 悬停预览改为按目标显示图标、状态和进度；空间不足时只分页目标列，角色列和表头保持一致。
- 完整页面新增目标目录与路线说明，角色表仍显示当前检查点、进度和下一步。
- 目标页、悬停预览、Broker 和小地图入口会即时读取同一份最新快照；测试投影不会写入真实角色进度。
- 优化目录和矩阵在窄窗口、UI 缩放及刷新时的布局与滚动稳定性。
- 删除角色缓存时，会一并清除该角色的传说快照、人工确认和本次登录的测试投影；其它角色数据及全局设置不受影响。

**依赖：** 必须同时安装并启用 [YiboCore](https://www.curseforge.com/wow/addons/yibocore)；本下载不包含 YiboCore。

---

## English

### Legendary catalog

- Legendary Journey now uses an account-wide character-by-legendary matrix. The full page, Broker tooltip, and minimap tooltip share the same character snapshots.
- Three routes are now supported: the MoP Legendary Cloak, Thunderfury, Blessed Blade of the Windseeker, and Thori'dal, the Stars' Fury.
- Added Thori'dal tracking with automatic inventory/equipment detection and clearly labeled player-confirmed evidence for historical ownership.
- Added catalog entries for future targets, including Sulfuras, the Black Qiraji Battle Tank, Atiesh, Warglaives of Azzinoth, Val'anyr, Shadowmourne, Dragonwrath, and Fangs of the Father. Archived targets are grouped under a separate Archived view; targets without a collector do not create character progress.

### Usability and reliability

- Tooltip previews now display target icons, states, and progress. When space is limited, only target columns paginate, keeping the character column and header aligned.
- The full page now includes a target catalog and route details alongside each character's checkpoint, progress, and next step.
- The page, tooltips, Broker, and minimap entry all consume the same latest snapshot. Test projections never overwrite real character progress.
- Improved matrix layout and scrolling stability for narrow windows, UI scaling, and refreshes.
- Removing a character cache also removes only that character's legendary snapshot, manual evidence, and current-session test projection; other characters and global settings remain intact.

**Dependency:** [YiboCore](https://www.curseforge.com/wow/addons/yibocore) must be installed and enabled. It is not included in this download.
