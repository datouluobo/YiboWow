# YiboMail Forever 最小适配与验收

日期：2026-10-19。状态：**代码与双端模拟通过；实机启动、空收件箱采集及中文主窗口已确认，其余待验证**。Vault 的银行、邮件附件、拍卖行、公会银行继续保持待实机验证；不将模拟或代码兼容声明记作客户端验收。

## 版本与范围

| 目标 | 清单 | 版本 | 存档表 |
| --- | --- | --- | --- |
| Mists | YiboMail.toc，Interface50504 | 1.2.17-api1 | YiboMailDB |
| Forever | YiboMail_Forever.toc，Interface16001 | 0.1.0-api1 | YiboMailForeverDB |

Forever清单复用Namespace、语言资源、Store与Items，单独加载目标配置、只读Scanner、Core账号页面及Bootstrap。仅当前角色收件箱：寄件人、主题、物品附件、金额／COD、原生读状态与观察时的到期估计；不读取正文。金额列明确使用铜币单位，到期估计不用于自动操作。

不加载Queue、Compose、Recipients、规则寄件、NativeUI、ActionTodo、GoalTargets等操作或其它业务模块，不安装原生邮箱增强、收取、发送、退信、删除、支付、自动拉取更多或登录提醒。原生邮箱仍由玩家正常操作；本轮只是观察。Mists原模块集合和行为保留。

`WOW_PROJECT_ID`必须匹配具名 `WOW_PROJECT_CAMELOT`；默认Mists清单在Forever强行加载时也会在写库前停止。独立存档不导入或复制YiboMailDB；schema超前、客户端范围不匹配或顶层／快照结构不兼容时保留数据并停止初始化。

## Core 能力与职责

最低API13，明确检查localization:1、business-services:1、character-name-format:1、item-resolver:1、character-identity:1、characters:1、character-cleanup:1、account-view:2、account-preview-characters:1、account-character-admission:1、account-surface-budget:2、account-entry:2及实际使用的方法。版本／能力不足时提示升级并在数据库初始化前停止。Core语言服务本身缺失时，启动诊断使用固定英文提示；业务页面没有并行语言回退实现。

本轮没有输入控件、物品选择器、发送或收件队列，故Forever不要求本轮未调用的basic-input／item-picker；Mists原最低能力要求不改。Core承担角色GUID／名称、物品解析、窗口／滚动、角色准入、字段／悬停、入口和清理生命周期；Mail负责邮件事实、身份匹配、存档及公开快照。无Core反向业务依赖或其它插件私有读取。

本次接入复用CAP-001／003／004／005／007／009／010。窗口／预览用同一行快照，通用字段与入口设置交给Core；默认独立入口三通道关闭，没有第二套设置窗口。当前没有额外业务设置分区。新增玩家文字使用Mail owner的Core.Locale中英文资源；动态寄件人、主题、物品名称保留原文。关于页已声明Mail的Forever目标及当前收件箱范围。

## 采集与保存

接口依据为[暴雪Forever原生邮件UI源码镜像](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MailFrame/MailFrame.lua)及[邮件事件文档](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MailInfoDocumentation.lua)。既有独立探针确认旧式收件箱接口存在，但没有本轮Mail真实收件箱样本；源码镜像不代替本机build70374实测。

- 仅进入世界、收到MAIL_SHOW后读取；MailFrame存在时还必须可见。MAIL_INBOX_UPDATE合并重采，关闭邮箱或离开世界使待执行任务失效。Slash仍为 `/yma`，`scan`手动读取、`status`显示状态，其余打开Core收件箱页；没有旧别名或额外操作命令。
- `GetInboxNumItems()`载入数必须等于总数。原生命令仍等待或邮箱未完整载入时保留旧快照并显示待采，不通过CheckInbox强制拉取，也不提交可见子集。
- 按原生ATTACHMENTS_MAX_RECEIVE逐封读取头信息和所有附件槽，验证金额／COD／天数、附件计数、物品ID／数量／可用链接及受限值。完整纯文字邮件允许nil附件计数；头信息未加载不算空信。货币附件本阶段不支持，遇到时整批失败并保留旧快照，不将货币ID当作物品ID。
- 提交前复核收件箱数量、每封关键头字段、Core当前GUID、原生可见性与命令状态；整批候选验证后调用共享CommitScan。读取失败不部分覆盖；初次整体零封需邮箱更新事件或玩家加载后手动确认，不能仅凭延时写空。
- 复用Mail原有签名／重复多重集／本地mailKey匹配与历史存档机制。mailKey是本地快照身份，不是服务器唯一邮件ID；该目标不以它发起操作。失去可见性的旧记录按原有未核实历史语义保留，不据缺失推断收取、退信或删除完成。
- 当前角色标识只用Core公开GUID，不创建名字回退键，不导入旧角色身份。其它GUID的历史数据可保留为存储，但本目标查询／窗口只准入当前角色；Core既有角色清理确认流程负责删除对应Mail缓存。
- 关闭／重载后，公开状态为stale，旧内容及采样时间保留；重新打开并成功采样后恢复。完整确认空邮箱写known-empty且当前visibleKeys为空，保留历史证据。原生文件仍为无限客户端 `WTF/Account/<账号>/SavedVariables/YiboMail.lua`，表名YiboMailForeverDB。

## mail.items 契约及 Vault 可选集成

提供方为YiboMail，服务名 `mail.items`，providerID `YiboMail:inbox`。沿用API1与原v1.0收件箱方法形状：**major1/minor0**，GetState({characterID})、GetByCharacter({characterID,options})、GetRevision。只声明mail-items.query:1／state:1／events:1；不声明transfers，不注册GetTransfers方法，直接调用也返回unsupported-capability。Mists继续提供原v1.1及在途能力，不降版。

GetState返回覆盖状态、计数、观察时间和revision；未采是not-yet-scanned，失败／关闭为error／stale。GetByCharacter返回records、quantity、coverage、revision值副本，附件记录保留source=mail／sourceClass=external、当前characterID、mailKey、邮件序号／附件槽、物品身份与数量。账号／服务器／其它GUID范围拒绝；includeStale=false排除旧数据。没有快照的零数量不能作为“没有附件”的依据。

通知继续由Core.Contracts.NotifyChanged发布，负载沿用characterID、changedMailKeys、changedItemIDs、revision、reason、observedAt；消费方订阅Core公开契约生命周期事件并按owner清理。服务及页面成功初始化可重复调用而不重注册；消费方不依赖加载顺序。

Vault Forever随本轮升至 **0.6.0-api1**，增加目标专用公开契约适配器，消费mail.items major1/minor0：

1. Mail单独启用时独立工作；Vault单独启用时保留原本地只读采集。
2. 发现兼容Mail契约后，Vault停止原生邮件读取，通过Core.Contracts读取状态与附件快照；不读取YiboMail全局实现或SavedVariables，也不将结果写成Vault第二份权威存档。
3. 提供方尚未采样时，Vault显示未知，不拿旧本地附件冒充新提供方快照。已有Vault本地缓存只作休眠的备用历史，不导入Mail。
4. 运行时值副本／派生缓存带契约registrationRef、revision、状态与观察时间。注册、变更、注销通知使Vault缓存失效；注销或方法不兼容时，Vault本地基础采集恢复。已知不完整状态不会显示为完整新鲜覆盖。
5. Mail负责邮件判断、采集与保存；Vault仅投影附件，仍按当前GUID过滤，原主表／悬停复用该公开快照。Mail清理会通知Vault，不能留下第二份活动附件状态。

这是真实集成所需的最小可选契约，没有新增业务RequiredDeps／OptionalDeps，也没有建立公共总线或服务目录。

## 验证证据

- 新Mail真实双端清单集成 **69项通过**：启动、错目标／默认清单保护、独立存档、未来schema／异范围拒绝、缺Core能力／GUID、完整／纯文字／空箱、附件末槽、数量与副本、错误／部分载入保留、保存恢复、Core主窗／预览、Mists原收件箱采集／账号查询／窗口，以及Vault先加载、Mail晚注册、仅一份原生采集、注销恢复、重注册、方法不兼容和清理通知。
- Core双端69项、Vault双端2874项保持通过；Core／Mail／Vault六份清单共107个Lua源文件语法通过。
- Mists构建ValidateOnly分别通过：Mail1.2.17-api1与Vault1.2.3-api1，均Interface50504；未生成或发布新包。
- Mail既有12个独立Spec中10通过、2失败：AttachmentReadinessSpec.lua:86、MailRuntimeSpec.lua:157。通过内存路由逆向剥离本轮四个共享文件改动的任务前态对照，两处失败相同；没有用HEAD覆盖混合工作区，也不将失败计为通过。明细见[对照JSON](../../_NonRelease/MailForever/LegacyTestComparison.json)。
- 本地化候选报告已生成并查看：新增区域无中文硬编码，Core542项资源缺英文／格式不一致均0；全工作区原有6个未知key仍属AutoOpen。模拟和词法检查不能代替中英文客户端验收。

```powershell
lua _NonRelease/MailForever/Smoke.lua
lua _NonRelease/CoreForever/Smoke.lua
lua _NonRelease/VaultForever/Smoke.lua
.\Tools\Test-LuaSyntax.ps1 -Addon YiboCore,YiboMail,YiboVault
.\Tools\Build-ReleasePackages.ps1 -Addon YiboMail -Target Mists -ValidateOnly
.\Tools\Build-ReleasePackages.ps1 -Addon YiboVault -Target Mists -ValidateOnly
python Tools/Check-Localization.py --output _NonRelease/Localization/Workspace-Report.md
```

## 待实机验收

2026-10-19用户截图 `codex-clipboard-47c161f5-73a8-4006-b7c7-a11099795914.png` 确认：原生邮箱已打开且为空；Core收件箱页显示 `YiboMail v0.1.0-api1`、当前角色及“已完整采集：收件箱无邮件。”。据此确认Forever启动、目标版本生效、空箱采集状态及本次中文主窗口展示。截图不能证明保存落盘或重载恢复，也不能证明有邮件时的字段与附件读取。

同次附带探针报告为0.1.1／session13，记录MAIL_SHOW事件注册及触发；GetInboxNumItems／GetInboxHeaderInfo／GetInboxItem存在，C_Mail.GetInboxNumItems不存在。报告声明仅采样背包与装备，没有收件箱返回值；不将接口存在当作邮件读取样本，也不据此扩展验收结论。

非空收件箱数据／金额／附件、变化刷新、保存落盘与恢复、完整中英文及手动语言模式布局、与Vault联动、MoP邮件实机回归仍**待实机验证**。Vault银行、邮件附件、拍卖行、公会银行继续待实机，不要求现在执行。

以后正常可测试时：完整退出重开客户端，启用Core＋Mail，可同时启用Vault。确认Mail0.1.0-api1／Vault0.6.0-api1；正常打开邮箱，待内容显示后用 `/yma scan`、`/yma` 核对当前收件箱。比较Vault“邮件附件”数量和Mail一致，正常原生取件后复核变化；关闭／重载后核对过期快照和保存，再开箱重采。用户主动通过原生界面操作，插件本阶段不执行取件或发信。

## 2026-10-24集中实机历史快照

2026-10-24 B01/Mail页面反馈：用户按先不打开原生邮箱步骤提供截图，显示YiboMail v0.1.0-api1、当前角色天堂-CAMWOW CN1 Realm 2 PvE；状态“历史收件箱快照，请重新打开邮箱刷新。”，一条邮件行可见，寄件人有文本、主题区域未见文本、物品附件列“无物品附件”、金额（铜）0、到付（铜）0。登记已有历史快照及旧数据状态提示可见，不将该行判为当前邮箱真实状态，不将无物品附件等同空邮箱或附件采集通过，也不据此判重载／退出恢复全流程通过。非空附件、金额／COD、原生取件变化及Vault联动并入B08同次邮箱访问。截图聊天区出现任务奖励声望增长，下一步声望页只作初始快照观察，不据事后页面推定自动刷新已通过。证据：`F:/Temp/User/codex-clipboard-891d4872-b624-4d3b-9700-1159d8a8af35.png`。下一步B01声望之路页面。


2026-10-26 B08/B非空邮箱初始对照：F:/Temp/User/codex-clipboard-3acd3a34-7913-4cb1-9314-d71d31e01e99.png，Mail0.1.0-api1显示4行，与原生4封可见邮件对应：联盟拍卖行银叶草(3)成功、多汁狼肉(9)成功、蟹爪(4)到期，以及洛瑟鲁姆·星风来信（具体字符以原生为准）。蟹爪x4与原生附件图标4一致，前三封寄件人／主题及四行展示有同屏证据。Mail金额字段143、1383铜、COD均0仅为插件显示；原生未打开邮件详情，不能判金额与COD已原生逐项核对。尚未显示Vault邮件附件页，取件前后变化、最后附件槽、关闭历史及恢复均待；不把4行快照扩大为完整邮件全流程通过。
