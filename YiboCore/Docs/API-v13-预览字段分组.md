# API13 预览字段分组

能力：`account-preview-field-groups:1`，最低 Core1.12.3 / API13。实现：UI/AccountPages/SettingsWorkbench.lua；消费：YiboAltoBoss。

## 职责与契约

Core 的统一设置工作台将页面 `fields` 与 `GetPreviewFieldDefinitions()` 返回项的 `group` 传递给既有多选控件。Core 只组织字段选择，业务所有者负责字段定义、选择保存、投影与失效，不新增业务规则或数据副本。

`GetPreviewFieldDefinitions()` 返回数组，每项为 `{id=稳定ASCII标识, title=会话语言标签, group=可选分组标签}`。id 必须在页面全部字段中唯一；group 仅用于显示，省略时归入常规组。分组按首次出现顺序显示；业务方按实际内容限制组长度，避免无限列表。

`GetPreviewFields()` 返回以字段id为键、布尔值为值的独立快照。`SetPreviewFieldVisible(id, visible)` 由业务所有者校验并保存。分组标签不得作为持久化字段身份。设置页刷新时重新读取定义，重复刷新不重复注册页面或订阅。

消费方初始化检查能力版本；缺失或不兼容时明确提示升级并停止依赖初始化，无本地设置回退。未声明group的既有页面行为保持。

## 接入与验证

AltoBoss 固定副本字段使用 `instance:<既有副本key>`，旧 lockoutColumns 选择仅在新字段缺失时导入 settings.previewColumns；旧记录保留。每资料片组按12项分段，历史／有效锁定补充规则仍归 AltoBoss。

静态语法与既有副本回归通过；客户端菜单、语言及选择保留验收待完成。其他页面未来需要分组时通过同一元数据接入，无需新增插件专用分支。
