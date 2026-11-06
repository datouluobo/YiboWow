# YiboCore for MoP

项目名称：`YiboCore for MoP`；下一包版本：`v1.0.1`；目标：Mists of Pandaria Classic。

整合包收录配置中登记的全部 15 个正式插件当前源码版本，不包含非发布探针。它保留单体目录、版本及存档身份，提供一次下载的固定组件快照。`YiboCore for MoP/` 是仓库内存放文档、设计资源与打包脚本的资料目录，不是插件，也不会进入 CurseForge ZIP。ZIP 根层以 `YiboCore/` 为主体目录，其余插件目录并列。

## 本地打包

在仓库根目录使用 PowerShell 7.2+：

```powershell
pwsh -File 'YiboCore for MoP/Tools/Build-Suite.ps1'
```

需要 Python 与 Lua 5.1 luac（沿用单体构建要求）。脚本先在 `_NonRelease/Packaging/Suite/<运行ID>/` 使用现有打包器生成全部单体安装包，核对组件依赖闭合并合并其实际内容；中间产物保留用于追溯。不会改写或归档单体 Builds 产物。BeastPaths 沿用现有 universal 维护包内容，Suite 整体兼容声明仅为 Mists。

默认输出 `Builds/YiboCore-for-MoP-mists-v1.0.1-curseforge.zip`；支持 `-WorkspaceRoot`、`-OutputRoot` 和 `-ValidateOnly`。ValidateOnly 执行单体构建计划校验，不生成或移动产物。实际构建会先验证 ZIP 和输入快照稳定性，再归档旧版整合包；同名安装包已存在时停止，避免覆盖固定版本。正式分发应固定源码快照并递增整合包版本。

整合包发布资料保存在 `YiboCore for MoP/Releases/v<版本>/`，包括自动生成的 CHANGELOG.md、INSTALL.md 和 YiboCoreForMoPManifest.json；它们只留在仓库资料目录，不放进玩家 ZIP。Changelog 从实际单体包 TOC 与清单生成，记录每个组件版本、TOC 依赖、最低 Core API（已登记项）和组件包 SHA256。

## 发布状态

此前 v1.0.0 文件因资料目录结构被拒绝。本次调整为 `YiboCore for MoP` 项目名，并从上传 ZIP 排除仓库资料目录；新候选尚未构建或上传。多插件并列目录的 CF 审核与客户端同时管理仍待验证。

完整安装与更新规则见 [INSTALL.md](INSTALL.md)，每次下载对应内容见 Releases 下该版本的 Changelog。CF 项目介绍使用 [CURSEFORGE_DESCRIPTION.md](CURSEFORGE_DESCRIPTION.md)；CF 文件页使用该版本 `CURSEFORGE_CHANGELOG.md`。
