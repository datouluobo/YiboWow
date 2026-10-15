# YiboBuilds

YiboBuilds is a character-build viewer for MoP Classic. It stores and shows talents, glyphs, equipment, gems, and enchants for every character on the account.

## Features

- Current / backup specialization overview for account characters
- Hover preview with up to 20 eligible characters
- Character workbench with equipment model, talents, and glyphs
- Equipment upgrade panel with live gem, enchant, engineering, and profession candidates
- Direct gem socketing and equipment-targeted enhancement actions
- Separate equipment snapshots for each talent slot
- Automatically save active equipment on logout, reload, or exit; preserve the outgoing specialization's last observation when switching
- Click equipment to open its upgrade panel; click the same item again to close it
- Equipment icons show item levels, excluding shirts and tabards

## Requirements

- MoP Classic
- YiboCore 1.12.5 or later (API v13; required capabilities checked at startup)

## Chinese

YiboBuilds 是用于 MoP Classic 的账号角色构筑查看器，记录并展示账号角色的天赋、雕文、装备、宝石和附魔。

### 功能

- 按角色显示当前或备用专精构筑
- 悬停预览最多显示 20 名符合条件的角色
- 单角色工作台展示装备人偶、天赋和雕文
- 装备提升面板显示实时宝石、附魔、工程及专业候选
- 在面板内镶嵌宝石，并直接对当前装备施加增强
- 每个天赋槽位独立保存装备快照
- 小退、重载或退出时自动保存当前专精装备；切换专精时保存上一专精最近一次观测的装备
- 点击装备打开提升面板，再次点击同一装备关闭；点击其它装备切换提升目标
- 装备图标按物品仓库样式在右下角显示淡紫色描边装等，衬衣和战袍除外；空栏位或装等未知时不显示数值

### 依赖

- MoP Classic
- YiboCore 1.12.5 或更新版本（API v13；启动时检查所需能力）


## 行动中心主动添加（2026-10-10 工作树）

支持实际宝石／附魔候选；目标绑定具体装备实例，实际应用才完成，换装暂停；无GUID保持待核实。

构筑与目标增强统一要求 Core API13 / business-item-actions:1，全部能力检查通过后才注册页面与采集；不足时明确提示升级并停止初始化。

实际契约、自动化与客户端待验收范围见 [实施与验证](../Docs/行动中心-主动添加实施与验证.md)。

## Core API13 适配（2026-10-15 工作树）

页面、字段、悬停、装备操作、目标提示及 Slash 输出接入 Core 账号语言；公共角色名使用 FormatName。缓存所有者接入 character-cleanup:2。Builds 1.5.0：Core适配与附魔候选修复均已获得用户实测确认。离线验证与真实客户端待验范围见[接入记录](Docs/Core-API13-接入说明.md)。
