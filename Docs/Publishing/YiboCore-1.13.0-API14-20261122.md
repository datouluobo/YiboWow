# YiboCore 1.13.0 / 0.3.0 / 0.2.0（API14）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认三目标已上传发布；渠道文件 ID 未提供）。

## 产物

| 目标 | 文件 | 版本 | Interface | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- |
| Mists | `Builds/YiboCore-mists-v1.13.0-api14-curseforge.zip` | 1.13.0 / API14 | 50504 | 1513736 | `F3D90A0930F7DF92D19E19B85F949E831AE604DF10696202480E73655BD5265A` |
| Forever | `Builds/YiboCore-forever-v0.3.0-api14-curseforge.zip` | 0.3.0 / API14 | 16001 | 1511018 | `0B8A6E0CC789C1BEC08D898E8959499EF9C4C9E08086D5743B97C800984C351F` |
| Retail | `Builds/YiboCore-retail-v0.2.0-api14-curseforge.zip` | 0.2.0 / API14 | 120105 | 1507268 | `6532FC74B2742F86C40E21B9E019B02D12F1AC98ADBD5D77D9F20A36C6D41C10` |

源码／构建配置摘要：`db7c9d53a30d1a299b52b41a98443579e73c5e883fd946b8b139a0e2c0312d66（含 CHANGELOG-Recent）`（三目标同一快照）。旧 Mists 1.12.14、Forever 0.2.4 包已由统一构建器移入 `Builds/Archive/YiboCore/`。本轮未生成 GitHub 源码归档。首次构建后补写 CHANGELOG-Recent 改变了源码摘要，已重建；与首次构建相比仅 `YiboReleaseManifest.json` 不同，运行文件逐字节一致，首次构建包移至 `_NonRelease/CoreRelease-20261122/Superseded-PreChangelog/`。schema 11 与三目标 SavedVariables（`YiboCoreDB`／`YiboCoreForeverDB`／`YiboCoreRetailDB`）不变。

## 发布内容

- API14 / `pixel-line:1`：1 线宽按物理像素绘制，按边像素边框，`SetPixelAnchor` 公开重新定位接口；UI 缩放、显示尺寸和整合界面 `UIParent:SetScale` 后即时刷新。
- Core 内部线框全部改为 1 像素线；角色档案相邻行只共用一条线。
- 当前角色描边画在格线上，从表头开始、止于可见内容；普通 Frame 视口不再报错。
- 双行角色表头整组垂直居中；左/右对齐表头与正文同一内容边界。
- 统一构建器修复生成内容的 luac 校验方式（`Tools/Release.Common.ps1`）。

## 兼容性

- API 向下兼容：仍要求 API13 的业务插件（Currency、AutoOpen、Mounts、Crafting Forever 及当前已发布的各业务版本）在新 Core 下继续运行。
- 已适配 API14 的业务插件新版本（AltoBoss、Builds、Crafting、Mail、QuestBlocker、Reputation、TaskHub、Todo、Vault、Legendary、BeastPaths）必须在本 Core 之后或同批发布；配旧 Core 会提示升级并停止。
- 旧版业务插件与新 Core 组合：线框按旧插件自身画法，Core 部件（按钮、表头、描边）为新画法；Crafting 旧版专业矩阵描边会包含分页条高度，Legendary 旧版行描边会延伸到行宽，均为外观差异，随对应插件新版本消除。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | 三目标正式构建成功：目标、Interface、版本、API 后缀、引用与包内容校验通过；包内仅默认 `YiboCore.toc` |
| 干净安装（实际 ZIP 解包） | Mists／Forever／Retail 各 3 种语言模式：就绪、目标版本、API14 能力与公开像素接口、本目标存档保留、他目标存档未触碰、单次就绪、重复初始化、档案与设置渲染、快照重启恢复、无回调失败 |
| 覆盖更新 | Mists 1.12.14 → 1.13.0、Forever 0.2.4 → 0.3.0：旧包解压后直接覆盖新包，保留旧文件；旧包独有残留文件 0 个，覆盖后仍只有 `YiboCore.toc`；同上全部用例通过。Retail 无上一正式发行版，不适用 |
| 误装目标 | 每个包装到另两个客户端均在写库前停止，不初始化存档 |
| 合计 | `_NonRelease/CoreRelease-20261122/PackagedSpec.lua` 220 项通过 |
| 回归 | Core 8 组离线测试通过（PixelLineSpec 85 项）；全工作区 145 个在用测试与 2026-11-20 基线一致，无新增失败 |
| 语法 | 36 个 TOC、431 文件通过 |
| 本地化 | Core 568 项，缺英文 0、格式不一致 0、重复 0（报告 `_NonRelease/Localization/Build/Core-1.13.0-API14.md`） |
| 实机 | 用户确认三端（MoP NDui、Forever EllesmereUI、Retail 原生）像素线、即时刷新及业务插件迁移实机验证通过；探针证据见 `_NonRelease/YiboCorePixelLineProbe/Evidence-Mists-20261121.md` |

## 待办

- 上传 CurseForge（用户执行），登记文件 ID 与发布日期。
- 业务插件 API14 版本的版本号与发布检查另行进行。
