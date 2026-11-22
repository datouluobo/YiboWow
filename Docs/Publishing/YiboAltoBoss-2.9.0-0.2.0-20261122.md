# YiboAltoBoss Mists 2.9.0 / Forever 0.2.0（Core API14 像素线）发布检查记录

日期：2026-11-22。状态：**已发布**（2026-11-22 用户确认已上传发布；渠道文件 ID 未提供。下方为发布检查记录）。

## 产物

| 目标 | 文件 | 版本 | Interface | 最低 Core API（构建器读取） | 文件数 | 大小 | ZIP SHA256 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Mists | `Builds/YiboAltoBoss-mists-v2.9.0-curseforge.zip` | 2.8.7 → 2.9.0 | 50504 | 14 | 40 | 1978266 | `9F6FE871B9C25C13C8377613F11BDC60D7AACFF6F2FE20347971DFFC0999AAAE` |
| Forever | `Builds/YiboAltoBoss-forever-v0.2.0-curseforge.zip` | 0.1.0 → 0.2.0 | 16001 | 14 | 22 | 1871014 | `1116A45454AFFD570F5680D230639D2A2983BE822FC64CCF7FAE783F66AB0C8A` |

源码／构建配置摘要：`ddb03809eb9b7cd8f9e25b91c15dd359a2304f6b501e4b5510c9a36abd0e786a`（两目标同一快照，含 CHANGELOG／README 更新；构建后 ValidateOnly 复核摘要一致）。上一发行包 `YiboAltoBoss-mists-v2.8.7-curseforge.zip`（`8342BE0F8C67EB7140ABF8602422BB9CD7E600B31410B7A10B5A14C0F90611D0`）与 `YiboAltoBoss-forever-v0.1.0-curseforge.zip`（`14F4CBDDEC60DB7966C6DE06CCF18F18959E34554065B75F2A0D33DAC76A843C`）已由统一构建器移入 `Builds/Archive/YiboAltoBoss/`。本轮未生成 GitHub 源码归档。SavedVariables（Mists `YiboAltoBossDB`／Forever `YiboAltoBossForeverDB`）、`/yab` 与页面 ID 不变。

## 发布内容

- 首领矩阵行改为 Core 按边像素边框，相邻行只共用一条线；普通状态格不再画自身边框，语义边框与悬停高亮保留。
- 两端共用的 `Common/LockoutsPage.lua`：页签按钮、页签分隔线、副本锁定格改由 Core 绘制 1 物理像素线，页签衔接偏移由 `SetPixelAnchor` 随缩放重新锚定。
- Mists 最低 Core 提到 API14 / `pixel-line:1`（`Mists/CoreRequirements.lua`），Forever 同步提到 API14（`Forever/Target.lua`），中英文升级提示同步；不足时提示并停止，无本地回退。

## 兼容性

- 需要 YiboCore API14：Mists 1.13.0 / Forever 0.3.0 / Retail 0.2.0（均已发布）。配旧 Core（API13）时提示升级并在写库前停止。
- 版本选择：Mists 源码清单 `YiboAltoBoss_Mists.toc`、Forever 源码清单 `YiboAltoBoss_Forever.toc`，玩家包均输出为默认 `YiboAltoBoss.toc`。

## 检查结果

| 项 | 结果 |
| --- | --- |
| 统一构建器 | 两目标正式构建成功：目标、Interface、版本、最低 Core API 14、引用与包内容校验通过 |
| 包内容（实际 ZIP） | 单一顶级目录 `YiboAltoBoss/`；仅默认 `YiboAltoBoss.toc` + 本目标文件 + Media + 构建清单；无其它目标 TOC／目录、`_NonRelease`、测试、WTF、文档；TOC 引用全部存在 |
| 覆盖更新 | Mists 2.8.7 → 2.9.0、Forever 0.1.0 → 0.2.0：旧包解压后直接覆盖新包、保留旧文件；旧包独有残留文件 0 个，覆盖后仍只有 `YiboAltoBoss.toc`，无残留 TOC／XML |
| 打包回放 | `_NonRelease/YiboAltoBossRelease-20261122/PackagedSpec.lua` 71 项通过（Clean／Overlay × Mists／Forever 各 17 项 + 旧包生成存档 3 项）：已发布 Core 包（1.13.0／0.3.0，API14、`pixel-line:1`）下按包内 TOC 顺序加载；单次注册（RegisterAddon／入口各 1 次，重复事件不再注册）；旧版存档保留（Mists 2.8.7 设置与自定义目标、Forever 0.1.0 目标与手动标记，均由实际旧包在同一 Core 下生成）；主页面与副本页渲染、像素线刷新无错误；重载恢复；误装到另一客户端在任何写库前停止并提示；API13 Core 被拒并显示 API14 升级提示、不写库 |
| 回归 | 10 组离线测试通过（HolidayBoss 286、InstanceKills 57、LockoutProjection 21、MultiTarget 31 及 6 组性能），与改版本前一致；`MultiTargetSpec` 版本断言同步为 0.2.0 |
| 语法 | 3 个 TOC、36 文件通过 |
| 实机 | 像素线迁移已由用户在本会话实机验证（源码联接加载）；打包 ZIP 本身未在客户端单独安装／覆盖测试 |

## 待办

- 上传 CurseForge（用户执行），登记文件 ID 与发布日期。
- `Forever/Bootstrap.lua` 第 8 行 `RegisterAddon` 的 `requiredAPI` 仍为 13（实际门槛在 `Forever/Target.lua` 为 `CheckAPIVersion(14)`，构建器读取 14）；仅影响 Core 登记元数据，不影响拒绝旧 Core。下次修改 Forever 时同步为 14。
- `Tools/ReleaseProfiles.psd1` 的 `ValidationState` 仍为 2.8.7／0.1.0 时的文字，写入包内构建清单；由负责人统一更新。
- 已发布 Core 包内 `PackagedAddonVersions` 仍列 2.8.7（Mists），仅用于 Core 插件状态显示，随下次 Core 发布更新。
