# YiboQuestBlocker 3.2.0（Mists，API14）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标 | 文件 | 版本 | Interface | 最低 Core（构建器读取） | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- | --- |
| Mists | `Builds/YiboQuestBlocker-mists-v3.2.0-curseforge.zip` | 3.2.0 | 50504 | API14 | 1823225 | `F2F3A1408C515DC4DB04629C094C0E5DC75F64F524D767D6722A99387F3B966B` |

源码摘要 `97e0780c4c24b7ec704c0ecae762dea58f8f5ed5eab5d7afe84229a154589312`（含 CHANGELOG 3.2.0 条目；构建后 ValidateOnly 复核一致）。上一发行版 `YiboQuestBlocker-mists-v3.1.3-curseforge.zip`（SHA256 `1507C8C3F37D6D721A00D38B1D05C66A61EC1C01B786369E7D6B739E1C514C1E`）已由统一构建器移入 `Builds/Archive/YiboQuestBlocker/`。未生成 GitHub 源码归档。

## 发布内容

- 账号页数据行改为仅填充背景加 Core `CreatePixelBorder`（首行画顶边，相邻行共用一条线）；工具栏与添加面板改用 `ApplyPixelBackdrop`，1 线宽按物理像素绘制。
- 最低 Core 提高到 API14，并检查 `pixel-line:1`、`ApplyPixelBackdrop`、`CreatePixelBorder`；不足时输出中英文升级提示并停止初始化。
- 版本：TOC `## Version` 3.1.3 → 3.2.0；`CoreIntegration.lua` 向 Core 注册的版本由遗留的 `3.1.1` 同步为 `3.2.0`。
- 规则、角色存档（`YiboQuestBlockerDB`，schema 3）与 Slash 命令 `/yqb` 不变。

## 兼容性

- 需要 YiboCore API14：Mists 1.13.0 / Forever 0.3.0 / Retail 0.2.0（本插件只发 Mists 包，Mists 配 Core Mists 1.13.0）。
- 配旧 Core（API13，如 Mists 1.12.14）会提示升级并停止，存档保留。
- 本插件仅 Mists；装到其它客户端在写库前停止（见下表）。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | Mists 正式构建成功：目标、Interface、版本、引用与包内容校验通过；manifest `minimumCoreAPI = 14` |
| 包内容（实际 ZIP） | 15 项，单顶级目录 `YiboQuestBlocker/`；只有默认 `YiboQuestBlocker.toc`；无其它目标 TOC、`_NonRelease`、测试、文档、WTF；包内文件与源码逐字节一致 |
| 新旧包差异 | 变更 `AccountPage.lua`、`CoreIntegration.lua`、`Locale.lua`、TOC、manifest；其余 10 项不变；无新增／移除路径 |
| 覆盖更新 | 3.1.3 解压后直接覆盖 3.2.0，保留旧文件：旧包独有残留 0 个，覆盖后仍只有 `YiboQuestBlocker.toc`，无 XML；覆盖目录与干净目录逐文件一致 |
| 打包回放 | `_NonRelease/YiboQuestBlockerRelease-20261122/PackagedReplay.lua`：真实 Core Mists 1.13.0 包 + 本插件包按 TOC 顺序加载（Core 文件→Core 存档→ADDON_LOADED(YiboCore)→插件文件→插件存档→ADDON_LOADED→PLAYER_LOGIN→PLAYER_ENTERING_WORLD），Clean／Overlay 各 78 项，共 **156 项通过、0 失败**（日志 `PackagedReplay-Result.txt`） |
| 安装／升级 | 新装 zhCN、上一版存档 zhCN／enUS：Core 1.13.0／API14 就绪；插件初始化；`RegisterAddon`／页面／入口各 1 次；Core 注册版本 3.2.0；重复 ADDON_LOADED／PLAYER_LOGIN／PLAYER_ENTERING_WORLD 及直接 `Initialize` 不重复注册；账号页渲染无错误；上一版存档（全局屏蔽、他角色屏蔽、等级过滤、预览列、处理模式）保留；存档副本重载后单次初始化且数据保留；无事件处理错误 |
| API13 拒绝 | 已发布 Core Mists 1.12.14（API13）包：Core 自身就绪、插件不初始化、零注册、中英文升级提示（含 API 14）、存档保留；Clean／Overlay 各 13 项通过 |
| 误装目标 | 装到 Forever（配 Core Forever 0.3.0）、Retail（配 Core Retail 0.2.0）、Forever（误配 Core Mists 包），各含无存档／有存档：均不初始化、零注册、存档未改动；Clean／Overlay 各 24 项通过。上一版 3.1.3 同场景 24 项通过 |
| 回归 | 插件无离线测试；语法检查 5 文件通过 |
| 实机 | 像素线迁移由用户在 MoP 工作树实机验证通过（与本包仅版本字符串不同）；本安装包的客户端干净安装／覆盖与完整退出恢复未单独执行 |

TOC／运行入口收尾：适用 YiboQuestBlocker／Mists；源码清单与实际加载名均为 `YiboQuestBlocker.toc`；误目标在 `Locale.lua` 加载期检查 `WOW_PROJECT_MISTS_CLASSIC`，早于业务存档初始化；Core 就绪、API14 与能力在加载期和 `CoreIntegration:Initialize` 双重检查；单次初始化由 `initialized` 守卫；存档身份 `YiboQuestBlockerDB` 不变；旧文件覆盖无残留；构建引用经统一构建器校验。回放夹具说明：`_NonRelease/BusinessReleaseHarness-20261122/Harness.lua` 在 `CoreForever/FrameFixture.lua` 基础上补 `SetParent` 及若干返回“无观测”的客户端 API 桩；任务接取／拒绝流程未在回放中以真实任务数据执行。

## 待办

- 上传 CurseForge（用户执行），登记文件 ID 与发布日期；须在 Core Mists 1.13.0 之后或同批。
- 可选：安装包客户端干净安装／覆盖与完整退出恢复（同加载字节的工作树实机证据可复用）。
