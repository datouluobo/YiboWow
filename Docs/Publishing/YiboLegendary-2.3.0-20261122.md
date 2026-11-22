# YiboLegendary 2.3.0（Mists，API14）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标 | 文件 | 版本 | Interface | 最低 Core（构建器读取） | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- | --- |
| Mists | `Builds/YiboLegendary-mists-v2.3.0-curseforge.zip` | 2.3.0 | 50504 | API14 | 1577076 | `B7BF9549D3444E4235905FB77E096DFBAF6FABA74CFE4C64042A485931852D64` |

源码摘要 `5f0a8e449bba0fceb4018ea712c4d2efb8a9b656d2957399555b5dbdd3d16c87`（含 CHANGELOG 2.3.0 条目；构建后 ValidateOnly 复核一致）。上一发行版 `YiboLegendary-mists-v2.2.5-curseforge.zip`（SHA256 `0B8B0D28AFBB6AFCF09669D123FE0CE94A490A231630DE1BA6F745831A76B1E1`）已由统一构建器移入 `Builds/Archive/YiboLegendary/`。未生成 GitHub 源码归档。

## 发布内容

- 目标页工具栏归档分隔竖线改用 Core `ApplyPixelRule`，粗细按物理像素绘制并随 UI 缩放即时刷新；当前角色行描边只覆盖矩阵列宽（消除旧版配新 Core 时描边延伸到行宽的外观差异）。
- 最低 Core 提高到 API14，并检查 `pixel-line:1` 与 `ApplyPixelRule`；不足时输出中英文升级提示并停止初始化。
- 版本：TOC `## Version` 与 `Bootstrap.lua` `Addon.VERSION` 2.2.5 → 2.3.0。
- 存档（`YiboLegendaryDB`／`YiboCloakProgressDB`，schema 2）、追踪逻辑与 `/yle` 不变。

## 兼容性

- 需要 YiboCore API14：Mists 1.13.0 / Forever 0.3.0 / Retail 0.2.0（本插件只发 Mists 包，Mists 配 Core Mists 1.13.0）。
- 配旧 Core（API13）提示升级并停止，存档保留；本插件仅 Mists，装到其它客户端在写库前停止。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | Mists 正式构建成功：目标、Interface、版本、引用与包内容校验通过；manifest `minimumCoreAPI = 14` |
| 包内容（实际 ZIP） | 17 项，单顶级目录；只有默认 `YiboLegendary.toc`；无其它目标 TOC、`_NonRelease`、测试、文档、WTF；包内文件与源码逐字节一致 |
| 新旧包差异 | 变更 `Bootstrap.lua`、`UI.lua`、`Locales/Interface.lua`、TOC、manifest；其余 12 项不变；无新增／移除路径 |
| 覆盖更新 | 2.2.5 解压后直接覆盖 2.3.0，保留旧文件：残留 0 个，仍只有 `YiboLegendary.toc`，无 XML；覆盖目录与干净目录逐文件一致 |
| 打包回放 | `_NonRelease/YiboLegendaryRelease-20261122/PackagedReplay.lua`：真实 Core Mists 1.13.0 包 + 本插件包按 TOC 与客户端事件顺序加载，Clean／Overlay 各 78 项，共 **156 项通过、0 失败**（日志 `PackagedReplay-Result.txt`） |
| 安装／升级 | 新装 zhCN、上一版存档 zhCN／enUS：Core 1.13.0／API14 就绪；插件初始化；`RegisterAddon`／页面／入口各 1 次；Core 注册版本 2.3.0；重复事件与直接 `Initialize` 不重复注册；账号页渲染无错误；上一版存档（等级过滤、预览列、他角色记录）保留；重载后单次初始化且数据保留；无事件处理错误 |
| API13 拒绝 | 已发布 Core Mists 1.12.14（API13）包：插件不初始化、零注册、中英文升级提示（含 API v14）、存档保留；Clean／Overlay 各 13 项通过 |
| 误装目标 | Forever（Core Forever 0.3.0）、Retail（Core Retail 0.2.0）、Forever 误配 Core Mists 包，各含无存档／有存档：均不初始化、零注册、存档未改动；各 24 项通过。上一版 2.2.5 同场景 24 项通过 |
| 回归 | 插件无离线测试；语法检查 7 文件通过 |
| 实机 | 像素线迁移由用户在 MoP 工作树实机验证通过（与本包仅版本字符串不同）；本安装包的客户端干净安装／覆盖与完整退出恢复未单独执行 |

TOC／运行入口收尾：适用 YiboLegendary／Mists；源码清单与实际加载名均为 `YiboLegendary.toc`；`Initialize` 依次检查 Core API14 与能力、Core 就绪、`WOW_PROJECT_MISTS_CLASSIC`，之后才绑定存档；单次初始化由 `initialized` 守卫；存档身份不变；旧文件覆盖无残留；构建引用经统一构建器校验。回放夹具说明见 `_NonRelease/BusinessReleaseHarness-20261122/Harness.lua`（FrameFixture 补 `SetParent` 及返回“无观测”的客户端 API 桩；货币／任务追踪未以真实数据执行）。

## 待办

- 上传 CurseForge（用户执行），登记文件 ID 与发布日期；须在 Core Mists 1.13.0 之后或同批。
- 可选：安装包客户端干净安装／覆盖与完整退出恢复（同加载字节的工作树实机证据可复用）。
