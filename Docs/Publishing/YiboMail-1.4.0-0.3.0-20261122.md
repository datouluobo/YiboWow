# YiboMail 1.4.0-api1 / 0.3.0-api1（Core API14）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标 | 文件 | 版本 | Interface | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- |
| Mists | `Builds/YiboMail-mists-v1.4.0-api1-curseforge.zip` | 1.4.0-api1 / Public API1 | 50504 | 1662331 | `C1F80C90995BBDA61414496342252B2067ED614CCADDB2B2916F4E3BA7BF6B66` |
| Forever | `Builds/YiboMail-forever-v0.3.0-api1-curseforge.zip` | 0.3.0-api1 / Public API1 | 16001 | 1661353 | `386A65BD75D08B434D5181005A2ECA9C717A546D948E268AF901B4CC5C4E2F27` |

源码／构建配置摘要：`c3cdb22485cba94ef5df5f9f1d689d24341c0704b8a1c0fe6f855eb5bb0664bf`（两目标同一快照，含本次 CHANGELOG；构建后 ValidateOnly 复核摘要不变）。构建器读取的最低 Core API：**14**（两目标 `minimumCoreAPI=14`）。旧 Mists 1.3.5-api1、Forever 0.2.0-api1 包已由统一构建器移入 `Builds/Archive/YiboMail/`。本轮未生成 GitHub 源码归档。SavedVariables 身份不变（Mists `YiboMailDB`，Forever `YiboMailForeverDB`）。

版本来源：Mists `Namespace.lua` 与 `YiboMail_Mists.toc`；Forever `Forever/Target.lua` 与 `YiboMail_Forever.toc`；默认提示清单 `YiboMail.toc` 不带版本。`-api1` 后缀为源码版本字符串的一部分，未改变。`_NonRelease/MailForever/Smoke.lua` 的 Forever 版本断言同步为 0.3.0-api1。

## 发布内容

- Mail 自建线框改由 Core `pixel-line:1` 控制，线宽恒为 1 物理像素，布局尺寸不变；原生收件列表行只保留一条底线；图标内缩经 `SetPixelAnchor` 随缩放即时重新对齐（细节见 `YiboMail/Docs/Forever-整体适配方案-2026-11-17.md` 2026-11-21／22 段）。
- 最低 Core 提升为 API14，新增 `pixel-line:1` 及 UITheme 像素方法检查；不足时提示升级并在写库前停止。
- Forever 0.3.0 同时包含未上传渠道的 0.2.0 开发周期内容（共享邮件工作区、收取／退信／空信清理、联系人、规则寄、在途、货币附件等）。

## 兼容性

- 需要 YiboCore API14：Mists 1.13.0 / Forever 0.3.0 / Retail 0.2.0（均已发布）。配 API13 Core 时提示升级并停止，不创建或修改存档。
- 对外 `mail.items` 契约主版本 1 不变；Vault 新包经 Core 契约联动回放通过。
- 覆盖升级起点：Mists 1.3.5-api1（上一发行）、1.3.4-api1；Forever 0.2.0-api1（`Builds/` 中的上一包，未确认上传渠道）、0.1.5-api1（最后确认发布的 Forever 版本）。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | 两目标正式构建成功：目标、Interface、版本、API 后缀、引用与包内容校验通过 |
| 包内容（实际 ZIP） | 单一顶级目录 `YiboMail/`；仅默认 `YiboMail.toc`；Mists 53 文件／TOC 43 项、Forever 52 文件／TOC 42 项，引用全部存在，无未引用 Lua；无他目标目录、`_NonRelease`、测试、文档或 WTF；文件集与包内清单一致（`_NonRelease/MailRelease-20261122/CheckPackages.ps1`） |
| 干净安装 | 解包 `Clean-Mists`／`Clean-Forever`，加载已发布 Core 包（`Core-<Target>`）：初始化一次，Core 登记版本与 requiredAPI=14，TOC 每文件恰加载一次，Core 文件无重复加载，重复 Initialize／ADDON_LOADED 不重复订阅或登记，他目标存档未触碰，无启动错误 |
| 覆盖更新 | 旧包解压后直接覆盖新包、保留旧文件。Mists 1.3.5→1.4.0、1.3.4→1.4.0：旧包独有残留 6 个（`Bootstrap.lua`、`Mists/InboxUI.lua`、`Mists/Queue.lua`、`Mists/Returns.lua`、`Mists/ReturnUI.lua`、`Mists/TransferMigration.lua`），均不被新 TOC 引用、未执行，覆盖后 TOC 仍只有 `YiboMail.toc`。Forever 0.2.0→0.3.0 残留 0；0.1.5→0.3.0 残留 2（`Forever/AccountPage.lua`、`Forever/Bootstrap.lua`），未执行。新包文件在覆盖目录中与干净包逐字节一致 |
| 旧版存档保留 | `PackageAcceptance.lua`（Core 重定向到已发布包）4 个覆盖用例：旧包运行并写入存档→序列化重载→新包读取，旧设置（historyDays=45）与附件快照保留且标为 stale，实时扫描、幂等、与新 Vault 包联动通过；另 2 个干净用例通过 |
| 误装目标 | Mists 包装到 Forever 客户端、Forever 包装到 Mists 客户端：均提示安装对应客户端版本并停止，未登记 Core，未创建或修改任一存档 |
| API13 Core | 已发布 API13 Core 包（Mists 1.12.14、Forever 0.2.4）加载新包：均拒绝初始化，提示“请升级 YiboCore：Mail 需要 API14、pixel-line:1……”，未登记，存档表保持原样 |
| 真实清单回放 | `_NonRelease/MailForever/Smoke.lua` 在干净、覆盖（上一包）、覆盖（更早起点）三套包根上各 135 项通过（含误装、未来 schema、外来存档范围、能力缺失、提示清单） |
| 合计 | 回放 14 个用例全部通过（含 Vault 用例），见 `_NonRelease/MailRelease-20261122/Replay-Transcript.txt`；Mail 专项 `ReleaseChecks.lua` 124 项 |
| 回归 | 版本号变更后 Mail 38 组离线测试通过（`YiboMail/_NonRelease/Tests` 19 组、`_NonRelease/MailForever` 18 组 Spec、Smoke 135 项），与变更前一致 |
| 语法 | 3 个 TOC、48 文件通过 |
| 实机 | 像素线迁移已由用户实机确认（Core 记录所述三端验证）；本次版本号变更未改运行逻辑，未另做实机 |

脚本与解包目录：`_NonRelease/MailRelease-20261122/`（`Extract.ps1`、`CheckPackages.ps1`、`Redirect.lua`、`RunOnPackages.lua`、`ReleaseChecks.lua`、`RunReplays.ps1`）。本机无 Python，原 `RunPackageAcceptance.py` 未运行，改由 PowerShell 解包加 Lua 直接调用 `PackageAcceptance.lua`。

## 待办

- 上传 CurseForge（用户执行），登记文件 ID 与发布日期。
- 构建清单中的 `validationState` 仍为配置文件旧值（Forever `forever-0.2.0-api1-mail-parity-client-pending-20261119`），`Tools/ReleaseProfiles.psd1` 未在本次修改，由负责人决定是否更新。
- 0.2.0 周期台账中登记的 Forever 实机待验项（实际投递、完整退出恢复等）仍按原记录保持，本次离线回放不改写其状态。
- 离线回放不替代 CurseForge 客户端更新工具的覆盖行为验证。
