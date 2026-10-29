# AltoBoss Core API13 接入与清理记录

2026-10-29矩阵分配修复：本次SetStatus目标绑定改用所有者TargetCatalog的bossKey索引，避免逐单元格通过Core.Defaults:Copy复制全部副本／难度目录；对外Query副本、Core服务隔离和BusinessItemActions绑定保持。CAP-004／007／008／009接入边界、API13与能力最低要求不变，无并行本地回退。72项适用回归及统一构建校验通过，用户192.7 MB截图回收后Core12.4 MB／关窗12.2 MB属于修复前实机基线；新字节峰值和交互待验。详见[截图与分配记录](../../Docs/Core-高占用截图与Boss矩阵临时分配-2026-10-29.md)。

日期：2026-10-14。实施分支：main。基线：Core1.12.2 / API13。状态：适用运行代码已迁入，已有回归与初始化检查通过；实际中英文客户端验收待完成，台账按部分接入记录。发布版本：AltoBoss2.7.0 / Core1.12.3（2026-10-15）；真实客户端验收状态按下文保留。

## 职责与初始化

YiboCore 为 RequiredDeps；设置壳、账号窗口、角色目录／排序、入口及小地图、输入与公共确认由 Core 提供。AltoBoss 负责 Boss／副本业务采集、规则、保存和失效。CoreRequirements.lua 是 TOC 第一文件，检查 API13、已初始化及实际公共能力／方法；失败仅输出明确双语升级提示，CoreReady=false 让其余模块在读取 Core 对象前停止。没有独立窗口或本地功能回退。

基础要求 localization:1、characters:1、character-identity:1、character-name-format:1、basic-input:1、account-view:2、account-preview-field-groups:1、account-entry:2、character-cleanup:1、level-filter:1；操作确认使用 API13 已有 Core.ItemConfirmation:Show 并检查方法。目标增强另检查 business-services:1／business-providers:1、business-item-actions:3；DBM 补充检查 events:1 与所需身份方法，缺少补充只影响补充路径。

## CAP 逐项核对

| 台账 | 本次覆盖与结果 | 剩余范围 |
|---|---|---|
| CAP-001 | 主矩阵／转置表头及行、宽度测量、副本角色行、行动名称统一走 Core.Characters:FormatName；身份读取经 ResolveLegacyKey → Get(identityOnly) | 短名／跨服与缺失身份实机核对 |
| CAP-002 | NPC 与小时上限使用 UITheme:CreateInput；提交复用 OnSubmit／SetValue，保留 Core 输入法与失焦行为；等级表达式委托 Core.LevelFilter，删除本地解析／匹配实现 | 中文输入法、英文布局与提交实机核对 |
| CAP-003 | 自定义目标移除复用 Core.ItemConfirmation；绑定目标ID／当前记录复核，页面隐藏取消请求；移除位于“数据与缓存”末尾并明示清除范围 | 确认、取消和页面切换实机核对；NPC不是物品，物品解析／选择不适用 |
| CAP-004 | 仅 Core 工作台业务面板、账号页和 Core.Entry；删除独立设置壳、回退分支、隐藏的重复角色过滤面板、旧窗口尺寸／位置／缩放接口、旧缓存编辑器、旧小地图／文本悬停接口及旧角色排序摘要 | 中文／英文设置布局、主表／入口预览及八种入口组合实机核对 |
| CAP-005 | 保持 Core.Contracts 的目标契约与公开 Events 桥接；业务状态所有者不变；预览设置 getter 返回复制，避免暴露数据库表引用 | 真实TaskHub／DBM组合实机；两组前置回归错误仍需独立处理 |
| CAP-006 | 当前没有需新增的首次提示，沿用不适用 | 新增实际首次引导时重审 |
| CAP-007 | 本次所有角色身份读取均使用 identityOnly，不复制领域数据；显示不再解析短名／服务器自行拼接 | 多角色与改名实机核对；内部历史存储键保留，公开角色关联经 Core 唯一ID |
| CAP-008 | API13／business-item-actions:3 已检查，副本 compactTooltip 仍由 Core 提供 | 真实手势／菜单及缺参数补充验收 |
| CAP-009 | 311 对 owner 资源覆盖正式 UI、设置、状态／错误、目录回退、目标投影与命令反馈；会话语言统一取 Core，无 GetLocale 界面语言分支 | 中文／enUS与手动语言模式实机验收 |

## 清理与数据边界

Settings.lua 只保留统一工作台业务面板与刷新适配器，未创建 UIParent 独立壳或自己的滚动窗口。旧 minimap／window／cache-editor 接口、默认窗口配置和局部角色排序已清理；已有 SavedVariables 中的历史 UI 字段原样保留但不再作为独立窗口配置读取。业务击杀、轮次、刷新样本及玩家自定义名称不删除、不改写。

合法的自定义目标删除行为保留：玩家确认后清理指定目标在所有角色上的击杀／位面记录及刷新样本；这与源代码清理不同。提示明确风险，接受时复核目标仍存在且为同一记录。

Core 的 Bootstrap.VERSION 已从1.12.1对齐TOC1.12.2；API号仍为13。工作台补齐既有预览字段group元数据传递，声明 account-preview-field-groups:1，契约见 Core 的 API-v13-预览字段分组.md。需要同步使用 Core1.12.3，旧包缺此能力会明确要求升级。

固定副本预览列从业务设置移到 Core「显示与入口」的预览字段菜单，按资料片每12项分组。选择统一保存 settings.previewColumns；旧 lockoutColumns 标记仅在对应新字段缺失时导入，不覆盖新选择。历史元数据保留，主表完整副本列和有效锁定补充规则保持。

## 语言资源与剩余候选

新 Locale.lua 使用稳定 ASCII 语义 key；旧 LockoutLocale.lua 的35对资源保留。静态 Boss／旧副本回退目录使用稳定 Boss key／地图ID，输入识别别名不作为持久化身份；战争使者位置规则增加稳定 zoneKey 与双语原生名称输入别名，防止界面语言影响匹配。

旧刷新置信度标签仅在显示时兼容识别，新的计算结果用 preliminary/high/medium/reference 稳定码，避免将会话语言写入语义状态。实际 WoW API 的副本／NPC／难度／区域名称、历史快照与玩家文本继续使用原文。

工作区报告仍会标出数百条候选：主要位于 InstanceLockouts 的中英文副本缩写／资料片输入映射、TargetCatalog 的原生名称与搜索别名、Core 的区域输入与历史置信度识别，以及 HolidayBoss 的日历／地下城输入别名。这些为识别数据，未作为新的硬编码界面文本。CoreRequirements 的双语启动错误是语言服务不可用时的明确例外。数字候选不是界面覆盖百分比，逐区域覆盖以上表为准。

## 验证与限制

- 全部 TOC 运行 Lua 语法通过。
- 语言报告缺英文、未知 key、格式参数差异为0；中英文资源保持同一参数契约。
- InstanceKillsSpec 带真实探针样本58项通过；BossGoalsSpec19项、CustomBossGoalsSpec25项通过（后者包含前置运行，不简单相加为独立覆盖）。
- 固定副本预览迁移4项检查通过：旧选择导入、新选择不被旧标记覆盖、旧元数据保留、每组不超过12项。
- 初始化入口4项检查：API12拒绝、缺basic-input拒绝、缺character-name-format拒绝、API13与所需公共接口齐备通过；拒绝路径不初始化设置／账号页／采集模块。
- 两组此前完整回归分别被 Todo 语言前置错误与 GoalSources provider-error 阻断，本次未扩大修改它们，不能记为通过。
- 静态／模拟检查不替代真实客户端。待用户重载后核对统一设置、短名、语言模式、目标删除确认、输入法及现有进度／TP行为。

## 2026-10-15 设置页布局续改

业务规则与TP选项前置，增长列表独立分页（监控每页10行含组标题，自定义每页8项），宽内容区双列、低于760单列；翻页不改变选择，收起或删除后页码钳制在有效范围，跨页重复组标题。共享Core工作台滚动，不新增列表滚动壳；Core现有按钮／输入／名称悬停和owner语言资源继续复用。风险说明按实际文本高度排列，确认语义不变。新增5对资源，目前316对。语法及语言静态检查通过，本轮未运行测试，游戏客户端布局待验。
