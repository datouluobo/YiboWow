# Yibo Addon Suite Mists 1.2.0 / Forever 1.0.0 发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认 Mists 1.2.0 与 Forever 1.0.0 已上传到原整合包 CurseForge 项目；项目正文已按 `CURSEFORGE_DESCRIPTION.md` 双客户端版更新，用户确认显示正常；渠道文件 ID 未提供）。

## 产物

| 目标 | 文件 | 版本 | 组件 | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- |
| Mists | `Builds/Yibo-Addon-Suite-mists-v1.2.0-curseforge.zip` | 1.2.0 | 15 | 30462717 | `7CB883FFE07C904542974DC04FEACF8CAD0EF5BCCC7CC11219DB83CF36268519` |
| Forever | `Builds/Yibo-Addon-Suite-forever-v1.0.0-curseforge.zip` | 1.0.0 | 9 | 16058898 | `6A9EB8DCB9113C672057D21CBD34F9DC7102432D16A85C1526CB9A6300B57C09` |

- 源码快照摘要：Mists `79e53c21d3f04de60c1abb89ae07a006df594760396cd37948846613173a89cb`，Forever `af963aa6decbd71b8389c68695133484e59e88398628cbed9322e42fb9e3871e`。
- 发布资料：`YiboCore for MoP/Releases/mists-v1.2.0/`、`YiboCore for MoP/Releases/forever-v1.0.0/`（CHANGELOG.md、CURSEFORGE_CHANGELOG.md、INSTALL.md、YiboAddonSuiteManifest.json）。
- 旧名 `Yibo-Addon-Suite-for-MoP-mists-v1.1.0` 移至 `Builds/Archive/Yibo-Addon-Suite-for-MoP/`。

## 组件

| 插件 | Mists | Forever |
| --- | --- | --- |
| YiboCore | 1.13.0（API14） | 0.3.0（API14） |
| YiboAltoBoss | 2.9.0 | 0.2.0 |
| YiboAutoOpen | 1.2.7 | 0.1.2 |
| YiboBeastPaths | 1.10.0（universal 共用包） | — |
| YiboBuilds | 1.6.0 | 0.2.0 |
| YiboCrafting | 1.3.0 | 0.2.0 |
| YiboCurrency | 1.1.3 | 0.1.9 |
| YiboLegendary | 2.3.0 | — |
| YiboMail | 1.4.0-api1 | 0.3.0-api1 |
| YiboMounts | 1.0.3 | — |
| YiboQuestBlocker | 3.2.0 | — |
| YiboReputation | 1.8.0 | 0.2.0 |
| YiboTaskHub | 0.7.0 | — |
| YiboTodo | 1.3.0 | — |
| YiboVault | 1.3.0-api1 | 0.7.0-api1 |

## 打包工具变更

- 整合包更名 `Yibo-Addon-Suite`，`Suite.psd1` 改为按目标配置版本与组件；`Build-Suite.ps1` 新增 `-Target Mists|Forever`，组件集合须等于 `ReleaseProfiles.psd1` 中声明该目标的全部插件。
- 本机无 PowerShell 7，构建器改为 Windows PowerShell 5.1 兼容。.NET Framework 的 `ZipFile.CreateFromDirectory` 会写出反斜杠条目名；改为逐条写入正斜杠条目，并在 ZIP 校验中拒绝反斜杠。首次构建（反斜杠条目）及对应发布资料已移至 `_NonRelease/SuiteRelease-20261122/Superseded-Backslash/`，未上传。
- 新增 `CURSEFORGE_CHANGELOG.md`（CF 文件页组件版本表）自动生成。
- `INSTALL.md`、`README.md`、`CURSEFORGE_DESCRIPTION.md`、`发布包约定.md` 更新为双客户端。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 包结构 | ZIP 根层仅插件目录，无资料目录、`_NonRelease`、测试或 WTF；条目全部为正斜杠；构建器逐文件校验 ZIP 与暂存内容一致 |
| 组件一致性 | 与已发布单体包逐文件比对（不含各自的 `YiboReleaseManifest.json`）：Mists 14 个、Forever 8 个业务组件全部逐字节一致；Mounts 1.0.3 与整合包 1.1.0 中的文件逐字节一致（无单体包在 `Builds/`） |
| Core 组件差异 | 仅 `YiboCore/Data/PackagedAddonVersions.lua` 与已发布 Core 单体包不同：该文件由打包器按当时各插件版本生成，Core 单体包构建于业务插件升版前；整合包内为本批实际组件版本（关于页显示用），属预期差异 |
| 依赖与 API | 构建器核对所有 RequiredDeps 均在包内；各组件最低 Core API ≤ 包内 Core API14 |
| 运行回放 | 未对整合包另做合并加载回放；各组件运行文件与已逐项完成干净安装、覆盖、误装与 API13 回放的单体包逐字节一致 |

## 待办

- 用户上传两份 ZIP；CF 文件页 Changelog 粘贴对应 `CURSEFORGE_CHANGELOG.md`，Game Version 分别选 MoP Classic 5.5.4 与 Forever 1.60.1。
- 项目正文改用新的 `CURSEFORGE_DESCRIPTION.md`。
- CF 同时管理整合包与单体仍未验证（见 INSTALL）。
