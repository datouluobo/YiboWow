# API v12：业务项目主动添加

Core 1.11.0 / API v12，2026-10-11 已发布。能力 `business-item-actions:1`；已接入来源与验证状态见 [实施记录](../../Docs/行动中心-主动添加实施与验证.md) 和 [CAP-008 台账](Core-公共能力迁移台账.md#cap-008业务项目主动添加)。

## 职责与调用

Core 统一手势、控件绑定、提示、确认和窗口壳；TaskHub 拥有目标；来源解释业务意图与事实。Core 不读取业务 SavedVariables，不硬编码来源技术名。

```lua
if not (Core:CheckAPIVersion(12) and Core:HasCapability("business-item-actions", 1)) then
    Core:Print("请升级 Core，主动添加需要 API v12。")
    return -- 停止此增强
end
Core.BusinessItemActions:Bind(control, {
    owner = addonName,
    GetIntent = function() return currentIntent end,
    reservedButtons = { LeftButton = true, RightButton = true },
    -- menu = false 仅用于已有另一个可见菜单的安全覆盖控件
})
control:RegisterForClicks("AnyUp")
control:SetScript("OnClick", function(self, button)
    if Core.BusinessItemActions:Handle(self, button) then return end
    -- 在此保留来源原点击行为
end)
```

`GetIntent` 是本插件传给 Core 工具的回调；返回纯值意图。回调／Frame 不经 Contracts 传递。行复用重新 Bind，空行主动 Unbind；Core 在 OnHide 解绑，已创建菜单重复复用。Bind 要求 owner / GetIntent，有效时返回 true 及可选 gesture-conflict。Handle 只有匹配且未保留的按键返回 true，并消费当前点击；失败反馈仍消费添加点击，避免执行第二个动作。

`Invoke(control, options?)` 供可见菜单和 Handle 共用。通过 Core Resolve `action.demands` major1 调用 Add；显式点击菜单时，缺参数 Configure，重复 Locate。Handle 使用 `{keepOpen=true,toggle=true}`：先精确 Lookup，已有目标用返回 revision 调用 Update 移除，否则添加；均保持当前主窗口、悬停与页面；缺参数只提示点击＋补充，保存前不创建目标。来源或 Task 不兼容／缺失时明确提示。✓ 通过来源规范化身份精确匹配；参数不足不误标。右上角模式使用16px的 ＋／原生勾选按钮，仅项目悬停时显示；中键或 Ctrl＋左键模式隐藏此按钮，缺参数时临时显示补参入口。三种方式互斥，手势再次触发取消精确目标。menu=false 仅用于同项目的重复安全覆盖控件。

已加入的项目按 markerStyle 常驻左下角金黄色折角（corner，默认）或青绿圆点（dot）。均使用两条原生纹理，不接收鼠标、不改变图标尺寸。悬停说明目标数量及进行中／暂停／已完成状态；标记只表示已加入，不表示完成。Core 按帧合并绑定和目标变更通知，通过 `action.demands` v1.1 的 LookupItems 批量查询；Task 按库 revision 缓存索引，不查询来源事实或复制历史。项目匹配按来源、对象与可选角色范围，因此缺少数量或模式的业务项目也能显示已有目标；悬停菜单的✓仍使用精确 Lookup，语义不同。目标移除、控件复用、角色变化、能力晚注册或注销会刷新／清除标记。menu=false 的重复安全覆盖控件不绘制第二个标记。旧 v1.0 Task 仍可添加，仅无此可选标记增强；未注册或不兼容时隐藏标记。

`GetOptions()` 返回 `{mode,markerStyle}` 副本；`SetOptions()` 校验并保存到 Core settings.businessItemActions，立即刷新绑定与标记。统一工作台选择 menu / middle / ctrlLeft 三种互斥方式，默认 middle；markerStyle 为 corner / dot。战斗中拒绝修改。旧 settings.businessItemGesture 自动迁移：标准中键和 Ctrl＋左键映射对应模式，其它已有组合保留 custom 兼容项，直到用户主动选择新方式。

`GetGesture()` 返回当前模式的手势副本，`GestureLabel()` 返回提示，Matches 要求修饰状态完全一致。`SetGesture()` 仅保留旧调用兼容，不作为新设置界面。普通业务入口显式设置 `ctrlLeftSafe=true` 后可复用 Ctrl＋左键，原左键保持保留；必须在原业务处理前调用 Handle 并消费返回 true。安全控件使用可选 `ConfigureCtrlLeft(enabled)`：来源战斗外设置 ctrl-type1 空字符串以禁用安全动作回退，其它模式恢复 nil，成功返回 true。Core 只调用回调，不修改安全属性或代理施法；来源未声明安全接入时仍拒绝复用保留按键。已接入来源包括 Todo／Builds 安全控件以及 Currency／Crafting／Mail／Legendary／Reputation 普通点击控件。


`TooltipLines(lines,control)` 返回带当前手势／菜单说明的副本；`Unbind(control)` 隐藏菜单并移除当前上下文；`BUSINESS_ITEM_GESTURE_CHANGED` 使用 Core Events 隔离通知。业务页面应在后续刷新时重新生成提示。

## 能力版本 2：悬停与产物位置

2026-10-11 工作树提供 `business-item-actions:2`，兼容版本 1 调用。Bind 新增可选 `menuPlacement="right"`，将按钮放在来源控件右侧 2px；默认仍为右上角，来源负责预留 18px 空间。Core 用单个 50ms 焦点检查器寻找鼠标所在的最近绑定祖先，并沿按钮的来源引用保留同一项目；切项立即隐藏前项，离开时 120ms 宽限支持跨入旁侧按钮。源控件的 OnEnter/OnLeave 可由业务 tooltip 设置，不再影响添加入口；解绑最后一个来源时停止检查器。点击分派仍由来源调用 Handle。

Crafting 1.0.7 的目标增强要求能力 2；低版本明确提示升级并停止目标增强初始化，基础配方浏览沿用原最低版本要求，无本地按钮回退。矩阵仅已学格绑定，产物图标使用右侧位置。

## 版本与接入

菜单已加入状态使用 WoW 原生 UI-CheckBox-Check 纹理，未加入使用 ASCII 加号，避免中文字体缺字；状态不依赖文本✓渲染。

中键及其它配置手势再次触发时取消精确匹配的目标；数量、模式或难度不足以确定同一目标时仍走必要参数提示，不批量移除同对象其它目标。Lookup 返回 revision 后才允许取消；旧服务缺此字段明确提示升级，不绕过事务校验。

所有新绑定要求 API12 / business-item-actions:1。TaskHub 整体要求 API12；来源保留旧基础最低版本作为明确兼容例外，只有新增强停用，无第二套本地绑定回退。现有 Service、Provider、事件、账号页与输入 API 保持兼容。

已接入调用位于 AltoBoss / Builds / Crafting / Currency / Legendary / Mail / Reputation / Todo / Vault 的 GoalTargets 与实际业务页面；Core 手势设置在 SettingsWorkbench。其它来源当前无合适持久目标，未注册占位能力。来源新增可验证对象或修改同类点击入口时接入本能力。客户端安全交互与布局仍待验收，自动化与范围以实施记录为准。

## 简短悬停说明（2026-10-14，business-item-actions:3）

API13 工作树提供能力3，兼容能力1／2的已有调用。`Bind(control, {owner, GetIntent, compactTooltip=true, ...})` 可选择简短操作说明；默认 false，已有消费者显示不变。`TooltipLines(lines, control)` 根据已注册绑定和当前全局操作模式生成一行中英文提示并用辅助色呈现；手势模式描述添加／取消，菜单模式描述添加／查看。必要参数缺失仍由现有 Invoke 流程提示并提供补参入口。无绑定时不输出操作说明，重复调用不会堆积提示或分隔行。没有业务数据输入或业务分支，Core 不读取消费者内部状态。

AltoBoss 的目标增强检查 API13 / business-item-actions:3，不满足时提示升级并停止该增强；基础采集及副本展示继续运行，不提供本地手势回退。副本格启用 compactTooltip，其他格及其他插件保持原默认。后续业务调用触及同类简化需求时按需接入；本次仅静态语法及语言检查，实际交互待客户端验收。

## 已保存目标标记的完成状态（2026-10-25）

`LookupItems` 的 count／active／paused／completed 继续返回全部已保存目标及状态，供查看历史。Core 的常驻角标／圆点仅在 active + paused > 0 时显示；仅剩 completed 历史时隐藏。混合同对象目标时，一个仍活动或暂停的目标足以保留标记；重新开启目标后恢复标记。已完成历史、精确查找、查看与重开操作不因角标隐藏而删除或改写。循环目标按其持久状态处理，不用临时完成预览代替状态字段。

本次为现有 business-item-actions:3 的显示修正，兼容现有1／2／3绑定和action.demands:1.1的状态汇总，不新增业务插件分支或版本要求。共享UI/BusinessItemActions.lua由Mists与Forever加载；实际Core与Hub集成验证覆盖制作完成后两种来源控件角标隐藏、历史保留、混合状态、重开／暂停／移除，客户端待复验。
