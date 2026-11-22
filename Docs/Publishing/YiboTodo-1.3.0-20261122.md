# YiboTodo 1.3.0（Mists，API14）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标 | 文件 | 版本 | Interface | 最低 Core（构建器读取） | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- | --- |
| Mists | `Builds/YiboTodo-mists-v1.3.0-curseforge.zip` | 1.3.0 | 50504 | API14 | 1771764 | `5C235E6548121B7BFE64D3AB1C521E963C20DF025CA2517F47C47D13FE921ABC` |

源码摘要 `261713898cd369a47ef97c23a948fd71b19d7ca141193ecd1b35b64a2ad6f50b`（含 CHANGELOG 1.3.0 误装保护条目；构建后 ValidateOnly 复核一致）。未生成 GitHub 源码归档。

- 被替代的首次构建（误装保护缺失，从未上传）：SHA256 `0C3C51B2D42F5B906E7AFE36F8DD54D350DC888CB979F6245F10E78C13396D7D`、1770830 字节、源码摘要 `a501d74a…6e9b`，已移至 `_NonRelease/YiboTodoRelease-20261122/Superseded/`（同目录保存旧 Clean／Overlay 解压目录与旧回放日志 `PackagedReplay-Result-before-wrong-target-fix.txt`）。
- 上一发行版 `YiboTodo-mists-v1.2.6-curseforge.zip`（SHA256 `DDF05598FA442AA7977CDD63EF81998B2A87F7EDA2C21C44D3F2FA80E2E7579E`）位于 `Builds/Archive/YiboTodo/`，仍为覆盖起点。

## 发布内容

- 账号页数据行（`ROW_GAP = 0`）改为仅填充背景加 Core `CreatePixelBorder`，相邻行共用一条线；账号共享行只画顶边与左右边；项目图标框与当前角色可执行描边改用 `ApplyPixelBackdrop`。
- 最低 Core 提高到 API14，并检查 `pixel-line:1`、`ApplyPixelBackdrop`、`CreatePixelBorder`；`ERROR.CORE_REQUIRED` 中英文同步更新。
- 误装保护（本次修复）：`Namespace.lua` 以 `WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC` 判定实际客户端；`CoreIntegration:CheckStartup()` 在 ADDON_LOADED、`Database:Initialize()` 之前依次检查客户端身份与 Core（存在、`IsInitialized()`、API14、原有能力清单含 `pixel-line:1`、`calendar-day-query:1`）。误装时只打印静态中英文提示“请安装 YiboTodo 熊猫人之谜版本”并停止；Core 不满足时打印原有升级提示并停止；两种情况均不创建／修改 `YiboTodoDB`、不向 Core 注册。结果缓存，重复事件不重复提示；`CoreIntegration:Initialize()` 被直接调用时同样拒绝。
- 版本：TOC `## Version` 与 `Namespace.lua` `Addon.VERSION` 1.2.6 → 1.3.0（修复后保持 1.3.0）。
- 存档（`YiboTodoDB`，schema 10、catalog 16）、TOC 文件列表、任务周期与 `/ytd` 不变。

## 兼容性

- 需要 YiboCore API14：Mists 1.13.0 / Forever 0.3.0 / Retail 0.2.0（本插件只发 Mists 包，Mists 配 Core Mists 1.13.0）。
- 配旧 Core（API13）或 Core 未就绪：提示升级并停止，存档不被创建或修改。
- 误装到 Forever／Retail（含误配 Mists Core）：提示安装熊猫人之谜版本并停止，存档与 Core 注册均不受影响。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | Mists 正式构建成功：目标、Interface、版本、引用与包内容校验通过；manifest `minimumCoreAPI = 14` |
| 包内容（实际 ZIP） | 43 项，单顶级目录；只有默认 `YiboTodo.toc`；无其它目标 TOC、XML、`_NonRelease`、`Tests/`、文档、WTF；包内文件与源码逐字节一致 |
| 与被替代构建差异 | 仅 `Bootstrap.lua`、`CoreIntegration.lua`、`Namespace.lua`、manifest |
| 新旧包差异（对 1.2.6） | 变更 `AccountPage.lua`、`Bootstrap.lua`、`CoreIntegration.lua`、`Locale.lua`、`Namespace.lua`、TOC、manifest；其余 36 项不变；无新增／移除路径 |
| 覆盖更新 | 1.2.6 解压后直接覆盖新 1.3.0，保留旧文件：残留 0 个，仍只有 `YiboTodo.toc`，无 XML；覆盖目录与干净目录逐文件一致 |
| 打包回放 | `_NonRelease/YiboTodoRelease-20261122/PackagedReplay.lua`（Spec 增加误装断言），真实 Core 包 + 重建插件包按 TOC 与客户端事件顺序加载，26 次启动、**234 通过、0 失败**；修复前首次构建为 136/8（原 Spec），同一扩展 Spec 下为 156/40。日志 `PackagedReplay-Result.txt` |
| 安装／升级 | Clean／Overlay 各 41 项全部通过（新装 zhCN、上一版存档 zhCN／enUS；单次初始化与注册；重复事件与直接 `Initialize` 不重复注册；账号页渲染；存档保留；重载） |
| API13 拒绝 | Core Mists 1.12.14（API13）：不初始化、零注册、中英文升级提示（含 API v14）、存档保留；Clean／Overlay 各 13 项通过 |
| 误装目标 | Clean／Overlay 各 **63 通过、0 失败**：Forever（Core Forever 0.3.0）、Retail（Core Retail 0.2.0）、Forever 误配 Core Mists 1.13.0，各含无存档（zhCN）与上一版存档（enUS）。断言：不初始化；`RegisterAddon`／页面／入口／清理所有者均 0；`YiboTodoDB` 不创建、不修改；显示误装提示且不显示升级提示；英文提示无中文；重复 ADDON_LOADED／PLAYER_LOGIN／PLAYER_ENTERING_WORLD 加直接 `Initialize` 仍被拒绝、无新提示、无错误。原 `CharacterCleanup.lua:138` Lua 错误消失。上一版 1.2.6 对照仍为 14/4（预期，旧版无保护） |
| 源码回放 | `PackagedReplay.lua source`：117 通过、0 失败（作为误装用例的离线测试） |
| 回归 | 10 个离线测试：4 通过（ActionSelection、DarkmoonCalendar、SpecialActivity、TargetedRefresh），6 失败；输出与修复前逐字一致（5 个夹具缺 `GetAllCached`，`Model/Snapshot.lua:329`；MonitoringSettingsSmoke 夹具缺 `Addon.Core`，`Settings.lua:12`），非本次引入。这些既有测试不经过 Bootstrap，误装用例由回放覆盖 |
| 语法 | `luac -p` 源码 43 个 Lua 文件（含包内 33 个）通过 |
| 实机 | 像素线迁移已由用户在 MoP 实机验证；本次误装保护与 ADDON_LOADED 时机的 Core 检查尚无客户端证据（离线回放已覆盖） |

TOC／运行入口收尾：适用 YiboTodo／Mists；源码清单与实际加载名均为 `YiboTodo.toc`；误目标写库保护：ADDON_LOADED 中 `Database:Initialize()` 之前检查 `WOW_PROJECT_ID`，回放确认不建库、不注册；Core 就绪及版本：同一时点检查 `IsInitialized()`、API14 与能力清单，PLAYER_LOGIN 的 `Initialize` 复查；单次初始化：`initialized` 与启动检查缓存守卫，回放确认；存档身份 `YiboTodoDB` 不变；旧文件覆盖无残留；构建引用经统一构建器校验。说明：`Locale.lua` 是文件加载期执行，误装时仍会向 Core 的内存语言表登记本插件文案（不持久化、不属于插件／页面／入口注册），本次未改。已验：离线回放（干净／覆盖／API13／误装）；待验：MoP 客户端正常加载冒烟，Forever／Retail 实机误装（可选，离线已覆盖）。

## 待办

- 建议上传前：MoP 客户端装重建包（干净或覆盖 1.2.6）确认正常加载、账号页与 `/ytd` 可用、无启动提示。
- 上传 CurseForge（用户执行），须在 Core Mists 1.13.0 之后或同批。
- 离线测试夹具（`GetAllCached`、`Addon.Core`）修复另行安排。
