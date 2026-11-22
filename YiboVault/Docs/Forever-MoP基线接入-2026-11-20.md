# Forever 对齐 MoP 仓储功能

2026-11-20 · Forever 0.6.6-api1，客户端待验

- 仓储可查看离线角色邮件和本人拍卖的历史快照，名称与物品 ID 搜索覆盖所选范围内的角色。Core 入口预览可显示多角色及物品归属。
- Core 的「物品总览」设置复用 MoP 的物品提示开关、服务器范围、按 ID 过滤及公会缓存管理。隐藏的公会可显式打开，依然排除在默认合计之外。访问过的其他公会可管理本地缓存，物品和容量只在当前身份及页签权限允许时显示。
- 容量显示已采集容器或公会页签的格数和空位。容器类型没有可靠样本时使用未知分组。当前角色仍按无限服原生入口采集，其他角色使用各自历史快照。物品目标继续通过 Core 选择与注册，缺少可选能力时提示升级。
- 公开 vault.items v1.1 扩大账号、服务器与指定角色读取范围，提供 items.personal-counts:1。无范围仍查当前角色。邮件通过 Core 发现，使用提供者快照或 Vault 自己的缓存。未采集库存保留未知，在途数量独立于已持有量。

无限服清单为 YiboVault_Forever.toc，MoP 清单为 YiboVault_Mists.toc，两个单目标包各自输出唯一 YiboVault.toc。保留各目标原有 SavedVariables 与 schema。目标身份及 Core API13、就绪与所需能力在写库前检查，Tooltip、入口、设置及索引只初始化一次。共用 Tooltip 范围、设置、容量分组与库存契约。客户端 API、扫描规则、公会权限和原生容量数据留在目标层。覆盖回放保留旧文件，新清单引用完整，无 XML 加载分支。复用 Core API13 及现有角色、设置、物品解析、服务与语言能力，库存目标额外使用可选 business-item-actions:1。

验证包括真实双端清单模拟 3157 项、16 组 Vault 专项、统一构建、解包后干净安装及保留旧文件覆盖的模拟回放，以及本地化报告。客户端待核对中英文设置、切角色后邮件与拍卖历史、Tooltip 与入口预览、公会授权页签、空银行与来源变化，并完整退出后核对存档恢复。待实机验证后再判断发布就绪。

2026-11-22 像素线宽（Core API14 / pixel-line:1，CAP-013）接入：MoP `StoragePage.lua` 角色/公会列表行（行间 2 单位间隔，不共边）与物品格（5 单位间隔）改用 Core `ApplyPixelBackdrop`，选中行强调色和悬停/品质边框继续用 `SetBackdropBorderColor`；物品图标内缩改为 `GetPixelSize`。无限服 `Forever/AccountPage.lua` 物品格（仅边框）改用 `ApplyPixelBackdrop(background=false)`。共用 `Namespace.lua` 最低 Core 提高为 API14，`Common/CoreIntegration.lua` 增加 `pixel-line:1` 及 `ApplyPixelBackdrop`／`GetPixelSize` 方法检查，两目标同时生效；`BOOT.CORE_REQUIRED` 中英文同步。Vault 自身 Items API 仍为 v1（`-api1` 不变），版本号与存档不变。离线：16 组 Vault 专项（StoragePageCreate 增加像素边框断言）、VaultForever Smoke 3158 项（含 API13 拒绝）、VaultSplit 6 组通过，双目标构建预检通过。待实机：仓库页选中行强调边框可见、物品格品质边框在非整数缩放下为单像素。同日补充：物品图标内缩改在 `CreateItemCell` 中经 Core `Theme:SetPixelAnchor` 应用，界面缩放／显示尺寸变化后由 Core 立即重新内缩、无需等页面刷新，`Common/CoreIntegration.lua` 同步检查 `UITheme.SetPixelAnchor`（两目标生效），离线回归与 Mists／Forever ValidateOnly 通过，缩放切换后图标贴边待实机。