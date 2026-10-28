# API13：R1共享底座兼容与失败契约

2026-10-27。本页汇总R1-01～09实际实现，不替代各专项API文档。R1阶段基线：Mists1.12.9／Forever0.2.0，API13、schema11。两端各33项能力，并集34项；R1时点尚未接入Retail；R2当前范围见[Retail验收](R2-01-02-Retail目标与构建实施验收.md)。版本号、源码存在、安装状态和能力声明不能代替运行就绪或客户端验收。

## 就绪与兼容性

- 依赖当前能力前检查Core存在、`IsInitialized()`、`CheckAPIVersion(13)`以及所需能力最低版本。旧文档中的v7、v9等表示首发接口门槛；本轮共享底座采用API13，新接入或实际触及语言服务的消费者同时检查`localization:1`。
- `Core:Initialize()`首次成功返回true；失败返回false及本地化消息，保留原存档，可在原因修复后重试。重复成功调用返回true，不重复注册或重发就绪。重入返回false及初始化中提示。
- `CORE_READY`成功提交后发送，事件回调形状为`function(owner, coreVersion)`，coreVersion是当前目标版本字符串。消费者既处理Core已就绪，也可订阅晚就绪；回调内重新检查API／能力，不依赖通知先后或重复次数。生命周期调用方协调注册一次。
- 能力名与版本以`HasCapability`／`GetCapabilityVersion`为准，不从插件版本推算。原API13及能力版本保持，R1没有新公开Service、占位Provider或业务能力。
- 强依赖Core的插件仍按统一TOC规范声明RequiredDeps并执行运行检查；可选增强按已确认范围隔离停止。YBP既有路线独立，未来离线兽栏依赖Core，本轮没有修改其TOC或业务初始化，也没有将其记为已接入。
- `Core.Client`及目标策略是Core内部实现边界；业务插件消费下列公开接口，不绑定内部reader／surface／target或访问其它业务私有存档。

## 当前能力与数据边界

| 用途／公开入口 | 最低能力（本轮API13基线） | 输入、输出与失败 |
| --- | --- | --- |
| Locale:Get／Core:Text | localization:1 | 稳定ASCII owner／key与完整格式参数；返回会话文本。缺英文回退中文，未知key返回诊断占位。语言偏好保存后重载生效，不改GetLocale或原生动态名称 |
| Characters:Get／GetCurrent／GetAll，identityOnly | character-identity:1 | 角色ID或当前角色；返回独立身份表／数组，缺角色nil，空目录空数组。角色显示名不作为关联键；GUID暂不可读不能虚构新角色；Mists既有legacy兼容与Forever真实GUID要求分别保留 |
| Characters:GetAllCached | characters:1 | 无参数；缓存有效时复用同一只读数组及记录，失效后重建。调用方不修改；需要可修改结果时使用GetAll，不要求每次复制全量域数据 |
| 角色名称显示 | character-name-format:1 | FormatName接收角色／显示选项；仅生成显示文本，不能把结果保存为角色ID或业务操作地址 |
| AccountView页面／范围／字段与预览 | account-view:2；按使用场景检查account-surface-budget:2、account-preview-characters:1、account-character-admission:1等 | 页面由业务提供快照准入、布局及显示数据；Core提供隐藏、范围、排序、尺寸和角色切片。主表与预览使用同一业务快照，缺快照不按零值或未完成展示 |
| ItemResolver:GetInfo／Parse／Request | item-resolver:1 | 正整数itemID、链接或显式名称查询；返回信息／候选或nil及本地化消息，异步请求返回取消句柄。具体字段与失败见下节；不采集库存或替业务判定可保存 |
| 输入／选择／确认 | basic-input:1；单项item-picker:1、批量item-picker:2 | Core提供控件、代次取消和确认生命周期；业务决定准入、操作和风险文案。Popup不可显示时取消当前确认，不执行操作 |
| Contracts:Register／Resolve／List／Call | business-services:1；多来源加business-providers:1 | 带owner／版本的服务与Provider；发现返回descriptor副本，Call返回业务结果副本。缺失／不兼容／注销／提供者异常返回nil与稳定错误码，不通过本地化文字判断业务状态 |
| ArchiveFields业务字段 | character-archive-providers:1 | 通过Contracts注册GetFields／Read；明确来源与角色ID，未知／非法值显示未知，重复字段隔离冲突来源；业务保持权威数据 |
| CharacterCleanup:RegisterOwner／GetImpact／RetryPending | character-cleanup:2 | Inspect／Delete由业务提供，Core传角色、别名副本和删除上下文，协调待重放历史。失败保留，确认不重复执行；不读取业务数据库 |
| AddonStatus:Get／GetAll | addon-status:1 | 插件技术名／当前目录；返回安装、启用、注册、版本及查询可用性。connected仅表示Core Registry登记；版本索引只表示打包时源版本 |

注册、冲突、注销的逐接口规则见[R1-07／08契约核对](R1-07-08-目标元数据与通用契约实施验收.md#注册冲突与注销契约核对)。保持同页／域／静态字段／清理owner重复ID报错；不把所有接口改成静默成功。页面注销关闭本页预览并释放实例槽，再注册执行新Create；用户设置保留。

## 物品与状态失败语义

`GetInfo(itemID)`每次返回新的`{itemID,name,link,icon,state,availability}`表，ID非法返回nil。

- `state`保持ready／unloaded／loading／failed，只有验证后的缓存名称存在才ready。
- `availability`为known／unloaded／error／unavailable，描述本次原生缓存查询，与请求是否正在loading是不同维度。原生异常、非法类型及秘密值不作为ready数据；缺缓存不等于物品不存在。
- `Parse`默认允许ID／链接、名称须显式启用；按ID去重和排序。名称候选不是存在性或业务准入证明。`includeBags`在Mists搜索0～4，在Forever仅明确报告ReagentBag=5时增加5；不含银行／其它角色，不承诺库存完整采集。读取失败返回nil及专用“随身背包暂不可读”提示，不能返回部分候选冒充完整结果。
- `Request(id,callback,{retry,timeout})`同ID合并；缓存就绪可同步回调。默认8秒，无效／无限／非正timeout使用默认值；原生事件不能订阅时仍有界轮询。失败后仅显式retry再次请求。Cancel只屏蔽该消费者回调，不承诺取消已合并的原生加载；UI还须校验代次和可见状态。
- callback接收`info,errorMessage`，失败消息用于显示，不能作为稳定业务匹配键。异步消费者异常隔离，不阻断其它等待者。详情见[物品与输入API](API-v7-物品选择与基础输入.md)。

AddonStatus保留`installed/enabled/connected/installedVersion/packagedVersion/state`，追加的`availability`表示状态查询可用性。原生信息或启用查询失败时不据此推断未安装／禁用；未注册时state为unavailable。已注册时state仍为connected，但不意味着其业务就绪。About本轮将显示文字明确为“已向Core注册”，并分别显示“状态暂不可读”“已安装但版本暂不可用”及已确认未安装。未查询到版本不制造版本号。版本值仅用于展示，不代替API／能力检查。

## 存档、快照与时效

Mists使用YiboCoreDB，Forever使用YiboCoreForeverDB，技术名／安装目录与schema保持。实际产品身份先于业务写库校验；存档预检／迁移在候选副本上执行，失败保留原表，成功才提交并通知就绪。启动前不能信任存档偏好时使用原生客户端语言的Core资源；通过预检并初始化后固定本会话语言。

数据域只有table＋known（或省略state的成功table）才替换；显式known空table可表示确认空。nil／部分数据＋error、unavailable、stale、not-yet-scanned保留旧值；known却没有合法table视为error。Core域updatedAt是状态／数据变化时间，不是所有成功采集的独立时间。

业务快照与业务重置规则归业务所有者。YBP未来自行记录随身／兽栏分组采集时间及可用性，Core不提供宠物采集／保存或路线“已拥有”判断。R1的合成消费者只验证公共框架，不表示YBP离线兽栏已完成。

清理owner由目标期望名单、当前注册、存档已知owner及删除历史合并；新历史可选requiredOwners，旧记录缺字段继续可读。历史目标外owner保留，缺失／失败owner待晚注册重放，全部已知owner确认且无失败才允许软上限裁剪。见[清理v2](API-v13-角色清理v2.md)。

## 目标与验证边界

源码默认YiboCore.toc仅提示；Mists／Forever源码目标清单分别加载62／59项，单目标玩家包输出所选清单为默认YiboCore.toc。两端目录14／6业务条目、期望owner10／6；YBP的Retail标记仅记录既有路线支持，不创建Core Retail实现。

本页契约在真实目标清单的离线夹具中验证。自动／手动语言、原生名称／字体／IME、真实宿主、战斗保护和WTF落盘恢复仍按客户端证据登记。统一构建ValidateOnly、语法及虚拟旧文件覆盖不等于最终包安装验收。最新结果见[R1-09收尾记录](R1-09-文案与契约文档收尾验收.md)，后续Retail接入和发布不得提前记为通过。

## R2追加（2026-10-27）

Retail0.1.0保持API13／schema11，提供32项共享基础设施；仅目录identity域与身份／等级两字段。它采用真实GUID、禁止legacy导入及非空无目标戳存档，使用YiboCoreRetailDB。专业／装备／位置／日历与宠物业务不提供，缺少的数据不得以零值替代。标准Retail源和Mainline开发别名均输出单目标默认玩家清单；当前代码、实机及包边界见[本阶段验收](R2-01-02-Retail目标与构建实施验收.md)。本页R1历史两端记录保留，业务最低能力要求不变。
## R3消费者支持索引（2026-10-27）

面向后续YBP离线兽栏的最小能力／方法、业务数据所有权、两组时间与未知状态投影、依赖停止、页面托管设置、会话幂等及清理回放已固定在[API13公共支持契约](API-v13-YBP离线兽栏公共支持契约.md)，[R3验收](R3-YBP离线兽栏公共契约实施验收.md)记录2463项三目标合成消费者验证及适用旧目标回归。R3未改变本页既有公开契约或生产运行字节，真实YBP业务接入、客户端与最终包恢复仍待。
