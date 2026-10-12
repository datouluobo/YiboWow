# YiboQuestBlocker

**Dependencies:** Required — [YiboCore](https://www.curseforge.com/wow/addons/yibocore) (API v5+).

## The YiboCore framework

YiboCore is the shared account window, character directory, and settings framework for Yibo addons. This addon requires [YiboCore](https://www.curseforge.com/wow/addons/yibocore) to provide its account page and shared entry.

Keep unwanted quests out of your log, even when you use an automatic quest-acceptance addon.

## What makes it useful

Rules can act before a blocked quest is accepted and can be shared account-wide or scoped to one character, with pause and abandon modes. This addresses a common pain point: unwanted quests can be stopped before automatic acceptance puts them in the quest log.

## Features

- Account-wide and per-character quest blocklists.
- Add quests from the current quest list or by quest ID.
- Decline, abandon, and pause modes with a fallback abandonment queue.
- A quest-by-character management matrix and matching hover preview.
- Filters for quest type, completed quests, and character levels.

## Getting started

Use `/yqb`, add unwanted quests to the global or character list, then choose a processing mode. Pause temporarily when you want to keep all rules but stop handling quests.

## Requirements and data

Mists of Pandaria Classic; packaged for client 5.5.4. Requires [YiboCore](https://www.curseforge.com/wow/addons/yibocore), API v5 or later. Keep Core updated together with this addon.

Auto-acceptance compatibility varies. Supported adapters include !Pig and NDui QuickQuest; disable Questie or Leatrix Plus auto-acceptance when using refusal mode. Game restrictions can prevent some abandon operations.

## Feedback

Report issues in this project's CurseForge comments with the addon version, client version, and steps to reproduce.

---

# YiboQuestBlocker · 任务屏蔽

**依赖：** 强依赖 — [YiboCore](https://www.curseforge.com/wow/addons/yibocore)（API v5+）。



## YiboCore 框架

YiboCore 为 Yibo 插件提供统一账号窗口、角色目录与设置工作台。本插件需要 [YiboCore](https://www.curseforge.com/wow/addons/yibocore) 承载账号页和统一入口。

将不想接的任务加入屏蔽规则，配合自动接任务插件使用。

## 特点与解决的问题

自动接任务工具可能把不需要的任务加入日志；可在接取前拒绝，并按账号或角色管理与临时暂停。
解决的痛点：避免自动接取流程把屏蔽任务先加入任务日志。

## 主要功能

- 账号共享与角色独立任务屏蔽列表。
- 从当前任务列表或按任务 ID 添加规则。
- 提供拒绝、放弃与暂停模式，以及兜底放弃队列。
- 任务与角色矩阵管理，并提供同数据悬停预览。
- 按任务类型、完成状态和角色等级筛选。

## 开始使用

使用 `/yqb`，把任务加入全局或角色屏蔽列表后选择处理模式；暂时不想处理时可暂停并保留规则。

## 运行需求与数据说明

熊猫人之谜经典版；当前发布包对应 5.5.4 客户端。需要 [YiboCore](https://www.curseforge.com/wow/addons/yibocore) API v5 或更新版本，建议与业务插件一起更新。

自动接任务兼容性取决于具体插件。适配包含 !Pig、NDui QuickQuest；使用拒绝模式时关闭 Questie 或 Leatrix Plus 的自动接取。部分放弃操作仍受游戏限制。

## 问题反馈

请在本项目 CurseForge 评论中提供插件版本、客户端版本与复现步骤。
