# YiboSuite installation / 安装说明

YiboSuite for MoP - Account QoL Addons supports Mists of Pandaria Classic. Suite versions identify a fixed component snapshot; each addon retains its own version. See the CHANGELOG shipped with this download for exact component versions.

YiboSuite 面向熊猫人之谜怀旧服。Suite 版本标识一次固定组件快照，各插件保留自己的版本号；具体版本以本次下载附带的 CHANGELOG 为准。包含 BeastPaths 的多 TOC 维护包不代表 Suite 支持正式服；BeastPaths Mists TOC 当前声明 Interface 50400，进入客户端可能需要允许加载过期插件，发布前仍须核对当前客户端表现。

## Manual installation / 手动安装

Exit WoW. Extract all Yibo addon folders directly into the intended Mists Classic client's Interface/AddOns directory. Keep the original folder names. Do not nest them inside an outer YiboSuite folder. The separate YiboSuite folder contains documentation only and may be kept alongside the addon folders or stored elsewhere.

完整退出游戏，把 ZIP 内各 Yibo 插件目录直接解压到目标怀旧服客户端的 Interface/AddOns 下，保留目录名。不要把业务插件放进外层 YiboSuite 目录。ZIP 中并列的 YiboSuite 目录仅存放发布资料，可保留在 AddOns 下或另行保存。

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
