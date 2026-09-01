---
target: YiboCore UI suite
total_score: 28
p0_count: 0
p1_count: 3
timestamp: 2026-08-31T16-03-18Z
slug: yibocore-ui-accountview-lua
---
# Yibo 账号界面族设计审查

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 3/4 | 当前页、服务器范围和多数业务状态清楚；快照新鲜度及未同步原因尚未统一。 |
| 2 | Match System / Real World | 4/4 | 业务术语符合 WoW 多角色玩家习惯。 |
| 3 | User Control and Freedom | 3/4 | 范围、排序、字段、关闭均可控；高密度矩阵缺少一致的快捷路径。 |
| 4 | Consistency and Standards | 2/4 | 共享壳已统一，标题身份、角色表头、网格、行高和外框仍漂移。 |
| 5 | Error Prevention | 3/4 | 删除等危险动作已有防护；部分未知/不可用状态仍易被误读。 |
| 6 | Recognition Rather Than Recall | 3/4 | 多数状态有文字或图形；`—/不可用/未同步/未知` 的区别仍依赖记忆。 |
| 7 | Flexibility and Efficiency | 3/4 | 支持范围、排序、字段和快速预览；键盘与批量加速有限。 |
| 8 | Aesthetic and Minimalist Design | 3/4 | 密度合理；绿色同时表示选中、当前角色、成功等多种语义。 |
| 9 | Error Recovery | 2/4 | 部分页面给出恢复提示，但未形成统一恢复文案。 |
| 10 | Help and Documentation | 2/4 | 有 tooltip 和关于页；缺统一状态图例与数据更新时间说明。 |
| **Total** |  | **28/40** | **Good；视觉方向正确，需要系统化收口。** |

## Anti-Patterns Verdict

**LLM assessment**：不像通用 AI 生成界面。界面有明确的 WoW 语境、克制的深青色工作台、真实的数据密度，没有奶油色 SaaS、玻璃卡片、巨大圆角、渐变字或装饰性动效。真正的问题是产品级“不可信感”：相同配色下，各业务页仍像分别实现的组件，用户会持续注意 subtly-off 的行高、边框和表头。

**Deterministic scan**：两次 `detect.mjs --json` 均退出 0，合计 0 findings。扫描器面向 Web/CSS/DOM；目录 walker 不包含 `.lua`，补扫明确 Lua 文件后仍为 0。这只能证明未触发 Web 规则，不能证明 WoW UI 没有问题；它存在明显 false-negative 风险。

**Visual overlays**：WoW Lua 界面没有 DOM 或 localhost 页面，浏览器可视化与注入不适用，没有可靠的用户可见 overlay。替代证据是 17 张真实游戏内截图与 Lua 源码逐项对应。

## Overall Impression

统一主壳已经建立了很强的家族感，信息密度也服务于多角色决策，不需要重做视觉风格。最大机会是把“颜色统一”升级为“几何与绘制责任统一”：标题身份、角色表头、Table primitive、斑马纹和当前角色框必须由 Core 的共享构件唯一负责。

## What's Working

1. 共享壳方向正确：46px 标题栏、140px 导航、服务器范围、排序、设置和关闭已有统一结构。
2. 高密度矩阵适合任务：主表 24px 行、分组 28px、悬停紧凑行的 token 已存在，切页后能快速比较账号角色。
3. 大多数业务状态不只靠颜色：文字、复选框、数值、图标和 `—` 共同表达；当前角色也按数据方向使用行框或列框。

## Priority Issues

### [P1] 当前角色列框在纵向 overflow 时逃出窗口

- **证据**：截图 #11 的 Currency 当前列框越过窗口底部；新增 #17 悬停中，同一列框能在最后一行闭合。源码把 outline 建在页面父层，并将底边锚到完整 `currencyBody`，因此滚动内容高于 viewport 时不受裁切。
- **影响**：覆盖游戏世界与动作条，属于明显视觉破损和信任损失。
- **修复**：共享 `headerOutline` 与 `viewportOutline`；body 框作为 scroll viewport 的裁切子层，Y 轴固定覆盖可视区，X 轴继续复用现有 64px 列测量；Reputation 等同模式页面一并回归。
- **Suggested command**：`$impeccable harden`，随后 `$impeccable polish`。

### [P1] 标题身份契约会随宽度降级为空，业务页图标注册不完整

- **证据**：当前代码允许 `完整身份 → 无版本 → 仅页面名 → 空标题`；AltoBoss、QuestBlocker、Legendary 未向页面注册 `icon`。Currency #11/#17 已证明正确目标应为同一图标、插件名、TOC 版本和页面名；#2 应视为旧构建证据。
- **影响**：窄悬停可能变成“无主窗口”，版本排障和插件识别不稳定。
- **修复**：主窗口固定 `22px 图标 + 18px 插件名 v版本 · 页面名`；悬停身份行不得消失，空间不足时把服务器范围移到独立 30px 行。图标 x=16、22×22、标题 x=44；只有 Core 内建页允许无图标。
- **Suggested command**：`$impeccable typeset` + `$impeccable layout`。

### [P1] “所有服务器”下角色身份不完整

- **证据**：QuestBlocker 在 all scope 中显示“角色名 / -服务器”；Currency #11/#17 和 Reputation #14 在同一 scope 中只显示短角色名。行向页面则使用 `角色名-服务器`。
- **影响**：跨服同名角色无法区分，可能把业务数值归到错误角色。
- **修复**：Core 提供唯一角色身份 builder：`realm:*` 为 24px 单行短名；`all` 为 28px 两行“角色名 + muted -服务器”；行向页面为单行全名；tooltip 永远保留全名。
- **Suggested command**：`$impeccable clarify` + `$impeccable polish`。

### [P2] 表头、网格、行高和斑马纹缺少共享渲染契约

- **证据**：AltoBoss 是完整单元格边框，Currency 几乎无竖线，QuestBlocker 是父表头加横线，Reputation 另有层级与星标；Todo 使用 30px+2px，而其他主表多为 24px。Currency 用全局 row index 计算交替色，分组行会改变普通数据行的奇偶相位。
- **影响**：同一套产品切页后仍需重新校准视觉节奏；这是“1px 都不差”验收的主要失败源。
- **修复**：Core 建立共享 Table primitive；主行 24px、悬停 22px、单行表头 24px、两行角色表头/分组 28px；只有明确 iconRow 可用 30px。横线和竖线各只绘一次，禁止相邻 cell 双绘。斑马纹只按数据行计数，并规定每组是否重置。
- **Suggested command**：`$impeccable document`，随后 `$impeccable polish`。

### [P2] 状态词、绿色语义和数据新鲜度未统一

- **证据**：`—、未知？、不可用、尚未同步、未击杀、拜服、数字` 并存；绿色同时表示服务器选中、当前角色、完成、可获取和高声望。
- **影响**：玩家必须先解释颜色再读数据；旧缓存可能被误认为明确的未完成或 0。
- **修复**：统一为“已知值 / 明确未完成 / 不适用 / 未同步或过期”四态；`—` 只表示不适用；未同步附恢复动作；不可用说明条件原因；增加紧凑的快照更新时间。当前角色继续用 1px 青绿色框，但增加非颜色标记，并与 success green 分离。
- **Suggested command**：`$impeccable clarify` + `$impeccable colorize`。

## Pixel Contract

| 区域 | 统一基线 |
|---|---|
| 外壳边框 | 1px |
| 标题栏 | 46px；悬停若换行，scope row 30px |
| 左侧导航 | 140px，内容侧 1px 分隔 |
| 内容 inset | 主界面 8px；悬停 6px |
| 标题 / 图标 | 18px；图标 22×22，x=16；标题 x=44 |
| 标准按钮 | 30px 高；scope 间距 8px |
| 表头 | 单行 24px；all-scope 两行 28px |
| 数据行 | 主界面 24px；悬停 22px；明确 iconRow 例外 30px |
| 单元格 | inset 3px；padding 6px |
| 网格线 | 单源 1px，禁止双绘 |
| 当前角色框 | 1px；独立层；body 仅在 viewport 内显示 |
| Currency | 固定货币列 136px；角色列 64px；斑马纹只按数据行计数 |

像素验收必须锁定 WoW UI Scale、窗口缩放、服务器范围和角色样本；同一构建重拍主界面与悬停，再做差分叠图。截图集混有旧/新阶段，不能把历史截图的每个差异都当作当前回归。

## Persona Red Flags

**Alex（高级用户）**：切页后要重新理解竖线、绿色和表头语法；没有一致的 scope/排序/分页快捷路径；#11 的外框泄漏会立即打断操作流。

**Sam（低视力/键盘依赖）**：11–12px 辅助文字偏小；按钮只有鼠标 hover，没有统一 focus 状态；当前角色主要靠绿色 1px 框，而完成与选中也使用绿色家族。

**Riley（压力测试者）**：all scope 中两个同名角色无法区分；20+角色、长服务器名、不同 UI Scale 与纵向滚动会暴露标题回退、分页和 outline 裁切问题。

**阿衡（多角色 WoW 玩家）**：目标是在 5–10 秒内决定先上哪个角色；现有矩阵很适合，但短名歧义、未知状态和缺少同步时间会让他怀疑数据归属与新鲜度。

## Minor Observations

- `Boss / 目标` 的中英混排应形成全局术语规范。
- About 页的“获取链接”实际更像“项目主页”；空图标框应使用统一占位符。
- AltoBoss 的整片高饱和成功绿更像一排主按钮，应降低填色强度。
- Reputation 独立当前角色预览没有使用 current outline；若属于明确的行列表例外，应在设计规范中记录。
- frame level 应建立语义层级 token，避免 outline、可点击 cell、滚动条和弹出层各自加偏移。

## Questions to Consider

1. 标题栏空间不足时，为什么牺牲插件身份，而不是让服务器范围换到第二行？
2. “所有服务器”却不显示服务器名，是否违背了 scope 本身的意义？
3. 当前角色只是导航线索，为什么要与成功状态共用最醒目的绿色？
4. 如果所有业务页转成灰度，只看轮廓、行高与网格，它们还能否被认作同一套组件？
