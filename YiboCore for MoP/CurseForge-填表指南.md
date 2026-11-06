# YiboCore for MoP v1.0.1 CurseForge 填表指南

状态：v1.0.0 因 ZIP 中包含资料目录而被拒。当前本地候选为 v1.0.1；打包时仅保留真实插件目录，尚未重建、重传。

## 创建项目

| 字段 | 填写内容 |
|---|---|
| Game | World of Warcraft |
| Class | Addons |
| Name | YiboCore for MoP |
| Slug（允许手动设置时） | yibocore-for-mop（若可修改且可用） |
| Summary | A modular collection of 15 Yibo addons for account-wide tracking and everyday convenience in MoP Classic. |
| Main category | Miscellaneous |
| Additional categories | Bags & Inventory、Mail、Professions、Quests & Leveling |
| Source | https://github.com/datouluobo/YiboWow/tree/main/YiboCore%20for%20MoP |
| Issues（若启用此入口） | https://github.com/datouluobo/YiboWow/issues |
| Project type | 普通项目，不勾 Experimental |
| License | 沿用作者已确定的授权；当前项目未声明开放源代码许可证。如采用保留权利的发行方式，选择 All Rights Reserved，不自行选择 MIT/GPL。此字段不替代随包第三方库通知。 |
| Logo / Avatar | 使用 `Media/Mists/YiboCore-MoP-Logo-512.png`，透明 PNG；原 Core 主体配右下对齐的翡翠绿 MoP 文字，已确认定稿。 |

## Description（可复制的英文正文）

当前应复制同目录 `CURSEFORGE_DESCRIPTION.md`：英文在前、中文在后，插件名称均带 CF 站内链接。下文为早期英文草稿。

YiboCore for MoP is a collection of 15 modular Yibo addons for Mists of Pandaria Classic, combining account-wide tracking with everyday quality-of-life features.

It includes YiboCore, YiboAltoBoss, YiboAutoOpen, YiboBeastPaths, YiboBuilds, YiboCrafting, YiboCurrency, YiboLegendary, YiboMail, YiboMounts, YiboQuestBlocker, YiboReputation, YiboTaskHub, YiboTodo and YiboVault. Features cover boss lockouts, container opening, hunter routes, character builds, crafting, currencies, legendary progress, mail, mount sources, quest blocking, reputation, tasks and inventory.

Each download is a fixed snapshot. See that file's changelog for exact component versions and dependencies. Suite and standalone addon versions are independent.

All business addons can be disabled or removed individually. Keep YiboCore enabled while using addons that require it. YiboAutoOpen, YiboBeastPaths and YiboMounts can run without Core, with their Core integrations unavailable. Cross-addon enhancements are optional.

The download contains `YiboCore/` as its primary addon folder, with the other addon folders beside it. Extract them directly into the game's `Interface/AddOns` folder and preserve their original names.

Manual overlay installation with standalone downloads uses the same addon folders and saved settings. The last files copied take effect; no automatic component version selection occurs. Compare component versions and retain a compatible YiboCore. Reinstalling Suite overwrites its included components and restores removed addon folders. Back up your WTF settings before switching versions; arbitrary downgrades may not support data migrated by newer versions.

Concurrent CurseForge App management of Suite and standalone projects sharing the same folders has not been verified. Choose one update source. Updates or reinstalls may overwrite selected versions, and uninstalling an overlapping project may affect shared folders. Disabling automatic updates does not resolve folder ownership or uninstall risks.

This Suite targets MoP Classic only. The included BeastPaths maintenance package also contains Retail TOCs; this does not extend Suite support to Retail.

## 上传文件（本次不执行）

| 字段 | 填写内容 |
|---|---|
| Choose file | Builds/YiboCore-for-MoP-mists-v1.0.1-curseforge.zip |
| Display Name | YiboCore for MoP v1.0.1 - MoP Classic |
| Release Type | 建议首轮选 Beta；完成预定验收后可选 Release。两者不改变 Suite 版本号。 |
| Game Version / Flavor | MoP Classic / Mists of Pandaria Classic |
| Supported Version | 5.5.4（与当前 14 个主组件构建配置对应；不勾选未验收版本） |
| Changelog format | Markdown（若支持格式选择） |
| Changelog | 粘贴 Releases/v1.0.1/CURSEFORGE_CHANGELOG.md：仅列英文插件名与本包具体版本号。随包完整安装与依赖说明仍见 CHANGELOG.md 和 INSTALL.md。 |
| Required Dependencies | 留空；本包已包含 Core 和组件运行文件，不要求 CF 再安装单体。 |
| Optional Dependencies | 不把本包已含的单体列成可选下载。 |
| Incompatible | 不因“同时管理未验证”就标记运行不兼容；通过项目正文与文件 Changelog 说明限制。 |
| Embedded Library / Includes（如有） | 仅在后台确实提供此关系并明确适用于已内嵌组件时关联对应单体项目；不要将已内嵌组件误标 Required Dependency。 |

项目名与 ZIP 根目录名分开处理。ZIP 只包含各自带同名 TOC 的插件目录，`YiboCore/` 与其余插件目录并列；仓库里的 `YiboCore for MoP/` 文档与脚本目录不进入 ZIP。CurseForge 是否接受多个并列插件目录仍待 v1.0.1 上传验证。

## 构建追溯

重建 ZIP 时会从当前工作区生成 15 个单体组件包，再按固定组件清单合并。组件摘要与逐文件记录保存在本地 `Releases/v1.0.1/YiboCoreForMoPManifest.json`；这些资料不进入玩家 ZIP。

参考：[创建项目](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project)、[文件字段与项目关系](https://support.curseforge.com/support/solutions/articles/9000197242)、[WoW 当前分类与游戏版本](https://www.curseforge.com/wow/addons)。
