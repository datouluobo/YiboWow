# Forever 专业档案契约

日期：2026-10-20。实现：Core Forever0.2.0／API13；实机待验证。能力名 `profession-profile:1`，复用 `data-domains:1` 及 `professions` v1，不增加业务配方存储或跨业务服务。

## 职责与调用

Core拥有当前角色的通用专业身份及技能档案，Crafting拥有配方观察与学习事实。消费方通过 `Core:HasCapability("profession-profile",1)` 检查，再调用 `Core.DataDomains:Get(characterID,"professions")` 获取副本；通过Core.Events订阅DATA_DOMAIN_UPDATED，筛选domainID及当前characterID。监听按owner清理；不得读取Core内部数据库。

档案形状：`{schemaVersion=1,state,updatedAt,revision,data={professions={...},primaryProfessions={...},skillLineIDsAuthoritative=true,observedAt}}`。每项为 `{id,slot,name,icon,skillLevel,maxSkillLevel}`。id来自GetProfessionInfo的skillLineID；slot仅为来源位置，不能代替专业身份。名称为API原文。primaryProfessions只保留来源前两个主专业位；副专业及新增专业按真实ID识别，不能套用MoP副专业槽位。

仅在Forever清单加载目标采集器，MoP仍用原采集器与原最低能力。新数据的skillLineIDsAuthoritative要求角色档案字段按精确ID查询，原MoP旧档案缺少该标记时保留原槽位兼容。Core保存于YiboCoreForeverDB，不复制到Crafting作为第二权威。

## 来源与就绪

依据[Forever原生Camelot专业页](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua)的七个返回位及GetProfessionInfo字段，采集两次并比较稳定ID、等级、名称和图标；缺接口、非法值、重复ID、受限值、读取变化时保留旧data并设置非known状态。接口存在不代替本机70374实测。

PLAYER_ENTERING_WORLD／SKILL_LINES_CHANGED／BAG_UPDATE_DELAYED驱动；最后一项用于迟到GUID及数据恢复。全空结果只有明确SKILL_LINES_CHANGED才记为已知空；登录初期空保持not-yet-scanned。失败的updatedAt表示本次状态变化，事实采样时间以data.observedAt为准，不把失败时间当新事实。

档案仅为当前角色观察，未证明跨角色共享或特殊规则集。配方消费者要求state==known及精确专业ID匹配；旧／失败状态不得授权读取另一个人的专业。就绪通知不依赖插件先后顺序；档案变更只说明数据已更新，不指令业务调用私有函数。

## 验证与后续触发

`_NonRelease/CraftingForever/Smoke.lua` 当前69项覆盖Core七位、精确副专业身份、错误保留、保存恢复、缺API、旧MoP槽位兼容及Crafting消费；Core双端69项及现有业务目标回归通过。真实专业名称／等级、学习与放弃专业、重载／重登及语言模式仍待实机。

本次仅Crafting Forever接入；其它插件未审查，不推定已接入。以后涉及专业展示或资格查询时，复用该公开档案并检查能力；配方、材料、冷却、可制造及场所限制继续由业务插件解释。进度见CAP-011。
