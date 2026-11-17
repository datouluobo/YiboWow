# Yibo Addon Suite for MoP - Account QoL Addons - v1.1.0

Local release candidate / 本地发布候选；not uploaded / 未上传。

Suite snapshot containing all 15 configured addons for Mists of Pandaria Classic. Component versions remain independent.
Suite 快照包含全部 15 个插件的本次打包版本。Suite 与单体分别维护版本。

Source snapshot SHA256: 0dcd838f58ec50ae7aaba8bab960d797b086950ae5a2bf39f397062ee2167815

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

# Yibo Addon Suite for MoP installation / 安装说明

Yibo Addon Suite for MoP is a collection of 15 addons for Mists of Pandaria Classic. Each download contains a fixed component snapshot; every addon retains its own version. See the project's file changelog for the exact component versions.

Yibo Addon Suite for MoP 面向熊猫人之谜怀旧服。Suite 版本标识一次固定组件快照，各插件保留自己的版本号；具体版本以本次下载附带的 CHANGELOG 为准。包含 BeastPaths 的多 TOC 维护包不代表 Suite 支持正式服；BeastPaths Mists TOC 当前声明 Interface 50504，发布前仍须核对当前客户端表现。

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

- `YiboAltoBoss-mists-v2.8.6-curseforge.zip`: `8a56995b454f9d9a48acebb1018e11cd836161e67f9256458675bff5d5a7e92f`
- `YiboAutoOpen-mists-v1.2.5-curseforge.zip`: `1c12e6cdf9be5d32532ccc4eb0b7ce688cbc2aa98c7a886961265c679b59df4d`
- `YiboBeastPaths-universal-v1.8.3-curseforge.zip`: `a6a4535eac90a1fd94810d22f3e6fef3de47eb0818807a57c80b1919e020b86b`
- `YiboBuilds-mists-v1.5.3-curseforge.zip`: `ce2b4641b298d3417d82d6cc9a851156019a33a6251f2b4f1f8062df30d78d9a`
- `YiboCore-mists-v1.12.14-api13-curseforge.zip`: `fd247b0c7a9c983268b31bd9146fda8796430e873f063378dbd9a686605204bc`
- `YiboCrafting-mists-v1.2.4-curseforge.zip`: `276f98f342b19a9d5fb58c4cff33a5a688e7784bd0ba22e8f2512a4613dfb931`
- `YiboCurrency-mists-v1.1.2-curseforge.zip`: `2b05ab69b590ca802d279dab947f0d36b7ad75ce147484d2772e4b5e3aac1bca`
- `YiboLegendary-mists-v2.2.5-curseforge.zip`: `e7992a8c8b748a45657ebbfb105d5a66b22d93cb86576b8014aa54e08c43afea`
- `YiboMail-mists-v1.3.4-api1-curseforge.zip`: `1f3254a4c6bfe493d98e751060f55f7a8d1cee726c45fcc01bc7f7b9b61dbb2b`
- `YiboMounts-mists-v1.0.3-curseforge.zip`: `ecf194ca3badc6cd4fbb3150601e06d4c0bda58c2a37ac2a91ba35b797a0d9d2`
- `YiboQuestBlocker-mists-v3.1.3-curseforge.zip`: `042a0b3477cdd6818fb64c5aa4e3110f9ef348585bb3e32e0357111a29b6ee14`
- `YiboReputation-mists-v1.7.3-curseforge.zip`: `46354550ac61019900b1946fd2646b65ea5fbc78d66a81ca154434f6b7dc41b4`
- `YiboTaskHub-mists-v0.6.4-curseforge.zip`: `93d5f83521dffbaf7570623455b2cdc76078da5de5eabee38a657e073f296de2`
- `YiboTodo-mists-v1.2.6-curseforge.zip`: `9f409a400c5320e6758c3291c2e0d503642f76b7c154f1d69b15e318b3cf911d`
- `YiboVault-mists-v1.2.5-api1-curseforge.zip`: `9790c259459d0cb38e22ee7b1b6b257b261c3d6434154047a5090f98e1b48969`