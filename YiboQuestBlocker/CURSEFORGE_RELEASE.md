# YiboQuestBlocker v3.0.1

## 更新 / What's New

- 已屏蔽任务现在会优先在接取前跳过或拒绝，并保留自动放弃作为异常兜底。 / Blocked quests are now skipped or declined before acceptance, with automatic abandonment retained as a fallback.
- 新增“拒绝 / 放弃 / 暂停”处理模式。 / Added **Reject / Abandon / Pause** processing modes.
- 账号页、Broker、小地图入口与悬停预览已统一接入 YiboCore。 / The account page, Broker, minimap entry, and hover preview are now unified through YiboCore.
- 优化任务矩阵与角色管理，支持折叠任务分组。 / Improved the quest matrix and character management, including collapsible quest groups.

## 自动接任务兼容性 / Auto-Quest Compatibility

- 支持：`!Pig`、NDui QuickQuest。 / Supported: `!Pig`, NDui QuickQuest.
- 不兼容拒绝模式：Questie、Leatrix Plus。使用 YiboQuestBlocker 时，请关闭它们的自动接任务功能；其它功能可继续使用。 / Incompatible with Reject mode: Questie and Leatrix Plus. Disable their auto-quest features when using YiboQuestBlocker; their other features can remain enabled.
- DialogueUI 不提供自动接任务功能，不列入适配状态。 / DialogueUI does not provide auto-quest functionality and is not included in the compatibility status.
