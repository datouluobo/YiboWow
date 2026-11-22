# Yibo Addon Suite - Account QoL Addons - Mists of Pandaria Classic - v1.2.0

Local release candidate / 本地发布候选；not uploaded / 未上传。

Suite snapshot containing all 15 Yibo addons released for Mists of Pandaria Classic. Component versions remain independent.
本整合包包含 熊猫人之谜怀旧服 已发布的全部 15 个 Yibo 插件。整合包与各插件分别维护版本号。

Source snapshot SHA256: 79e53c21d3f04de60c1abb89ae07a006df594760396cd37948846613173a89cb

## Included components / 本文件包含的具体组件

| Addon | Version | Required TOC dependencies / 必须依赖 | Optional TOC dependencies / 可选依赖 | Minimum Core API / 最低 Core API |
|---|---|---|---|---|
| YiboAltoBoss | 2.9.0 | YiboCore | - | 14 |
| YiboAutoOpen | 1.2.7 | - | YiboCore | Runtime capability check / 以运行时能力检查为准 |
| YiboBeastPaths | 1.10.0 | - | YiboCore | Runtime capability check / 以运行时能力检查为准 |
| YiboBuilds | 1.6.0 | YiboCore | - | 14 |
| YiboCore | 1.13.0 | - | LibDataBroker-1.1 | Provides API 14 |
| YiboCrafting | 1.3.0 | YiboCore | - | 14 |
| YiboCurrency | 1.1.3 | YiboCore | - | 13 |
| YiboLegendary | 2.3.0 | YiboCore | - | 14 |
| YiboMail | 1.4.0-api1 | YiboCore | - | 14 |
| YiboMounts | 1.0.3 | - | YiboCore | Runtime capability check / 以运行时能力检查为准 |
| YiboQuestBlocker | 3.2.0 | YiboCore | - | 14 |
| YiboReputation | 1.8.0 | YiboCore | - | 14 |
| YiboTaskHub | 0.7.0 | YiboCore | - | 14 |
| YiboTodo | 1.3.0 | YiboCore | - | 14 |
| YiboVault | 1.3.0-api1 | YiboCore | - | 14 |

## Installation, removal and update rules / 安装、删减与更新规则

# Yibo Addon Suite installation / 安装说明

Yibo Addon Suite is published as one package per game client: a Mists of Pandaria Classic package (`mists`) and a Forever package (`forever`). Each package contains every Yibo addon released for that client; each download contains a fixed component snapshot and every addon retains its own version. See the file changelog for the exact component versions. Install only the package for the client you play.

Yibo Addon Suite 按游戏客户端分别提供整合包：熊猫人之谜怀旧服（`mists`）与无限服（`forever`）。每个包含该客户端已发布的全部 Yibo 插件；整合包版本标识一次固定组件快照，各插件保留自己的版本号，具体版本以本次下载附带的 CHANGELOG 为准。只安装与所玩客户端对应的整合包。MoP 包内的 BeastPaths 维护包保留正式服 TOC，不代表整合包支持正式服。
## Manual installation / 手动安装

Exit WoW. Extract the addon folders directly into the matching client's Interface/AddOns directory. Keep the original folder names. `YiboCore/` is the primary addon folder; the other addon folders sit beside it.

完整退出游戏，把 ZIP 内各插件目录直接解压到对应客户端的 Interface/AddOns 下，保留目录名。`YiboCore/` 是主体插件目录，其余插件目录与它并列。

## Components and dependencies / 组件与依赖

All business addons may be disabled or removed individually. Keep YiboCore enabled while any addon marked as requiring it remains enabled. AutoOpen, BeastPaths and Mounts (MoP package) can run without Core; their Core settings or integrations then become unavailable. Core bundles its runtime libraries; a separate LibDataBroker installation is not required.

所有业务插件均可逐个禁用或移除；仍启用任何强依赖 Core 的插件时，必须保留并启用 YiboCore。AutoOpen、BeastPaths、Mounts（MoP 包）可独立运行，缺少 Core 时不提供相应统一设置或增强功能。Core 包含运行所需库，不要求额外安装 LibDataBroker。逐插件依赖见本文件配套 CHANGELOG。

Cross-addon integrations are optional. Removing a TaskHub source removes that source's tasks; TaskHub's own goals remain available. Without Mail, Vault loses the shared Mail snapshot and in-transit enhancement and uses its own collection. Without Vault, consumers lose Vault inventory enhancements. Compatibility is checked through Core capability contracts.

跨业务插件集成均为可选增强。移除行动中心来源插件会失去相应来源任务，行动中心自建目标仍可使用。移除 Mail 后，Vault 使用自有采集，不再获得 Mail 共享快照和在途增强；移除 Vault 后，消费方失去相应库存增强。能力兼容以 Core 契约检查为准。

## Wrong client / 装错客户端

Packages are not interchangeable between clients. An addon built for another client stops before reading or writing its saved data and prints a message; remove it and install the matching package.

不同客户端的包不可互换。装到其它客户端的插件会在读写存档前停止并提示；请删除后安装对应客户端的包。

## Overlay installation / 单体与 Suite 覆盖安装

Suite and standalone downloads use the same addon folder names and SavedVariables names. The last files copied win; no installer selects the newest component automatically. Compare component versions, not Suite's version against an addon version. Install Suite first, then overlay any standalone version you choose. A later Suite installation overwrites all included components and restores folders you previously removed. Disable unwanted addons in-game if you want to keep the complete Suite installed.

Suite 与单体使用相同目录和 SavedVariables 名称。最后复制的文件生效，不会自动保留较新组件；请比较具体组件版本，不能拿 Suite 版本与单体版本比较。可先安装 Suite，再覆盖自己选择的单体。之后再次安装 Suite 会覆盖全部包含组件，并恢复先前移除的目录；保留完整 Suite 时可在游戏内禁用不需要的插件。

Keep a compatible Core when mixing versions. Overlaying preserves existing settings because the package contains no WTF or SavedVariables data. Back up WTF before changing versions. Arbitrary downgrades are not guaranteed to read data migrated by newer versions. Copying over files also leaves obsolete files behind; follow any component-specific migration instructions. Review archive contents and component TOCs, then fully restart WoW after installation.

混用版本时须满足各插件最低 Core 要求。本包不含 WTF 或 SavedVariables 用户数据，覆盖安装沿用现有配置；切换版本前建议备份 WTF。旧版本不保证能读取新版迁移后的数据。合并覆盖可能保留旧包已移除的文件，应遵循组件专属迁移说明。安装后核对包内清单与组件 TOC，并完整重启游戏。

## CurseForge App limitation / CF 同时管理限制

Manual overlay installation is supported at the folder-layout level. Concurrent CurseForge App management of Suite and standalone projects sharing folders has NOT been verified. Do not rely on it to preserve newer standalone files or safely uninstall only one overlapping project. Updates/reinstalls may overwrite your chosen component versions; uninstalling an overlapping project may affect shared folders; rescans may change project identification. These are shared-folder risks, not confirmed observations of this Suite.

手动覆盖安装使用相同目录结构。CF 客户端同时管理 Suite 与共享目录的单体项目尚未验证，不承诺自动保留较新单体，也不承诺能安全地只卸载其中一方。更新或重装可能覆盖用户选定组件，卸载可能影响共享目录，重新扫描可能改变项目识别。这些属于共享目录风险推断，尚非本 Suite 实测结论。

Choose either Suite or standalone projects as the update authority. For deliberate manual mixing, disable automatic installation of updates for the relevant WoW instance, review each download's component list, and reapply chosen standalone versions as needed. Disabling auto-updates does not resolve folder ownership or uninstall risks. Do not uninstall an overlapping CF project merely to switch update modes without a backup and a complete replacement package ready.

建议选择 Suite 或单体其中一种作为更新来源。主动手动混用时，关闭对应 WoW 实例的自动安装更新，每次更新前查看组件清单，必要时重新覆盖所选单体。关闭自动更新不能解决目录归属和卸载风险。切换管理方式前先备份，并备好完整替代安装包，勿直接依赖卸载重叠项目来切换。

Before claiming concurrent App support, verify both installation orders, updates of each project, reinstalls, individual uninstalls and identification after an App restart in an isolated test installation.

宣称支持 CF 同时管理前，须在隔离安装中验收两种安装顺序、双方更新、重装、分别卸载以及客户端重启后的识别。

References / 参考：[CF automatic updates](https://support.curseforge.com/support/solutions/articles/9000193488-getting-started?locale=zh), [WoW archive processor](https://support.curseforge.com/support/solutions/articles/9000210425-elerium-file-processor-errors-per-game). Official documentation does not establish safe ownership of shared addon folders by separate projects.


## Component package checksums / 组件安装包校验

The Suite includes each component package byte-for-byte after extraction. Its manifest records each runtime file checksum.
Suite 内组件内容与本次单体包解压内容逐字节一致；清单逐文件记录运行内容校验值。

- `YiboAltoBoss-mists-v2.9.0-curseforge.zip`: `c176d962c8d3f22cc158fce0422d12523fa69caf45752bd6a2b5cee90d8b654b`
- `YiboAutoOpen-mists-v1.2.7-curseforge.zip`: `2bd341d74674a5a957340da7286fc22b37b05af5f7b7e1867e2df55326766008`
- `YiboBeastPaths-universal-v1.10.0-curseforge.zip`: `d19d823b63d9299c75178a841246ce2100a8302508576446e6ccb03f5dd8e430`
- `YiboBuilds-mists-v1.6.0-curseforge.zip`: `2a7de873bbb8462b8f64bf337d274b837c05abaa2fddca2af88f6941b50c229a`
- `YiboCore-mists-v1.13.0-api14-curseforge.zip`: `ca5b6f862510ca8925b2d9bb679b4ffb7cad352272195ac0bef22006450fd1ea`
- `YiboCrafting-mists-v1.3.0-curseforge.zip`: `c3225741b075e3276c1854d7fd0f7c7d511592d34687de29fdcd47effc760d36`
- `YiboCurrency-mists-v1.1.3-curseforge.zip`: `0204ac312d940f02044034ad7651ae04022d556f5b94e1ecc4115c692fcd5308`
- `YiboLegendary-mists-v2.3.0-curseforge.zip`: `9af05e120b292c778c8f6fb4460ad712d1e4dbab86a4c417c7e6d5cfb5197c95`
- `YiboMail-mists-v1.4.0-api1-curseforge.zip`: `68747a92c7693afaefdd22d47c4af323a9eeed87485d1bbd6d66aff99a423aa2`
- `YiboMounts-mists-v1.0.3-curseforge.zip`: `5cf4509bc78cd4b3628a2f5aee271f6b9091650ec565f4523d745c1022b6812e`
- `YiboQuestBlocker-mists-v3.2.0-curseforge.zip`: `65e644887959628b5f8041114a58d3993c1740bc055df75ebf128a58fa87df4b`
- `YiboReputation-mists-v1.8.0-curseforge.zip`: `78427b04bc54a509c92c8ee38775c265dc137066f095c9e94cfdc52c34f332af`
- `YiboTaskHub-mists-v0.7.0-curseforge.zip`: `4ad856db8852b54d58a36f647db82940ca15fc7b26c929972f2e8fc9cdc7e64a`
- `YiboTodo-mists-v1.3.0-curseforge.zip`: `4e2a1685eaf945051eac40c648d269e40490bc85b329b8b9d965db5448cb32c1`
- `YiboVault-mists-v1.3.0-api1-curseforge.zip`: `72cf3e3e1e8a2513881512092dd20507912fd8a2607a2da9c9817cd1a037fccb`