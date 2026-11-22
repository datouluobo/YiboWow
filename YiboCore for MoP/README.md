# Yibo Addon Suite - Account QoL Addons

显示名称：`Yibo Addon Suite - Account QoL Addons`（2026-11-22 起去掉 “for MoP”，CurseForge 项目沿用原项目与链接）。整合包按客户端分别打包，此后所有整合包都发布在该项目：

| 目标 | 安装包 | 当前版本 | 组件 |
| --- | --- | --- | --- |
| Mists（熊猫人之谜怀旧服） | `Builds/Yibo-Addon-Suite-mists-v<版本>-curseforge.zip` | 1.2.0 | 统一构建配置中声明 Mists 的全部 15 个插件 |
| Forever（无限服） | `Builds/Yibo-Addon-Suite-forever-v<版本>-curseforge.zip` | 1.0.0 | 声明 Forever 的全部 9 个插件 |

两个目标的整合包版本独立递增；各组件保留自身版本、目录与存档身份。不含非发布探针。`YiboCore for MoP/` 是仓库内存放文档、设计资源与打包脚本的资料目录（目录名为历史名称，未改名），不是插件，不进入 ZIP。ZIP 根层以 `YiboCore/` 为主体目录，其余插件目录并列。

## 本地打包

在仓库根目录用 Windows PowerShell 5.1：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File 'YiboCore for MoP/Tools/Build-Suite.ps1' -Target Mists
powershell -NoProfile -ExecutionPolicy Bypass -File 'YiboCore for MoP/Tools/Build-Suite.ps1' -Target Forever
```

需要 Lua 5.1 luac 在 PATH 中（沿用单体构建要求）。脚本先在 `_NonRelease/Packaging/Suite/<运行ID>/` 用统一构建器生成该目标全部单体包，核对组件依赖闭合与最低 Core API，再合并其实际内容；中间产物保留用于追溯，不改写或归档单体 Builds 产物。组件集合必须等于 `Tools/ReleaseProfiles.psd1` 中声明该目标的全部插件（Mists 另含 BeastPaths 共用包）。支持 `-WorkspaceRoot`、`-OutputRoot`、`-ValidateOnly`；同名安装包或发布资料已存在时停止。

发布资料保存在 `YiboCore for MoP/Releases/<目标slug>-v<版本>/`：自动生成的 CHANGELOG.md、CURSEFORGE_CHANGELOG.md（CF 文件页用的组件版本表）、INSTALL.md 和 YiboAddonSuiteManifest.json，不放进玩家 ZIP。旧版 `Releases/v1.x` 为 “for MoP” 名称时期的记录。

## 发布状态

- v1.1.0（Mists，旧名 `Yibo-Addon-Suite-for-MoP`）已发布。
- Mists 1.2.0 与 Forever 1.0.0：2026-11-22 已发布，项目正文已更新为双客户端版，见 `Docs/Publishing/Yibo-Addon-Suite-20261122.md`。

完整安装与更新规则见 [INSTALL.md](INSTALL.md)。CF 项目介绍使用 [CURSEFORGE_DESCRIPTION.md](CURSEFORGE_DESCRIPTION.md)；CF 文件页使用对应版本的 `CURSEFORGE_CHANGELOG.md`。
