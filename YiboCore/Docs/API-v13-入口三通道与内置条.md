# API v13：入口三通道与内置条

2026-10-11 工作树已实现，客户端待验收，未发布。Core 总 API 保持 13；新增行为检查 `account-entry:2`，信息条基础能力检查 `builtin-entry-bar:1`；外观与前后移动检查 `builtin-entry-bar:2`，图标拖拽定位调序检查 `builtin-entry-bar:3`。原 `RegisterBusinessEntry`、`defaultMode`、`legacyIDs` 和四状态读取／切换接口保持兼容；旧接口只操作小地图和 Broker，保留内置条选择。已有业务注册无需提高版本。新消费者须检查 API13 与实际所需能力；不足时提示升级并停止依赖功能。

## 职责和真值

Core 独占入口配置、LDB 对象、内置条布局与共用预览生命周期；业务继续提供页面、图标、文字、快照和字段。三处入口不另存业务数据，也不增加逐图标扫描。内置条直接消费 Core 注册表，未选 Broker 时不发布外部对象。内部 `EntryConfig` 不作为业务 API。

配置位于 `settings.accountView.entry`：`channelsVersion=1`、`coreChannels`、按入口 ID 索引的 `businessChannels`、`bar`。三个通道名为 `minimap / broker / builtinBar`，全部布尔值。Schema 11 将四种旧模式和未加载插件配置迁入；新表优先，显式 false 保留；旧字段只保留为迁移来源，不再作为运行时真值。角度、位置、悬停偏好保持。

## Core.Entry 公共方法

| 方法 | 输入／返回／失败 |
| --- | --- |
| `GetEntryChannels(id)` | Core ID 为 `YiboCore`；返回三个布尔值的独立副本；未知业务 ID 返回全 false |
| `SetEntryChannel(id, channel, enabled)` | 有效非空 ID、上述通道及布尔值；保存并即时刷新，返回 true；参数无效返回 false；允许预配置尚未注册 ID |
| `GetBuiltinBarSettings()` | 返回独立副本；默认关闭、锁定、图标24、间距6、不显示名称，TOP/TOP、0/-16；v2 增加 showBorder=true、background=theme、backgroundAlpha=0.95、order={} |
| `SetBuiltinBarEnabled(enabled)` | 布尔值；保留所有入口选择；关闭只清理内置条拥有的预览，返回 true；参数无效 false |
| `SetBuiltinBarOption(key, value)` | locked/showNames 布尔值，iconSize 数值16–48，spacing 数值0–20；v2 增加 showBorder 布尔值、background 枚举 theme/black/charcoal/navy/forest、backgroundAlpha 数值0–1；即时生效，数值有界归一化，非法键／类型 false |
| `SetBuiltinBarPosition(point, relativePoint, x, y)` | 保存锚点和偏移；异常值归一化；运行时限制在安全屏幕范围 |
| `GetEntryAvailability(id)` | 已注册、未注销，且解析后的目标页面通过现有 PageEnabled 规则；返回布尔值。Core 依共享窗口可用性 |
| `HandleEntryClick(id, mouseButton)` | 不可用 false；右键打开 display 设置，左键沿现有解析打开业务页面／Core 框架；有效 true |
| `ShowEntryPreview(id, anchor, source)` | source 使用 minimap/broker/builtinBar；不可用或当前不允许预览返回 false，否则沿原窗口预览路径；异步渲染仍由原 token 合并与取消机制管理 |
| `CloseEntryPreview(id?, source?)` | 仅清理匹配的当前所有者；两者省略清理当前预览；关闭条不能误清理 Broker／小地图预览 |
| `GetBuiltinBarEntries()` | 已选且可用列表；默认 Core 首位，之后按 addonName/id 排序；v2 优先应用用户保存的顺序，未排序的新入口按默认规则追加；不受总开关过滤，用于设置统计；仅返回 id/addonName/text/icon 元数据副本，不暴露按钮或 Broker 内部引用 |

`RegisterBusinessEntry` 新增可选 `defaultChannels`，仅在无已保存选择及可用旧别名时应用。仅允许上述布尔键；未知键或非布尔值拒绝注册。缺省键为 false；未提供时沿用 defaultMode，内置条 false。`YiboCore` 为保留 ID。晚注册／重复注册恢复展示，注销停用各通道，配置继续保留。

## 生命周期和交互

入口注册／注销、配置及页面注册／注销刷新展示；显示开关修改即时刷新且不改写通道。统一右键进入“显示与入口”，未增加入口定位参数。内置条不需要外部展示插件，总开关关闭不影响其它通道；总开关开启且无可用入口不显示空白条。

外部 LDB 不支持通用注销：停用后立即撤销交互，下次重载不注册；外部图标隐藏由展示插件控制，不改写 LDB 私有表。Core 和业务 Broker 均支持初始关闭后即时创建、停用后恢复。同名非本 Core 对象不覆盖。LibStub 版本机制保留较新共享库。

内置条解锁后用左侧独立把手拖动。位置由 Core 保存，图标不承担拖动。按内容宽度换行，超出安全高度后分页；分页仅处理入口按钮。分辨率/UI 缩放重新布局，框架 clamp 保证可达。预览仍使用唯一账号窗口、快照、角色准入与预览列，沿用延迟关闭及进入预览的交互。

## 已接入和后续触发

Core 小地图、Core Broker、业务小地图、业务 Broker、内置条和设置表已统一消费。所有原有业务注册自动获得 Core 托管行为，本次未修改业务运行源码；这不代表各业务实机验收完成。以后业务修改只需按原注册契约提供元数据；主动调用新配置方法时声明所需能力。台账 CAP-004 记录进度；语言资源 CAP-009 同步记录。

自动化和实际客户端矩阵见 [实施与验收记录](Core-内置LDB与信息条-实施与验收记录.md)。

## 设置布局与 v2 调序

Core 常规设置自身可点击，直接显示语言与通用悬停内容；窗口、角色与排序、信息条、显示与入口为下一级导航。显示与入口以共享表头、每插件一行展示全部注册页面与业务设置，不分页，超出安全高度后纵向滚动。信息条管理外观、位置与按钮顺序。没有字段选项的业务不占用字段行。完整列表提供注册插件总数，不改变左侧导航；同时纳入仅注册业务设置的插件，明确标注没有独立页面或入口。控件统一30高度，行距38，通道按翻译文本宽度分配，普通按钮按文本自然宽度，表单控件限制为紧凑宽度。

`MoveBuiltinBarEntry(id, direction)`：v2，direction 仅 -1/+1，在当前已选且可用按钮中前移／后移一位，支持 Core；有效变更保存并刷新，未知 ID、非法方向和首尾越界返回 false。`ResetBuiltinBarOrder()`：v2，清空自定义顺序并刷新，恢复默认排序。order 保存稳定入口 ID，暂时不可用或未注册的 ID 保留；恢复后沿用原顺序，不改写其它通道和导航排序。总开关关闭保留配色、透明度、外框与排序。读取设置和列表继续返回副本。

## v3 图标拖拽与名称

`builtin-entry-bar:3` 增加 `ReorderBuiltinBarEntry(id, targetID)`，将已选且可用的源入口移至目标入口的当前位置，返回 true 并保存刷新；未知、不可用或同一 ID 返回 false。未展示的保存 ID 继续保留，恢复后保持其排序槽位；v1/v2 方法继续兼容，API13 与 schema11 不变。Core 信息条直接拖拽图标调用此方法，限当前可见按钮，条外松开取消；拖拽不打开业务页面，下一次正常点击仍可打开。位置锁仅约束条的位置把手，图标调序不受影响。禁用／隐藏条取消进行中的图标拖拽。

`GetBuiltinBarEntries()` 的 text 优先使用目标页面标题，否则使用注册入口文字，统一去掉颜色标记、前导 [Yibo] 和前导 Yibo技术名加连字符；Core 同样移除作者前缀。仅影响内置条名称及其调序下拉，不修改业务元数据、TOC 或历史文本。返回副本、稳定 ID、数据所有权保持。
