# Yibo 系列插件技术名、简称与 Slash 命令清单

本文记录工作区当前顶层 Yibo 插件的技术名、简称与 Slash 命令，供开发、命令分配与冲突检查时查询。

简称是从技术名提取的便于阅读写法，不代表另有一套正式命名或登记规则。命令以插件源码中的 `SLASH_*` 注册为准。

| 技术名 | 简称 | Slash 命令 |
|---|---|---|
| `YiboAltoBoss` | AltoBoss | `/yab` |
| `YiboAutoOpen` | AutoOpen | `/yao` |
| `YiboBeastPaths` | BeastPaths | `/ybp` |
| `YiboBuilds` | Builds | `/ybb` |
| `YiboCore` | Core | `/yco` |
| `YiboCrafting` | Crafting | `/ycr` |
| `YiboCurrency` | Currency | `/ycu` |
| `YiboLegendary` | Legendary | `/yle` |
| `YiboMail` | Mail | `/yma` |
| `YiboMounts` | Mounts | `/ymt` |
| `YiboQuestBlocker` | QuestBlocker | `/yqb` |
| `YiboReputation` | Reputation | `/yrp` |
| `YiboTaskHub` | TaskHub | `/yth` |
| `YiboTodo` | Todo | `/ytd` |
| `YiboVault` | Vault | `/yva` |

## 冲突检查

- 当前列出的 15 个插件技术名各不相同，Slash 命令也没有重复。
- 所有主 Slash 命令均为三个英文字母，符合仓库命令长度约定。
- 同一插件在不同客户端目标实现中注册相同命令属于目标版本实现，不视为插件间冲突；每个目标安装包只加载适用的实现。
- 工作区中的 `YiboCore for MoP` 目录未发现 TOC 或 Slash 注册，不计入当前插件清单。

## 独立探针命令

独立游戏探针使用唯一三字母命令，避免复用业务插件主命令。每次新增或修改先全工作区搜索 `SLASH_*`，确认无冲突后同步登记。

| 探针技术名 | Slash 命令 | 状态 |
|---|---|---|
| `YiboLocaleProbe` | `/ylp` | 已占用 |
| `YiboProgressForeverProbe` | `/ypg` | 已占用；2026-11-03已联接无限正式客户端，待运行核验 |
| `YiboAltoBossForeverProbe` | `/yaf` | 已占用；2026-11-03已联接无限正式客户端，待运行核验 |
| `YiboBuildsForeverProbe` | `/ybf` | 已占用；2026-11-03已联接无限正式客户端，待运行核验 |
| `YiboLegendaryProbe` | `/yep` | 已占用；Mists 原生 API 采样 |
| `YiboMountsProbe` | `/ymp` | 已占用；Mists 原生 API 采样 |
| `YiboTodoProbe` | `/ytp` | 已占用；Mists 原生 API/事件采样 |
| `YiboCurrencyProbe` | `/ycp` | 已占用；Mists 原生金币与货币列表采样 |

探针命令具体用途及链接状态以各探针 README 和客户端 Junction 实查为准；本表记录命令占用，历史探针未登记或没有 Slash 命令不推定可复用。

## 维护说明

新增插件或变更 Slash 命令时，先全工作区搜索 `SLASH_*` 注册，确认命令未被占用，再同步更新本表。正式命令不得保留旧命令别名；具体规则见仓库 `AGENTS.md` 的“插件 Slash 命令”约定。
