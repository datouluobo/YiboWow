# YiboCore API v14 · 像素线宽（`pixel-line:1`）

2026-11-21 · 状态：工作树已实现，离线通过，三端实机待验 · 台账：CAP-013 · 方案：[像素线宽统一控制实施方案](Core-像素线宽统一控制-实施方案-2026-11-21.md)

## 职责

让 1 线宽的格线、分隔线、边框和描边在任意分辨率与 UI 缩放下都恰好占 N 个物理像素。Core 负责像素换算、缩放变化后的刷新和按边边框；业务插件只声明要几像素、要哪几条边，不自行换算，也不保留本地 `edgeSize = 1` 回退。布局尺寸（列宽、行高、外边距、沟槽）仍为 UI 单位，不受影响。

## 版本检查

```lua
if not (Core:CheckAPIVersion(14) and Core:HasCapability("pixel-line", 1)
    and type(Core.UITheme.CreatePixelBorder) == "function") then
    -- 提示升级 YiboCore，停止依赖本能力的页面初始化
end
```

## 换算

`N 像素的 UI 长度 = N × 768 ÷ 物理屏幕高度 ÷ 区域有效缩放`。物理高度来自目标适配层 `Core.Client:ReadPhysicalScreenSize()`（三端绑定 `GetPhysicalScreenSize`）。读不到、出错或返回非正整数时，1 像素回退为 1 UI 单位（即旧行为），状态为 `unknown`，不抛错；有效读数才缓存，失败会在下次使用时重读。

## 接口（`Core.UITheme`）

| 接口 | 说明 |
| --- | --- |
| `GetPixelSize(region, pixels)` | `pixels`（默认 1，取整且至少 1）个物理像素在 `region` 中的 UI 长度。 |
| `SnapToPixel(region, value)` | 把偏移或尺寸吸附到 `region` 的像素网格；`unknown` 时原样返回。 |
| `GetPixelMetricsState()` | `"known"` 或 `"unknown"`。 |
| `ApplyPixelRule(texture, orientation, options)` | 把已有纹理设为 N 像素线；`orientation` 为 `"horizontal"`/`"vertical"`，`options.pixels`、`options.color`。调用方负责沿线方向的锚点，Core 只管粗细。 |
| `CreatePixelRule(parent, orientation, options)` | 新建纹理并 `ApplyPixelRule`；另可传 `layer`、`sublevel`（默认 `ARTWORK` / 7）。 |
| `ApplyPixelBackdrop(frame, options)` | 替代 `SetBackdrop({ bgFile, edgeFile, edgeSize = 1 })`；`options.background = false` 只画边，`options.pixels`。之后照常调用 `SetBackdropColor` / `SetBackdropBorderColor`；尺寸变化重建时恢复颜色。 |
| `CreatePixelBorder(frame, options)` | 按边边框。`options.sides = { top, right, bottom, left }`（省略为四边）、`color`、`pixels`、`layer`、`sublevel`。同一 frame 重复调用原地更新：新增的边才创建纹理，去掉的边隐藏。竖边避开已画的横边，拐角像素只画一次。 |
| `border:SetColor(color 或 r,g,b,a)` / `border:SetSides(sides)` / `border:SetShown(shown)` | 状态切换只改颜色、边或显隐，不重建。 |
| `SetPixelAnchor(region, anchor)` | 立即执行 `anchor`，并在每次像素尺寸变化（UI 缩放、显示尺寸、`UIParent:SetScale`）后重新执行。用于依赖 `GetPixelSize` 的锚点或尺寸，例如 1 像素边框内的图标内缩、随边框宽度变化的内容宽度。每个 region 一个 anchor，再次调用即替换，传 `nil` 移除；已是 Core 像素线／Backdrop 的 region 保留其自身的粗细刷新。业务插件不得再读取或写入 `__yiboPixelAnchor` 等内部字段。 |
| `RefreshPixelLines()` | 立即按当前缩放重算全部已登记的线；通常无需业务调用。 |

`Theme.Table.lineWidth` 自 API 14 起表示**物理像素数**（默认 1），不得直接用作锚点偏移；需要偏移时用 `GetPixelSize(region, Theme.Table.lineWidth)`。

## 刷新与生命周期

- 已登记对象保存在弱引用表中，frame 回收后不再访问。
- Core 监听目标已声明的 `UI_SCALE_CHANGED`、`DISPLAY_SIZE_CHANGED`，同一帧内多次事件合并为下一帧一次刷新（`C_Timer.After(0)`），不使用 `OnUpdate` 轮询。另以 `hooksecurefunc(UIParent, "SetScale")` 后置钩子和 `UIParent:OnSizeChanged` 触发同一合并刷新：整合界面插件直接调用 `UIParent:SetScale` 时，缩放事件和 OnSizeChanged 都不会触发（Forever 1.60.1 实测）。
- 依赖线宽的锚点（当前角色描边内缩、页签基线、表头右线下端）随刷新重新计算；描边隐藏后不再重锚。
- 不写 SavedVariables，不读取业务插件数据。

## 推荐用法

- 相邻堆叠的行：每行 `sides = { top = 首行, right = true, bottom = true, left = true }`，相邻行只共用一条线。
- 有列底纹的矩阵不画普通竖线；状态格保留语义边框时，所在行不再画竖向格线。
- 当前角色描边、表头等 Core 共用部件已内置，业务页无需处理。

## 当前角色描边几何（2026-11-21 修订）

- 描边画在它所强调的格线上，而不是格线内侧 1 像素，避免与普通格线形成平行线组。
- 列描边：左边覆盖左邻列的右线（`x - 1px`），右边覆盖本列右线（`x + width`），顶边贴表头顶部。
- 列描边底部跟随视口内实际可见内容：内容比视口短时止于最后一行底线；内容溢出时止于视口底部。视口为 Core `CreateScrollFrame` 且页面调用 `SetContentHeight` 时自动生效，滚动、视口尺寸变化和 `SetContentHeight` 都会重新定位；非 Core 滚动视口仍以视口底部为界。
- 行描边：贴行自身边界；若该行使用 Core 按边边框且没有顶边（非首行），顶边上移 1 像素覆盖上一行的底线。行仍使用四边 Backdrop 的旧页面，相邻行底线仍会与描边相邻，需随该页按边边框迁移后消除。
- 新旧两种句柄（`CreateCurrentCharacterOutline` 返回的旧句柄、按 owner 自动创建）使用同一套几何：顶部一律取 `header` 的上沿（旧句柄原先取 header 与视口两者较低的上沿，会把表头排除在外，已取消）。调用约定：`header` 传上沿等于角色表头上沿的框体（表头条比表头格高时传当前角色表头格，`x = 0`，`viewportX` 为该列在视口内的横坐标）；`viewport` 传内容视口，没有 Core 滚动视口时可传最后一行，描边止于该行底边。
- 视口若是普通 Frame（没有 `OnVerticalScroll`），Core 只监听尺寸变化，不再因 `HookScript` 不支持而报错。
- 行比表格宽（斑马底纹铺满视口）时，页面应把行描边交给只覆盖表格列宽的子框体，避免描边超出最后一列。

## 已接入与待迁移

见 [公共能力迁移台账 CAP-013](Core-公共能力迁移台账.md#cap-013像素线宽与按边像素边框)。迁移触发条件：业务插件修改含线框的页面时，同步把该页 `edgeSize = 1` 线框迁到本接口并按“一条边界只画一次”去重，同时提高最低 Core 要求。
