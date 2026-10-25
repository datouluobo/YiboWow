# Forever 当前角色银行最小适配

日期：2026-10-19。状态：**实现与双端模拟通过，银行实机采集／保存／展示待验收**。当前角色7级，尚未到达银行；无需为本轮验收改变正常升级路线。

后续状态：用户要求银行继续保持待实机验证。当前开发版本已随[邮件阶段](Forever-当前角色邮件附件最小适配.md)升至0.3.0-api1；下文保留0.2银行阶段的实现与验证证据。

## 版本与边界

- Forever：`YiboVault_Forever.toc`，Interface16001，版本 **0.2.0-api1**。继续使用 `YiboVaultForeverDB`、schema1，不复制或导入MoP存档。
- Mists：版本 **1.2.3-api1**、Interface50504、`YiboVaultDB`、原银行采集及仓储页保持。本次运行修改仅涉及Forever模块与共享语言／目录说明。
- 仅当前角色银行，来源名 `bank`。账号银行、公会银行、其它角色与银行操作不在范围；不存取物品、不购买银行格或页、不自动打开或切换原生银行界面。
- 用户已确认上一轮背包／装备／刷新标签及页签高亮正确。背包装备已有真实采集与展示截图；保存恢复与MoP仍须实机核对。本轮不将模拟数据或窗口能打开计作银行实测。

## 原生接口依据与准入

依据[暴雪Forever分支Camelot银行UI源码镜像](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/BankFrame.lua)及[同分支生成的Bank API文档](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/BankDocumentation.lua)。该分支展示角色与账号两类银行，并使用 `C_Bank.FetchPurchasedBankTabData(bankType)` 的容器ID读取内容；不套用MoP固定的 `-1`／银行袋编号。镜像当前分支不是本机build70374的实测证据，返回形状与完整性仍待首次到银行核对。

1. 只有角色在世界中，收到 `BANKFRAME_OPENED` 且 `C_Bank.CanViewBank(Enum.BankType.Character)==true` 时读取银行。
2. 使用 `FetchPurchasedBankTabData(Character)` 与 `FetchNumPurchasedBankTabs(Character)` 交叉校验已购买容器数量。每条必须声明相同角色银行类型；容器ID必须属于客户端原生 `Enum.BagIndex.CharacterBankTab_N`，不得重复。账号容器、缺字段、异常数量直接拒绝；不猜固定ID或退回旧银行算法。
3. 使用 `C_Container.GetContainerNumSlots/GetContainerItemInfo` 扫描每个容器；主容器容量为零视作未就绪。空格数接口存在时验证空格＋实见占用格数等于容量。链接、数量、ID须可读，受限／异常值导致本次来源读取失败。
4. 全部容器暂存完成后，再校验银行仍打开、可见及已购买容器集合未变，才逐位置提交。任一容器失败均不提交该批候选，不用部分成功覆盖旧快照。
5. 首次整体空响应需对应原生物品变化事件，或玩家在银行正常加载后手动刷新，才生成完整空快照。仅延时或打开银行事件不建立空库存；零个已购买容器视作未就绪。

## 保存、变化与失败

银行数据仍由Vault唯一拥有，使用现有记录结构、角色GUID、Store和Query。Core仅承担公开角色身份、物品名称解析、窗口、字段、预览、入口及清理生命周期。银行位置以实际容器ID和格位记录，UI使用中英文资源显示；不以物品名称作为库存关联键。

银行打开后延迟合并采样；`BAG_UPDATE_DELAYED`、`BAG_CONTAINER_UPDATE`、`PLAYERBANKSLOTS_CHANGED`、角色类型的 `BANK_TABS_CHANGED` 触发合并更新。银行事件逐项保护注册，客户端不支持的事件记录于业务私有 `_unsupportedEvents`，不中断已有背包／装备启动；通用背包变化事件与手动刷新继续适用。`BANK_TABS_CHANGED` 只证明目录变化，不单独赋予全空物品就绪状态。

关闭银行、离开世界与重载后，保留已有银行记录、原观察时间及覆盖信息，标记过期；关闭后不查询银行容器。打开后不可见／未就绪不清空；读取失败保留旧内容并标记错误。后续完整成功读取恢复正常；完整空读取清除已移走记录并保存 `known-empty`。本轮枚举中消失的旧容器保留为过期，不将未确认范围当作新鲜库存。

存档继续由WoW原生落盘，实际无限客户端路径为 `WTF/Account/<账号>/SavedVariables/YiboVault.lua`，其中表名为 `YiboVaultForeverDB`。不因新增银行来源升schema或迁移旧背包装备记录。页签选择保存在 `settings.foreverSource`；重载后银行页可直接查看旧快照。

## 契约与页面

- Core API最低13，原有 `account-surface-budget:2`、`account-character-admission:1` 等能力检查不变；没有新增Core公共能力或绕过Core访问其它插件。
- `vault.items` provider `YiboVault:inventory`、契约major1/minor1、Vault API1保持兼容；Forever新增可发现的 `source.bank:1`。范围仍仅当前GUID，账号／服务器／其它角色查询继续返回不支持。
- `Query({sources={"bank"}})` 返回既有records／coverage／revision值副本。未访问银行时没有完成覆盖，totals=0不能当作空银行；`includeStale=false` 排除旧／失败记录。`GetPersonalCounts` 仍不宣称支持。
- 复用Core的 `vault-items` 页面，增加“银行”页签。未采集显示“尚未采集：请先打开角色银行”，关闭银行时刷新不可用，已有旧记录显示过期状态。主表与悬停预览复用相同查询、角色准入、字段投影及状态；没有第二个银行窗口或设置壳。
- 角色准入仍仅当前GUID且至少有一个完整物品来源快照；银行页未采集不会生成空银行业务事实。角色隐藏、字段、排序和入口继续由Core管理。关于页当前目标描述同步包括角色银行。

## 验证证据

```powershell
lua _NonRelease/VaultForever/Smoke.lua
lua _NonRelease/CoreForever/Smoke.lua
.\Tools\Test-LuaSyntax.ps1 -Addon YiboCore,YiboVault
.\Tools\Build-ReleasePackages.ps1 -Addon YiboVault -Target Mists -ValidateOnly
python Tools/Check-Localization.py --output _NonRelease/Localization/Workspace-Report.md
```

双端真实清单模拟 **842项** 通过，包括原背包装备及MoP采集／窗口、未访问银行、动态角色容器、多容器数量、账号与重复容器拒绝、主表／悬停、事件合并、第二容器失败不部分提交、不完整空格数据、零容量／空目录、关闭前取消、关闭后保留、保存恢复及成功空快照。计数包含边界API断言，不代表842个独立用户场景。

Core回归69项、两插件73个TOC加载Lua源文件语法及Mists构建ValidateOnly通过。语言候选报告已查看：新增区域无中文硬编码；Core缺英文／格式不一致均0，工作区既有6个未知key仍位于AutoOpen。本轮不扩展无关旧独立夹具修复，已知旧测试基线见上一阶段记录。

## 分阶段实机验收

现在可做：`/reload` 后 `/yva open`，确认版本0.2.0-api1、三页签文字正常；银行页显示未采集提示且没有虚假的空快照。背包／装备页面正常。清单版本显示若未刷新，可完整重启客户端。不要为测试写入或复制模拟存档。

日后正常到达银行再做：

1. 打开原生角色银行，等待内容出现；打开Vault银行页核对所有已购买容器的物品／数量／格位。必要时在原生界面加载后手动刷新。
2. 正常存入／取出一组物品，核对自动刷新；关闭银行，确认旧记录保留并标为过期，刷新不可用。重新打开银行应恢复当前快照。
3. `/reload` 或退出重登后，在未开银行前核对旧快照与过期标识，再开银行重采；核对原生保存文件中的独立表名。
4. MoP沿用原启用集合复测银行、背包、装备与仓储页，并核对原存档。

验收状态：银行API形状、原生事件、全部容器覆盖、变化更新、保存落盘及中英文真实布局均 **待实机**。目前角色尚无银行环境，不需要现在补测。
