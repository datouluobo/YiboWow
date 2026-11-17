# YiboCore for MoP - v1.1.0

Local release candidate / 本地发布候选；not uploaded / 未上传。

Suite snapshot containing all 15 configured addons for Mists of Pandaria Classic. Component versions remain independent.
Suite 快照包含全部 15 个插件的本次打包版本。Suite 与单体分别维护版本。

Source snapshot SHA256: dd029b511cb55fb209e2899749fd24ea48ad7eb379fa6c6653e6209513b87859

## Included components / 本文件包含的具体组件

| Addon | Version | Required TOC dependencies / 必须依赖 | Optional TOC dependencies / 可选依赖 | Minimum Core API / 最低 Core API |
|---|---|---|---|---|
| YiboAltoBoss | 2.8.6 | YiboCore | - | Runtime capability check / 以运行时能力检查为准 |
| YiboAutoOpen | 1.2.5 | - | YiboCore | Runtime capability check / 以运行时能力检查为准 |
| YiboBeastPaths | v1.8.3 | - | YiboCore | Runtime capability check / 以运行时能力检查为准 |
| YiboBuilds | 1.5.3 | YiboCore | - | 13 |
| YiboCore | 1.12.14 | - | LibDataBroker-1.1 | Provides API 13 |
| YiboCrafting | 1.2.4 | YiboCore | - | Runtime capability check / 以运行时能力检查为准 |
| YiboCurrency | 1.1.2 | YiboCore | - | 13 |
| YiboLegendary | 2.2.5 | YiboCore | - | 13 |
| YiboMail | 1.3.4-api1 | YiboCore | - | 13 |
| YiboMounts | 1.0.3 | - | YiboCore | Runtime capability check / 以运行时能力检查为准 |
| YiboQuestBlocker | 3.1.3 | YiboCore | - | 13 |
| YiboReputation | 1.7.3 | YiboCore | - | 13 |
| YiboTaskHub | 0.6.4 | YiboCore | - | 13 |
| YiboTodo | 1.2.6 | YiboCore | - | 13 |
| YiboVault | 1.2.5-api1 | YiboCore | - | 13 |

## Installation, removal and update rules / 安装、删减与更新规则

# YiboCore for MoP installation / 安装说明

YiboCore for MoP is a collection of 15 addons for Mists of Pandaria Classic. Each download contains a fixed component snapshot; every addon retains its own version. See the project's file changelog for the exact component versions.

YiboCore for MoP 面向熊猫人之谜怀旧服。Suite 版本标识一次固定组件快照，各插件保留自己的版本号；具体版本以本次下载附带的 CHANGELOG 为准。包含 BeastPaths 的多 TOC 维护包不代表 Suite 支持正式服；BeastPaths Mists TOC 当前声明 Interface 50400，进入客户端可能需要允许加载过期插件，发布前仍须核对当前客户端表现。

## Manual installation / 手动安装

Exit WoW. Extract the addon folders directly into the intended Mists Classic client's Interface/AddOns directory. Keep the original folder names. `YiboCore/` is the primary addon folder; the other addon folders sit beside it.

完整退出游戏，把 ZIP 内各插件目录直接解压到目标怀旧服客户端的 Interface/AddOns 下，保留目录名。`YiboCore/` 是主体插件目录，其余插件目录与它并列。

## Components and dependencies / 组件与依赖

All business addons may be disabled or removed individually. Keep YiboCore enabled while any addon marked as requiring it remains enabled. AutoOpen, BeastPaths and Mounts can run without Core; their Core settings or integrations then become unavailable. Core bundles its runtime libraries; a separate LibDataBroker installation is not required.

所有业务插件均可逐个禁用或移除；仍启用任何强依赖 Core 的插件时，必须保留并启用 YiboCore。AutoOpen、BeastPaths、Mounts 可独立运行，缺少 Core 时不提供相应统一设置或增强功能。Core 包含运行所需库，不要求额外安装 LibDataBroker。逐插件依赖见本文件配套 CHANGELOG。

Cross-addon integrations are optional. Removing a TaskHub source removes that source's tasks; TaskHub's own goals remain available. Without Mail, Vault loses the shared Mail snapshot and in-transit enhancement and uses its own collection. Without Vault, consumers lose Vault inventory enhancements. Compatibility is checked through Core capability contracts.

跨业务插件集成均为可选增强。移除行动中心来源插件会失去相应来源任务，行动中心自建目标仍可使用。移除 Mail 后，Vault 使用自有采集，不再获得 Mail 共享快照和在途增强；移除 Vault 后，消费方失去相应库存增强。能力兼容以 Core 契约检查为准。

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

- `YiboAltoBoss-mists-v2.8.6-curseforge.zip`: `e2748a20ac60bf48217baa3ca59fd90e14ccffa43f191152959bf064d5aaba1c`
- `YiboAutoOpen-mists-v1.2.5-curseforge.zip`: `f0690b2cd5ceb896e7e28cedf55201c03fe017f20f3be827b42d3f73084067d6`
- `YiboBeastPaths-universal-v1.8.3-curseforge.zip`: `ca4dac27abfe85bacde6a9d6377fb964fd935318da0162e73ddd03e3b31bea66`
- `YiboBuilds-mists-v1.5.3-curseforge.zip`: `5c62cbe90a5cecc935cd6cac08e19d40e898b499db5ecac76aed5a2ec7eb16b2`
- `YiboCore-mists-v1.12.14-api13-curseforge.zip`: `165703ba904113108ea6cc720ca7b101e4ffaf1fd50634af7a5a1efe8f998ff4`
- `YiboCrafting-mists-v1.2.4-curseforge.zip`: `b3e66dba37c32f8c7cca85d192e82907fbaeeb8fb8dce7214a483374b768c0bd`
- `YiboCurrency-mists-v1.1.2-curseforge.zip`: `d3af6cd705bd4a2710c48f2dd9e872150c1006dd82e0a1847d15051bde175b5b`
- `YiboLegendary-mists-v2.2.5-curseforge.zip`: `0a1b33c0c0a0c122bcc1762ba5ef429b25e4e2dca4eea132ee3e35b00d1fd7b9`
- `YiboMail-mists-v1.3.4-api1-curseforge.zip`: `16770a7510945efa4cceeddcb14d8c1b7174ef2c150563d25a5d0a12fbdfda1a`
- `YiboMounts-mists-v1.0.3-curseforge.zip`: `ec11b3843cb133f0252257b7f4905991618261502264ee2214665a30e0eec48a`
- `YiboQuestBlocker-mists-v3.1.3-curseforge.zip`: `3eeabc141630a3435e87d68e0935c895d1a06dbf7be7ed0723f042846f8d984c`
- `YiboReputation-mists-v1.7.3-curseforge.zip`: `ae07027dc1b99662ffa6307a8cdb6f2b9f8a808741c17324d4275480d84b008d`
- `YiboTaskHub-mists-v0.6.4-curseforge.zip`: `bceea2d6cbbc9530295b09afce1383485f7e751db871dd2710422092a0f6c751`
- `YiboTodo-mists-v1.2.6-curseforge.zip`: `cb50b030d4fcfee62ac7131a3e7a718183ef35a2f5cf8d51bbec5499b801a2bd`
- `YiboVault-mists-v1.2.5-api1-curseforge.zip`: `39534b853c2171e0f9508a4839164f27e7cc1bf5e91743d364aaa7f54b604b56`