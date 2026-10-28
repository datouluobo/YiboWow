2026-10-28 YBP1.8.3：CAP-002／004／009既有共享输入、设置／维护页与owner语言调用开放Retail；最低API13及能力版本不变，Core无运行代码变化。两目标真实Flavor入口988项、中英文四页签91动作模拟及26文件语法通过，Retail新增交互与Mists简短回归待验，记为部分接入；离线兽栏仍待接入。见[本轮记录](../../YiboBeastPaths/Docs/Retail-Core维护接入-1.8.3.md)。

2026-10-27 Core R5：文档与台账收尾完成，见[R5验收](R5-文档与台账收尾验收.md)。CAP-001／004／007／009／010公开实现及最低API13／能力版本不变；R4仅新增Retail／Mists指定包的基本页面、声明覆盖、reload／完整退出恢复和原环境恢复证据，不把全部能力路径、英文／手动语言、宿主／战斗／IME等未验范围记为通过。Forever实机保留待测，整体未判定可发布；YBP离线兽栏仍待接入。按追加授权恢复误删源文件后15插件语法及适用回归通过，原5组失败和1条诊断保留，未发布。

2026-10-26 AltoBoss／Hub SW进度：CAP-003复用Core.ItemConfirmation进行本周期确认及撤销；CAP-004复用Core托管目标编辑器按钮；CAP-008经Core.Contracts消费AltoBoss action.targets:1.2的actions、ConfirmCycle／RevokeCycle，状态仍由AltoBoss唯一拥有；CAP-009新增owner中英文状态／确认资源。无Core运行代码或最低API13变化；事件归Mists，周期合并及Hub操作归Common。RaidProgress40、目录编辑468、身份33项四语言组合及相关回归通过，新增客户端行为与覆盖安装待验，详见[SW取证与确认](../../Docs/行动中心-SW锁定取证与本周期确认.md)。

2026-10-27 Core R3：CAP-001名称、CAP-004页面／准入／设置／三通道／预览／预算、CAP-007轻量身份、CAP-009 owner语言、CAP-010清理v2完成面向YBP离线兽栏的公共支持契约验证，详见[API13基线](API-v13-YBP离线兽栏公共支持契约.md)及[R3验收](R3-YBP离线兽栏公共契约实施验收.md)。2463项三目标合成消费者专项、适用Mists／Forever回归和三目标构建校验通过；生产字节、API13及能力版本不变，没有新公共接口。YiboBeastPaths的离线兽栏在上述各项均为“待接入”，当前仅测试owner CoreR3Consumer消费；既有路线／维护调用与最低要求不变。无业务输入／物品／跨业务消费需求，CAP-002／003／005／008／011不因本次夹具新增YBP接入；未触及的既有实现不改写状态。真实YBP提示／保存／恢复／客户端UI及R4最终包仍待，扩展旧夹具失败保留，未发布。

2026-10-27 Core R2-01／02：Retail0.1.0／API13／schema11接入32项共享基础设施，最小目录identity域和身份／等级两字段；不提供专业／位置／装备／日历或宠物业务。CAP-001／003／004／005／007／009／010相关实现按目标登记，既有能力版本不变，Mists／Forever各33项回归通过。115项Retail专项、213项三目标计划和索引／消费者回归通过；正式服源码就绪、独立存档归属、轻量身份、幂等和中文各页获用户确认。完整物品／宿主／语言／恢复／最终包及旧夹具仍待。见[验收记录](R2-01-02-Retail目标与构建实施验收.md)；YBP仅有既有路线元数据，离线兽栏未新增接入，业务最低要求未改变。

2026-10-27 Core R1-09：CAP-003物品失败文案、CAP-004状态／版本展示、CAP-009语言及CAP-005／007／010相关公开契约完成收尾，见[当前共享底座契约](API-v13-R1共享底座兼容与失败契约.md)与[验收记录](R1-09-文案与契约文档收尾验收.md)。新增6个双语key，563key静态审查无缺译／格式错／重复，791项自动／手动语言及失败路径专项和双目标回归通过。API13、能力版本及业务最低要求保持；item-picker当前v2、单项v1兼容门槛已明确。没有业务运行代码或接入状态变化；YBP兽栏和Retail未接入。旧夹具及新增实机／最终包继续待验。

2026-10-27 Core R1-07／08：CAP-004窗口／入口／设置／档案字段、CAP-005通用契约、CAP-007轻量角色身份、CAP-009语言、CAP-010清理所有者相关公共实现和证据完成本轮复核。目标元数据限定目录／帮助／期望owner，历史owner及pending保留；修复页面注销后新注册的Create和活动预览生命周期，现有重复／冲突契约保持。389＋465项专项及双目标／消费者回归、构建计划通过，扩展旧夹具与新增实机待验，见[验收记录](R1-07-08-目标元数据与通用契约实施验收.md)。API13、能力版本、业务最低要求和运行调用不变，没有新增业务接入；YBP兽栏和Retail未接入。

2026-10-27 Core R1-05／06：CAP-002基础输入、CAP-003公共物品、CAP-004窗口／入口／确认的原生查询通过内部目标surface集中；CAP-009复用现有本地化资源。API13、各能力版本及消费者最低Core要求不变；业务运行代码没有新增接入。192项专项与双目标／消费者回归、构建计划及语法通过，扩展旧夹具阻塞与新增实机待验，见[实施验收](R1-05-06-公共物品与UI原生边界实施验收.md)及[物品API补充](API-v7-物品选择与基础输入.md)。YBP业务及Retail未接入，不将内部机制记为它们已完成。

2026-10-22 Mail MoP1.3.0：包含既有退信与刷新修复，用户确认刷新修复实机通过并授权提交推送打包；沿用API13及CAP-003／007／009，无新增Core能力要求。其余专项及发行检查保留待验。

# Core 公共能力迁移台账

2026-10-27 Core R1-03／04：角色身份与位置原生绑定经内部Client边界接入，Mists专业／装备／专精迁至目标目录，目标字段集合及旧槽映射拆出，失败读取保留域与旧profile及时间；known空快照仍可替换。133项专项、143项入口、334项启动、69项双端、268项七业务联合、92项专业消费者及其它角色／清理／业务回归通过；构建计划142＋148项通过，新实机待验。CAP-001／004／007／009／010／011适用公共实现与证据见[验收记录](R1-03-04-角色身份与数据域实施验收.md)；API13、能力版本及业务最低Core要求不变，没有新增业务接入。Retail未接入，前阶段及R0机器基线保持历史快照。

2026-10-27 Core R1-01／02公共底座保护：API13及现有能力版本保持，Mists／Forever均增加显式目标／生命周期与候选存档预检；CORE_READY在必要初始化与提交成功后单次隔离通知，失败保留存档并允许重试。CAP-004窗口／入口、CAP-007角色身份、CAP-009语言、CAP-010清理所有者相关底座回归见[实施验收](R1-01-02-启动与存档预检实施验收.md)；业务插件调用与最低Core要求无变化，未增加已接入插件。334项专项与两端／联合模拟通过，新增实机仍待；Retail未接入，不将共享机制存在记为正式服能力可用。

本轮Hub搜索与SW身份复核：CAP-003/004保留Core输入框生命周期，Hub筛选不再隐藏活动输入框；CAP-008由AltoBoss统一Mists TBC难度及历史目标identityAliases，Hub添加/查找/复制和投影复用同一来源；CAP-009新增175/176中英文资源。无Core运行代码或最低能力版本变化。33项四语言组合、458项目录夹具、20项列投影及相关专项通过，真实客户端和覆盖安装待验，详见[实施记录](../../Docs/行动中心-搜索焦点与副本身份一致性.md)。

2026-10-25 副本目录及Hub内添加：AltoBoss2.8.3／TaskHub0.6.1工作树，CAP-004复用Core搜索/单选/多选/分组/分页，CAP-008通过boss.target-catalog及action.targets元数据完成Hub内部目录选择，CAP-009新增owner资源及Mists目录名称。最低API13和能力版本不变，无Core运行代码变化；目录API/静态事实位于Mists、组合与Hub界面位于Common。456项四语言组合及相关专项通过，来源缺失/不兼容/晚注册已模拟，真实客户端和覆盖安装待验。未提高版本或发布，详见[实施记录](../../Docs/行动中心-副本首领范围修复-20261025.md)。

2026-10-25 本轮验收与版本：用户确认附魔目标添加、制作后Hub完成清理及Crafting角标清理通过；Core1.12.9、Crafting1.2.2、Hub0.6.1更新，公开API与能力版本不变。服务器范围及完整语言／覆盖安装矩阵继续保留精确待验范围，打包与提交不等于渠道发布。

2026-10-25 CAP-008完成状态标记补修：用户确认附魔制作后Hub任务清理实机通过，Crafting绿色来源标记仍保留。Core共享BusinessItemActions将角标／圆点条件改为active+paused>0，LookupItems完成历史、原契约及最低版本不变，无新业务分支；实际Core／Hub／Crafting集成覆盖配方和角色格清理、混合状态、重开与暂停，Core Contracts90、Forever69、三插件93文件语法及Mists构建校验通过。来源标记补修待实机，扩大性能回归有AltoBoss独立阻断，详见[完成后的来源标记](../../YiboCrafting/Docs/Mists-附魔制造目标修复与验收.md)。

2026-10-24 Crafting／Hub服务器范围：CAP-001／004／007／009与公开Contracts继续接入；新增owner中英文范围字段，复用Core角色目录realm数据与统一下拉，不新增Core能力。Crafting来源在保存、施法与库存判定中约束服务器，Hub账号标记经公开Normalize获取当前候选，目标管理共享职责移入Common/Goals.lua；两插件最低API13及既有能力要求不变。用户确认添加目标操作实机通过，卷轴及服务器新行为仍待实机；新增范围／Snapshot／标记测试、原回归、两插件构建校验及Forever兼容模拟通过，细目见[附魔目标及服务器范围](../../YiboCrafting/Docs/Mists-附魔制造目标修复与验收.md)。

2026-10-24 Crafting Mists附魔目标修复：按固定build 70032的附魔效果补齐319条卷轴映射；目标来源及配方目录归入Mists/。CAP-001／003／004／007／009沿用现有公开调用，API13／localization:1／business-item-actions:2要求不变。实际目录经Hub保存测试覆盖两种执行范围与制造／持有两种条件，卷轴查询复用ItemResolver与Contracts库存来源；5275条产物证据核对、原7组、新增目标测试、40文件语法、构建校验及Forever92项模拟通过。旧路径为空操作避免覆盖更新重复加载；无新增Core契约，客户端待验及扩展回归失败见[附魔目标验收](../../YiboCrafting/Docs/Mists-附魔制造目标修复与验收.md)。

2026-10-22 Vault MoP分类空位显示：CAP-004复用现有Core窗口／Theme物品格字体和颜色；CAP-009新增CAPACITY稳定键，zh/en参数一致，四语言标签与宽度198项模拟通过。最低API13／localization:1未变，无新Core契约；原解析、身份和查询范围不变。新增显示已同步独立MoP测试目录，客户端待验，Forever仅共享资源兼容回归通过。详见[分类空位验收](../../YiboVault/Docs/Mists-分类空位显示与验收.md)，不将新增显示记为实机完成。

2026-10-22 Vault双端采集拆分：迁移范围内MoP原生链接缺itemID时接入CAP-003 ItemResolver:Parse，并显式检查Parse方法；CAP-007共用错误状态与MoP采集的四处身份查询改用identityOnly。最低API13／item-resolver:1／character-identity:1不变，无新增Core契约。2874项双端模拟、加载专项106项、Mail联动69项及测试目录覆盖回放通过；旧专项11处失败与前态一致，客户端待验，沿用部分接入。未触及的旧调用不推定完成，见[拆分验收](../../YiboVault/Docs/双端采集加载拆分与覆盖更新验收.md)。

2026-10-22 Mail MoP1.2.26安全补修：紫翠玉39705铜邮件经用户确认，重载历史为已收取，实际钱包到账缺少独立余额证据；1.2.26单封拍卖成功邮件退信禁用、普通邮件与拍卖所得混选退信已实机通过（成功1封、跳过1封，拍卖邮件保留）。业务层新增原生canReply明确许可与非GM检查，复用既有CAP-003确认、CAP-007当前角色及CAP-009 owner中英文提示，最低API13和Core契约不变。10组离线入口、50文件语法与MoP构建ValidateOnly通过；其余补修实机及发行检查待完成，原1.2.25已验范围不外推到本次安全门槛，详见[退信事件与验收](../../YiboMail/Docs/Mists-单封与批量退信方案与验收.md)。

2026-10-20 Builds Forever0.1.0装备最小版：CAP-001公共角色名、CAP-003 ItemResolver:Parse／GetInfo、CAP-004统一页面／滚动／字段／同源预览与三通道入口、CAP-007当前GUID、CAP-009 owner语言、CAP-010清理v2在本目标已调用；最低API13与item-resolver:1等能力及方法显式检查。没有新Core契约，未新增业务输入或跨业务能力；CAP-002／005／008本目标不适用，CAP-011未消费仍待评估。67项目标模拟、MoP Core13Spec1057及增强回归、Core69与其它五个Forever目标回归通过；原Mists接入记录保留。新目标全部待实机，记部分接入，详见[实施与验收](../../YiboBuilds/Docs/Forever-当前角色装备最小适配与验收.md)。


2026-10-20 Crafting Forever阶段：Core0.2.0／API13提供CAP-011 profession-profile:1，Crafting0.1.0先通过公开专业档案确认本人专业，再拥有配方观察／保存。业务复用CAP-001／004／007／009／010；无输入、物品或跨业务消费，CAP-002／003／005本目标不适用。69项目标模拟、Crafting原7组、Core69及四个其它业务目标回归通过；70文件语法、两插件MoP构建校验通过。新增专业档案与Crafting全部待实机，无发布就绪声明，详见[实施与验收](../../YiboCrafting/Docs/Forever-专业与配方最小适配与验收.md)。

2026-10-20 Reputation0.1.1显示实机确认：用户确认等级名称、当前级进度、零进度和等级颜色条的中文主窗口展示，补充CAP-004／009证据；夜爪德鲁伊及高阶会已显示增长后值，采集触发方式未确认。悬停、其它语言、自动变化刷新、存档独立恢复及MoP回归等保持待验，整体仍为部分接入。见[声望实施与验收](../../YiboReputation/Docs/Forever-当前角色声望最小适配与验收.md)。

2026-10-20 Reputation Forever0.1.1显示接入复核：CAP-004继续复用Core窗口、字段显隐及同源悬停；等级名称／当前级进度／颜色条由Reputation业务层生成，未增加Core业务逻辑。CAP-009复用STANDING中英文资源并新增进度／已满／待确认资源；最低Core要求与其它能力调用不变。91项目标模拟和MoP原回归通过，0.1.1显示待实机复验；此前0.1.0采集与对照证据保留，见[声望实施与验收](../../YiboReputation/Docs/Forever-当前角色声望最小适配与验收.md)。

2026-10-20 Reputation原生对照／RL补充：用户截图确认暴风城、肯瑞托、诺莫瑞根流亡者、高阶会的原生等级进度与插件原始区间换算一致；用户明确最后一张为RL后，Core窗口与8项数值正常且已重新观察。补充CAP-004／007／009显示及重载路径证据；变化刷新、重采前存档恢复、完整退出落盘和其它验收仍待，CAP-010未获新证据，整体保持部分接入。见[声望实施与验收](../../YiboReputation/Docs/Forever-当前角色声望最小适配与验收.md)。

2026-10-20 Reputation实机证据补充：用户截图确认Forever0.1.0启动、当前角色8项声望采集展示（含正值与零值）及中文Core主窗口，补充CAP-001／004／007／009本次路径的实机证据。原生列表逐项对照、变化刷新、保存恢复、完整语言／字段／悬停及MoP回归仍待验证；CAP-010等未获新实机证据，整体保持部分接入，见[声望实施与验收](../../YiboReputation/Docs/Forever-当前角色声望最小适配与验收.md)。

2026-10-20 Reputation Forever阶段（部分接入，待实机）：0.1.0接入CAP-001名称／004窗口字段入口预览与角色准入／007 GUID／009语言／010缓存清理v2；最低API13及account-surface-budget:2显式检查。Reputation独立拥有当前角色声望事实，Core不恢复声望域；没有输入、物品或跨业务查询，CAP-002／003／005本目标无调用，不适用。70项目标模拟覆盖四语言、晚就绪、缺能力与停止建库、清理回放和同源预览；MoP原88项／Retention额外39及Hover、Core69、Currency60、Mail69、Vault2874、74文件语法与MoP构建校验通过。全部待实机，见[声望实施与验收](../../YiboReputation/Docs/Forever-当前角色声望最小适配与验收.md)。

2026-10-19 Currency实机证据补充：Forever0.1.0截图确认当前角色金币页面、正值采集及中文展示；窗口0金17银18铜与探针1718铜一致，为CAP-001／004／007／009本次路径补充实机证据。变化刷新、保存恢复、角色切换、完整语言模式、悬停及MoP回归仍待验证；CAP-010等未获新实机证据，整体保持部分接入，见[金币实施与验收](../../YiboCurrency/Docs/Forever-金币最小适配与验收.md)。

2026-10-19 Currency金币Forever阶段（部分接入，待实机）：0.1.0复用CAP-001名称／004窗口字段入口预览与角色准入／007当前GUID／009语言／010清理v2，最低API13与account-surface-budget:2显式检查。单角色金币由Currency采集保存，Core不恢复货币域；没有跨业务消费或输入／物品需求，CAP-002／003／005本目标不适用。关于页声明目标与当前角色金币范围。60项目标模拟覆盖四种语言模式、清理回放、缺能力及停止写库；Core69、Vault2874、Mail69、Currency原四组Spec及72文件语法／MoP构建校验通过。实机全部待验证，见[金币实施与验收](../../YiboCurrency/Docs/Forever-金币最小适配与验收.md)。

2026-10-19 Mail实机证据补充：用户截图确认Forever0.1.0-api1启动、当前角色空收件箱采集及中文Core主窗口。CAP-004／007／009的本次页面路径增加实机证据；其余能力、非空邮件、保存恢复、语言模式和MoP回归仍待验证，整体保持部分接入。Vault银行、邮件附件、拍卖行、公会银行状态不变。详见[Mail实施与验收](../../YiboMail/Docs/Forever-最小适配与验收.md)。

2026-10-19 Mail本体Forever阶段（部分接入，待实机）：Mail0.1.0-api1复用CAP-001／003／004／005／007／009／010及最低API13，显式要求account-surface-budget:2；无输入／物品选择器需求，CAP-002等未调用能力在本目标不适用，Mists原要求保持。独立存档与当前GUID范围，Core页／预览同源；mail.items v1.0只读收件契约供Vault0.6.0-api1可选消费，注册／注销／方法不兼容分别验证，数据不另存为第二权威。69项Mail双端与联动、Core69项、Vault2874项、107文件语法及两插件MoP构建校验通过；12旧Spec的两处失败与四共享文件前态内存对照一致。Mail及Vault四类来源均待实机，见[Mail实施与验收](../../YiboMail/Docs/Forever-最小适配与验收.md)。

2026-10-19 Vault公会银行阶段（部分接入，待实机）：Forever0.5.0-api1新增当前公会＋访问角色GUID隔离的guild-bank来源，复用CAP-001／003／004／005／007／009／010及API13检查。仅查看权限页、跟随原生当前页逐页采集，权限撤销过滤旧缓存，空页手动确认；主表／预览同源，Core清理所有者同步覆盖该GUID公会快照。无新Core契约，无跨业务私有读取；无输入控件，CAP-002不适用。2874项双端模拟包含MoP原GuildBank采集与账号查询，Core69项、76文件语法和MoP构建校验通过。银行、邮件附件、拍卖行、公会银行均待实机验证，见[公会银行实施记录](../../YiboVault/Docs/Forever-当前角色公会银行最小适配.md)。

2026-10-19 Vault拍卖阶段（部分接入，待实机）：Forever0.4.0-api1新增当前角色auction来源，只收集Active本人上架物品。CAP-001／003／004／005／007／009／010继续复用既有公开接口及API13检查，无新Core契约或私有业务读取；无新输入控件，CAP-002不适用。异步查询等待完整原生结果，错误／关闭保留旧快照，主表／预览同源。2538项双端模拟包含原MoP拍卖查询、采集及账号查询，Core69项、75文件语法和MoP构建校验通过。银行、邮件附件与拍卖行均待实机验证，见[拍卖实施与验收](../../YiboVault/Docs/Forever-当前角色拍卖行最小适配.md)。

2026-10-19 Vault邮件阶段（部分接入，待邮件实机）：Forever0.3.0-api1新增当前角色mail/inbox物品附件来源，沿用CAP-001／003／004／005／007／009／010与最低API13及既有能力检查。未新增Core公共能力，不读取其它业务实现或存档，邮件数据由Vault该目标采集器拥有；MoP原MailItems／Provider保留。新增页面与预览继续复用Core窗口／字段／入口，完整邮箱校验后提交，关闭保留过期快照。1925项双端模拟（含原MoP邮件采集／账号查询）、Core69项、74文件语法及MoP构建校验通过。邮件与银行均待实机验证，见[邮件实施与验收](../../YiboVault/Docs/Forever-当前角色邮件附件最小适配.md)。

2026-10-19 Vault银行阶段（部分接入，待银行实机）：Forever0.2.0-api1新增当前角色bank来源，继续复用CAP-001／003／004／005／007／009／010的既有公开接口及最低API13检查，无新增Core能力、无跨业务私有读取。UI复用同一页签／字段／预览与物品解析；此前按钮修复已获用户确认。842项双端模拟与Core69项通过；角色7级尚无银行环境，真实银行采集、保存与展示继续待测。MoP版本与范围保留，见[银行实施与验收](../../YiboVault/Docs/Forever-当前角色银行最小适配.md)。

## 当前基线

2026-10-19 Vault新目标接入（部分接入，待完整客户端验收）：Forever0.1.0-api1复用CAP-001名称格式化、CAP-003物品解析、CAP-004账号窗口／字段／入口、CAP-005服务、CAP-007当前角色身份、CAP-009语言与CAP-010清理所有者；最低API13，并明确检查account-surface-budget:2及account-character-admission:1。本次不自建基础输入、窗口壳、入口或角色排序；无输入控件需求，CAP-002不适用。用户截图已确认当前背包与装备采集、窗口切换和托管设置页；按Core既有Theme按钮签名修正误传高度导致标签显示28，并复用selected状态。320项双端模拟通过，Core目录同步加入Vault的Forever目标与当前角色描述；按钮修复、保存恢复和MoP待实机核对，不外推MoP既有验收结论，见[Vault实施记录](../../YiboVault/Docs/Forever-当前角色物品最小适配.md)。

2026-10-19 CAP-004目标显示补充：关于页改为直接消费按 `supportedTargets` 过滤的共享 AddonCatalog，未适配当前目标的条目不查询安装状态或创建卡片；空分组隐藏。Forever业务目录当前仅Vault，Mists业务目录保留13项，69项双端模拟通过，目录显示改动待实机复测。沿用 `addon-catalog:1`、Locale绑定与账号窗口能力，未新增公共契约；Vault目标接入状态见上条。

2026-10-19 新目标补充：Core 已实现 Forever 0.1.0 / API13 的最小开发清单，复用 CAP-004 窗口／设置、CAP-007 GUID角色目录与 CAP-009 语言，使用独立 `YiboCoreForeverDB`，原 Mists 1.12.7 基线保留。两端清单的离线启动／窗口／保存模拟已验证，原生清单选择与客户端验收待做；未新增公共能力或业务接入，不将已有 Mists 验收结论外推到 Forever。详见[最小适配与验收](Forever-最小适配与验收.md)。

> 最近复核：2026-10-18。当前 Core 源码为 1.12.7 / API 13；当前版本发行状态缺少明确记录时标待核对，历史发布记录按原日期保留。
>
> 用户于2026-10-16确认：除Legendary／Todo完整英文适配、BeastPaths后续宠物开发、TaskHub复杂任务链三项外，Core与全部现有业务插件的当前功能均已实机验收收口，包含AutoOpen与Mail。三项延期见[后续开发任务清单](../../Docs/后续开发任务清单.md)，逐插件源码版本与发行核对见[当前状态总览](../../Docs/仓库当前状态总览.md)。
>
> 本台账共登记 CAP-001 至 CAP-011。验收结论表示现有交付范围通过；下方旧版代码观察、候选与兼容边界保留追溯，不重新生成本轮待办，也不据用户验收推造新增接口或未执行的自动化证据。
> Reputation 1.7.1 数据归属改造已实施：Core 停止声望采集，Reputation 接管采集、目录与新存储；旧快照经公开接口一次性导入并冻结保留。迁移与验证证据见 CAP-009 和实施记录。

## 目录

- [当前基线](#当前基线)
- [当前实施节奏](#当前实施节奏2026-10-16)
- [维护与状态](#维护与状态)
- [首次审查依据与边界](#首次审查依据与边界)
- [API 版本演进与追赶要求](#api9-与-api10-合并发布及业务追赶要求)
- [活动能力总表](#活动能力总表)
- [插件最低版本与依赖基线](#当前插件最低版本与依赖基线)
- [CAP-001：公共名称格式化](#cap-001公共名称格式化)
- [CAP-002：基础输入](#cap-002基础输入)
- [CAP-003：物品解析、选择与操作确认](#cap-003物品解析选择与操作确认)
- [CAP-004：账号页面、入口与设置](#cap-004账号页面入口与设置接入基线)
- [CAP-005：跨业务能力连接](#cap-005通用跨业务能力连接)
- [CAP-006：首次打开提示](#cap-006页面首次打开提示)
- [CAP-007：轻量角色身份投影](#cap-007轻量角色身份投影)
- [CAP-008：业务项目主动添加](#cap-008业务项目主动添加)
- [CAP-009：语言服务与账号语言偏好](#cap-009公共语言服务与账号语言偏好)
- [CAP-010：角色缓存所有者与延后清理](#cap-010角色缓存所有者与延后清理)
- [后续更新记录](#后续更新记录)

## 当前实施节奏（2026-10-16）

- 保留触及即迁移；每次后续业务修改收尾时按实际 diff 检查，持续记录正确接入与遗漏。未触及的旧实现保留为迁移库存。
- 最近两天维护文档、延期任务与无限首次验证计划。无限开测日期待确认；从1级角色现有能力逐步采样，解锁系统后补测，见[首次验证计划](../../Docs/无限公测首次验证计划.md)。新目标适配范围依据真实证据另定。
- 大幅更新开始时固定当时已实现且满足验证要求的 Core 能力基线，补齐该插件全部适用项。基线须涵盖 api9／api10 合并增量，若当时 Core 又有新能力，也一并审查适用范围、最低版本及验证要求；接口明细继续按 CAP 条目登记。
- Core 负责通用操作实现，业务负责接入与业务回调。现有功能已验收；历史审查提及的调用位置仅在实际触及或新需求出现时核对，不自动重开旧开发事项。

## 维护与状态

- 使用稳定编号 `CAP-001` 等标识迁移事项；编号不代表运行时注册名称。
- Core 状态：`待实现`、`已提供`、`待扩展`。另列发布版本与验证情况；源码存在不等于已发布或已验收。
- 插件状态：`待评估`（尚未确定适用范围）、`待迁移`（已确认存在相关调用）、`部分接入`（已有接入但仍有剩余调用、版本要求或验证缺口）、`已接入`（所列范围完成接入、最低版本检查与必要验证）、`不适用`（已审查，所列范围没有该能力需求）。
- 每个状态仅适用于该能力条目明确列出的范围。使用旧接口或间接使用 Core 控件，不等于已接入新契约。
- Core 新增或发布能力、业务接入、发现遗漏、契约变化或新增插件时更新相关条目。新插件须在各活动能力下登记；未经审查先记为待评估。无变化时无需定期更新。
- 表格按插件技术名排序。后续更新须记录接入版本、已覆盖与剩余范围、验证证据、最近审查日期；未发布改动标注“工作树”，不猜测发布版本。
- 台账保存进度与证据，接口参数、返回值与兼容语义以对应 API 文档为准。每项能力的完成条件是 Core 已提供，所有适用插件已接入，且已知缺口已关闭。

## 首次审查依据与边界

审查仓库根目录的 `YiboCore` 与 13 个业务插件：以 `.toc` 加载清单、初始化检查、运行时代码和相关 API 文档为依据，排除第三方 Libs、探针、构建输出与测试辅助实现。分支为 `main`，工作树包含尚未提交的其他改动，以下结论是本次读取的本地源码快照，不代表远端或已发布安装包状态。

首次审查时 Core 源码版本为 **1.6.3 / API v7**。2026-10-08 后续发布记录：当前源码与 HEAD 均为 **1.9.0 / API v10**，提交 `1ef9ccf`；依据 [Bootstrap.lua](../Bootstrap.lua)、[YiboCore.toc](../YiboCore.toc) 及用户提供的发布页截图，渠道从 **v1.7.0-api8** 直接提交 **v1.9.0-api10**，未单独发布 **v1.8.0-api9**。截图中 api8 已 Approved，api10 为 Uploading；记录为已发起发布，尚无审核完成证据。业务插件工作树接入与游戏内验收仍分别记录，不能由 Core 发包推定完成。

本轮覆盖 14 个业务目录（13 个现有业务插件及 YiboTaskHub 项目基础），静态复核加载清单、最低版本、能力注册及接入调用。重新运行 RuntimePerformanceSpec、InboxReleaseSpec、MailProviderSpec、VaultIntegrationSpec 均通过；CharacterNamesSpec 在“API v10 应拒绝”的过期断言处失败，见 AUD-009。历史通过记录保留，但不能据此宣称当前工作树名称回归全部通过。首次提示本轮仅静态核对。

首次审查完整登记名称显示、基础输入和物品选择相关范围，并建立账号页面、入口、设置接入基线。其余已注册能力登记为现有接口索引，未进行逐调用验收；后续发现真实迁移需求时新增独立条目。

## api9 与 api10 合并发布及业务追赶要求

2026-10-08 用户确认：跳过 v1.8.0-api9 独立发布，api9 的实现随 v1.9.0-api10 一起发布。1.8.0 是实现阶段版本；使用 api9 能力的用户应升级到渠道包 **v1.9.0-api10 或更新版本**。运行时仍按实际所需 API／能力版本检查，不因合并发包把只需 API v9 的插件一律改成 requiredAPI=10。

**其它业务插件后续追赶 Core 时，必须把 api9 与 api10 纳入同一次接入审查和验收，补齐两代中全部适用项；不能只完成 api10 首次提示或提高版本声明，就将 api9 记为已完成。** 已有接入也需核对剩余范围；不适用项记录理由，不添加无需求功能。更早 API 的遗留项继续按各 CAP 条目记录。

| 代际 / 台账 | 同批核对与补齐范围 | 完成证据 |
| --- | --- | --- |
| api9／api11 / CAP-005 | 真实跨业务调用经 Core.Contracts；Service 与 Provider／List 均已实现，业务接入分别登记 | Service 查 API v9 / business-services:1，Provider 查 API v11 / business-providers:1；验证缺失、晚注册、注销、不兼容及业务时效 |
| api9 / CAP-004 | 已有 NotifyPageChanged 调用复用 Core 的合并刷新；核对可见性、切页、悬停及需要即时反馈的交互 | Core 内部刷新改进可直接继承，但需验收业务页面行为；不要求无需求插件新增刷新机制 |
| api9 / CAP-003 | 对本次涉及的物品展示加载复用已提供的 ItemResolver；核对异步回调、过期取消和错误／超时 | 公共解析接口仍为 API v7 / item-resolver:1；api9 是内部调度改进，不单独抬高该调用的门槛 |
| api10 / CAP-006 | 有首次引导需求的页面接入 firstUseTip；没有该需求时登记不适用；必需状态与安全提示保留常显 | 使用者检查 API v10 / account-view:2；验证一次性、预览不触发、成功记录、计时及低版本提示／停止 |

追赶记录须分别列出 api9 与 api10 的已覆盖、剩余、不适用和验证证据。Mail／Vault／Currency 的 api9 工作树接入，以及 Builds／Reputation／Todo 的 api10 工作树接入，均不代表整个插件已完成这次合并批次。

## API 11–13 版本演进补充

上方关于 API 10 的批准／上传状态是 2026-10-08 的历史发布记录，不是当前源码上限。之后的实现与接入按当时工作树版本记录；以下是从 API 10 补齐到当前 Core 1.12.6 / API 13 的能力基线。API 11–13 的发布状态按各版本记录区分；1.12.5 / API13 的角色清理 v2 已发布，1.12.6 为当前源码版本，渠道发行待核对。

| Core 基线 | 新增或扩展的公开能力 | 迁移台账与当前边界 |
|---|---|---|
| Core 1.10.0 / API 11 | `business-providers:1`（Provider/List）；`account-surface-budget:1`；`account-character-admission:1`；`character-identity:1` | CAP-004、CAP-005、CAP-007 分别登记。Provider、准入／高度预算及身份能力按真实消费者接入；没有对应需求的插件保持不适用或待评估。 |
| Core 1.11.0 / API 12 | `business-item-actions:1`，为业务页面提供 Core 管理的主动添加与目标操作入口 | CAP-008 登记提供方与消费方。Core 1.12.0 将其向后兼容扩展为 `business-item-actions:2`，已有 v1 调用仍有效。 |
| Core 1.12.0 / API 13 | `localization:1`；`account-entry:2`；`builtin-entry-bar:3`。并把 `business-item-actions` 升至 v2；统一下拉互斥等控件行为沿用既有接口 | CAP-004、CAP-008、CAP-009 登记。语言接入最低 API13；新入口消费者按具体所需能力检查版本。当前功能实机验收已收口；该版本历史发行证据分别保留。 |
| Core 1.12.4 / API 13 | `account-dynamic-fields:1`、`character-archive-providers:1`；Core 停止声望域采集并由 YiboReputation 接管权威数据 | CAP-004／005／009／010；Currency 与 Reputation 的代码、发布和验收状态见插件条目。 |
| Core 1.12.5 / API 13 | 已发布 `character-cleanup:2`，兼容 v1；持久所有者登记与延后删除上下文 | CAP-010；Builds 与 Currency 已接入 v2，其他调用按真实生命周期需要评估。 |
| Core 1.12.6 / API 13（工作树） | `account-surface-budget:2`；最终窗口高度与列宽预算，兼容 v1 页面 | CAP-004；六个业务插件接入，用户确认本轮实机验收完成；当前版本发行待核对。 |

YiboMounts 1.0.0 已按 API13 接入 `localization:1` 和 API v6 独立设置注册；Core 保持可选，增强功能要求 API13，独立来源 Tooltip 保持可用。现有范围已验收，契约与历史证据见 [YiboMounts API13 接入说明](../../YiboMounts/Docs/Core-API13-接入说明.md)。

## 活动能力总表

| 编号 | 能力 | Core 状态与最低版本 | 当前适配状态 | 后续事项 |
| --- | --- | --- | --- | --- |
| CAP-001 | 公共角色／联系人名称格式化 | 已提供；API v8 / `character-name-format:1` | 当前已验收插件按各自范围接入；Legendary、Todo 语言以外的当前范围按本轮验收结论处理 | AutoOpen 不涉及角色名；联系人特殊显示语义见插件条目 |
| CAP-002 | 基础输入控件 | 已提供；API v7 / `basic-input:1` | 当前适用范围实机验收完成 | 现有功能已收口；后续输入变更按公开能力审查 |
| CAP-003 | 物品解析、选择与操作确认 | 已提供；API v7 / `item-resolver:1`，`item-picker:2` | 当前适用范围实机验收完成 | 现有功能已收口；独立模式与可选Core边界继续保持 |
| CAP-004 | 账号页面、入口与设置工作台 | 已提供；API 13 / `account-entry:2`、`builtin-entry-bar:3`、`account-surface-budget:2`；其余能力版本按消费范围检查 | 当前适用范围实机验收完成；可选集成仍按自身契约处理 | 无当前已知阻断；历史兼容边界见 CAP-004 |
| CAP-005 | 通用跨业务能力连接 | 已提供；Service API v9、Provider API v11；以能力版本为准 | 当前服务／提供者／消费者按 CAP-005 逐项记录，客户端适配验收完成 | 待评估项仅在出现真实跨业务需求时重审 |
| CAP-006 | 页面首次打开提示 | 已提供；API v10 / `account-view:2` | 当前适用页面按本轮验收结论完成 | 新增真实低频操作引导时再评估 |
| CAP-007 | 轻量角色身份投影 | 已提供；API v11 / `character-identity:1` | 14 个插件均已登记；各自适用范围见 CAP-007 | 后续身份查询触及时按需复用 |
| CAP-008 | 业务项目主动添加 | 已提供；API v12 起，当前 Core 提供 `business-item-actions:3`，按消费版本检查 | 当前适用插件的代码与验收状态见 CAP-008 | 业务目标范围仍按来源与消费者契约演进 |
| CAP-009 | 公共语言服务与账号语言偏好 | 已提供；API 13 / `localization:1` | 当前适用范围验收完成；Legendary、Todo 有硬编码候选暂缓 | 使用原版英文客户端处理 Legendary、Todo 候选 |
| CAP-010 | 角色缓存所有者与延后清理 | 已提供；Core 1.12.5 / API 13 / `character-cleanup:2`，v1 兼容 | 14 个插件逐项登记；当前适配验收完成不代表必须迁移到 v2 | 仅在确有 v2 生命周期需求时接入；发布状态见契约记录 |

### 当前插件最低版本与依赖基线


以下按 2026-10-16 台账复核整理，现有功能均已实机收口；历史接入版本保留在后续详细条目，当前源码版本以状态总览和主TOC为准。最低 API 是插件初始化／注册门槛，不代表该插件已消费该 API 的全部能力；TOC 插件版本与 Core 发布状态须分别核对。具体能力检查以各 CAP 条目和插件 Bootstrap 为准。

| 插件技术名 | 最低 Core API | TOC Core 依赖 | 能力要求与当前范围 |
| --- | --- | --- | --- |
| YiboAltoBoss | 13（基础与增强） | RequiredDeps | 工作树副本状态／悬停使用 localization:1；五人本 DBM 可选桥接使用 events:1，目标增强继续要求 business-services:1 / business-providers:1；旧设置壳移除见 CAP-004；AUD-005 已关闭 ；2026-10-16本轮矩阵接入另检查account-surface-budget:2及实际方法 |
| YiboAutoOpen | 13 + `localization:1`（可选设置） | OptionalDeps | Core 缺失或版本不足时独立基础队列保留；当前功能已实机收口 |
| YiboBeastPaths | 13（可选维护页） | OptionalDeps（各客户端 TOC） | 当前源码v1.8；固定 Core 1.12.1 基线；检查 localization:1、basic-input:1、account-view:2、account-surface-budget:1；独立路线功能保留 / 2026-10-13 |
| YiboBuilds | 13 | RequiredDeps | 当前源码1.5.0；Core1.12.5+；localization:1、character-name-format:1、character-identity:1、account-view:2、account-entry:2、character-cleanup:2、business-providers:1、business-item-actions:1；当前实机验收已收口 |
| YiboCrafting | 13 | RequiredDeps | 当前源码1.2.1；API13、名称／输入／物品解析及账号视图等要求见 CAP-001～009；当前验收完成 |
| YiboCurrency | 13 | RequiredDeps | 当前源码1.0.0：Core1.12.5 / API13、account-dynamic-fields:1、character-archive-providers:1、character-cleanup:2及实际接入能力；Vault仅经契约发现，无TOC业务依赖 |
| YiboLegendary | 13 | RequiredDeps | 当前源码2.2.3检查 `localization:1`、`character-name-format:1`、`account-view:2`、`account-entry:2` 与所需方法；语言硬编码候选暂缓至原版英文客户端处理；2026-10-16 矩阵接入另检查account-surface-budget:2及实际方法 |
| YiboMail | 13；action.todo 提醒 11 | RequiredDeps | 当前1.2.16-api1；API13初次接入时的基础业务要求 localization:1、business-services:1、character-name-format:1、basic-input:1、item-resolver:1、item-picker:2、character-identity:1、characters:1、character-cleanup:1、account-view:2、account-character-admission:1、account-surface-budget:1、account-entry:2；邮件目标操作要求 business-item-actions:1；action.todo 新邮件提醒单独要求 business-providers:1，不足仅停止对应可选功能 |
| YiboMounts | 13（可选 Core 设置／语言增强） | OptionalDeps | 1.0.0：Core v6 设置面板与 API13 localization:1；Core 缺失或不兼容时来源 Tooltip 独立运行，见 Core-API13-接入说明 |
| YiboQuestBlocker | 13；localization:1、character-name-format:1、basic-input:1、account-view:2、account-entry:2 | RequiredDeps | 当前源码3.1.1；版本不足时提示升级并停止初始化 ；2026-10-16本轮矩阵接入另检查account-surface-budget:2及实际方法 |
| YiboReputation | 13（最低 Core1.12.4） | RequiredDeps | 当前源码1.7.2；localization:1、account-view:2、account-surface-budget:2、data-domains:1、events:1、basic-input:1、character-name-format:1、character-identity:1、character-cleanup:1；迁移检查 GetDefinitions 与停采集状态；目标增强另检查 API12 / business-item-actions:1、business-providers:1、character-identity:1 |
| YiboTaskHub | 13 | RequiredDeps | 工作树 0.6.0；语言与入口最低 API13，跨业务能力仍按各自能力版本检查；当前验收完成 |
| YiboTodo | 13 | RequiredDeps | 当前源码1.2.1；已检查 localization:1、account-view:2、character-identity:1、character-name-format:1、account-entry:2；语言硬编码候选待原版英文客户端处理 |
| YiboVault | 13（基础Core1.12.0起） | RequiredDeps | 当前源码1.2.3-api1；localization:1、business-services:1、character-name-format:1、basic-input:1、item-resolver:1、character-identity:1、account-entry:2；初始化逐项检查版本与所需方法 |

源码依据：各插件 Bootstrap、Namespace 或 CoreIntegration，及各自根目录 TOC。强依赖插件仍须按实际所需 API／能力检查，不能统一把最低版本改成 10；业务提供方缺失与 Core 版本不足是两种不同的失败路径。

## CAP-001：公共名称格式化

### Core 当前状态与边界

- 已有 [Characters:GetDisplayName](../Data/Characters.lua)：`short` 读取以角色 ID 保存的短名，其余模式返回原始角色名。现有 `full` **不包含服务器**，必须保留该接口的兼容语义。
- 已提供 `Characters:FormatName(identity, options)`，能力声明为 `character-name-format:1`。
ameMode=original/short` 与 `realmMode=omit/sameRealm/full` 独立选择；同服参照服务器必须由调用方明确提供。正式契约见 [API v8 公共名称格式化](API-v8-公共名称格式化.md)。
- [共享角色表头](../UI/Theme.lua) 已接入新接口；保留业务传入名称／服务器的覆盖优先级、两段布局、旧 full 名称模式、真实身份悬停与状态提示，不要求旧业务插件改动调用或提高最低版本。
- 目录外联系人可直接提供 `{name, realm}` 格式化，不建立角色目录记录；短名只按明确提供的 Core 角色 ID 读取。联系人备注、职业色、WoW 文本转义、地址解析与业务操作仍归调用方。
- Core 内部已覆盖范围：[Theme](../UI/Theme.lua) 的表头、身份悬停与宽度测量；[角色档案字段](../Data/Fields/CharacterArchive.lua)；[角色档案删除确认](../UI/AccountPages/CharacterArchive.lua)；[设置工作台](../UI/AccountPages/SettingsWorkbench.lua) 的排序、短名管理身份标签。身份键、业务地址与短名存档结构未改动。
- 旧接口说明：[角色短名与统一服务器切换实施方案](Core-角色短名与统一服务器切换实施方案.md)。实施源码版本为 Core 1.7.0 / API v8（尚未上传发布渠道）。2026-10-07 验证通过：[CharacterNamesSpec](../_NonRelease/Tests/CharacterNamesSpec.lua) 75 项检查、Core TOC 的 44 个 Lua 5.1 文件语法检查、现有 Currency CoreItemControlsSpec 回归。游戏内 Core 档案／设置与旧业务主窗口／预览仍待核对。

### 业务插件接入表

首次登记为 2026-10-07；以下 14 项于 2026-10-08 静态复核。共享表头在 Core 内部已接入，业务仍须分别核对调用、最低要求与实际行为。名称测试的历史通过不代替本轮验证，见 AUD-009。

| 插件 | 状态 | 已有路径与证据 | 剩余范围 / 后续触发 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（适用代码完成，客户端验收完成） | Core API13 / character-name-format:1；主矩阵、转置及副本角色行／测量／行动统一 Core FormatName，经唯一ID与轻量身份读取 | 历史原生文本保留；短名及跨服实机验收完成，见 AltoBoss/Docs/Core-API13-完整接入.md / 2026-10-14；客户端验收完成：用户确认 2026-10-16 |
| YiboAutoOpen | 不适用 | [加载清单](../../YiboAutoOpen/YiboAutoOpen.toc) 与设置／队列代码未发现账号角色或联系人的名称显示需求 | 新增相应显示需求时重审；物品别名不属于角色短名 |
| YiboBeastPaths | 既有路线不适用；离线兽栏待接入 | [加载清单](../../YiboBeastPaths/YiboBeastPaths.toc)及路线维护以路线、宠物和坐标为对象；R3仅验证测试owner的角色短名／服务器格式化，未改YBP调用 | 既有客户端确认2026-10-16；新增角色显示按[R3支持契约](API-v13-YBP离线兽栏公共支持契约.md)接入；最近审查2026-10-27 |
| YiboBuilds | 部分接入（代码／离线通过，客户端验收完成） | 主表角色行与预览CharacterLabel统一调用FormatName；短名／所有服务器策略复用Core | Core13Spec（1057项）验证单服／全服与短名策略；最低API13 / character-name-format:1；2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboCrafting | 部分接入（代码完成／客户端验收完成） | 1.2.0 / API13；FormatName、共享角色表头、真实身份悬停全部接入，最低能力检查 | CoreNameIntegration／CoreAdaptation；中英文、短名、职业色及全服显示客户端验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboCurrency | 部分接入（适用代码完成／客户端验收完成） | 0.9.1工作树 / API13，检查 character-name-format:1；主矩阵共享表头及货币／库存提示角色标签使用Core格式化，不再本地拼接名称 | API13Spec四组各52项、CharacterNames77项通过；短名／全服／完整身份实机验收完成 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboLegendary | 部分接入（API13 代码完成／客户端验收完成） | 工作树 2.2.0 检查 API13 / `character-name-format:1` 与 FormatName；角色行、行动标题按账号范围格式化，人工确认使用 original/full 身份 | 悬停、列表与完整身份客户端核对待做；名称历史状态不可由自动化或共享表头推定；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboMail | 当前适用范围实机已收口 | 当前工作树 1.2.9-api1 / API13；角色总览与预览复用 FormatName，能力要求见最低版本基线 | 用户2026-10-16确认当前功能实机收口；历史接口、实现观察和兼容边界保留，后续变更按实际范围审查 |
| YiboMounts | 不适用 | [加载清单](../../YiboMounts/YiboMounts.toc) 与图鉴提示／Core 设置适配未发现角色或联系人身份显示 | 新增相应显示需求时重审；坐骑名称与来源格式继续归业务；客户端验收完成：用户确认 2026-10-16 |
| YiboQuestBlocker | 部分接入（代码完成／客户端验收完成） | 工作树 3.1.0：共享表头不再覆盖 Core 格式化；当前角色分组通过 `Characters:FormatName` 使用短名 | 角色短名、同服／跨服表头、职业色和身份 Tooltip 需实机核对；身份 ID 与旧键迁移逻辑保持不变 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboReputation | 部分接入（API13 代码完成，客户端验收完成） | 1.7.1 检查 API13 / `character-name-format:1`；主矩阵、监控预览复用 Core 共享角色表头；遗留当前角色预览显式使用 `FormatName` | 角色短名、同服／跨服提示及职业色客户端验收完成核对；公会名称与公会键仍属公会身份，不作为角色格式化范围 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboTaskHub | 部分接入 | 2026-10-09 0.3.1 主表执行角色／跨角色受益者、悬停角色标题／摘要复用 CreateMatrixHeader／SetCharacterHeader；FormatName short／sameRealm 用于紧凑角色行，详情执行者和跨角色受益者 original／full。显式检查共享方法，359 项回归及 Core 名称 77 项通过 | 修复 0.3.0 普通文本缺少职业色／统一身份提示；紧凑任务行采用共享控件单行模式；游戏内职业色／跨服身份验收完成；客户端验收完成：用户确认 2026-10-16 |
| YiboTodo | 部分接入 | 工作树 1.3.0 检查 API13 / `character-name-format:1`，角色标签使用 `Characters:FormatName` | 本轮涉及标签已迁移；其他可能属于身份提示的用户文本与客户端显示待审查 / 2026-10-12；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboVault | 部分接入（代码完成／客户端验收完成） | [Tooltip.lua](../../YiboVault/Tooltip.lua) 与 [StoragePage.lua](../../YiboVault/StoragePage.lua) 角色显示使用 `Characters:FormatName`；最低 API13 / `character-name-format:1` | 公会显示、容器名称和公会身份键仍由各自逻辑处理；角色显示客户端验收完成核对 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |

### 首次审查注意事项

1. “所选单服范围内省略服务器”与“相对当前登录服务器省略服务器”是两种不同调用语义。Currency、Legendary 等按 `context.scope` 显示；Mail、Vault 部分显示相对当前角色服务器。新契约与迁移须明确参照范围，不能直接用一种替换另一种。
2. Mail 的 `Recipients:Normalize / Key`、收件地址、规则发件人匹配，Core 的旧键别名及稳定角色 ID，均承担身份或操作语义。迁移只替换显示调用，不能向这些数据写入短名或省略服务器后的显示文本。
3. Mail 的 CacheModel / HistoryModel 已把短名加入搜索文本；它们是检索输入，不是身份标签。后续显示迁移时检查检索一致性，不能机械替换成单一格式化字符串。
4. 共享表头收到 `options.name` 时会覆盖默认短名；QuestBlocker、Currency 当前存在此路径。完成 Core 实现后仍需逐业务核对，不能据共享表头调用将它们记为已接入。

## CAP-002：基础输入

接口与首批验证记录见 [API v7 物品选择与基础输入](API-v7-物品选择与基础输入.md)。Core 入口为 [Theme:CreateInput](../UI/Input.lua)。

首次登记为 2026-10-07；以下条目于 2026-10-08 静态复核。输入控件专项历史验证本轮未重跑；最低版本按上方基线更新。

| 插件 | 状态 | 已覆盖 / 证据 | 剩余范围与接入版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（适用代码完成，客户端验收完成） | API13 / basic-input:1 / level-filter:1；NPC与小时上限使用 CreateInput，等级表达式委托Core，旧重复过滤面板及解析已清理 | 中文输入法、失焦／提交及英文布局验收完成 / 2026-10-14；客户端验收完成：用户确认 2026-10-16 |
| YiboAutoOpen | 当前功能已实机收口 | 历史实现观察保留：[Settings.lua](../../YiboAutoOpen/Settings.lua) 中空位、物品、确认来源和别名输入均本地创建 | 用户2026-10-16确认；独立运行与OptionalDeps边界继续有效，后续变更按实际Core能力复核 |
| YiboBeastPaths | 部分接入（适用调用代码完成／客户端验收完成） | 1.7.0 Core 维护页多行导出迁移 CreateInput，最低 API13 / basic-input:1；不限长度、换行、IME／焦点生命周期；旧独立 DebugCalibrator 布局不由 Core 页面构建 | Core13IntegrationSpec 与双语 CoreDebugViewSmoke 通过，长文本复制与 IME 客户端验收完成，见 [接入说明](../../YiboBeastPaths/Docs/Core-API13-接入说明.md) / 2026-10-13；客户端验收完成：用户确认 2026-10-16 |
| YiboBuilds | 不适用 | 当前账号页面与设置接入代码未发现本地 EditBox | 新增输入时使用公共控件；无接入版本；客户端验收完成：用户确认 2026-10-16 |
| YiboCrafting | 部分接入（代码完成／客户端验收完成） | 1.2.0 搜索使用 CreateInput 的 OnChanged／OnSubmit／OnFocus 与共享清空，保留 Core IME／隐藏生命周期；API13 / basic-input:1 | 真实 Input 模块与 IME 合成回归通过，AUD-012 代码关闭；实际输入客户端验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboCurrency | 已接入（所列范围） | 0.9.1工作树 / API13；自定义选择器复用公共输入，检查basic-input:1及实际方法 | 中文／英文CoreItemControlsSpec通过；游戏内输入与布局验收完成 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboLegendary | 不适用 | 当前业务页与业务设置未发现本地 EditBox | 新增输入时使用公共控件；无接入版本；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboMail | 当前适用范围实机已收口 | 当前工作树 1.2.9-api1 / API13；Core 托管设置中的适用输入接入 basic-input:1 | 用户2026-10-16确认当前功能实机收口；历史接口、实现观察和兼容边界保留，后续变更按实际范围审查 |
| YiboMounts | 不适用 | 图鉴及 Core 设置适配未发现本地 EditBox | 新增输入时使用公共控件；无接入版本；客户端验收完成：用户确认 2026-10-16 |
| YiboQuestBlocker | 部分接入（代码完成／客户端验收完成） | 工作树 3.1.0：等级表达式与数字任务 ID 使用 Core `CreateInput`；检查 `basic-input:1` | 任务 ID 校验和等级表达式规则仍归业务；IME 输入法、回车提交与焦点生命周期客户端验收完成核对 / API13 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboReputation | 部分接入（API13 代码完成，客户端验收完成） | 1.7.1 矩阵搜索使用 `Theme:CreateInput`，检查 `basic-input:1`；保留输入值、清空按钮并复用 IME 处理 | 中文输入法合成、清空／焦点及英文布局客户端验收完成核对 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboTaskHub | 部分接入（本轮范围） | 2026-10-10 0.4.0 TargetsPage 的搜索使用 CreateInput(clearable=true)，复用清空与 IME 处理；检查 API11 / basic-input:1 及方法；BossTargetsSpec 覆盖缺失能力停止和真实标签页操作 | 新增输入均已收拢，中文输入法与客户端布局验收完成；无物品选择需求；客户端验收完成：用户确认 2026-10-16 |
| YiboTodo | 不适用 | 当前待办设置与页面未发现本地 EditBox | 新增输入时使用公共控件；无接入版本；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboVault | 部分接入（适用输入已收拢） | [StoragePage.lua](../../YiboVault/StoragePage.lua) 搜索与 [AccountPage.lua](../../YiboVault/AccountPage.lua) 物品过滤均使用 Core `CreateInput`；初始化检查 API13 / `basic-input:1` 和方法 | IME、输入交互及设置布局客户端验收完成验收 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |

## CAP-003：物品解析、选择与操作确认

R1-09（2026-10-27）：物品缓存失败与includeBags读取失败文案分开，公开返回形状与能力版本保持；791项语言／失败专项及ItemControls通过，客户端新提示待验。单项item-picker:1兼容，批量需item-picker:2；见[当前契约](API-v13-R1共享底座兼容与失败契约.md)。

公共契约与验证依据同 [API v7 文档](API-v7-物品选择与基础输入.md)。业务保存、执行、物品准入与风险文案由消费方提供；不是所有物品展示或扫描都需要选择器。

初次审查为 2026-10-07；以下条目于 2026-10-08 静态复核。状态只覆盖所述功能；Smoke／控件专项等此前通过记录为历史证据，本轮重跑范围见审查边界。

| 插件 | 状态 | 已覆盖 / 证据 | 剩余范围与接入版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（确认代码完成，客户端验收完成） | API13 Core.ItemConfirmation；目标移除位于数据区末尾，复核目标并在隐藏时取消 | NPC非物品，物品解析／选择不适用；确认／取消／切页验收完成 / 2026-10-14；客户端验收完成：用户确认 2026-10-16 |
| YiboAutoOpen | 当前功能已实机收口 | 历史实现观察保留：[ItemResolver.lua](../../YiboAutoOpen/ItemResolver.lua) 本地解析物品 ID／链接／名字；设置仍有本地输入 | 用户2026-10-16确认；独立运行与OptionalDeps边界继续有效，后续变更按实际Core能力复核 |
| YiboBeastPaths | 不适用 | 路线维护以坐标和路线数据为输入 | 无物品录入迁移项；客户端验收完成：用户确认 2026-10-16 |
| YiboBuilds | 不适用 | 当前构筑页面读取装备／配方数据，未发现可直接替换的物品输入选择器 | 业务动作与装备应用不自动纳入此项；客户端验收完成：用户确认 2026-10-16 |
| YiboCrafting | 部分接入（适用展示代码完成） | 1.2.0 / API13 / item-resolver:1；资料经 GetInfo，搜索只读已缓存项，事件去重；无物品编辑／批量确认／图标选择需求 | SearchPerformance／Smoke 通过；Tooltip 与实际搜索性能客户端验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboCurrency | 已接入（所列范围） | 0.9.1工作树 / API13；Settings复用CreateItemPicker、ItemResolver与ItemConfirmation，删除位于数据区末尾 | 中英文CoreItemControlsSpec通过；游戏内验收完成 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboLegendary | 不适用 | 人工目标确认不是物品身份选择 | 不为统一形式改造成物品确认器；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboMail | 既有范围实机收口；1.2.25退信确认部分接入（确认／取消实机通过，生命周期与缺方法待验） | 附件解析及规则物品选择沿用原公开接口；1.2.25-api1 MoP单封／批量退信新增Core.ItemConfirmation:Show，隐藏／关闭取消句柄，确认后复核选择、邮箱generation及全部可见邮件；初始化检查最低API13与Show方法。ReturnUISpec及InboxReleaseSpec覆盖确认／取消和缺方法升级停止 | 既有范围用户2026-10-16确认；2026-10-22用户确认普通单封／批量、二次确认／取消、金币／COD退信及退回内容通过；AH取消上架、按钮置灰、混选及收取通过。隐藏关闭／缺方法提示等专项仍待实机，详见[方案与验收](../../YiboMail/Docs/Mists-单封与批量退信方案与验收.md)。Forever未接入操作 |
| YiboMounts | 不适用 | 当前图鉴读取坐骑／物品来源，未提供通用物品录入 | 展示与来源查询不自动替换成选择器；客户端验收完成：用户确认 2026-10-16 |
| YiboQuestBlocker | 不适用 | 手动输入任务 ID | 校验与操作归任务业务；客户端验收完成：用户确认 2026-10-16 |
| YiboReputation | 不适用 | 搜索声望目录，未发现通用物品身份录入 | 声望搜索不属于物品解析；客户端验收完成：用户确认 2026-10-16 |
| YiboTaskHub | 部分接入 | 2026-10-09 0.3.1 的 Presentation 为三展示面使用 ItemResolver:GetInfo／Request 加载 item.itemID 图标；显式检查 API11 / item-resolver:1 和方法；来源 icon 直接渲染，缺失时通用任务图标 | OverviewSpec 包含一次请求、加载完成、非法元数据与缺能力停止；共 359 项回归通过，游戏内图标与加载效果验收完成；后续编辑器仍需重新评估控件；客户端验收完成：用户确认 2026-10-16 |
| YiboTodo | 不适用 | 当前配置选择活动／目标，未发现通用物品身份录入 | 活动 ID 与业务条件不属于物品解析；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboVault | 部分接入（展示及本轮MoP原生链接解析代码完成） | StoragePage 格子复用 `item-resolver:1` 加载展示；2026-10-22 Mists/Collector缺itemID时使用Parse，Common/CoreIntegration检查API13、能力及Parse／GetInfo／Request | 新解析及缺Parse停止专项、双端与覆盖模拟通过，新增路径实机待验；无损variantKey由业务记录格式保留，详见拆分验收。旧展示用户2026-10-16确认范围保留，未触及解析调用继续按后续修改审查 / 2026-10-22 |

## CAP-004：账号页面、入口与设置接入基线

R2 Retail（2026-10-27）：共享窗口／入口／设置代码已接入Retail0.1.0；用户确认/yco及各页正常，当前仅身份／等级两字段。真实宿主、战斗、边界与完整三通道验收待补；既有消费者未变，见[本阶段记录](R2-01-02-Retail目标与构建实施验收.md)。

R1-09（2026-10-27）：About状态／版本区域以会话资源完整插值，明确未安装、状态不可读、版本未知和仅注册；布局／接口不变。新增双语路径离线通过、实机待验，见[收尾记录](R1-09-文案与契约文档收尾验收.md)。

R1-08复核（2026-10-27）：注册／冲突语义保持；页面注销关闭本页预览并清除旧实例槽，新注册执行新的Create。465项双目标契约专项覆盖同源预览、范围、分页与只读缓存；新增生命周期实机待验，见[本阶段记录](R1-07-08-目标元数据与通用契约实施验收.md)。

2026-10-18：Core 升至 1.12.7 / API 13，修正 `HandleEntryClick` 的业务入口右键路由，Core 入口仍打开“显示与入口”，业务 Broker／小地图／内置条直接打开其解析后业务页面对应的 Core 设置项；左键行为不变。无需新增能力版本或业务插件本地接入。契约见 [三通道入口与内置条](API-v13-入口三通道与内置条.md)。

2026-10-13：Core 1.12.1 / API13 工作树新增 `account-preview-characters:1`，公开页面字段 `previewCharacterLimit`，默认20名兼容、false保留全部准入角色。契约见 [悬停角色范围](API-v13-悬停角色范围.md)。消费者按技术名：YiboMail 1.2.13 已接入代码，显式检查能力；WorkspaceSpec 验证24角色跨服务器、末位仓库角色、旧默认与显式数量，中英文1／4／18／24行含提醒／无提醒完整尺寸与受限滚动、缺失能力停止。客户端仍待验收，记部分接入；其它业务插件新字段待评估，默认行为保持。CAP-001 本轮服务器名称继续复用 FormatName，以选中范围为参考；CAP-002 原生输入未改、CAP-003 附件解析未改、CAP-005 队列通知未改、CAP-006 无新增引导、CAP-007 既有 identityOnly 保持、CAP-008 既有目标绑定保持，无新增本地公共能力实现。

2026-10-11：Core 工作树 API13 新增 [三通道入口与内置条契约](API-v13-入口三通道与内置条.md)，起始提供 account-entry:2 / builtin-entry-bar:2、schema11；后续 `builtin-entry-bar` 已向后兼容升至 v3，见 2026-10-12 更新。旧 RegisterBusinessEntry/defaultMode/legacyIDs 兼容，不提高未改业务插件最低版本。Core 的小地图／Broker／内置条及设置已统一接入，1156项入口／布局专项与相关回归通过；真实业务客户端验收待完成，各插件下表状态不因此变更。没有新增业务本地实现，后续主动消费新 API 时检查 API13 及所需能力。最近审查 2026-10-12；证据见实施记录。

2026-10-09 0.3.0 收拢：AccountPage 新来源／状态下拉全部使用 UITheme:CreateDropdown；预览继续消费可用高度预算；HUD／登录列表入口使用 SetPageScope 与 ShowPage 回到全服第一页。新增 OverviewSpec 验证折叠／展开、筛选、行池按钮及入口重置；无新增 Core 接口。用户 0.2.1 截图证实上一轮修复生效，本轮 UI 仍待验收，见 [收拢记录](../../Docs/行动中心-概念图收拢与流程修正.md)。

2026-10-09 O4／O5 联合复核增加 [视图可用高度](API-v11-视图可用高度.md)：Core 1.10.0 / API v11 / account-surface-budget:1，主页面与悬停在测量前提供高度预算，原有页面行为兼容。TaskHub 0.2.1 显式检查并直接消费；SurfacesSpec 现为 95 项，含真实 Core 测量、压缩后尺寸与缺能力停止。用户 0.2.0 截图已定位问题，修复后仍待客户端验收；其余业务页未触及。

2026-10-09 O4 按真实需求补齐 [角色准入通知](API-v11-角色准入通知.md)：Core 1.10.0 / API v11 / account-character-admission:1，隐藏及默认页面等级筛选有效变化后发出隔离事件。TaskHub 为首个消费者；无改动和无效输入不通知，订阅可清理。SurfacesSpec 追加 86 项检查包含实际 AccountView 路径，游戏内尚未验收。

已有公开接口见 [API v5](API-v5-业务插件接入指南.md)、[API v6](API-v6-业务插件增量接入指南.md) 与 [统一协作计划](Core-0.3-统一协作与改造计划.md)。下表登记源码路径，**不是运行时验收表**；存在注册路径统一记为部分接入，待验证实际行为和遗留分支后才能关闭本条目。2026-10-08 已静态复核；首次发布版本未逐一追溯。首次提示增量独立记录于 CAP-006。

| 插件 | 状态 | 已有接入与证据 | 剩余核对范围 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（适用代码完成，客户端验收完成） | API13 / account-view:2 / account-entry:2；仅Core设置／账号页／入口；固定副本选择接入account-preview-field-groups:1；独立设置壳、旧窗口及小地图接口已移除 | 旧SavedVariables字段保留而不读取；双语布局及入口组合验收完成 / 2026-10-14；客户端验收完成：用户确认 2026-10-16 |
| YiboAutoOpen | 当前功能已实机收口 | [CoreIntegration.lua](../../YiboAutoOpen/CoreIntegration.lua) 检查 API13、`localization:1` 与设置 UI 后可选注册统一业务设置；基础队列独立运行 | 用户2026-10-16确认现有功能验收；Core可选设置要求API13／localization:1，发行状态待核对 |
| YiboBeastPaths | 部分接入（既有维护页实机完成）；离线兽栏待接入 | Mists可选维护页与统一业务设置最低API13，检查account-view:2／account-surface-budget:1；既有范围无账号入口。R3固定兽栏的v2预算／准入／三通道支持，未修改YBP最低要求或调用 | 原494项及双语UI／客户端确认2026-10-16保留；R3三目标2463项仅为合成消费者证据，真实兽栏页／入口／预览待实施；最近审查2026-10-27 |
| YiboBuilds | 部分接入（代码／离线通过，客户端验收完成） | API13统一页面与三通道入口；设置元数据双语，预览字段副本及ID校验；没有独立业务设置面板 | Core13Spec验证能力不足停止与重复注册；最低API13 / account-view:2 / account-entry:2；2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboCrafting | 部分接入（代码完成／客户端验收完成） | 1.2.0 / API13；统一账号页、共享矩阵视觉／滚动／分页、嵌入设置、三通道注册和同快照预览；按业务快照准入和高度预算投影 | CoreAdaptation 通过；实际入口／字段／安全边界客户端验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboCurrency | 部分接入（适用代码完成／客户端验收完成） | 0.9.1工作树 / Core1.12.4工作树 / API13，检查account-dynamic-fields:1、account-entry:2、account-preview-field-groups:1及表面／准入能力；自有目录动态字段注册、档案金币Provider、previewColumns、同源矩阵及可选悬停转置、统一工作台、三通道默认关闭 | 旧选择保留、动态增删、主表／悬停一致性：API13Spec四组各52项及EntryBar1133项通过；真实客户端验收完成 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboLegendary | 部分接入（API13 代码完成／客户端验收完成） | 工作树 2.2.0 检查 `account-view:2`、`account-entry:2`，注册本地化页面与 Core 业务设置，三入口默认关闭 | 核对悬停角色范围、完整矩阵、设置与三入口开关；本轮最低版本升至 API13；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboMail | 当前适用范围实机已收口 | [AccountPage.lua](../../YiboMail/AccountPage.lua) 注册页面、入口与业务设置 | 用户2026-10-16确认现有账号页、入口、设置与邮件功能收口；当前版本发行待核对 |
| YiboMounts | 部分接入（可选设置增强） | 1.0.0 检查 Core API13、初始化状态与 `localization:1`，注册 Locale 资源和 v6 设置面板；TOC 使用 `OptionalDeps: YiboCore` 保证加载顺序，未转为硬依赖 | Core 缺失／低版本时保留独立来源 Tooltip，停用收藏状态与 Core 设置；游戏内注册、设置保存和 Core 缺失／旧版路径验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboQuestBlocker | 部分接入（API13 代码完成／客户端验收完成） | 工作树 3.1.0 检查 API13、`account-view:2` 与 `account-entry:2`；页面注册预览字段；Broker、小地图、内置信息条入口首次均关闭；业务设置仍交给 Core 工作台托管 | 核对账号页与悬停快照／准入／筛选一致性、字段可见性、三入口独立开关／右键设置路由、设置保存与安全高度；未消费的 `account-surface-budget:1` 不列为依赖 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboReputation | 部分接入（API13 代码完成，客户端验收完成） | 1.7.1 检查 `account-view:2`、`account-surface-budget:1` 与页面所需方法；保留 Core 统一页面、入口、设置、悬停预览和 20 角色默认范围 | 英文入口／布局与页面尺寸客户端验收完成验收；声望由 Reputation 自有 Store 提供；旧 Core 只用于导入，角色删除接入 CharacterCleanup，87 项专项通过 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboTaskHub | 部分接入 | 0.5.0 检查 API13 / account-entry:2、builtin-entry-bar:1，RegisterBusinessEntry 通过 defaultChannels 明确三个入口默认关闭；保留 Core 对用户选择的统一管理 | ActionIntegrationSpec 检查最低 API 与默认值；客户端验证三个通道切换、悬停与页面跳转待做；旧截图不替代新编辑器、窄窗口、IME 和完整登录流程验收；客户端验收完成：用户确认 2026-10-16 |
| YiboTodo | 部分接入 | 工作树 1.3.0 整体最低 API13；检查 `account-view:2`、`character-identity:1`、`character-name-format:1`、`account-entry:2`、`localization:1`；入口显式默认关闭三个通道 | Core 注册、设置与低版本停止验收完成证；首次提示独立见 CAP-006；中英文与三个入口通道待客户端验收 / 2026-10-12；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboVault | 部分接入（适用接口代码完成） | [AccountPage.lua](../../YiboVault/AccountPage.lua) 注册账号页、Core 业务设置及 `account-entry:2` 三通道入口；默认通道均关闭，最低 API13 | 账号页、入口通道与统一设置工作台行为客户端验收完成验收；固定仓储页面由 Core 统一页面容器处理，不消费动态高度预算 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |

### CAP-004 增量：统一滚动表面预算（2026-10-16）

Core1.12.6 / API13未发布工作树提供account-surface-budget:2，[契约](API-v13-滚动表面预算.md)。Core按最终主窗口／入口悬停高度统一决定槽宽、向上取整及自然宽度优先，业务声明scrollContentHeight／scrollFixedHeight并通过GetScrollSurfaceWidth读取最终可用宽度。业务不再手工加减滚动槽；v1兼容。公共预算与账号页面本轮完成验证，不等于所有业务已迁移。

| 插件／区域（技术名排序） | 本轮状态／剩余范围 | 证据与触发点 |
| --- | --- | --- |
| YiboAltoBoss账号矩阵／锁定矩阵 | 已接入（2.7.1工作树；本轮范围离线通过，用户实机确认）；要求预算2及实际方法，主表两方向声明，锁定矩阵使用Core滚动容器 | MatrixBudget四组各100项、InstanceKills56；用户已确认本轮实机检查无问题；2026-10-16 |
| YiboCrafting账号／悬停矩阵 | 已接入（1.2.1工作树；本轮范围离线通过，用户实机确认）；预算2、分组／筛选计划与快照复用、显式悬停声明；专业多面板详情不套单矩阵预算 | MatrixBudget四组各100项，CoreAdaptation／CoreNameIntegration／Smoke／SearchPerformance／采集与目标回归；2026-10-16 |
| YiboCurrency主表／两种悬停 | 已接入（0.9.2工作树；本轮范围离线通过，用户实机确认）；显式要求预算2，取消本地槽宽计算 | 四组API13各52、Core预算10项及完整迁移回归；2026-10-16 |
| YiboLegendary目标列预览 | 已接入（2.2.3工作树；本轮范围离线通过，用户实机确认）；实际为角色行／目标列，预算2、图例固定高度、完整目标宽度及Core目标切片；升级检查已补 | MatrixBudget四组各100项含实际预览渲染、窄屏切片、字段隐藏与缺方法拒绝；2026-10-16 |
| YiboQuestBlocker主表／悬停 | 已接入（3.1.1工作树；本轮范围离线通过，用户实机确认）；要求预算2，完整角色范围任务分组与空态高度、Core宽度及悬停声明；隐藏角色字段无空页 | MatrixBudget四组各100项含实际主表／悬停、分组与分页一致及旧预算拒绝；2026-10-16 |
| YiboReputation主矩阵 | 已接入（1.7.2工作树；本轮范围离线通过，用户实机确认）；显式要求预算2，取消本地rows>20补槽，完整范围行发现后再切角色列 | 88+39迁移／清理、HoverSpec；用户已确认本轮实机检查无问题；2026-10-16 |
| YiboReputation监控预览 | 本次滚动槽不适用：独立布局声明verticalOverflow=none，没有纵向ScrollFrame | 保留既有分页和悬停检查，不预留空槽 |

Mail缓存／规则／原生界面的滚动槽调用属于独立内嵌列表，不是账号窗口自然宽度，不能直接套用窗口预算；后续触及这些独立容器时再评估适用的Core布局工具。Mail／Vault／Todo／TaskHub等页面本轮仅发现固定／行向或压缩布局，未做新预算的逐回调验收，保持待评估，不登记已接入。Core档案为字段列投影，不在本次角色列分页迁移范围。

CoreScrollBudget10、EntryBar1133、Contracts90、CharacterNames77与84文件语法及三owner语言检查通过。TaskHub旧SurfacesSpec前置Todo语言夹具失败，记录在契约中，不宣称整体通过。此次无运行时版本更新、提交、推送或打包。业务数据归属没有变化。

2026-10-16验收与版本补记：用户反馈“已实机看过没问题”，以上六插件本轮矩阵预算范围记为已接入；不扩展为其它功能或全部语言组合均已验收。配套工作树版本为Core1.12.6、AltoBoss2.7.1、Crafting1.2.1、Currency0.9.2、Legendary2.2.3、QuestBlocker3.1.1、Reputation1.7.2；API13及预算能力2不变，尚未提交、推送或打包发布。

## CAP-005：通用跨业务能力连接

R1-08复核（2026-10-27）：同方法引用重入、版本／方法变化拒绝、服务冲突、Provider聚合、晚发现和注销后的旧descriptor均按原契约验证；未新增Service或业务接入。见[本阶段记录](R1-07-08-目标元数据与通用契约实施验收.md)。

2026-10-09 0.3.0 收拢：action.todo v1.0 增加可选 icon 显示元数据，Mail 1.2.5-api1 从自己附件快照提供纹理；中心验证并通用渲染，不按提供方技术名分支。MailSourceSpec 56 项、OverviewSpec 43 项，连同原集成与展示共 327 项。折叠只改变投影，保留所有原始身份、数量与业务引用。

2026-10-09 联合复核：Mail 1.2.4-api1 对 Schedule 的快照失效和同内容成功扫描的恢复发布已有 Items 事实，再由既有 action.todo Provider 合并通知。查询仍只读，不改变契约版本；TASK 通用消费，无来源分支。MailSourceSpec 55 项，连同展示及原集成共 283 项通过；邮件运行／启动／原生界面／API 回归通过。原始缺陷截图与修复后待验收项见 [联合记录](../../Docs/行动中心-O4-O5-联合验收与修复.md)。

### Core 状态与边界

- 初次设计时状态为待实现。2026-10-08 初次静态核对 [Registry](../Runtime/Registry.lua)、[Events](../Runtime/Events.lua)、[Capabilities](../Runtime/Capabilities.lua) 与 [Bootstrap](../Bootstrap.lua)：当时 Core 1.7.1 / API v8 没有跨业务 Service／Provider 调用接口。
- 真实需求为独立行动中心的需求下发、业务待办和角色工作流聚合；Core 只提供连接与生命周期，不接管中心、库存、配方或邮件数据。
- 当前契约：[API v9](API-v9-业务服务与刷新.md)。实现阶段 Core 1.8.0 起提供 Core.Contracts 的最小 Service 注册、发现、隔离调用和注销，能力为 business-services:1；未独立发布 api9，随 v1.9.0-api10 发起发布。本轮已登记 RuntimePerformanceSpec、MailProviderSpec、VaultIntegrationSpec、InboxReleaseSpec 通过；业务接入仍在工作树，游戏内待验收。
- 2026-10-09 工作树已提供 [API v11](API-v11-跨业务Provider.md) / `business-providers:1`；O2 已接入 Todo 首项 action.todo 输出与 TaskHub 消费，ContractsSpec 90 项、集成 70 项与相关回归通过。未发布、客户端待验收，草案 business-contracts:1 不作为实际能力检查。
- 实施范围为真实需要的最小连接、输入输出隔离、冲突、版本、晚注册、注销与通用事件；旧业务调用在涉及范围内逐步接入，既有 Core UI API 行为保持兼容。

### 业务接入台账

以下既有业务接入范围审查日期为 2026-10-08；2026-10-09 更新 Core Provider 实现和 Todo／TaskHub 下一步范围。Mail／Vault／Currency 的既有库存协作已接入最小 Service，最低 API v9，新回归通过不代表新增 Provider 已接入；其余业务状态不因 Core 扩展改变。

| 插件技术名 | 接入状态 | 已覆盖及证据 | 剩余范围与版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（运行代码与自动化完成） | 2026-10-10 2.6.0 经 Core 提供 boss.target-catalog 与 action.todo / planned-targets，消费 task.boss-targets；奖励观察、精确副本／难度、旧目录稳定键及自动投影均由来源负责，136项联动检查通过 | 基础 API13 / localization:1；目标能力继续要求 business-services:1 / business-providers:1，五人本 DBM 可选桥接复用 events:1 与 character-identity:1；客户端映射、窗口、切号及重置验收完成；客户端验收完成：用户确认 2026-10-16 |
| YiboAutoOpen | 待评估 | 无该新连接接入证据 | 真实协作出现时评估，独立开包功能不因此扩展 |
| YiboBeastPaths | 不适用（当前范围） | 路线工具无跨业务查询、聚合或操作；Core 就绪通知复用公开 CORE_READY | 1.7.0 源码审查无业务对象／SavedVariables 读取；真实协作出现时重审 / 2026-10-13；客户端验收完成：用户确认 2026-10-16 |
| YiboBuilds | 部分接入（代码／离线通过，客户端验收完成） | action.targets Provider为构筑所有者提供具体装备强化目标，Core负责发现与操作绑定 | 既有实际应用判断保持；双语标题与错误；最低API13 / business-providers:1 / business-item-actions:1；安全点击客户端验收完成验收；2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboCrafting | 部分接入（当前连接代码完成） | 1.2.0 / API13；action.targets v1.2 注册／发现／公开库存调用，生命周期通知；制造规则与基线归来源，无业务私有访问 | GoalSourcesSpec72／GoalTargets 通过，尊重公开库存 validUntil；可选来源客户端验收完成，配方只读 Service 是后续产品功能 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboCurrency | 已接入（本轮连接范围，客户端验收完成） | 0.9.1工作树 / API13 / business-services:1、business-providers:1、character-archive-providers:1；vault.items经Resolve／Call，TOC无业务依赖，缺失／注销／不兼容／错误回退确认来源，返回覆盖校验 | VaultIntegrationSpec原样通过（已补身份夹具及生命周期回归）；货币权威迁移代码完成，实机验收完成；整角色Vault单一来源或自有随身快照，无旧Core运行读 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboLegendary | 待评估 | 无该新连接接入证据 | 真实待办／目标接入时评估；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboMail | 部分接入（Provider代码与自动化完成／客户端待验收） | 1.2.11-api1：既有mail.items v1.1 GetTransfers按全账号签名／时间证据索引匹配，纯状态复用缓存且公共revision保持最新；自动查看多封信合并通知。邮件与新邮件查看状态仍由Mail所有，Vault仅经Core Service消费 | 基础API13 / business-services:1；TransfersPerformanceSpec 20角色／3411历史约0.04秒（旧约0.73秒），100封确认1次通知；MailProviderSpec真实服务集成与缺失／不兼容／晚注册通过。客户端仍待复验；logistics／evidence仍未公开 / 2026-10-12 |
| YiboMounts | 不适用 | 1.0.0 全面接入复核：Tooltip 图鉴只读取自身坐骑目录与 Core 账号级设置，无跨业务查询、提供或聚合需求 | 出现真实跨业务需求时按 Service／Provider 契约评估 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboQuestBlocker | 待评估 | 无该新连接接入证据 | 不把阻止接任务当成任务数据能力；真实需求出现再评估；客户端验收完成：用户确认 2026-10-16 |
| YiboReputation | 部分接入（目标 Provider 已接入，客户端验收完成） | 1.7.1 通过 Core.Contracts 注册 action.targets v1.1；Normalize／Evaluate 读取插件自有声望快照，未知友谊等级不回退普通 standingID；迁移专项覆盖已知／未知／采集错误目标判断 | 目标增强 API12 / business-providers:1、business-item-actions:1；总体最低 Core1.12.4 / API13；可选消费者与客户端继续验收 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboTaskHub | 部分接入（运行代码与自动化完成） | 2026-10-10 0.4.0 通用消费 Todo 全量／Mail／AltoBoss action.todo，并提供 task.boss-targets、消费 boss.target-catalog；计划由 Task 保存，逐角色双向复制通过 Service 协作，schema3 迁移；672项检查通过 | API11 / business-services:1 / business-providers:1；本轮仅实现刷取计划安排，通用跨角色制作／任务链未实现；客户端验收完成，见 [运行契约](../../Docs/行动中心-AltoBoss-运行契约与验收.md)；客户端验收完成：用户确认 2026-10-16 |
| YiboTodo | 部分接入（运行代码与自动化完成） | 2026-10-09 1.1.4 注册神纹布与诺米 action.todo，独立 epoch／revision／覆盖与合并通知，持久元数据分开；实际模型及 133 项集成、日常／冷却／动作／旧日常回归通过 | 新集成 API v11 / business-providers:1；基础 UI 保留 API v10。游戏内观察、交付／重置与中心一致性验收完成；当前已扩展至全部适用监控项目，见下方 2026-10-09 全量接入复核；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboVault | 部分接入 | 1.2.1-api1 工作树消费 Mail `mail.items` v1.1 可选转移投影；Query、邮件仓储格与 Tooltip 单独显示在途，且不计入持有小计；vault.items 提升 v1.1 并保持 v1.0 消费兼容；本次未运行自动化 | 插件整体最低 Core API13；Service 仍只需 `business-services:1`。Mail 缺失／v1.0 时保留本地扫描基础行为；客户端联动验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |

行动中心技术名为 YiboTaskHub；2026-10-08 建立项目基础与客户端联接，2026-10-09 O2 已完成首项 Provider 消费及 Core 主页／入口，客户端待验收。其他业务能力仍按真实接入分别登记，不能推定全仓库迁移完成。

2026-10-09 O3 增加 Todo 的诺米 Provider；本次实际 diff 触及来源输出／注册／通知和中心状态文本。CAP-005 复用已有公开连接与版本门槛；中心既有主题／名称调用无改动，CAP-001／004 的客户端验证状态不变。没有新增通用输入、物品解析或首次提示调用，CAP-002／003／006 本次不适用。

## CAP-006：页面首次打开提示

### Core 状态与边界

- Core 1.9.0 / API v10 已提供，注册能力为 account-view:2；契约见 [API v10](API-v10-首次打开界面提示.md)。渠道包 v1.9.0-api10 包含 api9，截图为上传中；这不改变 v5 页面注册基础接口的最低要求。
- [AccountView](../UI/AccountView.lua) 读取页面定义 `firstUseTip`；[Theme](../UI/Theme.lua) 提供 ShowFirstUseTooltip；[Database](../Data/Database.lua) 默认保存 firstUseHints。只在主视图成功显示后记录，以 pageID 区分，6 秒自动关闭；预览不触发。Core 概览已使用。
- 业务插件提供提示文案，Core 不解释业务、复制业务缓存或替代必需的状态／风险说明。本轮静态确认调用与版本检查；没有首次提示专项自动化或游戏内验收证据。

### 业务接入表

最近审查：2026-10-08。`不适用` 仅表示当前未注册首次提示，无须为了追赶版本给每页强加提示；后续真实需要时重审。

| 插件技术名 | 状态 | 已覆盖 / 证据 | 剩余范围与版本 |
| --- | --- | --- | --- |
| YiboAltoBoss | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估；客户端验收完成：用户确认 2026-10-16 |
| YiboAutoOpen | 不适用（当前范围） | 可选设置注册无 firstUseTip | 独立功能不因此提高 Core 门槛 |
| YiboBeastPaths | 不适用（当前范围） | 可选维护注册无 firstUseTip | 独立功能不因此提高 Core 门槛；客户端验收完成：用户确认 2026-10-16 |
| YiboBuilds | 部分接入 | CoreIntegration模型旋转／缩放提示已双语；统一API13 / account-view:2启动检查 | Core13Spec正常注册及缺失能力停止通过；一次性显示、预览与计时游戏内验收完成；2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboCrafting | 不适用（已审查） | 1.2.0 状态、搜索和添加提示常显；没有依赖一次性提示的隐藏操作 | 新增首次引导需求再评估 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboCurrency | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估；客户端验收完成：用户确认 2026-10-16 |
| YiboLegendary | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboMail | 不适用（当前范围） | 页面无 firstUseTip | 安全提示继续常显；新增引导时评估 |
| YiboMounts | 不适用（当前范围） | 可选设置注册无 firstUseTip | 独立功能不因此提高 Core 门槛；客户端验收完成：用户确认 2026-10-16 |
| YiboQuestBlocker | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估；客户端验收完成：用户确认 2026-10-16 |
| YiboReputation | 部分接入（API13 代码完成，客户端验收完成） | 1.7.1 提示文案经 Core Locale 注册中英文；整体初始化检查 API13 与 `account-view:2` | 静态资源已检查；低版本升级提示、一次性显示、预览不触发及计时客户端验收完成验收 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboTaskHub | 不适用（O4 范围） | 2026-10-09 主页面及只读展示没有低频操作引导，HUD 拖动／锁定说明在业务设置常显，未登记 firstUseTip | 后续编辑器存在真实引导需求时重新评估；客户端验收完成：用户确认 2026-10-16 |
| YiboTodo | 部分接入 | CoreIntegration 使用 firstUseTip；整体最低 Core API13 并检查 `account-view:2` | 工作树；低版本提示与停止、一次性显示、预览及计时验收完成证；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboVault | 不适用（当前范围） | 页面无 firstUseTip | 新增首次引导需求时评估；客户端验收完成：用户确认 2026-10-16 |

## 后续方向与实现状态

| 方向 | 当前证据 | 对迁移节奏的影响 |
| --- | --- | --- |
| 中英文客户端适配 | 已实现 localization:1 / API13，见 CAP-009 与语言服务文档；客户端待验收 | Core 已提供不代表业务已接入；按触及区域迁移并登记最低版本和验证证据 |
| 内置 LDB 与信息条 | 2026-10-11 工作树已内置三库，提供 account-entry:2 / builtin-entry-bar:2；三通道和总开关实现，1156项专项通过，客户端待验收 | 方案明确保留 RegisterBusinessEntry、defaultMode 与 legacyIDs 兼容；主要由 Core 改造，不作为全插件追版本的前提 |
| 业务任务聚合 | CAP-005 的 Provider／List 已提供；Todo／Mail 三个 action.todo 与 TaskHub 四个展示面已有代码及自动化 | 按真实提供方／消费方继续扩展；两个业务所有者已接入，不等同于全部业务或跨角色安排已实现 |
| 网络通讯协议 | 本轮在业务运行 Lua 中未找到 SendAddonMessage／CHAT_MSG_ADDON／RegisterAddonMessagePrefix；本机 Core.Events／Contracts 不属于网络协议 | 需求、契约和实现版本尚未确定；不作为当前追赶完成条件 |

## 其他现有能力索引

2026-10-08 按 TOC 所加载源码的 Capabilities:Register 复核；以下显式记录能力版本，不能把能力版本与 Public API 版本混为一谈：

| 类别 | 已注册能力 | 后续处理 |
| --- | --- | --- |
| 运行与配置 | runtime:1、database:1、migrations:1、events:1、resources:1、fields:1、addon-catalog:1、addon-status:1 | 现有基础设施；发现具体重复实现或版本缺口时建迁移条目 |
| 角色与数据 | characters:1、character-cleanup:1、character-profile:1、data-domains:1、domain-store:1、level-filter:1 | 角色身份与清理已有公共接口；character-profile 是旧兼容层，新功能按现有指南读取 DataDomains。数据域内容仍须遵守业务所有权 |
| 账号 UI | account-view:2、account-entry:2、builtin-entry-bar:3、account-character-admission:1 | 角色准入通知见 API-v11-角色准入通知；接入基线见 CAP-004，首次提示见 CAP-006；注册存在不代表全部行为已验收 |
| 输入与物品 | basic-input:1、item-resolver:1、item-picker:2、currency-catalog:1 | 迁移见 CAP-002／003；currency-catalog 后续有真实迁移需求时单列 |
| 名称与连接 | character-name-format:1、business-services:1 | 见 CAP-001／005；business-contracts 尚未注册 |

Core 1.7.0 新增 `character-name-format:1`，接入进度见 CAP-001。接口索引不构成新建服务目录或迁入业务数据的授权。

## 首次审查待处理项

| 编号 | 事项 | 关联能力 | 处理触发 / 验证要求 |
| --- | --- | --- | --- |
| AUD-001 | 部分关闭：十个插件适配验收完成；Legendary／Todo 语言候选暂缓；AutoOpen 待单独适配 | CAP-001／009 | 用户确认的验收范围、候选延期及 AutoOpen 后续处理均记录于当前基线与能力条目 |
| AUD-002 | Mail 输入／选择器最低要求已修正 | CAP-002／003 | 工作树 1.1.0-api1 检查 API v8、名称能力与 item-picker:2；InboxReleaseSpec 覆盖升级提示和停止行为，已关闭 |
| AUD-003 | Vault 最低 API 缺口关闭 | CAP-002 | 本轮初始化要求 API v9 / business-services:1，低版本停止并提示升级；搜索框原公共调用保留 |
| AUD-004 | 已关闭 | CAP-004 | Mounts 1.0.0 已登记 Core API13、设置 v6 与可选依赖行为；用户确认当前适配验收完成 / 2026-10-16 |
| AUD-005 | 已关闭 | CAP-004 | 当前记录显示独立设置壳、旧窗口及小地图接口已移除；用户确认当前适配验收完成 / 2026-10-16 |
| AUD-006 | Mail 已通过公开配置保留确认输入 | CAP-003 | Core 1.7.1 提供 retainInput 与 multiple；CoreItemControlsSpec 与 RuleSendUISpec 验证生命周期，已关闭 |
| AUD-007 | 已关闭 | CAP-005 | Currency 0.9.1 通过 Core 契约发现 Vault，当前记录明确 TOC 无业务插件依赖；生命周期与错误回退已验证 / 2026-10-15 |
| AUD-008 | API 总览过期，与 Core 发现边界冲突 | CAP-005 | 本轮更新总览至工作树 v10，修正 Mail 阶段及“直接调用业务提供方”的旧指引；已关闭，仅文档修正 |
| AUD-009 | 名称测试把当前 API v10 当未来版本拒绝 | CAP-001 | 2026-10-09 已关闭：接受 v10／当前版本、拒绝 API_VERSION+1；CharacterNamesSpec 77 项通过，旧版兼容覆盖保留 |
| AUD-010 | 已关闭（本轮验收） | CAP-006 | Builds、Reputation、Todo 的首次提示已按用户 2026-10-16 验收结论标记；语言候选延期不影响该项 |
| AUD-011 | 已关闭 | CAP-001 | Crafting 当前名称接入已复核；用户确认适配验收完成 / 2026-10-16 |
| AUD-012 | 已关闭 | CAP-002 | Crafting 1.2.0 使用 Core CreateInput；用户确认适配验收完成 / 2026-10-16 |

## 更新记录

| 日期 | 更新范围 | 结果与证据 |
| --- | --- | --- |
| 2026-10-16 | Core 1.12.6 / API13 与业务插件验收复核 | 更新 CAP-001～010 总表、插件版本基线与接入状态；用户确认 Builds、Crafting、QuestBlocker、Reputation、AltoBoss、BeastPaths、Currency、TaskHub、Mounts、Vault 当前适配验收完成。Legendary／Todo 语言硬编码候选暂缓至原版英文客户端处理；AutoOpen 为唯一待适配插件，另开对话处理。补齐 CAP-007／010 全部14个插件条目，复核并关闭已解决的 AUD-004／005／007／011／012。仅更新文档，未运行代码测试。 |
| 2026-10-10 | TaskHub 0.4.0／AltoBoss 2.6.0 刷取目标 | CAP-002 更新 Task 共享输入；CAP-004 更新共享业务标签页与工作台；CAP-005 登记两个 Service／一个 Provider 和最低版本边界。目标136项、原536项通过；CAP-001 新增 Task 角色选择及 AltoBoss 目标行动标题复用 FormatName；AltoBoss API5 基础行动保留原显示逻辑，版本兼容边界已记录；CAP-003 原物品显示未改；CAP-006 必要说明常显，无新首次提示。运行与自动化完成，客户端待验收，未发布 |
| 2026-10-09 | TASK 角色显示与新邮件语义复核 | TaskHub 0.3.1 的名称格式化已接入，补齐共享角色控件与 GetDataRowColor，显式检查所需方法；CAP-001／004 更新。Mail 1.2.6-api1 改为每角色一条新邮件提醒，已看未取由来源确认，CAP-005 更新。CAP-003 原调用保留并回归；本轮无输入／选择器及首次引导，CAP-002／006 不适用。359 项、Core 名称 77 项、邮件／Vault 回归通过；未提交／发布，客户端待验收 |
| 2026-10-09 | O5 邮件待收取跨业务来源 | Mail 1.2.4-api1 新增 action.todo，TaskHub 无运行改动；46 项新增／265 项累计与邮件启动／运行／API 回归通过。实际 diff 仅新增 Provider 注册、通知和业务投影，CAP-005 版本门槛与失败清理已接入；CAP-001／002／003／004／006 无新接入变化，旧迁移库存保持。未提交／发布，客户端待验收 |
| 2026-10-09 | O4 展示与提醒及角色准入通知 | Core 先补 account-character-admission:1，TaskHub 0.2.0 再接入；实际 diff 收拢名称／详情、预览字段、业务设置与角色准入。219 项集成及展示、Core 连接 90 项／名称 77 项／性能、待办日常回归与 88 个加载 Lua 语法通过。用户确认 0.1.1 主页面外观；O4 客户端待验收，未提交／发布 |
| 2026-10-07 | 建立台账；首次静态审查 Core 与全部 13 个业务插件 | 登记 CAP-001～004、现有能力索引及 AUD-001～006；源码路径见各表；本轮仅文档更新，未修改运行代码或运行测试 |
| 2026-10-07 | CAP-001 Core 实施 | Core 1.7.0 / API v8 提供 FormatName 与 character-name-format:1，完成 Core 内部显示迁移；75 项名称／兼容检查、44 文件语法检查及 Currency 控件回归通过。业务状态保留，游戏内尚未验收 |
| 2026-10-07 | Mail 1.1.0 工作树接入；Core 1.7.1 批量控件扩展 | CAP-001 记录已覆盖与剩余名称调用；CAP-002 最低版本缺口关闭、旧输入保留待迁移；CAP-003 完成所列范围接入；AUD-002／006 关闭。相关自动化及 Core／Mail 66 文件语法检查通过；尚未发布，游戏内待验收 |
| 2026-10-08 | CAP-005 通用跨业务连接契约设计 | 新增待实现条目，计划 API v9 / business-contracts:1，登记首批业务现状与后续范围；未新增连接运行时、未接入业务或执行测试 |
| 2026-10-08 | 新建 YiboTaskHub 项目基础 | CAP-001～005 登记新插件为待评估；TOC、Namespace 和客户端目录联接已建立，尚无公共能力接入 |
| 2026-10-08 | 刷新扫描修复与最小 Service 实施 | CAP-003 记录 Mail／Vault／Crafting 展示加载；CAP-005 记录 Core business-services:1 与 Mail／Vault／Currency；接口与测试见 API-v9 文档。未发布、游戏内待验收 |
| 2026-10-08 | 台账复核与迁移节奏审查 | 修正当前工作树 1.9.0 / API v10、CAP-005 总表及能力版本；新增插件最低版本表、CAP-006 和规划观察项；更新 API 总览，登记 AUD-007～010。4 个相关测试通过，名称测试因过期版本断言失败；仅改文档，未修改 AGENTS 或运行／测试代码 |
| 2026-10-08 | api9／api10 合并发布与追赶记录 | 用户确认跳过 v1.8.0-api9，随 v1.9.0-api10 发布；HEAD 已为 1ef9ccf，截图 api10 上传中。新增同批追赶要求与分代验收清单，修正 Core 当前发布依据；业务接入／验证状态不因 Core 发包自动完成 |
| 2026-10-08 | 触及即迁移执行审查 | 对规则生效时点、Core 合并提交及 38 个业务运行 Lua diff 逐项核对；列 10 个正确迁移实例、1 个当前调用层漏迁、1 个较早已提交历史漏迁。未触及旧实现不计违规；新增 AUD-011／012，仅改审查与台账文档 |
| 2026-10-08 | 确认迁移节奏与持续观察 | 用户确认保留触及即迁移，集中追赶随无限服开服后的各插件大幅更新执行；AGENTS 增加收尾 diff 核对，台账记录实际接入与遗漏。明确搜索清空已在 Core，业务搜索框需接入标准输入；未改运行代码 |
| 2026-10-09 | O1 Provider 与真实任务映射 | CAP-005 登记 Core 1.10.0 / API v11 / business-providers:1 与自动化回归；Todo／TaskHub 记待迁移、无运行接入；AUD-009 关闭。未发布、客户端待验收 |
| 2026-10-09 | O2 首项输出与两个角色列表 | Todo 1.1.3／TaskHub 0.1.0 接入 action.todo；70 项集成及待办／Core 回归、36 文件语法通过。按本轮实际修改审查 CAP-001～006，更新名称、页面／入口与 Provider 接入；客户端待验收，未提交／发布 |
| 2026-10-09 | O3 诺米第二来源 | Todo 1.1.4／TaskHub 0.1.1，两个真实 Provider 同属 Todo；133 项集成及待办日常／冷却／动作／旧日常、Core 连接／性能回归通过。复用 Core API v11，更新 CAP-005；其余本次相关能力无新接入变化，客户端待验收，未提交／发布 |
| 2026-10-09 | Crafting 专业与角色联动筛选 | 专业归属沿用 Core.DataDomains，自然宽度与分页复用 AccountView 公开接口；专业筛选、状态范围与 Core 原范围保留的针对性验证、Lua 5.1 语法通过。此次相关角色显示遗漏已在下一项补齐，AUD-011 更新为代码已修复、客户端待验收。输入控件及业务服务等未触及的旧范围继续按原状态登记 |
| 2026-10-09 | Crafting 角色表头及名称 API v8 接入 | 矩阵使用 Core 共享表头，角色下拉／详情使用 FormatName；初始化与注册要求 API v8，检查名称能力和方法，失败时提示升级并停止初始化。CoreNameIntegration、Crafting Smoke、Core 名称 77 项及四个相关文件语法通过；CAP-001 部分接入、AUD-011 代码已修复，游戏显示待验收 |


2026-10-09 CAP-005 / Todo 全量接入复核：YiboTodo 1.2.0 保持 API v11 / business-providers:1 门槛，基础 UI 继续最低 API v10。`profession-cooldown` 输出全部适用冷却组；
omi` 保留；新增 `activities` 输出其余 `monitoringProjects`，账号布林顿去重并投影候选。Core 连接实现和 TaskHub 消费实现无需改动。TodoSourcesSpec 177 项、原 359 项以及全部 Todo 烟雾测试通过；低版本停止、三来源注销／重注册已验证。状态仍为“部分接入（运行代码与自动化完成，客户端待验收）”。CAP-001／002／003／004／006 本次无新接入变化；未触及调用继续保持原台账状态。范围与实际契约见 [全量接入记录](../../Docs/行动中心-Todo全量接入.md)。

2026-10-12 CAP-005 Mail／Vault批量取件：Mail 1.2.12合并同轮扫描与收取归档通知、队列中间状态只更新原生进度；Vault 1.2.2经Core Contracts消费可选transfersUnchanged提示，仅状态变化刷新当前角色，缺失提示／实际数据／混合批次保持全账号刷新。最低API13／business-services:1不变，无来源私有访问；MailRuntimeSpec 30封90附件库存与归档一致、180次通知、1次队列完整刷新；MailProviderSpec含状态范围、混合失效、在途核实与缺失／不兼容／晚注册通过，客户端待验收。Core公共接口没有变化，CAP-007身份调用继续沿用既有接入，无新增能力迁移。

## CAP-007：轻量角色身份投影

R2 Retail（2026-10-27）：API13／character-identity:1保持，真实GUID目录、跨服ID、等级事件和轻量副本接入，禁止legacy导入和名字fallback。用户诊断确认DRUID66、identity=known、一个角色及独立内存存档；115项专项含晚GUID、错端／错档和幂等。完整落盘恢复待验，见[本阶段记录](R2-01-02-Retail目标与构建实施验收.md)。

2026-10-10；Core 状态：已提供（1.10.0 工作树，未发布）；API v11 / character-identity:1。职责、选项、返回字段、缺失及默认兼容语义见 [API 文档](API-v11-轻量角色身份.md)。不复制 domains，无新业务存储。

| 插件 | 状态与已覆盖范围 | 剩余范围／验证 | 最近审查 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入：API13 / character-identity:1；身份读取统一使用 identityOnly，公开角色引用经 Core 唯一 ID，旧数据存储键不变 | 多角色、改名与缺失身份场景已由用户验收 / 2026-10-16 | 2026-10-16 |
| YiboAutoOpen | 不适用（现有功能无角色身份目录查询） | 物品队列为独立业务；无 CAP-007 迁移项 | 2026-10-16 |
| YiboBeastPaths | 既有路线不适用；离线兽栏待接入 | 路线显示宠物、路线与坐标；R3已验证character-identity:1的GUID／跨服副本及猎人准入，YBP尚未调用新增范围 | 既有确认2026-10-16保留；跨角色兽栏按[R3契约](API-v13-YBP离线兽栏公共支持契约.md)实施；最近审查2026-10-27 |
| YiboBuilds | 部分接入：目标角色校验使用 identityOnly，业务快照由 Builds 自有数据提供 | API13 / character-identity:1；Core13Spec 及目标范围用户验收完成 / 2026-10-16 | 2026-10-16 |
| YiboCrafting | 部分接入：1.2.0 的目标角色目录／存在性使用 identityOnly；领域快照仍经 DataDomains:Get | character-identity:1 / API13；GoalTargets 与来源集成已验证，用户验收完成 / 2026-10-16 | 2026-10-16 |
| YiboCurrency | 部分接入：0.9.1 工作树 / API13，目标角色校验使用 Get(identityOnly=true)，检查能力与实际方法 | API13Spec 四组各 52 项通过；用户验收完成 / 2026-10-16 | 2026-10-16 |
| YiboLegendary | 部分接入：目标角色校验使用 identityOnly | 当前适配验收结论见基线；语言候选延期见 CAP-009 | 2026-10-16；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboMail | 部分接入：1.2.11-api1 收件箱／账号视图、名称、状态、扫描、队列、行动投影及新建历史占位使用 identityOnly；联系人与寄送经公开只读目录补阵营；未触及的设置页／诊断低频完整读取保留 | Core 10,000 物品对照；100 轮邮箱身份／名称／状态／联系人约 180KB、0 领域复制；相关 7 个 Spec 通过。详见 `../../Docs/Mail-内存与首次打开性能修复.md` | 2026-10-12 |
| YiboMounts | 不适用：当前图鉴、坐骑目录与独立设置不读取 Core 角色身份目录或领域快照 | 新增账号角色级坐骑页面时重审 | 2026-10-16 |
| YiboQuestBlocker | 已评估：现有页面读取角色等级／任务状态所需角色资料，未登记 identityOnly 改造需求 | 当前范围用户验收完成 / 2026-10-16 | 2026-10-16；客户端验收完成：用户确认 2026-10-16 |
| YiboReputation | 部分接入：1.7.1 采集、目标、迁移与目录校验使用 identityOnly；业务快照归 Reputation 自有 Store | Retention 126 项及数据归属迁移检查通过；用户验收完成 / 2026-10-16 | 2026-10-16 |
| YiboTaskHub | 已接入：角色身份、目录、受益者、目标校验、主视图／预览／提醒均检查能力 | Overview 50 项、专项 219 项及依赖回归通过；用户验收完成 / 2026-10-16 | 2026-10-16 |
| YiboTodo | 已接入：Bootstrap 任务事件、DailyQuest 观察、Snapshot 与行动投影使用身份接口，最低 API v11 并检查能力 | 九个 smoke、TodoSources 177 项及专项 219 项通过；语言候选延期见 CAP-009 | 2026-10-16；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboVault | 部分接入：Tooltip 与仓储页使用 FormatName；业务目标显式范围使用 identityOnly；2026-10-22 Common/Collector与Mists/Collector的四处身份查询接入identityOnly；检查API13 / character-identity:1 | 本批双端、加载及覆盖模拟通过，新增路径客户端待验；未触及旧查询保留库存。角色显示、范围与目标交互用户2026-10-16确认范围保留 | 2026-10-22 |
本表已补齐全部 14 个插件；未登记适用调用的插件明确说明不适用或当前无迁移需求。未来触及只需身份、存在性或等级的查询时迁移；需要完整领域快照的既有查询保持默认形式。

CAP-005 本轮复核：TaskHub 仅按稳定 Provider 标识与范围缓存、精准失效；AltoBoss 目标配置仍经 Core Service，缓存随 registrationRef／变化事实失效，投影仍由来源生成。无跨业务对象或 SavedVariables 读取。CAP-001／CAP-004 已接入的名称、统一准入和窗口刷新继续复用，本轮未新增UI壳或业务来源分支。测试与客户端复测边界见 [性能记录](../../Docs/任务链-性能异常修复-2026-10-10.md)。

2026-10-10 悬停／显隐设置复核：CAP-004 的 YiboTaskHub 本次业务设置继续复用统一工作台与共享控件，以 ShowSettings("sorting") 和 ShowSettings("todo") 跳转既有入口，不重复保存角色准入／来源监控。CAP-005 的 Todo 三个来源新增可选 displayGroups／task.displayGroup 展示元数据，TaskHub 经既有 Core Provider 获取完整冷却／活动目录，不直读来源业务对象或数据；缺少目录仅支持来源级显示开关。CAP-001／002／003／007 本次涉及调用保持现有接入与最低版本声明，无新增本地回退。46项显隐专项、既有集成回归和219项性能回归通过；客户端待验收。详情见 [显隐设置与契约](../../Docs/行动中心-显隐设置与悬停规则.md)。


## CAP-008：业务项目主动添加

2026-10-11 设置入口复核：共享添加方式与目标标记仍由 Core 的窗口页统一渲染保存；TaskHub 业务设置新增“添加方式与目标标记”直达按钮，通过既有 AccountView:ShowSettings("core") 导航，不重复设置控件或数据。宽窄布局相应预留按钮高度，沿用 API12 最低版本要求。

2026-10-11 触及审查：Core 增加 business-item-actions:2，统一鼠标焦点追踪和可选旁侧按钮位置；版本 1 调用兼容。Crafting 1.0.7 目标增强检查 API12 / 能力2，名称、产物、已学矩阵格均复用公共绑定，无业务本地按钮。TaskHub GoalEditor 消费 action.targets v1.2 可选执行范围元数据，维持原提供者兼容，无来源名分支。共享角色身份与专业归属来自 Characters / DataDomains，持有判断经 Contracts 调用 Vault；Core 不承担制造判断。GoalSourcesSpec 60 项、GoalsSpec 94 项及 Crafting 四项、BossTargetsSpec136 和 Lua语法检查通过；悬停视觉、跨角色共享任务及实际完成仍待游戏验收，接入记为部分完成。未触及能力维持原状态。

2026-10-10 客户端反馈复核：Core 菜单改为悬停显示与延迟 Lookup，九个业务绑定继续复用同一公共能力，无本地重复按钮。Task 添加导航经 CAP-005 的 action.targets v1.1 GetEntry 发现九个来源；v1.0 评估保持兼容。Task 角色显示偏好、分页及源状态继续复用 CAP-001／002／004／007 的名称、共享控件、账号壳与轻量身份，不建立第二套角色数据或设置窗口。AltoBoss 补 action.targets 变化通知，Task 目标投影不复制历史并仅清过期缓存。230项目标专项及相关回归通过；客户端视觉、战斗安全和性能采样待复测。详见 [反馈记录](../../Docs/行动中心-客户端反馈修复与发布前检查-2026-10-10.md)。

Core 状态：已提供，工作树 1.11.0 / API v12 / business-item-actions:1，未发布。职责、方法、失败行为与版本要求以 [API v12](API-v12-业务项目主动添加.md) 为准。目标写入与业务评估经 CAP-005 的既有 Contracts；Core 不保存用户目标或业务数据。

| 插件技术名 | 接入状态／已覆盖 | 剩余范围与验证 | 最近审查 |
| --- | --- | --- | --- |
| YiboAltoBoss | 部分接入（适用代码完成，客户端验收完成） | API13 / business-item-actions:3；世界／节日／副本及自定义目标通过公开主动添加，副本启用Core精简TP | 手势／菜单／缺参数实机验收完成；不保留本地按钮回退 / 2026-10-14；客户端验收完成：用户确认 2026-10-16 |
| YiboAutoOpen | 本轮对象不适用：即时操作 | 后续真实持久目标出现时评估；未改变基础功能 | 2026-10-10 |
| YiboBeastPaths | 本轮对象不适用：路线说明 | 无角色驯服完成采集；后续收藏入口再评估 | 2026-10-10；客户端验收完成：用户确认 2026-10-16 |
| YiboBuilds | 部分接入：宝石／附魔实际候选、具体装备与孔位；统一最低API13 / business-item-actions:1 | 原低版本基础功能兼容分支已收拢；客户端GUID／安全点击验收完成 | 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboCrafting | 部分接入（代码完成／客户端验收完成） | 1.2.0 / API13 / business-item-actions:2；配方名称、产物及已学角色格均走 Core，无本地按钮 | 默认参数／多产物配置／键鼠回归通过；真实交互客户端验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboCurrency | 部分接入：原生货币／金币角色格与标题 | 0.9.1工作树整体API13；目标增强检查business-item-actions:1／business-providers:1／character-identity:1与实际方法。API13Spec覆盖开启及stale未知；物品目标归Vault，账号合计不在范围；客户端验收完成 | 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboLegendary | 部分接入：角色最终目标；增强最低API12 | 客户端；任意中间节点与整链未接入 | 2026-10-10；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboMail | 当前已交付查看邮件目标范围实机收口；增强最低API12 | 寄达／收取需求关联按DEV-003的真实任务链需求另行设计 | 原接入记录2026-10-10；用户2026-10-16确认当前功能实机收口 |
| YiboMounts | 当前入口不适用：Tooltip 来源说明 | 未来收藏管理入口与完成采集再评估 | 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboQuestBlocker | 本轮对象不适用：屏蔽规则 | 规则不转目标；未来真实业务对象另评估 | 2026-10-10；客户端验收完成：用户确认 2026-10-16 |
| YiboReputation | 部分接入：角色声望单元格、来源等级；增强最低API12 | 1.7.1 使用 Reputation 自有 Store；91项专项覆盖正常与未知／错误快照，不将缺失好友度等级解释为普通standing；客户端与消费者联动验收完成 | 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboTaskHub | 部分接入：action.demands v1、参数面板、手势消费与目标定位；整体最低API12 | 客户端；代码及自动化闭环完成 | 2026-10-10；客户端验收完成：用户确认 2026-10-16 |
| YiboTodo | 部分接入：角色项目精确目标，不依赖显示监控；增强最低API12 | 客户端周期／账号活动；基础旧版本分支属兼容例外 | 2026-10-10；当前范围验收确认 2026-10-16，语言候选延期见 CAP-009 |
| YiboVault | 当前已交付范围实机收口：仓储物品格、阈值与固定账号范围；整体最低API13 | 增强检查兼容的 `business-item-actions:1`与角色身份能力；公会／拍卖目标属于后续范围；Core v2兼容v1调用 | 原接入记录2026-10-12；用户2026-10-16确认当前功能实机收口 |

验证证据：GoalsSpec62、GoalSources40、BossGoals15、GoalSurfaces12；相关原集成672、性能219、布局197、显隐46、Core连接90／名称77、Todo九个smoke及Crafting两个smoke通过；17TOC／255Lua语法通过。详见 [实施与验证](../../Docs/行动中心-主动添加实施与验证.md)。自动化帧夹具与客户端验收分别记录；原“部分接入”保留当时的接入范围，当前已交付功能实机验收按2026-10-16用户确认收口。新增实际对象或修改同类入口时复用本能力；暂无对象的插件不提前生成空Provider。

### 本轮直接相关公共能力核对

- CAP-001／007：新增参数角色下拉、来源校验、作用域与目标管理显示使用 Core.FormatName / identityOnly，不以短名关联业务。本轮新增调用已接入；其它旧范围保持原台账状态。
- CAP-002／003／004：目标编辑复用共享输入／下拉／按钮和统一账号壳；移除及复制复用 ItemConfirmation；仓储物品名称复用 ItemResolver；不建第二套窗口、入口或角色设置。本轮直接相关逻辑已接入，客户端待验收。
- CAP-005：新增 action.demands Service 与九个 action.targets Provider，制造→库存公开调用、Boss兼容配置投影都经Core；Task目标所有权唯一，来源查询不读Task内部实现。来源内部读取自身Catalog／SavedVariables不越权。
- CAP-006：本轮未修改首次提示机制，原接入状态保持；新增空态引导是必要产品说明。
- 兼容例外：九个来源仅主动添加增强要求API12，原有基础业务继续自身旧最低版本；低版本显式提示并停止增强，没有新交互本地回退。适用旧Core；当来源整体提升最低版本时收拢此分支。TaskHub整体最低API12。

CAP-007 历史记录：Vault Items 对个人仓储的明确 characters 范围逐个 Get(identityOnly=true)，不枚举并复制全部角色领域。此前 Items 查询兼容旧 Core；2026-10-12 Vault 整体最低版本升至 API13，旧 Core 身份回退已收拢；目标增强仍单独检查角色身份能力。本轮代码完成，客户端范围与目标行为待验收。

2026-10-10 CAP-008 追加审查：九类来源已有绑定直接复用 Core 常驻已加入折角与保持窗口的手势；无业务本地实现新增。CAP-005 的 action.demands v1.1 新增 LookupItems，按帧批量、按库 revision 索引；旧 minor0 保留添加，仅不显示可选标记。GoalsSpec 87 项覆盖角色、状态、移除、复用、注销、查询合并和中键不导航；客户端悬停与图标位置待复测。

2026-10-10 CAP-008 农场与切换手势复核：Todo 补齐农场目录校验，继续使用既有 Snapshot／ActionActivities，不新增业务判断到 Core；Core 统一 Handle 使用精确 Lookup 与 revision 校验 Update 实现再次手势取消。无新增公共能力，action.demands v1.1 的 Lookup 增加 revision 元数据。GoalsSpec89、GoalSourcesSpec46 通过，覆盖农场观察、重置、角色隔离与三次手势添加／取消／再添加；客户端待验收。

2026-10-10 CAP-005／008 图标执行接入：Todo action.targets v1.2 公开 GetClickAction／AfterClick，Task 以 Core Contracts 发现，不访问 Todo 全局实现或 SavedVariables；Todo 图标和提供方共享 Actions:Describe。Task 主表／悬停使用同一安全绑定，继续复用 Core UI 提示与战斗窗口生命周期；其它来源未迁移执行能力，不预建空接口。ClickActionsSpec26 与既有目标、布局、性能及 Todo 操作回归通过，客户端待验收。契约见 ../../Docs/行动中心-目标图标执行契约-v1.2.md。

2026-10-10 CAP-005 图标执行客户端反馈：Task 安全按钮改为锚定行 Frame＋工作列数值偏移，消除锚定 FontString 导致的刷新中断；Core 契约与 Todo 提供方无变化。ClickActionsSpec26、Layout197 与256文件语法检查通过，重载后客户端待复测。

2026-10-10 CAP-008 图标反馈：Core 统一添加按钮使用原生勾选纹理，消除中文字体缺字方块；Todo ActionNomi 经既有目标投影提供 item／icon，Task 继续通过公开来源消费，保留 ItemResolver 并补已可用纹理显示。无新增能力或跨业务私有访问。GoalsSpec90、ClickActionsSpec29、Layout197、TodoSources177 与语法检查通过，客户端待复测。

2026-10-10 CAP-005／008 连续点击与图标布局：Task 统一使用带边框的工作图标及同位安全按钮；当前角色目标逐项显示，完成行仅在当前打开的 UI 中保留到关闭。Todo Evaluate 可选提供 display.item／icon，未知专业只保留显示元数据，不推定执行或完成。继续复用 Core Contracts、ItemResolver 与 UITheme，未新增 Core 业务分支或来源私有访问。ClickActionsSpec45、Layout197、Performance219、256文件语法检查通过；客户端待复测。

CAP-008 设置与状态同步追加审查：Core 统一设置提供右上角按钮／中键／Ctrl＋左键互斥选择，以及金色折角／青绿圆点；旧自定义手势迁移保留。Todo、Builds 的安全属性由来源回调负责，Currency、Crafting、Mail、Legendary、Reputation 的普通入口声明安全消费 Ctrl＋左键；全部复用既有 API12 / business-item-actions:1，未增加本地按钮实现。CAP-005 的 Todo 精确查询与账号快照复用同一专业图标／动作元数据；每日预计状态由来源解释为准备，Task 不重算重置。ItemActionSettings30、TodoStateSync23 与既有专项及回归通过，客户端战斗与视觉仍待复测。

2026-10-11 CAP-005 同步复核：Todo 继续通过既有 action.targets／action.todo 输出，已学习可制作但无数值冷却的配方投影准备，保留 profession 置信度；Task 不读取来源 SavedVariables。Task 悬停分组保留既有 current/others 段标识，当前未知目标与主表同样逐项展示。无新增 Core 接口或本地回退；TodoStateSync36、ClickActions45、Layout197 及只读已保存观察回放通过，客户端仍待复测。

2026-10-11 CAP-005 活动关闭同步复核：Todo 通过既有 action.targets 任务的 active/not-applicable 状态表达暗月未开放，Task 复用 Snapshot 筛选并让完成行保留逻辑尊重明确不适用状态；无新增 Core 能力或来源内部访问。EventGoals17 验证午夜缓存到期、当前与其它角色、悬停、完成行移出、目标历史保留及下期恢复。

2026-10-11 CAP-005／008 AltoBoss 自定义目标复核：来源公开目录与进度纳入 custom NPC，Task 继续经 Core Contracts 消费，击杀和有效期仍归 AltoBoss。目录增删改经既有 NotifyChanged 失效；角色状态格复用 API12 / business-item-actions:1，并声明普通按钮安全消费 Ctrl＋左键。无新增 Core 接口、业务分支或跨插件内部访问；CustomBossGoalsSpec25 验证实际来源增删改、添加取消、角色隔离及有效期恢复，客户端仍待复测。


## CAP-009：公共语言服务与账号语言偏好

R2 Retail（2026-10-27）：复用563个资源与localization:1，无新增硬编码或业务接入；正式服中文各页基础显示已确认，英文／手动语言、原生名称及IME仍待实际客户端验证。见[本阶段记录](R2-01-02-Retail目标与构建实施验收.md)。

R1-09（2026-10-27）：Core共563个双语key，新增6个ASCII key，缺英文／格式不一致／重复均0；自动与手动语言、绑定身份、重复初始化和模拟重载专项通过。语言会话接口及localization:1不变，业务无新接入；新增字节实际语言验收待完成，见[收尾记录](R1-09-文案与契约文档收尾验收.md)。

2026-10-18 YiboAltoBoss 已排队时间Tooltip：CAP-009新增 `QUEUE.ELAPSED_WAIT` 一对中英文资源；CAP-004复用现有行动Tooltip，和预估时间相邻显示，同次系统查询计算已排队时长。API13与接口要求不变，无本地语言或计时回退。HolidayBossSpec261、语法及语言检查通过，客户端待确认。详见[排队状态同步修复](../../YiboAltoBoss/Docs/节日排队状态同步修复.md)。

2026-10-18 YiboAltoBoss 排队预估Tooltip：CAP-009新增两对 owner 资源，CAP-004继续使用现有 Tooltip 显示／定位／关闭及行动单元格；API13要求不变，没有新增Core接口或本地语言回退。HolidayBossSpec252含中英文实际Tooltip渲染、最新估算与异常数据检查，BossGoals19及语法／语言检查通过；实机显示待验。详见[排队状态同步修复](../../YiboAltoBoss/Docs/节日排队状态同步修复.md)。

2026-10-18 YiboAltoBoss 节日队列同步复核：实时状态与事件刷新复用 CAP-004 账号视图和 CAP-009 既有 owner 提示，API13要求不变，无新增Core契约或本地语言回退。HolidayBossSpec240、BossGoals19、InstanceKills56与语法检查通过，实际队列与系统图标状态仍待客户端核对。详见[同步修复](../../YiboAltoBoss/Docs/节日排队状态同步修复.md)。

2026-10-18 YiboAltoBoss 四类节日副本核查：新增埃霍恩与皇冠药剂公司两对 owner 资源，四类日历／副本输入别名分别审查；仍要求 API13 / localization:1，无 Core 契约变化。复用 CAP-004 统一视图与 CAP-005／008 目标目录。HolidayBossSpec225（四类首领共12组语言场景）、既有 Boss 目标／副本回归、语法与语言静态检查通过；新增节日的排队和奖励仍待实机验证，既往范围的验收结论不扩大。详见[核查与验收](../../YiboAltoBoss/Docs/四类节日副本首领核查与验收.md)。

2026-10-18 YiboAltoBoss 万圣节续接入：新增无头骑士显示名复用 API13 / localization:1 owner 资源，中英文各一项；节日目标继续经既有 CAP-005／008 契约枚举，无 Core 接口变化。HolidayBossSpec24、BossGoals19、CustomBossGoals25（含前置 BossGoals）、InstanceKills56、LockoutProjection16 与 Lua 语法通过；语言报告缺英文／格式差异为0，6个未知 key 位于未涉及的 AutoOpen。节日输入名称别名属识别数据。日历、排队、奖励及中英文客户端待验，不扩大此前实机验收结论。详见[接入与验收](../../YiboAltoBoss/Docs/万圣节首领接入与验收.md)。

2026-10-13 Mail 1.2.13 截图修复：寄信发送／取消按钮和保留期确认直接使用 Mail owner 的 Core.Locale 资源，不再让客户端 CANCEL／ACCEPT 覆盖手动英文；中英文到期数值统一 d／h、估算保留~。NativeInboxSpec 验证中文原生标签在 Core 英文及中文的悬停／启禁刷新，WorkspaceSpec 验证两种语言的范围与高度。基础最低 Core 1.12.1 / API13，新增范围能力见 CAP-004；语言能力仍 localization:1。未修改游戏动态名称、历史快照或用户文本，客户端语言／布局验收仍待完成。

Core 状态：**已提供（1.12.0 / API v13 起，语言服务仍兼容；当前 Core 工作树为 1.12.6）**。能力 `localization:1`，最低 API13。契约见 [API v13 语言服务](API-v13-语言服务.md)；Core 当前 532 对资源已接入，175 项语言验证、206 项语言模拟布局及1133项入口专项与相关回归通过，真实客户端待验收。Core 保留旧 API，不推动无关业务整体提版本。

职责：Core 提供账号模式与会话语言、资源注册/查询/格式化/中文回退/缺失报告；业务拥有翻译目录与业务数据。正常业务注册早于自身页面文件、晚于 Core 就绪；保存语言偏好只在下次重载或登录生效。临时预览只在非发布探针，不保存。

| 插件（技术名排序） | 接入状态 | 已覆盖 / 剩余范围与版本要求 | 验证证据 / 最近审查 |
|---|---|---|---|
| YiboAltoBoss | 部分接入（适用代码完成，客户端验收完成） | API13 / localization:1；311对owner资源覆盖正式UI、设置、状态／错误、静态回退目录与目标／命令反馈，无独立语言开关 | 原生API名、历史、自定义文本与输入别名保留；中英文及手动语言模式验收完成 / 2026-10-14；客户端验收完成：用户确认 2026-10-16 |
| YiboAutoOpen | 当前适用范围实机已收口 | 当前1.2.3，可选Core设置要求API13／localization:1；资源接入方式按现有实现，历史词法观察不作为本轮新增待办 | 用户2026-10-16确认；完整英文延期任务只登记Legendary／Todo，见DEV-001 |
| YiboBeastPaths | 部分接入（既有维护区域实机完成）；离线兽栏待接入 | 可选维护增强最低API13／localization:1；既有owner语言与独立地图模式维护例外保持。R3测试owner的两组状态／时间资源验证不代表YBP新增文案接入，兽栏不得新增本地语言回退 | 原494项／双语smoke／26文件及客户端确认2026-10-16保留；R3五语言组合模拟通过，真实兽栏依赖提示／状态／时间文案与实机待验；最近审查2026-10-27 |
| YiboBuilds | 部分接入（主要区域代码完成，客户端验收完成） | 页面／字段／设置元数据／悬停／状态与确认／目标／命令／专业标签接入owner资源；历史占位在展示时翻译，原生API／DB2名称和识别别名保持 | Core13Spec双语资源与格式、旧快照无改写；词法报告55候选已分类，布局与真实客户端验收完成；最低API13 + localization:1；2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboCrafting | 部分接入（适用区域代码完成） | 1.2.0 整体 API13 / localization:1；页面、设置、入口、Tooltip、状态／错误、目标和稳定分类 ID 均迁移，动态名称／历史来源原文保留 | CoreAdaptation 双语资源／页面与静态报告通过；真实中文／enUS／手动语言模式客户端验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboCurrency | 部分接入（适用代码与离线检查完成／客户端验收完成） | 0.9.1工作树 / API13 / localization:1；页面、设置、悬停、状态、目录、目标、诊断与数字单位均使用owner中英文资源；原生名称和自定义历史文本保留 | YiboCurrency-Migration-Report.md：0硬编码、缺英文、未知key及格式差异；四种语言组合各52项通过；真实客户端验收完成 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboLegendary | 部分接入（适用区域未完成） | 工作树 2.2.0 / API13 注册自有 zh/en 资源，并迁移 Core 页面元数据、设置说明、摘要、部分状态、错误、清理提示与人工确认；剩余硬编码候选待原版英文客户端处理 | `_NonRelease/Localization/Legendary-API13-Report.md`：305 个硬编码候选、90 个 Core Locale 引用；缺英文、未知 key、格式差异均为 0。Bootstrap/UI 与 Catalog 路线目录、Data 行动文案部分迁移；Data 定义与 Model 快照状态仍有大量静态文案待迁移。硬编码候选暂缓，待原版英文客户端处理；语言客户端验收待该客户端 / 2026-10-13 |
| YiboMail | 既有范围实机已收口；1.2.25退信区域待实机 | 工作树 1.2.9-api1，最低 Core 1.12.0 / API13；Mail 静态玩家文案、账号入口、邮件状态／错误、目标与目录使用 Mail 自有 zh/en 稳定 ASCII key 并由 Core.Locale 按账号会话语言解析；动态游戏名称、历史快照及存档值保持原文。可选 action.todo 继续单独要求 API11 / business-providers:1；邮件目标操作检查 business-item-actions:1 | 既有静态与布局验证证据保留；用户2026-10-16确认当前功能实机收口，2026-10-21新增MoP退信按钮、确认、结果与历史状态的中英文资源；专项报告0硬编码／未知key／格式差异，界面中英文模拟通过；2026-10-22用户确认普通单封／批量、确认／取消、金币／COD及内容核对、AH取消上架／按钮／混选／收取通过，完整中英文及手动语言模式仍待验；当前版本未发布 |
| YiboMounts | 部分接入（Core 增强） | 1.0.0 注册 `YiboMounts` zh/en 资源；Core 可用时设置面板、收藏状态 Tooltip 和固定文案使用账号会话语言。双语源目录保留其数据字段，独立模式保留本地 Locale 兼容文本以满足 Core 可选契约；Core 增强最低 API13 + `localization:1` | 静态检查到注册／查询路径；中文／英文会话、手动语言、设置保存、Core 缺失／旧版验收验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboQuestBlocker | 部分接入（适用区域代码完成／客户端验收完成） | 工作树 3.1.0 整体要求 API13 与 `localization:1`；页面、入口、设置、状态、错误和命令前缀使用 QuestBlocker 自有 zh/en 资源与 Core Locale | Workspace-Report：0 硬编码候选、0 未知 key、0 缺失英文、0 格式差异；动态任务名及旧存档迁移 token 保持原文；中文／enUS／手动语言模式和实际入口交互客户端验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboReputation | 部分接入（适用区域代码完成，客户端验收完成） | 1.7.1 / API13 注册 owner zh/en 资源并使用 Core Locale；覆盖页面／入口／首次提示、矩阵、设置、预览、状态／错误、目标和稳定资料片／分类目录；动态声望名称及历史快照保留原文 | `_NonRelease/Localization/Reputation-Migration-Report.md`：0 缺失英文、未知 key、格式差异；人工分类的原生游戏名称匹配 token 与低版本启动错误回退保留。中文／enUS、手动语言、IME 和入口客户端验收验收完成；新增迁移／采集失败／诊断／缓存影响中英文资源；数据归属迁移代码与离线验证已完成，真实客户端验收完成 / 2026-10-15；客户端验收完成：用户确认 2026-10-16 |
| YiboTaskHub | 部分接入（静态文案已迁移） | 工作树 0.6.0：最低 YiboCore 1.12.0 / API13、localization:1、account-entry:2、builtin-entry-bar:1；TOC 注册 zh/en 资源，页面、入口、错误、摘要、HUD、设置、状态、目标编辑与 Boss 目录静态文案均通过 `Addon:T` 调用 Core Locale。动态来源名称仍由来源插件提供；搜索归一化用标点不属于显示文案 | 6 个 TaskHub 独立 Spec 均通过；静态报告 `_NonRelease/Localization/TaskHub-API13-Report.md`：0 未处理候选、0 缺失英文／未知 key／参数差异；中英文客户端布局及登录验收验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |
| YiboTodo | 部分接入（适用区域代码未完成） | 工作树 1.3.0，最低 API13；`Locale.lua` 注册 zh/en，并接入页面注册元数据、统一升级／初始化错误、摘要、空页面、设置标题和命令帮助。业务数据和游戏动态名称保留来源原值 | `_NonRelease/Localization/Todo-API13-Report.md`：0 未知 key、0 参数差异；275 个硬编码候选暂缓，待原版英文客户端处理；语言客户端验收待该客户端 / 2026-10-12 |
| YiboVault | 部分接入（适用区域代码完成） | 工作树要求 YiboCore 1.12.0 / API13 与 `localization:1`；TOC 注册 zh/en 资源，页面、设置、入口、Tooltip、状态／错误与固定目录文本经 Core Locale。动态游戏名称、历史快照与玩家自定义文本保持原文 | `Vault-Core13-Report.md`：0 硬编码候选、缺失英文、未知 key、格式差异；中英文客户端、手动语言模式与登录验收验收完成 / 2026-10-12；客户端验收完成：用户确认 2026-10-16 |

证据：[实施与验收记录](../../Docs/Core系列中英文客户端适配-实施与验收记录.md)，`_NonRelease/Localization/{Core-Report,Workspace-Report}.md`。字符串数不是加权区域覆盖度。后续新增/修改区域触发接入；达到单插件收尾条件时固定能力基线并集中验证。Core 间接给旧业务页面提供英文壳，不等于该业务已接入语言服务。

本轮仅修改 Core 运行代码及直接关联测试夹具；业务源代码没有因语言服务新增而迁移，CAP-001～008 状态保持。模拟布局中的 Fixture 是测试数据，不登记为插件接入。

2026-10-11 CAP-009：本轮 Core 入口／设置新增18对资源（总497对），继续 Core:Text 与统一会话语言，未涉及业务源码语言迁移；严格静态检查零缺失／未知／参数差异／硬编码，客户端待验收。

2026-10-11 CAP-009 文档同步：正式三模式设置承担插件显示语言覆盖，接口为 Core.Locale:GetLanguage() → zh/en，GetLocale() 保持客户端值；无需另建覆盖开关。zhCN 手动英文用于日常开发，真实 enUS 的原生名称、字体和业务场景验收仍待完成。探针仅作 Core 快速预览，未迁移业务状态保持。此次仅补齐文档，沿用既有验证证据，未新增运行验证。

2026-10-11 CAP-004／CAP-009 设置迭代：Core 新增 builtin-entry-bar:2 的外框、背景配色、透明度与稳定 ID 调序；设置三个固定页签、业务入口按高度分页。新增22对资源，当前519对；1156项入口专项、40项语言布局、175项语言契约通过，严格静态检查零缺失／未知／参数差异／硬编码。业务源码与接入范围未变；客户端验收待完成。

2026-10-12 CAP-004／CAP-009：Core 通用和信息条成为独立设置页，入口列表合并仅注册设置的插件，使用显式分页与总数；统一控件高度、行距和紧凑宽度。当前526对资源，1116项入口专项、58项语言布局通过；能力仍 API13 / account-entry:2 / builtin-entry-bar:2，业务源码与接入状态未变，客户端修正版待验收。

2026-10-12 本轮调整：点击 Core 常规设置直接显示语言与悬停，信息条与窗口等导航缩进为下一级。显示与入口完整展示注册的业务页面与独立设置，每个插件30高单行、38行距、共享表头，字段下拉仅显示数量；列表纵向滚动。builtin-entry-bar:3 增加图标拖拽调序，取消拖拽不改顺序，拖拽松开不触发打开页面；条与调序下拉统一使用去作者前缀的页面名称。Core 公共能力变化仅涉及 CAP-004／CAP-009，业务源码与接入范围未变。1133项入口专项、58项语言布局与532对资源严格检查通过；客户端交互仍待验收。

2026-10-12 文案与高度调整：Core 子页面统一导航按钮和文字锚点，信息条与其它子项对齐；设置隐藏重复页说明，入口表移除重复提示、注册数量与底部提示，保留字段表头、操作控件及必要风险确认。语言、重载、信息条拖拽与仅设置状态同步精简中英文。帮助页复用关于页高度规则，并优先读取关于页保存高度，覆盖旧帮助小窗口高度。1133项入口专项、61项布局（含子项对齐、帮助／关于默认及保存高度一致）、175项语言契约通过；532对资源严格静态检查无异常，客户端待验收。能力版本与业务接入范围未变。

2026-10-12 TaskHub 文案迁移：主总览、目标管理／编辑、Boss 目录、设置、悬停、HUD 与状态共 307 处静态资源调用使用 Core.Locale；英语列表分隔符已本地化。全量发布 Lua 静态检查 0 未处理候选、0 缺失英文／未知 key／格式参数差异；TaskHub 六个 Spec（683 项）与发布 Lua 语法检查通过。截图中业务来源动态名称仍由来源插件提供；英语客户端布局和完整登录验收待完成。CAP-009 接入状态仍为部分接入（自动化完成、客户端验收待完成）。

2026-10-12 Crafting 截图反馈修正（CAP-002／CAP-009）：已知专业显示按稳定 ID 优先使用 owner 双语资源，覆盖选择、列表、矩阵分组和详情，修复中文原生快照覆盖手动英文的遗漏。Core Theme 统一管理单选／多选下拉互斥与嵌套菜单关闭；Crafting 继续使用共用控件，无本地并行实现。公共接口与最低 API13 要求不变。CoreAdaptation、LocaleLayoutSpec 213项及运行文件语法检查通过；语言报告缺英文／未知 key／参数差异为0。原生配方／角色名称与历史数据保留，游戏菜单交互与专业显示待复验，状态仍为部分接入。

2026-10-12 YiboMail 1.2.8-api1 Core 1.12.0 / API13 适配：基础能力门槛增加 localization:1 与实际调用能力检查；Mail 玩家可见静态文本迁移到自有 zh/en 资源与稳定 ASCII key，目标操作检查 business-item-actions:1，action.todo 仍独立检查 API11 / business-providers:1。`YiboMail-API13-Report.md` 显示 0 硬编码候选、0 缺失英文／未知 key／格式参数差异；原生分类标记仅作内部识别。完整尺寸与中英文客户端、手动语言模式及登录验收待完成，故状态为部分接入。

2026-10-12 角色设置布局：信息条移至角色与排序、显示与入口之间；去掉三个导航资源文字内的前导空格，缩进统一由导航锚点控制。默认排序改下拉，操作按钮按文案宽度，业务等级过滤按宽度两至三列；角色档案过滤控件恢复分栏，等级输入固定120宽。Core 等级与短名输入改为既有 Theme:CreateInput（CAP-002 / basic-input:1），保留校验、回车保存、失焦保存和取消。仅 Core 消费实现接入变化，业务插件状态不变，无公共能力升版。206项布局覆盖中英文620／1200宽度、12业务过滤、共享输入与表达式保存、导航顺序与缩进；1133项入口专项通过。532对资源严格检查无异常，游戏内布局待验收。

2026-10-12 Vault Core 1.12.0 / API13 最新工作树复核：Vault 整体最低版本为 API13，启动时检查 `localization:1`、`business-services:1`、`character-name-format:1`、`basic-input:1`、`item-resolver:1`、`character-identity:1`、`account-entry:2` 及实际调用方法；能力不满足时提示并停止初始化。页面过滤输入迁移到 Core `CreateInput`，角色标签迁移到 `FormatName`，物品显示继续使用 ItemResolver；入口显式声明三个默认关闭通道；固定仓储页不需要 `account-surface-budget:1`。Core 最新 `business-item-actions:2` 向后兼容 v1，Vault 库存目标增强只调用并检查 v1；`builtin-entry-bar:3` 的拖拽排序由 Core 内部使用，Vault 未调用，不需依赖 v3。目标增强不满足 API13、`business-item-actions:1`、身份方法和 Core Contracts/绑定方法时单独停用。`vault.items` / `mail.items` 数据所有权和 Service 契约不变，Core 无需新增业务分支。语言静态报告为 0 硬编码候选、0 缺失英文、0 未知 key、0 格式差异；尚未做中英文游戏客户端与入口交互验收。

2026-10-12 YiboTodo 1.3.0 API13 适配：整体最低 Core API 升至13，启动检查 localization:1、account-view:2、character-identity:1、character-name-format:1、account-entry:2；目标操作仍独立检查 API12 / business-item-actions:1，Todo 来源仍检查 API11 / business-providers:1。角色名调用 FormatName，页面注册与部分基础 UI／帮助文本注册中英文资源；业务入口三通道默认关闭。语言检查报告显示 0 未知 key、0 格式参数差异，但有275个硬编码候选仍待人工分类／迁移，故 CAP-009 记部分接入。未进行客户端验收。

2026-10-12 YiboTodo 本地化续迁：完成账号矩阵状态与 Tooltip、农场／诺米状态、行动中心 Todo/Nomi 的动态状态原因、目标范围错误、共享清理说明、矩阵列标题和列表分隔符资源化。静态报告从415降至275个硬编码候选，语言资源引用由21增至152；未知 key、缺失英文和格式参数差异均为0。剩余候选主要在业务目录文本、探针／诊断与农场／日历的客户端原文匹配关键词；后者是输入匹配规则，不应翻译替换；客户端验证仍待完成。
2026-10-12 YiboTodo 目录名称渐进本地化：新增按稳定法术／物品／任务 ID 查询当前客户端显示名的辅助方法；成功时用于单配方冷却组、已记录任务、纳特鱼类与精确农场法术名称，API 缺失、数据未载入或返回空值时沿用原目录中文标签。任务投影按 questID 重新解析显示名，避免已保存的名称阻碍切换语言。中文农场关键词与暗月日历关键词识别保持原样，英文识别尚未验证，不计为完成；静态报告 275 项中按用户要求排除探针 57 项，本轮关注范围为 218 项，仍需按游戏实体名称、自定义目录文案及输入匹配规则逐类迁移。中文客户端行为以原标签和原匹配条件回退，英文客户端及目标 Classic API 实机验证待完成 / 2026-10-12

2026-10-12 Mail 英文截图修复（CAP-004／CAP-009）：账号／邮箱／规则控件复用 Theme 文字测量与既有共享控件，完整组换行；字段关联改用插件内部稳定 groupID，显示标题继续本地化。历史隐藏行停止逐条读取角色目录，角色名称仍经公开接口格式化。API13 门槛不变，无新公共能力。三个 UI Spec 与26个运行Lua语法检查通过，3411条历史模拟布局约0.02秒；游戏内待复验。CAP-002：账号搜索与规则输入继续公共输入，原生寄信控件保留原对象；NativeUI／RecipientUI／MailUI 的旧自建输入剩余范围仍待迁移，不据本轮尺寸修复升级为全部接入。

2026-10-12 Mail 1.2.9-api1 版本整理：合并 API13 适配与英文布局／历史性能修复，生成双渠道安装包；客户端验收状态仍保持待完成。

2026-10-13 YiboTodo 列头英文文案：CAP-009 接入范围内将职业列标题改为 `Cooldowns`，珠宝列标题改为 `JC`（Jewelcrafting 的常用缩写）；中文资源保持不变。职业列继续按图标内容宽度计算，珠宝列沿用当前语言标题测量，因此英语标题变短后列宽随之缩小。最低 Core API 与调用范围不变；游戏内英文／中文显示待验收。

2026-10-13 YiboTodo 设置页目录文案（CAP-009）：监控组标题和设置内静态目录项现在按稳定 group/item ID 查询 zh/en 资源，覆盖职业冷却、农场、诺米、日常分类、纳特、暗月与布林顿项目；业务设置页不再直接显示目录中的中文标签。角色动态采集名称仍遵循当前游戏 API 原文。Core API 与能力依赖不变；中英文客户端及手动语言模式待验收。

2026-10-13 YiboLegendary 2.2.0 API13 适配：基础初始化要求 `localization:1`、`character-name-format:1`、`account-view:2`、`account-entry:2` 与实际使用方法；注册中英文 Core Locale 资源，页面元数据、部分状态、设置、错误与人工确认已接入；角色显示与人工确认身份使用 Core `FormatName`；业务入口默认关闭三个通道。目标主动添加仍独立检查 API12 / `business-item-actions:1`。静态报告复核为305个硬编码候选、90个Locale引用，缺英文／未知key／格式参数差异为0；Catalog目录目标部分经稳定ID本地化，任务行动文案经Core.Locale解析。任务叙述、专有名词、路线说明及Model目标进度／任务诊断保留中文原文；英文范围限定为菜单、矩阵表头、按钮、控件和通用状态／错误提示，硬编码报告候选多为该业务文案且不作为此范围的未完成项；客户端待验收，故CAP-001／004／009均记部分接入。

2026-10-13 YiboLegendary 本地化续接（CAP-009）：Catalog扩展标签改为显式稳定键映射，消除动态 key 未知项；Data 任务行动与表格行动拆分为独立资源键，接入 Core.Locale。报告更新为305个硬编码候选、90个Locale引用，缺英文、未知key与格式参数差异均为0。任务定义和 Model 快照仍待迁移，客户端验收未完成。

2026-10-13 YiboLegendary 英文适配范围澄清（CAP-009）：任务步骤、专有名词、路线说明与目标进度缺少可靠原版英文来源，保留中文原文；英文适配聚焦菜单、矩阵表头、按钮、控件及通用状态／错误提示。静态词法候选数仍报告，但业务叙述候选不作为该范围的完成门槛。


2026-10-14 CAP-005：AltoBoss 五人本可选 DBM 适配器通过既有 Core events:1 发布 YIBOALTOBOSS_DUNGEON_COMPLETED v1 隔离事实；回调注册／注销、晚加载、版本化负载、Core 唯一角色ID／地图／难度／本轮校验与去重均由业务侧负责。无 DBM 依赖或 Core 业务分支，团本原生路径保持。最低 API13，接口与失效细节见 YiboAltoBoss/Docs/FivePlayerBossRecording.md；自动化通过，真实客户端待验收。

2026-10-14 YiboAltoBoss 普通五人本主表进度（CAP-009）：本轮完成集合投影到现有副本格及入口预览；新增 LOCKOUT.KILL_COUNT / LOCKOUT.CURRENT_RUN 双语资源，继续使用 owner Core.Locale:Get、API13 / localization:1。复用现有 Core 账号视图与入口，不新增公共能力。玩家截图已确认监狱三个 Boss 的历史采集；本次展示改动未运行自动化测试，中文／英文客户端及手动语言模式、击杀后显示和重置后恢复待客户端验收。

2026-10-14 CAP-008／CAP-009 AltoBoss 副本 TP：Core 提供 business-item-actions:3 / API13 的通用 Bind.compactTooltip 选项，保持既有调用默认行为与必要参数补充流程；契约见 API-v12-业务项目主动添加.md。AltoBoss 目标增强已检查能力3，副本格启用简短提示，缺能力提示升级并停止增强；基础采集／展示继续。副本 TP 使用既有 UITheme 双列／间隔／文本行，历史次数、最近时间、进入次数开关纳入统一业务设置；新增 TP.* owner 双语资源，历史默认关闭。CAP-001／CAP-004 继续复用现有账号视图、入口及工作台，不新增窗口或缓存权威。静态语法与语言检查通过，本次未运行自动化测试，客户端及交互验收待完成；按部分接入记录。其他插件与 AltoBoss Boss 格未启用简短提示，不推定其已接入能力3。

2026-10-14 CAP-009 AltoBoss 普通本显示时效：新增 TP.STALE／TP.STALE_HINT 中英文 owner 资源，离本 30 分钟后显示待刷新；业务时效和轮次事实仍由 AltoBoss 所有，复用现有 Core Locale／账号页刷新，公共契约与最低 API13 不变。Lua 语法与语言静态报告通过，本次未运行自动化测试，客户端计时／返回／重置及语言验收待完成。

2026-10-14 AltoBoss 2.6.1 对 Core1.12.2 审查：当前API13、localization:1、events:1／character-identity:1与business-item-actions:3调用兼容；InstanceKills带样本58项、BossGoals19项、CustomBossGoals25项通过。CAP-001角色名称、CAP-002公共输入、CAP-004旧独立设置分支与CAP-009其余界面语言仍未完成，保留部分接入／待迁移状态。发现Core TOC1.12.2与Bootstrap.VERSION1.12.1不一致，尚未修改运行代码。两组完整回归受前置测试阻断，详见 [审查报告](../../YiboAltoBoss/Docs/Core-1.12.2-适配审查.md)。

2026-10-14 AltoBoss API13 迁入收尾：按Core1.12.2既有能力补齐适用运行代码，删除独立设置壳、局部输入／名称／旧入口及窗口分支；统一工作台的数据区复用公共确认，历史不清除。Core Bootstrap版本与TOC对齐；CAP-004补齐既有预览字段group元数据传递并声明account-preview-field-groups:1，见[契约](API-v13-预览字段分组.md)。AltoBoss固定副本选择迁入Core显示与入口，旧选择导入previewColumns，客户端待验。适用代码与验证边界逐项见 [完整记录](../../YiboAltoBoss/Docs/Core-API13-完整接入.md)；保留客户端待验，台账不将其记为全部验收完成。

2026-10-15 CAP-004／CAP-009 AltoBoss设置页续改：公共能力调用无新增／遗漏，继续复用Core统一工作台、按钮／输入、BindTooltip与owner语言。业务规则前置，两个增长列表使用独立分页与窄宽度单列，破坏性操作保留数据区末尾及Core确认。新增5对资源（现316对），静态语法及语言报告通过；未运行测试，实际中文／英文客户端布局验收待完成。Core运行代码本轮无改动。

2026-10-15 CAP-004／CAP-009 发布记录：AltoBoss2.7.0与Core1.12.3 / API13同步发布，预览字段分组最低Core1.12.3 / account-preview-field-groups:1。保留本轮静态验证证据与客户端待验状态。

2026-10-15 YiboCurrency 0.9.1 对 Core1.12.3 / API13 只读运行代码审查：基础仍检查API9／business-services:1，目标增强独立检查API12／business-item-actions:1；CAP-001名称与CAP-009语言仍待迁移，CAP-004显示／悬停字段与排序仍保存在业务设置，待统一注册接入。CAP-002／003控件专项本轮通过；CAP-005 VaultIntegrationSpec原样因角色接口mock落后失败，仅内存补齐GetAllCached／Get后诊断通过，运行代码查询故障未据此成立。发现Core economy／economy-items仍采集并权威保存货币与代币，以及Core／Vault混合来源、未确认银行仍标known、容器兼容路径丢失carried问题；未改运行代码或删除历史数据。完整范围、证据与迁移顺序见[Currency适配与数据归属审查](../../YiboCurrency/Docs/Core-1.12.3-适配与货币数据归属审查.md)。上述状态未升级为全部接入或客户端验收完成。

2026-10-15 Reputation 1.7.1／Core1.12.4 声望归属迁移：CAP-004 接入 character-cleanup:1、角色身份事件与现有统一页面；CAP-005／008 action.targets 改读本地权威快照；CAP-009 补迁移、失败、诊断及缓存影响资源。Core 运行时停用声望域，旧域仅公开只读导入；未新增连接机制或业务 Service。87 项迁移专项、独立悬停、71 文件语法及语言检查通过；既有综合性能脚本被 AltoBoss 第107行断言阻断，未声称整体通过。真实客户端、旧数据最终清理及发布待完成，详见[实施记录](../../YiboReputation/Docs/声望数据归属迁移-实施与验收记录.md)。

2026-10-15 Reputation 数据迁移二次复查：CAP-004／005／008 公共调用边界不变，补充历史保留、重复导入、ID 重映射及 CharacterCleanup 验证。修复空失败占位阻断导入、标记存在而快照缺失不恢复、重复 ID 事件传播旧阻断，以及本地快照已就绪后 status 失败计数未收敛；原有91项加新增39项共126项通过。覆盖冷启动阻断持久化、Core完整旧来源不变、当前角色删除拒绝、owner失败重试、延后删除只执行一次与其它角色隔离。真实客户端验收仍待完成；详见[实施记录的二次复查](../../YiboReputation/Docs/声望数据归属迁移-实施与验收记录.md)。

2026-10-15 交付版本：Core1.12.4 / API13、Reputation1.7.1；提交推送并打包，保留126项迁移回归及客户端待验状态。

2026-10-15 Currency0.10.0收尾：Core1.12.4工作树按真实动态目录需求新增account-dynamic-fields:1，契约见[动态账号字段](API-v13-动态账号字段.md)。CAP-001～005／007～009按上表更新；CAP-006保持不适用。Core和Currency容器计数、确认来源完整度及中英文控件／版本停止回归已完成；RuntimePerformanceSpec在既有AltoBoss第107行阻断，HEAD AccountView诊断同样失败，未宣称整体通过。客户端尚未验收；[接入记录](../../YiboCurrency/Docs/Core-API13-实施与验收.md)与[数据归属方案](../../YiboCurrency/Docs/货币数据归属迁移方案.md)区分已完成代码和待确认迁移。无玩家存档迁移或清理。

## CAP-010：角色缓存所有者与延后清理

R2 Retail（2026-10-27）：清理基础设施v2已加载，目标期望owner为空（YBP离线业务尚未接入），已有存档／注册／历史owner合并规则保留。独立存档新增无戳拒绝策略，未改变Mists／Forever规则。真实删除／重放和退出恢复未据此判定通过，见[本阶段记录](R2-01-02-Retail目标与构建实施验收.md)。

R1-07复核（2026-10-27）：目标期望owner为Mists10／Forever6，继续合并存档和历史owner；新记录可选requiredOwners，旧记录兼容，pending不得裁剪。389项元数据／历史专项及59项既有清理回归通过，真实回放与恢复待验；接口与能力版本保持，见[本阶段记录](R1-07-08-目标元数据与通用契约实施验收.md)。

Core 1.12.5 / API 13 已发布 `character-cleanup:2`，兼容 v1：持久保存已登记所有者 ID，插件禁用后保留待清理记录；删除上下文提供 `deletedAt`、`deletionID` 与 `replay`。详见[契约](API-v13-档案业务字段与清理所有者.md)。

| 插件 | 状态与覆盖／剩余 | 验证／日期 |
| --- | --- | --- |
| YiboAltoBoss | 使用 v1 清理注册；本轮未要求迁移 v2 | 当前适配验收完成；仅生命周期变更时重审 / 2026-10-16 |
| YiboAutoOpen | 不适用：未登记角色档案缓存清理调用 | 当前功能已实机收口；现有可选Core边界见CAP-002／003／009 |
| YiboBeastPaths | 既有路线不适用；离线兽栏待接入 | 路线维护不作为角色缓存owner；R3已验证character-cleanup:2的单次owner、影响未知、失败pending与逐组时间回放，实际YBP未登记新owner；最近审查2026-10-27，后续按[R3支持契约](API-v13-YBP离线兽栏公共支持契约.md)接入 |
| YiboBuilds | 已接入 v2：Inspect／Delete、别名清理及回放保留新观察 | Core13Spec 覆盖旧观察、别名、重采、未来时间与直接删除；用户验收完成 / 2026-10-16 |
| YiboCrafting | 使用 v1 清理注册；本轮未要求迁移 v2 | 当前适配验收完成；仅生命周期变更时重审 / 2026-10-16 |
| YiboCurrency | 已接入 v2：显式检查能力、注册 Inspect／Delete，阻止旧数据复活 | CoreSpec 23 项、Retention 107 项；用户验收完成 / 2026-10-16 |
| YiboLegendary | 使用 v1 清理注册；本轮未要求迁移 v2 | 语言候选暂缓事项见 CAP-009；仅生命周期变更时重审 / 2026-10-16 |
| YiboMail | 使用v1清理注册；本轮未要求迁移v2 | 用户2026-10-16确认当前功能实机收口；仅生命周期变更时重审 |
| YiboMounts | 不适用：未登记角色档案缓存清理调用 | 当前适配验收完成 / 2026-10-16 |
| YiboQuestBlocker | 使用 v1 清理注册；本轮未要求迁移 v2 | 当前适配验收完成；仅生命周期变更时重审 / 2026-10-16 |
| YiboReputation | 使用 v1 清理注册；兼容性与现有调用已验证，未改为要求 v2 | Retention 126 项；用户验收完成 / 2026-10-16 |
| YiboTaskHub | 不适用：未登记角色档案缓存清理调用 | 当前适配验收完成 / 2026-10-16 |
| YiboTodo | 使用 v1 清理注册；本轮未要求迁移 v2 | 当前适配验收结论见基线；语言候选延期见 CAP-009 / 2026-10-16 |
| YiboVault | 使用 v1 清理注册；本轮未要求迁移 v2 | 当前适配验收完成；仅生命周期变更时重审 / 2026-10-16 |

2026-10-15 Currency 货币归属实施与保留验证详见[实施与验收记录](../../YiboCurrency/Docs/货币数据归属迁移-实施与验收记录.md)。v2 是向后兼容扩展；除 Builds 与 Currency 已接入、Reputation 保留 v1 外，本轮不将 v2 接入列为适配阻断项。

## 后续更新记录

2026-10-15 Currency货币归属实施：Core1.12.4工作树停止货币域和目录采集，旧数据冻结；Currency0.9.1工作树接管原生余额与最小随身观察，通过公开副本导入，不自动清理历史。CAP-004／005新增通用档案字段Provider，`character-archive-providers:1`；CAP-010补动态所有者留存。CoreSpec23、迁移55、额外保留29（共107）、TOC额外15、容器额外10、双语API13四组各37、Vault／控件、EntryBar1133、声望126及语法／语言检查通过。真实客户端验收与发版待用户测试后处理，详见[实施与验收记录](../../YiboCurrency/Docs/货币数据归属迁移-实施与验收记录.md)。历史AltoBoss性能阻断已由用户反馈实测无问题，不作为本次交付阻断；未宣称旧综合脚本整体通过。

2026-10-15 Currency截图反馈：CAP-004接入现有autoFitWidth、FitRepeatedColumnWidth与GetColumnPageByWidth，主窗口优先完整角色列，悬停可在业务设置独立转置；实际方法检查齐全，未变更Core能力接口。CAP-009新增业务设置／转置开关中英文资源；四组API13各47项、设置控件及完整迁移回归通过，客户端待复测。版本保持原值，未提交、推送或打包。

2026-10-16 Currency自定义物品设置反馈：CAP-004在现有Core托管业务设置内恢复已保存目录列表，复用公共按钮、文本、Tooltip、ItemPicker与确认流程，不新增通用字段选择或本地设置窗口；CAP-003确认边界保持，CAP-009新增5对列表／空状态／分页资源。中英文控件及完整迁移回归通过；用户确认当前适配验收完成。Core公开契约没有变化，未改运行时版本或提交发布。

2026-10-16 Currency单项提示／分页复核：CAP-004继续复用Core矩阵、完整自然宽度、分页和Tooltip基础，补齐自然尺寸的滚动槽预算与向上取整，修复13角色末列被挤至第二页；单项提示共享Projection，不另查第二份库存或排全角色副本。CAP-009复用既有owner资源，无新硬编码。四组API13各51项及完整迁移回归通过；用户确认当前适配验收完成，无Core公共能力契约变化。

2026-10-19 Currency货币目录与显示管理：CAP-004按用户要求在Core托管货币设置中统一内置／自定义项目的主窗口、悬停两列显隐；主窗口右键与行内勾选共用稳定ID操作，Core通用字段设置读写相同状态；悬停保持只读投影。CAP-003复用物品Picker和确认框，拖入只加入目录，移出目录位于数据与缓存末尾并确认。CAP-009补齐中英文表头、目录操作、状态反馈与说明。最低版本和Core公开契约不变，补齐实际UI方法检查；离线证据及客户端待验收范围见[货币目录与显示管理](../../YiboCurrency/Docs/货币目录与显示管理-实施与验收.md)。

2026-10-19 Currency显示管理复核：CAP-003／004补齐新增自定义项目的目录页定位，超过24项时加入后自动显示所在页。遍历48项内置与1项合成自定义目录，四种语言组合API13各1102项覆盖四种显隐组合、设置／主窗口操作／悬停投影同步；实际Picker补查取消加入、取消移出、确认移出、重新加入与内置项目保护。CAP-009本次未新增文案，本地化报告无缺英文／未知键／参数差异／硬编码候选。客户端复验仍待完成，详见货币目录与显示管理记录。

2026-10-19 Currency设置分页面：CAP-004使用Core托管上下文的availableHeight，将内置目录独立为一页，自定义目录、悬停转置和目录管理集中于另一页；按高度调整目录分页容量，加入定位按实际页容量计算。模拟高度480／600、48项内置／6项自定义及长列表检查通过，Core契约与最低版本不变；CAP-009更新中英文页签。实际客户端布局待复验。

## CAP-011：当前角色专业档案

Core实现：Forever0.2.0／API13提供 `profession-profile:1`，复用 `data-domains:1` 的professions v1及DATA_DOMAIN_UPDATED；支持七个专业来源位、稳定skillLineID和技能等级，明确副专业精确ID。接口与失败／时效／所有权见[专业档案契约](Forever-专业档案契约.md)。MoP原采集器未统一提高要求。

最近审查：2026-10-20。Core／Crafting联合69项及Core双端69项通过；新能力全部待实机。

| 插件 | 接入状态与范围 | 剩余范围／证据 |
| --- | --- | --- |
| YiboAltoBoss | 待评估 | 未涉及专业调用，不能推定已接入 |
| YiboAutoOpen | 待评估 | 未涉及专业调用 |
| YiboBeastPaths | 待评估 | 未涉及专业调用 |
| YiboBuilds | 待评估 | 后续构筑涉及专业时审查 |
| YiboCrafting | **部分接入**；Forever已检查能力并通过公开professions域查询本人专业、显示档案、授权配方扫描；无本地专业回退 | 69项包含七位、档案错误保留／恢复、MoP副专业兼容与消费方停止行为；实机待验。Mists原professions域路径保留 |
| YiboCurrency | 待评估 | 当前Forever金币版无新增专业调用；旧范围待审 |
| YiboLegendary | 待评估 | 未涉及专业调用 |
| YiboMail | 待评估 | 未涉及专业调用 |
| YiboMounts | 待评估 | 未涉及专业调用 |
| YiboQuestBlocker | 待评估 | 未涉及专业调用 |
| YiboReputation | 待评估 | 未涉及专业调用 |
| YiboTaskHub | 待评估 | 来源及资格契约需要时审查 |
| YiboTodo | 待评估 | 后续专业冷却适配时审查 |
| YiboVault | 待评估 | 未涉及专业调用 |

2026-10-20 Crafting Forever 0.1.1诊断复核：CAP-004复用Core.UITheme按钮，CAP-009复用owner中英文资源，最低Core0.2.0/API13与能力要求不变。CAP-011专业档案已有制皮26/75实机对照，其余字段／恢复待验；Crafting配方采集报错，仍为部分接入，不能用档案展示代替业务采集验收。新增76项联合模拟包含诊断失败定位、脱敏和窗口复用；不新增Core契约。


## CAP-012：日历当天查询

最近审查：2026-10-22。Core Mists 1.12.8／API13提供 `calendar-day-query:1`，目标适配位于 `Mists/Calendar.lua`；[接口、最低版本、保护范围与失败语义](API-v13-日历当天查询.md)。Core实现与离线验证已完成，新增代码实机与发行检查待验；Forever未提供。Core不拥有活动业务规则或存档。

| 插件 | 接入状态与范围 | 剩余范围／证据 |
| --- | --- | --- |
| YiboAltoBoss | 部分接入；Mists节日日历通过目标适配层使用Core，启动检查新能力，无本地回退 | CalendarAnchor12、HolidayBoss284、BossGoals19、CustomBossGoals25；完整客户端与安装包待验 |
| YiboAutoOpen | 待评估 | 未触及日历查询 |
| YiboBeastPaths | 待评估 | 未触及日历查询 |
| YiboBuilds | 待评估 | 未触及日历查询 |
| YiboCrafting | 待评估 | 未触及日历查询 |
| YiboCurrency | 待评估 | 未触及日历查询 |
| YiboLegendary | 待评估 | 未触及日历查询 |
| YiboMail | 待评估 | 未触及日历查询 |
| YiboMounts | 待评估 | 未触及日历查询 |
| YiboQuestBlocker | 待评估 | 未触及日历查询 |
| YiboReputation | 待评估 | 未触及日历查询 |
| YiboTaskHub | 待评估 | 本次仅验证来源消费，不直接读取日历 |
| YiboTodo | 部分接入；Mists暗月及节日日历统一消费Core，启动检查新能力，无本地回退 | CalendarAnchor12、DarkmoonCalendar／Cycle与SpecialActivity通过、TodoSources177；完整客户端与安装包待验 |
| YiboVault | 待评估 | 未触及日历查询 |

Core CalendarDaySpec16项通过；三插件TOC语法107文件及Mists构建ValidateOnly通过。用户输出证实59个月相对查询返回0、绝对切至当前月后返回3；换角色恢复不算新增代码实机通过。BossTargetsSpec在既有前置ActionIntegrationSpec:188本地化夹具断言失败，未进入本轮断言；EventGoals既有前置provider-error仍未解除。


2026-10-22 CAP-012启动就绪补证：首份客户端追踪显示加载阶段C_DateAndTime返回1999-00-00、日历浏览2004-11，登录前恢复2026-10，后续Questie／MountsJournal调用未造成异常；未复现此前2021-11，来源保持待定。Core Mists日期读取增加有效范围校验，接口存在但失败或返回无效日期时保持未知，不用本机日期回退或据此校正基准；calendar-day-query:1及既有接入不变。Core CalendarDaySpec新增3项后19项通过，联合12、Todo暗月两组及AltoBoss HolidayBoss284通过；新保护客户端待验，两业务插件保持部分接入。原始日志与分析见[首份日历调用日志分析](../../_NonRelease/CalendarAnchor/Trace-Analysis-20261022.md)。
