# YiboLegacyForeverProbe

非发布只读探针，为 `YiboLegacy` 的 Forever 客户端取证采集传承挑战、传承树和奖励轨道原始观察。不进入任何玩家包。测试清单见 [YiboLegacy 产品讨论与开发方向](../../YiboLegacy/产品讨论与开发方向.md#客户端取证)。

- 目标：仅 Forever（Interface `16001` 且 `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`），不匹配时停止采样。只有默认清单 `YiboLegacyForeverProbe.toc`。
- 命令：`/ylg scan` 完整快照；`/ylg ach 成就ID` 单项挑战；`/ylg report` 打开可复制摘要。
- 存档：`YiboLegacyForeverProbeDB`（schema 1，最多保留 8 个样本）。重载或正常退出后落盘于 `WTF/Account/<账号>/SavedVariables/YiboLegacyForeverProbe.lua`。结构未知时停止采样并保留原数据。
- 只读：调用为固定白名单，Slash 参数不作为 API 路径。不调用购买、退还、提交配点或加载 `Blizzard_LegacySystem`；暂存配点只观察。不依赖 Core，不写业务插件存档。

## 采集内容

| 部分 | 来源 |
|---|---|
| 身份 | `GetBuildInfo`、项目 ID、GUID、名称、等级、职业、语言、`C_GameRules.GetActiveGameMode`（可能不存在） |
| 常量 | `Constants.LegacyConsts` 全部键值 |
| 奖励轨道 | 奖励阵营的 `C_MajorFactions` 名望等级、阵营数据、等级列表及各级奖励 |
| 传承树 | 三棵树的配置 ID、配置/树信息、含暂存与仅已提交的点数、最大可用点数、节点信息 |
| 挑战 | 以各职业默认分类的根分类为范围，枚举 `GetCategoryList` 中的子分类、分类计数、每项成就信息、条件和单项传承点 |
| 场景 | 地图 ID、副本信息、区域名 |
| 事件 | 成就、条件、名望、天赋配置、换区、升级、技能变化的计数及最近 48 条参数 |

0.1.0 只扫描职业默认分类所在的根分类，L0 实测只得到职业 27 项，而 `GetCategoryList` 共返回 29 个分类。0.1.1 改为扫描整个分类列表，并在摘要中输出各级奖励、条件数和挑战描述。0.1.1 实测扫到 111 项成就，其中带传承点的正好 65 项，其余是探索类辅助成就。0.1.2 修正了两处：奖励按名望等级值（15/25/40/55）查询，此前误用列表序号；摘要只为带点挑战展开条件，辅助成就各压缩为一行 `sup`。

## 部署

2026-11-20 以同名 Junction 联接到 `D:/Program/World of Warcraft Forever/World of Warcraft/_forever_/Interface/AddOns/YiboLegacyForeverProbe`，两端 `Probe.lua` SHA256 一致，见 `Deployment-20261120.json`。0.1.0 已于同日在构建 70959 上由两个角色运行 L0，结果记录在 YiboLegacy 产品文档；0.1.1 沿用同一联接，`/reload` 后生效。
