# YiboSuite for MoP - Account QoL Addons

技术名：`YiboSuite`；首包版本：`v1.0.0`；目标：Mists of Pandaria Classic。

Suite 收录 Suite.psd1 中登记的全部 15 个正式插件当前源码版本，不包含非发布探针。它保留单体目录、版本及存档身份，提供一次下载的固定组件快照。YiboSuite 自身仅为发行资料目录，无 TOC、运行代码或强制加载关系。

## 本地打包

在仓库根目录使用 PowerShell 7.2+：

```powershell
pwsh -File YiboSuite/Tools/Build-Suite.ps1
```

需要 Python 与 Lua 5.1 luac（沿用单体构建要求）。脚本先在 `_NonRelease/Packaging/Suite/<运行ID>/` 使用现有打包器生成全部单体安装包，核对组件依赖闭合并合并其实际内容；中间产物保留用于追溯。不会改写或归档单体 Builds 产物。BeastPaths 沿用现有 universal 维护包内容，Suite 整体兼容声明仅为 Mists。

默认输出 `Builds/YiboSuite-mists-v1.0.0-curseforge.zip`；支持 `-WorkspaceRoot`、`-OutputRoot` 和 `-ValidateOnly`。ValidateOnly 执行单体构建计划校验，不生成或移动产物。实际构建会先验证 ZIP 和输入快照稳定性，再复用公共发布器归档旧版 Suite；同名安装包已存在时停止，避免覆盖固定版本。正式分发应固定源码快照并递增 Suite 版本，不能把不同组件组合复用为同一已发布版本。

Suite 发布资料独立保存在 `YiboSuite/Releases/v<版本>/`，包括自动生成的 CHANGELOG.md、INSTALL.md 和 YiboSuiteManifest.json；包内为 `YiboSuite/` 下同名资料。Changelog 从实际单体包 TOC 与清单生成，包含每个组件版本、TOC 依赖、最低 Core API（已登记项）和组件包 SHA256。未登记最低版本显示为运行时检查，不虚构要求。

## 发布状态

本次仅生成本地候选安装包，未上传。CF 多目录包审核、项目归属与客户端同时管理未验收；不能把本地打包成功视为 CF 或游戏内验收通过。现有工作区验收记录应按本次组件快照复核，尤其是中英文客户端与手动语言模式。

完整安装与更新规则见 [INSTALL.md](INSTALL.md)，每次下载对应内容见 Releases 下该版本的 Changelog。CF 项目介绍使用 [CURSEFORGE_DESCRIPTION.md](CURSEFORGE_DESCRIPTION.md)，英文在前、中文在后，插件名包含 CF 站内链接；CF 文件页使用该版本 `CURSEFORGE_CHANGELOG.md`，仅列英文插件名与精确版本。随包完整 Changelog 保留依赖与安装规则，不引用单体滚动更新日志替代组件清单。
