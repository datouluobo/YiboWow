# Forever 当前角色邮件附件最小适配

日期：2026-10-19。状态：**实现与双端模拟通过，邮件实机采集／保存／展示待验收**。角色银行继续标记为**待实机验证**；本轮不将银行或邮件模拟结果外推为原生验收完成。

后续阶段：当前开发清单随[拍卖行最小适配](Forever-当前角色拍卖行最小适配.md)升至0.4.0-api1；银行、邮件附件与拍卖行均保持待实机验证。下文保留0.3邮件阶段实施证据。

## 范围与版本

- Forever：`YiboVault_Forever.toc`，Interface16001，**0.3.0-api1**。新增 `Forever/Mail.lua`，复用共享Store／Items、物品记录构造与Core托管页面。存档继续为 `YiboVaultForeverDB`、schema1，不迁移或复制MoP数据。
- Mists：**1.2.3-api1**、Interface50504、`YiboVaultDB`、原MailItems／MailProvider及完整来源、账号查询与仓储页保持；本轮不改MoP采集实现。
- 仅当前角色完整载入的收件箱中的物品附件。金额、邮件正文、寄件操作、在途、其它角色、账号汇总不在本阶段范围。寄件人和主题仅在采样期间用于一致性校验，不保存到本轮物品记录。
- 不自动打开邮箱、不取件／收钱／删除／退信／发送、不调用CheckInbox。附件位置只表示该快照内的邮件序号与附件槽，不是跨会话邮件唯一ID，不作为操作地址。

## 接口依据与采集

既有探针确认 `GetInboxNumItems/GetInboxHeaderInfo/GetInboxItem` 存在；接口形状参考[暴雪Forever邮件UI源码镜像](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MailFrame/MailFrame.lua)和[同分支邮件事件文档](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MailInfoDocumentation.lua)。源码镜像当前分支不等于本机build70374的实测证据，首封有物品附件的原生邮件仍待核对。

1. 仅在世界内、收到 `MAIL_SHOW` 后读取；原生MailFrame存在时还须可见。关闭邮箱、离开世界与重载后不查询收件箱。
2. `MAIL_SHOW` 延迟采样，`MAIL_INBOX_UPDATE` 合并重采；手动刷新沿用 `/yva scan` 或页面刷新。共享队列取消离开世界的定时任务；关闭邮箱后队列不再读取邮件。已有背包事件不赋予空邮箱就绪状态。
3. `GetInboxNumItems()` 的载入数必须等于总数。载入数小于总数或原生命令仍等待时，本阶段不提交可见子集，显示“收件箱尚未就绪或未完整载入”，保留旧快照并标记过期。玩家可正常等待原生邮箱加载，不由插件强制拉取更多。
4. 使用原生 `ATTACHMENTS_MAX_RECEIVE`，逐封读取头信息与全部附件槽。已加载的纯文字信允许附件计数为nil并视作0；缺少主题的头信息视作未加载，不能据此写空快照。
5. 校验附件数量与头信息一致，每条物品ID、数量、链接可读且一致，拒绝受限值、异常数量、不完整附件与链接ID错配。缺链接时可用有效ID／数量建立item-id-only记录；货币附件在最小阶段不支持，遇到时保留旧快照并显示读取失败，不将货币ID当物品ID。
6. 提交前重新核对收件箱数量、各封邮件的寄件人／主题／金额／COD／附件计数、当前角色GUID、邮箱可见性及原生命令状态。候选在内存中构建，整批验证成功后一次替换mail/inbox；失败不部分覆盖。
7. 首次整体零封邮件需收到邮箱更新事件或玩家加载后手动确认才写入空快照。仅打开事件或延时不能把登录初期零值解释为“没有附件”。完整载入的纯文字邮件经完整附件校验后，可以生成确实无物品附件的快照。

## 保存与契约

Vault是该目标邮件附件快照的唯一所有者，角色关联使用Core当前GUID。继续使用既有 `mail` 外部来源、`inbox`位置和记录结构，sourceClass为external；邮件附件数量计入externalQuantity，不计入physicalQuantity。每附件sourceID包括角色GUID、邮件序号及附件槽，记录 `location.container=inbox, slot=邮件序号, attachmentIndex=附件槽`。

沿用API1、服务 `vault.items`、provider `YiboVault:inventory`、major1/minor1，通过Core.Contracts发现；Forever增加 `source.mail:1`。查询仍仅当前GUID；返回值为副本，保留records／coverage／revision与现有变更通知。无快照时totals=0不等于确认空，须查看完成覆盖。未完整载入保留旧快照，`includeStale=false` 排除；失败标记error，后续完整采样恢复。没有在途记录或个人库存合计能力，不宣称支持GetPersonalCounts。

关闭邮箱后保存已有内容、原观察时间及覆盖并标记过期；下一会话恢复过期快照，重新打开且成功采样后恢复正常。已确认完整空收件箱／无物品附件写入known-empty并清除已移走附件。WoW原生保存文件仍为无限客户端 `WTF/Account/<账号>/SavedVariables/YiboVault.lua`，表名 `YiboVaultForeverDB`。

本阶段不依赖未适配的YiboMail，不加载MoP邮件Provider或读取其它业务插件对象／存档。未来若无限YiboMail提供公开邮件快照，应先按既有Core契约发现与数据所有权要求设计接入，不能同时维护两份权威附件状态。

## 页面与公共能力复核

沿用Core API最低13及现有显式能力检查。复用公开角色身份／名称、物品解析、账号页、统一窗口／滚动、主表／预览字段、入口和清理所有者，不新增Core公共机制或接口版本。无新增输入控件或独立设置壳；本次涉及的公共能力调用继续接入CAP-001／003／004／005／007／009／010。

同一 `vault-items` 页新增“邮件附件”页签，显示物品、邮件序号／附件槽、数量。未访问提示“尚未采集：请先打开邮箱”；关闭后禁用刷新且显示过期快照。主窗口与Core悬停复用同一查询、准入和状态；页签选择保存在Vault设置。四页签最小内容宽度相应调整，原生布局仍待实测。通用设置仍位于Core工作台，新增文本使用ASCII key中英文资源。关于页描述同步包含邮件附件。

## 验证与实机步骤

双端实际清单模拟 **1925项检查通过**，含边界API断言，不代表1925个独立用户场景。覆盖未访问邮箱、两附件含第16槽、纯文字信、事件合并、完整数量、部分载入、头信息变化、链接失败／错配、数量缺失、货币附件拒绝、原生命令等待、关闭取消、保存恢复、空收件箱就绪及同快照主表／悬停。真实MoP清单的原邮件采集器与账号邮件查询也通过，另有原背包／装备／银行测试保留。

Core回归69项、两插件74个TOC加载Lua源文件语法及Mists构建ValidateOnly通过。语言候选报告已生成并查看：新增区域无中文硬编码，Core缺英文／格式不一致均0；工作区已有6个未知key均属AutoOpen。本轮不改无关旧独立测试夹具。

```powershell
lua _NonRelease/VaultForever/Smoke.lua
lua _NonRelease/CoreForever/Smoke.lua
.\Tools\Test-LuaSyntax.ps1 -Addon YiboCore,YiboVault
.\Tools\Build-ReleasePackages.ps1 -Addon YiboVault -Target Mists -ValidateOnly
python Tools/Check-Localization.py --output _NonRelease/Localization/Workspace-Report.md
```

现在可 `/reload` 后 `/yva open`，确认0.3.0-api1和邮件页的未采集提示；如清单版本仍旧可完整重启。遇到正常邮箱后：打开原生收件箱，等实际邮件显示，再运行 `/yva scan` 并切“邮件附件”，对照物品、数量和附件位置。玩家正常取走附件后核对自动更新；关闭邮箱核对旧快照与过期状态；`/reload` 或退出重登核对保存恢复，随后重新开箱重采。原生邮箱有溢出未完整载入时，本轮允许保持待采而不覆盖旧内容。

有附件、纯文字／空邮箱、变化刷新、真实保存落盘、中英文布局及MoP客户端邮件回归均 **待实机验证**。银行继续 **待实机验证**，不要求当前7级角色提前到银行，也不生成模拟游戏存档代替验收。

### 实机反馈：版本与入口已确认

用户截图确认Vault **0.3.0-api1**已加载，背包、装备、银行、邮件附件四页签可见，当前背包页面仍正常显示物品。用户说明当前邮箱为空，待以后有附件再测试。截图停留在背包页，本次仅确认版本与邮件附件入口，不将空收件箱采集状态或邮件页内容计为已验收。有附件采集、数量／位置、变化刷新和保存恢复继续待实机；银行保持待实机验证。

## 后续公开提供方接入

YiboMail本体Forever0.1.0-api1现已实现只读收件箱和mail.items v1.0契约；Vault0.6.0-api1增加可选Core契约消费及生命周期切换，兼容提供方存在时停止本地原生采集，不复制权威存档。实现及69项双端／联动证据见[Mail目标记录](../../YiboMail/Docs/Forever-最小适配与验收.md)。两插件联动与本节邮件附件仍待实机验证。
