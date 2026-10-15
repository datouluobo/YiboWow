# API13：滚动表面的统一宽度预算

2026-10-16，Core1.12.6工作树提供 `account-surface-budget:2`，尚未打包发布。沿用API13。v1消费者继续兼容；新接入必须检查能力2及实际方法。Core负责屏幕安全区、窗口保存尺寸、滚动槽、宽度精度与分页基础设施，业务只提供内容尺寸与数据布局。

## 测量契约

`GetSurfaceMetrics(context)` 可提供下面两个成对的可选字段；`GetHoverMetrics(context)` 同样支持。既有宽高字段语义保持：naturalContentWidth／preferredWidth只报告完整内容及业务内边距，不自行加滚动条槽，不按当前分页角色切片测量自然宽度。

| 字段 | 含义 |
| --- | --- |
| scrollContentHeight | 全部可见业务行的滚动内容高度，有限非负数；按完整角色范围筛选行后测量 |
| scrollFixedHeight | 业务内容表面内不能随列表滚动的区域高度，包括表头、业务工具栏、间隔及上下内边距；不含Core窗口壳 |

Core在主窗口最终高度（含保存高度、最小高度及屏幕夹取）确定后，判断实际滚动区是否溢出；有溢出才增加统一滚动槽。声明这对字段的页面，保存的窄宽度不能提前截断自然矩阵，Core先扩展到完整自然宽度及必要滚动槽，最大仍为屏幕安全宽度。保存的更大宽度保留，不强制压缩。

悬停使用最终入口方向可用高度／原位重建高度，在定位前预算槽宽，不以全屏高度冒充入口上方或下方空间。短列表不预留空槽。宽度向上取整，避免最后一列因小数精度丢失。

只有同时提供有效的两字段才启用新预算；缺失／无效时沿用既有测量行为。Core不读取业务数据库，不推断业务行数，不固定20行，不按业务插件名分支。

## 渲染契约

`AccountView:GetScrollSurfaceWidth(context, parent, bodyHeight, fixedHeight)` 返回最终业务表面的可用横向宽度，按parent实际高度扣除必要滚动槽；原始宽度取context.surfaceAvailableWidth，缺失时取parent实际宽度。bodyHeight和fixedHeight与测量时的定义相同，但须使用本次实际显示内容。

业务随后扣除自身左右内边距，交给既有FitRepeatedColumnWidth／GetColumnPage／GetColumnPageByWidth。不得再手工扣Geometry.scrollbarGutter，避免重复占位。返回值最小为1；读宽度不修改存档、不触发扫描或刷新。

新代码检查API13、account-surface-budget:2与GetScrollSurfaceWidth，缺失则提示升级并停止相关初始化，不并行保留本地几何回退。已有v1页面没有新字段时保持兼容；后续触及账号矩阵的尺寸／滚动／分页代码时接入。

## 当前接入与证据

- Currency：主矩阵、普通悬停、转置悬停报告滚动内容及固定高度；自然尺寸和渲染的本地滚动槽判断已撤下。四种语言组合API13Spec各52项，包含真实Core ApplyPageSize到渲染的54货币／13角色回放及能力不足停止。
- Reputation：主矩阵撤下rows>20滚动槽补偿；按完整角色范围生成显示行后交由Core预算，再分页角色，表头、数据行和分页使用同一角色切片。单独监控预览为无纵向滚动布局，本次不添加假滚动槽。迁移／清理88+39项及HoverSpec通过；主矩阵游戏视觉待复测。
- ScrollBudgetSpec10项直接覆盖真实Core主窗口／悬停、保存的窄宽度和高窗口、精确高度匹配、无空槽、显式HoverMetrics、锚点受限空间及安全边界。EntryBar1133项、Core Contracts90项、CharacterNames77项、84文件语法与三个owner本地化检查通过。
- TaskHub旧SurfacesSpec在其前置ActionIntegrationSpec的Todo语言夹具处失败（ACTION.RECIPE_UNLEARNED未加载），未据此宣称该套回归通过。本次未改其运行代码或扩大修复范围。

以上为离线验证，真实客户端仍需核对两插件在相同角色与窗口高度下的分页、滚动条显隐、入口悬停位置和短列表。其余账号矩阵的接入范围见CAP-004台账，不由Core提供能力推定全部业务已接入。

2026-10-16 后续统一接入：CAP-004列出的AltoBoss、Crafting、Legendary、QuestBlocker剩余矩阵均已接入声明和渲染预算，四组MatrixBudget各100项及相关回归通过，用户已确认本轮实机检查无问题。具体多面板／无纵向滚动边界和实机步骤见[实施记录](矩阵预算统一接入-实施与验收.md)。原先的“待迁移”审查结论已由台账当前状态替代，v2契约保持不变，工作树版本更新至Core1.12.6。
