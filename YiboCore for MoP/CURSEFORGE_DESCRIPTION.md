# Yibo Addon Suite

Yibo Addon Suite brings together the modular Yibo addons in one download, combining account-wide tracking with everyday quality-of-life features. Each game client has its own package:

| Package | Client | Addons |
| --- | --- | --- |
| `Yibo-Addon-Suite-mists` | Mists of Pandaria Classic | 15 |
| `Yibo-Addon-Suite-forever` | Forever | 9 |

**Download the package for the client you play.** Packages are not interchangeable; an addon installed on the wrong client stops before touching its saved data and tells you so.

## Included Addons

| Addon | Purpose | MoP | Forever |
| --- | --- | :---: | :---: |
| [YiboCore](https://www.curseforge.com/wow/addons/yibocore) | Shared account views, character management, settings and addon entries | ✓ | ✓ |
| [YiboAltoBoss](https://www.curseforge.com/wow/addons/yiboaltoboss) | Boss and instance progress tracking | ✓ | ✓ |
| [YiboAutoOpen](https://www.curseforge.com/wow/addons/yiboautoopen) | Automatic opening of supported, allowlisted containers | ✓ | ✓ |
| [YiboBeastPaths](https://www.curseforge.com/wow/addons/yibobeastpaths) | Hunter pet locations and routes | ✓ | |
| [YiboBuilds](https://www.curseforge.com/wow/addons/yibobuilds) | Character build and equipment utilities | ✓ | ✓ |
| [YiboCrafting](https://www.curseforge.com/wow/addons/yibocrafting) | Crafting and profession tracking | ✓ | ✓ |
| [YiboCurrency](https://www.curseforge.com/wow/addons/yibocurrency) | Account-wide currency tracking | ✓ | ✓ |
| [YiboLegendary](https://www.curseforge.com/wow/addons/yibolegendary) | Legendary quest progress tracking | ✓ | |
| [YiboMail](https://www.curseforge.com/wow/addons/yibomail) | Mail management and account mail information | ✓ | ✓ |
| [YiboMounts](https://www.curseforge.com/wow/addons/yibomounts) | Mount source information | ✓ | |
| [YiboQuestBlocker](https://www.curseforge.com/wow/addons/yiboquestblocker) | Quest blocking tools | ✓ | |
| [YiboReputation](https://www.curseforge.com/wow/addons/yiboreputation) | Account-wide reputation tracking | ✓ | ✓ |
| [YiboTaskHub](https://www.curseforge.com/wow/addons/yibotaskhub-action-hub) | A shared action hub for supported tasks and custom goals | ✓ | |
| [YiboTodo](https://www.curseforge.com/wow/addons/yibotodo) | Recurring activities and profession cooldown tracking | ✓ | |
| [YiboVault](https://www.curseforge.com/wow/addons/yibovault) | Account-wide inventory tracking | ✓ | ✓ |

## Modular Installation

You can disable or remove individual business addons.

**Keep YiboCore installed and enabled whenever an enabled addon requires it.** YiboAutoOpen, YiboBeastPaths and YiboMounts can run independently, with their Core integrations unavailable.

Cross-addon enhancements are optional. Removing a source addon makes its associated information or tasks unavailable.

## Installation

1. Exit World of Warcraft.
2. Extract the addon folders directly into the matching client's `Interface/AddOns` directory.
3. Keep the original addon folder names.
4. Restart the game and enable the addons you want to use.

The download contains the YiboCore addon folder and the other included addon folders side by side. Extract them directly into `Interface/AddOns`.

## Suite and Standalone Downloads

Suite and standalone downloads use the same addon folders and saved settings.

Each Suite release contains a fixed component snapshot. **See the changelog of your downloaded file for exact addon versions.** Suite versions and individual addon versions are independent, and the MoP and Forever packages are versioned separately.

For manual overlay installation, the last files copied take effect. No automatic selection of newer components occurs. Keep a compatible YiboCore when mixing versions.

Installing Suite again overwrites its included components and restores addon folders you previously removed. Back up your WTF folder before switching versions. Older addon versions may not support data migrated by newer releases.

## CurseForge App Management

**Choose either Suite or standalone projects as your update source.**

Concurrent CurseForge App management of Suite and standalone projects sharing the same addon folders has not been verified. Updates or reinstalls may overwrite your selected component versions, and uninstalling an overlapping project may affect shared folders.

Disabling automatic updates does not resolve shared-folder identification or uninstall risks.

## Supported Clients

**Mists of Pandaria Classic** (`mists` package) and **Forever** (`forever` package).

The YiboBeastPaths maintenance package in the MoP Suite also contains Retail TOCs. This does not extend the Suite's supported clients to Retail.

## Feedback

Please include your game client and version, Suite package and version, affected addon version, steps to reproduce the issue, and any Lua error message.

[Report an issue](https://github.com/datouluobo/YiboWow/issues)

---

# Yibo Addon Suite 整合包

Yibo Addon Suite 把可按需启用的 Yibo 系列插件合并为一次下载，提供账号多角色信息追踪与日常便利功能。每个游戏客户端有各自的整合包：

| 整合包 | 客户端 | 插件数 |
| --- | --- | --- |
| `Yibo-Addon-Suite-mists` | 熊猫人之谜怀旧服 | 15 |
| `Yibo-Addon-Suite-forever` | 无限服 | 9 |

**请下载与所玩客户端对应的整合包。** 不同客户端的包不可互换；装到其它客户端的插件会在读写存档前停止并提示。

## 包含的插件

| 插件 | 功能 | MoP | 无限服 |
| --- | --- | :---: | :---: |
| [YiboCore](https://www.curseforge.com/wow/addons/yibocore) | 统一账号视图、角色管理、设置工作台与插件入口 | ✓ | ✓ |
| [YiboAltoBoss](https://www.curseforge.com/wow/addons/yiboaltoboss) | 首领与副本进度追踪 | ✓ | ✓ |
| [YiboAutoOpen](https://www.curseforge.com/wow/addons/yiboautoopen) | 自动打开受支持且已加入允许列表的容器 | ✓ | ✓ |
| [YiboBeastPaths](https://www.curseforge.com/wow/addons/yibobeastpaths) | 猎人宠物位置与路线 | ✓ | |
| [YiboBuilds](https://www.curseforge.com/wow/addons/yibobuilds) | 角色配装与装备辅助 | ✓ | ✓ |
| [YiboCrafting](https://www.curseforge.com/wow/addons/yibocrafting) | 制造与专业信息追踪 | ✓ | ✓ |
| [YiboCurrency](https://www.curseforge.com/wow/addons/yibocurrency) | 账号多角色货币追踪 | ✓ | ✓ |
| [YiboLegendary](https://www.curseforge.com/wow/addons/yibolegendary) | 传奇任务进度追踪 | ✓ | |
| [YiboMail](https://www.curseforge.com/wow/addons/yibomail) | 邮件管理与账号邮件信息 | ✓ | ✓ |
| [YiboMounts](https://www.curseforge.com/wow/addons/yibomounts) | 坐骑来源信息 | ✓ | |
| [YiboQuestBlocker](https://www.curseforge.com/wow/addons/yiboquestblocker) | 任务阻断工具 | ✓ | |
| [YiboReputation](https://www.curseforge.com/wow/addons/yiboreputation) | 账号多角色声望追踪 | ✓ | ✓ |
| [YiboTaskHub](https://www.curseforge.com/wow/addons/yibotaskhub-action-hub) | 汇总受支持的来源任务与自建目标 | ✓ | |
| [YiboTodo](https://www.curseforge.com/wow/addons/yibotodo) | 周期活动与专业冷却追踪 | ✓ | |
| [YiboVault](https://www.curseforge.com/wow/addons/yibovault) | 账号多角色库存追踪 | ✓ | ✓ |

## 按需启用与删减

各业务插件均可单独禁用或移除。

**只要仍启用任何依赖 YiboCore 的插件，就必须保留并启用 YiboCore。** YiboAutoOpen、YiboBeastPaths 和 YiboMounts 可以独立运行，缺少 Core 时不提供相应的 Core 集成功能。

跨插件联动属于可选增强。移除来源插件后，相应的信息或任务来源将不可用。

## 安装方法

1. 完整退出魔兽世界。
2. 将各插件目录直接解压到对应客户端的 `Interface/AddOns` 目录。
3. 保留原有插件目录名称。
4. 重新启动游戏，启用需要使用的插件。

下载包在 `YiboCore/` 之外并列包含其它插件目录；全部目录均直接解压到 `Interface/AddOns`。

## 整合包与单体覆盖安装

整合包与单体使用相同的插件目录和配置存档名称。

每个整合包版本包含一份固定的组件快照。**各插件的具体版本，请查看当前下载文件的更新日志。** 整合包版本号与各单体插件版本号分别维护，MoP 包与无限服包的版本号也各自独立。

手动覆盖安装时，最后复制进去的文件生效，不会自动挑选较新的组件。混用版本时，请保留满足各插件要求的 YiboCore。

再次安装整合包会覆盖包内全部组件，并恢复此前移除的插件目录。切换版本前请备份 WTF 目录；旧版插件可能无法读取新版已经迁移的数据。

## CurseForge 客户端管理限制

**建议选择整合包或单体其中一种作为更新来源。**

CF 客户端同时管理共享插件目录的整合包与单体项目尚未验证。更新或重装可能覆盖用户选定的组件版本，卸载其中一个重叠项目也可能影响共享目录。

关闭自动更新不能解决共享目录的项目识别与卸载风险。

## 支持的客户端

**熊猫人之谜怀旧服**（`mists` 包）与**无限服**（`forever` 包）。

MoP 整合包内的 YiboBeastPaths 维护包同时保留正式服 TOC，但这不代表整合包支持正式服。

## 问题反馈

反馈时请提供游戏客户端与版本、整合包及其版本、相关插件版本、复现步骤，以及出现的 Lua 错误信息。

[提交问题反馈](https://github.com/datouluobo/YiboWow/issues)
