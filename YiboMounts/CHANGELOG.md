# YiboMounts Changelog / 更新日志

## 0.8.4

### 中文

- 固化完整怀旧服分支边界，恢复曾在 5.5.4 分支出现的坐骑目录项。
- 补齐本轮坐骑来源路径；已确认进入目录的坐骑只补充信息，不因来源暂缺反复增删。

## 0.8.3

### 中文

- 修复敌对阵营或坐骑日志 ID 失配时，已拥有坐骑被误报为未拥有的问题。
- 按 spellID 校验并重新解析当前坐骑日志；无法可靠判定时保持静默。

### English

- Fixed collected mounts being reported as uncollected for opposing factions or stale journal IDs.
- Validated and re-resolved current journal entries by spellID, while keeping uncertain states silent.

## 0.8.2

### 中文

- 补充“风暴乌鸦”（spellID 1298512）到运行时坐骑目录，并记录其挑战模式白金币兑换来源。
- 补全挑战模式坐骑来源：四只熊猫人凤凰、风暴乌鸦、冰霜巨龙、幽灵驭风者、魔法公鸡与白毛犀牛，并记录白金币价格。

### English

- Added Storm Crow (spellID 1298512) to the runtime mount catalog with its Challenge Mode Platinum Coin source.
- Normalized Challenge Mode sources for the four Pandaren Phoenixes, Stormcrow, Juvenile Frostwyrm, Spectral Wind Rider, Magic Rooster, and Wooly White Rhino, including Platinum Coin prices.

## 0.8.1

### 中文

- 设置页改为两个独立选项：显示已拥有、显示未拥有；移除总开关。
- 修复收藏状态设置选项无法正常切换的问题。

### English

- Replaced the collection-status master switch with two independent options: show collected and show uncollected.
- Fixed collection-status settings not toggling correctly.

## 0.8

### 中文

- 新增账号级坐骑收藏状态提示，可在 YiboCore 设置中分别控制已拥有与未拥有状态。
- 坐骑收藏面板沿用游戏原生收藏状态；玩家自身坐骑光环不重复显示收藏状态。
- 未知收藏状态保持静默，不误报为未拥有。
- 修复 Core 设置面板递归刷新、维护页按钮重叠和设置导航重复条目问题。

### English

- Added account-wide mount collection status tooltips with separate YiboCore controls for collected and uncollected mounts.
- The Mount Journal keeps its native collection state, and the player's own mount auras no longer repeat it.
- Unknown collection states remain silent instead of being reported as uncollected.
- Fixed recursive Core settings refreshes, overlapping maintenance buttons, and duplicate settings navigation entries.

## 0.7

### 中文

- 现在支持在坐骑面板中悬停坐骑，查看对应的获取来源。
- 现在支持在聊天框中悬停坐骑链接或坐骑法术链接，查看对应的获取来源。
- 坐骑面板与聊天链接复用现有坐骑图鉴数据和来源格式化逻辑。
- 未收录或未知链接保持静默，不影响原生 Tooltip 显示。
- 保留原有坐骑 Aura Tooltip 行为，并处理重复来源追加。

### English

- Mount tooltips in the Mount Journal now show the corresponding acquisition source.
- Hovering a mount link or mount spell link in chat now shows the corresponding acquisition source.
- Mount Journal and chat-link tooltips reuse the existing mount catalog and source formatting logic.
- Unknown or untracked links remain silent and do not alter the native tooltip.
- Existing mount-aura tooltip behavior is preserved, with duplicate source lines suppressed.
