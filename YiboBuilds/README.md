# YiboBuilds

## Mists 1.5.3 — 2026-10-31

装备悬停边框会在客户端品质信息就绪后自动刷新。此前宝石候选和多孔装备孔序调整见 [1.5.1 更新说明](RELEASE_NOTES.md)。需要 YiboCore 1.12.5 / API13。

> 文档状态更新（2026-10-16）：现有功能已由用户确认实机验收收口。当前源码版本与发行证据见[状态总览](../Docs/仓库当前状态总览.md)，后续任务见[延期清单](../Docs/后续开发任务清单.md)。下文旧版本的开发／待验收描述按其原日期理解；当前版本渠道状态没有明确证据时保留待核对。

YiboBuilds is a character-build viewer for MoP Classic. It stores and shows talents, glyphs, equipment, gems, and enchants for every character on the account.

## Features

- Current / backup specialization overview for account characters
- Hover preview with up to 20 eligible characters
- Character workbench with equipment model, talents, and glyphs
- Equipment upgrade panel with live gem, enchant, engineering, and profession candidates
- Direct gem socketing and equipment-targeted enhancement actions
- Separate equipment snapshots for each talent slot
- Automatically save active equipment on logout, reload, or exit; preserve the outgoing specialization's last observation when switching
- Equipment hover borders refresh when the client finishes loading cached item quality
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
- 装备品质信息到达后自动刷新悬停边框，避免首次预览保留灰色边框
- 点击装备打开提升面板，再次点击同一装备关闭；点击其它装备切换提升目标
- 装备图标按物品仓库样式在右下角显示淡紫色描边装等，衬衣和战袍除外；空栏位或装等未知时不显示数值

### 依赖

- MoP Classic
- YiboCore 1.12.5 或更新版本（API v13；启动时检查所需能力）


## 行动中心主动添加（2026-10-10 工作树）

支持实际宝石／附魔候选；目标绑定具体装备实例，实际应用才完成，换装暂停；无GUID保持待核实。

构筑与目标增强统一要求 Core API13 / business-item-actions:1，全部能力检查通过后才注册页面与采集；不足时明确提示升级并停止初始化。

实际契约、自动化与客户端待验收范围见 [实施与验证](../Docs/行动中心-主动添加实施与验证.md)。

## 图标资源（2026-10-14）

当前图标为 `Media/YiboBuildsIcon`：默认TGA为64px，插件列表使用128px TGA；PNG提供16/24/32/64/128/512/1024px，母版为312px透明位图。版本、统一缩放和验证范围见[系列资源记录](../Docs/Design/Yibo系列Logo-20261014/README.md)。

![YiboBuilds 图标](Media/YiboBuildsIcon-128.png)

## Core API13 适配（2026-10-15 工作树）

页面、字段、悬停、装备操作、目标提示及 Slash 输出接入 Core 账号语言；公共角色名使用 FormatName。缓存所有者接入 character-cleanup:2。Builds 1.5.0：Core适配与附魔候选修复均已获得用户实测确认。离线验证与真实客户端待验范围见[接入记录](Docs/Core-API13-接入说明.md)。

## Forever 装备最小版 0.1.0

当前角色已穿戴装备只读采集、独立YiboBuildsForeverDB、Core主窗口与同源预览已实现，全部待实机验证，尚不可发布。完整重启客户端后 `/ybb` 打开，`/ybb scan` 刷新。天赋、增强、宝石与传承后续单独取证；MoP为1.5.1。详见[无限服实施与验收](Docs/Forever-当前角色装备最小适配与验收.md)。
