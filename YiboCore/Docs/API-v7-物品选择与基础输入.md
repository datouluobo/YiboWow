# API v7：物品选择与基础输入

首批版本：YiboCore **1.6.1**＋YiboCurrency **0.9.1**。Core API v7 保持 v5/v6 兼容。
新业务插件须保留 `.toc` 的 `RequiredDeps: YiboCore`，并在注册页面或创建控件前检查 `CheckAPIVersion(7)` 和所需方法。能力版本为 `basic-input:1`、`item-resolver:1`、`item-picker:1`。

## 基础输入

`Core.UITheme:CreateInput(parent, options)` 返回 EditBox，复用 Theme 字体、颜色、间距和尺寸。

| options | 约定 |
| --- | --- |
| width / size | 默认 240，尺寸档位默认 `standard` |
| placeholder / maxLetters / numeric | 提示、长度上限（默认 255）、纯数字输入 |
| value / restoreOnEscape | 初始值；可声明 Esc 恢复获得焦点时的值 |
| OnChanged(text, userInput, input) | 用户输入触发；程序赋值仅显式通知时触发 |
| Validate(text) / OnInvalid(message, input) | 回车提交前业务校验及错误回调 |
| OnSubmit(text, input) / OnFocus(focused, input) | 回车提交、焦点变化 |

`input:SetValue(value, notify)` 默认静默赋值；`SetInputEnabled(enabled)` 统一禁用状态。默认不抢焦点，Esc 和隐藏时清理焦点。

## 脱离 UI 的解析服务

`Core.ItemResolver:Parse(input, options)` 返回候选数组，或 `nil, message`。每项为 `{ itemID, name, link, icon, state }`。ID 限制为正整数且不超过 2147483647；格式合法不表示物品存在，也不表示业务允许保存。

- `allowID`、`allowLink` 默认开启，`allowName` 默认关闭。
- `candidates` 是物品 ID／`{ itemID, name/title }` 数组或返回数组的函数；不接受 NPC、任务等其它身份。
- `includeBags` 显式启用当前随身背包 0–4，不扫描银行或其它插件私有目录。
- `match` 默认精确匹配，`contains` 为子串匹配。按 ID 去重并排序，多个候选必须由调用方明确选择。
- 目录名称可以用于匹配，但保存前仍须确认客户端真实信息。

`GetInfo(itemID)` 返回当前信息，状态为 `ready/unloaded/loading/failed`。
`Request(itemID, callback, { retry, timeout })` 返回带 `Cancel()` 的句柄，回调为 `(info, errorMessage)`。缓存就绪时同步回调；未缓存时同 ID 合并请求，默认 8 秒超时。失败后只有显式 `retry=true` 才再次请求，无自动循环。取消仅影响自己的回调。UI 调用方仍须用组件代次和可见状态检查过期结果。

## 可配置选择器

`Core:CreateItemPicker(parent, config)` 返回托管 Frame。`Layout(width)` 按完整控件换行并返回内容高度；`SetValue(value)` 取消旧动作并静默回填；`Unbind()` 取消请求、确认并隐藏。

| config | 约定 |
| --- | --- |
| resolve | 传递给 Parse 的配置 |
| placeholder / candidateDropdown | 提示；候选下拉默认开启，可关闭（多个匹配仍禁止提交） |
| enterAction | 回车动作，默认有 add 时为 `add`，否则 `select` |
| add / remove | 业务操作定义；未配置时不创建按钮 |
| dropMode | `select` 仅选择、`add` 仅添加、`toggle` 按存在性添加／删除；未配置时不创建拖放区 |
| Exists(info) | toggle 的存在性检查；删除资格由 remove.Validate 检查 |
| OnSelected(info) / OnSuccess() | 选择结果填入业务草稿／成功后刷新 |
| actions | 扩展按钮数组：`label, width, style, IsEnabled(), Execute()` |

操作定义为 `{ label, Validate(info), Confirm(info), Execute(info) }`。
Validate 返回 `ok, reason`，确认前和接受时均检查；Confirm 返回业务风险文案，nil 时直接执行；Execute 返回 `ok, message`，负责业务存档。Core 不接管目录、规则或 NPC 解析。扩展按钮调用自身业务回调。

候选下拉仅在多个匹配时显示，每页 8 项，选中后再次点击操作提交。重试仅在物品信息加载失败时显示；空反馈区域收起，隐藏控件不占布局空间。`OnLayoutChanged(height)` 可通知宿主更新内容高度。预览展示客户端名称、ID、图标；失败提供具体原因和重试。加载与确认期间阻止重复提交；输入变化、隐藏、解绑取消旧动作。成功清空输入再刷新，失败及取消保留输入。业务须把整个组件放在“数据与缓存”末尾。操作栏按可用宽度排布，输入及候选框分配剩余空间，操作按钮按最长可见文案统一宽度，右侧默认预留 Theme.Space.md（16px），可用 rightInset 配置；四个默认控件可容纳时共用一行，不足时整控件换行。remove 位于操作组最后，保留危险样式与风险确认。反馈按实际文字高度展示。

拖放只读取身份，不移动、邮寄、使用或装备物品。捕获合法物品 ID 后才 ClearCursor；无效拖放保留光标，加载或业务校验失败保留输入且不执行业务动作。

## 物品操作确认

首轮接口 `Core.ItemConfirmation:Show({ text, IsCurrent(), OnAccept(), OnCancel() })` 返回带 Cancel 的独立请求。仅一个物品确认活跃，新请求取消前一个；接受时检查当前请求，业务仍负责最终资格检查。页面外调用方须在所属页面隐藏时取消句柄。

Currency 主账号页 `ConfirmRemoveCustomItem(itemID, refreshPage, owner)` 复用设置页的删除定义和 Core 确认框；使用已保存名称，owner 隐藏时取消。

## 验证

从仓库根运行：

```powershell
lua YiboCurrency/_NonRelease/Tests/CoreItemControlsSpec.lua
lua YiboCurrency/_NonRelease/Tests/VaultIntegrationSpec.lua
./Tools/Test-LuaSyntax.ps1 -Addon YiboCore,YiboCurrency
```

覆盖解析歧义、请求合并／取消／超时／重试、程序赋值、Currency 存档操作、旧确认失效、候选分页、窄宽布局、扩展操作、旧 Core 停止注册。游戏内验证见 Currency 客户端验收清单。
