# YiboBeastPaths 1.10.0（Retail／Mists 共用包，Core API14 像素线）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标集合 | 文件 | 版本 | Interface | 最低 Core API（构建器读取） | 文件数 | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Retail + Mists（universal） | `Builds/YiboBeastPaths-universal-v1.10.0-curseforge.zip` | 1.9.1 → 1.10.0 | 120105（`_Mainline`）／50504（`_Mists`）；提示 TOC 120105, 50504 | 14（`Common/OfflinePetCoreGate.lua` 与 `Maintenance/CoreDebugAdapter.lua` 一致） | 118 | 5107540 | `634097B8FF1E8CA1124E3E160C85C41349202BE8DC9793E13605ED8960715E70` |

源码／构建配置摘要：`40c8105ef8e6bd8a7f8f05d54ae2478e332c2477035b06b2fee83f2fee150d91`（含 CHANGELOG 更新；构建后 ValidateOnly 复核摘要一致）。上一发行包 `YiboBeastPaths-universal-v1.9.1-curseforge.zip`（`237E538D10E78E101751651A65A1215D69DC22B1EA5A7352539E63F77062EF7C`）已由构建器移入 `Builds/Archive/YiboBeastPaths/`。本轮未生成 GitHub 源码归档。SavedVariables（`YiboBeastPathsDB`、`YiboBeastPathsDebugDB`）、`/ybp` 与页面 ID 不变。

版本位置：`YiboBeastPaths.toc`、`YiboBeastPaths_Mainline.toc`、`YiboBeastPaths_Mists.toc` 的 `## Version`（构建器要求三者一致），以及 `Common/OfflinePetRuntime.lua`、`Maintenance/CoreDebugAdapter.lua` 中 `RegisterAddon` 的 `version`。测试 `OfflinePetRealCoreSpec.lua`、`Core13IntegrationSpec.lua` 版本断言同步为 1.10.0。

## 包形态与约定

- 构建入口：`Tools/Build-ReleasePackages.ps1 -Addon YiboBeastPaths` 因 `Tools/ReleaseProfiles.psd1` 的 `LegacyBundles.YiboBeastPaths`（Slug `universal`）转交 `Tools/Build-LegacyBundle.ps1`。
- 按发布说明执行 `-Target Mists` 与 `-Target Retail`：构建器均拒绝，报错 `No configured legacy multi-TOC bundle for this addon/target.`（`Build-LegacyBundle.ps1` 只接受 `Universal`）。实际构建为不带 `-Target` 的默认路径，产出上表单个 universal 包。
- 与约定的差异：`发布包约定.md` 写明 BeastPaths 1.9 玩家包分别使用 `retail`／`mists` slug、只含所选目标默认 TOC；而 `YiboBeastPaths/AGENTS.md` 记录用户 2026-11-13 批准“1.9 继续采用 1.8.3 的双端共用包例外”，构建配置与已发布 1.9.0／1.9.1 均为 universal。本包含默认提示 TOC + `_Mainline` + `_Mists` 三份 TOC，并沿用旧打包器内容（含 `README.md`、`CHANGELOG.md`、`Docs/`、`Assets/Screenshots/github-homepage-preview.jpg`），与 1.9.1 包文件集合完全相同。**该例外是否覆盖 1.10.0 须用户确认**；若改为分包，需先修改构建配置（本轮未改 Tools）。

## 发布内容

- 离线兽栏（`Common/OfflinePetCoreGate.lua`，Retail／Mists 共用）与路线维护增强（`Maintenance/CoreDebugAdapter.lua`）最低 Core 提到 API14，新增 `pixel-line:1` 及 `ApplyPixelBackdrop`（维护另查 `ApplyPixelRule`）检查；两处 `RegisterAddon` 声明 API14，中英文 `CORE_REQUIRED`／`MAINTENANCE_STATUS` 改为 API14。
- 兽栏详情面板、CoreDebugView 分组卡片、导出框与宠物图标框改用 Core `ApplyPixelBackdrop`；`DebugCalibrator` 分隔线改用 `ApplyPixelRule`。路线几何与 Tooltip 边框不变。
- Core 缺失或版本不足时只停用这些增强，地图路线照常运行（Core 为 OptionalDeps）。
- 包内变更文件（对比 1.9.1 包）：`Common/OfflinePetCoreGate.lua`、`Common/OfflinePetRenderer.lua`、`Common/OfflinePetRuntime.lua`、`Locale.lua`、`Maintenance/CoreDebugAdapter.lua`、`Maintenance/CoreDebugView.lua`、`Maintenance/DebugCalibrator.lua`、三份 TOC、`CHANGELOG.md`、`Docs/Core-API13-接入说明.md`、`Docs/离线兽栏与拥有状态-版本任务清单.md`。无新增或移除文件。

## 兼容性

- Core 增强需要 YiboCore API14：Mists 1.13.0 / Retail 0.2.0（均已发布）。配旧 Core 时只停用离线兽栏与路线维护并提示升级，路线地图不受影响。
- 客户端选择：Mists 客户端选 `YiboBeastPaths_Mists.toc`，Retail 客户端选 `YiboBeastPaths_Mainline.toc`；默认 `YiboBeastPaths.toc` 仅加载 `Common/TocHint.lua`。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | universal 包构建成功：三 TOC 版本一致、Interface 与声明一致、两处 Core 门槛均为 14、引用与 Lua 校验通过；`-Target Mists`／`-Target Retail` 被拒（见上） |
| 包内容（实际 ZIP） | 单一顶级目录 `YiboBeastPaths/`；三份 TOC（提示、`_Mainline`、`_Mists`）+ Retail／Mists／Common／Maintenance／Libs／Media／Assets 及文档；无 `_NonRelease`、测试、WTF。按 universal 例外设计包含两目标 TOC 与文档，不满足“仅默认 TOC + 本目标文件”的单目标包规则 |
| 覆盖更新 | 1.9.1 → 1.10.0：旧包解压后直接覆盖新包、保留旧文件；旧包独有残留文件 0 个，TOC 集合不变（同名覆盖） |
| 打包回放 | `_NonRelease/YiboBeastPathsRelease-20261122/PackagedReplay.lua` 132 项通过（旧包存档 4、初始化 76、存档 16、误装 16、API13 20）。已发布 Core 包（Mists 1.13.0／Retail 0.2.0）下按各客户端所选 TOC 从 Clean／Overlay 加载完整 35 文件链：API14 与 `pixel-line:1`、Core 登记 1.10.0／requiredAPI 14、离线兽栏页只注册 1 次（重复 ADDON_LOADED／PLAYER_LOGIN／CORE_READY／`Core:Initialize` 不增加页面或设置注册）、页面打开渲染、无错误消息；旧版存档由实际 1.9.1 包生成（Mists 在 Core 1.12.14／API13 下，Retail 因无 API13 Retail Core 在 0.2.0 下），路线设置与离线兽栏记录保留并重载恢复；默认提示 TOC 单独加载时只运行 TocHint、不写库；把另一客户端的 TOC 强加到本客户端时不创建对象、不改存档、不注册；API13 Core 被拒（Mists 为已发布 1.12.14 包，Retail 为 0.2.0 包人为降为 API13 的合成情形），路线照常启动、不写离线兽栏存档，`/ybp debug`／`/ybp stable` 给出含 API14 的升级提示。合成环境限制：仅提供空地图层级的最小地图 API，桩 `WorldMapFrame` 只在 HereBeDragons 库加载期间存在，插件走“世界地图尚未加载”路径，世界地图／小地图路线渲染未覆盖；共享 FrameFixture 缺 `SetZoom`、`UnregisterAllEvents`，按记录的空操作补足 |
| 回归 | 12 组离线测试通过（Core13IntegrationSpec 1196、CoreDebugViewSmoke、DebugContextSmoke、OfflinePetCapture、MistsReader、Observation、RealCore、Runtime 54、Snapshot、WrongTarget、UnifiedSettings），与改版本前一致；`OfflinePetMistsReplay.lua`、`OfflinePetStoredSummary.lua` 需要 SavedVariables 路径参数，未运行（既有） |
| 语法 | 3 个 TOC、38 文件通过 |
| 实机 | 像素线迁移已由用户在本会话实机验证（源码联接加载）；打包 ZIP 本身未在客户端单独安装／覆盖测试 |

TOC／运行入口记录：适用 Retail、Mists（universal 例外）；实际加载名 Retail `YiboBeastPaths_Mainline.toc`、Mists `YiboBeastPaths_Mists.toc`；误目标写库保护（`Target.lua` 的 `YBP_TARGET_OK`）回放通过；Core 就绪、API14 与能力检查回放通过；单次初始化回放通过；存档身份不变；旧文件覆盖无残留；构建引用由构建器校验。

## 待办

- **用户确认**：1.10.0 是否继续沿用 universal 单包例外（`YiboBeastPaths/AGENTS.md` 的批准文字限定为 1.9）；若沿用，建议在插件文档记录例外延续范围，并同步 `发布包约定.md` 中“BeastPaths 1.9 使用 retail／mists”的表述。
- 确认后上传 CurseForge（用户执行，项目 1575919），登记文件 ID 与发布日期。
- `Tools/ReleaseProfiles.psd1` 的 `ValidationState` 仍为 `1.9.1-retail-mists-bundle-user-accepted-20261115`，写入包内构建清单；由负责人统一更新。
- `_NonRelease/Tools/Build-CurseForgePackages.ps1` 的可选 `-Version` 核对仍写死 1.9.0（非发布文件，未改动）。

## 2026-11-22 例外确认与重建

用户确认 1.10.0 继续沿用 2026-11-13 批准的 Retail／Mists 双端 universal 共用包例外，此前“分包”阻断项撤销。按用户要求删除首次构建的 1.10.0 包（SHA256 `69D09D3C7D812AD98782305ED1789C17196EEBE27E90834BEE32FF696B8BED9A`）后重建：`Builds/YiboBeastPaths-universal-v1.10.0-curseforge.zip`，5107540 字节，SHA256 `634097B8FF1E8CA1124E3E160C85C41349202BE8DC9793E13605ED8960715E70`，源码摘要 `40c8105ef8e6bd8a7f8f05d54ae2478e332c2477035b06b2fee83f2fee150d91`；包含默认、`_Mainline`、`_Mists` 三份 TOC，118 个文件。重新解包后打包回放 132 项通过（自 1.9.1 覆盖、旧存档、误装、API13 拒绝）。状态：**发布检查通过，待用户上传**。`YiboBeastPaths/AGENTS.md` 的例外范围说明待下次源码修改时补写 1.10.0（本次不改源码，以免改变已构建包的源码摘要）。
