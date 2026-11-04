# Mists 保护拦截与手动开启

日期：2026-11-04。范围：YiboAutoOpen 1.2.5 的物品使用结果与队列隔离职责；代码完成，离线验证通过，客户端复验待完成，未判定可发布。

## 行为与归因

用户报告裂纹的蚌壳（24476）加入目录后触发 ADDON_ACTION_FORBIDDEN，调用栈为 Queue:ProcessNext → BagAdapter:UseItem → UseContainerItem；移出目录后不再报错。该证据只说明这条使用路径被拦截，不推定所有容器或其它目标存在相同行为。

队列只在本次 UseItem 调用期间接受本插件名的保护事件，兼容 UNKNOWN() 函数名。事件仅标记当前 pending，接口返回后结束操作、解除绑定确认候选、使旧操作令牌失效，并按物品 ID 设置 protected-action 隔离，继续扫描其它候选。接口同时抛出 Lua 错误时仍走此路径；普通失败沿用原有重试规则。

隔离无自动解除定时器，普通背包、世界恢复和新物品事件均保留。明确手动重试、重新加入目录可解除；重载／重新登录会重建运行内存，因此可能再次遇到首次拦截。首次暴雪警告不被隐藏。手动提示沿用通知模式设置，静默模式仍不打印。

事件同步语义与参数核对来源：[暴雪生成的 RestrictedActions API 文档镜像](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)。实现不按物品 ID 硬编码客户端许可，也不把其它插件的拦截或后续 UI 操作误归因给正在等待结果的物品。

## 加载与公共能力审查

- 适用目标仅为已登记 Mists；源码清单及玩家实际加载名均为 YiboAutoOpen.toc，Interface 50504。未新增目标或修改 TOC、初始化与数据库入口。新增事件复用原有逐项受保护注册循环，无第二个事件帧。
- 本轮单元为通用保护结果归因与隔离策略，无目标专用 API 或静态目录变化，保持共享队列位置；未扩展 Forever 兼容声明。误目标写库保护属于未触及的既有初始化职责，本轮不作为已通过项目。
- Core 仍为可选增强；既有设置检查 API13、localization:1 与所需 UI 方法。本轮新增 QUEUE.MANUAL_REQUIRED 中英文资源，复用 Addon:T；Core 可用时走 owner Locale:Get，独立运行使用已有资源机制。未新增 Core 服务、身份、UI 或业务数据调用。CAP-009 登记本次文案变化，其它能力无接入变化。
- 技术名、安装目录、YiboAutoOpenDB 身份和 schema 保持；隔离不写入 SavedVariables。加载路径和旧文件引用保持，因此无新增覆盖路径冲突；旧文件覆盖、设置恢复和实际事件单次投递尚未作为本轮实机通过。
- 统一构建器 ValidateOnly 核验 Mists、Interface、版本、加载引用、Lua 语法及目标包计划通过；未生成或发布新安装包，未以离线结果替代实际包安装验收。

## 验证

- `lua YiboAutoOpen/_NonRelease/Tests/TestRunner.lua`：17 组通过。新增 ProtectedActionSpec 覆盖 FORBIDDEN/BLOCKED、调用同时异常、UNKNOWN()、其它插件事件排除、调用返回后的事件排除、隔离保留、其它物品继续、单次通知、明确人工解除、普通失败保持重试和中英文资源。
- `Tools/Build-ReleasePackages.ps1 -Addon YiboAutoOpen -Target Mists -ValidateOnly`：通过，版本 1.2.4。
- `python Tools/Check-Localization.py --output _NonRelease/Localization/Workspace-Report.md`：已生成并查看。工作区仍有既存本地化债务；AutoOpen 105 个硬编码候选，不宣称全插件语言验收通过。新增资源中英文均使用一个 %d，并由测试验证格式化。
- 待实机：重新加入 24476，首次拦截后仅提示一次手动开启，等待超过 15 秒并触发背包更新／切图均不重试；同时其它已验证容器继续处理。检查手动开启、Core 可选模式和中英文／手动语言模式提示。重载后按新会话重新检测。

## 24476 使用机制调查（2026-11-04）

直接读取 Wowhead 原站 tooltip 数据：

- [MoP 24476](https://nether.wowhead.com/mop-classic/tooltip/item/24476) 的使用效果链接为 `/mop-classic/spell=58160/jaggal-clam`；[该法术](https://nether.wowhead.com/mop-classic/tooltip/spell/58160) 标为 Item Effect、Instant。
- [TBC 24476](https://nether.wowhead.com/tbc/tooltip/item/24476) 无使用法术链接，显示 Right Click to Open。两目标的数据形态不同，不把 TBC 自动开蚌插件声明外推到 MoP。
- [MoP 52340](https://nether.wowhead.com/mop-classic/tooltip/item/52340) 则关联使用法术 73500，与仓库现有手动专用物品的机制一致；相同数据形态本身不能单独证明保护权限，24476 的拒绝结论仍以用户当前客户端调用栈为直接证据。

核对暴雪 UI 源码镜像：[SecureTemplates.lua](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua) 的 SECURE_ACTIONS.item 解析物品后调用 SecureCmdUseItem；[ChatFrameUtil.lua](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua) 的该函数按参数转发至 C_Container.UseContainerItem、UseInventoryItem 或 C_Item.UseItemByName。因此使用安全按钮／宏的重点在玩家触发的安全执行链，而非另一个开蚌 API。YAO 当前已优先使用 C_Container.UseContainerItem，换成命名空间形式不是新增方案。

调查结论：结合 24476 的物品法术数据、用户客户端实际保护拒绝及公开安全入口，未找到可让 YAO 在无人点击的定时队列中自动开启该物品的可行公开调用方式。不增加未经验证的 UseItemByName／施法／宏回退。玩家主动点击的安全物品按钮或 `/use item:24476` 宏是可验证的半自动方向，本轮未实现、未在客户端验证，也不声明一次点击后可自动连续开启。

以上是在线数据和源码审查；未操作游戏、未测试替代调用。当前客户端构建 70631 的具体许可仍以实机结果为准，公开分支和其它客户端成功记录不替代本构建验收。此次仅补充调查文档，运行代码、清单、Core 接入和存档身份均无变化。

## 24476 手动专用与添加拦截（2026-11-04）

按用户确认，将 24476 标为手动专用并禁止进入目录。Catalog 维护手动标记与目录排除策略；Database:AddItem 在写入、重置运行状态或入队前返回 manual_only，命令及设置输入／拖放共同消费此结果，使用 CATALOG.MANUAL_ONLY_REJECTED 中英文提示。原有 52340 的目录行为保持。

旧档加载时，Normalize 从 catalog.order 和重建的 entries 中移除 24476，保留其它项目与顺序；该清理可重复执行。此业务目录变更不更换 SavedVariables 身份、不重置设置、不删除背包物品。BagAdapter 原有手动专用过滤作为第二道保护，即使内存存在陈旧条目，也不会尝试使用。

本轮职责为 Mists 手动物品目录策略与添加反馈；无新加载链、目标或客户端 API，保持当前单目标 Catalog 与共享数据库位置。源码／玩家加载清单仍为 YiboAutoOpen.toc，Interface 50504；初始化、误目标保护、事件帧与单次注册边界无新增变更。Core 仍可选，API13／localization:1 检查及已有 Addon:T owner 语言契约保持；CAP-009 补充本次资源变化。新旧代码引用保持，无新增旧文件覆盖冲突，覆盖安装及客户端实际表现仍待复验。

离线回归覆盖：真实 Catalog 标记、旧档重复条目清理和幂等性、数据库拒绝且不写入、命令即时提示、其它目录保留，以及陈旧目录也不进入自动候选。统一构建校验通过。本轮候选报告已重新生成并查看，新增中英文均使用一个 %s。离线验证不等于客户端验收；待实机通过命令、输入／链接和拖放添加 24476，核对即时手动提示、列表无该物品、手动“重新尝试”后也不使用；旧档重载后检查条目清理、其它目录与设置保留、中英文及 Core 手动语言模式。代码完成，未判定可发布。

本地化候选报告复核：9 个 unknownKeys 均属于 AutoOpen 的 Addon:T owner 键；其中本轮新增的 2 处引用共享 CATALOG.MANUAL_ONLY_REJECTED，该键已在 Locale.lua 的 zh/en 中注册并通过实际格式化测试。报告的提取器未识别现有 FALLBACK 表注册结构；本轮不修改检查工具，106 个硬编码候选不作为语言完成证明。

1.2.5 交付检查（2026-11-04）：Bootstrap、TOC 与中英文 README 版号已统一更新，更新日志记录两项修复。17 组 Lua 回归及 Mists 统一构建 ValidateOnly 通过。本次按用户请求生成本地 Mists 安装包并提交推送；渠道上传未包含在请求内，客户端、语言模式与存档恢复待验项继续保留。
