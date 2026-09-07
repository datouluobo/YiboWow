# YiboQuestBlocker - Quest Blocking

YiboQuestBlocker is an account-wide quest blocking addon for **Mists of Pandaria Classic / China 5.5.4**.

Build a blocklist for quests you do not want, then keep those quests out of your quest log—even when you use supported auto-quest addons. Version 3 prioritizes blocking a matched quest before it is accepted, with the older safe-abandon flow retained as a fallback for unusual paths.

## Highlights

- Block quests account-wide or only for a specific character.
- Add quests from your current quest list, or enter a quest ID manually.
- Choose one processing mode:
  - **Reject** — decline blocked quests before acceptance whenever possible.
  - **Abandon** — use the legacy post-acceptance safe-abandon flow.
  - **Pause** — keep all rules and data, but take no automatic or manual quest action.
- Use the YiboCore account page to compare blocked quests across characters.
- Filter character data by level, sort characters, and maintain a custom character order.
- Use Broker and optional minimap entries managed by YiboCore; their hover preview shows the same account quest-blocking view.
- Open the addon page with `/yqb`.

## Auto-Quest Compatibility

| Addon | Reject-mode status |
| --- | --- |
| `!Pig` | Supported |
| NDui QuickQuest | Supported |
| Questie | Disable Questie's auto-accept feature while using Reject mode. Questie’s other features can remain enabled. |
| Leatrix Plus | Disable its auto-accept feature while using Reject mode. Its other features can remain enabled. |
| DialogueUI | No auto-quest adapter is needed; it does not provide auto-quest behavior. |

For unknown or unverified auto-quest addons, YiboQuestBlocker safely falls back to direct rejection only. It does not take over their task-selection logic or promise seamless continuation after a blocked quest.

## Requirements

**YiboCore is required and is not included in this download.** Install and enable both addons.

[Download YiboCore](https://www.curseforge.com/wow/addons/yibocore)

Supported client: Mists of Pandaria Classic / China 5.5.4.

---

# YiboQuestBlocker - 任务屏蔽

YiboQuestBlocker 是用于 **魔兽世界：熊猫人之谜怀旧服 / 国服 5.5.4** 的账号级任务屏蔽插件。

将不想接取的任务加入屏蔽列表后，即使启用了已支持的自动接任务插件，也会尽量让这些任务不进入任务日志。v3 优先在接取前拦截命中的任务；少数特殊路径仍保留原有的安全放弃兜底。

## 功能

- 支持账号全局任务屏蔽和角色专属任务屏蔽。
- 可从当前任务列表直接加入屏蔽，也可手动输入任务 ID。
- 提供三种处理模式：
  - **拒绝**：尽可能在接取前拒绝已屏蔽任务。
  - **放弃**：使用旧版的接取后安全放弃流程。
  - **暂停**：保留规则和数据，但不执行自动或手动任务处理。
- 在 YiboCore 统一账号页面中跨角色查看任务屏蔽情况。
- 支持等级过滤、角色排序和自定义角色顺序。
- Broker 与可选小地图入口由 YiboCore 统一管理；悬停预览与账号页使用同一份任务屏蔽数据。
- 使用 `/yqb` 打开插件页面。

## 自动接任务兼容性

| 插件 | 拒绝模式状态 |
| --- | --- |
| `!Pig` | 已支持 |
| NDui QuickQuest | 已支持 |
| Questie | 使用拒绝模式时，请关闭 Questie 的自动接任务功能；其它功能可继续使用。 |
| Leatrix Plus | 使用拒绝模式时，请关闭其自动接任务功能；其它功能可继续使用。 |
| DialogueUI | 不提供自动接任务功能，无需适配器。 |

对于未知或未经验证的自动接任务插件，YiboQuestBlocker 会安全降级为仅直接拒绝：不会接管对方的任务选择逻辑，也不会承诺跳过屏蔽任务后仍能无缝继续自动接取。

## 依赖与支持版本

**必须同时安装并启用 YiboCore；本下载包不包含 YiboCore。**

[下载 YiboCore](https://www.curseforge.com/wow/addons/yibocore)

支持客户端：Mists of Pandaria Classic / 国服 5.5.4。
