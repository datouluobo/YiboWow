# YiboReputation Mists 1.8.0 / Forever 0.2.0（Core API14 像素线）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标 | 文件 | 版本 | Interface | 最低 Core API（构建器读取） | 文件数 | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Mists（重建） | `Builds/YiboReputation-mists-v1.8.0-curseforge.zip` | 1.7.4 → 1.8.0 | 50504 | 14 | 28 | 1960315 | `FC012FCE1256E9AB4171308A69CCF50FAEFCD2C11626F23FB38566629EC46A24` |
| Forever | `Builds/YiboReputation-forever-v0.2.0-curseforge.zip` | 0.1.9 → 0.2.0 | 16001 | 14 | 17 | 1934511 | `37E818DBA3655A5EBF6F56A2997DF16661F2618A6D443058142F481C13222808` |

源码／构建配置摘要：Mists 重建包 `f35e646ecee470bf27f812bd3a12d3f28d9f854a3b8acab1b1f68e6c7daf8849`（含修复与 CHANGELOG；重建后两目标 ValidateOnly 通过、摘要一致）。Forever 包未重建，包内清单仍记录首次快照 `1b50a4712c4efe3b1555f042b46f9ffcf8b0ab4729fc80cfc644af22e6e8cd8b`；其后变化的 `Bootstrap.lua`（仅 `YiboReputation_Mists.toc` 引用；Forever 使用 `Forever/Bootstrap.lua`）与 `CHANGELOG.md` 均不在 Forever 包内。首次 Mists 包（`C80A554455111430B14A6BD15C65CC76B1BE26F47FF63D260E8870CD2CF79DD4`，1960239 字节，从未上传）已移至 `_NonRelease/YiboReputationRelease-20261122/Superseded/`，旧解包目录在 `Superseded/Extract-r1/`；重建时构建器 `Archived=0`。重建包与被替换包相比仅 `Bootstrap.lua`、`YiboReleaseManifest.json` 不同，文件集相同。上一发行包 `YiboReputation-mists-v1.7.4-curseforge.zip`（`1EC710A8331FA51F904AC06DF6E88EE98AA98F4D75734289AB76CEE4C0E234E0`）与 `YiboReputation-forever-v0.1.9-curseforge.zip`（`FA10DAA3ED59EB3908838B464DF824784344F989AA4F412A3CB957CFF75223E1`）仍在 `Builds/Archive/YiboReputation/`，作为覆盖起点。本轮未生成 GitHub 源码归档。SavedVariables（Mists `YiboReputationDB`／Forever `YiboReputationForeverDB`）、`/yrp` 与页面 ID 不变。

版本位置：`YiboReputation_Mists.toc`、`Bootstrap.lua`（Mists）；`YiboReputation_Forever.toc`、`Forever/Namespace.lua`（Forever）；默认提示 `YiboReputation.toc` 无版本行。`_NonRelease/ReputationForever/Smoke.lua` 版本断言同步为 0.2.0。

## 发布内容

- Mists 主矩阵 `AccountMatrixView.lua` 与悬停关注预览 `MonitoredPreview.lua` 的堆叠行改为仅填充背景＋Core `CreatePixelBorder`，相邻行只共用一条 1 物理像素线。
- Forever `Forever/AccountPage.lua` 进度条改用 `ApplyPixelBackdrop`，填充内缩与宽度经 `SetPixelAnchor`／`GetPixelSize` 随缩放重算；表头文字改为填满容器高度，在 26/28 单位表头与 32 单位行内垂直居中。
- 最低 Core 提到 API14 / `pixel-line:1`：Mists `CoreIntegration.lua`、Forever `Forever/Bootstrap.lua` 增加能力与像素方法检查，`RegisterAddon` 声明 API14；中英文升级提示同步。不足时提示并停止，无本地回退。
- 包内变更文件（对比上一包）：Mists `AccountMatrixView.lua`、`Bootstrap.lua`、`CoreIntegration.lua`、`Locales/Interface.lua`、`MonitoredPreview.lua`、`YiboReputation.toc`；Forever `Forever/AccountPage.lua`、`Forever/Bootstrap.lua`、`Forever/Namespace.lua`、`Locales/Interface.lua`、`YiboReputation.toc`。无新增或移除文件。
- 重建修复（仅 Mists）：`YiboReputation/Bootstrap.lua:6-7` 删除文件加载时的 `YiboReputationDB = YiboReputationDB or {}`，改由 `EnsureDB()`（`:15-16`）在需要时创建；`ADDON_LOADED` 处理（`:73-80`）不再先调 `EnsureDB()`。存档只在 `CoreIntegration:Initialize` 完成客户端、Core 能力／方法、Core 已初始化及 Core 交接检查之后（`CoreIntegration.lua:88`，未改）创建或补默认值。API13 Core 下 `YiboReputationDB` 逐字节不变，缺失时不创建；初始化仍由 `initialized` 保证单次。

## 兼容性

- 需要 YiboCore API14：Mists 1.13.0 / Forever 0.3.0 / Retail 0.2.0（均已发布；本插件无 Retail 目标）。配旧 Core（API13）时提示升级并停止初始化。
- 版本选择：Mists 源码清单 `YiboReputation_Mists.toc`、Forever 源码清单 `YiboReputation_Forever.toc`，玩家包均输出为默认 `YiboReputation.toc`；包内无其它目标 TOC。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | 两目标正式构建成功：目标、Interface、版本、最低 Core API 14、引用与包内容校验通过；Mists 重建同样通过，重建后两目标 ValidateOnly 通过 |
| 包内容（实际 ZIP） | 单一顶级目录 `YiboReputation/`；仅默认 `YiboReputation.toc` + 本目标文件 + Locales + Media + 构建清单；无其它目标 TOC／目录、`_NonRelease`、测试、WTF、文档（Mists 重建包重新核对：28 文件、TOC 18 项、无未引用 Lua） |
| 覆盖更新 | Mists 1.7.4 → 1.8.0（重建包重新解包）、Forever 0.1.9 → 0.2.0：旧包解压后直接覆盖新包、保留旧文件；旧包独有残留文件 0 个，覆盖后仍只有 `YiboReputation.toc`，新包文件在覆盖目录中逐字节一致 |
| 打包回放 | `_NonRelease/YiboReputationRelease-20261122/PackagedReplay.lua` 147 项通过（旧包存档 5、初始化 72、存档 24、误装 20、API13 26）。已发布 Core 包（1.13.0／0.3.0）下按包内 TOC 顺序加载 Clean／Overlay：API14 与 `pixel-line:1`、包版本、单次注册（`RegisterAddon` 1 次，重复 ADDON_LOADED／CORE_READY／`Core:Initialize` 不再注册）、页面渲染、无错误消息；旧版存档由实际旧包在 API13 Core（1.12.14／0.2.4）下生成，新包保留并在重扫后更新，重载恢复；误装到另一客户端不创建本目标存档、不改动对方存档、不注册，只输出一条提示，且本目标真实旧存档逐字节不变；API13 Core 被拒、显示含 API14 的升级提示，Mists 不再创建 `YiboReputationDB`，两目标真实旧版存档在 API13 拒绝后逐字节不变 |
| 回归 | Reputation 迁移 Spec 95（新增 5 项：API13 下已有存档逐字节不变并提示、误装客户端存档不变且单条提示、API13 下缺失存档不创建；原“no partial initialization”断言改为拒绝后存档未创建）、Retention 39、HoverSpec、Forever 发现 Spec 通过；`_NonRelease/ReputationForever/Smoke.lua` 第 147 行为既有失败，未改 |
| 语法 | 3 个 TOC、25 个 Lua 文件通过，TOC 引用无缺失 |
| 实机 | 像素线迁移已由用户在本会话实机验证（源码联接加载）；本次启动顺序修复、Forever 表头居中修复与打包 ZIP 本身未在客户端单独安装／覆盖测试 |

TOC／运行入口记录：适用 Mists（重建）、Forever（未变）；实际加载名均为默认 `YiboReputation.toc`；误目标写库保护（Mists 包 `CLIENT_SUPPORTED`、Forever 包 `WOW_PROJECT_CAMELOT` 检查）回放通过；Core 就绪、API14 与能力检查在任何存档创建／补默认值之前，回放通过；单次初始化回放通过；存档身份不变；旧文件覆盖无残留；构建引用由统一构建器校验。

## 待办

- 上传 CurseForge（用户执行），登记文件 ID 与发布日期。上传的 Mists 文件必须是重建包（SHA256 `FC012FCE…6A24`），不要使用 `Superseded/` 中的旧包。
- 首次检查的观察项（Mists 遇 API13 Core 时先写 `YiboReputationDB.settings` 默认值）已在重建包修复。
- `Tools/ReleaseProfiles.psd1` 的 Forever `ValidationState` 仍为 0.1.9 时的文字，写入包内构建清单；由负责人统一更新。
- 已发布 Core 包内 `PackagedAddonVersions` 仍列 1.7.4／0.1.9，仅用于 Core 插件状态显示，随下次 Core 发布更新。
