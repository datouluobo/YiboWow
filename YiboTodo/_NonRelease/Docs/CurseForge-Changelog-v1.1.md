# YiboTodo 1.1

## 中文

### 当前角色动作

- 账号待办中的当前角色图标现支持安全点击：诺米图标可召唤/解散诺米，右键会选中诺米；其它角色仍保持只读。
- 专业冷却图标现在可打开对应专业，并在专业面板已载入时尝试制作一份对应配方；右键始终只打开专业面板。
- 动作结果仍以游戏事件和专业快照为准：不会因点击而提前把待办标记为完成或冷却，失败也不会自动重试。

### 待办追踪与显示

- 暗月马戏团仅在确认开放期间显示；当日历数据尚未载入时，会按首个周日开始、持续七天的规则判断活动窗口。
- 当前角色的可操作图标会在 Tooltip 中明确说明左键与右键的行为；跨角色项目不会提供远程操作。

### 诊断与可靠性

- 新增商业冷却动作诊断命令：`/ytd action-debug`。
- 改进专业窗口刷新与角色切换之间的绑定，避免延迟扫描把冷却记录写入错误角色。

**依赖：** 必须同时安装并启用 [YiboCore](https://www.curseforge.com/wow/addons/yibocore)；本下载不包含 YiboCore。

---

## English

### Current-character actions

- Current-character icons in the account Todo view now support secure clicks: the Nomi icon can summon/dismiss Nomi, and right-click targets Nomi. Other characters remain read-only.
- Profession cooldown icons can now open their profession and, after the profession window is loaded, attempt to craft one matching recipe. Right-click always opens the profession window only.
- Results are still confirmed by game events and profession snapshots. Clicking never marks a Todo complete or on cooldown early, and failed actions are not retried automatically.

### Todo tracking and display

- Darkmoon Faire is shown only while it is confirmed to be active. If calendar data has not loaded yet, the activity window falls back to the first Sunday of the month and the following seven days.
- Tooltips now clearly state left- and right-click behavior for actionable current-character icons; cross-character projects do not expose remote actions.

### Diagnostics and reliability

- Added the profession-cooldown action diagnostic command: `/ytd action-debug`.
- Improved the binding between profession-window refreshes and character changes, preventing delayed scans from writing cooldown records to the wrong character.

**Dependency:** [YiboCore](https://www.curseforge.com/wow/addons/yibocore) must be installed and enabled. It is not included in this download.
