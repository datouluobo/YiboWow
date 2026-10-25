# Forever 当前角色拍卖行最小适配

日期：2026-10-19。状态：**代码与双端模拟通过，待实机验证**。用户当前无法测试拍卖行；银行和邮件附件继续**待实机验证**，不要求现在补测。

后续阶段：当前开发清单已随[公会银行阶段](Forever-当前角色公会银行最小适配.md)升至0.5.0-api1；银行、邮件附件、拍卖行和公会银行均保持待实机验证。下文保留0.4阶段的实现与离线证据。

## 版本、范围与数据所有权

- Forever：`YiboVault_Forever.toc`、Interface16001、**0.4.0-api1**，新增 `Forever/Auction.lua`。仍使用 `YiboVaultForeverDB`、schema1，不复制MoP存档或迁移旧物品记录。
- Mists：**1.2.3-api1**、Interface50504、`YiboVaultDB`、原AuctionHouse采集器、账号查询及仓储页保持。本次不修改其运行采集实现；共享语言资源和Core关于页说明同步扩展。
- 仅当前角色本人拍卖结果中状态为Active的物品，排除Sold。没有市场浏览／价格扫描、竞标列表、上架、竞价、购买、取消、收钱或自动操作；不推断其它角色或账号拍卖。
- 该目标拍卖快照由Vault唯一拥有，Core只提供公开身份、名称、物品解析、页面／预览／字段／入口和清理生命周期。不读取其它业务实现或SavedVariables。

## 接口依据与异步就绪

参考[暴雪Forever生成的AuctionHouse API文档镜像](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua)和[原生拍卖页面](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseAuctionsFrame.lua)。当前源码分支提供 `QueryOwnedAuctions`、`GetNumOwnedAuctions`、`GetOwnedAuctionInfo`、`HasFullOwnedAuctionResults` 及 `Enum.AuctionStatus.Active/Sold`。该镜像不能替代本机build70374的API、事件、所有权和完整性实测；未获得真实上架样本前兼容验收保持待测。

1. 仅在世界内且收到 `AUCTION_HOUSE_SHOW` 后查询与采集；原生AuctionHouseFrame存在时还须可见。打开时请求一次 `QueryOwnedAuctions({})`，手动刷新也请求本人结果，不浏览整个市场。
2. 打开或重新请求后清除结果就绪标志，并将旧拍卖覆盖标记过期。须收到当前打开会话的 `OWNED_AUCTIONS_UPDATED`，且 `HasFullOwnedAuctionResults()==true` 才采集；既有缓存中的正值或零值都不能绕过该门槛。
3. 原生限流系统未就绪时暂缓请求；收到 `AUCTION_HOUSE_THROTTLED_SYSTEM_READY` 后重试一次，仍等待本人结果更新。8秒单次等待通知不写空数据、不轮询、不自动反复查询。未完整载入时继续保留旧快照，由后续原生更新或玩家正常刷新继续。
4. `OWNED_AUCTIONS_UPDATED` 合并触发本地读取，事件批量不反复请求服务器。查询、原生错误、关闭和离开世界均有独立边界；关闭后不调用本人查询／条目读取，并取消本会话待执行的结果处理。
5. 银行／邮件／拍卖事件逐项保护注册；客户端缺少事件不会中断已有背包装备启动，缺项记录在业务私有 `_unsupportedEvents`。必要接口或状态枚举缺失时停止该来源采样、保留数据并显示失败，不猜用旧客户端API或固定状态值。

## 采集、提交与保存

本人结果枚举逐条验证auctionID、已知状态、物品itemKey.itemID、正整数数量及可用链接；拒绝重复ID、受限／异常值、缺失条目、未知状态和链接ID错配。Sold条目不计入当前上架物品；有效物品无链接时保留item-id-only身份，不伪造完整链接。使用原生Active/Sold枚举比较，不按数字0／1硬编码。

每批结果在内存构造，两次读取完整列表并按auctionID比较状态／物品ID／数量／链接；核对数量、当前GUID、结果更新序号、拍卖行可见性及完整标志后，一次替换 `auction/auction`。第二条失败或数量相同但内容变化时，都不提交第一条候选。完全就绪的零条结果或全Sold结果可写入known-empty并清除不再上架的旧记录；未就绪／不完整不视为空。

记录沿用共享结构，`source=auction, sourceClass=listed`，稳定sourceID包含当前GUID和原生auctionID，保存auctionID／数量／状态／原观察时间。大ID用完整整数文本格式化，避免身份字符串转科学计数或显示溢出。UI位置显示拍卖ID；物品名称交给Core ItemResolver，名称不作为身份键。

本阶段不采价格、费用、准确到期时间，也不从时间区间猜到期。关闭拍卖行、离开世界及重载后，保留旧记录与采样时间并标记过期；不在后台推断仍上架、已成交或邮件已到达。重新获得完整结果后才刷新。请求或读取失败标记error，旧记录通过includeStale=true仍可见，includeStale=false排除；完整成功后恢复正常。

原生保存文件仍为无限客户端 `WTF/Account/<账号>/SavedVariables/YiboVault.lua`，表为 `YiboVaultForeverDB`。页签选择保存在Vault设置，下一会话可直接查看过期快照。模拟存档不写入游戏WTF目录。

## 公开契约与页面复核

沿用API1、Core API最低13及既有能力版本检查；无新增Core公共机制或跨业务耦合。`vault.items`、provider `YiboVault:inventory`、major1/minor1保持兼容，Forever增加可发现的 `source.auction:1`。Query仅准入当前GUID，账号／服务器／其它角色仍不支持；返回records／coverage／revision副本，数量计入listedQuantity而非physicalQuantity。无完成覆盖时totals=0不能作为空库存结论。GetPersonalCounts仍不宣称支持。

Core同一 `vault-items` 页新增“拍卖行”页签，显示物品、拍卖ID和数量；未访问显示“尚未采集：请先打开拍卖行”，等待／不完整／失败／过期分别显示，关闭时刷新不可用。主表和Core悬停复用相同查询、角色准入和状态，预览只投影用户选择的字段。五页签相应扩展页面最小及自然宽度；真实客户端布局仍待实机。没有第二套窗口或设置壳，通用角色／字段／入口继续交Core管理。

本次触及的名称、物品解析、账号窗口／字段／入口、服务、角色身份、语言、清理所有者继续复用CAP-001／003／004／005／007／009／010。无新增输入控件，CAP-002不适用。新增可见文本采用稳定ASCII key中英文资源，Core关于页目标描述同步包含本人拍卖。

## 验证与待测项目

双端真实清单集成 **2538项检查通过**，计数包含重复边界API断言，不代表2538个独立用户场景。新增覆盖：未访问不查询、先等事件再读缓存、Active／Sold过滤、全量门槛、稳定auctionID、事件合并、两次读取一致性、第二条失败保留、重复ID／异常数量／状态／链接拒绝、限流恢复、请求失败、关闭取消、保存恢复、已确认空结果、同快照主表／预览。MoP原拍卖查询与采集器及账号拍卖查询通过；既有背包、装备、银行、邮件回归保留。

Core回归69项、两插件75个TOC加载Lua源文件语法及Mists构建ValidateOnly通过。语言报告已查看：新增区域无中文硬编码，Core缺英文和格式不一致为0；工作区既有6个未知key仍属于AutoOpen。本轮不修复无关旧独立夹具失败，不将其计入通过。

```powershell
lua _NonRelease/VaultForever/Smoke.lua
lua _NonRelease/CoreForever/Smoke.lua
.\Tools\Test-LuaSyntax.ps1 -Addon YiboCore,YiboVault
.\Tools\Build-ReleasePackages.ps1 -Addon YiboVault -Target Mists -ValidateOnly
python Tools/Check-Localization.py --output _NonRelease/Localization/Workspace-Report.md
```

原生加载、本人结果的所有权／完整性、有效上架物品／数量／拍卖ID、更新／取消／售出后的结果变化、真正空结果、真实保存落盘与中英文布局、MoP拍卖实机回归均**待实机验证**。待日后正常能访问拍卖行时，打开原生拍卖界面并等待本人结果，再打开Vault拍卖页对照；正常操作后核对刷新，关闭／重载后核对旧快照与过期标识，再打开重采。用户当前无法测试，银行和邮件附件同样保留待实机，不要求现在执行。
