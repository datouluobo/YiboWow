# Forever 当前角色可查看公会银行最小适配

日期：2026-10-19。状态：**代码与双端模拟通过，待实机验证**。用户当前无法测试；角色银行、邮件附件、拍卖行及本轮公会银行均保持**待实机验证**，不要求立即验收。

## 版本与最小边界

- Forever：`YiboVault_Forever.toc`、Interface16001、**0.5.0-api1**，新增 `Forever/GuildBank.lua`。继续使用 `YiboVaultForeverDB`、schema1，没有导入MoP数据或将共享银行复制成个人库存。
- Mists：**1.2.3-api1**、Interface50504、`YiboVaultDB`、原GuildBank采集器／公会身份／账号查询与仓储页保留。本轮共享Items仅增加目标私有策略接入点；MoP没有对应方法，沿用原分支。
- 当前角色在原生公会银行中有查看权限的页签，跟随原生当前页逐页采集。未查看、有权限但未加载、无权限的页签不算空页，不宣称完整公会库存。
- 无存取、自动整理、购买页签、修改权限／名称、收支日志、资金采集或其它公会操作。查询只调用当前已选且有查看权限页签的 `QueryGuildBankTab`，不调用SetCurrentGuildBankTab或自动翻原生页。

## 原生依据与稳定身份

接口形状参考[暴雪Forever公会银行UI源码镜像](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua)、[公会银行事件文档](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildBankDocumentation.lua)和[Club API文档](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ClubDocumentation.lua)。UI使用旧式GetGuildBankTabInfo、GetGuildBankItemInfo／Link、GetCurrentGuildBankTab、QueryGuildBankTab。当前分支槽位上限98为UI局部常量，本轮在Forever目标配置显式记录 `guildBankSlots=98`，属于来源明确的待实测目标参数，不称为本机原生常量，也不复用MoP回退编号。

公会身份取 `C_Club.GetGuildClubId()`，角色取Core公开当前GUID。缓存键为 `Forever:club:<ClubId>:viewer:<GUID>`，即每个公会的访问者快照；同公会不同角色不合并权限视图。公会名称／服务器仅显示，不用于键，不从Core旧guild字段或名称推断身份。Club API未初始化、缺失、返回无效ID时显示“公会标识尚未就绪”，不选择名称相同的历史缓存。IsInGuild为false时显示未加入公会。

当前分支镜像不等于本机build70374实测；ClubId可用性、98槽、事件与权限返回形状都待首次原生公会银行验证。不能据接口存在或模拟通过宣称客户端兼容验收完成。

## 权限、就绪与逐页提交

1. 仅在世界内、收到GUILDBANKFRAME_OPENED，且存在的GuildBankFrame可见时请求／读取。打开后延迟请求当前页，关闭／离开世界取消后续访问。
2. 枚举GetNumGuildBankTabs并读取每页GetGuildBankTabInfo的查看权限；只有明确true的页进入观察范围。零个页或权限未知保留待采，不写空数据。每页仍使用原生页号，不用显示名称关联。
3. 请求只发给GetCurrentGuildBankTab所指、有查看权限的一页。GUILDBANKBAGSLOTS_CHANGED不携带页号：若当前页与请求页不同，先建立该页请求，等待后续更新；不把旧请求的更新按FIFO归给其它页，也不把未访问页标完成。
4. 每批对同页全部98槽读取两次，校验物品链接中的itemID、正整数数量、占用状态和两次内容一致。已占用但链接／数量未就绪、受限值或API失败时整页不提交，保留旧快照；不部分替换同页。
5. 提交前复核当前公会／访问角色、原生当前页、查看权限、银行仍可见。成功后只替换该页，记录该角色与对应公会范围；其它有权限但未采页仍未知。
6. 页签更新事件无法证明整页零值已就绪。本阶段对整页空响应采取保守边界：保持旧记录／待采，玩家在原生页加载后手动刷新，并收到对应更新后，才确认known-empty。取走最后一件物品也可能需要手动确认空页，不能把延时当作完成证明。
7. GUILDBANK_UPDATE_TABS／GUILD_ROSTER_UPDATE重新核对权限。同页元数据更新不会重复查询形成事件循环；原生切换到另一可查看页后再请求。权限被撤销的旧页数据保留在库中但从公开查询和页面立即隐藏，includeHiddenGuilds不能绕过权限过滤。

观察范围是最近核对的权限与快照。关闭后不能确认后台权限变化，历史已允许内容标记过期；再次打开核对权限后才更新，不能将旧快照当作当前授权或新鲜库存。PLAYER_GUILD_UPDATE、换公会、退会或稳定ID不可用时，不沿名称／角色历史关联旧公会。

## 保存与契约

公会银行物品由Vault唯一拥有，仍使用现有Store的byGuild／tabs／coverage结构，增加访问角色和最近viewableTabs／viewableCount元数据。记录为 `source=guild-bank, sourceClass=physical`，含guildKey／guildName、visitorCharacterID、页号／槽号、itemID／链接／数量与原观察时间。它表示共享银行物品，不是该角色背包或个人可取数量；不保存取件权限、限额或业务可用量结论。

沿用API1、`vault.items`、provider `YiboVault:inventory`、major1/minor1，新增可发现的 `source.guild-bank:1`。Query仍仅准入Core当前GUID，公会选择也限当前稳定公会＋该访问者范围；显式其它guildKey返回scope-not-supported，不再走旧名称匹配／历史访问者回退。返回records／coverage／revision副本；无覆盖的零总数不代表空公会银行，未查看页必须视为未知。对本目标，includeHiddenGuilds只保留既有隐藏设置语义，不能越过成员身份、访问者或页权限边界。

同页错误保留旧数据并标记error，includeStale=false排除失败／过期页；成功完整读取恢复该页。关闭、离开世界和重载后保留旧快照、原观察时间，标记过期；重新访问逐页恢复。权限变化即使旧页已过期，也发出既有变更通知并更新revision，供消费者失效缓存。

Core角色清理所有者继续复用：Inspect包含该访问者的公会缓存，用户通过Core既有确认流程删除角色缓存时，清理该GUID关联的公会观察快照，不清理其它访问者。没有新增独立破坏性按钮。原生存档文件仍为无限客户端 `WTF/Account/<账号>/SavedVariables/YiboVault.lua`，表名YiboVaultForeverDB；不向WTF写入模拟数据。

## 页面与公共能力复核

同一vault-items页新增“公会银行”页签，展示当前允许观察范围的物品、原生公会页／槽、数量。未入会、稳定身份未就绪、无查看权限、未采集、等待当前页、部分可查看页完成、错误、过期及已确认空分别显示。全部当前可查看页有完成覆盖后才可显示完整采集状态；未访问页不被默认为空。原生页切换负责选择采集对象，插件页不另建翻页操作。

主表与Core悬停复用同一权限过滤、查询、角色准入和状态；只有公会来源快照时也可准入当前访问角色。通用字段、入口、角色隐藏／排序和窗口仍交给Core；六个来源页签对应调整按钮间距与窗口预算，原生布局待测。新增文字使用稳定ASCII key中英文资源，Core关于页描述同步更新。

最低Core API13及原有显式能力检查保持。CAP-001／003／004／005／007／009／010继续复用名称、物品解析、账号窗口／字段／入口、服务、身份、语言及清理所有者；没有新增Core公共机制、反向依赖或跨业务私有读取。无输入控件，CAP-002不适用。本次Items的目标私有方法只连接同一Vault业务模块，不是新增Core服务。

## 离线验证与实机状态

双端真实清单模拟 **2874项检查通过**，包括重复API边界断言，不代表2874个独立玩家场景。新增覆盖：关闭不读、当前页查询等待、两可查看页逐页采集、无权限页跳过、部分覆盖、占用链接缺失、末槽失败保留、事件合并、元数据不循环查询、权限撤销隐藏、缓存副本、同快照主表／预览、保存恢复、同名不同公会／ClubId缺失无回退、退会、手动确认空页、关闭取消及按访问者清理。真实MoP清单的原GuildBank采集器和账号公会查询通过，原背包／装备／银行／邮件／拍卖测试保留。

Core回归69项、两插件76个TOC加载Lua源文件语法及Mists构建ValidateOnly通过。语言报告已查看：本次新增区域无中文硬编码，Core缺英文／格式不一致为0；全工作区既有6个未知key仍属AutoOpen，不扩大本轮修复范围。

```powershell
lua _NonRelease/VaultForever/Smoke.lua
lua _NonRelease/CoreForever/Smoke.lua
.\Tools\Test-LuaSyntax.ps1 -Addon YiboCore,YiboVault
.\Tools\Build-ReleasePackages.ps1 -Addon YiboVault -Target Mists -ValidateOnly
python Tools/Check-Localization.py --output _NonRelease/Localization/Workspace-Report.md
```

**待实机**：原生加载、ClubId／成员身份、槽位上限、页签权限与更新事件、各页真实物品／数量、确认空页、权限变化后的隐藏、取放后的刷新、保存落盘、中英文布局、MoP公会银行实机回归。用户目前无法测试，银行、邮件附件、拍卖行、公会银行均保持待实机验证；不根据模拟修改成已验收。

未来正常能访问公会银行时，打开原生窗口并逐页选择有查看权限的页，等待内容显示后核对Vault；空页在加载后手动刷新确认。关闭／重载核对旧快照和过期标识，再访问复采。原生查看权限变化后复核不可见页隐藏；不要为本轮测试额外购买页签或调整公会权限。
