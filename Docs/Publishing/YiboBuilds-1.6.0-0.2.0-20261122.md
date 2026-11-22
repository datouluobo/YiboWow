# YiboBuilds Mists 1.6.0 / Forever 0.2.0（Core API14 像素线）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标 | 文件 | 版本 | Interface | 最低 Core API（构建器读取） | 文件数 | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Mists（重建） | `Builds/YiboBuilds-mists-v1.6.0-curseforge.zip` | 1.5.4 → 1.6.0 | 50504 | 14 | 31 | 1877088 | `3C014FAFFEFCA24C5DC15C71D32ED315100AEB0303E06A6834786F702A626229` |
| Forever | `Builds/YiboBuilds-forever-v0.2.0-curseforge.zip` | 0.1.20 → 0.2.0 | 16001 | 14 | 20 | 1751953 | `FA144443CFA9A6786B2B74EA0F3B3F57C6CEB20AF831ABB09F02E9CC743B7401` |

源码／构建配置摘要：Mists 重建包 `08bbcac71428ee303aa4649bf818eff391fc8af735635b487ba1e4b2f6992bf7`（含修复、CHANGELOG 与新测试；重建后两目标 ValidateOnly 通过、摘要一致）。Forever 包未重建，包内清单仍记录首次快照 `da4f4068794e3c2ae1e5feec7b8a8f738e9f04584f27c40d38e6ea1139f1c90d`；其后变化的 `Bootstrap.lua`、`CoreIntegration.lua`、`CHANGELOG.md` 与测试均不在 `YiboBuilds_Forever.toc` 或 Forever 包内。首次 Mists 包（`0D579470E6C2E9789EE958D947D66C452E624793572E0CF7AC1C2EABDB3955B2`，1876664 字节，从未上传）已移至 `_NonRelease/YiboBuildsRelease-20261122/Superseded/`，旧解包目录在 `Superseded/Extract-r1/`；重建时构建器 `Archived=0`。重建包与被替换包相比仅 `Bootstrap.lua`、`CoreIntegration.lua`、`YiboReleaseManifest.json` 不同，文件集相同。上一发行包 `YiboBuilds-mists-v1.5.4-curseforge.zip`（`CE7BA996F4233236BD86CE93809255B9AF6FB6AE54A8E17EE9D13BED336B42C5`）与 `YiboBuilds-forever-v0.1.20-curseforge.zip`（`86B32EAE79C0803593AF31B48052875074F6AB14715AB898F380A046A7452C5F`）仍在 `Builds/Archive/YiboBuilds/`，作为覆盖起点。本轮未生成 GitHub 源码归档。SavedVariables（Mists `YiboBuildsDB`／Forever `YiboBuildsForeverDB`）与 `/ybb` 不变。

## 发布内容

- Mists：角色列表、主面板、装备详情、专精图标、悬停装备矩阵及提示框改用 Core 像素边框；天赋／雕文行底线改 `ApplyPixelRule`；装备与宝石图标框改 Core `CreatePixelBorder`（颜色仍随品质／孔色）。
- Forever：悬停装备格与天赋树格改用 Core 像素边框，天赋点数角标内缩经 `SetPixelAnchor` 随缩放重新锚定。
- 两端最低 Core 提到 API14 / `pixel-line:1`（Mists `Bootstrap.lua`，Forever `Forever/Bootstrap.lua`），中英文升级提示同步；不足时提示并停止，无本地回退。
- 重建修复（仅 Mists）：
  - `YiboBuilds/Bootstrap.lua:139-142`：`ADDON_LOADED` 不再调用 `EnsureDB()`；`YiboBuilds/CoreIntegration.lua:11-12`：`EnsureDB()` 移到 `HasCompatibleCore()`（客户端、Core 已初始化、API14、全部所需能力与方法）通过之后。旧 Core 下 `YiboBuildsDB` 逐字节不变（含不存在时不创建）；通过时照旧补齐默认值，`initialized` 保证单次。
  - `YiboBuilds/Bootstrap.lua:35-45`：Mists 包误装到无限服客户端时，在任何框架、Core 查询或存档访问前输出一条按客户端语言选择的中／英文提示（“这是熊猫人之谜版本……请安装与当前客户端对应的 YiboBuilds 版本”），参照 AltoBoss `Common/Startup.lua` 的 WRONG_MISTS 写法；此时 Core 语言服务不可依赖，故按 `GetLocale()` 选择文本。
  - 文件列表、版本、SavedVariables 名不变；改动文件均只在 `YiboBuilds_Mists.toc` 中，Forever 不重建。

## 兼容性

- 需要 YiboCore API14：Mists 1.13.0 / Forever 0.3.0 / Retail 0.2.0（均已发布）。配旧 Core（API13）时提示升级并停止初始化。
- 版本选择：Mists 源码清单 `YiboBuilds_Mists.toc`、Forever 源码清单 `YiboBuilds_Forever.toc`，玩家包均输出为默认 `YiboBuilds.toc`。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | 两目标正式构建成功：目标、Interface、版本、最低 Core API 14、引用与包内容校验通过；Mists 重建同样通过，重建后两目标 ValidateOnly 通过 |
| 包内容（实际 ZIP） | 单一顶级目录 `YiboBuilds/`；仅默认 `YiboBuilds.toc` + 本目标文件 + Media + 构建清单；无其它目标 TOC／目录、`_NonRelease`、测试、WTF、文档；TOC 引用全部存在（Mists 重建包重新核对：31 文件、TOC 20 项、无未引用 Lua） |
| 覆盖更新 | Mists 1.5.4 → 1.6.0（重建包重新解包）、Forever 0.1.20 → 0.2.0：旧包解压后直接覆盖新包、保留旧文件；旧包独有残留文件 0 个，覆盖后仍只有 `YiboBuilds.toc`，新包文件在覆盖目录中逐字节一致 |
| 打包回放 | `_NonRelease/YiboBuildsRelease-20261122/PackagedSpec.lua` 77 项通过（旧包生成存档 3 项；Mists Clean／Overlay 各 19 项，Forever Clean／Overlay 各 18 项）：已发布 Core 包（1.13.0／0.3.0，API14、`pixel-line:1`）下按包内 TOC 顺序加载；单次注册（RegisterAddon／页面／入口各 1 次，重复事件与重复 Initialize 不再注册）；旧版存档保留（Mists 1.5.4 设置、Forever 0.1.20 装备快照，均由实际旧包在同一 Core 下生成）；构筑页渲染与像素线刷新无错误；重载恢复；误装到另一客户端不写任何存档且**两包都只输出一条提示**（Mists 包：“这是熊猫人之谜版本……请安装与当前客户端对应的 YiboBuilds 版本”；Forever 包：“此装备清单需要无限服客户端”），Mists 包误装时真实旧存档逐字节不变；API13 Core 被拒并显示 API14 升级提示，哨兵存档与本目标真实旧版存档**逐字节不变**（Mists 不再补默认值） |
| 回归 | Core13Spec 1065、GemCandidates 228、SocketOrder 58、EquipmentAugment 通过；新增 `YiboBuilds/_NonRelease/Tests/StoreGuardSpec.lua` 20 项通过（按真实 `YiboBuilds_Mists.toc` 顺序加载：API13 下已有／缺失存档逐字节不变并提示升级；兼容 Core 下 ADDON_LOADED 不写库、PLAYER_LOGIN 单次初始化并补默认值；误装 Forever 时中／英文各一条提示、无框架、无 Core 查询、存档不变）。`MistsTargetGuardSpec.lua` 第 15 行（读取默认提示 TOC 后断言 1.5.1）与 `_NonRelease/BuildsForever/Smoke.lua` 第 148 行为既有失败，失败点不变，未修改 |
| 语法 | 3 个 TOC、30 个 Lua 文件通过，TOC 引用无缺失 |
| 实机 | 像素线迁移已由用户在本会话实机验证（源码联接加载）；本次修复（启动顺序与误装提示）与打包 ZIP 本身未在客户端单独安装／覆盖测试，误装提示文本按离线证据登记 |

TOC／运行入口记录：适用 Mists（重建）、Forever（未变）；实际加载名均为默认 `YiboBuilds.toc`；误目标写库保护：Mists 包在 `Bootstrap.lua` 文件级检查 `WOW_PROJECT_CAMELOT` 后提示并停止，Forever 包检查无限服身份；Core 就绪、API14 与能力检查在写库之前（Mists 现已不在 ADDON_LOADED 预写）；单次初始化回放通过；存档身份不变；旧文件覆盖无残留；构建引用由统一构建器校验。

### 首次检查发现的既有行为（已在重建包修复）

- Mists 包误装到 Forever：原先在任何存档写入与 Core 查询前停止但无提示 → 现输出一条中／英文安装提示。
- Mists 在旧 Core（API13）下：原先 `ADDON_LOADED` 时 `EnsureDB` 已给 `YiboBuildsDB` 补默认结构 → 现存档逐字节不变。证据：重建前包的 `_NonRelease/YiboBuildsRelease-20261122/PreexistingProbe.lua`，重建后见上方回放。

## 待办

- 上传 CurseForge（用户执行），登记文件 ID 与发布日期。上传的 Mists 文件必须是重建包（SHA256 `3C014FAF…6229`），不要使用 `Superseded/` 中的旧包。
- 修复 `MistsTargetGuardSpec` 与 `Smoke.lua` 的默认提示清单用例（既有失败，本次未改；StoreGuardSpec 已按目标清单覆盖误装场景）。
- `Tools/ReleaseProfiles.psd1` 的 `ValidationState` 仍为旧版本文字（Forever `forever-0.1.20-...`），写入包内构建清单；由负责人统一更新。
- 已发布 Core 包内 `PackagedAddonVersions` 仍列 1.5.4／0.1.20，仅用于 Core 插件状态显示，随下次 Core 发布更新。
