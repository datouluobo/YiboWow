# YiboSuite v1.0.0 CurseForge 填表指南

状态：仅准备填写内容，尚未上传。表单名称可能随作者后台调整，以实际界面为准。

## 创建项目

| 字段 | 填写内容 |
|---|---|
| Game | World of Warcraft |
| Class | Addons |
| Name | YiboSuite for MoP - Account QoL Addons |
| Slug（允许手动设置时） | yibosuite |
| Summary | A modular collection of 15 Yibo addons for account-wide tracking and everyday convenience in MoP Classic. |
| Main category | Miscellaneous |
| Additional categories | Bags & Inventory、Mail、Professions、Quests & Leveling |
| Source | https://github.com/datouluobo/YiboWow/tree/main/YiboSuite |
| Issues（若启用此入口） | https://github.com/datouluobo/YiboWow/issues |
| Project type | 普通项目，不勾 Experimental |
| License | 沿用作者已确定的授权；当前 Suite 未声明开放源代码许可证。如采用保留权利的发行方式，选择 All Rights Reserved，不自行选择 MIT/GPL。此字段不替代随包第三方库通知。 |
| Logo / Avatar | 使用已确认归属 Suite 的品牌图；当前任务未制作 Suite 专属 Logo。 |

## Description（可复制的英文正文）

YiboSuite is a modular collection of 15 Yibo addons for Mists of Pandaria Classic, combining account-wide tracking with everyday quality-of-life features.

It includes YiboCore, YiboAltoBoss, YiboAutoOpen, YiboBeastPaths, YiboBuilds, YiboCrafting, YiboCurrency, YiboLegendary, YiboMail, YiboMounts, YiboQuestBlocker, YiboReputation, YiboTaskHub, YiboTodo and YiboVault. Features cover boss lockouts, container opening, hunter routes, character builds, crafting, currencies, legendary progress, mail, mount sources, quest blocking, reputation, tasks and inventory.

Each download is a fixed snapshot. See that file's changelog for exact component versions and dependencies. Suite and standalone addon versions are independent.

All business addons can be disabled or removed individually. Keep YiboCore enabled while using addons that require it. YiboAutoOpen, YiboBeastPaths and YiboMounts can run without Core, with their Core integrations unavailable. Cross-addon enhancements are optional.

Install the addon folders directly into your Mists Classic Interface/AddOns directory. Preserve their original names. The separate YiboSuite folder contains documentation only.

Manual overlay installation with standalone downloads uses the same addon folders and saved settings. The last files copied take effect; no automatic component version selection occurs. Compare component versions and retain a compatible YiboCore. Reinstalling Suite overwrites its included components and restores removed addon folders. Back up your WTF settings before switching versions; arbitrary downgrades may not support data migrated by newer versions.

Concurrent CurseForge App management of Suite and standalone projects sharing the same folders has not been verified. Choose one update source. Updates or reinstalls may overwrite selected versions, and uninstalling an overlapping project may affect shared folders. Disabling automatic updates does not resolve folder ownership or uninstall risks.

This Suite targets MoP Classic only. The included BeastPaths maintenance package also contains Retail TOCs; this does not extend Suite support to Retail.

## 上传文件（本次不执行）

| 字段 | 填写内容 |
|---|---|
| Choose file | Builds/YiboSuite-mists-v1.0.0-curseforge.zip |
| Display Name | YiboSuite v1.0.0 - MoP Classic |
| Release Type | 建议首轮选 Beta；完成预定验收后可选 Release。两者不改变 Suite 版本号。 |
| Game Version / Flavor | MoP Classic / Mists of Pandaria Classic |
| Supported Version | 5.5.4（与当前 14 个主组件构建配置对应；不勾选未验收版本） |
| Changelog format | Markdown（若支持格式选择） |
| Changelog | 粘贴 Releases/v1.0.0/CHANGELOG.md 的完整正文，不能用单体 Changelog 替代。 |
| Required Dependencies | 留空；本包已包含 Core 和组件运行文件，不要求 CF 再安装单体。 |
| Optional Dependencies | 不把本包已含的单体列成可选下载。 |
| Incompatible | 不因“同时管理未验证”就标记运行不兼容；通过项目正文与文件 Changelog 说明限制。 |
| Embedded Library / Includes（如有） | 仅在后台确实提供此关系并明确适用于已内嵌组件时关联对应单体项目；不要将已内嵌组件误标 Required Dependency。 |

项目名或 slug 不等于 ZIP 根目录名。当前 Suite 为多个并列插件目录加资料目录；不要为迁就表单把插件嵌套进 YiboSuite，或把资料目录冒充可加载插件。若后台要求唯一主插件目录或处理器拒绝此布局，应按实际审核反馈处理，当前没有经过 CF 上传验证。

## 构建追溯

本次 ZIP 来源于当时工作区的完整快照，不等于只提交 Suite 文件后远端主分支的源码快照。Suite 构建依赖现有公共打包工具改造；这些改造和业务插件更新没有随本次 Suite 专属提交一起纳入。远端独立复现前需完成相关前置改造提交。原包逐组件摘要与逐文件校验记录见 Releases/v1.0.0/YiboSuiteManifest.json。

参考：[创建项目](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project)、[文件字段与项目关系](https://support.curseforge.com/support/solutions/articles/9000197242)、[WoW 当前分类与游戏版本](https://www.curseforge.com/wow/addons)。
