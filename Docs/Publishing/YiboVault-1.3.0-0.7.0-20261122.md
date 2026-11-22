# YiboVault 1.3.0-api1 / 0.7.0-api1（Core API14）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标 | 文件 | 版本 | Interface | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- |
| Mists（重建） | `Builds/YiboVault-mists-v1.3.0-api1-curseforge.zip` | 1.3.0-api1 / Items API1 | 50504 | 1842373 | `B610259071291E097EC75634B2880F722A643663EDE0226C8CF6CE24300289BF` |
| Forever | `Builds/YiboVault-forever-v0.7.0-api1-curseforge.zip` | 0.7.0-api1 / Items API1 | 16001 | 1837049 | `7F0D40CB193CCDCF07C303039521076E796EAB5AF10F36CA40CF50D1962F72D5` |

源码／构建配置摘要：Mists 重建包 `9eee3429dfe4147d99433c74e451cc2cdfc293abad4b1d3e92faaab6baca72fd`（含修复与 CHANGELOG；重建后两目标 ValidateOnly 均通过、摘要一致）。Forever 包未重建，包内清单仍记录首次构建快照 `e2d75ce104421c28655ff8e83d34b5e24e556e8d62ae6b28f778d735c8115b33`；其后变化的 `Bootstrap.lua`、`CHANGELOG.md` 与测试均不在 `YiboVault_Forever.toc` 或 Forever 包内，Forever 运行内容不变。构建器读取的最低 Core API：**14**（两目标 `minimumCoreAPI=14`）。

重建记录：首次 Mists 包（`E8AE59CA686F11467334F0F963AD7968DDE5B073B85D60CAD7DAB9199B027C59`，1842280 字节，从未上传）已移至 `_NonRelease/VaultRelease-20261122/Superseded/`，其解包目录移至 `Superseded/Extract-r1/`；重建时 `Builds/` 无同目标旧包，构建器 `Archived=0`。旧 Mists 1.2.6-api1、Forever 0.6.5-api1 包仍在 `Builds/Archive/YiboVault/`，作为覆盖起点。重建包与被替换包相比仅 `Bootstrap.lua` 与 `YiboReleaseManifest.json` 不同，文件集相同。本轮未生成 GitHub 源码归档。SavedVariables 身份不变（Mists `YiboVaultDB`，Forever `YiboVaultForeverDB`）。

版本来源：Mists `Namespace.lua` 的 `RELEASE_VERSION` 与 `YiboVault_Mists.toc`；Forever `Forever/Target.lua` 的 `RELEASE_VERSION` 与 `YiboVault_Forever.toc`；`VERSION = RELEASE_VERSION .. "-api" .. API_VERSION`，`-api1` 后缀按原方案生成。默认提示清单 `YiboVault.toc` 不带版本。`_NonRelease/VaultForever/Smoke.lua` 的 Forever 版本断言同步为 0.7.0-api1。

Forever 覆盖起点说明：工作树此前为 0.6.6-api1，但 0.6.6 从未进入 `Builds/`（仅有 `_NonRelease/VaultForever/MistsParity-20261120/Verified` 候选包），`Builds/` 中的上一 Forever 包是 **0.6.5-api1**，故以 0.6.5 作为覆盖起点，并加测 0.6.4-api1（`Builds/Archive` 中更早的 Forever 正式构建包）。

## 发布内容

- 仓储页列表行、物品格与图标内缩改由 Core `pixel-line:1` 控制，线宽恒为 1 物理像素，缩放变化后由 `SetPixelAnchor` 即时重新内缩；布局尺寸不变（细节见 `YiboVault/Docs/Forever-MoP基线接入-2026-11-20.md` 2026-11-22 段）。
- 最低 Core 提升为 API14，新增 `pixel-line:1` 及 UITheme 像素方法检查；不足时提示升级并停止初始化。
- Forever 0.7.0 同时包含未单独打包的 0.6.6 MoP 基线接入内容。Items API 仍为 v1。
- 重建修复（Mists）：`YiboVault/Bootstrap.lua:6-8` 在客户端检查之后、`InitializeDatabase()` 之前先执行 `CheckCoreRequirements()`（Core 存在、已初始化、API14、`localization:1`／`pixel-line:1` 等能力与所需方法）；不满足时提示升级并停止，`YiboVaultDB` 保持逐字节不变（不再预补默认结构、不再把已有覆盖状态改为 `stale`）。`RegisterWithCore()` 内的复查不变，初始化仍由 `initialized` 保证单次。文件列表、版本与 SavedVariables 名不变；`Bootstrap.lua` 只在 `YiboVault_Mists.toc` 中，Forever 使用 `Forever/Bootstrap.lua`（本就先检查 Core），故 Forever 不重建。

## 兼容性

- 需要 YiboCore API14：Mists 1.13.0 / Forever 0.3.0 / Retail 0.2.0（均已发布）。配 API13 Core 时提示升级并停止。
- `vault.items` 契约 v1 不变；与新 Mail 包经 Core 契约联动在 Mail 回放中通过。
- 覆盖升级起点：Mists 1.2.6-api1；Forever 0.6.5-api1、0.6.4-api1。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | 两目标正式构建成功：目标、Interface、版本、API 后缀、引用与包内容校验通过；Mists 重建同样通过，重建后两目标 ValidateOnly 通过 |
| 包内容（实际 ZIP） | 单一顶级目录 `YiboVault/`；仅默认 `YiboVault.toc`；Mists 37 文件／TOC 25 项、Forever 36 文件／TOC 24 项，引用全部存在，无未引用 Lua；无他目标目录、`_NonRelease`、测试、文档或 WTF；文件集与包内清单一致（Mists 重建包重新核对） |
| 干净安装 | 解包 `Clean-Mists`（重建包）／`Clean-Forever`，加载已发布 Core 包：初始化一次，Core 登记版本与 requiredAPI=14，TOC 每文件恰加载一次，Core 文件无重复加载，重复 Initialize／ADDON_LOADED 不增加 Tooltip 钩子或登记，实时采集 7 件物品，他目标存档未触碰，无启动错误 |
| 覆盖更新 | 旧包解压后直接覆盖新包、保留旧文件：Mists 1.2.6→1.3.0（重建包重新解包）、Forever 0.6.5→0.7.0、0.6.4→0.7.0 旧包独有残留均为 0；覆盖后 TOC 仍只有 `YiboVault.toc`；新包文件在覆盖目录中与干净包逐字节一致 |
| 旧版存档保留 | 旧包（1.2.6／0.6.5／0.6.4）在已发布 Core 上运行并采集→修改设置→序列化重载→新包：沿用同一存档表，`tooltipRealmScope=all` 设置、角色快照保留，重新扫描前即可查询到 7 件，之后实时采集正常 |
| 误装目标 | Mists 包装到 Forever 客户端、Forever 包装到 Mists 客户端：均只提示一次“Vault 未启动，请安装对应客户端的版本”并停止，未登记 Core，本目标与对方存档均逐字节不变 |
| API13 Core | 已发布 API13 Core 包（Mists 1.12.14、Forever 0.2.4）：两目标均拒绝初始化、不登记，提示“需要对应客户端的 YiboCore，最低 API 14……请升级 Core”。哨兵存档与旧版真实存档（含 `known` 覆盖状态）在两目标均**逐字节不变**。重建前的 Mists 包在新断言下按预期失败（“saved store untouched (byte-identical)”），重建包通过 |
| 真实清单回放 | `_NonRelease/VaultForever/Smoke.lua` 在干净、覆盖（0.6.5／1.2.6）、覆盖（0.6.4／1.2.6）三套包根上各 3158 项通过（Mists 根为重建包） |
| 合计 | Vault 专项 `_NonRelease/VaultRelease-20261122/ReleaseChecks.lua` 94 项通过（API13 与误装断言改为逐字节比较）；14 个包根回放用例（含 Mail Smoke／PackageAcceptance／ReleaseChecks，Mists 侧引用重建的 Vault 包根）全部通过，记录见 `_NonRelease/VaultRelease-20261122/Replay-Transcript-rebuild.txt`（首次记录 `_NonRelease/MailRelease-20261122/Replay-Transcript.txt` 保留未改） |
| 回归 | Vault 22 组离线测试通过（`YiboVault/_NonRelease/Tests` 16 组、`_NonRelease/VaultSplit` 5 组、VaultForever Smoke 3158 项）；`_NonRelease/VaultSplit/MistsReleaseSpec.lua` 由 31 项扩为 45 项，新增 API13、缺 `pixel-line`、误装客户端三种拒绝下真实 Mists 存档逐字节不变、单条提示、不登记，以及 API13 下不创建缺失存档 |
| 语法 | 3 个 TOC、37 个 Lua 文件通过，TOC 引用无缺失 |
| 实机 | 像素线迁移已由用户实机确认；本次修复只调整启动检查顺序，未另做实机（API13 拒绝场景按离线证据登记） |

TOC／运行入口记录：适用 Mists（重建）、Forever（未变）；实际加载名均为默认 `YiboVault.toc`；误目标写库保护：Mists `CLIENT_SUPPORTED`、Forever `WOW_PROJECT_CAMELOT` 检查，均在写库前停止；Core 就绪、API14 与能力检查现两目标均在存档初始化之前；单次初始化回放通过；存档身份不变；旧文件覆盖无残留；构建引用由统一构建器校验。

## 待办

- 上传 CurseForge（用户执行），登记文件 ID 与发布日期。上传的 Mists 文件必须是重建包（SHA256 `B6102590…89BF`），不要使用 `Superseded/` 中的旧包。
- 构建清单中的 `validationState` 仍为配置文件旧值（Forever `forever-0.6.6-api1-mists-parity-client-pending-20261120`，Mists `mists-1.2.4-manual-install-client-accepted`），`Tools/ReleaseProfiles.psd1` 未在本次修改。
- 0.6.6 MoP 基线接入在台账中登记的 Forever 实机待验项（切角色后邮件与拍卖历史、公会授权页签、完整退出恢复等）仍按原记录保持。
- 离线回放不替代 CurseForge 客户端更新工具的覆盖行为验证。
