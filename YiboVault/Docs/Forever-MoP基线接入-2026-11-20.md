# Forever 对齐 MoP 仓储功能

2026-11-20 · Forever 0.6.6-api1，客户端待验

- 仓储可查看离线角色邮件和本人拍卖的历史快照，名称与物品 ID 搜索覆盖所选范围内的角色。Core 入口预览可显示多角色及物品归属。
- Core 的「物品总览」设置复用 MoP 的物品提示开关、服务器范围、按 ID 过滤及公会缓存管理。隐藏的公会可显式打开，依然排除在默认合计之外。访问过的其他公会可管理本地缓存，物品和容量只在当前身份及页签权限允许时显示。
- 容量显示已采集容器或公会页签的格数和空位。容器类型没有可靠样本时使用未知分组。当前角色仍按无限服原生入口采集，其他角色使用各自历史快照。物品目标继续通过 Core 选择与注册，缺少可选能力时提示升级。
- 公开 vault.items v1.1 扩大账号、服务器与指定角色读取范围，提供 items.personal-counts:1。无范围仍查当前角色。邮件通过 Core 发现，使用提供者快照或 Vault 自己的缓存。未采集库存保留未知，在途数量独立于已持有量。

无限服清单为 YiboVault_Forever.toc，MoP 清单为 YiboVault_Mists.toc，两个单目标包各自输出唯一 YiboVault.toc。保留各目标原有 SavedVariables 与 schema。目标身份及 Core API13、就绪与所需能力在写库前检查，Tooltip、入口、设置及索引只初始化一次。共用 Tooltip 范围、设置、容量分组与库存契约。客户端 API、扫描规则、公会权限和原生容量数据留在目标层。覆盖回放保留旧文件，新清单引用完整，无 XML 加载分支。复用 Core API13 及现有角色、设置、物品解析、服务与语言能力，库存目标额外使用可选 business-item-actions:1。

验证包括真实双端清单模拟 3157 项、16 组 Vault 专项、统一构建、解包后干净安装及保留旧文件覆盖的模拟回放，以及本地化报告。客户端待核对中英文设置、切角色后邮件与拍卖历史、Tooltip 与入口预览、公会授权页签、空银行与来源变化，并完整退出后核对存档恢复。待实机验证后再判断发布就绪。

2026-11-22 像素线宽（Core API14 / pixel-line:1，CAP-013）接入：MoP `StoragePage.lua` 角色/公会列表行（行间 2 单位间隔，不共边）与物品格（5 单位间隔）改用 Core `ApplyPixelBackdrop`，选中行强调色和悬停/品质边框继续用 `SetBackdropBorderColor`；物品图标内缩改为 `GetPixelSize`。无限服 `Forever/AccountPage.lua` 物品格（仅边框）改用 `ApplyPixelBackdrop(background=false)`。共用 `Namespace.lua` 最低 Core 提高为 API14，`Common/CoreIntegration.lua` 增加 `pixel-line:1` 及 `ApplyPixelBackdrop`／`GetPixelSize` 方法检查，两目标同时生效；`BOOT.CORE_REQUIRED` 中英文同步。Vault 自身 Items API 仍为 v1（`-api1` 不变），版本号与存档不变。离线：16 组 Vault 专项（StoragePageCreate 增加像素边框断言）、VaultForever Smoke 3158 项（含 API13 拒绝）、VaultSplit 6 组通过，双目标构建预检通过。待实机：仓库页选中行强调边框可见、物品格品质边框在非整数缩放下为单像素。同日补充：物品图标内缩改在 `CreateItemCell` 中经 Core `Theme:SetPixelAnchor` 应用，界面缩放／显示尺寸变化后由 Core 立即重新内缩、无需等页面刷新，`Common/CoreIntegration.lua` 同步检查 `UITheme.SetPixelAnchor`（两目标生效），离线回归与 Mists／Forever ValidateOnly 通过，缩放切换后图标贴边待实机。
## 2026-11-27 仓储网格与公会页签

Mists 1.4.0-api1 与 Forever 0.8.0-api1 工作树共用 `Common/StorageLayout.lua` 的网格列数、坐标、内容高度和页签布局。MoP 保持原物品格间距和可视行复用，Forever 保持原格距，各端继续按自己的主窗组织角色与货物。Forever 公会仓改为独立页签按钮，保留「全部页签」，窗口窄时按钮换行。背包和个人银行保留容器下拉。

按钮只投影原查询返回的已缓存可见页签。点选按授权快照过滤记录和容量、回到网格顶部，无原生页签切换、读取或查询。权限撤销时隐藏旧页签并回到全部授权页签；搜索和悬停隐藏主窗的页签按钮。

| 目标 | 源码 TOC | 包内加载名 | Interface | 存档 |
| --- | --- | --- | --- | --- |
| Mists | `YiboVault_Mists.toc` | `YiboVault.toc` | 50504 | `YiboVaultDB` |
| Forever | `YiboVault_Forever.toc` | `YiboVault.toc` | 16001 | `YiboVaultForeverDB` |

源码默认清单继续做缺目标提示。两端仅追加共用模块引用，复用 Core 托管页面、按钮和滚动框。现有写库前身份与 Core 就绪、API14 及 `pixel-line:1` 检查和单次初始化守卫沿用。此次无数据库结构或采集规则变化。覆盖时替换目标的默认 TOC 与活动文件，旧包的保留文件不会引入额外的加载入口。统一构建与临时包逐文件核对通过。

VaultForever 实际清单 3166 项、Vault 与 VaultSplit 规格通过，包括两端加载保护、权限、布局、刷新及存档回放。按需同步了 Vault 跨插件夹具对 Currency 重构后物品登记和主窗控件的引用。已检查工作区本地化报告。游戏内按钮换行、权限变化、双语显示、保留旧文件覆盖及完整退出恢复待验。当前版本号沿用，尚未发布。

## 2026-11-27 无限服悬停与搜索状态

Forever 0.8.0-api1 工作树的悬停来源使用页面实例中的临时选择，首次打开沿用主窗来源。悬停切换只影响预览，不写 `settings.foreverSource` 或清空主窗搜索词。

主窗搜索在当前 Core 范围内查询。左侧列出符合名称或物品 ID 条件的角色及授权公会，右侧显示所选持有者跨来源的命中。搜索使用独立的持有者选择，隐藏普通浏览的来源和容器控件。清空搜索恢复普通浏览的角色、来源和公会页签。搜索和切换只读取已有公开查询结果，公会仍依赖当前身份和页签授权，隐藏公会仍按原显隐开关处理。

Forever 实际清单模拟 3176 项通过，新增回放覆盖搜索间的悬停来源切换、切回主窗保留查询、双角色与公会分组、清空后恢复来源及选中的公会页签。Vault 与 VaultSplit 既有规格、双目标构建预检通过，游戏内交互待验。本轮复用已接入的 Core 页面、角色身份、按钮、输入框和滚动框。目标清单、所需 Core API14 与能力、写库前目标保护、单次初始化、各端 SavedVariables 及覆盖加载引用沿用。MoP 悬停继续关闭，本轮尚未发布。

## 2026-11-27 共用主窗物品格复用

Mists 1.4.0-api1 与 Forever 0.8.0-api1 工作树的仓储主窗使用 `Common/StorageLayout.lua` 的同一可见格子池。滚动和缩放时，按视口和缓冲行更新现有格子。内容变短时按新高度收敛可见范围。格子复用为其他物品或空位时，关闭原物品提示，并更新或解绑 Core 目标操作。

两端继续各自绘制物品格、计算容量和选择显示范围。MoP 保留装备槽、装等、品质边框和网格间距。Forever 保留数量、来源提示、空位组及原图标间距，原入口悬停仍使用已有列表投影。复用 Core 已接入的滚动框、物品提示与可选目标操作。

新增实际无限服清单回放覆盖 400 条物品、滚动复用、旧提示关闭、目标解绑、显示末尾空位及结果缩短，专项共 3184 项通过。Vault 与 VaultSplit 既有规格、双端语法与统一构建预检通过。实际窗口缩放、长仓储列表滚动及切换后的提示仍待游戏内复验。

源码继续通过 `YiboVault_Mists.toc` 和 `YiboVault_Forever.toc` 加载已登记的共用模块。单目标包加载 `YiboVault.toc`。目标校验、Core 就绪及 API14 和既有能力、单次注册、各端 SavedVariables、覆盖加载引用均沿用。此轮沿用版本号，尚未发布。

## 2026-11-27 共用主窗浏览与搜索

Mists 1.4.0-api1 与 Forever 0.8.0-api1 主窗共用 `Common/StorageBrowse.lua`。该模块管理浏览和搜索各自的持有者与来源选择，按物品名或 ID 搜索，并以角色 ID 或公会键归组。清空搜索恢复浏览选择。MoP 可在搜索中继续切来源与已授权公会页签，Forever 仍显示所选持有者的跨来源结果，主窗来源继续写入原有设置。Forever 悬停继续使用独立来源，MoP 的页面注册保持原有配置。

两端继续从各自的查询层取得已授权记录，权限、采集、存档及快照规则沿用。MoP 搜索名称改用 Core 公开的 `ItemResolver:GetInfo`，沿用既有 API14 和 `item-resolver:1` 门槛。两目标 TOC 各引用共用模块一次，放在主窗实现前，玩家包仍输出唯一的 `YiboVault.toc`。目标校验、Core 就绪与能力检查、写库前保护和单次初始化沿用。存档继续分别使用 `YiboVaultDB` 和 `YiboVaultForeverDB`。

Vault 16 组与 VaultSplit 5 组专项通过。MoP 新增主窗输入、名称搜索、授权公会页签和清空后恢复原角色及银行来源的回归。Forever 实际清单模拟 3184 项通过，包括分组、来源恢复、悬停隔离及公会权限。两端统一构建均通过。临时包按唯一默认 TOC 做干净解包及保留旧包文件的覆盖回放，两种环境各通过 Forever 3184 项与 MoP 45 项。两端实机主窗交互、实际覆盖安装、重载与退出恢复待验。

## 2026-11-27 入口按钮

Forever 0.8.0-api1 工作树关闭 Vault 的 Core 页面预览，与 MoP 的入口一致。Broker、小地图和内置条继续使用 Core 的入口按钮，左键打开物品总览，右键进入设置。删除 Forever 主窗代码中专供入口悬停的物品列表。物品格和原生物品 Tooltip 继续显示库存信息。既有入口渠道设置、Vault 存档和 Core API14 门槛沿用。

真实 Core／Vault 清单模拟通过 3174 项，覆盖 Broker 悬停、左键打开主窗并恢复搜索及来源、物品格 Tooltip。Vault 与 VaultSplit 专项、双端构建预检通过。当前为工作树变更，游戏内 Broker 复验待做。

## 2026-11-27 双端升版

MoP 从 1.4.0-api1 升至 1.5.0-api1，Forever 从 0.8.0-api1 升至 0.9.0-api1。运行时版本、目标 TOC 和统一构建登记已同步。源码继续使用 `YiboVault_Mists.toc` 与 `YiboVault_Forever.toc`，玩家包采用 `YiboVault.toc`。本次升版沿用目标写库前保护、Core 就绪及 API14 能力检查、单次初始化、`YiboVaultDB` 与 `YiboVaultForeverDB`，以及原有加载引用和覆盖路径。

两端统一构建预检通过，实际清单 Forever 3174 项、双端加载 116 项和 MoP 45 项通过。新版本实际安装、旧文件覆盖与退出恢复待验，本次仅更新源码版本。
