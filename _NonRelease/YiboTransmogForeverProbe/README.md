# YiboTransmogForeverProbe

这是一个不发布的只读探针，用于在 Forever 客户端为 `YiboTransmog` 采集外观收藏、来源、套装、任务奖励和幻化显示状态的原始数据。它不进入任何玩家包。测试清单见 [YiboTransmog 产品讨论与开发方向](../../YiboTransmog/产品讨论与开发方向.md#测试清单)。

- **目标**：只支持 Forever，判定条件为 Interface `16001` 且 `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`，不匹配时停止采样。只有默认清单 `YiboTransmogForeverProbe.toc`。
- **命令**：
  - `/ytf scan`：总快照，包括身份、显示状态、各分类计数和套装。
  - `/ytf item 物品ID或链接`：单件物品的外观与全部来源。
  - `/ytf cat 分类ID`：单个分类的外观列表和来源类型分布，最多扫描 800 个外观。
  - `/ytf bags`：背包 0–4 中可装备物品的外观状态，最多 48 件。
  - `/ytf quest`：打开任务窗口时读取奖励。任务交付窗口打开时会自动采样一次，不会替你选择或交付。
  - `/ytf verify`：核对最近一次交付的任务。交付 3 秒后会自动执行一次，之后可以手动重复。
  - `/ytf report`：打开最近一次样本的可复制摘要。
- **任务奖励核对（0.1.1）**：
  - 摘要的 `questApi` 行列出 `GetNumQuestChoices`、`GetQuestItemLink`、`GetQuestItemInfo`、`GetQuestReward` 等是否存在。
  - 对 `GetQuestReward` 做后置钩子，只记录玩家选了第几项，原函数照常执行。
  - 交付后，把每件奖励交付前的收集状态和当前状态对照，并检查交付窗口打开后是否收到 `SOURCE_ADDED`。
  - 结论为四种之一：`unlocked`（已解锁）、`not-unlocked`（未解锁）、`already-had`（交付前已拥有）、`no-appearance`（物品无外观）。汇总行 `unchosenUnlocked 已解锁 / 可判定` 统计未选奖励。
- **存档**：`YiboTransmogForeverProbeDB`（schema 1），最多保留 24 个样本，`/reload` 或正常退出后写入 `WTF/Account/<账号>/SavedVariables/YiboTransmogForeverProbe.lua`。存档结构无法识别时停止采样，原数据不动。
- **只读**：调用的接口是固定白名单，Slash 参数只作为物品 ID、物品链接或分类号使用。不调用任何筛选、套装收藏、外观收藏、场景、CVar 或幻化的设置函数，不依赖 Core，也不写业务插件存档。
- **事件**：完整记录 `TRANSMOG_COLLECTION_SOURCE_ADDED`／`REMOVED` 和装饰品新增，每次会话最多 200 条，并附来源物品，用于核对拾取、交付任务后实际解锁了哪些外观。CVar、对话、任务、拾取、换区和战场事件只记计数和最近 64 条参数。

## 采集内容

| 部分 | 来源 |
|---|---|
| 身份 | `GetBuildInfo`、项目 ID、GUID、名称、等级、职业、语言、游戏模式、体验预设 `C_GameRules.GetForeverExperiencePreset` |
| 显示状态 | `C_TransmogOutfitInfo.IsTransmogEnabled`、场景开关与场景分类、当前外观方案、方案数量、幻化活动、是否在幻化师旁；名称含 transmog/wardrobe/appearance/outfit 的 CVar（仅在客户端能列出命令时采集） |
| 筛选状态 | 已收集与未收集的显示开关、默认筛选、职业筛选，只读不改 |
| 分类计数 | 枚举 `Enum.TransmogCollectionType` 中的每个分类，记录名称、已收集数、总数和筛选后计数 |
| 套装 | `GetAllSets` 的总数、已收集、收集前隐藏、本角色可用、限时套装和按资料片分布，以及前 40 套明细 |
| 物品 | 物品信息、外观 ID 与来源 ID、玩家或账号能否收集、是否已知、掉落、节日要求、所属套装，以及同一外观的其他来源 |
| 任务奖励 | 任务 ID、标题、可选奖励和固定奖励的链接、是否可用，以及每件奖励的外观状态 |

## 部署

2026-11-21 0.1.1 增加了任务奖励核对，沿用同一联接。同日在构建 70959 上完成 T0 与 T3，结果记录在 YiboTransmog 产品文档的「T0／T3 结果」。2026-11-22 在构建 71037 上完成 T1 与 T2。之后升级到 0.1.2：没有物品奖励的任务不再自动采样，样本上限改为 24；沿用同一联接，`/reload` 后生效。

2026-11-21 以同名 Junction 联接到 `D:/Program/World of Warcraft Forever/World of Warcraft/_forever_/Interface/AddOns/YiboTransmogForeverProbe`，两端 `Probe.lua` 的 SHA256 一致，见 `Deployment-20261121.json`。目前只完成了离线检查，还没有在客户端运行。新增插件目录后，需要完整退出游戏再重新进入才能识别。
