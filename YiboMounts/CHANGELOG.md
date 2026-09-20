# YiboMounts Changelog / 更新日志

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
