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
- YiboCore 1.9.0 or later (API v10, account-view v2)

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
- YiboCore 1.9.0 或更新版本（API v10、account-view v2）


## 行动中心主动添加（2026-10-10 工作树）

支持实际宝石／附魔候选；目标绑定具体装备实例，实际应用才完成，换装暂停；无GUID保持待核实。

新增强最低 Core API v12 / business-item-actions:1，不足提示升级并停止增强；原基础业务保留既有最低版本，作为旧 Core 兼容例外，无新交互本地回退。整体提高最低版本时收拢此例外。

实际契约、自动化与客户端待验收范围见 [实施与验证](../Docs/行动中心-主动添加实施与验证.md)。
