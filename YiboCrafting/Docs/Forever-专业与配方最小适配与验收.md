# Forever 专业与配方最小适配

日期：2026-10-20；最近更新：2026-10-24。状态：**档案与页面部分实机通过；0.1.2配方归属补修离线通过，待实机复验**。

| 目标 | 版本／清单 | 存档 |
| --- | --- | --- |
| Core Forever | 0.2.0／API13，YiboCore_Forever.toc | YiboCoreForeverDB，专业档案由Core拥有 |
| Crafting Forever | 0.1.2，YiboCrafting_Forever.toc，Interface16001 | YiboCraftingForeverDB，schema1 |
| Mists | Core1.12.7／API13、Crafting1.2.1，原清单 | 原库与模块集合 |

## 最小范围与所有权

Core先提供真实需要的当前角色专业名称、稳定skillLineID及技能等级，详见[专业档案契约](../../YiboCore/Docs/Forever-专业档案契约.md)。Crafting只拥有配方观察：当前角色、当前本人专业窗口中可读的recipeID、名称、明确learned布尔值和观察时间。学习状态与可制造、材料数量、冷却及营地设施要求分别处理；本版不推断后四者，也不执行制造、学习、打开或关闭专业窗口。

不加载MoP配方／分类目录、IsPlayerSpell扫描、GoalTargets或旧跨角色业务页面。Mists共享文件仅增加目标保护；目标层与当前中英文资源复用，新增资源在Forever/Locale.lua按owner注册。没有跨业务依赖、私有存档访问或目标占位服务。

## 本人列表与采集

来源核对于2026-10-20：[Forever专业工具源码](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_Professions.lua)、[配方与专业结构](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUITypesDocumentation.lua)及[生成的接口声明](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua)。列表枚举还需本机GetAllRecipeIDs运行结果核对；既有探针中的函数存在不等于本轮业务已验证。

- 进入世界、收到TRADE_SKILL_SHOW且原生ProfessionsFrame可见才扫描；要求IsTradeSkillReady明确true，链接／公会／公会成员／NPC列表检查均明确false。能力缺失保持未确认，不放宽本人来源条件。
- 当前BaseProfessionInfo的parentProfessionID或professionID必须精确匹配Core已知专业ID；不按名称关联。每条配方先核对GetProfessionInfoByRecipeID；专业元数据不匹配时，以IsRecipeInSkillLine对当前子／父技能线的明确布尔结果确定归属，明确无关项跳过，不确定时保留旧快照并停止。采样前后professionID／父ID／sourceCounter及当前GUID保持一致。
- 读取GetAllRecipeIDs和逐条GetRecipeInfo，验证连续列表、重复／非法ID、名称、明确learned状态、secret及dummy标记；虚拟条目不存为配方。连续两次候选一致后原子提交。缺字段、nil信息、错误、异专业或中途切换均保留旧批次。
- 全空结果不证明专业没有配方。覆盖始终为部分观察；过滤、折叠或未列出的项目保留旧事实并显示上次快照，不由缺失推出未学。明确返回learned=false才保存未学；已学变化可覆盖该配方的旧事实。
- 关闭专业／离开世界取消排队任务，旧快照不再标为新鲜。Source变化使未执行任务失效；高频列表／学习事件合并采样。Core专业移除后，该专业旧配方留存但不准入当前视图，也不能授权扫描。

## 独立保存、Core和页面

保存范围为 `clientScope={target="Forever",projectID=18,scope="current-character",rulesetState="unknown"}`。以Core GUID、professionID、recipeID关联，不使用名称或列表位置。库只保存配方事实，不复制专业档案；查询返回副本且只允许当前GUID。未来schema、异范围或非法结构在修改前拒绝，不导入Mists库。默认Mists清单若强制加载到Forever，在初始化写库前停止。

最低Core Forever0.2.0／API13，显式检查profession-profile:1、data-domains:1、events:1、localization:1、character-name-format:1、character-identity:1、characters:1、character-cleanup:2、account-view:2、account-entry:2、account-preview-characters:1、account-character-admission:1、account-surface-budget:2及实际方法。旧Core0.1.0缺少专业能力时提示升级并在建库前停止，无本地平行专业采集。

本次复用CAP-001／004／007／009／010，新增专业档案能力记CAP-011。没有输入、物品解析或跨业务查询调用，CAP-002／003／005本目标不适用；原Mists要求保持。

Core页面crafting显示当前角色、专业名称与技能等级、配方、学习及数据状态；Core统一管理字段、角色准入、入口和窗口。滚动使用Core控件，按视口复用行，3003项快照不一次创建3003组控件；主窗及悬停复用同一快照。当前没有额外业务设置，独立入口三通道默认关闭。关于页加入当前目标说明。

新增三字母命令 `/ycr`，注册前已全工作区检查SLASH；未与其它插件冲突，独立探针使用/yct。`/ycr`打开，`/ycr scan`刷新并输出状态，`/ycr status`仅输出状态；0.1.1增加 `/ycr report` 只读采样并展示可复制诊断；无旧别名。共享语言由Core管理，新资源无中文硬编码。

角色清理注册Core v2；取消该角色排队扫描，历史删除回放保留删除之后的新事实；清理其它角色不应影响当前采集。不会自动清理玩家历史。真实SavedVariables位于无限客户端WTF对应YiboCrafting.lua，表名YiboCraftingForeverDB。

## 离线证据

- CraftingForever Smoke **76项通过**，加载真实Core／Crafting清单；涵盖七专业位／副专业ID、正负学习事实、变化、过滤遗漏、本人来源四种拒绝、就绪、重复／空／失败／secret／异专业、保存恢复、清理回放、旧Core／缺能力、错目标、四语言、同源预览及3003条行复用。
- Crafting原7组测试全部通过：CoreAdaptation、CoreNameIntegration、GoalTargets、RecipeScanScheduling、RecipeStateScanner、SearchPerformance、Smoke；MoP原采集、控件、业务目标和扫描保留。
- Core69、Currency60、Mail69、Reputation91、Vault2874通过。Core／Crafting四清单70个Lua文件语法通过；Core Mists1.12.7／Crafting Mists1.2.1构建ValidateOnly通过，无新包或上传。
- 本地化报告生成并查看：Core545资源缺英文／参数差异均0；6个既有未知key均AutoOpen。Crafting原165条候选未在本次扩大迁移；新Forever文件无中文硬编码，四语言模拟不代替客户端布局验收。

## 待实机与发布状态

2026-10-20用户截图（2024e3d1）：0.1.0窗口与专业档案展示通过，制皮26/75与原生一致；另显示剥皮83/150、急救38/75、钓鱼1/75、烹饪1/75，尚未逐项原生对照。本人制皮窗口已打开，但配方读取报错、无配方行，属于实机阻断，不能记为配方采集通过。

0.1.1仅补充定位证据，未放宽采集校验、未宣称根因已修复。重载后保持本人制皮窗口打开，执行 `/ycr report`，Ctrl+C复制报告。报告包含最近一次扫描的失败阶段、配方ID、最多24条API返回摘要及关键接口可用性；每张表最多12个字段、字符串最多160字符，限制值先脱敏。报告仅存会话，不新增SavedVariables或普通入口；不执行制造、不改变原生过滤。诊断界面和可复制内容仍需实机验证。

修复后再验证：学习一门专业后，先在Core角色档案核对名称和技能等级，再正常打开本人原生专业窗口，用 `/ycr`／`/ycr scan` 对照已有配方。确认至少一个已学与一个API明确列出的未学项目；原生界面没有负样本时保持待测，不能凭缺失补造未学。

后续验证：专业升级与新配方、过滤不丢历史、切换／关闭／重开、本人与链接／公会来源、重载及完整退出恢复、语言／入口／预览及MoP共享改动回归。特殊专业、完整目录、材料／产物／冷却、制造场所与账号共享不在本版声明内。

当前新增TOC、Core专业文件及Crafting目标文件，首次验证应完整重启客户端。仍无插件级Forever发行配置，**尚不可发布**；统一状态见[无限服台账](../../Docs/无限服适配与发布验收台账.md)。

本次Core公共能力复核：诊断按钮复用Core.UITheme，文案使用现有localization:1 owner资源；专业域、角色标识、清理及账号页面调用契约不变，无新增公共能力迁移。

2026-10-23集中准备：76项目标回归再次通过，新增7个目标同载及3组探针的联合验证268项通过。本轮未取得 `/ycr report` 实机返回，配方失败尚未定位或修复。新增独立[成长与收藏探针](../../_NonRelease/YiboProgressForeverProbe/README.md)在 `/ypg cooldown` 同时记录准备/本人来源标志、BaseProfessionInfo、全部/筛选ID及配方/归属原始多返回，可与0.1.1诊断交叉核对；不改变正式Scanner校验或业务版本。按[集中批次F01](../../Docs/无限服-集中开发与测试批次-2026-10-23.md)一次打开本人窗口取证；新探针72项通过，实机待测。无正式业务运行diff或Core契约/接入变化。

## 2026-10-24集中实机初始页面

2026-10-24 B01/Crafting页面反馈：用户未按本轮步骤打开原生专业窗口，截图显示YiboCrafting v0.1.1、当前角色天堂-CAMWOW CN1 Realm 2 PvE；专业档案列出制皮33/75、剥皮83/150、急救38/75、钓鱼1/75、烹饪1/75。状态为“专业窗口已关闭，显示上次观察的配方。”，配方表头可见但无数据行。登记0.1.1页面与五项专业档案展示，不将数值判为已与原生专业逐项对照，也不将空配方或关闭提示判为配方采集阻断已修复。原配方失败继续保留，B02一次打开本人专业窗口时采/ycr report、原生对照及/ypg cooldown。证据：`F:/Temp/User/codex-clipboard-4fff5a87-9bf2-440e-a815-4c92135f733d.png`。下一步B01货币总览页面。

## 2026-10-24制皮配方失败复现

2026-10-24 B02失败复现：用户反馈Crafting只能看到急救，看不到其它专业。截图同时显示本人原生制皮窗口33/75及多项制皮配方，Crafting0.1.1顶部制皮33/75一致；插件状态为“配方读取失败或内容变化，已保留上次快照。”，当前可见行均为急救配方，数据状态“上次快照”，包含已学／未学行。制皮当前等级33/75原生对照通过；制皮配方读取失败复现，未将急救历史行误认成成功采集的制皮，也不因页面可滚动推断完整数据库仅有急救。其它专业是否分别失败仍须各自证据。未见用户提供Lua异常，不将业务失败状态等同Lua异常。检查现有Scanner与/ycr report实现：报告会在原生窗口保持打开时重扫，输出state/detail及API原始返回，须先获取报告定位实际失败点，不放宽本人来源／专业匹配／原子保存校验。证据：`F:/Temp/User/codex-clipboard-ff241c96-a4e0-404e-8a3e-2b0b04d05492.png`。下一步保持当前制皮窗口打开执行/ycr report复制完整报告；运行代码与客户端载荷未改。

## 2026-10-24诊断首报窗口关闭状态

2026-10-24 B02诊断报告首次返回：YiboCrafting Forever0.1.1；state=closed、detail=context、inWorld=true open=false；GetAllRecipeIDs/GetRecipeInfo/GetProfessionInfoByRecipeID/GetBaseProfessionInfo/IsRecipeInSkillLine均function。无API调用trace，故本次/ycr report触发的重扫在Context窗口检查前段停止，不能据此定位先前制皮配方失败点，也不能把API存在判为返回正确。代码核对：open由TRADE_SKILL_SHOW/CLOSE事件设置，Context还要求ProfessionsFrame可见；report会先重扫并重置trace，可能覆盖先前失败信息。实际窗口是否已关闭、事件状态是否不同步尚未区分，不责归用户操作，不判根因。下一步重新打开本人制皮并保持可见，不按Esc关闭，直接聊天/ycr report；若仍closed且原生窗口确实可见，则按窗口状态同步缺陷继续排查。原始报告按本段完整保留；未修改运行代码或载荷。

## 2026-10-24跨专业配方归属补修

2026-10-24 B02配方专业匹配补修（Forever0.1.2，待实机）：用户0.1.1报告state=error、open=true，失败于recipe_profession:461692 expected=165；该ID配方名称“合成戈多克食人魔装”、learned=false，GetProfessionInfoByRecipeID返回parent197/child2948（裁缝），此前正常记录返回parent165/child2945（制皮）。证明原扫描在专业元数据不匹配时整批拒绝，未证明该配方一定不属于制皮。补修对元数据不匹配项调用IsRecipeInSkillLine(recipeID, 当前childID)，明确false后再查当前parentID（两ID相同时只查一次）；任一true时按当前本人专业收录，均false时仅排除该项，未知／受限／缺API／异常仍停止整批并保留旧快照。未硬编码461692或165、197等业务样本ID。两次采集及来源一致性检查保持；全排除后仍pending，不写已知空；已有历史观察按原部分快照规则保留。报告trace增加第二参数，便于实机核对技能线结果。函数签名核对Forever生成文档：https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua#L944 。原报告附件C:/Users/Administrator/.codex/attachments/ce5b6240-6923-4b03-bcb8-9982007f9062/已粘贴的文本.txt不含新增运行脚本指令。

离线：Crafting专项92项通过（含实际失败形状、共用配方child/parent归属、明确异专业、查询失败／非布尔／受限、缺API、两遍变化、全排除保留）；七业务三探针联合268项通过；Mists positive-cache Smoke与RecipeStateScanner通过；Scanner/Namespace语法通过。本地化报告已生成并查看：缺英文0、参数差异0，6个既有未知key均在AutoOpen旧CoreIntegration，本次无玩家可见资源新增。初次新测试夹具曾因模拟重复专业ID导致profile拒绝，修正夹具后专项通过，不将失败首跑隐去为运行修复缺陷。

迁移／Core审查：职责单元原已在Forever/Scanner.lua，无新增共用客户端分支或未迁移职责；只改该目标Scanner、Namespace和Forever TOC版本，Mists加载链与版本不变。继续使用Core0.2.0/API13、profession-profile:1、公开当前角色身份与既有Locale/UI/存储边界；无Core调用接入变化或遗漏，无需更新公共能力迁移条目。SavedVariables/schema不变，未直接访问其它业务插件；旧文件不会新增加载引用，干净／保留旧文件覆盖的正式发行验收仍待。运行文件只有原位修改，不删除或新增加载路径。

部署：Forever YiboCrafting仍为指向仓库YiboCrafting的Junction，已核对；无需复制到Vault或恢复任一独立测试目录。已加载游戏内仍可能为0.1.1；由于本次TOC版本变更，下一步完整退出再启动，核对页面0.1.2后打开本人制皮复验并采/ycr report。未主动操作客户端/WTF，也未自动重载。代码补修与离线通过不解除实机阻断，0.1.2继续待实机，不可发布。

## 2026-10-24 0.1.2剥皮正向样本

2026-10-24 B02/0.1.2首次复验截图：页面版本YiboCrafting0.1.2，用户当前原生打开剥皮窗口86/150，插件专业档案剥皮86/150一致。原生“营地椅子”可见，插件剥皮同名行标“已学／本次已观察”；另有捕兽者工作台与野外指南未学、本次已观察。制皮多条配方行已可见，但均标“上次快照”，证明已有制皮历史观察存在，不据此关闭先前当前制皮采集失败场景。插件状态已为“已采集当前专业可读的配方；尚不代表完整目录，未显示的项目不判为未学。”，无前次配方失败提示。登记0.1.2剥皮等级86/150与营地椅子已学正向样本通过，暂不将原生未显示项的未学状态或全部专业／配方判通过。证据：`F:/Temp/User/codex-clipboard-6574ab00-040d-46f9-9cb2-2c3ad2a04d78.png`。下一步仅切回本人制皮，不reload、不手动刷新，观察状态及原生可见已学配方对应行是否为本次已观察，补原失败场景直接证据。


2026-10-24 B02目标差异补充：用户明确指出“剥皮的配方是无限服特有的，其它游戏版本剥皮是没有制造配方的”。按本次范围记录Forever剥皮制造配方为已取得原生正向样本的目标特性；其它目标保持既有专业规则，本次不得因Forever样本扩展MoP剥皮制造能力，跨版本全局结论不另作未经取证的外推。当前实现已通过Forever本人专业档案及原生窗口／API采集，无新增跨目标剥皮白名单。用户补图仍为原生剥皮86/150、营地椅子；插件剥皮行本次已观察、制皮行上次快照，与前次同场景复用，不追加为制皮实时采集通过。证据：`F:/Temp/User/codex-clipboard-b1f543d5-467b-4314-b789-9b2144674647.png`。下一步切换原生制皮窗口后复验，不重复剥皮已通过样本。

## 2026-10-24 0.1.2制皮失败场景复验

2026-10-24 B02/0.1.2制皮原失败场景直接复验：用户按不手动刷新、切回本人制皮步骤提供截图。原生制皮33/75、营地帐篷可见；插件Crafting0.1.2专业档案制皮33/75，状态为已采集当前专业可读配方，无先前读取失败提示。当前可见制皮未学行均由上次快照变为本次已观察，剥皮营地椅子等行转为上次快照。登记制皮原先整批失败在本场景已不复现，切换专业后的新旧快照标记行为通过；不据截图未显示的营地帐篷插件行推定该已学状态已对照，不判全部专业／配方／恢复验收通过。原生未显示的未学配方仍待明确原生样本核对。证据：`F:/Temp/User/codex-clipboard-6bc559fa-ff1b-4e5f-9de8-928379fbf13a.png`。下一步仅在插件列表向上滚动找到营地帐篷，与原生已学正向样本同屏对照，无需制作、重载或手动刷新。

## 2026-10-24营地帐篷已学正向对照

2026-10-24 B02/0.1.2制皮已学正向样本：用户同屏截图显示本人原生制皮33/75，营地帐篷可选择且有制作按钮和材料需求；Crafting0.1.2对应“制皮／营地帐篷”行明确“已学／本次已观察”，状态为当前专业可读配方已采集。营地帐篷名称、已学和当前观察状态对照通过，结合上一截图制皮失败场景已复验，关闭该具体配方采集阻断的复现项；其它专业、明确未学原生对照、学习变化、过滤遗漏、关闭恢复及跨角色等继续待验，不判整插件测试完成。周围未学行不因未在原生显示而判学习状态准确。证据：`F:/Temp/User/codex-clipboard-5a78b41a-febe-4af3-acf0-46b0c2f1817e.png`。下一步保持本人专业窗口打开，用既有/ypg cooldown再/ypg report取原始专业／配方／冷却输入，复用同次窗口操作；未有真实冷却对象时仍标待样本，不要求制造。

## 2026-10-24专业／冷却原始报告审查

2026-10-24 B02专业／冷却探针报告：用户提交YiboProgressForeverProbe0.1.0 cooldown样本1/session29，build1.60.1.70450、Interface16001、project18、zhCN，原生IsTradeSkillReady=true、linked/guild/guildMember/NPC均false。GetBaseProfessionInfo返回professionID165、skill33/max75、sourceCounter7；GetAllRecipeIDs592项、GetFilteredRecipeIDs11项，列表结构未截断，但此事实不等同业务全目录已验证。详细行仅第1页100条，其中专业归属165共100、learned=true10／false90；100条GetRecipeCooldown均返回nil,false,0,0，未取得正向配方冷却。大量SPELL_UPDATE_COOLDOWN事件仅为原始法术事件，不据此认定专业周期，也不把nil当成业务已完成或无冷却。Todo F04/B13仍待真实对象及前后／到期／重置样本，当前无需制造或逐页强行补采。过滤与全部ID差异解释为可见范围不同的原始事实，不能用原生当前未显示项证明未学状态正确。原始附件C:/Users/Administrator/.codex/attachments/fc7a8973-b57b-4c5a-84f2-e9d7c140f5ce/已粘贴的文本.txt含观察者GUID与事件，保留在附件，不原样复制入仓库；脱敏统计保存_NonRelease/ForeverBatch/Parsed-CurrentCooldownReport.json（仅技术计数、返回形状，已省略角色身份／事件）。本次仅按字面表数据解析，未执行附件Lua。下一步尝试原生过滤器的未学视图，固定一条同名配方核对插件未学／本次已观察；无该过滤选项则记录条件后继续其它专业。

## 2026-10-24未学原生对照待条件

2026-10-24 B02未学配方对照条件反馈：用户明确无限服过滤器看不到未学配方，截图原生制皮过滤菜单仅见提高技能、材料齐备、栏位及其子项，无未学习入口。记录当前客户端／窗口无法通过该过滤器取得明确未学原生样本，跳过此取证路径；未学状态准确性继续待条件，不判通过或不适用，也不因API learned=false与原生未显示直接判已验证。保留既有已学正向和专业切换结果；不要求用户为测试学习、购买或制造。证据：`F:/Temp/User/codex-clipboard-fb583a2a-c3e2-4ad5-bc3b-b97969febe91.png`。后续遇自然可见的训练师／配方书等明确未学来源，再固定稳定ID作对照。下一步切到本人原生烹饪窗口并看Crafting当前专业与已学行，验证另一副专业；学习变化与保存恢复仍分别待测。

## 2026-10-26烹饪等级与切换

2026-10-26 B02/0.1.2烹饪初步复验：用户按切换本人原生烹饪步骤提供同屏截图，原生烹饪1/75与Crafting0.1.2档案烹饪1/75一致；插件无读取失败提示，当前可见行均为烹饪且标本次已观察。原生左侧可见烧烤狼肉、草药烘蛋、接野猪肉（具体名称以客户端原文为准）、滑皮鲭鱼、闪亮小鱼等已学列表，以及选中的基础营火工具包；插件当前滚动位置展示另一批未学配方，不能据此判已学正向对照完成或学习状态错误。登记烹饪等级与专业切换／当前观察行为通过；未学原生对照仍受过滤器条件限制。证据：`F:/Temp/User/codex-clipboard-01d40c15-b0f6-4793-9ffd-7f4a3a9f985c.png`。下一步选择原生“闪亮小鱼”，在插件列表滚动找到同名行，同屏核对已学／本次已观察；不制作、不刷新。跨日期客户端build尚未重新采样，不推定本次已核对新build。

## 2026-10-26烹饪已学正向对照

2026-10-26 B02/0.1.2烹饪已学正向对照：用户同屏截图原生烹饪1/75，当前选中闪亮小鱼，可见配方详情、材料不足和烹饪用火要求；原生列表亦有滑皮鲭鱼。Crafting0.1.2同名闪亮小鱼、滑皮鲭鱼均标已学／本次已观察，烹饪档案1/75与原生一致。登记两条名称／已学／当前观察正向对照通过；材料不足、缺烹饪用火仅为原生可制作条件，不把其当未学，也不新增Crafting可制造能力验收。其余未学行仍未取得原生对照，保持待条件。证据：`F:/Temp/User/codex-clipboard-23474343-79e9-4525-872a-4bf8486aae1a.png`。下一步本人急救窗口，核对等级及原生可见已学绷带与插件同名行；不制作、不手动刷新。

## 2026-10-26急救正向对照

2026-10-26 B02/0.1.2急救正向对照：用户同屏截图原生急救38/75、亚麻绷带已在原生列表且选中；Crafting0.1.2档案急救38/75，同名亚麻绷带明确已学／本次已观察，当前状态为已采集当前专业可读配方，无读取失败提示。登记急救等级、专业切换与亚麻绷带已学正向样本通过。不据其它未学绷带行未在原生列表显示而判未学准确性通过；未制作，不新增学习变化或制造验证。证据：`F:/Temp/User/codex-clipboard-6f91b207-b705-4ec2-a1b5-206bf6c28c5b.png`。下一步查看本人钓鱼入口／原生窗口并与Crafting档案等级对照；是否存在钓鱼制造配方按本目标实际窗口记录，不由其它客户端推定，没有配方窗口时说明实际界面而非要求制造。

## 2026-10-26钓鱼空已学列表与未学目录边界

2026-10-26 B02/0.1.2钓鱼等级与未学目录观察：用户说明当前角色没有钓鱼配方，且其它专业也读到未学项。截图原生钓鱼1/75、搜索框无输入，列表显示“你当前的搜索条件没有任何结果。”；Crafting档案钓鱼1/75一致，钓鱼鱼缸／钓鱼架／钓鱼小屋均标未学／本次已观察，其它专业行标上次快照。登记钓鱼等级与专业切换标记通过；用户当前无已学钓鱼配方反馈按实际范围保留，不将原生空过滤列表扩展为客户端不存在这些目录条目。

当前Scanner枚举GetAllRecipeIDs并保存明确learned布尔值，因此能展示原生已学列表以外的API目录项；此前制皮592全ID／11过滤ID报告亦支持目录与原生显示集合不同。未学条目没有被判为已学，当前不因这项观察擅自更改功能为只显示已学，也不删除历史数据。但API目录／learned=false不证明本服可学习、可获取、来源或完整性；未学准确性独立原生样本仍待条件，不能用“原生没显示”代替对照。钓鱼没有已学正向样本，记待条件，不要求制造／学习。证据：`F:/Temp/User/codex-clipboard-032aef9f-0763-4791-a2e6-232f3cd501be.png`。下一步只关闭原生专业窗口保留插件，观察已有行转为上次快照、数据不清空及状态提示；保存／重启恢复仍并入B15。

## 2026-10-26关闭窗口与本阶段收尾

2026-10-26 B02/0.1.2关闭专业窗口反馈：用户按仅关闭左侧原生专业窗口步骤提供截图，Crafting0.1.2仍显示专业档案与原有配方，状态明确“专业窗口已关闭，显示上次观察的配方。”；原本钓鱼本次已观察行均转为上次快照，当前可见烹饪、剥皮行亦为上次快照，已学／未学标记保留。登记关闭后可见记录不清空、陈旧标记及状态提示通过，不以可见行证明全库逐条一致，也不外推reload或完整退出持久化通过。证据：`F:/Temp/User/codex-clipboard-81df5c4e-edc1-4f6f-acd6-151421b187ad.png`。

B02当前阶段收尾：制皮33/75及营地帐篷、Forever剥皮86/150及营地椅子、烹饪1/75及闪亮小鱼／滑皮鲭鱼、急救38/75及亚麻绷带原生对照通过；钓鱼1/75与空已学列表／未学目录观察已记录；专业切换和关闭标记通过。明确未学原生样本、自然学习／专业等级变化、来源切换其它边界及保存恢复继续待验；真实冷却周期待样本，不判Crafting整插件测试完成。先继续可独立执行的B03天赋取证，B15统一做已采数据恢复，不重复安排本次关闭动作。下一步打开原生天赋并/ybf scan、/ybf report复制原始节点报告，无需洗点、加点或购买。
