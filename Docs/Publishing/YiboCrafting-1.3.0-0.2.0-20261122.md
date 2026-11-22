# YiboCrafting Mists 1.3.0 / Forever 0.2.0（Core API14 像素线）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标 | 文件 | 版本 | Interface | 最低 Core API（构建器读取） | 文件数 | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Mists | `Builds/YiboCrafting-mists-v1.3.0-curseforge.zip` | 1.2.5 → 1.3.0 | 50504 | 14 | 22 | 1877289 | `8E80CACF5C16F95F15BD0619D8CF18C04AE4B353E570DE328F3D01E323A60CDE` |
| Forever | `Builds/YiboCrafting-forever-v0.2.0-curseforge.zip` | 0.1.5 → 0.2.0 | 16001 | 13 | 17 | 1794013 | `5092FC8C7B7F93566FD9E5CA13F51755481CD6C85D6C7AFC6BDFA6F6E884F593` |

源码／构建配置摘要：`5782940b5a1a36e8025e1193ffb3525c9867f45d84890af402387991a82b251c`（两目标同一快照，含 CHANGELOG 更新；构建后 ValidateOnly 复核摘要一致）。上一发行包 `YiboCrafting-mists-v1.2.5-curseforge.zip`（`17614AD2997F6045327C23FAC7C652DCEF8BF1BCD403AFD9232CAF8B51C729F8`）与 `YiboCrafting-forever-v0.1.5-curseforge.zip`（`02FEB5941467A8B44D3981C84E11D111E69E3E02F24ED1EF86470EDD6F06E8AC`）已由统一构建器移入 `Builds/Archive/YiboCrafting/`。本轮未生成 GitHub 源码归档。SavedVariables（Mists `YiboCraftingDB`／Forever `YiboCraftingForeverDB`）、`/ycr` 与页面 ID 不变。

版本位置：`YiboCrafting_Mists.toc`、`Namespace.lua`（Mists）；`YiboCrafting_Forever.toc`、`Forever/Namespace.lua`（Forever）；默认提示 `YiboCrafting.toc` 无版本行。`_NonRelease/CraftingForever/Smoke.lua` 版本断言同步为 0.2.0。

## 发布内容

- Mists `AccountPage.lua`：面板外框改用 Core `ApplyPixelBackdrop`，配方行分隔线改用 `ApplyPixelRule`；滚动区与矩阵表头按 `GetPixelSize` 内缩并经 `SetPixelAnchor` 随缩放重锚，宽高预算改为 2 × 像素。
- Mists 最低 Core 提到 1.13.0 / API14（`Bootstrap.lua`，含 `pixel-line:1` 与像素方法检查，`RegisterAddon` 声明 API14），`UI.UPGRADE` 中英文同步；不足时提示并停止，无本地回退。
- Forever `Forever/AccountPage.lua`：表头文字改为填满容器高度，在 26 单位表头与 30 单位行内垂直居中。Forever 最低 Core 保持 API13（`Forever/Bootstrap.lua` `CheckAPIVersion(13)`，`RegisterAddon` 声明 13）。
- 包内变更文件（对比上一包）：Mists `AccountPage.lua`、`Bootstrap.lua`、`Locales/Interface.lua`、`Namespace.lua`、`YiboCrafting.toc`；Forever `Forever/AccountPage.lua`、`Forever/Namespace.lua`、`Locales/Interface.lua`（共享资源，仅 Mists 升级文本变化）、`YiboCrafting.toc`。无新增或移除文件。

## 兼容性

- Mists 需要 YiboCore 1.13.0 / API14；配旧 Core（1.12.14 / API13）时提示升级并在写库前停止。
- Forever 仍只需 API13：在已发布 Core 无限服 0.3.0（API14）与上一版 0.2.4（API13）上均正常初始化，不被拒绝。
- 版本选择：Mists 源码清单 `YiboCrafting_Mists.toc`、Forever 源码清单 `YiboCrafting_Forever.toc`，玩家包均输出为默认 `YiboCrafting.toc`；包内无其它目标 TOC。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | 两目标正式构建成功：目标、Interface、版本、最低 Core API（Mists 14／Forever 13）、引用与包内容校验通过 |
| 包内容（实际 ZIP） | 单一顶级目录 `YiboCrafting/`；仅默认 `YiboCrafting.toc` + 本目标文件 + Locales + Media + 构建清单（Mists 含 `Mists/`，Forever 含 `Forever/`）；无其它目标 TOC／目录、`_NonRelease`、测试、WTF、文档 |
| 覆盖更新 | Mists 1.2.5 → 1.3.0、Forever 0.1.5 → 0.2.0：旧包解压后直接覆盖新包、保留旧文件；旧包独有残留文件 0 个，覆盖后仍只有 `YiboCrafting.toc` |
| 打包回放 | `_NonRelease/YiboCraftingRelease-20261122/PackagedReplay.lua` 144 项通过（旧包存档 6、初始化 88、存档 30、误装 12、API13 8）。已发布 Core 包下按包内 TOC 顺序加载 Clean／Overlay：包版本、单次注册（`RegisterAddon` 1 次，requiredAPI Mists 14／Forever 13；重复 ADDON_LOADED／PLAYER_LOGIN／CORE_READY 不再注册）、页面渲染、无错误消息；旧版存档由实际旧包在 API13 Core 下经其自身 Store 写入（Mists 配方观察与预览列设置，Forever 配方快照与预览列设置），新包保留并重载恢复；Forever 包在 Core 0.3.0 与 0.2.4 上各自完成全新与升级两种回放；误装到另一客户端不创建本目标存档、不改动对方存档、不注册；Mists 包遇 API13 Core 被拒、不建存档、显示含 API14 的升级提示。合成环境限制：MoP 页面渲染时共享 FrameFixture 缺 `Disable`、`HasScript`、`IsInIMECompositionMode` 三个控件方法，按记录的空操作补足 |
| 回归 | Crafting 8 组离线测试通过（CoreAdaptation、CoreNameIntegration、EnchantGoals、GoalTargets、RealmGoals、RecipeScanScheduling、RecipeStateScanner、SearchPerformance），与改版本前一致；`Tests/Smoke.lua` 栈溢出、`_NonRelease/CraftingForever/Smoke.lua:163` 为既有失败（版本断言已过）；`Tests/LoadLocale.lua` 为被其它测试加载的夹具，单独运行即断言失败，改版本前后相同 |
| 语法 | 3 个 TOC、19 文件通过 |
| 实机 | 像素线迁移已由用户在本会话实机验证（源码联接加载）；Forever 表头居中修复与打包 ZIP 本身未在客户端单独安装／覆盖测试 |

TOC／运行入口记录：适用 Mists、Forever；实际加载名均为默认 `YiboCrafting.toc`；误目标写库保护（Mists `CLIENT_SUPPORTED`、Forever `WOW_PROJECT_CAMELOT` 检查）回放通过；Core 就绪、版本（Mists API14／Forever API13）与能力检查回放通过；单次初始化回放通过；存档身份不变；旧文件覆盖无残留；构建引用由统一构建器校验。

## 待办

- 上传 CurseForge（用户执行），登记文件 ID 与发布日期。
- `Tools/ReleaseProfiles.psd1` 的 Forever `ValidationState` 仍为 0.1.5 时的文字，写入包内构建清单；由负责人统一更新。
- 已发布 Core 包内 `PackagedAddonVersions` 仍列 1.2.5／0.1.5，仅用于 Core 插件状态显示，随下次 Core 发布更新。

## 2026-11-22 Forever 版本号更正

用户指出 Forever 应从 0.1.5 升到 0.2.0（原误为 0.1.6）。已更正 `YiboCrafting_Forever.toc`、`Forever/Namespace.lua`、CHANGELOG 与 `_NonRelease/CraftingForever/Smoke.lua` 版本断言；0.1.6 包未上传，移至 `_NonRelease/YiboCraftingRelease-20261122/Superseded/`。重建 `Builds/YiboCrafting-forever-v0.2.0-curseforge.zip`：1794001 字节，SHA256 `5092FC8C7B7FBCF67410E7AE8FF89D6416C120FC8DB698D7593B426CDB0F2DF3`，源码摘要 `a13f7c2949c3cad7ac4f3ef3be5a95ac0654204746a2a7d310bf5534526fb352`，最低 Core 仍为 API13。自 0.1.5 覆盖残留 0；打包回放 144 项通过；语法 19 文件通过；CraftingForever Smoke 通过版本断言后仍在既有的 163 行失败。Mists 1.3.0 包内容不变、未重建，其包内记录的源码摘要为 CHANGELOG 更正前的快照。状态：**发布检查通过，待用户上传**。
